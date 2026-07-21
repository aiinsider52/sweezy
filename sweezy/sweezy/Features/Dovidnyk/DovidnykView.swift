//
//  DovidnykView.swift
//  sweezy
//
//  Unified view combining Guides and Checklists with tabs
//

import SwiftUI
import UIKit

struct DovidnykView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    
    let requestedSection: DovidnykRouteSection?
    let routeID: UUID
    
    @State private var selectedTab: DovidnykTab = .guides
    @State private var searchText = ""
    
    enum DovidnykTab: String, CaseIterable {
        case guides = "guides"
        case checklists = "checklists"
        
        var title: String {
            switch self {
            case .guides: return "dovidnyk.tab.guides".localized
            case .checklists: return "dovidnyk.tab.checklists".localized
            }
        }
        
        var icon: String {
            switch self {
            case .guides: return "book.fill"
            case .checklists: return "checklist"
            }
        }
        
        init(routeSection: DovidnykRouteSection) {
            switch routeSection {
            case .guides:
                self = .guides
            case .checklists:
                self = .checklists
            case .tools:
                self = .guides
            }
        }
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    init(requestedSection: DovidnykRouteSection? = nil, routeID: UUID = UUID()) {
        self.requestedSection = requestedSection
        self.routeID = routeID
    }
    
    var body: some View {
        NavigationStack {
            InkPageScaffold {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    InkHeaderTitle(title: "guides.title".localized)

                    InkSearchField(text: $searchText, prompt: "guides.search_placeholder".localized)

                    PillSegmentedControl(
                        items: DovidnykTab.allCases.map(\.title),
                        selection: Binding(
                            get: { DovidnykTab.allCases.firstIndex(of: selectedTab) ?? 0 },
                            set: { selectedTab = DovidnykTab.allCases[$0] }
                        )
                    )
                }
            } content: {
                TabView(selection: $selectedTab) {
                    GuidesContentView(searchText: $searchText)
                        .tag(DovidnykTab.guides)

                    ChecklistsContentView()
                        .tag(DovidnykTab.checklists)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
                .padding(.top, Theme.Spacing.sm)
            }
            .navigationBarHidden(true)
            .refreshable {
                await appContainer.contentService.refreshContent()
                haptic(.light)
            }
            .featureOnboarding(.dovidnyk)
        }
        .onAppear {
            applyRequestedSection()
        }
        .onChange(of: routeID) { _, _ in
            applyRequestedSection()
        }
    }
    
    private func applyRequestedSection() {
        guard let requestedSection else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = DovidnykTab(routeSection: requestedSection)
        }
    }
    
}

