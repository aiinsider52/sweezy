//
//  OnboardingViewRedesigned.swift
//  sweezy
//
//  Bold GoIT-inspired full-screen hero onboarding
//

import SwiftUI

struct OnboardingViewRedesigned: View {
    @AppStorage("preferredLanguage") private var preferredLanguage = "uk"
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appContainer: AppContainer
    
    @State private var currentPage = 0
    @State private var showLanguageSelection = false
    @State private var showWinterGreeting = WinterTheme.isActive
    
    private let pages: [OnboardingV2Page] = [
        OnboardingV2Page(
            id: 1,
            icon: "hand.wave.fill",
            gradient: LinearGradient(
                colors: [Color(red: 0.0, green: 0.357, blue: 0.733), Color(red: 0.0, green: 0.478, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            titleKey: "onboarding.page1.title",
            subtitleKey: "onboarding.page1.subtitle"
        ),
        OnboardingV2Page(
            id: 2,
            icon: "book.pages.fill",
            gradient: LinearGradient(
                colors: [Color(red: 0.0, green: 0.478, blue: 1.0), Color(red: 0.204, green: 0.78, blue: 0.349)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            titleKey: "onboarding.page2.title",
            subtitleKey: "onboarding.page2.subtitle"
        )
    ]
    
    var body: some View {
        ZStack {
            // Winter greeting screen (shown first in winter season)
            if showWinterGreeting {
                WinterGreetingScreen {
                    withAnimation(Theme.Animation.smooth) {
                        showWinterGreeting = false
                    }
                }
                .transition(.opacity)
            } else {
                // Full-screen paged content
                TabView(selection: $currentPage) {
                    ForEach(pages) { page in
                        OnboardingV2PageView(page: page)
                            .tag(page.id - 1)
                    }
                    // Language picker page
                    LanguagePickerPage(selectedLanguage: $preferredLanguage) { code in
                        preferredLanguage = code
                        appContainer.updateLocale(Locale(identifier: code))
                    }
                    .tag(pages.count)
                    // Theme picker page (second to last)
                    ThemePickerPage(selectedTheme: $themeManager.selectedTheme)
                        .tag(pages.count + 1)
                    // Success page (last)
                    SuccessPageView()
                        .tag(totalPages - 1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            
            // Top controls (only Skip on the right)
            VStack {
                HStack {
                    Spacer()

                    // Skip button (only on non-final pages)
                    if currentPage < totalPages - 1 {
                        Button(action: completeOnboarding) {
                            Text(LocalizedStringKey("onboarding.skip"))
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                        }
                        .accessibilityIdentifier("onboarding.skipButton")
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xl)
                
                Spacer()
            }
            
            // Bottom controls
            VStack {
                Spacer()
                
                // Page indicator - winter snowflakes or regular dots
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        if WinterTheme.isActive {
                            Text(index == currentPage ? "❄️" : "•")
                                .font(.system(size: index == currentPage ? 16 : 10))
                                .foregroundColor(index == currentPage ? Color.cyan : Color.white.opacity(0.4))
                                .scaleEffect(index == currentPage ? 1.1 : 1.0)
                                .animation(Theme.Animation.smooth, value: currentPage)
                        } else {
                            Capsule()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                                .frame(width: index == currentPage ? 32 : 8, height: 8)
                                .animation(Theme.Animation.smooth, value: currentPage)
                        }
                    }
                }
                .padding(.bottom, Theme.Spacing.lg)
                
                // Navigation buttons
                HStack(spacing: Theme.Spacing.md) {
                    // Back button (only if not first page)
                    if currentPage > 0 {
                        Button(action: goBack) {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(LocalizedStringKey("common.back"))
                                    .font(Theme.Typography.body)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.18))
                            )
                        }
                        .accessibilityIdentifier("onboarding.backButton")
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    
                    // Next/Get Started button
                    Button(action: goNext) {
                        HStack {
                            Text(LocalizedStringKey(currentPage == totalPages - 1 ? "onboarding.get_started" : "common.next"))
                            .font(Theme.Typography.body)
                            .fontWeight(.semibold)
                            
                            if currentPage < totalPages - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .semibold))
                            } else {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(Theme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                        )
                    }
                    .accessibilityIdentifier(currentPage == totalPages - 1 ? "onboarding.getStartedButton" : "onboarding.nextButton")
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
            } // End of else block for showWinterGreeting
        }
        .animation(Theme.Animation.smooth, value: currentPage)
        .animation(Theme.Animation.smooth, value: showWinterGreeting)
        .sheet(isPresented: $showLanguageSelection) {
            LanguageSelectionSheetV2(selectedLanguage: $preferredLanguage)
        }
    }
    
    // MARK: - Actions
    
    private func goNext() {
        if currentPage < totalPages - 1 {
            withAnimation(Theme.Animation.smooth) {
                currentPage += 1
            }
            triggerHapticFeedback()
        } else {
            completeOnboarding()
        }
    }
    
    private func goBack() {
        if currentPage > 0 {
            withAnimation(Theme.Animation.smooth) {
                currentPage -= 1
            }
            triggerHapticFeedback()
        }
    }
    
    private func completeOnboarding() {
        withAnimation(Theme.Animation.smooth) {
            appContainer.completeOnboarding()
        }
        triggerHapticFeedback(style: .medium)
    }
    
    private var totalPages: Int { pages.count + 3 }
    
    private var languageDisplayName: String {
        switch preferredLanguage {
        case "uk": return "Українська"
        case "ru": return "Русский"
        case "en": return "English"
        case "de": return "Deutsch"
        default: return "Українська"
        }
    }
    
    private func triggerHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Theme Picker Page

private struct ThemePickerPage: View {
    @Binding var selectedTheme: AppTheme
    @State private var selectionIndex: Int = 0
    
    private let controlWidth: CGFloat = 280
    private let controlHeight: CGFloat = 56
    
    var body: some View {
        ZStack {
            // Background - winter or theme-based
            if WinterTheme.isActive {
                // Winter night background (dark by default for consistency)
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.25),
                        Color(red: 0.1, green: 0.15, blue: 0.35),
                        Color(red: 0.08, green: 0.12, blue: 0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Northern lights
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.1),
                        Color.green.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 40)
                .ignoresSafeArea()
                
                // Snowfall
                SnowfallView(particleCount: 12, speed: 0.5)
                    .ignoresSafeArea()
            } else {
                // Background that reflects current theme choice
                Group {
                    if selectedTheme == .dark {
                        LinearGradient(
                            colors: [Color(red: 0.05, green: 0.05, blue: 0.12), Color(red: 0.0, green: 0.35, blue: 0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            colors: [Color(red: 0.9, green: 0.98, blue: 0.96), Color(red: 0.96, green: 0.99, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .ignoresSafeArea()
                .overlay(FloatingParticlesOverlayV2().opacity(0.15))
            }
            
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                
                // Title
                VStack(spacing: Theme.Spacing.sm) {
                    Text("onboarding.choose_style.title".localized)
                        .font(Theme.Typography.title1)
                        .fontWeight(.bold)
                        .foregroundColor(selectedTheme == .dark ? .white : Theme.Colors.textPrimary)
                    Text("onboarding.choose_style.subtitle".localized)
                        .font(Theme.Typography.body)
                        .foregroundColor(selectedTheme == .dark ? .white.opacity(0.8) : Theme.Colors.textSecondary)
                }
                
                // Switcher (Bolt/Uber inspired)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: controlHeight/2, style: .continuous)
                        .fill(selectedTheme == .dark ? Color.white.opacity(0.08) : Color.white)
                        .frame(width: controlWidth, height: controlHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: controlHeight/2)
                                .stroke(selectedTheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .shadow(color: selectedTheme == .dark ? .black.opacity(0.25) : .black.opacity(0.06), radius: 10, x: 0, y: 6)
                    
                    // Sliding knob
                    RoundedRectangle(cornerRadius: controlHeight/2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: selectedTheme == .dark ? [Color.white.opacity(0.15), Color.white.opacity(0.05)] : [Color.white, Color.white.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: controlWidth/2 + 4, height: controlHeight - 6)
                        .offset(x: (controlWidth/2 - 2) * (selectedTheme == .dark ? 1 : 0))
                        .animation(Theme.Animation.smooth, value: selectedTheme)
                        .padding(3)
                    
                    HStack(spacing: 0) {
                        Button(action: { withAnimation { selectedTheme = .light; selectionIndex = 0 } }) {
                            HStack(spacing: 8) {
                                Image(systemName: "sun.max.fill")
                                Text("settings.theme.light".localized)
                            }
                            .foregroundColor(selectedTheme == .dark ? .white.opacity(0.7) : Theme.Colors.primary)
                            .frame(width: controlWidth/2, height: controlHeight)
                        }
                        Button(action: { withAnimation { selectedTheme = .dark; selectionIndex = 1 } }) {
                            HStack(spacing: 8) {
                                Image(systemName: "moon.fill")
                                Text("settings.theme.dark".localized)
                            }
                            .foregroundColor(selectedTheme == .dark ? .white : Theme.Colors.textSecondary)
                            .frame(width: controlWidth/2, height: controlHeight)
                        }
                    }
                    .font(Theme.Typography.subheadline)
                }
                
                // Preview cards
                HStack(spacing: Theme.Spacing.md) {
                    ThemePreviewCard(isDark: false, isSelected: selectedTheme == .light)
                        .onTapGesture { withAnimation { selectedTheme = .light } }
                    ThemePreviewCard(isDark: true, isSelected: selectedTheme == .dark)
                        .onTapGesture { withAnimation { selectedTheme = .dark } }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                
                Spacer()
                Spacer()
            }
            .padding(.top, Theme.Spacing.xl)
        }
        .onChange(of: selectionIndex) { _, _ in UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }
}

private struct ThemePreviewCard: View {
    let isDark: Bool
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 10).fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)).frame(height: 10)
            RoundedRectangle(cornerRadius: 6).fill(isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.08)).frame(height: 6)
            HStack(spacing: 6) {
                Circle().fill(isDark ? Color.green.opacity(0.7) : Theme.Colors.accentTurquoise).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 4).fill(isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.08)).frame(height: 6)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 150, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isDark ? Color(red: 0.08, green: 0.08, blue: 0.14) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? LinearGradient(colors: [Theme.Colors.primary, Theme.Colors.accent], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.black.opacity(0.06)], startPoint: .leading, endPoint: .trailing), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(isDark ? 0.4 : 0.1), radius: 12, x: 0, y: 8)
    }
}

// MARK: - Onboarding Page Model

private struct OnboardingV2Page: Identifiable {
    let id: Int
    let icon: String
    let gradient: LinearGradient
    let titleKey: String
    let subtitleKey: String
}

// MARK: - Onboarding Page View

private struct OnboardingV2PageView: View {
    let page: OnboardingV2Page
    
    @State private var animateIcon = false
    @State private var animateText = false
    
    var body: some View {
        ZStack {
            // Full-screen background - winter or regular gradient
            if WinterTheme.isActive {
                // Winter night background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.25),
                        Color(red: 0.1, green: 0.15, blue: 0.35),
                        Color(red: 0.08, green: 0.12, blue: 0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Northern lights hint
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.15),
                        Color.green.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 40)
                .ignoresSafeArea()
                
                // Snowfall
                SnowfallView(particleCount: 15, speed: 0.5)
                    .ignoresSafeArea()
            } else {
                page.gradient
                    .ignoresSafeArea()
                
                // Subtle animated particles
                FloatingParticlesOverlayV2()
                    .opacity(0.2)
            }
            
            // Content
            VStack(spacing: Theme.Spacing.xxl) {
                Spacer()
                
                // Large icon with winter decorations
                ZStack {
                    Circle()
                        .fill(WinterTheme.isActive ? Color.cyan.opacity(0.15) : Color.white.opacity(0.2))
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                    
                    // Winter frost ring
                    if WinterTheme.isActive {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.4), Color.white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 150, height: 150)
                    }
                    
                    Image(systemName: page.icon)
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundColor(.white)
                        .scaleEffect(animateIcon ? 1.0 : 0.5)
                        .opacity(animateIcon ? 1.0 : 0.0)
                    
                    // Corner snowflakes
                    if WinterTheme.isActive {
                        Text("❄️")
                            .font(.system(size: 20))
                            .opacity(0.7)
                            .offset(x: 65, y: -55)
                        
                        Text("✨")
                            .font(.system(size: 16))
                            .opacity(0.6)
                            .offset(x: -60, y: 50)
                    }
                }
                
                // Text content
                VStack(spacing: Theme.Spacing.md) {
                    // Winter greeting on first page
                    if WinterTheme.isActive && page.id == 1 {
                        Text(WinterTheme.isPostNewYear ? "🎄 З Новим Роком!" : "🎄 Святкова зима разом із Sweezy")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.cyan)
                            .padding(.bottom, 4)
                    }
                    
                    Text(LocalizedStringKey(page.titleKey))
                        .font(Theme.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .opacity(animateText ? 1.0 : 0.0)
                        .offset(y: animateText ? 0 : 20)
                    
                    Text(LocalizedStringKey(page.subtitleKey))
                        .font(Theme.Typography.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .opacity(animateText ? 1.0 : 0.0)
                        .offset(y: animateText ? 0 : 20)
                }
                .accessibilityIdentifier("onboarding.page.title.\(page.id)")
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(Theme.Animation.bounce.delay(0.2)) {
                animateIcon = true
            }
            withAnimation(Theme.Animation.smooth.delay(0.5)) {
                animateText = true
            }
        }
    }
}

// MARK: - Language Selection Sheet

private struct LanguageSelectionSheetV2: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss
    
    private let languages: [(code: String, name: String, flag: String)] = [
        ("uk", "Українська", "🇺🇦"),
        ("en", "English", "🇬🇧"),
        ("de", "Deutsch", "🇩🇪")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.primaryBackground.ignoresSafeArea()
                
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "globe")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.Colors.gradientPrimaryAdaptive)
                        
                        Text(LocalizedStringKey("onboarding.select_language"))
                            .font(Theme.Typography.title1)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .padding(.top, Theme.Spacing.xl)
                    
                    // Language options
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(languages, id: \.code) { language in
                            LanguageOptionButtonV2(
                                flag: language.flag,
                                name: language.name,
                                code: language.code,
                                isSelected: selectedLanguage == language.code
                            ) {
                                selectedLanguage = language.code
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Language Picker Page (inline onboarding)

private struct LanguagePickerPage: View {
    @Binding var selectedLanguage: String
    var onSelect: (String) -> Void
    
    private let languages: [(code: String, name: String, flag: String)] = [
        ("uk", "Українська", "🇺🇦"),
        ("en", "English", "🇬🇧"),
        ("de", "Deutsch", "🇩🇪")
    ]
    
    var body: some View {
        ZStack {
            // Background - winter or regular
            if WinterTheme.isActive {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.25),
                        Color(red: 0.1, green: 0.15, blue: 0.35),
                        Color(red: 0.08, green: 0.12, blue: 0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Northern lights
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.12),
                        Color.green.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 40)
                .ignoresSafeArea()
                
                // Snowfall
                SnowfallView(particleCount: 15, speed: 0.5)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [Color(red: 0.14, green: 0.16, blue: 0.28), Color(red: 0.0, green: 0.6, blue: 0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .overlay(FloatingParticlesOverlayV2().opacity(0.15))
            }
            
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                
                // Winter emoji
                if WinterTheme.isActive {
                    Text("🎄")
                        .font(.system(size: 36))
                        .padding(.bottom, 8)
                }
                
                Text(LocalizedStringKey("onboarding.select_language"))
                    .font(Theme.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(languages, id: \.code) { language in
                        Button(action: {
                            selectedLanguage = language.code
                            onSelect(language.code)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }) {
                            HStack(spacing: Theme.Spacing.md) {
                                Text(language.flag).font(.system(size: 28))
                                Text(language.name)
                                    .font(Theme.Typography.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                if selectedLanguage == language.code {
                                    if WinterTheme.isActive {
                                        Text("❄️").font(.system(size: 20))
                                    } else {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                    .fill(
                                        WinterTheme.isActive && selectedLanguage == language.code
                                            ? Color.cyan.opacity(0.2)
                                            : Color.white.opacity(selectedLanguage == language.code ? 0.18 : 0.12)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                    .stroke(
                                        WinterTheme.isActive && selectedLanguage == language.code
                                            ? Color.cyan.opacity(0.5)
                                            : Color.white.opacity(selectedLanguage == language.code ? 0.35 : 0.2),
                                        lineWidth: selectedLanguage == language.code ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                
                Spacer()
                Spacer()
            }
            .padding(.top, Theme.Spacing.xl)
        }
    }
}

// MARK: - Success Page (last)

private struct SuccessPageView: View {
    var body: some View {
        ZStack {
            // Background - winter or regular
            if WinterTheme.isActive {
                // Winter celebration background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.25),
                        Color(red: 0.1, green: 0.15, blue: 0.35),
                        Color(red: 0.08, green: 0.12, blue: 0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Festive northern lights
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.15),
                        Color.green.opacity(0.1),
                        Color.yellow.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 40)
                .ignoresSafeArea()
                
                // Snowfall
                SnowfallView(particleCount: 20, speed: 0.5)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.8, blue: 0.2), Color(red: 1.0, green: 0.58, blue: 0.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(WinterTheme.isActive ? Color.cyan.opacity(0.2) : Color.white.opacity(0.25))
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                    
                    // Winter: Christmas tree, Regular: checkmark
                    if WinterTheme.isActive {
                        Text("🎄")
                            .font(.system(size: 80))
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 80, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Corner snowflakes
                    if WinterTheme.isActive {
                        Text("❄️")
                            .font(.system(size: 24))
                            .opacity(0.7)
                            .offset(x: 70, y: -60)
                        
                        Text("✨")
                            .font(.system(size: 20))
                            .opacity(0.6)
                            .offset(x: -65, y: 55)
                    }
                }
                
                // Title
                if WinterTheme.isActive {
                    Text(WinterTheme.isPostNewYear ? "🎉 З Новим Роком!" : "🎉 Святковий настрій разом із Sweezy")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.cyan)
                        .padding(.bottom, 4)
                }
                
                Text("onboarding.page3.title".localized)
                    .font(Theme.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("onboarding.page3.subtitle".localized)
                    .font(Theme.Typography.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer()
                Spacer()
            }
        }
    }
}

private struct LanguageOptionButtonV2: View {
    let flag: String
    let name: String
    let code: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }) {
            HStack(spacing: Theme.Spacing.md) {
                Text(flag)
                    .font(.system(size: 32))
                
                Text(name)
                    .font(Theme.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.Colors.gradientPrimaryAdaptive)
                        .accessibilityIdentifier("onboarding.language.selectedIcon")
                }
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Theme.Colors.glassMaterial) : AnyShapeStyle(Theme.Colors.glassMaterial.opacity(0.5)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .stroke(
                        isSelected
                            ? LinearGradient(
                                colors: [Theme.Colors.primary, Theme.Colors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .allowsHitTesting(false)
            )
            .themeShadow(isSelected ? Theme.Shadows.level2 : Theme.Shadows.level1)
        }
        .accessibilityIdentifier("onboarding.language.option.\(code)")
    }
}

// MARK: - Floating Particles Overlay

private struct FloatingParticlesOverlayV2: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: CGFloat.random(in: 15...40))
                    .offset(
                        x: CGFloat.random(in: -200...200),
                        y: animate ? -UIScreen.main.bounds.height : UIScreen.main.bounds.height
                    )
                    .opacity(0.3)
                    .animation(
                        Animation.linear(duration: Double.random(in: 10...20))
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

// MARK: - Preview

#Preview("Onboarding Redesigned") {
    OnboardingViewRedesigned()
        .environmentObject(ThemeManager())
}

#Preview("Onboarding Dark") {
    OnboardingViewRedesigned()
        .environmentObject(ThemeManager())
        .preferredColorScheme(.dark)
}

