//
//  HomeViewRedesigned.swift
//  sweezy
//
//  Bold GoIT-inspired redesign with full-width hero and interactive sections
//

import SwiftUI

struct HomeViewRedesigned: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("lastSeenVersion") private var lastSeenVersion = ""
    @State private var showWhatsNewSheet = false
    @State private var showSettings = false
    @State private var showCVBuilder = false
    @State private var showTemplates = false
    @State private var showJobs = false
    @State private var showOnboarding = false
    @State private var selectedGuide: Guide?
    @State private var selectedNews: NewsItem?
    @State private var cachedFeaturedGuides: [Guide] = []
    
    // Live stats mirrors (lightweight, avoid deep dependencies)
    @State private var statXP: Int = 0
    @State private var statLevel: Int = 1
    @State private var statGuides: Int = 0
    @State private var statChecklists: Int = 0
    @State private var statTemplates: Int = 0
    @State private var statHoursSaved: Int = 0
    @State private var entitlements: APIClient.Entitlements?
    @State private var favoritesCount: Int = 0
    @State private var showSubscription = false
    @State private var selectedPlan: PaywallPlan = .yearly
    @State private var dismissedNewsIDs: Set<UUID> = []
    @State private var selectedJourneyStage: JourneyStage?
    // Forces lightweight refresh on day change / foreground to keep "today focus" accurate
    @State private var dayToken: Date = Date()
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Full hero with progress (full-bleed to the very top)
                        heroWithProgress(topInset: geo.safeAreaInsets.top)
                        
                        VStack(spacing: Theme.Spacing.xxl) {
                            // personalModulesSection + stats removed per design — мінімізуємо візуальний шум
                            journeyRoadmapSection
                            quickActionsSection
                            recommendationsSection
                            proCardSection
                            newsSection
                            telegramSection
                        }
                        .padding(.top, Theme.Spacing.xl)
                        .padding(.bottom, Theme.Spacing.xxxl)
                    }
                }
                // Allow hero background to extend behind the status bar
                .ignoresSafeArea(edges: .top)
                .background(
                    ZStack {
                        // Winter gradient background (always festive)
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.1, blue: 0.2),
                                Color(red: 0.08, green: 0.15, blue: 0.28),
                                Color(red: 0.06, green: 0.12, blue: 0.22)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                        
                        // Subtle snowfall
                        WinterSceneLite(intensity: .light)
                    }
                )
                .navigationBarHidden(true)
                .navigationDestination(item: $selectedGuide) { guide in
                    GuideDetailView(guide: guide)
                }
                .navigationDestination(item: $selectedNews) { news in
                    NewsDetailView(news: news)
                }
                .navigationDestination(isPresented: .constant(false)) { EmptyView() }
            }
        }
        .sheet(isPresented: $showWhatsNewSheet) {
            WhatsNewView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showCVBuilder) {
            CVBuilderView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
        }
        .sheet(isPresented: $showTemplates) {
            TemplatesView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
        }
        .onAppear {
            print("🏠 HomeViewRedesigned onAppear")
            // Defer heavy operations to not block UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                checkForWhatsNew()
                if !appContainer.isOnboardingCompleted {
                    showOnboarding = true
                }
            }
        }
        .task {
            // Delay background tasks to let UI render first
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec
            
            EventBus.shared.emit(GamEvent(type: .appDailyOpen))
            appContainer.analytics.track("daily_open", properties: ["entitlement": appContainer.subscriptionManager.isPremium ? "premium" : "free"])
            
            // Re-engage notification for free users (once), driven by RemoteConfig
            if appContainer.subscriptionManager.entitlement == .free {
                let key = "reengage_scheduled_v2"
                if !UserDefaults.standard.bool(forKey: key) {
                    let cfg = await appContainer.remoteConfigService.getRemoteConfig()
                    let days = cfg?.reengageDays ?? [7, 14, 30]
                    var scheduledAny = false
                    for d in days {
                        let ok = await appContainer.notificationService.scheduleReengageReminder(afterDays: d)
                        scheduledAny = scheduledAny || ok
                    }
                    if scheduledAny { UserDefaults.standard.set(true, forKey: key) }
                }
            }
            
            // Seed stats mirrors once UI is visible
            await MainActor.run {
                statXP = appContainer.gamification.totalXP
                statLevel = appContainer.gamification.level()
                statGuides = appContainer.userStats.guidesReadCount
                statChecklists = appContainer.userStats.activeChecklistsCount
                statTemplates = appContainer.contentService.templates.count
                statHoursSaved = max(0, appContainer.userStats.guidesReadCount * 2 + appContainer.userStats.activeChecklistsCount)
            }
        }
        .task {
            // Delay content refresh
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 sec
            if appContainer.contentService.news.isEmpty {
                await appContainer.contentService.refreshContent()
            }
        }
        .task {
            // Prime featured guides quickly with retries (non-blocking)
            for _ in 1...10 {
                let guides = appContainer.contentService.guides
                if !guides.isEmpty {
                    // Prefer top guide per key category, fallback to first items
                    let preferred = [GuideCategory.housing, .work, .integration, .documents, .healthcare, .education]
                        .compactMap { topGuide(for: $0) }
                    let fallback = preferred.isEmpty ? Array(guides.prefix(6)) : preferred
                    cachedFeaturedGuides = Array(fallback.prefix(6))
                    break
                }
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s
            }
        }
        // Live updates for stats with minimal overhead
        .onReceive(appContainer.gamification.$totalXP) { value in
            statXP = value
            statLevel = appContainer.gamification.level()
        }
        .onReceive(appContainer.userStats.$lastUpdated) { _ in
            statGuides = appContainer.userStats.guidesReadCount
            statChecklists = appContainer.userStats.activeChecklistsCount
            statHoursSaved = max(0, appContainer.userStats.guidesReadCount * 2 + appContainer.userStats.activeChecklistsCount)
        }
        // Recompute lightweight "todayFocus" on calendar day change
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            dayToken = Date()
        }
        // Also refresh when app returns to foreground
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                dayToken = Date()
            }
        }
        .task {
            // Delay API calls
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 sec
            async let entitlementsTask = APIClient.fetchEntitlements()
            async let favoritesTask = APIClient.listJobFavorites()
            entitlements = await entitlementsTask
            let favorites = await favoritesTask
            favoritesCount = favorites.count       
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(appContainer)
        }
        .fullScreenCover(isPresented: $showJobs) {
            JobsView()
                .environmentObject(appContainer)
        }
    }
    
    // MARK: - Simplified Hero (for debugging)
    private var simplifiedHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dynamicGreeting)
                .font(.title.bold())
                .foregroundColor(.primary)
            
            Text(lockManager.isRegistered
                ? "Вітаємо, \(lockManager.userName)! Продовжуйте ваш шлях"
                : "Ваш повний гід для успішного життя в Швейцарії")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Hero with embedded progress (Full Bleed Aurora)
    private func heroWithProgress(topInset: CGFloat) -> some View {
        let tasks = appContainer.firstWeekService.tasks.sorted(by: { $0.dueDate < $1.dueDate })
        let total = max(1, tasks.count)
        let done = tasks.filter { $0.isDone }.count
        let percent = total > 0 ? Int((Double(done) / Double(total)) * 100) : 0
        // Daily login streak: consecutive days user opens the app.
        // Зберігається в GamificationService, для нового користувача стартує з 0.
        let streak = appContainer.gamification.currentStreak()
        
        return FullBleedAuroraHero(
            greeting: dynamicGreeting,
            userName: lockManager.isRegistered ? lockManager.userName : "Друже",
            xp: statXP,
            level: statLevel,
            streak: min(streak, 999),
            integrationPercent: percent,
            topInset: topInset,
            onAvatarTap: {
                showSettings = true
            },
            onProgressTap: {
                NotificationCenter.default.post(name: .switchTab, object: 1)
            }
        )
    }
    
    // MARK: - Personal Focus (Week Strip)
    private var personalModulesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Ваш фокус")
            
            WeekStripFocusView(
                todayTasks: todayFocus,
                weekTasks: weekFocus,
                onDayTap: { _ in
                    // Можна показати sheet з задачами на цей день
                }
            )
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
    
    private var insiderSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            SectionHeader("Sweezy Insider")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(insiderMoments) { insight in
                        InsiderCard(moment: insight)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }
    
    private var journeyRoadmapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Roadmap інтеграції")
            
            // New Mountain Roadmap Preview Card
            NavigationLink {
                MountainRoadmapView()
                    .environmentObject(appContainer)
            } label: {
                MountainRoadmapPreviewCard()
                    .environmentObject(appContainer)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }
    
    // helper funcs removed (moved into IntegrationProgressCard)
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Используем явный текст, чтобы не зависеть от String.localized в этом файле
            SectionHeader("Швидкі дії")
            
            BentoQuickActionsExtended(
                featuredItem: bentoFeaturedQuickAction,
                primaryItems: bentoPrimaryQuickActions,
                secondaryItems: bentoSecondaryQuickActions
            )
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }
    
    private var bentoFeaturedQuickAction: BentoQuickActionItem {
        BentoQuickActionItem(
            icon: "briefcase.fill",
            title: LocalizedStringKey("Пошук роботи"),
            subtitle: LocalizedStringKey("RAV + Indeed • Фільтри"),
            accentColor: Color.cyan,
            badgeText: "Скоро",
            isLocked: true
        ) {
            showJobs = true
        }
    }
    
    private var bentoPrimaryQuickActions: [BentoQuickActionItem] {
        // Завжди 2 елементи справа для правильного layout
        [
            BentoQuickActionItem(
                icon: "book.fill",
                title: LocalizedStringKey("Довідник"),
                subtitle: LocalizedStringKey("Гайди + чек-листи"),
                accentColor: Color.blue
            ) {
                NotificationCenter.default.post(name: .switchTab, object: 1)
            },
            BentoQuickActionItem(
                icon: "map.fill",
                title: LocalizedStringKey("Карта"),
                subtitle: LocalizedStringKey("Сервіси поруч"),
                accentColor: Color.orange
            ) {
                NotificationCenter.default.post(name: .switchTab, object: 2)
            }
        ]
    }
    
    private var bentoSecondaryQuickActions: [BentoQuickActionItem] {
        [
            BentoQuickActionItem(
                icon: "function",
                title: LocalizedStringKey("Калькулятор"),
                subtitle: nil,
                accentColor: Color.cyan
            ) {
                DeepLinkService.shared.navigate(to: .calculator)
            },
            BentoQuickActionItem(
                icon: "doc.richtext",
                title: LocalizedStringKey("CV Builder"),
                subtitle: nil,
                accentColor: Color.purple
            ) {
                showCVBuilder = true
            },
            BentoQuickActionItem(
                icon: "doc.text",
                title: LocalizedStringKey("Шаблони"),
                subtitle: nil,
                accentColor: Color.pink
            ) {
                showTemplates = true
            },
            BentoQuickActionItem(
                icon: "gearshape.fill",
                title: LocalizedStringKey("Налаштування"),
                subtitle: nil,
                accentColor: Color.gray
            ) {
                NotificationCenter.default.post(name: .switchTab, object: 3)
            }
        ]
    }
    
    // MARK: - Jobs Promo Section
    private var jobsPromoSection: some View {
        VStack(spacing: 0) {
            InteractiveCard(
                icon: "briefcase.fill",
                title: "Пошук роботи",
                subtitle: "Офіційний RAV + Indeed. Фільтр за кантонами.",
                badge: "Нове",
                badgeColor: Theme.Colors.accent
            ) { showJobs = true }
            .buttonStyle(CardPressStyle())
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
    
    // MARK: - Stats Section (Bento Grid)
    
    private var statsSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            SectionHeader("Ваша статистика")
            BentoStatsGrid(
                level: statLevel,
                xp: statXP,
                xpNext: xpTarget(for: statLevel),
                guidesRead: statGuides,
                checklists: statChecklists,
                templates: statTemplates,
                hoursSaved: statHoursSaved
            )
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }
    
    // MARK: - Recommendations Section
    private var recommendationsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            SectionHeader("Рекомендації для вас")
            let cards = recommendedGuides.prefix(4).map {
                RecommendationDisplay(
                    guide: $0,
                    badgeText: badgeFor(guide: $0),
                    badgeColor: badgeColorFor(guide: $0),
                    tagline: taglineForGuide($0)
                )
            }
            StackedRecommendationList(
                cards: cards,
                onSelect: { guide in selectedGuide = guide }
            )
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
    
    // MARK: - Local helpers
    private func xpTarget(for level: Int) -> Int {
        switch level {
        case 1: return 100
        case 2: return 300
        case 3: return 600
        case 4: return 1000
        case 5: return 1500
        case 6: return 2200
        case 7: return 3000
        default: return 4000
        }
    }
    
    // MARK: - Pro Card (Premium Design)
    private var proCardSection: some View {
        Group {
            if shouldShowProCard {
                ZStack {
                    // Background with gradient and glow
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.12, blue: 0.18),
                                    Color(red: 0.05, green: 0.08, blue: 0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Ambient glow blobs
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.Colors.accentTurquoise.opacity(0.25), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 120
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 40)
                        .offset(x: -80, y: -60)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.Colors.accent.opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 100
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 35)
                        .offset(x: 100, y: 80)
                    
                    // Content
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Header with crown and badge
                        HStack(spacing: Theme.Spacing.sm) {
                            // Animated crown icon
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.95, green: 0.80, blue: 0.30),
                                                Color(red: 0.85, green: 0.65, blue: 0.20)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color(red: 0.95, green: 0.80, blue: 0.30).opacity(0.5), radius: 12, x: 0, y: 4)
                                
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sweezy Pro")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("Повний доступ до всіх можливостей")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            // Pro badge with glow
                            Text("PRO")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: Theme.Colors.accentTurquoise.opacity(0.5), radius: 8, x: 0, y: 2)
                        }
                        
                        // Benefits with icons
                        VStack(alignment: .leading, spacing: 10) {
                            ProBenefitRow(icon: "wand.and.stars", text: "AI-генерація CV та листів", highlight: true)
                            ProBenefitRow(icon: "doc.richtext", text: "Преміум шаблони + офлайн PDF", highlight: false)
                            ProBenefitRow(icon: "bell.badge", text: "Безлімітні push-сповіщення", highlight: false)
                            ProBenefitRow(icon: "infinity", text: "Необмежені збереження", highlight: false)
                        }
                        
                        // Plan selector (redesigned)
                        ProPlanSelector(selectedPlan: $selectedPlan)
                        
                        // CTA Button with savings info
                        VStack(spacing: 10) {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showSubscription = true
                            } label: {
                                HStack(spacing: 8) {
                                    Text(selectedPlan.ctaTitle)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: Theme.Colors.accentTurquoise.opacity(0.4), radius: 16, x: 0, y: 8)
                            }
                            .accessibilityLabel("Оформити \(selectedPlan.displayTitle)")
                            
                            // Savings info
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.accentYellowSoft)
                                Text(selectedPlan.savingsLine)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                Text("•")
                                    .foregroundColor(.white.opacity(0.4))
                                Text(selectedPlan.detailLine(limitReached: isFavoritesLimitReached))
                                    .font(Theme.Typography.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding(Theme.Spacing.xl)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05),
                                    Theme.Colors.accentTurquoise.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.horizontal, Theme.Spacing.lg)
                .sheet(isPresented: $showSubscription) {
                    SubscriptionView()
                        .environmentObject(appContainer)
                }
            }
        }
    }
    
    // MARK: - Analytics Pinboard (Gamification)
    private var analyticsPinboard: some View {
        GamificationLevelCard(
            currentXP: userXP,
            xpForNextLevel: xpForNextLevel,
            level: userLevel,
            levelTitle: levelTitle,
            hoursSaved: estimatedHoursSaved,
            guidesRead: appContainer.userStats.guidesReadCount,
            lastAward: appContainer.gamification.lastAwardedXP,
            todayXP: appContainer.gamification.xpGainedToday(),
            badges: earnedBadges
        )
        .padding(.horizontal, Theme.Spacing.lg)
    }
    
    // MARK: - Gamification Helpers
    private var userXP: Int {
        appContainer.gamification.totalXP
    }
    
    private var userLevel: Int {
        switch userXP {
        case 0..<100: return 1
        case 100..<300: return 2
        case 300..<600: return 3
        case 600..<1000: return 4
        case 1000..<1500: return 5
        case 1500..<2200: return 6
        case 2200..<3000: return 7
        default: return 8
        }
    }
    
    private var xpForNextLevel: Int {
        switch userLevel {
        case 1: return 100
        case 2: return 300
        case 3: return 600
        case 4: return 1000
        case 5: return 1500
        case 6: return 2200
        case 7: return 3000
        default: return 4000
        }
    }
    
    private var levelTitle: String {
        switch userLevel {
        case 1: return "Новачок"
        case 2: return "Дослідник"
        case 3: return "Інтегратор"
        case 4: return "Експерт"
        case 5: return "Майстер"
        case 6: return "Гуру"
        case 7: return "Легенда"
        default: return "Чемпіон"
        }
    }
    
    private var earnedBadges: [GamificationBadge] {
        var badges: [GamificationBadge] = []
        
        if appContainer.userStats.guidesReadCount >= 1 {
            badges.append(GamificationBadge(icon: "book.fill", title: "Читач", color: Theme.Colors.info))
        }
        if appContainer.userStats.guidesReadCount >= 5 {
            badges.append(GamificationBadge(icon: "books.vertical.fill", title: "Книголюб", color: Theme.Colors.accentTurquoise))
        }
        if appContainer.userStats.activeChecklistsCount >= 1 {
            badges.append(GamificationBadge(icon: "checklist", title: "Організатор", color: Theme.Colors.success))
        }
        if estimatedHoursSaved >= 5 {
            badges.append(GamificationBadge(icon: "clock.fill", title: "Економ часу", color: Theme.Colors.accent))
        }
        if estimatedHoursSaved >= 20 {
            badges.append(GamificationBadge(icon: "star.fill", title: "Суперзірка", color: Theme.Colors.accentCoral))
        }
        
        return badges
    }
    
    // MARK: - Local Feed Chips
    private var localFeedChips: some View {
        VStack(spacing: Theme.Spacing.md) {
            SectionHeader("Локальна стрічка")
            FlowLayout(spacing: 8) {
                ForEach(upcomingChips.prefix(8), id: \.id) { chip in
                    InfoChip(text: chip.text, color: chip.color, countdown: chip.countdown)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
    
    // MARK: - Ambient Notifications
    private var notificationAmbientSection: some View {
        Group {
            if !ambientAlerts.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    SectionHeader("Сповіщення")
                    VStack(spacing: Theme.Spacing.md) {
                        ForEach(ambientAlerts) { alert in
                            AmbientNotificationCard(alert: alert)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
        }
    }
    
    // MARK: - Featured Guides Section (Mind Map)
    
    private var featuredGuidesSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            SectionHeader("Популярні гіди")
            KnowledgeMindMapView(
                guides: cachedFeaturedGuides.isEmpty ? featuredGuides : cachedFeaturedGuides,
                onSelect: { guide in selectedGuide = guide }
            )
            .frame(height: 380)
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
    
    private var featuredGuides: [Guide] {
        [GuideCategory.housing, .work, .integration, .documents, .healthcare, .education]
            .compactMap { topGuide(for: $0) }
            .prefix(6)
            .map { $0 }
    }
    
    // MARK: - News Section
    
    private var newsSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            SectionHeader("Що нового")
            
			let items: [NewsItem] = {
				let lang = appContainer.currentLocale.identifier
				let primary = appContainer.contentService.latestNews(limit: 8, language: lang)
				return primary.isEmpty
				? appContainer.contentService.latestNews(limit: 8, language: nil)
				: primary
			}()
			
			if items.isEmpty {
				Text("Новини поки що відсутні")
					.font(Theme.Typography.caption)
					.foregroundColor(Theme.Colors.textTertiary)
					.padding(.horizontal, Theme.Spacing.lg)
			} else {
				NewsCarousel(items: items) { item in
					if let content = item.content, !content.isEmpty {
						selectedNews = item
					} else if let url = URL(string: item.url) {
						UIApplication.shared.open(url)
					}
				}
			}
        }
    }
    
    // MARK: - Telegram Section
    
    private var telegramSection: some View {
        TelegramCommunityCard()
            .padding(.horizontal, Theme.Spacing.lg)
    }
    
    // MARK: - Helpers (must stay inside HomeViewRedesigned for @EnvironmentObject access)
    
    private var checklistTasks: [FirstWeekChecklistService.TaskItem] {
        appContainer.firstWeekService.tasks
    }
    
    private var todayFocus: [FirstWeekChecklistService.TaskItem] {
        checklistTasks
            .filter { !$0.isDone && Calendar.current.isDateInToday($0.dueDate) }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    private var weekFocus: [FirstWeekChecklistService.TaskItem] {
        let calendar = Calendar.current
        return checklistTasks
            .filter {
                guard !$0.isDone else { return false }
                return calendar.isDate($0.dueDate, equalTo: Date(), toGranularity: .weekOfYear)
            }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    private func focusSubtitle(for tasks: [FirstWeekChecklistService.TaskItem]) -> String {
        guard let first = tasks.first else {
            return "Сьогодні без критичних задач"
        }
        if tasks.count == 1 {
            return first.title
        }
        return "\(first.title) + ще \(tasks.count - 1)"
    }
    
    private var dynamicGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Доброго ранку"
        case 12..<17: return "Доброго дня"
        case 17..<22: return "Доброго вечора"
        default: return "Доброї ночі"
        }
    }
    
    private func checkForWhatsNew() {
        let currentVersion = Bundle.main.appVersion
        if lastSeenVersion != currentVersion && !lastSeenVersion.isEmpty {
            showWhatsNewSheet = true
            lastSeenVersion = currentVersion
        } else if lastSeenVersion.isEmpty {
            lastSeenVersion = currentVersion
        }
    }
    
    private func topGuide(for category: GuideCategory) -> Guide? {
        appContainer.contentService.guides
            .filter { $0.category == category }
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.lastUpdated > $1.lastUpdated
            }
            .first
    }
    
    private var insiderMoments: [InsiderMoment] {
        let cantonName = appContainer.userProfile?.canton.localizedName ?? "Швейцарії"
        return [
            InsiderMoment(title: "Пільги \(cantonName)", summary: "Короткий список виплат та гарантій.", icon: "bolt.fill", tag: "Benefits", accent: Color(red: 0.22, green: 0.88, blue: 0.72), gradient: [Color(red: 0.15, green: 0.75, blue: 0.65), Color(red: 0.08, green: 0.45, blue: 0.55)], isNew: true, count: 5),
            InsiderMoment(title: "Career Pulse", summary: "3 вакансії тижня.", icon: "chart.line.uptrend.xyaxis", tag: "Jobs", accent: Color(red: 0.98, green: 0.55, blue: 0.45), gradient: [Color(red: 0.95, green: 0.45, blue: 0.35), Color(red: 0.75, green: 0.30, blue: 0.50)], isNew: false, count: 3)
        ]
    }
    
    private var recommendedGuides: [Guide] {
        let canton = appContainer.userProfile?.canton ?? .zurich
        let localeId = appContainer.currentLocale.identifier
        
        // Use locale‑aware helper from ContentService to ensure language matches user choice
        let localizedGuides = appContainer.contentService.getGuidesForLocale(localeId)
        
        return localizedGuides
            .filter { $0.appliesTo(canton: canton) }
            .sorted {
                if $0.isNew != $1.isNew { return $0.isNew && !$1.isNew }
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.lastUpdated > $1.lastUpdated
            }
    }
    
    private func badgeFor(guide: Guide) -> String? {
        if guide.isNew { return "New" }
        if daysSince(guide.lastUpdated) < 10 { return "Updated" }
        return nil
    }
    
    private func badgeColorFor(guide: Guide) -> Color {
        if guide.isNew { return Theme.Colors.success }
        return Theme.Colors.info
    }
    
    private func taglineForGuide(_ guide: Guide) -> String {
        let cantonName = appContainer.userProfile?.canton.localizedName ?? "Швейцарія"
        return "\(cantonName) • \(guide.category.localizedName)"
    }
    
    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
    
    private var shouldShowProCard: Bool {
        if appContainer.subscriptionManager.isPremium { return false }
        guard let ents = entitlements else { return false }
        if ents.is_premium { return false }
        return true
    }
    
    private var isFavoritesLimitReached: Bool {
        guard let limit = entitlements?.favorites_limit else { return false }
        return favoritesCount >= limit
    }
    
    private var estimatedHoursSaved: Int {
        max(1, appContainer.userStats.guidesReadCount * 2 + appContainer.userStats.activeChecklistsCount)
    }
    
    private var upcomingChips: [ChipItem] {
        var arr: [ChipItem] = []
        let soonTasks = checklistTasks.filter { !$0.isDone }.sorted { $0.dueDate < $1.dueDate }.prefix(3)
        for task in soonTasks {
            arr.append(.init(text: "Дедлайн: \(task.title)", color: Theme.Colors.warning, countdown: countdownString(to: task.dueDate)))
        }
        return arr
    }
    
    private func countdownString(to date: Date) -> String? {
        let comps = Calendar.current.dateComponents([.day, .hour], from: Date(), to: date)
        guard let day = comps.day, let hour = comps.hour else { return nil }
        if day <= 0 && hour <= 0 { return "сьогодні" }
        if day > 0 { return "через \(day)d" }
        return "через \(max(1, hour))h"
    }
    
    private var ambientAlerts: [AmbientAlert] {
        var alerts: [AmbientAlert] = []
        if let next = appContainer.firstWeekService.nextDueTask {
            alerts.append(AmbientAlert(title: "Нагадування", detail: next.title, icon: "bell.badge.fill", accent: Theme.Colors.warning, time: countdownString(to: next.dueDate) ?? "сьогодні"))
        }
        return alerts
    }
    
    private var nextFocusTitle: String {
        todayFocus.first?.title ?? "Сьогодні без критичних задач"
    }
    
    private var documentsProgress: Double {
        min(1.0, Double(appContainer.userStats.activeChecklistsCount) / 5.0)
    }
    
    private var careerProgress: Double {
        min(1.0, Double(appContainer.userStats.guidesReadCount) / 6.0)
    }
    
    private var primaryGoalName: String {
        appContainer.userProfile?.goals.first?.localizedName ?? "кар'єри"
    }
}

// MARK: - Telegram Community Card (Premium Design)
private struct TelegramCommunityCard: View {
    @State private var appeared = false
    @State private var isHovered = false
    
    // Telegram brand color
    private let telegramBlue = Color(red: 0.14, green: 0.67, blue: 0.88)
    private let telegramDark = Color(red: 0.10, green: 0.55, blue: 0.75)
    
    var body: some View {
        Button(action: {
            haptic(.medium)
            if let url = URL(string: "https://t.me/sweezy_swiss") {
                UIApplication.shared.open(url)
            }
        }) {
            ZStack {
                // Background with gradient
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                telegramBlue.opacity(0.15),
                                telegramDark.opacity(0.08),
                                Color(red: 0.08, green: 0.08, blue: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Ambient glow
                Circle()
                    .fill(telegramBlue.opacity(0.25))
                    .frame(width: 150, height: 150)
                    .blur(radius: 60)
                    .offset(x: -80, y: -30)
                
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .blur(radius: 50)
                    .offset(x: 100, y: 40)
                
                // Content
                HStack(spacing: 16) {
                    // Telegram icon with animated ring
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [telegramBlue, Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 64, height: 64)
                        
                        // Inner circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [telegramBlue, telegramDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: telegramBlue.opacity(0.5), radius: 12, x: 0, y: 6)
                        
                        // Icon
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-10))
                    }
                    
                    // Text content
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("Telegram")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.textPrimary)
                            
                            // Live badge
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Live")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.15))
                            )
                        }
                        
                        Text("Спільнота українців у Швейцарії")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        // Stats
                        HStack(spacing: 12) {
                            Label("500+", systemImage: "person.2.fill")
                            Label("Підтримка", systemImage: "bubble.left.and.bubble.right.fill")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(telegramBlue)
                    }
                    
                    Spacer()
                    
                    // Arrow with circle
                    ZStack {
                        Circle()
                            .fill(telegramBlue.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(telegramBlue)
                    }
                }
                .padding(20)
                
                // Border
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                telegramBlue.opacity(0.4),
                                Color.white.opacity(0.1),
                                telegramBlue.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: telegramBlue.opacity(0.2), radius: 20, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(TelegramCardPressStyle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }
}

private struct TelegramCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// NOTE: All duplicate helpers removed

// MARK: - Supporting Components

    private struct PastelQuickAction: View {
        let color: Color
        let icon: String
        let titleKey: LocalizedStringKey
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                PastelCard(background: color) {
                    HStack(alignment: .center, spacing: 12) {
                        PixelBadgeIcon(icon, tint: Theme.Colors.accentTurquoise)
                        Text(titleKey)
                            .font(Theme.Typography.subhead)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }
            .buttonStyle(CardPressStyle())
        }
    }

// MARK: - Bento Stats Grid (Apple-style asymmetric layout)

private struct BentoStatsGrid: View {
    let level: Int
    let xp: Int
    let xpNext: Int
    let guidesRead: Int
    let checklists: Int
    let templates: Int
    let hoursSaved: Int
    
    @State private var animatedProgress: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    private var xpProgress: CGFloat {
        let previousLevelXP: Int = {
            switch level {
            case 1: return 0
            case 2: return 100
            case 3: return 300
            case 4: return 600
            case 5: return 1000
            default: return 1500
            }
        }()
        let xpInLevel = xp - previousLevelXP
        let xpNeeded = xpNext - previousLevelXP
        return CGFloat(xpInLevel) / CGFloat(max(1, xpNeeded))
    }
    
    private var levelTitle: String {
        switch level {
        case 1: return "Новачок"
        case 2: return "Дослідник"
        case 3: return "Інтегратор"
        case 4: return "Експерт"
        case 5: return "Майстер"
        default: return "Легенда"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Row 1: Large XP card + two small cards
            HStack(spacing: 12) {
                // Main XP/Level card (large)
                BentoLevelCard(
                    level: level,
                    levelTitle: levelTitle,
                    xp: xp,
                    xpNext: xpNext,
                    progress: animatedProgress,
                    pulseScale: pulseScale
                )
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                
                // Right column: two small cards
                VStack(spacing: 12) {
                    BentoMiniCard(
                        icon: "book.fill",
                        value: "\(guidesRead)",
                        label: "гідів",
                        color: Theme.Colors.primary
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                    
                    BentoMiniCard(
                        icon: "checkmark.circle.fill",
                        value: "\(checklists)",
                        label: "чеклістів",
                        color: Theme.Colors.success
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                }
                .frame(width: 110)
            }
            
            // Row 2: Two medium cards
            HStack(spacing: 12) {
                BentoMediumCard(
                    icon: "clock.fill",
                    value: "\(hoursSaved)",
                    label: "годин збережено",
                    color: Theme.Colors.accentTurquoise
                )
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                
                BentoMediumCard(
                    icon: "doc.text.fill",
                    value: "\(templates)",
                    label: "шаблонів",
                    color: Theme.Colors.accent
                )
                .frame(maxWidth: .infinity)
                .frame(height: 90)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedProgress = xpProgress
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
        }
    }
}

// Large card for Level/XP
private struct BentoLevelCard: View {
    let level: Int
    let levelTitle: String
    let xp: Int
    let xpNext: Int
    let progress: CGFloat
    let pulseScale: CGFloat
    
    var body: some View {
        ZStack {
            // Subtle gradient background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.Colors.accentTurquoise.opacity(0.25), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .frame(width: 120, height: 120)
                .blur(radius: 30)
                .offset(x: -40, y: -30)
            
            HStack(spacing: 16) {
                // Level ring
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Theme.Colors.accentTurquoise,
                                    Theme.Colors.accent,
                                    Theme.Colors.accentCoral,
                                    Theme.Colors.accentTurquoise
                                ],
                                center: .center
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulseScale)
                        .opacity(0.6)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    // Inner circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.16, blue: 0.22),
                                    Color(red: 0.08, green: 0.10, blue: 0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: Theme.Colors.accentTurquoise.opacity(0.4), radius: 10, x: 0, y: 0)
                    
                    // Level number
                    Text("\(level)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(levelTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(xp) / \(xpNext) XP")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    // Mini XP bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                    .frame(maxWidth: 120)
                    
                    Text("До рівня \(level + 1)")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                
                Spacer()
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// Mini card for single stat
private struct BentoMiniCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
            
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// Medium card for stats
private struct BentoMediumCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
            
            // Subtle glow
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 60, height: 60)
                .blur(radius: 25)
                .offset(x: -30, y: 0)
            
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(label)
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct RecommendationDisplay: Identifiable {
    let guide: Guide
    let badgeText: String?
    let badgeColor: Color
    let tagline: String
    
    var id: UUID { guide.id }
}

private struct StackedRecommendationList: View {
    let cards: [RecommendationDisplay]
    let onSelect: (Guide) -> Void
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                RecommendationCard(card: card, index: index) {
                    onSelect(card.guide)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.08), value: appeared)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            if !appeared { appeared = true }
        }
    }
}

private struct RecommendationCard: View {
    let card: RecommendationDisplay
    let index: Int
    let action: () -> Void
    
    // Кольори для різних категорій
    private var categoryColor: Color {
        switch card.guide.category {
        case .integration: return Color(red: 0.2, green: 0.7, blue: 0.6)
        case .education: return Color(red: 0.3, green: 0.5, blue: 0.9)
        case .transport: return Color(red: 0.9, green: 0.6, blue: 0.2)
        case .legal: return Color(red: 0.7, green: 0.4, blue: 0.9)
        case .healthcare: return Color(red: 0.9, green: 0.4, blue: 0.4)
        case .finance, .banking: return Color(red: 0.3, green: 0.8, blue: 0.5)
        case .housing: return Color(red: 0.5, green: 0.6, blue: 0.9)
        case .documents: return Color(red: 0.6, green: 0.5, blue: 0.8)
        case .insurance: return Color(red: 0.4, green: 0.7, blue: 0.8)
        case .work: return Color(red: 0.95, green: 0.7, blue: 0.3)
        case .emergency: return Color(red: 0.95, green: 0.35, blue: 0.35)
        }
    }
    
    var body: some View {
        Button(action: {
            haptic(.light)
            action()
        }) {
            HStack(spacing: 14) {
                // Ліва кольорова смуга з іконкою
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [categoryColor, categoryColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: categoryIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: categoryColor.opacity(0.4), radius: 8, x: 0, y: 4)
                
                // Контент
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(card.guide.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        
                        if let badge = card.badgeText {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [card.badgeColor, card.badgeColor.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                    }
                    
                    Text(card.guide.subtitle ?? card.guide.category.localizedName)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(categoryColor.opacity(0.8))
                        Text(card.tagline)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
                
                Spacer(minLength: 4)
                
                // Стрілка
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(categoryColor)
                }
            }
            .padding(14)
            .background(
                ZStack {
                    // Glass background
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // Subtle gradient tint
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(categoryColor.opacity(0.05))
                    
                    // Border
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    categoryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    
                    // Corner snowflakes (winter theme only)
                    if WinterTheme.isActive {
                        CornerSnowflakes()
                            .padding(8)
                    }
                }
            )
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            .apply {
                if WinterTheme.isActive {
                    $0.frostFrame(cornerRadius: 18, lineWidth: 1.5)
                } else {
                    $0
                }
            }
        }
        .buttonStyle(RecommendationCardPressStyle())
    }
    
    private var categoryIcon: String {
        switch card.guide.category {
        case .integration: return "person.badge.plus"
        case .education: return "graduationcap.fill"
        case .transport: return "tram.fill"
        case .legal: return "building.columns.fill"
        case .healthcare: return "heart.fill"
        case .finance, .banking: return "banknote.fill"
        case .housing: return "house.fill"
        case .documents: return "doc.text.fill"
        case .insurance: return "shield.fill"
        case .work: return "briefcase.fill"
        case .emergency: return "exclamationmark.triangle.fill"
        }
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }
}

private struct RecommendationCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// (no placeholders)

private struct NewsCard: View {
    let title: String
    let date: String
    let gradient: LinearGradient
    let action: () -> Void
    let onDismiss: (() -> Void)?
    @State private var hasScheduledDismiss = false
    
    init(title: String, date: String, gradient: LinearGradient, action: @escaping () -> Void, onDismiss: (() -> Void)? = nil) {
        self.title = title
        self.date = date
        self.gradient = gradient
        self.action = action
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Spacer()
                
                Text(title)
                    .font(Theme.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                Text(date)
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 240, height: 150, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous)
                    .fill(gradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .themeShadow(Theme.Shadows.level2)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
        .onAppear {
            guard !hasScheduledDismiss else { return }
            hasScheduledDismiss = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                onDismiss?()
            }
        }
    }
}

// MARK: - Week Strip Focus View

private struct WeekStripFocusView: View {
    let todayTasks: [FirstWeekChecklistService.TaskItem]
    let weekTasks: [FirstWeekChecklistService.TaskItem]
    let onDayTap: (WeekDay) -> Void
    
    @State private var selectedDay: WeekDay? = nil
    @State private var appeared = false
    
    private let calendar = Calendar.current
    
    // Дні тижня
    private var weekDays: [WeekDay] {
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = weekday == 1 ? -6 : 2 - weekday
        
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: mondayOffset + offset, to: today) ?? today
            let dayNumber = calendar.component(.day, from: date)
            let isToday = calendar.isDateInToday(date)
            let dayTasks = tasksForDay(date)
            
            return WeekDay(
                index: offset,
                shortName: shortDayName(for: offset),
                dayNumber: dayNumber,
                isToday: isToday,
                tasksCount: dayTasks.count,
                date: date,
                tasks: dayTasks
            )
        }
    }
    
    private func shortDayName(for index: Int) -> String {
        ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Нд"][index]
    }
    
    private func tasksForDay(_ date: Date) -> [FirstWeekChecklistService.TaskItem] {
        if calendar.isDateInToday(date) {
            return todayTasks
        }
        // Для майбутніх днів — фільтруємо по dueDate
        return weekTasks.filter { task in
            calendar.isDate(task.dueDate, inSameDayAs: date)
        }
    }
    
    // Найближча задача для Quick Preview
    private var nextUpcomingTask: FirstWeekChecklistService.TaskItem? {
        let allTasks = (todayTasks + weekTasks).filter { !$0.isDone }
        return allTasks.sorted { $0.dueDate < $1.dueDate }.first
    }
    
    var body: some View {
        VStack(spacing: 14) {
            // Week strip
            weekStripView
            
            // Quick Preview — найближча задача (Варіант 3)
            if let nextTask = nextUpcomingTask, selectedDay == nil {
                QuickTaskPreview(task: nextTask)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
            
            // Expandable day tasks (Варіант 1)
            if let day = selectedDay, !day.tasks.isEmpty {
                ExpandableDayTasks(day: day, tasks: day.tasks)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
            } else if let day = selectedDay, day.tasks.isEmpty {
                EmptyDayView(dayName: day.shortName)
                    .transition(.opacity)
            }
            
            // Summary row
            summaryRow
        }
        .onAppear {
            if !appeared { appeared = true }
        }
    }
    
    private var weekStripView: some View {
        HStack(spacing: 0) {
            ForEach(weekDays) { day in
                WeekDayCell(
                    day: day,
                    isSelected: selectedDay?.index == day.index,
                    onTap: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedDay = selectedDay?.index == day.index ? nil : day
                        }
                        haptic(.light)
                        onDayTap(day)
                    }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.8).delay(Double(day.index) * 0.04),
                    value: appeared
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(weekStripBackground)
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
    
    private var weekStripBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
            
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.15, blue: 0.2).opacity(0.5),
                            Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
    
    private var summaryRow: some View {
        HStack(spacing: 20) {
            FocusSummaryItem(
                icon: "sun.max.fill",
                value: "\(todayTasks.count)",
                label: "сьогодні",
                color: Color.orange
            )
            
            Divider()
                .frame(height: 30)
                .background(Color.white.opacity(0.2))
            
            FocusSummaryItem(
                icon: "calendar",
                value: "\(weekTasks.count)",
                label: "тиждень",
                color: Color.cyan
            )
            
            Divider()
                .frame(height: 30)
                .background(Color.white.opacity(0.2))
            
            FocusSummaryItem(
                icon: "checkmark.circle.fill",
                value: "\(completedPercentage)%",
                label: "виконано",
                color: Color.green
            )
        }
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: appeared)
    }
    
    private var completedPercentage: Int {
        let total = todayTasks.count + weekTasks.count
        guard total > 0 else { return 100 }
        let completed = todayTasks.filter { $0.isDone }.count + weekTasks.filter { $0.isDone }.count
        return Int((Double(completed) / Double(total)) * 100)
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }
}

// MARK: - Quick Task Preview (Варіант 3)
private struct QuickTaskPreview: View {
    let task: FirstWeekChecklistService.TaskItem
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: task.dueDate)
    }
    
    private var isUrgent: Bool {
        Calendar.current.isDateInToday(task.dueDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Іконка з індикатором
            ZStack {
                Circle()
                    .fill(isUrgent ? Color.orange.opacity(0.2) : Color.cyan.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: isUrgent ? "exclamationmark.circle.fill" : "arrow.right.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isUrgent ? .orange : .cyan)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Найближче")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textTertiary)
                
                Text(task.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Час
            if isUrgent {
                Text("Сьогодні")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
            } else {
                Text(timeString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isUrgent ? Color.orange.opacity(0.3) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Expandable Day Tasks (Варіант 1)
private struct ExpandableDayTasks: View {
    let day: WeekDay
    let tasks: [FirstWeekChecklistService.TaskItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Задачі на \(day.shortName), \(day.dayNumber)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Spacer()
                
                Text("\(tasks.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(day.isToday ? Color.cyan : Color.gray.opacity(0.5))
                    )
            }
            .padding(.horizontal, 4)
            
            // Tasks list
            VStack(spacing: 8) {
                ForEach(Array(tasks.prefix(5).enumerated()), id: \.element.id) { index, task in
                    TaskRowItem(task: task, index: index)
                }
                
                if tasks.count > 5 {
                    HStack {
                        Spacer()
                        Text("+ ще \(tasks.count - 5) задач")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.textTertiary)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.12, blue: 0.18).opacity(0.6),
                                    Color(red: 0.08, green: 0.08, blue: 0.12).opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Task Row Item
private struct TaskRowItem: View {
    let task: FirstWeekChecklistService.TaskItem
    let index: Int
    
    @State private var appeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            ZStack {
                Circle()
                    .stroke(task.isDone ? Color.green : Color.gray.opacity(0.4), lineWidth: 2)
                    .frame(width: 22, height: 22)
                
                if task.isDone {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 22, height: 22)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Title
            Text(task.title)
                .font(.system(size: 14, weight: task.isDone ? .regular : .medium))
                .foregroundColor(task.isDone ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                .strikethrough(task.isDone, color: Theme.Colors.textTertiary)
                .lineLimit(1)
            
            Spacer()
            
            // Time indicator
            if !task.isDone {
                Text(formatTime(task.dueDate))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(task.isDone ? Color.green.opacity(0.08) : Color.white.opacity(0.05))
        )
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -10)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05)) {
                appeared = true
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Empty Day View
private struct EmptyDayView: View {
    let dayName: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(Color.green.opacity(0.6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Немає задач")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("\(dayName) вільний від завдань")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// День тижня
struct WeekDay: Identifiable {
    let index: Int
    let shortName: String
    let dayNumber: Int
    let isToday: Bool
    let tasksCount: Int
    let date: Date
    let tasks: [FirstWeekChecklistService.TaskItem]
    
    var id: Int { index }
}

// Клітинка дня
private struct WeekDayCell: View {
    let day: WeekDay
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // День тижня
                Text(day.shortName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(day.isToday ? .white : Theme.Colors.textTertiary)
                
                // Число
                ZStack {
                    if day.isToday {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.cyan.opacity(0.5), radius: 8, x: 0, y: 4)
                    } else if isSelected {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 36, height: 36)
                    }
                    
                    Text("\(day.dayNumber)")
                        .font(.system(size: 15, weight: day.isToday ? .bold : .medium, design: .rounded))
                        .foregroundColor(day.isToday ? .white : Theme.Colors.textPrimary)
                }
                
                // Точки задач
                HStack(spacing: 3) {
                    ForEach(0..<min(day.tasksCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(day.isToday ? Color.cyan : Color.gray.opacity(0.5))
                            .frame(width: 4, height: 4)
                    }
                    if day.tasksCount > 3 {
                        Text("+")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Summary item
private struct FocusSummaryItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
    }
}

// MARK: - Supporting Components / Helpers

private struct AmbientCard<Badge: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let badge: Badge
    let gradients: [Color]
    
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradients,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Ambient glow circles
            Circle()
                .fill(gradients.first?.opacity(0.5) ?? Color.white.opacity(0.3))
                .frame(width: 100, height: 100)
                .blur(radius: 40)
                .offset(x: -50, y: -40)
            
            Circle()
                .fill(gradients.last?.opacity(0.4) ?? Color.white.opacity(0.2))
                .frame(width: 80, height: 80)
                .blur(radius: 35)
                .offset(x: 60, y: 50)
            
            // Glass overlay
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Content
            VStack(alignment: .leading, spacing: 10) {
                // Top row: Icon + Badge
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    badge
                    
                    Spacer()
                }
                
                Spacer()
                
                // Title
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                
                // Subtitle
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(18)
            
            // Border
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .frame(width: 180, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: gradients.first?.opacity(0.4) ?? Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

private struct AmbientNotificationCard: View {
    let alert: AmbientAlert
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(alert.accent.opacity(0.4))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: alert.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(alert.detail)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            Spacer()
            Text(alert.time)
                .font(Theme.Typography.caption2)
                .foregroundColor(alert.accent)
        }
        .padding()
        .background(Theme.Colors.glassMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous)
                .stroke(alert.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - News Carousel

private struct NewsCarousel: View {
    let items: [NewsItem]
    let onSelect: (NewsItem) -> Void
    
    @State private var appeared = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PremiumNewsCard(item: item, index: index) {
                        onSelect(item)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 30)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.08),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 8)
        }
        .onAppear {
            if !appeared { appeared = true }
        }
    }
}

// MARK: - Premium News Card
private struct PremiumNewsCard: View {
    let item: NewsItem
    let index: Int
    let action: () -> Void
    
    // Кольори для різних джерел/тегів
    private var accentColor: Color {
        let tag = item.tags.first?.lowercased() ?? item.source.lowercased()
        switch tag {
        case "law", "legal", "юридична": return Color(red: 0.6, green: 0.4, blue: 0.9)
        case "caritas", "help", "допомога": return Color(red: 0.9, green: 0.5, blue: 0.3)
        case "canton", "кантон": return Color(red: 0.3, green: 0.7, blue: 0.9)
        case "work", "робота": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "finance", "фінанси": return Color(red: 0.95, green: 0.7, blue: 0.2)
        default: return Color(red: 0.4, green: 0.6, blue: 0.95)
        }
    }
    
    var body: some View {
        Button(action: {
            haptic(.light)
            action()
        }) {
            ZStack {
                // Background gradient
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.2),
                                accentColor.opacity(0.05),
                                Color(red: 0.08, green: 0.08, blue: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Ambient glow
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .blur(radius: 50)
                    .offset(x: -80, y: -40)
                
                // Content
                VStack(alignment: .leading, spacing: 12) {
                    // Tags row
                    HStack(spacing: 8) {
                        NewsTagChip(text: item.source, color: accentColor)
                        NewsTagChip(text: item.language.uppercased(), color: .white.opacity(0.6))
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Title
                    Text(item.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                    
                    // Summary
                    Text(item.summary)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(2)
                    
                    // Date row
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .medium))
                        Text(relativeDate(item.publishedAt))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(accentColor.opacity(0.9))
                }
                .padding(18)
                
                // Border
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.5),
                                Color.white.opacity(0.15),
                                accentColor.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .frame(width: 280, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: accentColor.opacity(0.25), radius: 16, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(NewsCardPressStyle())
    }
    
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }
}

// MARK: - News Tag Chip
private struct NewsTagChip: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.2))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
    }
}

// MARK: - News Card Press Style
private struct NewsCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Legacy SourceChip for compatibility
private struct SourceChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.Typography.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.18))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
    }
}

private struct JourneyRoadmapView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stages: [JourneyStage]
    @Binding var selectedStage: JourneyStage?
    
    // Animations
    @State private var pathTrim: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.4
    @State private var particlePhase: Double = 0
    @State private var travelerOffset: CGFloat = 0
    
    @State private var xpToast: (id: UUID, amount: Int, position: CGPoint)?
    
    private let mapWidth: CGFloat = 900
    private let mapHeight: CGFloat = 340
    
    var body: some View {
        let positions = stagePositions()
        
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    // Deep space background
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.12, blue: 0.22),
                                    Color(red: 0.02, green: 0.04, blue: 0.10)
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 500
                            )
                        )
                    
                    // Starfield particles
                    if !reduceMotion {
                        TimelineView(.animation(minimumInterval: 0.1)) { timeline in
                            Canvas { context, size in
                                let time = timeline.date.timeIntervalSinceReferenceDate
                                for i in 0..<40 {
                                    let seed = Double(i) * 1.618
                                    let x = (sin(seed * 3.14) * 0.5 + 0.5) * size.width
                                    let baseY = (cos(seed * 2.71) * 0.5 + 0.5) * size.height
                                    let twinkle = sin(time * 2 + seed) * 0.5 + 0.5
                                    let starSize = CGFloat(1 + twinkle * 1.5)
                                    var circle = Path()
                                    circle.addEllipse(in: CGRect(x: x, y: baseY, width: starSize, height: starSize))
                                    context.fill(circle, with: .color(Color.white.opacity(0.12 + twinkle * 0.2)))
                                }
                            }
                        }
                        .blendMode(.plusLighter)
                    }
                    
                    // Nebula glow blobs
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.cyan.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 180
                            )
                        )
                        .frame(width: 360, height: 360)
                        .offset(x: -200, y: -40)
                        .blur(radius: 60)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.12), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(x: 280, y: 60)
                        .blur(radius: 70)
                    
                    // Main route path with animated trim
                    routePathShape(positions: positions)
                        .trim(from: 0, to: pathTrim)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.0, green: 1.0, blue: 0.85),
                                    Color(red: 0.4, green: 0.7, blue: 1.0),
                                    Color(red: 0.85, green: 0.5, blue: 1.0),
                                    Color(red: 1.0, green: 0.6, blue: 0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color.cyan.opacity(glowOpacity), radius: 12, x: 0, y: 0)
                        .shadow(color: Color.purple.opacity(glowOpacity * 0.6), radius: 20, x: 0, y: 0)
                    
                    // Dashed overlay for texture
                    routePathShape(positions: positions)
                        .trim(from: 0, to: pathTrim)
                        .stroke(
                            Color.white.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 16])
                        )
                    
                    // Traveling pulse along path
                    if !reduceMotion {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .shadow(color: .white, radius: 8)
                            .modifier(TravelingModifier(path: routePathShape(positions: positions), progress: travelerOffset))
                            .opacity(pathTrim > 0.1 ? 1 : 0)
                    }
                    
                    // Stage nodes
                    ForEach(Array(zip(stages.indices, stages)), id: \.1.id) { index, stage in
                        let pos = positions[index]
                        let isSelected = selectedStage?.id == stage.id
                        let isCompleted = stage.progress >= 1.0
                        let stageProgress = min(CGFloat(index + 1) / CGFloat(stages.count), pathTrim)
                        let nodeVisible = stageProgress >= CGFloat(index) / CGFloat(stages.count)
                        
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                selectedStage = stage
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if stage.progress >= 1.0 && !appContainer.roadmapProgress.isCompleted(stage.title) {
                                appContainer.roadmapProgress.markCompleted(id: stage.title, rewardXP: 80)
                                withAnimation(.spring()) {
                                    xpToast = (stage.id, 80, pos)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation(.easeOut) { xpToast = nil }
                                }
                            }
                        } label: {
                            ZStack {
                                // Outer glow ring
                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            colors: [stage.accent, stage.accent.opacity(0.3), stage.accent],
                                            center: .center
                                        ),
                                        lineWidth: 3
                                    )
                                    .frame(width: isSelected ? 100 : 80, height: isSelected ? 100 : 80)
                                    .rotationEffect(.degrees(particlePhase * 60))
                                    .opacity(isSelected ? 1 : 0.5)
                                
                                // Pulse ring
                                Circle()
                                    .stroke(stage.accent.opacity(0.4), lineWidth: 2)
                                    .frame(width: isSelected ? 110 : 90, height: isSelected ? 110 : 90)
                                    .scaleEffect(pulseScale)
                                    .opacity(isSelected ? (2 - pulseScale) * 0.5 : 0)
                                
                                // Main node
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                isCompleted ? stage.accent : stage.accent.opacity(0.8),
                                                isCompleted ? stage.accent.opacity(0.6) : Color(white: 0.15)
                                            ],
                                            center: .topLeading,
                                            startRadius: 5,
                                            endRadius: 50
                                        )
                                    )
                                    .frame(width: isSelected ? 72 : 60, height: isSelected ? 72 : 60)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                                    .shadow(color: stage.accent.opacity(0.7), radius: isSelected ? 20 : 10, x: 0, y: 8)
                                
                                // Icon
                                Image(systemName: isCompleted ? "checkmark" : stage.icon)
                                    .font(.system(size: isSelected ? 28 : 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                                
                                // Step number badge
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundColor(stage.accent)
                                    .padding(6)
                                    .background(Circle().fill(Color.white))
                                    .offset(x: 30, y: -30)
                            }
                            .scaleEffect(nodeVisible ? 1 : 0.3)
                            .opacity(nodeVisible ? 1 : 0)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .position(pos)
                        .id(stage.id)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("\(stage.title), \(Int(stage.progress * 100))%"))
                        .accessibilityHint(Text("Відкрити деталі етапу"))
                        
                        // Label below node
                        VStack(spacing: 4) {
                            Text(stage.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("\(Int(stage.progress * 100))%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(stage.accent)
                            
                            // Mini progress arc
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 3)
                                Circle()
                                    .trim(from: 0, to: stage.progress)
                                    .stroke(stage.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                            }
                            .frame(width: 32, height: 32)
                        }
                        .position(x: pos.x, y: pos.y + 75)
                        .opacity(nodeVisible ? 1 : 0)
                    }
                    
                    // Border glow
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.cyan.opacity(0.1),
                                    Color.purple.opacity(0.1),
                                    Color.white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .frame(width: mapWidth, height: mapHeight)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
            }
            .onAppear {
                // Path draw animation
                if reduceMotion {
                    pathTrim = 1.0
                    pulseScale = 1.0
                    glowOpacity = 0.4
                } else {
                    withAnimation(.easeOut(duration: 2.0)) { pathTrim = 1.0 }
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulseScale = 1.3 }
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { glowOpacity = 0.7 }
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { particlePhase = 1 }
                    withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { travelerOffset = 1 }
                }
                // Auto-select first incomplete
                if selectedStage == nil, let first = stages.first(where: { $0.progress < 1.0 }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation { selectedStage = first }
                    }
                }
            }
            .onChange(of: selectedStage?.id) { _, stageID in
                guard let stageID,
                      let stage = stages.first(where: { $0.id == stageID }) else { return }
                withAnimation(.spring()) {
                    proxy.scrollTo(stage.id, anchor: .center)
                }
            }
        }
    }
    
    private func stagePositions() -> [CGPoint] {
        guard stages.count > 1 else {
            return [CGPoint(x: mapWidth / 2, y: mapHeight / 2)]
        }
        let padding: CGFloat = 100
        let usableWidth = mapWidth - padding * 2
        let spacing = usableWidth / CGFloat(stages.count - 1)
        
        return stages.indices.map { idx in
            let x = padding + CGFloat(idx) * spacing
            // Sinusoidal wave for visual interest
            let wave = sin(Double(idx) * .pi / 2) * 50
            let y = mapHeight / 2 + CGFloat(wave) - 20
            return CGPoint(x: x, y: y)
        }
    }
    
    private func routePathShape(positions: [CGPoint]) -> Path {
        var path = Path()
        guard positions.count > 1 else { return path }
        path.move(to: positions[0])
        
        for i in 1..<positions.count {
            let prev = positions[i - 1]
            let curr = positions[i]
            let midX = (prev.x + curr.x) / 2
            
            // Smooth bezier curves
            path.addCurve(
                to: curr,
                control1: CGPoint(x: midX, y: prev.y),
                control2: CGPoint(x: midX, y: curr.y)
            )
        }
        return path
    }
}