// MARK: - Guides Content View (reuses existing GuidesView logic)
struct GuidesContentView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @Binding var searchText: String
    
    @State private var guides: [Guide] = []
    @State private var selectedCategory: GuideCategory?
    // TEMPORARY (App Store review): IAP removed, all content is unlocked.
    private let hasPremiumAccess: Bool = true
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    private var allGuides: [Guide] {
        guides
    }
    
    private var filteredGuides: [Guide] {
        var guides = allGuides
        
        if let category = selectedCategory {
            guides = guides.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            guides = guides.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.subtitle?.localizedCaseInsensitiveContains(searchText) == true) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return guides.sorted { $0.priority > $1.priority }
    }
    
    private var featuredGuide: Guide? {
        let unread = allGuides.filter { !appContainer.userStats.isGuideRead(id: $0.id) }
        if let canton = appContainer.userProfile?.canton {
            if let match = unread.first(where: { $0.cantonCodes.contains(canton.rawValue) }) {
                return match
            }
        }
        return unread.first ?? allGuides.first
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: Theme.Spacing.lg) {
                // Category chips
                categoryChips
                
                if searchText.isEmpty && selectedCategory == nil {
                    // Featured guide
                    if let featured = featuredGuide {
                        featuredCard(featured)
                    }
                }
                
                // Guides list
                ForEach(filteredGuides) { guide in
                    NavigationLink {
                        GuideDetailView(guide: guide)
                    } label: {
                        GuideCardCompact(guide: guide)
                    }
                    .buttonStyle(.plain)
                }
                
                if filteredGuides.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.lg)
            .padding(.bottom, 80)
        }
        .accessibilityIdentifier("dovidnyk.guides.content")
        .onAppear {
            loadGuidesIfNeeded()
        }
        // Reload guides when app language changes so content fully matches selected locale
        .onChange(of: appContainer.currentLocale.identifier) { _, _ in
            guides = []
            loadGuidesIfNeeded()
        }
    }
    
    // MARK: - Category Chips
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chipButton(nil, isSelected: selectedCategory == nil)
                ForEach(GuideCategory.allCases, id: \.self) { cat in
                    chipButton(cat, isSelected: selectedCategory == cat)
                }
            }
        }
    }
    
    private func chipButton(_ category: GuideCategory?, isSelected: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedCategory = isSelected ? nil : category
            }
            haptic(.light)
        } label: {
            HStack(spacing: 6) {
                if let cat = category {
                    Image(systemName: cat.iconName)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(category?.localizedName ?? "Всі")
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? (category?.swiftUIColor ?? Theme.Colors.accent) : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Featured Card
    private func featuredCard(_ guide: Guide) -> some View {
        NavigationLink {
            GuideDetailView(guide: guide)
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Background gradient
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                guide.category.swiftUIColor.opacity(0.95),
                                guide.category.swiftUIColor.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 210)

                // Decorative large icon
                Image(systemName: guide.category.iconName)
                    .font(.system(size: 110, weight: .thin))
                    .foregroundColor(.white.opacity(0.12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .offset(x: -16, y: -10)

                // Dark gradient overlay at bottom for text legibility
                LinearGradient(
                    colors: [.clear, .black.opacity(0.3)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                // Content
                VStack(alignment: .leading, spacing: 10) {
                    // Top badges row
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: guide.category.iconName)
                                .font(.system(size: 10, weight: .semibold))
                            Text(guide.category.localizedName)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                        if appContainer.userStats.isGuideRead(id: guide.id) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Прочитано")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.green.opacity(0.7)))
                        } else {
                            Text("Рекомендовано")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.white.opacity(0.2)))
                        }
                        Spacer()
                    }

                    Spacer()

                    Text(guide.title)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let subtitle = guide.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }

                    HStack(spacing: 14) {
                        Label("\(guide.estimatedReadingTime) хв читання", systemImage: "clock")
                        if !guide.tags.isEmpty {
                            Label(guide.tags.prefix(2).joined(separator: ", "), systemImage: "tag")
                                .lineLimit(1)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.75))
                }
                .padding(18)
            }
            .frame(height: 210)
            .shadow(color: guide.category.swiftUIColor.opacity(0.35), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("Гайди не знайдено")
                .font(.headline)
                .foregroundColor(Theme.Colors.textSecondary)
            if !searchText.isEmpty {
                Text("Спробуйте інший пошуковий запит")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func loadGuidesIfNeeded() {
        // If already loaded, don't reload
        if !guides.isEmpty { return }
        
        Task {
            let locale = appContainer.currentLocale.identifier
            // Retry a few times while content service finishes loading
            for _ in 1...10 {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                let localized = await MainActor.run {
                    appContainer.contentService.getGuidesForLocale(locale)
                }
                if !localized.isEmpty {
                    await MainActor.run {
                        // Показуємо всі гайди для вибраної мови,
                        // незалежно від кантону користувача
                        self.guides = localized.sorted { $0.priority > $1.priority }
                    }
                    return
                }
            }
            // Final fallback: whatever service currently has (even if empty)
            let final = await MainActor.run {
                appContainer.contentService.getGuidesForLocale(locale)
            }
            await MainActor.run {
                self.guides = final
            }
        }
    }
}

// MARK: - Compact Guide Card
struct GuideCardCompact: View {
    let guide: Guide
    
    @EnvironmentObject private var appContainer: AppContainer
    
    private var isRead: Bool {
        appContainer.userStats.isGuideRead(id: guide.id)
    }
    
    // Check if guide has related checklist (by category match)
    private var hasRelatedChecklist: Bool {
        appContainer.contentService.checklists.contains { checklist in
            checklist.category.rawValue.lowercased() == guide.category.rawValue.lowercased()
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left accent strip (colored by category, green if read)
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(isRead ? Theme.Colors.success : guide.category.swiftUIColor)
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 6)

            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(guide.category.swiftUIColor.opacity(isRead ? 0.08 : 0.13))
                        .frame(width: 50, height: 50)
                    Image(systemName: isRead ? "checkmark.circle.fill" : guide.category.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isRead ? Theme.Colors.success : guide.category.swiftUIColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(guide.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isRead ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                            .lineLimit(2)
                        if guide.isNew {
                            Text("New")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.red))
                        }
                    }

                    if let subtitle = guide.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 10) {
                        Label("\(guide.estimatedReadingTime) хв", systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textTertiary)
                        if hasRelatedChecklist {
                            Label("+ чек-лист", systemImage: "checklist")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.primary.opacity(0.8))
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 13)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isRead ? Theme.Colors.success.opacity(0.2) : Color.gray.opacity(0.1),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Checklists Content View (reuses existing ChecklistsView logic)
struct ChecklistsContentView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @AppStorage("checklist_progress_version") private var checklistProgressVersion = 0
    
    @State private var selectedCategory: ChecklistCategory?
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    private var allChecklists: [Checklist] {
        let locale = appContainer.currentLocale.identifier
        let localized = appContainer.contentService.getChecklistsForLocale(locale)
        if !localized.isEmpty {
            return localized
        }
        return appContainer.contentService.checklists.sorted { $0.priority > $1.priority }
    }
    
    private var filteredChecklists: [Checklist] {
        let all = allChecklists
        if let category = selectedCategory {
            return all.filter { $0.category == category }
        }
        return all
    }
    
    // Overall progress
    private var overallProgress: (completed: Int, total: Int, percentage: Double) {
        var totalSteps = 0
        var completedSteps = 0
        for checklist in allChecklists {
            totalSteps += checklist.steps.count
            let key = AccountScopedStorage.checklistCompletedKey(for: checklist.id)
            if let saved = UserDefaults.standard.array(forKey: key) as? [String] {
                completedSteps += saved.count
            }
        }
        let percentage = totalSteps > 0 ? Double(completedSteps) / Double(totalSteps) : 0
        return (completedSteps, totalSteps, percentage)
    }
    
    var body: some View {
        let _ = checklistProgressVersion
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: Theme.Spacing.lg) {
                // Progress card
                progressCard
                
                // Category chips
                categoryChips
                
                // Checklists
                ForEach(filteredChecklists) { checklist in
                    NavigationLink {
                        ChecklistDetailView(checklist: checklist)
                    } label: {
                        ChecklistCardCompact(checklist: checklist)
                    }
                    .buttonStyle(.plain)
                }
                
                if filteredChecklists.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.lg)
            .padding(.bottom, 80)
        }
        .accessibilityIdentifier("dovidnyk.checklists.content")
    }
    
    // MARK: - Progress Card
    private var progressCard: some View {
        let progress = overallProgress
        let percent = Int(progress.percentage * 100)
        let isAllDone = progress.total > 0 && progress.completed == progress.total

        return ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isAllDone
                            ? [Color.green.opacity(0.85), Color.green.opacity(0.55)]
                            : [Theme.Colors.accentTurquoise.opacity(0.9), Theme.Colors.accent.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Decorative circle
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 100, height: 100)
                .offset(x: 100, y: -30)

            HStack(spacing: 18) {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 76, height: 76)

                    Circle()
                        .trim(from: 0, to: progress.percentage)
                        .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8), value: progress.percentage)

                    VStack(spacing: 1) {
                        Text("\(percent)%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("готово")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(isAllDone ? "Все виконано! 🏆" : "Ваш прогрес")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(progress.completed) з \(progress.total) завдань")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))

                    Text(progressMessage(for: percent))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()
            }
            .padding(18)
        }
        .frame(height: 130)
        .shadow(
            color: (isAllDone ? Color.green : Theme.Colors.accentTurquoise).opacity(0.3),
            radius: 12, x: 0, y: 6
        )
    }
    
    private func progressMessage(for percent: Int) -> String {
        switch percent {
        case 0..<25: return "Починайте — все вийде! 💪"
        case 25..<50: return "Гарний старт! 🔥"
        case 50..<75: return "Половина шляху! ⚡️"
        case 75..<100: return "Майже готово! 🎯"
        default: return "Вітаємо! 🏆"
        }
    }
    
    // MARK: - Category Chips
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryChip(nil, isSelected: selectedCategory == nil)
                ForEach(ChecklistCategory.allCases, id: \.self) { cat in
                    categoryChip(cat, isSelected: selectedCategory == cat)
                }
            }
        }
    }
    
    private func categoryChip(_ category: ChecklistCategory?, isSelected: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedCategory = isSelected ? nil : category
            }
            haptic(.light)
        } label: {
            HStack(spacing: 6) {
                if let cat = category {
                    Image(systemName: cat.iconName)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(category?.localizedName ?? "Всі")
                    .font(.system(size: 14, weight: .medium))
                
                // Count badge
                let count = category == nil ? allChecklists.count : allChecklists.filter { $0.category == category }.count
                Text("\(count)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Circle().fill(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2)))
                    .foregroundColor(isSelected ? .white : Theme.Colors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? (category?.swiftUIColor ?? Theme.Colors.accent) : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 50))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("Чек-листи не знайдено")
                .font(.headline)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Compact Checklist Card
struct ChecklistCardCompact: View {
    let checklist: Checklist
    
    @EnvironmentObject private var appContainer: AppContainer
    @AppStorage("checklist_progress_version") private var checklistProgressVersion = 0
    @State private var completedStepIDs: Set<UUID> = []
    
    private var storageKey: String { AccountScopedStorage.checklistCompletedKey(for: checklist.id) }
    
    init(checklist: Checklist) {
        self.checklist = checklist
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            _completedStepIDs = State(initialValue: Set(saved.compactMap { UUID(uuidString: $0) }))
        }
    }
    
    private var completedSteps: Int {
        completedStepIDs.count
    }
    
    private var progress: Double {
        guard !checklist.steps.isEmpty else { return 0 }
        return Double(completedSteps) / Double(checklist.steps.count)
    }
    
    private var isCompleted: Bool {
        progress >= 1.0
    }
    
    // Check if checklist has related guide
    private var hasRelatedGuide: Bool {
        appContainer.contentService.guides.contains { guide in
            guide.category.rawValue.lowercased() == checklist.category.rawValue.lowercased()
        }
    }
    
    private var statusStripColor: Color {
        if isCompleted { return Theme.Colors.success }
        if progress > 0 { return checklist.category.swiftUIColor }
        return Color.gray.opacity(0.3)
    }

    var body: some View {
        let _ = checklistProgressVersion
        HStack(spacing: 0) {
            // Left status strip
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(statusStripColor)
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 6)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(isCompleted ? Theme.Colors.success.opacity(0.12) : checklist.category.swiftUIColor.opacity(0.12))
                            .frame(width: 50, height: 50)
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : checklist.category.iconName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(isCompleted ? Theme.Colors.success : checklist.category.swiftUIColor)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(checklist.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(2)
                            Spacer()
                            if isCompleted {
                                Text("Готово")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.Colors.success))
                            } else if checklist.isNew {
                                Text("New")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.Colors.accent))
                            }
                        }

                        Text(checklist.description)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)

                        HStack(spacing: 10) {
                            Label(checklist.estimatedDuration, systemImage: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textTertiary)
                            Spacer()
                            Text("\(completedSteps)/\(checklist.steps.count) кроків")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isCompleted ? Theme.Colors.success : Theme.Colors.textSecondary)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isCompleted ? Theme.Colors.success : checklist.category.swiftUIColor)
                            .frame(width: geo.size.width * progress, height: 5)
                            .animation(.spring(response: 0.4), value: progress)
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isCompleted ? Theme.Colors.success.opacity(0.25) : Color.gray.opacity(0.1),
                    lineWidth: 1
                )
        )
        .onAppear { reloadCompletedSteps() }
        .onChange(of: checklistProgressVersion) { _, _ in reloadCompletedSteps() }
        .onReceive(EventBus.shared.publisher) { event in
            switch event.type {
            case .checklistStepCompleted, .checklistCompleted:
                reloadCompletedSteps()
            default:
                break
            }
        }
    }
    
    private func reloadCompletedSteps() {
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            completedStepIDs = Set(saved.compactMap { UUID(uuidString: $0) })
        } else {
            completedStepIDs = []
        }
    }
}

// MARK: - Lazy Wrapper for DovidnykView
struct LazyDovidnykWrapper: View {
    let requestedSection: DovidnykRouteSection?
    let routeID: UUID
    @State private var showOriginal = false
    
    var body: some View {
        Group {
            if showOriginal {
                DovidnykView(requestedSection: requestedSection, routeID: routeID)
                    .onAppear {
                        AppLogger.ui("DovidnykView loaded")
                    }
            } else {
                DovidnykLiteView()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showOriginal = true
            }
        }
    }
}

// MARK: - Lite placeholder view
struct DovidnykLiteView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ProgressView()
                    .tint(.cyan)
                Text("Завантаження...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Theme.Colors.primaryDark,
                        Theme.Colors.primary.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Довідник")
        }
    }
}

#Preview {
    DovidnykView()
        .environmentObject(AppContainer())
        .environmentObject(AppLockManager())
        .environmentObject(ThemeManager())
}
