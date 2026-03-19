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
    @State private var selectedCanton: Canton = .zurich
    @State private var selectedPermitType: PermitType = .s
    @State private var arrivalMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var arrivalYear: Int = Calendar.current.component(.year, from: Date())
    @State private var hasChildren = false
    @State private var childrenCount = 1
    @State private var familyStatus: FamilyStatus? = nil
    @State private var skippedAboutStep = false
    @State private var skippedFamilyStep = false
    @State private var didSeedProfileState = false
    
    private let pages: [OnboardingV2Page] = [
        OnboardingV2Page(
            id: 1,
            icon: "hand.wave.fill",
            gradient: LinearGradient(
                colors: [Theme.Colors.primary, Theme.Colors.accentTurquoise],
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
                colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            titleKey: "onboarding.page2.title",
            subtitleKey: "onboarding.page2.subtitle"
        )
    ]
    
    var body: some View {
        ZStack {
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
                    ProfileDetailsPage(
                        selectedCanton: $selectedCanton,
                        selectedPermitType: $selectedPermitType,
                        arrivalMonth: $arrivalMonth,
                        arrivalYear: $arrivalYear,
                        onSkip: skipAboutStep
                    )
                    .tag(pages.count + 1)
                    FamilyDetailsPage(
                        hasChildren: $hasChildren,
                        childrenCount: $childrenCount,
                        familyStatus: $familyStatus,
                        onSkip: skipFamilyStep
                    )
                    .tag(pages.count + 2)
                    // Theme picker page (second to last)
                    ThemePickerPage(selectedTheme: $themeManager.selectedTheme)
                        .tag(pages.count + 3)
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
                
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(width: index == currentPage ? 32 : 8, height: 8)
                            .animation(Theme.Animation.smooth, value: currentPage)
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
        }
        .animation(Theme.Animation.smooth, value: currentPage)
        .onAppear {
            seedProfileStateIfNeeded()
        }
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
        persistOnboardingProfile()
        withAnimation(Theme.Animation.smooth) {
            appContainer.completeOnboarding()
        }
        triggerHapticFeedback(style: .medium)
    }
    
    private func skipAboutStep() {
        skippedAboutStep = true
        goNext()
    }
    
    private func skipFamilyStep() {
        skippedFamilyStep = true
        goNext()
    }
    
    private var totalPages: Int { pages.count + 5 }
    
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
    
    private func seedProfileStateIfNeeded() {
        guard !didSeedProfileState else { return }
        didSeedProfileState = true
        
        guard let profile = appContainer.userProfile else { return }
        selectedCanton = profile.canton
        selectedPermitType = profile.permitType
        preferredLanguage = profile.preferredLanguage
        
        if let arrivalDate = profile.arrivalDate {
            arrivalMonth = Calendar.current.component(.month, from: arrivalDate)
            arrivalYear = Calendar.current.component(.year, from: arrivalDate)
        }
        
        hasChildren = profile.hasChildren
        familyStatus = profile.familyStatus
        
        let adults = adultCount(for: profile.familyStatus)
        if profile.hasChildren {
            childrenCount = max(1, profile.familySize - adults)
        }
    }
    
    private func persistOnboardingProfile() {
        var profile = appContainer.userProfile ?? UserProfile()
        
        profile.preferredLanguage = preferredLanguage
        
        if !skippedAboutStep {
            profile.canton = selectedCanton
            profile.permitType = selectedPermitType
            profile.arrivalDate = resolvedArrivalDate
        }
        
        if !skippedFamilyStep {
            profile.hasChildren = hasChildren
            profile.familyStatus = familyStatus
            profile.familySize = resolvedFamilySize
        }
        
        appContainer.userProfile = profile
        appContainer.firstWeekService.generateTasks(for: profile)
    }
    
    private var resolvedArrivalDate: Date? {
        var components = DateComponents()
        components.year = arrivalYear
        components.month = arrivalMonth
        components.day = 1
        return Calendar.current.date(from: components)
    }
    
    private var resolvedFamilySize: Int {
        let adults = adultCount(for: familyStatus)
        return hasChildren ? adults + childrenCount : adults
    }
    
    private func adultCount(for status: FamilyStatus?) -> Int {
        switch status {
        case .married, .partner:
            return 2
        default:
            return 1
        }
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
            Group {
                if selectedTheme == .dark {
                    LinearGradient(
                        colors: [Theme.Colors.darkBackground, Theme.Colors.darkBackground.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Theme.Colors.gradientSoft
                }
            }
            .ignoresSafeArea()
            .overlay(FloatingParticlesOverlayV2().opacity(0.15))
            
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
                .fill(isDark ? Theme.Colors.darkBackground : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? LinearGradient(colors: [Theme.Colors.primary, Theme.Colors.accent], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.black.opacity(0.06)], startPoint: .leading, endPoint: .trailing), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(isDark ? 0.4 : 0.1), radius: 12, x: 0, y: 8)
    }
}

private struct ProfileDetailsPage: View {
    @Binding var selectedCanton: Canton
    @Binding var selectedPermitType: PermitType
    @Binding var arrivalMonth: Int
    @Binding var arrivalYear: Int
    let onSkip: () -> Void
    
    private let permitOptions: [PermitType] = [.b, .c, .s, .n, .other]
    private let months = Array(1...12)
    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 10)...(currentYear + 1)).reversed()
    }
    
    @State private var titleAppeared = false
    
    var body: some View {
        OnboardingDetailsBackground {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.lg) {
                    Spacer().frame(height: 20)
                    
                    // Hero icon + title
                    VStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 72, height: 72)
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.white)
                                .symbolEffect(.pulse, options: .repeating.speed(0.3))
                        }
                        .opacity(titleAppeared ? 1 : 0)
                        .scaleEffect(titleAppeared ? 1 : 0.5)
                        
                        VStack(spacing: 8) {
                            Text("Расскажи о себе")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text("Выбери кантон, тип разрешения и примерно\nукажи, когда ты приехал в Швейцарию.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .opacity(titleAppeared ? 1 : 0)
                        .offset(y: titleAppeared ? 0 : 15)
                    }
                    
                    VStack(spacing: 14) {
                        OnboardingFieldCard(title: "Кантон проживания", icon: "mappin.and.ellipse", delay: 0.15) {
                            Menu {
                                ForEach(Canton.allCases, id: \.self) { canton in
                                    Button(canton.localizedName) {
                                        selectedCanton = canton
                                    }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selectedCanton.localizedName)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(selectedCanton.rawValue)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        OnboardingFieldCard(title: "Тип разрешения", icon: "doc.badge.gearshape", delay: 0.25) {
                            VStack(spacing: 4) {
                                ForEach(permitOptions, id: \.self) { permit in
                                    OnboardingChoiceRow(
                                        title: permit.localizedName,
                                        subtitle: permit.description,
                                        isSelected: selectedPermitType == permit
                                    ) {
                                        selectedPermitType = permit
                                    }
                                }
                            }
                        }
                        
                        OnboardingFieldCard(title: "Дата приезда", icon: "calendar", delay: 0.35) {
                            HStack(spacing: 12) {
                                Picker("Month", selection: $arrivalMonth) {
                                    ForEach(months, id: \.self) { month in
                                        Text(monthName(for: month)).tag(month)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.white)
                                
                                Picker("Year", selection: $arrivalYear) {
                                    ForEach(years, id: \.self) { year in
                                        Text(String(year)).tag(year)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.white)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    
                    // Skip styled as pill
                    Button {
                        onSkip()
                    } label: {
                        Text("Пропустить")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .accessibilityIdentifier("onboarding.profile.skipButton")
                    
                    Spacer().frame(height: 12)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                titleAppeared = true
            }
        }
        .accessibilityIdentifier("onboarding.profileDetailsPage")
    }
    
    private func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.monthSymbols[month - 1]
    }
}

private struct FamilyDetailsPage: View {
    @Binding var hasChildren: Bool
    @Binding var childrenCount: Int
    @Binding var familyStatus: FamilyStatus?
    let onSkip: () -> Void
    @State private var titleAppeared = false
    
    var body: some View {
        OnboardingDetailsBackground {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.lg) {
                    Spacer().frame(height: 40)
                    
                    // Hero icon + title
                    VStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 72, height: 72)
                            Image(systemName: "figure.2.and.child.holdinghands")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(.white)
                                .symbolEffect(.pulse, options: .repeating.speed(0.3))
                        }
                        .opacity(titleAppeared ? 1 : 0)
                        .scaleEffect(titleAppeared ? 1 : 0.5)
                        
                        VStack(spacing: 8) {
                            Text("Твоя семья")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Этот шаг необязательный. Он поможет\nлучше подобрать стартовые задачи.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .opacity(titleAppeared ? 1 : 0)
                        .offset(y: titleAppeared ? 0 : 15)
                    }
                    
                    VStack(spacing: 14) {
                        OnboardingFieldCard(title: "Семейное положение", icon: "heart.circle", delay: 0.15) {
                            VStack(spacing: 4) {
                                ForEach(FamilyStatus.allCases) { status in
                                    OnboardingChoiceRow(
                                        title: status.localizedName,
                                        subtitle: nil,
                                        isSelected: familyStatus == status
                                    ) {
                                        familyStatus = status
                                    }
                                }
                            }
                        }
                        
                        OnboardingFieldCard(title: "Есть ли дети", icon: "figure.and.child.holdinghands", delay: 0.25) {
                            Toggle(isOn: $hasChildren) {
                                Text(hasChildren ? "Да" : "Нет")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .tint(Theme.Colors.accent)
                        }
                        
                        if hasChildren {
                            OnboardingFieldCard(title: "Количество детей", icon: "number.circle", delay: 0.35) {
                                Stepper(value: $childrenCount, in: 1...5) {
                                    Text("\(childrenCount)")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .tint(Theme.Colors.accent)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasChildren)
                    
                    // Skip styled as pill
                    Button {
                        onSkip()
                    } label: {
                        Text("Пропустить этот шаг")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .accessibilityIdentifier("onboarding.family.skipButton")
                    
                    Spacer().frame(height: 12)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                titleAppeared = true
            }
        }
        .accessibilityIdentifier("onboarding.familyDetailsPage")
    }
}

private struct OnboardingDetailsBackground<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.Colors.primaryDark,
                    Theme.Colors.primary,
                    Theme.Colors.accentTurquoise.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Radial glow accent
            RadialGradient(
                colors: [Theme.Colors.accent.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
            
            // Decorative background symbols
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 120, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.04))
                        .rotationEffect(.degrees(-8))
                        .offset(x: 40, y: -20)
                }
                Spacer()
                HStack {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 80, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.03))
                        .rotationEffect(.degrees(25))
                        .offset(x: -30, y: 20)
                    Spacer()
                }
            }
            .ignoresSafeArea()
            
            FloatingParticlesOverlayV2().opacity(0.1)
            
            content
        }
    }
}

