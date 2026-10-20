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

    var menuSymbol: String {
        switch engineState {
        case .running: "rectangle.split.3x1"
        case .restarting: "rectangle.split.3x1"
        case .failed: "exclamationmark.triangle"
        case .stopped: startBlockers.isEmpty ? "rectangle.split.3x1.slash" : "exclamationmark.triangle"
        }
    }
}

struct MenuContent: View {
    let model: AppModel
    let presenter: WindowPresenter

    var body: some View {
        Text(model.statusText)
        if let issue = model.configurationIssue {
            Text("Configuration error. Open Settings for details.")
                .help(issue.description)
        }
        Divider()
        switch model.engineState {
        case .running, .restarting:
            Button("Stop Window Management") { model.stop() }
            Button("Restart Engine") { model.restart() }
        case .failed:
            Button("Restart Engine") { model.restart() }
        case .stopped:
            Button("Start Window Management") { model.start() }
        }
        Divider()
        Button("Settings…") { presenter.show(.settings) }
            .keyboardShortcut(",")
        Button("Copy Diagnostics…") { presenter.show(.diagnostics) }
        Divider()
        Button("Quit Miri") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

struct SettingsView: View {
    enum Page: String { case general, layout, gestures, shortcuts, setup, diagnostics }

    let model: AppModel
    @AppStorage("settingsTab") private var page = Page.general

    var body: some View {
        TabView(selection: $page) {
            Tab("General", systemImage: "gearshape", value: .general) { GeneralSettings(model: model) }
            Tab("Layout", systemImage: "rectangle.split.3x1", value: .layout) { LayoutSettings(model: model) }
            Tab("Gestures", systemImage: "hand.draw", value: .gestures) { GestureSettings(model: model) }
            Tab("Shortcuts", systemImage: "keyboard", value: .shortcuts) { ShortcutsSettings(model: model) }
            Tab("Setup", systemImage: "checklist", value: .setup) { SetupSettings(model: model) }
            Tab("Diagnostics", systemImage: "stethoscope", value: .diagnostics) { DiagnosticsSettings(model: model) }
        }
        .frame(width: 560, height: 500)
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

struct GeneralSettings: View {
    let model: AppModel

    var body: some View {
        Form {
            ConfigurationIssueBanner(model: model)
            Section {
                LabeledContent("Status", value: model.statusText)
                if case .failed(let reason) = model.engineState {
                    Text(reason).foregroundStyle(.secondary)
                }
                HStack {
                    switch model.engineState {
                    case .stopped: Button("Start Window Management") { model.start() }
                    case .failed: Button("Restart Engine") { model.restart() }
                    case .running, .restarting:
                        Button("Stop Window Management") { model.stop() }
                        Button("Restart Engine") { model.restart() }
                    }
                }
            }
            Section {
                Toggle(
                    "Launch at login",
                    isOn: Binding(get: { model.settings.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                if let error = model.loginItemError {
                    Text(error).foregroundStyle(.secondary)
                }
                Toggle(
                    "Animate window movement",
                    isOn: Binding(
                        get: { model.settings.animations }, set: { value in model.update { $0.animations = value } }))
                if model.reduceMotion {
                    Text("Reduce Motion is on in System Settings, so windows move instantly.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct LayoutSettings: View {
    let model: AppModel
    @State private var presetsText = ""
    @State private var presetsError: String?

    var body: some View {
        Form {
            ConfigurationIssueBanner(model: model)
            Section("Gaps") {
                gapRow("Between windows", \.innerGap)
                gapRow("At screen edges", \.outerGap)
            }
            Section {
                LabeledContent("Width presets") {
                    TextField("Width presets", text: $presetsText, prompt: Text("0.25, 0.5, 0.75"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 240)
                        .onSubmit(applyPresets)
                }
                if let presetsError {
                    Text(presetsError).foregroundStyle(.red)
                }
            } footer: {
                Text(
                    "Fractions of the display width, from narrowest to widest, separated by commas. Control-Option-R cycles through them."
                )
                .foregroundStyle(.secondary)
            }
            Section {
                Picker("Windows per stack", selection: stackLimit) {
                    Text("Fit the display").tag(StackLimit.fit)
                    ForEach(Array(1...stackCountMax), id: \.self) { count in
                        Text("\(count)").tag(StackLimit.count(count))
                    }
                }
            } footer: {
                Text(
                    "Stacking a window onto a full stack starts a new column instead. Up to \(mainDisplayFit) windows fit on the main display at the minimum height of \(StackLimit.minimumWindowHeight) points, and a stack never holds more than fit on its display."
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: showPresets)
        .onChange(of: model.settings.widthPresets) { showPresets() }
    }

    private var stackLimit: Binding<StackLimit> {
        Binding(get: { model.settings.stackLimit }, set: { value in model.update { $0.stackLimit = value } })
    }

    /// How many windows fit in a column on the display with the menu bar, as the engine counts them.
    private var mainDisplayFit: Int {
        let height = NSScreen.screens.first?.visibleFrame.height ?? 0
        return StackLimit.fitCount(columnHeight: height - Double(2 * model.settings.edgePadding))
    }

    /// The largest number offered, which still includes a larger number set by hand.
    private var stackCountMax: Int {
        guard case .count(let count) = model.settings.stackLimit else { return mainDisplayFit }
        return max(mainDisplayFit, count)
    }

    private func gapRow(_ title: String, _ key: WritableKeyPath<MiriSettings, Int>) -> some View {
        LabeledContent(title) {
            Stepper(value: gap(key), in: MiriSettings.gapRange) {
                Text("\(model.settings[keyPath: key]) pt").monospacedDigit()
            }
        }
    }

    private func gap(_ key: WritableKeyPath<MiriSettings, Int>) -> Binding<Int> {
        Binding(get: { model.settings[keyPath: key] }, set: { value in model.update { $0[keyPath: key] = value } })
    }

    private func showPresets() {
        presetsText = model.settings.widthPresets.map { $0.formatted(.number.precision(.fractionLength(0...4))) }
            .joined(separator: ", ")
    }

    private func applyPresets() {
        let values = presetsText.split(separator: ",").map {
            Double($0.trimmingCharacters(in: .whitespaces))
        }
        var candidate = model.settings
        candidate.widthPresets = values.compactMap(\.self)
        do throws(ConfigurationIssue) {
            guard !values.contains(nil) else {
                throw ConfigurationIssue.invalidValue(key: "", message: "Enter numbers separated by commas.")
            }
            try candidate.validate()
            presetsError = nil
            model.update { $0.widthPresets = candidate.widthPresets }
        } catch {
            presetsError = error.description
        }
    }
}

struct SetupSettings: View {
    let model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(model.setupChecks) { check in
                    SetupCheckRow(check: check)
                }
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    Text(
                        "Miri never changes macOS settings. Each Open button shows the System Settings page to change."
                    )
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check Again") { model.refreshSetup() }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refreshSetup() }
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

struct DiagnosticsSettings: View {
    let model: AppModel
    @Environment(\.presenter) private var presenter

    var body: some View {
        Form {
            Section {
                LabeledContent("Logs") {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([model.log.url])
                    }
                }
                LabeledContent("Configuration file") {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([model.paths.configuration])
                    }
                }
            } footer: {
                Text("Logs stay on this Mac. Miri sends no telemetry.").foregroundStyle(.secondary)
            }
            Section {
                Button("Copy Diagnostics…") { presenter?.show(.diagnostics) }
                Button("Permission Experiment…") { presenter?.show(.permissionExperiment) }
            }
        }
        .formStyle(.grouped)
    }
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