// Modifier to animate element along path
private struct TravelingModifier: ViewModifier, Animatable {
    let path: Path
    var progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func body(content: Content) -> some View {
        content.modifier(PositionAlongPath(path: path, progress: progress))
    }
}

private struct PositionAlongPath: ViewModifier {
    let path: Path
    let progress: CGFloat
    
    func body(content: Content) -> some View {
        GeometryReader { _ in
            content.position(pointOnPath())
        }
    }
    
    private func pointOnPath() -> CGPoint {
        let trimmed = path.trimmedPath(from: 0, to: max(0.001, min(progress, 0.999)))
        return trimmed.currentPoint ?? .zero
    }
}

private struct RoadmapStageDetail: View {
    let stage: JourneyStage
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Label(stage.title, systemImage: stage.icon)
                        .foregroundColor(stage.accent)
                        .font(Theme.Typography.subheadline)
                    Spacer()
                    Text(stage.cta)
                        .font(Theme.Typography.caption2)
                        .foregroundColor(stage.accent)
                }
                Text(stage.detail)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }
}

private struct InfoChip: View {
    let text: String
    let color: Color
    let countdown: String?
    @State private var appear = false
    
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
            if let countdown {
                Text(countdown)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.Colors.glassMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 6)
        .animation(.easeOut(duration: 0.4), value: appear)
        .onAppear { appear = true }
    }
}

