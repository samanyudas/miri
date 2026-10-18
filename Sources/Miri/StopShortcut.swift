import Carbon.HIToolbox
import MiriCore

/// Miri's global shortcuts for Stop window manager. A Carbon hot key needs no Accessibility permission, so they work
/// whether or not the engine is running. The app keeps one instance for its whole life.
final class StopShortcut {
    private let action: () -> Void
    private var hotKeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    /// Replaces the registered shortcuts. A chord with fn, or with a key the layout cannot place, is skipped, because
    /// Carbon hot keys have no fn modifier.
    func register(_ chords: [Chord], layout: KeyLayout) {
        for hotKey in hotKeys { UnregisterEventHotKey(hotKey) }
        hotKeys = []
        guard !chords.isEmpty, installHandler() else { return }
        for (index, chord) in chords.enumerated() {
            guard !chord.modifiers.contains(.function), let keyCode = layout.keyCode(for: chord.key) else { continue }
            let identifier = EventHotKeyID(signature: OSType(0x4D_69_72_69), id: UInt32(index + 1))
            var hotKey: EventHotKeyRef?
            if RegisterEventHotKey(
                UInt32(keyCode), Self.carbonModifiers(chord.modifiers), identifier, GetEventDispatcherTarget(), 0,
                &hotKey) == noErr, let hotKey
            {
                hotKeys.append(hotKey)
            }
        }
    }

    private func installHandler() -> Bool {
        guard handler == nil else { return true }
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
        if status != noErr { handler = nil }
        return status == noErr
    }

    private static func carbonModifiers(_ modifiers: Set<ChordModifier>) -> UInt32 {
        let masks: [(ChordModifier, Int)] = [
            (.control, controlKey), (.option, optionKey), (.command, cmdKey), (.shift, shiftKey),
        ]
        return UInt32(masks.filter { modifiers.contains($0.0) }.reduce(0) { $0 | $1.1 })
    }
}
