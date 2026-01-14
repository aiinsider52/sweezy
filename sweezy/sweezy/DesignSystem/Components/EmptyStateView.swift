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
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.primaryGradient)
            
            VStack(spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(Theme.Typography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.primaryText)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
            }
            
            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(actionTitle, style: .secondary) {
                    action()
                }
                .frame(maxWidth: 220)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .foregroundColor(Theme.Colors.secondaryText)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PulseAnimation: ViewModifier {
    @State private var animate = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(animate ? 1.05 : 1.0)
            .animation(Theme.Animation.soft.repeatForever(autoreverses: true), value: animate)
            .onAppear { animate = true }
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
                .font(.system(size: 56))
                .foregroundColor(.orange)
            Text(title)
                .font(Theme.Typography.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.primaryText)
            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            PrimaryButton(retryTitle) {
                onRetry()
            }
            .frame(maxWidth: 220)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
