import Foundation
import Testing

@testable import MiriCore

struct ConfigurationStoreTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "miri-config-\(UUID().uuidString)")
    private var url: URL { directory.appending(path: "config.toml") }

    private func contents() throws -> String { try String(contentsOf: url, encoding: .utf8) }

    @Test func createsTheFileWithAcceptedDefaultsAndDerivedEngineKeys() throws {
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
        store.load(reduceMotion: false)
        #expect(store.issue == nil)
        #expect(store.settings == MiriSettings())
        let document = try TOMLDocument(contents())
        #expect(document.text.hasPrefix(ConfigurationStore.header))
        #expect(
            document.value(at: ["options", "preset_column_widths"])
                == .array([0.25, 0.33, 0.5, 0.66, 0.75].map(TOMLValue.float)))
        #expect(document.value(at: ["options", "animation_speed"]) == .float(14))
        #expect(document.value(at: ["options", "stack_limit"]) == .integer(5))
        for side in ["top", "right", "bottom", "left"] {
            #expect(document.value(at: ["padding", side]) == .integer(4))
        }
        #expect(document.value(at: ["windows", "miri-gaps", "title"]) == .string(".*"))
        #expect(document.value(at: ["windows", "miri-gaps", "horizontal_padding"]) == .integer(4))
        #expect(document.value(at: ["windows", "miri-gaps", "vertical_padding"]) == .integer(4))
        #expect(document.value(at: ["decorations", "menu", "visible"]) == .boolean(false))
        #expect(
            document.value(at: ["windows", "miri-settings"])
                == .table([
                    "title": .string(".*"), "bundle_id": .string("io.github.samanyudas.miri"),
                    "floating": .boolean(true),
                ]))
    }

    @Test func loadingTwiceDoesNotRewriteTheFile() throws {
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
        store.load(reduceMotion: false)
        let first = try contents()
        let modified = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        store.load(reduceMotion: false)
        #expect(try contents() == first)
        #expect(try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date == modified)
    }

    @Test func keepsUserContentWhenSaving() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = """
            # My notes
            [options]
            focus_follows_mouse = true # I like this

            [bindings]
            window_focus_west = "ctrl + alt - h"
            """
        try original.write(to: url, atomically: true, encoding: .utf8)
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
        store.load(reduceMotion: false)
        try store.update(reduceMotion: false) { $0.innerGap = 12 }
        let text = try contents()
        #expect(text.hasPrefix("# My notes\n[options]\nfocus_follows_mouse = true # I like this\n"))
        #expect(text.contains("[bindings]\nwindow_focus_west = \"ctrl + alt - h\"\n"))
        let document = try TOMLDocument(text)
        #expect(document.value(at: ["miri", "inner_gap"]) == .integer(12))
        #expect(document.value(at: ["windows", "miri-gaps", "horizontal_padding"]) == .integer(6))
        #expect(document.value(at: ["padding", "top"]) == .integer(2))
    }

    @Test func invalidTOMLKeepsTheLastValidSettingsAndTheFile() throws {
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
        store.load(reduceMotion: false)
        try store.update(reduceMotion: false) { $0.outerGap = 16 }
        let broken = try contents() + "\n[miri\n"
        try broken.write(to: url, atomically: true, encoding: .utf8)
        store.load(reduceMotion: false)
        guard case .invalidTOML(let error) = store.issue else {
            Issue.record("Expected a TOML error, got \(String(describing: store.issue))")
            return
        }
        #expect(error.line == broken.split(separator: "\n", omittingEmptySubsequences: false).count - 1)
        #expect(store.settings.outerGap == 16)
        #expect(throws: ConfigurationIssue.self) { try store.update(reduceMotion: false) { $0.outerGap = 4 } }
        #expect(try contents() == broken)
    }

    @Test func invalidValuesAreReportedByKey() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "[miri]\ninner_gap = 99\n".write(to: url, atomically: true, encoding: .utf8)
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
        store.load(reduceMotion: false)
        guard case .invalidValue(let key, _) = store.issue else {
            Issue.record("Expected an invalid value, got \(String(describing: store.issue))")
            return
        }
        #expect(key == "miri.inner_gap")
        #expect(try contents() == "[miri]\ninner_gap = 99\n")
    }

    @Test func rejectsInvalidChangesWithoutWriting() throws {
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
        store.load(reduceMotion: false)
        let before = try contents()
        #expect(throws: ConfigurationIssue.self) {
            try store.update(reduceMotion: false) { $0.widthPresets = [0.5, 0.25] }
        }
        #expect(throws: ConfigurationIssue.self) { try store.update(reduceMotion: false) { $0.innerGap = -1 } }
        #expect(try contents() == before)
        #expect(store.settings == MiriSettings())
    }

    @Test func refusesToOverwriteAFileThatChangedSinceItWasRead() throws {
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
        store.load(reduceMotion: false)
        let external = try contents() + "\n# edited elsewhere\n"
        try external.write(to: url, atomically: true, encoding: .utf8)
        #expect(throws: ConfigurationIssue.self) { try store.update(reduceMotion: false) { $0.innerGap = 2 } }
        #expect(try contents() == external)
    }

    @Test func animationFollowsTheSettingAndReduceMotion() throws {
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
        store.load(reduceMotion: true)
        #expect(try TOMLDocument(contents()).value(at: ["options", "animation_speed"]) == nil)
        store.load(reduceMotion: false)
        #expect(try TOMLDocument(contents()).value(at: ["options", "animation_speed"]) == .float(14))
        try store.update(reduceMotion: false) { $0.animations = false }
        #expect(try TOMLDocument(contents()).value(at: ["options", "animation_speed"]) == nil)
    }

    @Test func reportsAFormMiriCannotRewrite() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "padding = { top = 1 }\n".write(to: url, atomically: true, encoding: .utf8)
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
        store.load(reduceMotion: false)
        guard case .notEditable(let message) = store.issue else {
            Issue.record("Expected notEditable, got \(String(describing: store.issue))")
            return
        }
        #expect(message.contains("padding"))
        #expect(try contents() == "padding = { top = 1 }\n")
        try store.update(reduceMotion: false) { $0.widthPresets = [0.4, 0.6] }
        let saved = try TOMLDocument(contents())
        #expect(saved.text.hasPrefix("padding = { top = 1 }\n"))
        #expect(saved.value(at: ["options", "preset_column_widths"]) == .array([.float(0.4), .float(0.6)]))
    }
}

