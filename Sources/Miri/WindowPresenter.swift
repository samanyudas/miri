import AppKit
import MiriCore
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
        // Settings and Copy Diagnostics draw under their title bars at the design's size.
        // Set Up Miri draws under its title bar too, and takes the height of its content.
        let designSize: NSSize? =
            switch kind {
            case .settings: NSSize(width: 880, height: 640)
            case .diagnostics: NSSize(width: 640, height: 540)
            case .initialSetup, .permissionExperiment: nil
            }
        // A window never gets smaller than the design, which its pages are laid out for.
        // Settings grows for long pages such as Shortcuts, and a little wider for larger text.
        // Copy Diagnostics grows without a limit to show more of its long report.
        let maximumSize = NSSize(
            width: kind == .settings ? 1100 : CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let host: NSHostingController<AnyView>
        if let designSize {
            // The hosting controller sets the window's content size limits from these, and replaces any limits set on
            // the window itself. It adds the title bar's height to the view's, as the content runs under the title bar.
            let titleBar = NSWindow.frameRect(forContentRect: .zero, styleMask: .titled).height
            let limited = content.frame(
                minWidth: designSize.width, maxWidth: maximumSize.width,
                minHeight: designSize.height - titleBar, maxHeight: maximumSize.height)
            host = NSHostingController(rootView: AnyView(limited.environment(\.presenter, self)))
            host.sizingOptions = [.minSize, .maxSize]
        } else {
            host = NSHostingController(rootView: AnyView(content.environment(\.presenter, self)))
            host.sizingOptions = [.preferredContentSize]
        }
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
            // A new window opens at the design's size, and a reopened one keeps the size the user chose within the
            // limits. Both keep their top-left corner.
            var frame = window.frame
            if !restored {
                frame.origin.y += frame.height - designSize.height
                frame.size = designSize
            }
            window.setFrame(WindowSizeLimits.frame(frame, minimum: designSize, maximum: maximumSize), display: false)
            window.keepSize(minimum: designSize, maximum: maximumSize)
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

extension NSWindow {
    /// Resizes the window back within the size limits after any resize.
    /// AppKit applies a window's limits only when the user drags its edge. A resize through Accessibility, such as one
    /// from the engine or another window tool, sets any size and could make Settings too small for its layout.
    fileprivate func keepSize(minimum: NSSize, maximum: NSSize) {
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: self, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated {
                guard let window = self else { return }
                let limited = WindowSizeLimits.frame(window.frame, minimum: minimum, maximum: maximum)
                if limited != window.frame { window.setFrame(limited, display: true) }
            }
        }
    }
}

extension EnvironmentValues {
    @Entry var presenter: WindowPresenter?
}
