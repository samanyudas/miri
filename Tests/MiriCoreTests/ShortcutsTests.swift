import Foundation
import Testing

@testable import MiriCore

@MainActor struct KeyLayoutTests {
    nonisolated private static let ids = ["US", "French", "German", "Dvorak"]

    private func layout(_ name: String) throws -> KeyLayout {
        try #require(KeyLayout(inputSourceID: "com.apple.keylayout.\(name)"))
    }

    @Test func azertyNamesKeysByTheirCharacters() throws {
        let azerty = try layout("French")
        #expect(azerty.name(for: 0) == "q")
        #expect(azerty.keyCode(for: "a") == 12)
        // The top row types symbols without Shift.
        #expect(azerty.name(for: 18) == "&")
        // The US equal position types "-", which would split the chord text, so Miri writes its position name.
        #expect(azerty.name(for: 24) == "equal")
        #expect(azerty.keyCode(for: "equal") == 24)
        // The engine's "minus" always means the US minus position, which types ")" on AZERTY.
        #expect(azerty.keyCode(for: "minus") == 27)
        #expect(azerty.name(for: 27) == ")")
        #expect(azerty.name(for: 22) == "§")
    }

    @Test func qwertzAndDvorakNameKeysByTheirCharacters() throws {
        let qwertz = try layout("German")
        #expect(qwertz.name(for: 16) == "z")
        #expect(qwertz.keyCode(for: "y") == 6)
        let dvorak = try layout("Dvorak")
        #expect(dvorak.name(for: 40) == "t")
        #expect(dvorak.keyCode(for: "h") == 38)
    }

    @Test func aKeyWhoseCharacterAnEarlierKeyTypesFallsBackToItsPosition() throws {
        // Keypad minus types "-", like the US minus key, which comes first in the engine's table.
        #expect(try layout("US").name(for: 78) == "keypadminus")
        #expect(try layout("US").name(for: 27) == "minus")
    }

    @Test(arguments: ids)
    func everyNamedKeyReadsBackAsTheSameKey(id: String) throws {
        let layout = try layout(id)
        for code in EngineKey.layoutKeys.map(\.code) {
            let name = try #require(layout.name(for: code), "code \(code)")
            #expect(layout.keyCode(for: name) == code, "\(id) \(name)")
        }
    }

    @Test func labelsFollowMacOSOrder() throws {
        let us = try layout("US")
        #expect(us.label(for: Chord([.control, .option], "leftarrow")) == "⌃⌥←")
        #expect(us.label(for: Chord([.shift, .option, .control], "h")) == "⌃⌥⇧H")
        #expect(us.label(for: Chord([.command, .shift, .option, .control], "rightarrow")) == "⌃⌥⇧⌘→")
        #expect(us.label(for: Chord([.control, .option], "equal")) == "⌃⌥=")
        #expect(us.label(for: Chord([.command], "space")) == "⌘Space")
        #expect(us.label(for: Chord([.control], "f2")) == "⌃F2")
        #expect(try layout("French").label(for: Chord([.control, .option], "minus")) == "⌃⌥)")
        #expect(try layout("French").label(for: Chord([.control, .option], "1")) == "⌃⌥Keypad 1")
    }

    @Test func chordsConflictWhenTheyPressTheSameKeys() throws {
        let us = try layout("US")
        #expect(us.conflicts(Chord([.control, .option], "="), Chord([.control, .option], "equal")))
        #expect(!us.conflicts(Chord([.control, .option], "="), Chord([.control, .option, .shift], "equal")))
        let azerty = try layout("French")
        #expect(!azerty.conflicts(Chord([.control], "="), Chord([.control], "equal")))
        #expect(azerty.conflicts(Chord([.control], "-"), Chord([.control], "equal")))
    }
}

@MainActor struct ShortcutsTests {
    private let us = KeyLayout(inputSourceID: "com.apple.keylayout.US")!
    private let focusWest = ShortcutAction.engine(command: "window_focus_west")
    private let resize = ShortcutAction.engine(command: "window_resize_grow")

