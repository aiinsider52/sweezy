//
//  MountainRoadmapView.swift
//  sweezy
//
//  Mountain-themed roadmap visualization with 10 levels
//

import SwiftUI

struct MountainRoadmapView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @StateObject private var roadmapService = RoadmapService()
    
    @State private var selectedLevel: RoadmapLevel?
    @State private var showSkipConfirmation = false
    @State private var levelToSkip: RoadmapLevel?
    
    private var isPremium: Bool {
        appContainer.subscriptionManager.isPremium
    }
    
    var body: some View {
        ZStack {
            // Background gradient (sky)
            MountainTheme.skyGradient
                .ignoresSafeArea()
            
            // Stars (subtle)
            StarsOverlay()
            
            // Winter snowfall with enhanced effects
            if WinterTheme.isActive {
                WinterSceneLite(intensity: .medium)
            }
            
            // Main content
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        headerSection
                        
                        // Mountain path with levels
                        mountainPath
                            .padding(.top, 20)
                        
                        // Bottom padding
                        Spacer(minLength: 100)
                    }
                }
                .onAppear {
                    // Scroll to current level
                    withAnimation(.easeOut(duration: 0.5)) {
                        proxy.scrollTo(roadmapService.progress.currentLevel, anchor: .center)
                    }
                }
            }
        }
        .sheet(item: $selectedLevel) { level in
            LevelDetailSheet(
                level: level,
                status: roadmapService.status(for: level, isPremium: isPremium),
                progress: roadmapService.levelProgress(for: level.id),
                isPremium: isPremium,
                onSkip: {
                    levelToSkip = level
                    showSkipConfirmation = true
                }
            )
            .environmentObject(appContainer)
        }
        // Refresh when background sync updates persisted progress
        .onReceive(NotificationCenter.default.publisher(for: .roadmapProgressUpdated)) { _ in
            roadmapService.refreshFromStorage()
        }
        .alert("Пропустити рівень?", isPresented: $showSkipConfirmation) {
            Button("Скасувати", role: .cancel) {}
            Button("Пропустити") {
                if let level = levelToSkip {
                    _ = roadmapService.skipLevel(level.id, isPremium: isPremium)
                }
            }
        } message: {
            Text("Ви впевнені? Ви зможете повернутися до цього рівня пізніше.")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Title
            Text("Шлях інтеграції")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            
            // Overall progress
            VStack(spacing: 8) {
                HStack {
                    Text("Загальний прогрес")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("\(Int(roadmapService.overallProgress * 100))%")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * roadmapService.overallProgress)
                    }
                }
                .frame(height: 8)
                
                // Current milestone
                Text(roadmapService.nextMilestone)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            
            // Altitude indicator
            HStack {
                Image(systemName: "mountain.2.fill")
                    .foregroundColor(.white.opacity(0.6))
                Text("Висота: \(roadmapService.currentLevel?.altitude ?? 0) м")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                if isPremium {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Premium")
                            .font(.caption.bold())
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    // MARK: - Mountain Path
    
    private var mountainPath: some View {
        VStack(spacing: 0) {
            ForEach(roadmapService.levels) { level in
                LevelNode(
                    level: level,
                    status: roadmapService.status(for: level, isPremium: isPremium),
                    progress: roadmapService.levelProgress(for: level.id),
                    isPremium: isPremium,
                    isFirst: level.id == 1
                ) {
                    selectedLevel = level
                }
                .id(level.id)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Level Node

struct LevelNode: View {
    let level: RoadmapLevel
    let status: LevelStatus
    let progress: Double
    let isPremium: Bool
    let isFirst: Bool
    let onTap: () -> Void
    
    @State private var isAnimating = false
    
    private var isLocked: Bool { status == .locked }
    private var isActive: Bool { status == .inProgress }
    
    var body: some View {
        VStack(spacing: 0) {
            // Connection line to next level (above)
            if !isFirst {
                PathLine(isCompleted: status == .completed)
            }
            
            // Level card
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Level icon with progress ring
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(isLocked ? MountainTheme.lockedColor : levelBackgroundColor)
                            .frame(width: 70, height: 70)
                        
                        // Progress ring
                        if !isLocked && status != .completed {
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    MountainTheme.glowColor,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 70, height: 70)
                                .rotationEffect(.degrees(-90))
                        }
                        
                        // Completed checkmark or icon
                        if status == .completed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.green)
                        } else if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.5))
                        } else {
                            Image(systemName: level.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        
                        // Level number badge
                        Text("\(level.id)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(status.color))
                            .offset(x: 25, y: -25)
                        
                        // Premium badge
                        if level.isPremiumOnly {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                                .padding(4)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                                .offset(x: -25, y: -25)
                        }
                    }
                    .scaleEffect(isActive && isAnimating ? 1.05 : 1.0)
                    .shadow(color: isActive ? MountainTheme.glowColor.opacity(0.5) : .clear, radius: 10)
                    
                    // Level info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(level.title)
                            .font(.headline)
                            .foregroundColor(isLocked ? .white.opacity(0.5) : .white)
                        
                        Text(level.subtitle)
                            .font(.subheadline)
                            .foregroundColor(isLocked ? .white.opacity(0.3) : .white.opacity(0.7))
                        
                        // Progress or status
                        HStack(spacing: 8) {
                            if status == .completed {
                                Label("Завершено", systemImage: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else if isLocked {
                                Label("Заблоковано", systemImage: "lock")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Text("\(Int(progress * 100))%")
                                    .font(.caption.bold())
                                    .foregroundColor(MountainTheme.glowColor)
                                
                                Text("• \(level.estimatedDays)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Arrow
                    Image(systemName: "chevron.right")
                        .foregroundColor(isLocked ? .white.opacity(0.3) : .white.opacity(0.6))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isLocked ? Color.white.opacity(0.05) : Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isActive ? MountainTheme.glowColor.opacity(0.5) : Color.white.opacity(0.1),
                                    lineWidth: isActive ? 2 : 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isLocked && !isPremium)
        }
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
    
    private var levelBackgroundColor: Color {
        MountainTheme.altitudeColor(for: level.altitude).opacity(0.3)
    }
}

// MARK: - Path Line

struct PathLine: View {
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            // Dashed line
            Path { path in
                path.move(to: CGPoint(x: 51, y: 0))
                path.addLine(to: CGPoint(x: 51, y: 40))
            }
            .stroke(
                isCompleted ? Color.green : Color.white.opacity(0.3),
                style: StrokeStyle(lineWidth: 2, dash: [5, 5])
            )
        }
        .frame(height: 40)
    }
}

// MARK: - Stars Overlay

struct StarsOverlay: View {
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<30, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height * 0.4)
                    )
            }
        }
    }
}

