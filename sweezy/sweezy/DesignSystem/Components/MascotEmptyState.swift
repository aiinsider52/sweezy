import SwiftUI

/// Shared empty state: mascot, one clear sentence, one action.
/// Used instead of bare "nothing here" text so empty screens still feel part of the app.
struct MascotEmptyState: View {
    let title: String
    var subtitle: String?
    var pose: SweezyCompanionPose = .guide
    var actionTitle: String?
    var actionIdentifier: String?
    /// `story-<name>` scene to show instead of the standalone mascot, when the screen has one.
    var story: String?
    var action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            if let story {
                StoryScene(name: story, height: 168, cornerRadius: 20)
                    .padding(.bottom, 4)
            } else {
                ZStack {
                    Circle()
                        .fill(JourneyVisual.lime.opacity(0.2))
                        .frame(width: 128, height: 128)
                        .blur(radius: 26)
                    SweezyCompanion(pose: pose, size: 116)
                        .idleFloat(enabled: !reduceMotion)
                }
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .frame(height: 46)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())
                    .accessibilityIdentifier(actionIdentifier ?? "")
            }
        }
        .padding(.horizontal, story == nil ? 22 : 12)
        .padding(.top, story == nil ? 26 : 12)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.84), value: appeared)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .accessibilityElement(children: .contain)
    }
}
