//
//  OnboardingViewRedesigned.swift
//  sweezy
//
//  Bold GoIT-inspired full-screen hero onboarding
//

import SwiftUI
import UserNotifications

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
    
    private let introPages: [OnboardingV2Page] = [
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
            TabView(selection: $currentPage) {
                    OnboardingV2PageView(page: introPages[0])
                        .tag(0)
                    // Language picker page
                    LanguagePickerPage(selectedLanguage: $preferredLanguage) { code in
                        preferredLanguage = code
                        appContainer.updateLocale(Locale(identifier: code))
                    }
                    .tag(1)
                    OnboardingV2PageView(page: introPages[1])
                        .tag(2)
                    ProfileDetailsPage(
                        selectedCanton: $selectedCanton,
                        selectedPermitType: $selectedPermitType,
                        arrivalMonth: $arrivalMonth,
                        arrivalYear: $arrivalYear,
                        onSkip: skipAboutStep
                    )
                    .tag(3)
                    FamilyDetailsPage(
                        hasChildren: $hasChildren,
                        childrenCount: $childrenCount,
                        familyStatus: $familyStatus,
                        onSkip: skipFamilyStep
                    )
                    .tag(4)
                    // Theme picker page
                    ThemePickerPage(selectedTheme: $themeManager.selectedTheme)
                        .tag(5)
                    // Notification permission page
                    NotificationPermissionPage(onNext: goNext)
                        .tag(6)
                    // Success page (last)
                    SuccessPageView()
                        .tag(totalPages - 1)
                }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(JourneyVisual.lime)
                            .frame(width: 9, height: 9)
                        Text("SWEEZY")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Color.black.opacity(0.46))
                    .background(.ultraThinMaterial.opacity(0.45))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))

                    Spacer()

                    if currentPage < totalPages - 1 {
                        Button(action: completeOnboarding) {
                            HStack(spacing: 7) {
                                Text(LocalizedStringKey("onboarding.skip"))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 15)
                            .frame(height: 38)
                            .background(Color.black.opacity(0.46))
                            .background(.ultraThinMaterial.opacity(0.45))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        }
                        .accessibilityIdentifier("onboarding.skipButton")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                
                Spacer()
            }
            
            if currentPage != totalPages - 2 {
                VStack {
                    Spacer()

                    VStack(spacing: 13) {
                        HStack(spacing: 10) {
                            Text(String(format: "%d / %d", currentPage + 1, totalPages))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.64))
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.14))
                                    Capsule()
                                        .fill(JourneyVisual.lime)
                                        .frame(width: geometry.size.width * CGFloat(currentPage + 1) / CGFloat(totalPages))
                                }
                            }
                            .frame(height: 4)
                        }
                        .accessibilityLabel("Step \(currentPage + 1) of \(totalPages)")

                        HStack(spacing: 10) {
                            if currentPage > 0 {
                                Button(action: goBack) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 52, height: 52)
                                        .background(Color.white.opacity(0.09))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                }
                                .accessibilityLabel(Text(LocalizedStringKey("common.back")))
                                .accessibilityIdentifier("onboarding.backButton")
                            }

                            Button(action: goNext) {
                                HStack(spacing: 10) {
                                    Text(LocalizedStringKey(currentPage == totalPages - 1 ? "onboarding.get_started" : "common.next"))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(JourneyVisual.lime)
                                .clipShape(Capsule())
                                .shadow(color: JourneyVisual.lime.opacity(0.22), radius: 18, y: 8)
                            }
                            .accessibilityIdentifier(currentPage == totalPages - 1 ? "onboarding.getStartedButton" : "onboarding.nextButton")
                        }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial.opacity(0.78))
                    .background(Color.black.opacity(0.60))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: .black.opacity(0.42), radius: 24, y: 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .animation(Theme.Animation.smooth, value: currentPage)
        .preferredColorScheme(.dark)
        .onAppear {
            seedProfileStateIfNeeded()
            syncAppLocaleWithPreferredLanguage()
        }
        .onChange(of: preferredLanguage) { _, _ in
            syncAppLocaleWithPreferredLanguage()
        }
        .sheet(isPresented: $showLanguageSelection) {
            LanguageSelectionSheetV2(selectedLanguage: $preferredLanguage)
        }
    }
    
    // MARK: - Actions
    
    private func goNext() {
        if currentPage < totalPages - 1 {
            appContainer.analytics.track("onboarding_step_completed", properties: ["step": currentPage])
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
        appContainer.analytics.track("onboarding_completed", properties: [
            "skipped_profile": skippedAboutStep,
            "skipped_family": skippedFamilyStep
        ])
        persistOnboardingProfile()
        withAnimation(Theme.Animation.smooth) {
            appContainer.completeOnboarding()
        }
        scheduleRetentionReminders()
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
    
    private var totalPages: Int { introPages.count + 6 }
    
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

    private func syncAppLocaleWithPreferredLanguage() {
        let selectedCode = preferredLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCode = selectedCode.isEmpty ? "uk" : selectedCode
        if appContainer.currentLocale.identifier != resolvedCode {
            appContainer.updateLocale(Locale(identifier: resolvedCode))
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
        let seededLevel = RoadmapService().seedFromOnboardingProfile(
            profile,
            firstWeekProgress: appContainer.firstWeekService.progress
        )
        appContainer.telemetry.retention(
            .roadmapSeeded,
            source: "onboarding",
            meta: ["level": String(seededLevel)]
        )
        appContainer.telemetry.retention(
            .onboardingProfileSaved,
            source: "onboarding",
            meta: [
                "canton": profile.canton.rawValue,
                "permit": profile.permitType.rawValue,
                "has_children": String(profile.hasChildren),
                "roadmap_level": String(seededLevel)
            ]
        )
        EventBus.shared.emit(GamEvent(
            type: .profileCompleted,
            metadata: [
                "entityId": "onboarding_profile",
                "title": "Profile completed"
            ]
        ))
    }

    private func scheduleRetentionReminders() {
        Task { @MainActor in
            let scheduledFirstWeek = await appContainer.firstWeekService.scheduleReminders(using: appContainer.notificationService)
            let scheduledReengage = await appContainer.notificationService.scheduleReengageReminder(afterDays: 3)
            appContainer.telemetry.retention(
                .firstWeekReminderScheduled,
                source: "onboarding",
                meta: [
                    "first_week": String(scheduledFirstWeek),
                    "reengage": String(scheduledReengage),
                    "tasks": String(appContainer.firstWeekService.tasks.count)
                ]
            )
        }
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

// MARK: - Notification Permission Page

private struct NotificationPermissionPage: View {
    @EnvironmentObject private var appContainer: AppContainer
    let onNext: () -> Void
    @State private var titleAppeared = false
    
    var body: some View {
        OnboardingDetailsBackground {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 118)

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(JourneyVisual.lime)
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    Text("onboarding.notifications.eyebrow".localized)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(JourneyVisual.lime)
                }

                VStack(alignment: .leading, spacing: 8) {
                        Text("onboarding.notifications_title".localized)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("onboarding.notifications_subtitle".localized)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.70))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                }
                .padding(.top, 18)

                JourneyGlassPanel(cornerRadius: 24) {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Sweezy")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Text("onboarding.notifications.preview.now".localized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.50))
                        }
                        Text("onboarding.notifications.preview.title".localized)
                            .font(.system(size: 17, weight: .bold))
                        Text("onboarding.notifications.preview.body".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineSpacing(2)
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                            Text("onboarding.notifications.preview.action".localized)
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(JourneyVisual.lime)
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                }
                .padding(.top, 26)

                Spacer(minLength: 22)

                VStack(spacing: 12) {
                    Button {
                        requestNotificationPermission()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("onboarding.notifications_allow".localized)
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())
                        .shadow(color: JourneyVisual.lime.opacity(0.20), radius: 18, y: 8)
                    }
                    .accessibilityIdentifier("onboarding.notifications.allowButton")
                    
                    Button {
                        onNext()
                    } label: {
                        Text("onboarding.notifications_later".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .accessibilityIdentifier("onboarding.notifications.laterButton")
                }
                .padding(14)
                .background(Color.black.opacity(0.48))
                .background(.ultraThinMaterial.opacity(0.68))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 20)
            .opacity(titleAppeared ? 1 : 0)
            .offset(y: titleAppeared ? 0 : 16)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                titleAppeared = true
            }
        }
        .accessibilityIdentifier("onboarding.notificationPermissionPage")
    }
    
    private func requestNotificationPermission() {
        Task { @MainActor in
            let granted = await appContainer.notificationService.requestPermission()
            NotificationPreference.isEnabled = granted
            appContainer.telemetry.retention(
                .notificationPermissionUpdated,
                source: "onboarding",
                meta: ["granted": String(granted)]
            )
            onNext()
        }
    }
}

