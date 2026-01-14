//
//  OnboardingView.swift
//  sweezy
//
//  Collects basic profile info and generates the first-week checklist.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var canton: Canton = .zurich
    @State private var permit: PermitType = .s
    @State private var arrivalDate: Date = Date()
    @State private var permitExpiry: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var selectedGoals = Set<UserGoal>()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Вітаємо у Sweezy") {
                    TextField("Повне ім'я", text: $fullName)
                    TextField("Email", text: $email).keyboardType(.emailAddress)
                }
                Section("Регіон та статус") {
                    Picker("Кантон", selection: $canton) {
                        ForEach(Canton.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                    }
                    Picker("Дозвіл", selection: $permit) {
                        ForEach(PermitType.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                    }
                    DatePicker("Дата прибуття", selection: $arrivalDate, displayedComponents: .date)
                    DatePicker("Кінцевий термін дозволу", selection: $permitExpiry, displayedComponents: .date)
                }
                Section("Цілі") {
                    goalsGrid
                }
            }
            .navigationTitle("Налаштування профілю")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Пропустити") { completeOnboarding() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { completeOnboarding() }
                        .disabled(fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var goalsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(UserGoal.allCases) { goal in
                Button {
                    if selectedGoals.contains(goal) { selectedGoals.remove(goal) } else { selectedGoals.insert(goal) }
                } label: {
                    HStack {
                        Image(systemName: selectedGoals.contains(goal) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedGoals.contains(goal) ? .green : .secondary)
                        Text(goal.localizedName)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
                }
            }
        }
    }
    
    private func completeOnboarding() {
        var profile = appContainer.userProfile ?? UserProfile()
        profile.fullName = fullName.isEmpty ? profile.fullName : fullName
        if !email.isEmpty { profile.email = email }
        profile.canton = canton
        profile.permitType = permit
        profile.arrivalDate = arrivalDate
        profile.permitExpiryDate = permitExpiry
        profile.goals = Array(selectedGoals)
        appContainer.userProfile = profile
        
        // Generate first-week tasks and schedule reminders
        appContainer.firstWeekService.generateDefaultTasks(for: profile)
        Task {
            _ = await appContainer.notificationService.requestPermission()
            await appContainer.firstWeekService.scheduleReminders(using: appContainer.notificationService)
        }
        
        // Live Activities
        if let next = appContainer.firstWeekService.nextDueTask {
            LiveActivitiesManager.shared.updateNextTask(.init(title: next.title, dueDate: next.dueDate))
        }
        LiveActivitiesManager.shared.updatePermitDeadline(profile.permitExpiryDate)
        
        appContainer.completeOnboarding()
        dismiss()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppContainer())
}

//
//  OnboardingView.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI

