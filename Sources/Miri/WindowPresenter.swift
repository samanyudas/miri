import AppKit
import SwiftUI

/// Opens Miri's windows. AppKit owns them, so the menu bar, a Dock reopen, and code all open the same window.
final class WindowPresenter {
    enum Kind { case settings, diagnostics, permissionExperiment, initialSetup }

    private let model: AppModel
    private let experiment: PermissionExperiment
    private var windows: [Kind: NSWindow] = [:]
    private var terminating = false

    init(model: AppModel, experiment: PermissionExperiment) {
        self.model = model
        self.experiment = experiment
        // AppKit closes every open window after it posts this, and a quit must not count as finishing initial setup.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.terminating = true } }
    }

    func show(_ kind: Kind) {
        let window = windows[kind] ?? makeWindow(kind)
        windows[kind] = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close(_ kind: Kind) {
        windows[kind]?.close()
    }

    private func makeWindow(_ kind: Kind) -> NSWindow {
        let (title, content): (String, AnyView) =
            switch kind {
            case .settings: ("Miri Settings", AnyView(SettingsView(model: model)))
            case .diagnostics: ("Copy Diagnostics", AnyView(DiagnosticsView(model: model)))
            case .permissionExperiment:
                (
                    "Permission Experiment",
                    AnyView(ExperimentView(experiment: experiment).frame(width: 560, height: 360))
                )
            case .initialSetup: ("Set Up Miri", AnyView(InitialSetupView(model: model)))
            }
        let window = NSWindow(
            contentViewController: NSHostingController(rootView: content.environment(\.presenter, self)))
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("Miri.\(kind)")
        if !window.setFrameUsingName("Miri.\(kind)") { window.center() }
        if kind == .initialSetup {
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, !self.terminating else { return }
                    self.model.finishInitialSetup()
                }
            }
        }
        return window
    }
}

extension EnvironmentValues {
    @Entry var presenter: WindowPresenter?
}
