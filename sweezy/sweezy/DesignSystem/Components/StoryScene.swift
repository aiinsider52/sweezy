import SwiftUI

/// Fills its frame with a 3:2 scene but crops toward the upper part instead of the centre,
/// so the mascot's face survives in short banners. `focusY` 0 = top-anchored, 0.5 = centred.
struct FocusedSceneImage: View {
    let name: String
    var aspectRatio: CGFloat = 1.5
    var focusY: CGFloat = 0.3

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, proxy.size.height * aspectRatio)
            let height = width / aspectRatio
            let overflowX = width - proxy.size.width
            let overflowY = max(0, height - proxy.size.height)

            Image(name)
                .resizable()
                .frame(width: width, height: height)
                .offset(x: -overflowX / 2, y: -overflowY * focusY)
        }
        .clipped()
    }
}

/// Illustrated moment where the mascot acts out what a screen is for (logging in, moving in,
/// learning German…). Rounded card that sits above a screen's title, replacing generic glyphs.
/// Assets are named `story-<name>`.
struct StoryScene: View {
    let name: String
    var height: CGFloat = 200
    var cornerRadius: CGFloat = 28

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        FocusedSceneImage(name: "story-\(name)")
            // Slow breathing zoom, the same life the home hero has.
            .scaleEffect(drift ? 1.05 : 1, anchor: .init(x: 0.62, y: 0.35))
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipShape(shape)
            .overlay(shape.stroke(JourneyVisual.softBorder, lineWidth: 1))
            .shadow(color: JourneyVisual.black.opacity(0.08), radius: 16, y: 6)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion, !drift else { return }
                withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
    }
}
