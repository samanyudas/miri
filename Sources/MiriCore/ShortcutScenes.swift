import CoreGraphics
import Foundation

/// A drawing of one moment on the displays: which windows sit in which columns, and which window has focus.
/// The Shortcuts settings page draws a before and an after sketch for each action (#351).
public struct StripSketch: Equatable, Sendable {
    public var displays: [SketchDisplay]
    public var focused: String?
    /// False after Stop, when Miri no longer arranges the windows.
    public var managed = true

    public init(_ displays: [SketchDisplay], focused: String?, managed: Bool = true) {
        self.displays = displays
        self.focused = focused
        self.managed = managed
    }

    /// Every window in the sketch, tiled or floating.
    public var windows: [String] {
        displays.flatMap { $0.columns.flatMap(\.windows) + $0.floating }
    }

    /// Where a window sits: its display, its column, and its place in the column. A floating window has no column.
    public func place(of window: String) -> (display: Int, column: Int?, row: Int)? {
        for (displayIndex, display) in displays.enumerated() {
            for (columnIndex, column) in display.columns.enumerated() {
                if let row = column.windows.firstIndex(of: window) { return (displayIndex, columnIndex, row) }
            }
            if display.floating.contains(window) { return (displayIndex, nil, 0) }
        }
        return nil
    }
}

/// One display in a sketch, with its strip of columns.
public struct SketchDisplay: Equatable, Sendable {
    /// The display's place in the arrangement, in whole displays, as in System Settings > Displays.
    public var position: (x: Int, y: Int)
    public var columns: [SketchColumn]
    public var floating: [String]
    /// How far the strip has scrolled, as a fraction of the display width. A negative value shows later columns.
    public var offset: Double

    public init(
        at position: (x: Int, y: Int) = (0, 0), _ columns: [SketchColumn], floating: [String] = [],
        offset: Double = 0
    ) {
        self.position = position
        self.columns = columns
        self.floating = floating
        self.offset = offset
    }

    public static func == (lhs: SketchDisplay, rhs: SketchDisplay) -> Bool {
        lhs.position == rhs.position && lhs.columns == rhs.columns && lhs.floating == rhs.floating
            && lhs.offset == rhs.offset
    }
}

/// A column: one window, or a stack of windows from top to bottom.
public struct SketchColumn: Equatable, Sendable {
    public var windows: [String]
    /// The column's width as a fraction of the display width.
    public var width: Double
    /// Each window's share of the column height, from the top. Nil means equal shares.
    public var heights: [Double]?

    public init(_ windows: String..., width: Double = 0.28, heights: [Double]? = nil) {
        self.windows = windows
        self.width = width
        self.heights = heights
    }
}

/// What one shortcut does, as a before and after sketch with a caption that says what moves, where, and what stays.
public struct ShortcutScene: Equatable, Sendable {
    public let before: StripSketch
    public let after: StripSketch
    public let caption: String
}

/// Where each display and window of a sketch is drawn, in points.
public struct SketchLayout: Equatable, Sendable {
    public var displays: [CGRect]
    public var windows: [String: CGRect]
}

extension StripSketch {
    /// The gap between columns, and between a column and the display edge, as a fraction of the display width.
    static let gap = 0.03
    /// A display's height for a width of 1, as on a 16:10 display.
    static let displayAspect = 0.625

    /// Places the displays and windows in a box of `size`, keeping the displays' shape.
    /// A window outside its display is cut to the display's edge, so a scrolled strip shows only what is on screen.
    /// `frame` is the arrangement of both sketches of a scene, so the before and after sketches use one scale.
    public func layout(in size: CGSize, arrangement frame: StripSketch? = nil) -> SketchLayout {
        let reference = frame ?? self
        let columns = (reference.displays.map(\.position.x).max() ?? 0) + 1
        let rows = (reference.displays.map(\.position.y).max() ?? 0) + 1
        let spacing = 4.0
        let unit = min(
            (size.width - spacing * Double(columns - 1)) / Double(columns),
            (size.height - spacing * Double(rows - 1)) / (Double(rows) * Self.displayAspect))
        let displayHeight = unit * Self.displayAspect
        let used = CGSize(
            width: unit * Double(columns) + spacing * Double(columns - 1),
            height: displayHeight * Double(rows) + spacing * Double(rows - 1))
        let origin = CGPoint(x: (size.width - used.width) / 2, y: (size.height - used.height) / 2)
        var result = SketchLayout(displays: [], windows: [:])
        for display in displays {
            let box = CGRect(
                x: origin.x + Double(display.position.x) * (unit + spacing),
                y: origin.y + Double(display.position.y) * (displayHeight + spacing),
                width: unit, height: displayHeight)
            result.displays.append(box)
            let inset = Self.gap * unit
            var x = box.minX + (display.offset + Self.gap) * unit
            for column in display.columns {
                let width = column.width * unit
                let shares =
                    column.heights ?? Array(repeating: 1 / Double(column.windows.count), count: column.windows.count)
                var y = box.minY + inset
                let height = box.height - 2 * inset - inset * Double(column.windows.count - 1)
                for (window, share) in zip(column.windows, shares) {
                    let rect = CGRect(x: x, y: y, width: width, height: height * share)
                    result.windows[window] =
                        rect.intersection(box).isNull ? clamped(rect, to: box) : rect.intersection(box)
                    y += height * share + inset
                }
                x += width + inset
            }
            for (index, window) in display.floating.enumerated() {
                let size = CGSize(width: box.width * 0.42, height: box.height * 0.55)
                result.windows[window] = CGRect(
                    x: box.midX - size.width / 2 + Double(index) * inset,
                    y: box.midY - size.height / 2 + Double(index) * inset,
                    width: size.width, height: size.height)
            }
        }
        return result
    }

    /// A zero-width rectangle at the display edge nearest a window that lies wholly outside it.
    private func clamped(_ rect: CGRect, to box: CGRect) -> CGRect {
        let x = rect.maxX <= box.minX ? box.minX : box.maxX
        return CGRect(x: x, y: max(rect.minY, box.minY), width: 0, height: min(rect.height, box.height))
    }
}
