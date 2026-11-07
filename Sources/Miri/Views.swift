import AppKit
import MiriCore
import SwiftUI

extension AppModel {
    /// One line that says whether Miri is managing windows, and why not.
    var statusText: String {
        switch engineState {
        case .running: "Managing windows"
        case .restarting: "Restarting the engine…"
        case .failed: "Stopped after engine failures"
        case .stopped:
            if let blocker = startBlockers.first {
                "Waiting for setup: \(blocker.title)"
            } else {
                "Stopped"
            }
        }
    }

    var menuIcon: Image {
        switch engineState {
        case .running: .menuRunning
        case .restarting: .menuRunning
        case .failed: Image(systemName: "exclamationmark.triangle")
        case .stopped: startBlockers.isEmpty ? .menuStopped : Image(systemName: "exclamationmark.triangle")
        }
    }

    func showLogsInFinder() {
        NSApp.activate()
        NSWorkspace.shared.activateFileViewerSelecting([log.url])
    }
}

extension Image {
    fileprivate static let menuRunning = menuTemplate("menubar-icon")
    fileprivate static let menuStopped = menuTemplate("menubar-icon-stopped")

    private static func menuTemplate(_ name: String) -> Image {
        let image = NSImage(contentsOf: Bundle.main.url(forResource: name, withExtension: "svg")!)!
        image.isTemplate = true
        return Image(nsImage: image)
    }
}

/// Text that keeps VoiceOver current inside a `LabeledContent`.
/// On macOS 27, `LabeledContent` keeps the first accessibility value of its content, so this text restates its string as its value.
struct LiveText: View {
    let string: String

    init(_ string: String) {
        self.string = string
    }

    var body: some View {
        Text(string).accessibilityValue(string)
    }
}

/// The menu bar menu: what Miri is doing, the one action that changes it, and the ways into Settings.
struct MenuContent: View {
    let model: AppModel
    let presenter: WindowPresenter

    var body: some View {
        Text(model.statusText)
        if let issue = model.configurationIssue {
            Text(issue.menuSummary)
                .help(issue.description)
        }
        Divider()
        switch model.engineState {
        case .running, .restarting:
            Button("Restart Engine") { model.restart() }
                .disabled(!model.engineState.isRunning)
            Button("Stop Window Management") { model.stop() }
            Text("Your windows stay where they are.")
        case .failed:
            Button("Restart Engine") { model.restart() }
            Button("Show Logs in Finder") { model.showLogsInFinder() }
        case .stopped where !model.startBlockers.isEmpty:
            Button(setupCheckerTitle) { presenter.showSettings(.setup) }
            Text("Miri starts by itself when setup is done.")
            Button(AppModel.cancelAutomaticStartTitle) { model.stop() }
        case .stopped:
            Button("Start Window Management") { model.start() }
        }
        Divider()
        Button("Settings…") { presenter.show(.settings) }
            .keyboardShortcut(",")
        if model.startBlockers.isEmpty {
            Button(setupCheckerTitle) { presenter.showSettings(.setup) }
        }
        Button("Copy Diagnostics…") { presenter.show(.diagnostics) }
        Divider()
        Button("Quit Miri") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Names how many setup checks to review, with the same count as the Setup badge in Settings.
    private var setupCheckerTitle: String {
        let count = model.setupReviewCount
        return count == 0 ? "Setup Checker…" : "Setup Checker… (\(count) to review)"
    }
}

extension SetupCheck {
    /// A gesture check only looks for conflicts. Only a gesture test turns the swipe on, so it never says Passed.
    var isGestureCheck: Bool { id == .fourFingerGesture || id == .threeFingerGesture }

    /// Whether the check found something the user should look at.
    var needsAttention: Bool { status != .passed }
}

/// Previews the redacted report before anything reaches the clipboard.
struct DiagnosticsView: View {
    let model: AppModel
    @State private var report = ""
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Review the report before you copy it")
                    .font(.heroTitle)
                    .foregroundStyle(Palette.primaryText)
                    .accessibilityAddTraits(.isHeader)
                Text("Miri removes window titles, document paths, user names, and the configuration file.")
                    .font(.detail)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                Text(report)
                    .font(.mono)
                    .foregroundStyle(Palette.primaryText)
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(Palette.group, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.groupRing, lineWidth: 1))
            HStack(spacing: 10) {
                Button("Refresh") { refresh() }
                Spacer()
                if copied {
                    Label("Copied", systemImage: "checkmark")
                        .font(.detail)
                        .foregroundStyle(Palette.secondaryText)
                }
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report, forType: .string)
                    copied = true
                    AccessibilityNotification.Announcement("Copied to the clipboard").post()
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accentFill)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 44)
        .padding(.bottom, 20)
        // The window presenter sets the size, and the content runs under the title bar.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Palette.content)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        report = model.diagnostics()
        copied = false
    }
}
