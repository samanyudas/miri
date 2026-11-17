import CoreGraphics

/// Keeps a resized window at least its minimum size.
///
/// macOS applies a window's minimum size only when the user drags the window's edge.
/// A resize through Accessibility, such as one from the engine or another window tool, can set any size.
public enum WindowSizeLimits {
    /// The frame grown to at least `minimum`, with the left and top edges where `frame` puts them.
    /// The frame uses AppKit coordinates, where y grows upward, so the top edge is `maxY`.
    public static func frame(_ frame: CGRect, minimum: CGSize) -> CGRect {
        let width = max(frame.width, minimum.width)
        let height = max(frame.height, minimum.height)
        return CGRect(x: frame.minX, y: frame.maxY - height, width: width, height: height)
    }
}
