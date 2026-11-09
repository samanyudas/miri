import AppKit
import MiriCore
import SwiftUI

extension AppModel {
    /// One line that says whether Miri is managing windows, and why not.
    var statusText: String {
        switch engineState {
        case .running: String(localized: "Managing windows")
        case .restarting: String(localized: "Restarting the engine…")
        case .failed: String(localized: "Stopped after engine failures")
        case .stopped:
            if let blocker = startBlockers.first {
                String(localized: "Waiting for setup: \(blocker.title)")
            } else {
                stoppedByUser ? String(localized: "Stopped by you") : String(localized: "Stopped")
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

/// Text that keeps VoiceOver current inside a control's label, such as a `Stepper` or a `LabeledContent`.
/// On macOS 27, such a control keeps the first accessibility value of its label, so this text restates its string as its value.
/// Use plain `Text` elsewhere: it updates by itself, and a restated value makes VoiceOver read the text twice.
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
            // When the engine exits, it moves each window it arranged back to its frame from before it started.
            Text("Windows open before Miri started go back to where they were.")
        case .failed:
            Button("Restart Engine") { model.restart() }
            Button("Show Logs in Finder") { model.showLogsInFinder() }
        case .stopped where !model.startBlockers.isEmpty:
            Button(setupCheckerTitle) { presenter.showSettings(.setup) }
            Button(AppModel.cancelAutomaticStartTitle) { model.stop() }
            Text(AppModel.startsWhenReadySentence)
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
        Button("Send Feedback…") { NSWorkspace.shared.open(Feedback.formList) }
        Divider()
        Button("Quit Miri") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Names how many setup checks to review, with the same count as the Setup badge in Settings.
    private var setupCheckerTitle: String {
        let count = model.setupReviewCount
        return count == 0
            ? String(localized: "Setup Checker…") : String(localized: "Setup Checker… (\(count) to review)")
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
            // When a translation is too long for one row, Refresh moves above the copy buttons instead of cutting them off.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button("Refresh") { refresh() }
                    Spacer()
                    copyButtons
                }
                VStack(alignment: .trailing, spacing: 10) {
                    Button("Refresh") { refresh() }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 10) { copyButtons }
                }
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

    @ViewBuilder private var copyButtons: some View {
        if copied {
            Label("Copied", systemImage: "checkmark")
                .font(.detail)
                .foregroundStyle(Palette.secondaryText)
        }
        // The person pastes the report into the form's diagnostics field, so Miri sends nothing itself.
        Button("Copy and Open Bug Report…") {
            copy()
            NSWorkspace.shared.open(Feedback.bugReport)
        }
        .fixedSize()
        Button("Copy to Clipboard") { copy() }
            .buttonStyle(.borderedProminent)
            .tint(Palette.accentFill)
            .keyboardShortcut(.defaultAction)
            .fixedSize()
    }

    private func refresh() {
        report = model.diagnostics()
        copied = false
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        copied = true
        AccessibilityNotification.Announcement(String(localized: "Copied to the clipboard")).post()
    }
}
