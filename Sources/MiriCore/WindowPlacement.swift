import CoreGraphics

/// Keeps Miri's own windows within a display's visible area when shown.
///
/// All rectangles use AppKit coordinates, where y grows upward.
public enum WindowPlacement {
    /// Returns `frame` shifted into `visibleArea`, shrinking only if `frame` is larger than `visibleArea`.
    /// A frame that already fits inside `visibleArea` is returned unchanged.
    public static func fitted(_ frame: CGRect, in visibleArea: CGRect) -> CGRect {
        guard visibleArea.width > 0, visibleArea.height > 0 else { return frame }
        let width = min(frame.width, visibleArea.width)
        let height = min(frame.height, visibleArea.height)
        let x = min(max(frame.minX, visibleArea.minX), visibleArea.maxX - width)
        let y = min(max(frame.minY, visibleArea.minY), visibleArea.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
