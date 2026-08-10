//
//  HomeViewRedesigned.swift
//  sweezy
//
//  Bold GoIT-inspired redesign with full-width hero and interactive sections
//

import SwiftUI

struct HomeViewRedesigned: View {
    private struct NextBestActionDescriptor {
        enum Destination {
            case checklists
            case roadmap

            var telemetryName: String {
                switch self {
                case .checklists: return "checklists"
                case .roadmap: return "roadmap"
                }
            }
        }

        let title: String
        let detail: String
        let progressLabel: String
        let ctaTitle: String
        let iconName: String
        let accent: Color
        let destination: Destination
    }

    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("lastSeenVersion") private var lastSeenVersion = ""
    @State private var showWhatsNewSheet = false
    @State private var showSettings = false
    @State private var showCVBuilder = false
    @State private var showTemplates = false
    @State private var showRoadmap = false
    @State private var showSweezyPassport = false
    @State private var cityHubRoute: CityHubRoute?
    @State private var selectedGuide: Guide?
    @State private var selectedNews: NewsItem?
    @State private var cachedFeaturedGuides: [Guide] = []
    @StateObject private var roadmapService = RoadmapService()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    // Live stats mirrors (lightweight, avoid deep dependencies)
    @State private var statXP: Int = 0
    @State private var statLevel: Int = 1
    @State private var statGuides: Int = 0
    @State private var statChecklists: Int = 0
    @State private var statTemplates: Int = 0
    @State private var statHoursSaved: Int = 0
    @State private var dismissedNewsIDs: Set<UUID> = []
    @State private var selectedJourneyStage: JourneyStage?
    @State private var recentlyCompletedTaskIDs: Set<UUID> = []
    @State private var lastLoggedNextActionTitle: String?
    // Forces lightweight refresh on day change / foreground to keep "today focus" accurate
    @State private var dayToken: Date = Date()
    // Ink header pill tabs: 0 = focus (all), 1 = tasks, 2 = guides
    @State private var homeTab = 0

    private static let sheetCornerRadius: CGFloat = 32

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        greetingSection(topInset: geo.safeAreaInsets.top)

                        VStack(spacing: Theme.Spacing.xxl) {
                            switch homeTab {
                            case 1:
                                if shouldShowPriorityTasksSection {
                                    priorityTasksSection
                                }
                                if shouldShowRoadmapEntrySection {
                                    roadmapEntrySection
                                }
                                if !shouldShowPriorityTasksSection && !shouldShowRoadmapEntrySection {
                                    homeTabEmptyState
                                }
                            case 2:
                                if shouldShowCuratedContentSection {
                                    curatedContentSection
                                } else {
                                    homeTabEmptyState
                                }
                                telegramSection
                            default:
                                focusTabContent
                            }
                        }
                        .padding(.top, Theme.Spacing.xl)
                        .padding(.bottom, Theme.Spacing.xxxl)
                        .frame(maxWidth: .infinity)
                        .background(
                            UnevenRoundedRectangle(
                                topLeadingRadius: Self.sheetCornerRadius,
                                topTrailingRadius: Self.sheetCornerRadius,
                                style: .continuous
                            )
                            .fill(Color.black.opacity(0.74))
                        )
                        .padding(.top, -Self.sheetCornerRadius)
                    }
                }
                .background(
                    // Ink behind the header (incl. status bar + top bounce),
                    // paper behind the sheet (incl. bottom bounce).
                    JourneyPhotoBackground(imageName: JourneyBackdrop.lake.rawValue, blurRadius: 6, darkness: 0.64)
                )
                .navigationBarHidden(true)
                .navigationDestination(item: $selectedGuide) { guide in
                    GuideDetailView(guide: guide)
                }
                .navigationDestination(isPresented: $showRoadmap) {
                    MountainRoadmapView()
                        .environmentObject(appContainer)
                }
                .navigationDestination(item: $selectedNews) { news in
                    NewsDetailView(news: news)
                }
                .navigationDestination(isPresented: $showSweezyPassport) {
                    SweezyPassportView()
                        .environmentObject(appContainer)
                }
                .navigationDestination(item: $cityHubRoute) { route in
                    if let hub = CityHubRegistry.hub(for: route.slug) {
                        CityHubView(hub: hub)
                            .environmentObject(appContainer)
                    }
                }
            }
        }
        .journeyScreen(.lake, darkness: 0.64)
        .sheet(isPresented: $showWhatsNewSheet) {
            WhatsNewView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(themeManager)
                // Explicitly pass SessionManager so the sheet remains safe
                // even if HomeViewRedesigned is ever mounted in a different context.
                .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showCVBuilder) {
            CVBuilderView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
        }
        .sheet(isPresented: $showTemplates) {
            NavigationStack {
                TemplatesView()
                    .environmentObject(appContainer)
                    .environmentObject(appContainer.accountManager)
                    .environmentObject(lockManager)
            }
        }
        .onAppear {
            AppLogger.ui("HomeViewRedesigned onAppear")
            #if DEBUG
            // Screenshot automation: pass "-screenshotRoute roadmap|passport" as a launch argument
            switch UserDefaults.standard.string(forKey: "screenshotRoute") {
            case "roadmap": showRoadmap = true
            case "passport": showSweezyPassport = true
            default: break
            }
            #endif
            roadmapService.refreshFromStorage()
            logNextBestActionViewedIfNeeded()
            // Defer heavy operations to not block UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                checkForWhatsNew()
            }
        }
        .task {
            // Delay background tasks to let UI render first
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec
            
            EventBus.shared.emit(GamEvent(type: .appDailyOpen))
            appContainer.analytics.track(
                "daily_open",
                properties: ["entitlement": subscriptionManager.isPremium ? "plus" : "free"]
            )
            
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
        .onReceive(NotificationCenter.default.publisher(for: .roadmapProgressUpdated)) { _ in
            roadmapService.refreshFromStorage()
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
            // TEMPORARY: subscription / favorites sync disabled (no gating in this build).
        }
    }
    
    private func greetingSection(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("home.brand.title".localized)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(greetingSubtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.82))
                }

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Colors.primaryLight.opacity(0.9), Theme.Colors.primary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 44, height: 44)
                        Text(profileBadgeText)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.openSettingsButton")
            }

            PillSegmentedControl(
                items: [
                    "home.tab.focus".localized,
                    "home.tab.tasks".localized,
                    "home.tab.guides".localized
                ],
                selection: $homeTab
            )
            .padding(.top, Theme.Spacing.xs)
        }
        .padding(.top, topInset + Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg + Self.sheetCornerRadius)
        .background(
            ZStack {
                Theme.Colors.ink

                HStack {
                    Spacer()
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.06))
                        .rotationEffect(.degrees(-25))
                        .offset(x: 20, y: -10)
                }
            }
        )
        .overlay(alignment: .topTrailing) {
            Rectangle()
                .fill(Theme.Colors.accent.opacity(0.10))
                .frame(width: 180, height: 120)
                .blur(radius: 50)
                .offset(x: 40, y: -20)
                .allowsHitTesting(false)
        }
    }
    
    // MARK: - Simplified Hero (for debugging)
    private var simplifiedHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dynamicGreeting)
                .font(.title.bold())
                .foregroundColor(.primary)
            
            Text(lockManager.isRegistered
                ? "home.hero.subtitle.registered".localized(with: lockManager.userName)
                : "home.hero.subtitle.guest".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.Colors.gradientSoft)
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
            userName: lockManager.isRegistered ? lockManager.userName : "home.friend".localized,
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
            SectionHeader("home.focus".localized)
            
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
            SectionHeader("home.insider".localized)
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
    
    // PHASE 4: Re-enable when Roadmap flow is production-ready.
