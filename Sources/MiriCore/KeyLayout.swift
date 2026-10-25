import Carbon.HIToolbox
import Foundation

/// A keyboard layout as the engine reads it, so Miri resolves a key name to the same physical key the engine does.
///
/// The engine translates each key in its US-position table with no modifiers (`generate_virtual_keymap`,
/// `vendor/paneru/src/config.rs` line 2003) and reads the layout once when it starts. On AZERTY, `a` therefore names
/// the key at the US Q position, while `minus` always names the US minus position.
public struct KeyLayout: Equatable, Sendable {
    struct Key: Equatable, Sendable {
        let code: UInt16
        let character: String
    }

    /// The unshifted character of each translatable key, in the engine's table order.
    let keys: [Key]

    init(keys: [Key]) {
        self.keys = keys
    }

    /// Names keys only by their US position and fixed names, as the engine does when it cannot read the layout.
    public static let positional = KeyLayout(keys: [])

    /// The current ASCII-capable layout. Without one, the engine falls back to US-position names, and so does this.
    /// HIToolbox aborts when two threads call the input source API at once, so every caller is on the main actor.
    @MainActor public static var current: KeyLayout {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return positional
        }
        return KeyLayout(source: source) ?? positional
    }

    /// An installed layout, such as `com.apple.keylayout.French`, whether or not the user enabled it.
    @MainActor public init?(inputSourceID: String) {
        let filter = [kTISPropertyInputSourceID as String: inputSourceID] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
            let source = list.first
        else { return nil }
        self.init(source: source)
    }

    @MainActor private init?(source: TISInputSource) {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        let keys = data.withUnsafeBytes { bytes -> [Key]? in
            guard let layout = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            var deadKeyState: UInt32 = 0
            var characters = [UniChar](repeating: 0, count: 256)
            return EngineKey.layoutKeys.compactMap { entry in
                var length = 0
                let status = UCKeyTranslate(
                    layout, entry.code, UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, characters.count, &length, &characters)
                guard status == noErr else { return nil }
                return Key(code: entry.code, character: String(utf16CodeUnits: characters, count: length))
            }
        }
        guard let keys else { return nil }
        self.init(keys: keys)
    }

    /// The key the engine binds for `name`: the layout's character first, then the US position, then a fixed key.
    public func keyCode(for name: String) -> UInt16? {
        // Rust compares UTF-8 bytes, whereas Swift String equality also accepts canonical Unicode equivalents.
        keys.first { $0.character.utf8.elementsEqual(name.utf8) }?.code
            ?? EngineKey.layoutKeys.first { $0.name == name }?.code
            ?? EngineKey.literalKeys.first { $0.name == name }?.code
    }

    /// The name Miri writes for a pressed key, which the engine reads back as the same key. Returns `nil` for a key
    /// no name reaches, such as one whose only character is shadowed by an earlier key.
    public func name(for keyCode: UInt16) -> String? {
        if let literal = EngineKey.literalKeys.first(where: { $0.code == keyCode }) { return literal.name }
        // A dash would split the chord text, and the engine trims whitespace from the key name.
        if let character = keys.first(where: { $0.code == keyCode })?.character, character.count == 1,
            character == character.lowercased(), character != "-", Self.isPrintable(character),
            self.keyCode(for: character) == keyCode
        {
            return character
        }
        if let position = EngineKey.layoutKeys.first(where: { $0.code == keyCode }),
            self.keyCode(for: position.name) == keyCode
        {
            return position.name
        }
        return nil
    }

    /// Whether two chords press the same keys under this layout, such as `=` and `equal` on a US layout.
    public func conflicts(_ first: Chord, _ second: Chord) -> Bool {
        guard first.modifiers == second.modifiers else { return false }
        guard let firstCode = keyCode(for: first.key), let secondCode = keyCode(for: second.key) else {
            return first.key == second.key
        }
        return firstCode == secondCode
    }

    /// The chord as macOS menus show it, such as `⌃⌥←` or `⌃⌥⇧H`.
    public func label(for chord: Chord) -> String {
        Self.label(for: chord.modifiers) + keyLabel(chord.key)
    }

    /// Modifiers in the order macOS menus show them, such as `⌃⌥⇧⌘`.
    public static func label(for modifiers: Set<ChordModifier>) -> String {
        let symbols: [(ChordModifier, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return (modifiers.contains(.function) ? "fn" : "")
            + symbols.filter { modifiers.contains($0.0) }.map(\.1).joined()
    }

    private func keyLabel(_ name: String) -> String {
        if let symbol = Self.keySymbols[name] { return symbol }
        if name.count >= 2, name.first == "f", let number = Int(name.dropFirst()), (1...20).contains(number) {
            return name.uppercased()
        }
        if let code = keyCode(for: name), let character = keys.first(where: { $0.code == code })?.character,
            Self.isPrintable(character)
        {
            // On AZERTY the digit names reach the keypad, because the top row types symbols without Shift.
            let isKeypad = EngineKey.layoutKeys.contains { $0.code == code && $0.name.hasPrefix("keypad") }
            return (isKeypad ? "Keypad " : "") + character.uppercased()
        }
        return name
    }

    /// Keypad Enter and Clear translate to control characters, which neither a file nor a label should show.
    private static func isPrintable(_ character: String) -> Bool {
        !character.isEmpty
            && !character.unicodeScalars.contains {
                EngineKey.whitespace.contains($0) || $0.properties.generalCategory == .control
            }
    }

    private static let keySymbols = [
        "leftarrow": "←", "rightarrow": "→", "uparrow": "↑", "downarrow": "↓", "return": "↩", "tab": "⇥",
        "space": "Space", "delete": "⌫", "escape": "⎋", "forwarddelete": "⌦", "home": "↖", "end": "↘",
        "pageup": "⇞", "pagedown": "⇟",
    ]
}
