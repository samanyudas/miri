import AppKit
import MiriCore
import SwiftUI

/// Shows a configuration problem at the top of a page.
struct ConfigurationIssueNotice: View {
    let model: AppModel

    var body: some View {
        if let issue = model.configurationIssue {
            Banner(
                kind: .warning, title: "The configuration file has a problem",
                detail: "\(issue.description) Miri does not change the file until it is fixed."
            ) {
                Button("Show Configuration File in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([model.paths.configuration])
                }
            }
        }
    }
}

// MARK: - General

struct GeneralSettings: View {
    let model: AppModel
    @Binding var page: SettingsView.Page

    var body: some View {
        SettingsPage(title: "General", subtitle: subtitle) {
            ConfigurationIssueNotice(model: model)
            status
            SettingsSection("Startup") {
                SettingsRow(
                    title: "Launch at login", detail: "If you stopped Miri before logging out, it stays stopped."
                ) {
                    RowSwitch(
                        label: "Launch at login",
                        isOn: Binding(get: { model.settings.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                }
                if let error = model.loginItemError {
                    NoticeRow(kind: .warning, text: error) {
                        if !AppModel.isInApplicationsFolder {
                            Button("Show Miri in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                            }
                        }
                    }
                }
            }
            SettingsSection("Configuration file") {
                SettingsRow(
                    title: (model.paths.configuration.path as NSString).abbreviatingWithTildeInPath,
                    detail: "Changes here apply right away. Standalone Paneru settings are left alone.",
                    monospacedTitle: true
                ) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([model.paths.configuration])
                    }
                }
            }
        }
    }

    private var subtitle: String {
        switch model.engineState {
        case .running, .restarting:
            "Closing this window keeps Miri managing your windows. Use Stop to pause, or Quit from the menu bar."
        case .failed:
            "Window management stopped because the engine kept failing. Your windows stay where they are."
        case .stopped where !model.startBlockers.isEmpty:
            "Miri waits for setup before it manages windows. Closing this window keeps it waiting."
        case .stopped:
            "Closing this window keeps Miri open. Window management stays paused until you start it."
        }
    }

    @ViewBuilder private var status: some View {
        switch model.engineState {
        case .running:
            StatusHero(
                eyebrow: "Running", eyebrowColor: Palette.accentText, title: model.statusText,
                detail: displaysSentence, tint: Palette.heroTint, faded: false)
        case .restarting:
            StatusHero(
                eyebrow: "Restarting", eyebrowColor: Palette.orange, title: model.statusText,
                detail:
                    "The engine stopped unexpectedly. Your windows are back on screen, and Miri restarts it in a moment.",
                tint: Palette.warningTint, faded: true)
        case .failed(let reason):
            Banner(
                kind: .error, title: "Window management stopped after engine failures", detail: reason,
                accessibilityValue: model.statusText
            ) {
                Button("Show Logs in Finder") { model.showLogsInFinder() }
                Button("Restart Engine") { model.restart() }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accent)
            }
        case .stopped where !model.startBlockers.isEmpty:
            Banner(
                kind: .warning, title: "Window management has not started",
                detail: "Miri starts by itself when the required checks in Setup pass.",
                accessibilityValue: model.statusText
            ) {
                Button("Open Setup") { page = .setup }
                Button("Stop Window Management") { model.stop() }
            }
        case .stopped:
            Banner(
                kind: .warning, title: "Window management is paused",
                detail: "Your windows stay where they are. Miri stays stopped across launches until you start it.",
                accessibilityValue: model.statusText
            ) {
                Button("Start Window Management") { model.start() }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accent)
            }
        }
    }

    /// Names the displays Miri manages, such as "Built-in Retina Display and LG 27UK850, one strip per Space."
    private var displaysSentence: String {
        let names = NSScreen.screens.map(\.localizedName)
        guard !names.isEmpty else { return "One strip per Space." }
        return "\(names.formatted(.list(type: .and))), one strip per Space."
    }
}

/// The status card at the top of General, with a small picture of the strips.
private struct StatusHero: View {
    let eyebrow: String
    let eyebrowColor: Color
    let title: String
    let detail: String
    let tint: Color
    let faded: Bool