// MARK: - Theme Picker Page

private struct ThemePickerPage: View {
    @Binding var selectedTheme: AppTheme
    
    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: JourneyBackdrop.alpine.rawValue, blurRadius: 2, darkness: 0.62)
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.26), Color.black.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 170)

                Text("onboarding.style.eyebrow".localized)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(JourneyVisual.lime)

                VStack(alignment: .leading, spacing: 7) {
                    Text("onboarding.choose_style.title".localized)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("onboarding.choose_style.subtitle".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.66))
                }
                .padding(.top, 10)

                JourneyGlassPanel(cornerRadius: 26) {
                    VStack(spacing: 8) {
                        ForEach(AppTheme.allCases) { theme in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedTheme = theme
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: theme.iconName)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(selectedTheme == theme ? .black : .white)
                                        .frame(width: 42, height: 42)
                                        .background(selectedTheme == theme ? JourneyVisual.lime : Color.white.opacity(0.09))
                                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    Text(theme.localizedName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: selectedTheme == theme ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 21))
                                        .foregroundStyle(selectedTheme == theme ? JourneyVisual.lime : .white.opacity(0.26))
                                }
                                .padding(.horizontal, 13)
                                .frame(height: 62)
                                .background(selectedTheme == theme ? Color.white.opacity(0.10) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("onboarding.theme.\(theme.rawValue)")
                        }
                    }
                    .padding(10)
                }
                .padding(.top, 24)

                HStack(spacing: Theme.Spacing.md) {
                    ThemePreviewCard(isDark: false, isSelected: selectedTheme == .light)
                        .onTapGesture { withAnimation { selectedTheme = .light } }
                    ThemePreviewCard(isDark: true, isSelected: selectedTheme == .dark)
                        .onTapGesture { withAnimation { selectedTheme = .dark } }
                }
                .padding(.top, 16)

                Spacer().frame(height: 154)
            }
            .padding(.horizontal, 20)
        }
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
    @Environment(\.locale) private var locale
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
                VStack(spacing: 14) {
                    Spacer().frame(height: 92)
                    
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(JourneyVisual.lime)
                                .frame(width: 54, height: 54)
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .opacity(titleAppeared ? 1 : 0)
                        .scaleEffect(titleAppeared ? 1 : 0.5)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("onboarding.profile_title".localized)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            Text("onboarding.profile_subtitle".localized)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                        }
                        .opacity(titleAppeared ? 1 : 0)
                        .offset(y: titleAppeared ? 0 : 15)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    
                    VStack(spacing: 12) {
                        OnboardingFieldCard(title: "onboarding.canton".localized, icon: "mappin.and.ellipse", delay: 0.15) {
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
                        
                        OnboardingFieldCard(title: "onboarding.permit_type".localized, icon: "doc.badge.gearshape", delay: 0.25) {
                            VStack(spacing: 4) {
                                ForEach(permitOptions, id: \.self) { permit in
                                    OnboardingChoiceRow(
                                        title: permitTitle(for: permit),
                                        subtitle: permitDescription(for: permit),
                                        isSelected: selectedPermitType == permit
                                    ) {
                                        selectedPermitType = permit
                                    }
                                }
                            }
                        }
                        
                        OnboardingFieldCard(title: "onboarding.arrival_date".localized, icon: "calendar", delay: 0.35) {
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

                    // Extra clearance for page indicator + bottom nav buttons
                    Spacer().frame(height: 220)
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
        formatter.locale = locale
        return formatter.monthSymbols[month - 1]
    }

    private func permitTitle(for permit: PermitType) -> String {
        "onboarding.permit.\(permit.rawValue.lowercased()).title".localized
    }

    private func permitDescription(for permit: PermitType) -> String {
        "onboarding.permit.\(permit.rawValue.lowercased()).description".localized
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
                VStack(spacing: 14) {
                    Spacer().frame(height: 92)
                    
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(JourneyVisual.lime)
                                .frame(width: 54, height: 54)
                            Image(systemName: "figure.2.and.child.holdinghands")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .opacity(titleAppeared ? 1 : 0)
                        .scaleEffect(titleAppeared ? 1 : 0.5)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("onboarding.family_title".localized)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("onboarding.family_subtitle".localized)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                        }
                        .opacity(titleAppeared ? 1 : 0)
                        .offset(y: titleAppeared ? 0 : 15)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    
                    VStack(spacing: 12) {
                        OnboardingFieldCard(title: "onboarding.family_status".localized, icon: "heart.circle", delay: 0.15) {
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
                        
                        OnboardingFieldCard(title: "onboarding.has_children".localized, icon: "figure.and.child.holdinghands", delay: 0.25) {
                            Toggle(isOn: $hasChildren) {
                                Text(hasChildren ? "onboarding.yes".localized : "onboarding.no".localized)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .tint(Theme.Colors.accent)
                        }
                        
                        if hasChildren {
                            OnboardingFieldCard(title: "onboarding.children_count".localized, icon: "number.circle", delay: 0.35) {
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

                    // Extra clearance for page indicator + bottom nav buttons
                    Spacer().frame(height: 220)
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
            JourneyPhotoBackground(imageName: JourneyBackdrop.alpine.rawValue, blurRadius: 2, darkness: 0.64)
            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [JourneyVisual.lime.opacity(0.11), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 360
            )
            .ignoresSafeArea()

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
        VStack(alignment: .leading, spacing: 10) {
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.72))
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.52))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.30), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.32), radius: 18, y: 9)
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
            .padding(.vertical, 10)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateIcon = false
    @State private var animateText = false

    private var backdrop: JourneyBackdrop {
        page.id == 1 ? .city : .alpine
    }

    private var featureRows: [(String, String)] {
        if page.id == 1 {
            return [
                ("checkmark.circle.fill", "onboarding.page1.feature1".localized),
                ("building.columns.fill", "onboarding.page1.feature2".localized),
                ("person.2.fill", "onboarding.page1.feature3".localized)
            ]
        }
        return [
            ("list.bullet.clipboard.fill", "onboarding.page2.feature1".localized),
            ("clock.badge.exclamationmark.fill", "onboarding.page2.feature2".localized),
            ("map.fill", "onboarding.page2.feature3".localized)
        ]
    }
    
    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: backdrop.rawValue, blurRadius: 1.5, darkness: 0.46)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.18), Color.black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 190)

                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(JourneyVisual.lime)
                            .frame(width: 46, height: 46)
                    Image(systemName: page.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                    }
                    Text("onboarding.hero.eyebrow".localized)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(JourneyVisual.lime)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizedStringKey(page.titleKey))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    
                    Text(LocalizedStringKey(page.subtitleKey))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                }
                .padding(.top, 18)
                .accessibilityIdentifier("onboarding.page.title.\(page.id)")

                JourneyGlassPanel(cornerRadius: 24) {
                    VStack(spacing: 0) {
                        ForEach(Array(featureRows.enumerated()), id: \.offset) { index, feature in
                            HStack(spacing: 13) {
                                Image(systemName: feature.0)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(JourneyVisual.lime)
                                    .frame(width: 24)
                                Text(feature.1)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .frame(minHeight: 48)

                            if index < featureRows.count - 1 {
                                Divider().overlay(Color.white.opacity(0.10))
                            }
                        }
                    }
                    .padding(.horizontal, 17)
                    .padding(.vertical, 5)
                }
                .padding(.top, 24)

                Spacer().frame(height: 154)
            }
            .padding(.horizontal, 20)
            .opacity(animateText ? 1 : 0)
            .offset(y: animateText ? 0 : 18)
        }
        .onAppear {
            animateIcon = true
            withAnimation(reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.86).delay(0.12)) {
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
                JourneyPhotoBackground(imageName: JourneyBackdrop.city.rawValue, blurRadius: 6, darkness: 0.68)
                
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
        .journeyScreen(.city, darkness: 0.68)
    }
}

