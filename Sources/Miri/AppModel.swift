import AppKit
import Carbon.HIToolbox
import MiriCore
import Observation
import ServiceManagement

/// The app's state: configuration, engine lifecycle, setup checks, and the saved stopped state.
@Observable final class AppModel {
    static let stoppedKey = "managementStopped"
    static let setupPollInterval: Duration = .seconds(2)

    let paths: EnginePaths
    let log: RotatingLog
    private(set) var engineState: EngineState = .stopped
    private(set) var settings = MiriSettings()
    private(set) var configurationIssue: ConfigurationIssue?
    private(set) var keyLayout: KeyLayout
    private(set) var setupChecks: [SetupCheck] = []
    /// Why management is not running when the user did not stop it, such as missing permission.
    private(set) var startBlockers: [SetupCheck] = []
    private(set) var loginItemError: String?
    /// The user's explicit Stop. It persists across launches until the user starts management again.
    private(set) var stoppedByUser: Bool

    @ObservationIgnored private let store: ConfigurationStore
    @ObservationIgnored private var supervisor: EngineSupervisor!
    @ObservationIgnored private var watcher: ConfigurationWatcher?
    @ObservationIgnored private var setupPoll: Task<Void, Never>?
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
        supervisor = EngineSupervisor(
            launcher: ProcessEngineLauncher(paths: paths, log: log),
            recoverWindows: { WindowRestorer.recover() })
        supervisor.onChange = { [weak self] state in self?.engineState = state }
    }

    var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Loads the configuration, watches it, and starts management unless the user stopped it.
    func launch() {
        stopShortcut = StopShortcut { [weak self] in self?.stopFromShortcut() }
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
        if !stoppedByUser { start() } else { refreshSetup() }
    }

    func reloadConfiguration() {
        store.load(reduceMotion: reduceMotion)
        settings = store.settings
        configurationIssue = store.issue
        stopShortcut?.register(store.stopChordsToRegister, layout: keyLayout)
    }

    private func keyboardLayoutChanged() {
        keyLayout = .current
        store.layout = keyLayout
        reloadConfiguration()
    }

    func update(_ change: (inout MiriSettings) -> Void) {
        do {
            try store.update(reduceMotion: reduceMotion, change)
            settings = store.settings
            configurationIssue = nil
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
        setupChecks = SetupChecker.evaluate(SetupProbe.observe())
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
        let revisionURL = Bundle.main.bundleURL.appending(path: "Contents/Resources/engine-revision.txt")
        let revision =
            (try? String(contentsOf: revisionURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
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
