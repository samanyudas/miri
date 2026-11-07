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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            identity
                .padding(.top, 58)
                .padding(.bottom, 18)
            VStack(spacing: 2) {
                ForEach(SettingsView.Page.allCases, id: \.self) { item in
                    SidebarRow(page: item, selected: page == item, badge: badge(for: item)) { page = item }
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

    private var identity: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)
                .padding(-2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Miri")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(-0.15)
                    .foregroundStyle(Palette.primaryText)
                HStack(spacing: 5) {
                    Circle().fill(model.stateColor).frame(width: 7, height: 7)
                    LiveText(model.sidebarStatus)
                        .font(.system(size: 11))
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
                .font(.system(size: 11))
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
            sidebarButton("Stop Miri", glyph: "stop.fill", help: "Stop Window Management") { model.stop() }
        case .failed:
            sidebarButton("Restart Miri", glyph: "arrow.clockwise", help: "Restart Engine") { model.restart() }
        case .stopped where !model.startBlockers.isEmpty:
            sidebarButton("Stop Miri", glyph: "stop.fill", help: "Stop Window Management") { model.stop() }
        case .stopped:
            sidebarButton("Start Miri", glyph: "play.fill", help: "Start Window Management") { model.start() }
        }
    }

    private func sidebarButton(
        _ title: String, glyph: String, help: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: glyph)
                .labelStyle(SidebarButtonLabelStyle())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .help(help)
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

private struct SidebarButtonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 9, weight: .bold))
            configuration.title.font(.system(size: 13, weight: .medium))
        }
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
                    .background(selected ? Palette.accent : Palette.iconTile, in: .rect(cornerRadius: 5))
                Text(page.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Palette.accentText : Palette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Palette.orange, in: .capsule)
                        .accessibilityLabel("\(badge) to review")
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(selected ? Palette.accentTint : .clear, in: .rect(cornerRadius: 7))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(page.title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

extension AppModel {
    /// A few words for the sidebar about whether Miri is managing windows.
    var sidebarStatus: String {
        switch engineState {
        case .running:
            let count = NSScreen.screens.count
            return "Running · \(count) \(count == 1 ? "display" : "displays")"
        case .restarting(let crashes): return "Restarting · crash \(crashes)"
        case .failed: return "Stopped after failures"
        case .stopped:
            if !startBlockers.isEmpty { return "Setup required" }
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
