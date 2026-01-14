//
//  GuidesViewRedesigned.swift
//  sweezy
//
//  Bold GoIT-inspired redesign with full search and interactive cards
//

import SwiftUI

struct GuidesViewRedesigned: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    
    @State private var searchText = ""
    @State private var selectedCategory: GuideCategory?
    @State private var selectedGuide: Guide?
    @Namespace private var animation
    
    private var filteredGuides: [Guide] {
        appContainer.contentService.searchGuides(
            query: searchText,
            category: selectedCategory,
            canton: appContainer.userProfile?.canton
        )
    }
    
    private var categories: [GuideCategory] {
        GuideCategory.allCases
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Theme.Spacing.xl) {
                    // Header section
                    headerSection
                    
                    // Search bar
                    searchBarSection
                    
                    // Category filter chips
                    categoryFilterSection
                    
                    // Guides list
                    if lockManager.isRegistered {
                        guidesListSection
                    } else {
                        lockedContentSection
                    }
                }
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .background(Theme.Colors.primaryBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await appContainer.contentService.refreshContent()
                triggerHapticFeedback()
            }
            .sheet(item: $selectedGuide) { guide in
                GuideDetailSheet(guide: guide)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(
                "Довідники",
                subtitle: "\(filteredGuides.count) статей доступно"
            )
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
    }
    
    // MARK: - Search Bar Section
    
    private var searchBarSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Glass search bar with gradient focus
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.Colors.gradientPrimaryAdaptive)
                
                TextField("Шукати довідники...", text: $searchText)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(Theme.Animation.quick) {
                            searchText = ""
                        }
                        triggerHapticFeedback()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.glassMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .stroke(
                        searchText.isEmpty
                            ? AnyShapeStyle(Color.white.opacity(0.2))
                            : AnyShapeStyle(LinearGradient(
                                colors: [Theme.Colors.primary.opacity(0.4), Theme.Colors.accent.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )),
                        lineWidth: searchText.isEmpty ? 1 : 2
                    )
                    .animation(Theme.Animation.quick, value: searchText.isEmpty)
                    .allowsHitTesting(false)
            )
            .themeShadow(Theme.Shadows.level1)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }
    
    // MARK: - Category Filter Section
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                // "All" filter
                CategoryChip(
                    title: "Всі",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    namespace: animation
                ) {
                    withAnimation(Theme.Animation.smooth) {
                        selectedCategory = nil
                    }
                    triggerHapticFeedback()
                }
                
                // Category filters
                ForEach(categories, id: \.self) { category in
                    CategoryChip(
                        title: category.localizedName,
                        icon: category.iconName,
                        isSelected: selectedCategory == category,
                        namespace: animation
                    ) {
                        withAnimation(Theme.Animation.smooth) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                        triggerHapticFeedback()
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
    
    // MARK: - Guides List Section
    
    private var guidesListSection: some View {
        LazyVStack(spacing: Theme.Spacing.md) {
            if filteredGuides.isEmpty {
                EmptyStateView(
                    systemImage: "doc.text.magnifyingglass",
                    title: "Нічого не знайдено",
                    subtitle: "Спробуйте змінити пошуковий запит або фільтр"
                )
                .padding(.top, Theme.Spacing.xxl)
            } else {
                ForEach(Array(filteredGuides.enumerated()), id: \.element.id) { index, guide in
                    InteractiveCard(
                        icon: guide.category.iconName,
                        iconGradient: true,
                        title: guide.title,
                        subtitle: guide.subtitle,
                        badge: (guide.priority >= 5) ? "Важливо" : (guide.isNew ? "Нове" : nil),
                        badgeColor: (guide.priority >= 5) ? Theme.Colors.warning : Theme.Colors.success
                    ) {
                        selectedGuide = guide
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(
                        Theme.Animation.smooth.delay(Double(index) * 0.05),
                        value: filteredGuides.count
                    )
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }
    
    // MARK: - Locked Content Section
    
    private var lockedContentSection: some View {
        ZStack {
            // Blurred preview
            guidesListSection
                .blur(radius: 6)
                .disabled(true)
            
            // Lock overlay
            VStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primary.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .blur(radius: 12)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Theme.Colors.gradientPrimaryAdaptive)
                }
                
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Зареєструйтесь для доступу")
                        .font(Theme.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text("Отримайте повний доступ до всіх довідників, чеклістів та шаблонів")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
                
                PrimaryButton("Зареєструватись", style: .primary) {
                    // Navigate to registration
                }
                .frame(maxWidth: 280)
            }
            .padding(Theme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.xxl, style: .continuous)
                    .fill(Theme.Colors.glassMaterial.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.xxl, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .themeShadow(Theme.Shadows.level4)
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
    
    // MARK: - Helpers
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Category Chip Component

private struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(title)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.pill, style: .continuous)
                            .fill(Theme.Colors.gradientPrimaryAdaptive)
                            .matchedGeometryEffect(id: "selected", in: namespace)
                    } else {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.pill, style: .continuous)
                            .fill(Theme.Colors.glassMaterial.opacity(0.5))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.pill, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.clear
                            : Color.white.opacity(0.2),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .themeShadow(isSelected ? Theme.Shadows.level2 : Theme.Shadows.level1)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.95))
    }
}

// MARK: - Guide Detail Sheet (Placeholder)

private struct GuideDetailSheet: View {
    let guide: Guide
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Hero image or gradient
                    Rectangle()
                        .fill(Theme.Colors.gradientHero)
                        .frame(height: 200)
                        .overlay(
                            VStack {
                                Spacer()
                                HStack {
                                    Image(systemName: guide.category.iconName)
                                        .font(.system(size: 48))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(Theme.Spacing.lg)
                            }
                        )
                    
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text(guide.title)
                            .font(Theme.Typography.title1)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        if let subtitle = guide.subtitle {
                            Text(subtitle)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        
                        Divider()
                        
                        Text(guide.bodyMarkdown)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineSpacing(6)

                        if !guide.tags.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                Text("common.tags".localized)
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                FlowLayout(spacing: Theme.Spacing.sm) {
                                    ForEach(guide.tags, id: \.self) { tag in
                                        HStack(spacing: 6) {
                                            Text("#\(tag)")
                                                .font(Theme.Typography.caption)
                                                .foregroundColor(Theme.Colors.textPrimary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Theme.Colors.primaryBackground))
                                        .overlay(Capsule().stroke(Theme.Colors.chipBorder, lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
            }
            .background(Theme.Colors.primaryBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрити") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Guides Redesigned - Registered") {
    struct PreviewWrapper: View {
        @StateObject private var container = AppContainer()
        @StateObject private var lockManager = AppLockManager()
        
        init() {
            // Simulate registered user
            let manager = AppLockManager()
            manager.userName = "Тест"
            manager.userEmail = "test@test.com"
            manager.isRegistered = true
            _lockManager = StateObject(wrappedValue: manager)
        }
        
        var body: some View {
            GuidesViewRedesigned()
                .environmentObject(container)
                .environmentObject(lockManager)
        }
    }
    
    return PreviewWrapper()
}

#Preview("Guides Redesigned - Locked") {
    GuidesViewRedesigned()
        .environmentObject(AppContainer())
        .environmentObject(AppLockManager())
}

#Preview("Guides Redesigned - Dark") {
    struct PreviewWrapper: View {
        @StateObject private var container = AppContainer()
        @StateObject private var lockManager = AppLockManager()
        
        init() {
            let manager = AppLockManager()
            manager.userName = "Тест"
            manager.userEmail = "test@test.com"
            manager.isRegistered = true
            _lockManager = StateObject(wrappedValue: manager)
        }
        
        var body: some View {
            GuidesViewRedesigned()
                .environmentObject(container)
                .environmentObject(lockManager)
                .preferredColorScheme(.dark)
        }
    }
    
    return PreviewWrapper()
}

