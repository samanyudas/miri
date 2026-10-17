/// The engine's reading of a chord's text, such as `ctrl+alt-leftarrow`, so Miri can report a chord it cannot read.
///
/// The engine splits the text on `-` and trims each part (`vendor/paneru/src/config.rs` line 1379), reads the
/// modifiers with `parse_modifiers` (line 1736), and looks the key up with `keycode_for_key_name` (line 1718).
/// Names are case-sensitive. `scripts/check-compat.py` checks the name lists below against the engine's tables.
enum EngineKey {
    enum Problem {
        case extraDash(text: String)
        case invalidModifier(text: String, name: String)
        case unknownKey(text: String, name: String)

        var message: String {
            switch self {
            case .extraDash(let text):
                "\"\(text)\" has more than one dash. Write the modifiers joined by +, then one dash and the key."
            case .invalidModifier(let text, let name):
                "\"\(text)\" names the modifier \"\(name)\", which the engine does not know. "
                    + "Use ctrl, alt, cmd, shift, or fn."
            case .unknownKey(let text, let name):
                "\"\(text)\" names the key \"\(name)\", which the engine does not know, so the shortcut does nothing. "
                    + "Use a key name such as leftarrow, equal, or h."
            }
        }
    }

    static func problem(in text: String) -> Problem? {
        var parts = text.split(separator: "-", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let key = parts.removeLast()
        guard parts.count <= 1 else {
            return .extraDash(text: text)
        }
        if let modifiers = parts.first {
            for name in modifiers.split(separator: "+", omittingEmptySubsequences: false).map({
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }) where !modifierNames.contains(name) {
                return .invalidModifier(text: text, name: name)
            }
        }
        guard !isPlausible(key) else { return nil }
        return .unknownKey(text: text, name: key)
    }

    /// A named key, or a single character, which the engine reads from the current keyboard layout
    /// (`generate_virtual_keymap`). The layout gives each key's unshifted character, so an uppercase letter never
    /// matches. Miri cannot see the layout, so it accepts any other single character.
    static func isPlausible(_ key: String) -> Bool {
        (key.count == 1 && key == key.lowercased()) || layoutKeyNames.contains(key) || fixedKeyNames.contains(key)
    }

    static let modifierNames: Set<String> = [
        "alt", "lalt", "ralt", "shift", "lshift", "rshift", "cmd", "lcmd", "rcmd", "ctrl", "lctrl", "rctrl", "fn",
    ]

    /// `virtual_keycode` (config.rs line 1836): keys named by their position on a US keyboard.
    static let layoutKeyNames: Set<String> = [
        "a", "s", "d", "f", "h", "g", "z", "x", "c", "v", "section", "b", "q", "w", "e", "r", "y", "t", "1", "2", "3",
        "4", "6", "5", "equal", "9", "7", "minus", "8", "0", "rightbracket", "o", "u", "leftbracket", "i", "p", "l",
        "j", "quote", "k", "semicolon", "backslash", "comma", "slash", "n", "m", "period", "grave", "keypaddecimal",
        "keypadmultiply", "keypadplus", "keypadclear", "keypaddivide", "keypadenter", "keypadminus", "keypadequals",
        "keypad0", "keypad1", "keypad2", "keypad3", "keypad4", "keypad5", "keypad6", "keypad7", "keypad8", "keypad9",
    ]

    /// `literal_keycode` (config.rs line 1931): keys that every layout places in the same position.
    static let fixedKeyNames: Set<String> = [
        "return", "tab", "space", "delete", "escape", "command", "shift", "capslock", "option", "control",
        "rightcommand", "rightshift", "rightoption", "rightcontrol", "function", "f17", "volumeup", "volumedown",
        "mute", "f18", "f19", "f20", "f5", "f6", "f7", "f3", "f8", "f9", "f11", "f13", "f16", "f14", "f10",
        "contextualmenu", "f12", "f15", "help", "home", "pageup", "forwarddelete", "f4", "end", "f2", "pagedown", "f1",
        "leftarrow", "rightarrow", "downarrow", "uparrow",
    ]
}
