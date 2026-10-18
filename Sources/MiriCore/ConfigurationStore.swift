import Foundation

/// Owns Miri's configuration file: creates it, reads it, and writes changes without touching anything else in it.
///
/// After any failure the store keeps the last valid settings. It never writes to a file it could not read correctly.
public final class ConfigurationStore {
    public static let header = """
        # Miri configuration.
        # Miri Settings writes this file, and you can also edit it by hand. Valid edits apply immediately.
        # Paneru keys keep their Paneru names. Miri-only settings are in [miri].
        # Miri derives [padding] and [windows.miri-gaps] from miri.inner_gap and miri.outer_gap.
        # [windows.miri-settings] keeps Miri's own windows floating.
        # [decorations.menu] hides the engine's menu bar item, because Miri has its own.
        # [bindings] starts with Miri's default shortcuts. Miri never changes a shortcut you set.
        # miri.default_bindings_version records which defaults Miri has offered, so a shortcut you delete stays deleted.
        # Miri owns [swipe.gesture]. fingers_count is present only while a tested strip swipe is on or being tested.

        """

    public let url: URL
    public let appBundleIdentifier: String
    public private(set) var settings = MiriSettings()
    public private(set) var issue: ConfigurationIssue?
    /// The keyboard layout that decides which chords press the same keys.
    public var layout: KeyLayout
    /// The strip swipe the engine should intercept for given settings, or `nil` for none. The app sets it, because
    /// the answer depends on the gesture test result and setup checks, which live outside the file.
    public var gestureFingers: (MiriSettings) -> GestureFingers? = { _ in nil }
    /// The finger count of the last write, so a change to it alone still reaches the file.
    private var writtenGestureFingers: GestureFingers?
    /// The Stop shortcuts Miri registers: `[miri].stop_shortcut` without the chords a `[bindings]` entry uses.
    /// When the engine would reject `[bindings]`, this keeps its previous value, as the engine keeps its old bindings.
    public private(set) var stopChordsToRegister = [DefaultBinding.stopChord]
    /// The current file, when it was read correctly. Writes require it.
    private var document: TOMLDocument?

    public init(url: URL, appBundleIdentifier: String, layout: KeyLayout = .positional) {
        self.url = url
        self.appBundleIdentifier = appBundleIdentifier
        self.layout = layout
    }

    /// The shortcuts in the file, when it was read correctly.
    public var shortcuts: Shortcuts? { document.map(Shortcuts.init) }

    /// Reads the file, creating it with defaults when it is missing, then writes any derived engine keys it lacks.
    public func load(reduceMotion: Bool) {
        document = nil
        let text: String
        do {
            text = try read()
        } catch {
            issue = error
            return
        }
        do throws(ConfigurationIssue) {
            let parsed: TOMLDocument
            do { parsed = try TOMLDocument(text) } catch { throw .invalidTOML(error) }
            let bindings = DefaultBinding.inspect(in: parsed)
            let stopIssue = Shortcuts.stopShortcutIssue(in: parsed)
            if case .usable = bindings, stopIssue == nil {
                stopChordsToRegister = Shortcuts(document: parsed).stopChordsToRegister(layout: layout)
            }
            let read = try MiriSettings(document: parsed)
            if let issue = bindings.issue ?? stopIssue { throw issue }
            document = parsed
            settings = read
            issue = nil
            try write(read, reduceMotion: reduceMotion)
        } catch {
            issue = error
        }
    }

    /// Validates and saves a change. On failure the file and the current settings stay unchanged.
    public func update(reduceMotion: Bool, _ change: (inout MiriSettings) -> Void) throws(ConfigurationIssue) {
        var changed = settings
        change(&changed)
        try changed.validate()
        guard document != nil else { throw issue ?? .unreadable("Reload the file and try again.") }
        try write(changed, reduceMotion: reduceMotion, replacing: settings)
        settings = changed
    }

    /// Writes `[swipe.gesture].fingers_count` when `gestureFingers` now gives a different answer.
    public func applyGestureFingers(reduceMotion: Bool) throws(ConfigurationIssue) {
        guard document != nil, gestureFingers(settings) != writtenGestureFingers else { return }
        try write(settings, reduceMotion: reduceMotion, replacing: settings)
    }

