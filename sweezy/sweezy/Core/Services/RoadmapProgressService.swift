//
//  RoadmapProgressService.swift
//  sweezy
//
//  Persists completion state and XP rewards for roadmap stages.
//

import Foundation
import Combine

@MainActor
final class RoadmapProgressService: ObservableObject {
    @Published private(set) var completedStageIds: Set<String> = []
    @Published private(set) var totalXPEarned: Int = 0
    
    private let defaults = UserDefaults.standard
    private let completedKey = "roadmap.completedStageIds"
    private let xpKey = "roadmap.totalXPEarned"
    
    init() {
        if let arr = defaults.array(forKey: completedKey) as? [String] {
            completedStageIds = Set(arr)
        }
        totalXPEarned = defaults.integer(forKey: xpKey)
    }
    
    func isCompleted(_ id: String) -> Bool {
        completedStageIds.contains(id)
    }
    
    func markCompleted(id: String, rewardXP: Int = 80) {
        guard !completedStageIds.contains(id) else { return }
        completedStageIds.insert(id)
        totalXPEarned += max(0, rewardXP)
        persist()
    }
    
    func reset() {
        completedStageIds.removeAll()
        totalXPEarned = 0
        persist()
    }
    
    private func persist() {
        defaults.set(Array(completedStageIds), forKey: completedKey)
        defaults.set(totalXPEarned, forKey: xpKey)
    }
}