struct StackLimitConfigurationTests {
    private let directory = FileManager.default.temporaryDirectory.appending(
        path: "miri-stack-limit-\(UUID().uuidString)")
    private var url: URL { directory.appending(path: "config.toml") }

    private func contents() throws -> String { try String(contentsOf: url, encoding: .utf8) }

    private func store(_ text: String) throws -> ConfigurationStore {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        let store = ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
        store.load(reduceMotion: false)
        return store
    }

    @Test func readsANumberOrFit() throws {
        #expect(try store("[options]\nstack_limit = 3\n").settings.stackLimit == .count(3))
        #expect(try store("[options]\nstack_limit = \"fit\"\n").settings.stackLimit == .fit)
    }

    @Test func writesTheChoiceAsTheEngineReadsIt() throws {
        let store = try store("")
        try store.update(reduceMotion: false) { $0.stackLimit = .fit }
        #expect(try TOMLDocument(contents()).value(at: ["options", "stack_limit"]) == .string("fit"))
        try store.update(reduceMotion: false) { $0.stackLimit = .count(2) }
        #expect(try TOMLDocument(contents()).value(at: ["options", "stack_limit"]) == .integer(2))
        #expect(store.settings.stackLimit == .count(2))
    }

    @Test func rejectsValuesTheEngineRejects() throws {
        for bad in ["0", "-1", "\"bogus\"", "2.5", "true"] {
            let text = "[options]\nstack_limit = \(bad)\n"
            let store = try store(text)
            #expect(
                store.issue
                    == .invalidValue(
                        key: "options.stack_limit",
                        message: "options.stack_limit must be a whole number from 1 or \"fit\"."), "\(bad)")
            #expect(try contents() == text)
        }
    }

    @Test func refusesAZeroLimitWithoutWriting() throws {
        let store = try store("[options]\nstack_limit = 4\n")
        let before = try contents()
        #expect(throws: ConfigurationIssue.self) { try store.update(reduceMotion: false) { $0.stackLimit = .count(0) } }
        #expect(try contents() == before)
        #expect(store.settings.stackLimit == .count(4))
    }

    @Test func countsWhatFitsAsTheEngineDoes() {
        #expect(StackLimit.fitCount(columnHeight: 1270) == 6)
        #expect(StackLimit.fitCount(columnHeight: 748) == 3)
        #expect(StackLimit.fitCount(columnHeight: 1399.5) == 6)
        #expect(StackLimit.fitCount(columnHeight: 1400) == 7)
        #expect(StackLimit.fitCount(columnHeight: 150) == 1)
    }
}

