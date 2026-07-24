//
//  RoadmapService.swift
//  sweezy
//
//  Manages roadmap progress and persistence
//

import SwiftUI
import Combine

@MainActor
class RoadmapService: ObservableObject {
    @Published var progress: RoadmapProgress
    @Published var levels: [RoadmapLevel] = RoadmapLevel.allLevels
    
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    private var storageKey: String { AccountScopedStorage.roadmapProgressKey }
    
    init() {
        // Load saved progress or create new
        let initialStorageKey = AccountScopedStorage.roadmapProgressKey
        if let data = defaults.data(forKey: initialStorageKey),
           let saved = try? JSONDecoder().decode(RoadmapProgress.self, from: data) {
            self.progress = saved
        } else {
            self.progress = .empty
        }
        
        NotificationCenter.default.publisher(for: .accountScopeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadForCurrentScope()
            }
            .store(in: &cancellables)
    }
    
    /// Reloads progress from persistent storage if it changed externally.
    func refreshFromStorage() {
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(RoadmapProgress.self, from: data) else { return }
        // Update only if different to avoid unnecessary UI work
        if saved.currentLevel != progress.currentLevel
            || saved.levelProgress != progress.levelProgress
            || saved.completedLevels != progress.completedLevels
            || saved.skippedLevels != progress.skippedLevels {
            progress = saved
        }
    }
    
    // MARK: - Public API
    
    func status(for level: RoadmapLevel, isPremium: Bool) -> LevelStatus {
        progress.status(for: level.id, isPremium: isPremium)
    }
    
    func levelProgress(for levelId: Int) -> Double {
        progress.progress(for: levelId)
    }
    
    func updateProgress(for levelId: Int, progress newProgress: Double) {
        progress.levelProgress[levelId] = min(1.0, max(0.0, newProgress))
        
        // Check if level completed
        if newProgress >= 1.0 && !progress.completedLevels.contains(levelId) {
            completeLevel(levelId)
        }
        
        save()
    }
    
    func completeLevel(_ levelId: Int) {
        progress.completedLevels.insert(levelId)
        progress.completedAt[levelId] = Date()
        
        // Unlock next level
        if levelId < levels.count {
            progress.currentLevel = max(progress.currentLevel, levelId + 1)
            progress.unlockedAt[levelId + 1] = Date()
            progress.levelProgress[levelId + 1] = 0.0
        }
        
        save()
    }
    
    func skipLevel(_ levelId: Int, isPremium: Bool) -> Bool {
        guard isPremium else { return false }
        guard levelId <= progress.currentLevel + 2 else { return false }
        
        progress.skippedLevels.insert(levelId)
        progress.completedAt[levelId] = Date()
        
        // Unlock next level
        if levelId < levels.count {
            progress.currentLevel = max(progress.currentLevel, levelId + 1)
            progress.unlockedAt[levelId + 1] = Date()
        }
        
        save()
        return true
    }
    
    func unlockLevel(_ levelId: Int) {
        guard levelId <= levels.count else { return }
        progress.unlockedAt[levelId] = Date()
        if progress.levelProgress[levelId] == nil {
            progress.levelProgress[levelId] = 0.0
        }
        save()
    }

    func seedFromOnboardingProfile(_ profile: UserProfile, firstWeekProgress: Double) -> Int {
        guard !defaults.bool(forKey: AccountScopedStorage.roadmapOnboardingSeededKey) else {
            return progress.currentLevel
        }

        let focusLevel = recommendedStartingLevel(for: profile)
        let hasMeaningfulProgress = !progress.completedLevels.isEmpty || overallProgress > 0.05

        if !hasMeaningfulProgress, focusLevel > 1 {
            for levelId in 1..<focusLevel {
                progress.completedLevels.insert(levelId)
                progress.completedAt[levelId] = Date()
                progress.levelProgress[levelId] = 1.0
            }
            progress.currentLevel = focusLevel
            progress.unlockedAt[focusLevel] = Date()
            progress.levelProgress[focusLevel] = max(progress.levelProgress[focusLevel] ?? 0, 0)
        } else {
            let onboardingProgress = min(0.35, max(0, firstWeekProgress) * 0.35)
            progress.levelProgress[1] = max(progress.levelProgress[1] ?? 0, onboardingProgress)
        }

        defaults.set(true, forKey: AccountScopedStorage.roadmapOnboardingSeededKey)
        save()
        NotificationCenter.default.post(name: .roadmapProgressUpdated, object: nil)
        return progress.currentLevel
    }
    
    func resetProgress() {
        progress = .empty
        save()
    }
    
    // MARK: - Computed Properties
    
    var currentLevel: RoadmapLevel? {
        levels.first { $0.id == progress.currentLevel }
    }
    
