//
//  FeatureOnboardingView.swift
//  sweezy
//
//  Reusable modal onboarding view with single-page or carousel support.
//  Winter/New Year themed design matching the app aesthetic.
//

import SwiftUI

struct FeatureOnboardingView: View {
    let content: FeatureOnboardingContent
    let onDismiss: () -> Void
    
    @State private var currentPage = 0
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var isLastPage: Bool {
        currentPage >= content.slides.count - 1
    }
    
    private var isMultiPage: Bool {
        content.slides.count > 1
    }
    
    var body: some View {
        ZStack {
            // Winter gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.08, blue: 0.18),
                    Color(red: 0.06, green: 0.12, blue: 0.24),
                    Color(red: 0.05, green: 0.10, blue: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Subtle ambient glow (static, no animation)
            Circle()
                .fill(Color.cyan.opacity(0.08))
                .frame(width: 250, height: 250)
                .blur(radius: 80)
                .offset(x: -80, y: -150)
            
            Circle()
                .fill(Color.blue.opacity(0.06))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: 100, y: 100)
            
            // Very light snowfall (minimal, won't crash)
            if WinterTheme.isActive {
                LightSnowfall()
                    .ignoresSafeArea()
            }
            
            // Main content
            VStack(spacing: 0) {
                // Close (disabled until last page for multi-page)
                HStack {
                    Spacer()
                    Button {
                        FeatureOnboardingManager.shared.markAsSeen(content.feature)
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isLastPage && isMultiPage)
                    .opacity((!isLastPage && isMultiPage) ? 0.25 : 1.0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                
                if isMultiPage {
                    // Carousel mode
                    TabView(selection: $currentPage) {
                        ForEach(Array(content.slides.enumerated()), id: \.element.id) { index, slide in
                            slideView(slide)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else if let slide = content.slides.first {
                    // Single page mode
                    slideView(slide)
                }
                
                // Page indicator (only for multi-page)
                if isMultiPage {
                    pageIndicator
                        .padding(.bottom, 20)
                }
                
                // Action button
                actionButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 38)
            }
        }
        .interactiveDismissDisabled(!isLastPage && isMultiPage)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    appeared = true
                }
            }
        }
    }
    
    // MARK: - Slide View
    
    private func slideView(_ slide: OnboardingSlide) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon with winter glow effect
            ZStack {
                // Outer glow
                Circle()
                    .fill(slide.iconColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                
                // Inner frost circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        slide.iconColor.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                
                // Icon
                Image(systemName: slide.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [slide.iconColor, slide.iconColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: slide.iconColor.opacity(0.5), radius: 10, x: 0, y: 4)
            }
            .scaleEffect(reduceMotion ? 1.0 : (appeared ? 1.0 : 0.8))
            .opacity(reduceMotion ? 1.0 : (appeared ? 1.0 : 0))
            .padding(.top, 16)
            
            // Title
            Text(slide.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Description
            Text(slide.description)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Page Indicator
    
    private var pageIndicator: some View {
        HStack(spacing: 10) {
            ForEach(0..<content.slides.count, id: \.self) { index in
                Capsule()
                    .fill(
                        index == currentPage
                        ? LinearGradient(
                            colors: [Color.cyan, Color.cyan.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.15)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
            }
        }
    }
    
    // MARK: - Action Button
    
    private var actionButton: some View {
        Button {
            if isLastPage || !isMultiPage {
                FeatureOnboardingManager.shared.markAsSeen(content.feature)
                onDismiss()
            } else {
                if reduceMotion {
                    currentPage += 1
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentPage += 1
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(isLastPage || !isMultiPage ? content.buttonTitle : "onboarding.next".localized)
                    .font(.system(size: 17, weight: .semibold))
                
                if !isLastPage && isMultiPage {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    // Gradient background
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.75, blue: 0.9),
                            Color(red: 0.25, green: 0.65, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Frost shimmer overlay
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.clear,
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.cyan.opacity(0.2),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.cyan.opacity(0.4), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: reduceMotion ? 1.0 : 0.97))
    }
}

// MARK: - Lightweight Snowfall (optimized for sheets)

private struct LightSnowfall: View {
    // Static positions - no Timer, no state updates = no crashes
    private let flakes: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = {
        (0..<12).map { _ in
            (
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 2...5),
                opacity: Double.random(in: 0.2...0.5)
            )
        }
    }()
    
    @State private var offset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            ZStack {
                ForEach(0..<flakes.count, id: \.self) { i in
                    let flake = flakes[i]
                    Circle()
                        .fill(Color.white.opacity(flake.opacity))
                        .frame(width: flake.size, height: flake.size)
                        .position(
                            x: flake.x * width,
                            y: (flake.y * height + offset * (0.5 + flake.size / 10)).truncatingRemainder(dividingBy: height + 20)
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            // Single slow animation, not a Timer loop
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                offset = 800
            }
        }
    }
}

// MARK: - View Modifier for Easy Integration

struct FeatureOnboardingModifier: ViewModifier {
    let content: FeatureOnboardingContent
    @State private var showOnboarding = false
    
    func body(content view: Content) -> some View {
        view
            .onAppear {
                // Delay slightly for smoother UX
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if FeatureOnboardingManager.shared.shouldShowOnboarding(for: content.feature) {
                        showOnboarding = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                FeatureOnboardingView(content: content) {
                    showOnboarding = false
                }
            }
    }
}

extension View {
    /// Attach feature onboarding that shows on first visit
    func featureOnboarding(_ content: FeatureOnboardingContent) -> some View {
        modifier(FeatureOnboardingModifier(content: content))
    }
}

// MARK: - Preview

#Preview("Single Page") {
    Text("Feature Screen")
        .sheet(isPresented: .constant(true)) {
            FeatureOnboardingView(content: .calculator) {}
        }
}

#Preview("Multi Page") {
    Text("Feature Screen")
        .sheet(isPresented: .constant(true)) {
            FeatureOnboardingView(content: .dovidnyk) {}
        }
}
