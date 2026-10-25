import Foundation
import Testing

@testable import MiriCore

struct DefaultBindingsTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "miri-bindings-\(UUID().uuidString)")
    private var url: URL { directory.appending(path: "config.toml") }

    private func load(
        _ original: String? = nil, layout: KeyLayout = KeyLayout(keys: [.init(code: 0x18, character: "=")])
    ) throws -> (ConfigurationStore, TOMLDocument) {
        if let original {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try original.write(to: url, atomically: true, encoding: .utf8)
        }
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri", layout: layout)
        store.load(reduceMotion: false)
        return (store, try TOMLDocument(String(contentsOf: url, encoding: .utf8)))
    }

    @Test func aNewInstallGetsTheAcceptedDefaultSet() throws {
        let (store, document) = try load()
        #expect(store.issue == nil)
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(3))
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
            "window_stack_west": .string("ctrl+alt-leftbracket"),
            "window_stack_east": .string("ctrl+alt-rightbracket"),
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
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(3))
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
        #expect(bindings?["window_grow"] == nil)
        #expect(bindings?["window_step_grow"] == .string("ctrl+alt-equal"))
        #expect(bindings?["window_vertical_shrink"] == nil)
        #expect(bindings?["window_vertical_step_shrink"] == .string("ctrl+alt+shift-minus"))
        #expect(bindings?["window_shrink"] == .string("alt-minus"))
        #expect(bindings?["window_step_shrink"] == .string("ctrl+alt-minus"))
        #expect(bindings?["window_vertical_grow"] == .array([.string("ctrl+alt+shift-equal"), .string("fn-f1")]))
        #expect(bindings?["window_vertical_step_grow"] == nil)
        #expect(bindings?["window_focus_east"] == nil)
        #expect(bindings?["window_focusdisplay_west"] == .string("ctrl+alt+cmd-a"))
        #expect(bindings?["window_movedisplay_east"] == .string("ctrl+alt+cmd+shift-d"))
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(3))
    }

    @Test func deletedVersionOneResizeShortcutsStayDeletedAfterUpgrade() throws {
        let (store, document) = try load("[miri]\ndefault_bindings_version = 1\n")
        #expect(store.issue == nil)
        for command in [
            "window_step_grow", "window_step_shrink", "window_vertical_step_grow", "window_vertical_step_shrink",
        ] {
            #expect(document.value(at: ["bindings", command]) == nil)
        }
        #expect(document.value(at: ["bindings", "window_focusdisplay_west"]) == .string("ctrl+alt+cmd-a"))
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(3))
    }

    @Test func keepsUnversionedUserBindingsThatMatchRetiredDefaults() throws {
        let original = """
            [bindings]
            window_grow = "ctrl+alt-equal"
            window_shrink = "ctrl+alt-minus"
            window_vertical_grow = "ctrl+alt+shift-equal"
            window_vertical_shrink = "ctrl+alt+shift-minus"
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        #expect(document.text.hasPrefix(original + "\n"))
        #expect(document.value(at: ["bindings", "window_grow"]) == .string("ctrl+alt-equal"))
        #expect(document.value(at: ["bindings", "window_shrink"]) == .string("ctrl+alt-minus"))
        #expect(document.value(at: ["bindings", "window_vertical_grow"]) == .string("ctrl+alt+shift-equal"))
        #expect(document.value(at: ["bindings", "window_vertical_shrink"]) == .string("ctrl+alt+shift-minus"))
        #expect(document.value(at: ["bindings", "window_step_grow"]) == nil)
        #expect(document.value(at: ["bindings", "window_vertical_step_grow"]) == nil)
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(3))
    }

    @Test(arguments: [1, 2])
    func anUpgradeMovesUnchangedJoinDefaultsSoOpeningBracketMeansLeft(version: Int) throws {
        let original = """
            [bindings]
            window_stack_west = "ctrl+alt-rightbracket"
            window_stack_east = "ctrl+alt-leftbracket"
            window_unstack_east = "ctrl+alt+shift-rightbracket"
            window_unstack_west = "ctrl+alt+shift-leftbracket"

            [miri]
            default_bindings_version = \(version)
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        let bindings = document.value(at: ["bindings"])
        #expect(bindings?["window_stack_west"] == .string("ctrl+alt-leftbracket"))
        #expect(bindings?["window_stack_east"] == .string("ctrl+alt-rightbracket"))
        #expect(bindings?["window_unstack_east"] == .string("ctrl+alt+shift-rightbracket"))
        #expect(bindings?["window_unstack_west"] == .string("ctrl+alt+shift-leftbracket"))
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(3))
        #expect(store.keptDefaults.isEmpty)
    }

    @Test func aCustomizedJoinStaysAndItsUnchangedCounterpartMovesToAFreeChord() throws {
        let original = """
            [bindings]
            window_stack_west = "ctrl+alt-rightbracket"
            window_stack_east = "ctrl+alt-p"

            [miri]
            default_bindings_version = 2
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        #expect(document.value(at: ["bindings", "window_stack_west"]) == .string("ctrl+alt-leftbracket"))
        #expect(document.value(at: ["bindings", "window_stack_east"]) == .string("ctrl+alt-p"))
        #expect(store.keptDefaults.isEmpty)
    }

    @Test func aCustomizedJoinOnTheNewChordKeepsItsCounterpartOnTheOldOneAndReportsIt() throws {
        let original = """
            [bindings]
            window_stack_west = "ctrl+alt-rightbracket"
            window_stack_east = ["ctrl+alt-leftbracket", "fn-f1"]

            [miri]
            default_bindings_version = 2
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        #expect(document.text.hasPrefix(original.replacingOccurrences(of: "= 2", with: "= 3")))
        #expect(
            store.keptDefaults == [
                KeptDefault(
                    action: .engine(command: "window_stack_west"), kept: Chord([.control, .option], "rightbracket"),
                    wanted: Chord([.control, .option], "leftbracket"), owner: "Stack focused window into right column")
            ])
        store.load(reduceMotion: false)
        #expect(store.keptDefaults.count == 1)
        try store.apply(.resetToDefaults)
        #expect(store.keptDefaults.isEmpty)
        #expect(
            store.shortcuts?.chords(for: .engine(command: "window_stack_west")) == [
                Chord([.control, .option], "leftbracket")
            ])
    }

    @Test func aKeptJoinNoticeEndsWhenTheShortcutsNoLongerMatchIt() throws {
        let original = """
            [bindings]
            window_stack_west = "ctrl+alt-rightbracket"
            window_stack_east = ["ctrl+alt-leftbracket", "fn-f1"]

            [miri]
            default_bindings_version = 2
            """
        let (store, document) = try load(original)
        #expect(store.keptDefaults.count == 1)
        let freed = document.text.replacingOccurrences(of: "[\"ctrl+alt-leftbracket\", \"fn-f1\"]", with: "\"fn-f1\"")
        try freed.write(to: url, atomically: true, encoding: .utf8)
        store.load(reduceMotion: false)
        #expect(store.issue == nil)
        #expect(store.keptDefaults.isEmpty)

        try original.write(to: url, atomically: true, encoding: .utf8)
        store.load(reduceMotion: false)
        #expect(store.keptDefaults.count == 1)
        try store.apply(
            .remove(Chord([.control, .option], "rightbracket"), from: .engine(command: "window_stack_west")))
        #expect(store.keptDefaults.isEmpty)
    }

    @Test func aBlockedJoinMoveCanBlockItsCounterpartSoNoChordIsShared() throws {
        let original = """
            [bindings]
            window_stack_west = "ctrl+alt-rightbracket"
            window_stack_east = "ctrl+alt-leftbracket"
            quit = "ctrl+alt-leftbracket"

            [miri]
            default_bindings_version = 2
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        #expect(document.value(at: ["bindings", "window_stack_west"]) == .string("ctrl+alt-rightbracket"))
        #expect(document.value(at: ["bindings", "window_stack_east"]) == .string("ctrl+alt-leftbracket"))
        #expect(
            store.keptDefaults.map(\.owner) == [
                "Stack focused window into right column", "Stack focused window into left column",
            ])
    }

    @Test func aDeletedJoinStaysDeletedAndItsCounterpartMoves() throws {
        let original = """
            [bindings]
            window_stack_east = "ctrl+alt-leftbracket"

            [miri]
            default_bindings_version = 2
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        #expect(document.value(at: ["bindings", "window_stack_west"]) == nil)
        #expect(document.value(at: ["bindings", "window_stack_east"]) == .string("ctrl+alt-rightbracket"))
    }

    @Test func keepsUnversionedJoinBindingsThatMatchTheOldDefaults() throws {
        let original = """
            [bindings]
            window_stack_west = "ctrl+alt-rightbracket"
            window_stack_east = "ctrl+alt-leftbracket"
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        #expect(document.text.hasPrefix(original + "\n"))
        #expect(document.value(at: ["bindings", "window_stack_west"]) == .string("ctrl+alt-rightbracket"))
        #expect(document.value(at: ["bindings", "window_stack_east"]) == .string("ctrl+alt-leftbracket"))
        #expect(store.keptDefaults.isEmpty)
    }

    @Test func leavesOldJoinDefaultsInABindingsTableMiriCannotEdit() throws {
        let original = """
            bindings = { window_stack_west = "ctrl+alt-rightbracket", window_stack_east = "ctrl+alt-leftbracket" }
            [miri]
            default_bindings_version = 2
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        #expect(document.text.hasPrefix(original))
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(2))
    }

    @Test func backsUpTheOriginalFileBeforeUpgradingDefaults() throws {
        let original = """
            # My shortcuts.
            [bindings]
            window_grow = "ctrl+alt-equal"
            [miri]
            default_bindings_version = 1
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        #expect(document.value(at: ["bindings", "window_grow"]) == nil)
        let backupDirectory = url.appendingPathExtension("backups")
        let manager = FileManager.default
        #expect(manager.fileExists(atPath: backupDirectory.path))
        guard manager.fileExists(atPath: backupDirectory.path) else { return }
        let backups = try manager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
        #expect(backups.count == 1)
        let backup = try #require(backups.first)
        #expect(try String(contentsOf: backup, encoding: .utf8) == original)
        store.load(reduceMotion: false)
        #expect(store.issue == nil)
        #expect(try manager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil) == backups)
    }

    @Test func leavesTheOriginalFileUntouchedWhenItsBackupCannotBeCreated() throws {
        let original = "[miri]\ndefault_bindings_version = 1\n"
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let backupDirectory = url.appendingPathExtension("backups")
        try "occupied".write(to: backupDirectory, atomically: true, encoding: .utf8)
        let (store, _) = try load(original)
        guard case .unwritable = store.issue else {
            Issue.record("expected a backup write failure, got \(String(describing: store.issue))")
            return
        }
        #expect(try String(contentsOf: url, encoding: .utf8) == original)
        #expect(try String(contentsOf: backupDirectory, encoding: .utf8) == "occupied")
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

    @Test(arguments: ["ctrl+alt-=", "ctrl + lalt - leftarrow", "f5", "cmd+fn-keypad7"])
    func acceptsBindingsTheEngineReads(chord: String) throws {
        let (store, _) = try load("[bindings]\nquit = \"\(chord)\"\n")
        #expect(store.issue == nil)
    }

    @Test func theStopShortcutYieldsToABindingOnItsChord() throws {
        let (free, _) = try load()
        #expect(free.stopChordsToRegister == [DefaultBinding.stopChord])
        let (taken, _) = try load("[bindings]\nquit = \"ctrl + alt - q\"\n")
        #expect(taken.stopChordsToRegister.isEmpty)
    }

    @Test func acceptsAMultilineBindingAndReservesItsStopChord() throws {
        let original = "[bindings]\nwindow_center = \"\"\"\nctrl+alt-q\n\"\"\"\n"
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        #expect(store.stopChordsToRegister.isEmpty)
        #expect(document.text.hasPrefix(original))
    }

    @Test(arguments: ["", "ctrl+alt-c", "ctrl+alt-q"])
    func droppedUppercaseKeyLeavesStopFree(initialChord: String) throws {
        let (store, _) = try load("[bindings]\nwindow_center = \"\(initialChord)\"\n")
        let replacement = "[bindings]\nwindow_center = \"ctrl+alt-Q\"\n"
        try replacement.write(to: url, atomically: true, encoding: .utf8)

        store.load(reduceMotion: false)

        #expect(store.issue != nil)
        #expect(store.stopChordsToRegister == [DefaultBinding.stopChord])
        #expect(try String(contentsOf: url, encoding: .utf8) == replacement)
    }

    @Test func droppedUppercaseKeyLeavesStopFreeOnFirstLoad() throws {
        let (store, _) = try load("[bindings]\nwindow_center = \"ctrl+alt-Q\"\n")
        #expect(store.issue != nil)
        #expect(store.stopChordsToRegister == [DefaultBinding.stopChord])
    }

    @Test(arguments: [
        "\u{0009}", "\u{000A}", "\u{000B}", "\u{000C}", "\u{000D}", "\u{0020}", "\u{0085}", "\u{00A0}",
        "\u{1680}", "\u{2000}", "\u{2001}", "\u{2002}", "\u{2003}", "\u{2004}", "\u{2005}", "\u{2006}",
        "\u{2007}", "\u{2008}", "\u{2009}", "\u{200A}", "\u{2028}", "\u{2029}", "\u{202F}", "\u{205F}",
        "\u{3000}",
    ])
    func trimsTheEnginesUnicodeWhitespace(whitespace: String) {
        let text = "\(whitespace)ctrl\(whitespace)+\(whitespace)alt\(whitespace)-\(whitespace)q\(whitespace)"
        #expect(EngineKey.problem(in: text) == nil)
        #expect(Chord(engineText: text) == DefaultBinding.stopChord)
    }

    @Test func splitsASCIISeparatorsBeforeCombiningMarks() {
        guard case .invalidModifier(_, let name) = EngineKey.problem(in: "ctrl+\u{301}alt-q") else {
            Issue.record("expected an invalid modifier after the ASCII plus")
            return
        }
        #expect(name == "\u{301}alt")
        #expect(Chord(engineText: "ctrl+\u{301}alt-q") == nil)
        guard case .unknownKey(_, let key) = EngineKey.problem(in: "ctrl+alt-\u{301}q") else {
            Issue.record("expected a dropped key after the ASCII dash")
            return
        }
        #expect(key == "\u{301}q")
        #expect(Chord(engineText: "ctrl+alt-\u{301}q")?.modifiers == [.control, .option])
    }

    @Test func noDefaultUsesTheStopChord() {
        #expect(!DefaultBinding.table.flatMap(\.chords).contains(DefaultBinding.stopChord))
    }

    @Test(arguments: ["?", "ü", "🙂"])
    func reportsACharacterTheLayoutCannotResolve(key: String) throws {
        let original = "[bindings]\nwindow_focus_west = \"ctrl+alt-\(key)\"\n"
        let (store, _) = try load(original)
        #expect(store.issue != nil)
        #expect(try String(contentsOf: url, encoding: .utf8) == original)
    }

    @MainActor @Test(arguments: [("US", "="), ("German", "ü"), ("French", "&")])
    func acceptsCharactersFromTheSelectedLayout(name: String, key: String) throws {
        let layout = try #require(KeyLayout(inputSourceID: "com.apple.keylayout.\(name)"))
        let original = "[bindings]\nwindow_focus_west = \"ctrl+alt-\(key)\"\n"
        let (store, _) = try load(original, layout: layout)
        #expect(store.issue == nil)
        #expect(
            store.shortcuts?.chords(for: .engine(command: "window_focus_west")) == [Chord([.control, .option], key)])
    }

    @Test func validatesCharactersAgainWhenTheLayoutChanges() throws {
        let original = "[bindings]\nwindow_focus_west = \"ctrl+alt-ü\"\n"
        let (store, _) = try load(original)
        store.layout = KeyLayout(keys: [.init(code: 0x21, character: "ü")])
        store.load(reduceMotion: false)
        #expect(store.issue == nil)
        store.layout = .positional
        store.load(reduceMotion: false)
        #expect(store.issue != nil)
    }

    @Test func reportsACanonicallyEquivalentCharacterTheEngineDrops() throws {
        let original = "[bindings]\nwindow_focus_west = \"ctrl+alt-u\u{0308}\"\n"
        let layout = KeyLayout(keys: [.init(code: 0x21, character: "ü")])
        let (store, _) = try load(original, layout: layout)
        #expect(store.issue != nil)
        #expect(try String(contentsOf: url, encoding: .utf8) == original)
    }

    @Test func theStopShortcutYieldsWhenAnotherBindingHasAnUnknownKey() throws {
        let original = """
            [bindings]
            window_center = "ctrl+alt-q"
            window_focus_west = "ctrl+alt-lefarrow"
            """
        let (store, _) = try load(original)
        #expect(store.issue != nil)
        #expect(store.stopChordsToRegister.isEmpty)
        #expect(try String(contentsOf: url, encoding: .utf8) == original)
    }

    @Test(
        arguments: [
            "hyper-h", "Ctrl-h", "ctrl-alt-h", "\u{200B}ctrl+alt-h", "\u{FEFF}ctrl+alt-h",
            "hyper-\u{301}q", "ctrl-\u{301}alt-\u{301}q",
        ], [true, false])
    func retainsStopShortcutOwnershipWhenTheEngineRejectsAReload(chord: String, wasFree: Bool) throws {
        let initialChord = wasFree ? "ctrl+alt-c" : "ctrl+alt-q"
        let (store, _) = try load("[bindings]\nwindow_center = \"\(initialChord)\"\n")
        try #require(store.issue == nil)
        #expect((store.stopChordsToRegister == [DefaultBinding.stopChord]) == wasFree)

        let replacementChord = wasFree ? "ctrl+alt-q" : "ctrl+alt-c"
        let replacement = """
            [bindings]
            window_center = "\(replacementChord)"
            window_focus_east = "ctrl+alt-lefarrow"
            window_focus_west = "\(chord)"
            """
        try replacement.write(to: url, atomically: true, encoding: .utf8)
        store.load(reduceMotion: false)

        #expect(store.issue != nil)
        #expect((store.stopChordsToRegister == [DefaultBinding.stopChord]) == wasFree)
        #expect(try String(contentsOf: url, encoding: .utf8) == replacement)
    }

    @Test(
        arguments: [
            "window_missing = \"ctrl+alt-h\"",
            "window_missing = \"ctrl+alt-lefarrow\"",
            "window_focus_west = 1",
            "window_focus_west = true",
            "window_focus_west = { key = \"ctrl+alt-h\" }",
            "window_focus_west = [\"ctrl+alt-lefarrow\", 1]",
            "window_focus_west = [\"ctrl+alt-lefarrow\", \"hyper-h\"]",
        ], [true, false])
    func rejectsBindingRowsWithoutChangingStopOwnership(row: String, wasFree: Bool) throws {
        let initialChord = wasFree ? "ctrl+alt-c" : "ctrl+alt-q"
        let (store, _) = try load("[bindings]\nwindow_center = \"\(initialChord)\"\n")
        try #require(store.issue == nil)
        let previousSettings = store.settings
        let replacementChord = wasFree ? "ctrl+alt-q" : "ctrl+alt-c"
        let replacement = "[bindings]\nwindow_center = \"\(replacementChord)\"\n\(row)\n"
        try replacement.write(to: url, atomically: true, encoding: .utf8)

        store.load(reduceMotion: false)

        guard case .invalidValue(let key, _) = store.issue else {
            Issue.record("expected an invalid binding, got \(String(describing: store.issue))")
            return
        }
        #expect(key == "bindings.\(row.components(separatedBy: " = ")[0])")
        #expect((store.stopChordsToRegister == [DefaultBinding.stopChord]) == wasFree)
        #expect(store.settings == previousSettings)
        #expect(try String(contentsOf: url, encoding: .utf8) == replacement)
        #expect(throws: ConfigurationIssue.self) { try store.update(reduceMotion: false) { $0.innerGap = 12 } }
        #expect(try String(contentsOf: url, encoding: .utf8) == replacement)
    }

    @Test(arguments: ["[]", "1", "\"ctrl+alt-q\""], [true, false])
    func rejectsANonTableBindingsSectionWithoutChangingStopOwnership(value: String, wasFree: Bool) throws {
        let initialChord = wasFree ? "ctrl+alt-c" : "ctrl+alt-q"
        let (store, _) = try load("[bindings]\nwindow_center = \"\(initialChord)\"\n")
        try #require(store.issue == nil)
        let replacement = "bindings = \(value)\n"
        try replacement.write(to: url, atomically: true, encoding: .utf8)

        store.load(reduceMotion: false)

        guard case .invalidValue(let key, _) = store.issue else {
            Issue.record("expected an invalid bindings section, got \(String(describing: store.issue))")
            return
        }
        #expect(key == "bindings")
        #expect((store.stopChordsToRegister == [DefaultBinding.stopChord]) == wasFree)
        #expect(try String(contentsOf: url, encoding: .utf8) == replacement)
    }

    @Test(arguments: ["", "window_missing = []\n"], [true, false])
    func acceptedReloadChangesStopOwnership(emptyRow: String, wasFree: Bool) throws {
        let initialChord = wasFree ? "ctrl+alt-c" : "ctrl+alt-q"
        let (store, _) = try load("[bindings]\nwindow_center = \"\(initialChord)\"\n")
        try #require(store.issue == nil)
        let replacementChord = wasFree ? "ctrl+alt-q" : "ctrl+alt-c"
        let replacement = "[bindings]\nwindow_center = \"\(replacementChord)\"\n\(emptyRow)"
        try replacement.write(to: url, atomically: true, encoding: .utf8)

        store.load(reduceMotion: false)

        #expect(store.issue == nil)
        #expect((store.stopChordsToRegister == [DefaultBinding.stopChord]) == !wasFree)
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
        #expect(document.value(at: ["miri", "default_bindings_version"]) == .integer(3))
    }

    @Test func anUpgradeLeavesAStopChordToStop() throws {
        let original = """
            [bindings]
            window_grow = "ctrl+alt-g"

            [miri]
            default_bindings_version = 1
            stop_shortcut = "ctrl+alt-equal"
            """
        let (store, document) = try load(original)
        #expect(store.issue == nil)
        #expect(document.value(at: ["bindings", "window_step_grow"]) == nil)
        #expect(document.value(at: ["miri", "stop_shortcut"]) == .string("ctrl+alt-equal"))
        #expect(store.stopChordsToRegister == [Chord([.control, .option], "equal")])
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
        ("showmenu", "showmenu"),
        ("hidemenu", "hidemenu"),
    ])
    func readsABindingsKeyAsTheEngineDoes(key: String, canonical: String) {
        #expect(EngineCommand.canonical(key) == canonical)
    }

    @Test(arguments: [
        "window_focus_0", "window_focus", "window_focus_", "window_focus_-1", "window_swap_2", "window_resize_up",
        "window_stack_north", "window_virtual_0", "window", "Window_center", "window__center", "mouse", "",
        "window_step_up", "window_vertical_step_up", "window_focusdisplay_first", "window_focusdisplay",
        "window_movedisplay_2",
        "showmenu_extra", "hidemenu_extra", "showmenu_", "hidemenu_",
    ])
    func rejectsBindingsKeysTheEngineRejects(key: String) {
        #expect(EngineCommand.canonical(key) == nil)
    }

    @Test(arguments: ["quit_\u{301}", "window_center_\u{301}"])
    func acceptsCommandAliasesSeparatedByScalarUnderscores(command: String) throws {
        let (store, _) = try load("[bindings]\n\"\(command)\" = \"ctrl+alt-q\"\n")
        #expect(store.issue == nil)
        #expect(store.stopChordsToRegister.isEmpty)
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
