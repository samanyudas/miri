import Carbon.HIToolbox
import MiriCore

/// Global shortcuts that Miri handles, rather than sending directly to the engine.
final class ApplicationShortcuts {
    private static let signature = OSType(0x4D_69_72_69)
    private var actions: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var hotKeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    /// Replaces the registered shortcuts. A chord with fn, or with a key the layout cannot place, is skipped, because
    /// Carbon hot keys have no fn modifier.
    func register(_ shortcuts: [(chord: Chord, action: () -> Void)], layout: KeyLayout) {
        for hotKey in hotKeys { UnregisterEventHotKey(hotKey) }
        hotKeys = []
        actions = [:]
        guard !shortcuts.isEmpty, installHandler() else { return }
        for shortcut in shortcuts {
            let chord = shortcut.chord
            guard !chord.modifiers.contains(.function), let keyCode = layout.keyCode(for: chord.key) else { continue }
            let identifier = EventHotKeyID(signature: Self.signature, id: nextID)
            nextID &+= 1
            var hotKey: EventHotKeyRef?
            if RegisterEventHotKey(
                UInt32(keyCode), Self.carbonModifiers(chord.modifiers), identifier, GetEventDispatcherTarget(), 0,
                &hotKey) == noErr, let hotKey
            {
                hotKeys.append(hotKey)
                actions[identifier.id] = shortcut.action
            }
        }
    }

    private func installHandler() -> Bool {
        guard handler == nil else { return true }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, context in
                guard let context, let event else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
                guard status == noErr else { return status }
                // The application event target dispatches on the main thread.
                return MainActor.assumeIsolated {
                    let shortcuts = Unmanaged<ApplicationShortcuts>.fromOpaque(context).takeUnretainedValue()
                    return shortcuts.handle(identifier)
                }
            }, 1, &type, context, &handler)
        if status != noErr { handler = nil }
        return status == noErr
    }

    private func handle(_ identifier: EventHotKeyID) -> OSStatus {
        guard identifier.signature == Self.signature, let action = actions[identifier.id] else {
            return OSStatus(eventNotHandledErr)
        }
        action()
        return noErr
    }

    private static func carbonModifiers(_ modifiers: Set<ChordModifier>) -> UInt32 {
        let masks: [(ChordModifier, Int)] = [
            (.control, controlKey), (.option, optionKey), (.command, cmdKey), (.shift, shiftKey),
        ]
        return UInt32(masks.filter { modifiers.contains($0.0) }.reduce(0) { $0 | $1.1 })
    }
}