//    private var journeyRoadmapSection: some View {
//        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
//            SectionHeader("home.roadmap".localized)
//
//            NavigationLink {
//                MountainRoadmapView()
//                    .environmentObject(appContainer)
//            } label: {
//                MountainRoadmapPreviewCard()
//                    .environmentObject(appContainer)
//            }
//            .buttonStyle(.plain)
//        }
//        .padding(.horizontal, Theme.Spacing.lg)
//    }
    
    // helper funcs removed (moved into IntegrationProgressCard)
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            SectionHeader("home.quick_actions".localized)
            
            LazyVGrid(columns: quickActionColumns, spacing: 12) {
                ForEach(quickActionItems) { item in
                    HomeQuickActionTile(item: item)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    // MARK: - Focus tab (mockup layout)

    private var focusTabContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            todayFocusCardSection
            mockupQuickActionsSection
            swissMomentsGallerySection
        }
        .padding(.bottom, Theme.Spacing.xl)
    }

    private var todayFocusCardSection: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            HomeFocusProgressRing(
                progress: todayFocusProgress,
                percent: todayFocusPercent,
                style: .ink
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("home.todays_focus.title".localized)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(todayFocusMotivation)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "scope")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.Colors.primaryLight)
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(HomeInkSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(HomeInkSurface.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .accessibilityIdentifier("home.todaysFocusCard")
    }

    private var mockupQuickActionsSection: some View {
        LazyVGrid(columns: quickActionColumns, spacing: 12) {
            ForEach(mockupActionItems) { item in
                HomeMockupGridTile(item: item)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var swissMomentsGallerySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("home.swiss_moments.title".localized)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Button {
                    NotificationCenter.default.post(name: .switchTab, object: 2)
                } label: {
                    Text("home.swiss_moments.view_all".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(swissMomentGalleryItems) { item in
                        HomeSwissMomentPhotoCard(item: item) {
                            openSwissMoment(item)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    private var mockupActionItems: [HomeMockupGridItem] {
        [
            HomeMockupGridItem(
                icon: "doc.richtext",
                title: "qa.cv_builder".localized,
                subtitle: "qa.cv_builder.subtitle".localized,
                accentColor: Theme.Colors.primaryLight,
                accessibilityIdentifier: "home.quickAction.cvBuilder"
            ) {
                showCVBuilder = true
            },
            HomeMockupGridItem(
                icon: "doc.text",
                title: "qa.templates.title".localized,
                subtitle: "qa.templates.subtitle".localized,
                accentColor: Theme.Colors.accentCoral,
                accessibilityIdentifier: "home.quickAction.templates"
            ) {
                showTemplates = true
            },
            HomeMockupGridItem(
                icon: "map.fill",
                title: "qa.map".localized,
                subtitle: "qa.map.subtitle".localized,
                accentColor: Color(red: 0.92, green: 0.78, blue: 0.28),
                accessibilityIdentifier: "home.quickAction.map"
            ) {
                NotificationCenter.default.post(name: .switchTab, object: 2)
            },
            HomeMockupGridItem(
                icon: "book.fill",
                title: "qa.guides".localized,
                subtitle: "qa.guides.subtitle".localized,
                accentColor: Color(red: 0.45, green: 0.62, blue: 0.88),
                accessibilityIdentifier: "home.quickAction.guides"
            ) {
                NotificationCenter.default.post(
                    name: .switchTab,
                    object: SwitchTabPayload(tab: 1, section: .guides)
                )
            }
        ]
    }

    private var swissMomentGalleryItems: [HomeSwissMomentGalleryItem] {
        [
            HomeSwissMomentGalleryItem(
                id: "grindelwald",
                title: "Grindelwald",
                subtitle: "home.swiss_moments.canton.be".localized,
                imageName: "swiss-moment-grindelwald",
                latitude: 46.6244,
                longitude: 8.0414,
                spanDelta: 0.12
            ),
            HomeSwissMomentGalleryItem(
                id: "zurich",
                title: "Zürich",
                subtitle: "home.swiss_moments.canton.zh".localized,
                imageName: "swiss-moment-zurich",
                cityHubSlug: "zurich",
                latitude: 47.3769,
                longitude: 8.5417,
                spanDelta: 0.09
            ),
            HomeSwissMomentGalleryItem(
                id: "luzern",
                title: "Luzern",
                subtitle: "home.swiss_moments.canton.lu".localized,
                imageName: "swiss-moment-luzern",
                latitude: 47.0502,
                longitude: 8.3093,
                spanDelta: 0.09
            ),
            HomeSwissMomentGalleryItem(
                id: "geneva",
                title: "Genève",
                subtitle: "home.swiss_moments.canton.ge".localized,
                imageName: "swiss-moment-geneva",
                latitude: 46.2044,
                longitude: 6.1432,
                spanDelta: 0.09
            )
        ]
    }

    private func openSwissMoment(_ item: HomeSwissMomentGalleryItem) {
        if let slug = item.cityHubSlug, CityHubRegistry.hub(for: slug) != nil {
            appContainer.telemetry.retention(
                .contentOpened,
                source: "home",
                meta: ["type": "city_hub", "id": item.id]
            )
            cityHubRoute = CityHubRoute(slug: slug)
            return
        }
        openMomentOnMap(item)
    }

    private func openMomentOnMap(_ item: HomeSwissMomentGalleryItem) {
        MapFocusRouter.pending = MapFocusTarget(
            latitude: item.latitude,
            longitude: item.longitude,
            spanDelta: item.spanDelta
        )
        appContainer.telemetry.retention(
            .contentOpened,
            source: "home",
            meta: ["type": "swiss_moment_city", "id": item.id]
        )
        NotificationCenter.default.post(name: .switchTab, object: 2)
    }

    private var todayFocusPercent: Int {
        min(100, max(
            Int(roadmapService.overallProgress * 100),
            Int(firstWeekProgress * 100),
            min(statGuides * 8, 35)
        ))
    }

    private var todayFocusProgress: CGFloat {
        CGFloat(todayFocusPercent) / 100
    }

    private var todayFocusMotivation: String {
        if todayFocusPercent >= 70 {
            return "home.todays_focus.motivation_high".localized
        }
        if todayFocusPercent >= 35 {
            return "home.todays_focus.motivation_mid".localized
        }
        return "home.todays_focus.motivation_low".localized
    }

    private var greetingSubtitle: String {
        let name: String
        if lockManager.isRegistered, !lockManager.userName.isEmpty {
            let parts = lockManager.userName.split(separator: " ")
            name = parts.first.map(String.init) ?? lockManager.userName
        } else {
            name = "home.friend".localized
        }
        return "\(dynamicGreeting), \(name) 👋"
    }
    
    // PHASE 4: Re-enable when Jobs flow is production-ready.
//    private var bentoFeaturedQuickAction: BentoQuickActionItem {
//        BentoQuickActionItem(
//            icon: "briefcase.fill",
//            title: "qa.jobs.title",
//            subtitle: "qa.jobs.subtitle",
//            accentColor: Theme.Colors.accentTurquoise,
//            badgeText: "common.soon".localized,
//            isLocked: true
//        ) {
//            showJobs = true
//        }
//    }
    
    private var bentoPrimaryQuickActions: [BentoQuickActionItem] {
        // Завжди 2 елементи справа для правильного layout
        [
            BentoQuickActionItem(
                icon: "book.fill",
                title: "qa.guides",
                subtitle: "qa.guides.subtitle",
                accentColor: Theme.Colors.primary
            ) {
                NotificationCenter.default.post(name: .switchTab, object: 1)
            },
            BentoQuickActionItem(
                icon: "map.fill",
                title: "qa.map",
                subtitle: "qa.map.subtitle",
                accentColor: Color.orange
            ) {
                NotificationCenter.default.post(name: .switchTab, object: 2)
            }
        ]
    }
    
    private var bentoSecondaryQuickActions: [BentoQuickActionItem] {
        [
            // TODO: unhide when calculator is production-ready.
            BentoQuickActionItem(
                icon: "doc.richtext",
                title: "qa.cv_builder",
                subtitle: nil,
                accentColor: Theme.Colors.accent
            ) {
                showCVBuilder = true
            },
            BentoQuickActionItem(
                icon: "doc.text",
                title: "qa.templates_short",
                subtitle: nil,
                accentColor: Color.pink
            ) {
                showTemplates = true
            },
            BentoQuickActionItem(
                icon: "gearshape.fill",
                title: "settings.title",
                subtitle: nil,
                accentColor: Color.gray
            ) {
                NotificationCenter.default.post(name: .switchTab, object: 4)
            }
        ]
    }
    
    // MARK: - Jobs Promo Section
    // PHASE 4: Re-enable when Jobs flow is production-ready.
//    private var jobsPromoSection: some View {
//        VStack(spacing: 0) {
//            InteractiveCard(
//                icon: "briefcase.fill",
//                title: "qa.jobs.title".localized,
//                subtitle: "qa.jobs.subtitle".localized,
//                badge: "common.new".localized,
//                badgeColor: Theme.Colors.accent
//            ) { showJobs = true }
//            .buttonStyle(CardPressStyle())
//            .padding(.horizontal, Theme.Spacing.lg)
//        }
//    }
    
    // MARK: - Stats Section (Bento Grid)
    
    private var statsSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            SectionHeader("home.stats".localized)
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
            SectionHeader("home.recommendations".localized)
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
                onSelect: openGuideFromHome
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
    
    // MARK: - Pro Card (removed)
    private var proCardSection: some View {
        // TEMPORARY (App Store review): paywall UI removed.
        EmptyView()
    }
    
    // MARK: - Analytics Pinboard (Gamification)
    private var analyticsPinboard: some View {
        Button {
            showSweezyPassport = true
        } label: {
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
        }
        .buttonStyle(.plain)
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
        case 1: return "gamification.level.1".localized
        case 2: return "gamification.level.2".localized
        case 3: return "gamification.level.3".localized
        case 4: return "gamification.level.4".localized
        case 5: return "gamification.level.5".localized
        case 6: return "gamification.level.6".localized
        case 7: return "gamification.level.7".localized
        default: return "gamification.level.default".localized
        }
    }
    
    private var earnedBadges: [GamificationBadge] {
        var badges: [GamificationBadge] = []
        
        if appContainer.userStats.guidesReadCount >= 1 {
            badges.append(GamificationBadge(icon: "book.fill", title: "gamification.badge.reader".localized, color: Theme.Colors.info))
        }
        if appContainer.userStats.guidesReadCount >= 5 {
            badges.append(GamificationBadge(icon: "books.vertical.fill", title: "gamification.badge.bookworm".localized, color: Theme.Colors.accentTurquoise))
        }
        if appContainer.userStats.activeChecklistsCount >= 1 {
            badges.append(GamificationBadge(icon: "checklist", title: "gamification.badge.organizer".localized, color: Theme.Colors.success))
        }
        if estimatedHoursSaved >= 5 {
            badges.append(GamificationBadge(icon: "clock.fill", title: "gamification.badge.time_saver".localized, color: Theme.Colors.accent))
        }
        if estimatedHoursSaved >= 20 {
            badges.append(GamificationBadge(icon: "star.fill", title: "gamification.badge.superstar".localized, color: Theme.Colors.accentCoral))
        }
        
        return badges
    }
    
    // MARK: - Local Feed Chips
    private var localFeedChips: some View {
        VStack(spacing: Theme.Spacing.md) {
            SectionHeader("home.local_feed".localized)
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
                    SectionHeader("home.notifications".localized)
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
            SectionHeader("home.popular_guides".localized)
            KnowledgeMindMapView(
                guides: cachedFeaturedGuides.isEmpty ? featuredGuides : cachedFeaturedGuides,
                onSelect: openGuideFromHome
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
    
    // PHASE 4: Re-enable when News carousel flow is production-ready.
//    private var newsSection: some View {
//        VStack(spacing: Theme.Spacing.lg) {
//            SectionHeader("whats_new.title".localized)
//
//			let items: [NewsItem] = {
//				let lang = appContainer.currentLocale.identifier
//				let primary = appContainer.contentService.latestNews(limit: 8, language: lang)
//				let rawItems = primary.isEmpty
//				? appContainer.contentService.latestNews(limit: 8, language: nil)
//				: primary
//                return validatedHomeNewsItems(from: rawItems)
//			}()
//
//			if items.isEmpty {
//				Text("news.empty".localized)
//					.font(Theme.Typography.caption)
//					.foregroundColor(Theme.Colors.textTertiary)
//					.padding(.horizontal, Theme.Spacing.lg)
//			} else {
//				NewsCarousel(items: items) { item in
//                    handleNewsCardTap(item)
//				}
//			}
//        }
//    }
    
    // MARK: - Telegram Section
    
    private var telegramSection: some View {
        TelegramCommunityCard()
            .padding(.horizontal, Theme.Spacing.lg)
    }
    
    // MARK: - Helpers (must stay inside HomeViewRedesigned for @EnvironmentObject access)
    
    private var shouldShowPriorityTasksSection: Bool {
        !priorityTasks.isEmpty
    }
    
    private var priorityTasks: [FirstWeekChecklistService.TaskItem] {
        let recentCompleted = checklistTasks
            .filter { $0.isDone && recentlyCompletedTaskIDs.contains($0.id) }
            .sorted { $0.dueDate < $1.dueDate }
        let pending = checklistTasks
            .filter { !$0.isDone }
            .sorted { $0.dueDate < $1.dueDate }
        var visible: [FirstWeekChecklistService.TaskItem] = []
        for task in recentCompleted + pending {
            guard !visible.contains(where: { $0.id == task.id }) else { continue }
            visible.append(task)
            if visible.count == 3 { break }
        }
        return visible
    }
    
    private var compactProgressSection: some View {
        Button {
            showSweezyPassport = true
        } label: {
            compactProgressContent
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var embeddedPassportSection: some View {
        Button {
            showSweezyPassport = true
        } label: {
            compactProgressContent
        }
        .buttonStyle(.plain)
    }

    private var compactProgressContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("Sweezy Passport", systemImage: "person.text.rectangle.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("Open")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }

            HStack(spacing: Theme.Spacing.md) {
                CompactProgressPill(
                    icon: "bolt.fill",
                    value: "\(statXP)",
                    label: "XP",
                    color: Theme.Colors.primaryLight
                )

                CompactProgressPill(
                    icon: "star.fill",
                    value: "\(statLevel)",
                    label: "Status",
                    color: Theme.Colors.accent
                )

                CompactProgressPill(
                    icon: "flame.fill",
                    value: "\(appContainer.gamification.currentStreak())",
                    label: "Streak",
                    color: Theme.Colors.accentCoral
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous)
                .fill(Theme.Colors.inkElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous)
                .stroke(Theme.Colors.inkBorder, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private var homeTabEmptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(Theme.Colors.primary)
            Text("home.tab.empty".localized)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .paperCard()
        .padding(.horizontal, Theme.Spacing.lg)
    }

    @ViewBuilder
    private var nextBestActionSection: some View {
        if let action = nextBestAction {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("home.focus".localized)
                        .font(.title3.weight(.bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("home.next_action.subtitle".localized)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Button {
                    handleNextBestActionTap(action.destination)
                } label: {
                    HStack(alignment: .center, spacing: Theme.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(action.accent.opacity(0.14))
                                .frame(width: 56, height: 56)

                            Image(systemName: action.iconName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(action.accent)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("home.focus.today_label".localized)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                            Text(action.title)
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                            Text(action.detail)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 12)

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(action.accent)
                    }
                    .padding(Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Theme.Colors.paperCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(action.accent.opacity(0.22), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)

                HStack(spacing: Theme.Spacing.sm) {
                    Label(action.progressLabel, systemImage: "chart.line.uptrend.xyaxis")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)

                    Spacer()

                    Button(action.ctaTitle) {
                        handleNextBestActionTap(action.destination)
                    }
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(action.accent)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    private var roadmapEntrySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .center) {
                Text("home.roadmap".localized)
                    .font(.title3.weight(.bold))
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                Button("home.next_action.open_roadmap".localized) {
                    showRoadmap = true
                }
                .font(Theme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.primary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Button {
                showRoadmap = true
            } label: {
                MountainRoadmapPreviewCard()
                    .environmentObject(appContainer)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
    
    private var priorityTasksSection: some View {
        let priorityBorderColor: Color = Theme.Colors.adaptiveBorder
        let priorityShadowColor: Color = Color.black.opacity(0.05)

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("home.priority_tasks".localized)
                        .font(.title3.weight(.bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(priorityTasksSubtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                Spacer()
                
                Button("home.see_all".localized) {
                    NotificationCenter.default.post(
                        name: .switchTab,
                        object: SwitchTabPayload(tab: 1, section: .checklists)
                    )
                }
                .font(Theme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.accentTurquoise)
                .accessibilityIdentifier("home.showAllTasksButton")
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.adaptiveSurface)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.accentTurquoise, Theme.Colors.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * firstWeekProgress)
                }
            }
            .frame(height: 8)
            
            VStack(spacing: 10) {
                ForEach(priorityTasks) { task in
                    PriorityTaskRow(
                        task: task,
                        countdownText: countdownString(to: task.dueDate),
                        isRecentlyCompleted: recentlyCompletedTaskIDs.contains(task.id),
                        onToggle: {
                            let taskWasDone = task.isDone
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                appContainer.firstWeekService.toggle(task.id)
                                if taskWasDone {
                                    _ = recentlyCompletedTaskIDs.remove(task.id)
                                } else {
                                    _ = recentlyCompletedTaskIDs.insert(task.id)
                                }
                            }

                            guard !taskWasDone else { return }
                            let completedTaskID = task.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    _ = recentlyCompletedTaskIDs.remove(completedTaskID)
                                }
                            }
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .scale(scale: 0.92).combined(with: .opacity)))
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.Colors.paperCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(priorityBorderColor, lineWidth: 1)
        )
        .shadow(color: priorityShadowColor, radius: 10, x: 0, y: 4)
        .padding(.horizontal, Theme.Spacing.lg)
        .accessibilityIdentifier("home.priorityTasksSection")
    }
    
    private var shouldShowProgressSection: Bool {
        statXP > 0 || appContainer.gamification.currentStreak() > 0 || statGuides > 0 || statChecklists > 0
    }

    private var shouldShowRoadmapEntrySection: Bool {
        roadmapService.currentLevel != nil
    }
    
    private var quickActionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }
    
    private var quickActionItems: [HomeQuickActionItem] {
        [
            HomeQuickActionItem(icon: "doc.richtext", title: "qa.cv_builder".localized, accentColor: Theme.Colors.primary, accessibilityIdentifier: "home.quickAction.cvBuilder") {
                showCVBuilder = true
            },
            HomeQuickActionItem(icon: "doc.text", title: "qa.templates_short".localized, accentColor: Theme.Colors.accentCoral, accessibilityIdentifier: "home.quickAction.templates") {
                showTemplates = true
            },
            HomeQuickActionItem(icon: "map.fill", title: "qa.map".localized, accentColor: Theme.Colors.accent, accessibilityIdentifier: "home.quickAction.map") {
                NotificationCenter.default.post(name: .switchTab, object: 2)
            },
            HomeQuickActionItem(icon: "book.fill", title: "qa.guides".localized, accentColor: Theme.Colors.primaryLight, accessibilityIdentifier: "home.quickAction.guides") {
                NotificationCenter.default.post(
                    name: .switchTab,
                    object: SwitchTabPayload(tab: 1, section: .guides)
                )
            }
        ]
    }
    
    private var shouldShowCuratedContentSection: Bool {
        !topRecommendedCards.isEmpty || featuredNewsItem != nil
    }
    
    private var curatedContentSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            SectionHeader("home.recommended_content".localized)
            
            if !topRecommendedCards.isEmpty {
                StackedRecommendationList(
                    cards: topRecommendedCards,
                    onSelect: openGuideFromHome
                )
                .padding(.horizontal, Theme.Spacing.lg)
            }
            
            if let featuredNewsItem {
                FeaturedNewsInlineCard(item: featuredNewsItem) {
                    handleNewsCardTap(featuredNewsItem)
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }
    
    private var topRecommendedCards: [RecommendationDisplay] {
        recommendedGuides.prefix(2).map {
            RecommendationDisplay(
                guide: $0,
                badgeText: badgeFor(guide: $0),
                badgeColor: badgeColorFor(guide: $0),
                tagline: taglineForGuide($0)
            )
        }
    }
    
    private var featuredNewsItem: NewsItem? {
        let lang = appContainer.currentLocale.identifier
        let localized = appContainer.contentService.latestNews(limit: 3, language: lang)
        let rawItems = localized.isEmpty
            ? appContainer.contentService.latestNews(limit: 3, language: nil)
            : localized
        return validatedHomeNewsItems(from: rawItems).first
    }
    
    private func validatedHomeNewsItems(from items: [NewsItem]) -> [NewsItem] {
        items.filter(isValidHomeNewsItem)
    }
    
    private func isValidHomeNewsItem(_ item: NewsItem) -> Bool {
        let hasContent = !(item.content?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let urlString = item.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidURL = URL(string: urlString) != nil
        return hasContent || hasValidURL
    }
    
    private func handleNewsCardTap(_ news: NewsItem) {
        appContainer.telemetry.retention(
            .contentOpened,
            source: "home",
            meta: ["type": "news", "id": news.id.uuidString]
        )
        let trimmedContent = news.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedContent.isEmpty {
            selectedNews = news
            return
        }
        
        let trimmedURL = news.url.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmedURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func openGuideFromHome(_ guide: Guide) {
        appContainer.telemetry.retention(
            .contentOpened,
            source: "home",
            meta: ["type": "guide", "id": guide.id.uuidString, "category": guide.category.rawValue]
        )
        selectedGuide = guide
    }
    
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
            return "home.no_critical_tasks".localized
        }
        if tasks.count == 1 {
            return first.title
        }
        return "home.focus.plus_more_format".localized(with: first.title, tasks.count - 1)
    }
    
    private var dynamicGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "home.greeting.morning".localized
        case 12..<17: return "home.greeting.afternoon".localized
        case 17..<22: return "home.greeting.evening".localized
        default: return "home.greeting.night".localized
        }
    }
    
    private var greetingTitle: String {
        if lockManager.isRegistered, !lockManager.userName.isEmpty {
            return "home.greeting.hello_name".localized(with: lockManager.userName)
        }
        return "home.greeting.hello".localized
    }
    
    private var formattedGreetingDate: String {
        let formatter = DateFormatter()
        formatter.locale = appContainer.currentLocale
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: dayToken).capitalized
    }
    
    private var profileBadgeText: String {
        if lockManager.isRegistered, let first = lockManager.userName.first {
            return String(first).uppercased()
        }
        return "⚙︎"
    }
    
    private var firstWeekProgress: CGFloat {
        CGFloat(appContainer.firstWeekService.progress)
    }
    
    private var priorityTasksSubtitle: String {
        let completed = checklistTasks.filter(\.isDone).count
        let total = checklistTasks.count
        guard total > 0 else { return "" }
        return "home.priority_tasks.progress_format".localized(with: completed, total)
    }

    private var nextBestAction: NextBestActionDescriptor? {
        if let nextTask = appContainer.firstWeekService.nextDueTask {
            let countdown = countdownString(to: nextTask.dueDate) ?? "home.countdown.today".localized
            return NextBestActionDescriptor(
                title: nextTask.title,
                detail: "\("home.reminder".localized) • \(countdown)",
                progressLabel: priorityTasksSubtitle,
                ctaTitle: "home.next_action.open_checklist".localized,
                iconName: "checklist.checked",
                accent: Theme.Colors.accentTurquoise,
                destination: .checklists
            )
        }

        if let currentLevel = roadmapService.currentLevel {
            return NextBestActionDescriptor(
                title: currentLevel.title,
                detail: roadmapService.nextMilestone.isEmpty ? currentLevel.subtitle : roadmapService.nextMilestone,
                progressLabel: "home.next_action.roadmap_progress_format".localized(with: Int(roadmapService.levelProgress(for: currentLevel.id) * 100)),
                ctaTitle: "home.next_action.open_roadmap".localized,
                iconName: currentLevel.iconName,
                accent: Theme.Colors.primary,
                destination: .roadmap
            )
        }

        return nil
    }

    private func handleNextBestActionTap(_ destination: NextBestActionDescriptor.Destination) {
        switch destination {
        case .checklists:
            NotificationCenter.default.post(
                name: .switchTab,
                object: SwitchTabPayload(tab: 1, section: .checklists)
            )
        case .roadmap:
            showRoadmap = true
        }
        appContainer.telemetry.retention(
            .nextActionTapped,
            source: "home",
            meta: ["destination": destination.telemetryName]
        )
    }

    private func logNextBestActionViewedIfNeeded() {
        guard let action = nextBestAction else { return }
        guard lastLoggedNextActionTitle != action.title else { return }
        lastLoggedNextActionTitle = action.title
        appContainer.telemetry.retention(
            .nextActionViewed,
            source: "home",
            meta: [
                "destination": action.destination.telemetryName,
                "title": action.title
            ]
        )
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
        let cantonName = appContainer.userProfile?.canton.localizedName ?? "home.switzerland_genitive".localized
        return [
            InsiderMoment(title: "home.insider.benefits_format".localized(with: cantonName), summary: "home.insider.benefits_summary".localized, icon: "bolt.fill", tag: "Benefits", accent: Theme.Colors.accentTurquoise, gradient: [Theme.Colors.primary, Theme.Colors.accentTurquoise], isNew: true, count: 5),
            InsiderMoment(title: "Career Pulse", summary: "home.insider.jobs_summary".localized, icon: "chart.line.uptrend.xyaxis", tag: "Jobs", accent: Theme.Colors.accentCoral, gradient: [Theme.Colors.accentCoral, Theme.Colors.accent], isNew: false, count: 3)
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
        let cantonName = appContainer.userProfile?.canton.localizedName ?? "home.switzerland".localized
        return "\(cantonName) • \(guide.category.localizedName)"
    }
    
    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
    
    private var estimatedHoursSaved: Int {
        max(1, appContainer.userStats.guidesReadCount * 2 + appContainer.userStats.activeChecklistsCount)
    }
    
    private var upcomingChips: [ChipItem] {
        var arr: [ChipItem] = []
        let soonTasks = checklistTasks.filter { !$0.isDone }.sorted { $0.dueDate < $1.dueDate }.prefix(3)
        for task in soonTasks {
            arr.append(.init(text: "home.deadline_format".localized(with: task.title), color: Theme.Colors.warning, countdown: countdownString(to: task.dueDate)))
        }
        return arr
    }
    
    private func countdownString(to date: Date) -> String? {
        let comps = Calendar.current.dateComponents([.day, .hour], from: Date(), to: date)
        guard let day = comps.day, let hour = comps.hour else { return nil }
        if day <= 0 && hour <= 0 { return "home.countdown.today".localized }
        if day > 0 { return "home.countdown.in_days_format".localized(with: day) }
        return "home.countdown.in_hours_format".localized(with: max(1, hour))
    }
    
    private var ambientAlerts: [AmbientAlert] {
        var alerts: [AmbientAlert] = []
        if let next = appContainer.firstWeekService.nextDueTask {
            alerts.append(AmbientAlert(title: "home.reminder".localized, detail: next.title, icon: "bell.badge.fill", accent: Theme.Colors.warning, time: countdownString(to: next.dueDate) ?? "home.countdown.today".localized))
        }
        return alerts
    }
    
    private var nextFocusTitle: String {
        todayFocus.first?.title ?? "home.no_critical_tasks".localized
    }
    
    private var documentsProgress: Double {
        min(1.0, Double(appContainer.userStats.activeChecklistsCount) / 5.0)
    }
    
    private var careerProgress: Double {
        min(1.0, Double(appContainer.userStats.guidesReadCount) / 6.0)
    }
    
    private var primaryGoalName: String {
        appContainer.userProfile?.goals.first?.localizedName ?? "home.career_genitive".localized
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
            if let url = URL(string: "https://t.me/sweezyxswiss") {
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
                    .fill(Theme.Colors.accentTurquoise.opacity(0.15))
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
                                    colors: [telegramBlue, Theme.Colors.accentTurquoise],
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
                        
                        Text("home.telegram.community".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        // Stats
                        HStack(spacing: 12) {
                            Label("500+", systemImage: "person.2.fill")
                            Label("home.telegram.support".localized, systemImage: "bubble.left.and.bubble.right.fill")
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
                                Theme.Colors.adaptiveSurface,
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

private struct CompactProgressPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                // Always white: this pill lives on the ink header in both schemes
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text(label)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(.white.opacity(0.55))
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct HomeQuickActionItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let accentColor: Color
    let accessibilityIdentifier: String
    let action: () -> Void
}

private struct HomeQuickActionTile: View {
    let item: HomeQuickActionItem

    var body: some View {
        Button(action: item.action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(item.accentColor.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(item.accentColor)
                }

                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.Colors.paperCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.Colors.adaptiveBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98))
        .accessibilityIdentifier(item.accessibilityIdentifier)
    }
}

private struct HomeMockupGridItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let accessibilityIdentifier: String
    let action: () -> Void
}

private enum HomeInkSurface {
    static let card = Color(red: 0.10, green: 0.15, blue: 0.12)
    static let cardBorder = Color.white.opacity(0.08)
}

private struct HomeMockupGridTile: View {
    let item: HomeMockupGridItem

    var body: some View {
        Button(action: item.action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Capsule()
                        .fill(item.accentColor.opacity(0.18))
                        .frame(width: 48, height: 34)
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(item.accentColor)
                }

                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.52))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(HomeInkSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(HomeInkSurface.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98))
        .accessibilityIdentifier(item.accessibilityIdentifier)
    }
}

private struct CityHubRoute: Identifiable, Hashable {
    let slug: String
    var id: String { slug }
}

private struct HomeSwissMomentGalleryItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let imageName: String
    var cityHubSlug: String? = nil
    let latitude: Double
    let longitude: Double
    let spanDelta: Double
}

private struct HomeSwissMomentPhotoCard: View {
    let item: HomeSwissMomentGalleryItem
    let onTap: () -> Void

    private let cardSize = CGSize(width: 148, height: 196)

    var body: some View {
        Button(action: onTap) {
            Image(item.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: cardSize.width, height: cardSize.height)
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.35), .black.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 96)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(item.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.88))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .frame(width: cardSize.width, alignment: .leading)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98))
    }
}

private struct HomeFocusProgressRing: View {
    enum Style {
        case paper
        case ink
    }

    let progress: CGFloat
    let percent: Int
    var style: Style = .paper

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: 7)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Theme.Colors.primaryLight,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(percent)%")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(labelColor)
        }
        .frame(width: 68, height: 68)
    }

    private var trackColor: Color {
        switch style {
        case .paper: Theme.Colors.primary.opacity(0.12)
        case .ink: Color.white.opacity(0.10)
        }
    }

    private var labelColor: Color {
        switch style {
        case .paper: Theme.Colors.textPrimary
        case .ink: .white
        }
    }
}

private struct PriorityTaskRow: View {
    let task: FirstWeekChecklistService.TaskItem
    let countdownText: String?
    let isRecentlyCompleted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke((task.isDone ? Color.green : Theme.Colors.accentTurquoise).opacity(0.55), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if task.isDone {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(task.isDone ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                        .strikethrough(task.isDone, color: Theme.Colors.textTertiary)
                        .multilineTextAlignment(.leading)
                    if let details = task.details, !details.isEmpty {
                        Text(details)
                            .font(Theme.Typography.caption)
                            .foregroundColor(task.isDone ? Theme.Colors.textTertiary : Theme.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if task.isDone {
                    Label("common.done".localized, systemImage: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.12))
                        )
                } else if let countdownText {
                    Text(countdownText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.Colors.accentTurquoise)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.accentTurquoise.opacity(0.12))
                        )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(task.isDone ? Color.green.opacity(0.08) : Theme.Colors.secondaryBackground.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(task.isDone ? Color.green.opacity(0.22) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isRecentlyCompleted ? 1.015 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: task.isDone)
            .animation(.easeInOut(duration: 0.25), value: isRecentlyCompleted)
        }
        .buttonStyle(.plain)
    }
}

private struct FeaturedNewsInlineCard: View {
    let item: NewsItem
    let action: () -> Void
    
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
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    NewsTagChip(text: item.source, color: accentColor)
                    Spacer()
                    Text(relativeDate(item.publishedAt))
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                
                Text(item.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(item.summary)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                HStack {
                    Text("home.read_more".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentColor)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(accentColor)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.Colors.paperCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(accentColor.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98))
    }
    
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
        case 1: return "gamification.level.1".localized
        case 2: return "gamification.level.2".localized
        case 3: return "gamification.level.3".localized
        case 4: return "gamification.level.4".localized
        case 5: return "gamification.level.5".localized
        case 6: return "gamification.level.6".localized
        case 7: return "gamification.level.7".localized
        default: return "gamification.level.default".localized
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
                        label: "gamification.guides".localized,
                        color: Theme.Colors.primary
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                    
                    BentoMiniCard(
                        icon: "checkmark.circle.fill",
                        value: "\(checklists)",
                        label: "home.stats.checklists".localized,
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
                    label: "gamification.hours_saved".localized,
                    color: Theme.Colors.accentTurquoise
                )
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                
                BentoMediumCard(
                    icon: "doc.text.fill",
                    value: "\(templates)",
                    label: "home.stats.templates".localized,
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
    
    private var levelAccent: Color {
        switch level {
        case 1: return Theme.Colors.accentTurquoise
        case 2: return Theme.Colors.primary
        case 3: return Theme.Colors.accent
        case 4: return Theme.Colors.accentCoral
        case 5: return Theme.Colors.accentYellowSoft
        default: return Theme.Colors.accent
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.Colors.paperCard)
            
            HStack(spacing: 14) {
                // Level ring
                ZStack {
                    Circle()
                        .stroke(levelAccent.opacity(0.15), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [levelAccent, levelAccent.opacity(0.6), levelAccent],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    Circle()
                        .fill(levelAccent.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Text("\(level)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(levelTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text("\(xp) / \(xpNext) XP")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    // Mini XP bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.Colors.adaptiveSurface)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [levelAccent, levelAccent.opacity(0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 5)
                    .frame(maxWidth: 110)
                    
                    Text("gamification.to_level_format".localized(with: level + 1))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                
                Spacer()
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [levelAccent.opacity(0.35), Theme.Colors.adaptiveBorder.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
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
                .fill(Theme.Colors.paperCard)
            
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
                        .foregroundColor(Theme.Colors.textPrimary)
                    
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
                .stroke(color.opacity(0.2), lineWidth: 1)
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
        case .lifestyle: return Color(red: 0.2, green: 0.72, blue: 0.7)
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
                        .foregroundColor(Theme.Colors.textSecondary)
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
                    
                }
            )
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            
        }
        .buttonStyle(RecommendationCardPressStyle())
    }
    
    private var categoryIcon: String {
        switch card.guide.category {
        case .integration: return "person.badge.plus"
        case .lifestyle: return "sun.horizon.fill"
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
        ["weekday.short.mon", "weekday.short.tue", "weekday.short.wed", "weekday.short.thu", "weekday.short.fri", "weekday.short.sat", "weekday.short.sun"][index].localized
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
                            Theme.Colors.primary.opacity(0.15),
                            Theme.Colors.primary.opacity(0.08)
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
                label: "home.focus.today".localized,
                color: Color.orange
            )
            
            Divider()
                .frame(height: 30)
                .background(Color.white.opacity(0.2))
            
            FocusSummaryItem(
                icon: "calendar",
                value: "\(weekTasks.count)",
                label: "home.focus.week".localized,
                color: Theme.Colors.accentTurquoise
            )
            
            Divider()
                .frame(height: 30)
                .background(Color.white.opacity(0.2))
            
            FocusSummaryItem(
                icon: "checkmark.circle.fill",
                value: "\(completedPercentage)%",
                label: "home.focus.completed".localized,
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
                    .fill(isUrgent ? Color.orange.opacity(0.2) : Theme.Colors.accentTurquoise.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: isUrgent ? "exclamationmark.circle.fill" : "arrow.right.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isUrgent ? .orange : .cyan)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("home.focus.next_up".localized)
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
                Text("home.focus.today_label".localized)
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
                            isUrgent ? Color.orange.opacity(0.3) : Theme.Colors.adaptiveSurface,
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
                Text("home.focus.tasks_for_day_format".localized(with: day.shortName, day.dayNumber))
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
                            .fill(day.isToday ? Theme.Colors.accentTurquoise : Color.gray.opacity(0.5))
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
                        Text("home.focus.plus_more_tasks_format".localized(with: tasks.count - 5))
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
                        .stroke(Theme.Colors.adaptiveSurface, lineWidth: 1)
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
                Text("home.focus.no_tasks".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("home.focus.day_free_format".localized(with: dayName))
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
                                    colors: [Theme.Colors.accentTurquoise, Theme.Colors.primary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: Theme.Colors.accentTurquoise.opacity(0.5), radius: 8, x: 0, y: 4)
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
                            .fill(day.isToday ? Theme.Colors.accentTurquoise : Color.gray.opacity(0.5))
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
                    .foregroundColor(Theme.Colors.textSecondary)
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
                                colors: [Theme.Colors.accentTurquoise.opacity(0.15), Color.clear],
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
                                colors: [Theme.Colors.accent.opacity(0.12), Color.clear],
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
                        .shadow(color: Theme.Colors.accentTurquoise.opacity(glowOpacity), radius: 12, x: 0, y: 0)
                        .shadow(color: Theme.Colors.accent.opacity(glowOpacity * 0.6), radius: 20, x: 0, y: 0)
                    
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
                                                    colors: [Color.white.opacity(0.6), Theme.Colors.adaptiveSurface],
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
                        .accessibilityHint(Text("home.accessibility.stage_details".localized))
                        
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
                                    Theme.Colors.accentTurquoise.opacity(0.1),
                                    Theme.Colors.accent.opacity(0.1),
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
                    .foregroundColor(Theme.Colors.textSecondary)
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
            .fill(Theme.Colors.textSecondary)
            .frame(width: 4, height: 4)
            .offset(y: 6)
        Text(text)
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.textSecondary)
            .multilineTextAlignment(.leading)
    }
}

// TEMPORARY (App Store review): paywall plan UI removed.

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
                                    Theme.Colors.adaptiveSurface,
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
    
    private var levelAccent: Color {
        switch level {
        case 1: return Theme.Colors.accentTurquoise
        case 2: return Theme.Colors.primary
        case 3: return Theme.Colors.accent
        case 4: return Theme.Colors.accentCoral
        case 5: return Theme.Colors.accentYellowSoft
        default: return Theme.Colors.accent
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Top section: Level badge + Info + XP earned ──
            HStack(alignment: .center, spacing: 16) {
                // Level ring
                ZStack {
                    // Progress ring (background track)
                    Circle()
                        .stroke(levelAccent.opacity(0.15), lineWidth: 4)
                        .frame(width: 64, height: 64)
                    
                    // Progress ring (filled arc)
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            AngularGradient(
                                colors: [levelAccent, levelAccent.opacity(0.6), levelAccent],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    
                    // Inner circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    levelAccent.opacity(0.15),
                                    levelAccent.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    // Level number
                    Text("\(level)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                
                // Title + XP text
                VStack(alignment: .leading, spacing: 4) {
                    Text(levelTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text("\(currentXP) / \(xpForNextLevel) XP")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                Spacer()
                
                // XP earned badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(lastAward)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(levelAccent)
                        .scaleEffect(showXPGain ? 1.15 : 1.0)
                    
                    Text("gamification.xp_earned".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // ── Progress bar ──
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Theme.Colors.adaptiveSurface)
                    
                    // Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [levelAccent, levelAccent.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * animatedProgress))
                        .shadow(color: levelAccent.opacity(0.5), radius: 6, y: 0)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            
            // ── Stats row ──
            HStack(spacing: 0) {
                LevelStatItem(icon: "bolt.fill", value: "+\(todayXP)", label: "gamification.xp_today".localized, color: levelAccent)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Theme.Colors.adaptiveBorder.opacity(0.3))
                    .frame(width: 1, height: 28)
                
                LevelStatItem(icon: "clock.fill", value: "\(hoursSaved)", label: "gamification.hours_saved".localized, color: .orange)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Theme.Colors.adaptiveBorder.opacity(0.3))
                    .frame(width: 1, height: 28)
                
                LevelStatItem(icon: "book.fill", value: "\(guidesRead)", label: "gamification.guides".localized, color: Theme.Colors.primary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            
            // Next level hint
            HStack {
                Spacer()
                Text("gamification.to_level_format".localized(with: level + 1))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            
            // ── Badges section ──
            if !badges.isEmpty {
                Rectangle()
                    .fill(Theme.Colors.adaptiveBorder.opacity(0.25))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("home.achievements".localized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(badges) { badge in
                                BadgeChip(badge: badge)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.Colors.paperCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [levelAccent.opacity(0.4), Theme.Colors.adaptiveBorder.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: levelAccent.opacity(0.12), radius: 20, y: 8)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3)) {
                animatedProgress = progress
            }
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

// MARK: - Level Card Sub-components

private struct LevelStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .monospacedDigit()
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
                .fill(Theme.Colors.paperCard)
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
                                                colors: [Color.white.opacity(0.5), Theme.Colors.adaptiveSurface],
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
                        .foregroundColor(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
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
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            onSelect(guide)
                        } label: {
                            Text("common.open".localized)
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
        case .lifestyle: return Color(red: 0.2, green: 0.72, blue: 0.7)
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
        case .lifestyle: return "sun.horizon.fill"
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
