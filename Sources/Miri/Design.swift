import AppKit
import SwiftUI

/// The colors of the Paper design for the Settings window, each with a light and a dark value.
enum Palette {
    static let accent = dynamic(0x4F6BF5, 0x6A84FF)
    /// Text and icons in the accent color on a light surface, such as the selected sidebar row.
    static let accentText = dynamic(0x3048C8, 0xAFC0FF)
    static let accentTint = dynamic(0x4F6BF5, 0x6A84FF, lightAlpha: 0.11, darkAlpha: 0.2)
    /// The fill behind white text, such as a prominent button. Darker than `accent` so the text reaches 4.5:1.
    static let accentFill = dynamic(0x4B65E8, 0x465DCC)

    static let primaryText = dynamic(0x1D1D1F, 0xF2F2F5)
    static let secondaryText = dynamic(0x6E6E73, 0xA1A1A8, contrast: (0x48484D, 0xC7C7CE))
    static let tertiaryText = dynamic(0x6E6E73, 0x8E8E96, contrast: (0x48484D, 0xB4B4BC))

    static let sidebar = dynamic(0xF4F4F6, 0x252528)
    static let sidebarBorder = dynamic(0xE3E3E7, 0x38383B, contrast: (0xA8A8AF, 0x6A6A70))
    static let content = dynamic(0xFFFFFF, 0x1E1E20)
    static let group = dynamic(0xFFFFFF, 0x2A2A2D)
    static let groupRing = dynamic(0xE5E5EA, 0x3A3A3E, contrast: (0xA8A8AF, 0x6A6A70))
    static let divider = dynamic(0xEFEFF2, 0x353538, contrast: (0xC4C4CA, 0x58585E))
    static let chip = dynamic(0xF2F2F5, 0x3A3A3D)
    static let track = dynamic(0xEEEEF1, 0x3A3A3D, contrast: (0xDADADF, 0x4A4A4E))
    static let segment = dynamic(0xFFFFFF, 0x636366)
    static let iconTile = dynamic(0x8E8E93, 0x5A5A5F)

    static let heroTint = dynamic(0xF3F6FE, 0x232A45)
    static let heroTile = dynamic(0xDFE5F4, 0x3A4260)
    static let heroTileBorder = dynamic(0xE3E8F4, 0x47507A)

    static let green = dynamic(0x1F9D55, 0x32C46E)
    /// Green text, such as the On label. Darker than `green` in light mode so small text reaches 4.5:1.
    static let greenText = dynamic(0x16763F, 0x32C46E)
    static let orange = dynamic(0xC2410C, 0xF0743A)
    static let red = dynamic(0xD92D20, 0xFF6B60)
    static let gray = dynamic(0x8E8E93, 0x8E8E96)
    /// A glyph drawn on a status color: white on the deep light colors, near black on the bright dark ones.
    static let onStatus = dynamic(0xFFFFFF, 0x1D1D1F)
    /// The count badge behind white text, deep enough for 4.5:1 in both appearances.
    static let badge = dynamic(0xC2410C, 0xC2410C)

    static let warningTint = dynamic(0xFFF7ED, 0x3B2A1C)
    static let warningBorder = dynamic(0xF6DCC3, 0x5A3E26)
    static let warningText = dynamic(0x7C2D12, 0xFFB98F)
    static let errorTint = dynamic(0xFFF1F1, 0x3E2024)
    static let errorBorder = dynamic(0xF6CFCF, 0x5E2C31)
    static let errorText = dynamic(0x7F1D1D, 0xFFB4AE)

    static let logBackground = dynamic(0x1D1D1F, 0x141416)
    static let logText = dynamic(0xE5E5EA, 0xD5D5DA)

    /// A color with a light and a dark value, and stronger values for Increase Contrast when `contrast` is given.
    private static func dynamic(
        _ light: UInt32, _ dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1,
        contrast: (light: UInt32, dark: UInt32)? = nil
    ) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [
                    .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
                ])
                let isDark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
                let isHighContrast =
                    match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
                let value =
                    switch (isDark, isHighContrast ? contrast : nil) {
                    case (false, let contrast?): contrast.light
                    case (true, let contrast?): contrast.dark
                    case (false, nil): light
                    case (true, nil): dark
                    }
                return NSColor(rgb: value, alpha: isDark ? darkAlpha : lightAlpha)
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

