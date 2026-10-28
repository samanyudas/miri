/// Screen Recording permission, which the engine needs to show window contents on edges next to another display.
public protocol ScreenRecordingAccess {
    /// Whether Miri has the permission. Reading it never shows a prompt.
    var isGranted: Bool { get }
    /// Shows the macOS prompt when Miri lacks the permission, and returns whether Miri has it now.
    func request() -> Bool
}

extension ScreenRecordingAccess {
    /// The `sharedEdgeSlices` value to save when the user sets the switch to `wanted`. Only turning it on prompts.
    public func sharedEdgeSlices(wanting wanted: Bool) -> Bool {
        wanted && request()
    }

    /// Whether a switch saved as on must turn off, because the permission is gone. It never prompts.
    public func revokes(sharedEdgeSlices: Bool) -> Bool {
        sharedEdgeSlices && !isGranted
    }
}
