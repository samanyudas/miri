import CoreGraphics
import Foundation
import Testing

@testable import MiriCore

struct ShortcutSceneTests {
    static let reference = URL(filePath: #filePath).deletingLastPathComponent()
        .appending(path: "../../decisions/keybinding reference.md").standardized

    @Test(arguments: ShortcutAction.editable) func everyActionInSettingsHasAScene(_ action: ShortcutAction) throws {
        let scene = try #require(action.scene, "\(action.title) has no illustration")
        #expect(scene.before != scene.after, "\(action.title) shows no change")
        #expect(!scene.caption.isEmpty)
    }

    @Test func everyCaptionIsDifferent() {
        let captions = ShortcutAction.editable.compactMap(\.scene?.caption)
        #expect(Set(captions).count == captions.count)
    }

    /// Each action in the reference's shortcut tables is listed in Settings and has a scene.
    @Test func everyActionInTheKeybindingReferenceHasAScene() throws {
        let titles = try Self.referenceActions()
        #expect(titles.count >= 40, "the reference tables were not found")
        for title in titles {
            let action = ShortcutAction.editable.first { $0.title == title }
            #expect(action?.scene != nil, "\(title) from the keybinding reference has no illustration")
        }
    }

    /// The scenes follow the rules in the keybinding reference, so an illustration never shows another behavior.
    @Test(arguments: ShortcutAction.editable) func sceneFollowsTheKeybindingReference(_ action: ShortcutAction) throws {
        let scene = try #require(action.scene)
        let (before, after) = (scene.before, scene.after)
        guard case .engine(let command) = action else {
            // Stop leaves every window where it is.
            #expect(before.displays == after.displays && !after.managed)
            return
        }
        let focused = try #require(before.focused)
        let from = try #require(before.place(of: focused))
        let to = try #require(after.place(of: focused == after.focused ? focused : after.focused ?? ""))
        if command.hasPrefix("window_focus") {
            // "These focus commands move no windows."
            #expect(before.displays == after.displays, "\(command) moves a window")
            #expect(before.focused != after.focused, "\(command) does not move focus")
            if command.hasPrefix("window_focusdisplay") { #expect(from.display != to.display) }
            return
        }
        // Every other action acts on the focused window or column, which keeps focus.
        #expect(after.focused == focused, "\(command) moves focus away from the window it acts on")
        #expect(Set(before.windows) == Set(after.windows), "\(command) adds or removes a window")
        switch command {
        case "window_movedisplay_west", "window_movedisplay_east", "window_movedisplay_north",
            "window_movedisplay_south", "window_nextdisplay":
            // "The arriving column goes immediately after the destination's active column."
            #expect(from.display != to.display)
            #expect(to.column == 1, "\(command) does not place the column after the destination's active column")
        case "window_swap_first":
            #expect(to.column == 0 && to.display == from.display)
        case "window_swap_last":
            #expect(to.column == after.displays[to.display].columns.count - 1 && to.display == from.display)
        case "window_stack_west", "window_stack_east":
            // "Stacking moves only the focused window into the neighboring column."
            let old = before.displays[from.display].columns[from.column!].windows.filter { $0 != focused }
            #expect(after.displays[to.display].columns[to.column!].windows.count > 1)
            #expect(after.displays.flatMap(\.columns).contains { $0.windows == old })
        case "window_manage":
            #expect(to.column == nil, "the floated window is still in a column")
        case "window_resize", "window_step_grow", "window_step_shrink", "window_maximize", "window_center",
            "window_vertical_step_grow", "window_vertical_step_shrink", "window_equalize":
            // Sizing and centering keep the column order.
            #expect(
                before.displays.map { $0.columns.map(\.windows) } == after.displays.map { $0.columns.map(\.windows) })
        default:
            #expect(from.display == to.display, "\(command) moves the window to another display")
        }
    }

    /// Every window is cut to its own display, and the window the action is about is fully on screen in both sketches.
    @Test(arguments: ShortcutAction.editable) func theFocusedWindowIsOnItsDisplay(_ action: ShortcutAction) throws {
        let scene = try #require(action.scene)
        for sketch in [scene.before, scene.after] {
            let layout = sketch.layout(in: CGSize(width: 160, height: 100), arrangement: scene.before)
            for window in sketch.windows {
                let place = try #require(sketch.place(of: window))
                #expect(layout.clips[window] == layout.displays[place.display], "\(window) is cut to another display")
            }
            // Centre column starts with the focused column partly off the display, which is what it fixes.
            if action == .engine(command: "window_center"), sketch == scene.before { continue }
            let focused = try #require(sketch.focused)
            let place = try #require(sketch.place(of: focused))
            let rect = try #require(layout.windows[focused])
            #expect(
                layout.displays[place.display].insetBy(dx: -0.001, dy: -0.001).contains(rect),
                "\(action.title): the focused window \(focused) reaches off its display")
        }
    }

    /// Width changes keep the column's center, as the keybinding reference says.
    @Test(arguments: ["window_resize", "window_step_grow", "window_step_shrink"])
    func widthChangesKeepTheColumnCenter(_ command: String) throws {
        let scene = try #require(ShortcutAction.engine(command: EngineCommand.canonical(command)!).scene)
        let size = CGSize(width: 160, height: 100)
        let focused = try #require(scene.before.focused)
        let before = try #require(scene.before.layout(in: size).windows[focused])
        let after = try #require(scene.after.layout(in: size).windows[focused])
        #expect(before.width != after.width)
        #expect(abs(before.midX - after.midX) < 0.01, "\(command) moves the column's center")
    }

    /// A display move keeps every column's width.
    @Test(arguments: [
        "window_movedisplay_west", "window_movedisplay_east", "window_movedisplay_north", "window_movedisplay_south",
        "window_nextdisplay",
    ])
    func displayMovesKeepColumnWidths(_ command: String) throws {
        let scene = try #require(ShortcutAction.engine(command: EngineCommand.canonical(command)!).scene)
        let widths = { (sketch: StripSketch) in
            Dictionary(uniqueKeysWithValues: sketch.displays.flatMap(\.columns).map { ($0.windows[0], $0.width) })
        }
        #expect(widths(scene.before) == widths(scene.after))
    }

    /// The action names in the reference's shortcut tables, with "Jump to column 1 through 9" as nine names.
    static func referenceActions() throws -> [String] {
        let text = try String(contentsOf: reference, encoding: .utf8)
        var titles: [String] = []
        var inShortcutTable = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("| Action | Default shortcut") {
                inShortcutTable = true
                continue
            }
            guard inShortcutTable, line.hasPrefix("|") else {
                inShortcutTable = false
                continue
            }
            let title = line.split(separator: "|").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            if title.hasPrefix("---") || title.hasSuffix("v2 only") { continue }
            if title == "Jump to column 1 through 9" {
                titles += (1...9).map { "Jump to column \($0)" }
            } else {
                titles.append(title)
            }
        }
        return titles
    }
}
