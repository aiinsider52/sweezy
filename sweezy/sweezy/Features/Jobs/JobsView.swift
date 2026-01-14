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
    @State private var favoriteIds: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "job_favorite_ids") ?? [])
    @State private var didSearchOnce: Bool = false
    @State private var selectedJob: APIClient.JobItem?
    @State private var showPaywall: Bool = false
    @State private var subscription: APIClient.SubscriptionCurrent?
    @State private var entitlements: APIClient.Entitlements?
    @State private var favoritesCount: Int = 0
    @State private var page: Int = 1
    @State private var canLoadMore: Bool = false
    @State private var selectedEmployment: EmploymentFilter = .all
    @State private var selectedCity: String = ""
    @State private var showDraftSheet: Bool = false
    @State private var draftedText: String?
    @State private var isDrafting: Bool = false
    
    // AI Match
    @State private var showAIMatchProfile: Bool = false
    @State private var isAIMatching: Bool = false
    @State private var matchedItems: [APIClient.JobItem] = []
    @State private var showMatchResults: Bool = false
    
    // Onboarding
    @AppStorage("jobs.didSeeOnboarding") private var didSeeJobsOnboarding: Bool = false
    @State private var showJobsOnboarding: Bool = false
    
    // Stats for dashboard
    @State private var newTodayCount: Int = 0
    @State private var appliedCount: Int = 0
    
    // Persisted preferences
    @AppStorage("jobs.lastKeyword") private var lastKeyword: String = ""
    @AppStorage("jobs.lastCanton") private var lastCanton: String = ""
    @AppStorage("jobs.lastEmployment") private var lastEmploymentRaw: String = EmploymentFilter.all.rawValue
    @AppStorage("jobs.appliedJobIds") private var appliedJobIdsRaw: String = ""
    
    // AI Match Profile (persisted)
    @AppStorage("aiMatch.desiredPosition") private var aiDesiredPosition: String = ""
    @AppStorage("aiMatch.skills") private var aiSkills: String = ""
    @AppStorage("aiMatch.preferredCanton") private var aiPreferredCanton: String = ""
    @AppStorage("aiMatch.employmentType") private var aiEmploymentType: String = ""
    @AppStorage("aiMatch.remotePreference") private var aiRemotePreference: Bool = false
    @AppStorage("aiMatch.experienceLevel") private var aiExperienceLevel: String = ""
    
    private let perPage: Int = 20
    private let cantons = ["", "AG", "AI", "AR", "BE", "BL", "BS", "FR", "GE", "GL", "GR", "JU", "LU", "NE", "NW", "OW", "SG", "SH", "SO", "SZ", "TG", "TI", "UR", "VD", "VS", "ZG", "ZH"]
    private let quickTags = ["Java", "Driver", "Nurse", "QA", "Warehouse", "React", "Manager", "Sales"]
    
    private enum EmploymentFilter: String, CaseIterable {
        case all = "Всі"
        case fullTime = "Full-time"
        case partTime = "Part-time"
        case contract = "Contract"
        case remote = "Remote"
    }
    
    // Check if AI profile is configured
    private var hasAIProfile: Bool {
        !aiDesiredPosition.isEmpty || !aiSkills.isEmpty
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
    
    private var isPremium: Bool {
        if let ent = entitlements { return ent.is_premium }
        if let sub = subscription { return sub.status == "premium" || sub.status == "trial" }
        return false
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.06, blue: 0.10), Color(red: 0.02, green: 0.12, blue: 0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        // Dashboard metrics
                        dashboardSection
                        
                        // Smart filters
                        smartFiltersSection
                        
                        // Quick tags
                        quickTagsSection
                        
                        // City chips
                        if !topCities.isEmpty {
                            cityChipsSection
                        }
                        
                        // Results
                        resultsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable {
                    showMatchResults = false
                    await performSearch()
                    haptic(.light)
                }
            }
            .navigationTitle("Вакансії")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Назад")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            appContainer.telemetry.info("view_open", source: "jobs", message: "JobsView opened")
        }
        .sheet(item: $selectedJob) { job in
            JobDetailSheet(job: job, isPremium: isPremium, onDraft: { await draftApply(job) })
                .environmentObject(appContainer)
        }
        .sheet(isPresented: $showDraftSheet) {
            DraftSheet(text: draftedText, isDrafting: isDrafting)
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionView().environmentObject(appContainer)
        }
        .sheet(isPresented: $showAIMatchProfile) {
            AIMatchProfileSheet(
                desiredPosition: $aiDesiredPosition,
                skills: $aiSkills,
                preferredCanton: $aiPreferredCanton,
                employmentType: $aiEmploymentType,
                remotePreference: $aiRemotePreference,
                experienceLevel: $aiExperienceLevel,
                cantons: cantons,
                onSearch: {
                    showAIMatchProfile = false
                    Task { await performAIMatch() }
                }
            )
        }
        .sheet(isPresented: $showJobsOnboarding) {
            JobsOnboardingSheet(
                onClose: {
                    didSeeJobsOnboarding = true
                    showJobsOnboarding = false
                },
                onSetupProfile: {
                    didSeeJobsOnboarding = true
                    showJobsOnboarding = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showAIMatchProfile = true
                    }
                }
            )
        }
        .task {
            if !didSearchOnce {
                keyword = lastKeyword
                canton = lastCanton
                selectedEmployment = EmploymentFilter(rawValue: lastEmploymentRaw) ?? .all
                appliedCount = appliedJobIdsRaw.split(separator: ",").count
                await performSearch()
                subscription = await APIClient.subscriptionCurrent()
                entitlements = await APIClient.fetchEntitlements()
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
    }
    
    // MARK: - Dashboard Section
    private var dashboardSection: some View {
        HStack(spacing: 12) {
            DashboardMetricCard(
                icon: "sparkles",
                value: "\(newTodayCount)",
                label: "Нових сьогодні",
                color: .cyan
            )
            
            DashboardMetricCard(
                icon: "heart.fill",
                value: "\(favoritesCount)",
                label: "Збережено",
                color: .pink
            )
            
            DashboardMetricCard(
                icon: "paperplane.fill",
                value: "\(appliedCount)",
                label: "Відгуків",
                color: .green
            )
        }
    }
    
    // MARK: - Smart Filters Section
    private var smartFiltersSection: some View {
        VStack(spacing: 12) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                
                TextField("Пошук вакансій...", text: $keyword)
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
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(14)
            
            // Filter chips row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Canton picker
                    Menu {
                        ForEach(cantons, id: \.self) { code in
                            Button(code.isEmpty ? "Всі кантони" : code) {
                                canton = code
                                showMatchResults = false
                                Task { await performSearch() }
                            }
                        }
                    } label: {
                        FilterChip(
                            icon: "mappin",
                            text: canton.isEmpty ? "Кантон" : canton,
                            isActive: !canton.isEmpty
                        )
                    }
                    
                    // Employment type
                    ForEach(EmploymentFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            icon: nil,
                            text: filter.rawValue,
                            isActive: selectedEmployment == filter
                        ) {
                            selectedEmployment = filter
                            haptic(.light)
                        }
                    }
                }
            }
            
            // AI Match button
            HStack(spacing: 12) {
                // Show match results indicator
                if showMatchResults {
                    Button {
                        showMatchResults = false
                        haptic(.light)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Скинути AI")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
                
                // AI Match main button
                Button {
                    haptic(.medium)
                    if hasAIProfile {
                        Task { await performAIMatch() }
                    } else {
                        showAIMatchProfile = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isAIMatching {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(hasAIProfile ? "AI Match" : "Налаштувати AI")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: hasAIProfile ? [Color.cyan, Color.green] : [Color.gray.opacity(0.6), Color.gray.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(isAIMatching)
                
                // Settings button for AI profile
                if hasAIProfile {
                    Button {
                        showAIMatchProfile = true
                        haptic(.light)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.white.opacity(0.7))
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
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
    
    // MARK: - Results Section
    private var resultsSection: some View {
        VStack(spacing: 12) {
            // Results header
            HStack {
                if showMatchResults {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.cyan)
                        Text("AI Результати")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else {
                    Text("Результати")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if !displayedItems.isEmpty {
                    Text("\(displayedItems.count) вакансій")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
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
            lastKeyword = keyword
            lastCanton = canton
            lastEmploymentRaw = selectedEmployment.rawValue
            
            appContainer.telemetry.info("jobs_search", source: "jobs", meta: [
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
        let list = await APIClient.listJobFavorites()
        await MainActor.run { favoritesCount = list.count }
    }
    
    private func toggleFavorite(_ job: APIClient.JobItem) {
        haptic(.medium)
        
        if favoriteIds.contains(job.id) {
            favoriteIds.remove(job.id)
            Task { _ = await APIClient.removeJobFavorite(jobId: job.id, source: job.source) }
            favoritesCount = max(0, favoritesCount - 1)
        } else {
            // Check limit
            if let limit = entitlements?.favorites_limit, favoriteIds.count >= limit {
                showPaywall = true
                return
            }
            
            favoriteIds.insert(job.id)
            favoritesCount += 1
            Task {
                let outcome = await APIClient.addJobFavorite(job: job)
                if case .upgradeRequired = outcome {
                    await MainActor.run {
                        favoriteIds.remove(job.id)
                        favoritesCount -= 1
                        showPaywall = true
                    }
                }
            }
        }
        UserDefaults.standard.set(Array(favoriteIds), forKey: "job_favorite_ids")
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
        if !isPremium {
            showPaywall = true
            return
        }
        
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
        var applied = Set(appliedJobIdsRaw.split(separator: ",").map(String.init))
        applied.insert(job.id)
        appliedJobIdsRaw = applied.joined(separator: ",")
        appliedCount = applied.count
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
                                LinearGradient(colors: [.cyan, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
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
                            LinearGradient(colors: [.cyan, .green], startPoint: .leading, endPoint: .trailing)
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
            color1: Color(red: 0.0, green: 0.8, blue: 0.9),
            color2: Color(red: 0.0, green: 0.6, blue: 0.8),
            title: "Знайди роботу мрії",
            subtitle: "Агрегатор вакансій зі Швейцарії",
            features: ["RAV + Indeed", "Тисячі вакансій", "Щоденні оновлення"]
        ),
        (
            icon: "magnifyingglass",
            color1: Color(red: 0.4, green: 0.3, blue: 0.9),
            color2: Color(red: 0.6, green: 0.2, blue: 0.8),
            title: "Розумний пошук",
            subtitle: "Знаходь швидко та точно",
            features: ["Пошук по ключовим словам", "Фільтри по кантону", "Тип зайнятості"]
        ),
        (
            icon: "wand.and.stars",
            color1: Color(red: 0.0, green: 0.9, blue: 0.5),
            color2: Color(red: 0.0, green: 0.7, blue: 0.9),
            title: "AI Match",
            subtitle: "Персоналізовані рекомендації",
            features: ["Заповни профіль", "AI підбере вакансії", "Оцінка відповідності"]
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.10, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
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
                                    colors: [Color.cyan, Color.green],
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
            .background(isActive ? Color.cyan : Color.white.opacity(0.1))
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
                .foregroundColor(isSelected ? .black : .cyan)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.cyan : Color.cyan.opacity(0.15))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
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
    
    @State private var isPressed = false
    
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
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .top, spacing: 12) {
                    // Company logo placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Text(String((job.company ?? "C").prefix(1)))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(job.company ?? "Company")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text(job.location ?? "Switzerland")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // Match score badge
                    if let score = matchScore, score > 0 {
                        MatchScoreBadge(score: score)
                    }
                }
                
                // Tags
                HStack(spacing: 8) {
                    if isNew {
                        JobTag(text: "NEW", color: .green)
                    }
                    if isRemote {
                        JobTag(text: "Remote", color: .purple)
                    }
                    JobTag(text: job.source.uppercased(), color: .blue)
                    
                    Spacer()
                }
                
                // Actions
                HStack(spacing: 12) {
                    Button(action: onSave) {
                        HStack(spacing: 6) {
                            Image(systemName: isSaved ? "heart.fill" : "heart")
                                .foregroundColor(isSaved ? .pink : .white.opacity(0.6))
                            Text(isSaved ? "Збережено" : "Зберегти")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onShare) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Поділитись")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(matchScore != nil ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
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
        VStack(spacing: 16) {
            Image(systemName: isAIMatch ? "wand.and.stars" : (hasSearched ? "magnifyingglass" : "briefcase.fill"))
                .font(.system(size: 48))
                .foregroundColor(.cyan.opacity(0.5))
            
            Text(isAIMatch ? "Немає відповідних вакансій" : (hasSearched ? "Нічого не знайдено" : "Почніть пошук"))
                .font(.headline)
                .foregroundColor(.white)
            
            Text(isAIMatch ? "Спробуйте змінити параметри AI Match профілю" : (hasSearched ? "Спробуйте змінити фільтри або ключові слова" : "Введіть ключове слово або оберіть категорію"))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Job Detail Sheet
private struct JobDetailSheet: View {
    let job: APIClient.JobItem
    let isPremium: Bool
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
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button {
                            Task { await onDraft() }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("AI Відповідь")
                                if !isPremium {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isPremium ? Color.purple : Color.gray)
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
    }
}

#Preview {
    JobsView()
        .environmentObject(AppContainer())
}
