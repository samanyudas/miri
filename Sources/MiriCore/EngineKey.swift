import Foundation

/// The engine's reading of a chord's text, such as `ctrl+alt-leftarrow`, so Miri can report a chord it cannot read.
///
/// The engine splits the text on `-` and trims each part (`vendor/paneru/src/config.rs` line 1379), reads the
/// modifiers with `parse_modifiers` (line 1736), and looks the key up with `keycode_for_key_name` (line 1718).
/// Names are case-sensitive. `scripts/check-compat.py` checks the tables below against the engine's.
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

    /// Unicode White_Space, which Rust's `str::trim` uses instead of Foundation's broader whitespace set.
    static let whitespace = CharacterSet(
        charactersIn: "\u{0009}\u{000A}\u{000B}\u{000C}\u{000D}\u{0020}\u{0085}\u{00A0}\u{1680}"
            + "\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200A}"
            + "\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}")

    static func problem(in text: String, layout: KeyLayout = .positional) -> Problem? {
        var parts = text.unicodeScalars.split(separator: "-", omittingEmptySubsequences: false).map {
            String($0).trimmingCharacters(in: whitespace)
        }
        let key = parts.removeLast()
        guard parts.count <= 1 else {
            return .extraDash(text: text)
        }
        if let modifiers = parts.first {
            for name in modifiers.unicodeScalars.split(separator: "+", omittingEmptySubsequences: false).map({
                String($0).trimmingCharacters(in: whitespace)
            }) where !modifierNames.contains(name) {
                return .invalidModifier(text: text, name: name)
            }
        }
        guard layout.keyCode(for: key) == nil else { return nil }
        return .unknownKey(text: text, name: key)
    }

    static let modifierNames: Set<String> = [
        "alt", "lalt", "ralt", "shift", "lshift", "rshift", "cmd", "lcmd", "rcmd", "ctrl", "lctrl", "rctrl", "fn",
    ]

    /// `virtual_keycode` (config.rs line 1836): keys named by their position on a US keyboard, in the engine's order,
    /// which is also the order it reads the layout's characters in.
    static let layoutKeys: [(name: String, code: UInt16)] = [
        ("a", 0x00), ("s", 0x01), ("d", 0x02), ("f", 0x03), ("h", 0x04), ("g", 0x05), ("z", 0x06), ("x", 0x07),
        ("c", 0x08), ("v", 0x09), ("section", 0x0a), ("b", 0x0b), ("q", 0x0c), ("w", 0x0d), ("e", 0x0e), ("r", 0x0f),
        ("y", 0x10), ("t", 0x11), ("1", 0x12), ("2", 0x13), ("3", 0x14), ("4", 0x15), ("6", 0x16), ("5", 0x17),
        ("equal", 0x18), ("9", 0x19), ("7", 0x1a), ("minus", 0x1b), ("8", 0x1c), ("0", 0x1d), ("rightbracket", 0x1e),
        ("o", 0x1f), ("u", 0x20), ("leftbracket", 0x21), ("i", 0x22), ("p", 0x23), ("l", 0x25), ("j", 0x26),
        ("quote", 0x27), ("k", 0x28), ("semicolon", 0x29), ("backslash", 0x2a), ("comma", 0x2b), ("slash", 0x2c),
        ("n", 0x2d), ("m", 0x2e), ("period", 0x2f), ("grave", 0x32), ("keypaddecimal", 0x41), ("keypadmultiply", 0x43),
        ("keypadplus", 0x45), ("keypadclear", 0x47), ("keypaddivide", 0x4b), ("keypadenter", 0x4c),
        ("keypadminus", 0x4e), ("keypadequals", 0x51), ("keypad0", 0x52), ("keypad1", 0x53), ("keypad2", 0x54),
        ("keypad3", 0x55), ("keypad4", 0x56), ("keypad5", 0x57), ("keypad6", 0x58), ("keypad7", 0x59),
        ("keypad8", 0x5b), ("keypad9", 0x5c),
    ]

    /// `literal_keycode` (config.rs line 1931): keys that every layout places in the same position.
    static let literalKeys: [(name: String, code: UInt16)] = [
        ("return", 0x24), ("tab", 0x30), ("space", 0x31), ("delete", 0x33), ("escape", 0x35), ("command", 0x37),
        ("shift", 0x38), ("capslock", 0x39), ("option", 0x3a), ("control", 0x3b), ("rightcommand", 0x36),
        ("rightshift", 0x3c), ("rightoption", 0x3d), ("rightcontrol", 0x3e), ("function", 0x3f), ("f17", 0x40),
        ("volumeup", 0x48), ("volumedown", 0x49), ("mute", 0x4a), ("f18", 0x4f), ("f19", 0x50), ("f20", 0x5a),
        ("f5", 0x60), ("f6", 0x61), ("f7", 0x62), ("f3", 0x63), ("f8", 0x64), ("f9", 0x65), ("f11", 0x67),
        ("f13", 0x69), ("f16", 0x6a), ("f14", 0x6b), ("f10", 0x6d), ("contextualmenu", 0x6e), ("f12", 0x6f),
        ("f15", 0x71), ("help", 0x72), ("home", 0x73), ("pageup", 0x74), ("forwarddelete", 0x75), ("f4", 0x76),
        ("end", 0x77), ("f2", 0x78), ("pagedown", 0x79), ("f1", 0x7a), ("leftarrow", 0x7b), ("rightarrow", 0x7c),
        ("downarrow", 0x7d), ("uparrow", 0x7e),
    ]
}