// MARK: - Language Picker Page (inline onboarding)

private struct LanguagePickerPage: View {
    @Binding var selectedLanguage: String
    var onSelect: (String) -> Void
    
    private let languages: [(code: String, name: String, shortCode: String)] = [
        ("uk", "Українська", "UA"),
        ("en", "English", "EN"),
        ("de", "Deutsch", "DE")
    ]
    
    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: JourneyBackdrop.city.rawValue, blurRadius: 2, darkness: 0.56)
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.22), Color.black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 180)

                Text("onboarding.language.eyebrow".localized)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(JourneyVisual.lime)

                Text(LocalizedStringKey("onboarding.select_language"))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 10)

                Text("onboarding.language.subtitle".localized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .padding(.top, 8)

                JourneyGlassPanel(cornerRadius: 26) {
                    VStack(spacing: 8) {
                        ForEach(languages, id: \.code) { language in
                            Button(action: {
                                selectedLanguage = language.code
                                onSelect(language.code)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }) {
                                HStack(spacing: 14) {
                                    Text(language.shortCode)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(selectedLanguage == language.code ? .black : .white)
                                        .frame(width: 42, height: 42)
                                        .background(selectedLanguage == language.code ? JourneyVisual.lime : Color.white.opacity(0.09))
                                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                                Text(language.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                Spacer()
                                    Image(systemName: selectedLanguage == language.code ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 21, weight: .medium))
                                        .foregroundStyle(selectedLanguage == language.code ? JourneyVisual.lime : .white.opacity(0.28))
                            }
                                .padding(.horizontal, 13)
                                .frame(height: 62)
                                .background(selectedLanguage == language.code ? Color.white.opacity(0.10) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("onboarding.language.option.\(language.code)")
                        }
                    }
                    .padding(10)
                }
                .padding(.top, 24)

                Spacer().frame(height: 158)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Success Page (last)

private struct SuccessPageView: View {
    @State private var appeared = false
    @State private var glowPulse = false

    private let features: [(icon: String, title: String, color: Color)] = [
        ("book.fill", "onboarding.success.feature1".localized, JourneyVisual.lime),
        ("checklist", "onboarding.success.feature2".localized, JourneyVisual.lime),
        ("storefront.fill", "onboarding.success.feature3".localized, JourneyVisual.lime),
    ]

    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: JourneyBackdrop.zurich.rawValue, blurRadius: 2, darkness: 0.58)
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.32), Color.black.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Decorative background blobs
            Circle()
                .fill(JourneyVisual.lime.opacity(0.07))
                .frame(width: 320, height: 320)
                .offset(x: 120, y: -240)
            Circle()
                .fill(JourneyVisual.lime.opacity(0.04))
                .frame(width: 220, height: 220)
                .offset(x: -100, y: 280)

            VStack(spacing: 0) {
                Spacer().frame(height: 128)

                // Animated checkmark badge
                ZStack {
                    // Outer glow ring — pulses
                    Circle()
                        .fill(JourneyVisual.lime.opacity(0.08))
                        .frame(width: 190, height: 190)
                        .scaleEffect(glowPulse ? 1.12 : 0.95)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowPulse)

                    // Middle ring
                    Circle()
                        .fill(JourneyVisual.lime.opacity(0.14))
                        .frame(width: 150, height: 150)
                        .scaleEffect(appeared ? 1 : 0.3)
                        .animation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1), value: appeared)

                    // Inner solid circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [JourneyVisual.lime, JourneyVisual.lime.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .scaleEffect(appeared ? 1 : 0.2)
                        .animation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.05), value: appeared)

                    // Checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .scaleEffect(appeared ? 1 : 0.1)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.28), value: appeared)
                }
                .padding(.bottom, 28)

                // Title + subtitle
                VStack(spacing: 10) {
                    Text("onboarding.page3.title".localized)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 22)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.38), value: appeared)

                    Text("onboarding.page3.subtitle".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 36)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.46), value: appeared)
                }
                .padding(.bottom, 32)

                // Feature highlights
                VStack(spacing: 10) {
                    ForEach(Array(features.enumerated()), id: \.offset) { idx, feature in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(feature.color.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: feature.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text(feature.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .opacity(appeared ? 1 : 0)
                        .offset(x: appeared ? 0 : 32)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.56 + Double(idx) * 0.1), value: appeared)
                    }
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 152)
            }
        }
        .onAppear {
            withAnimation { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                glowPulse = true
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
