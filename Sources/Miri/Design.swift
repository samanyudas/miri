import AppKit
import SwiftUI

/// The colors of the Paper design for the Settings window, each with a light and a dark value.
enum Palette {
    static let accent = dynamic(0x4F6BF5, 0x6A84FF)
    /// Text and icons in the accent color on a light surface, such as the selected sidebar row.
    static let accentText = dynamic(0x3048C8, 0xAFC0FF)
    static let accentTint = dynamic(0x4F6BF5, 0x6A84FF, lightAlpha: 0.11, darkAlpha: 0.2)

    static let primaryText = dynamic(0x1D1D1F, 0xF2F2F5)
    static let secondaryText = dynamic(0x6E6E73, 0xA1A1A8)
    static let tertiaryText = dynamic(0x8E8E93, 0x8E8E96)

    static let sidebar = dynamic(0xF4F4F6, 0x252528)
    static let sidebarBorder = dynamic(0xE3E3E7, 0x38383B)
    static let content = dynamic(0xFFFFFF, 0x1E1E20)
    static let group = dynamic(0xFFFFFF, 0x2A2A2D)
    static let groupRing = dynamic(0xE5E5EA, 0x3A3A3E)
    static let divider = dynamic(0xEFEFF2, 0x353538)
    static let chip = dynamic(0xF2F2F5, 0x3A3A3D)
    static let track = dynamic(0xEEEEF1, 0x3A3A3D)
    static let segment = dynamic(0xFFFFFF, 0x636366)
    static let iconTile = dynamic(0x8E8E93, 0x5A5A5F)

    static let heroTint = dynamic(0xF3F6FE, 0x232A45)
    static let heroTile = dynamic(0xDFE5F4, 0x3A4260)
    static let heroTileBorder = dynamic(0xE3E8F4, 0x47507A)

    static let green = dynamic(0x1F9D55, 0x32C46E)
    static let orange = dynamic(0xC2410C, 0xF0743A)
    static let red = dynamic(0xD92D20, 0xFF6B60)
    static let gray = dynamic(0x8E8E93, 0x8E8E96)

    static let warningTint = dynamic(0xFFF7ED, 0x3B2A1C)
    static let warningBorder = dynamic(0xF6DCC3, 0x5A3E26)
    static let warningText = dynamic(0x7C2D12, 0xFFB98F)
    static let errorTint = dynamic(0xFFF1F1, 0x3E2024)
    static let errorBorder = dynamic(0xF6CFCF, 0x5E2C31)
    static let errorText = dynamic(0x7F1D1D, 0xFFB4AE)

    static let logBackground = dynamic(0x1D1D1F, 0x141416)
    static let logText = dynamic(0xE5E5EA, 0xD5D5DA)

    private static func dynamic(
        _ light: UInt32, _ dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1
    ) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return NSColor(rgb: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
            })
    }
}

extension NSColor {
    fileprivate convenience init(rgb: UInt32, alpha: Double) {
        self.init(
            srgbRed: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255, alpha: alpha)
    }
}

/// A scrolling Settings page: a title, a short description, and its sections.
struct SettingsPage<Trailing: View, Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Palette.primaryText)
                            .accessibilityAddTraits(.isHeader)
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 420, alignment: .leading)
                    }
                    Spacer(minLength: 0)
                    trailing
                }
                content
            }
            .padding(.horizontal, 40)
            .padding(.top, 44)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.content)
    }
}

extension SettingsPage where Trailing == EmptyView {
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, trailing: { EmptyView() }, content: content)
    }
}

/// A small uppercase label above a group, with an optional control at its trailing end.
struct SectionLabel<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.secondaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            accessory
        }
        .padding(.horizontal, 2)
    }
}

extension SectionLabel where Accessory == EmptyView {
    init(_ title: String) {
        self.init(title: title, accessory: { EmptyView() })
    }
}

/// A labelled section holding one group of rows.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            SettingsGroup { content }
        }
    }
}

/// A rounded card that separates its rows with hairlines.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Group(subviews: content) { rows in
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    if index > 0 { Rectangle().fill(Palette.divider).frame(height: 1) }
                    rows[index]
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.group)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.groupRing, lineWidth: 1))
    }
}

