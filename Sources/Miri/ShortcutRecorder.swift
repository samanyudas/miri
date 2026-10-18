import AppKit
import CoreGraphics
import MiriCore

/// Captures the next key press for the Shortcuts page, including chords the engine already binds.
///
/// The engine swallows its bound chords in an event tap at the HID level, so an ordinary app event monitor never sees
/// them. While recording, Miri inserts its own tap at the head of the same location, which runs before the engine's
/// older tap, and swallows key presses so they reach neither the engine nor an app. Without Accessibility permission
/// the tap cannot be created, and Miri falls back to watching its own key events.
final class ShortcutRecorder {
    struct Press {
        let keyCode: UInt16
        /// Control, Option, Shift, and Command. Miri never records fn, because the engine ignores it alongside
        /// other modifiers.
        let modifiers: Set<ChordModifier>
    }

    enum Event {
        case modifiersChanged(Set<ChordModifier>)
        case keyDown(Press)
    }

    private var onEvent: ((Event) -> Void)?
    private var onCancel: (() -> Void)?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var monitor: Any?
    private var resignObserver: NSObjectProtocol?

    var isRecording: Bool { onEvent != nil }

    /// Starts reporting key events. `onCancel` runs when Miri stops recording on its own, such as when another app
    /// becomes active.
    func start(onEvent: @escaping (Event) -> Void, onCancel: @escaping () -> Void) {
        stop()
        self.onEvent = onEvent
        self.onCancel = onCancel
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.cancel() } }
        if !installTap() { installMonitor() }
    }

    /// Tears down the tap or monitor. Safe to call when not recording.
    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        onEvent = nil
        onCancel = nil
    }

    private func cancel() {
        let onCancel = self.onCancel
        stop()
        onCancel?()
    }

    private func installTap() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard
            let tap = CGEvent.tapCreate(
                tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
                callback: { _, type, event, context in
                    guard let context else { return Unmanaged.passUnretained(event) }
                    // The tap's run loop source is on the main run loop.
                    let swallow = MainActor.assumeIsolated {
                        Unmanaged<ShortcutRecorder>.fromOpaque(context).takeUnretainedValue().handle(type, event)
                    }
                    return swallow ? nil : Unmanaged.passUnretained(event)
                }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// Returns whether to swallow the event.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .flagsChanged:
            deliver(.modifiersChanged(Self.modifiers(event.flags)))
            return false
        case .keyDown:
            guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return true }
            let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            deliver(.keyDown(Press(keyCode: keyCode, modifiers: Self.modifiers(event.flags))))
            return true
        case .keyUp:
            return true
        default:
            return false
        }
    }

    /// Reports the event after the tap returns, so a handler that stops recording never tears down a running tap.
    private func deliver(_ event: Event) {
        DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
    }

    private func installMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.isRecording else { return event }
            let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
            if event.type == .flagsChanged {
                self.deliver(.modifiersChanged(Self.modifiers(flags)))
                return event
            }
            if !event.isARepeat {
                self.deliver(.keyDown(Press(keyCode: event.keyCode, modifiers: Self.modifiers(flags))))
            }
            return nil
        }
    }

    private static func modifiers(_ flags: CGEventFlags) -> Set<ChordModifier> {
        let masks: [(ChordModifier, CGEventFlags)] = [
            (.control, .maskControl), (.option, .maskAlternate), (.shift, .maskShift), (.command, .maskCommand),
        ]
        return Set(masks.filter { flags.contains($0.1) }.map(\.0))
    }
}
