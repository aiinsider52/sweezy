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
    @State private var selectedCountry: ResidenceCountry = .switzerland
    @State private var selectedSubdivisionCode = ResidenceCountry.switzerland.defaultSubdivisionCode
    @State private var selectedResidenceStatusCode = ResidenceCountry.switzerland.defaultResidenceStatusCode
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
                        selectedCountry: $selectedCountry,
                        selectedSubdivisionCode: $selectedSubdivisionCode,
                        selectedResidenceStatusCode: $selectedResidenceStatusCode,
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
                    AnalyticsConsentPage(onDecision: goNext)
                        .tag(6)
                    // Notification permission page
                    NotificationPermissionPage(onNext: goNext)
                        .tag(7)
                    // Success page (last)
                    SuccessPageView()
                        .tag(totalPages - 1)
                }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            OnboardingMascotStage(page: currentPage)

            VStack {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(JourneyVisual.lime)
                            .frame(width: 9, height: 9)
                        Text("SWEEZY")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(JourneyVisual.primaryText)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Theme.Colors.card)
                    .background(.ultraThinMaterial.opacity(0.45))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))

                    Spacer()

                    if currentPage < totalPages - 1 {
                        Button(action: completeOnboarding) {
                            HStack(spacing: 7) {
                                Text(LocalizedStringKey("onboarding.skip"))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .padding(.horizontal, 15)
                            .frame(height: 38)
                            .background(Theme.Colors.card)
                            .background(.ultraThinMaterial.opacity(0.45))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
                        }
                        .accessibilityIdentifier("onboarding.skipButton")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .background(alignment: .top) {
                    // Scrolling form steps fade out under the brand bar instead of colliding with it.
                    LinearGradient(
                        colors: [JourneyVisual.pageBackground, JourneyVisual.pageBackground.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 96)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                }

                Spacer()
            }
            
            if currentPage != totalPages - 3 && currentPage != totalPages - 2 {
                VStack {
                    Spacer()

                    VStack(spacing: 13) {
                        OnboardingStepProgress(current: currentPage, total: totalPages)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Step \(currentPage + 1) of \(totalPages)")

                        HStack(spacing: 10) {
                            if currentPage > 0 {
                                Button(action: goBack) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(JourneyVisual.primaryText)
                                        .frame(width: 52, height: 52)
                                        .background(Theme.Colors.card)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
                                }
                                .accessibilityLabel(Text(LocalizedStringKey("common.back")))
                                .accessibilityIdentifier("onboarding.backButton")
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                            }

                            Button(action: goNext) {
                                HStack(spacing: 10) {
                                    Text(LocalizedStringKey(currentPage == totalPages - 1 ? "onboarding.get_started" : "common.next"))
                                        .id(currentPage == totalPages - 1)
                                        .transition(.push(from: .bottom).combined(with: .opacity))
                                    Image(systemName: currentPage == totalPages - 1 ? "sparkles" : "arrow.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .contentTransition(.symbolEffect(.replace))
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
                    .background(Theme.Colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
                    .shadow(color: .black.opacity(0.10), radius: 22, y: 10)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .animation(Theme.Animation.smooth, value: currentPage)
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
        if !AnalyticsConsentStore.hasDecision {
            appContainer.analytics.setEnabled(false)
        }
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
    
    private var totalPages: Int { introPages.count + 7 }
    
    private var languageDisplayName: String {
        switch preferredLanguage {
        case "uk": return "Українська".localized
        case "ru": return "Русский".localized
        case "en": return "English"
        case "de": return "Deutsch"
        default: return "Українська".localized
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
        selectedCountry = profile.country
        selectedSubdivisionCode = profile.administrativeAreaCode
        selectedResidenceStatusCode = profile.residenceStatusCode
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
            profile.country = selectedCountry
            profile.administrativeAreaCode = selectedSubdivisionCode
            profile.residenceStatusCode = selectedResidenceStatusCode
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
                "country": profile.country.rawValue,
                "subdivision": profile.administrativeAreaCode,
                "residence_status": profile.residenceStatusCode,
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

// MARK: - Analytics Consent Page

private struct AnalyticsConsentPage: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onDecision: () -> Void

    var body: some View {
        OnboardingDetailsBackground {
            VStack(alignment: .leading, spacing: 22) {
                Spacer().frame(height: 96)
                SweezyCompanion(pose: .guide, size: 104)
                    .idleFloat(enabled: !reduceMotion)
                Text("onboarding.analytics.title".localized)
                    .font(.system(size: 29, weight: .bold, design: .default))
                    .foregroundStyle(JourneyVisual.primaryText)
                Text("onboarding.analytics.body".localized)
                    .font(.system(size: 16))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .lineSpacing(4)

                Spacer()

                VStack(spacing: 12) {
                    Button("onboarding.analytics.allow".localized) {
                        appContainer.analytics.setEnabled(true)
                        appContainer.telemetry.track(
                            .analyticsConsentUpdated,
                            source: "onboarding",
                            meta: ["granted": "true"]
                        )
                        onDecision()
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("onboarding.analytics.allowButton")

                    Button("onboarding.analytics.decline".localized) {
                        appContainer.analytics.setEnabled(false)
                        onDecision()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .accessibilityIdentifier("onboarding.analytics.declineButton")
                }
                .padding(.bottom, 46)
            }
            .padding(.horizontal, 20)
        }
        // Contain keeps the page id from overriding the ids of its buttons.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.analyticsConsentPage")
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
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                        Text("onboarding.notifications_title".localized)
                            .font(.system(size: 29, weight: .bold, design: .default))
                            .foregroundColor(JourneyVisual.primaryText)
                        Text("onboarding.notifications_subtitle".localized)
                            .font(.system(size: 16))
                            .foregroundColor(JourneyVisual.secondaryText)
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
                                .foregroundStyle(JourneyVisual.secondaryText)
                        }
                        Text("onboarding.notifications.preview.title".localized)
                            .font(.system(size: 17, weight: .bold))
                        Text("onboarding.notifications.preview.body".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(JourneyVisual.secondaryText)
                            .lineSpacing(2)
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                            Text("onboarding.notifications.preview.action".localized)
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .foregroundStyle(JourneyVisual.primaryText)
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
                            .foregroundColor(JourneyVisual.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.notifications.laterButton")
                }
                .padding(14)
                .background(Theme.Colors.card)
                .background(.ultraThinMaterial.opacity(0.68))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
                // Keep both actions clear of the home indicator even though the
                // page background intentionally extends under the safe areas.
                .padding(.bottom, 42)
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
        // Contain keeps the page id from overriding the ids of its buttons.
        .accessibilityElement(children: .contain)
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
    @State private var revealed = false
    
    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: JourneyBackdrop.alpine.rawValue, blurRadius: 2, darkness: 0.62)
                .allowsHitTesting(false)
            OnboardingScrim(middle: 0.26, bottom: 0.96)
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 170)

                Text("onboarding.style.eyebrow".localized)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .onboardingReveal(revealed, order: 0)

                VStack(alignment: .leading, spacing: 7) {
                    Text("onboarding.choose_style.title".localized)
                        .font(.system(size: 29, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text("onboarding.choose_style.subtitle".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                }
                .padding(.top, 10)
                .onboardingReveal(revealed, order: 1)

                JourneyGlassPanel(cornerRadius: 26) {
                    VStack(spacing: 8) {
                        ForEach(AppTheme.allCases) { theme in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.74)) {
                                    selectedTheme = theme
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: theme.iconName)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(selectedTheme == theme ? .black : JourneyVisual.primaryText)
                                        .frame(width: 42, height: 42)
                                        .background(selectedTheme == theme ? JourneyVisual.lime : JourneyVisual.softSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(selectedTheme == theme ? Color.clear : JourneyVisual.softBorder, lineWidth: 1))
                                        .symbolEffect(.bounce, value: selectedTheme == theme)
                                    Text(theme.localizedName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(JourneyVisual.primaryText)
                                    Spacer()
                                    Image(systemName: selectedTheme == theme ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 21))
                                        .foregroundStyle(selectedTheme == theme ? JourneyVisual.accentStrong : JourneyVisual.softBorder)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                                .padding(.horizontal, 13)
                                .frame(height: 62)
                                .background(selectedTheme == theme ? JourneyVisual.softSurface : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .sensoryFeedback(.selection, trigger: selectedTheme == theme)
                            .accessibilityIdentifier("onboarding.theme.\(theme.rawValue)")
                        }
                    }
                    .padding(10)
                }
                .padding(.top, 24)
                .onboardingReveal(revealed, order: 2)

                HStack(spacing: Theme.Spacing.md) {
                    ThemePreviewCard(isDark: false, isSelected: selectedTheme == .light)
                        .onTapGesture { withAnimation { selectedTheme = .light } }
                    ThemePreviewCard(isDark: true, isSelected: selectedTheme == .dark)
                        .onTapGesture { withAnimation { selectedTheme = .dark } }
                }
                .padding(.top, 16)
                .onboardingReveal(revealed, order: 3)

                Spacer().frame(height: 154)
            }
            .padding(.horizontal, 20)
        }
        .onAppear { revealed = true }
        .onDisappear { revealed = false }
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
        .scaleEffect(isSelected ? 1.03 : 0.97)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isSelected)
    }
}

private struct ProfileDetailsPage: View {
    @Environment(\.locale) private var locale
    @Binding var selectedCountry: ResidenceCountry
    @Binding var selectedSubdivisionCode: String
    @Binding var selectedResidenceStatusCode: String
    @Binding var selectedCanton: Canton
    @Binding var selectedPermitType: PermitType
    @Binding var arrivalMonth: Int
    @Binding var arrivalYear: Int
    let onSkip: () -> Void

    private let months = Array(1...12)
    private var subdivisions: [AdministrativeArea] { CountryCatalog.subdivisions(for: selectedCountry) }
    private var residenceStatuses: [ResidenceStatusOption] { CountryCatalog.statuses(for: selectedCountry) }
    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 10)...(currentYear + 1)).reversed()
    }
    private var selectedStatus: ResidenceStatusOption? {
        residenceStatuses.first { $0.code == selectedResidenceStatusCode }
    }

    @State private var titleAppeared = false

    var body: some View {
        OnboardingDetailsBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Spacer().frame(height: 92)

                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(JourneyVisual.lime)
                                .frame(width: 48, height: 48)
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("onboarding.profile_title".localized)
                                .font(.system(size: 26, weight: .bold, design: .default))
                                .foregroundColor(JourneyVisual.primaryText)
                            Text("onboarding.profile.subtitle_short".localized)
                                .font(.system(size: 14))
                                .foregroundColor(JourneyVisual.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .onboardingReveal(titleAppeared, order: 0)

                    // One settings-style card: four taps instead of four cards and a long radio list.
                    VStack(spacing: 0) {
                        countryRow
                        rowDivider
                        subdivisionRow
                        rowDivider
                        statusRow
                        rowDivider
                        arrivalRow
                    }
                    .background(Theme.Colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(JourneyVisual.softBorder, lineWidth: 1)
                    )
                    .onboardingReveal(titleAppeared, order: 1)

                    Text("onboarding.profile.editable_hint".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .onboardingReveal(titleAppeared, order: 2)

                    Spacer().frame(height: 200)
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
        .onAppear { titleAppeared = true }
        .onDisappear { titleAppeared = false }
        .sensoryFeedback(.selection, trigger: selectedResidenceStatusCode)
        .accessibilityIdentifier("onboarding.profileDetailsPage")
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(JourneyVisual.softBorder)
            .frame(height: 1)
            .padding(.leading, 58)
    }

    private var countryRow: some View {
        Menu {
            ForEach(ResidenceCountry.allCases) { country in
                Button("\(country.flag) \(country.name)") { select(country) }
            }
        } label: {
            OnboardingSummaryRow(
                icon: "globe.europe.africa.fill",
                label: "country.residence_country".localized,
                value: "\(selectedCountry.flag) \(selectedCountry.name)"
            )
        }
        .accessibilityIdentifier("onboarding.profile.country")
    }

    private var subdivisionRow: some View {
        Menu {
            ForEach(subdivisions) { area in
                Button("\(area.name) (\(area.code))") {
                    selectedSubdivisionCode = area.code
                    if selectedCountry == .switzerland {
                        selectedCanton = Canton(rawValue: area.code) ?? .zurich
                    }
                }
            }
        } label: {
            OnboardingSummaryRow(
                icon: "mappin.and.ellipse",
                label: selectedCountry.subdivisionTitle,
                value: CountryCatalog.subdivisionName(country: selectedCountry, code: selectedSubdivisionCode)
            )
        }
        .accessibilityIdentifier("onboarding.profile.subdivision")
    }

    private var statusRow: some View {
        Menu {
            ForEach(residenceStatuses) { status in
                Button("\(status.title) · \(status.detail)") {
                    selectedResidenceStatusCode = status.code
                    if selectedCountry == .switzerland {
                        selectedPermitType = PermitType(rawValue: status.code) ?? .other
                    }
                }
            }
        } label: {
            OnboardingSummaryRow(
                icon: "doc.badge.gearshape",
                label: "country.residence_status".localized,
                value: selectedStatus?.title ?? selectedResidenceStatusCode,
                detail: selectedStatus?.detail
            )
        }
        .accessibilityIdentifier("onboarding.profile.status")
    }

    private var arrivalRow: some View {
        HStack(spacing: 12) {
            OnboardingRowIcon(icon: "calendar")

            VStack(alignment: .leading, spacing: 6) {
                Text("onboarding.arrival_date".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText)

                HStack(spacing: 8) {
                    Menu {
                        ForEach(months, id: \.self) { month in
                            Button(monthName(for: month)) { arrivalMonth = month }
                        }
                    } label: {
                        valuePill(monthName(for: arrivalMonth))
                    }
                    .accessibilityIdentifier("onboarding.profile.arrivalMonth")

                    Menu {
                        ForEach(years, id: \.self) { year in
                            Button(String(year)) { arrivalYear = year }
                        }
                    } label: {
                        valuePill(String(arrivalYear))
                    }
                    .accessibilityIdentifier("onboarding.profile.arrivalYear")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func valuePill(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(JourneyVisual.primaryText)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(JourneyVisual.secondaryText)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(JourneyVisual.softSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
    }

    private func select(_ country: ResidenceCountry) {
        selectedCountry = country
        selectedSubdivisionCode = country.defaultSubdivisionCode
        selectedResidenceStatusCode = country.defaultResidenceStatusCode
        if country == .switzerland {
            selectedCanton = .zurich
            selectedPermitType = .s
        }
    }

    private func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
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
                                .font(.system(size: 28, weight: .bold, design: .default))
                                .foregroundColor(JourneyVisual.primaryText)
                            Text("onboarding.family_subtitle".localized)
                                .font(.system(size: 14))
                                .foregroundColor(JourneyVisual.secondaryText)
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
                                    .foregroundColor(JourneyVisual.primaryText)
                            }
                            .tint(JourneyVisual.accentText)
                        }
                        
                        if hasChildren {
                            OnboardingFieldCard(title: "onboarding.children_count".localized, icon: "number.circle", delay: 0.35) {
                                Stepper(value: $childrenCount, in: 1...5) {
                                    Text("\(childrenCount)")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(JourneyVisual.primaryText)
                                }
                                .tint(JourneyVisual.accentText)
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
                .allowsHitTesting(false)
            OnboardingScrim(top: 0.10, middle: 0.42, bottom: 0.96)

            RadialGradient(
                colors: [JourneyVisual.lime.opacity(0.11), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 360
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            content
        }
    }
}

/// Night scrim in dark mode; in light mode the illustration fades into paper so dark text stays readable.
private struct OnboardingScrim: View {
    @Environment(\.colorScheme) private var colorScheme
    var top: Double = 0
    let middle: Double
    let bottom: Double

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.black.opacity(top), Color.black.opacity(middle), Color.black.opacity(bottom)]
                : [.clear, JourneyVisual.pageBackground.opacity(0.7), JourneyVisual.pageBackground],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct OnboardingFieldCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
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
                        .foregroundColor(JourneyVisual.secondaryText)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundColor(JourneyVisual.secondaryText)
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
                        .fill(colorScheme == .dark ? Color.black.opacity(0.52) : Theme.Colors.card)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? LinearGradient(
                            colors: [Color.white.opacity(0.30), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [JourneyVisual.softBorder], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.06), radius: 18, y: 9)
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
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) { action() }
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.35) : JourneyVisual.softBorder), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(Theme.Colors.accent)
                            .frame(width: 24, height: 24)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .transition(.scale(scale: 0.2).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? (colorScheme == .dark ? Color.white.opacity(0.14) : JourneyVisual.softSurface) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Theme.Colors.accent.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
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
    @State private var revealed = false

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
                .allowsHitTesting(false)

            OnboardingScrim(middle: 0.18, bottom: 0.94)

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
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .onboardingReveal(revealed, order: 0)

                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizedStringKey(page.titleKey))
                        .font(.system(size: 29, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    
                    Text(LocalizedStringKey(page.subtitleKey))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                }
                .padding(.top, 18)
                .onboardingReveal(revealed, order: 1)
                .accessibilityIdentifier("onboarding.page.title.\(page.id)")

                JourneyGlassPanel(cornerRadius: 24) {
                    VStack(spacing: 0) {
                        ForEach(Array(featureRows.enumerated()), id: \.offset) { index, feature in
                            HStack(spacing: 13) {
                                Image(systemName: feature.0)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .frame(width: 24)
                                Text(feature.1)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(JourneyVisual.primaryText)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(JourneyVisual.secondaryText)
                            }
                            .frame(minHeight: 48)
                            .onboardingReveal(revealed, order: 3 + index)

                            if index < featureRows.count - 1 {
                                Divider().overlay(JourneyVisual.softBorder)
                            }
                        }
                    }
                    .padding(.horizontal, 17)
                    .padding(.vertical, 5)
                }
                .padding(.top, 24)
                .onboardingReveal(revealed, order: 2)

                Spacer().frame(height: 154)
            }
            .padding(.horizontal, 20)
        }
        .onAppear { revealed = true }
        .onDisappear { revealed = false }
    }
}

// MARK: - Language Selection Sheet

private struct LanguageSelectionSheetV2: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss
    
    private let languages: [(code: String, name: String, flag: String)] = [
        ("uk", "Українська".localized, "🇺🇦"),
        ("en", "English", "🇬🇧"),
        ("de", "Deutsch", "🇩🇪")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: JourneyBackdrop.city.rawValue, blurRadius: 6, darkness: 0.68)
                    .allowsHitTesting(false)
                
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
    @State private var revealed = false
    
    private let languages: [(code: String, name: String, shortCode: String)] = [
        ("uk", "Українська".localized, "UA"),
        ("en", "English", "EN"),
        ("de", "Deutsch", "DE")
    ]
    
    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: JourneyBackdrop.city.rawValue, blurRadius: 2, darkness: 0.56)
                .allowsHitTesting(false)
            OnboardingScrim(middle: 0.22, bottom: 0.94)
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 180)

                Text("onboarding.language.eyebrow".localized)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .onboardingReveal(revealed, order: 0)

                Text(LocalizedStringKey("onboarding.select_language"))
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .padding(.top, 10)
                    .onboardingReveal(revealed, order: 1)

                Text("onboarding.language.subtitle".localized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .padding(.top, 8)
                    .onboardingReveal(revealed, order: 2)

                JourneyGlassPanel(cornerRadius: 26) {
                    VStack(spacing: 8) {
                        ForEach(languages, id: \.code) { language in
                            let isSelected = selectedLanguage == language.code
                            Button(action: {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                                    selectedLanguage = language.code
                                }
                                onSelect(language.code)
                            }) {
                                HStack(spacing: 14) {
                                    Text(language.shortCode)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(isSelected ? .black : JourneyVisual.primaryText)
                                        .frame(width: 42, height: 42)
                                        .background(isSelected ? JourneyVisual.lime : JourneyVisual.softSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(isSelected ? Color.clear : JourneyVisual.softBorder, lineWidth: 1))
                                        .scaleEffect(isSelected ? 1.06 : 1)

                                Text(language.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(JourneyVisual.primaryText)
                                Spacer()
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 21, weight: .medium))
                                        .foregroundStyle(isSelected ? JourneyVisual.accentStrong : JourneyVisual.softBorder)
                                        .contentTransition(.symbolEffect(.replace))
                                        .symbolEffect(.bounce, value: isSelected)
                            }
                                .padding(.horizontal, 13)
                                .frame(height: 62)
                                .background(isSelected ? JourneyVisual.softSurface : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .sensoryFeedback(.selection, trigger: isSelected)
                            .accessibilityIdentifier("onboarding.language.option.\(language.code)")
                        }
                    }
                    .padding(10)
                }
                .padding(.top, 24)
                .onboardingReveal(revealed, order: 3)

                Spacer().frame(height: 158)
            }
            .padding(.horizontal, 20)
        }
        .onAppear { revealed = true }
        .onDisappear { revealed = false }
    }
}

// MARK: - Success Page (last)

private struct SuccessPageView: View {
    private enum Phase { case building, ready }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .building
    @State private var checkedCount = 0
    @State private var confetti = 0
    @State private var revealed = false

    private let features: [(icon: String, title: String)] = [
        ("book.fill", "onboarding.success.feature1".localized),
        ("checklist", "onboarding.success.feature2".localized),
        ("storefront.fill", "onboarding.success.feature3".localized)
    ]

    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: JourneyBackdrop.zurich.rawValue, blurRadius: 2, darkness: 0.58)
                .allowsHitTesting(false)
            OnboardingScrim(middle: 0.32, bottom: 0.96)

            VStack(spacing: 0) {
                Spacer().frame(height: 104)

                ZStack {
                    Circle()
                        .fill(JourneyVisual.lime.opacity(phase == .ready ? 0.3 : 0.18))
                        .frame(width: 210, height: 210)
                        .blur(radius: 34)

                    Image((phase == .ready ? SweezyCompanionPose.celebrate : .documents).assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 172, height: 172)
                        .id(phase)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .scale(scale: 0.62, anchor: .bottom).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                )
                        )
                }
                .frame(height: 212)
                .idleFloat(enabled: !reduceMotion && phase == .building)
                .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.66), value: phase)

                VStack(spacing: 10) {
                    Text((phase == .ready ? "onboarding.ready.title" : "onboarding.building.title").localized)
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)

                    Text((phase == .ready ? "onboarding.ready.subtitle" : "onboarding.building.subtitle").localized)
                        .font(.system(size: 16))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 36)
                        .contentTransition(.opacity)
                }
                .padding(.top, 6)
                .padding(.bottom, 28)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: phase)

                VStack(spacing: 10) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        planRow(index: index, icon: feature.icon, title: feature.title)
                            .onboardingReveal(revealed, order: index + 1)
                    }
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 152)
            }

            ConfettiBurst(trigger: confetti)
        }
        .onAppear { revealed = true }
        .onDisappear {
            revealed = false
            phase = .building
            checkedCount = 0
        }
        .task(id: revealed) {
            guard revealed else { return }
            await buildPlan()
        }
        .sensoryFeedback(.success, trigger: phase == .ready)
    }

    private func planRow(index: Int, icon: String, title: String) -> some View {
        let isChecked = index < checkedCount
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isChecked ? JourneyVisual.lime.opacity(0.22) : JourneyVisual.softBorder)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isChecked ? JourneyVisual.accentStrong : JourneyVisual.secondaryText)
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(JourneyVisual.primaryText)

            Spacer()

            if isChecked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 19))
                    .foregroundColor(JourneyVisual.accentStrong)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(JourneyVisual.accentStrong)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isChecked ? JourneyVisual.accentStrong.opacity(0.35) : JourneyVisual.softBorder, lineWidth: 1)
        )
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74), value: isChecked)
    }

    /// Short "we are preparing your plan" beat, then the celebration.
    private func buildPlan() async {
        guard !reduceMotion else {
            checkedCount = features.count
            phase = .ready
            return
        }
        try? await Task.sleep(for: .milliseconds(420))
        for step in 1...features.count {
            guard !Task.isCancelled else { return }
            checkedCount = step
            try? await Task.sleep(for: .milliseconds(430))
        }
        guard !Task.isCancelled else { return }
        try? await Task.sleep(for: .milliseconds(220))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            phase = .ready
        }
        confetti += 1
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
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<20, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: CGFloat.random(in: 15...40))
                        .offset(
                            x: CGFloat.random(in: -200...200),
                            y: animate ? -geometry.size.height : geometry.size.height
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
