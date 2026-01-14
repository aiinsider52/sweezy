//
//  ChecklistsView.swift
//  sweezy
//
//  Redesigned: Hero progress, gamification, today's focus, timeline view, celebrations

import SwiftUI

struct ChecklistsView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @State private var selectedCategory: ChecklistCategory?
    @State private var viewMode: ViewMode = .list
    @State private var showPaywall = false
    @Namespace private var animation
    
    enum ViewMode: String, CaseIterable {
        case list = "list"
        case timeline = "timeline"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .timeline: return "point.topleft.down.to.point.bottomright.curvepath"
            }
        }
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
        if let category = selectedCategory { return all.filter { $0.category == category } }
        return all
    }
    
    // Overall progress across all checklists
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
    
    // Today's recommended task
    private var todaysFocus: (checklist: Checklist, step: ChecklistStep)? {
        for checklist in allChecklists {
            let key = "checklist_\(checklist.id.uuidString)_completed"
            let completed = Set((UserDefaults.standard.array(forKey: key) as? [String] ?? []).compactMap { UUID(uuidString: $0) })
            if let nextStep = checklist.steps.sorted(by: { $0.order < $1.order }).first(where: { !completed.contains($0.id) }) {
                return (checklist, nextStep)
            }
        }
        return nil
    }
    
    // Streak calculation — використовуємо глобальний login-streak з GamificationService
    private var currentStreak: Int {
        appContainer.gamification.currentStreak()
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
                    VStack(spacing: Theme.Spacing.lg) {
                        // Hero progress card
                        heroProgressCard
                        
                        // Streak & gamification bar
                        if currentStreak > 0 || appContainer.gamification.totalXP > 0 {
                            gamificationBar
                        }
                        
                        // Today's focus
                        if let focus = todaysFocus {
                            todaysFocusCard(focus.checklist, step: focus.step)
                        }
                        
                        // View mode toggle + category filters
                        filtersSection
                        
                        // Content based on view mode
                        if viewMode == .list {
                            listContent
                        } else {
                            timelineContent
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Чек-листи")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Button {
                                withAnimation(.spring(response: 0.3)) { viewMode = mode }
                                haptic(.light)
                            } label: {
                                Label(mode == .list ? "Список" : "Timeline", systemImage: mode.icon)
                            }
                        }
                    } label: {
                        Image(systemName: viewMode.icon)
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
            .refreshable {
                await appContainer.contentService.refreshContent()
                haptic(.light)
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionView().environmentObject(appContainer)
            }
        }
    }
    
    // MARK: - Hero Progress Card
    private var heroProgressCard: some View {
        let progress = overallProgress
        
        return ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.accentTurquoise, Theme.Colors.accentTurquoise.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Decorative circles
            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: 120, height: 120)
                .offset(x: 100, y: -40)
            
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 80, height: 80)
                .offset(x: -120, y: 50)
            
            HStack(spacing: 20) {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 10)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: progress.percentage)
                        .stroke(
                            .white,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8), value: progress.percentage)
                    
                    VStack(spacing: 2) {
                        Text("\(Int(progress.percentage * 100))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("готово")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ваш прогрес інтеграції")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(progress.completed) з \(progress.total) задач виконано")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    
                    if progress.total - progress.completed > 0 {
                        Text("Залишилось \(progress.total - progress.completed) задач")
                            .font(Theme.Typography.caption)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Всі задачі виконано!")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
            .padding(20)
        }
        .frame(height: 160)
        .shadow(color: Theme.Colors.accentTurquoise.opacity(0.4), radius: 16, x: 0, y: 8)
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    // MARK: - Gamification Bar
    private var gamificationBar: some View {
        HStack(spacing: 16) {
            // Streak
            if currentStreak > 0 {
                HStack(spacing: 8) {
                    Text("🔥")
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(currentStreak)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("днів")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
            
            // XP
            HStack(spacing: 8) {
                Text("⭐")
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(appContainer.gamification.totalXP)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("XP")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            
            // Level
            HStack(spacing: 8) {
                Text("🏆")
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Рівень \(appContainer.gamification.level())")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    // MARK: - Today's Focus Card
    private func todaysFocusCard(_ checklist: Checklist, step: ChecklistStep) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(Theme.Colors.accent)
                Text("Фокус на сьогодні")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Text("+10 XP")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(10)
            }
            
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(checklist.category.swiftUIColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: checklist.category.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(checklist.category.swiftUIColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(checklist.title)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        if let time = step.estimatedTime {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(time)
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                }
                
                Spacer()
                
                // Complete button
                Button {
                    completeTask(checklist: checklist, step: step)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.Colors.accentTurquoise)
                }
                .accessibilityLabel("Позначити крок виконаним")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Theme.Colors.accent.opacity(0.3), Theme.Colors.accentTurquoise.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    // MARK: - Filters Section
    private var filtersSection: some View {
        VStack(spacing: 12) {
            // Category chips with counters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    categoryChip(nil, count: allChecklists.count)
                    ForEach(ChecklistCategory.allCases, id: \.self) { cat in
                        let count = allChecklists.filter { $0.category == cat }.count
                        if count > 0 {
                            categoryChip(cat, count: count)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }
    
    private func categoryChip(_ category: ChecklistCategory?, count: Int) -> some View {
        let isSelected = selectedCategory == category
        let color = category?.swiftUIColor ?? Theme.Colors.accent
        
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedCategory = category
            }
            haptic(.light)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: category?.iconName ?? "square.grid.2x2")
                    .font(.system(size: 14, weight: .semibold))
                Text(category?.localizedName ?? "Всі")
                    .font(Theme.Typography.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                // Counter badge
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isSelected ? color : Theme.Colors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? color.opacity(0.2) : Theme.Colors.chipBackground)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? color.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? color : Theme.Colors.textSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? color : Theme.Colors.chipBorder, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - List Content
    private var listContent: some View {
        LazyVStack(spacing: 14) {
            if filteredChecklists.isEmpty {
                emptyState
            } else {
                ForEach(filteredChecklists) { checklist in
                    NavigationLink(destination: ChecklistDetailView(checklist: checklist)) {
                        ChecklistProgressCard(checklist: checklist)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    // MARK: - Timeline Content
    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(filteredChecklists.enumerated()), id: \.element.id) { index, checklist in
                TimelineChecklistRow(
                    checklist: checklist,
                    isFirst: index == 0,
                    isLast: index == filteredChecklists.count - 1
                )
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("Немає чек-листів")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("Спробуйте змінити фільтр категорії")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - Helpers
    private func completeTask(checklist: Checklist, step: ChecklistStep) {
        let key = "checklist_\(checklist.id.uuidString)_completed"
        var completed = Set((UserDefaults.standard.array(forKey: key) as? [String] ?? []))
        completed.insert(step.id.uuidString)
        UserDefaults.standard.set(Array(completed), forKey: key)
        
        // Gamification
        EventBus.shared.emit(GamEvent(type: .checklistStepCompleted, metadata: ["stepId": step.id.uuidString]))
        
        haptic(.success)
    }
    
    private func haptic(_ style: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(style)
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Checklist Progress Card

private struct ChecklistProgressCard: View {
    let checklist: Checklist
    @State private var completedSteps: Set<UUID> = []
    @State private var isPressed = false
    
    private var storageKey: String { "checklist_\(checklist.id.uuidString)_completed" }
    
    init(checklist: Checklist) {
        self.checklist = checklist
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            _completedSteps = State(initialValue: Set(saved.compactMap { UUID(uuidString: $0) }))
        }
    }
    
    private var completion: Double {
        guard !checklist.steps.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(checklist.steps.count)
    }
    
    private var isCompleted: Bool { completion >= 1.0 }
    private var isNotStarted: Bool { completedSteps.isEmpty }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                // Icon with status
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(checklist.category.swiftUIColor.opacity(isCompleted ? 0.25 : 0.15))
                        .frame(width: 60, height: 60)
                    
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: checklist.category.iconName)
                            .font(.system(size: 26))
                            .foregroundColor(checklist.category.swiftUIColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(checklist.title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        // Status badges
                        if isCompleted {
                            completedBadge
                        } else if checklist.isNew {
                            newBadge
                        }
                    }
                    
                    Text(checklist.description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                    
                    // Meta info
                    HStack(spacing: 12) {
                        Label(checklist.estimatedDuration, systemImage: "clock")
                        Label(checklist.difficulty.localizedName, systemImage: "speedometer")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            
            // Progress bar with glow
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(checklist.category.swiftUIColor.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: isCompleted 
                                    ? [.green, .green.opacity(0.7)]
                                    : [checklist.category.swiftUIColor, checklist.category.swiftUIColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * completion, height: 8)
                        .shadow(color: (isCompleted ? Color.green : checklist.category.swiftUIColor).opacity(0.5), radius: 4, x: 0, y: 0)
                        .animation(.spring(response: 0.5), value: completion)
                }
            }
            .frame(height: 8)
            
            // Bottom stats
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "chart.bar.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isCompleted ? .green : checklist.category.swiftUIColor)
                    Text(isCompleted ? "Завершено" : "\(Int(completion * 100))%")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isCompleted ? .green : Theme.Colors.textSecondary)
                }
                
                Spacer()
                
                Text("\(completedSteps.count)/\(checklist.steps.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isCompleted 
                        ? Color.green.opacity(0.4)
                        : (isNotStarted ? Theme.Colors.chipBorder : checklist.category.swiftUIColor.opacity(0.3)),
                    lineWidth: isCompleted ? 2 : 1
                )
        )
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.spring(response: 0.3), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { isPressed = $0 }, perform: {})
        .onReceive(EventBus.shared.publisher) { event in
            switch event.type {
            case .checklistStepCompleted, .checklistCompleted:
                if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
                    completedSteps = Set(saved.compactMap { UUID(uuidString: $0) })
                }
            default:
                break
            }
        }
    }
    
    private var completedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
            Text("Готово")
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green)
        .cornerRadius(8)
    }
    
    private var newBadge: some View {
        Text("NEW")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red)
            .cornerRadius(8)
    }
}

// MARK: - Timeline Checklist Row

private struct TimelineChecklistRow: View {
    let checklist: Checklist
    let isFirst: Bool
    let isLast: Bool
    @State private var completedSteps: Set<UUID> = []
    private var storageKey: String { "checklist_\(checklist.id.uuidString)_completed" }
    
    init(checklist: Checklist, isFirst: Bool, isLast: Bool) {
        self.checklist = checklist
        self.isFirst = isFirst
        self.isLast = isLast
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            _completedSteps = State(initialValue: Set(saved.compactMap { UUID(uuidString: $0) }))
        }
    }
    
    private var completion: Double {
        guard !checklist.steps.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(checklist.steps.count)
    }
    
    private var isCompleted: Bool { completion >= 1.0 }
    private var isInProgress: Bool { !completedSteps.isEmpty && completion < 1.0 }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline line + dot
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(isCompleted || isInProgress ? Theme.Colors.accentTurquoise : Theme.Colors.chipBorder)
                        .frame(width: 3, height: 20)
                }
                
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : (isInProgress ? Theme.Colors.accentTurquoise : Theme.Colors.chipBackground))
                        .frame(width: 24, height: 24)
                    
                    if isCompleted {
                        if WinterTheme.isActive {
                            Text("❄️")
                                .font(.system(size: 12))
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    } else if isInProgress {
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .stroke(Theme.Colors.chipBorder, lineWidth: 2)
                            .frame(width: 20, height: 20)
                    }
                }
                
                if !isLast {
                    Rectangle()
                        .fill(isCompleted ? Theme.Colors.accentTurquoise : Theme.Colors.chipBorder)
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 24)
            
            // Content card
            NavigationLink(destination: ChecklistDetailView(checklist: checklist)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(checklist.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text("\(completedSteps.count)/\(checklist.steps.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isCompleted ? .green : Theme.Colors.textSecondary)
                    }
                    
                    Text(checklist.description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                    
                    // Mini progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.Colors.chipBorder)
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isCompleted ? Color.green : checklist.category.swiftUIColor)
                                .frame(width: geo.size.width * completion, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(14)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isInProgress ? checklist.category.swiftUIColor.opacity(0.4) : Theme.Colors.chipBorder, lineWidth: isInProgress ? 2 : 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
        .onReceive(EventBus.shared.publisher) { event in
            switch event.type {
            case .checklistStepCompleted, .checklistCompleted:
                if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
                    completedSteps = Set(saved.compactMap { UUID(uuidString: $0) })
                }
            default:
                break
            }
        }
    }
}

// MARK: - Checklist Detail View (Redesigned)

struct ChecklistDetailView: View {
    let checklist: Checklist
    @EnvironmentObject private var appContainer: AppContainer
    @State private var completedSteps: Set<UUID> = []
    @State private var expandedSteps: Set<UUID> = []
    @State private var showCelebration = false
    @State private var showXPToast = false
    @State private var earnedXP = 0
    
    private var sortedSteps: [ChecklistStep] { checklist.steps.sorted { $0.order < $1.order } }
    private var completion: Double {
        guard !checklist.steps.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(checklist.steps.count)
    }
    
    init(checklist: Checklist) {
        self.checklist = checklist
        let key = "checklist_\(checklist.id.uuidString)_completed"
        if let saved = UserDefaults.standard.array(forKey: key) as? [String] {
            _completedSteps = State(initialValue: Set(saved.compactMap { UUID(uuidString: $0) }))
        }
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.primaryBackground.ignoresSafeArea()
            
            // Winter theme background
            if WinterTheme.isActive {
                WinterSceneLite(intensity: .light)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.lg) {
                    // Hero header
                    heroHeader
                    
                    // Progress card
                    progressCard
                    
                    // Steps
                    stepsSection
                }
                .padding(.bottom, 100)
            }
        }
        .navigationTitle(checklist.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Sync active checklist state with stats service
            appContainer.userStats.setChecklistActive(id: checklist.id, active: !completedSteps.isEmpty)
        }
        .overlay(alignment: .center) {
            if showCelebration {
                CelebrationOverlay()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if showXPToast {
                xpToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: completion) { old, new in
            if new >= 1.0 && old < 1.0 {
                withAnimation(.spring()) { showCelebration = true }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
                // Award bonus XP (use centralized XP table so UI and totals always match)
                let bonus = GamificationXP.value(for: .checklistCompleted)
                earnedXP = bonus
                EventBus.shared.emit(
                    GamEvent(
                        type: .checklistCompleted,
                        metadata: [
                            "entityId": checklist.id.uuidString,
                            "checklistId": checklist.id.uuidString
                        ]
                    )
                )
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showCelebration = false }
                }
            }
        }
    }
    
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            LinearGradient(
                colors: [checklist.category.swiftUIColor, checklist.category.swiftUIColor.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            .overlay(
                Image(systemName: checklist.category.iconName)
                    .font(.system(size: 100, weight: .thin))
                    .foregroundColor(.white.opacity(0.15))
                    .offset(x: 80, y: -20)
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
                .frame(height: 180)
                
                // Corner snowflakes
                Text("❄️")
                    .font(.system(size: 20))
                    .opacity(0.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: -12, y: 12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Category badge
                HStack(spacing: 6) {
                    Image(systemName: checklist.category.iconName)
                    Text(checklist.category.localizedName)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                
                Spacer()
                
                Text(checklist.description)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                
                HStack(spacing: 16) {
                    Label(checklist.estimatedDuration, systemImage: "clock")
                    Label(checklist.difficulty.localizedName, systemImage: "speedometer")
                }
                .font(Theme.Typography.caption)
                .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    private var progressCard: some View {
        HStack(spacing: 20) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(checklist.category.swiftUIColor.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: completion)
                    .stroke(
                        completion >= 1.0 ? Color.green : checklist.category.swiftUIColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: completion)
                
                Text("\(Int(completion * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(completion >= 1.0 ? .green : checklist.category.swiftUIColor)
            }
            .accessibilityLabel("Прогрес")
            .accessibilityValue("\(Int(completion * 100)) відсотків")
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Прогрес")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("\(completedSteps.count) з \(checklist.steps.count) кроків виконано")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                if completion < 1.0 {
                    Text("Залишилось: \(checklist.steps.count - completedSteps.count)")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Кроки")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                let stepXP = GamificationXP.value(for: .checklistStepCompleted)
                Text("+\(stepXP) XP за крок")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, Theme.Spacing.md)
            
            ForEach(sortedSteps) { step in
                StepCard(
                    step: step,
                    isCompleted: completedSteps.contains(step.id),
                    isExpanded: expandedSteps.contains(step.id),
                    categoryColor: checklist.category.swiftUIColor,
                    onToggle: { toggleStep(step) },
                    onExpand: {
                        withAnimation(.spring(response: 0.3)) {
                            if expandedSteps.contains(step.id) {
                                expandedSteps.remove(step.id)
                            } else {
                                expandedSteps.insert(step.id)
                            }
                        }
                    }
                )
            }
        }
    }
    
    private var xpToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 16))
                .foregroundColor(.yellow)
            Text("+\(earnedXP) XP")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(colors: [.yellow.opacity(0.5), .orange.opacity(0.5)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1
                )
        )
        .padding(.top, 60)
    }
    
    private func toggleStep(_ step: ChecklistStep) {
        let wasCompleted = completedSteps.contains(step.id)
        
        withAnimation(.spring(response: 0.3)) {
            if wasCompleted {
                completedSteps.remove(step.id)
            } else {
                completedSteps.insert(step.id)
                let stepXP = GamificationXP.value(for: .checklistStepCompleted)
                earnedXP = stepXP
                withAnimation { showXPToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showXPToast = false }
                }
            }
        }
        
        // Save
        let key = "checklist_\(checklist.id.uuidString)_completed"
        UserDefaults.standard.set(completedSteps.map { $0.uuidString }, forKey: key)
        // Sync active state
        appContainer.userStats.setChecklistActive(id: checklist.id, active: !completedSteps.isEmpty)
        
        // Gamification
        if !wasCompleted {
            EventBus.shared.emit(
                GamEvent(
                    type: .checklistStepCompleted,
                    metadata: [
                        "entityId": step.id.uuidString,
                        "stepId": step.id.uuidString
                    ]
                )
            )
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Step Card

private struct StepCard: View {
    let step: ChecklistStep
    let isCompleted: Bool
    let isExpanded: Bool
    let categoryColor: Color
    var onToggle: () -> Void
    var onExpand: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 14) {
                // Checkbox
                Button(action: onToggle) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isCompleted ? categoryColor : Color.clear)
                            .frame(width: 28, height: 28)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCompleted ? categoryColor : Theme.Colors.chipBorder, lineWidth: 2)
                            .frame(width: 28, height: 28)
                        
                        if isCompleted {
                            if WinterTheme.isActive {
                                Text("❄️")
                                    .font(.system(size: 14))
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .accessibilityLabel(isCompleted ? "Скасувати виконання" : "Виконати крок")
                .accessibilityHint(step.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isCompleted ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                        .strikethrough(isCompleted)
                    
                    HStack(spacing: 10) {
                        if let time = step.estimatedTime {
                            Label(time, systemImage: "clock")
                        }
                        if step.isOptional {
                            Text("Опціонально")
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textTertiary)
                }
                
                Spacer()
                
                // XP indicator
                if !isCompleted {
                    Text("+10")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                }
                
                // Expand button
                if !step.description.isEmpty || !step.links.isEmpty || !step.tips.isEmpty {
                    Button(action: onExpand) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(categoryColor)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
            }
            .padding(14)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if !step.description.isEmpty {
                        Text(step.description)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    
                    if !step.tips.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("💡 Поради")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.textPrimary)
                            
                            ForEach(step.tips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(categoryColor)
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 6)
                                    Text(tip)
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }
                        }
                    }
                    
                    if !step.links.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🔗 Корисні посилання")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.textPrimary)
                            
                            ForEach(step.links) { link in
                                Button {
                                    if let url = URL(string: link.url) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "link")
                                            .font(.system(size: 12))
                                        Text(link.title)
                                            .font(.system(size: 13))
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundColor(categoryColor)
                                    .padding(10)
                                    .background(categoryColor.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCompleted ? Color.green.opacity(0.3) : Theme.Colors.chipBorder, lineWidth: 1)
        )
        .padding(.horizontal, Theme.Spacing.md)
    }
}

// MARK: - Celebration Overlay

private struct CelebrationOverlay: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    // Glow
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(isAnimating ? 1 : 0.1)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isAnimating)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(isAnimating ? 1 : 0.1)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: isAnimating)
                }
                
                VStack(spacing: 8) {
                    Text("🎉 Вітаємо!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Чек-лист завершено!")
                        .font(Theme.Typography.body)
                        .foregroundColor(.white.opacity(0.9))
                    
                    HStack(spacing: 6) {
                        Text("⭐")
                        Text("+100 XP")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onAppear { isAnimating = true }
    }
}

#Preview {
    ChecklistsView()
        .environmentObject(AppContainer())
        .environmentObject(AppLockManager())
}