/// The type scale. Every text in Miri's windows uses one of these.
/// Each is a macOS text style of the same size, so the text follows the system text size where macOS offers one.
extension Font {
    /// The page title, such as "General": 22 points.
    static let pageTitle = Font.title.bold()
    /// The big line of a status card or sheet: 19 points, between the title and title2 styles.
    static let heroTitle = Font.system(size: 19, weight: .bold)
    /// Row titles and ordinary text: 13 points.
    static let rowTitle = Font.body
    /// Explanations under a title, notices, and footnotes: 12 points.
    static let detail = Font.callout
    /// Small labels, such as section labels and the version line: 11 points.
    static let small = Font.subheadline
    /// The app name in the Settings sidebar: 15 points.
    static let sidebarName = Font.title3.bold()
    /// File paths, engine binding names, and reports: 12 points.
    static let mono = Font.callout.monospaced()
    /// The engine log: 11 points.
    static let monoSmall = Font.subheadline.monospaced()
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
                            .font(.pageTitle)
                            .foregroundStyle(Palette.primaryText)
                            .accessibilityAddTraits(.isHeader)
                        Text(subtitle)
                            .font(.rowTitle)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 520, alignment: .leading)
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
                .font(.small.weight(.semibold))
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
                    .font(monospacedTitle ? .mono : .rowTitle)
                    .foregroundStyle(Palette.primaryText)
                if let detail {
                    LiveText(detail)
                        .font(.detail)
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
    /// A state the user chose, such as a stop. It needs no attention.
    case neutral
    /// A passed check or a running engine.
    case success
    case info, warning, error

    var color: Color {
        switch self {
        case .neutral: Palette.gray
        case .success: Palette.green
        case .info: Palette.accent
        case .warning: Palette.orange
        case .error: Palette.red
        }
    }

    var tint: Color {
        switch self {
        case .neutral, .success: Palette.chip
        case .info: Palette.heroTint
        case .warning: Palette.warningTint
        case .error: Palette.errorTint
        }
    }

    var border: Color {
        switch self {
        case .neutral, .success: Palette.groupRing
        case .info: Palette.heroTileBorder
        case .warning: Palette.warningBorder
        case .error: Palette.errorBorder
        }
    }

    var text: Color {
        switch self {
        case .neutral, .success, .info: Palette.primaryText
        case .warning: Palette.warningText
        case .error: Palette.errorText
        }
    }

    var symbol: String {
        switch self {
        case .neutral: "pause.fill"
        case .success: "checkmark"
        case .info: "info"
        case .warning: "exclamationmark"
        // A different shape from the warning, so the two never differ by color alone.
        case .error: "xmark"
        }
    }

    /// The word VoiceOver reads before a notice, because the colored glyph is hidden from it.
    var spokenPrefix: String {
        switch self {
        case .neutral, .success: ""
        case .info: "Note: "
        case .warning: "Warning: "
        case .error: "Error: "
        }
    }
}

/// A filled circle with a short symbol, such as `!`, used beside notices and setup checks.
struct NoticeGlyph: View {
    let kind: NoticeKind
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * (kind == .neutral ? 0.45 : 0.56), weight: .heavy))
            .foregroundStyle(Palette.onStatus)
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
            Text(text)
                .font(.detail)
                .foregroundStyle(kind.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(kind.spokenPrefix + text)
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
                        .font(.rowTitle.weight(.semibold))
                        .foregroundStyle(Palette.primaryText)
                        .accessibilityLabel(kind.spokenPrefix + title)
                        .modifier(StatusValue(value: accessibilityValue))
                    LiveText(detail)
                        .font(.detail)
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
    var minWidth: CGFloat = 40

    var body: some View {
        Text(label)
            .font(.detail.weight(.medium))
            .foregroundStyle(Palette.primaryText)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .frame(minWidth: minWidth, minHeight: 22)
            .background(Palette.chip, in: .rect(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.groupRing, lineWidth: 0.5))
    }
}

