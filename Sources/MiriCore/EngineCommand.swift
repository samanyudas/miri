/// The engine's reading of a `[bindings]` key, so that two spellings of one command compare equal.
///
/// The engine splits a key on `_` (`vendor/paneru/src/config.rs` line 1177), parses the words with `parse_command`
/// (`vendor/paneru/src/types/argv.rs` lines 43-168), and ignores words after the ones a command needs. Several keys
/// therefore name one command, such as `window_grow`, `window_resize`, and `window_resize_grow`. This mirrors that
/// parser at the pinned engine and writes the result in the engine's own encoding (`to_argv`, argv.rs lines 176-256).
enum EngineCommand {
    /// The engine's own spelling of the command a key names, such as `window_resize_grow` for `window_grow`.
    /// Returns `nil` for a key the engine rejects.
    static func canonical(_ key: String) -> String? {
        let words = key.split(separator: "_", omittingEmptySubsequences: false).map(String.init)
        return command(words)?.joined(separator: "_")
    }

    private static func command(_ words: [String]) -> [String]? {
        switch words[0] {
        case "printstate", "quit", "restart": [words[0]]
        case "window": operation(Array(words.dropFirst())).map { ["window"] + $0 }
        case "mouse": words.count > 1 && words[1] == "nextdisplay" ? ["mouse", "nextdisplay"] : nil
        default: nil
        }
    }

    private static func operation(_ words: [String]) -> [String]? {
        let verb = words.first ?? ""
        let argument = words.count > 1 ? words[1] : nil
        switch verb {
        case "focus":
            guard let argument else { return nil }
            if argument == "unmanaged" || argument == "managed" { return [verb, argument] }
            return positional(argument).map { [verb, $0] }
        case "raise": return argument == "floating" ? [verb, "floating"] : nil
        case "swap": return argument.flatMap(direction).map { [verb, $0] }
        case "resize", "step": return resizeDirection(argument).map { [verb, $0] }
        case "grow", "shrink": return ["resize", verb]
        case "vertical":
            let form = argument == "step" ? "step" : "resize"
            let direction = argument == nil || argument == form ? words.count > 2 ? words[2] : nil : argument
            return resizeDirection(direction).map { ["vertical", form, $0] }
        case "focusdisplay", "movedisplay": return argument.flatMap(compass).map { [verb, $0] }
        case "stack": return side(argument, default: "west").map { [verb, $0] }
        case "unstack": return side(argument, default: "east").map { [verb, $0] }
        case "center", "fullwidth", "manage", "equalize", "balance", "tabbeddisplay", "nextdisplay",
            "nextdisplaysend", "snap", "copyrule", "virtualadd", "togglefloatlayer":
            return [verb]
        case "virtualfocus": return argument.flatMap(direction).map { [verb, $0] }
        case "virtualnum", "virtualmovenum", "virtualsendnum":
            return argument.flatMap(workspace).map { [verb, $0] }
        case "virtual", "virtualmove", "virtualsend":
            guard let argument else { return nil }
            // A number selects the `num` form, so `window_virtual_2` is `window_virtualnum_2` (argv.rs line 155).
            if number(argument, max: UInt64(UInt32.max)) != nil {
                return workspace(argument).map { [verb + "num", $0] }
            }
            return direction(argument).map { [verb, $0] }
        default: return nil
        }
    }

    /// `Direction::parse` (`vendor/paneru/src/types/commands.rs` line 49).
    private static func direction(_ word: String) -> String? {
        ["north", "south", "west", "east", "first", "last"].contains(word) ? word : nil
    }

    /// `Direction::parse_compass` (commands.rs line 66).
    private static func compass(_ word: String) -> String? {
        ["north", "south", "west", "east"].contains(word) ? word : nil
    }

    /// `Direction::parse_positional` (commands.rs line 81): a 1-based number, or else a direction name.
    private static func positional(_ word: String) -> String? {
        guard let value = number(word, max: UInt64(UInt.max)) else { return direction(word) }
        return value == 0 ? nil : String(value)
    }

    /// `parse_virtual_workspace_number` (commands.rs line 250).
    private static func workspace(_ word: String) -> String? {
        guard let value = number(word, max: UInt64(UInt32.max)), value > 0 else { return nil }
        return String(value)
    }

    /// `ResizeDirection::parse` (commands.rs line 208), with `grow` when the word is absent (argv.rs line 140).
    private static func resizeDirection(_ word: String?) -> String? {
        guard let word else { return "grow" }
        return word == "grow" || word == "shrink" ? word : nil
    }

    /// `Side::parse` (commands.rs line 179), with the default for an absent side (argv.rs line 145).
    private static func side(_ word: String?, default fallback: String) -> String? {
        guard let word else { return fallback }
        return word == "west" || word == "east" ? word : nil
    }

    /// Rust's unsigned `str::parse`: an optional `+`, then one or more ASCII digits, within the type's range.
    private static func number(_ word: String, max: UInt64) -> UInt64? {
        let digits = word.hasPrefix("+") ? word.dropFirst() : Substring(word)
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }), let value = UInt64(digits),
            value <= max
        else { return nil }
        return value
    }
}
