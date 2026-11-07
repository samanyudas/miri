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
        let host = NSHostingController(rootView: content.environment(\.presenter, self))
        // Settings and Set Up Miri draw under their title bars, so their sizes come from the design.
        let designSize: NSSize? =
            switch kind {
            case .settings: NSSize(width: 880, height: 640)
            case .initialSetup: NSSize(width: 600, height: 580)
            case .diagnostics, .permissionExperiment: nil
            }
        if designSize != nil { host.sizingOptions = [] }
        let window = NSWindow(contentViewController: host)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("Miri.\(kind)")
        if !window.setFrameUsingName("Miri.\(kind)") { window.center() }
        if let designSize {
            // The content runs under the title bar, so the window buttons sit on it, as in the design.
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            // The content covers the whole frame, so the frame is the design's size. Keep the saved top-left corner.
            var frame = window.frame
            frame.origin.y += frame.height - designSize.height
            frame.size = designSize
            window.setFrame(frame, display: false)
        }
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
