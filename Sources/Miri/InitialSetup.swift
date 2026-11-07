import AppKit
import MiriCore
import SwiftUI

/// The window Miri opens on first launch. It shows what blocks window management and recommends the strip swipe.
/// The v2 shortcut tour (#81) is deliberately not here.
struct InitialSetupView: View {
    let model: AppModel
    @Environment(\.presenter) private var presenter
    @State private var testing = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                header
                ConfigurationIssueNotice(model: model)
                SettingsSection("Window management") {
                    status
                    ForEach(model.startBlockers) { check in SetupCheckItem(check: check) }
                }
                swipe
            }
            .padding(.horizontal, 40)
            .padding(.top, 52)
            .padding(.bottom, 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Any spare height goes above the footer, so the footer always sits on the bottom edge.
            Spacer(minLength: 0)
            footer
        }
        // The window takes the height of its content, so it fits with or without blocking checks and never scrolls.
        .frame(width: 600)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Palette.content)
        .onAppear { model.refreshSetup() }
        .sheet(isPresented: $testing) { GestureTestSheet(model: model) }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .padding(-4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Miri")
                    .font(.pageTitle)
                    .foregroundStyle(Palette.primaryText)
                    .accessibilityAddTraits(.isHeader)
                Text("Miri lines up the windows on each display side by side in a strip that you scroll.")
                    .font(.rowTitle)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var status: some View {
        HStack(spacing: 12) {
            NoticeGlyph(kind: stateKind, size: 18)
            VStack(alignment: .leading, spacing: 2) {
                // The blocking checks are listed right below, so the title does not repeat the first one.
                Text(statusTitle)
                    .font(.rowTitle.weight(.semibold))
                    .accessibilityLabel(stateKind.spokenPrefix + statusTitle)
                    .foregroundStyle(Palette.primaryText)
                    .modifier(StatusValue(value: model.statusText))
                Text(statusDetail)
                    .font(.detail)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if canStart {
                // Starting is the next step here, so it is the prominent button and Return presses it.
                Button("Start Window Management") { model.start() }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accentFill)
                    .keyboardShortcut(.defaultAction)
            } else if case .failed = model.engineState {
                Button("Restart Engine") { model.restart() }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accentFill)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 50)
    }

    /// The notice kind of the state, so its glyph and spoken prefix match the Settings banners.
    private var stateKind: NoticeKind {
        switch model.engineState {
        case .running: .success
        case .restarting: .warning
        case .failed: .error
        case .stopped: model.startBlockers.isEmpty ? .neutral : .warning
        }
    }

    private var statusTitle: String { model.startBlockers.isEmpty ? model.statusText : "Waiting for setup" }

    private var canStart: Bool { model.engineState == .stopped && model.startBlockers.isEmpty }

    /// Whether the status row holds the main action, Start or Restart, so Done steps back to a plain button.
    private var statusHasMainAction: Bool {
        if case .failed = model.engineState { return true }
        return canStart
    }

    private var statusDetail: String {
        switch model.engineState {
        case .running: "Keyboard shortcuts work now."
        case .restarting: "The engine is restarting. Keyboard shortcuts resume when it is ready."
        case .failed: "Restart the engine to manage windows again. Settings > Diagnostics has the log."
        case .stopped where !model.startBlockers.isEmpty: AppModel.startsWhenReadySentence
        case .stopped: "Keyboard shortcuts work once Miri starts."
        }
    }

    private var swipe: some View {
        SettingsSection("Strip swipe") {
            SettingsRow(
                title: "Fingers", detail: "Four is recommended. Three fingers can clash with Three Finger Drag."
            ) {
                SegmentedChoice(
                    label: "Fingers",
                    selection: Binding(
                        get: { model.settings.stripGesture },
                        set: { value in model.update { $0.stripGesture = value } }),
                    options: [("Three", .three), ("Four", .four), ("Off", .off)])
            }
            if model.settings.stripGesture != .off {
                SettingsRow(title: "Swipe test", detail: testDetail) {
                    Button("Test Gesture…") { testing = true }
                        .disabled(model.gestureTestBlocker != nil)
                }
                if case .conflict(let message) = model.gestureState {
                    NoticeRow(kind: .warning, text: message) {
                        if let url = model.settings.stripGesture.fingers.flatMap(model.gestureCheck)?.settingsURL {
                            Button("Open Trackpad Settings") { NSWorkspace.shared.open(url) }
                        }
                    }
                }
            }
        }
    }

    /// The swipe's state, and why the test is not available yet. Only a macOS conflict gets a warning.
    private var testDetail: String {
        switch model.gestureState {
        case .off: "Off."
        case .enabled(let date): AppModel.confirmedSentence(date)
        // The same reason as on the Gestures page, such as "Start window management to test the swipe."
        case .needsTest: model.gestureTestBlocker ?? "The swipe stays off until you test it."
        case .conflict: "Off, because macOS uses this swipe."
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("You can change all of this later in Settings.")
                .font(.detail)
                .foregroundStyle(Palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if statusHasMainAction {
                Button("Done") { presenter?.close(.initialSetup) }
            } else {
                Button("Done") { presenter?.close(.initialSetup) }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accentFill)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .overlay(alignment: .top) { Rectangle().fill(Palette.divider).frame(height: 1) }
    }
}
