import AppKit
import MiriCore
import SwiftUI

/// Settings > Gestures: the strip swipe's state and test, its finger count and direction, and the change report.
struct GestureSettings: View {
    let model: AppModel
    @State private var testing = false
    @State private var confirmingReport = false

    var body: some View {
        SettingsPage(
            title: "Gestures",
            subtitle:
                "Swipe across the trackpad to scroll the strip. Miri turns the swipe on only after you test it and confirm that the strip followed your fingers."
        ) {
            ConfigurationIssueNotice(model: model)
            hero
            SettingsSection("Strip swipe") {
                SettingsRow(
                    title: "Fingers", detail: "Four is recommended. Three fingers can clash with Three Finger Drag."
                ) {
                    SegmentedChoice(
                        label: "Fingers", selection: setting(\.stripGesture),
                        options: [("Three", .three), ("Four", .four), ("Off", .off)])
                }
                SettingsRow(title: "Direction", detail: "Changing fingers or direction needs a new test.") {
                    SegmentedChoice(
                        label: "Direction", selection: setting(\.reverseSwipe),
                        options: [("Follow fingers", false), ("Reversed", true)])
                }
                if case .conflict(let message) = model.gestureState {
                    NoticeRow(kind: .warning, text: message) {
                        if let url = conflictCheck?.settingsURL {
                            Button("Open System Settings") { NSWorkspace.shared.open(url) }
                        }
                    }
                } else if let blocker = model.gestureTestBlocker, model.settings.stripGesture != .off {
                    NoticeRow(kind: .warning, text: blocker)
                }
            }
            Text("Keyboard shortcuts work whether the swipe is on or off. Miri never changes macOS settings.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondaryText)
        }
        .onAppear { model.refreshSetup() }
        .sheet(isPresented: $testing) { GestureTestSheet(model: model) }
        .confirmationDialog("Report a macOS gesture change?", isPresented: $confirmingReport) {
            Button("Report Change") { model.reportGestureChange() }
        } message: {
            Text("Miri turns the strip swipe off until you test it again.")
        }
    }

    private var hero: some View {
        HStack(spacing: 22) {
            TrackpadPicture(fingers: model.settings.stripGesture.fingers, reversed: model.settings.reverseSwipe)
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.text)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(eyebrow.color)
                Text(heroTitle)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Palette.primaryText)
                    .modifier(StatusValue(value: model.gestureSummary))
                LiveText(heroDetail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 8) {
                Button("Test Gesture…") { testing = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accent)
                    .disabled(model.gestureTestBlocker != nil)
                if model.gestureVerification != nil {
                    Button("Report a macOS Gesture Change") { confirmingReport = true }
                }
            }
            .fixedSize()
        }
        .padding(20)
        .background(Palette.heroTint, in: .rect(cornerRadius: 12))
    }

    private var eyebrow: (text: String, color: Color) {
        switch model.gestureState {
        case .off: ("Off", Palette.secondaryText)
        case .enabled: ("On", Palette.green)
        case .needsTest: ("Off until tested", Palette.orange)
        case .conflict: ("Off: macOS uses this swipe", Palette.orange)
        }
    }

    private var heroTitle: String {
        switch model.settings.stripGesture {
        case .three: "Three-finger swipe"
        case .four: "Four-finger swipe"
        case .off: "Strip swipe is off"
        }
    }

    private var heroDetail: String {
        switch model.gestureState {
        case .off:
            "Choose three or four fingers below to use the swipe."
        case .enabled(let date):
            "You confirmed on \(date.formatted(date: .abbreviated, time: .omitted)) that the strip follows your fingers."
        case .needsTest(let reason, let detectionUnavailable):
            "Test it to turn it on: \(reason.explanation)."
                + (detectionUnavailable
                    ? " Miri can't read your macOS gesture settings, so it can't check them for you." : "")
        case .conflict:
            "macOS uses this swipe. Turn it off in System Settings, then test again."
        }
    }

    private var conflictCheck: SetupCheck? {
        model.settings.stripGesture.fingers.flatMap(model.gestureCheck)
    }

    private func setting<Value>(_ key: WritableKeyPath<MiriSettings, Value>) -> Binding<Value> {
        Binding(get: { model.settings[keyPath: key] }, set: { value in model.update { $0[keyPath: key] = value } })
    }
}

/// A sketch of a trackpad with one dot per finger and an arrow for the direction the strip moves.
private struct TrackpadPicture: View {
    let fingers: GestureFingers?
    let reversed: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle().fill(fingers == nil ? Palette.gray : Palette.accent).frame(width: 13, height: 13)
                }
            }
            Image(systemName: reversed ? "arrow.left" : "arrow.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(fingers == nil ? Palette.gray : Palette.accent)
        }
        .frame(width: 132, height: 92)
        .background(Palette.group, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.heroTileBorder, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var count: Int {
        switch fingers {
        case .three?: 3
        case .four?, nil: 4
        }
    }
}

extension AppModel {
    /// One line about the strip swipe, which Settings and the test tools read as its status.
    var gestureSummary: String {
        switch gestureState {
        case .off: "Off"
        case .enabled(let date): "On, verified by user test on \(date.formatted(date: .abbreviated, time: .omitted))"
        case .needsTest(let reason, _): "Off until tested: \(reason.explanation)"
        case .conflict: "Off: macOS uses this swipe"
        }
    }
}