    var body: some View {
        HStack(spacing: 26) {
            StripPicture(faded: faded)
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(eyebrowColor)
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Palette.primaryText)
                    .modifier(StatusValue(value: title))
                LiveText(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(tint, in: .rect(cornerRadius: 12))
    }
}

/// A decorative sketch of one strip per display, up to two, with one column picked out in the accent color.
private struct StripPicture: View {
    let faded: Bool

    var body: some View {
        VStack(spacing: 6) {
            display(widths: [28, 62, 44, 44, 40], stacked: 2, highlighted: 1, height: 52)
            if NSScreen.screens.count > 1 {
                display(widths: [94, 60, 50], stacked: nil, highlighted: nil, height: 40)
            }
        }
        .frame(width: 200)
        .accessibilityHidden(true)
    }

    private func display(widths: [CGFloat], stacked: Int?, highlighted: Int?, height: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(widths.indices, id: \.self) { index in
                if index == stacked {
                    VStack(spacing: 2) {
                        tile(highlighted: false)
                        tile(highlighted: false)
                    }
                    .frame(width: widths[index])
                } else {
                    tile(highlighted: index == highlighted).frame(width: widths[index])
                }
            }
        }
        .padding(5)
        .frame(width: 200, height: height, alignment: .leading)
        .clipped()
        .background(Palette.group, in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.heroTileBorder, lineWidth: 1))
    }

    private func tile(highlighted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(highlighted ? Palette.accent.opacity(faded ? 0.4 : 1) : Palette.heroTile)
    }
}

// MARK: - Layout

struct LayoutSettings: View {
    let model: AppModel
    @State private var presetsText = ""
    @State private var presetsError: String?
    @State private var mainDisplayHeight = LayoutSettings.currentMainDisplayHeight()

