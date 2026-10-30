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

    var body: some View {
        Form {
            ConfigurationIssueBanner(model: model)
            if !model.keptDefaults.isEmpty {
                Section {
                    ForEach(model.keptDefaults, id: \.self) { kept in
                        Label {
                            Text(notice(for: kept))
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "info.circle.fill").foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("Updated Default Shortcuts")
                }
            }
            if let shortcuts = model.shortcuts {
                Section {
                    TextField("Filter", text: $filter, prompt: Text("Filter shortcuts"))
                        .labelsHidden()
                }
                Section {
                    ForEach(ShortcutAction.editable.filter { matches($0, shortcuts) }, id: \.self) { action in
                        row(action, chords: shortcuts.chords(for: action))
                    }
                } footer: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(
                            "Press Escape to cancel recording. Stop window manager works even while the engine is stopped."
                        )
                        .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reset to Defaults…") { confirmingReset = true }
                    }
                }
                let others = shortcuts.others.filter { matches($0) }
                if !others.isEmpty {
                    Section {
                        ForEach(others, id: \.self) { other in
                            HStack(spacing: 6) {
                                Text(other.key).font(.body.monospaced())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(other.chords, id: \.self) { chord in
                                    ShortcutChip(label: model.keyLayout.label(for: chord))
                                }
                            }
                        }
                    } header: {
                        Text("Other Engine Bindings")
                    } footer: {
                        Text("Miri does not list these engine commands. Edit them in the configuration file.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear(perform: stopRecording)
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

    private func row(_ action: ShortcutAction, chords: [Chord]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(action.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(chords, id: \.self) { chord in
                    let label = model.keyLayout.label(for: chord)
                    ShortcutChip(label: label) {
                        notice = nil
                        model.removeShortcut(chord, from: action)
                    }
                }
                if recording == action {
                    RecordingChip(modifiers: heldModifiers, cancel: stopRecording)
                } else {
                    Button {
                        startRecording(action)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 22, height: 22)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.borderless)
                    .help("Add a shortcut for \(action.title)")
                    .accessibilityLabel("Add Shortcut")
                }
            }
            if let notice, notice.action == action {
                Text(notice.text)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var conflictTitle: String {
        guard let pendingConflict else { return "" }
        return "\(model.keyLayout.label(for: pendingConflict.chord)) is used by macOS for "
            + "\(pendingConflict.shortcut.name)."
    }

    private func notice(for kept: KeptDefault) -> String {
        let wanted = model.keyLayout.label(for: kept.wanted)
        let held = "Its new default, \(wanted), is used by \(kept.owner)."
        guard !kept.kept.isEmpty else { return "\(kept.action.title) has no shortcut. \(held)" }
        return
            "\(kept.action.title) kept \(kept.kept.map(model.keyLayout.label(for:)).joined(separator: ", ")). \(held)"
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
        case .added, .failed:
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

/// One assigned shortcut, with a remove button when it can be edited.
struct ShortcutChip: View {
    let label: String
    var remove: (() -> Void)?

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .lineLimit(1)
                .frame(minWidth: 40)
            if let remove {
                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove \(label)")
                .accessibilityLabel("Remove \(label)")
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, remove == nil ? 7 : 4)
        .frame(height: 22)
        .background(.quaternary, in: .rect(cornerRadius: 6))
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
                .foregroundStyle(modifiers.isEmpty ? .secondary : .primary)
                .lineLimit(1)
            Button(action: cancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Cancel recording")
            .accessibilityLabel("Cancel Recording")
        }
        .padding(.leading, 7)
        .padding(.trailing, 4)
        .frame(height: 22)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor, lineWidth: 1.5))
        .fixedSize()
    }
}
