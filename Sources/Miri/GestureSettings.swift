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
            title: String(localized: "Gestures"),
            subtitle:
                String(localized: "Scroll the strip with a swipe on the trackpad.")
        ) {
            ConfigurationIssueNotice(model: model)
            hero
            SettingsSection(String(localized: "Strip swipe")) {
                SettingsRow(
                    title: String(localized: "Fingers"),
                    detail: String(localized: "Four is recommended. Three fingers can clash with Three Finger Drag.")
                ) {
                    SegmentedChoice(
                        label: String(localized: "Fingers"), selection: setting(\.stripGesture),
                        options: [
                            (String(localized: "Three"), .three), (String(localized: "Four"), .four),
                            (String(localized: "Off"), .off),
                        ])
                }
                SettingsRow(
                    title: String(localized: "Direction"),
                    detail: String(localized: "Changing fingers or direction needs a new test.")
                ) {
                    SegmentedChoice(
                        label: String(localized: "Direction"), selection: setting(\.reverseSwipe),
                        options: [(String(localized: "Follow fingers"), false), (String(localized: "Reversed"), true)])
                }
                if case .conflict(let message) = model.gestureState {
                    NoticeRow(kind: .warning, text: message) {
                        if let url = conflictCheck?.settingsURL {
                            Button("Open Trackpad Settings") { NSWorkspace.shared.open(url) }
                        }
                    }
                }
            }
            Text("Keyboard shortcuts work whether the swipe is on or off. Miri never changes macOS settings.")
                .font(.detail)
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
                    .font(.small.weight(.semibold))
                    .tracking(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(eyebrow.color)
                Text(heroTitle)
                    .font(.heroTitle)
                    .foregroundStyle(Palette.primaryText)
                    .modifier(StatusValue(value: model.gestureSummary))
                Text(heroDetail)
                    .font(.detail)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 8) {
                // A disabled test is an ordinary button, so it does not look like the next step.
                if model.gestureTestBlocker == nil {
                    Button("Test Gesture…") { testing = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accentFill)
                } else {
                    // macOS shows no tooltip on a disabled button, so the help sits on a wrapper around it.
                    Button("Test Gesture…") {}
                        .disabled(true)
                        .accessibilityHint(model.gestureTestBlocker ?? "")
                        .padding(1)
                        .contentShape(.rect)
                        .help(model.gestureTestBlocker ?? "")
                }
                if model.gestureVerification != nil {
                    Button("Report a macOS Gesture Change") { confirmingReport = true }
                }
            }
            .fixedSize()
        }
        .padding(20)
        .background(heroTint, in: .rect(cornerRadius: 10))
    }

    private var heroTint: Color {
        if case .conflict = model.gestureState { Palette.warningTint } else { Palette.heroTint }
    }

    private var eyebrow: (text: String, color: Color) {
        switch model.gestureState {
        case .off: (String(localized: "Off"), Palette.secondaryText)
        case .enabled: (String(localized: "On"), Palette.greenText)
        case .needsTest: (String(localized: "Needs a test"), Palette.accentText)
        case .conflict: (String(localized: "Blocked by macOS"), Palette.orange)
        }
    }

    private var heroTitle: String {
        switch model.settings.stripGesture {
        case .three: String(localized: "Three-finger swipe")
        case .four: String(localized: "Four-finger swipe")
        case .off: String(localized: "Strip swipe is off")
        }
    }

    private var heroDetail: String {
        switch model.gestureState {
        case .off:
            String(localized: "Choose three or four fingers below to use the swipe.")
        case .enabled(let date): AppModel.confirmedSentence(date)
        case .needsTest(let reason, let detectionUnavailable):
            [
                reason.sentence, String(localized: "Test it to turn it on."),
                detectionUnavailable
                    ? String(localized: "Miri can't read your macOS gesture settings, so the test is the only check.")
                    : nil,
                model.gestureTestBlocker,
            ].compactMap(\.self).joined(separator: " ")
        case .conflict:
            String(localized: "Resolve the macOS conflict below, then test again.")
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
        .background(Palette.group, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.heroTileBorder, lineWidth: 1))
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
    /// Says when the user confirmed the swipe, in the same words on the Gestures page and in Set Up Miri.
    static func confirmedSentence(_ date: Date) -> String {
        String(
            localized:
                "You confirmed on \(date.formatted(date: .abbreviated, time: .omitted)) that the strip follows your fingers."
        )
    }

    /// One line about the strip swipe, which Settings and the test tools read as its status.
    var gestureSummary: String {
        switch gestureState {
        case .off: String(localized: "Off")
        case .enabled(let date):
            String(localized: "On, verified by user test on \(date.formatted(date: .abbreviated, time: .omitted))")
        case .needsTest(let reason, _): String(localized: "Off until tested: \(reason.explanation)")
        case .conflict: String(localized: "Off: macOS uses this swipe")
        }
    }
}

