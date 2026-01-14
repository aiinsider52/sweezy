//
//  HeroView.swift
//  sweezy
//
//  Bold hero section with parallax effect — GoIT-inspired
//

import SwiftUI

/// Full-width cinematic hero with gradient background and parallax scrolling
struct HeroView<Content: View>: View {
    let height: CGFloat
    let gradient: LinearGradient
    let content: Content
    let enableParallax: Bool
    
    @State private var scrollOffset: CGFloat = 0
    
    init(
        height: CGFloat = 400,
        gradient: LinearGradient = Theme.Colors.gradientHero,
        enableParallax: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.height = height
        self.gradient = gradient
        self.enableParallax = enableParallax
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geo in
            let offset = geo.frame(in: .global).minY
            let parallaxOffset = enableParallax ? offset * 0.3 : 0
            
            ZStack(alignment: .bottom) {
                // Animated gradient background with parallax
                Rectangle()
                    .fill(gradient)
                    .frame(height: height + max(0, offset))
                    .offset(y: -offset + parallaxOffset)
                    .overlay(
                        // Subtle animated particles (optional)
                        FloatingParticles()
                            .opacity(0.3)
                            .allowsHitTesting(false)
                    )
                
                // Content layer (moves at normal speed)
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    content
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: height)
            .clipped()
            .onChange(of: offset) { _, newValue in
                scrollOffset = newValue
            }
        }
        .frame(height: height)
    }
}

/// Floating particles for hero background animation
private struct FloatingParticles: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<15, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: CGFloat.random(in: 20...60))
                    .offset(
                        x: CGFloat.random(in: -150...150),
                        y: animate ? -300 : 300
                    )
                    .animation(
                        Animation.linear(duration: Double.random(in: 8...15))
                            .repeatForever(autoreverses: false)
                            .delay(Double.random(in: 0...5)),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Hero Text Components

/// Large hero headline with optional gradient text
struct HeroHeadline: View {
    let text: String
    let gradient: Bool
    
    init(_ text: String, gradient: Bool = false) {
        self.text = text
        self.gradient = gradient
    }
    
    var body: some View {
        Text(text)
            .font(Theme.Typography.megaTitle)
            .fontWeight(.bold)
            .foregroundStyle(
                gradient
                    ? AnyShapeStyle(LinearGradient(
                        colors: [.white, Color.white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    : AnyShapeStyle(.white)
            )
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }
}

/// Hero subtitle text
struct HeroSubtitle: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(Theme.Typography.body)
            .foregroundColor(.white.opacity(0.9))
            .lineLimit(3)
    }
}

/// Hero CTA button
struct HeroCTA: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(Theme.Typography.body)
                    .fontWeight(.semibold)
            }
            .foregroundColor(Theme.Colors.primary)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Preview

#Preview("Hero - Light") {
    ScrollView {
        VStack(spacing: 0) {
            HeroView(height: 400) {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    HeroHeadline("Ласкаво просимо до Швейцарії")
                    HeroSubtitle("Ваш повний гід для успішного життя в Швейцарії")
                    HeroCTA("Почати", icon: "arrow.right") {}
                }
            }
            
            Rectangle()
                .fill(Theme.Colors.surface)
                .frame(height: 600)
                .overlay(Text("Scroll content below").foregroundColor(.gray))
        }
    }
}

#Preview("Hero - Dark") {
    ScrollView {
        VStack(spacing: 0) {
            HeroView(height: 400) {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    HeroHeadline("Welcome to Switzerland", gradient: true)
                    HeroSubtitle("Your complete guide for successful life in Switzerland")
                    HeroCTA("Get Started", icon: "arrow.right") {}
                }
            }
            
            Rectangle()
                .fill(Theme.Colors.darkBackground)
                .frame(height: 600)
                .overlay(Text("Scroll content below").foregroundColor(.white.opacity(0.5)))
        }
    }
    .preferredColorScheme(.dark)
}

