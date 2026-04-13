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
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadFromCurrentScope()
        NotificationCenter.default.publisher(for: .accountScopeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadFromCurrentScope()
            }
            .store(in: &cancellables)
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
        defaults.set(Array(completedStageIds), forKey: AccountScopedStorage.roadmapCompletedStageIdsKey)
        defaults.set(totalXPEarned, forKey: AccountScopedStorage.roadmapTotalXPKey)
    }

    private func loadFromCurrentScope() {
        if let arr = defaults.array(forKey: AccountScopedStorage.roadmapCompletedStageIdsKey) as? [String] {
            completedStageIds = Set(arr)
        } else {
            completedStageIds = []
        }
        totalXPEarned = defaults.integer(forKey: AccountScopedStorage.roadmapTotalXPKey)
    }
}


