import MiriCore
import SwiftUI

/// The panel above the Shortcuts list that shows what one action does (#351).
/// It draws a before and an after sketch. When the action changes, the after sketch plays the move once, in about
/// 0.6 seconds. With Reduce Motion on, it shows the still pair. VoiceOver reads the title and the caption, and skips
/// the drawing, because the caption says the same thing.
struct ShortcutPreview: View {
    let action: ShortcutAction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsAfter = false

    var body: some View {
        if let scene = action.scene {
            HStack(alignment: .center, spacing: 18) {
                HStack(spacing: 6) {
                    SketchView(sketch: scene.before, arrangement: scene.before)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                    SketchView(sketch: showsAfter ? scene.after : scene.before, arrangement: scene.before)
                }
                .frame(width: 330, height: 100)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.rowTitle.weight(.semibold))
                        .foregroundStyle(Palette.primaryText)
                    Text(scene.caption)
                        .font(.detail)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
            .padding(14)
            .background(Palette.heroTint, in: .rect(cornerRadius: 10))
            .task(id: action) { await play() }
        }
    }

    /// Starts from the before sketch, then plays the move once. Reduce Motion shows the end at once.
    private func play() async {
        showsAfter = false
        if reduceMotion {
            showsAfter = true
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.6)) { showsAfter = true }
    }
}

/// One sketch of displays and windows. The focused window is in the accent color.
private struct SketchView: View {
    let sketch: StripSketch
    /// The sketch whose displays set the scale, so the before and after sketches match.
    let arrangement: StripSketch

    var body: some View {
        GeometryReader { proxy in
            let layout = sketch.layout(in: proxy.size, arrangement: arrangement)
            ZStack(alignment: .topLeading) {
                ForEach(layout.displays.indices, id: \.self) { index in
                    let box = layout.displays[index]
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Palette.group)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.heroTileBorder, lineWidth: 1))
                        .frame(width: box.width, height: box.height)
                        .position(x: box.midX, y: box.midY)
                }
                ForEach(sketch.windows.sorted(), id: \.self) { window in
                    let rect = layout.windows[window] ?? .zero
                    let floating = sketch.place(of: window)?.column == nil
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fill(for: window))
                        .shadow(color: .black.opacity(floating ? 0.25 : 0), radius: 2, y: 1)
                        .frame(width: max(rect.width, 0), height: max(rect.height, 0))
                        .position(x: rect.midX, y: rect.midY)
                        .zIndex(floating ? 1 : 0)
                }
            }
        }
    }

    private func fill(for window: String) -> Color {
        guard sketch.managed else { return Palette.heroTile.opacity(0.55) }
        return window == sketch.focused ? Palette.accent : Palette.heroTile
    }
}
