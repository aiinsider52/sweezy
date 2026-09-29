//
//  JobsView.swift
//  sweezy
//
//  Country-scoped job finder with modern dashboard design and AI Match
//

import SwiftUI
import CoreHaptics
import MapKit

struct JobsView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var keyword: String = ""
    @State private var canton: String = ""
    @State private var isLoading: Bool = false
    @State private var items: [APIClient.JobItem] = []
    @State private var sources: [String: Int] = [:]
    @State private var catalogStatus: String = "ready"
    @State private var loadErrorMessage: String?
    @State private var searchGeneration = 0
    @State private var favoriteIds: Set<String> = []
    @State private var didSearchOnce: Bool = false
    @State private var selectedJob: APIClient.JobItem?
    @State private var selectedConversation: ChatConversation?
    @State private var applications: [APIClient.JobApplication] = []
    @State private var alerts: [APIClient.JobAlert] = []
    @State private var showApplicationTracker = false
    @State private var showAlerts = false
    @State private var showJobMap = false
    @State private var showEmployerHub = false
    @State private var noExperienceOnly = false
    @State private var noDegreeOnly = false
    @State private var minimumSalary = 0
    @State private var interactionMessage: String?
    @State private var favoritesCount: Int = 0
    @State private var page: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var selectedEmployment: EmploymentFilter = .all
    @State private var selectedCity: String = ""
    @State private var showAdvancedFilters: Bool = false
    @State private var showDraftSheet: Bool = false
    @State private var draftedText: String?
    @State private var isDrafting: Bool = false
    @State private var showAuthEntry: Bool = false
    @State private var showSubscription: Bool = false
    @State private var showCVBuilder: Bool = false
    @State private var savedCV: CVResume?
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    // AI Match
    @State private var showAIMatchProfile: Bool = false
    @State private var isAIMatching: Bool = false
    @State private var matchedItems: [APIClient.JobItem] = []
    @State private var matchScores: [String: Int] = [:]
    @State private var matchReasons: [String: [String]] = [:]
    @State private var showMatchResults: Bool = false
    
    // Onboarding
    @State private var didSeeJobsOnboarding: Bool = false
    @State private var showJobsOnboarding: Bool = false
    @State private var didLoadScopedState: Bool = false
    
    // Stats for dashboard
    @State private var newTodayCount: Int = 0
    @State private var appliedCount: Int = 0
    
    // Persisted preferences
    @State private var appliedJobIds: Set<String> = []
    
    // AI Match Profile (persisted)
    @State private var aiDesiredPosition: String = ""
    @State private var aiSkills: String = ""
    @State private var aiPreferredCanton: String = ""
    @State private var aiEmploymentType: String = ""
    @State private var aiRemotePreference: Bool = false
    @State private var aiExperienceLevel: String = ""
    
    private let perPage: Int = 20
    private var activeCountry: ResidenceCountry {
        ResidenceCountry(rawValue: APIClient.countryCode) ?? .switzerland
    }
    private var cantons: [String] {
        [""] + CountryCatalog.subdivisions(for: activeCountry).map(\.code)
    }
    private let quickTags = ["Java", "Driver", "Nurse", "QA", "Warehouse", "React", "Manager", "Sales"]
    private let defaults = UserDefaults.standard
    
    private enum EmploymentFilter: String, CaseIterable {
        case all = "Всі"
        case fullTime = "Full-time"
        case partTime = "Part-time"
        case contract = "Contract"
        case remote = "Remote"

        var serverEmploymentType: String? {
            switch self {
            case .all, .remote: return nil
            case .fullTime: return "full"
            case .partTime: return "part"
            case .contract: return "contract"
            }
        }
    }
    
    private var favoriteIdsKey: String { AccountScopedStorage.jobsKey("favoriteIds") }
    private var didSeeJobsOnboardingKey: String { AccountScopedStorage.jobsKey("didSeeOnboarding") }
    private var lastKeywordKey: String { AccountScopedStorage.jobsKey("lastKeyword") }
    private var lastCantonKey: String { AccountScopedStorage.jobsKey("lastCanton") }
    private var lastEmploymentKey: String { AccountScopedStorage.jobsKey("lastEmployment") }
    private var appliedJobIdsKey: String { AccountScopedStorage.jobsKey("appliedJobIds") }
    private var aiDesiredPositionKey: String { AccountScopedStorage.aiMatchKey("desiredPosition") }
    private var aiSkillsKey: String { AccountScopedStorage.aiMatchKey("skills") }
    private var aiPreferredCantonKey: String { AccountScopedStorage.aiMatchKey("preferredCanton") }
    private var aiEmploymentTypeKey: String { AccountScopedStorage.aiMatchKey("employmentType") }
    private var aiRemotePreferenceKey: String { AccountScopedStorage.aiMatchKey("remotePreference") }
    private var aiExperienceLevelKey: String { AccountScopedStorage.aiMatchKey("experienceLevel") }
    
    // Check if AI profile is configured
    private var hasAIProfile: Bool {
        !aiDesiredPosition.isEmpty || !aiSkills.isEmpty
    }

    private var aiProfileProgress: Double {
        let completed = [
            !aiDesiredPosition.isEmpty,
            !aiSkills.isEmpty,
            !aiPreferredCanton.isEmpty,
            !aiEmploymentType.isEmpty,
            aiRemotePreference,
            !aiExperienceLevel.isEmpty
        ].filter { $0 }.count
        return Double(completed) / 6.0
    }
    
    // MARK: - Computed
    private var displayedItems: [APIClient.JobItem] {
        let baseItems = showMatchResults ? matchedItems : items
        let filtered = baseItems.filter { job in
            // City filter
            if !selectedCity.isEmpty {
                guard (job.location ?? "").localizedCaseInsensitiveContains(selectedCity) else { return false }
            }
            // Employment filter
            if selectedEmployment != .all {
                let t = (job.employment_type ?? "").lowercased()
                switch selectedEmployment {
                case .all: break
                case .fullTime: if !t.contains("full") && !t.contains("vollzeit") { return false }
                case .partTime: if !t.contains("part") && !t.contains("teilzeit") { return false }
                case .contract: if !t.contains("contract") && !t.contains("auftrag") { return false }
                case .remote:
                    let workplace = (job.workplace_type ?? "").lowercased()
                    if !workplace.contains("remote") && !workplace.contains("hybrid") { return false }
                }
            }
            return true
        }
        return filtered.sorted { parseDate($0.posted_at) ?? .distantPast > parseDate($1.posted_at) ?? .distantPast }
    }
    
    private var topCities: [String] {
        var counts: [String: Int] = [:]
        for it in items {
            if let city = primaryCity(from: it.location), !city.isEmpty {
                counts[city, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(6).map { $0.key }
    }
    
    private var hasPremiumAccess: Bool { subscriptionManager.isPremium }
    private var careerProfile: CareerProfileSnapshot { CareerProfileSnapshot(resume: savedCV) }
    private var activeApplications: [APIClient.JobApplication] {
        applications.filter { !["rejected", "withdrawn"].contains($0.status) }
    }
    private var careerMatchCount: Int {
        #if DEBUG
        if isCareerHubUITest { return 12 }
        #endif
        return matchedItems.count
    }

    private var isCareerHubUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["UITESTS"] == "1" &&
            ProcessInfo.processInfo.arguments.contains("--ui-test-career-hub")
        #else
        false
        #endif
    }

    private var isJobsGateUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["UITESTS"] == "1" &&
            ProcessInfo.processInfo.arguments.contains("--ui-test-jobs-gate")
        #else
        false
        #endif
    }

    private enum CareerNextAction {
        case createCV
        case completeCV
        case findMatches
        case reviewMatches
        case reviewApplications
    }

    private var careerNextAction: CareerNextAction {
        if !careerProfile.hasResume { return .createCV }
        if careerProfile.completion < 70 || !careerProfile.canMatchJobs { return .completeCV }
        if activeApplications.contains(where: { $0.status == "interview" || $0.status == "offer" }) {
            return .reviewApplications
        }
        if careerMatchCount == 0 { return .findMatches }
        if activeApplications.isEmpty { return .reviewMatches }
        return .reviewApplications
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            if sessionManager.isAuthenticated || isCareerHubUITest, !isJobsGateUITest {
                jobsContent
            } else {
                jobsAccessGate
            }
        }
        .interactiveSwipeBackEnabled()
        .sheet(isPresented: $showAuthEntry) {
            AuthEntryView(showsCloseButton: true) {
                showAuthEntry = false
            }
            .environment(\.locale, appContainer.currentLocale)
            .environmentObject(appContainer)
            .environmentObject(lockManager)
            .environmentObject(sessionManager)
        }
        .onChange(of: sessionManager.isAuthenticated) { _, authenticated in
            if authenticated {
                showAuthEntry = false
            }
        }
        .task { await subscriptionManager.load() }
        .fullScreenCover(isPresented: $showCVBuilder, onDismiss: {
            reloadCareerProfile(syncMatchProfile: true)
        }) {
            CVBuilderView(onClose: { showCVBuilder = false })
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
        .fullScreenCover(isPresented: $showSubscription) {
            SubscriptionView(source: .profile)
        }
    }

    private var jobsContent: some View {
        ZStack(alignment: .top) {
            JourneyVisual.pageBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    heroSection

                    VStack(spacing: 13) {
                        careerHubSection
                        smartFiltersSection

                        if showAdvancedFilters {
                            advancedFiltersSection
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        resultsSection
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.bottom, 112)
            }
            .refreshable {
                showMatchResults = false
                await performSearch()
                haptic(.light)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            appContainer.telemetry.info("view_open", source: "jobs", message: "JobsView opened")
        }
        .sheet(item: $selectedJob) { job in
            JobDetailSheet(
                job: job,
                matchScore: matchScores[job.id],
                matchReasons: matchReasons[job.id] ?? [],
                isApplied: appliedJobIds.contains(job.id),
                onOpen: { await openJob(job) },
                onDraft: { await draftApply(job) },
                onApplied: { await markApplied(job) },
                onChat: { await openJobChat(job) },
                onReport: { await reportJob(job) }
            )
                .environmentObject(appContainer)
        }
        .fullScreenCover(item: $selectedConversation) { conversation in
            ChatConversationView(conversation: conversation)
                .environmentObject(appContainer)
        }
        .sheet(isPresented: $showDraftSheet) {
            DraftSheet(text: draftedText, isDrafting: isDrafting)
        }
        .sheet(isPresented: $showApplicationTracker) {
            JobApplicationTrackerSheet(applications: applications) { jobID, status in
                await updateApplication(jobID: jobID, status: status)
            }
        }
        .sheet(isPresented: $showAlerts) {
            JobAlertsSheet(
                alerts: alerts,
                defaultKeywords: keyword,
                defaultCanton: canton,
                onCreate: { name, keywords in await createAlert(name: name, keywords: keywords) },
                onDelete: { alertID in await deleteAlert(alertID) }
            )
        }
        .sheet(isPresented: $showJobMap) {
            JobMapSheet(jobs: displayedItems) { job in
                showJobMap = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { selectedJob = job }
            }
        }
        .sheet(isPresented: $showEmployerHub) {
            JobEmployerHubSheet(cantons: cantons)
        }
        .sheet(isPresented: $showAIMatchProfile, onDismiss: {
            persistAIMatchProfile()
        }) {
            AIMatchProfileSheet(
                desiredPosition: $aiDesiredPosition,
                skills: $aiSkills,
                preferredCanton: $aiPreferredCanton,
                employmentType: $aiEmploymentType,
                remotePreference: $aiRemotePreference,
                experienceLevel: $aiExperienceLevel,
                cantons: cantons,
                onSearch: {
                    persistAIMatchProfile()
                    showAIMatchProfile = false
                    Task { await performAIMatch() }
                }
            )
        }
        .sheet(isPresented: $showJobsOnboarding) {
            JobsOnboardingSheet(
                onClose: {
                    didSeeJobsOnboarding = true
                    persistJobsScopedState()
                    showJobsOnboarding = false
                },
                onSetupProfile: {
                    didSeeJobsOnboarding = true
                    persistJobsScopedState()
                    showJobsOnboarding = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showAIMatchProfile = true
                    }
                }
            )
        }
        .task {
            if !didLoadScopedState {
                loadScopedState()
                reloadCareerProfile(syncMatchProfile: true)
                applyJobsPresetIfNeeded()
                didLoadScopedState = true
            }
            if isCareerHubUITest {
                didSearchOnce = true
                return
            }
            if !didSearchOnce {
                await performSearch()
                await refreshFavoritesCount()
                if !didSeeJobsOnboarding {
                    // Показуємо легкий onboarding лише при першому вході
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showJobsOnboarding = true
                        appContainer.telemetry.info("onboarding_show", source: "jobs", message: "Jobs onboarding displayed")
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountScopeDidChange)) { _ in
            loadScopedState()
            showMatchResults = false
            selectedJob = nil
            selectedConversation = nil
            draftedText = nil
            matchedItems = []
            didSearchOnce = false
            Task {
                await performSearch()
                await refreshFavoritesCount()
            }
        }
        .alert("Вакансії".localized, isPresented: Binding(
            get: { interactionMessage != nil },
            set: { if !$0 { interactionMessage = nil } }
        )) {
            Button("OK", role: .cancel) { interactionMessage = nil }
        } message: {
            Text(interactionMessage ?? "")
        }
    }

    private var jobsAccessGate: some View {
        ZStack(alignment: .top) {
            JourneyVisual.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Sweezy reviewing a CV at the coworking desk, with the back button on the picture.
                    StoryScene(name: "jobs", height: 230)
                        .overlay(alignment: .topLeading) {
                            jobsGateBackButton
                                .padding(12)
                        }
                        .overlay(alignment: .bottomLeading) {
                            Label("CAREER HUB", systemImage: "briefcase.fill")
                                .font(.system(size: 11, weight: .black))
                                .tracking(1.2)
                                .foregroundColor(.black)
                                .padding(.horizontal, 11)
                                .frame(height: 28)
                                .background(JourneyVisual.lime, in: Capsule())
                                .padding(14)
                        }

                    Text("Знайди роботу,\nяка тобі підходить".localized)
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                        .minimumScaleFactor(0.78)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 22)

                    Text("AI Match, збережені вакансії та весь шлях заявки — в одному місці.".localized)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        accessBenefit(
                            icon: "sparkles",
                            swatch: JourneyCategoryPalette.lime,
                            title: "Персональний AI Match".localized,
                            subtitle: "Рекомендації під твій досвід і цілі".localized
                        )
                        Divider().overlay(JourneyVisual.softBorder).padding(.leading, 64)
                        accessBenefit(
                            icon: "bookmark.fill",
                            swatch: JourneyCategoryPalette.sky,
                            title: "Збережені вакансії".localized,
                            subtitle: "Усі цікаві пропозиції завжди під рукою".localized
                        )
                        Divider().overlay(JourneyVisual.softBorder).padding(.leading, 64)
                        accessBenefit(
                            icon: "paperplane.fill",
                            swatch: JourneyCategoryPalette.sand,
                            title: "Трекер заявок".localized,
                            subtitle: "Статуси й наступні кроки в одному місці".localized
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
                    .padding(.top, 20)

                    Button {
                        openJobsAuthentication()
                    } label: {
                        HStack {
                            Text("Увійти та знайти вакансії".localized)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.08), in: Circle())
                        }
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundColor(.black)
                        .padding(.leading, 20)
                        .padding(.trailing, 10)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: JourneyVisual.lime.opacity(0.35), radius: 14, y: 5)
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
                    .padding(.top, 20)
                    .accessibilityHint("Відкриває вхід або створення акаунта".localized)

                    Label("Вхід потрібен, щоб зберігати вакансії та заявки".localized, systemImage: "lock.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 116)
            }
            .accessibilityIdentifier("careerHub.guestGate")
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private var jobsGateBackButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(JourneyVisual.primaryText)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .background(Theme.Colors.card.opacity(0.6), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Назад".localized)
    }

    private func accessBenefit(icon: String, swatch: JourneyCategorySwatch, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            JourneyCategoryIcon(symbol: icon, swatch: swatch, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private func openJobsAuthentication() {
        showAuthEntry = true
        haptic(.medium)
    }
    
    // MARK: - Hero
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial.opacity(0.78))
                    .background(Theme.Colors.card)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Назад".localized)

            // Sweezy reviewing a CV next to the laptop: the whole hub in one picture.
            StoryScene(name: "jobs", height: 190)
                .padding(.top, 14)
                .padding(.bottom, 18)

            Text("CAREER HUB · ШВЕЙЦАРІЯ".localized)
                .font(.system(size: 13, weight: .bold))
                .tracking(2.2)
                .foregroundColor(Theme.Colors.textPrimary)

            Text("Від сильного CV\nдо першого оферу".localized)
                .font(.system(size: 29, weight: .bold, design: .default))
                .foregroundColor(JourneyVisual.primaryText)
                .minimumScaleFactor(0.82)
                .lineSpacing(1)
                .padding(.top, 13)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    // MARK: - Career Hub
    private var careerHubSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                CareerReadinessRing(progress: careerProfile.completion)

                VStack(alignment: .leading, spacing: 5) {
                    Text("КАР’ЄРНИЙ ПРОФІЛЬ".localized)
                        .font(.system(size: 10, weight: .black, design: .default))
                        .tracking(1.6)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text(careerProfile.desiredPosition.isEmpty ? "Твій наступний крок".localized : careerProfile.desiredPosition)
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                        .lineLimit(2)

                    Text(careerProfile.hasResume ? "CV автоматично живить пошук і AI Match".localized : "Створи CV — решту Career Hub збере сам".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button {
                    showCVBuilder = true
                } label: {
                    Image(systemName: careerProfile.hasResume ? "pencil" : "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.card)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(careerProfile.hasResume ? "Редагувати CV".localized : "Створити CV".localized)
            }

            careerRoute

            HStack(spacing: 8) {
                CareerHubMetric(
                    value: "\(careerProfile.completion)%",
                    label: "готовність CV".localized,
                    icon: "doc.text.fill"
                )
                CareerHubMetric(
                    value: "\(careerMatchCount)",
                    label: "AI збігів".localized,
                    icon: "sparkles"
                )
                CareerHubMetric(
                    value: "\(activeApplications.count)",
                    label: "активні заявки".localized,
                    icon: "paperplane.fill"
                )
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: careerNextIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 38, height: 38)
                    .background(JourneyVisual.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("НАСТУПНА ДІЯ".localized)
                        .font(.system(size: 9, weight: .black, design: .default))
                        .tracking(1.2)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(careerNextTitle)
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text(careerNextSubtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(13)
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(JourneyVisual.softBorder))

            Button {
                handleCareerPrimaryAction()
            } label: {
                HStack(spacing: 10) {
                    if isAIMatching {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: careerPrimaryIcon)
                    }
                    Text(careerPrimaryTitle)
                        .font(.system(size: 16, weight: .bold, design: .default))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .black))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(JourneyVisual.lime)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isAIMatching)
            .accessibilityIdentifier("careerHub.primaryAction")

            HStack(spacing: 10) {
                careerUtilityButton(icon: "slider.horizontal.3", title: "Профіль AI".localized) {
                    showAIMatchProfile = true
                }
                careerUtilityButton(icon: alerts.isEmpty ? "bell" : "bell.fill", title: "Сповіщення".localized) {
                    showAlerts = true
                }
                careerUtilityButton(icon: "rectangle.stack", title: "Трекер".localized) {
                    showApplicationTracker = true
                }
            }
        }
        .padding(17)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.Colors.card.opacity(0.97))
                RadialGradient(
                    colors: [JourneyVisual.lime.opacity(0.14), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 220
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [JourneyVisual.lime.opacity(0.72), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: JourneyVisual.lime.opacity(0.08), radius: 28, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("careerHub.dashboard")
    }

    private var careerRoute: some View {
        HStack(spacing: 0) {
            CareerRouteNode(title: "CV", icon: "doc.text.fill", state: careerProfile.hasResume ? .complete : .current)
            CareerRouteConnector(isComplete: careerMatchCount > 0)
            CareerRouteNode(title: "Збіги".localized, icon: "sparkles", state: careerMatchCount > 0 ? .complete : (careerProfile.hasResume ? .current : .locked))
            CareerRouteConnector(isComplete: !activeApplications.isEmpty)
            CareerRouteNode(title: "Заявки".localized, icon: "paperplane.fill", state: !activeApplications.isEmpty ? .complete : (careerMatchCount > 0 ? .current : .locked))
            CareerRouteConnector(isComplete: applications.contains(where: { $0.status == "offer" }))
            CareerRouteNode(title: "Офер".localized, icon: "checkmark.seal.fill", state: applications.contains(where: { $0.status == "offer" }) ? .complete : .locked)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Кар'єрний маршрут: CV, збіги, заявки, офер".localized)
    }

    private func careerUtilityButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(JourneyVisual.softBorder))
        }
        .buttonStyle(.plain)
    }

    private var careerNextIcon: String {
        switch careerNextAction {
        case .createCV: return "doc.badge.plus"
        case .completeCV: return "pencil.and.list.clipboard"
        case .findMatches: return "sparkles"
        case .reviewMatches: return "rectangle.stack.fill"
        case .reviewApplications: return "arrow.triangle.2.circlepath"
        }
    }

    private var careerNextTitle: String {
        switch careerNextAction {
        case .createCV: return "Створи швейцарське CV".localized
        case .completeCV:
            return "Додай \(careerProfile.nextMissingSection ?? "дані CV")"
        case .findMatches: return "Запусти пошук за своїм CV".localized
        case .reviewMatches: return "Обери першу відповідну вакансію".localized
        case .reviewApplications:
            if applications.contains(where: { $0.status == "interview" }) { return "Підготуйся до співбесіди".localized }
            if applications.contains(where: { $0.status == "offer" }) { return "Переглянь свій офер".localized }
            return "Онови статус активних заявок".localized
        }
    }

    private var careerNextSubtitle: String {
        switch careerNextAction {
        case .createCV: return "Профіль, досвід, навички та ATS PDF в одному процесі.".localized
        case .completeCV: return "Повніший профіль дає точніші AI-рекомендації.".localized
        case .findMatches: return "Посада й навички вже готові для персонального підбору.".localized
        case .reviewMatches: return "Відкрий збіг, перевір вимоги та підготуй заявку.".localized
        case .reviewApplications: return "Career Hub збереже етапи й наступні дії в одному місці.".localized
        }
    }

    private var careerPrimaryTitle: String {
        switch careerNextAction {
        case .createCV: return "Створити CV".localized
        case .completeCV: return "Завершити CV".localized
        case .findMatches: return "Знайти роботу за моїм CV".localized
        case .reviewMatches: return "Переглянути AI-збіги".localized
        case .reviewApplications: return "Відкрити трекер заявок".localized
        }
    }

    private var careerPrimaryIcon: String {
        switch careerNextAction {
        case .createCV, .completeCV: return "doc.text.fill"
        case .findMatches: return "sparkles"
        case .reviewMatches: return "briefcase.fill"
        case .reviewApplications: return "rectangle.stack.fill"
        }
    }

    private func handleCareerPrimaryAction() {
        switch careerNextAction {
        case .createCV, .completeCV:
            showCVBuilder = true
        case .findMatches:
            Task { await findJobsUsingSavedCV() }
        case .reviewMatches:
            withAnimation(.easeInOut(duration: 0.2)) { showMatchResults = true }
        case .reviewApplications:
            showApplicationTracker = true
        }
        haptic(.medium)
    }

    private func findJobsUsingSavedCV() async {
        reloadCareerProfile(syncMatchProfile: true)
        guard careerProfile.canMatchJobs else {
            showCVBuilder = true
            return
        }
        await performAIMatch()
    }

    // MARK: - AI Match
    private var aiMatchSection: some View {
        JourneyGlassPanel(cornerRadius: 25) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 46, height: 46)
                        .background(JourneyVisual.lime)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Match")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(JourneyVisual.primaryText)
                        Text(hasAIProfile ? "За досвідом і твоїми цілями".localized : "Профіль для точного підбору".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 6)
                    AIProfileProgressRing(progress: aiProfileProgress)

                    Button {
                        showAIMatchProfile = true
                        haptic(.light)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(JourneyVisual.primaryText)
                            .frame(width: 38, height: 38)
                            .background(Theme.Colors.card)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Налаштувати AI профіль".localized)
                }

                Button {
                    haptic(.medium)
                    if hasAIProfile {
                        Task { await performAIMatch() }
                    } else {
                        showAIMatchProfile = true
                    }
                } label: {
                    HStack(spacing: 9) {
                        if isAIMatching { ProgressView().tint(.black) }
                        Text(hasAIProfile ? "Знайти збіги".localized : "Налаштувати профіль".localized)
                            .font(.system(size: 17, weight: .bold))
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 22)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(JourneyVisual.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isAIMatching)
            }
            .padding(15)
        }
    }

    // MARK: - Dashboard
    private var dashboardSection: some View {
        HStack(spacing: 11) {
            JobsInlineMetric(icon: "sparkles", value: newTodayCount, label: "нових".localized)
            Circle().fill(JourneyVisual.softBorder).frame(width: 4, height: 4)
            JobsInlineMetric(icon: "heart", value: favoritesCount, label: "збережено".localized)
            Circle().fill(JourneyVisual.softBorder).frame(width: 4, height: 4)
            Button {
                showApplicationTracker = true
            } label: {
                JobsInlineMetric(icon: "paperplane", value: appliedCount, label: "трекер".localized)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                showAlerts = true
            } label: {
                Image(systemName: alerts.isEmpty ? "bell.badge" : "bell.badge.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .frame(width: 34, height: 34)
                    .background(Theme.Colors.card)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Сповіщення про вакансії".localized)

            Menu {
                Button { showJobMap = true } label: {
                    Label("Карта вакансій".localized, systemImage: "map")
                }
                Button { showEmployerHub = true } label: {
                    Label("Для роботодавців".localized, systemImage: "building.2")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(Theme.Colors.card)
                    .clipShape(Circle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Smart Filters
    private var smartFiltersSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText)

                TextField(
                    "",
                    text: $keyword,
                    prompt: Text("Посада, навичка або компанія".localized).foregroundColor(JourneyVisual.secondaryText)
                )
                    .foregroundColor(JourneyVisual.primaryText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        showMatchResults = false
                        Task { await performSearch() }
                    }

                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                        showMatchResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(JourneyVisual.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 17)
            .frame(height: 54)
            .background(.ultraThinMaterial.opacity(0.7))
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Menu {
                        ForEach(cantons, id: \.self) { code in
                            Button(code.isEmpty ? "Всі кантони".localized : code) {
                                canton = code
                                showMatchResults = false
                                Task { await performSearch() }
                            }
                        }
                    } label: {
                        JobsMenuPill(icon: "mappin", text: canton.isEmpty ? "Кантон".localized : canton, isActive: !canton.isEmpty)
                    }

                    Menu {
                        ForEach(EmploymentFilter.allCases, id: \.self) { filter in
                            Button(filter.rawValue.localized) {
                                selectedEmployment = filter
                                haptic(.light)
                                Task { await performSearch() }
                            }
                        }
                    } label: {
                        JobsMenuPill(
                            icon: "briefcase",
                            text: selectedEmployment == .all ? "Тип роботи".localized : selectedEmployment.rawValue.localized,
                            isActive: selectedEmployment != .all
                        )
                    }

                    Button {
                        selectedEmployment = selectedEmployment == .remote ? .all : .remote
                        haptic(.light)
                        Task { await performSearch() }
                    } label: {
                        JobsMenuPill(icon: "house", text: "Віддалено".localized, isActive: selectedEmployment == .remote, showsChevron: false)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) { showAdvancedFilters.toggle() }
                        haptic(.light)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(showAdvancedFilters ? .black : JourneyVisual.primaryText)
                            .frame(width: 44, height: 44)
                            .background(showAdvancedFilters ? JourneyVisual.lime : Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Advanced Filters
    private var advancedFiltersSection: some View {
        JourneyGlassPanel(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 15) {
                Text("Швидкий пошук".localized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                quickTagsSection

                if !topCities.isEmpty {
                    Divider().overlay(Color.white.opacity(0.12))
                    Text("Міста".localized)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                    cityChipsSection
                }

                Divider().overlay(Color.white.opacity(0.12))
                Toggle("Без досвіду".localized, isOn: $noExperienceOnly)
                    .tint(JourneyVisual.lime)
                    .foregroundColor(JourneyVisual.primaryText)
                Toggle("Без обов'язкового диплома".localized, isOn: $noDegreeOnly)
                    .tint(JourneyVisual.lime)
                    .foregroundColor(JourneyVisual.primaryText)
                VStack(alignment: .leading, spacing: 8) {
                    Text(minimumSalary == 0 ? "Будь-яка зарплата".localized : "Від %@ %@k / рік".localized(with: "\(activeCountry.currencyCode)", "\(minimumSalary / 1000)"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(JourneyVisual.secondaryText)
                    Slider(value: Binding(
                        get: { Double(minimumSalary) },
                        set: { minimumSalary = Int($0 / 5_000) * 5_000 }
                    ), in: 0...200_000, step: 5_000)
                    .tint(JourneyVisual.accentText)
                }

                Button {
                    Task { await performSearch() }
                } label: {
                    Text("Застосувати фільтри".localized)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(JourneyVisual.lime)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                if showMatchResults {
                    Button {
                        showMatchResults = false
                        haptic(.light)
                    } label: {
                        Label("Скинути AI результати".localized, systemImage: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Quick Tags Section
    private var quickTagsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(quickTags, id: \.self) { tag in
                    QuickTagChip(
                        text: tag,
                        isSelected: keyword == tag
                    ) {
                        keyword = tag
                        showMatchResults = false
                        Task { await performSearch() }
                        haptic(.light)
                    }
                }
            }
        }
    }
    
    // MARK: - City Chips Section
    private var cityChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                QuickTagChip(text: "Всі міста".localized, isSelected: selectedCity.isEmpty) {
                    selectedCity = ""
                    haptic(.light)
                }
                
                ForEach(topCities, id: \.self) { city in
                    QuickTagChip(text: city, isSelected: selectedCity == city) {
                        selectedCity = city
                        haptic(.light)
                    }
                }
            }
        }
    }
    
    // MARK: - Results
    private var resultsSection: some View {
        VStack(spacing: 12) {
            HStack {
                if showMatchResults {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("AI результати".localized)
                            .foregroundColor(JourneyVisual.primaryText)
                    }
                } else {
                    Text("Рекомендовано для тебе".localized)
                        .foregroundColor(JourneyVisual.primaryText)
                }

                Spacer()

                if !displayedItems.isEmpty {
                    Text("%@ вакансій".localized(with: "\(displayedItems.count)"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }
            .font(.system(size: 21, weight: .bold, design: .default))
            .padding(.top, 6)
            
            if isLoading || isAIMatching {
                // Skeleton loading
                ForEach(0..<4, id: \.self) { _ in
                    JobCardSkeleton()
                }
            } else if let loadErrorMessage {
                JobsRecoveryState(
                    icon: "wifi.exclamationmark",
                    title: "Не вдалося оновити вакансії".localized,
                    message: loadErrorMessage,
                    actionTitle: "Спробувати ще".localized
                ) { Task { await performSearch() } }
            } else if catalogStatus == "source_unavailable" {
                JobsRecoveryState(
                    icon: "antenna.radiowaves.left.and.right.slash",
                    title: "Джерела вакансій тимчасово недоступні".localized,
                    message: "Ми вже перевіряємо підключення. Збережені вакансії та трекер залишаються доступними.".localized,
                    actionTitle: "Перевірити знову".localized
                ) { Task { await performSearch() } }
            } else if displayedItems.isEmpty {
                JobsEmptyState(hasSearched: didSearchOnce, isAIMatch: showMatchResults)
            } else {
                // Job cards
                ForEach(displayedItems, id: \.id) { job in
                    JobCard(
                        job: job,
                        isSaved: favoriteIds.contains(job.id),
                        matchScore: showMatchResults ? matchScores[job.id] : nil,
                        onTap: { selectedJob = job },
                        onSave: { toggleFavorite(job) },
                        onShare: { shareJob(job) }
                    )
                }
                
                // Load more (only for regular search)
                if canLoadMore && !showMatchResults {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(JourneyVisual.primaryText)
                            } else {
                                Text("Завантажити ще".localized)
                            }
                        }
                        .foregroundColor(JourneyVisual.primaryText)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.card)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - AI Match Logic
    private func performAIMatch() async {
        guard hasAIProfile else {
            showAIMatchProfile = true
            return
        }
        
        isAIMatching = true
        haptic(.medium)
        
        // Build search query from profile
        var searchKeywords: [String] = []
        
        if !aiDesiredPosition.isEmpty {
            searchKeywords.append(aiDesiredPosition)
        }
        
        // Add top skills (max 2)
        let skillsList = aiSkills.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        searchKeywords.append(contentsOf: skillsList.prefix(2))
        
        let searchQuery = searchKeywords.joined(separator: " ")
        let searchCanton = aiPreferredCanton.isEmpty ? nil : aiPreferredCanton
        
        do {
            let response = try await APIClient.matchJobs(
                desiredPosition: aiDesiredPosition,
                skills: skillsList,
                canton: searchCanton,
                employmentType: aiEmploymentType.isEmpty ? nil : aiEmploymentType,
                remote: aiRemotePreference,
                experienceLevel: aiExperienceLevel.isEmpty ? nil : aiExperienceLevel
            )
            matchedItems = response.items.map(\.job)
            matchScores = Dictionary(uniqueKeysWithValues: response.items.map { ($0.job.id, $0.score) })
            matchReasons = Dictionary(uniqueKeysWithValues: response.items.map { ($0.job.id, $0.reasons) })
            showMatchResults = true
            
            haptic(.success)
            appContainer.telemetry.info("ai_match_success", source: "jobs", meta: [
                "q": searchQuery, "canton": searchCanton ?? "", "count": String(matchedItems.count)
            ])
        } catch {
            matchedItems = []
            showMatchResults = false
            haptic(.error)
            appContainer.telemetry.error("ai_match_error", source: "jobs", message: (error as NSError).localizedDescription)
        }
        
        isAIMatching = false
    }
    
    private func applyJobsPresetIfNeeded() {
        if let presetCanton = JobsSearchPreset.pendingCanton {
            canton = presetCanton
            JobsSearchPreset.pendingCanton = nil
        }
        if let presetCity = JobsSearchPreset.pendingCity {
            selectedCity = presetCity
            JobsSearchPreset.pendingCity = nil
        }
    }

    private func loadScopedState() {
        favoriteIds = Set(defaults.stringArray(forKey: favoriteIdsKey) ?? [])
        didSeeJobsOnboarding = defaults.bool(forKey: didSeeJobsOnboardingKey)
        keyword = defaults.string(forKey: lastKeywordKey) ?? ""
        canton = defaults.string(forKey: lastCantonKey) ?? ""
        selectedEmployment = EmploymentFilter(rawValue: defaults.string(forKey: lastEmploymentKey) ?? "") ?? .all
        appliedJobIds = Set((defaults.string(forKey: appliedJobIdsKey) ?? "").split(separator: ",").map(String.init))
        appliedCount = appliedJobIds.count
        aiDesiredPosition = defaults.string(forKey: aiDesiredPositionKey) ?? ""
        aiSkills = defaults.string(forKey: aiSkillsKey) ?? ""
        aiPreferredCanton = defaults.string(forKey: aiPreferredCantonKey) ?? ""
        aiEmploymentType = defaults.string(forKey: aiEmploymentTypeKey) ?? ""
        aiRemotePreference = defaults.bool(forKey: aiRemotePreferenceKey)
        aiExperienceLevel = defaults.string(forKey: aiExperienceLevelKey) ?? ""
        favoritesCount = favoriteIds.count
    }

    private func reloadCareerProfile(syncMatchProfile: Bool) {
        #if DEBUG
        if isCareerHubUITest {
            applyCareerResume(Self.careerHubFixture, syncMatchProfile: syncMatchProfile)
            return
        }
        #endif

        guard !lockManager.userEmail.isEmpty else {
            savedCV = nil
            return
        }

        let key = "cv_saved_data_\(lockManager.userEmail.lowercased())"
        guard let data = ProtectedLocalStore.data(for: key, migratingFrom: key),
              let resume = try? JSONDecoder().decode(CVResume.self, from: data) else {
            savedCV = nil
            return
        }

        applyCareerResume(resume, syncMatchProfile: syncMatchProfile)
    }

    private func applyCareerResume(_ resume: CVResume, syncMatchProfile: Bool) {
        savedCV = resume
        guard syncMatchProfile else { return }

        let snapshot = CareerProfileSnapshot(resume: resume)
        if !snapshot.desiredPosition.isEmpty {
            aiDesiredPosition = snapshot.desiredPosition
        }
        if !snapshot.normalizedSkills.isEmpty {
            aiSkills = snapshot.normalizedSkills.joined(separator: ", ")
        }
        if aiPreferredCanton.isEmpty, let profileCanton = appContainer.userProfile?.canton.rawValue {
            aiPreferredCanton = profileCanton
        }
        if aiExperienceLevel.isEmpty, let inferredLevel = snapshot.inferredExperienceLevel {
            aiExperienceLevel = inferredLevel
        }
        persistAIMatchProfile()
    }

    #if DEBUG
    private static var careerHubFixture: CVResume {
        var resume = CVResume.empty
        resume.personal = CVPersonal(
            fullName: "Anna Kovalenko",
            title: "Product Designer",
            email: "anna@example.com",
            phone: "+41 79 123 45 67",
            location: "Zürich",
            summary: "Product designer building clear, accessible services for international teams in Switzerland."
        )
        resume.experience = [
            CVExperience(role: "Product Designer", company: "Digital Solutions AG", period: "2022–сьогодні".localized, location: "Zürich", achievements: "Запустила дизайн-систему та покращила ключові user flows.".localized)
        ]
        resume.skills = ["Figma", "UX Research", "Design Systems", "Prototyping"]
        return resume
    }
    #endif
    
    private func persistJobsScopedState() {
        defaults.set(Array(favoriteIds), forKey: favoriteIdsKey)
        defaults.set(didSeeJobsOnboarding, forKey: didSeeJobsOnboardingKey)
        defaults.set(keyword, forKey: lastKeywordKey)
        defaults.set(canton, forKey: lastCantonKey)
        defaults.set(selectedEmployment.rawValue, forKey: lastEmploymentKey)
        defaults.set(appliedJobIds.sorted().joined(separator: ","), forKey: appliedJobIdsKey)
    }
    
    private func persistAIMatchProfile() {
        defaults.set(aiDesiredPosition, forKey: aiDesiredPositionKey)
        defaults.set(aiSkills, forKey: aiSkillsKey)
        defaults.set(aiPreferredCanton, forKey: aiPreferredCantonKey)
        defaults.set(aiEmploymentType, forKey: aiEmploymentTypeKey)
        defaults.set(aiRemotePreference, forKey: aiRemotePreferenceKey)
        defaults.set(aiExperienceLevel, forKey: aiExperienceLevelKey)
    }
    
    // MARK: - Actions
    private func performSearch() async {
        searchGeneration &+= 1
        let generation = searchGeneration
        isLoading = true
        loadErrorMessage = nil
        didSearchOnce = true
        defer {
            if generation == searchGeneration { isLoading = false }
        }
        
        do {
            page = 1
            let resp = try await APIClient.searchJobs(
                keyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines),
                canton: canton.isEmpty ? nil : canton,
                employmentType: selectedEmployment.serverEmploymentType,
                workplaceType: selectedEmployment == .remote ? "remote" : nil,
                noExperience: noExperienceOnly ? true : nil,
                noDegree: noDegreeOnly ? true : nil,
                minSalary: minimumSalary > 0 ? minimumSalary : nil,
                page: page,
                perPage: perPage
            )
            guard generation == searchGeneration, !Task.isCancelled else { return }
            items = resp.items
            sources = resp.sources ?? [:]
            catalogStatus = resp.catalog_status ?? "ready"
            canLoadMore = page < (resp.pages ?? 1)
            
            // Calculate new today
            let today = Calendar.current.startOfDay(for: Date())
            newTodayCount = items.filter { job in
                guard let dateStr = job.posted_at, let date = parseDate(dateStr) else { return false }
                return date >= today
            }.count
            
            // Persist preferences
            persistJobsScopedState()
            
            appContainer.telemetry.retention(.jobSearchPerformed, source: "jobs", meta: [
                "q": keyword, "canton": canton, "results": String(items.count)
            ])
        } catch {
            guard generation == searchGeneration, !Task.isCancelled else { return }
            items = []
            sources = [:]
            catalogStatus = "ready"
            loadErrorMessage = (error as NSError).localizedDescription
            canLoadMore = false
            appContainer.telemetry.error("jobs_search_error", source: "jobs", message: (error as NSError).localizedDescription)
        }
    }
    
    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            page += 1
            let resp = try await APIClient.searchJobs(
                keyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines),
                canton: canton.isEmpty ? nil : canton,
                employmentType: selectedEmployment.serverEmploymentType,
                workplaceType: selectedEmployment == .remote ? "remote" : nil,
                noExperience: noExperienceOnly ? true : nil,
                noDegree: noDegreeOnly ? true : nil,
                minSalary: minimumSalary > 0 ? minimumSalary : nil,
                page: page,
                perPage: perPage
            )
            items.append(contentsOf: resp.items)
            canLoadMore = page < (resp.pages ?? page)
        } catch {
            page -= 1
            canLoadMore = false
        }
    }
    
    private func refreshFavoritesCount() async {
        guard KeychainStore.get("access_token") != nil else {
            favoritesCount = favoriteIds.count
            return
        }
        let favorites = await APIClient.listJobFavorites()
        let remoteIds = Set(favorites.map(\.job_id))
        favoriteIds.formUnion(remoteIds)
        defaults.set(Array(favoriteIds), forKey: favoriteIdsKey)
        favoritesCount = favoriteIds.count

        if let remoteApplications = try? await APIClient.listJobApplications() {
            applications = remoteApplications
            appliedJobIds = Set(remoteApplications.filter { ["applied", "interview", "offer"].contains($0.status) }.map(\.job_id))
            appliedCount = appliedJobIds.count
        }
        alerts = (try? await APIClient.listJobAlerts()) ?? []
    }
    
    private func toggleFavorite(_ job: APIClient.JobItem) {
        haptic(.medium)
        
        let isRemoving = favoriteIds.contains(job.id)
        if isRemoving {
            favoriteIds.remove(job.id)
            favoritesCount = max(0, favoritesCount - 1)
        } else {
            favoriteIds.insert(job.id)
            favoritesCount += 1
        }
        defaults.set(Array(favoriteIds), forKey: favoriteIdsKey)
        guard KeychainStore.get("access_token") != nil else { return }
        Task {
            if isRemoving {
                if !(await APIClient.removeJobFavorite(jobId: job.id, source: job.source)) {
                    await MainActor.run {
                        favoriteIds.insert(job.id)
                        favoritesCount = favoriteIds.count
                    }
                }
            } else {
                let outcome = await APIClient.addJobFavorite(job: job)
                if case .failure = outcome {
                    await MainActor.run {
                        favoriteIds.remove(job.id)
                        favoritesCount = favoriteIds.count
                    }
                }
            }
            await MainActor.run { defaults.set(Array(favoriteIds), forKey: favoriteIdsKey) }
        }
    }
    
    private func shareJob(_ job: APIClient.JobItem) {
        let text = "\(job.title) at \(job.company ?? "Company")\n\(job.url)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
    
    private func draftApply(_ job: APIClient.JobItem) async {
        guard KeychainStore.get("access_token")?.isEmpty == false else {
            showAuthEntry = true
            return
        }
        guard hasPremiumAccess else {
            showSubscription = true
            APIClient.logPaywall(eventType: "view", context: "jobs")
            return
        }
        
        isDrafting = true
        draftedText = ""
        showDraftSheet = true
        
        let text = await APIClient.draftJobApplication(
            title: job.title,
            company: job.company,
            description: job.snippet,
            language: appContainer.currentLocale.identifier,
            candidateSummary: savedCandidateSummary()
        )
        draftedText = text ?? "Не вдалося згенерувати відповідь.".localized
        isDrafting = false
        
        if let text {
            _ = try? await APIClient.updateJobApplication(jobId: job.id, status: "prepared", coverLetter: text)
        }
    }

    private func savedCandidateSummary() -> String? {
        guard !lockManager.userEmail.isEmpty else { return nil }
        let key = "cv_saved_data_\(lockManager.userEmail.lowercased())"
        guard let data = ProtectedLocalStore.data(for: key, migratingFrom: key),
              let resume = try? JSONDecoder().decode(CVResume.self, from: data) else {
            return nil
        }
        let language: CVDocumentLanguage = appContainer.currentLocale.language.languageCode?.identifier == "de"
            ? .german
            : .ukrainian
        return CVDocumentFormatter().candidateSummary(from: resume, language: language)
    }

    private func markApplied(_ job: APIClient.JobItem) async {
        guard KeychainStore.get("access_token") != nil else {
            return
        }
        if !applications.contains(where: { $0.job_id == job.id }) {
            _ = try? await APIClient.updateJobApplication(jobId: job.id, status: "prepared")
        }
        if let updated = try? await APIClient.updateJobApplication(jobId: job.id, status: "applied") {
            applications.removeAll { $0.job_id == job.id }
            applications.append(updated)
            appliedJobIds.insert(job.id)
            appliedCount = appliedJobIds.count
            persistJobsScopedState()
        }
    }

    private func openJob(_ job: APIClient.JobItem) async {
        guard let url = URL(string: job.url) else { return }
        await UIApplication.shared.open(url)
    }

    private func openJobChat(_ job: APIClient.JobItem) async {
        guard job.can_message == true else { return }
        do {
            let conversation = try await appContainer.chatStore.openJobConversation(for: job.id)
            await MainActor.run {
                selectedJob = nil
                selectedConversation = conversation
            }
        } catch {
            appContainer.telemetry.error("job_chat_error", source: "jobs", message: error.localizedDescription)
            await MainActor.run { interactionMessage = error.localizedDescription }
        }
    }

    private func reportJob(_ job: APIClient.JobItem) async {
        do {
            try await APIClient.reportJob(id: job.id, reason: "suspicious")
            haptic(.success)
            await MainActor.run { interactionMessage = "Скаргу надіслано. Модерація перевірить вакансію.".localized }
        } catch {
            haptic(.error)
            await MainActor.run { interactionMessage = error.localizedDescription }
        }
    }

    private func updateApplication(jobID: String, status: String) async {
        guard let updated = try? await APIClient.updateJobApplication(jobId: jobID, status: status) else { return }
        applications.removeAll { $0.job_id == jobID }
        applications.append(updated)
        appliedJobIds = Set(applications.filter { ["applied", "interview", "offer"].contains($0.status) }.map(\.job_id))
        appliedCount = appliedJobIds.count
        persistJobsScopedState()
    }

    private func createAlert(name: String, keywords: String) async {
        guard !keywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let alert = try? await APIClient.createJobAlert(
            name: name,
            keywords: keywords,
            canton: canton.isEmpty ? nil : canton,
            employmentType: selectedEmployment.serverEmploymentType,
            workplaceType: selectedEmployment == .remote ? "remote" : nil
        ) {
            alerts.insert(alert, at: 0)
        }
    }

    private func deleteAlert(_ id: String) async {
        do {
            try await APIClient.deleteJobAlert(id: id)
            alerts.removeAll { $0.id == id }
        } catch {
            interactionMessage = error.localizedDescription
        }
    }
    
    private func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df.date(from: s)
    }
    
    private func primaryCity(from location: String?) -> String? {
        guard let location, !location.isEmpty else { return nil }
        return location.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if targetEnvironment(simulator)
        return
        #else
        if UIAccessibility.isReduceMotionEnabled { return }
        if !CHHapticEngine.capabilitiesForHardware().supportsHaptics { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
    
    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if targetEnvironment(simulator)
        return
        #else
        if UIAccessibility.isReduceMotionEnabled { return }
        if !CHHapticEngine.capabilitiesForHardware().supportsHaptics { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
        #endif
    }
}

private enum CareerRouteState {
    case complete
    case current
    case locked
}

private struct CareerReadinessRing: View {
    let progress: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(JourneyVisual.softBorder, lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(progress, 100))) / 100)
                .stroke(JourneyVisual.lime, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -1) {
                Text("\(progress)%")
                    .font(.system(size: 17, weight: .black, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)
                Text("CV")
                    .font(.system(size: 8, weight: .bold, design: .default))
                    .foregroundColor(JourneyVisual.secondaryText)
            }
        }
        .frame(width: 66, height: 66)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Готовність CV %@ відсотків".localized(with: "\(progress)"))
    }
}

private struct CareerHubMetric: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(value)
                    .font(.system(size: 17, weight: .black, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)
            }
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(JourneyVisual.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .frame(height: 58)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(JourneyVisual.softBorder))
        .accessibilityElement(children: .combine)
    }
}

private struct CareerRouteNode: View {
    let title: String
    let icon: String
    let state: CareerRouteState

    private var fill: Color {
        switch state {
        case .complete: return JourneyVisual.lime
        case .current: return JourneyVisual.lime.opacity(0.16)
        case .locked: return Color.white.opacity(0.055)
        }
    }

    private var foreground: Color {
        switch state {
        case .complete: return .black
        case .current: return JourneyVisual.lime
        case .locked: return .white.opacity(0.32)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: state == .complete ? "checkmark" : icon)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(foreground)
                .frame(width: 28, height: 28)
                .background(fill)
                .clipShape(Circle())
                .overlay(Circle().stroke(state == .current ? JourneyVisual.lime.opacity(0.62) : Color.clear, lineWidth: 1))
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(state == .locked ? JourneyVisual.secondaryText : JourneyVisual.primaryText)
                .lineLimit(1)
        }
        .frame(width: 48)
    }
}

private struct CareerRouteConnector: View {
    let isComplete: Bool

    var body: some View {
        Capsule()
            .fill(isComplete ? JourneyVisual.lime : Color.white.opacity(0.1))
            .frame(maxWidth: .infinity)
            .frame(height: 2)
            .offset(y: -10)
    }
}

// MARK: - AI Match Profile Sheet
private struct AIMatchProfileSheet: View {
    @Binding var desiredPosition: String
    @Binding var skills: String
    @Binding var preferredCanton: String
    @Binding var employmentType: String
    @Binding var remotePreference: Bool
    @Binding var experienceLevel: String
    
    let cantons: [String]
    let onSearch: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let employmentTypes = ["", "Full-time", "Part-time", "Contract", "Internship"]
    private let experienceLevels = ["", "Junior", "Middle", "Senior", "Lead", "Manager"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(colors: [Theme.Colors.primary, Theme.Colors.primaryLight], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        
                        Text("AI Match Profile")
                            .font(.title2.bold())
                        
                        Text("Заповніть профіль для персоналізованого пошуку вакансій".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    
                    // Form
                    VStack(spacing: 20) {
                        // Desired position
                        ProfileField(
                            icon: "briefcase.fill",
                            title: "Бажана посада".localized,
                            placeholder: "напр. iOS Developer, Project Manager".localized,
                            text: $desiredPosition
                        )
                        
                        // Skills
                        ProfileField(
                            icon: "star.fill",
                            title: "Навички".localized,
                            placeholder: "Swift, Python, SQL (через кому)".localized,
                            text: $skills
                        )
                        
                        // Canton
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Бажаний кантон".localized, systemImage: "mappin.circle.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            
                            Menu {
                                ForEach(cantons, id: \.self) { code in
                                    Button(code.isEmpty ? "Будь-який".localized : code) {
                                        preferredCanton = code
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(preferredCanton.isEmpty ? "Будь-який".localized : preferredCanton)
                                        .foregroundColor(preferredCanton.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Employment type
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Тип зайнятості".localized, systemImage: "clock.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            
                            Menu {
                                ForEach(employmentTypes, id: \.self) { type in
                                    Button(type.isEmpty ? "Будь-який".localized : type) {
                                        employmentType = type
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(employmentType.isEmpty ? "Будь-який".localized : employmentType)
                                        .foregroundColor(employmentType.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Experience level
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Рівень досвіду".localized, systemImage: "chart.bar.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            
                            Menu {
                                ForEach(experienceLevels, id: \.self) { level in
                                    Button(level.isEmpty ? "Будь-який".localized : level) {
                                        experienceLevel = level
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(experienceLevel.isEmpty ? "Будь-який".localized : experienceLevel)
                                        .foregroundColor(experienceLevel.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Remote preference
                        Toggle(isOn: $remotePreference) {
                            Label("Віддалена робота".localized, systemImage: "house.fill")
                                .font(.subheadline.bold())
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Search button
                    Button(action: onSearch) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Знайти вакансії".localized)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(JourneyVisual.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [Theme.Colors.primary, Theme.Colors.primaryLight], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .disabled(desiredPosition.isEmpty && skills.isEmpty)
                    .opacity((desiredPosition.isEmpty && skills.isEmpty) ? 0.5 : 1)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("AI Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрити".localized) { dismiss() }
                }
            }
        }
        .journeyScreen(.city, darkness: 0.72)
    }
}

// MARK: - Profile Field
private struct ProfileField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            
            TextField(placeholder, text: $text)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

// MARK: - Jobs Onboarding Sheet
// MARK: - Jobs Onboarding Sheet (Beautiful & Optimized)
private struct JobsOnboardingSheet: View {
    let onClose: () -> Void
    let onSetupProfile: () -> Void
    
    @State private var currentPage: Int = 0
    @State private var appeared: Bool = false
    
    private let slides: [(icon: String, color1: Color, color2: Color, title: String, subtitle: String, features: [String])] = [
        (
            icon: "briefcase.fill",
            color1: Theme.Colors.primary,
            color2: Theme.Colors.primaryDark,
            title: "Знайди роботу мрії".localized,
            subtitle: "Актуальні вакансії з перевірених джерел".localized,
            features: ["Дата оновлення".localized, "Пряме посилання".localized, "Статус джерела".localized]
        ),
        (
            icon: "magnifyingglass",
            color1: Theme.Colors.accent,
            color2: Theme.Colors.accentCoral,
            title: "Розумний пошук".localized,
            subtitle: "Знаходь швидко та точно".localized,
            features: ["Пошук по ключовим словам".localized, "Фільтри по кантону".localized, "Тип зайнятості".localized]
        ),
        (
            icon: "wand.and.stars",
            color1: Theme.Colors.primaryLight,
            color2: Theme.Colors.primary,
            title: "AI Match",
            subtitle: "Пояснює, чому вакансія підходить".localized,
            features: ["Семантичний пошук".localized, "Збіги навичок".localized, "Чого бракує".localized]
        )
    ]
    
    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: JourneyBackdrop.alpine.rawValue, blurRadius: 7, darkness: 0.7)
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .padding(12)
                            .background(Theme.Colors.card)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Content
                TabView(selection: $currentPage) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        OnboardingSlideView(
                            slide: slides[index],
                            appeared: appeared
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 24)
                
                // Buttons
                VStack(spacing: 12) {
                    if currentPage == slides.count - 1 {
                        // Final slide - Setup profile button
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onSetupProfile()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Заповнити профіль".localized)
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Theme.Colors.primary, Theme.Colors.primaryLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        
                        Button {
                            onClose()
                        } label: {
                            Text("Пропустити".localized)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(JourneyVisual.secondaryText)
                        }
                        .padding(.top, 4)
                    } else {
                        // Next button
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Далі".localized)
                                    .font(.system(size: 17, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(JourneyVisual.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.Colors.card)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(JourneyVisual.softBorder, lineWidth: 1)
                            )
                        }
                        
                        Button {
                            onClose()
                        } label: {
                            Text("Пропустити".localized)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(JourneyVisual.secondaryText)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .journeyScreen(.alpine, darkness: 0.7)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.5)) {
                    appeared = true
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Onboarding Slide View
private struct OnboardingSlideView: View {
    let slide: (icon: String, color1: Color, color2: Color, title: String, subtitle: String, features: [String])
    let appeared: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [slide.color1.opacity(0.4), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                
                // Icon circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [slide.color1, slide.color2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: slide.icon)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                }
                .shadow(color: slide.color1.opacity(0.5), radius: 20, x: 0, y: 10)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
            
            // Title
            Text(slide.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(JourneyVisual.primaryText)
                .multilineTextAlignment(.center)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
            
            // Subtitle
            Text(slide.subtitle)
                .font(.system(size: 16))
                .foregroundColor(JourneyVisual.secondaryText)
                .multilineTextAlignment(.center)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
            
            // Features
            VStack(spacing: 12) {
                ForEach(slide.features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [slide.color1, slide.color2],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(feature)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(JourneyVisual.secondaryText)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.card)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .offset(y: appeared ? 0 : 30)
            .opacity(appeared ? 1 : 0)
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Jobs Premium Components
private struct AIProfileProgressRing: View {
    let progress: Double

    private var percentage: Int {
        Int((min(max(progress, 0), 1) * 100).rounded())
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(JourneyVisual.softBorder, lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(progress, 0.035))
                .stroke(JourneyVisual.lime, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percentage)%")
                .font(.system(size: 13, weight: .bold, design: .default))
                .foregroundColor(JourneyVisual.primaryText)
        }
        .frame(width: 46, height: 46)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Профіль заповнено на %@ відсотків".localized(with: "\(percentage)"))
    }
}

private struct JobsInlineMetric: View {
    let icon: String
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text("\(value) \(label)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(JourneyVisual.secondaryText)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.76)
    }
}

private struct JobsMenuPill: View {
    let icon: String
    let text: String
    let isActive: Bool
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .foregroundColor(isActive ? .black : JourneyVisual.primaryText)
        .padding(.horizontal, 15)
        .frame(height: 44)
        .background(isActive ? JourneyVisual.lime : Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(isActive ? JourneyVisual.lime : Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Dashboard Metric Card
private struct DashboardMetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)
            }
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(JourneyVisual.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.Colors.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Filter Chip
private struct FilterChip: View {
    let icon: String?
    let text: String
    let isActive: Bool
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(text)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isActive ? .black : JourneyVisual.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isActive ? Theme.Colors.primary : Color.white.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Tag Chip
private struct QuickTagChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .black : Theme.Colors.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.15))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.Colors.primary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Job Card
private struct JobCard: View {
    let job: APIClient.JobItem
    let isSaved: Bool
    let matchScore: Int?
    let onTap: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void
    
    private var isNew: Bool {
        guard let dateStr = job.posted_at else { return false }
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: dateStr) else { return false }
        return date > Date().addingTimeInterval(-24 * 60 * 60)
    }
    
    private var isRemote: Bool {
        (job.employment_type ?? "").lowercased().contains("remote") ||
        (job.location ?? "").lowercased().contains("remote")
    }

    private var companyInitial: String {
        String((job.company ?? "S").prefix(1)).uppercased()
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white)
                Text(companyInitial)
                    .font(.system(size: 25, weight: .black, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [JourneyVisual.lime, Color(red: 0.15, green: 0.36, blue: 0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.title)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(JourneyVisual.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 5) {
                            Text(job.company ?? "Компанія".localized)
                            if isNew {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                    }

                    Spacer(minLength: 4)

                    Button(action: onSave) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isSaved ? Theme.Colors.textPrimary : JourneyVisual.secondaryText)
                            .frame(width: 42, height: 42)
                            .background(Theme.Colors.card)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSaved ? "Видалити зі збережених".localized : "Зберегти вакансію".localized)
                }

                HStack(spacing: 7) {
                    Image(systemName: "mappin")
                    Text(job.location ?? (ResidenceCountry(rawValue: APIClient.countryCode)?.name ?? "Швейцарія".localized))
                    if let employment = job.employment_type, !employment.isEmpty {
                        Text("·")
                        Text(employment)
                    } else if isRemote {
                        Text("· Remote")
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(JourneyVisual.secondaryText)
                .lineLimit(1)

                HStack(spacing: 10) {
                    if let salary = job.salary, !salary.isEmpty {
                        Text(salary)
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(JourneyVisual.primaryText)
                            .lineLimit(1)
                    } else {
                        Text(job.source.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(JourneyVisual.secondaryText)
                    }

                    if let score = matchScore, score > 0 {
                        Text("%@%% збіг".localized(with: "\(score)"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(JourneyVisual.lime.opacity(0.11))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(JourneyVisual.lime.opacity(0.32), lineWidth: 1))
                    }

                    Spacer()

                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Поділитися вакансією".localized)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(JourneyVisual.secondaryText)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.72))
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    matchScore != nil ? JourneyVisual.lime.opacity(0.32) : Color.white.opacity(0.16),
                    lineWidth: 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Відкрити вакансію", onTap)
    }
}

// MARK: - Match Score Badge
private struct MatchScoreBadge: View {
    let score: Int
    
    private var color: Color {
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .gray
    }
    
    var body: some View {
        Text("\(score)%")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(8)
    }
}

// MARK: - Job Tag
private struct JobTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

// MARK: - Job Card Skeleton
private struct JobCardSkeleton: View {
    @State private var shimmer = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(JourneyVisual.softBorder)
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(JourneyVisual.softBorder)
                    .frame(height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(JourneyVisual.softBorder)
                    .frame(width: 120, height: 12)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(JourneyVisual.softBorder)
                    .frame(width: 80, height: 10)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .overlay(
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.1), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: shimmer ? 400 : -400)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Empty State
private struct JobsEmptyState: View {
    let hasSearched: Bool
    var isAIMatch: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isAIMatch ? "wand.and.stars" : (hasSearched ? "magnifyingglass" : "briefcase.fill"))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
                .frame(width: 48, height: 48)
                .background(JourneyVisual.lime.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(isAIMatch ? "Немає відповідних вакансій".localized : (hasSearched ? "Нічого не знайдено".localized : "Почніть пошук".localized))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)

                Text(isAIMatch ? "Зміни параметри AI Match".localized : (hasSearched ? "Зміни фільтри або ключові слова".localized : "Введи посаду або навичку".localized))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
    }
}

private struct JobsRecoveryState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(JourneyVisual.lime.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(JourneyVisual.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
    }
}

// MARK: - Job Detail Sheet
private struct JobDetailSheet: View {
    let job: APIClient.JobItem
    let matchScore: Int?
    let matchReasons: [String]
    let isApplied: Bool
    let onOpen: () async -> Void
    let onDraft: () async -> Void
    let onApplied: () async -> Void
    let onChat: () async -> Void
    let onReport: () async -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showReportConfirmation = false
    @State private var translatedDescription: String?
    @State private var isTranslating = false
    @State private var translationError: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(job.title)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        Text([job.company, job.location, job.canton].compactMap { $0 }.joined(separator: " • "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()

                    HStack(spacing: 10) {
                        Label(job.is_verified == true ? "Перевірене джерело".localized : job.source.capitalized, systemImage: job.is_verified == true ? "checkmark.seal.fill" : "link")
                        if let freshness = job.freshness {
                            Label(freshness == "fresh" ? "Оновлено нещодавно".localized : "Перевір дату".localized, systemImage: "clock")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(job.freshness == "stale" ? .orange : Theme.Colors.primary)

                    if let matchScore {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Підходить на %@%%".localized(with: "\(matchScore)"))
                                .font(.headline)
                            ForEach(matchReasons, id: \.self) { reason in
                                Label(reason, systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.primary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    jobFacts

                    if job.recognition_required == true {
                        Label(
                            "Для цієї професії може знадобитися офіційне визнання диплома %@.".localized(with: (ResidenceCountry(rawValue: APIClient.countryCode) ?? .switzerland).inCountryPhrase),
                            systemImage: "checkmark.seal"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.orange)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    
                    // Description
                    if let description = job.description ?? job.snippet, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(translatedDescription == nil ? "Опис вакансії".localized : "Переклад українською".localized)
                                    .font(.headline)
                                Spacer()
                                Button {
                                    if translatedDescription != nil {
                                        translatedDescription = nil
                                    } else {
                                        Task { await translateDescription() }
                                    }
                                } label: {
                                    if isTranslating {
                                        ProgressView()
                                    } else {
                                        Label(
                                            translatedDescription == nil ? "Перекласти".localized : "Оригінал".localized,
                                            systemImage: "character.book.closed"
                                        )
                                    }
                                }
                                .font(.caption.weight(.bold))
                                .disabled(isTranslating)
                            }
                            Text(translatedDescription ?? description)
                                .font(.body)
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        if job.source != "sweezy" {
                            Button {
                                Task { await onOpen() }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("Відкрити вакансію".localized)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.Colors.primary)
                                .foregroundColor(Theme.Colors.textOnPrimary)
                                .cornerRadius(12)
                            }
                        }

                        if !isApplied {
                            Button {
                                Task { await onApplied() }
                            } label: {
                                Label("Позначити як відправлено".localized, systemImage: "paperplane.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.Colors.card)
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                            }
                        } else {
                            Label("Відгук додано до трекера".localized, systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(JourneyVisual.accentText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }

                        if job.can_message == true {
                            Button {
                                Task { await onChat() }
                            } label: {
                                Label("Написати роботодавцю".localized, systemImage: "bubble.left.and.bubble.right.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.Colors.card)
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                            }
                        }
                        
                        Button {
                            Task { await onDraft() }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("AI Відповідь".localized)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.Colors.accent)
                            .foregroundColor(JourneyVisual.primaryText)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Деталі".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showReportConfirmation = true
                        } label: {
                            Label("Поскаржитися".localized, systemImage: "exclamationmark.triangle")
                        }
                        Button("Закрити".localized) { dismiss() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .journeyScreen(.city, darkness: 0.72)
        .confirmationDialog("Повідомити про підозрілу вакансію?".localized, isPresented: $showReportConfirmation) {
            Button("Надіслати скаргу".localized, role: .destructive) { Task { await onReport() } }
            Button("Скасувати".localized, role: .cancel) {}
        }
        .alert("Переклад недоступний".localized, isPresented: Binding(
            get: { translationError != nil },
            set: { if !$0 { translationError = nil } }
        )) {
            Button("OK", role: .cancel) { translationError = nil }
        } message: {
            Text(translationError ?? "Спробуйте пізніше.".localized)
        }
    }

    @MainActor
    private func translateDescription() async {
        isTranslating = true
        defer { isTranslating = false }
        do {
            translatedDescription = try await APIClient.translateJob(id: job.id, language: "uk").text
        } catch {
            translationError = error.localizedDescription
        }
    }

    private var jobFacts: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let salary = salaryText {
                Label(salary, systemImage: "banknote")
                Text("Вказана зарплата — brutto. Netto залежить від кантону, сімейного стану та відрахувань.".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let workload = workloadText {
                Label(workload, systemImage: "clock")
            }
            if let workplace = job.workplace_type, !workplace.isEmpty {
                Label(workplaceLabel(workplace), systemImage: "house.and.flag")
            }
            if let languages = job.languages, !languages.isEmpty {
                Label("Мови: \(languages.joined(separator: ", "))", systemImage: "character.bubble")
            }
            if let permits = job.permit_requirements, !permits.isEmpty {
                Label("Дозвіл: \(permits.joined(separator: ", "))", systemImage: "person.text.rectangle")
            }
            if job.no_experience_required == true {
                Label("Підходить без досвіду".localized, systemImage: "sparkles")
            }
            if job.degree_required == false {
                Label("Диплом не вказаний як обов’язковий".localized, systemImage: "graduationcap")
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundColor(.primary)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var salaryText: String? {
        if let salary = job.salary, !salary.isEmpty { return salary }
        guard job.salary_min != nil || job.salary_max != nil else { return nil }
        let currency = job.salary_currency ?? (APIClient.countryCode == "CH" ? "CHF" : "EUR")
        let period = ["year": "/рік".localized, "month": "/місяць".localized, "hour": "/год".localized].first { job.salary_period?.lowercased().contains($0.key) == true }?.value ?? ""
        if let minimum = job.salary_min, let maximum = job.salary_max {
            return "\(currency) \(minimum.formatted())–\(maximum.formatted())\(period) brutto"
        }
        if let minimum = job.salary_min { return "від %@ %@%@ brutto".localized(with: "\(currency)", "\(minimum.formatted())", "\(period)") }
        if let maximum = job.salary_max { return "до %@ %@%@ brutto".localized(with: "\(currency)", "\(maximum.formatted())", "\(period)") }
        return nil
    }

    private var workloadText: String? {
        if let minimum = job.workload_min, let maximum = job.workload_max { return "Зайнятість: %@–%@%%".localized(with: "\(minimum)", "\(maximum)") }
        if let minimum = job.workload_min { return "Зайнятість: від %@%%".localized(with: "\(minimum)") }
        if let maximum = job.workload_max { return "Зайнятість: до %@%%".localized(with: "\(maximum)") }
        return job.employment_type
    }

    private func workplaceLabel(_ value: String) -> String {
        ["remote": "Віддалено".localized, "hybrid": "Гібридно".localized, "on_site": "На місці".localized][value] ?? value
    }
}

// MARK: - Draft Sheet
private struct DraftSheet: View {
    let text: String?
    let isDrafting: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isDrafting {
                        HStack {
                            ProgressView()
                            Text("Генерую відповідь...".localized)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(text ?? "")
                            .font(.body)
                    }
                }
                .padding()
            }
            .navigationTitle("AI Відповідь".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Копіювати".localized) {
                        if let text {
                            UIPasteboard.general.string = text
                        }
                        dismiss()
                    }
                }
            }
        }
        .journeyScreen(.city, darkness: 0.74)
    }
}

private struct JobApplicationTrackerSheet: View {
    let applications: [APIClient.JobApplication]
    let onStatusChange: (String, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    private let stages = ["saved", "prepared", "applied", "interview", "offer", "rejected", "withdrawn"]

    private func title(_ status: String) -> String {
        ["saved": "Збережено".localized, "prepared": "Готово".localized, "applied": "Відправлено".localized, "interview": "Співбесіда".localized, "offer": "Офер".localized, "rejected": "Відмова".localized, "withdrawn": "Закрито".localized][status] ?? status
    }

    private func nextStages(after status: String) -> [String] {
        [
            "saved": ["prepared", "applied", "withdrawn"],
            "prepared": ["saved", "applied", "withdrawn"],
            "applied": ["interview", "rejected", "withdrawn"],
            "interview": ["offer", "rejected", "withdrawn"],
            "offer": ["withdrawn"],
            "rejected": ["saved"],
            "withdrawn": ["saved"]
        ][status] ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Твій шлях до оферу".localized)
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text("Оновлюй статус після кожного кроку. Уся історія синхронізується між пристроями.".localized)
                        .font(.subheadline)
                        .foregroundColor(JourneyVisual.secondaryText)

                    if applications.isEmpty {
                        JobsRecoveryState(
                            icon: "paperplane",
                            title: "Трекер поки порожній".localized,
                            message: "Відкрий вакансію, підготуй відгук або познач його як відправлений.".localized,
                            actionTitle: "Знайти вакансію".localized
                        ) { dismiss() }
                    } else {
                        ForEach(stages, id: \.self) { stage in
                            let rows = applications.filter { $0.status == stage }
                            if !rows.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(title(stage))
                                            .font(.headline)
                                            .foregroundColor(JourneyVisual.primaryText)
                                        Text("\(rows.count)")
                                            .font(.caption.bold())
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(JourneyVisual.lime)
                                            .clipShape(Capsule())
                                    }
                                    ForEach(rows) { application in
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack(alignment: .top) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(application.job_title)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(JourneyVisual.primaryText)
                                                    Text([application.company, application.location].compactMap { $0 }.joined(separator: " · "))
                                                        .font(.caption)
                                                        .foregroundColor(JourneyVisual.secondaryText)
                                                }
                                                Spacer()
                                                if let url = URL(string: application.job_url) {
                                                    Link(destination: url) {
                                                        Image(systemName: "arrow.up.right")
                                                            .foregroundColor(Theme.Colors.textPrimary)
                                                    }
                                                }
                                            }
                                            Menu {
                                                ForEach(nextStages(after: application.status), id: \.self) { next in
                                                    Button(title(next)) {
                                                        Task { await onStatusChange(application.job_id, next) }
                                                    }
                                                }
                                            } label: {
                                                Label("Змінити етап".localized, systemImage: "arrow.triangle.2.circlepath")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.black)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(JourneyVisual.lime)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            }
                                        }
                                        .padding(14)
                                        .background(Theme.Colors.card)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JourneyVisual.softBorder))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .background(JourneyVisual.pageBackground.ignoresSafeArea())
            .navigationTitle("Відгуки".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово".localized) { dismiss() } } }
        }
    }
}

private struct JobAlertsSheet: View {
    let alerts: [APIClient.JobAlert]
    let onCreate: (String, String) async -> Void
    let onDelete: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var keywords: String

    init(
        alerts: [APIClient.JobAlert],
        defaultKeywords: String,
        defaultCanton: String,
        onCreate: @escaping (String, String) async -> Void,
        onDelete: @escaping (String) async -> Void
    ) {
        self.alerts = alerts
        self.onCreate = onCreate
        self.onDelete = onDelete
        _name = State(initialValue: defaultCanton.isEmpty ? "Нові вакансії".localized : "Нові вакансії · %@".localized(with: "\(defaultCanton)"))
        _keywords = State(initialValue: defaultKeywords)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Не пропусти свій шанс".localized)
                        .font(.system(size: 29, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text("Sweezy перевіряє нові збіги після синхронізації каталогу та надсилає push лише про релевантні вакансії.".localized)
                        .font(.subheadline)
                        .foregroundColor(JourneyVisual.secondaryText)

                    VStack(spacing: 12) {
                        JobsDarkField(title: "Назва".localized, text: $name, icon: "bell")
                        JobsDarkField(title: "Ключові слова".localized, text: $keywords, icon: "magnifyingglass")
                        Button {
                            Task { await onCreate(name, keywords) }
                        } label: {
                            Label("Створити сповіщення".localized, systemImage: "bell.badge.fill")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(JourneyVisual.lime)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(keywords.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                        .opacity(keywords.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 ? 0.45 : 1)
                    }
                    .padding(15)
                    .background(Theme.Colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    ForEach(alerts) { alert in
                        HStack(spacing: 13) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.black)
                                .frame(width: 42, height: 42)
                                .background(JourneyVisual.lime)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(alert.name).font(.headline).foregroundColor(JourneyVisual.primaryText)
                                Text([alert.keywords, alert.canton].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundColor(JourneyVisual.secondaryText)
                            }
                            Spacer()
                            Button(role: .destructive) { Task { await onDelete(alert.id) } } label: {
                                Image(systemName: "trash")
                            }
                        }
                        .padding(14)
                        .background(Theme.Colors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(JourneyVisual.pageBackground.ignoresSafeArea())
            .navigationTitle("Job Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово".localized) { dismiss() } } }
        }
    }
}

private struct JobMapSheet: View {
    let jobs: [APIClient.JobItem]
    let onSelect: (APIClient.JobItem) -> Void
    @Environment(\.dismiss) private var dismiss

    private var mappedJobs: [APIClient.JobItem] {
        jobs.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map {
                    ForEach(mappedJobs) { job in
                        if let latitude = job.latitude, let longitude = job.longitude {
                            Annotation(job.title, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                                Button { onSelect(job) } label: {
                                    Image(systemName: "briefcase.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 40, height: 40)
                                        .background(JourneyVisual.lime)
                                        .clipShape(Circle())
                                        .shadow(radius: 8)
                                }
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))

                if mappedJobs.isEmpty {
                    Text("У цих результатах немає координат. Зміни пошук або кантон.".localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(20)
                }
            }
            .navigationTitle("Карта вакансій".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрити".localized) { dismiss() } } }
        }
    }
}

private struct JobEmployerHubSheet: View {
    let cantons: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var company = ""
    @State private var website = ""
    @State private var canton = ""
    @State private var contactName = ""
    @State private var contactEmail = ""
    @State private var companyDescription = ""
    @State private var title = ""
    @State private var jobDescription = ""
    @State private var location = ""
    @State private var skills = ""
    @State private var languages = "Deutsch"
    @State private var salaryMin = ""
    @State private var salaryMax = ""
    @State private var ownJobs: [APIClient.JobItem] = []
    @State private var candidates: [APIClient.EmployerJobApplication] = []
    @State private var isVerified = false
    @State private var isLoading = false
    @State private var message: String?
    @State private var messageIsError = false

    private var activeCountry: ResidenceCountry {
        ResidenceCountry(rawValue: APIClient.countryCode) ?? .switzerland
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Знайди людей, які підходять".localized)
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Label(isVerified ? "Перевірена компанія".localized : "Профіль очікує перевірки".localized, systemImage: isVerified ? "checkmark.seal.fill" : "clock.badge")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(isVerified ? JourneyVisual.lime : .orange)

                    JobsPanelTitle("Компанія".localized, icon: "building.2")
                    VStack(spacing: 11) {
                        JobsDarkField(title: "Назва компанії".localized, text: $company, icon: "building.2")
                        JobsDarkField(title: "Контактна особа".localized, text: $contactName, icon: "person")
                        JobsDarkField(title: "Робочий email".localized, text: $contactEmail, icon: "envelope")
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        JobsDarkField(title: "Website (необов'язково)".localized, text: $website, icon: "globe")
                            .textInputAutocapitalization(.never)
                        Picker(activeCountry.subdivisionTitle, selection: $canton) {
                            ForEach(cantons.filter { !$0.isEmpty }, id: \.self) { Text($0).tag($0) }
                        }
                        .tint(JourneyVisual.lime)
                        JobsDarkField(title: "Про компанію".localized, text: $companyDescription, icon: "text.alignleft")
                    }

                    JobsPanelTitle("Нова вакансія".localized, icon: "briefcase")
                    VStack(spacing: 11) {
                        JobsDarkField(title: "Посада".localized, text: $title, icon: "briefcase")
                        JobsDarkField(title: "Місто / адреса".localized, text: $location, icon: "mappin")
                        JobsDarkField(title: "Опис — мінімум 30 символів".localized, text: $jobDescription, icon: "text.alignleft")
                        JobsDarkField(title: "Навички через кому".localized, text: $skills, icon: "checkmark.circle")
                        JobsDarkField(title: "Мови через кому".localized, text: $languages, icon: "character.book.closed")
                        HStack {
                            JobsDarkField(title: "%@ від".localized(with: "\(activeCountry.currencyCode)"), text: $salaryMin, icon: "banknote")
                                .keyboardType(.numberPad)
                            JobsDarkField(title: "%@ до".localized(with: "\(activeCountry.currencyCode)"), text: $salaryMax, icon: "banknote")
                                .keyboardType(.numberPad)
                        }
                    }

                    Button {
                        Task { await publish() }
                    } label: {
                        HStack {
                            if isLoading { ProgressView().tint(.black) }
                            Text("Надіслати на модерацію".localized)
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(JourneyVisual.lime)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .disabled(isLoading || company.count < 2 || title.count < 3 || jobDescription.count < 30)
                    .opacity(company.count < 2 || title.count < 3 || jobDescription.count < 30 ? 0.45 : 1)

                    if let message {
                        Text(message)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(messageIsError ? .orange : JourneyVisual.lime)
                    }

                    if !ownJobs.isEmpty {
                        JobsPanelTitle("Мої вакансії".localized, icon: "tray.full")
                        ForEach(ownJobs) { job in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(job.title).font(.headline).foregroundColor(JourneyVisual.primaryText)
                                    Text(["pending": "На модерації".localized, "active": "Активна".localized, "rejected": "Відхилена".localized, "closed": "Закрита".localized][job.status ?? ""] ?? (job.status ?? ""))
                                        .font(.caption).foregroundColor(JourneyVisual.secondaryText)
                                }
                                Spacer()
                                Image(systemName: job.is_verified == true ? "checkmark.seal.fill" : "clock")
                                    .foregroundColor(job.is_verified == true ? JourneyVisual.lime : .orange)
                            }
                            .padding(14)
                            .background(Theme.Colors.card)
                            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        }
                    }

                    if !candidates.isEmpty {
                        JobsPanelTitle("Відгуки кандидатів".localized, icon: "person.2.badge.gearshape")
                        ForEach(candidates) { candidate in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(candidate.job_title)
                                            .font(.headline)
                                            .foregroundColor(JourneyVisual.primaryText)
                                        Text(candidate.candidate_email)
                                            .font(.subheadline)
                                            .foregroundColor(JourneyVisual.secondaryText)
                                    }
                                    Spacer()
                                    Text(applicationStatusTitle(candidate.status))
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(candidate.status == "offer" ? .black : JourneyVisual.lime)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(candidate.status == "offer" ? JourneyVisual.lime : JourneyVisual.lime.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                if candidate.status == "applied" {
                                    HStack(spacing: 9) {
                                        employerStatusButton("Співбесіда".localized, icon: "video", status: "interview", candidate: candidate)
                                        employerStatusButton("Відмовити".localized, icon: "xmark", status: "rejected", candidate: candidate)
                                    }
                                } else if candidate.status == "interview" {
                                    HStack(spacing: 9) {
                                        employerStatusButton("Зробити offer".localized, icon: "checkmark.seal", status: "offer", candidate: candidate)
                                        employerStatusButton("Відмовити".localized, icon: "xmark", status: "rejected", candidate: candidate)
                                    }
                                }
                            }
                            .padding(15)
                            .background(Theme.Colors.card)
                            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 19).stroke(JourneyVisual.softBorder, lineWidth: 1))
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .background(JourneyVisual.pageBackground.ignoresSafeArea())
            .navigationTitle("Для роботодавців".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово".localized) { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        if canton.isEmpty {
            canton = activeCountry.defaultSubdivisionCode
        }
        guard KeychainStore.get("access_token") != nil else {
            message = "Увійди в акаунт, щоб публікувати вакансії.".localized
            messageIsError = true
            return
        }
        if let profile = try? await APIClient.getJobEmployerProfile() {
            company = profile.company_name
            website = profile.website ?? ""
            canton = profile.canton
            contactName = profile.contact_name
            contactEmail = profile.contact_email
            companyDescription = profile.description ?? ""
            isVerified = profile.is_verified
        }
        ownJobs = (try? await APIClient.listEmployerJobs()) ?? []
        candidates = (try? await APIClient.listEmployerJobApplications()) ?? []
    }

    private func applicationStatusTitle(_ status: String) -> String {
        ["applied": "Новий відгук".localized, "interview": "Співбесіда".localized, "offer": "Offer", "rejected": "Відмовлено".localized, "withdrawn": "Відкликано".localized][status] ?? status
    }

    private func employerStatusButton(
        _ title: String,
        icon: String,
        status: String,
        candidate: APIClient.EmployerJobApplication
    ) -> some View {
        Button {
            Task {
                do {
                    let updated = try await APIClient.updateEmployerJobApplication(id: candidate.id, status: status)
                    if let index = candidates.firstIndex(where: { $0.id == updated.id }) { candidates[index] = updated }
                } catch {
                    message = "Помилка: %@".localized(with: "\(error.localizedDescription)")
                    messageIsError = true
                }
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundColor(status == "rejected" ? .white : .black)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(status == "rejected" ? Color.white.opacity(0.09) : JourneyVisual.lime)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func publish() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let profile = try await APIClient.saveJobEmployerProfile(.init(
                company_name: company,
                website: website.isEmpty ? nil : website,
                canton: canton,
                contact_name: contactName,
                contact_email: contactEmail,
                description: companyDescription.isEmpty ? nil : companyDescription
            ))
            isVerified = profile.is_verified
            let job = try await APIClient.createEmployerJob(.init(
                title: title,
                description: jobDescription,
                location: location,
                canton: canton,
                employment_type: "full",
                workplace_type: "on_site",
                workload_min: 80,
                workload_max: 100,
                salary_min: Int(salaryMin),
                salary_max: Int(salaryMax),
                salary_period: "year",
                languages: languages.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                skills: skills.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                permit_requirements: [],
                experience_level: nil,
                no_experience_required: false,
                degree_required: false,
                recognition_required: false,
                apply_url: nil,
                expires_at: nil
            ))
            ownJobs.insert(job, at: 0)
            title = ""
            jobDescription = ""
            message = "Вакансію надіслано на модерацію.".localized
            messageIsError = false
        } catch {
            message = "Помилка: %@".localized(with: "\(error.localizedDescription)")
            messageIsError = true
        }
    }
}

private struct JobsPanelTitle: View {
    let title: String
    let icon: String
    init(_ title: String, icon: String) { self.title = title; self.icon = icon }
    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundColor(JourneyVisual.primaryText)
            .padding(.top, 4)
    }
}

private struct JobsDarkField: View {
    let title: String
    @Binding var text: String
    let icon: String
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon).foregroundColor(Theme.Colors.textPrimary).frame(width: 22)
            TextField(title, text: $text, axis: .vertical)
                .foregroundColor(JourneyVisual.primaryText)
                .lineLimit(1...5)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(JourneyVisual.softBorder))
    }
}

#Preview {
    let lockManager = AppLockManager()
    lockManager.userEmail = "preview@sweezy.app"
    lockManager.userName = "Preview"
    lockManager.isRegistered = true
    
    return JobsView()
        .environmentObject(AppContainer())
        .environmentObject(lockManager)
        .environmentObject(SessionManager(lockManager: lockManager))
}
