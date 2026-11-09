import AppKit
import MiriCore
import SwiftUI

/// Shows a configuration problem at the top of a page.
struct ConfigurationIssueNotice: View {
    let model: AppModel

    var body: some View {
        if let issue = model.configurationIssue {
            Banner(
                kind: .warning, title: String(localized: "The configuration file has a problem"),
                detail: String(localized: "\(issue.description) Miri does not change the file until it is fixed.")
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
        SettingsPage(
            title: String(localized: "General"),
            subtitle: String(localized: "Closing this window keeps Miri in the menu bar.")
        ) {
            ConfigurationIssueNotice(model: model)
            status
            SettingsSection(String(localized: "Startup")) {
                SettingsRow(
                    title: String(localized: "Launch at login"),
                    detail: String(localized: "If you stopped Miri before logging out, it stays stopped.")
                ) {
                    RowSwitch(
                        label: String(localized: "Launch at login"),
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
                ShowInDockRow(model: model)
            }
            SettingsSection(String(localized: "Pointer")) {
                SettingsRow(
                    title: String(localized: "Move the pointer to windows that Miri focuses"),
                    detail:
                        String(
                            localized:
                                "Focus shortcuts, display focus, and workspace switches move it to the window's centre. Clicks and Cmd-Tab leave it in place."
                        )
                ) {
                    RowSwitch(
                        label: String(localized: "Move the pointer to windows that Miri focuses"),
                        isOn: Binding(
                            get: { model.settings.mouseFollowsFocus },
                            set: { value in model.update { $0.mouseFollowsFocus = value } }))
                }
            }
            SettingsSection(String(localized: "Configuration file")) {
                SettingsRow(
                    title: (model.paths.configuration.path as NSString).abbreviatingWithTildeInPath,
                    detail: String(
                        localized: "Changes here apply right away. Settings from other tools are not touched."),
                    monospacedTitle: true
                ) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([model.paths.configuration])
                    }
                }
            }
        }
    }

    @ViewBuilder private var status: some View {
        switch model.engineState {
        case .running:
            StatusHero(
                eyebrow: String(localized: "Running"), eyebrowColor: Palette.accentText, title: model.statusText,
                detail: displaysSentence, tint: Palette.heroTint, faded: false)
        case .restarting:
            StatusHero(
                eyebrow: String(localized: "Restarting"), eyebrowColor: Palette.orange, title: model.statusText,
                detail:
                    String(
                        localized:
                            "The engine stopped unexpectedly. Your windows are back on screen, and Miri restarts it in a moment."
                    ),
                tint: Palette.warningTint, faded: true)
        case .failed(let reason):
            Banner(
                kind: .error, title: model.statusText, detail: reason,
                accessibilityValue: model.statusText
            ) {
                Button("Show Logs in Finder") { model.showLogsInFinder() }
                Button("Restart Engine") { model.restart() }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accentFill)
            }
        case .stopped where !model.startBlockers.isEmpty:
            Banner(
                kind: .warning, title: String(localized: "Waiting for setup"),
                detail:
                    String(
                        localized:
                            "Waiting for the \u{201C}\(model.startBlockers.first?.title ?? "required")\u{201D} check. \(AppModel.startsWhenReadySentence)"
                    ),
                accessibilityValue: model.statusText
            ) {
                Button(AppModel.cancelAutomaticStartTitle) { model.stop() }
                Button("Open Setup") { page = .setup }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accentFill)
            }
        case .stopped:
            Banner(
                kind: .neutral, title: String(localized: "Window management is stopped"),
                // Only a stop the user chose is remembered across log-ins, so only that one promises it.
                detail: model.stoppedByUser
                    ? String(localized: "Your windows stay where they are. Miri stays stopped until you start it.")
                    : String(localized: "Your windows stay where they are."),
                accessibilityValue: model.statusText
            ) {
                Button("Start Window Management") { model.start() }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accentFill)
            }
        }
    }

    /// Names the displays Miri manages, such as "Built-in Retina Display and LG 27UK850, one strip per Space."
    private var displaysSentence: String {
        let names = NSScreen.screens.map(\.localizedName)
        guard !names.isEmpty else { return String(localized: "One strip per Space.") }
        return String(localized: "\(names.formatted(.list(type: .and))), one strip per Space.")
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
                    .font(.small.weight(.semibold))
                    .tracking(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(eyebrowColor)
                Text(title)
                    .font(.heroTitle)
                    .foregroundStyle(Palette.primaryText)
                    .modifier(StatusValue(value: title))
                Text(detail)
                    .font(.detail)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(tint, in: .rect(cornerRadius: 10))
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
        // A picture of the screen keeps the screen's real left and right, also in Arabic.
        .environment(\.layoutDirection, .leftToRight)
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
    @FocusState private var editingPresets: Bool
    @State private var mainDisplayHeight = LayoutSettings.currentMainDisplayHeight()

    var body: some View {
        SettingsPage(
            title: String(localized: "Layout"),
            subtitle: String(localized: "How columns sit on the strip. Changes apply right away.")
        ) {
            ConfigurationIssueNotice(model: model)
            SettingsSection(String(localized: "Gaps")) {
                gapRow(String(localized: "Between windows"), \.innerGap)
                gapRow(String(localized: "At screen edges"), \.outerGap)
            }
            SettingsSection(String(localized: "Column widths and motion")) {
                SettingsRow(
                    title: String(localized: "Width presets"),
                    detail: presetsDetail
                ) {
                    TextField("Width presets", text: $presetsText, prompt: Text("0.25, 0.5, 0.75"))
                        .labelsHidden()
                        .textFieldStyle(.plain)
                        .font(.rowTitle)
                        .fieldBox(focused: editingPresets)
                        .frame(width: 200)
                        .focused($editingPresets)
                        .onSubmit(applyPresets)
                        // Leaving the field applies it too, so an edit is never lost by clicking elsewhere.
                        .onChange(of: editingPresets) { if !editingPresets { applyPresets() } }
                }
                if let presetsError {
                    NoticeRow(kind: .error, text: presetsError)
                }
                SettingsRow(title: String(localized: "Animate window movement"), detail: motionDetail) {
                    RowSwitch(
                        label: String(localized: "Animate window movement"),
                        isOn: Binding(
                            get: { model.settings.animations },
                            set: { value in model.update { $0.animations = value } }))
                }
            }
            SettingsSection(String(localized: "Stacks")) {
                SettingsRow(
                    title: String(localized: "Windows per stack"),
                    detail:
                        String(
                            localized:
                                "Up to \(mainDisplayFit) fit on the main display at the minimum height of \(StackLimit.minimumWindowHeight) points. A full stack sends the next window to a new column."
                        )
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
                    title: String(localized: "Maximized stacked window opens"),
                    detail: String(localized: "Restoring it returns it to the stack if there is room.")
                ) {
                    SegmentedChoice(
                        label: String(localized: "Maximized stacked window opens"), selection: maximizedWindowSide,
                        options: [
                            (String(localized: "Left of its stack"), .left),
                            (String(localized: "Right of its stack"), .right),
                        ])
                }
            }
            SettingsSection(String(localized: "Displays side by side")) {
                SettingsRow(
                    title: String(localized: "Show window contents on edges next to another display"),
                    detail:
                        String(
                            localized:
                                "A column waiting past an edge next to another display shows a photo of its window. Needs Screen Recording permission."
                        )
                ) {
                    RowSwitch(
                        label: String(localized: "Show window contents on edges next to another display"),
                        isOn: Binding(
                            get: { model.settings.sharedEdgeSlices }, set: { model.setSharedEdgeSlices($0) }))
                }
                if model.sharedEdgeSlicesNeedPermission {
                    NoticeRow(
                        kind: .warning,
                        text:
                            String(
                                localized:
                                    "Off because Miri does not have Screen Recording permission. Turn on Miri there, then switch this on again."
                            )
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
        .onChange(of: presetsError) {
            if let presetsError { AccessibilityNotification.Announcement(presetsError).post() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) {
            _ in
            mainDisplayHeight = Self.currentMainDisplayHeight()
        }
    }

    private var presetsDetail: String {
        editingPresets && presetsText != formattedPresets
            ? String(localized: "Press Return to apply. Fractions of the display width, narrowest first.")
            : String(localized: "Fractions of the display width, narrowest first. \(cycleShortcutText)")
    }

    private var formattedPresets: String {
        model.settings.widthPresets.map { $0.formatted(.number.precision(.fractionLength(0...4))) }
            .joined(separator: ", ")
    }

    private var motionDetail: String {
        model.reduceMotion
            ? String(localized: "Reduce Motion is on in System Settings, so windows move instantly.")
            : String(localized: "Movement is always instant when macOS Reduce Motion is on.")
    }

    /// Names the shortcuts bound to cycling the presets, which the user can change in Shortcuts.
    private var cycleShortcutText: String {
        let action = ShortcutAction.cyclePresetWidths
        guard let shortcuts = model.shortcuts else { return "" }
        let labels = shortcuts.chords(for: action).map(model.keyLayout.sentenceLabel(for:))
        return labels.isEmpty
            ? String(localized: "\(action.title) has no shortcut. Add one in Shortcuts.")
            // A no-break space keeps the shortcut on the same line as its verb.
            : String(localized: "\(labels.formatted(.list(type: .or)))\u{00A0}cycles through them.")
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
                LiveText(String(localized: "\(model.settings[keyPath: key]) pt"))
                    .font(.rowTitle)
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
        presetsText = formattedPresets
    }

    private func applyPresets() {
        // Unedited text shows the presets rounded to four places, so applying it would rewrite them.
        guard presetsText != formattedPresets else {
            presetsError = nil
            return
        }
        let values = presetsText.split(separator: ",").map {
            Double($0.trimmingCharacters(in: .whitespaces))
        }
        var candidate = model.settings
        candidate.widthPresets = values.compactMap(\.self)
        do throws(ConfigurationIssue) {
            guard !values.contains(nil) else {
                throw ConfigurationIssue.invalidValue(
                    key: "", message: String(localized: "Enter numbers separated by commas."))
            }
            try candidate.validate()
            presetsError = nil
            if candidate.widthPresets != model.settings.widthPresets {
                model.update { $0.widthPresets = candidate.widthPresets }
            }
        } catch {
            presetsError = error.description
        }
    }
}

// MARK: - Setup

struct SetupSettings: View {
    let model: AppModel
    @Binding var page: SettingsView.Page
    @State private var checked = false
    @State private var resetChecked: Task<Void, Never>?

    var body: some View {
        SettingsPage(
            title: String(localized: "Setup"),
            subtitle:
                String(
                    localized:
                        "Miri checks your Mac for anything that blocks window management. It never changes your settings for you."
                )
        ) {
            Button(checked ? "Checked" : "Check Again", systemImage: checked ? "checkmark" : "arrow.clockwise") {
                model.refreshSetup()
                let count = model.setupReviewCount
                AccessibilityNotification.Announcement(
                    count == 0
                        ? String(localized: "Checked. Nothing to review.")
                        : String(localized: "Checked. \(count) to review.")
                ).post()
                // The button says Checked for a moment, so a check that changed nothing still shows it ran.
                checked = true
                // A second press restarts the two seconds instead of ending them early.
                resetChecked?.cancel()
                resetChecked = Task {
                    try? await Task.sleep(for: .seconds(2))
                    if !Task.isCancelled { checked = false }
                }
            }
        } content: {
            if !model.startBlockers.isEmpty {
                Banner(
                    kind: .warning, title: String(localized: "Waiting for setup"),
                    detail: AppModel.startsWhenReadySentence)
            }
            let required = model.setupChecks.filter(\.blocksStart)
            // Problems first, so the rows that need attention are not hidden between passing ones.
            let others = model.setupChecks.filter { !$0.blocksStart }
            let recommended = others.filter(\.needsAttention) + others.filter { !$0.needsAttention }
            if !required.isEmpty {
                SettingsSection(String(localized: "Required to start")) {
                    ForEach(required) { check in
                        SetupCheckItem(check: check, openGestures: { page = .gestures }, inRequiredSection: true)
                    }
                }
            }
            if !recommended.isEmpty {
                SettingsSection(String(localized: "Recommended")) {
                    ForEach(recommended) { check in SetupCheckItem(check: check) { page = .gestures } }
                }
            }
        }
        .onAppear { model.refreshSetup() }
    }
}

/// One setup check: its result as a colored symbol, what it found, and the ways to fix it below that.
struct SetupCheckItem: View {
    let check: SetupCheck
    /// Opens Settings > Gestures for a gesture check. Set Up Miri lists only start blockers, so it passes nothing.
    var openGestures: (() -> Void)?
    /// Whether the row sits under a "Required to start" label, which already says that it blocks start.
    var inRequiredSection = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            symbol
                .accessibilityHidden(true)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rowTitle)
                    .foregroundStyle(Palette.primaryText)
                    .accessibilityValue(result)
                if let detail {
                    Text(detail)
                        .font(.detail)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if check.status != .passed, check.isGestureCheck || check.settingsURL != nil {
                    ButtonRow {
                        if check.isGestureCheck, let openGestures {
                            Button("Open Gestures", action: openGestures)
                        }
                        if let url = check.settingsURL {
                            Button(check.isGestureCheck ? "Open Trackpad Settings" : "Open System Settings") {
                                NSWorkspace.shared.open(url)
                            }
                            .help("Open the System Settings page for \(check.title)")
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch check.status {
        case .passed, .problem: check.title
        case .notChecked: String(localized: "\(check.title): Not checked")
        case .unableToVerify: String(localized: "\(check.title): Unable to verify")
        }
    }

    /// The result VoiceOver reads with the title, because the colored symbol is hidden from it.
    private var result: String {
        switch check.status {
        case .passed: check.isGestureCheck ? String(localized: "No conflict found") : String(localized: "Passed")
        case .problem: check.blocksStart ? String(localized: "Blocks start") : String(localized: "Recommended change")
        case .notChecked: String(localized: "Not checked")
        case .unableToVerify: String(localized: "Unable to verify")
        }
    }

    private var detail: String? {
        switch check.status {
        case .passed: check.isGestureCheck ? String(localized: "No conflict found.") : nil
        case .problem(let text):
            check.blocksStart && !inRequiredSection ? String(localized: "Blocks start. \(text)") : text
        case .notChecked(let text), .unableToVerify(let text): text
        }
    }

    @ViewBuilder private var symbol: some View {
        switch check.status {
        case .passed:
            NoticeGlyph(kind: .success, size: 18)
        // A check that blocks start is an error, so it reads apart from a recommended change by color and shape.
        case .problem:
            NoticeGlyph(kind: check.blocksStart ? .error : .warning, size: 18)
        case .unableToVerify:
            Image(systemName: "questionmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Palette.onStatus)
                .frame(width: 18, height: 18)
                .background(Palette.orange, in: .circle)
        case .notChecked:
            Image(systemName: "minus")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Palette.gray)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Palette.gray, lineWidth: 1.2))
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
            title: String(localized: "Diagnostics"),
            subtitle: String(localized: "Engine health and local logs.")
        ) {
            if case .failed(let reason) = model.engineState {
                Banner(kind: .error, title: model.statusText, detail: reason) {
                    Button("Restart Engine") { model.restart() }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accentFill)
                }
            }
            engineFacts
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: String(localized: "Engine log")) {
                    Button("Show Logs in Finder") { model.showLogsInFinder() }
                        .controlSize(.small)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        if logTail.isEmpty { Text("The log is empty.") }
                        ForEach(logTail.indices, id: \.self) { index in logLine(logTail[index]) }
                    }
                    .font(.monoSmall)
                    .foregroundStyle(Palette.logText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
                .defaultScrollAnchor(.bottom)
                .accessibilityLabel("Engine log")
                .frame(height: 200)
                .background(Palette.logBackground, in: .rect(cornerRadius: 10))
                // The log box is dark in both appearances, so its scroll bar is too.
                .environment(\.colorScheme, .dark)
            }
            // When a translation makes the row too long, the note moves under the buttons instead of cutting them off.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    logButtons
                    privacyNote
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) { logButtons }
                    privacyNote
                }
            }
            SettingsSection(String(localized: "Feedback")) {
                SettingsRow(
                    title: String(localized: "Send feedback"),
                    detail: String(localized: "Opens GitHub, where you pick a bug report or a feature request.")
                ) {
                    Button("Send Feedback…") { NSWorkspace.shared.open(Feedback.formList) }
                }
            }
            SettingsSection(String(localized: "Developer")) {
                SettingsRow(
                    title: String(localized: "Accessibility permission experiment"),
                    detail: String(
                        localized: "Checks which process macOS credits with Miri's Accessibility permission.")
                ) {
                    Button("Permission Experiment…") { presenter?.show(.permissionExperiment) }
                }
            }
        }
        // The log keeps growing while the engine runs, so the page reads it again every second while it shows.
        .task {
            while !Task.isCancelled {
                readLog()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    @ViewBuilder private var logButtons: some View {
        // A failed engine has Restart Engine in the banner above.
        switch model.engineState {
        // A healthy engine needs no next step, so Restart Engine is a plain button here.
        case .running:
            Button("Restart Engine") { model.restart() }.fixedSize()
        case .restarting:
            Button("Restart Engine") {}.disabled(true).fixedSize()
        case .failed, .stopped: EmptyView()
        }
        Button("Copy Diagnostics…") { presenter?.show(.diagnostics) }.fixedSize()
    }

    private var privacyNote: some View {
        Text("Logs stay on this Mac. Miri sends no telemetry.")
            .font(.detail)
            .foregroundStyle(Palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var engineFacts: some View {
        HStack(spacing: 0) {
            fact(String(localized: "Engine"), value: engineWord, dot: model.stateColor)
            Rectangle().fill(Palette.divider).frame(width: 1)
            fact(
                String(localized: "Process"), value: processText, dot: nil,
                muted: processText == String(localized: "None"))
            Rectangle().fill(Palette.divider).frame(width: 1)
            fact(String(localized: "Displays"), value: "\(NSScreen.screens.count)", dot: nil)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Palette.group, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.groupRing, lineWidth: 1))
    }

    /// One fact. A missing value, such as no engine process, is drawn quieter than real data.
    private func fact(_ title: String, value: String, dot: Color?, muted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.detail)
                .foregroundStyle(Palette.secondaryText)
            HStack(spacing: 7) {
                if let dot { Circle().fill(dot).frame(width: 8, height: 8) }
                Text(value)
                    .font(.heroTitle)
                    .foregroundStyle(muted ? Palette.secondaryText : Palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var engineWord: String {
        switch model.engineState {
        case .running: String(localized: "Running")
        case .restarting: String(localized: "Restarting")
        case .failed: String(localized: "Failed")
        case .stopped:
            model.startBlockers.isEmpty ? String(localized: "Stopped") : String(localized: "Waiting for setup")
        }
    }

    private var processText: String {
        switch model.engineState {
        case .running(let pid): String(localized: "pid \(String(pid))")
        case .restarting, .failed, .stopped: String(localized: "None")
        }
    }

    /// One log line. A wrapped message stays indented under its own text, so it never reads as a new entry.
    @ViewBuilder private func logLine(_ line: String) -> some View {
        if let match = line.wholeMatch(of: /(\d{2}:\d{2}:\d{2}  \S+\s+)(.*)/) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(match.1).fixedSize()
                Text(match.2).fixedSize(horizontal: false, vertical: true)
            }
            // VoiceOver reads the time and the message as one line.
            .accessibilityElement(children: .combine)
        } else {
            Text(line).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func readLog() {
        // Only a changed log replaces the text, so a selection in it survives the refresh.
        let lines = model.log.tail(maximum: 6_000)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .suffix(40)
            .map { Self.shortLine(String($0)) }
        if Array(lines) != logTail { logTail = Array(lines) }
    }

    /// Keeps the local time, level, and message of an engine log line, and drops the date and the Rust source location.
    /// For example `2026-11-07T09:49:05.422397Z  INFO paneru::ecs: src/ecs.rs:17: Message` becomes
    /// `20:19:05  INFO  Message` in Melbourne. A line in another shape stays as it is.
    static func shortLine(_ line: String) -> String {
        guard
            let match = line.wholeMatch(
                of: /(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\S*\s+(\w+)\s+\S+?:\s+(?:\S+\.rs:\d+:\s+)?(.*)/),
            let date = try? Date(String(match.1) + "Z", strategy: .iso8601)
        else { return line }
        let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
        let level = String(match.2).padding(toLength: 5, withPad: " ", startingAt: 0)
        return "\(time)  \(level) \(match.3)"
    }
}

/// The Show in Dock switch, in Settings > General and in the first-launch window.
struct ShowInDockRow: View {
    let model: AppModel

    var body: some View {
        SettingsRow(
            title: String(localized: "Show in Dock"),
            detail: String(localized: "When off, open Miri from its menu bar icon.")
        ) {
            RowSwitch(
                label: String(localized: "Show in Dock"),
                isOn: Binding(get: { model.settings.showInDock }, set: { on in model.update { $0.showInDock = on } }))
        }
    }
}
