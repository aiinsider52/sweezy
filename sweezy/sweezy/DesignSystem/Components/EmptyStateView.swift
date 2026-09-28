import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String?
    let actionTitle: String?
    var action: (() -> Void)?
    
    init(systemImage: String, title: String, subtitle: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        MascotEmptyState(
            title: title,
            subtitle: subtitle,
            pose: pose,
            actionTitle: actionTitle,
            action: action
        )
        .frame(maxWidth: 520)
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    /// The mascot mirrors what the screen is about, so empty states stop looking interchangeable.
    private var pose: SweezyCompanionPose {
        switch systemImage {
        case "calendar", "clock": return .documents
        case "checkmark.seal", "party.popper": return .celebrate
        default: return .guide
        }
    }
}

struct LoadingStateView: View {
    let title: String
    let subtitle: String?
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Gradient pulse bar
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                .fill(Theme.Colors.gradientAccent)
                .frame(width: 60, height: 6)
                .opacity(0.8)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        .allowsHitTesting(false)
                )
                .modifier(PulseAnimation())
            Text(title)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle.map { "\(title). \($0)" } ?? title)
    }
}

private struct PulseAnimation: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(!reduceMotion && animate ? 1.05 : 1.0)
            .animation(
                reduceMotion ? nil : Theme.Animation.soft.repeatForever(autoreverses: true),
                value: animate
            )
            .onAppear { animate = !reduceMotion }
    }
}

struct ErrorStateView: View {
    let title: String
    let message: String
    let retryTitle: String
    var onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.orange)
                .frame(width: 64, height: 64)
                .background(Color.orange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous))
            Text(title)
                .font(Theme.Typography.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 420)
            PrimaryButton(retryTitle) {
                onRetry()
            }
            .frame(maxWidth: 220)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}
