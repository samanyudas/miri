import Foundation

/// A macOS or standard app shortcut that a Miri shortcut on the same keys would take over.
public struct SystemShortcut: Equatable, Sendable {
    public let name: String
    public let modifiers: Set<ChordModifier>
    public let keyCode: UInt16
}

/// The macOS shortcuts Miri warns about: the user's enabled shortcuts from System Settings > Keyboard > Keyboard
/// Shortcuts, read over the defaults for the ones the user never changed, plus standard app shortcuts.
public struct SystemShortcuts: Sendable {
    public let shortcuts: [SystemShortcut]

    /// Reads the live shortcuts. `com.apple.symbolichotkeys` holds only the entries the user or macOS changed.
    public static func load(layout: KeyLayout) -> SystemShortcuts {
        let entries = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys")
        return parse(symbolicHotKeys: entries ?? [:], layout: layout)
    }

    /// Merges `AppleSymbolicHotKeys` entries over the built-in defaults. Each entry has `enabled` and
    /// `value.parameters`, which is `[character, keyCode, modifierMask]`.
    public static func parse(symbolicHotKeys: [String: Any], layout: KeyLayout) -> SystemShortcuts {
        var result: [SystemShortcut] = []
        var seen = Set<Int>()
        for hotKey in defaults {
            seen.insert(hotKey.id)
            let entry = symbolicHotKeys[String(hotKey.id)] as? [String: Any]
            let enabled = entry.flatMap(isEnabled) ?? hotKey.enabledByDefault
            guard enabled else { continue }
            if let entry, let parsed = shortcut(in: entry, name: hotKey.name) {
                result.append(parsed)
            } else if entry.flatMap(parameters) == nil {
                result.append(SystemShortcut(name: hotKey.name, modifiers: hotKey.modifiers, keyCode: hotKey.keyCode))
            }
        }
        for (key, value) in symbolicHotKeys.sorted(by: { $0.key < $1.key }) {
            guard let id = Int(key), !seen.contains(id), let entry = value as? [String: Any],
                isEnabled(entry) == true,
                let parsed = shortcut(in: entry, name: "a shortcut in System Settings > Keyboard > Keyboard Shortcuts")
            else { continue }
            result.append(parsed)
        }
        for app in appShortcuts {
            guard let keyCode = layout.keyCode(for: app.key) else { continue }
            result.append(SystemShortcut(name: app.name, modifiers: app.modifiers, keyCode: keyCode))
        }
        return SystemShortcuts(shortcuts: result)
    }

    public func conflict(for chord: Chord, layout: KeyLayout) -> SystemShortcut? {
        guard let keyCode = layout.keyCode(for: chord.key) else { return nil }
        return shortcuts.first { $0.modifiers == chord.modifiers && $0.keyCode == keyCode }
    }

    private static func isEnabled(_ entry: [String: Any]) -> Bool? {
        (entry["enabled"] as? NSNumber)?.boolValue
    }

    private static func parameters(_ entry: [String: Any]) -> [Int]? {
        guard let value = entry["value"] as? [String: Any], let items = value["parameters"] as? [NSNumber],
            items.count >= 3
        else { return nil }
        return items.map(\.intValue)
    }

    /// The entry's shortcut, or `nil` when it has no parameters or names no key.
    private static func shortcut(in entry: [String: Any], name: String) -> SystemShortcut? {
        guard let parameters = parameters(entry), parameters[1] != noKey, let keyCode = UInt16(exactly: parameters[1])
        else { return nil }
        var modifiers = Set<ChordModifier>()
        for (modifier, mask) in masks where parameters[2] & mask != 0 {
            modifiers.insert(modifier)
        }
        // macOS sets fn on these keys whether or not the user holds it.
        if functionKeyCodes.contains(keyCode) { modifiers.remove(.function) }
        return SystemShortcut(name: name, modifiers: modifiers, keyCode: keyCode)
    }

    private static let noKey = 65_535