    var body: some View {
        SettingsPage(
            title: "Layout",
            subtitle: "How columns sit on the strip. Changes apply to your windows as soon as you make them."
        ) {
            ConfigurationIssueNotice(model: model)
            SettingsSection("Gaps") {
                gapRow("Between windows", \.innerGap)
                gapRow("At screen edges", \.outerGap)
            }
            SettingsSection("Column widths and motion") {
                SettingsRow(
                    title: "Width presets",
                    detail: "Fractions of the display width, narrowest first. \(cycleShortcutText)"
                ) {
                    TextField("Width presets", text: $presetsText, prompt: Text("0.25, 0.5, 0.75"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 200)
                        .onSubmit(applyPresets)
                }
                if let presetsError {
                    NoticeRow(kind: .error, text: presetsError)
                }
                SettingsRow(title: "Animate window movement", detail: motionDetail) {
                    RowSwitch(
                        label: "Animate window movement",
                        isOn: Binding(
                            get: { model.settings.animations },
                            set: { value in model.update { $0.animations = value } }))
                }
            }
            SettingsSection("Stacks") {
                SettingsRow(
                    title: "Windows per stack",
                    detail:
                        "Up to \(mainDisplayFit) fit on the main display at the minimum height of \(StackLimit.minimumWindowHeight) points. A full stack sends the next window to a new column."
                ) {
                    Picker("Windows per stack", selection: stackLimit) {
                        Text("Fit the display").tag(StackLimit.fit)
                        ForEach(
                            StackLimit.offeredCounts(fit: mainDisplayFit, configured: model.settings.stackLimit),
                            id: \.self
                        ) { count in
                            Text("\(count)").tag(StackLimit.count(count))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsRow(
                    title: "Maximized stacked window opens",
                    detail: "Restoring it returns it to the stack if there is room."
                ) {
                    SegmentedChoice(
                        label: "Maximized stacked window opens", selection: maximizedWindowSide,
                        options: [("Left of its stack", .left), ("Right of its stack", .right)])
                }
            }
            SettingsSection("Displays side by side") {
                SettingsRow(
                    title: "Show window contents on edges next to another display",
                    detail:
                        "A column waiting past an edge next to another display shows a photo of its window. Needs Screen Recording permission."
                ) {
                    RowSwitch(
                        label: "Show window contents on edges next to another display",
                        isOn: Binding(
                            get: { model.settings.sharedEdgeSlices }, set: { model.setSharedEdgeSlices($0) }))
                }
                if model.sharedEdgeSlicesNeedPermission {
                    NoticeRow(
                        kind: .warning,
                        text:
                            "Off because Miri does not have Screen Recording permission. Turn on Miri there, then switch this on again."
                    ) {
                        if let url = SystemScreenRecording.settingsURL {
                            Button("Open Screen Recording Settings") { NSWorkspace.shared.open(url) }
                        }
                    }
                }
            }
        }
        .onAppear(perform: showPresets)
        .onChange(of: model.settings.widthPresets) { showPresets() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) {
            _ in
            mainDisplayHeight = Self.currentMainDisplayHeight()
        }
    }

    private var motionDetail: String {
        model.reduceMotion
            ? "Reduce Motion is on in System Settings, so windows move instantly."
            : "Movement is always instant when macOS Reduce Motion is on."
    }

    /// Names the shortcuts bound to cycling the presets, which the user can change in Shortcuts.
    private var cycleShortcutText: String {
        let action = ShortcutAction.cyclePresetWidths
        guard let shortcuts = model.shortcuts else { return "" }
        let labels = shortcuts.chords(for: action).map(model.keyLayout.label(for:))
        return labels.isEmpty
            ? "\(action.title) has no shortcut. Add one in Shortcuts."
            : "\(labels.formatted(.list(type: .or))) cycles through them."
    }

    private var stackLimit: Binding<StackLimit> {
        Binding(get: { model.settings.stackLimit }, set: { value in model.update { $0.stackLimit = value } })
    }

    private var maximizedWindowSide: Binding<MaximizedWindowSide> {
        Binding(
            get: { model.settings.maximizedWindowSide },
            set: { value in model.update { $0.maximizedWindowSide = value } })
    }

    /// How many windows fit in a column on the display with the menu bar, as the engine counts them.
    private var mainDisplayFit: Int {
        StackLimit.fitCount(columnHeight: mainDisplayHeight - Double(2 * model.settings.edgePadding))
    }

    /// The visible height of the display with the menu bar, which macOS lists first.
    private static func currentMainDisplayHeight() -> Double {
        Double(NSScreen.screens.first?.visibleFrame.height ?? 0)
    }

    private func gapRow(_ title: String, _ key: WritableKeyPath<MiriSettings, Int>) -> some View {
        SettingsRow(title: title) {
            Stepper(value: gap(key), in: MiriSettings.gapRange) {
                LiveText("\(model.settings[keyPath: key]) pt")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(Palette.primaryText)
            }
            .accessibilityLabel(title)
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

// MARK: - Setup

struct SetupSettings: View {
    let model: AppModel
    @Binding var page: SettingsView.Page

    var body: some View {
        SettingsPage(
            title: "Setup",
            subtitle:
                "Miri checks your Mac for anything that would stop it from managing windows. It never changes macOS settings for you."
        ) {
            Button("Check Again", systemImage: "arrow.clockwise") { model.refreshSetup() }
        } content: {
            if !model.startBlockers.isEmpty {
                Banner(
                    kind: .warning, title: "Window management has not started",
                    detail: "Miri starts by itself when the required checks pass.")
            }
            let required = model.setupChecks.filter(\.blocksStart)
            let recommended = model.setupChecks.filter { !$0.blocksStart }
            if !required.isEmpty {
                SettingsSection("Required to start") {
                    ForEach(required) { check in SetupCheckItem(check: check) { page = .gestures } }
                }
            }
            if !recommended.isEmpty {
                SettingsSection("Recommended") {
                    ForEach(recommended) { check in SetupCheckItem(check: check) { page = .gestures } }
                }
            }
            Text("Each Open button shows the System Settings page to change. Miri never changes it for you.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondaryText)
        }
        .onAppear { model.refreshSetup() }
    }
}

/// One setup check: its result as a colored symbol, what it found, and a way to fix it.
struct SetupCheckItem: View {
    let check: SetupCheck
    /// Opens Settings > Gestures for a gesture check. Set Up Miri lists only start blockers, so it passes nothing.
    var openGestures: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.primaryText)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if check.isGestureCheck, check.status != .passed, let openGestures {
                Button("Open Gestures", action: openGestures)
            }
            if let url = check.settingsURL, check.status != .passed {
                Button("Open") { NSWorkspace.shared.open(url) }
                    .help("Open the System Settings page for \(check.title)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 50)
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch check.status {
        case .passed: check.title
        case .problem: check.title
        case .notChecked: "\(check.title): Not checked"
        case .unableToVerify: "\(check.title): Unable to verify"
        }
    }

    private var detail: String? {
        switch check.status {
        case .passed: check.isGestureCheck ? "No conflict found." : nil
        case .problem(let text): check.blocksStart ? "Blocks start. \(text)" : text
        case .notChecked(let text), .unableToVerify(let text): text
        }
    }

    @ViewBuilder private var symbol: some View {
        switch check.status {
        case .passed:
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Palette.green, in: .circle)
                .accessibilityLabel("Passed")
        case .problem:
            NoticeGlyph(kind: .warning, size: 18).accessibilityLabel("Problem")
        case .unableToVerify:
            Text("?")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Palette.orange, in: .circle)
                .accessibilityLabel("Unable to verify")
        case .notChecked:
            Image(systemName: "minus")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Palette.gray)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Palette.gray, lineWidth: 1.2))
                .accessibilityLabel("Not checked")
        }
    }
}

// MARK: - Diagnostics

struct DiagnosticsSettings: View {
    let model: AppModel
    @Environment(\.presenter) private var presenter
    @State private var logTail: [String] = []

    var body: some View {
        SettingsPage(
            title: "Diagnostics",
            subtitle: "Engine health and local logs. Nothing leaves your Mac unless you copy it yourself."
        ) {
            if case .failed(let reason) = model.engineState {
                Banner(kind: .error, title: "Window management stopped after engine failures", detail: reason)
            }
            engineFacts
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Engine log") {
                    Button("Show Logs in Finder") { model.showLogsInFinder() }
                        .buttonStyle(.link)
                        .font(.system(size: 12))
                }
                ScrollView([.vertical, .horizontal]) {
                    Text(logTail.isEmpty ? "The log is empty." : logTail.joined(separator: "\n"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.logText)
                        .lineSpacing(3)
                        .fixedSize()
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .defaultScrollAnchor(.bottomLeading)
                .frame(height: 200)
                .background(Palette.logBackground, in: .rect(cornerRadius: 10))
            }
            HStack(spacing: 10) {
                if model.engineState != .stopped {
                    Button("Restart Engine") { model.restart() }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accent)
                }
                Button("Copy Diagnostics…") { presenter?.show(.diagnostics) }
                Text("Logs stay on this Mac. Miri sends no telemetry.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondaryText)
            }
            SettingsSection("Developer") {
                SettingsRow(
                    title: "Accessibility permission experiment",
                    detail: "Checks which process macOS credits with Miri's Accessibility permission."
                ) {
                    Button("Permission Experiment…") { presenter?.show(.permissionExperiment) }
                }
            }
        }
        .onAppear(perform: readLog)
        .onChange(of: model.engineState) { readLog() }
    }

    private var engineFacts: some View {
        HStack(spacing: 0) {
            fact("Engine", value: engineWord, dot: model.stateColor)
            Rectangle().fill(Palette.divider).frame(width: 1)
            fact("Process", value: processText, dot: nil)
            Rectangle().fill(Palette.divider).frame(width: 1)
            fact("Displays", value: "\(NSScreen.screens.count)", dot: nil)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Palette.group, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.groupRing, lineWidth: 1))
    }

    private func fact(_ title: String, value: String, dot: Color?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondaryText)
            HStack(spacing: 7) {
                if let dot { Circle().fill(dot).frame(width: 8, height: 8) }
                LiveText(value)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Palette.primaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var engineWord: String {
        switch model.engineState {
        case .running: "Running"
        case .restarting: "Restarting"
        case .failed: "Failed"
        case .stopped: model.startBlockers.isEmpty ? "Stopped" : "Waiting"
        }
    }

    private var processText: String {
        switch model.engineState {
        case .running(let pid): "pid \(pid)"
        case .restarting(let crashes): "crash \(crashes)"
        case .failed, .stopped: "None"
        }
    }

    private func readLog() {
        logTail = model.log.tail(maximum: 6_000)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .suffix(40)
            .map(String.init)
    }
}
