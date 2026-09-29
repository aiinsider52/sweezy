//
//  ButtonStyles.swift
//  sweezy
//
//  Reusable button styles with interactive animations
//

import SwiftUI

/// Scale button style with haptic feedback
struct ScaleButtonStyle: ButtonStyle {
    let scaleAmount: CGFloat
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    
    init(
        scaleAmount: CGFloat = 0.96,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium
    ) {
        self.scaleAmount = scaleAmount
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        ScaleButtonBody(configuration: configuration, scaleAmount: scaleAmount, hapticStyle: hapticStyle)
    }
}

private struct ScaleButtonBody: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let configuration: ButtonStyleConfiguration
    let scaleAmount: CGFloat
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(reduceMotion ? nil : Theme.Animation.quick, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { UIImpactFeedbackGenerator(style: hapticStyle).impactOccurred() }
            }
    }
}

/// Glow button style that increases glow on press
struct GlowButtonStyle: ButtonStyle {
    let glowColor: Color
    
    init(glowColor: Color = Theme.Colors.primary) {
        self.glowColor = glowColor
    }
    
    func makeBody(configuration: Configuration) -> some View {
        GlowButtonBody(configuration: configuration, glowColor: glowColor)
    }
}

private struct GlowButtonBody: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let configuration: ButtonStyleConfiguration
    let glowColor: Color

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1.0)
            .shadow(
                color: glowColor.opacity(configuration.isPressed ? 0.36 : 0.16),
                radius: configuration.isPressed ? 18 : 12,
                x: 0,
                y: 4
            )
            .animation(reduceMotion ? nil : Theme.Animation.quick, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            }
    }
}

/// Card press style with subtle scale and glow
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CardPressBody(configuration: configuration)
    }
}

private struct CardPressBody: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(reduceMotion ? nil : Theme.Animation.quick, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            }
    }
}