    var completedLevelsCount: Int {
        progress.completedLevels.count + progress.skippedLevels.count
    }
    
    var overallProgress: Double {
        let total = Double(levels.count)
        let completed = Double(completedLevelsCount)
        let currentProgress = progress.progress(for: progress.currentLevel)
        return (completed + currentProgress) / total
    }
    
    var nextMilestone: String {
        guard let current = currentLevel else { return "" }
        let currentProgress = levelProgress(for: current.id)
        let remaining = Int((1.0 - currentProgress) * 100)
        return "roadmap.percent_to_complete".localized(with: remaining, current.title.localized)
    }
    
    // MARK: - Task Progress Calculation
    
    /// Calculate level progress based on completed tasks
    func calculateTaskProgress(for level: RoadmapLevel, completedTaskIds: Set<String>, isPremium: Bool) -> Double {
        let availableTasks = isPremium ? level.tasks : level.tasks.filter { !$0.isPremiumOnly }
        guard !availableTasks.isEmpty else { return 0.0 }
        
        let completedCount = availableTasks.filter { completedTaskIds.contains($0.id) }.count
        return Double(completedCount) / Double(availableTasks.count)
    }
    
    /// Get total XP available for a level
    func totalXP(for level: RoadmapLevel, isPremium: Bool) -> Int {
        let tasks = isPremium ? level.tasks : level.tasks.filter { !$0.isPremiumOnly }
        return tasks.reduce(0) { $0 + $1.effectiveXPReward }
    }
    
    /// Get next uncompleted task for a level
    func nextTask(for level: RoadmapLevel, completedTaskIds: Set<String>, isPremium: Bool) -> LevelTask? {
        let availableTasks = isPremium ? level.tasks : level.tasks.filter { !$0.isPremiumOnly }
        return availableTasks.first { !completedTaskIds.contains($0.id) }
    }
    
    // MARK: - Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func recommendedStartingLevel(for profile: UserProfile) -> Int {
        var level = 1

        if let arrivalDate = profile.arrivalDate {
            let days = Calendar.current.dateComponents([.day], from: arrivalDate, to: Date()).day ?? 0
            switch days {
            case 120...:
                level = max(level, 4)
            case 45...:
                level = max(level, 3)
            case 14...:
                level = max(level, 2)
            default:
                break
            }
        }

        if profile.hasChildren {
            level = max(level, 3)
        }
        if profile.goals.contains(.work) {
            level = max(level, 4)
        }

        // Settled residents (1+ year) start near the top of the base roadmap so
        // that the settled branch (taxes/career/family/permit) becomes primary.
        if profile.isSettledResident {
            level = max(level, max(1, levels.count - 1))
        }

        return min(level, levels.count)
    }

    /// Branch hint used by Home / Roadmap UI to choose between the "newcomer" base
    /// flow and the "settled" branch focused on recurring Swiss moments.
    enum Branch: String { case newcomer, settled }

    func activeBranch(for profile: UserProfile?) -> Branch {
        guard let profile else { return .newcomer }
        if profile.isSettledResident { return .settled }
        if !profile.lifeEvents.isEmpty { return .settled }
        if profile.permitType == .c { return .settled }
        return .newcomer
    }

    private func reloadForCurrentScope() {
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(RoadmapProgress.self, from: data) {
            progress = saved
        } else {
            progress = .empty
        }
    }
    
    // MARK: - Integration with Checklists
    
    func syncWithChecklists(completedChecklistIds: Set<String>) {
        for level in levels {
            guard !level.relatedChecklistIds.isEmpty else { continue }
            
            let completedCount = level.relatedChecklistIds.filter { completedChecklistIds.contains($0) }.count
            let total = level.relatedChecklistIds.count
            let newProgress = Double(completedCount) / Double(total)
            
            if newProgress > levelProgress(for: level.id) {
                updateProgress(for: level.id, progress: newProgress)
            }
        }
    }
    
    func syncWithGuides(readGuideCategories: [String: Int], totalByCategory: [String: Int]) {
        for level in levels {
            guard !level.relatedGuideCategories.isEmpty else { continue }
            
            var totalRead = 0
            var totalAvailable = 0
            
            for category in level.relatedGuideCategories {
                totalRead += readGuideCategories[category] ?? 0
                totalAvailable += totalByCategory[category] ?? 1
            }
            
            guard totalAvailable > 0 else { continue }
            
            let guideProgress = Double(totalRead) / Double(totalAvailable)
            let currentProgress = levelProgress(for: level.id)
            
            // Guides contribute 30% to level progress
            let combinedProgress = currentProgress * 0.7 + guideProgress * 0.3
            
            if combinedProgress > currentProgress {
                updateProgress(for: level.id, progress: combinedProgress)
            }
        }
    }
}

