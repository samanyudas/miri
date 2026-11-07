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
        VStack(alignment: .leading, spacing: 0) {
            Text("Gesture test")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.secondaryText)
                .padding(.bottom, 8)
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 6)
            Text(detail)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)
            progress
                .padding(.bottom, 20)
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
        // Closing Settings hides its window without removing this view, so onDisappear alone can miss it.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in test.cancel() }
    }

    private var title: String {
        switch test.phase {
        case .idle, .watching: "Swipe left and right with \(fingerWord) fingers on the trackpad."
        case .passedAwaitingConfirmation: "Did the strip follow your fingers?"
        case .failed(let reason): reason
        case .inconclusive: "Miri did not see the strip move both ways within 20 seconds."
        }
    }

    private var detail: String {
        switch test.phase {
        case .idle, .watching: "Keep at least two windows on this display so the strip can move."
        case .passedAwaitingConfirmation:
            "Miri saw the strip move both ways and no macOS action. Only your answer turns the swipe on."
        case .failed, .inconclusive: "The swipe stays off. Keyboard shortcuts keep working."
        }
    }

    /// What Miri has seen so far, in a tinted box like the status cards in Settings.
    private var progress: some View {
        HStack(spacing: 10) {
            switch test.phase {
            case .idle, .watching(movementSeen: false):
                ProgressView().controlSize(.small)
                LiveText("Waiting for the strip to move…")
            case .watching(movementSeen: true):
                checkmark
                LiveText("The strip moved. Keep swiping left and right.")
            case .passedAwaitingConfirmation:
                checkmark
                LiveText("The strip moved both ways.")
            case .failed:
                NoticeGlyph(kind: .warning, size: 18)
                LiveText("The test found a problem.")
            case .inconclusive:
                NoticeGlyph(kind: .warning, size: 18)
                LiveText("The test timed out.")
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Palette.primaryText)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(Palette.heroTint, in: .rect(cornerRadius: 10))
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(Palette.green, in: .circle)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var buttons: some View {
        switch test.phase {
        case .idle, .watching:
            Button("Cancel", role: .cancel) { dismiss() }
        case .passedAwaitingConfirmation:
            Button("Cancel", role: .cancel) { dismiss() }
            Button("It Did Not Work") { test.deny() }
            Button("The Strip Followed My Fingers") {
                test.confirm()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.accent)
            .keyboardShortcut(.defaultAction)
        case .failed, .inconclusive:
            Button("Done", role: .cancel) { dismiss() }
            Button("Try Again") { test.start() }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .keyboardShortcut(.defaultAction)
        }
    }

    private var fingerWord: String {
        switch test.fingers ?? model.settings.stripGesture.fingers {
        case .three?: "three"
        case .four?, nil: "four"
        }
    }
}
