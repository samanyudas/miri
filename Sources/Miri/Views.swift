import AppKit
import MiriCore
import SwiftUI

extension AppModel {
    /// One line that says whether Miri is managing windows, and why not.
    var statusText: String {
        switch engineState {
        case .running: "Managing windows"
        case .restarting: "Restarting the engine…"
        case .failed: "Stopped after repeated engine failures"
        case .stopped:
            if let blocker = startBlockers.first {
                "Waiting: \(blocker.title)"
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
            Button("Stop Window Management") { model.stop() }
            Text("Your windows stay where they are.")
            Button("Restart Engine") { model.restart() }
        case .failed:
            Button("Restart Engine") { model.restart() }
            Button("Show Logs in Finder") { model.showLogsInFinder() }
        case .stopped where !model.startBlockers.isEmpty:
            Button("Open Setup Checker…") { presenter.showSettings(.setup) }
            Button("Stop Window Management") { model.stop() }
            Text("Miri starts by itself when setup is done.")
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

    /// Names how many setup checks found a problem, as the Setup badge in Settings does.
    private var setupCheckerTitle: String {
        let problems = model.setupChecks.filter { if case .problem = $0.status { true } else { false } }.count
        return problems == 0 ? "Setup Checker…" : "Setup Checker… (\(problems) to review)"
    }
}

extension SetupCheck {
    /// A gesture check only looks for conflicts. Only a gesture test turns the swipe on, so it never says Passed.
    var isGestureCheck: Bool { id == .fourFingerGesture || id == .threeFingerGesture }
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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.primaryText)
                    .accessibilityAddTraits(.isHeader)
                Text("Miri removes window titles, document paths, user names, and the configuration file.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                Text(report)
                    .font(.system(size: 11.5, design: .monospaced))
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
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.secondaryText)
                }
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report, forType: .string)
                    copied = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 640, height: 520)
        .background(Palette.content)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        report = model.diagnostics()
        copied = false
    }
}