private struct HomeStatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(Theme.Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

@ViewBuilder
private func bulletRow(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Circle()
            .fill(Theme.Colors.secondaryText)
            .frame(width: 4, height: 4)
            .offset(y: 6)
        Text(text)
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.secondaryText)
            .multilineTextAlignment(.leading)
    }
}

// Legacy PlanToggle (kept for compatibility)
private struct PlanToggle: View {
    @Binding var selectedPlan: PaywallPlan
    
    var body: some View {
        ProPlanSelector(selectedPlan: $selectedPlan)
    }
}

// MARK: - Pro Card Components

private struct ProBenefitRow: View {
    let icon: String
    let text: String
    let highlight: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(highlight
                          ? LinearGradient(colors: [Theme.Colors.accentTurquoise.opacity(0.3), Theme.Colors.accent.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(highlight ? Theme.Colors.accentTurquoise : .white.opacity(0.8))
            }
            
            Text(text)
                .font(Theme.Typography.subheadline)
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.accentTurquoise)
        }
    }
}

private struct ProPlanSelector: View {
    @Binding var selectedPlan: PaywallPlan
    @Namespace private var planAnimation
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(PaywallPlan.allCases, id: \.self) { plan in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedPlan = plan
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    ZStack {
                        // Background
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedPlan == plan
                                  ? LinearGradient(
                                        colors: plan == .yearly
                                            ? [Theme.Colors.accentTurquoise.opacity(0.3), Theme.Colors.accent.opacity(0.2)]
                                            : [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                  : LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        
                        // Selection ring
                        if selectedPlan == plan {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: plan == .yearly
                                            ? [Theme.Colors.accentTurquoise, Theme.Colors.accent]
                                            : [Color.white.opacity(0.4), Color.white.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .matchedGeometryEffect(id: "planRing", in: planAnimation)
                        } else {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        }
                        
                        // Content
                        VStack(spacing: 6) {
                            // Badge for yearly
                            if plan == .yearly {
                                Text("НАЙКРАЩА ЦІНА")
                                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                            }
                            
                            Text(plan.displayTitle)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(selectedPlan == plan ? .white : .white.opacity(0.7))
                            
                            Text(plan.priceLine)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(selectedPlan == plan
                                                 ? (plan == .yearly ? Theme.Colors.accentTurquoise : .white.opacity(0.9))
                                                 : .white.opacity(0.5))
                        }
                        .padding(.vertical, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: plan == .yearly ? 100 : 85)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

private enum PaywallPlan: CaseIterable {
    case monthly, yearly
    
    var displayTitle: String {
        switch self {
        case .monthly: return "Щомісяця"
        case .yearly: return "Рік"
        }
    }
    
    var priceLine: String {
        switch self {
        case .monthly: return "14 CHF"
        case .yearly: return "11 CHF / міс"
        }
    }
    
    var ctaTitle: String {
        switch self {
        case .monthly: return "Активувати Monthly"
        case .yearly: return "Активувати Yearly"
        }
    }
    
    var savingsLine: String {
        switch self {
        case .monthly: return "Гнучка оплата щомісяця"
        case .yearly: return "Заощаджує 36 CHF/рік"
        }
    }
    
    func detailLine(limitReached: Bool) -> String {
        if limitReached {
            return "Досягнуто ліміту збережень • активуйте, щоб не зупинятись"
        }
        switch self {
        case .monthly: return "Можна скасувати будь-коли"
        case .yearly: return "Вигода −3 CHF/міс + бонусні шаблони"
        }
    }
}

private struct JourneyStage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let progress: Double
    let cta: String
    let detail: String
}

private struct InsiderMoment: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let icon: String
    let tag: String
    let accent: Color
    let gradient: [Color]
    var isNew: Bool = false
    var count: Int = 0
}

// MARK: - Enhanced Insider Card
private struct InsiderCard: View {
    let moment: InsiderMoment
    
    @State private var isPressed = false
    @State private var iconGlow = false
    
    var body: some View {
        Button(action: {
            // Handle tap - можна додати навігацію
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: Icon + Badge
                HStack(spacing: 10) {
                    // Animated glowing icon
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(moment.accent.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .blur(radius: iconGlow ? 8 : 4)
                            .scaleEffect(iconGlow ? 1.2 : 1.0)
                        
                        // Icon background
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: moment.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, moment.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    // Badge with count
                    HStack(spacing: 4) {
                        Text(moment.tag)
                            .font(.system(size: 11, weight: .bold))
                        
                        if moment.count > 0 {
                            Text("•")
                                .font(.system(size: 8))
                            Text("\(moment.count)")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .foregroundColor(moment.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(moment.accent.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Spacer()
                    
                    // NEW badge
                    if moment.isNew {
                        Text("NEW")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.yellow)
                            )
                            .shadow(color: .yellow.opacity(0.5), radius: 4, x: 0, y: 2)
                    }
                }
                
                Spacer()
                
                // Title
                Text(moment.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                // Subtitle
                Text(moment.summary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(3)
                    .lineSpacing(2)
            }
            .padding(16)
            .frame(width: 200, height: 165)
            .background(
                ZStack {
                    // Modern mesh-like gradient
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: moment.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Subtle pattern overlay
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                    
                    // Glass edge highlight
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            // Deep shadow for depth
            .shadow(color: moment.gradient.first?.opacity(0.4) ?? .clear, radius: 12, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            // Press animation
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isPressed = false
                    }
                }
        )
        .onAppear {
            // Start icon glow animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                iconGlow = true
            }
        }
    }
}

private struct AmbientAlert: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let accent: Color
    let time: String
}

private struct ChipItem: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
    let countdown: String?
}

// MARK: - Gamification Level Card

struct GamificationBadge: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let color: Color
}

struct GamificationLevelCard: View {
    let currentXP: Int
    let xpForNextLevel: Int
    let level: Int
    let levelTitle: String
    let hoursSaved: Int
    let guidesRead: Int
    let lastAward: Int
    let todayXP: Int
    let badges: [GamificationBadge]
    
    @State private var animatedProgress: CGFloat = 0
    @State private var showXPGain: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    
    private var progress: CGFloat {
        let previousLevelXP: Int = {
            switch level {
            case 1: return 0
            case 2: return 100
            case 3: return 300
            case 4: return 600
            case 5: return 1000
            case 6: return 1500
            case 7: return 2200
            default: return 3000
            }
        }()
        let xpInCurrentLevel = currentXP - previousLevelXP
        let xpNeededForLevel = xpForNextLevel - previousLevelXP
        return CGFloat(xpInCurrentLevel) / CGFloat(max(1, xpNeededForLevel))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with level
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                // Level badge
                ZStack {
                    // Outer glow ring - winter or regular
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: WinterTheme.isActive 
                                    ? [Color.cyan, Color.white.opacity(0.8), Color(red: 0.6, green: 0.85, blue: 1.0), Color.cyan]
                                    : [Theme.Colors.accentTurquoise, Theme.Colors.accent, Theme.Colors.accentCoral, Theme.Colors.accentTurquoise],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 70, height: 70)
                        .scaleEffect(pulseScale)
                    
                    // Inner circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.1, green: 0.15, blue: 0.25),
                                    Color(red: 0.05, green: 0.08, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(
                                    WinterTheme.isActive 
                                        ? Color.cyan.opacity(0.4) 
                                        : Color.white.opacity(0.2), 
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: WinterTheme.isActive 
                                ? Color.cyan.opacity(0.6) 
                                : Theme.Colors.accentTurquoise.opacity(0.5), 
                            radius: 12, 
                            x: 0, 
                            y: 0
                        )
                    
                    // Level number
                    Text("\(level)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: WinterTheme.isActive 
                                    ? [Color.cyan, Color.white]
                                    : [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(levelTitle)
                        .font(Theme.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text("\(currentXP) / \(xpForNextLevel) XP")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                // XP indicator (last award)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(lastAward)")
                        .font(Theme.Typography.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.accentTurquoise)
                        .opacity(showXPGain ? 1 : 0.7)
                        .scaleEffect(showXPGain ? 1.1 : 1.0)
                    
                    Text("XP зароблено")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .padding(Theme.Spacing.lg)
            
            // XP Progress bar
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                WinterTheme.isActive 
                                    ? Color.cyan.opacity(0.15) 
                                    : Color.white.opacity(0.1)
                            )
                            .frame(height: 12)
                        
                        // Progress fill - winter or regular
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: WinterTheme.isActive 
                                        ? [Color.cyan, Color(red: 0.6, green: 0.85, blue: 1.0), Color.white.opacity(0.8)]
                                        : [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * animatedProgress, height: 12)
                            .shadow(
                                color: WinterTheme.isActive 
                                    ? Color.cyan.opacity(0.7) 
                                    : Theme.Colors.accentTurquoise.opacity(0.6), 
                                radius: 8, 
                                x: 0, 
                                y: 0
                            )
                        
                        // Shine effect
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: geo.size.width * animatedProgress, height: 6)
                            .offset(y: -1)
                        
                        // Winter snowflake indicator at progress end
                        if WinterTheme.isActive && animatedProgress > 0.05 {
                            Text("❄️")
                                .font(.system(size: 14))
                                .offset(x: geo.size.width * animatedProgress - 10)
                        }
                    }
                }
                .frame(height: 12)
                
                // Stats row (equal flexible columns to avoid wrapping/clipping)
                HStack(spacing: 10) {
                    StatPill(icon: "bolt.fill", value: "+\(todayXP)", label: "XP сьогодні")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StatPill(icon: "clock.fill", value: "\(hoursSaved)", label: "год збережено")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StatPill(icon: "book.fill", value: "\(guidesRead)", label: "гідів")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Next level hint (separate row to reduce horizontal pressure)
                HStack {
                    Spacer()
                    Text("До рівня \(level + 1)")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)
            
            // Badges section
            if !badges.isEmpty {
                Divider()
                    .background(WinterTheme.isActive ? Color.cyan.opacity(0.2) : Color.white.opacity(0.1))
                
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(spacing: 6) {
                        if WinterTheme.isActive {
                            Text("🏆")
                                .font(.system(size: 14))
                        }
                        Text("Досягнення")
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(badges) { badge in
                                BadgeChip(badge: badge)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xxl, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.xxl, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: WinterTheme.isActive 
                                    ? [Color.cyan.opacity(0.5), Color.white.opacity(0.2)]
                                    : [Theme.Colors.accentTurquoise.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: WinterTheme.isActive ? 1.5 : 1
                        )
                )
        )
        .shadow(
            color: WinterTheme.isActive 
                ? Color.cyan.opacity(0.2) 
                : Theme.Colors.accentTurquoise.opacity(0.15), 
            radius: 20, 
            x: 0, 
            y: 10
        )
        .overlay(
            Group {
                if WinterTheme.isActive {
                    // Corner snowflakes
                    Text("❄️")
                        .font(.system(size: 18))
                        .opacity(0.8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: -16, y: 16)
                    
                    Text("✨")
                        .font(.system(size: 14))
                        .opacity(0.7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .offset(x: 16, y: 16)
                }
            }
        )
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3)) {
                animatedProgress = progress
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
            // initial pulse for award if any
            if lastAward > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { showXPGain = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.25)) { showXPGain = false }
                    }
                }
            }
        }
        .onChange(of: lastAward) { _, newValue in
            guard newValue > 0 else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { showXPGain = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.25)) { showXPGain = false }
            }
        }
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.Colors.accentTurquoise)
            
            Text(value)
                .font(Theme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
                .monospacedDigit()
            
            Text(label)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
        }
        // No fixedSize: allow flexible shrink within column
    }
}