/// The finger count choice, the swipe status, and the gesture test, shared by Settings and initial setup.
struct StripSwipeSections<ChoiceAccessory: View, TestAccessory: View>: View {
    let model: AppModel
    var header: LocalizedStringKey? = nil
    let choiceFooter: LocalizedStringKey
    let testFooter: LocalizedStringKey
    @ViewBuilder let choiceAccessory: ChoiceAccessory
    @ViewBuilder let testAccessory: TestAccessory
    @State private var testing = false

    var body: some View {
        Section {
            Picker(
                "Strip swipe",
                selection: Binding(
                    get: { model.settings.stripGesture }, set: { value in model.update { $0.stripGesture = value } })
            ) {
                Text("Off").tag(StripGesture.off)
                Text("Three fingers").tag(StripGesture.three)
                Text("Four fingers (recommended)").tag(StripGesture.four)
            }
            choiceAccessory
        } header: {
            if let header { Text(header) }
        } footer: {
            Text(choiceFooter).foregroundStyle(.secondary)
        }
        Section {
            GestureStatusRow(model: model)
            HStack {
                Button("Test Gesture…") { testing = true }
                    .disabled(model.gestureTestBlocker != nil)
                Spacer()
                testAccessory
            }
            .sheet(isPresented: $testing) { GestureTestSheet(model: model) }
            if let blocker = model.gestureTestBlocker, model.settings.stripGesture != .off {
                Text(blocker).foregroundStyle(.secondary)
            }
        } footer: {
            Text(testFooter).foregroundStyle(.secondary)
        }
    }
}

extension StripSwipeSections where ChoiceAccessory == EmptyView, TestAccessory == EmptyView {
    init(
        model: AppModel, header: LocalizedStringKey? = nil, choiceFooter: LocalizedStringKey,
        testFooter: LocalizedStringKey
    ) {
        self.init(
            model: model, header: header, choiceFooter: choiceFooter, testFooter: testFooter,
            choiceAccessory: { EmptyView() },
            testAccessory: { EmptyView() })
    }
}

struct GestureStatusRow: View {
    let model: AppModel

    var body: some View {
        LabeledContent("Status") {
            VStack(alignment: .trailing, spacing: 3) {
                LiveText(summary)
                switch model.gestureState {
                case .needsTest(_, detectionUnavailable: true):
                    Text("Unable to verify").foregroundStyle(.secondary)
                case .conflict(let message):
                    LiveText(message).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = conflictCheck?.settingsURL {
                        Button("Open System Settings") { NSWorkspace.shared.open(url) }
                    }
                case .off, .needsTest, .enabled: EmptyView()
                }
            }
        }
    }

    private var summary: String { model.gestureSummary }

    private var conflictCheck: SetupCheck? {
        model.settings.stripGesture.fingers.flatMap(model.gestureCheck)
    }
}

extension MiriCore.GestureState.TestReason {
    var explanation: String {
        switch self {
        case .neverTested: "not tested yet"
        case .fingersChanged: "the finger count changed"
        case .directionChanged: "the direction changed"
        case .macOSChanged: "macOS was updated"
        case .engineChanged: "Miri's engine was updated"
        case .gestureSettingsChanged: "macOS trackpad gestures changed"
        }
    }
}

/// Guides one gesture test, from swiping to the user's confirmation.
struct GestureTestSheet: View {
    let model: AppModel
    @State private var test: GestureTest
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel) {
        self.model = model
        _test = State(initialValue: GestureTest(model: model))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Test the Strip Swipe").font(.headline)
            content
        }
        .padding(20)
        .frame(width: 420, alignment: .leading)
        .onAppear { test.start() }
        .onDisappear { test.cancel() }
        // Closing Settings hides its window without removing this view, so onDisappear alone can miss it.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in test.cancel() }
    }

    @ViewBuilder private var content: some View {
        switch test.phase {
        case .idle, .watching:
            Text("Swipe left and right with \(fingerWord) fingers on the trackpad.")
            Text("Keep at least two windows on this display so the strip can move.")
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if case .watching(movementSeen: true) = test.phase {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("The strip moved. Keep swiping left and right.")
                } else {
                    ProgressView().controlSize(.small)
                    Text("Waiting for the strip to move…")
                }
            }
            buttons { Button("Cancel", role: .cancel) { dismiss() } }
        case .passedAwaitingConfirmation:
            Text("Did the strip follow your fingers?")
            Text("Miri saw the strip move both ways and no macOS action. Only your answer turns the swipe on.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            buttons {
                Button("Cancel", role: .cancel) { dismiss() }
                Button("It Did Not Work") { test.deny() }
                Button("The Strip Followed My Fingers") {
                    test.confirm()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        case .failed(let reason):
            Label(reason, systemImage: "exclamationmark.triangle.fill")
            Text("The swipe stays off. Keyboard shortcuts keep working.").foregroundStyle(.secondary)
            retryButtons
        case .inconclusive:
            Label("Miri did not see the strip move both ways within 20 seconds.", systemImage: "questionmark.circle")
            Text("The swipe stays off. Keyboard shortcuts keep working.").foregroundStyle(.secondary)
            retryButtons
        }
    }

    private var retryButtons: some View {
        buttons {
            Button("Done", role: .cancel) { dismiss() }
            Button("Try Again") { test.start() }.keyboardShortcut(.defaultAction)
        }
    }

    private func buttons(@ViewBuilder _ content: () -> some View) -> some View {
        HStack {
            Spacer()
            content()
        }
    }

    private var fingerWord: String {
        switch test.fingers ?? model.settings.stripGesture.fingers {
        case .three?: "three"
        case .four?, nil: "four"
        }
    }
}
