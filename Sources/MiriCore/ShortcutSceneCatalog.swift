import Foundation

extension ShortcutAction {
    /// The before and after sketch of what this action does, as `decisions/keybinding reference.md` describes it.
    /// `ShortcutSceneTests` fails when an action in Settings has none.
    public var scene: ShortcutScene? {
        switch self {
        case .stop: Scenes.stop
        // Settings names an action by the engine's canonical command, and the scenes use the default table's spelling.
        case .engine(let command): Scenes.forCommand(DefaultBinding.row(for: command)?.command ?? command)
        }
    }
}

/// The scenes, by engine command. Window names are letters, and only the focused window is drawn in color.
private enum Scenes {
    typealias Column = SketchColumn
    typealias Display = SketchDisplay

    static func strip(_ columns: Column..., focused: String, offset: Double = 0) -> StripSketch {
        StripSketch([Display(columns, offset: offset)], focused: focused)
    }

    static func scene(_ before: StripSketch, _ after: StripSketch, _ caption: String) -> ShortcutScene {
        ShortcutScene(before: before, after: after, caption: caption)
    }

    /// Two displays, `first` to the left of or above `second`.
    static func pair(_ first: [Column], _ second: [Column], focused: String, vertical: Bool = false) -> StripSketch {
        StripSketch([Display(at: (0, 0), first), Display(at: vertical ? (0, 1) : (1, 0), second)], focused: focused)
    }

