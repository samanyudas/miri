import AppKit
import Carbon.HIToolbox
import MiriCore
import Observation
import ServiceManagement

@Observable final class AppModel {
    enum ScreenRecordingFeature: Hashable, CaseIterable {
        case sharedEdgeSlices
        case slideWindowPictures

        var keyPath: WritableKeyPath<MiriSettings, Bool> {
            switch self {
            case .sharedEdgeSlices: \.sharedEdgeSlices
            case .slideWindowPictures: \.slideWindowPictures
            }
        }
    }

    static let stoppedKey = "managementStopped"
    static let setupPollInterval: Duration = .seconds(2)
    static let gestureVerificationKey = "gestureVerification"
    static let initialSetupKey = "initialSetupDone"
    /// How often Miri rereads the macOS gesture settings while a strip swipe is selected.
    static let gesturePollInterval: Duration = .seconds(5)

    let paths: EnginePaths
    let log: RotatingLog
    private(set) var engineState: EngineState = .stopped
    /// The Dock icon follows every new value, from launch, a file edit, or Settings, so a login launch follows it too.
    private(set) var settings = MiriSettings() {
        didSet { showDockIcon(settings.showInDock) }
    }
    var settingsPage: SettingsView.Page {
        didSet { defaults.set(settingsPage.rawValue, forKey: SettingsView.pageKey) }
    }
    private(set) var screenNames: [String] = NSScreen.screens.map(\.localizedName)
    private(set) var configurationIssue: ConfigurationIssue?
    private(set) var shortcuts: Shortcuts?
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
    private(set) var gestureEnvironment: GestureEnvironment
    let engineRevision: String?
    private(set) var gestureTestFingers: GestureFingers?
    private var refusedScreenRecordingFeatures: Set<ScreenRecordingFeature> = []

    @ObservationIgnored private let store: ConfigurationStore
    @ObservationIgnored private var supervisor: EngineSupervisor!
    @ObservationIgnored private var watcher: ConfigurationWatcher?
    @ObservationIgnored private var setupPoll: Task<Void, Never>?
    @ObservationIgnored private var gesturePoll: Task<Void, Never>?
    @ObservationIgnored private let applicationShortcuts = ApplicationShortcuts()
    @ObservationIgnored private var findWindow: () -> Void = {}
    @ObservationIgnored private let defaults = UserDefaults.standard

    init(bundle: Bundle = .main) {
        let identifier = bundle.bundleIdentifier ?? "io.github.samanyudas.miri"
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Miri"  // Not interface text
        let support = URL.applicationSupportDirectory.appending(path: name, directoryHint: .isDirectory)
        paths = EnginePaths(
            executable: Self.engineExecutableURL(in: bundle), support: support,
            serviceName: identifier + ".engine")
        log = RotatingLog(url: paths.logs.appending(path: "engine.log"))
        let layout = KeyLayout.current
        keyLayout = layout
        store = ConfigurationStore(url: paths.configuration, appBundleIdentifier: identifier, layout: layout)
        settingsPage =
            defaults.string(forKey: SettingsView.pageKey).flatMap(SettingsView.Page.init(rawValue:)) ?? .general
        stoppedByUser = defaults.bool(forKey: Self.stoppedKey)
        gestureVerification = defaults.data(forKey: Self.gestureVerificationKey).flatMap {
            try? JSONDecoder().decode(GestureVerification.self, from: $0)
        }
        engineRevision = Self.bundledEngineRevision(in: bundle)
        gestureEnvironment = GestureEnvironment(
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            gestureSettings: GestureSettingsSnapshot(threeFingerSwipe: nil, fourFingerSwipe: nil, threeFingerDrag: nil))
        supervisor = EngineSupervisor(
            launcher: ProcessEngineLauncher(paths: paths, log: log),
            recoverWindows: { WindowRestorer.recover() })
        supervisor.onChange = { [weak self] state in self?.engineState = state }
        store.gestureFingers = { [weak self] settings in
            MainActor.assumeIsolated { self?.activeGestureFingers(for: settings) }
        }
    }

    static func engineExecutableURL(in bundle: Bundle = .main) -> URL {
        bundle.bundleURL.appending(path: "Contents/Helpers/miri-engine")
    }

