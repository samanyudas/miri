import CoreGraphics

/// Keeps Miri's own windows visible and at least their minimum size.
///
/// All rectangles use AppKit coordinates, where y grows upward.
public enum WindowPlacement {
    public static func fitted(_ frame: CGRect, in visibleArea: CGRect) -> CGRect {
        guard visibleArea.width > 0, visibleArea.height > 0 else { return frame }
        let width = min(frame.width, visibleArea.width)
        let height = min(frame.height, visibleArea.height)
        let x = min(max(frame.minX, visibleArea.minX), visibleArea.maxX - width)
        let y = min(max(frame.minY, visibleArea.minY), visibleArea.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// macOS applies a window's minimum size only when the user drags its edge; an Accessibility resize can set any size.
    /// Keeps the left and top edges fixed (`maxY` is the top edge in AppKit coordinates).
    public static func enforcingMinimum(_ frame: CGRect, minimum: CGSize) -> CGRect {
        let width = max(frame.width, minimum.width)
        let height = max(frame.height, minimum.height)
        return CGRect(x: frame.minX, y: frame.maxY - height, width: width, height: height)
    }
}
