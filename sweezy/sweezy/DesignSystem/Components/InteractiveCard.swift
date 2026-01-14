//
//  InteractiveCard.swift
//  sweezy
//
//  Tappable card component with gradient icon and hover effects
//

import SwiftUI

/// Interactive card for list items with icon, title, subtitle, and chevron
struct InteractiveCard: View {
    let icon: String
    let iconGradient: Bool
    let title: String
    let subtitle: String?
    let badge: String?
    let badgeColor: Color
    let action: () -> Void
    
    // Press state visual handled by ButtonStyle; no custom gesture to avoid intercepting taps
    
    init(
        icon: String,
        iconGradient: Bool = true,
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        badgeColor: Color = Theme.Colors.primary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconGradient = iconGradient
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.badgeColor = badgeColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                // Icon with gradient or solid color
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primary.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            iconGradient
                                ? AnyShapeStyle(Theme.Colors.gradientPrimaryAdaptive)
                                : AnyShapeStyle(Theme.Colors.primary)
                        )
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(title)
                            .font(Theme.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(Theme.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(badgeColor)
                                )
                        }
                    }
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .fill(Theme.Colors.glassMaterial.opacity(Theme.Colors.glassOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .themeShadow(Theme.Shadows.level2)
        }
        .buttonStyle(CardPressStyle())
    }
}

// MARK: - Compact variant for secondary lists

/// Compact card variant for dense lists
struct CompactCard: View {
    let icon: String
    let title: String
    let value: String?
    let action: () -> Void
    
    init(
        icon: String,
        title: String,
        value: String? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.Colors.gradientPrimaryAdaptive)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Theme.Colors.primary.opacity(0.1))
                    )
                
                Text(title)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.glassMaterial.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous))
        }
        .buttonStyle(CardPressStyle())
    }
}

// MARK: - Preview

#Preview("Interactive Cards") {
    ZStack {
        Theme.Colors.surface.ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                InteractiveCard(
                    icon: "book.fill",
                    title: "Guides for Newcomers",
                    subtitle: "Complete information for your first steps in Switzerland",
                    badge: "New",
                    badgeColor: Theme.Colors.success
                ) {
                    print("Tapped")
                }
                
                InteractiveCard(
                    icon: "checkmark.circle.fill",
                    title: "Residency Checklist",
                    subtitle: "14 tasks remaining"
                ) {
                    print("Tapped")
                }
                
                InteractiveCard(
                    icon: "doc.text.fill",
                    title: "Employment Contract Template",
                    subtitle: nil,
                    badge: "Premium",
                    badgeColor: Theme.Colors.accent
                ) {
                    print("Tapped")
                }
                
                Divider().padding(.vertical, Theme.Spacing.sm)
                
                Text("Compact Variant")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: Theme.Spacing.xs) {
                    CompactCard(icon: "moon.fill", title: "Dark Mode", value: "System") {}
                    CompactCard(icon: "globe", title: "Language", value: "Українська") {}
                    CompactCard(icon: "bell.fill", title: "Notifications") {}
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }
}

#Preview("Dark Mode") {
    ZStack {
        Theme.Colors.darkBackground.ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                InteractiveCard(
                    icon: "star.fill",
                    title: "Starred Guide",
                    subtitle: "Your favorite resources in one place"
                ) {}
                
                InteractiveCard(
                    icon: "calendar",
                    title: "Upcoming Appointments",
                    subtitle: "3 appointments this week",
                    badge: "3",
                    badgeColor: .orange
                ) {}
            }
            .padding(Theme.Spacing.lg)
        }
    }
    .preferredColorScheme(.dark)
}

