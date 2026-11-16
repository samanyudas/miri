import CoreGraphics

/// Keeps a resized window within its size limits.
///
/// macOS applies a window's minimum and maximum size only when the user drags the window's edge.
/// A resize through Accessibility, such as one from the engine or another window tool, can set any size.
public enum WindowSizeLimits {
    /// The frame limited to `minimum` and `maximum`, with the left and top edges where `frame` puts them.
    /// The frame uses AppKit coordinates, where y grows upward, so the top edge is `maxY`.
    public static func frame(_ frame: CGRect, minimum: CGSize, maximum: CGSize) -> CGRect {
        let width = min(max(frame.width, minimum.width), maximum.width)
        let height = min(max(frame.height, minimum.height), maximum.height)
        return CGRect(x: frame.minX, y: frame.maxY - height, width: width, height: height)
    }
}
