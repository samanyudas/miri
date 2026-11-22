/// Screen Recording permission, which the engine needs to show pictures of windows: on edges next to another display,
/// and while the strip slides.
public protocol ScreenRecordingAccess {
    /// Whether Miri has the permission. Reading it never shows a prompt.
    var isGranted: Bool { get }
    /// Shows the macOS prompt when Miri lacks the permission, and returns whether Miri has it now.
    func request() -> Bool
}

extension ScreenRecordingAccess {
    /// The value to save for a switch that needs the permission when the user sets it to `wanted`. Only turning it on
    /// prompts.
    public func switchValue(wanting wanted: Bool) -> Bool {
        wanted && request()
    }

    /// Whether a switch saved as `on` must turn off, because the permission is gone. It never prompts.
    public func revokes(_ on: Bool) -> Bool {
        on && !isGranted
    }
}
