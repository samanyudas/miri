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
        // Settings and Copy Diagnostics draw under their title bars at the design's size.
        // Set Up Miri draws under its title bar too, and takes the height of its content.
        let designSize: NSSize? =
            switch kind {
            case .settings: NSSize(width: 880, height: 640)
            case .diagnostics: NSSize(width: 640, height: 540)
            case .initialSetup, .permissionExperiment: nil
            }
        host.sizingOptions = designSize == nil ? [.preferredContentSize] : []
        let window = NSWindow(contentViewController: host)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        // AppKit restores a saved size only on a resizable window, so these become resizable before the restore.
        if kind == .settings || kind == .diagnostics { window.styleMask.insert(.resizable) }
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("Miri.\(kind)")
        let restored = window.setFrameUsingName("Miri.\(kind)")
        if !restored { window.center() }
        if designSize != nil || kind == .initialSetup {
            // The content runs under the title bar, so the window buttons sit on it, as in the design.
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
        if let designSize {
            // The content covers the whole frame, so the frame is the design's size. Keep the saved top-left corner.
            var size = designSize
            if kind == .settings {
                // Settings grows for long pages such as Shortcuts, and a little wider for larger text.
                window.contentMinSize = NSSize(width: designSize.width, height: 560)
                window.contentMaxSize = NSSize(width: 1100, height: CGFloat.greatestFiniteMagnitude)
                // It opens at least the design's size, and keeps a larger size the user chose.
                if restored {
                    size.width = min(max(window.frame.width, designSize.width), 1100)
                    size.height = max(window.frame.height, designSize.height)
                }
            }
            if kind == .diagnostics {
                // The report is long, so Copy Diagnostics can grow to show more of it.
                window.contentMinSize = designSize
                if restored {
                    size.width = max(window.frame.width, designSize.width)
                    size.height = max(window.frame.height, designSize.height)
                }
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
