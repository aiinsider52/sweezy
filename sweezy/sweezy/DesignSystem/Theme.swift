//
//  Theme.swift
//  sweezy
//
//  Redesigned with Apple × OpenAI × Monobank aesthetic
//

import SwiftUI
import UIKit

/// Design system theme with colors, typography, spacing, and motion
struct Theme {
    
    // MARK: - Colors
    struct Colors {
        // MARK: Brand Colors (Legacy / Ukrainian)
        static let primary = Color(red: 0.0, green: 0.357, blue: 0.733) // #005BBB Ukrainian Blue
        static let accent = Color(red: 1.0, green: 0.835, blue: 0.0) // #FFD500 Gold

        // MARK: GoIT-Inspired Accents
        static let accentTurquoise = Color(red: 0.0, green: 0.784, blue: 0.627) // #00C8A0
        static let accentYellowSoft = Color(red: 1.0, green: 0.878, blue: 0.4) // #FFE066
        static let accentWarmGreen = Color(red: 0.643, green: 0.902, blue: 0.765) // #A4E6C3
        static let accentCoral = Color(red: 1.0, green: 0.439, blue: 0.357) // #FF705B

        // MARK: Surface Colors (Light)
        static let surface = Color(red: 0.957, green: 0.976, blue: 0.965) // light pastel surface
        static let card = Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.65)
        static let divider = Color.black.opacity(0.06)

        // MARK: GoIT-Inspired Backgrounds
        static let backgroundIvory = Color(red: 0.980, green: 0.976, blue: 0.965) // #FAF9F6
        static let backgroundStone = Color(red: 0.961, green: 0.961, blue: 0.953) // #F5F5F3

