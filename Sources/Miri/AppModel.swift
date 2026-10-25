import AppKit
import Carbon.HIToolbox
import MiriCore
import Observation
import ServiceManagement

/// The app's state: configuration, engine lifecycle, setup checks, and the saved stopped state.
@Observable final class AppModel {
    static let stoppedKey = "managementStopped"
    static let setupPollInterval: Duration = .seconds(2)
    static let gestureVerificationKey = "gestureVerification"
    /// How often Miri rereads the macOS gesture settings while a strip swipe is selected.
    static let gesturePollInterval: Duration = .seconds(5)

    let paths: EnginePaths
    let log: RotatingLog
    private(set) var engineState: EngineState = .stopped
    private(set) var settings = MiriSettings()
    private(set) var configurationIssue: ConfigurationIssue?
    /// The file's shortcuts, or `nil` while the file cannot be read correctly.
    private(set) var shortcuts: Shortcuts?
    /// The defaults the last upgrade could not move to their new shortcut.
    private(set) var keptDefaults: [KeptDefault] = []
    private(set) var keyLayout: KeyLayout
    private(set) var setupChecks: [SetupCheck] = []
    /// Why management is not running when the user did not stop it, such as missing permission.
    private(set) var startBlockers: [SetupCheck] = []
    private(set) var loginItemError: String?
    /// The user's explicit Stop. It persists across launches until the user starts management again.
    private(set) var stoppedByUser: Bool
    /// The confirmed gesture test. It is app state, so editing the configuration file cannot mark a swipe as tested.
    private(set) var gestureVerification: GestureVerification?
    /// The macOS version, engine revision, and macOS gesture settings that a gesture test result depends on.
    private(set) var gestureEnvironment: GestureEnvironment
    /// The finger count a running gesture test turned on.
    private(set) var gestureTestFingers: GestureFingers?

    @ObservationIgnored private let store: ConfigurationStore
    @ObservationIgnored private var supervisor: EngineSupervisor!
    @ObservationIgnored private var watcher: ConfigurationWatcher?
    @ObservationIgnored private var setupPoll: Task<Void, Never>?
    @ObservationIgnored private var gesturePoll: Task<Void, Never>?
    @ObservationIgnored private var stopShortcut: StopShortcut?
    @ObservationIgnored private let defaults = UserDefaults.standard

    init(bundle: Bundle = .main) {
        let identifier = bundle.bundleIdentifier ?? "io.github.samanyudas.miri"
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Miri"
        let support = URL.applicationSupportDirectory.appending(path: name, directoryHint: .isDirectory)
        paths = EnginePaths(
            executable: bundle.bundleURL.appending(path: "Contents/Helpers/miri-engine"), support: support,
            serviceName: identifier + ".engine")
        log = RotatingLog(url: paths.logs.appending(path: "engine.log"))
        let layout = KeyLayout.current
        keyLayout = layout
        store = ConfigurationStore(url: paths.configuration, appBundleIdentifier: identifier, layout: layout)
        stoppedByUser = UserDefaults.standard.bool(forKey: Self.stoppedKey)
        gestureVerification = UserDefaults.standard.data(forKey: Self.gestureVerificationKey).flatMap {
            try? JSONDecoder().decode(GestureVerification.self, from: $0)
        }
        gestureEnvironment = GestureEnvironment(
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            engineRevision: Self.engineRevision(bundle: bundle),
            gestureSettings: GestureSettingsSnapshot(threeFingerSwipe: nil, fourFingerSwipe: nil, threeFingerDrag: nil))
        supervisor = EngineSupervisor(
            launcher: ProcessEngineLauncher(paths: paths, log: log),
            recoverWindows: { WindowRestorer.recover() })
        supervisor.onChange = { [weak self] state in self?.engineState = state }
        store.gestureFingers = { [weak self] settings in
            MainActor.assumeIsolated { self?.activeGestureFingers(for: settings) }
        }
    }

