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
                // The sketches show the screen's real left and right, also in Arabic.
                .environment(\.layoutDirection, .leftToRight)
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
                    let clip = layout.clips[window] ?? .zero
                    let floating = sketch.place(of: window)?.column == nil
                    // The window keeps its full size while it moves, and its display cuts off what lies outside,
                    // so a column sliding off the display keeps its width.
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fill(for: window))
                        .shadow(color: .black.opacity(floating ? 0.25 : 0), radius: 2, y: 1)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .mask {
                            Rectangle()
                                .frame(width: clip.width, height: clip.height)
                                .position(x: clip.midX, y: clip.midY)
                        }
                        .zIndex(floating ? 1 : 0)
                }
            }
        }
    }

    private func fill(for window: String) -> Color {
        let color = window == sketch.focused ? Palette.accent : Palette.heroTile
        // After Stop, Miri no longer arranges the windows, so they fade.
        return sketch.managed ? color : color.opacity(0.45)
    }
}