private struct OnboardingFieldCard<Content: View>: View {
    let title: String
    let icon: String?
    let delay: Double
    @ViewBuilder let content: Content
    @State private var appeared = false
    
    init(title: String, icon: String? = nil, delay: Double = 0, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.delay = delay
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            content
        }
        .padding(Theme.Spacing.md + 2)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.45))
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                appeared = true
            }
        }
    }
}

private struct OnboardingChoiceRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(Theme.Colors.accent)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryDark)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Theme.Colors.accent.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            page.gradient
                .ignoresSafeArea()
            
            FloatingParticlesOverlayV2()
                .opacity(0.2)
            
            // Content
            VStack(spacing: Theme.Spacing.xxl) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                    
                    Image(systemName: page.icon)
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundColor(.white)
                        .scaleEffect(animateIcon ? 1.0 : 0.5)
                        .opacity(animateIcon ? 1.0 : 0.0)
                }
                
                // Text content
                VStack(spacing: Theme.Spacing.md) {
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
            LinearGradient(
                colors: [Theme.Colors.primary, Theme.Colors.accentTurquoise],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(FloatingParticlesOverlayV2().opacity(0.15))
            
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                
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
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                    .fill(Color.white.opacity(selectedLanguage == language.code ? 0.18 : 0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                    .stroke(
                                        Color.white.opacity(selectedLanguage == language.code ? 0.35 : 0.2),
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
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            Theme.Colors.gradientSunrise
                .ignoresSafeArea()
            
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 180, height: 180)
                        .blur(radius: 25)
                    
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.15))
                        .offset(x: -40, y: -30)
                        .rotationEffect(.degrees(appeared ? 15 : 0))
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.12))
                        .offset(x: 45, y: 25)
                        .rotationEffect(.degrees(appeared ? -10 : 0))
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundColor(.white)
                        .scaleEffect(appeared ? 1.0 : 0.7)
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
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
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