    private static let masks: [(ChordModifier, Int)] = [
        (.shift, 0x2_0000), (.control, 0x4_0000), (.option, 0x8_0000), (.command, 0x10_0000), (.function, 0x80_0000),
    ]

    /// Arrows, F1 to F20, Home, End, Page Up, Page Down, and Forward Delete.
    private static let functionKeyCodes: Set<UInt16> = Set(
        EngineKey.literalKeys.filter { key in
            key.name.hasSuffix("arrow") || ["home", "end", "pageup", "pagedown", "forwarddelete"].contains(key.name)
                || (key.name.first == "f" && Int(key.name.dropFirst()) != nil)
        }.map(\.code))

    private struct HotKey {
        let id: Int
        let name: String
        let modifiers: Set<ChordModifier>
        let keyCode: UInt16
        let enabledByDefault: Bool

        init(_ id: Int, _ name: String, _ modifiers: Set<ChordModifier>, _ keyCode: UInt16, enabled: Bool = true) {
            self.id = id
            self.name = name
            self.modifiers = modifiers
            self.keyCode = keyCode
            enabledByDefault = enabled
        }
    }

    /// The macOS 27 defaults for the symbolic hot keys a Miri shortcut is likely to meet.
    private static let defaults: [HotKey] =
        [
            HotKey(7, "Move focus to the menu bar", [.control], 120),
            HotKey(8, "Move focus to the Dock", [.control], 99),
            HotKey(27, "Move focus to next window", [.command], 50),
            HotKey(28, "Save picture of screen as a file", [.shift, .command], 20),
            HotKey(29, "Copy picture of screen", [.control, .shift, .command], 20),
            HotKey(30, "Save picture of selected area", [.shift, .command], 21),
            HotKey(31, "Copy picture of selected area", [.control, .shift, .command], 21),
            HotKey(32, "Mission Control", [.control], 126),
            HotKey(33, "Application windows", [.control], 125),
            HotKey(36, "Show Desktop", [], 103),
            HotKey(52, "Turn Dock hiding on or off", [.option, .command], 2),
            HotKey(60, "Select the previous input source", [.control], 49),
            HotKey(61, "Select next source in Input menu", [.control, .option], 49),
            HotKey(64, "Show Spotlight search", [.command], 49),
            HotKey(65, "Show Finder search window", [.option, .command], 49),
            HotKey(79, "Move left a space", [.control], 123),
            HotKey(81, "Move right a space", [.control], 124),
        ]
        + zip(1...9, [18, 19, 20, 21, 23, 22, 26, 28, 25] as [UInt16]).map { number, keyCode in
            HotKey(117 + number, "Switch to Desktop \(number)", [.control], keyCode, enabled: false)
        }
        + [HotKey(184, "Screenshot and recording options", [.shift, .command], 23)]

    /// Standard app shortcuts, with keys named as the engine names them so they follow the layout.
    private static let appShortcuts: [(name: String, modifiers: Set<ChordModifier>, key: String)] = [
        ("Quit the frontmost app", [.command], "q"),
        ("Close window", [.command], "w"),
        ("Hide app", [.command], "h"),
        ("Hide other apps", [.option, .command], "h"),
        ("Minimize window", [.command], "m"),
        ("App switcher", [.command], "tab"),
        ("App switcher", [.shift, .command], "tab"),
        ("App settings", [.command], ","),
        ("Force Quit", [.option, .command], "escape"),
        ("Lock Screen", [.control, .command], "q"),
        ("Full screen", [.control, .command], "f"),
        ("Emoji and Symbols", [.control, .command], "space"),
        ("Copy", [.command], "c"),
        ("Paste", [.command], "v"),
        ("Cut", [.command], "x"),
        ("Undo", [.command], "z"),
        ("Select all", [.command], "a"),
        ("Save", [.command], "s"),
        ("New", [.command], "n"),
        ("New tab", [.command], "t"),
        ("Find", [.command], "f"),
        ("Print", [.command], "p"),
        ("Open", [.command], "o"),
    ]
}
