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
    private let guidesKey = "stats.guidesReadIds"
    private let activeChecklistsKey = "stats.activeChecklistIds"
    
    private var guidesReadIds: Set<String> = []
    private var activeChecklistIds: Set<String> = []
    
    init() {
        if let arr = defaults.array(forKey: guidesKey) as? [String] {
            guidesReadIds = Set(arr)
        }
        if let arr = defaults.array(forKey: activeChecklistsKey) as? [String] {
            activeChecklistIds = Set(arr)
        }
        recalc()
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
        defaults.set(Array(guidesReadIds), forKey: guidesKey)
        defaults.set(Array(activeChecklistIds), forKey: activeChecklistsKey)
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