/// A segmented control in the design's colors, which do not follow the system accent color.
/// It is one keyboard stop, the arrow keys move the choice, and VoiceOver reads it as a native segmented control.
struct SegmentedChoice<Value: Hashable>: View {
    let label: String
    @Binding var selection: Value
    let options: [(title: String, value: Value)]
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var focused: Bool
    /// Whether the focus came from the keyboard. A window that opens with the focus here shows no ring.
    @State private var showsFocusRing = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(.detail.weight(selected ? .medium : .regular))
                        .foregroundStyle(Palette.primaryText)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(minWidth: 58, minHeight: 22)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Palette.segment)
                                    .shadow(color: .black.opacity(0.14), radius: 0.75, y: 0.5)
                                    // With Increase Contrast, an outline marks the choice, not only the fill.
                                    .overlay {
                                        if contrast == .increased {
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(Palette.primaryText, lineWidth: 1.5)
                                        }
                                    }
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(2)
        .background(Palette.track, in: .rect(cornerRadius: 8))
        // A keyboard focus ring in the accent color, drawn by the control so it follows the rounded track.
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Palette.accent.opacity(0.6), lineWidth: 2.5)
                .padding(-3)
                .opacity(focused && showsFocusRing ? 1 : 0)
        }
        .fixedSize()
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onChange(of: focused) { showsFocusRing = focused && NSApp.currentEvent?.type == .keyDown }
        .onMoveCommand { direction in
            showsFocusRing = true
            move(direction)
        }
        .accessibilityRepresentation {
            Picker(label, selection: $selection) {
                ForEach(options.indices, id: \.self) { index in
                    Text(options[index].title).tag(options[index].value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func move(_ direction: MoveCommandDirection) {
        guard let index = options.firstIndex(where: { $0.value == selection }) else { return }
        switch direction {
        case .left where index > 0: selection = options[index - 1].value
        case .right where index < options.count - 1: selection = options[index + 1].value
        default: break
        }
    }
}

/// A search field with a magnifying glass and a clear button, in the design's colors.
struct SearchField: View {
    @Binding var text: String
    let prompt: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
                .accessibilityHidden(true)
            TextField("Search", text: $text, prompt: Text(prompt))
                .labelsHidden()
                .textFieldStyle(.plain)
                .font(.rowTitle)
                .focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.tertiaryText)
                }
                .buttonStyle(.borderless)
                .help("Clear the search")
                .accessibilityLabel("Clear Search")
            }
        }
        .fieldBox(focused: focused)
    }
}

extension View {
    /// The box of a text field in the design's colors: a group fill, a ring, and at least 28 points of height.
    /// While the field has focus, the ring is the accent color, like the focus ring of the segmented control.
    func fieldBox(focused: Bool) -> some View {
        padding(.horizontal, 8)
            .frame(minHeight: 28)
            .background(Palette.group, in: .rect(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(focused ? Palette.accent : Palette.groupRing, lineWidth: focused ? 2 : 1))
    }
}

/// Lays out its views in lines, and starts a new line when the next view does not fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = lines(for: subviews, width: proposal.width ?? .infinity)
        let width = lines.map { line in line.map(\.size.width).reduce(0, +) + spacing * CGFloat(line.count - 1) }.max()
        let height = lines.map { $0.map(\.size.height).max() ?? 0 }.reduce(0, +) + spacing * CGFloat(lines.count - 1)
        return CGSize(width: width ?? 0, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(for: subviews, width: bounds.width) {
            var x = bounds.minX
            let height = line.map(\.size.height).max() ?? 0
            for item in line {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += height + spacing
        }
    }

    private func lines(for subviews: Subviews, width: CGFloat) -> [[(index: Int, size: CGSize)]] {
        var lines: [[(index: Int, size: CGSize)]] = [[]]
        var used: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !lines[lines.count - 1].isEmpty, used + spacing + size.width > width {
                lines.append([])
                used = 0
            }
            used += (lines[lines.count - 1].isEmpty ? 0 : spacing) + size.width
            lines[lines.count - 1].append((index, size))
        }
        return lines
    }
}
