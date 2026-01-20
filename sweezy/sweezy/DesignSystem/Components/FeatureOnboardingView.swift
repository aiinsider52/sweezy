//
//  FeatureOnboardingView.swift
//  sweezy
//
//  Reusable modal onboarding view with single-page or carousel support.
//  Apple-style "What's New" design.
//

import SwiftUI

struct FeatureOnboardingView: View {
    let content: FeatureOnboardingContent
    let onDismiss: () -> Void
    
    @State private var currentPage = 0
    @Environment(\.colorScheme) private var colorScheme
    
    private var isLastPage: Bool {
        currentPage >= content.slides.count - 1
    }
    
    private var isMultiPage: Bool {
        content.slides.count > 1
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
            
            if isMultiPage {
                // Carousel mode
                TabView(selection: $currentPage) {
                    ForEach(Array(content.slides.enumerated()), id: \.element.id) { index, slide in
                        slideView(slide)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
            } else if let slide = content.slides.first {
                // Single page mode
                slideView(slide)
            }
            
            // Page indicator (only for multi-page)
            if isMultiPage {
                pageIndicator
                    .padding(.bottom, 16)
            }
            
            // Action button
            actionButton
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
        }
        .background(backgroundColor)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(!isLastPage && isMultiPage)
    }
    
    // MARK: - Slide View
    
    private func slideView(_ slide: OnboardingSlide) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(slide.iconColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(slide.iconColor.opacity(0.08))
                    .frame(width: 130, height: 130)
                
                Image(systemName: slide.icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(slide.iconColor)
            }
            .padding(.top, 20)
            
            // Title
            Text(slide.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            // Description
            Text(slide.description)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Page Indicator
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<content.slides.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Theme.Colors.accentTurquoise : Color.secondary.opacity(0.3))
                    .frame(width: index == currentPage ? 20 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentPage)
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
                withAnimation(.spring(response: 0.4)) {
                    currentPage += 1
                }
            }
        } label: {
            HStack {
                Text(isLastPage || !isMultiPage ? content.buttonTitle : "onboarding.next".localized)
                    .font(.system(size: 17, weight: .semibold))
                
                if !isLastPage && isMultiPage {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Colors.accentTurquoise)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Background
    
    private var backgroundColor: some View {
        Group {
            if colorScheme == .dark {
                Color(red: 0.11, green: 0.11, blue: 0.12)
            } else {
                Color(red: 0.98, green: 0.98, blue: 0.99)
            }
        }
        .ignoresSafeArea()
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if FeatureOnboardingManager.shared.shouldShowOnboarding(for: content.feature) {
                        showOnboarding = true
                    }
                }
            }
            .sheet(isPresented: $showOnboarding) {
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