extension MiriCore.GestureState.TestReason {
    var explanation: String {
        switch self {
        case .neverTested: String(localized: "not tested yet")
        case .fingersChanged: String(localized: "the finger count changed")
        case .directionChanged: String(localized: "the direction changed")
        case .macOSChanged: String(localized: "macOS was updated")
        case .gestureSettingsChanged: String(localized: "macOS trackpad gestures changed")
        }
    }

    /// The reason as a sentence for the Gestures page, or nothing when the swipe was never tested.
    var sentence: String? {
        switch self {
        case .neverTested: nil
        case .fingersChanged: String(localized: "The finger count changed.")
        case .directionChanged: String(localized: "The direction changed.")
        case .macOSChanged: String(localized: "macOS was updated.")
        case .gestureSettingsChanged: String(localized: "Your macOS trackpad gestures changed.")
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
        VStack(alignment: .leading, spacing: 0) {
            Text("Gesture test")
                .font(.small.weight(.semibold))
                .tracking(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.secondaryText)
                .padding(.bottom, 8)
            Text(title)
                .font(.heroTitle)
                .foregroundStyle(Palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 6)
            Text(detail)
                .font(.detail)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)
            switch test.phase {
            case .failed, .inconclusive:
                // The title already says what went wrong, so a status box would only repeat it.
                EmptyView()
            case .idle, .watching, .passedAwaitingConfirmation:
                progress.padding(.bottom, 20)
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                buttons
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(width: 480, alignment: .leading)
        .background(Palette.content)
        .onAppear { test.start() }
        .onDisappear { test.cancel() }
        // VoiceOver users hear each step, because the focus stays on the buttons while the text changes.
        .onChange(of: test.phase) { AccessibilityNotification.Announcement(announcement).post() }
        // Closing Settings hides its window without removing this view, so onDisappear alone can miss it.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in test.cancel() }
    }

    private var title: String {
        switch test.phase {
        case .idle, .watching: swipeInstruction
        case .passedAwaitingConfirmation: String(localized: "Did the strip follow your fingers?")
        case .failed(let reason): reason
        case .inconclusive:
            String(
                localized:
                    "Miri did not see the strip move both ways within \(GestureTest.timeout.components.seconds) seconds."
            )
        }
    }

    private var detail: String {
        switch test.phase {
        case .idle, .watching: String(localized: "Keep at least two windows on this display so the strip can move.")
        case .passedAwaitingConfirmation:
            String(
                localized: "Miri saw the strip move both ways and no macOS action. Only your answer turns the swipe on."
            )
        case .failed, .inconclusive: String(localized: "The swipe stays off. Keyboard shortcuts keep working.")
        }
    }

    /// What Miri has seen so far, in a tinted box like the status cards in Settings.
    private var progress: some View {
        HStack(spacing: 10) {
            switch test.phase {
            case .idle, .watching(movementSeen: false):
                ProgressView().controlSize(.small)
                Text("Waiting for the strip to move…")
            case .watching(movementSeen: true):
                checkmark
                Text("The strip moved. Keep swiping left and right.")
            case .passedAwaitingConfirmation:
                checkmark
                Text("The strip moved both ways.")
            case .failed, .inconclusive:
                EmptyView()
            }
        }
        .font(.detail)
        .foregroundStyle(Palette.primaryText)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(Palette.heroTint, in: .rect(cornerRadius: 10))
    }

    private var announcement: String {
        switch test.phase {
        case .idle, .watching(movementSeen: false): title
        case .watching(movementSeen: true): String(localized: "The strip moved. Keep swiping left and right.")
        case .passedAwaitingConfirmation: String(localized: "The strip moved both ways. Did it follow your fingers?")
        case .failed, .inconclusive: "\(title) \(detail)"
        }
    }

    private var checkmark: some View {
        NoticeGlyph(kind: .success, size: 18)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var buttons: some View {
        switch test.phase {
        case .idle, .watching:
            Button("Cancel", role: .cancel) { dismiss() }
        case .passedAwaitingConfirmation:
            Button("Cancel", role: .cancel) { dismiss() }
            Button("No") { test.deny() }
            Button("Yes") {
                test.confirm()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.accentFill)
            .keyboardShortcut(.defaultAction)
        case .failed, .inconclusive:
            Button("Done", role: .cancel) { dismiss() }
            Button("Try Again") { test.start() }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accentFill)
                .keyboardShortcut(.defaultAction)
        }
    }

    /// A whole sentence for each finger count, so a translation never shows an English number word.
    private var swipeInstruction: String {
        switch test.fingers ?? model.settings.stripGesture.fingers {
        case .three?: String(localized: "Swipe left and right with three fingers on the trackpad.")
        case .four?, nil: String(localized: "Swipe left and right with four fingers on the trackpad.")
        }
    }
}
