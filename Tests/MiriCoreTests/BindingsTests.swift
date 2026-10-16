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
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(1))
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
            "window_resize": .string("ctrl+alt-r"),
            "window_fullwidth": .string("ctrl+alt-f"),
            "window_center": .string("ctrl+alt-c"),
            "window_grow": .string("ctrl+alt-equal"),
            "window_shrink": .string("ctrl+alt-minus"),
            "window_vertical_grow": .string("ctrl+alt+shift-equal"),
            "window_vertical_shrink": .string("ctrl+alt+shift-minus"),
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
        #expect(bindings?["window_grow"] == nil)
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
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(1))
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
    func readsTheEngineChordSyntax(text: String, normalized: String) {
        #expect(Chord(engineText: text)?.description == normalized)
    }

    @Test(arguments: ["ctrl+alt-", "a-b-c", "hyper-h", ""])
    func rejectsChordsTheEngineRejects(text: String) {
        #expect(Chord(engineText: text) == nil)
    }
}
