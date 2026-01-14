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
    
    @State private var selectedTab: DovidnykTab = .guides
    @State private var searchText = ""
    
    enum DovidnykTab: String, CaseIterable {
        case guides = "guides"
        case checklists = "checklists"
        
        var title: String {
            switch self {
            case .guides: return "Гайди"
            case .checklists: return "Чек-листи"
            }
        }
        
        var icon: String {
            switch self {
            case .guides: return "book.fill"
            case .checklists: return "checklist"
            }
        }
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab switcher
                tabSwitcher
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Guides tab
                    GuidesContentView(searchText: $searchText)
                        .tag(DovidnykTab.guides)
                    
                    // Checklists tab
                    ChecklistsContentView()
                        .tag(DovidnykTab.checklists)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
            }
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
            .navigationTitle("Довідник")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Пошук...")
            .refreshable {
                await appContainer.contentService.refreshContent()
                haptic(.light)
            }
        }
    }
    
    // MARK: - Tab Switcher (Winter styled)
    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(DovidnykTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                    haptic(.light)
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 15, weight: .semibold))
                            
                            // Winter snowflake on active tab
                            if selectedTab == tab {
                                Text("❄️")
                                    .font(.system(size: 10))
                            }
                        }
                        .foregroundColor(selectedTab == tab ? Color.cyan : .white.opacity(0.5))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        
                        // Indicator
                        Rectangle()
                            .fill(selectedTab == tab ? Color.cyan : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .background(
            Rectangle()
                .fill(Color(red: 0.05, green: 0.1, blue: 0.2).opacity(0.95))
                .shadow(color: Color.cyan.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Guides Content View (reuses existing GuidesView logic)
struct GuidesContentView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @Binding var searchText: String
    
    @State private var guides: [Guide] = []
    @State private var selectedCategory: GuideCategory?
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var entitlements: APIClient.Entitlements?
    
    private var isPremium: Bool {
        if let entitlements { return entitlements.is_premium }
        return subManager.isPremium
    }
    
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
                        GuideCardCompact(guide: guide, isPremium: isPremium)
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
        .task { await reloadSubscription() }
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
            .overlay(
                Group {
                    if WinterTheme.isActive && isSelected {
                        Capsule()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Featured Card
    private func featuredCard(_ guide: Guide) -> some View {
        NavigationLink {
            GuideDetailView(guide: guide)
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Background
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [guide.category.swiftUIColor, guide.category.swiftUIColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 180)
                
                // Winter frost overlay
                if WinterTheme.isActive {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.clear,
                                    Color.cyan.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 180)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Badge
                    HStack {
                        if guide.isNew {
                            Text(WinterTheme.isActive ? "🎄 Рекомендовано" : "Рекомендовано")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.25)))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Image(systemName: guide.category.iconName)
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Text(guide.title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if let subtitle = guide.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 12) {
                        Label("\(guide.estimatedReadingTime) хв", systemImage: "clock")
                        Label(guide.category.localizedName, systemImage: "folder")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                }
                .padding(20)
                
                // Winter corner snowflakes
                if WinterTheme.isActive {
                    Text("❄️")
                        .font(.system(size: 20))
                        .opacity(0.8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: -12, y: 12)
                    
                    Text("✨")
                        .font(.system(size: 14))
                        .opacity(0.7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .offset(x: -16, y: -16)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(
            Group {
                if WinterTheme.isActive {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                }
            }
        )
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
    
    private func reloadSubscription() async {
        entitlements = try? await APIClient.fetchEntitlements()
    }
    
    private func loadGuidesIfNeeded() {
        // If already loaded, don't reload
        if !guides.isEmpty { return }
        
        Task {
            let locale = appContainer.currentLocale.identifier
            // Retry a few times while content service finishes loading
            for attempt in 1...10 {
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
    let isPremium: Bool
    
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
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(guide.category.swiftUIColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: guide.category.iconName)
                    .font(.title2)
                    .foregroundColor(guide.category.swiftUIColor)
                
                // Winter decoration on icon
                if WinterTheme.isActive {
                    Text("❄️")
                        .font(.system(size: 10))
                        .offset(x: 20, y: -20)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(guide.title)
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    if guide.isNew {
                        Text("New")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.success)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                if let subtitle = guide.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    // Category
                    Text(guide.category.localizedName)
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    // Related checklist indicator
                    if hasRelatedChecklist {
                        HStack(spacing: 2) {
                            Image(systemName: "checklist")
                                .font(.caption2)
                            Text("+ чек-лист")
                                .font(.caption2)
                        }
                        .foregroundColor(Theme.Colors.success)
                    }
                    
                    Spacer()
                    
                    // Read indicator
                    if isRead {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.success)
                    }
                    
                    // Premium lock
                    if guide.isPremium && !isPremium {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Arrow
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    WinterTheme.isActive 
                        ? Color.cyan.opacity(0.3) 
                        : Color.gray.opacity(0.15),
                    lineWidth: WinterTheme.isActive ? 1.5 : 1
                )
        )
        .overlay(
            Group {
                if WinterTheme.isActive {
                    // Frost corner accent
                    Text("✨")
                        .font(.system(size: 12))
                        .opacity(0.7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: -8, y: 8)
                }
            }
        )
    }
}

// MARK: - Checklists Content View (reuses existing ChecklistsView logic)
struct ChecklistsContentView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    
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
            let key = "checklist_\(checklist.id.uuidString)_completed"
            if let saved = UserDefaults.standard.array(forKey: key) as? [String] {
                completedSteps += saved.count
            }
        }
        let percentage = totalSteps > 0 ? Double(completedSteps) / Double(totalSteps) : 0
        return (completedSteps, totalSteps, percentage)
    }
    
    var body: some View {
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
    }
    
    // MARK: - Progress Card
    private var progressCard: some View {
        let progress = overallProgress
        let percent = Int(progress.percentage * 100)
        
        return HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(
                        WinterTheme.isActive 
                            ? Color.cyan.opacity(0.15) 
                            : Color.gray.opacity(0.2),
                        lineWidth: 6
                    )
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: progress.percentage)
                    .stroke(
                        LinearGradient(
                            colors: WinterTheme.isActive 
                                ? [Color.cyan, Color(red: 0.6, green: 0.85, blue: 1.0)]
                                : [Theme.Colors.accent, Theme.Colors.accentTurquoise],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: WinterTheme.isActive ? Color.cyan.opacity(0.4) : Color.clear, radius: 4)
                
                Text("\(percent)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if WinterTheme.isActive {
                        Text("❄️")
                            .font(.system(size: 14))
                    }
                    Text("Ваш прогрес")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                
                Text("\(progress.completed) з \(progress.total) завдань виконано")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Text(progressMessage(for: percent))
                    .font(.caption)
                    .foregroundColor(WinterTheme.isActive ? Color.cyan : Theme.Colors.accent)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    WinterTheme.isActive ? Color.cyan.opacity(0.3) : Color.gray.opacity(0.15),
                    lineWidth: WinterTheme.isActive ? 1.5 : 1
                )
        )
        .overlay(
            Group {
                if WinterTheme.isActive {
                    Text("✨")
                        .font(.system(size: 14))
                        .opacity(0.8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: -12, y: 12)
                }
            }
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
            .overlay(
                Group {
                    if WinterTheme.isActive && isSelected {
                        Capsule()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    }
                }
            )
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
    
    private var completedSteps: Int {
        let key = "checklist_\(checklist.id.uuidString)_completed"
        return (UserDefaults.standard.array(forKey: key) as? [String])?.count ?? 0
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isCompleted ? Theme.Colors.success.opacity(0.15) : checklist.category.swiftUIColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    // Winter snowflake for completed, regular icon otherwise
                    if isCompleted && WinterTheme.isActive {
                        SnowflakeCheckmark()
                    } else {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : checklist.category.iconName)
                            .font(.title2)
                            .foregroundColor(isCompleted ? Theme.Colors.success : checklist.category.swiftUIColor)
                    }
                    
                    // Winter decoration
                    if WinterTheme.isActive && !isCompleted {
                        Text("❄️")
                            .font(.system(size: 10))
                            .offset(x: 20, y: -20)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(checklist.title)
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)
                        
                        if isCompleted {
                            Text(WinterTheme.isActive ? "🎄 Готово" : "Готово")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.success)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        } else if checklist.isNew {
                            Text("New")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.accent)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(checklist.description)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        // Duration
                        Label(checklist.estimatedDuration, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.textTertiary)
                        
                        // Related guide indicator
                        if hasRelatedGuide {
                            HStack(spacing: 2) {
                                Image(systemName: "book.fill")
                                    .font(.caption2)
                                Text("+ гайд")
                                    .font(.caption2)
                            }
                            .foregroundColor(Theme.Colors.info)
                        }
                        
                        Spacer()
                        
                        // Steps count
                        Text("\(completedSteps)/\(checklist.steps.count)")
                            .font(.caption.bold())
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                
                Spacer(minLength: 0)
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            
            // Progress bar - winter or regular
            if WinterTheme.isActive {
                WinterProgressBar(progress: progress, height: 4)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isCompleted ? Theme.Colors.success : checklist.category.swiftUIColor)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isCompleted 
                        ? Theme.Colors.success.opacity(0.3) 
                        : (WinterTheme.isActive ? Color.cyan.opacity(0.3) : Color.gray.opacity(0.15)),
                    lineWidth: WinterTheme.isActive ? 1.5 : 1
                )
        )
        .overlay(
            Group {
                if WinterTheme.isActive {
                    Text("✨")
                        .font(.system(size: 12))
                        .opacity(0.7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: -8, y: 8)
                }
            }
        )
    }
}

// MARK: - Lazy Wrapper for DovidnykView
struct LazyDovidnykWrapper: View {
    @State private var showOriginal = false
    
    var body: some View {
        Group {
            if showOriginal {
                DovidnykView()
                    .onAppear {
                        print("📚 DovidnykView loaded")
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
                        Color(red: 0.05, green: 0.1, blue: 0.2),
                        Color(red: 0.08, green: 0.15, blue: 0.28)
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

