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
        // A closed window keeps its frame on the display it was last on, so open it on the display in use.
        if !window.isVisible, let screen = NSScreen.main, window.screen != screen {
            let area = screen.visibleFrame
            window.setFrameOrigin(
                NSPoint(x: area.midX - window.frame.width / 2, y: area.midY - window.frame.height / 2))
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close(_ kind: Kind) {
        windows[kind]?.close()
    }

    private func makeWindow(_ kind: Kind) -> NSWindow {
        let (title, content): (String, AnyView) =
            switch kind {
            case .settings: (String(localized: "Miri Settings"), AnyView(SettingsView(model: model)))
            case .diagnostics: (String(localized: "Copy Diagnostics"), AnyView(DiagnosticsView(model: model)))
            case .permissionExperiment:
                (
                    String(localized: "Permission Experiment"),
                    AnyView(ExperimentView(experiment: experiment).frame(width: 560, height: 360))
                )
            case .initialSetup: (String(localized: "Set Up Miri"), AnyView(InitialSetupView(model: model)))
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
        // macOS keeps a closed window on its last desktop, and showing it again would switch the display back there.
        window.collectionBehavior.insert(.moveToActiveSpace)
        // Miri's windows stay above other apps' windows, like Picture-in-Picture, so a window that scrolls into view
        // or takes focus never covers them. The engine floats them, which keeps them out of the strip but not on top.
        window.level = .floating
        if designSize != nil || kind == .initialSetup {
            // The content runs under the title bar, so the window buttons sit on it, as in the design.
            // This comes before the restore: added after it, AppKit keeps the content size, and the saved frame
            // lost the 32-point title bar at every launch.
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
        let autosaveName = "Miri.\(kind)"  // Not interface text
        window.setFrameAutosaveName(autosaveName)
        let restored = window.setFrameUsingName(autosaveName)
        if !restored { window.center() }
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
