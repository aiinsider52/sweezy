//
//  ThemePreviewView.swift
//  sweezy
//
//  Visual QA for redesigned design system
//

import SwiftUI

struct ThemePreviewView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Colors Section
                    colorsSection
                    
                    Divider().padding(.horizontal)
                    
                    // Typography Section
                    typographySection
                    
                    Divider().padding(.horizontal)
                    
                    // Components Section
                    componentsSection
                    
                    Divider().padding(.horizontal)
                    
                    // Cards Section
                    cardsSection
                    
                    Divider().padding(.horizontal)
                    
                    // GoIT Special Section
                    goitSpecialSection
                    
                    Divider().padding(.horizontal)
                    
                    // Spacing Section
                    spacingSection
                    
                    Divider().padding(.horizontal)
                    
                    // Shadows Section
                    shadowsSection
                }
                .padding(.vertical, Theme.Spacing.xl)
            }
            .background(Theme.Colors.primaryBackground)
            .navigationTitle("Design System")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Colors", showAccentLine: true)
            
            // Brand Colors
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Brand")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                HStack(spacing: Theme.Spacing.sm) {
                    ColorSwatch(color: Theme.Colors.accentTurquoise, name: "Turquoise")
                    ColorSwatch(color: Theme.Colors.accentWarmGreen, name: "Warm Green")
                    ColorSwatch(color: Theme.Colors.accentYellowSoft, name: "Soft Yellow")
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            
            // Text Colors
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Text")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                HStack(spacing: Theme.Spacing.sm) {
                    ColorSwatch(color: Theme.Colors.textPrimary, name: "Primary")
                    ColorSwatch(color: Theme.Colors.textSecondary, name: "Secondary")
                    ColorSwatch(color: Theme.Colors.textTertiary, name: "Tertiary")
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            
            // Semantic Colors
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Semantic")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                HStack(spacing: Theme.Spacing.sm) {
                    ColorSwatch(color: Theme.Colors.success, name: "Success")
                    ColorSwatch(color: Theme.Colors.warning, name: "Warning")
                    ColorSwatch(color: Theme.Colors.error, name: "Error")
                    ColorSwatch(color: Theme.Colors.info, name: "Info")
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            
            // Gradients
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Gradients")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                VStack(spacing: Theme.Spacing.xs) {
                    GradientSwatch(gradient: Theme.Colors.gradientAccent, name: "Accent")
                    GradientSwatch(gradient: Theme.Colors.gradientSoft, name: "Soft")
                    GradientSwatch(gradient: Theme.Colors.gradientHero, name: "Hero")
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
    
    private var typographySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Typography", showAccentLine: true)
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                TypographyRow(font: Theme.Typography.largeTitle, name: "Large Title", size: "34pt Bold")
                TypographyRow(font: Theme.Typography.title1, name: "Title 1", size: "28pt Bold")
                TypographyRow(font: Theme.Typography.title2, name: "Title 2", size: "22pt Semibold")
                TypographyRow(font: Theme.Typography.headline, name: "Headline", size: "20pt Semibold")
                TypographyRow(font: Theme.Typography.body, name: "Body", size: "17pt Regular")
                TypographyRow(font: Theme.Typography.callout, name: "Callout", size: "16pt Regular")
                TypographyRow(font: Theme.Typography.subheadline, name: "Subheadline", size: "15pt Medium")
                TypographyRow(font: Theme.Typography.footnote, name: "Footnote", size: "13pt Regular")
                TypographyRow(font: Theme.Typography.caption, name: "Caption", size: "12pt Medium")
                TypographyRow(font: Theme.Typography.caption2, name: "Caption 2", size: "11pt Regular")
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
    
    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Components", showAccentLine: true)
            
            VStack(spacing: Theme.Spacing.md) {
                PrimaryButton("Primary Button") {}
                PrimaryButton("Secondary Button", style: .secondary) {}
                PrimaryButton("Outline Button", style: .outline) {}
                PrimaryButton("Loading State", isLoading: true) {}
                PrimaryButton("Disabled", isDisabled: true) {}
                HStack {
                    ChipView("All", systemImage: "square.grid.2x2", isSelected: true) {}
                    ChipView("Housing", systemImage: "house") {}
                    ChipView("Work", systemImage: "briefcase") {}
                }
                AccentTextField("Full name", text: .constant(""), icon: "person")
                AccentTextField("Email", text: .constant(""), icon: "envelope", keyboardType: .emailAddress)
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
    
    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Cards & Surfaces", showAccentLine: true)
            
            VStack(spacing: Theme.Spacing.md) {
                GlassCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Standard Glass Card")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("With inner glow and subtle material")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                
                GlassCard(gradientStroke: true) {
                    HStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.primary.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "star.fill")
                                .foregroundColor(Theme.Colors.accent)
                        }
                        Text("With Gradient Stroke")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private var goitSpecialSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("GoIT Specials", showAccentLine: true)
            
            VStack(spacing: Theme.Spacing.md) {
                PastelCard(background: Color(red: 0.93, green: 0.96, blue: 1.0)) {
                    HStack(spacing: 12) {
                        PixelBadgeIcon("doc.text")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pastel Card")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Large radius and soft shadow")
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()
                    }
                }
                
                HeroSplitView(
                    title: "Добро пожаловать",
                    subtitle: "Мы помогаем вам ориентироваться",
                    ctaTitle: "Начать",
                    right: { PixelBadgeIcon("sparkles", tint: .white) }
                ) {}
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
    
    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Spacing Scale", showAccentLine: true)
            
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                SpacingRow(value: Theme.Spacing.xxxs, name: "xxxs", points: "2pt")
                SpacingRow(value: Theme.Spacing.xxs, name: "xxs", points: "4pt")
                SpacingRow(value: Theme.Spacing.xs, name: "xs", points: "8pt")
                SpacingRow(value: Theme.Spacing.sm, name: "sm", points: "12pt")
                SpacingRow(value: Theme.Spacing.md, name: "md", points: "16pt")
                SpacingRow(value: Theme.Spacing.lg, name: "lg", points: "24pt")
                SpacingRow(value: Theme.Spacing.xl, name: "xl", points: "32pt")
                SpacingRow(value: Theme.Spacing.xxl, name: "xxl", points: "48pt")
                SpacingRow(value: Theme.Spacing.xxxl, name: "xxxl", points: "64pt")
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
    
    private var shadowsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Elevation & Shadows", showAccentLine: true)
            
            VStack(spacing: Theme.Spacing.lg) {
                ShadowCard(shadow: Theme.Shadows.level1, name: "Level 1 — Subtle lift")
                ShadowCard(shadow: Theme.Shadows.level2, name: "Level 2 — Cards")
                ShadowCard(shadow: Theme.Shadows.level3, name: "Level 3 — Modals")
                ShadowCard(shadow: Theme.Shadows.level4, name: "Level 4 — Floating CTAs")
                ShadowCard(shadow: Theme.Shadows.glow(color: Theme.Colors.accent), name: "Glow — Accent")
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
}

// MARK: - Helper Views

private struct ColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous)
                .fill(color)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
            Text(name)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

private struct GradientSwatch: View {
    let gradient: LinearGradient
    let name: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous)
                .fill(gradient)
                .frame(height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
            Text(name)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

private struct TypographyRow: View {
    let font: Font
    let name: String
    let size: String
    
    var body: some View {
        HStack {
            Text("Aa")
                .font(font)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(name)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(size)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

private struct SpacingRow: View {
    let value: CGFloat
    let name: String
    let points: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.Colors.accent)
                .frame(width: value, height: 20)
            Text(name)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
            Text(points)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
        }
    }
}

private struct ShadowCard: View {
    let shadow: Shadow
    let name: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(name)
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.textSecondary)
            
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                .fill(Color.white)
                .frame(height: 80)
                .themeShadow(shadow)
        }
    }
}

#Preview {
    ThemePreviewView()
}