    private func shortcuts(_ text: String) throws -> Shortcuts { Shortcuts(document: try TOMLDocument(text)) }

    @Test func theEditableListIsTheDefaultTableThenStop() {
        #expect(ShortcutAction.editable.count == DefaultBinding.table.count + 1)
        #expect(ShortcutAction.editable.first?.title == "Focus column left")
        #expect(ShortcutAction.editable.last == .stop)
        #expect(ShortcutAction.stop.title == "Stop window manager")
        #expect(resize.title == "Cycle preset widths forward")
    }

    @Test func readsChordsUnderAnySpellingAndStopsDefault() throws {
        let file = try shortcuts(
            """
            [bindings]
            window_focus_west = ["ctrl+alt-leftarrow", "ctrl + alt - h"]
            window_grow = "ctrl+alt-r"
            window_virtual_2 = "ctrl+alt+cmd-2"
            """)
        #expect(
            file.chords(for: focusWest) == [Chord([.control, .option], "leftarrow"), Chord([.control, .option], "h")])
        #expect(file.chords(for: resize) == [Chord([.control, .option], "r")])
        #expect(file.chords(for: .stop) == [Chord([.control, .option], "q")])
        #expect(
            file.others == [
                Shortcuts.OtherBinding(key: "window_virtual_2", chords: [Chord([.control, .option, .command], "2")])
            ])
    }

    @Test func rejectsAChordAnotherActionUsesAndLeavesTheFileUnchanged() throws {
        let text = "[bindings]\nwindow_focus_west = \"ctrl+alt-h\"\nwindow_center = \"ctrl+alt-c\"\n"
        let file = try shortcuts(text)
        #expect(throws: ShortcutRejection.usedBy("Focus column left")) {
            try file.adding(Chord([.control, .option], "h"), to: .engine(command: "window_center"), layout: us)
        }
        #expect(throws: ShortcutRejection.alreadyAssigned) {
            try file.adding(Chord([.control, .option], "h"), to: focusWest, layout: us)
        }
        #expect(throws: ShortcutRejection.usedBy("Stop window manager")) {
            try file.adding(Chord([.control, .option], "q"), to: focusWest, layout: us)
        }
        #expect(file.document.text == text)
    }

    @Test func aPrintedCharacterConflictsWithItsKeyName() throws {
        let file = try shortcuts("[bindings]\nwindow_step_grow = \"ctrl+alt-equal\"\n")
        #expect(throws: ShortcutRejection.usedBy("Make column wider")) {
            try file.adding(Chord([.control, .option], "="), to: focusWest, layout: us)
        }
    }

    @Test func rejectsAChordACommandOutsideMirisListUses() throws {
        let file = try shortcuts("[bindings]\nwindow_virtual_2 = \"ctrl+alt+cmd-2\"\n")
        #expect(throws: ShortcutRejection.usedBy("window_virtual_2")) {
            try file.adding(Chord([.control, .option, .command], "2"), to: focusWest, layout: us)
        }
    }

    @Test func addsToTheKeySpellingTheFileUses() throws {
        let file = try shortcuts("[bindings]\nwindow_grow = \"ctrl+alt-r\" # cycle\n")
        let result = try file.adding(Chord([.control, .option, .shift], "r"), to: resize, layout: us)
        #expect(result.text == "[bindings]\nwindow_grow = [\"ctrl+alt-r\", \"ctrl+alt+shift-r\"] # cycle\n")
    }

    @Test func createsAnAbsentKeyWithMirisCommandName() throws {
        let file = try shortcuts("[options]\nfocus_follows_mouse = true\n")
        let result = try file.adding(Chord([.control, .option], "r"), to: resize, layout: us)
        #expect(result.text == "[options]\nfocus_follows_mouse = true\n\n[bindings]\nwindow_resize = \"ctrl+alt-r\"\n")
    }

    @Test func addsAndRemovesStopShortcuts() throws {
        let added = try shortcuts("[miri]\ninner_gap = 8\n").adding(
            Chord([.control, .command], "s"), to: .stop, layout: us)
        #expect(added.text == "[miri]\ninner_gap = 8\nstop_shortcut = [\"ctrl+alt-q\", \"ctrl+cmd-s\"]\n")
        let one = try Shortcuts(document: added).removing(Chord([.control, .option], "q"), from: .stop)
        #expect(one.text == "[miri]\ninner_gap = 8\nstop_shortcut = \"ctrl+cmd-s\"\n")
        let none = try Shortcuts(document: one).removing(Chord([.control, .command], "s"), from: .stop)
        #expect(none.text == "[miri]\ninner_gap = 8\nstop_shortcut = []\n")
        #expect(Shortcuts(document: none).chords(for: .stop) == [])
    }

    @Test func removingTheLastChordRemovesTheKey() throws {
        let file = try shortcuts(
            "[bindings]\nwindow_focus_west = [\"ctrl+alt-leftarrow\", \"ctrl+alt-h\"]\nquit = \"f5\"\n")
        let one = try file.removing(Chord([.control, .option], "leftarrow"), from: focusWest)
        #expect(one.text == "[bindings]\nwindow_focus_west = \"ctrl+alt-h\"\nquit = \"f5\"\n")
        let none = try Shortcuts(document: one).removing(Chord([.control, .option], "h"), from: focusWest)
        #expect(none.text == "[bindings]\nquit = \"f5\"\n")
    }

    @Test func resetReplacesBindingsAndKeepsEverythingElse() throws {
        let original = """
            # My notes.
            [options]
            focus_follows_mouse = true # keep

            [bindings]
            # Custom set.
            window_grow = "ctrl+alt-g"
            window_focus_west = "cmd-h"

            [miri]
            stop_shortcut = []
            default_bindings_version = 1
            inner_gap = 12
            """
        let result = try shortcuts(original).resettingToDefaults()
        let defaults = DefaultBinding.table.map { row in
            let value =
                row.chords.count == 1
                ? "\"\(row.chords[0])\"" : "[" + row.chords.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
            return "\(row.command) = \(value)\n"
        }.joined()
        let expected = """
            # My notes.
            [options]
            focus_follows_mouse = true # keep

            [bindings]
            \(defaults)# Custom set.

            [miri]
            default_bindings_version = 2
            inner_gap = 12
            """
        #expect(result.text == expected)
        #expect(
            result.value(at: ["bindings", "window_focus_west"])
                == .array([.string("ctrl+alt-leftarrow"), .string("ctrl+alt-h")]))
        #expect(result.value(at: ["bindings", "window_resize"]) == .string("ctrl+alt-r"))
    }

    @Test func resetRefusesABindingsTableMiriCannotEdit() throws {
        let file = try shortcuts("bindings = { quit = \"f5\" }\n")
        #expect(throws: TOMLEditError.notEditable(path: "bindings.quit")) { try file.resettingToDefaults() }
    }

    @Test(arguments: [
        ("stop_shortcut = 1", "miri.stop_shortcut must be a shortcut string or an array of shortcut strings."),
        (
            "stop_shortcut = [\"ctrl+alt-q\", true]",
            "miri.stop_shortcut must be a shortcut string or an array of shortcut strings."
        ),
        (
            "stop_shortcut = \"ctrl+alt-lefarrow\"",
            "miri.stop_shortcut: \"ctrl+alt-lefarrow\" names the key \"lefarrow\""
        ),
        ("stop_shortcut = [\"hyper-q\"]", "miri.stop_shortcut: \"hyper-q\" names the modifier \"hyper\""),
    ])
    func reportsAStopShortcutMiriCannotRead(line: String, message: String) throws {
        let issue = Shortcuts.stopShortcutIssue(in: try TOMLDocument("[miri]\n\(line)\n"))
        guard case .invalidValue(let key, let text) = issue else {
            Issue.record("expected an invalid value, got \(String(describing: issue))")
            return
        }
        #expect(key == "miri.stop_shortcut")
        #expect(text.hasPrefix(message), "\(text)")
    }

    @Test func acceptsStopShortcutsMiriReads() throws {
        for line in [
            "stop_shortcut = []", "stop_shortcut = \"ctrl+cmd-s\"", "stop_shortcut = [\"ctrl+alt-q\", \"f5\"]",
        ] {
            #expect(Shortcuts.stopShortcutIssue(in: try TOMLDocument("[miri]\n\(line)\n")) == nil, "\(line)")
        }
    }

    @Test func anEngineBindingOnAStopChordWins() throws {
        let file = try shortcuts(
            "[bindings]\nwindow_step_grow = \"ctrl+alt-=\"\n[miri]\nstop_shortcut = [\"ctrl+alt-equal\", \"ctrl+cmd-s\"]\n"
        )
        #expect(file.stopChordsToRegister(layout: us) == [Chord([.control, .command], "s")])
    }
}