    static func engineRevisionURL(in bundle: Bundle = .main) -> URL {
        bundle.bundleURL.appending(path: "Contents/Resources/engine-revision.txt")
    }

    static func bundledEngineRevision(in bundle: Bundle = .main) -> String? {
        (try? String(contentsOf: engineRevisionURL(in: bundle), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    func launch(findWindow: @escaping () -> Void) {
        self.findWindow = findWindow
        stopOrphanedEngines()
        // The first write of the file needs the gesture settings and conflicts, so the swipe stays on across launches.
        refreshSetup()
        reloadConfiguration()
        watcher = ConfigurationWatcher(url: paths.configuration) { [weak self] in self?.reloadConfiguration() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.reloadConfiguration() } }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.screenNames = NSScreen.screens.map(\.localizedName) } }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil,
            queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.keyboardLayoutChanged() } }
        syncLoginItem()
        watchGestureSettings()
        if !stoppedByUser { start() } else { refreshSetup() }
    }

    /// Stops engines that an earlier Miri left running when it died, then recovers the windows they managed.
    private func stopOrphanedEngines() {
        let orphans = OrphanedEngines.find()
        guard !orphans.isEmpty else { return }
        log.append(Data("--- Miri stopped engines left running without an app: \(orphans) ---\n".utf8))
        OrphanedEngines.stop(orphans, timeout: EngineSupervisor.stopTimeout)
        WindowRestorer.recover()
    }

    func reloadConfiguration() {
        store.load(reduceMotion: reduceMotion)
        settings = store.settings
        configurationIssue = store.issue
        shortcuts = store.shortcuts
        keptDefaults = store.keptDefaults
        registerApplicationShortcuts()
        dropStaleGestureVerification()
    }

    private func registerApplicationShortcuts() {
        let stop = store.stopChordsToRegister.map { chord -> (Chord, () -> Void) in
            (chord, { [weak self] in self?.stopFromShortcut() })
        }
        let find = store.findWindowChordsToRegister.map { ($0, findWindow) }
        applicationShortcuts.register(stop + find, layout: keyLayout)
    }

    private func keyboardLayoutChanged() {
        let layout = KeyLayout.current
        guard layout != keyLayout else { return }
        keyLayout = layout
        store.layout = layout
        reloadConfiguration()
        // The engine reads the layout only when it starts, so it restarts to bind the same keys as Stop and the recorder.
        if engineState.isRunning && !stoppedByUser { supervisor.restartManually() }
    }

    enum ShortcutAddOutcome {
        case added
        case rejected(ShortcutRejection)
        case systemConflict(SystemShortcut)
        /// The file could not be saved. `configurationIssue` says why.
        case failed
    }

    func addShortcut(_ chord: Chord, to action: ShortcutAction, allowingSystemConflict: Bool = false)
        -> ShortcutAddOutcome
    {
        guard let shortcuts else { return .failed }
        if let rejection = shortcuts.rejection(adding: chord, to: action) {
            return .rejected(rejection)
        }
        if !allowingSystemConflict,
            let conflict = SystemShortcuts.load(layout: keyLayout).conflict(for: chord)
        {
            return .systemConflict(conflict)
        }
        return apply(.add(chord, to: action))
    }

    func moveShortcut(
        _ chord: Chord, from owner: ShortcutAction, to action: ShortcutAction, allowingSystemConflict: Bool = false
    ) -> ShortcutAddOutcome {
        guard shortcuts != nil else { return .failed }
        if !allowingSystemConflict,
            let conflict = SystemShortcuts.load(layout: keyLayout).conflict(for: chord)
        {
            return .systemConflict(conflict)
        }
        return apply(.move(chord, from: owner, to: action))
    }

    func removeShortcut(_ chord: Chord, from action: ShortcutAction) {
        _ = apply(.remove(chord, from: action))
    }

    func resetShortcuts() {
        _ = apply(.resetToDefaults)
    }

    private func apply(_ edit: ShortcutEdit) -> ShortcutAddOutcome {
        do {
            try store.apply(edit)
            configurationIssue = nil
            shortcuts = store.shortcuts
            keptDefaults = store.keptDefaults
            registerApplicationShortcuts()
            return .added
        } catch let rejection as ShortcutRejection {
            return .rejected(rejection)
        } catch {
            let issue = error as? ConfigurationIssue ?? .notEditable(String(describing: error))
            reloadConfiguration()
            configurationIssue = configurationIssue ?? issue
            return .failed
        }
    }

    func update(_ change: (inout MiriSettings) -> Void) {
        do {
            try store.update(reduceMotion: reduceMotion, change)
            settings = store.settings
            configurationIssue = nil
            dropStaleGestureVerification()
        } catch {
            reloadConfiguration()
            configurationIssue = configurationIssue ?? error
        }
    }

    /// The app starts without a Dock icon, from `LSUIElement`, so a hidden icon never shows during a launch.
    private func showDockIcon(_ shown: Bool) {
        let policy: NSApplication.ActivationPolicy = shown ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        let wasActive = NSApp.isActive
        NSApp.setActivationPolicy(policy)
        // Hiding the icon from Settings must keep Settings in front. A file edit made in another app must not take focus.
        // The policy change can hand the front to another app, and the plain activate() did not take it back after an
        // Accessibility press, as VoiceOver sends.
        if wasActive { NSApp.activate(ignoringOtherApps: true) }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        update { $0.launchAtLogin = enabled }
        syncLoginItem()
    }

    func needsScreenRecordingPermission(_ feature: ScreenRecordingFeature) -> Bool {
        refusedScreenRecordingFeatures.contains(feature) && !settings[keyPath: feature.keyPath]
    }

    func setScreenRecordingFeature(_ feature: ScreenRecordingFeature, wanted: Bool) {
        let on = wanted && SetupProbe.requestScreenRecording()
        if wanted && !on {
            refusedScreenRecordingFeatures.insert(feature)
        } else {
            refusedScreenRecordingFeatures.remove(feature)
        }
        update { $0[keyPath: feature.keyPath] = on }
    }

    func refreshSetup() {
        if !SetupProbe.screenRecordingGranted {
            let revoked = ScreenRecordingFeature.allCases.filter { settings[keyPath: $0.keyPath] }
            if !revoked.isEmpty {
                refusedScreenRecordingFeatures.formUnion(revoked)
                update { settings in
                    for feature in revoked { settings[keyPath: feature.keyPath] = false }
                }
            }
        }
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

    // MARK: Initial setup

    /// Launch arguments win over saved defaults, so `-initialSetupDone NO` shows setup again after it was finished.
    var needsInitialSetup: Bool { !defaults.bool(forKey: Self.initialSetupKey) }

    func finishInitialSetup() {
        defaults.set(true, forKey: Self.initialSetupKey)
    }

    /// Selects four fingers unless the user already chose a finger count. This alone does not turn the swipe on. Only
    /// a confirmed gesture test, or a saved one that still matches, turns it on.
    func recommendStripGesture() {
        if settings.stripGesture == .off { update { $0.stripGesture = .four } }
    }

    // MARK: Strip gestures

    var gestureState: GestureState { gestureState(for: settings) }

    /// The setup check that reports macOS gestures clashing with a finger count, or `nil` before the first check.
    func gestureCheck(for fingers: GestureFingers) -> SetupCheck? {
        setupChecks.first { $0.id == fingers.setupCheck }
    }

    /// Why the gesture test cannot start, or `nil` when it can. Miri offers the test only when it cannot read the macOS
    /// gesture settings.
    var gestureTestBlocker: String? {
        guard engineState.isRunning else { return String(localized: "Start window management to test the swipe.") }
        return nil
    }

    enum GestureTestResult {
        /// The user confirmed the strip followed their fingers.
        case confirmed(GestureVerification)
        /// The test failed, was inconclusive, or the user said it did not work.
        case failed
        case cancelled
    }

    func beginGestureTest() throws(GestureTestBlocked) -> GestureVerification {
        refreshSetup()
        if let blocker = gestureTestBlocker { throw GestureTestBlocked(message: blocker) }
        // The settings can become readable while the test sheet is open, so a Try Again checks the state again.
        switch gestureState {
        case .needsTest: break
        case .conflict(let message): throw GestureTestBlocked(message: message)
        case .enabled:
            throw GestureTestBlocked(
                message: String(localized: "Miri checked your macOS trackpad gestures and found no conflict."))
        case .off:
            throw GestureTestBlocked(message: String(localized: "Choose three or four fingers to test the swipe."))
        }
        let fingers = settings.stripGesture.fingers!
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

    /// A change that needs a new test also ends the old result, so changing back cannot turn the swipe on untested.
    /// While the swipe is Off, the tested finger count stands in for it, so other changes made while Off still count.
    private func dropStaleGestureVerification() {
        guard let verification = gestureVerification else { return }
        let reason = verification.retestReason(
            fingers: settings.stripGesture.fingers ?? verification.fingers, reversed: settings.reverseSwipe,
            environment: gestureEnvironment)
        if reason != nil { saveGestureVerification(nil) }
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
            ?? .unableToVerify(String(localized: "Miri has not checked the macOS gesture settings yet."))
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
            let wrote = try store.applyGestureFingers(reduceMotion: reduceMotion)
            if wrote, store.issue == nil { configurationIssue = nil }
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
            if !engineState.isRunning { supervisor.stop() }
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
        stoppedByUser = false
        defaults.set(false, forKey: Self.stoppedKey)
        if engineState.isRunning { supervisor.restartManually() } else { start() }
    }

    /// Stops the engine and recovers windows before the app exits. It does not change the saved stopped state.
    func prepareToQuit(completion: @escaping () -> Void) {
        gesturePoll?.cancel()
        gesturePoll = nil
        cancelSetupPoll()
        supervisor.stop(completion: completion)
    }

    func diagnostics() -> String {
        refreshSetup()
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(Self.shortVersion) (\(info["CFBundleVersion"] as? String ?? "?"))"
        let main = NSScreen.screens.first
        let mainMaxY = main?.frame.maxY ?? 0
        let displays = NSScreen.screens.map { screen in
            let ax = SetupProbe.axFrame(for: screen.frame, mainMaxY: mainMaxY)
            return DiagnosticsReport.Display(
                width: Int(ax.width), height: Int(ax.height), scale: screen.backingScaleFactor,
                x: Int(ax.minX), y: Int(ax.minY), isMain: screen == main)
        }
        let report = DiagnosticsReport(
            appVersion: version, engineRevision: engineRevision ?? "unknown",
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString, architecture: "arm64",
            displays: displays, engineState: engineState, setupChecks: setupChecks,
            configurationIssue: configurationIssue, log: log.tail(maximum: 16_384))
        let redactor = Redactor(
            homeDirectory: NSHomeDirectory(), userNames: [NSUserName(), NSFullUserName()],
            sensitiveStrings: WindowRestorer.openWindowTitles())
        return report.rendered(with: redactor)
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

    /// Whether this copy of Miri runs from an Applications folder, where macOS can register it as a login item.
    static var isInApplicationsFolder: Bool {
        let applications = FileManager.default.urls(for: .applicationDirectory, in: .allDomainsMask)
        return applications.contains { Bundle.main.bundleURL.path.hasPrefix($0.path + "/") }
    }

    /// Registers the login item only from an Applications folder, so a build in a work folder never adds one.
    private func syncLoginItem() {
        let service = SMAppService.mainApp
        guard Self.isInApplicationsFolder else {
            loginItemError = String(
                localized: "Launch at login takes effect after you move Miri to the Applications folder.")
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
            loginItemError = String(localized: "Launch at login could not be changed. \(error.localizedDescription)")
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
    private var pendingReload: Task<Void, Never>?
    private var pendingReplace = false

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        watch()
    }

    deinit {
        pendingReload?.cancel()
        source?.cancel()
    }

    private func watch() {
        source?.cancel()
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            pendingReload?.cancel()
            pendingReload = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.watch()
            }
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .extend, .delete, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if !source.data.isDisjoint(with: [.delete, .rename]) {
                self.pendingReplace = true
            }
            self.pendingReload?.cancel()
            // Let the writer finish before reading.
            self.pendingReload = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                let replaced = self.pendingReplace
                self.pendingReplace = false
                if replaced { self.watch() }
                self.onChange()
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }
}