        // MARK: Text Colors (Dynamic)
        static var textPrimary: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.92)
                    : UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1.0) // #212121 graphite
            })
        }
        
        static var textSecondary: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.6)
                    : UIColor(red: 0.047, green: 0.047, blue: 0.082, alpha: 0.6)
            })
        }
        
        static var textTertiary: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.4)
                    : UIColor(red: 0.047, green: 0.047, blue: 0.082, alpha: 0.4)
            })
        }
        
        static let textOnPrimary = Color.white
        
        // MARK: Semantic Colors
        static let success = Color(red: 0.204, green: 0.78, blue: 0.349) // #34C759
        static let warning = Color(red: 1.0, green: 0.584, blue: 0.0) // #FF9500
        static let error = Color(red: 1.0, green: 0.231, blue: 0.188) // #FF3B30
        static let info = Color(red: 0.0, green: 0.478, blue: 1.0) // #007AFF
        
        // Backwards-compatibility aliases
        static var primaryText: Color { textPrimary }
        static var secondaryText: Color { textSecondary }
        static var tertiaryText: Color { textTertiary }
        
        // MARK: Dark Mode Specific
        static let darkBackground = Color(red: 0.047, green: 0.047, blue: 0.082) // #0C0C15
        static let darkSurface = Color.white.opacity(0.06)
        static let darkCard = Color.white.opacity(0.08)
        static let darkElevated = Color.white.opacity(0.12)
        
        // MARK: Adaptive Backgrounds
        static var primaryBackground: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.047, green: 0.047, blue: 0.082, alpha: 1.0)
                    : UIColor(red: 0.980, green: 0.976, blue: 0.965, alpha: 1.0) // Ivory
            })
        }
        
        static var secondaryBackground: Color {
            Color(UIColor.secondarySystemBackground)
        }
        
        static var tertiaryBackground: Color {
            Color(UIColor.tertiarySystemBackground)
        }
        
        // MARK: Legacy Compatibility
        static let ukrainianBlue = primary
        static let warmYellow = accent
        static let swissWhite = Color(red: 0.98, green: 0.98, blue: 0.98)
        static let swissGray = Color(red: 0.45, green: 0.45, blue: 0.45)
        static let swissLightGray = Color(red: 0.95, green: 0.95, blue: 0.95)
        
        // Older glass helpers (kept for compatibility)
        static var glassBackground: Color { Color.white.opacity(0.1) }
        static var glassBorder: Color { Color.white.opacity(0.2) }
        
        // MARK: Gradients
        static var gradientPrimary: LinearGradient {
            LinearGradient(
                colors: [primary, accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// GoIT-inspired accent gradient (turquoise -> warm green)
        static var gradientAccent: LinearGradient {
            LinearGradient(
                colors: [accentTurquoise, accentWarmGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        
        static var gradientSoft: LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 0.878, green: 0.914, blue: 1.0), // #E0E9FF
                    Color(red: 1.0, green: 0.961, blue: 0.855) // #FFF5DA
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static var gradientHero: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: accentTurquoise, location: 0.0),
                    .init(color: Color(red: 0.0, green: 0.6, blue: 0.6), location: 0.5),
                    .init(color: accentWarmGreen, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        // Legacy gradient name
        static var primaryGradient: LinearGradient { gradientPrimaryAdaptive }
        
        // MARK: Adaptive Gradient (Dark Mode)
        static var gradientPrimaryAdaptive: LinearGradient {
            LinearGradient(
                colors: [
                    Color(UIColor { $0.userInterfaceStyle == .dark
                        ? UIColor(red: 0.0, green: 0.6, blue: 0.6, alpha: 1.0)
                        : UIColor(red: 0.0, green: 0.784, blue: 0.627, alpha: 1.0) // #00C8A0
                    }),
                    Color(UIColor { $0.userInterfaceStyle == .dark
                        ? UIColor(red: 0.98, green: 0.75, blue: 0.2, alpha: 1.0)
                        : UIColor(red: 0.643, green: 0.902, blue: 0.765, alpha: 1.0) // #A4E6C3
                    })
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        // MARK: Glass Effects
        static var glassMaterial: Material {
            .ultraThinMaterial
        }
        
        static var glassOpacity: Double { 0.75 }

        // MARK: Inputs & Chips
        static let chipBorder = Color(red: 0.878, green: 0.878, blue: 0.878) // #E0E0E0
        static var chipBackground: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.08)
                    : UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
            })
        }
        static let inputBorder = Color(red: 0.878, green: 0.878, blue: 0.878) // #E0E0E0
        static let focusGlow = accentTurquoise.opacity(0.35)
    }
    
    // MARK: - Typography
    struct Typography {
        // MARK: Display Hierarchy (GoIT-inspired bold scale)
        static let megaTitle = Font.system(size: 48, weight: .bold, design: .default) // Hero headlines
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title1 = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 24, weight: .semibold, design: .default)
        static let headline = Font.system(size: 20, weight: .semibold, design: .default)
        
        // MARK: Body Text
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let subhead = Font.system(size: 22, weight: .semibold, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .medium, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        
        // MARK: Small Text
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        
        // MARK: Mono (Numbers/Code)
        static let mono = Font.system(size: 17, weight: .regular, design: .monospaced)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let pill: CGFloat = 999
    }
    
    // MARK: - Shadows
    struct Shadows {
        // Level 0: Flat on surface
        static let level0 = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        
        // Level 1: Subtle lift
        static let level1 = Shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        
        // Level 2: Cards
        static let level2 = Shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        
        // Level 3: Modals
        static let level3 = Shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 8)
        
        // Level 4: Floating CTAs
        static let level4 = Shadow(color: Color.black.opacity(0.16), radius: 32, x: 0, y: 12)
        
        // Special: Glow
        static func glow(color: Color) -> Shadow {
            Shadow(color: color.opacity(0.3), radius: 20, x: 0, y: 0)
        }
        
        // Special: Colored
        static func colored(color: Color) -> Shadow {
            Shadow(color: color.opacity(0.2), radius: 16, x: 0, y: 4)
        }
        
        // Legacy
        static let light = level1
        static let medium = level2
        static let heavy = level4
    }
    
    // MARK: - Animation
    struct Animation {
        // Spring Presets
        static let quick = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0.2)
        static let smooth = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.3)
        static let soft = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3)
        static let bounce = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.3)
        
        // Duration-based (fallback)
        static let micro = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
    }
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions
extension View {
    /// Apply conditional transformation
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply theme shadow
    func themeShadow(_ shadow: Shadow) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }

    /// Enforce a single-line heading with tail truncation
    func singleLineHeading() -> some View {
        self
            .lineLimit(1)
            .truncationMode(.tail)
    }
    
    /// Apply glass effect with gradient stroke
    func glassEffect(strokeGradient: Bool = true) -> some View {
        self
            .background(Theme.Colors.glassMaterial.opacity(Theme.Colors.glassOpacity))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: strokeGradient
                                ? [Color.white.opacity(0.4), Color.white.opacity(0.1)]
                                : [Color.white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .themeShadow(Theme.Shadows.level2)
    }
    
    /// Apply gradient stroke overlay
    func gradientStroke(cornerRadius: CGFloat = Theme.CornerRadius.lg, lineWidth: CGFloat = 1) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )
                .allowsHitTesting(false)
        )
    }
    
    /// Floating card style
    func floatingCard() -> some View {
        self
            .background(Theme.Colors.glassMaterial)
            .gradientStroke(cornerRadius: Theme.CornerRadius.lg, lineWidth: 1)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .themeShadow(Theme.Shadows.level2)
    }
    
    /// Lock overlay reusable component
    func withLockOverlay(if condition: Bool, message: String) -> some View {
        ZStack {
            self.blur(radius: condition ? 4 : 0)
            if condition {
                LockOverlay(message: message)
            }
        }
    }
}

// MARK: - Backdrop Blur Effect
struct BackdropBlurView: UIViewRepresentable {
    let radius: CGFloat
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        let blur = UIBlurEffect(style: .systemUltraThinMaterial)
        view.effect = blur
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

extension View {
    func backdrop(blur radius: CGFloat) -> some View {
        self.background(BackdropBlurView(radius: radius))
    }
}

// MARK: - Lock Overlay View (local alias to avoid duplicate type with Features/Shared)
private struct LockOverlay: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .blur(radius: 8)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.Colors.primary)
            }
            
            Text(message)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.glassMaterial.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous))
        .themeShadow(Theme.Shadows.level3)
    }
}
