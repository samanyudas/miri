import AppKit
import MiriCore
import SwiftUI

/// The strip swipe choice, its status, and the gesture test.
struct GestureSettings: View {
    let model: AppModel
    @State private var testing = false
    @State private var confirmingReport = false

    var body: some View {
        Form {
            ConfigurationIssueBanner(model: model)
            Section {
                Picker("Strip swipe", selection: setting(\.stripGesture)) {
                    Text("Off").tag(StripGesture.off)
                    Text("Three fingers").tag(StripGesture.three)
                    Text("Four fingers (recommended)").tag(StripGesture.four)
                }
                Toggle("Reverse swipe direction", isOn: setting(\.reverseSwipe))
            } footer: {
                Text(
                    "Swipe left or right on the trackpad to slide the windows. The strip follows your fingers unless you reverse it."
                )
                .foregroundStyle(.secondary)
            }
            Section {
                GestureStatusRow(model: model)
                HStack {
                    Button("Test Gesture…") { testing = true }
                        .disabled(model.gestureTestBlocker != nil)
                    Spacer()
                    Button("Report a macOS Gesture Change") { confirmingReport = true }
                        .disabled(model.gestureVerification == nil)
                }
                if let blocker = model.gestureTestBlocker, model.settings.stripGesture != .off {
                    Text(blocker).foregroundStyle(.secondary)
                }
            } footer: {
                Text(
                    "Miri turns the swipe on only after you test it and confirm that the strip followed your fingers. Keyboard shortcuts work either way. Miri never changes macOS settings."
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refreshSetup() }
        .sheet(isPresented: $testing) { GestureTestSheet(model: model) }
        .confirmationDialog("Report a macOS gesture change?", isPresented: $confirmingReport) {
            Button("Report Change") { model.reportGestureChange() }
        } message: {
            Text("Miri turns the strip swipe off until you test it again.")
        }
    }

    private func setting<Value>(_ key: WritableKeyPath<MiriSettings, Value>) -> Binding<Value> {
        Binding(get: { model.settings[keyPath: key] }, set: { value in model.update { $0[keyPath: key] = value } })
    }
}

struct GestureStatusRow: View {
    let model: AppModel

    var body: some View {
        LabeledContent("Status") {
            VStack(alignment: .trailing, spacing: 3) {
                Text(summary)
                switch model.gestureState {
                case .needsTest(_, detectionUnavailable: true):
                    Text("Unable to verify").foregroundStyle(.secondary)
                case .conflict(let message):
                    Text(message).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = conflictCheck?.settingsURL {
                        Button("Open System Settings") { NSWorkspace.shared.open(url) }
                    }
                case .off, .needsTest, .enabled: EmptyView()
                }
            }
        }
    }

    private var summary: String {
        switch model.gestureState {
        case .off: "Off"
        case .enabled(let date): "On, verified by user test on \(date.formatted(date: .abbreviated, time: .omitted))"
        case .needsTest(let reason, _): "Off until tested: \(reason.explanation)"
        case .conflict: "Off: macOS uses this swipe"
        }
    }

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