struct BadgeChip: View {
    let badge: GamificationBadge
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.color.opacity(0.2))
                    .frame(width: 28, height: 28)
                
                Image(systemName: badge.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(badge.color)
            }
            
            Text(badge.title)
                .font(Theme.Typography.caption2)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(badge.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Knowledge Mind Map

private struct KnowledgeMindMapView: View {
    let guides: [Guide]
    let onSelect: (Guide) -> Void
    
    @State private var selectedNode: UUID?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var pulsePhase: Double = 0
    
    private let centerSize: CGFloat = 90
    private let nodeSize: CGFloat = 70
    private let orbitRadius: CGFloat = 130
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.Colors.accentTurquoise.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .position(center)
                    .blur(radius: 40)
                
                // Connection lines
                ForEach(Array(guides.enumerated()), id: \.element.id) { index, guide in
                    let nodePos = nodePosition(index: index, total: guides.count, center: center)
                    
                    // Animated connection line
                    Path { path in
                        path.move(to: center)
                        let control = CGPoint(
                            x: (center.x + nodePos.x) / 2 + CGFloat(sin(Double(index) * 1.5)) * 20,
                            y: (center.y + nodePos.y) / 2 + CGFloat(cos(Double(index) * 1.5)) * 20
                        )
                        path.addQuadCurve(to: nodePos, control: control)
                    }
                    .stroke(
                        LinearGradient(
                            colors: [
                                categoryColor(for: guide.category).opacity(0.6),
                                categoryColor(for: guide.category).opacity(0.2)
                            ],
                            startPoint: .init(x: center.x / geo.size.width, y: center.y / geo.size.height),
                            endPoint: .init(x: nodePos.x / geo.size.width, y: nodePos.y / geo.size.height)
                        ),
                        style: StrokeStyle(lineWidth: selectedNode == guide.id ? 3 : 2, lineCap: .round, dash: [8, 4])
                    )
                    .animation(.easeInOut(duration: 0.3), value: selectedNode)
                    
                    // Glow on line when selected
                    if selectedNode == guide.id {
                        Path { path in
                            path.move(to: center)
                            let control = CGPoint(
                                x: (center.x + nodePos.x) / 2 + CGFloat(sin(Double(index) * 1.5)) * 20,
                                y: (center.y + nodePos.y) / 2 + CGFloat(cos(Double(index) * 1.5)) * 20
                            )
                            path.addQuadCurve(to: nodePos, control: control)
                        }
                        .stroke(categoryColor(for: guide.category).opacity(0.4), lineWidth: 8)
                        .blur(radius: 6)
                    }
                }
                
                // Central hub
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Theme.Colors.accentTurquoise,
                                    Theme.Colors.accent,
                                    Theme.Colors.accentCoral,
                                    Theme.Colors.accentTurquoise
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: centerSize + 10, height: centerSize + 10)
                        .rotationEffect(.degrees(pulsePhase * 30))
                    
                    // Main circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.1, green: 0.15, blue: 0.25),
                                    Color(red: 0.05, green: 0.08, blue: 0.15)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: centerSize / 2
                            )
                        )
                        .frame(width: centerSize, height: centerSize)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Theme.Colors.accentTurquoise.opacity(0.4), radius: 20, x: 0, y: 0)
                    
                    // Icon
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .position(center)
                .scaleEffect(1 + sin(pulsePhase) * 0.03)
                
                // Guide nodes
                ForEach(Array(guides.enumerated()), id: \.element.id) { index, guide in
                    let nodePos = nodePosition(index: index, total: guides.count, center: center)
                    let isSelected = selectedNode == guide.id
                    
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            if selectedNode == guide.id {
                                onSelect(guide)
                            } else {
                                selectedNode = guide.id
                            }
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        EventBus.shared.emit(GamEvent(type: .roadmapStageCompleted, metadata: ["entityId": guide.id.uuidString]))
                    } label: {
                        ZStack {
                            // Glow background
                            Circle()
                                .fill(categoryColor(for: guide.category).opacity(isSelected ? 0.4 : 0.2))
                                .frame(width: nodeSize + 20, height: nodeSize + 20)
                                .blur(radius: 12)
                            
                            // Main node
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            categoryColor(for: guide.category).opacity(0.9),
                                            categoryColor(for: guide.category).opacity(0.6)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: nodeSize, height: nodeSize)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: categoryColor(for: guide.category).opacity(0.5), radius: isSelected ? 16 : 8, x: 0, y: 4)
                            
                            // Icon
                            Image(systemName: categoryIcon(for: guide.category))
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                            
                            // Badge for new
                            if guide.isNew {
                                Circle()
                                    .fill(Theme.Colors.success)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                    .offset(x: nodeSize / 2 - 6, y: -nodeSize / 2 + 6)
                            }
                        }
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .position(nodePos)
                    // no XP logic in knowledge map (visual only)
                    
                    // Label below node
                    Text(guide.title)
                        .font(Theme.Typography.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? Theme.Colors.textPrimary : Theme.Colors.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: 90)
                        .position(x: nodePos.x, y: nodePos.y + nodeSize / 2 + 20)
                        .opacity(isSelected ? 1 : 0.8)
                }
                
                // Selected node detail card
                if let selectedId = selectedNode, let guide = guides.first(where: { $0.id == selectedId }) {
                    VStack(spacing: 8) {
                        Text(guide.title)
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        if let subtitle = guide.subtitle {
                            Text(subtitle)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            onSelect(guide)
                        } label: {
                            Text("Відкрити")
                                .font(Theme.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(categoryColor(for: guide.category))
                                )
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .frame(width: 200)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                            .fill(Theme.Colors.secondaryBackground)
                            .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                            .stroke(categoryColor(for: guide.category).opacity(0.3), lineWidth: 1)
                    )
                    .position(x: center.x, y: geo.size.height - 60)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(value, 0.8), 1.5)
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
                    .onEnded { _ in
                        withAnimation(.spring()) {
                            offset = .zero
                        }
                    }
            )
            .onTapGesture {
                if selectedNode != nil {
                    withAnimation(.spring()) {
                        selectedNode = nil
                    }
                }
            }
            // no toast here
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                pulsePhase = .pi * 2
            }
        }
    }
    
    private func nodePosition(index: Int, total: Int, center: CGPoint) -> CGPoint {
        let angle = (Double(index) / Double(total)) * .pi * 2 - .pi / 2
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * orbitRadius,
            y: center.y + CGFloat(sin(angle)) * orbitRadius
        )
    }
    
    private func categoryColor(for category: GuideCategory) -> Color {
        switch category {
        case .housing: return Color(red: 0.2, green: 0.6, blue: 0.9)
        case .work: return Color(red: 0.3, green: 0.8, blue: 0.5)
        case .integration: return Color(red: 0.9, green: 0.5, blue: 0.3)
        case .documents: return Color(red: 0.6, green: 0.4, blue: 0.9)
        case .healthcare: return Color(red: 0.9, green: 0.3, blue: 0.4)
        case .education: return Color(red: 0.3, green: 0.7, blue: 0.8)
        case .finance: return Color(red: 0.9, green: 0.7, blue: 0.2)
        case .transport: return Color(red: 0.5, green: 0.5, blue: 0.8)
        case .legal: return Color(red: 0.4, green: 0.3, blue: 0.6)
        case .insurance: return Color(red: 0.7, green: 0.6, blue: 0.9)
        case .emergency: return Color(red: 0.9, green: 0.2, blue: 0.2)
        case .banking: return Color(red: 0.9, green: 0.8, blue: 0.4)
        }
    }
    
    private func categoryIcon(for category: GuideCategory) -> String {
        switch category {
        case .housing: return "house.fill"
        case .work: return "briefcase.fill"
        case .integration: return "person.3.fill"
        case .documents: return "doc.text.fill"
        case .healthcare: return "cross.case.fill"
        case .education: return "graduationcap.fill"
        case .finance: return "banknote.fill"
        case .transport: return "tram.fill"
        case .legal: return "hammer"
        case .insurance: return "shield.fill"
        case .emergency: return "exclamationmark.triangle.fill"
        case .banking: return "building.columns.fill"
        }
    }
}

// MARK: - Preview

#Preview("Home Redesigned - Light") {
    HomeViewRedesigned()
        .environmentObject(AppContainer())
        .environmentObject(AppLockManager())
        .environmentObject(ThemeManager())
}

#Preview("Home Redesigned - Dark") {
    HomeViewRedesigned()
        .environmentObject(AppContainer())
        .environmentObject(AppLockManager())
        .environmentObject(ThemeManager())
        .preferredColorScheme(.dark)
}


