//
//  JobsView.swift
//  sweezy
//
//  Swiss job finder with modern dashboard design and AI Match
//

import SwiftUI
import CoreHaptics

struct JobsView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var keyword: String = ""
    @State private var canton: String = ""
    @State private var isLoading: Bool = false
    @State private var items: [APIClient.JobItem] = []
    @State private var sources: [String: Int] = [:]
    @State private var favoriteIds: Set<String> = []
    @State private var didSearchOnce: Bool = false
    @State private var selectedJob: APIClient.JobItem?
    @State private var favoritesCount: Int = 0
    @State private var page: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var selectedEmployment: EmploymentFilter = .all
    @State private var selectedCity: String = ""
    @State private var showAdvancedFilters: Bool = false
    @State private var showDraftSheet: Bool = false
    @State private var draftedText: String?
    @State private var isDrafting: Bool = false
    
    // AI Match
    @State private var showAIMatchProfile: Bool = false
    @State private var isAIMatching: Bool = false
    @State private var matchedItems: [APIClient.JobItem] = []
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
    private let cantons = ["", "AG", "AI", "AR", "BE", "BL", "BS", "FR", "GE", "GL", "GR", "JU", "LU", "NE", "NW", "OW", "SG", "SH", "SO", "SZ", "TG", "TI", "UR", "VD", "VS", "ZG", "ZH"]
    private let quickTags = ["Java", "Driver", "Nurse", "QA", "Warehouse", "React", "Manager", "Sales"]
    private let defaults = UserDefaults.standard
    
    private enum EmploymentFilter: String, CaseIterable {
        case all = "Всі"
        case fullTime = "Full-time"
        case partTime = "Part-time"
        case contract = "Contract"
        case remote = "Remote"
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
                case .remote: if !t.contains("remote") && !t.contains("home") { return false }
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
    
    // TEMPORARY (App Store review): IAP removed, all features are fully unlocked.
    private let hasPremiumAccess: Bool = true
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            Image("jobs-zurich-hero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 610)
                .clipped()
                .overlay(Color.black.opacity(0.24))
                .overlay(
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.22), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(edges: .top)
                .accessibilityHidden(true)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    heroSection

                    VStack(spacing: 13) {
                        aiMatchSection
                        smartFiltersSection
                        dashboardSection

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
            JobDetailSheet(job: job, onDraft: { await draftApply(job) })
                .environmentObject(appContainer)
        }
        .sheet(isPresented: $showDraftSheet) {
            DraftSheet(text: draftedText, isDrafting: isDrafting)
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
                applyJobsPresetIfNeeded()
                didLoadScopedState = true
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
            draftedText = nil
            matchedItems = []
            didSearchOnce = false
            Task {
                await performSearch()
                await refreshFavoritesCount()
            }
        }
    }
    
    // MARK: - Hero
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial.opacity(0.78))
                    .background(Color.black.opacity(0.34))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Назад")

            Spacer(minLength: 12)

            Text("РОБОТА У ШВЕЙЦАРІЇ")
                .font(.system(size: 13, weight: .bold))
                .tracking(2.2)
                .foregroundColor(JourneyVisual.lime)

            Text("Знайди роботу,\nяка підходить тобі")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.82)
                .lineSpacing(-2)
                .padding(.top, 13)
        }
        .frame(maxWidth: .infinity, minHeight: 225, alignment: .topLeading)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 16)
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
                            .foregroundColor(.white)
                        Text(hasAIProfile ? "За досвідом і твоїми цілями" : "Профіль для точного підбору")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.62))
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
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Налаштувати AI профіль")
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
                        Text(hasAIProfile ? "Знайти збіги" : "Налаштувати профіль")
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
            JobsInlineMetric(icon: "sparkles", value: newTodayCount, label: "нових")
            Circle().fill(Color.white.opacity(0.34)).frame(width: 4, height: 4)
            JobsInlineMetric(icon: "heart", value: favoritesCount, label: "збережено")
            Circle().fill(Color.white.opacity(0.34)).frame(width: 4, height: 4)
            JobsInlineMetric(icon: "paperplane", value: appliedCount, label: "відгуків")
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
                    .foregroundColor(.white.opacity(0.62))

                TextField("Посада, навичка або компанія", text: $keyword)
                    .foregroundColor(.white)
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
                            .foregroundColor(.white.opacity(0.44))
                    }
                }
            }
            .padding(.horizontal, 17)
            .frame(height: 54)
            .background(.ultraThinMaterial.opacity(0.7))
            .background(Color.black.opacity(0.32))
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Menu {
                        ForEach(cantons, id: \.self) { code in
                            Button(code.isEmpty ? "Всі кантони" : code) {
                                canton = code
                                showMatchResults = false
                                Task { await performSearch() }
                            }
                        }
                    } label: {
                        JobsMenuPill(icon: "mappin", text: canton.isEmpty ? "Кантон" : canton, isActive: !canton.isEmpty)
                    }

                    Menu {
                        ForEach(EmploymentFilter.allCases, id: \.self) { filter in
                            Button(filter.rawValue) {
                                selectedEmployment = filter
                                haptic(.light)
                            }
                        }
                    } label: {
                        JobsMenuPill(
                            icon: "briefcase",
                            text: selectedEmployment == .all ? "Тип роботи" : selectedEmployment.rawValue,
                            isActive: selectedEmployment != .all
                        )
                    }

                    Button {
                        selectedEmployment = selectedEmployment == .remote ? .all : .remote
                        haptic(.light)
                    } label: {
                        JobsMenuPill(icon: "house", text: "Віддалено", isActive: selectedEmployment == .remote, showsChevron: false)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) { showAdvancedFilters.toggle() }
                        haptic(.light)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(showAdvancedFilters ? .black : .white)
                            .frame(width: 44, height: 44)
                            .background(showAdvancedFilters ? JourneyVisual.lime : Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
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
                Text("Швидкий пошук")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                quickTagsSection

                if !topCities.isEmpty {
                    Divider().overlay(Color.white.opacity(0.12))
                    Text("Міста")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    cityChipsSection
                }

                if showMatchResults {
                    Button {
                        showMatchResults = false
                        haptic(.light)
                    } label: {
                        Label("Скинути AI результати", systemImage: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(JourneyVisual.lime)
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
                QuickTagChip(text: "Всі міста", isSelected: selectedCity.isEmpty) {
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
                            .foregroundColor(JourneyVisual.lime)
                        Text("AI результати")
                            .foregroundColor(.white)
                    }
                } else {
                    Text("Рекомендовано для тебе")
                        .foregroundColor(.white)
                }

                Spacer()

                if !displayedItems.isEmpty {
                    Text("\(displayedItems.count) вакансій")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(JourneyVisual.lime)
                }
            }
            .font(.system(size: 21, weight: .bold, design: .rounded))
            .padding(.top, 6)
            
            if isLoading || isAIMatching {
                // Skeleton loading
                ForEach(0..<4, id: \.self) { _ in
                    JobCardSkeleton()
                }
            } else if displayedItems.isEmpty {
                // Empty state
                JobsEmptyState(hasSearched: didSearchOnce, isAIMatch: showMatchResults)
            } else {
                // Job cards
                ForEach(displayedItems, id: \.id) { job in
                    JobCard(
                        job: job,
                        isSaved: favoriteIds.contains(job.id),
                        matchScore: showMatchResults ? calculateMatchScore(job) : nil,
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
                                ProgressView().tint(.white)
                            } else {
                                Text("Завантажити ще")
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.1))
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
            // Fetch jobs with profile-based query
            let resp = try await APIClient.searchJobs(
                keyword: searchQuery,
                canton: searchCanton,
                page: 1,
                perPage: 50 // Get more for better matching
            )
            
            // Score and sort jobs
            var scoredJobs = resp.items.map { job -> (job: APIClient.JobItem, score: Int) in
                let score = calculateMatchScore(job)
                return (job, score)
            }
            
            // Sort by score descending
            scoredJobs.sort { $0.score > $1.score }
            
            // Take top matches
            matchedItems = scoredJobs.prefix(20).map { $0.job }
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
    
    private func calculateMatchScore(_ job: APIClient.JobItem) -> Int {
        var score = 0
        let title = job.title.lowercased()
        let snippet = (job.snippet ?? "").lowercased()
        let location = (job.location ?? "").lowercased()
        let employmentType = (job.employment_type ?? "").lowercased()
        
        // Position match (0-40 points)
        if !aiDesiredPosition.isEmpty {
            let positionWords = aiDesiredPosition.lowercased().components(separatedBy: " ")
            for word in positionWords where word.count > 2 {
                if title.contains(word) { score += 15 }
                if snippet.contains(word) { score += 5 }
            }
        }
        
        // Skills match (0-30 points)
        let skillsList = aiSkills.lowercased().components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for skill in skillsList where !skill.isEmpty {
            if title.contains(skill) { score += 10 }
            else if snippet.contains(skill) { score += 5 }
        }
        
        // Canton match (0-15 points)
        if !aiPreferredCanton.isEmpty {
            if job.canton == aiPreferredCanton { score += 15 }
            else if location.contains(aiPreferredCanton.lowercased()) { score += 10 }
        }
        
        // Employment type match (0-10 points)
        if !aiEmploymentType.isEmpty {
            let prefType = aiEmploymentType.lowercased()
            if employmentType.contains(prefType) { score += 10 }
        }
        
        // Remote preference (0-10 points)
        if aiRemotePreference {
            if employmentType.contains("remote") || location.contains("remote") || snippet.contains("remote") || snippet.contains("home office") {
                score += 10
            }
        }
        
        // Experience level match (0-5 points)
        if !aiExperienceLevel.isEmpty {
            let level = aiExperienceLevel.lowercased()
            if snippet.contains(level) || title.contains(level) { score += 5 }
        }
        
        // Bonus for new jobs
        if let dateStr = job.posted_at, let date = parseDate(dateStr) {
            if date > Date().addingTimeInterval(-24 * 60 * 60) { score += 5 }
        }
        
        return min(score, 100)
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
        isLoading = true
        didSearchOnce = true
        defer { isLoading = false }
        
        do {
            page = 1
            let resp = try await APIClient.searchJobs(
                keyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines),
                canton: canton.isEmpty ? nil : canton,
                page: page,
                perPage: perPage
            )
            items = resp.items
            sources = resp.sources ?? [:]
            canLoadMore = resp.items.count >= perPage
            
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
            items = []
            sources = [:]
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
                page: page,
                perPage: perPage
            )
            items.append(contentsOf: resp.items)
            canLoadMore = resp.items.count >= perPage
        } catch {
            page -= 1
            canLoadMore = false
        }
    }
    
    private func refreshFavoritesCount() async {
        // Favorites are fully available in this build.
        // For guests (no backend token), we rely on local persistence.
        await MainActor.run { favoritesCount = favoriteIds.count }
    }
    
    private func toggleFavorite(_ job: APIClient.JobItem) {
        haptic(.medium)
        
        if favoriteIds.contains(job.id) {
            favoriteIds.remove(job.id)
            favoritesCount = max(0, favoritesCount - 1)
        } else {
            favoriteIds.insert(job.id)
            favoritesCount += 1
        }
        defaults.set(Array(favoriteIds), forKey: favoriteIdsKey)
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
        guard hasPremiumAccess else { return }
        
        isDrafting = true
        draftedText = ""
        showDraftSheet = true
        
        let text = await APIClient.draftJobApplication(
            title: job.title,
            company: job.company,
            description: job.snippet,
            language: appContainer.currentLocale.identifier
        )
        draftedText = text ?? "Не вдалося згенерувати відповідь."
        isDrafting = false
        
        // Track applied
        appliedJobIds.insert(job.id)
        appliedCount = appliedJobIds.count
        persistJobsScopedState()
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
                        
                        Text("Заповніть профіль для персоналізованого пошуку вакансій")
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
                            title: "Бажана посада",
                            placeholder: "напр. iOS Developer, Project Manager",
                            text: $desiredPosition
                        )
                        
                        // Skills
                        ProfileField(
                            icon: "star.fill",
                            title: "Навички",
                            placeholder: "Swift, Python, SQL (через кому)",
                            text: $skills
                        )
                        
                        // Canton
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Бажаний кантон", systemImage: "mappin.circle.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            
                            Menu {
                                ForEach(cantons, id: \.self) { code in
                                    Button(code.isEmpty ? "Будь-який" : code) {
                                        preferredCanton = code
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(preferredCanton.isEmpty ? "Будь-який" : preferredCanton)
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
                            Label("Тип зайнятості", systemImage: "clock.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            
                            Menu {
                                ForEach(employmentTypes, id: \.self) { type in
                                    Button(type.isEmpty ? "Будь-який" : type) {
                                        employmentType = type
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(employmentType.isEmpty ? "Будь-який" : employmentType)
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
                            Label("Рівень досвіду", systemImage: "chart.bar.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            
                            Menu {
                                ForEach(experienceLevels, id: \.self) { level in
                                    Button(level.isEmpty ? "Будь-який" : level) {
                                        experienceLevel = level
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(experienceLevel.isEmpty ? "Будь-який" : experienceLevel)
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
                            Label("Віддалена робота", systemImage: "house.fill")
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
                            Text("Знайти вакансії")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
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
                    Button("Закрити") { dismiss() }
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
            title: "Знайди роботу мрії",
            subtitle: "Агрегатор вакансій зі Швейцарії",
            features: ["RAV + Indeed", "Тисячі вакансій", "Щоденні оновлення"]
        ),
        (
            icon: "magnifyingglass",
            color1: Theme.Colors.accent,
            color2: Theme.Colors.accentCoral,
            title: "Розумний пошук",
            subtitle: "Знаходь швидко та точно",
            features: ["Пошук по ключовим словам", "Фільтри по кантону", "Тип зайнятості"]
        ),
        (
            icon: "wand.and.stars",
            color1: Theme.Colors.primaryLight,
            color2: Theme.Colors.primary,
            title: "AI Match",
            subtitle: "Персоналізовані рекомендації",
            features: ["Заповни профіль", "AI підбере вакансії", "Оцінка відповідності"]
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
                            .foregroundColor(.white.opacity(0.6))
                            .padding(12)
                            .background(Color.white.opacity(0.1))
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
                                Text("Заповнити профіль")
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
                            Text("Пропустити")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
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
                                Text("Далі")
                                    .font(.system(size: 17, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        Button {
                            onClose()
                        } label: {
                            Text("Пропустити")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
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
                        .foregroundColor(.white)
                }
                .shadow(color: slide.color1.opacity(0.5), radius: 20, x: 0, y: 10)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
            
            // Title
            Text(slide.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
            
            // Subtitle
            Text(slide.subtitle)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
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
                            .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
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
                .stroke(Color.white.opacity(0.14), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(progress, 0.035))
                .stroke(JourneyVisual.lime, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percentage)%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 46, height: 46)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Профіль заповнено на \(percentage) відсотків")
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
                .foregroundColor(JourneyVisual.lime)
            Text("\(value) \(label)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.68))
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
        .foregroundColor(isActive ? .black : .white.opacity(0.88))
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
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.06))
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
            .foregroundColor(isActive ? .black : .white.opacity(0.8))
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
                    .font(.system(size: 25, weight: .black, design: .rounded))
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
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 5) {
                            Text(job.company ?? "Компанія")
                            if isNew {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(JourneyVisual.lime)
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.78))
                    }

                    Spacer(minLength: 4)

                    Button(action: onSave) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isSaved ? JourneyVisual.lime : .white)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSaved ? "Видалити зі збережених" : "Зберегти вакансію")
                }

                HStack(spacing: 7) {
                    Image(systemName: "mappin")
                    Text(job.location ?? "Швейцарія")
                    if let employment = job.employment_type, !employment.isEmpty {
                        Text("·")
                        Text(employment)
                    } else if isRemote {
                        Text("· Remote")
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.52))
                .lineLimit(1)

                HStack(spacing: 10) {
                    if let salary = job.salary, !salary.isEmpty {
                        Text(salary)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    } else {
                        Text(job.source.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.58))
                    }

                    if let score = matchScore, score > 0 {
                        Text("\(score)% збіг")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(JourneyVisual.lime)
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
                            .foregroundColor(.white.opacity(0.58))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Поділитися вакансією")

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white.opacity(0.62))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.72))
        .background(Color.black.opacity(0.38))
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
                .fill(Color.white.opacity(0.1))
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 120, height: 12)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 80, height: 10)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
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
                .foregroundColor(JourneyVisual.lime)
                .frame(width: 48, height: 48)
                .background(JourneyVisual.lime.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(isAIMatch ? "Немає відповідних вакансій" : (hasSearched ? "Нічого не знайдено" : "Почніть пошук"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text(isAIMatch ? "Зміни параметри AI Match" : (hasSearched ? "Зміни фільтри або ключові слова" : "Введи посаду або навичку"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.56))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Job Detail Sheet
private struct JobDetailSheet: View {
    let job: APIClient.JobItem
    let onDraft: () async -> Void
    
    @Environment(\.dismiss) private var dismiss
    
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
                    
                    // Description
                    if let snippet = job.snippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            if let url = URL(string: job.url) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("Відкрити вакансію")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.Colors.primary)
                            .foregroundColor(Theme.Colors.textOnPrimary)
                            .cornerRadius(12)
                        }
                        
                        Button {
                            Task { await onDraft() }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("AI Відповідь")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.Colors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Деталі")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрити") { dismiss() }
                }
            }
        }
        .journeyScreen(.city, darkness: 0.72)
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
                            Text("Генерую відповідь...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(text ?? "")
                            .font(.body)
                    }
                }
                .padding()
            }
            .navigationTitle("AI Відповідь")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Копіювати") {
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
