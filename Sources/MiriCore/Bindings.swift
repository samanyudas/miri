import Foundation

/// A modifier key in the engine's chord syntax.
public enum ChordModifier: String, CaseIterable, Comparable, Sendable {
    case control = "ctrl"
    case option = "alt"
    case command = "cmd"
    case shift = "shift"
    case function = "fn"

    /// The engine's side-specific names match either side of the same key, so they count as the generic modifier.
    static func parse(_ name: String) -> ChordModifier? {
        switch name.lowercased() {
        case "ctrl", "lctrl", "rctrl": .control
        case "alt", "lalt", "ralt": .option
        case "cmd", "lcmd", "rcmd": .command
        case "shift", "lshift", "rshift": .shift
        case "fn": .function
        default: nil
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

/// A key press with its modifiers, such as `ctrl+alt-leftarrow`.
public struct Chord: Hashable, Sendable, CustomStringConvertible {
    public let modifiers: Set<ChordModifier>
    /// The engine's key name, such as `h`, `leftarrow`, or `equal`.
    public let key: String

    public init(_ modifiers: Set<ChordModifier>, _ key: String) {
        self.modifiers = modifiers
        self.key = key
    }

    /// Reads a chord in the engine's syntax to find which chords a file already uses.
    ///
    /// This is deliberately more lenient than the engine. It ignores case, so it reads `Ctrl-H` as `ctrl-h` where
    /// the engine rejects the modifier (`vendor/paneru/src/config.rs` line 1736) and finds no key named `H`
    /// (line 1718). A near miss therefore still counts as taking its chord, and Miri adds no second binding for it.
    /// Returns `nil` for text that names no single chord, such as an empty key or an unknown modifier.
    public init?(engineText: String) {
        guard let exact = Chord(exactEngineText: engineText) else { return nil }
        self.init(exact.modifiers, Self.keyAliases[exact.key] ?? exact.key)
    }

    /// Like `init(engineText:)`, but keeps a printed character such as `=` as written, because only the keyboard
    /// layout says which key it names. `KeyLayout.conflicts` compares chords read this way.
    init?(exactEngineText engineText: String) {
        let parts = engineText.unicodeScalars.split(separator: "-", omittingEmptySubsequences: false).map {
            String($0).trimmingCharacters(in: EngineKey.whitespace)
        }
        guard (1...2).contains(parts.count), let last = parts.last, !last.isEmpty else { return nil }
        var modifiers = Set<ChordModifier>()
        if parts.count == 2 {
            for name in parts[0].unicodeScalars.split(separator: "+", omittingEmptySubsequences: false) {
                guard let modifier = ChordModifier.parse(String(name).trimmingCharacters(in: EngineKey.whitespace))
                else {
                    return nil
                }
                modifiers.insert(modifier)
            }
        }
        self.init(modifiers, last.lowercased())
    }

    /// The engine's syntax, with modifiers in a fixed order.
    public var description: String {
        let names = modifiers.sorted().map(\.rawValue).joined(separator: "+")
        return names.isEmpty ? key : "\(names)-\(key)"
    }

    /// On a US layout the engine also accepts a key's printed character, so both spellings name the same key.
    private static let keyAliases = [
        "=": "equal", "[": "leftbracket", "]": "rightbracket", ";": "semicolon", "'": "quote", ",": "comma",
        ".": "period", "/": "slash", "\\": "backslash", "`": "grave",
    ]
}

enum BindingInspection {
    case usable(droppedKeyIssue: ConfigurationIssue?)
    case rejected(ConfigurationIssue)

    var issue: ConfigurationIssue? {
        switch self {
        case .usable(let issue): issue
        case .rejected(let issue): issue
        }
    }
}

/// One action in Miri's default shortcut set and the engine command that performs it.
public struct DefaultBinding: Sendable {
    /// The action's name in the keybinding reference.
    public let action: String
    /// The engine's `[bindings]` key, which the engine splits on `_` into its command words.
    public let command: String
    public let chords: [Chord]
    /// The `miri.default_bindings_version` that first offered this default. Later versions add only newer rows.
    public let version: Int

    init(_ action: String, _ command: String, _ chords: Chord..., version: Int = 1) {
        self.action = action
        self.command = command
        self.chords = chords
        self.version = version
    }

    /// The accepted defaults from `decisions/keybinding reference.md` that the pinned engine can perform.
    ///
    /// The reference also lists actions this table leaves unbound, because the engine has no command for them or
    /// the action is app-owned or deferred to v2. `decisions/keybinding reference.md` names each one and the reason.
    public static let table: [DefaultBinding] =
        [
            DefaultBinding("Focus column left", "window_focus_west", ctrlAlt("leftarrow"), ctrlAlt("h")),
            DefaultBinding("Focus column right", "window_focus_east", ctrlAlt("rightarrow"), ctrlAlt("l")),
            DefaultBinding("Focus window above within column", "window_focus_north", ctrlAlt("uparrow"), ctrlAlt("k")),
            DefaultBinding(
                "Focus window below within column", "window_focus_south", ctrlAlt("downarrow"), ctrlAlt("j")),
            DefaultBinding("Focus first column", "window_focus_first", ctrlAlt("leftarrow", .command)),
            DefaultBinding("Focus last column", "window_focus_last", ctrlAlt("rightarrow", .command)),
        ]
        + (1...9).map { DefaultBinding("Jump to column \($0)", "window_focus_\($0)", ctrlAlt("\($0)")) }
        + [
            DefaultBinding("Move column left", "window_swap_west", ctrlAlt("leftarrow", .shift), ctrlAlt("h", .shift)),
            DefaultBinding(
                "Move column right", "window_swap_east", ctrlAlt("rightarrow", .shift), ctrlAlt("l", .shift)),
            DefaultBinding(
                "Move window up within column", "window_swap_north", ctrlAlt("uparrow", .shift), ctrlAlt("k", .shift)),
            DefaultBinding(
                "Move window down within column", "window_swap_south", ctrlAlt("downarrow", .shift),
                ctrlAlt("j", .shift)),
            DefaultBinding(
                "Move column to first position", "window_swap_first", ctrlAlt("leftarrow", .command, .shift)),
            DefaultBinding("Move column to last position", "window_swap_last", ctrlAlt("rightarrow", .command, .shift)),
            DefaultBinding("Send focused window to next display", "window_nextdisplay", ctrlAlt("n")),
            DefaultBinding("Focus monitor above", "window_focusdisplay_north", ctrlAlt("w", .command), version: 2),
            DefaultBinding("Focus monitor left", "window_focusdisplay_west", ctrlAlt("a", .command), version: 2),
            DefaultBinding("Focus monitor below", "window_focusdisplay_south", ctrlAlt("s", .command), version: 2),
            DefaultBinding("Focus monitor right", "window_focusdisplay_east", ctrlAlt("d", .command), version: 2),
            DefaultBinding(
                "Move focused window to monitor above", "window_movedisplay_north", ctrlAlt("w", .command, .shift),
                version: 2),
            DefaultBinding(
                "Move focused window to monitor left", "window_movedisplay_west", ctrlAlt("a", .command, .shift),
                version: 2),
            DefaultBinding(
                "Move focused window to monitor below", "window_movedisplay_south", ctrlAlt("s", .command, .shift),
                version: 2),
            DefaultBinding(
                "Move focused window to monitor right", "window_movedisplay_east", ctrlAlt("d", .command, .shift),
                version: 2),
            DefaultBinding("Cycle preset widths forward", "window_resize", ctrlAlt("r")),
            DefaultBinding("Make column full width", "window_fullwidth", ctrlAlt("f")),
            DefaultBinding("Centre column", "window_center", ctrlAlt("c")),
            DefaultBinding("Make column wider", "window_step_grow", ctrlAlt("equal"), version: 2),
            DefaultBinding("Make column narrower", "window_step_shrink", ctrlAlt("minus"), version: 2),
            DefaultBinding("Make window taller", "window_vertical_step_grow", ctrlAlt("equal", .shift), version: 2),
            DefaultBinding("Make window shorter", "window_vertical_step_shrink", ctrlAlt("minus", .shift), version: 2),
            DefaultBinding("Equalize window heights within column", "window_equalize", ctrlAlt("0")),
            DefaultBinding("Stack focused window into left column", "window_stack_west", ctrlAlt("rightbracket")),
            DefaultBinding("Stack focused window into right column", "window_stack_east", ctrlAlt("leftbracket")),
            DefaultBinding("Pop focused window out to right", "window_unstack_east", ctrlAlt("rightbracket", .shift)),
            DefaultBinding("Pop focused window out to left", "window_unstack_west", ctrlAlt("leftbracket", .shift)),
            DefaultBinding("Float or unfloat focused window", "window_manage", ctrlAlt("t")),
        ]

    /// The newest version in the table. Miri records it after offering the defaults.
    public static let currentVersion = table.map(\.version).max() ?? 0

    static let retired: [(command: String, replacement: String, chord: Chord, version: Int)] = [
        ("window_grow", "window_step_grow", ctrlAlt("equal"), 2),
        ("window_shrink", "window_step_shrink", ctrlAlt("minus"), 2),
        ("window_vertical_grow", "window_vertical_step_grow", ctrlAlt("equal", .shift), 2),
        ("window_vertical_shrink", "window_vertical_step_shrink", ctrlAlt("minus", .shift), 2),
    ]

    /// The default Stop window manager shortcut, used when `[miri].stop_shortcut` is absent. Miri owns Stop instead of
    /// the engine, because the engine's `quit` makes Miri restart the engine (miri#25).
    public static let stopChord = ctrlAlt("q")

    private static func ctrlAlt(_ key: String, _ extra: ChordModifier...) -> Chord {
        Chord(Set([.control, .option] + extra), key)
    }

    /// Adds each default newer than the recorded version whose engine command has no binding, with its free chords.
    ///
    /// A user binding is never changed. A default is offered once, so a binding the user deletes stays deleted.
    /// When the file defines `[bindings]` or `[miri]` in a form Miri does not rewrite, such as an inline table, Miri
    /// leaves the file as it is and records no version, so it offers the defaults again if the user converts the table.
    static func adding(to document: TOMLDocument) throws -> TOMLDocument {
        do {
            return try addingEditable(to: document)
        } catch TOMLEditError.notEditable {
            return document
        }
    }

    private static func addingEditable(to document: TOMLDocument) throws -> TOMLDocument {
        let versionPath = ["miri", "default_bindings_version"]
        let offered: Int
        switch document.value(at: versionPath) {
        case nil: offered = 0
        case .integer(let version): offered = Int(clamping: version)
        default:
            throw ConfigurationIssue.invalidValue(
                key: "miri.default_bindings_version", message: "miri.default_bindings_version must be a whole number.")
        }
        guard offered < currentVersion else { return document }

        var result = document
        var deletedReplacements = Set<String>()
        for old in retired where offered >= 1 && old.version > offered {
            if document.value(at: ["bindings", old.command]) == nil {
                deletedReplacements.insert(old.replacement)
            }
            if case .string(let text) = document.value(at: ["bindings", old.command]), text == old.chord.description {
                result = try result.removing(table: ["bindings"], key: old.command)
            }
        }
        let existing = result.value(at: ["bindings"])
        var taken = Set(boundChords(in: existing))
        // Only the file's own bindings count, so two default rows for one engine command both get written.
        let bound = Set(boundCommands(in: existing))
        for row in table where row.version > offered && !bound.contains(EngineCommand.canonical(row.command)!) {
            guard !deletedReplacements.contains(row.command) else { continue }
            let free = row.chords.filter { !taken.contains($0) }
            guard !free.isEmpty else { continue }
            taken.formUnion(free)
            let value: TOMLValue =
                free.count == 1 ? .string(free[0].description) : .array(free.map { .string($0.description) })
            result = try result.setting(value, table: ["bindings"], key: row.command)
        }
        return try result.setting(.integer(Int64(currentVersion)), table: ["miri"], key: "default_bindings_version")
    }

    /// Each bound command in the engine's own spelling, so that an alias such as `window_resize` counts as
    /// `window_grow`. A key the engine rejects keeps its own spelling.
    private static func boundCommands(in bindings: TOMLValue?) -> [String] {
        guard case .table(let entries) = bindings else { return [] }
        return entries.keys.map { EngineCommand.canonical($0) ?? $0 }
    }

    /// Whether the file binds `chord` to an engine command, in which case that binding wins over a Miri shortcut.
    public static func binds(_ chord: Chord, in document: TOMLDocument) -> Bool {
        bindingTexts(in: document.value(at: ["bindings"]))
            .filter { EngineKey.problem(in: $0) == nil }
            .contains { Chord(engineText: $0) == chord }
    }

    static func inspect(in document: TOMLDocument) -> BindingInspection {
        guard let bindings = document.value(at: ["bindings"]) else { return .usable(droppedKeyIssue: nil) }
        guard case .table(let entries) = bindings else {
            return .rejected(.invalidValue(key: "bindings", message: "bindings must be a table of shortcuts."))
        }
        var droppedKeyIssue: ConfigurationIssue?
        for (command, value) in entries.sorted(by: { $0.key < $1.key }) {
            let path = "bindings.\(command)"
            let values: [TOMLValue]
            switch value {
            case .array(let items): values = items
            default: values = [value]
            }
            var texts: [String] = []
            for value in values {
                guard case .string(let text) = value else {
                    return .rejected(
                        .invalidValue(
                            key: path, message: "\(path) must be a shortcut string or an array of shortcut strings."))
                }
                texts.append(text)
            }
            guard texts.isEmpty || EngineCommand.canonical(command) != nil else {
                return .rejected(.invalidValue(key: path, message: "\(path) names a command the engine does not know."))
            }
            for text in texts {
                guard let problem = EngineKey.problem(in: text) else { continue }
                let issue = ConfigurationIssue.invalidValue(key: path, message: "\(path): \(problem.message)")
                switch problem {
                case .unknownKey: droppedKeyIssue = droppedKeyIssue ?? issue
                case .extraDash, .invalidModifier: return .rejected(issue)
                }
            }
        }
        return .usable(droppedKeyIssue: droppedKeyIssue)
    }

    private static func boundChords(in bindings: TOMLValue?) -> [Chord] {
        bindingTexts(in: bindings).compactMap { Chord(engineText: $0) }
    }

    private static func bindingTexts(in bindings: TOMLValue?) -> [String] {
        guard case .table(let entries) = bindings else { return [] }
        return entries.values.flatMap { value -> [String] in
            switch value {
            case .string(let text): [text]
            case .array(let items): items.compactMap { if case .string(let text) = $0 { text } else { nil } }
            default: []
            }
        }
    }
}
