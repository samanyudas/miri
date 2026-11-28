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
                    SketchView(sketch: scene.before, scene: scene)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                    SketchView(sketch: showsAfter ? scene.after : scene.before, scene: scene)
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

private struct SketchView: View {
    let sketch: StripSketch
    let scene: ShortcutScene

    var body: some View {
        GeometryReader { proxy in
            let layout = scene.layout(sketch, in: proxy.size)
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
                if let box = layout.displays.first {
                    pickerOverlay(in: box)
                        .opacity(sketch.showsPicker ? 1 : 0)
                        .scaleEffect(sketch.showsPicker ? 1 : 0.94)
                        .position(x: box.midX, y: box.midY)
                        .zIndex(2)
                }
            }
        }
    }

    private func pickerOverlay(in box: CGRect) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
                Capsule()
                    .fill(Palette.primaryText.opacity(0.45))
                    .frame(width: box.width * 0.22, height: 2.5)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 5)
            .padding(.top, 5)
            Rectangle()
                .fill(Palette.heroTileBorder)
                .frame(height: 0.75)
            VStack(alignment: .leading, spacing: 2.5) {
                HStack {
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: box.width * 0.28, height: 2.5)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3.5)
                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 2.5))
                Capsule()
                    .fill(Palette.heroTile)
                    .frame(width: box.width * 0.22, height: 2.5)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 5)
        }
        .frame(width: box.width * 0.62)
        .background(Palette.group, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.heroTileBorder, lineWidth: 0.75))
        .shadow(color: .black.opacity(0.22), radius: 3, y: 1.5)
    }

    private func fill(for window: String) -> Color {
        let color = window == sketch.focused ? Palette.accent : Palette.heroTile
        // After Stop, Miri no longer arranges the windows, so they fade.
        return sketch.managed ? color : color.opacity(0.45)
    }
}