// MARK: - Next Action Row

struct NextActionRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    var isDone: Bool = false
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        if isDone {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Level Detail Sheet

struct LevelDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    
    let level: RoadmapLevel
    let status: LevelStatus
    let progress: Double
    let isPremium: Bool
    let onSkip: () -> Void
    
    // Track completed tasks locally
    @State private var completedTaskIds: Set<String> = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Progress
                    if status != .locked {
                        progressSection
                    }
                    
                    // Tasks - main actionable section
                    tasksSection
                    
                    // Description
                    descriptionSection
                    
                    // Tips
                    tipsSection
                    
                    // Actions
                    actionsSection
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(level.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрити") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            loadCompletedTasks()
        }
    }
    
    // MARK: - Tasks Section (Main Focus)
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📋 Завдання рівня")
                    .font(.headline)
                Spacer()
                Text("\(completedTasksCount)/\(availableTasks.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // XP reward summary (derived from GamificationXP via LevelTask.effectiveXPReward)
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                Text("До \(totalXPForLevel) XP за рівень")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Task cards
            ForEach(availableTasks) { task in
                TaskCard(
                    task: task,
                    isCompleted: isTaskCompleted(task),
                    isLocked: task.isPremiumOnly && !isPremium,
                    onTap: {
                        handleTaskTap(task)
                    }
                )
            }
            
            // Premium tasks teaser
            if !isPremium {
                let premiumTasks = level.tasks.filter { $0.isPremiumOnly }
                if !premiumTasks.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("\(premiumTasks.count) додаткових завдань для Premium")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("+\(premiumTasks.reduce(0) { $0 + $1.effectiveXPReward }) XP")
                            .font(.caption.bold())
                            .foregroundColor(.yellow)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var availableTasks: [LevelTask] {
        if isPremium {
            return level.tasks
        } else {
            return level.tasks.filter { !$0.isPremiumOnly }
        }
    }
    
    private var completedTasksCount: Int {
        availableTasks.filter { isTaskCompleted($0) }.count
    }
    
    private var totalXPForLevel: Int {
        availableTasks.reduce(0) { $0 + $1.effectiveXPReward }
    }
    
    private func isTaskCompleted(_ task: LevelTask) -> Bool {
        // Check based on task type
        switch task.type {
        case .checklist:
            if let slug = task.targetId {
                let info = checklistInfo(for: slug)
                return info.total > 0 && info.completed >= info.total
            }
        case .guideCategory:
            if let cat = task.targetId {
                let info = guideCategoryInfo(for: cat)
                return info.read > 0
            }
        case .guide:
            if let guideId = task.targetId {
                return appContainer.userStats.allReadGuideIds().contains(guideId)
            }
        case .action:
            // Check UserDefaults for action completion
            return UserDefaults.standard.bool(forKey: "task_\(task.id)_completed")
        }
        return completedTaskIds.contains(task.id)
    }
    
    private func handleTaskTap(_ task: LevelTask) {
        dismiss()
        
        // Small delay to let sheet dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch task.type {
            case .checklist:
                NotificationCenter.default.post(name: .switchTab, object: 1) // Dovídnik (Checklists tab)
            case .guideCategory, .guide:
                NotificationCenter.default.post(name: .switchTab, object: 1) // Dovídnik (Guides tab)
            case .action:
                // Handle specific actions
                handleAction(task.targetId ?? "")
            }
        }
    }
    
    private func handleAction(_ actionId: String) {
        switch actionId {
        case "map-gemeinde":
            NotificationCenter.default.post(name: .switchTab, object: 2) // Map
        case "save-contacts", "setup-twint", "register-rav", "apply-jobs",
             "compare-insurance", "check-pillar2", "setup-autopay", "learn-investing",
             "download-sbb", "calculate-ga", "apply-kinderzulagen", "find-activities",
             "language-exam", "civics-course", "join-verein", "volunteer", "vote",
             "become-mentor", "share-story", "learn-phrases", "find-tandem":
            // Mark as completed in UserDefaults (user-triggered actions)
            // These are "soft" tasks that user marks as done
            break
        default:
            break
        }
    }
    
    private func loadCompletedTasks() {
        // Load from UserDefaults
        let key = "level_\(level.id)_completed_tasks"
        if let saved = UserDefaults.standard.array(forKey: key) as? [String] {
            completedTaskIds = Set(saved)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: level.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(status.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Рівень \(level.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if level.isPremiumOnly {
                        Label("Premium", systemImage: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(level.subtitle)
                    .font(.headline)
                
                Text("Висота: \(level.altitude) м • \(level.estimatedDays)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helpers
    private func slugify(_ text: String) -> String {
        let lower = text.lowercased()
        let allowed = lower.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let joined = String(allowed)
        let collapsed = joined.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    private func checklistInfo(for slug: String) -> (title: String, completed: Int, total: Int) {
        if let cl = appContainer.contentService.checklists.first(where: { slugify($0.title) == slug || slugify($0.title).contains(slug) }) {
            let key = "checklist_\(cl.id.uuidString)_completed"
            let saved = (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
            return (cl.title, saved.count, cl.steps.count)
        }
        return (slug, 0, 0)
    }
    
    private func guideCategoryInfo(for raw: String) -> (localizedName: String, read: Int, total: Int) {
        let cat = GuideCategory(rawValue: raw) ?? .documents
        let total = appContainer.contentService.guides.filter { $0.category == cat }.count
        let read = appContainer.contentService.guides.filter { guide in
            guide.category == cat && appContainer.userStats.allReadGuideIds().contains(guide.id.uuidString)
        }.count
        return (cat.localizedName, read, total)
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Прогрес")
                    .font(.headline)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundColor(status.color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(status.color)
                        .frame(width: max(0, geo.size.width * progress))
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Опис")
                .font(.headline)
            
            Text(level.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💡 Поради")
                .font(.headline)
            
            ForEach(level.tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(tip)
                        .font(.subheadline)
                }
            }
            
            // Premium tips
            if isPremium && !level.premiumTips.isEmpty {
                Divider()
                
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Premium поради")
                        .font(.subheadline.bold())
                        .foregroundColor(.yellow)
                }
                
                ForEach(level.premiumTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(tip)
                            .font(.subheadline)
                    }
                }
            } else if !isPremium && !level.premiumTips.isEmpty {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                    Text("\(level.premiumTips.count) додаткових порад для Premium")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if status == .locked {
                if isPremium {
                    Button {
                        onSkip()
                        dismiss()
                    } label: {
                        Label("Пропустити рівень", systemImage: "forward.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("Завершіть попередній рівень на 80%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            } else if status == .inProgress {
                Button {
                    dismiss()
                    NotificationCenter.default.post(name: .switchTab, object: 1)
                } label: {
                    Label("Перейти до довідника", systemImage: "book.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Task Card
struct TaskCard: View {
    let task: LevelTask
    let isCompleted: Bool
    let isLocked: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            if !isLocked {
                onTap()
            }
        }) {
            HStack(spacing: 12) {
                // Status indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(backgroundColor)
                        .frame(width: 44, height: 44)
                    
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    } else if isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                    } else {
                        Image(systemName: task.iconName)
                            .foregroundColor(iconColor)
                    }
                }
                
                // Task info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.title)
                            .font(.subheadline.bold())
                            .foregroundColor(isLocked ? .secondary : .primary)
                            .strikethrough(isCompleted, color: .green)
                            .lineLimit(2)
                        
                        if task.isPremiumOnly {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                                .font(.caption2)
                        }
                    }
                    
                    Text(task.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // XP reward (uses LevelTask.effectiveXPReward so it matches global GamificationXP)
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 2) {
                        Text("+\(task.effectiveXPReward)")
                            .font(.caption.bold())
                            .foregroundColor(isCompleted ? .green : .orange)
                        Text("XP")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if !isLocked && !isCompleted {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isCompleted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.6 : 1)
    }
    
    private var backgroundColor: Color {
        if isCompleted {
            return Color.green.opacity(0.15)
        } else if isLocked {
            return Color(.systemGray5)
        } else {
            return taskTypeColor.opacity(0.15)
        }
    }
    
    private var iconColor: Color {
        taskTypeColor
    }
    
    private var taskTypeColor: Color {
        switch task.type {
        case .checklist: return .green
        case .guideCategory, .guide: return .blue
        case .action: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    MountainRoadmapView()
        .environmentObject(AppContainer())
}

