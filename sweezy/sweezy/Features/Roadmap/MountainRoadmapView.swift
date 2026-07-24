//
//  MountainRoadmapView.swift
//  sweezy
//
//  Mountain-themed roadmap visualization with 10 levels
//

import SwiftUI

struct MountainRoadmapView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @StateObject private var roadmapService = RoadmapService()
    
    @State private var selectedLevel: RoadmapLevel?
    @State private var showSkipConfirmation = false
    @State private var levelToSkip: RoadmapLevel?
    
    // TEMPORARY (App Store review): IAP removed — roadmap is fully unlocked.
    private var isPremium: Bool { true }
    
    var body: some View {
        ZStack {
            JourneyPhotoBackground(
                imageName: "swiss-moment-grindelwald",
                blurRadius: 1.5,
                darkness: 0.52
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    topBar
                    headerSection
                    progressOverview
                    currentStageCard

                    HStack(alignment: .firstTextBaseline) {
                        Text("roadmap.chrome.full_route".localized)
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text("roadmap.chrome.stage_count".localized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.52))
                    }

                    mountainPath
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 46)
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
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
        .alert("roadmap.chrome.skip_level_title".localized, isPresented: $showSkipConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("roadmap.chrome.skip".localized) {
                if let level = levelToSkip {
                    _ = roadmapService.skipLevel(level.id, isPremium: isPremium)
                }
            }
        } message: {
            Text("roadmap.chrome.skip_level_message".localized)
        }
        .featureOnboarding(.roadmap)
        .onAppear {
            roadmapService.refreshFromStorage()
            NotificationCenter.default.post(name: .setJourneyBottomBarHidden, object: true)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .setJourneyBottomBarHidden, object: false)
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .background(Color.black.opacity(0.2))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("roadmap.chrome.your_plan".localized)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.3)
                .foregroundColor(.white.opacity(0.62))

            Spacer()

            Image(systemName: "mountain.2.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 40, height: 40)
                .background(JourneyVisual.lime)
                .clipShape(Circle())
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("roadmap.chrome.hero_title".localized)
                .font(.system(size: 35, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineSpacing(-3)

            Text("roadmap.chrome.hero_subtitle".localized)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.66))
                .frame(maxWidth: 310, alignment: .leading)
        }
    }

    private var progressOverview: some View {
        JourneyGlassPanel(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("roadmap.chrome.overall_progress".localized)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.5))
                        Text(roadmapService.nextMilestone)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 10)

                    Text("\(Int(roadmapService.overallProgress * 100))%")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundColor(JourneyVisual.lime)
                        .monospacedDigit()
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.14))
                        Capsule()
                            .fill(JourneyVisual.lime)
                            .frame(width: max(geometry.size.width * roadmapService.overallProgress, roadmapService.overallProgress > 0 ? 12 : 0))
                    }
                }
                .frame(height: 7)

                HStack {
                    Label("roadmap.level_of_total_format".localized(with: roadmapService.progress.currentLevel), systemImage: "flag.fill")
                    Spacer()
                    Label((roadmapService.currentLevel?.estimatedDays ?? "").localized, systemImage: "clock")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.58))
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var currentStageCard: some View {
        if let level = roadmapService.currentLevel {
            Button { selectedLevel = level } label: {
                ZStack(alignment: .bottomLeading) {
                    Image("cityhub-zurich-landesmuseum")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 254)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    LinearGradient(
                        colors: [.black.opacity(0.04), .black.opacity(0.16), .black.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("roadmap.chrome.active_stage".localized)
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.9)
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(JourneyVisual.lime)
                                .clipShape(Capsule())

                            Spacer()

                            Text("\(Int(roadmapService.levelProgress(for: level.id) * 100))%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 11)
                                .frame(height: 28)
                                .background(.ultraThinMaterial.opacity(0.82))
                                .clipShape(Capsule())
                        }

                        Spacer()

                        Text("roadmap.chrome.step".localized(with: level.id))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(JourneyVisual.lime)
                            .textCase(.uppercase)

                        Text(level.title.localized)
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 10) {
                            Label("roadmap.tasks_count_format".localized(with: level.tasks.count), systemImage: "checklist")
                            Label(level.estimatedDays.localized, systemImage: "clock")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.68))
                        .padding(.top, 10)
                    }
                    .padding(16)
                }
                .frame(height: 254)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.34), radius: 20, y: 10)
            }
            .buttonStyle(.plain)
        }
    }

    private var mountainPath: some View {
        VStack(spacing: 10) {
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

    private var isLocked: Bool { status == .locked }
    private var isActive: Bool { status == .inProgress }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(nodeFill)
                        .frame(width: 58, height: 64)

                    VStack(spacing: 4) {
                        Image(systemName: nodeIcon)
                            .font(.system(size: 17, weight: .semibold))
                        Text(String(format: "%02d", level.id))
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(nodeForeground)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Text(level.title.localized)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(isLocked ? .white.opacity(0.44) : .white)
                            .lineLimit(1)

                        if isActive {
                            Text("roadmap.chrome.now".localized)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 7)
                                .frame(height: 19)
                                .background(JourneyVisual.lime)
                                .clipShape(Capsule())
                        }
                    }

                    Text(level.subtitle.localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(isLocked ? 0.32 : 0.52))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(statusText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(statusForeground)

                        if !isLocked && status != .completed {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.12))
                                    Capsule()
                                        .fill(JourneyVisual.lime)
                                        .frame(width: max(geometry.size.width * progress, progress > 0 ? 6 : 0))
                                }
                            }
                            .frame(width: 58, height: 4)
                        }
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(isLocked ? 0.24 : 0.58))
            }
            .padding(12)
            .background(.ultraThinMaterial.opacity(isActive ? 0.88 : 0.7))
            .background(Color.black.opacity(isActive ? 0.36 : 0.24))
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(isActive ? JourneyVisual.lime.opacity(0.72) : Color.white.opacity(0.14), lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }

    private var nodeFill: Color {
        switch status {
        case .completed: return JourneyVisual.lime
        case .inProgress: return Color.white
        case .available: return Color.white.opacity(0.12)
        case .locked: return Color.white.opacity(0.06)
        }
    }

    private var nodeForeground: Color {
        status == .completed || status == .inProgress ? .black : .white.opacity(isLocked ? 0.28 : 0.74)
    }

    private var nodeIcon: String {
        switch status {
        case .completed: return "checkmark"
        case .locked: return "lock.fill"
        case .inProgress, .available: return level.iconName
        }
    }

    private var statusText: String {
        switch status {
        case .completed: return "roadmap.chrome.completed".localized
        case .locked: return "roadmap.chrome.opens_later".localized
        case .inProgress: return "\(Int(progress * 100))% · \(level.estimatedDays.localized)"
        case .available: return "roadmap.chrome.can_start".localized(with: level.estimatedDays.localized)
        }
    }

    private var statusForeground: Color {
        status == .completed || isActive ? JourneyVisual.lime : .white.opacity(isLocked ? 0.28 : 0.5)
    }
}

