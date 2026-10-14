import CoreGraphics

/// Decides where to move windows that ended up out of view, so no window stays stranded after the engine stops.
///
/// All rectangles use the Accessibility coordinate space: the origin is the top-left of the main display and y grows
/// downward.
public enum WindowRecovery {
    /// A window counts as reachable when at least this fraction of it is on a display.
    public static let visibleFraction = 0.5
    /// Recovered windows are at most this fraction of the visible display area, like the engine's own exit cleanup.
    public static let maximumFraction = 0.9

    /// Returns the frame a window should move to, or `nil` when it is already reachable.
    /// - Parameters:
    ///   - window: The window's current frame.
    ///   - displays: Each display's visible frame, without the menu bar and Dock. The first is the main display.
    public static func target(for window: CGRect, displays: [CGRect]) -> CGRect? {
        guard !displays.isEmpty, window.width > 0, window.height > 0 else { return nil }
        let visible = displays.reduce(0) { $0 + area(window.intersection($1)) }
        if visible >= area(window) * visibleFraction { return nil }
        let center = CGPoint(x: window.midX, y: window.midY)
        let display =
            displays.first { $0.contains(center) }
            ?? displays.max { area(window.intersection($0)) < area(window.intersection($1)) }
            .flatMap { area(window.intersection($0)) > 0 ? $0 : nil }
            ?? displays[0]
        let size = CGSize(
            width: min(window.width, (display.width * maximumFraction).rounded(.down)),
            height: min(window.height, (display.height * maximumFraction).rounded(.down)))
        return CGRect(
            x: (display.midX - size.width / 2).rounded(), y: (display.midY - size.height / 2).rounded(),
            width: size.width, height: size.height)
    }

    private static func area(_ rect: CGRect) -> Double {
        rect.isNull ? 0 : Double(rect.width * rect.height)
    }
}