/// One row of a group: a title with an optional explanation, and its control at the trailing end.
struct SettingsRow<Control: View>: View {
    let title: String
    var detail: String?
    var monospacedTitle = false
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(monospacedTitle ? .system(size: 12, design: .monospaced) : .system(size: 13))
                    .foregroundStyle(Palette.primaryText)
                if let detail {
                    LiveText(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
    }
}

extension SettingsRow where Control == EmptyView {
    init(title: String, detail: String? = nil, monospacedTitle: Bool = false) {
        self.init(title: title, detail: detail, monospacedTitle: monospacedTitle, control: { EmptyView() })
    }
}

/// How serious a notice is, which sets its color and symbol.
enum NoticeKind {
    case info, warning, error

    var color: Color {
        switch self {
        case .info: Palette.accent
        case .warning: Palette.orange
        case .error: Palette.red
        }
    }

    var tint: Color {
        switch self {
        case .info: Palette.heroTint
        case .warning: Palette.warningTint
        case .error: Palette.errorTint
        }
    }

    var border: Color {
        switch self {
        case .info: Palette.heroTileBorder
        case .warning: Palette.warningBorder
        case .error: Palette.errorBorder
        }
    }

    var text: Color {
        switch self {
        case .info: Palette.primaryText
        case .warning: Palette.warningText
        case .error: Palette.errorText
        }
    }

    var glyph: String { self == .info ? "i" : "!" }
}

/// A filled circle with a short glyph, such as `!`, used beside notices and setup checks.
struct NoticeGlyph: View {
    let kind: NoticeKind
    var size: CGFloat = 16

    var body: some View {
        Text(kind.glyph)
            .font(.system(size: size * 0.69, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(kind.color, in: .circle)
            .accessibilityHidden(true)
    }
}

/// A tinted row inside a group that explains why a setting above it is off, with an optional action.
struct NoticeRow<Action: View>: View {
    let kind: NoticeKind
    let text: String
    @ViewBuilder var action: Action

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            NoticeGlyph(kind: kind)
            LiveText(text)
                .font(.system(size: 12))
                .foregroundStyle(kind.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            action
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(kind.tint)
    }
}

extension NoticeRow where Action == EmptyView {
    init(kind: NoticeKind, text: String) {
        self.init(kind: kind, text: text, action: { EmptyView() })
    }
}

/// A standalone tinted box with a bold line and an explanation, for the state of the whole app.
struct Banner<Actions: View>: View {
    let kind: NoticeKind
    let title: String
    let detail: String
    /// The value VoiceOver and the test tools read for this banner, such as the engine status.
    var accessibilityValue: String?
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                NoticeGlyph(kind: kind, size: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.primaryText)
                        .modifier(StatusValue(value: accessibilityValue))
                    LiveText(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Group(subviews: actions) { subviews in
                if !subviews.isEmpty {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        subviews
                    }
                }
            }
        }
        .padding(14)
        .background(kind.tint, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(kind.border, lineWidth: 1))
    }
}

extension Banner where Actions == EmptyView {
    init(kind: NoticeKind, title: String, detail: String) {
        self.init(kind: kind, title: title, detail: detail, actions: { EmptyView() })
    }
}

/// Marks the text that holds the engine status, so VoiceOver and the `axdo status` test tool can read it.
struct StatusValue: ViewModifier {
    static let identifier = "miri.status"
    let value: String?

    func body(content: Content) -> some View {
        if let value {
            content.accessibilityValue(value).accessibilityIdentifier(Self.identifier)
        } else {
            content
        }
    }
}

/// A switch in the accent color, with its label read by VoiceOver but drawn by the row.
struct RowSwitch: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .toggleStyle(.switch)
            .labelsHidden()
            .tint(Palette.accent)
    }
}

/// A keyboard shortcut drawn as a key cap.
struct KeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.primaryText)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .frame(minWidth: 40, minHeight: 22)
            .background(Palette.chip, in: .rect(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.groupRing, lineWidth: 0.5))
    }
}

/// A segmented control in the design's colors, which do not follow the system accent color.
struct SegmentedChoice<Value: Hashable>: View {
    let label: String
    @Binding var selection: Value
    let options: [(title: String, value: Value)]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(.system(size: 12.5, weight: selected ? .medium : .regular))
                        .foregroundStyle(Palette.primaryText)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(minWidth: 58, minHeight: 22)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Palette.segment)
                                    .shadow(color: .black.opacity(0.14), radius: 0.75, y: 0.5)
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Palette.track, in: .rect(cornerRadius: 8))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}
