//
//  GuidesView.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//  Redesigned: Hero featured card, category carousels, badges, reading progress, XP rewards

import SwiftUI
import UIKit

struct GuidesView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: GuideCategory?
    @Namespace private var animation
    
    // Backend subscription status
    @State private var entitlements: APIClient.Entitlements?
    @State private var subscription: APIClient.SubscriptionCurrent?
    private let freeGuidesLimit: Int = 5
    
    // Optional initial category for deep-linking
    private let initialCategory: GuideCategory?
    
    init(initialCategory: GuideCategory? = nil) {
        self.initialCategory = initialCategory
        _selectedCategory = State(initialValue: initialCategory)
    }
    
    private var isPremium: Bool {
        if let entitlements { return entitlements.is_premium }
        if let subscription { return subscription.status == "premium" || subscription.status == "trial" }
        return subManager.isPremium
    }
    
    private var allGuides: [Guide] {
        appContainer.contentService.searchGuides(query: "", category: nil, canton: appContainer.userProfile?.canton)
    }
    
    private var filteredGuides: [Guide] {
        appContainer.contentService.searchGuides(
            query: searchText,
            category: selectedCategory,
            canton: appContainer.userProfile?.canton
        )
    }
    
    private var featuredGuide: Guide? {
        // Recommend based on user profile or newest unread
        let unread = allGuides.filter { !appContainer.userStats.isGuideRead(id: $0.id) }
        if let canton = appContainer.userProfile?.canton {
            if let match = unread.first(where: { $0.cantonCodes.contains(canton.rawValue) }) {
                return match
            }
        }
        return unread.first ?? allGuides.first
    }
    
    private var categories: [GuideCategory] {
        GuideCategory.allCases
    }
    
    private func guidesForCategory(_ category: GuideCategory) -> [Guide] {
        allGuides.filter { $0.category == category }
    }
    
    var body: some View {
        NavigationStack {
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
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.xl) {
                        // Search bar
                        searchBar
                        
                        // Category chips
                        categoryChips
                        
                        if searchText.isEmpty && selectedCategory == nil {
                            // Featured card
                            if let featured = featuredGuide {
                                featuredCard(featured)
                            }
                            
                            // Category carousels
                            ForEach(categories, id: \.self) { category in
                                let guides = guidesForCategory(category)
                                if !guides.isEmpty {
                                    categorySection(category, guides: guides)
                                }
                            }
                        } else {
                            // Filtered list
                            filteredList
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("guides.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await appContainer.contentService.refreshContent()
                await reloadSubscription()
                haptic(.light)
            }
        }
        .task { await reloadSubscription() }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.textTertiary)
                TextField("Пошук гідів...", text: $searchText)
                    .font(Theme.Typography.body)
                if !searchText.isEmpty {
                    Button { withAnimation { searchText = "" }; haptic(.light) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    // MARK: - Category Chips
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chipButton(nil, isSelected: selectedCategory == nil)
                ForEach(categories, id: \.self) { cat in
                    chipButton(cat, isSelected: selectedCategory == cat)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
    
    private func chipButton(_ category: GuideCategory?, isSelected: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedCategory = category
            }
            haptic(.light)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category?.iconName ?? "square.grid.2x2")
                    .font(.system(size: 14, weight: .semibold))
                Text(category?.localizedName ?? "Всі")
                    .font(Theme.Typography.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? (category?.swiftUIColor ?? Theme.Colors.accent).opacity(0.18) : Color.clear)
            .foregroundColor(isSelected ? (category?.swiftUIColor ?? Theme.Colors.accent) : Theme.Colors.textSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? (category?.swiftUIColor ?? Theme.Colors.accent) : Theme.Colors.chipBorder, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Featured Card
    private func featuredCard(_ guide: Guide) -> some View {
        NavigationLink(destination: GuideDetailView(guide: guide)) {
            ZStack(alignment: .bottomLeading) {
                // Background gradient
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [guide.category.swiftUIColor, guide.category.swiftUIColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 220)
                
                // Decorative icon
                Image(systemName: guide.category.iconName)
                    .font(.system(size: 120, weight: .thin))
                    .foregroundColor(.white.opacity(0.15))
                    .offset(x: 140, y: -20)
                
                // Content
                VStack(alignment: .leading, spacing: 12) {
                    // Badges
                    HStack(spacing: 8) {
                        guideBadge("Рекомендовано", color: .white, textColor: guide.category.swiftUIColor)
                        if guide.isNew {
                            guideBadge("NEW", color: .red, textColor: .white)
                        }
                        if guide.isPremium && !isPremium {
                            guideBadge("PRO", color: Color.yellow, textColor: .black)
                        }
                        let quotaLocked = (!isPremium && appContainer.userStats.guidesReadCount >= freeGuidesLimit && !appContainer.userStats.isGuideRead(id: guide.id))
                        if quotaLocked {
                            guideBadge("LOCK", color: Color.gray.opacity(0.9), textColor: .white)
                        }
                    }
                    
                    Spacer()
                    
                    Text(guide.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if let subtitle = guide.subtitle {
                        Text(subtitle)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 16) {
                        Label("\(guide.estimatedReadingTime) хв", systemImage: "clock")
                        if appContainer.userStats.isGuideRead(id: guide.id) {
                            Label("Прочитано", systemImage: "checkmark.circle.fill")
                        }
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white.opacity(0.8))
                }
                .padding(20)
            }
            .frame(height: 220)
            .shadow(color: guide.category.swiftUIColor.opacity(0.4), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    // MARK: - Category Section
    private func categorySection(_ category: GuideCategory, guides: [Guide]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: category.iconName)
                    .foregroundColor(category.swiftUIColor)
                Text(category.localizedName)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Button {
                    withAnimation { selectedCategory = category }
                    haptic(.light)
                } label: {
                    Text("Всі")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            
            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(guides.prefix(6)) { guide in
                        NavigationLink(destination: GuideDetailView(guide: guide)) {
                            compactGuideCard(guide)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }
    
    private func compactGuideCard(_ guide: Guide) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Hero area
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [guide.category.swiftUIColor.opacity(0.25), guide.category.swiftUIColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 100)
                    .overlay(
                        Image(systemName: guide.category.iconName)
                            .font(.system(size: 36))
                            .foregroundColor(guide.category.swiftUIColor.opacity(0.5))
                    )
                
                // Badges
                HStack(spacing: 4) {
                    if guide.isNew {
                        smallBadge("NEW", color: .red)
                    }
                    if guide.isPremium && !isPremium {
                        smallBadge("PRO", color: .yellow)
                    }
                    let quotaLocked = (!isPremium && appContainer.userStats.guidesReadCount >= freeGuidesLimit && !appContainer.userStats.isGuideRead(id: guide.id))
                    if quotaLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    if appContainer.userStats.isGuideRead(id: guide.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                }
                .padding(8)
            }
            
            // Title
            Text(guide.title)
                .font(Theme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .frame(width: 160, alignment: .leading)
            
            // Meta
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text("\(guide.estimatedReadingTime) хв")
                    .font(.system(size: 11))
            }
            .foregroundColor(Theme.Colors.textTertiary)
        }
        .frame(width: 160)
    }
    
    // MARK: - Filtered List
    private var filteredList: some View {
        LazyVStack(spacing: 14) {
            if filteredGuides.isEmpty {
                emptyState
            } else {
                ForEach(filteredGuides) { guide in
                    NavigationLink(destination: GuideDetailView(guide: guide)) {
                        listGuideCard(guide)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    private func listGuideCard(_ guide: Guide) -> some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(guide.category.swiftUIColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: guide.category.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(guide.category.swiftUIColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(guide.title)
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if guide.isNew {
                        smallBadge("NEW", color: .red)
                    }
                    if guide.isPremium && !isPremium {
                        smallBadge("PRO", color: .yellow)
                    }
                    let quotaLocked = (!isPremium && appContainer.userStats.guidesReadCount >= freeGuidesLimit && !appContainer.userStats.isGuideRead(id: guide.id))
                    if quotaLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                if let subtitle = guide.subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: 10) {
                    Label("\(guide.estimatedReadingTime) хв", systemImage: "clock")
                    if appContainer.userStats.isGuideRead(id: guide.id) {
                        Label("Прочитано", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.Colors.chipBorder, lineWidth: 1)
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("Нічого не знайдено")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("Спробуйте змінити пошук або фільтри")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
            Button {
                withAnimation {
                    searchText = ""
                    selectedCategory = nil
                }
                haptic(.light)
            } label: {
                Text("Скинути фільтри")
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.accent)
                    .cornerRadius(14)
            }
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - Helpers
    private func guideBadge(_ text: String, color: Color, textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color))
    }
    
    private func smallBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color == .yellow ? .black : .white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
    }
    
    private func reloadSubscription() async {
        async let sub = APIClient.subscriptionCurrent()
        async let ent = APIClient.fetchEntitlements()
        subscription = await sub
        entitlements = await ent
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    // MARK: - Template Helpers
    private func templateCategoryMatchesGuide(templateCategory: TemplateCategory, guideCategory: GuideCategory) -> Bool {
        switch (templateCategory, guideCategory) {
        case (.government, .documents), (.government, .legal), (.government, .integration):
            return true
        case (.housing, .housing):
            return true
        case (.employment, .work), (.employment, .finance):
            return true
        case (.insurance, .insurance), (.insurance, .healthcare):
            return true
        case (.healthcare, .healthcare):
            return true
        case (.education, .education):
            return true
        case (.legal, .legal):
            return true
        case (.banking, .finance), (.banking, .banking):
            return true
        case (.complaint, _), (.request, _), (.application, _), (.notification, _):
            // Generic templates are likely useful across categories
            return true
        default:
            return false
        }
    }
}

// MARK: - Guide Detail View (Redesigned)

struct GuideDetailView: View {
    let guide: Guide
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var entitlements: APIClient.Entitlements?
    @State private var subscription: APIClient.SubscriptionCurrent?
    @State private var scrollOffset: CGFloat = 0
    @State private var showPaywall = false
    @State private var showShareSheet = false
    @State private var showXPToast = false
    @State private var didAwardXP = false
    @State private var timeOnPage: TimeInterval = 0
    @State private var timerActive: Bool = false
    
    // Для теперішнього релізу повністю відкриваємо всі гайди:
    // - немає ліміту "безкоштовних" гайдів
    // - блоку немає навіть для не‑преміум користувачів
    // Якщо в майбутньому з'явиться окремий платний контент, можна
    // повернути логіку через guide.isPremium.
    private let freeGuidesLimit: Int = .max
    
    private var isPremium: Bool {
        if let entitlements { return entitlements.is_premium }
        if let subscription { return subscription.status == "premium" || subscription.status == "trial" }
        return subManager.isPremium
    }
    
    private var isLocked: Bool {
        // Наразі **жоден** гайд не блокується для безкоштовних користувачів.
        // Можна змінити на `(guide.isPremium && !isPremium)`, якщо з'являться платні гайди.
        return false
    }
    
    private var readingProgress: Double {
        // Simple scroll-based progress
        let maxScroll: CGFloat = 1000
        return min(1.0, max(0, scrollOffset / maxScroll))
    }

    /// Minimal время (в секундах), которое пользователь должен провести на екрані гайда,
    /// чтобы вважати, що він хоча б поверхнево прочитав матеріал.
    /// Базируемся на estimatedReadingTime, але обмежуємо діапазон 30–120 секунд.
    private var minReadSeconds: TimeInterval {
        let estMinutes = max(1, guide.estimatedReadingTime)
        let base = Double(estMinutes) * 30.0 // ~30 сек на заявленную хвилину
        return min(120, max(30, base))
    }
    
    // Related templates matched by category/tags/locale
    private var relatedTemplates: [DocumentTemplate] {
        let localeTemplates = appContainer.contentService.getTemplatesForLocale(appContainer.currentLocale.identifier)
        
        // Match by category
        let categoryMatches = localeTemplates.filter { templateCategoryMatchesGuide(templateCategory: $0.category, guideCategory: guide.category) }
        
        // Match by overlapping tags (case-insensitive)
        let guideTags = Set(guide.tags.map { $0.lowercased() })
        let tagMatches = localeTemplates.filter { template in
            let tmplTags = Set(template.tags.map { $0.lowercased() })
            return !guideTags.isDisjoint(with: tmplTags)
        }
        
        // Merge preserving order, cap to 4 to stay light
        var merged: [DocumentTemplate] = []
        func appendUnique(_ templates: [DocumentTemplate]) {
            for t in templates where !merged.contains(t) {
                merged.append(t)
                if merged.count >= 4 { break }
            }
        }
        appendUnique(categoryMatches)
        appendUnique(tagMatches)
        
        // Fallback: if still empty, take top priority templates
        if merged.isEmpty {
            appendUnique(localeTemplates.prefix(3).map { $0 })
        }
        
        return merged
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Reading progress bar
            GeometryReader { geo in
                Rectangle()
                    .fill(guide.category.swiftUIColor)
                    .frame(width: geo.size.width * readingProgress, height: 3)
            }
            .frame(height: 3)
            .zIndex(100)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero
                    heroSection
                    
                    // Content
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // TL;DR Summary
                        tldrSection
                        
                        Divider().background(Theme.Colors.chipBorder)
                        
                        // Main content (with blur if locked)
                        contentSection
                        
                        // Templates step-by-step (only when unlocked)
                        if !relatedTemplates.isEmpty && !isLocked {
                            templateStepsSection
                        }
                        
                        // Links
                        if !guide.links.isEmpty && !isLocked {
                            linksSection
                        }
                        
                        // Tags
                        if !guide.tags.isEmpty {
                            tagsSection
                        }
                        
                        // XP reward info
                        if !appContainer.userStats.isGuideRead(id: guide.id) && !isLocked {
                            xpRewardBanner
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: -geo.frame(in: .named("scroll")).origin.y
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showShareSheet = true; haptic(.light) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .background(
            ZStack {
                Theme.Colors.primaryBackground
                    .ignoresSafeArea()
                
                // Winter theme overlay
                if WinterTheme.isActive {
                    WinterSceneLite(intensity: .light)
                }
            }
        )
        .sheet(isPresented: $showShareSheet) {
            GuidesShareSheet(items: [guide.title, guide.bodyMarkdown])
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionView().environmentObject(appContainer)
        }
        .overlay(alignment: .top) {
            if showXPToast {
                xpToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            // Стартуємо таймер читання тільки коли екран видимий
            timerActive = true
        }
        .onDisappear {
            timerActive = false
        }
        // Плавно відслідковуємо "реальне" читання:
        //  - користувач проводить на сторінці minReadSeconds
        //  - а також проскролив хоча б ~40% контенту (readingProgress >= 0.4)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard timerActive, !didAwardXP, !isLocked else { return }
            timeOnPage += 1
            let hasTime = timeOnPage >= minReadSeconds
            let hasScroll = readingProgress >= 0.4
            let wasReadBefore = appContainer.userStats.isGuideRead(id: guide.id)
            guard hasTime, hasScroll, !wasReadBefore else { return }
            
            // Фіксуємо "прочитано" і даємо XP тільки один раз
            appContainer.userStats.markGuideRead(id: guide.id)
            didAwardXP = true
            
            // Анімація тоста з XP така ж, як була раніше
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: reduceMotion ? 0.01 : 0.4,
                                      dampingFraction: 0.8)) {
                    showXPToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(.easeInOut(duration: reduceMotion ? 0.1 : 0.25)) {
                        showXPToast = false
                    }
                }
            }
        }
        .task {
            async let sub = APIClient.subscriptionCurrent()
            async let ent = APIClient.fetchEntitlements()
            subscription = await sub
            entitlements = await ent
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            LinearGradient(
                colors: [guide.category.swiftUIColor, guide.category.swiftUIColor.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 260)
            .overlay(
                Image(systemName: guide.category.iconName)
                    .font(.system(size: 140, weight: .thin))
                    .foregroundColor(.white.opacity(0.12))
                    .offset(x: 100, y: -30)
            )
            .overlay(
                LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom)
            )
            
            // Winter frost overlay
            if WinterTheme.isActive {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.1),
                        Color.clear,
                        Color.cyan.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 260)
                
                // Corner snowflakes
                Text("❄️")
                    .font(.system(size: 24))
                    .opacity(0.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: -16, y: 16)
                
                Text("✨")
                    .font(.system(size: 16))
                    .opacity(0.7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .offset(x: 16, y: 20)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Badges
                HStack(spacing: 8) {
                    categoryBadge
                    if guide.isNew {
                        Text(WinterTheme.isActive ? "🎄 NEW" : "NEW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.red))
                    }
                    if guide.isPremium {
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.yellow))
                    }
                    if appContainer.userStats.isGuideRead(id: guide.id) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Прочитано")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.green.opacity(0.8)))
                    }
                }
                
                Spacer()
                
                Text(guide.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(3)
                
                if let subtitle = guide.subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
                
                // Meta
                HStack(spacing: 16) {
                    Label("\(guide.estimatedReadingTime) хв читання", systemImage: "clock")
                    Label(formatDate(guide.lastUpdated), systemImage: "calendar")
                }
                .font(Theme.Typography.caption)
                .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
        }
        .frame(height: 260)
    }
    
    private var categoryBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: guide.category.iconName)
            Text(guide.category.localizedName)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    // MARK: - TL;DR Section
    private var tldrSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("Головне за 30 секунд")
                    .font(Theme.Typography.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(Theme.Colors.textPrimary)
            
            // Extract first 3-5 bullet points or summary
            VStack(alignment: .leading, spacing: 8) {
                ForEach(extractKeyPoints().prefix(5), id: \.self) { point in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(guide.category.swiftUIColor)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(point)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
            }
            .padding(16)
            .background(guide.category.swiftUIColor.opacity(0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(guide.category.swiftUIColor.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Content Section
    @ViewBuilder
    private var contentSection: some View {
        if isLocked {
            ZStack {
                // Blurred preview
                MarkdownContentView(content: String(guide.bodyMarkdown.prefix(500)))
                    .blur(radius: 6)
                
                // Lock overlay
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.accent)
                    
                    let quotaLocked = (!isPremium && !appContainer.userStats.isGuideRead(id: guide.id) && appContainer.userStats.guidesReadCount >= freeGuidesLimit)
                    Text(quotaLocked ? "Ліміт безкоштовних гідів вичерпано" : "Повний доступ з Premium")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text(quotaLocked ? "Доступно до 5 гідів на безкоштовному плані. Оформіть Premium, щоб читати без обмежень." : "Розблокуйте всі гіди, AI-інструменти та необмежені збереження")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        showPaywall = true
                        haptic(.medium)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                            Text("Спробувати 7 днів безкоштовно")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .padding(.horizontal, 20)
            }
        } else {
            MarkdownContentView(content: guide.bodyMarkdown)
        }
    }
    
    // MARK: - Template Steps Section
    private var templateStepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Документи за кроками")
                .font(Theme.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Text("Заповніть потрібні шаблони одразу під час читання гайда.")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
            
            VStack(spacing: 12) {
                ForEach(Array(relatedTemplates.enumerated()), id: \.element.id) { index, template in
                    TemplateStepCard(
                        stepNumber: index + 1,
                        template: template,
                        accent: guide.category.swiftUIColor
                    )
                }
            }
        }
        .padding(16)
        .background(Theme.Colors.primaryBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.Colors.chipBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Links Section
    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Корисні посилання")
                .font(Theme.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.textPrimary)
            
            ForEach(guide.links) { link in
                LinkRow(link: link, categoryColor: guide.category.swiftUIColor)
            }
        }
    }
    
    // MARK: - Tags Section
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Теги")
                .font(Theme.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.textPrimary)
            
            FlowLayout(spacing: 8) {
                ForEach(guide.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.chipBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Colors.chipBorder, lineWidth: 1)
                        )
                }
            }
        }
    }
    
    // MARK: - XP Reward Banner
    private var xpRewardBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 44)
                Text("⭐")
                    .font(.system(size: 22))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Отримайте +50 XP")
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Дочитайте гід до кінця")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(colors: [.yellow.opacity(0.15), .orange.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - XP Toast
    private var xpToast: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 20, height: 20)
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("+50 XP")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LinearGradient(colors: [.yellow.opacity(0.9), .orange.opacity(0.9)],
                                       startPoint: .leading, endPoint: .trailing), lineWidth: 1.2)
        )
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 6)
        .padding(.top, 56)
    }
    
    // MARK: - Helpers
    private func extractKeyPoints() -> [String] {
        // Extract bullet points or first sentences
        let lines = guide.bodyMarkdown.components(separatedBy: .newlines)
        var points: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
                points.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("1. ") || trimmed.hasPrefix("2. ") || trimmed.hasPrefix("3. ") {
                if let idx = trimmed.firstIndex(of: " ") {
                    points.append(String(trimmed[trimmed.index(after: idx)...]))
                }
            }
            if points.count >= 5 { break }
        }
        // Fallback: first sentences
        if points.isEmpty {
            let sentences = guide.bodyMarkdown.components(separatedBy: ". ")
            points = sentences.prefix(3).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        return points
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    // MARK: - Template Helpers (in-scope)
    private func templateCategoryMatchesGuide(templateCategory: TemplateCategory, guideCategory: GuideCategory) -> Bool {
        switch (templateCategory, guideCategory) {
        case (.government, .documents), (.government, .legal), (.government, .integration):
            return true
        case (.housing, .housing):
            return true
        case (.employment, .work), (.employment, .finance):
            return true
        case (.insurance, .insurance), (.insurance, .healthcare):
            return true
        case (.healthcare, .healthcare):
            return true
        case (.education, .education):
            return true
        case (.legal, .legal):
            return true
        case (.banking, .finance), (.banking, .banking):
            return true
        case (.complaint, _), (.request, _), (.application, _), (.notification, _):
            return true
        default:
            return false
        }
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Supporting Views

struct TemplateStepCard: View {
    let stepNumber: Int
    let template: DocumentTemplate
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("\(stepNumber)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(accent)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title)
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)
                    Text(template.description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            
            HStack(spacing: 8) {
                badge(title: template.category.localizedName, icon: template.category.iconName, color: accent.opacity(0.15), textColor: accent)
                badge(title: template.language.uppercased(), icon: "globe", color: Color.gray.opacity(0.15), textColor: Theme.Colors.textSecondary)
                if template.isOfficial {
                    badge(title: "Офіційний", icon: "checkmark.seal.fill", color: Color.green.opacity(0.15), textColor: .green)
                }
            }
            
            HStack(spacing: 10) {
                NavigationLink {
                    TemplateDetailView(template: template)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                        Text("Переглянути")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(accent.opacity(0.12))
                    .foregroundColor(accent)
                    .cornerRadius(12)
                }
                
                Spacer()
                
                Button {
                    let content = template.generateContent(with: [:])
                    UIPasteboard.general.string = content
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Скопіювати")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color(.systemGray6))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .cornerRadius(12)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
    }
    
    private func badge(title: String, icon: String, color: Color, textColor: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color)
        .foregroundColor(textColor)
        .cornerRadius(10)
    }
}

struct LinkRow: View {
    let link: GuideLink
    let categoryColor: Color
    @State private var isPressed = false
    
    var body: some View {
        Button {
            if let url = URL(string: link.url) {
                UIApplication.shared.open(url)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: link.type.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(categoryColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title)
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                    if let desc = link.description {
                        Text(desc)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(categoryColor)
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(categoryColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.spring(response: 0.3), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { isPressed = $0 }, perform: {})
    }
}

struct MarkdownContentView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ForEach(parseMarkdown(content), id: \.id) { element in
                element.view
            }
        }
    }
    
    private func parseMarkdown(_ content: String) -> [MarkdownElement] {
        let lines = content.components(separatedBy: .newlines)
        var elements: [MarkdownElement] = []
        
        for line in lines {
            if line.hasPrefix("# ") {
                elements.append(.heading1(String(line.dropFirst(2))))
            } else if line.hasPrefix("## ") {
                elements.append(.heading2(String(line.dropFirst(3))))
            } else if line.hasPrefix("### ") {
                elements.append(.heading3(String(line.dropFirst(4))))
            } else if line.hasPrefix("> ") {
                elements.append(.callout(String(line.dropFirst(2))))
            } else if line.trimmingCharacters(in: .whitespaces) == "---" {
                elements.append(.separator)
            } else if line.hasPrefix("- [ ] ") {
                elements.append(.task(text: String(line.dropFirst(6)), done: false))
            } else if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                elements.append(.task(text: String(line.dropFirst(6)), done: true))
            } else if line.hasPrefix("- ") {
                elements.append(.bulletPoint(String(line.dropFirst(2))))
            } else if !line.isEmpty {
                elements.append(.paragraph(line))
            }
        }
        
        return elements
    }
}

enum MarkdownElement {
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case paragraph(String)
    case bulletPoint(String)
    case callout(String)
    case task(text: String, done: Bool)
    case separator
    
    var id: String {
        switch self {
        case .heading1(let t), .heading2(let t), .heading3(let t), .paragraph(let t), .bulletPoint(let t), .callout(let t), .task(let t, _):
            return t + UUID().uuidString
        case .separator:
            return UUID().uuidString
        }
    }
    
    @ViewBuilder
    var view: some View {
        switch self {
        case .heading1(let text):
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                Rectangle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 44, height: 3)
                    .cornerRadius(1.5)
            }
            .padding(.top, Theme.Spacing.lg)
            
        case .heading2(let text):
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                Rectangle()
                    .fill(Theme.Colors.accent.opacity(0.6))
                    .frame(width: 32, height: 2)
                    .cornerRadius(1)
            }
            .padding(.top, Theme.Spacing.md)
            
        case .heading3(let text):
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.top, Theme.Spacing.sm)
            
        case .paragraph(let text):
            Text(text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineSpacing(6)
            
        case .bulletPoint(let text):
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Theme.Colors.accentTurquoise)
                    .frame(width: 6, height: 6)
                    .padding(.top, 8)
                Text(text)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineSpacing(6)
            }
            
        case .callout(let text):
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Theme.Colors.info)
                    .font(.system(size: 18))
                Text(text)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            .padding(16)
            .background(Theme.Colors.info.opacity(0.1))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.Colors.info.opacity(0.2), lineWidth: 1)
            )
            
        case .task(let text, let done):
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(done ? .green : Theme.Colors.textTertiary)
                    .font(.system(size: 18))
                Text(text)
                    .font(Theme.Typography.body)
                    .strikethrough(done)
                    .foregroundColor(done ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
            }
            .padding(.vertical, 2)
            
        case .separator:
            Divider()
                .background(Theme.Colors.chipBorder)
                .padding(.vertical, 8)
        }
    }
}

// Flow layout for tags
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        let size: CGSize
        let positions: [CGPoint]
        
        init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var currentPosition = CGPoint.zero
            var lineHeight: CGFloat = 0
            var maxX: CGFloat = 0
            
            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)
                
                if currentPosition.x + subviewSize.width > maxWidth && currentPosition.x > 0 {
                    currentPosition.x = 0
                    currentPosition.y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(currentPosition)
                currentPosition.x += subviewSize.width + spacing
                lineHeight = max(lineHeight, subviewSize.height)
                maxX = max(maxX, currentPosition.x - spacing)
            }
            
            self.positions = positions
            self.size = CGSize(width: maxX, height: currentPosition.y + lineHeight)
        }
    }
}

struct GuidesShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    GuidesView()
        .environmentObject(AppContainer())
        .environmentObject(AppLockManager())
}

