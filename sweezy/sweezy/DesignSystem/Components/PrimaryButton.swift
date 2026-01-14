//
//  PrimaryButton.swift
//  sweezy
//
//  Redesigned with Apple aesthetic
//

import SwiftUI

/// Primary CTA button with gradient background and natural motion
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    let isDisabled: Bool
    let style: ButtonStyle
    let size: ButtonSize
    
    enum ButtonStyle {
        case primary    // Gradient fill
        case secondary  // Subtle background
        case outline    // Transparent with border
        case coral      // Coral/orange solid CTA
    }
    enum ButtonSize {
        case small
        case regular
        case large
    }
    
    init(
        _ title: String,
        style: ButtonStyle = .primary,
        size: ButtonSize = .regular,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.9)
                } else {
                    Text(title)
                        .font(labelFont)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(backgroundView)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.pill, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill, style: .continuous))
            .themeShadow(shadowForStyle)
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(Theme.Animation.smooth, value: isPressed)
        .animation(Theme.Animation.smooth, value: isDisabled)
        .animation(Theme.Animation.smooth, value: isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isDisabled && !isLoading {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Theme.Colors.gradientAccent
        case .secondary:
            Theme.Colors.secondaryBackground
        case .outline:
            Color.clear
        case .coral:
            Theme.Colors.accentCoral
        }
    }
    
    private var height: CGFloat {
        switch size {
        case .small: return 44
        case .regular: return 56
        case .large: return 64
        }
    }
    
    private var labelFont: Font {
        switch size {
        case .small: return Theme.Typography.subheadline
        case .regular: return Theme.Typography.headline
        case .large: return Theme.Typography.title2
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return Theme.Colors.textOnPrimary
        case .secondary:
            return Theme.Colors.textPrimary
        case .outline:
            return Theme.Colors.accentTurquoise
        case .coral:
            return .white
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .secondary, .coral:
            return Color.clear
        case .outline:
            return Theme.Colors.accentTurquoise
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .primary, .secondary, .coral:
            return 0
        case .outline:
            return 2
        }
    }
    
    private var shadowForStyle: Shadow {
        switch style {
        case .primary:
            return Theme.Shadows.colored(color: Theme.Colors.accentTurquoise)
        case .secondary, .outline:
            return Theme.Shadows.level1
        case .coral:
            return Theme.Shadows.colored(color: Theme.Colors.accentCoral)
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        PrimaryButton("Continue") {
            print("Primary tapped")
        }
        
        PrimaryButton("Secondary Button", style: .secondary) {
            print("Secondary tapped")
        }
        
        PrimaryButton("Outline Button", style: .outline) {
            print("Outline tapped")
        }
        
        PrimaryButton("Loading...", isLoading: true) {
            print("Loading tapped")
        }
        
        PrimaryButton("Disabled", isDisabled: true) {
            print("Disabled tapped")
        }
    }
    .padding()
    .background(Theme.Colors.primaryBackground)
}
