import SwiftUI

private struct HomeExploreItem: Identifiable {
    let id: String
    let scene: String
    let titleKey: String
    let subtitleKey: String
    let icon: String
    let tab: Int
}

struct JourneyHomeView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showRoadmap = false
    @State private var showMyPlan = false
    @State private var showSubscription = false
    @State private var showCareerHub = false
    @State private var showSettings = false
    /// Vertical scroll position: negative while pulling down, positive once scrolled up.
    @State private var scrollOffset: CGFloat = 0
    @State private var heroDrift = false

    private let actions: [(String, String, DovidnykRouteSection?)] = [
        ("doc.text.fill", "journey.home.action.documents".localized, .checklists),
        ("briefcase.fill", "Career Hub", .tools),
        ("house.fill", "journey.home.action.housing".localized, .guides),
        ("cross.case.fill", "journey.home.action.health".localized, .guides)
    ]
    /// Same paper/ink pairs as the category stickers elsewhere, so a topic keeps its colour app-wide.
    private let actionSwatches = [
        JourneyCategoryPalette.sky,
        JourneyCategoryPalette.sand,
        JourneyCategoryPalette.lime,
        JourneyCategoryPalette.coral
    ]

    private let exploreItems: [HomeExploreItem] = [
        HomeExploreItem(id: "directory", scene: "directory", titleKey: "journey.tab.directory", subtitleKey: "journey.home.explore.directory", icon: "book.fill", tab: 1),
        HomeExploreItem(id: "map", scene: "map", titleKey: "journey.tab.map", subtitleKey: "journey.home.explore.map", icon: "map.fill", tab: 2),
        HomeExploreItem(id: "market", scene: "market", titleKey: "journey.tab.marketplace", subtitleKey: "journey.home.explore.market", icon: "bag.fill", tab: 3),
        HomeExploreItem(id: "people", scene: "people", titleKey: "journey.tab.people", subtitleKey: "journey.home.explore.people", icon: "person.2.fill", tab: 4)
    ]

    /// Illustration height below the status bar. The artwork keeps its upper-left calm for the heading.
    private let heroHeight: CGFloat = 400
    /// How far the plan card rides up over the illustration.
    private let heroOverlap: CGFloat = 92

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let topInset = geometry.safeAreaInsets.top

                ZStack(alignment: .top) {
                    JourneyVisual.pageBackground.ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            hero(width: geometry.size.width, topInset: topInset)

                            VStack(alignment: .leading, spacing: 0) {
                                planCard
                                    .journeyEntrance(delay: 0.12)
                                quickActions
                                    .padding(.top, 20)
                                    .journeyEntrance(delay: 0.18)
                                nextStepCard
                                    .padding(.top, 20)
                                    .journeyEntrance(delay: 0.22)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, -heroOverlap)

                            exploreSection
                                .padding(.top, 30)
                                .journeyEntrance(delay: 0.26)

                            helpCard
                                .padding(.horizontal, 20)
                                .padding(.top, 28)

                            if !subscriptionManager.isPremium {
                                SweezyPlusHomeCard(country: selectedCountry) {
                                    showSubscription = true
                                    APIClient.logPaywall(eventType: "cta_click", context: SubscriptionSource.home.rawValue)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                            }
                        }
                        .padding(.bottom, 126)
                    }
                    .ignoresSafeArea(edges: .top)
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    } action: { _, offset in
                        scrollOffset = offset
                    }

                    statusBarBackdrop
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showRoadmap) {
                MountainRoadmapView()
                    .environmentObject(appContainer)
            }
            .navigationDestination(isPresented: $showMyPlan) {
                MyPlanView()
                    .environmentObject(appContainer)
            }
            .navigationDestination(isPresented: $showCareerHub) {
                JobsView()
                    .environmentObject(appContainer)
            }
            .fullScreenCover(isPresented: $showSubscription) {
                SubscriptionView(source: .home)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(appContainer)
            }
            .onAppear {
                appContainer.telemetry.retention(
                    .nextActionViewed,
                    source: "journey_home",
                    meta: ["title": nextStepTitle]
                )
                if !reduceMotion && !heroDrift {
                    withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                        heroDrift = true
                    }
                }
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "screenshotRoadmap") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showRoadmap = true
                    }
                }
                #endif
            }
            .task {
                await subscriptionManager.load()
            }
        }
        .accessibilityIdentifier("home.screen")
    }

    // MARK: - Hero

    /// Full-bleed illustration behind the status bar: stretches when pulled, drifts slower than the page
    /// when scrolled, and breathes with a slow Ken Burns zoom. Heading sits on the calm sky.
    private func hero(width: CGFloat, topInset: CGFloat) -> some View {
        let total = heroHeight + topInset
        let pull = max(0, -scrollOffset)
        let lift = max(0, scrollOffset)
        let headingOpacity = Double(1 - min(1, lift / 260))
        let imageHeight = total + pull
        let imageWidth = max(width, imageHeight * 1.5)

        return ZStack(alignment: .topLeading) {
            // Crop is biased left (42% instead of centred) so the heading lands on sky and lake,
            // not on the Grossmünster towers, while the strolling couple stays in frame on the right.
            Image("city-scene-home")
                .resizable()
                .frame(width: imageWidth, height: imageHeight)
                .scaleEffect(heroDrift ? 1.06 : 1, anchor: .init(x: 0.62, y: 0.55))
                .offset(x: -(imageWidth - width) * 0.42)
                .frame(width: width, height: imageHeight, alignment: .leading)
                .clipped()
                .offset(y: -pull + lift * 0.35)
                .accessibilityHidden(true)

            // Paper wash behind the heading and status bar, and a melt into the page below.
            LinearGradient(
                stops: heroWashStops,
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: topInset + (colorScheme == .dark ? 240 : 170))
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [JourneyVisual.pageBackground.opacity(0), JourneyVisual.pageBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
            }
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                profileHeader
                    .journeyEntrance(delay: 0.02, distance: 8)
                heroTitle(width: width)
                    .padding(.top, 18)
                    .journeyEntrance(delay: 0.06)
                progressLabel
                    .padding(.top, 14)
                    .journeyEntrance(delay: 0.10, distance: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, topInset + 8)
            .opacity(headingOpacity)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .frame(width: width, height: total, alignment: .top)
        // Clip the bottom only: the stretched image must stay visible above the top edge.
        .mask(alignment: .bottom) {
            Rectangle().frame(height: total + 2000)
        }
    }

    /// The artwork's sky is bright in both themes, so dark mode needs a deeper wash behind light text.
    private var heroWashStops: [Gradient.Stop] {
        let strength: (Double, Double) = colorScheme == .dark ? (0.9, 0.62) : (0.7, 0.3)
        return [
            .init(color: JourneyVisual.pageBackground.opacity(strength.0), location: 0),
            .init(color: JourneyVisual.pageBackground.opacity(strength.1), location: 0.55),
            .init(color: JourneyVisual.pageBackground.opacity(0), location: 1)
        ]
    }

    /// Paper fills the status bar once the illustration has scrolled away, so the clock stays readable.
    private var statusBarBackdrop: some View {
        let progress = min(1, max(0, (scrollOffset - (heroHeight - 180)) / 60))
        return Color.clear
            .frame(height: 0)
            .background(JourneyVisual.pageBackground.opacity(progress).ignoresSafeArea(edges: .top))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var profileHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 28, height: 28)
                    .background(JourneyVisual.lime)
                    .clipShape(Circle())
                Text("journey.home.greeting".localized(with: firstName))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .lineLimit(1)
            }
            .padding(.leading, 5)
            .padding(.trailing, 14)
            .frame(height: 38)
            .background(.ultraThinMaterial, in: Capsule())
            .background(Theme.Colors.card.opacity(0.55), in: Capsule())
            .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .frame(width: Theme.Layout.minimumTouchTarget, height: Theme.Layout.minimumTouchTarget)
                    .background(.ultraThinMaterial, in: Circle())
                    .background(Theme.Colors.card.opacity(0.55), in: Circle())
                    .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94, hapticStyle: .light))
            .accessibilityLabel("settings.title".localized)
            .accessibilityIdentifier("home.openSettingsButton")
        }
    }

    private func heroTitle(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: -3) {
            Text("journey.home.hero.line1".localized)
            HStack(spacing: 7) {
                Text("journey.home.hero.line2".localized)
                Text(selectedCountry.homeHeroName(languageIdentifier: appContainer.currentLocale.identifier))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(JourneyVisual.lime)
                            .rotationEffect(.degrees(-1.5))
                    )
            }
        }
        .font(.system(size: min(34, Theme.Layout.heroTitleSize(for: width) + 4), weight: .bold, design: .default))
        .foregroundColor(JourneyVisual.primaryText)
        .lineSpacing(1)
        .shadow(color: JourneyVisual.pageBackground.opacity(0.9), radius: 14)
    }

    private var progressLabel: some View {
        let total = max(7, appContainer.firstWeekService.tasks.count)
        let fraction = total == 0 ? 0 : min(1, Double(completedTasks) / Double(total))
        return HStack(spacing: 10) {
            HStack(spacing: 5) {
                Text("\(completedTasks)/\(total)")
                    .font(.system(size: 13, weight: .bold, design: .default).monospacedDigit())
                    .foregroundColor(JourneyVisual.primaryText)
                    .contentTransition(.numericText(value: Double(completedTasks)))
                Text("journey.home.steps_completed".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
            }
            .fixedSize()

            // Segmented like the onboarding progress: each finished step fills one piece.
            HStack(spacing: 3) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(index < completedTasks ? JourneyVisual.accentStrong : JourneyVisual.primaryText.opacity(0.14))
                        .frame(height: 5)
                }
            }
            .frame(width: 96)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Theme.Colors.card.opacity(0.5), in: Capsule())
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: completedTasks)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(fraction * 100))%")
    }

    // MARK: - Plan

    /// The mascot sits on the card's edge with his map, so today's plan reads as the character's job.
    private var planCard: some View {
        Button { showMyPlan = true } label: {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("journey.home.plan_today".localized)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(urgentDeadlineCount > 0 ? JourneyVisual.coral : JourneyVisual.accentStrong)
                            .frame(width: 7, height: 7)
                        Text(planPulseSubtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .lineLimit(2)
                    }
                }
                .padding(.trailing, 104)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("companion.open_plan".localized)
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.08), in: Circle())
                }
                .foregroundStyle(.black)
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .frame(minHeight: 48)
                .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .padding(18)
            .padding(.top, 4)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
            .shadow(color: JourneyVisual.black.opacity(0.08), radius: 22, y: 10)
            .overlay(alignment: .topTrailing) {
                Image("sweezy-companion-plan")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 148)
                    .idleFloat(enabled: !reduceMotion)
                    .offset(x: -10, y: -64)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(CardPressStyle())
        .accessibilityIdentifier("home.myPlan")
    }

    // MARK: - Explore

    private var exploreSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("journey.home.explore.title".localized)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                Text("journey.home.explore.subtitle".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(exploreItems) { item in
                        exploreCard(item)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                    .opacity(phase.isIdentity ? 1 : 0.7)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    private func exploreCard(_ item: HomeExploreItem) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return Button {
            NotificationCenter.default.post(name: .switchTab, object: SwitchTabPayload(tab: item.tab))
        } label: {
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .overlay {
                        Image("city-scene-\(item.scene)")
                            .resizable()
                            .scaledToFill()
                    }
                    .allowsHitTesting(false)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: .black.opacity(0.35), location: 0.6),
                        .init(color: .black.opacity(0.82), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(item.titleKey.localized, systemImage: item.icon)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        Text(item.subtitleKey.localized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.88))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(JourneyVisual.lime, in: Circle())
                }
                .padding(14)
            }
            .frame(width: 272, height: 196)
            .clipShape(shape)
            .overlay(shape.stroke(Color.white.opacity(0.35), lineWidth: 1))
            .contentShape(shape)
            .shadow(color: JourneyVisual.black.opacity(0.10), radius: 14, y: 6)
        }
        .buttonStyle(CardPressStyle())
        .accessibilityIdentifier("home.explore.\(item.id)")
    }

    // MARK: - Help

    private var helpCard: some View {
        Button {
            NotificationCenter.default.post(
                name: .switchTab,
                object: SwitchTabPayload(tab: 1, section: .guides)
            )
        } label: {
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("journey.home.help.title".localized)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("journey.home.help.subtitle".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text("journey.home.help.action".localized)
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(JourneyVisual.lime, in: Capsule())
                    .padding(.top, 6)
                }
                .padding(.vertical, 20)
                .padding(.leading, 20)

                Spacer(minLength: 8)

                Image("sweezy-companion-help")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 176)
                    .padding(.trailing, 18)
                    .offset(y: 12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [JourneyVisual.lime.opacity(0.34), JourneyVisual.lime.opacity(0.08)],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            )
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(JourneyVisual.lime.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressStyle())
        .accessibilityIdentifier("home.helpCard")
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                Button {
                    if index == 1 {
                        showCareerHub = true
                    } else {
                        NotificationCenter.default.post(
                            name: .switchTab,
                            object: SwitchTabPayload(tab: 1, section: action.2)
                        )
                    }
                } label: {
                    VStack(spacing: 9) {
                        JourneyCategoryIcon(symbol: action.0, swatch: actionSwatches[index], size: 42)
                        Text(action.1)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(JourneyVisual.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Theme.Colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(JourneyVisual.softBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(CardPressStyle())
                .accessibilityLabel(action.1)
                .accessibilityIdentifier("home.quickAction.\(["documents", "jobs", "housing", "health"][index])")
            }
        }
    }

    private var nextStepCard: some View {
        CityPaper(inset: 0) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("journey.home.next_step_arrow".localized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(JourneyVisual.secondaryText)

                    Text(nextStepTitle)
                        .font(.system(size: 23, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                        .lineLimit(2)

                    JourneyPrimaryButton(title: "common.continue".localized, compact: true) {
                        if appContainer.firstWeekService.nextDueTask == nil {
                            showRoadmap = true
                        } else {
                            NotificationCenter.default.post(
                                name: .switchTab,
                                object: SwitchTabPayload(tab: 1, section: .checklists)
                            )
                        }
                        appContainer.telemetry.retention(
                            .nextActionTapped,
                            source: "journey_home",
                            meta: ["destination": appContainer.firstWeekService.nextDueTask == nil ? "roadmap" : "tasks"]
                        )
                    }
                }

                Spacer(minLength: 4)

                // A slice of the civic-square illustration (building and books), matching the art style
                // instead of the old grey photo.
                Color.clear
                    .frame(width: 84, height: 110)
                    .overlay(alignment: .trailing) {
                        Image("city-scene-directory")
                            .resizable()
                            .frame(width: 165, height: 110)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)
            }
            .padding(16)
        }
    }

    private var firstName: String {
        let name = lockManager.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.split(separator: " ").first.map(String.init) ?? "journey.home.default_name".localized
    }

    private var selectedCountry: ResidenceCountry {
        appContainer.userProfile?.country
            ?? ResidenceCountry(rawValue: APIClient.countryCode)
            ?? .switzerland
    }

    private var completedTasks: Int {
        appContainer.firstWeekService.tasks.filter(\.isDone).count
    }

    private var nextStepTitle: String {
        appContainer.firstWeekService.nextDueTask?.title ?? "journey.home.default_next_step".localized
    }

    private var homeDeadlines: [LifeDeadline] {
        appContainer.lifeAdmin.deadlines(
            profile: appContainer.userProfile,
            firstWeekTasks: appContainer.firstWeekService.tasks,
            appointments: appContainer.appointmentRepository.appointments
        )
    }

    private var urgentDeadlineCount: Int {
        homeDeadlines.filter { $0.urgency == .overdue || $0.urgency == .urgent }.count
    }

    private var planPulseSubtitle: String {
        if urgentDeadlineCount > 0 { return "journey.home.urgent_actions".localized(with: urgentDeadlineCount) }
        if let next = homeDeadlines.first { return "journey.home.next_deadline".localized(with: next.title) }
        return "journey.home.all_under_control".localized
    }
}
