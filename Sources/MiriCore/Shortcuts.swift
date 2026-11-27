import Foundation

/// An action whose shortcuts the Shortcuts settings page edits.
public enum ShortcutAction: Hashable, Sendable {
    /// An engine command in the engine's own spelling, from `EngineCommand.canonical`.
    case engine(command: String)
    /// Stop window manager, which Miri registers itself from `[miri].stop_shortcut`.
    case stop

    /// Miri's actions in the keybinding reference's order, then Stop.
    public static let editable: [ShortcutAction] =
        DefaultBinding.table.map { .engine(command: EngineCommand.canonical($0.command)!) } + [.stop]

    /// Cycle preset widths forward, which the Layout settings page names below the width presets.
    public static let cyclePresetWidths = ShortcutAction.engine(command: EngineCommand.canonical("window_resize")!)

    private static let stopTitleResource = LocalizedStringResource("Stop window manager")

    public var title: String {
        switch self {
        case .engine(let command): DefaultBinding.row(for: command)?.action ?? command
        case .stop: String(localized: Self.stopTitleResource)
        }
    }

    var titleResource: LocalizedStringResource? {
        switch self {
        case .engine(let command): DefaultBinding.row(for: command)?.titleResource
        case .stop: Self.stopTitleResource
        }
    }
}

/// The binding that owns a shortcut: a listed action or an unlisted `[bindings]` key.
public enum ShortcutOwner: Hashable, Sendable {
    case action(ShortcutAction)
    case other(String)

    public var title: String {
        switch self {
        case .action(let action): action.title
        case .other(let key): key
        }
    }

    public var action: ShortcutAction? {
        if case .action(let action) = self { action } else { nil }
    }
}

/// Why Miri refused to add a shortcut. The file stays unchanged.
public enum ShortcutRejection: Error, Equatable, Sendable {
    case usedBy(ShortcutOwner)
    case alreadyAssigned
}

/// A default shortcut that an action lacks after an upgrade, because another binding holds it.
public struct KeptDefault: Hashable, Sendable {
    public let action: ShortcutAction
    /// The chords the action kept, which can be none.
    public let kept: [Chord]
    public let wanted: Chord
    public let owner: ShortcutOwner
}

public enum ShortcutEdit: Equatable, Sendable {
    case add(Chord, to: ShortcutAction)
    case remove(Chord, from: ShortcutAction)
    case move(Chord, from: ShortcutAction, to: ShortcutAction)
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

    let document: TOMLDocument
    let layout: KeyLayout
    /// The file's `[bindings]` keys for each listed command, sorted, so edits go to the spelling the user wrote.
    private let keysByCommand: [String: [String]]
    public let others: [OtherBinding]

    init(document: TOMLDocument, layout: KeyLayout = .positional) {
        self.layout = layout
        self.document = document
        var keysByCommand: [String: [String]] = [:]
        var others: [OtherBinding] = []
        let entries: [String: TOMLValue] =
            if case .table(let entries) = document.value(at: ["bindings"]) { entries } else { [:] }
        for key in entries.keys.sorted() {
            guard let command = EngineCommand.canonical(key) else { continue }
            if DefaultBinding.row(for: command) != nil {
                keysByCommand[command, default: []].append(key)
            } else if let chords = Self.chords(in: entries[key], layout: layout), !chords.isEmpty {
                others.append(OtherBinding(key: key, chords: chords))
            }
        }
        self.keysByCommand = keysByCommand
        self.others = others
    }

    public func chords(for action: ShortcutAction) -> [Chord] {
        switch action {
        case .engine(let command):
            (keysByCommand[command] ?? []).flatMap {
                Self.chords(in: document.value(at: ["bindings", $0]), layout: layout) ?? []
            }
        case .stop:
            document.value(at: ["miri", "stop_shortcut"]).map { Self.chords(in: $0, layout: layout) ?? [] } ?? [
                DefaultBinding.stopChord
            ]
        }
    }

    public func rejection(adding chord: Chord, to action: ShortcutAction) -> ShortcutRejection? {
        if chords(for: action).contains(where: { layout.conflicts($0, chord) }) { return .alreadyAssigned }
        for other in ShortcutAction.editable where other != action {
            if chords(for: other).contains(where: { layout.conflicts($0, chord) }) { return .usedBy(.action(other)) }
        }
        if let other = others.first(where: { $0.chords.contains { layout.conflicts($0, chord) } }) {
            return .usedBy(.other(other.key))
        }
        return nil
    }