    static func forCommand(_ command: String) -> ShortcutScene? {
        let three = [Column("a"), Column("b"), Column("c")]
        switch command {
        case "window_focus_west":
            return scene(
                StripSketch([Display(three)], focused: "b"), StripSketch([Display(three)], focused: "a"),
                String(localized: "Focus moves to the column on the left. No window moves."))
        case "window_focus_east":
            return scene(
                StripSketch([Display(three)], focused: "b"), StripSketch([Display(three)], focused: "c"),
                String(localized: "Focus moves to the column on the right. No window moves."))
        case "window_focus_north":
            let columns = [Column("a", "b"), Column("c")]
            return scene(
                StripSketch([Display(columns)], focused: "b"), StripSketch([Display(columns)], focused: "a"),
                String(localized: "Focus moves to the window above in the same column. No window moves."))
        case "window_focus_south":
            let columns = [Column("a", "b"), Column("c")]
            return scene(
                StripSketch([Display(columns)], focused: "a"), StripSketch([Display(columns)], focused: "b"),
                String(localized: "Focus moves to the window below in the same column. No window moves."))
        case "window_focus_first":
            let columns = [
                Column("a", width: 0.21), Column("b", width: 0.21), Column("c", width: 0.21), Column("d", width: 0.21),
            ]
            return scene(
                StripSketch([Display(columns)], focused: "c"), StripSketch([Display(columns)], focused: "a"),
                String(localized: "Focus moves to the first column of the strip. No window moves."))
        case "window_focus_last":
            let columns = [
                Column("a", width: 0.21), Column("b", width: 0.21), Column("c", width: 0.21), Column("d", width: 0.21),
            ]
            return scene(
                StripSketch([Display(columns)], focused: "b"), StripSketch([Display(columns)], focused: "d"),
                String(localized: "Focus moves to the last column of the strip. No window moves."))
        case "window_focusdisplay_west":
            let left = [Column("a", width: 0.45), Column("b", width: 0.45)]
            let right = [Column("c", width: 0.45), Column("d", width: 0.45)]
            return scene(
                pair(left, right, focused: "c"), pair(left, right, focused: "b"),
                String(localized: "Focus moves to the display on the left. No window moves."))
        case "window_focusdisplay_east":
            let left = [Column("a", width: 0.45), Column("b", width: 0.45)]
            let right = [Column("c", width: 0.45), Column("d", width: 0.45)]
            return scene(
                pair(left, right, focused: "b"), pair(left, right, focused: "c"),
                String(localized: "Focus moves to the display on the right. No window moves."))
        case "window_focusdisplay_north":
            let top = [Column("a", width: 0.45), Column("b", width: 0.45)]
            let bottom = [Column("c", width: 0.45), Column("d", width: 0.45)]
            return scene(
                pair(top, bottom, focused: "c", vertical: true), pair(top, bottom, focused: "a", vertical: true),
                String(localized: "Focus moves to the display above. No window moves."))
        case "window_focusdisplay_south":
            let top = [Column("a", width: 0.45), Column("b", width: 0.45)]
            let bottom = [Column("c", width: 0.45), Column("d", width: 0.45)]
            return scene(
                pair(top, bottom, focused: "a", vertical: true), pair(top, bottom, focused: "c", vertical: true),
                String(localized: "Focus moves to the display below. No window moves."))
        case "window_swap_west":
            return scene(
                strip(Column("a"), Column("b"), Column("c"), focused: "b"),
                strip(Column("b"), Column("a"), Column("c"), focused: "b"),
                String(localized: "The focused column swaps places with the column on its left. Focus stays on it."))
        case "window_swap_east":
            return scene(
                strip(Column("a"), Column("b"), Column("c"), focused: "b"),
                strip(Column("a"), Column("c"), Column("b"), focused: "b"),
                String(localized: "The focused column swaps places with the column on its right. Focus stays on it."))
        case "window_swap_north":
            return scene(
                strip(Column("a", "b"), Column("c"), focused: "b"),
                strip(Column("b", "a"), Column("c"), focused: "b"),
                String(
                    localized:
                        "The focused window swaps places with the window above it in its column. Focus stays on it."))
        case "window_swap_south":
            return scene(
                strip(Column("a", "b"), Column("c"), focused: "a"),
                strip(Column("b", "a"), Column("c"), focused: "a"),
                String(
                    localized:
                        "The focused window swaps places with the window below it in its column. Focus stays on it."))
        case "window_swap_first":
            return scene(
                strip(
                    Column("a", width: 0.21), Column("b", width: 0.21), Column("c", width: 0.21),
                    Column("d", width: 0.21), focused: "c"),
                strip(
                    Column("c", width: 0.21), Column("a", width: 0.21), Column("b", width: 0.21),
                    Column("d", width: 0.21), focused: "c"),
                String(localized: "The focused column moves to the first position on its display. Focus stays on it."))
        case "window_swap_last":
            return scene(
                strip(
                    Column("a", width: 0.21), Column("b", width: 0.21), Column("c", width: 0.21),
                    Column("d", width: 0.21), focused: "b"),
                strip(
                    Column("a", width: 0.21), Column("c", width: 0.21), Column("d", width: 0.21),
                    Column("b", width: 0.21), focused: "b"),
                String(localized: "The focused column moves to the last position on its display. Focus stays on it."))
        case "window_movedisplay_west":
            return scene(
                pair(
                    [Column("a", width: 0.45), Column("b", width: 0.45)],
                    [Column("c", width: 0.45), Column("d", width: 0.45)], focused: "c"),
                pair(
                    [Column("a", width: 0.29), Column("c", width: 0.29), Column("b", width: 0.29)],
                    [Column("d", width: 0.45)], focused: "c"),
                String(
                    localized:
                        "The focused column moves to the display on the left, after its active column. Focus follows it."
                ))
        case "window_movedisplay_east", "window_nextdisplay":
            let caption =
                command == "window_nextdisplay"
                ? String(
                    localized:
                        "The focused column moves to the next display, after its active column. Focus follows it.")
                : String(
                    localized:
                        "The focused column moves to the display on the right, after its active column. Focus follows it."
                )
            return scene(
                pair(
                    [Column("a", width: 0.45), Column("b", width: 0.45)],
                    [Column("c", width: 0.45), Column("d", width: 0.45)], focused: "b"),
                pair(
                    [Column("a", width: 0.45)],
                    [Column("c", width: 0.29), Column("b", width: 0.29), Column("d", width: 0.29)], focused: "b"),
                caption)
        case "window_movedisplay_north":
            return scene(
                pair(
                    [Column("a", width: 0.45), Column("b", width: 0.45)],
                    [Column("c", width: 0.45), Column("d", width: 0.45)], focused: "d", vertical: true),
                pair(
                    [Column("a", width: 0.29), Column("d", width: 0.29), Column("b", width: 0.29)],
                    [Column("c", width: 0.45)], focused: "d", vertical: true),
                String(
                    localized:
                        "The focused column moves to the display above, after its active column. Focus follows it."))
        case "window_movedisplay_south":
            return scene(
                pair(
                    [Column("a", width: 0.45), Column("b", width: 0.45)],
                    [Column("c", width: 0.45), Column("d", width: 0.45)], focused: "b", vertical: true),
                pair(
                    [Column("a", width: 0.45)],
                    [Column("c", width: 0.29), Column("b", width: 0.29), Column("d", width: 0.29)], focused: "b",
                    vertical: true),
                String(
                    localized:
                        "The focused column moves to the display below, after its active column. Focus follows it."))
        case "window_resize":
            return scene(
                strip(Column("a", width: 0.2), Column("b", width: 0.28), Column("c", width: 0.2), focused: "b"),
                strip(Column("a", width: 0.2), Column("b", width: 0.45), Column("c", width: 0.2), focused: "b"),
                String(
                    localized: "The focused column takes the next preset width. The other columns keep their widths."))
        case "window_step_grow":
            return scene(
                strip(Column("a"), Column("b"), Column("c"), focused: "b"),
                strip(Column("a"), Column("b", width: 0.36), Column("c"), focused: "b"),
                String(localized: "The focused column gets a step wider. The other columns keep their widths."))
        case "window_step_shrink":
            return scene(
                strip(Column("a"), Column("b", width: 0.36), Column("c"), focused: "b"),
                strip(Column("a"), Column("b"), Column("c"), focused: "b"),
                String(localized: "The focused column gets a step narrower. The other columns keep their widths."))
        case "window_maximize":
            return scene(
                strip(Column("a"), Column("b"), Column("c"), focused: "b"),
                strip(Column("a"), Column("b", width: 0.94), Column("c"), focused: "b", offset: -0.31),
                String(
                    localized: "The focused window becomes as wide as the display. Press again to restore its width."))
        case "window_center":
            let columns = [
                Column("a", width: 0.35), Column("b", width: 0.35), Column("c", width: 0.35), Column("d", width: 0.35),
            ]
            return scene(
                StripSketch([Display(columns)], focused: "c"),
                StripSketch([Display(columns, offset: -0.465)], focused: "c"),
                String(
                    localized:
                        "The strip slides so the focused column sits in the middle of the display. No column changes size."
                ))
        case "window_vertical_step_grow":
            return scene(
                strip(Column("a", "b"), Column("c"), focused: "a"),
                strip(Column("a", "b", heights: [0.65, 0.35]), Column("c"), focused: "a"),
                String(
                    localized: "The focused window gets a step taller, and the other window in its column gets shorter."
                ))
        case "window_vertical_step_shrink":
            return scene(
                strip(Column("a", "b", heights: [0.65, 0.35]), Column("c"), focused: "a"),
                strip(Column("a", "b"), Column("c"), focused: "a"),
                String(
                    localized: "The focused window gets a step shorter, and the other window in its column gets taller."
                ))
        case "window_equalize":
            return scene(
                strip(Column("a", "b", "c", heights: [0.6, 0.2, 0.2]), Column("d"), focused: "a"),
                strip(Column("a", "b", "c"), Column("d"), focused: "a"),
                String(
                    localized:
                        "Every window in the focused column gets the same height. Other columns stay as they are."))
        case "window_stack_west":
            return scene(
                strip(Column("a"), Column("b", "e"), Column("c"), focused: "b"),
                strip(Column("a", "b"), Column("e"), Column("c"), focused: "b"),
                String(
                    localized:
                        "The focused window joins the column on its left. The rest of its old column stays in place."))
        case "window_stack_east":
            return scene(
                strip(Column("a"), Column("b", "e"), Column("c"), focused: "b"),
                strip(Column("a"), Column("e"), Column("c", "b"), focused: "b"),
                String(
                    localized:
                        "The focused window joins the column on its right. The rest of its old column stays in place."))
        case "window_unstack_east":
            return scene(
                strip(Column("a", "b"), Column("c"), focused: "b"),
                strip(Column("a"), Column("b"), Column("c"), focused: "b"),
                String(
                    localized:
                        "The focused window leaves its stack and becomes its own column on the right. Focus stays on it."
                ))
        case "window_unstack_west":
            return scene(
                strip(Column("a", "b"), Column("c"), focused: "b"),
                strip(Column("b"), Column("a"), Column("c"), focused: "b"),
                String(
                    localized:
                        "The focused window leaves its stack and becomes its own column on the left. Focus stays on it."
                ))
        case "window_manage":
            return scene(
                strip(Column("a"), Column("b"), Column("c"), focused: "b"),
                StripSketch([Display([Column("a"), Column("c")], floating: ["b"])], focused: "b"),
                String(
                    localized:
                        "The focused window floats above the strip, and the other columns close the gap. Press again to tile it."
                ))
        default:
            guard command.hasPrefix("window_focus_"), let number = Int(command.dropFirst("window_focus_".count)),
                (1...9).contains(number)
            else { return nil }
            return jump(to: number)
        }
    }

    /// Jump to column N: a strip of at least three columns, with focus moving to column N.
    static func jump(to number: Int) -> ShortcutScene {
        let count = max(number, 3)
        let width = (1 - StripSketch.gap * Double(count + 1)) / Double(count)
        let names = (0..<count).map { String(UnicodeScalar(UInt8(ascii: "a") + UInt8($0))) }
        let columns = names.map { Column($0, width: width) }
        let start = number == 1 ? names[count - 1] : names[0]
        return scene(
            StripSketch([Display(columns)], focused: start),
            StripSketch([Display(columns)], focused: names[number - 1]),
            String(localized: "Focus moves to column \(number) of the strip. No window moves."))
    }

    static let stop = scene(
        strip(Column("a"), Column("b"), Column("c"), focused: "b"),
        StripSketch([Display([Column("a"), Column("b"), Column("c")])], focused: nil, managed: false),
        String(localized: "Miri stops arranging windows. Every window stays where it is until you start Miri again."))
}