@MainActor struct ShortcutStoreTests {
    private let directory = FileManager.default.temporaryDirectory.appending(
        path: "miri-shortcuts-\(UUID().uuidString)")
    private var url: URL { directory.appending(path: "config.toml") }
    private let us = KeyLayout(inputSourceID: "com.apple.keylayout.US")!

    private func store(_ original: String, layout: KeyLayout? = nil) throws -> ConfigurationStore {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try original.write(to: url, atomically: true, encoding: .utf8)
        let store = ConfigurationStore(
            url: url, appBundleIdentifier: "io.github.samanyudas.miri", layout: layout ?? us)
        store.load(reduceMotion: false)
        return store
    }

    @Test func resetBacksUpTheFileFirst() throws {
        let store = try store("[bindings]\nwindow_focus_west = \"cmd-h\"\n[miri]\ndefault_bindings_version = 2\n")
        let before = try String(contentsOf: url, encoding: .utf8)
        try store.apply(.resetToDefaults)
        let backups = try FileManager.default.contentsOfDirectory(
            at: url.appendingPathExtension("backups"), includingPropertiesForKeys: nil)
        #expect(backups.count == 1)
        #expect(try String(contentsOf: try #require(backups.first), encoding: .utf8) == before)
        let after = try TOMLDocument(String(contentsOf: url, encoding: .utf8))
        #expect(
            after.value(at: ["bindings", "window_focus_west"])
                == .array([.string("ctrl+alt-leftarrow"), .string("ctrl+alt-h")]))
        #expect(store.shortcuts?.document.text == after.text)
    }

    @Test func anUpgradeLeavesStopTheKeyItsOtherSpellingNames() throws {
        let french = try #require(KeyLayout(inputSourceID: "com.apple.keylayout.French"))
        let store = try store(
            """
            [bindings]
            window_shrink = "ctrl+alt-g"

            [miri]
            default_bindings_version = 1
            stop_shortcut = "ctrl+alt-)"
            """, layout: french)
        let document = try TOMLDocument(String(contentsOf: url, encoding: .utf8))
        #expect(store.issue == nil)
        #expect(document.value(at: ["bindings", "window_step_shrink"]) == nil)
        #expect(store.stopChordsToRegister == [Chord([.control, .option], ")")])
    }

    @Test func aRejectedAddLeavesTheFileUnchanged() throws {
        let store = try store("")
        let before = try String(contentsOf: url, encoding: .utf8)
        #expect(throws: ShortcutRejection.usedBy("Focus column left")) {
            try store.apply(.add(Chord([.control, .option], "h"), to: .stop))
        }
        #expect(try String(contentsOf: url, encoding: .utf8) == before)
    }

    @Test func stopEditsUpdateTheChordsToRegister() throws {
        let store = try store("")
        #expect(store.stopChordsToRegister == [DefaultBinding.stopChord])
        try store.apply(.add(Chord([.control, .command], "s"), to: .stop))
        #expect(store.stopChordsToRegister == [DefaultBinding.stopChord, Chord([.control, .command], "s")])
        try store.apply(.remove(DefaultBinding.stopChord, from: .stop))
        try store.apply(.remove(Chord([.control, .command], "s"), from: .stop))
        #expect(store.stopChordsToRegister == [])
        store.load(reduceMotion: false)
        #expect(store.issue == nil)
        #expect(store.stopChordsToRegister == [])
    }

    @Test func anInvalidStopShortcutIsReportedAndKeepsThePreviousStopChords() throws {
        let store = try store("[miri]\nstop_shortcut = \"ctrl+cmd-s\"\n")
        #expect(store.stopChordsToRegister == [Chord([.control, .command], "s")])
        try "[miri]\nstop_shortcut = 5\n".write(to: url, atomically: true, encoding: .utf8)
        store.load(reduceMotion: false)
        #expect(
            store.issue?.description == "miri.stop_shortcut must be a shortcut string or an array of shortcut strings.")
        #expect(store.stopChordsToRegister == [Chord([.control, .command], "s")])
        #expect(store.shortcuts == nil)
    }
}

