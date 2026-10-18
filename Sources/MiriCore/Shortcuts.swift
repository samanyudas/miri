/// An action whose shortcuts the Shortcuts settings page edits.
public enum ShortcutAction: Hashable, Sendable {
    /// An engine command in the engine's own spelling, from `EngineCommand.canonical`.
    case engine(command: String)
    /// Stop window manager, which Miri registers itself from `[miri].stop_shortcut`.
    case stop

    /// Miri's actions in the keybinding reference's order, then Stop.
    public static let editable: [ShortcutAction] =
        DefaultBinding.table.map { .engine(command: EngineCommand.canonical($0.command)!) } + [.stop]

    public var title: String {
        switch self {
        case .engine(let command): DefaultBinding.row(for: command)?.action ?? command
        case .stop: "Stop window manager"
        }
    }
}

/// Why Miri refused to add a shortcut. The file stays unchanged.
public enum ShortcutRejection: Error, Equatable, Sendable {
    /// Another binding presses the same keys. The value is its action's title, or its `[bindings]` key when Miri
    /// does not list the command.
    case usedBy(String)
    case alreadyAssigned
}

/// A change the Shortcuts settings page makes.
public enum ShortcutEdit: Equatable, Sendable {
    case add(Chord, to: ShortcutAction)
    case remove(Chord, from: ShortcutAction)
    case resetToDefaults
}

/// The shortcuts a configuration file assigns, and edits to them that keep every other byte of the file.
///
/// Engine actions live in `[bindings]`, under any key the engine reads as the action's command. Stop lives in
/// `[miri].stop_shortcut`, where an absent key means ⌃⌥Q and an empty array means no shortcut. A chord the engine
/// drops, such as one with an unknown key, does not count, because it presses nothing.
public struct Shortcuts: Sendable {
    /// A binding for an engine command Miri does not list, which the page shows without editing.
    public struct OtherBinding: Hashable, Sendable {
        public let key: String
        public let chords: [Chord]
    }

    public let document: TOMLDocument
    /// The file's `[bindings]` keys for each listed command, sorted, so edits go to the spelling the user wrote.
    private let keysByCommand: [String: [String]]
    public let others: [OtherBinding]

    public init(document: TOMLDocument) {
        self.document = document
        var keysByCommand: [String: [String]] = [:]
        var others: [OtherBinding] = []
        let entries: [String: TOMLValue] =
            if case .table(let entries) = document.value(at: ["bindings"]) { entries } else { [:] }
        for key in entries.keys.sorted() {
            let command = EngineCommand.canonical(key) ?? key
            if DefaultBinding.row(for: command) != nil {
                keysByCommand[command, default: []].append(key)
            } else if let chords = Self.chords(in: entries[key]), !chords.isEmpty {
                others.append(OtherBinding(key: key, chords: chords))
            }
        }
        self.keysByCommand = keysByCommand
        self.others = others
    }

    public func chords(for action: ShortcutAction) -> [Chord] {
        switch action {
        case .engine(let command):
            (keysByCommand[command] ?? []).flatMap { Self.chords(in: document.value(at: ["bindings", $0])) ?? [] }
        case .stop:
            document.value(at: ["miri", "stop_shortcut"]).map { Self.chords(in: $0) ?? [] } ?? [
                DefaultBinding.stopChord
            ]
        }
    }

    /// Why `chord` cannot be added to `action`, or `nil` when it can.
    public func rejection(adding chord: Chord, to action: ShortcutAction, layout: KeyLayout) -> ShortcutRejection? {
        if chords(for: action).contains(where: { layout.conflicts($0, chord) }) { return .alreadyAssigned }
        for other in ShortcutAction.editable where other != action {
            if chords(for: other).contains(where: { layout.conflicts($0, chord) }) { return .usedBy(other.title) }
        }
        if let other = others.first(where: { $0.chords.contains { layout.conflicts($0, chord) } }) {
            return .usedBy(other.key)
        }
        return nil
    }

    public func adding(_ chord: Chord, to action: ShortcutAction, layout: KeyLayout) throws -> TOMLDocument {
        if let rejection = rejection(adding: chord, to: action, layout: layout) { throw rejection }
        switch action {
        case .engine(let command):
            guard let key = keysByCommand[command]?.first else {
                return try document.setting(
                    .string(chord.description), table: ["bindings"], key: DefaultBinding.row(for: command)!.command)
            }
            let texts = Self.texts(in: document.value(at: ["bindings", key])) + [chord.description]
            return try document.setting(Self.value(texts), table: ["bindings"], key: key)
        case .stop:
            let texts = chords(for: .stop).map(\.description) + [chord.description]
            return try document.setting(Self.value(texts), table: ["miri"], key: "stop_shortcut")
        }
    }