    var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Loads the configuration, watches it, and starts management unless the user stopped it.
    func launch() {
        stopShortcut = StopShortcut { [weak self] in self?.stopFromShortcut() }
        // The first write of the file needs the gesture settings and conflicts, so the swipe stays on across launches.
        refreshSetup()
        reloadConfiguration()
        watcher = ConfigurationWatcher(url: paths.configuration) { [weak self] in self?.reloadConfiguration() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.reloadConfiguration() } }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil,
            queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.keyboardLayoutChanged() } }
        syncLoginItem()
        watchGestureSettings()
        if !stoppedByUser { start() } else { refreshSetup() }
    }

    func reloadConfiguration() {
        store.load(reduceMotion: reduceMotion)
        settings = store.settings
        configurationIssue = store.issue
        shortcuts = store.shortcuts
        keptDefaults = store.keptDefaults
        stopShortcut?.register(store.stopChordsToRegister, layout: keyLayout)
        dropStaleGestureVerification()
    }

    private func keyboardLayoutChanged() {
        let layout = KeyLayout.current
        guard layout != keyLayout else { return }
        keyLayout = layout
        store.layout = layout
        reloadConfiguration()
        // The engine reads the layout only when it starts, so it restarts to bind the same keys as Stop and the recorder.
        if engineState.isRunning { supervisor.restartManually() }
    }

    enum ShortcutAddOutcome {
        case added
        case rejected(ShortcutRejection)
        case systemConflict(SystemShortcut)
        /// The file could not be saved. `configurationIssue` says why.
        case failed
    }

    /// Adds a shortcut unless another Miri binding uses its keys. A macOS conflict needs `allowingSystemConflict`.
    func addShortcut(_ chord: Chord, to action: ShortcutAction, allowingSystemConflict: Bool = false)
        -> ShortcutAddOutcome
    {
        guard let shortcuts else { return .failed }
        if let rejection = shortcuts.rejection(adding: chord, to: action, layout: keyLayout) {
            return .rejected(rejection)
        }
        if !allowingSystemConflict,
            let conflict = SystemShortcuts.load(layout: keyLayout).conflict(for: chord, layout: keyLayout)
        {
            return .systemConflict(conflict)
        }
        return apply(.add(chord, to: action)) ? .added : .failed
    }

    func removeShortcut(_ chord: Chord, from action: ShortcutAction) {
        apply(.remove(chord, from: action))
    }

    func resetShortcuts() {
        apply(.resetToDefaults)
    }

    @discardableResult private func apply(_ edit: ShortcutEdit) -> Bool {
        do {
            try store.apply(edit)
            configurationIssue = nil
            shortcuts = store.shortcuts
            keptDefaults = store.keptDefaults
            stopShortcut?.register(store.stopChordsToRegister, layout: keyLayout)
            return true
        } catch {
            let issue = error as? ConfigurationIssue ?? .notEditable(String(describing: error))
            reloadConfiguration()
            configurationIssue = configurationIssue ?? issue
            return false
        }
    }

    func update(_ change: (inout MiriSettings) -> Void) {
        do {
            try store.update(reduceMotion: reduceMotion, change)
            settings = store.settings
            configurationIssue = nil
            dropStaleGestureVerification()
        } catch {
            configurationIssue = error
            reloadConfiguration()
            configurationIssue = configurationIssue ?? error
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        update { $0.launchAtLogin = enabled }
        syncLoginItem()
    }

    func refreshSetup() {
        let observation = SetupProbe.observe()
        let checks = SetupChecker.evaluate(observation)
        if checks != setupChecks { setupChecks = checks }
        let gestureSettings = GestureSettingsSnapshot(observation)
        if gestureSettings != gestureEnvironment.gestureSettings {
            gestureEnvironment.gestureSettings = gestureSettings
        }
        dropStaleGestureVerification()
        applyGestureFingers()
    }

    // MARK: Strip gestures

    var gestureState: GestureState { gestureState(for: settings) }

    /// The setup check that reports macOS gestures clashing with a finger count, or `nil` before the first check.
    func gestureCheck(for fingers: GestureFingers) -> SetupCheck? {
        setupChecks.first { $0.id == fingers.setupCheck }
    }

    /// Why the gesture test cannot start, or `nil` when it can.
    var gestureTestBlocker: String? {
        guard engineState.isRunning else { return "Start window management to test the swipe." }
        guard settings.stripGesture != .off else { return "Choose three or four fingers to test the swipe." }
        if case .conflict = gestureState { return "Change the macOS gesture setting before testing the swipe." }
        return nil
    }

    enum GestureTestResult {
        /// The user confirmed the strip followed their fingers.
        case confirmed(GestureVerification)
        /// The test failed, was inconclusive, or the user said it did not work.
        case failed
        case cancelled
    }

    /// Turns on the selected swipe for a test. Returns the result to save if the user confirms it, dated now.
    func beginGestureTest() throws(GestureTestBlocked) -> GestureVerification {
        refreshSetup()
        if let blocker = gestureTestBlocker { throw GestureTestBlocked(message: blocker) }
        guard let fingers = settings.stripGesture.fingers else {
            throw GestureTestBlocked(message: "Choose three or four fingers to test the swipe.")
        }
        gestureTestFingers = fingers
        applyGestureFingers()
        return GestureVerification(
            fingers: fingers, reversed: settings.reverseSwipe, environment: gestureEnvironment, date: .now)
    }

    /// Ends a gesture test. The swipe stays on only when the saved result turns it on.
    func finishGestureTest(_ result: GestureTestResult) {
        gestureTestFingers = nil
        switch result {
        case .confirmed(let verification): saveGestureVerification(verification)
        case .failed: saveGestureVerification(nil)
        case .cancelled: applyGestureFingers()
        }
    }

    /// The user says a relevant macOS gesture changed, so the last test no longer counts.
    func reportGestureChange() {
        saveGestureVerification(nil)
    }

    /// A change that needs a new test also ends the old result, so changing back cannot turn the swipe on untested.
    /// A conflict is ignored here, because it blocks the swipe without saying whether the tested setup changed. While
    /// the swipe is Off, the tested finger count stands in for it, so other changes made while Off still count.
    private func dropStaleGestureVerification() {
        guard let verification = gestureVerification else { return }
        let tested: StripGesture = verification.fingers == .three ? .three : .four
        guard
            case .needsTest = GestureState.evaluate(
                preference: settings.stripGesture == .off ? tested : settings.stripGesture,
                reversed: settings.reverseSwipe, verification: verification, environment: gestureEnvironment,
                conflict: .passed)
        else { return }
        saveGestureVerification(nil)
    }

    private func saveGestureVerification(_ verification: GestureVerification?) {
        gestureVerification = verification
        if let verification, let data = try? JSONEncoder().encode(verification) {
            defaults.set(data, forKey: Self.gestureVerificationKey)
        } else {
            defaults.removeObject(forKey: Self.gestureVerificationKey)
        }
        applyGestureFingers()
    }

    private func gestureState(for settings: MiriSettings) -> GestureState {
        let conflict =
            settings.stripGesture.fingers.flatMap { gestureCheck(for: $0)?.status }
            ?? .unableToVerify("Miri has not checked the macOS gesture settings yet.")
        return GestureState.evaluate(
            preference: settings.stripGesture, reversed: settings.reverseSwipe, verification: gestureVerification,
            environment: gestureEnvironment, conflict: conflict)
    }

    private func activeGestureFingers(for settings: MiriSettings) -> GestureFingers? {
        if let gestureTestFingers { return gestureTestFingers }
        return gestureState(for: settings).isEnabled ? settings.stripGesture.fingers : nil
    }

    private func applyGestureFingers() {
        do {
            try store.applyGestureFingers(reduceMotion: reduceMotion)
        } catch {
            configurationIssue = error
        }
    }

    /// Rereads the macOS gesture settings while a swipe is selected, so a change made in System Settings turns the
    /// swipe off without waiting for a relaunch.
    private func watchGestureSettings() {
        gesturePoll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.gesturePollInterval)
                guard let self else { return }
                if self.settings.stripGesture != .off { self.refreshSetup() }
            }
        }
    }

    /// Starts management, or waits and rechecks while a setup problem blocks it.
    func start() {
        stoppedByUser = false
        defaults.set(false, forKey: Self.stoppedKey)
        refreshSetup()
        startBlockers = setupChecks.filter(\.isBlocking)
        guard startBlockers.isEmpty else {
            pollSetupUntilReady()
            return
        }
        setupPoll?.cancel()
        setupPoll = nil
        if engineState.isRunning { return }
        reloadConfiguration()
        supervisor.restartManually()
    }

    func stop() {
        stoppedByUser = true
        defaults.set(true, forKey: Self.stoppedKey)
        cancelSetupPoll()
        supervisor.stop()
    }

    func stopFromShortcut() {
        guard !stoppedByUser else { return }
        stop()
    }

    func restart() {
        if engineState.isRunning { supervisor.restartManually() } else { start() }
    }

    /// Stops the engine and recovers windows before the app exits. It does not change the saved stopped state.
    func prepareToQuit(completion: @escaping () -> Void) {
        cancelSetupPoll()
        supervisor.stop(completion: completion)
    }

    func diagnostics() -> String {
        refreshSetup()
        let info = Bundle.main.infoDictionary ?? [:]
        let version =
            "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
        let revision = gestureEnvironment.engineRevision
        let main = NSScreen.screens.first
        let displays = NSScreen.screens.map { screen in
            DiagnosticsReport.Display(
                width: Int(screen.frame.width), height: Int(screen.frame.height), scale: screen.backingScaleFactor,
                x: Int(screen.frame.minX), y: Int((main?.frame.maxY ?? 0) - screen.frame.maxY), isMain: screen == main)
        }
        let report = DiagnosticsReport(
            appVersion: version, engineRevision: revision,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString, architecture: "arm64",
            displays: displays, engineState: engineState, setupChecks: setupChecks,
            configurationIssue: configurationIssue, log: log.tail(maximum: 16_384))
        let redactor = Redactor(
            homeDirectory: NSHomeDirectory(), userNames: [NSUserName(), NSFullUserName()],
            sensitiveStrings: WindowRestorer.openWindowTitles())
        return report.rendered(with: redactor)
    }

    private static func engineRevision(bundle: Bundle) -> String {
        let url = bundle.bundleURL.appending(path: "Contents/Resources/engine-revision.txt")
        return (try? String(contentsOf: url, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "unknown"
    }

    private func pollSetupUntilReady() {
        guard setupPoll == nil else { return }
        setupPoll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.setupPollInterval)
                guard let self, !Task.isCancelled, !self.stoppedByUser else { return }
                self.refreshSetup()
                self.startBlockers = self.setupChecks.filter(\.isBlocking)
                if self.startBlockers.isEmpty {
                    self.setupPoll = nil
                    self.start()
                    return
                }
            }
        }
    }

    private func cancelSetupPoll() {
        setupPoll?.cancel()
        setupPoll = nil
        startBlockers = []
    }

    /// Registers the login item only from an Applications folder, so a build in a work folder never adds one.
    private func syncLoginItem() {
        let service = SMAppService.mainApp
        let applications = FileManager.default.urls(for: .applicationDirectory, in: .allDomainsMask)
        guard applications.contains(where: { Bundle.main.bundleURL.path.hasPrefix($0.path + "/") }) else {
            loginItemError = "Launch at login takes effect after you move Miri to the Applications folder."
            return
        }
        do {
            if settings.launchAtLogin, service.status != .enabled {
                try service.register()
            } else if !settings.launchAtLogin, service.status == .enabled {
                try service.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Launch at login could not be changed. \(error.localizedDescription)"
        }
    }
}

struct GestureTestBlocked: Error {
    let message: String
}

/// Calls `onChange` after the file is written, replaced, or deleted. It reopens the file after atomic replacement.
final class ConfigurationWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        watch()
    }

    deinit { source?.cancel() }

    private func watch() {
        source?.cancel()
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.watch() }
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .extend, .delete, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let replaced = !source.data.isDisjoint(with: [.delete, .rename])
            // Let the writer finish before reading.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if replaced { self.watch() }
                self.onChange()
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }
}