@MainActor struct SystemShortcutsTests {
    private let us = KeyLayout(inputSourceID: "com.apple.keylayout.US")!

    @Test func mergesUserChangesOverTheDefaults() {
        let system = SystemShortcuts.parse(
            symbolicHotKeys: [
                // Spotlight disabled.
                "64": ["enabled": false, "value": ["parameters": [32, 49, 1_048_576], "type": "standard"]],
                // Mission Control moved to ⌃⌥M.
                "32": ["enabled": true, "value": ["parameters": [109, 46, 786_432], "type": "standard"]],
                // Move left a space with the fn bit macOS adds to arrows.
                "79": ["enabled": true, "value": ["parameters": [65_535, 123, 8_650_752], "type": "standard"]],
                // Switch to Desktop 1 turned on.
                "118": ["enabled": true],
                "999": ["enabled": true, "value": ["parameters": [107, 40, 1_572_864], "type": "standard"]],
                "998": ["enabled": false, "value": ["parameters": [107, 37, 1_572_864], "type": "standard"]],
                "997": ["enabled": true, "value": ["parameters": [65_535, 65_535, 0], "type": "standard"]],
            ], layout: us)
        func names(_ chord: Chord) -> String? { system.conflict(for: chord, layout: us)?.name }
        #expect(names(Chord([.command], "space")) == nil)
        #expect(names(Chord([.control], "uparrow")) == nil)
        #expect(names(Chord([.control, .option], "m")) == "Mission Control")
        #expect(names(Chord([.control], "leftarrow")) == "Move left a space")
        #expect(names(Chord([.control], "1")) == "Switch to Desktop 1")
        #expect(names(Chord([.control], "2")) == nil)
        #expect(
            names(Chord([.option, .command], "k")) == "a shortcut in System Settings > Keyboard > Keyboard Shortcuts")
        #expect(names(Chord([.option, .command], "l")) == nil)
    }

    @Test func findsDefaultAndAppShortcuts() {
        let system = SystemShortcuts.parse(symbolicHotKeys: [:], layout: us)
        #expect(system.conflict(for: Chord([.command], "space"), layout: us)?.name == "Show Spotlight search")
        #expect(system.conflict(for: Chord([.command], "q"), layout: us)?.name == "Quit the frontmost app")
        #expect(system.conflict(for: Chord([.control, .command], "q"), layout: us)?.name == "Lock Screen")
        #expect(system.conflict(for: Chord([.control, .option], "q"), layout: us) == nil)
    }

    @Test func appShortcutsFollowTheLayout() throws {
        let azerty = try #require(KeyLayout(inputSourceID: "com.apple.keylayout.French"))
        let system = SystemShortcuts.parse(symbolicHotKeys: [:], layout: azerty)
        // ⌘Q on AZERTY is the key at the US A position.
        #expect(system.conflict(for: Chord([.command], "q"), layout: azerty)?.keyCode == 0)
    }
}
