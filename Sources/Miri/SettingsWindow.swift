import AppKit
import MiriCore
import SwiftUI

/// The Settings window: a sidebar with Miri's state and pages, and the page it selects.
struct SettingsView: View {
    enum Page: String, CaseIterable {
        case setup, general, layout, shortcuts, gestures, diagnostics

        var title: String {
            switch self {
            case .setup: "Setup"
            case .general: "General"
            case .layout: "Layout"
            case .shortcuts: "Shortcuts"
            case .gestures: "Gestures"
            case .diagnostics: "Diagnostics"
            }
        }

        var symbol: String {
            switch self {
            case .setup: "checkmark"
            case .general: "power"
            case .layout: "rectangle.split.3x1.fill"
            case .shortcuts: "keyboard"
            case .gestures: "hand.draw"
            case .diagnostics: "waveform.path.ecg"
            }
        }
    }

    /// The user defaults key that remembers the page, so Settings reopens where it was left.
    static let pageKey = "settingsTab"

    let model: AppModel
    @AppStorage(SettingsView.pageKey) private var page = Page.general

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(model: model, page: $page)
            Group {
                switch page {
                case .setup: SetupSettings(model: model, page: $page)
                case .general: GeneralSettings(model: model, page: $page)
                case .layout: LayoutSettings(model: model)
                case .shortcuts: ShortcutsSettings(model: model)
                case .gestures: GestureSettings(model: model)
                case .diagnostics: DiagnosticsSettings(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // The window presenter sets the 880 by 640 frame. The view fills it, under the title bar too.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Palette.content)
    }
}

struct SettingsSidebar: View {
    let model: AppModel
    @Binding var page: SettingsView.Page
    @FocusState private var focusedPage: SettingsView.Page?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            identity
                .padding(.top, 58)
                .padding(.bottom, 18)
            VStack(spacing: 2) {
                ForEach(SettingsView.Page.allCases, id: \.self) { item in
                    SidebarRow(page: item, selected: page == item, badge: badge(for: item)) { page = item }
                        .focused($focusedPage, equals: item)
                        // The up and down arrows change the page, as in a macOS sidebar, and take the focus along.
                        .onMoveCommand(perform: movePage)
                }
            }
            Spacer(minLength: 16)
            footer
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 14)
        .frame(width: 216)
        .frame(maxHeight: .infinity)
        .background(Palette.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Palette.sidebarBorder).frame(width: 1)
        }
    }

    private func movePage(_ direction: MoveCommandDirection) {
        let pages = SettingsView.Page.allCases
        guard let index = pages.firstIndex(of: page) else { return }
        switch direction {
        case .up where index > 0: page = pages[index - 1]
        case .down where index < pages.count - 1: page = pages[index + 1]
        default: return
        }
        focusedPage = page
    }

    private var identity: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)
                .padding(-2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Miri")
                    .font(.sidebarName)
                    .tracking(-0.15)
                    .foregroundStyle(Palette.primaryText)
                HStack(spacing: 5) {
                    Circle().fill(model.stateColor).frame(width: 7, height: 7)
                    LiveText(model.sidebarStatus)
                        .font(.small)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            managementButton
            Text(versionLine)
                .font(.small)
                .foregroundStyle(Palette.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
    }

    /// The one control that starts, stops, or restarts window management from any page.
    @ViewBuilder private var managementButton: some View {
        switch model.engineState {
        case .running, .restarting:
            sidebarButton("Stop Window Management") { model.stop() }
        case .failed:
            sidebarButton("Restart Engine") { model.restart() }
        case .stopped where !model.startBlockers.isEmpty:
            sidebarButton(AppModel.cancelAutomaticStartTitle) { model.stop() }
        case .stopped:
            sidebarButton("Start Window Management") { model.start() }
        }
    }

    /// Uses the same title as the page and menu buttons, so the action has one name everywhere.
    private func sidebarButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.detail.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var versionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let revision = model.gestureEnvironment.engineRevision
        let engine = revision == "unknown" ? "unknown" : String(revision.prefix(7))
        return "Version \(version) · Engine \(engine)"
    }

    private func badge(for page: SettingsView.Page) -> Int {
        guard page == .setup else { return 0 }
        return model.setupChecks.filter {
            if case .problem = $0.status { true } else { false }
        }.count
    }
}

private struct SidebarRow: View {
    let page: SettingsView.Page
    let selected: Bool
    let badge: Int
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 9) {
                Image(systemName: page.symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(selected ? Palette.accentFill : Palette.iconTile, in: .rect(cornerRadius: 5))
                Text(page.title)
                    .font(.rowTitle.weight(selected ? .semibold : .regular))
                    .foregroundStyle(Palette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.small.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Palette.badge, in: .capsule)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(selected ? Palette.accentTint : .clear, in: .rect(cornerRadius: 7))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(page.title)
        .accessibilityValue(badge > 0 ? "\(badge) to review" : "")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

extension AppModel {
    /// The action that keeps Miri stopped while it waits for setup, which would otherwise start it by itself.
    static let cancelAutomaticStartTitle = "Cancel Automatic Start"

    /// A few words for the sidebar about whether Miri is managing windows.
    var sidebarStatus: String {
        switch engineState {
        case .running:
            let count = NSScreen.screens.count
            return "Running · \(count) \(count == 1 ? "display" : "displays")"
        case .restarting: return "Restarting the engine"
        case .failed: return "Stopped after engine failures"
        case .stopped:
            if !startBlockers.isEmpty { return "Waiting for setup" }
            return stoppedByUser ? "Stopped by you" : "Stopped"
        }
    }

    var stateColor: Color {
        switch engineState {
        case .running: Palette.green
        case .restarting: Palette.orange
        case .failed: Palette.red
        case .stopped: startBlockers.isEmpty ? Palette.gray : Palette.orange
        }
    }
}

extension WindowPresenter {
    /// Opens Settings on `page`, such as Setup from the menu bar menu.
    func showSettings(_ page: SettingsView.Page) {
        UserDefaults.standard.set(page.rawValue, forKey: SettingsView.pageKey)
        show(.settings)
    }
}
