import AppKit
import Carbon.HIToolbox
import MiriCore
import Observation
import SwiftUI

/// A panel that can take keyboard input while the current app stays active.
final class WindowPicker: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var panel: PickerPanel?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        guard case .running(let pid) = model.engineState else { return }
        guard panel == nil else { return }
        let panel = PickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 376),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.title = String(localized: "Find a Window")
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        panel.delegate = self
        panel.cancel = { [weak self] in self?.close() }
        let session = PickerSession(paths: model.paths) { [weak self] window in
            self?.focus(window, enginePid: pid)
        }
        panel.moveSelection = { session.moveSelection(by: $0) }
        panel.contentViewController = NSHostingController(rootView: WindowPickerView(session: session))
        panel.center()
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        if notification.object as? NSWindow === panel { close() }
    }

    private func close() {
        let panel = self.panel
        self.panel = nil
        panel?.orderOut(nil)
    }

    private func focus(_ window: WindowSearch.Window, enginePid: Int32) {
        close()
        guard model.engineState == .running(pid: enginePid) else { return }
        let paths = model.paths
        Task {
            _ = await paths.request(["send-cmd", "window", "focus", "id", String(window.id)])
        }
    }

    private final class PickerPanel: NSPanel {
        var cancel: () -> Void = {}
        var moveSelection: (Int) -> Void = { _ in }

        override func cancelOperation(_ sender: Any?) { cancel() }

        override func sendEvent(_ event: NSEvent) {
            // The search field's editor consumes arrow keys. Let it keep them while an input method composes text.
            if event.type == .keyDown,
                event.modifierFlags.intersection([.shift, .control, .option, .command]).isEmpty,
                (firstResponder as? NSTextView)?.hasMarkedText() != true
            {
                switch Int(event.keyCode) {
                case kVK_UpArrow: moveSelection(-1)
                case kVK_DownArrow: moveSelection(1)
                case kVK_Escape: cancel()
                default: super.sendEvent(event)
                }
            } else {
                super.sendEvent(event)
            }
        }
    }
}

@Observable private final class PickerSession {
    let paths: EnginePaths
    let select: (WindowSearch.Window) -> Void

    var query = "" {
        didSet {
            selection = 0
            results = search?.matching(query) ?? []
        }
    }
    private(set) var results: [WindowSearch.Window] = []
    private(set) var selection = 0
    private(set) var loading = true
    private(set) var failed = false
    private var search: WindowSearch?

    init(paths: EnginePaths, select: @escaping (WindowSearch.Window) -> Void) {
        self.paths = paths
        self.select = select
    }

    func load() async {
        if let data = await paths.request(["query", "state", "--json"]), !Task.isCancelled {
            search = try? WindowSearch(json: data, excludingBundle: Bundle.main.bundleIdentifier)
        }
        results = search?.matching(query) ?? []
        loading = false
        failed = search == nil
    }

    func moveSelection(by step: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + step, 0), results.count - 1)
    }

    func submit() {
        if results.indices.contains(selection) { select(results[selection]) }
    }
}

private struct WindowPickerView: View {
    @Bindable var session: PickerSession
    @FocusState private var searching: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search window titles or app names", text: $session.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(16)
                .focused($searching)
                .onSubmit { session.submit() }
            Divider()
            if session.results.isEmpty {
                status
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(session.results.enumerated()), id: \.element.id) { index, window in
                                Button {
                                    session.select(window)
                                } label: {
                                    row(window, selected: index == session.selection)
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: session.selection) { proxy.scrollTo(session.selection) }
                }
            }
        }
        .padding(.top, 8)
        .frame(width: 520, height: 376)
        .task {
            searching = true
            await session.load()
        }
    }

    @ViewBuilder private var status: some View {
        if session.failed {
            Text("Couldn’t load windows. Open Find a Window to try again.")
        } else if session.loading {
            ProgressView()
                .controlSize(.small)
        } else if session.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("No open windows")
        } else {
            Text("No matching windows")
        }
    }

    private func row(_ window: WindowSearch.Window, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(window.title.isEmpty ? String(localized: "Untitled window") : window.title)
                .font(.body)
                .lineLimit(1)
            Text(window.appName)
                .font(.callout)
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Palette.accentTint : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