    /// Saves a change to the shortcuts. Throws `ShortcutRejection` when the chord is taken, or `ConfigurationIssue`.
    /// On failure the file stays unchanged. A reset backs up the file before replacing `[bindings]`.
    public func apply(_ edit: ShortcutEdit) throws {
        guard let current = document else {
            throw issue ?? ConfigurationIssue.unreadable("Reload the file and try again.")
        }
        let shortcuts = Shortcuts(document: current)
        let next: TOMLDocument
        do {
            switch edit {
            case .add(let chord, let action): next = try shortcuts.adding(chord, to: action, layout: layout)
            case .remove(let chord, let action): next = try shortcuts.removing(chord, from: action)
            case .resetToDefaults: next = try shortcuts.resettingToDefaults()
            }
        } catch let error as TOMLEditError {
            throw ConfigurationIssue.notEditable(error.description)
        }
        try commit(next, replacing: current, backingUpBefore: edit == .resetToDefaults ? "resetting shortcuts" : nil)
        issue = nil
        stopChordsToRegister = Shortcuts(document: next).stopChordsToRegister(layout: layout)
    }

    private func read() throws(ConfigurationIssue) -> String {
        let manager = FileManager.default
        if !manager.fileExists(atPath: url.path) {
            do {
                try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(Self.header.utf8).write(to: url, options: .withoutOverwriting)
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                // Another writer created it first. Read that file.
            } catch {
                throw .unwritable(error.localizedDescription)
            }
        }
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw .unreadable(error.localizedDescription) }
        guard let text = String(data: data, encoding: .utf8) else {
            throw .unreadable("The file is not UTF-8 text.")
        }
        return text
    }

    /// Writes `settings` into the file. A key the file defines in a form Miri does not rewrite is left alone, unless
    /// writing it is what changing `previous` to `settings` needs, in which case the save fails and names the key.
    ///
    /// Without `previous`, as on load, a skipped engine key means a setting is not in effect, so Miri reports it and
    /// writes nothing. The engine reads every table except `[miri]`.
    private func write(_ settings: MiriSettings, reduceMotion: Bool, replacing previous: MiriSettings? = nil)
        throws(ConfigurationIssue)
    {
        guard let current = document else { return }
        let fingers = gestureFingers(settings)
        let next: TOMLDocument
        do {
            let applied = try settings.applying(
                to: current, reduceMotion: reduceMotion, appBundleIdentifier: appBundleIdentifier, layout: layout,
                gestureFingers: fingers)
            if let previous {
                let before = try previous.applying(
                    to: current, reduceMotion: reduceMotion, appBundleIdentifier: appBundleIdentifier, layout: layout,
                    gestureFingers: writtenGestureFingers)
                // A key skipped both times still needs a write when the value Miri wants there changed.
                let needed = applied.skipped.filter { path, wanted in
                    before.skipped[path].map { $0 != wanted } ?? true
                }
                if let path = needed.keys.sorted().first {
                    throw TOMLEditError.notEditable(path: path)
                }
            } else if let path = applied.skipped.keys.filter({ !$0.hasPrefix("miri.") }).sorted().first {
                throw TOMLEditError.notEditable(path: path)
            }
            next = applied.document
        } catch let error as TOMLEditError {
            throw .notEditable(error.description)
        } catch let error as ConfigurationIssue {
            throw error
        } catch {
            throw .notEditable(String(describing: error))
        }
        let versionPath = ["miri", "default_bindings_version"]
        let upgrades = current.value(at: versionPath) != next.value(at: versionPath)
        try commit(next, replacing: current, backingUpBefore: upgrades ? "upgrading it" : nil)
        writtenGestureFingers = fingers
    }

    /// Replaces the file with `next`, after backing up `current` when `backupReason` names why.
    private func commit(_ next: TOMLDocument, replacing current: TOMLDocument, backingUpBefore backupReason: String?)
        throws(ConfigurationIssue)
    {
        guard next.text != current.text else { return }
        // Refuse to replace a file that changed since Miri read it. The file watcher reloads it instead.
        guard (try? String(contentsOf: url, encoding: .utf8)) == current.text else {
            throw .unwritable("The file changed while Miri was saving. Miri reloaded it. Try again.")
        }
        if let backupReason { try backUp(current, before: backupReason) }
        do {
            try Data(next.text.utf8).write(to: url, options: .atomic)
        } catch {
            throw .unwritable(error.localizedDescription)
        }
        document = next
    }

    private func backUp(_ document: TOMLDocument, before reason: String) throws(ConfigurationIssue) {
        do {
            let backups = url.appendingPathExtension("backups")
            try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
            let backup = backups.appendingPathComponent(UUID().uuidString).appendingPathExtension("toml")
            try Data(document.text.utf8).write(to: backup, options: .withoutOverwriting)
        } catch {
            throw .unwritable(
                "Miri could not back up the configuration before \(reason). \(error.localizedDescription)")
        }
    }
}
