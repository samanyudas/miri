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
            ScrollView {
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
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            stateGlyph.accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.statusText)
                    .font(.rowTitle.weight(.semibold))
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
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 50)
    }

    /// The same symbols as the Settings notices: a check while running, and the notice glyph of each other state.
    @ViewBuilder private var stateGlyph: some View {
        switch model.engineState {
        case .running:
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(Palette.onStatus)
                .frame(width: 18, height: 18)
                .background(Palette.green, in: .circle)
        case .restarting: NoticeGlyph(kind: .warning, size: 18)
        case .failed: NoticeGlyph(kind: .error, size: 18)
        case .stopped: NoticeGlyph(kind: model.startBlockers.isEmpty ? .neutral : .warning, size: 18)
        }
    }

    private var canStart: Bool { model.engineState == .stopped && model.startBlockers.isEmpty }

    private var statusDetail: String {
        switch model.engineState {
        case .running: "Keyboard shortcuts work now."
        case .restarting: "The engine is restarting. Keyboard shortcuts resume when it is ready."
        case .failed: "Restart the engine to manage windows again. Settings > Diagnostics has the log."
        case .stopped where !model.startBlockers.isEmpty: "Miri starts by itself when the checks below pass."
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
        case .enabled(let date): "On. You confirmed it on \(date.formatted(date: .abbreviated, time: .omitted))."
        case .needsTest:
            model.engineState.isRunning
                ? "The swipe stays off until you test it."
                : "Start window management first, then test the swipe. It stays off until you do."
        case .conflict: "Off, because macOS uses this swipe."
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("You can change all of this later in Settings.")
                .font(.detail)
                .foregroundStyle(Palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if canStart {
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
