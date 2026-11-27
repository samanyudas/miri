import AppKit
import MiriCore
import SwiftUI

struct GestureSettings: View {
    let model: AppModel
    @State private var testing = false

    var body: some View {
        SettingsPage(
            title: String(localized: "Gestures"),
            subtitle:
                String(localized: "Scroll the strip with a swipe on the trackpad.")
        ) {
            ConfigurationIssueNotice(model: model)
            hero
            SettingsSection(String(localized: "Strip swipe")) {
                StripSwipeFingersRow(model: model)
                SettingsRow(title: String(localized: "Direction")) {
                    SegmentedChoice(
                        label: String(localized: "Direction"), selection: model.setting(\.reverseSwipe),
                        options: [(String(localized: "Follow fingers"), false), (String(localized: "Reversed"), true)])
                }
                StripSwipeConflictRow(model: model)
            }
            SettingsSection(String(localized: "Scrolling")) {
                SettingsRow(
                    title: String(localized: "Scroll by"),
                    detail: String(
                        localized:
                            "Window by window lets each swipe follow your fingers, then land on one window. The trackpad clicks when the window it would land on changes. Each Option-scroll step moves one window."
                    )
                ) {
                    SegmentedChoice(
                        label: String(localized: "Scroll by"), selection: model.setting(\.stripScrolling),
                        options: [
                            (String(localized: "Continuous"), .continuous),
                            (String(localized: "Window by window"), .window),
                        ])
                }
                SettingsRow(
                    title: String(localized: "Swipe moves"),
                    detail: String(
                        localized:
                            "Under pointer moves the strip on the display the pointer is on. Focused window moves the strip of the window you are using, wherever the pointer is. This also applies to Option-scroll."
                    )
                ) {
                    SegmentedChoice(
                        label: String(localized: "Swipe moves"), selection: model.setting(\.swipeTarget),
                        options: [
                            (String(localized: "Under pointer"), .pointer),
                            (String(localized: "Focused window"), .focused),
                        ])
                }
            }
            Text("Keyboard shortcuts work whether the swipe is on or off. Miri never changes macOS settings.")
                .font(.detail)
                .foregroundStyle(Palette.secondaryText)
        }
        .onAppear { model.refreshSetup() }
        .sheet(isPresented: $testing) { GestureTestSheet(model: model) }
    }

    private var hero: some View {
        HeroCard(
            eyebrow: eyebrow.text, eyebrowColor: eyebrow.color, title: heroTitle, detail: heroDetail,
            statusValue: model.gestureSummary, tint: heroTint, spacing: 22
        ) {
            TrackpadPicture(fingers: model.settings.stripGesture.fingers, reversed: model.settings.reverseSwipe)
        } trailing: {
            // The test is offered only when Miri cannot read the macOS gesture settings.
            if case .needsTest = model.gestureState {
                GestureTestButton(blocker: model.gestureTestBlocker, prominentWhenEnabled: true) {
                    testing = true
                }
            }
        }
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
        case .enabled(let date?):
            String(
                localized:
                    "You confirmed on \(date.formatted(date: .abbreviated, time: .omitted)) that the strip follows your fingers."
            )
        case .enabled(nil): String(localized: "Miri checked your macOS trackpad gestures and found no conflict.")
        case .needsTest(let reason):
            [
                reason.sentence, String(localized: "Test it to turn it on."),
                String(localized: "Miri can't read your macOS gesture settings, so the test is the only check."),
                model.gestureTestBlocker,
            ].compactMap(\.self).joined(separator: " ")
        case .conflict:
            String(localized: "Change the macOS setting below to turn the swipe on.")
        }
    }
}

struct StripSwipeFingersRow: View {
    let model: AppModel

    var body: some View {
        SettingsRow(
            title: String(localized: "Fingers"),
            detail: String(localized: "Four is recommended. Three fingers can clash with Three Finger Drag.")
        ) {
            SegmentedChoice(
                label: String(localized: "Fingers"), selection: model.setting(\.stripGesture),
                options: [
                    (String(localized: "Three"), .three), (String(localized: "Four"), .four),
                    (String(localized: "Off"), .off),
                ])
        }
    }
}

struct StripSwipeConflictRow: View {
    let model: AppModel

    var body: some View {
        if case .conflict(let message) = model.gestureState {
            NoticeRow(kind: .warning, text: message) {
                if let url = model.settings.stripGesture.fingers.flatMap(model.gestureCheck)?.settingsURL {
                    Button("Open Trackpad Settings") { NSWorkspace.shared.open(url) }
                }
            }
        }
    }
}

struct GestureTestButton: View {
    let blocker: String?
    var prominentWhenEnabled = false
    let action: () -> Void

    var body: some View {
        if blocker == nil {
            if prominentWhenEnabled {
                Button("Test Gesture…", action: action)
                    .prominentButton()
                    .fixedSize()
            } else {
                Button("Test Gesture…", action: action)
                    .fixedSize()
            }
        } else {
            // macOS shows no tooltip on a disabled button, so the help sits on a wrapper around it.
            Button("Test Gesture…") {}
                .disabled(true)
                .accessibilityHint(blocker ?? "")
                .padding(1)
                .contentShape(.rect)
                .help(blocker ?? "")
                .fixedSize()
        }
    }
}

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
    /// One line about the strip swipe, which Settings and the test tools read as its status.
    var gestureSummary: String {
        switch gestureState {
        case .off: String(localized: "Off")
        case .enabled(let date?):
            String(localized: "On, verified by user test on \(date.formatted(date: .abbreviated, time: .omitted))")
        case .enabled(nil): String(localized: "On")
        case .needsTest(let reason): String(localized: "Off until tested: \(reason.explanation)")
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

struct GestureTestSheet: View {
    let model: AppModel
    @State private var test: GestureTest
    @State private var sheetWindow = WeakWindowBox()
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel) {
        self.model = model
        _test = State(initialValue: GestureTest(model: model))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Gesture test")
                .eyebrowStyle(color: Palette.secondaryText)
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
        .background(WindowReader(box: sheetWindow))
        .onAppear { test.start() }
        .onDisappear { test.cancel() }
        // VoiceOver users hear each step, because the focus stays on the buttons while the text changes.
        .onChange(of: test.phase) { AccessibilityNotification.Announcement(announcement).post() }
        // Closing Settings hides its window without removing this view, so onDisappear alone can miss it.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let closing = notification.object as? NSWindow,
                closing === sheetWindow.window || closing === sheetWindow.window?.sheetParent
            else { return }
            test.cancel()
        }
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
            .prominentButton()
            .keyboardShortcut(.defaultAction)
        case .failed, .inconclusive:
            Button("Done", role: .cancel) { dismiss() }
            Button("Try Again") { test.start() }
                .prominentButton()
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

private final class WeakWindowBox {
    weak var window: NSWindow?
}

private struct WindowReader: NSViewRepresentable {
    let box: WeakWindowBox

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.box = box
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        nsView.box = box
    }

    final class ObserverView: NSView {
        weak var box: WeakWindowBox?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            box?.window = window
        }
    }
}