struct GestureConfigurationTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "miri-gesture-\(UUID().uuidString)")
    private var url: URL { directory.appending(path: "config.toml") }

    private func contents() throws -> String { try String(contentsOf: url, encoding: .utf8) }

    private func store(_ text: String? = nil) throws -> ConfigurationStore {
        if let text {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return ConfigurationStore(url: url, appBundleIdentifier: "io.github.samanyudas.miri")
    }

    @Test func aNewFileHasTheSwipeOffAndFollowingTheFingers() throws {
        let store = try store()
        store.load(reduceMotion: false)
        let document = try TOMLDocument(contents())
        #expect(document.value(at: ["miri", "strip_gesture"]) == .string("off"))
        #expect(document.value(at: ["miri", "reverse_swipe"]) == .boolean(false))
        #expect(
            document.value(at: ["swipe", "gesture"])
                == .table(["direction": .string("Natural"), "vertical": .boolean(false)]))
    }

    @Test func writesTheFingerCountOnlyWhileASwipeIsActive() throws {
        let store = try store("[miri]\nstrip_gesture = \"four\"\n")
        var active: GestureFingers?
        store.gestureFingers = { settings in active == nil ? nil : settings.stripGesture.fingers }
        store.load(reduceMotion: false)
        #expect(store.settings.stripGesture == .four)
        #expect(try TOMLDocument(contents()).value(at: ["swipe", "gesture", "fingers_count"]) == nil)
        active = .four
        try store.applyGestureFingers(reduceMotion: false)
        #expect(try TOMLDocument(contents()).value(at: ["swipe", "gesture", "fingers_count"]) == .integer(4))
        try store.update(reduceMotion: false) { $0.stripGesture = .three }
        #expect(try TOMLDocument(contents()).value(at: ["swipe", "gesture", "fingers_count"]) == .integer(3))
        active = nil
        try store.applyGestureFingers(reduceMotion: false)
        let document = try TOMLDocument(contents())
        #expect(document.value(at: ["swipe", "gesture", "fingers_count"]) == nil)
        #expect(document.value(at: ["miri", "strip_gesture"]) == .string("three"))
    }

    @Test func writesTheDirectionFromReverseSwipe() throws {
        let store = try store("[miri]\nreverse_swipe = true\n")
        store.load(reduceMotion: false)
        #expect(try TOMLDocument(contents()).value(at: ["swipe", "gesture", "direction"]) == .string("Reversed"))
        try store.update(reduceMotion: false) { $0.reverseSwipe = false }
        #expect(try TOMLDocument(contents()).value(at: ["swipe", "gesture", "direction"]) == .string("Natural"))
    }

    @Test func removesLegacyAndHandEditedSwipeKeysButKeepsTheRest() throws {
        let store = try store(
            """
            # keep me
            [options]
            swipe_gesture_fingers = 3
            swipe_gesture_direction = "Reversed"
            focus_follows_mouse = true

            [swipe]
            sensitivity = 0.5 # mine

            [swipe.gesture]
            fingers_count = 3
            """)
        store.load(reduceMotion: false)
        #expect(store.issue == nil)
        let text = try contents()
        #expect(text.hasPrefix("# keep me\n[options]\nfocus_follows_mouse = true\n"))
        #expect(text.contains("[swipe]\nsensitivity = 0.5 # mine\n"))
        let document = try TOMLDocument(text)
        #expect(document.value(at: ["options", "swipe_gesture_fingers"]) == nil)
        #expect(document.value(at: ["options", "swipe_gesture_direction"]) == nil)
        #expect(
            document.value(at: ["swipe", "gesture"])
                == .table(["direction": .string("Natural"), "vertical": .boolean(false)]))
    }

    @Test func reportsAnUnknownStripGestureByKey() throws {
        let store = try store("[miri]\nstrip_gesture = \"five\"\n")
        store.load(reduceMotion: false)
        #expect(
            store.issue
                == .invalidValue(
                    key: "miri.strip_gesture", message: "miri.strip_gesture must be \"off\", \"three\", or \"four\"."))
        #expect(try contents() == "[miri]\nstrip_gesture = \"five\"\n")
    }

    @Test func leavesAnInlineSwipeTableAlone() throws {
        let original = "swipe = { sensitivity = 0.5 }\n"
        let store = try store(original)
        store.load(reduceMotion: false)
        guard case .notEditable(let message) = store.issue else {
            Issue.record("Expected notEditable, got \(String(describing: store.issue))")
            return
        }
        #expect(message.contains("swipe.gesture"))
        #expect(try contents() == original)
    }
}

struct GapMappingTests {
    @Test(arguments: [(8, 8, 4, 4), (0, 8, 0, 8), (8, 0, 4, 0), (9, 10, 4, 6), (32, 32, 16, 16)])
    func mapsGapsToEnginePadding(inner: Int, outer: Int, window: Int, edge: Int) {
        var settings = MiriSettings()
        settings.innerGap = inner
        settings.outerGap = outer
        #expect(settings.windowPadding == window)
        #expect(settings.edgePadding == edge)
    }
}
