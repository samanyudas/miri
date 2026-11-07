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
            case .initialSetup: NSSize(width: 600, height: 540)
            case .diagnostics: NSSize(width: 640, height: 540)
            case .permissionExperiment: nil
            }
        if designSize != nil { host.sizingOptions = [] }
        let window = NSWindow(contentViewController: host)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("Miri.\(kind)")
        let restored = window.setFrameUsingName("Miri.\(kind)")
        if !restored { window.center() }
        if let designSize {
            // The content runs under the title bar, so the window buttons sit on it, as in the design.
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            // The content covers the whole frame, so the frame is the design's size. Keep the saved top-left corner.
            var size = designSize
            if kind == .settings {
                // Settings grows taller for long pages such as Shortcuts, and keeps the design's width.
                window.styleMask.insert(.resizable)
                window.contentMinSize = NSSize(width: designSize.width, height: 560)
                window.contentMaxSize = NSSize(width: designSize.width, height: .greatestFiniteMagnitude)
                // It opens at least as tall as the design, and keeps a taller height the user chose.
                if restored { size.height = max(window.frame.height, designSize.height) }
            }
            var frame = window.frame
            frame.origin.y += frame.height - size.height
            frame.size = size
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
