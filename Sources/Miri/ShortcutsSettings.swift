import Carbon.HIToolbox
import MiriCore
import SwiftUI

struct ShortcutsSettings: View {
    private struct Notice: Equatable {
        let action: ShortcutAction
        let text: String
    }

    private struct PendingConflict {
        let chord: Chord
        let action: ShortcutAction
        let shortcut: SystemShortcut
    }

    let model: AppModel
    @State private var filter = ""
    @State private var recorder = ShortcutRecorder()
    @State private var recording: ShortcutAction?
    @State private var heldModifiers: Set<ChordModifier> = []
    @State private var notice: Notice?
    @State private var pendingConflict: PendingConflict?
    @State private var confirmingReset = false
    @State private var hovered: ShortcutAction?

    var body: some View {
        SettingsPage(
            title: "Shortcuts",
            subtitle:
                "Press + to add a shortcut. Miri blocks keys another action uses, and warns about macOS clashes."
        ) {
            ConfigurationIssueNotice(model: model)
            if let shortcuts = model.shortcuts {
                HStack(spacing: 10) {
                    SearchField(text: $filter, prompt: "Search actions or shortcuts")
                    Button("Reset to Defaults…") { confirmingReset = true }
                        .controlSize(.large)
                }
                if !model.keptDefaults.isEmpty {
                    SettingsSection("Updated default shortcuts") {
                        ForEach(model.keptDefaults, id: \.self) { kept in keptDefaultRow(kept) }
                    }
                }
                let actions = ShortcutAction.editable.filter { matches($0, shortcuts) }
                let others = shortcuts.others.filter { matches($0) }
                if actions.isEmpty, others.isEmpty {
                    VStack(spacing: 10) {
                        Text("No shortcuts match \u{201C}\(filter)\u{201D}.")
                            .font(.rowTitle)
                            .foregroundStyle(Palette.secondaryText)
                        Button("Clear Search") { filter = "" }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                if !actions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Actions")
                        SettingsGroup {
                            ForEach(actions, id: \.self) { action in
                                row(action, chords: shortcuts.chords(for: action))
                            }
                        }
                        Text(
                            "Press Escape to cancel recording. Stop window manager works even while the engine is stopped."
                        )
                        .font(.detail)
                        .foregroundStyle(Palette.secondaryText)
                        .padding(.horizontal, 2)
                    }
                }
                if !others.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsSection("Other engine bindings") {
                            ForEach(others, id: \.self) { other in
                                HStack(spacing: 6) {
                                    Text(other.key)
                                        .font(.mono)
                                        .foregroundStyle(Palette.primaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    ForEach(other.chords, id: \.self) { chord in
                                        KeyCap(label: model.keyLayout.label(for: chord))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .frame(minHeight: 44)
                            }
                        }
                        Text("Miri does not list these engine commands. Edit them in the configuration file.")
                            .font(.detail)
                            .foregroundStyle(Palette.secondaryText)
                            .padding(.horizontal, 2)
                    }
                }
            }
        }
        .onDisappear(perform: stopRecording)
        .onChange(of: notice) { if let notice { AccessibilityNotification.Announcement(notice.text).post() } }
        .alert(
            conflictTitle,
            isPresented: Binding(get: { pendingConflict != nil }, set: { if !$0 { pendingConflict = nil } }),
            presenting: pendingConflict
        ) { conflict in
            Button("Use Anyway") { add(conflict.chord, to: conflict.action, allowingSystemConflict: true) }
            Button("Cancel", role: .cancel) {}
                .keyboardShortcut(.defaultAction)
        } message: { _ in
            Text("If you use it anyway, one of the two shortcuts may stop working.")
        }
        .alert("Replace all shortcuts with Miri's defaults?", isPresented: $confirmingReset) {
            Button("Replace", role: .destructive) {
                notice = nil
                model.resetShortcuts()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Miri backs up your configuration file first.")
        }
    }

    /// A default an upgrade could not move, with one button that moves it when another listed action holds it.
    private func keptDefaultRow(_ kept: KeptDefault) -> some View {
        let wanted = model.keyLayout.label(for: kept.wanted)
        let owner = ShortcutAction.editable.first { $0.title == kept.owner }
        return HStack(alignment: .center, spacing: 10) {
            NoticeGlyph(kind: .info)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(kept.action.title) has a new default, \(wanted), but \(kept.owner) uses it.")
                    .font(.rowTitle)
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(keptText(kept, movable: owner != nil))
                    .font(.detail)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let owner {
                Button("Use \(wanted)") {
                    notice = nil
                    // The owner can spell the same keys another way, such as `ctrl+alt-[` for `ctrl+alt-leftbracket`.
                    for chord in model.shortcuts?.chords(for: owner) ?? []
                    where model.keyLayout.conflicts(chord, kept.wanted) {
                        model.removeShortcut(chord, from: owner)
                    }
                    add(kept.wanted, to: kept.action, allowingSystemConflict: false)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accentFill)
                .help("Move \(wanted) from \(kept.owner) to \(kept.action.title)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func row(_ action: ShortcutAction, chords: [Chord]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // One line while the chips fit beside the title, and the chips wrap below it when they do not.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    actionTitle(action).fixedSize()
                    Spacer(minLength: 12)
                    chips(action, chords)
                    addButton(action)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        actionTitle(action).frame(maxWidth: .infinity, alignment: .leading)
                        addButton(action)
                    }
                    FlowLayout(spacing: 6) { chips(action, chords) }
                }
            }
            if let notice, notice.action == action {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    NoticeGlyph(kind: .error, size: 14)
                    Text(notice.text)
                        .font(.detail)
                        .foregroundStyle(Palette.errorText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .background(notice?.action == action ? Palette.errorTint : .clear)
        .contentShape(.rect)
        .onHover { inside in
            if inside { hovered = action } else if hovered == action { hovered = nil }
        }
    }

    private func actionTitle(_ action: ShortcutAction) -> some View {
        Text(action.title)
            .font(.rowTitle.weight(recording == action ? .semibold : .regular))
            .foregroundStyle(Palette.primaryText)
    }

    @ViewBuilder private func chips(_ action: ShortcutAction, _ chords: [Chord]) -> some View {
        ForEach(chords, id: \.self) { chord in
            let label = model.keyLayout.label(for: chord)
            ShortcutChip(label: label, action: action.title, showsRemove: hovered == action) {
                notice = nil
                model.removeShortcut(chord, from: action)
            }
        }
        if recording == action {
            RecordingChip(modifiers: heldModifiers, cancel: stopRecording)
        }
    }

    @ViewBuilder private func addButton(_ action: ShortcutAction) -> some View {
        Button {
            startRecording(action)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .help("Add a shortcut for \(action.title)")
        .accessibilityLabel("Add Shortcut for \(action.title)")
        .disabled(recording == action)
    }

    private var conflictTitle: String {
        guard let pendingConflict else { return "" }
        return "\(model.keyLayout.label(for: pendingConflict.chord)) is used by macOS for "
            + "\(pendingConflict.shortcut.name)."
    }

    /// Says what Miri kept and, when the button can move the new default, that moving it takes it from its owner.
    private func keptText(_ kept: KeptDefault, movable: Bool) -> String {
        let wanted = model.keyLayout.label(for: kept.wanted)
        let labels = kept.kept.map(model.keyLayout.label(for:)).formatted(.list(type: .and))
        let keptSentence = kept.kept.isEmpty ? "\(kept.action.title) has no shortcut now." : "Miri kept \(labels)."
        return movable ? "\(keptSentence) Using \(wanted) removes it from \(kept.owner)." : keptSentence
    }

    private func matches(_ action: ShortcutAction, _ shortcuts: Shortcuts) -> Bool {
        filter.isEmpty || action.title.localizedCaseInsensitiveContains(filter)
            || shortcuts.chords(for: action).contains {
                model.keyLayout.label(for: $0).localizedCaseInsensitiveContains(filter)
            }
    }

    private func matches(_ other: Shortcuts.OtherBinding) -> Bool {
        filter.isEmpty || other.key.localizedCaseInsensitiveContains(filter)
            || other.chords.contains { model.keyLayout.label(for: $0).localizedCaseInsensitiveContains(filter) }
    }

    private func startRecording(_ action: ShortcutAction) {
        notice = nil
        heldModifiers = []
        recording = action
        AccessibilityNotification.Announcement(
            "Recording a shortcut for \(action.title). Press the keys, or Escape to cancel."
        ).post()
        recorder.start { event in
            handle(event, for: action)
        } onCancel: {
            recording = nil
            heldModifiers = []
        }
    }

    private func stopRecording() {
        recorder.stop()
        recording = nil
        heldModifiers = []
    }

    private func handle(_ event: ShortcutRecorder.Event, for action: ShortcutAction) {
        guard recording == action else { return }
        switch event {
        case .modifiersChanged(let modifiers):
            heldModifiers = modifiers
        case .keyDown(let press):
            if press.keyCode == kVK_Escape, press.modifiers.isEmpty {
                notice = nil
                stopRecording()
                return
            }
            guard !press.modifiers.isDisjoint(with: [.control, .option, .command]) else {
                notice = Notice(action: action, text: "Include Control, Option, or Command.")
                return
            }
            guard let name = model.keyLayout.name(for: press.keyCode) else {
                notice = Notice(action: action, text: "Miri cannot use this key in a shortcut.")
                return
            }
            stopRecording()
            add(Chord(press.modifiers, name), to: action, allowingSystemConflict: false)
        }
    }

    private func add(_ chord: Chord, to action: ShortcutAction, allowingSystemConflict: Bool) {
        let label = model.keyLayout.label(for: chord)
        switch model.addShortcut(chord, to: action, allowingSystemConflict: allowingSystemConflict) {
        case .added:
            notice = nil
            AccessibilityNotification.Announcement("\(label) added for \(action.title).").post()
        case .failed:
            notice = nil
        case .rejected(.usedBy(let owner)):
            notice = Notice(action: action, text: "\(label) is already used by \(owner).")
        case .rejected(.alreadyAssigned):
            notice = Notice(action: action, text: "\(label) is already a shortcut for this action.")
        case .systemConflict(let shortcut):
            pendingConflict = PendingConflict(chord: chord, action: action, shortcut: shortcut)
        }
    }
}

/// One assigned shortcut. Its remove button shows while the pointer is on its row or the button has keyboard focus,
/// and VoiceOver always finds it.
struct ShortcutChip: View {
    let label: String
    let action: String
    let showsRemove: Bool
    let remove: () -> Void
    @FocusState private var removeFocused: Bool

    var body: some View {
        Text(label)
            .font(.detail.weight(.medium))
            .foregroundStyle(Palette.primaryText)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .frame(minWidth: 52, minHeight: 22)
            .background(Palette.chip, in: .rect(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.groupRing, lineWidth: 0.5))
            .overlay(alignment: .topTrailing) {
                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Palette.group, Palette.secondaryText)
                        .font(.system(size: 13))
                        .frame(width: 20, height: 20)
                        .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .focused($removeFocused)
                .opacity(showsRemove || removeFocused ? 1 : 0)
                .offset(x: 9, y: -9)
                .help("Remove \(label)")
                .accessibilityLabel("Remove \(label) from \(action)")
            }
            .fixedSize()
    }
}

/// The chip that stands in for the shortcut being recorded, showing the modifiers held so far.
struct RecordingChip: View {
    let modifiers: Set<ChordModifier>
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Text(modifiers.isEmpty ? "Type Shortcut" : KeyLayout.label(for: modifiers))
                .font(.detail.weight(.medium))
                .foregroundStyle(modifiers.isEmpty ? Palette.secondaryText : Palette.primaryText)
                .lineLimit(1)
            Button(action: cancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Palette.secondaryText)
                    .frame(width: 20, height: 20)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .help("Cancel recording")
            .accessibilityLabel("Cancel Recording")
        }
        .padding(.leading, 7)
        .padding(.trailing, 2)
        .frame(minWidth: 52, minHeight: 22)
        .background(Palette.chip, in: .rect(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.accent, lineWidth: 1.5))
        .fixedSize()
    }
}
