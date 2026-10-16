import Foundation
import Testing

@testable import MiriCore

struct DefaultBindingsTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "miri-bindings-\(UUID().uuidString)")
    private var url: URL { directory.appending(path: "config.toml") }

    private func load(_ original: String? = nil) throws -> (ConfigurationStore, TOMLDocument) {
        if let original {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try original.write(to: url, atomically: true, encoding: .utf8)
        }
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
        store.load(reduceMotion: false)
        return (store, try TOMLDocument(String(contentsOf: url, encoding: .utf8)))
    }

    @Test func aNewInstallGetsTheAcceptedDefaultSet() throws {
        let (store, document) = try load()
        #expect(store.issue == nil)
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(2))
        let expected: [String: TOMLValue] = [
            "window_focus_west": .array([.string("ctrl+alt-leftarrow"), .string("ctrl+alt-h")]),
            "window_focus_east": .array([.string("ctrl+alt-rightarrow"), .string("ctrl+alt-l")]),
            "window_focus_north": .array([.string("ctrl+alt-uparrow"), .string("ctrl+alt-k")]),
            "window_focus_south": .array([.string("ctrl+alt-downarrow"), .string("ctrl+alt-j")]),
            "window_focus_first": .string("ctrl+alt+cmd-leftarrow"),
            "window_focus_last": .string("ctrl+alt+cmd-rightarrow"),
            "window_focus_1": .string("ctrl+alt-1"),
            "window_focus_2": .string("ctrl+alt-2"),
            "window_focus_3": .string("ctrl+alt-3"),
            "window_focus_4": .string("ctrl+alt-4"),
            "window_focus_5": .string("ctrl+alt-5"),
            "window_focus_6": .string("ctrl+alt-6"),
            "window_focus_7": .string("ctrl+alt-7"),
            "window_focus_8": .string("ctrl+alt-8"),
            "window_focus_9": .string("ctrl+alt-9"),
            "window_swap_west": .array([.string("ctrl+alt+shift-leftarrow"), .string("ctrl+alt+shift-h")]),
            "window_swap_east": .array([.string("ctrl+alt+shift-rightarrow"), .string("ctrl+alt+shift-l")]),
            "window_swap_north": .array([.string("ctrl+alt+shift-uparrow"), .string("ctrl+alt+shift-k")]),
            "window_swap_south": .array([.string("ctrl+alt+shift-downarrow"), .string("ctrl+alt+shift-j")]),
            "window_swap_first": .string("ctrl+alt+cmd+shift-leftarrow"),
            "window_swap_last": .string("ctrl+alt+cmd+shift-rightarrow"),
            "window_nextdisplay": .string("ctrl+alt-n"),
            "window_focusdisplay_north": .string("ctrl+alt+cmd-w"),
            "window_focusdisplay_west": .string("ctrl+alt+cmd-a"),
            "window_focusdisplay_south": .string("ctrl+alt+cmd-s"),
            "window_focusdisplay_east": .string("ctrl+alt+cmd-d"),
            "window_movedisplay_north": .string("ctrl+alt+cmd+shift-w"),
            "window_movedisplay_west": .string("ctrl+alt+cmd+shift-a"),
            "window_movedisplay_south": .string("ctrl+alt+cmd+shift-s"),
            "window_movedisplay_east": .string("ctrl+alt+cmd+shift-d"),
            "window_resize": .string("ctrl+alt-r"),
            "window_fullwidth": .string("ctrl+alt-f"),
            "window_center": .string("ctrl+alt-c"),
            "window_step_grow": .string("ctrl+alt-equal"),
            "window_step_shrink": .string("ctrl+alt-minus"),
            "window_vertical_step_grow": .string("ctrl+alt+shift-equal"),
            "window_vertical_step_shrink": .string("ctrl+alt+shift-minus"),
            "window_equalize": .string("ctrl+alt-0"),
            "window_stack_west": .string("ctrl+alt-rightbracket"),
            "window_stack_east": .string("ctrl+alt-leftbracket"),
            "window_unstack_east": .string("ctrl+alt+shift-rightbracket"),
            "window_unstack_west": .string("ctrl+alt+shift-leftbracket"),
            "window_manage": .string("ctrl+alt-t"),
        ]
        #expect(document.value(at: ["bindings"]) == .table(expected))
    }

    @Test func keepsUserBindingsAndAddsDefaultsOnlyForFreeChords() throws {
        let original = """
            [bindings]
            window_focus_west = "alt - h" # my own
            window_center = "ctrl + lalt - l"
            quit = ["ctrl+alt-equal"]
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        #expect(document.text.contains(original + "\n"))
        let bindings = document.value(at: ["bindings"])
        #expect(bindings?["window_focus_west"] == .string("alt - h"))
        #expect(bindings?["window_center"] == .string("ctrl + lalt - l"))
        // ctrl+alt-l is taken by the user's window_center, so only the arrow default is added.
        #expect(bindings?["window_focus_east"] == .string("ctrl+alt-rightarrow"))
        // The only default chord for wider is taken, so the action stays unbound.
        #expect(bindings?["window_step_grow"] == nil)
        #expect(bindings?["window_focus_north"] == .array([.string("ctrl+alt-uparrow"), .string("ctrl+alt-k")]))
    }

    @Test func aDeletedDefaultStaysDeleted() throws {
        let (store, first) = try load()
        let edited = first.text.replacingOccurrences(of: "window_center = \"ctrl+alt-c\"\n", with: "")
        #expect(edited != first.text)
        try edited.write(to: url, atomically: true, encoding: .utf8)
        store.load(reduceMotion: false)
        #expect(store.issue == nil)
        #expect(try String(contentsOf: url, encoding: .utf8) == edited)
    }

    @Test func anExistingFileWithoutBindingsGetsTheDefaults() throws {
        let original = """
            [miri]
            inner_gap = 8

            [options]
            preset_column_widths = [0.25, 0.33, 0.5, 0.66, 0.75]
            """
        let (_, document) = try load(original)
        #expect(document.text.hasPrefix("[miri]\ninner_gap = 8\n"))
        #expect(document.value(at: ["bindings", "window_manage"]) == .string("ctrl+alt-t"))
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(2))
    }

    @Test func rejectsAnInvalidVersionWithoutWriting() throws {
        let original = "[miri]\ndefault_bindings_version = \"one\"\n"
        let (store, _) = try load(original)
        #expect(store.issue?.description == "miri.default_bindings_version must be a whole number.")
        #expect(try String(contentsOf: url, encoding: .utf8) == original)
    }

    @Test(arguments: [
        "bindings = { window_focus_west = \"alt-h\" }\n",
        "bindings.window_focus_west = \"alt-h\"\n",
        "[bindings.window_focus_west]\n",
    ])
    func leavesBindingsMiriCannotEditAloneAndStillSaves(original: String) throws {
        let bindings = try TOMLDocument(original).value(at: ["bindings"])
        let (store, loaded) = try load(original)
        #expect(store.issue == nil)
        #expect(loaded.text.hasPrefix(original))
        #expect(loaded.value(at: ["bindings"]) == bindings)
        #expect(loaded.value(at: ["miri", "default_bindings_version"]) == nil)
        try store.update(reduceMotion: false) { $0.innerGap = 12 }
        let saved = try TOMLDocument(String(contentsOf: url, encoding: .utf8))
        #expect(saved.value(at: ["miri", "inner_gap"]) == .integer(12))
        #expect(saved.text.hasPrefix(original))
        #expect(saved.value(at: ["bindings"]) == bindings)
        #expect(saved.value(at: ["miri", "default_bindings_version"]) == nil)
        store.load(reduceMotion: false)
        #expect(store.issue == nil)
        #expect(try String(contentsOf: url, encoding: .utf8) == saved.text)
    }

    @Test(arguments: ["miri = { inner_gap = 8 }\n", "miri.inner_gap = 8\n"])
    func aMiriTableMiriCannotEditStillLoadsAndSavesOtherSettings(original: String) throws {
        let (store, loaded) = try load(original)
        #expect(store.issue == nil)
        #expect(loaded.text.hasPrefix(original))
        #expect(loaded.value(at: ["miri"]) == (try TOMLDocument(original)).value(at: ["miri"]))
        try store.update(reduceMotion: false) { $0.widthPresets = [0.4, 0.6] }
        let saved = try TOMLDocument(String(contentsOf: url, encoding: .utf8))
        #expect(saved.value(at: ["options", "preset_column_widths"]) == .array([.float(0.4), .float(0.6)]))
        #expect(saved.text.hasPrefix(original))
        #expect(throws: ConfigurationIssue.notEditable(TOMLEditError.notEditable(path: "miri.inner_gap").description)) {
            try store.update(reduceMotion: false) { $0.innerGap = 12 }
        }
        #expect(try String(contentsOf: url, encoding: .utf8) == saved.text)
        #expect(store.settings.innerGap == 8)
        #expect(
            throws: ConfigurationIssue.notEditable(TOMLEditError.notEditable(path: "miri.launch_at_login").description)
        ) {
            try store.update(reduceMotion: false) { $0.launchAtLogin = false }
        }
        #expect(store.settings.launchAtLogin)
        store.load(reduceMotion: false)
        #expect(store.issue == nil)
        #expect(try String(contentsOf: url, encoding: .utf8) == saved.text)
    }

    @Test(arguments: [
        ("window_resize", ["window_grow"]),
        ("window_resize_grow", ["window_resize", "window_grow"]),
        ("window_resize_shrink", ["window_shrink"]),
        ("window_vertical_resize", ["window_vertical_grow"]),
        ("window_vertical_resize_shrink", ["window_vertical_shrink"]),
        ("window_stack", ["window_stack_west"]),
        ("window_unstack", ["window_unstack_east"]),
        ("window_focus_01", ["window_focus_1"]),
        ("window_focus_+9", ["window_focus_9"]),
        ("window_center_now", ["window_center"]),
    ])
    func anAliasCountsAsTheCommandItNames(alias: String, unbound: [String]) throws {
        let (store, document) = try load("[bindings]\n\"\(alias)\" = \"fn-f1\"\n")
        #expect(store.issue == nil)
        let bindings = document.value(at: ["bindings"])
        #expect(bindings?[alias] == .string("fn-f1"))
        for command in unbound { #expect(bindings?[command] == nil) }
        #expect(bindings?["window_manage"] == .string("ctrl+alt-t"))
    }

    /// Version 2 moved the resize shortcuts to five-point steps (miri#22) and added the display shortcuts (miri#23).
    @Test func aVersionOneFileMovesUnchangedResizeDefaultsAndKeepsChangedOnes() throws {
        let original = """
            [bindings]
            window_grow = "ctrl+alt-equal"
            window_shrink = "alt-minus"
            window_vertical_grow = ["ctrl+alt+shift-equal", "fn-f1"]
            window_vertical_shrink = "ctrl+alt+shift-minus"
            window_focus_west = "ctrl+alt-leftarrow"

            [miri]
            default_bindings_version = 1
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        let bindings = document.value(at: ["bindings"])
        // Unchanged since Miri wrote them, so the step commands take their chords.
        #expect(bindings?["window_grow"] == nil)
        #expect(bindings?["window_step_grow"] == .string("ctrl+alt-equal"))
        #expect(bindings?["window_vertical_shrink"] == nil)
        #expect(bindings?["window_vertical_step_shrink"] == .string("ctrl+alt+shift-minus"))
        // Changed by the user, so they stay, and a step command gets only a free chord.
        #expect(bindings?["window_shrink"] == .string("alt-minus"))
        #expect(bindings?["window_step_shrink"] == .string("ctrl+alt-minus"))
        #expect(bindings?["window_vertical_grow"] == .array([.string("ctrl+alt+shift-equal"), .string("fn-f1")]))
        #expect(bindings?["window_vertical_step_grow"] == nil)
        // Version 1 rows are not offered again.
        #expect(bindings?["window_focus_east"] == nil)
        #expect(bindings?["window_focusdisplay_west"] == .string("ctrl+alt+cmd-a"))
        #expect(bindings?["window_movedisplay_east"] == .string("ctrl+alt+cmd+shift-d"))
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(2))
    }

    @Test(arguments: [
        ("ctrl+alt-lefarrow", "names the key \"lefarrow\""),
        ("ctrl+alt-", "names the key \"\""),
        ("ctrl+alt-H", "names the key \"H\""),
        ("hyper-h", "names the modifier \"hyper\""),
        ("Ctrl-h", "names the modifier \"Ctrl\""),
        ("ctrl-alt-h", "has more than one dash"),
    ])
    func reportsABindingTheEngineCannotReadWithoutWriting(chord: String, problem: String) throws {
        let original = "[bindings]\nwindow_focus_west = [\"ctrl+alt-h\", \"\(chord)\"]\n"
        let (store, _) = try load(original)
        guard case .invalidValue(let key, let message) = store.issue else {
            Issue.record("expected an invalid value, got \(String(describing: store.issue))")
            return
        }
        #expect(key == "bindings.window_focus_west")
        #expect(message.contains(problem), "\(message)")
        #expect(try String(contentsOf: url, encoding: .utf8) == original)
    }

    @Test(arguments: ["ctrl+alt-=", "ctrl + lalt - leftarrow", "f5", "cmd+fn-keypad7", "shift-ü"])
    func acceptsBindingsTheEngineReads(chord: String) throws {
        let (store, _) = try load("[bindings]\nquit = \"\(chord)\"\n")
        #expect(store.issue == nil)
    }

    @Test func theStopShortcutYieldsToABindingOnItsChord() throws {
        let (free, _) = try load()
        #expect(free.stopShortcutIsFree)
        let (taken, _) = try load("[bindings]\nquit = \"ctrl + alt - q\"\n")
        #expect(!taken.stopShortcutIsFree)
    }

    @Test func noDefaultUsesTheStopChord() {
        #expect(!DefaultBinding.table.flatMap(\.chords).contains(DefaultBinding.stopChord))
    }

    @Test func aRowWhoseChordsAreAllTakenStaysUnbound() throws {
        let (store, document) = try load("[bindings]\nquit = [\"ctrl+alt-leftarrow\", \"ctrl+alt-h\"]\n")
        #expect(store.issue == nil)
        #expect(document.value(at: ["bindings", "window_focus_west"]) == nil)
        #expect(
            document.value(at: ["bindings", "window_focus_east"])
                == .array([
                    .string("ctrl+alt-rightarrow"), .string("ctrl+alt-l"),
                ]))
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(2))
    }

    @Test func aVersionAboveTheCurrentOneAddsNothing() throws {
        let (store, document) = try load("[miri]\ndefault_bindings_version = 7\n")
        #expect(store.issue == nil)
        #expect(document.value(at: ["bindings"]) == nil)
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(7))
    }

    @Test(arguments: [
        ("window_grow", "window_resize_grow"),
        ("window_resize", "window_resize_grow"),
        ("window_resize_grow_extra", "window_resize_grow"),
        ("window_shrink", "window_resize_shrink"),
        ("window_vertical", "window_vertical_resize_grow"),
        ("window_vertical_grow", "window_vertical_resize_grow"),
        ("window_vertical_resize_shrink", "window_vertical_resize_shrink"),
        ("window_stack", "window_stack_west"),
        ("window_unstack", "window_unstack_east"),
        ("window_focus_01", "window_focus_1"),
        ("window_focus_east", "window_focus_east"),
        ("window_focus_unmanaged", "window_focus_unmanaged"),
        ("window_virtual_2", "window_virtualnum_2"),
        ("window_virtualsend_east", "window_virtualsend_east"),
        ("window_virtualmove_02", "window_virtualmovenum_2"),
        ("mouse_nextdisplay", "mouse_nextdisplay"),
        ("window_step", "window_step_grow"),
        ("window_step_shrink", "window_step_shrink"),
        ("window_vertical_step", "window_vertical_step_grow"),
        ("window_vertical_step_shrink_now", "window_vertical_step_shrink"),
        ("window_focusdisplay_north", "window_focusdisplay_north"),
        ("window_movedisplay_east", "window_movedisplay_east"),
        ("quit_now", "quit"),
    ])
    func readsABindingsKeyAsTheEngineDoes(key: String, canonical: String) {
        #expect(EngineCommand.canonical(key) == canonical)
    }

    @Test(arguments: [
        "window_focus_0", "window_focus", "window_focus_", "window_focus_-1", "window_swap_2", "window_resize_up",
        "window_stack_north", "window_virtual_0", "window", "Window_center", "window__center", "mouse", "",
        "window_step_up", "window_vertical_step_up", "window_focusdisplay_first", "window_focusdisplay",
        "window_movedisplay_2",
    ])
    func rejectsBindingsKeysTheEngineRejects(key: String) {
        #expect(EngineCommand.canonical(key) == nil)
    }

    @Test func theEngineAcceptsEveryDefaultCommand() {
        for row in DefaultBinding.table { #expect(EngineCommand.canonical(row.command) != nil, "\(row.command)") }
    }

    @Test func noTwoDefaultsShareAChord() {
        let chords = DefaultBinding.table.flatMap(\.chords)
        #expect(Set(chords).count == chords.count)
        let commands = DefaultBinding.table.map(\.command)
        #expect(Set(commands).count == commands.count)
    }

    @Test(arguments: [
        ("ctrl+alt-h", "ctrl+alt-h"),
        ("ctrl + alt - h", "ctrl+alt-h"),
        ("lalt+rctrl-H", "ctrl+alt-h"),
        ("shift+cmd+alt+ctrl-leftarrow", "ctrl+alt+cmd+shift-leftarrow"),
        ("ctrl+alt-=", "ctrl+alt-equal"),
        ("ctrl+alt-]", "ctrl+alt-rightbracket"),
        ("tab", "tab"),
    ])
    func normalizesChordSpellingsToFindTakenChords(text: String, normalized: String) {
        #expect(Chord(engineText: text)?.description == normalized)
    }

    @Test(arguments: ["ctrl+alt-", "a-b-c", "hyper-h", ""])
    func ignoresTextThatNamesNoChord(text: String) {
        #expect(Chord(engineText: text) == nil)
    }
}