    /// Removes `chord` from `action`. The last engine chord removes the key, and the last Stop chord leaves
    /// `stop_shortcut = []`, because an absent key means the default.
    public func removing(_ chord: Chord, from action: ShortcutAction) throws -> TOMLDocument {
        switch action {
        case .engine(let command):
            var result = document
            for key in keysByCommand[command] ?? [] {
                let texts = Self.texts(in: document.value(at: ["bindings", key]))
                let kept = texts.filter { Chord(exactEngineText: $0) != chord }
                guard kept.count < texts.count else { continue }
                result =
                    kept.isEmpty
                    ? try result.removing(table: ["bindings"], key: key)
                    : try result.setting(Self.value(kept), table: ["bindings"], key: key)
            }
            return result
        case .stop:
            let kept = chords(for: .stop).filter { $0 != chord }.map(\.description)
            return try document.setting(
                kept.isEmpty ? .array([]) : Self.value(kept), table: ["miri"], key: "stop_shortcut")
        }
    }

    /// Replaces `[bindings]` with exactly Miri's default set, restores the default Stop shortcut, and records the
    /// current defaults version, so a later upgrade offers only newer defaults.
    public func resettingToDefaults() throws -> TOMLDocument {
        var result = document
        if case .table(let entries) = document.value(at: ["bindings"]) {
            for key in entries.keys.sorted() {
                result = try result.removing(table: ["bindings"], key: key)
            }
        } else if document.value(at: ["bindings"]) != nil {
            throw TOMLEditError.notEditable(path: "bindings")
        }
        for row in DefaultBinding.table {
            result = try result.setting(
                Self.value(row.chords.map(\.description)), table: ["bindings"], key: row.command)
        }
        result = try result.removing(table: ["miri"], key: "stop_shortcut")
        return try result.setting(
            .integer(Int64(DefaultBinding.currentVersion)), table: ["miri"], key: "default_bindings_version")
    }

    /// The Stop chords Miri registers. A `[bindings]` entry on the same keys wins, because the engine takes the key
    /// press first.
    public func stopChordsToRegister(layout: KeyLayout) -> [Chord] {
        let engineChords =
            keysByCommand.values.joined().flatMap { Self.chords(in: document.value(at: ["bindings", $0])) ?? [] }
            + others.flatMap(\.chords)
        return chords(for: .stop).filter { stop in !engineChords.contains { layout.conflicts($0, stop) } }
    }

    /// The problem with `[miri].stop_shortcut`, if any. Miri reads it itself, so the engine never reports it.
    static func stopShortcutIssue(in document: TOMLDocument) -> ConfigurationIssue? {
        let key = "miri.stop_shortcut"
        guard let value = document.value(at: ["miri", "stop_shortcut"]) else { return nil }
        let items: [TOMLValue] = if case .array(let items) = value { items } else { [value] }
        var texts: [String] = []
        for item in items {
            guard case .string(let text) = item else {
                return .invalidValue(
                    key: key, message: "\(key) must be a shortcut string or an array of shortcut strings.")
            }
            texts.append(text)
        }
        for text in texts {
            if let problem = EngineKey.problem(in: text) {
                return .invalidValue(key: key, message: "\(key): \(problem.message)")
            }
        }
        return nil
    }

    /// The chords a binding value names, skipping text the engine drops. Returns `nil` for a value that is not a
    /// string or an array of strings.
    private static func chords(in value: TOMLValue?) -> [Chord]? {
        switch value {
        case .string, .array:
            texts(in: value).filter { EngineKey.problem(in: $0) == nil }.compactMap(Chord.init(exactEngineText:))
        default: nil
        }
    }

    private static func texts(in value: TOMLValue?) -> [String] {
        switch value {
        case .string(let text): [text]
        case .array(let items): items.compactMap { if case .string(let text) = $0 { text } else { nil } }
        default: []
        }
    }

    /// One chord as a string and several as an array, as Miri writes its defaults.
    private static func value(_ texts: [String]) -> TOMLValue {
        texts.count == 1 ? .string(texts[0]) : .array(texts.map(TOMLValue.string))
    }
}

extension DefaultBinding {
    static func row(for command: String) -> DefaultBinding? {
        table.first { EngineCommand.canonical($0.command) == command }
    }
}
