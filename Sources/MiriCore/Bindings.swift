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
    /// A row with no chords lists an action that Settings offers without a default shortcut.
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
            DefaultBinding("Focus column left", "window_focus_west", ctrlAlt("leftarrow"), ctrlAlt("h"), ctrlAlt("a")),
            DefaultBinding(
                "Focus column right", "window_focus_east", ctrlAlt("rightarrow"), ctrlAlt("l"), ctrlAlt("d")),
            DefaultBinding(
                "Focus window above within column", "window_focus_north", ctrlAlt("uparrow"), ctrlAlt("k"),
                ctrlAlt("w")),
            DefaultBinding(
                "Focus window below within column", "window_focus_south", ctrlAlt("downarrow"), ctrlAlt("j"),
                ctrlAlt("s")),
            DefaultBinding(
                "Focus first column or monitor left", "window_focusedge_west", ctrlAlt("leftarrow", .command),
                ctrlAlt("h", .command), ctrlAlt("a", .command), version: 4),
            DefaultBinding(
                "Focus last column or monitor right", "window_focusedge_east", ctrlAlt("rightarrow", .command),
                ctrlAlt("l", .command), ctrlAlt("d", .command), version: 4),
            DefaultBinding(
                "Focus monitor above", "window_focusdisplay_north", ctrlAlt("uparrow", .command),
                ctrlAlt("k", .command), ctrlAlt("w", .command), version: 2),
            DefaultBinding(
                "Focus monitor below", "window_focusdisplay_south", ctrlAlt("downarrow", .command),
                ctrlAlt("j", .command), ctrlAlt("s", .command), version: 2),
        ]
        + (1...9).map { DefaultBinding("Jump to column \($0)", "window_focus_\($0)", ctrlAlt("\($0)")) }
        + [
            DefaultBinding(
                "Move column left", "window_swap_west", ctrlAlt("leftarrow", .shift), ctrlAlt("h", .shift),
                ctrlAlt("a", .shift)),
            DefaultBinding(
                "Move column right", "window_swap_east", ctrlAlt("rightarrow", .shift), ctrlAlt("l", .shift),
                ctrlAlt("d", .shift)),
            DefaultBinding(
                "Move window up within column", "window_swap_north", ctrlAlt("uparrow", .shift), ctrlAlt("k", .shift),
                ctrlAlt("w", .shift)),
            DefaultBinding(
                "Move window down within column", "window_swap_south", ctrlAlt("downarrow", .shift),
                ctrlAlt("j", .shift), ctrlAlt("s", .shift)),
            DefaultBinding(
                "Move column to first position or monitor left", "window_moveedge_west",
                ctrlAlt("leftarrow", .command, .shift), ctrlAlt("h", .command, .shift),
                ctrlAlt("a", .command, .shift), version: 4),
            DefaultBinding(
                "Move column to last position or monitor right", "window_moveedge_east",
                ctrlAlt("rightarrow", .command, .shift), ctrlAlt("l", .command, .shift),
                ctrlAlt("d", .command, .shift), version: 4),
            DefaultBinding(
                "Move column to monitor above", "window_movedisplay_north", ctrlAlt("uparrow", .command, .shift),
                ctrlAlt("k", .command, .shift), ctrlAlt("w", .command, .shift), version: 2),
            DefaultBinding(
                "Move column to monitor below", "window_movedisplay_south", ctrlAlt("downarrow", .command, .shift),
                ctrlAlt("j", .command, .shift), ctrlAlt("s", .command, .shift), version: 2),
            DefaultBinding("Send column to next display", "window_nextdisplay", ctrlAlt("n")),
            DefaultBinding("Cycle preset widths forward", "window_resize", ctrlAlt("r")),
            // Version 1 offered this as `window_fullwidth`, which the engine still reads as `window_maximize`.
            DefaultBinding("Maximize or restore window", "window_maximize", ctrlAlt("f")),
            DefaultBinding("Centre column", "window_center", ctrlAlt("c")),
            DefaultBinding("Make column wider", "window_step_grow", ctrlAlt("equal"), version: 2),
            DefaultBinding("Make column narrower", "window_step_shrink", ctrlAlt("minus"), version: 2),
            DefaultBinding("Make window taller", "window_vertical_step_grow", ctrlAlt("equal", .shift), version: 2),
            DefaultBinding("Make window shorter", "window_vertical_step_shrink", ctrlAlt("minus", .shift), version: 2),
            DefaultBinding("Equalize window heights within column", "window_equalize", ctrlAlt("0")),
            DefaultBinding("Stack focused window into left column", "window_stack_west", ctrlAlt("leftbracket")),
            DefaultBinding("Stack focused window into right column", "window_stack_east", ctrlAlt("rightbracket")),
            DefaultBinding("Pop focused window out to right", "window_unstack_east", ctrlAlt("rightbracket", .shift)),
            DefaultBinding("Pop focused window out to left", "window_unstack_west", ctrlAlt("leftbracket", .shift)),
            DefaultBinding("Float or unfloat focused window", "window_manage", ctrlAlt("t")),
            // Version 4 gives these no shortcut, because the edge-or-monitor actions above took their chords.
            DefaultBinding("Focus first column", "window_focus_first"),
            DefaultBinding("Focus last column", "window_focus_last"),
            DefaultBinding("Move column to first position", "window_swap_first"),
            DefaultBinding("Move column to last position", "window_swap_last"),
            DefaultBinding("Focus monitor left", "window_focusdisplay_west", version: 2),
            DefaultBinding("Focus monitor right", "window_focusdisplay_east", version: 2),
            DefaultBinding("Move column to monitor left", "window_movedisplay_west", version: 2),
            DefaultBinding("Move column to monitor right", "window_movedisplay_east", version: 2),
        ]

    /// The newest version in the table or in `changed`. Miri records it after offering the defaults.
    public static let currentVersion = (table.map(\.version) + changed.map(\.version)).max() ?? 0

    /// Defaults that `version` removed, with the command that replaces each one. `offered` is the version that first
    /// wrote the retired default, so Miri can tell a binding the user deleted from one it never wrote.
    static let retired: [(command: String, replacement: String, chord: Chord, offered: Int, version: Int)] = [
        ("window_grow", "window_step_grow", ctrlAlt("equal"), 1, 2),
        ("window_shrink", "window_step_shrink", ctrlAlt("minus"), 1, 2),
        ("window_vertical_grow", "window_vertical_step_grow", ctrlAlt("equal", .shift), 1, 2),
        ("window_vertical_shrink", "window_vertical_step_shrink", ctrlAlt("minus", .shift), 1, 2),
        ("window_focus_first", "window_focusedge_west", ctrlAlt("leftarrow", .command), 1, 4),
        ("window_focusdisplay_west", "window_focusedge_west", ctrlAlt("a", .command), 2, 4),
        ("window_focus_last", "window_focusedge_east", ctrlAlt("rightarrow", .command), 1, 4),
        ("window_focusdisplay_east", "window_focusedge_east", ctrlAlt("d", .command), 2, 4),
        ("window_swap_first", "window_moveedge_west", ctrlAlt("leftarrow", .command, .shift), 1, 4),
        ("window_movedisplay_west", "window_moveedge_west", ctrlAlt("a", .command, .shift), 2, 4),
        ("window_swap_last", "window_moveedge_east", ctrlAlt("rightarrow", .command, .shift), 1, 4),
        ("window_movedisplay_east", "window_moveedge_east", ctrlAlt("d", .command, .shift), 2, 4),
    ]

    /// Defaults whose chords changed in `version`. Version 3 makes `[` mean left and `]` mean right (miri#92).
    /// Version 4 gives every directional action the same chords on the arrow keys, HJKL, and WASD (miri#79).
    static let changed: [(command: String, from: [Chord], to: [Chord], version: Int)] =
        [
            ("window_stack_west", [ctrlAlt("rightbracket")], [ctrlAlt("leftbracket")], 3),
            ("window_stack_east", [ctrlAlt("leftbracket")], [ctrlAlt("rightbracket")], 3),
        ]
        + [
            ("window_focus_west", ["a"]), ("window_focus_east", ["d"]), ("window_focus_north", ["w"]),
            ("window_focus_south", ["s"]), ("window_swap_west", ["a"]), ("window_swap_east", ["d"]),
            ("window_swap_north", ["w"]), ("window_swap_south", ["s"]),
            ("window_focusdisplay_north", ["uparrow", "k"]), ("window_focusdisplay_south", ["downarrow", "j"]),
            ("window_movedisplay_north", ["uparrow", "k"]), ("window_movedisplay_south", ["downarrow", "j"]),
        ].map { command, added in
            let to = table.first { $0.command == command }!.chords
            return (command, to.filter { !added.contains($0.key) }, to, 4)
        }

    /// Settings reports each chord of an action first offered in this version or later that another binding holds.
    /// Earlier versions added an action's free chords without a report, and their files keep that behavior.
    static let reportsHeldChordsSince = 4

    /// The default Stop window manager shortcut, used when `[miri].stop_shortcut` is absent. Miri owns Stop instead of
    /// the engine, because the engine's `quit` makes Miri restart the engine (miri#25).
    public static let stopChord = ctrlAlt("q")

    private static func ctrlAlt(_ key: String, _ extra: ChordModifier...) -> Chord {
        Chord(Set([.control, .option] + extra), key)
    }

    /// Adds each default newer than the recorded version whose engine command has no binding, with its free chords.
    ///
    /// A user binding is never changed. Miri changes only a retired or changed default that still has the exact value
    /// Miri wrote. A default is offered once, so a binding the user deletes stays deleted.
    /// When the file defines `[bindings]` or `[miri]` in a form Miri does not rewrite, such as an inline table, Miri
    /// leaves the file as it is and records no version, so it offers the defaults again if the user converts the table.
    static func adding(to document: TOMLDocument, layout: KeyLayout = .positional) throws -> TOMLDocument {
        do {
            return try addingEditable(to: document, layout: layout)
        } catch TOMLEditError.notEditable {
            return document
        }
    }

    private static func addingEditable(to document: TOMLDocument, layout: KeyLayout) throws -> TOMLDocument {
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
        let unwanted = replacementsToSkip(in: document, offered: offered)
        for old in retired where offered >= 1 && old.version > offered {
            if case .string(let text) = document.value(at: ["bindings", old.command]), text == old.chord.description {
                result = try result.removing(table: ["bindings"], key: old.command)
            }
        }
        result = try changing(in: result, offered: offered, layout: layout)
        let existing = result.value(at: ["bindings"])
        var taken = takenChords(in: result, layout: layout)
        // Only the file's own bindings count, so two default rows for one engine command both get written.
        let bound = Set(boundCommands(in: existing))
        for row in table where row.version > offered && !bound.contains(EngineCommand.canonical(row.command)!) {
            guard !unwanted.contains(row.command) else { continue }
            let free = row.chords.filter { chord in !taken.contains { layout.conflicts($0, chord) } }
            guard !free.isEmpty else { continue }
            taken += free
            result = try result.setting(encoded(free), table: ["bindings"], key: row.command)
        }
        return try result.setting(.integer(Int64(currentVersion)), table: ["miri"], key: "default_bindings_version")
    }

    /// The replacements for retired defaults that Miri must not add.
    ///
    /// In a recorded version, a replacement is skipped when the user deleted or emptied every retired default it
    /// replaces that Miri had written. A file with no recorded version keeps its bindings, so a replacement is skipped while any
    /// binding it replaces remains, because the two would split the same chords between old and new actions.
    private static func replacementsToSkip(in document: TOMLDocument, offered: Int) -> Set<String> {
        let bound = Set(boundCommands(in: document.value(at: ["bindings"])))
        let pending = Dictionary(grouping: retired.filter { $0.version > offered }, by: \.replacement)
        return Set(
            pending.filter { _, olds in
                if offered == 0 { return olds.contains { bound.contains(EngineCommand.canonical($0.command)!) } }
                let written = olds.filter { $0.offered <= offered }
                return !written.isEmpty
                    && written.allSatisfy { [nil, .array([])].contains(document.value(at: ["bindings", $0.command])) }
            }.keys)
    }

    /// Gives each `changed` default newer than `offered` its new chords, but only while the binding still has the
    /// exact value Miri wrote and every chord the change adds is free. Otherwise the binding keeps its value, and
    /// `keptChanges` finds it.
    private static func changing(in document: TOMLDocument, offered: Int, layout: KeyLayout) throws -> TOMLDocument {
        var changes = changed.filter { change in
            offered >= 1 && change.version > offered
                && document.value(at: ["bindings", change.command]) == encoded(change.from)
        }
        // A change whose new chord another binding holds keeps its old chords, which can block another change in turn.
        while true {
            var others = document
            for change in changes { others = try others.removing(table: ["bindings"], key: change.command) }
            let taken = takenChords(in: others, layout: layout)
            let blocked = Set(
                changes.filter { change in
                    added(by: change).contains { chord in taken.contains { layout.conflicts($0, chord) } }
                }.map(\.command))
            guard !blocked.isEmpty else { break }
            changes.removeAll { blocked.contains($0.command) }
        }
        var result = document
        for change in changes {
            result = try result.setting(encoded(change.to), table: ["bindings"], key: change.command)
        }
        return result
    }

    /// The `changed` defaults that `document` records as offered but that still have the exact value Miri wrote
    /// before the change, with the chords the change would have added.
    static func keptChanges(in document: TOMLDocument) -> [(command: String, kept: [Chord], wanted: [Chord])] {
        guard case .integer(let offered) = document.value(at: ["miri", "default_bindings_version"]) else { return [] }
        return changed.filter { change in
            change.version <= offered && document.value(at: ["bindings", change.command]) == encoded(change.from)
        }.map { ($0.command, $0.from, added(by: $0)) }
    }

    private static func added(by change: (command: String, from: [Chord], to: [Chord], version: Int)) -> [Chord] {
        change.to.filter { !change.from.contains($0) }
    }

    /// One chord as a string and several as an array, as Miri writes its defaults.
    static func encoded(_ chords: [Chord]) -> TOMLValue {
        chords.count == 1 ? .string(chords[0].description) : .array(chords.map { .string($0.description) })
    }

    /// The chords a new default must not take: every binding's, and Stop's, because an engine binding wins over Stop
    /// on the same chord.
    private static func takenChords(in document: TOMLDocument, layout: KeyLayout) -> [Chord] {
        var taken = boundChords(in: document.value(at: ["bindings"]), layout: layout)
        if let stop = document.value(at: ["miri", "stop_shortcut"]) {
            taken += boundChords(in: .table(["stop_shortcut": stop]), layout: layout)
        } else {
            taken.append(stopChord)
        }
        return taken
    }

    /// Each bound command in the engine's own spelling, so that an alias such as `window_resize` counts as
    /// `window_grow`. A key the engine rejects keeps its own spelling.
    private static func boundCommands(in bindings: TOMLValue?) -> [String] {
        guard case .table(let entries) = bindings else { return [] }
        return entries.keys.map { EngineCommand.canonical($0) ?? $0 }
    }

    static func inspect(in document: TOMLDocument, layout: KeyLayout = .positional) -> BindingInspection {
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
                guard let problem = EngineKey.problem(in: text, layout: layout) else { continue }
                let issue = ConfigurationIssue.invalidValue(key: path, message: "\(path): \(problem.message)")
                switch problem {
                case .unknownKey: droppedKeyIssue = droppedKeyIssue ?? issue
                case .extraDash, .invalidModifier: return .rejected(issue)
                }
            }
        }
        return .usable(droppedKeyIssue: droppedKeyIssue)
    }

    /// A printed character such as `]` names whichever key types it in `layout`, so it keeps its spelling there.
    /// Only a character the layout cannot resolve falls back to its US key name.
    private static func boundChords(in bindings: TOMLValue?, layout: KeyLayout) -> [Chord] {
        bindingTexts(in: bindings).compactMap { text in
            guard let exact = Chord(exactEngineText: text) else { return nil }
            return layout.keyCode(for: exact.key) == nil ? Chord(engineText: text) : exact
        }
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