    func adding(_ chord: Chord, to action: ShortcutAction) throws -> TOMLDocument {
        if let rejection = rejection(adding: chord, to: action) { throw rejection }
        switch action {
        case .engine(let command):
            guard let key = keysByCommand[command]?.first else {
                return try document.setting(
                    .string(chord.description), table: ["bindings"], key: DefaultBinding.row(for: command)!.command)
            }
            let texts = DefaultBinding.shortcutTexts(in: document.value(at: ["bindings", key])) + [chord.description]
            return try document.setting(DefaultBinding.encodedTexts(texts), table: ["bindings"], key: key)
        case .stop:
            let texts = chords(for: .stop).map(\.description) + [chord.description]
            return try document.setting(DefaultBinding.encodedTexts(texts), table: ["miri"], key: "stop_shortcut")
        }
    }

    /// Removes `chord` from `action`. The last engine chord removes the key, and the last Stop chord leaves
    /// `stop_shortcut = []`, because an absent key means the default.
    func removing(_ chord: Chord, from action: ShortcutAction) throws -> TOMLDocument {
        switch action {
        case .engine(let command):
            var result = document
            for key in keysByCommand[command] ?? [] {
                let texts = DefaultBinding.shortcutTexts(in: document.value(at: ["bindings", key]))
                let kept = texts.filter { Chord(exactEngineText: $0) != chord }
                guard kept.count < texts.count else { continue }
                result =
                    kept.isEmpty
                    ? try result.removing(table: ["bindings"], key: key)
                    : try result.setting(DefaultBinding.encodedTexts(kept), table: ["bindings"], key: key)
            }
            return result
        case .stop:
            let kept = chords(for: .stop).filter { $0 != chord }.map(\.description)
            return try document.setting(
                kept.isEmpty ? .array([]) : DefaultBinding.encodedTexts(kept), table: ["miri"], key: "stop_shortcut")
        }
    }

    /// Replaces `[bindings]` with exactly Miri's default set, restores the default Stop shortcut, and records the
    /// current defaults version, so a later upgrade offers only newer defaults.
    func resettingToDefaults() throws -> TOMLDocument {
        var result = document
        if case .table(let entries) = document.value(at: ["bindings"]) {
            for key in entries.keys.sorted() {
                result = try result.removing(table: ["bindings"], key: key)
            }
        } else if document.value(at: ["bindings"]) != nil {
            throw TOMLEditError.notEditable(path: "bindings")
        }
        for row in DefaultBinding.table where !row.chords.isEmpty {
            result = try result.setting(DefaultBinding.encoded(row.chords), table: ["bindings"], key: row.command)
        }
        result = try result.removing(table: ["miri"], key: "stop_shortcut")
        return try result.setting(
            .integer(Int64(DefaultBinding.currentVersion)), table: ["miri"], key: "default_bindings_version")
    }

    /// The Stop chords Miri registers. A `[bindings]` entry on the same keys wins, because the engine takes the key
    /// press first.
    func stopChordsToRegister() -> [Chord] {
        let engineChords =
            keysByCommand.values.joined().flatMap {
                Self.chords(in: document.value(at: ["bindings", $0]), layout: layout) ?? []
            }
            + others.flatMap(\.chords)
        return chords(for: .stop).filter { stop in !engineChords.contains { layout.conflicts($0, stop) } }
    }

    /// The problem with `[miri].stop_shortcut`, if any. Miri reads it itself, so the engine never reports it.
    static func stopShortcutIssue(in document: TOMLDocument, layout: KeyLayout = .positional) -> ConfigurationIssue? {
        let key = "miri.stop_shortcut"
        guard let value = document.value(at: ["miri", "stop_shortcut"]) else { return nil }
        let texts: [String]
        do {
            texts = try DefaultBinding.validateShortcutTexts(in: value, path: key)
        } catch {
            return error
        }
        for text in texts {
            if let problem = EngineKey.problem(in: text, layout: layout) {
                return .invalidValue(key: key, message: "\(key): \(problem.message)")
            }
        }
        return nil
    }

    /// The chords a binding value names, skipping text the engine drops. Returns `nil` for a value that is not a
    /// string or an array of strings.
    private static func chords(in value: TOMLValue?, layout: KeyLayout) -> [Chord]? {
        switch value {
        case .string, .array:
            DefaultBinding.shortcutTexts(in: value)
                .filter { EngineKey.problem(in: $0, layout: layout) == nil }
                .compactMap(Chord.init(exactEngineText:))
        default: nil
        }
    }
}

extension DefaultBinding {
    static func row(for command: String) -> DefaultBinding? {
        table.first { EngineCommand.canonical($0.command) == command }
    }
}