private struct RoadmapAmbientBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                RoadmapBackdropAlps()
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Theme.Colors.primary.opacity(0.14), Theme.Colors.darkSurface.opacity(0.18)]
                                : [Theme.Colors.primary.opacity(0.08), Theme.Colors.accentTurquoise.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 240)
            }

            GeometryReader { geo in
                ForEach(0..<16, id: \.self) { index in
                    Circle()
                        .fill((colorScheme == .dark ? Color.white : Theme.Colors.primary).opacity(colorScheme == .dark ? 0.12 : 0.08))
                        .frame(width: index.isMultiple(of: 3) ? 3 : 2, height: index.isMultiple(of: 3) ? 3 : 2)
                        .position(
                            x: geo.size.width * (0.08 + (Double(index % 8) * 0.11)),
                            y: geo.size.height * (0.08 + (Double(index / 8) * 0.16))
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct RoadmapBackdropAlps: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.76))
        path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.58))
        path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.34))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.66))
        path.addLine(to: CGPoint(x: w * 0.73, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.78))
        path.addLine(to: CGPoint(x: w, y: h * 0.7))
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
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
    @StateObject private var roadmapService = RoadmapService()
    
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
            .background(Color.clear)
            .navigationTitle(level.title.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.close".localized) { dismiss() }
                }
            }
        }
        .journeyScreen(.alpine, darkness: 0.74)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            loadCompletedTasks()
            recalculateAndPersistLevelProgress()
        }
    }
    
    // MARK: - Tasks Section (Main Focus)
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📋 " + "roadmap.chrome.level_tasks".localized)
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
                Text("roadmap.chrome.xp_for_level".localized(with: totalXPForLevel))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Task cards
            ForEach(availableTasks) { task in
                TaskCard(
                    task: task,
                    isCompleted: isTaskCompleted(task),
                    isLocked: false,
                    onTap: {
                        handleTaskTap(task)
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var availableTasks: [LevelTask] {
        // TEMPORARY: no subscription-based filtering.
        level.tasks
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
            return UserDefaults.standard.bool(forKey: AccountScopedStorage.roadmapTaskCompletedKey(for: task.id))
        }
        return completedTaskIds.contains(task.id)
    }
    
    private func handleTaskTap(_ task: LevelTask) {
        dismiss()
        appContainer.telemetry.retention(
            .nextActionTapped,
            source: "roadmap",
            meta: ["task_id": task.id, "task_type": task.type.rawValue, "level": String(level.id)]
        )
        
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
            markActionCompleted(actionId)
        case "save-contacts", "setup-twint", "register-rav", "apply-jobs",
             "compare-insurance", "check-pillar2", "setup-autopay", "learn-investing",
             "download-sbb", "calculate-ga", "apply-kinderzulagen", "find-activities",
             "language-exam", "civics-course", "join-verein", "volunteer", "vote",
             "become-mentor", "share-story", "learn-phrases", "find-tandem":
            markActionCompleted(actionId)
        default:
            break
        }
    }

    private func markActionCompleted(_ actionId: String) {
        guard let task = availableTasks.first(where: { $0.targetId == actionId }) else { return }
        UserDefaults.standard.set(true, forKey: AccountScopedStorage.roadmapTaskCompletedKey(for: task.id))
        completedTaskIds.insert(task.id)
        saveCompletedTasks()
        EventBus.shared.emit(GamEvent(type: .roadmapStageCompleted, metadata: ["entityId": task.id]))
        appContainer.telemetry.retention(
            .roadmapTaskCompleted,
            source: "roadmap",
            meta: ["task_id": task.id, "action_id": actionId, "level": String(level.id)]
        )
        recalculateAndPersistLevelProgress()
    }
    
    private func loadCompletedTasks() {
        // Load from UserDefaults
        let key = AccountScopedStorage.namespaced("roadmap.level.\(level.id).completed_tasks")
        if let saved = UserDefaults.standard.array(forKey: key) as? [String] {
            completedTaskIds = Set(saved)
        }
    }

    private func saveCompletedTasks() {
        let key = AccountScopedStorage.namespaced("roadmap.level.\(level.id).completed_tasks")
        UserDefaults.standard.set(Array(completedTaskIds), forKey: key)
    }

    private func recalculateAndPersistLevelProgress() {
        let completed = Set(availableTasks.filter { isTaskCompleted($0) }.map(\.id))
        completedTaskIds.formUnion(completed)
        saveCompletedTasks()
        let denominator = max(1, availableTasks.count)
        let progress = Double(completedTaskIds.count) / Double(denominator)
        roadmapService.updateProgress(for: level.id, progress: progress)
        NotificationCenter.default.post(name: .roadmapProgressUpdated, object: nil)
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
                    Text("roadmap.chrome.level_n".localized(with: level.id))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // TEMPORARY: no subscription labels.
                }
                
                Text(level.subtitle.localized)
                    .font(.headline)
                
                Text("roadmap.chrome.altitude".localized(with: level.altitude, level.estimatedDays.localized))
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
        let checklists = appContainer.contentService.checklists

        // 1) Exact or partial title slug match
        if let cl = checklists.first(where: { slugify($0.title) == slug || slugify($0.title).contains(slug) }) {
            let key = AccountScopedStorage.checklistCompletedKey(for: cl.id)
            let saved = (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
            return (cl.title, saved.count, cl.steps.count)
        }

        // 2) Match by ChecklistCategory rawValue (e.g. "housing", "insurance", "work")
        //    Prefer the user's locale (Ukrainian) first, then any available checklist
        if let category = ChecklistCategory(rawValue: slug) {
            let currentLang = Locale.current.language.languageCode?.identifier ?? "uk"
            let langTag = "lang:\(currentLang)"
            // Try to find a checklist tagged for current language first
            let candidates = checklists.filter { $0.category == category }
            let cl = candidates.first(where: { $0.tags.contains(langTag) }) ?? candidates.first
            if let cl {
                let key = AccountScopedStorage.checklistCompletedKey(for: cl.id)
                let saved = (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
                return (cl.title, saved.count, cl.steps.count)
            }
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
                Text("roadmap.chrome.progress".localized)
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
            Text("roadmap.chrome.description".localized)
                .font(.headline)
            
            Text(level.description.localized)
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
            Text("💡 " + "roadmap.chrome.tips".localized)
                .font(.headline)
            
            ForEach(level.tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(tip.localized)
                        .font(.subheadline)
                }
            }
            
            // TEMPORARY: show all tips without subscription labeling.
            ForEach(level.premiumTips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(tip.localized)
                        .font(.subheadline)
                }
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
                Button {
                    onSkip()
                    dismiss()
                } label: {
                    Label("roadmap.chrome.skip_level".localized, systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            } else if status == .inProgress {
                Button {
                    dismiss()
                    NotificationCenter.default.post(name: .switchTab, object: 1)
                } label: {
                    Label("roadmap.chrome.go_directory".localized, systemImage: "book.fill")
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
                        Text(task.title.localized)
                            .font(.subheadline.bold())
                            .foregroundColor(isLocked ? .secondary : .primary)
                            .strikethrough(isCompleted, color: .green)
                            .lineLimit(2)
                        
                        // TEMPORARY: no subscription markers.
                    }
                    
                    Text(task.description.localized)
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
