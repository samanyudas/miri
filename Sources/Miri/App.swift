import AppKit
import MiriCore
import SwiftUI

@main
struct MiriApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: delegate.model, presenter: delegate.presenter)
        } label: {
            Image(systemName: delegate.model.menuSymbol)
                .accessibilityLabel("Miri")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let experiment = PermissionExperiment()
    lazy var presenter = WindowPresenter(model: model, experiment: experiment)
    private var quitting = false
    private var terminationSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        quitOnTerminationSignal()
        let arguments = Array(CommandLine.arguments.dropFirst())
        // Arguments that start with a single dash are user defaults overrides, such as `-managementStopped YES`.
        guard let command = arguments.first, command.hasPrefix("--") else {
            model.launch()
            return
        }
        runSelftest(arguments)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { presenter.show(.settings) }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if case .checking = experiment.state {
            experiment.quit()
            return .terminateCancel
        }
        guard !quitting else { return .terminateLater }
        quitting = true
        model.prepareToQuit { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }

    /// `kill` sends SIGTERM, which by default ends the app at once, before the engine stops and windows recover.
    private func quitOnTerminationSignal() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        terminationSignal = source
    }

    /// Selftest commands for scripts/test-permission-prototype.sh and scripts/test-window-recovery.sh.
    private func runSelftest(_ arguments: [String]) {
        guard arguments.count == 4, ["--permission-observation", "--recovery-selftest"].contains(arguments[0]),
            arguments[2] == "--target-pid", let pid = Int32(arguments[3]), pid > 0
        else {
            exit(2)
        }
        NSApplication.shared.setActivationPolicy(.accessory)
        let destination = URL(fileURLWithPath: arguments[1])
        if arguments[0] == "--recovery-selftest" {
            do {
                try JSONEncoder().encode(RecoverySelftest.run(targetPid: pid)).write(to: destination, options: .atomic)
            } catch { exit(1) }
            exit(0)
        }
        do {
            try Data(String(getpid()).utf8).write(to: destination.appendingPathExtension("pid"), options: .atomic)
        } catch { exit(1) }
        experiment.check(targetPid: pid) { result in
            do {
                let data: Data
                switch result {
                case .success(let report): data = try JSONEncoder().encode(report)
                case .failure(let error):
                    data = try JSONSerialization.data(withJSONObject: [
                        "schemaVersion": 1, "failure": error.localizedDescription,
                        "appPid": getpid(), "permissionAttribution": "unresolved",
                    ])
                }
                try data.write(to: destination, options: .atomic)
            } catch {
                exit(1)
            }
            exit(0)
        }
    }
}
