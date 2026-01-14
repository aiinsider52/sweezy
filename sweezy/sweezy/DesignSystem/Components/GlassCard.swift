//
//  GlassCard.swift
//  sweezy
//
//  Redesigned with real depth and cinematic lighting
//

import SwiftUI

/// Glass morphism card component with depth and natural lighting
struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let padding: CGFloat
    let enableGradientStroke: Bool
    let enableInnerGlow: Bool
    
    init(
        cornerRadius: CGFloat = Theme.CornerRadius.lg,
        padding: CGFloat = Theme.Spacing.md,
        gradientStroke: Bool = false,
        innerGlow: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.enableGradientStroke = gradientStroke
        self.enableInnerGlow = innerGlow
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.Colors.glassMaterial.opacity(Theme.Colors.glassOpacity))
            )
            .overlay(
                // Gradient stroke
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: enableGradientStroke
                                ? [Color.white.opacity(0.4), Color.white.opacity(0.1)]
                                : [Color.white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .overlay(
                // Inner glow for depth
                Group {
                    if enableInnerGlow {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .themeShadow(Theme.Shadows.level2)
            .overlay(
                // Winter frost glow
                Group {
                    if WinterTheme.isActive {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.cyan.opacity(0.2),
                                        Color.blue.opacity(0.1),
                                        Color.cyan.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                            .allowsHitTesting(false)
                    }
                }
            )
    }
}

#Preview {
    ZStack {
        Theme.Colors.gradientHero
            .ignoresSafeArea()
        
        VStack(spacing: Theme.Spacing.lg) {
            GlassCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Standard Glass Card")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("This card uses the new material system with subtle inner glow and gradient stroke.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            
            GlassCard(cornerRadius: Theme.CornerRadius.xl, padding: Theme.Spacing.lg, gradientStroke: true) {
                HStack(spacing: Theme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primary.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "star.fill")
                            .foregroundColor(Theme.Colors.accent)
                            .font(.system(size: 24))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Premium Card")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("With gradient stroke")
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Spacer()
                }
            }
            
            GlassCard(innerGlow: false) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(Theme.Colors.info)
                    Text("Minimal card without inner glow")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }
        }
        .padding(Theme.Spacing.md)
    }
}
