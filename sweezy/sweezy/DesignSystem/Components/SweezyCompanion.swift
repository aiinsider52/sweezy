import SwiftUI

/// Shared, decorative brand character. Navigation and status always remain native UI.
enum SweezyCompanionPose: String, CaseIterable {
    case guide, documents, celebrate, welcome
    /// Full-body poses (portrait, trimmed): plan = sitting with a map, people = friend cards, help = books.
    case plan, people, help

    var assetName: String { "sweezy-companion-\(rawValue)" }
}

struct SweezyCompanion: View {
    var pose: SweezyCompanionPose = .guide
    var size: CGFloat = 112
    /// Increment only after a successful user action, never for initial data loading.
    var reaction: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrating = false
    @State private var emphasis = false
    @State private var pendingReaction = 0

    var body: some View {
        Image((celebrating ? SweezyCompanionPose.celebrate : pose).assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(emphasis && !reduceMotion ? 1.035 : 1)
            .rotationEffect(.degrees(emphasis && !reduceMotion ? -2 : 0))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: reaction) { _, value in pendingReaction = value }
            .task(id: pendingReaction) {
                guard pendingReaction > 0 else { return }
                let currentReaction = pendingReaction
                celebrating = true
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                    emphasis = true
                }
                do {
                    try await Task.sleep(for: .milliseconds(240))
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                        emphasis = false
                    }
                    try await Task.sleep(for: .milliseconds(1200))
                    celebrating = false
                } catch {
                    // SwiftUI cancels this task when the screen leaves or another action arrives.
                    if pendingReaction == currentReaction {
                        celebrating = false
                        emphasis = false
                    }
                }
            }
            .onDisappear {
                celebrating = false
                emphasis = false
                pendingReaction = 0
            }
    }
}

/// A single layout for photo-backed screen introductions and paper content sheets.
struct SweezyCompanionHeader: View {
    let title: String
    let subtitle: String
    var pose: SweezyCompanionPose = .guide
    var size: CGFloat = 112
    var reaction: Int = 0
    var onPhoto = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(onPhoto ? .white : Theme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(onPhoto ? .white.opacity(0.78) : Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            SweezyCompanion(pose: pose, size: dynamicTypeSize.isAccessibilitySize ? 80 : size, reaction: reaction)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Opaque surface prevents photos and light-mode glass from washing out companion copy.
struct SweezyCompanionPanel<Content: View>: View {
    var inset: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.ink, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
    }
}

/// One-shot social gestures. Reduced Motion keeps the illustration still.
struct SocialCompanion: View {
    var pose: SweezyCompanionPose = .welcome
    var size: CGFloat = 180
    var portrait = false
    var trigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilted = false

    var body: some View {
        Image(pose.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: portrait ? size * 1.65 : size, height: portrait ? size * 1.65 : size)
            .frame(width: size, height: size, alignment: .top)
            .clipped()
            .rotationEffect(.degrees(tilted && !reduceMotion ? -3 : 0), anchor: .bottom)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .task(id: trigger) {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.22)) { tilted = true }
                do {
                    try await Task.sleep(for: .milliseconds(240))
                    try Task.checkCancellation()
                    withAnimation(.easeInOut(duration: 0.28)) { tilted = false }
                } catch { tilted = false }
            }
            .onDisappear { tilted = false }
    }
}
