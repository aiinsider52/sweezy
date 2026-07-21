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
        // MARK: Brand Colors — Spring/Summer 2025 (Swiss Alpine Spring)
        static let primary = JourneyVisual.lime
        static let primaryLight = Color(red: 0.88, green: 1.0, blue: 0.32)
        static let primaryDark = Color(red: 0.48, green: 0.68, blue: 0.02)
        static let accent = JourneyVisual.lime

        // MARK: Spring Accents
        static let accentTurquoise = JourneyVisual.lime
        static let accentYellowSoft = Color(red: 1.0, green: 0.945, blue: 0.463) // #FFF176 Pastel Yellow
        static let accentWarmGreen = JourneyVisual.lime
        static let accentCoral = Color(red: 1.0, green: 0.439, blue: 0.263) // #FF7043 Warm Orange

        // MARK: Surface Colors (Light)
        static let surface = Color(red: 0.980, green: 0.992, blue: 0.969) // #FAFDF7 spring white-green
        static let card = Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.85)
        static let divider = Color.black.opacity(0.06)

        // MARK: Ink & Paper (layered surfaces: dark pine header + light sheet)
        /// Deep pine green used for dark header blocks. Same in both schemes —
        /// it's the "ink" layer the paper sheet overlaps.
        static let ink = Color(red: 0.086, green: 0.149, blue: 0.106) // #16261B
        /// Elevated element on top of ink (chips, avatar rings, pill track).
        static let inkElevated = Color.white.opacity(0.10)
        static let inkBorder = Color.white.opacity(0.14)
        /// Sheet background: spring off-white in light, ink in dark.
        static let paper = Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 0.02, alpha: 0.38)
                : UIColor(red: 0.980, green: 0.992, blue: 0.969, alpha: 1.0) // #FAFDF7
        })
        /// Opaque card on paper: solid white in light, elevated green-tinted in dark.
        static let paperCard = Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.12)
                : UIColor.white
        })

        // MARK: Spring Backgrounds
        static let backgroundIvory = Color(red: 0.980, green: 0.992, blue: 0.969) // #FAFDF7
        static let backgroundStone = Color(red: 0.945, green: 0.973, blue: 0.914) // #F1F8E9

        // MARK: Text Colors (adaptive: dark text on light bg, white on dark bg)
        static var textPrimary: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.92)
                    : UIColor(red: 0.110, green: 0.169, blue: 0.102, alpha: 1.0) // #1C2B1A
            })
        }
        
        static var textSecondary: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.60)
                    : UIColor(red: 0.290, green: 0.369, blue: 0.282, alpha: 1.0) // #4A5E48
            })
        }
        
        static var textTertiary: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.40)
                    : UIColor(red: 0.482, green: 0.580, blue: 0.475, alpha: 1.0) // #7B9479
            })
        }
        
        static let textOnPrimary = Color.black
        
        // MARK: Semantic Colors
        static let success = Color(red: 0.220, green: 0.557, blue: 0.235) // #388E3C
        static let warning = Color(red: 0.976, green: 0.659, blue: 0.145) // #F9A825
        static let error = Color(red: 0.827, green: 0.184, blue: 0.184) // #D32F2F
        static let info = Color(red: 0.008, green: 0.533, blue: 0.820) // #0288D1
        
        // MARK: Dark Mode Specific
        static let darkBackground = Color(red: 0.102, green: 0.137, blue: 0.094) // #1A2318
        static let darkSurface = Color.white.opacity(0.06)
        static let darkCard = Color.white.opacity(0.08)
        static let darkElevated = Color.white.opacity(0.12)
        
        // MARK: Adaptive Card / Surface / Border
        static let adaptiveCard = Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 0.02, alpha: 0.42)
                : UIColor(white: 1.0, alpha: 0.85)
        })
        
        static let adaptiveSurface = Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 0.02, alpha: 0.34)
                : UIColor(red: 0.945, green: 0.973, blue: 0.914, alpha: 1.0) // #F1F8E9
        })
        
        static let adaptiveBorder = Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.22)
                : UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.08)
        })
        
        // MARK: Adaptive Backgrounds
        static var primaryBackground: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: 0.015, alpha: 0.24)
                    : UIColor(red: 0.980, green: 0.992, blue: 0.969, alpha: 1.0) // #FAFDF7
            })
        }
        
        static var secondaryBackground: Color {
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.02, alpha: 0.42)
                    : UIColor.secondarySystemBackground
            })
        }
        
        static var tertiaryBackground: Color {
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.03, alpha: 0.32)
                    : UIColor.tertiarySystemBackground
            })
        }
        
        // MARK: Legacy Compatibility
        static let ukrainianBlue = primary
        static let warmYellow = accent
        static let swissWhite = Color(red: 0.98, green: 0.99, blue: 0.97)
        static let swissGray = Color(red: 0.45, green: 0.48, blue: 0.44)
        static let swissLightGray = Color(red: 0.95, green: 0.97, blue: 0.94)
        
        // Glass helpers (adaptive for light/dark)
        static var glassBackground: Color {
            Color(UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 0.02, alpha: 0.38)
                    : UIColor(white: 0.0, alpha: 0.04)
            })
        }
        static var glassBorder: Color {
            Color(UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.2)
                    : UIColor(white: 0.0, alpha: 0.08)
            })
        }
        
        // MARK: Gradients
        static var gradientPrimary: LinearGradient {
            LinearGradient(
                colors: [primary, accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var gradientAccent: LinearGradient {
            LinearGradient(
                colors: [accentTurquoise, primary],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        
        static var gradientSoft: LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 0.945, green: 0.973, blue: 0.914), // #F1F8E9
                    Color(red: 1.0, green: 0.945, blue: 0.463)    // #FFF176
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static var gradientHero: LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 0.180, green: 0.490, blue: 0.196), // #2E7D32
                    Color(red: 0.106, green: 0.369, blue: 0.125)  // #1B5E20
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        
        // Legacy gradient name
        static var primaryGradient: LinearGradient { gradientPrimaryAdaptive }
        
        static var gradientSunrise: LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.945, blue: 0.463),   // #FFF176
                    Color(red: 0.976, green: 0.659, blue: 0.145)   // #F9A825
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        
        // MARK: Adaptive Gradient
        static var gradientPrimaryAdaptive: LinearGradient {
            LinearGradient(
                colors: [
                    Color(UIColor { $0.userInterfaceStyle == .dark
                        ? UIColor(red: 0.400, green: 0.733, blue: 0.416, alpha: 1.0) // #66BB6A
                        : UIColor(red: 0.180, green: 0.490, blue: 0.196, alpha: 1.0) // #2E7D32
                    }),
                    Color(UIColor { $0.userInterfaceStyle == .dark
                        ? UIColor(red: 0.976, green: 0.659, blue: 0.145, alpha: 1.0) // #F9A825
                        : UIColor(red: 0.400, green: 0.733, blue: 0.416, alpha: 1.0) // #66BB6A
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
        static let chipBorder = Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.18)
                : UIColor(red: 0.180, green: 0.490, blue: 0.196, alpha: 0.15)
        })
        static let chipBackground = Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.09)
                : UIColor(red: 0.180, green: 0.490, blue: 0.196, alpha: 0.06)
        })
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
        
        // Level 2: Cards — tinted with primary for cohesive palette
        static let level2 = Shadow(color: Theme.Colors.primary.opacity(0.08), radius: 12, x: 0, y: 4)
        
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
    
    /// Paper card style: opaque card with soft shadow (no glass), per ink+paper design language
    func paperCard(cornerRadius: CGFloat = Theme.CornerRadius.xl) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.Colors.paperCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.adaptiveBorder, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
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
