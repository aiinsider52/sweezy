//
//  UserStatsService.swift
//  sweezy
//
//  Tracks per-user local statistics and persists to UserDefaults.
//

import Foundation
import Combine

@MainActor
final class UserStatsService: ObservableObject {
    @Published private(set) var guidesReadCount: Int = 0
    @Published private(set) var activeChecklistsCount: Int = 0
    @Published private(set) var lastUpdated: Date = Date()
    
    private let defaults = UserDefaults.standard
    private var guidesReadIds: Set<String> = []
    private var activeChecklistIds: Set<String> = []
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
    
    func markGuideRead(id: UUID) {
        let key = id.uuidString
        if !guidesReadIds.contains(key) {
            guidesReadIds.insert(key)
            persist()
            // Gamification event
            EventBus.shared.emit(GamEvent(type: .guideReadCompleted, metadata: ["entityId": key]))
        }
    }
    
    func isGuideRead(id: UUID) -> Bool {
        guidesReadIds.contains(id.uuidString)
    }
    
    func setChecklistActive(id: UUID, active: Bool) {
        let key = id.uuidString
        if active {
            if !activeChecklistIds.contains(key) {
                activeChecklistIds.insert(key)
                persist()
            }
        } else {
            if activeChecklistIds.contains(key) {
                activeChecklistIds.remove(key)
                persist()
            }
        }
    }
    
    func reset() {
        guidesReadIds.removeAll()
        activeChecklistIds.removeAll()
        persist()
    }
    
    private func persist() {
        defaults.set(Array(guidesReadIds), forKey: AccountScopedStorage.statsGuidesReadIdsKey)
        defaults.set(Array(activeChecklistIds), forKey: AccountScopedStorage.statsActiveChecklistIdsKey)
        recalc()
    }

    private func loadFromCurrentScope() {
        if let arr = defaults.array(forKey: AccountScopedStorage.statsGuidesReadIdsKey) as? [String] {
            guidesReadIds = Set(arr)
        } else {
            guidesReadIds = []
        }
        if let arr = defaults.array(forKey: AccountScopedStorage.statsActiveChecklistIdsKey) as? [String] {
            activeChecklistIds = Set(arr)
        } else {
            activeChecklistIds = []
        }
        recalc()
    }
    
    private func recalc() {
        guidesReadCount = guidesReadIds.count
        activeChecklistsCount = activeChecklistIds.count
        lastUpdated = Date()
    }
    
    // MARK: - Exposed read-only accessors
    /// Return a copy of all read guide IDs for lightweight analytics/sync.
    /// Kept as a method (not a published property) to avoid heavy UI updates.
    func allReadGuideIds() -> Set<String> {
        guidesReadIds
    }
}


