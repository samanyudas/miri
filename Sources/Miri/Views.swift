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

/// Shows a configuration problem above the settings it affects.
struct ConfigurationIssueBanner: View {
    let model: AppModel

    var body: some View {
        if let issue = model.configurationIssue {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.description)
                        Text("Miri does not change the file until it is fixed.").foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                }
                Button("Show Configuration File in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([model.paths.configuration])
                }
            }
        }
    }
}

struct SetupCheckRow: View {
    let check: SetupCheck

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            symbol.frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(check.title)
                if let detail {
                    Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            Text(label).foregroundStyle(.secondary)
            if let url = check.settingsURL, check.status != .passed {
                Button("Open") { NSWorkspace.shared.open(url) }
            }
        }
    }

    private var label: String {
        switch check.status {
        case .passed: check.isGestureCheck ? "No conflict found" : "Passed"
        case .problem: check.blocksStart ? "Blocks start" : "Problem"
        case .notChecked: "Not checked"
        case .unableToVerify: "Unable to verify"
        }
    }

    private var detail: String? {
        switch check.status {
        case .passed: nil
        case .problem(let text), .notChecked(let text), .unableToVerify(let text): text
        }
    }

    @ViewBuilder private var symbol: some View {
        switch check.status {
        case .passed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .problem: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
        case .notChecked, .unableToVerify: Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
        }
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Review the report before copying it.")
                .font(.headline)
            Text("Window titles, document paths, user names, and the configuration file are removed.")
                .foregroundStyle(.secondary)
            ScrollView {
                Text(report)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(.background.secondary, in: .rect(cornerRadius: 6))
            HStack {
                Button("Refresh") { refresh() }
                Spacer()
                if copied { Text("Copied").foregroundStyle(.secondary) }
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report, forType: .string)
                    copied = true
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 640, height: 520)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        report = model.diagnostics()
        copied = false
    }
}