struct IntroOnboardingView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @State private var showWinterGreeting = WinterTheme.isActive
    @State private var currentPage = 0
    @State private var showLanguageSelection = false
    
    private let pages = OnboardingPage.allPages
    
    var body: some View {
        ZStack {
            if showWinterGreeting {
                WinterGreetingScreen {
                    withAnimation(Theme.Animation.smooth) {
                        showWinterGreeting = false
                    }
                }
                .transition(.opacity)
            } else {
                // Background - winter or regular
                ZStack {
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
                        SnowfallView(particleCount: 20, speed: 0.6)
                            .ignoresSafeArea()
                    } else {
                        Theme.Colors.primaryGradient
                            .ignoresSafeArea()
                    }
                }
                
                if showLanguageSelection {
                    LanguageSelectionView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    onboardingContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
        }
        .animation(Theme.Animation.smooth, value: showLanguageSelection)
        .animation(Theme.Animation.smooth, value: showWinterGreeting)
    }
    
    private var onboardingContent: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button(LocalizationKeys.Onboarding.skip.localized) {
                    completeOnboarding()
                }
                .foregroundColor(.white.opacity(0.8))
                .padding()
                .accessibilityIdentifier("onboarding.skipButton")
            }
            
            // Page content
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index], index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Bottom section
            VStack(spacing: Theme.Spacing.lg) {
                // Page indicator - winter snowflakes or regular dots
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(pages.indices, id: \.self) { index in
                        if WinterTheme.isActive {
                            Text(index == currentPage ? "❄️" : "•")
                                .font(.system(size: index == currentPage ? 16 : 12))
                                .foregroundColor(index == currentPage ? Color.cyan : Color.white.opacity(0.4))
                                .scaleEffect(index == currentPage ? 1.1 : 1.0)
                                .animation(Theme.Animation.quick, value: currentPage)
                        } else {
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(Theme.Animation.quick, value: currentPage)
                        }
                    }
                }
                
                // Action buttons
                HStack(spacing: Theme.Spacing.md) {
                    if currentPage > 0 {
                        Button(LocalizationKeys.Common.back.localized) {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("onboarding.backButton")
                    }
                    
                    PrimaryButton(
                        currentPage == pages.count - 1 ? LocalizationKeys.Onboarding.getStarted.localized : LocalizationKeys.Common.next.localized,
                        style: .secondary
                    ) {
                        if currentPage == pages.count - 1 {
                            showLanguageSelection = true
                        } else {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(currentPage == pages.count - 1 ? "onboarding.getStartedButton" : "onboarding.nextButton")
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
    
    private func completeOnboarding() {
        withAnimation(Theme.Animation.smooth) {
            appContainer.completeOnboarding()
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let index: Int
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            
            // Animation placeholder with winter decorations
            ZStack {
                // Background circle with winter glow
                Circle()
                    .fill(
                        WinterTheme.isActive 
                            ? Color.cyan.opacity(0.15) 
                            : Color.white.opacity(0.1)
                    )
                    .frame(width: 200, height: 200)
                
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
                        .frame(width: 200, height: 200)
                }
                
                Image(systemName: page.iconName)
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.white)
                
                // Winter snowflake decorations
                if WinterTheme.isActive {
                    Text("❄️")
                        .font(.system(size: 24))
                        .opacity(0.8)
                        .offset(x: 80, y: -70)
                    
                    Text("✨")
                        .font(.system(size: 18))
                        .opacity(0.7)
                        .offset(x: -75, y: 65)
                }
            }
            .padding(.bottom, Theme.Spacing.lg)
            
            VStack(spacing: Theme.Spacing.md) {
                // Winter greeting prefix on first page
                if WinterTheme.isActive && index == 0 {
                    Text(WinterTheme.isPostNewYear ? "🎄 З Новим Роком!" : "🎄 Святкова зима разом із Sweezy")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.cyan)
                        .padding(.bottom, 4)
                }
                
                Text(page.title)
                    .font(Theme.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("onboarding.page.title.\(index + 1)")
                
                Text(page.subtitle)
                    .font(Theme.Typography.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .accessibilityIdentifier("onboarding.page.subtitle.\(index + 1)")
            }
            
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }
}

struct LanguageSelectionView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @State private var selectedLanguage: Language?
    
    private var languages: [Language] { appContainer.localizationService.availableLanguages }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            
            VStack(spacing: Theme.Spacing.lg) {
                // Winter greeting
                if WinterTheme.isActive {
                    Text("🎄")
                        .font(.system(size: 40))
                        .padding(.bottom, 8)
                }
                
                Text(LocalizationKeys.Onboarding.selectLanguage.localized)
                    .font(Theme.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(languages) { language in
                        LanguageOptionView(
                            language: language,
                            isSelected: selectedLanguage?.id == language.id
                        ) {
                            selectedLanguage = language
                        }
                        .accessibilityIdentifier("onboarding.language.option.\(language.code)")
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .accessibilityIdentifier("onboarding.language.container")
            }
            
            Spacer()
            
            PrimaryButton(
                LocalizationKeys.Onboarding.getStarted.localized,
                style: .secondary,
                isDisabled: selectedLanguage == nil
            ) {
                if let selectedLanguage = selectedLanguage {
                    appContainer.updateLocale(selectedLanguage.locale)
                }
                completeOnboarding()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
            .accessibilityIdentifier("onboarding.getStartedButton")
        }
        .onAppear {
            // Default to Ukrainian
            selectedLanguage = languages.first { $0.code == "uk" }
        }
    }
    
    private func completeOnboarding() {
        withAnimation(Theme.Animation.smooth) {
            appContainer.completeOnboarding()
        }
    }
}

struct LanguageOptionView: View {
    let language: Language
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Text(language.flag)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.nativeName)
                        .font(Theme.Typography.headline)
                        .foregroundColor(.white)
                    
                    Text(language.name)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                if isSelected {
                    if WinterTheme.isActive {
                        Text("❄️")
                            .font(.title2)
                            .accessibilityIdentifier("onboarding.language.selectedIcon")
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                            .accessibilityIdentifier("onboarding.language.selectedIcon")
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(
                        WinterTheme.isActive && isSelected 
                            ? Color.cyan.opacity(0.2) 
                            : .white.opacity(isSelected ? 0.2 : 0.1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(
                                WinterTheme.isActive && isSelected 
                                    ? Color.cyan.opacity(0.5) 
                                    : .white.opacity(0.3), 
                                lineWidth: WinterTheme.isActive && isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(Theme.Animation.quick, value: isSelected)
    }
}

// MARK: - Onboarding Data

struct OnboardingPage {
    let title: String
    let subtitle: String
    let iconName: String
    
    static let allPages = [
        OnboardingPage(
            title: "onboarding.title1".localized,
            subtitle: "onboarding.subtitle1".localized,
            iconName: "map"
        ),
        OnboardingPage(
            title: "onboarding.title2".localized,
            subtitle: "onboarding.subtitle2".localized,
            iconName: "person.crop.circle.badge.checkmark"
        ),
        OnboardingPage(
            title: "onboarding.title3".localized,
            subtitle: "onboarding.subtitle3".localized,
            iconName: "iphone"
        )
    ]
}

#Preview {
    IntroOnboardingView()
        .environmentObject(AppContainer())
}
