import Carbon.HIToolbox
import MiriCore

/// Miri's global ⌃⌥Q shortcut for Stop window manager. A Carbon hot key needs no Accessibility permission, so it works
/// whether or not the engine is running. The app keeps one for its whole life.
final class StopShortcut {
    private let action: () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    /// Registers the shortcut, or removes it so that a `[bindings]` entry on the same chord reaches the engine.
    func setEnabled(_ enabled: Bool) {
        if enabled, hotKey == nil {
            register()
        } else if !enabled, let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
            if let handler { RemoveEventHandler(handler) }
            handler = nil
        }
    }

    private func register() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                // The application event target dispatches on the main thread.
                MainActor.assumeIsolated { Unmanaged<StopShortcut>.fromOpaque(context).takeUnretainedValue().action() }
                return noErr
            }, 1, &type, context, &handler)
        guard status == noErr else { return }
        let identifier = EventHotKeyID(signature: OSType(0x4D_69_72_69), id: 1)  // "Miri"
        let modifiers = UInt32(controlKey | optionKey)
        if RegisterEventHotKey(
            UInt32(Self.keyCode(for: DefaultBinding.stopChord.key)), modifiers, identifier,
            GetEventDispatcherTarget(), 0, &hotKey) != noErr
        {
            hotKey = nil
            if let handler { RemoveEventHandler(handler) }
            handler = nil
        }
    }

    /// The key that types `character` in the current keyboard layout, as the engine reads a one-letter key name,
    /// so the shortcut follows AZERTY and other layouts. Falls back to the US position.
    static func keyCode(for character: String) -> Int {
        let fallback = kVK_ANSI_Q
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return fallback }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return data.withUnsafeBytes { bytes -> Int in
            guard let layout = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return fallback }
            for code in 0..<128 {
                var deadKeys: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, UInt16(code), UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters)
                if status == noErr, String(utf16CodeUnits: characters, count: length) == character { return code }
            }
            return fallback
        }
    }
}
