//
//  RoadmapSyncService.swift
//  sweezy
//
//  Keeps Roadmap progress in sync with user activity (guides, checklists),
//  persists updates to UserDefaults and broadcasts lightweight notifications
//  so UI can refresh without heavy bindings.
//

import Foundation
import Combine
import SwiftUI

extension Notification.Name {
    static let roadmapProgressUpdated = Notification.Name("roadmap.progress.updated")
}

@MainActor
final class RoadmapSyncService: ObservableObject {
    private unowned let app: AppContainer
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // Persist a small set of completed checklist slugs
    private let completedChecklistSlugsKey = "roadmap.completedChecklistSlugs"
    private var completedChecklistSlugs: Set<String> {
        get { Set(defaults.array(forKey: completedChecklistSlugsKey) as? [String] ?? []) }
        set { defaults.set(Array(newValue), forKey: completedChecklistSlugsKey) }
    }
    
    init(app: AppContainer) {
        self.app = app
        setupBindings()
        
        // Initial sync on launch (after content loads lazily)
        // Delay a bit to avoid doing work during first frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            Task { @MainActor in
                await self?.recalculateProgress()
            }
        }
    }
    
    private func setupBindings() {
        // React to gamification events
        EventBus.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event.type {
                case .guideReadCompleted:
                    // Lightweight: just recalc from current stats
                    self.scheduleRecalc()
                case .checklistCompleted:
                    // Support both "entityId" and "checklistId" metadata
                    if let raw = event.metadata["entityId"] ?? event.metadata["checklistId"] {
                        // If UUID provided → try to resolve to known roadmap slug
                        if let uuid = UUID(uuidString: raw),
                           let checklist = self.app.contentService.getChecklist(by: uuid),
                           let slug = self.inferRoadmapSlug(for: checklist) {
                            var set = self.completedChecklistSlugs
                            set.insert(slug)
                            self.completedChecklistSlugs = set
                        } else {
                            // Fallback: treat input as slug/alias
                            let mapped = self.mapChecklistIdentifier(raw)
                            if !mapped.isEmpty {
                                var set = self.completedChecklistSlugs
                                set.insert(mapped)
                                self.completedChecklistSlugs = set
                            }
                        }
                    }
                    self.scheduleRecalc()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // React to UserStats changes (debounced)
        app.userStats.$lastUpdated
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleRecalc()
            }
            .store(in: &cancellables)
    }
    
    private var pendingWork: DispatchWorkItem?
    private func scheduleRecalc() {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.recalculateProgress()
            }
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
    
    private func mapChecklistIdentifier(_ id: String) -> String {
        // Normalize known identifiers to roadmap slugs
        switch id {
        case "first_week", "first-week", "first7days", "first-7-days":
            return "first-7-days"
        default:
            return id
        }
    }
    
    private func slugify(_ text: String) -> String {
        let lower = text.lowercased()
        let allowed = lower.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let joined = String(allowed)
        // Collapse multiples of '-'
        let collapsed = joined.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    /// Try to infer a roadmap slug for a given checklist
    private func inferRoadmapSlug(for checklist: Checklist) -> String? {
        let s = slugify(checklist.title)
        // Heuristics for known slugs
        if s.contains("first-7") || s.contains("first7") || s.contains("перш") || s.contains("первые-7") {
            return "first-7-days"
        }
        return nil
    }
    
    private func buildGuideCategoryStats() -> (readByCategory: [String: Int], totalsByCategory: [String: Int]) {
        var readByCategory: [String: Int] = [:]
        var totalsByCategory: [String: Int] = [:]
        
        // Totals by category from content
        for guide in app.contentService.guides {
            let key = guide.category.rawValue
            totalsByCategory[key, default: 0] += 1
        }
        
        // Read ids from stats → categories
        let readIds = app.userStats.allReadGuideIds()
        for idString in readIds {
            if let uuid = UUID(uuidString: idString),
               let guide = app.contentService.getGuide(by: uuid) {
                let key = guide.category.rawValue
                readByCategory[key, default: 0] += 1
            }
        }
        return (readByCategory, totalsByCategory)
    }
    
    private func buildCompletedChecklistSlugs() -> Set<String> {
        var set = completedChecklistSlugs
        // Also derive first week checklist completion if all tasks done
        if app.firstWeekService.progress >= 0.999 {
            set.insert("first-7-days")
        }
        // Scan stored checklist progress from UserDefaults and infer slugs
        for cl in app.contentService.checklists {
            let key = "checklist_\(cl.id.uuidString)_completed"
            let saved = (defaults.array(forKey: key) as? [String]) ?? []
            if !cl.steps.isEmpty && saved.count >= cl.steps.count {
                if let slug = inferRoadmapSlug(for: cl) {
                    set.insert(slug)
                }
            }
        }
        return set
    }
    
    private func broadcastUpdate() {
        NotificationCenter.default.post(name: .roadmapProgressUpdated, object: nil)
    }
    
    // MARK: - Recalc
    private func recalculateProgress() async {
        // Use the same persistence as the UI service by simply reusing it
        let service = RoadmapService()
        
        // From guides
        let (readByCategory, totalsByCategory) = buildGuideCategoryStats()
        service.syncWithGuides(readGuideCategories: readByCategory, totalByCategory: totalsByCategory)
        
        // From checklists
        let completedSlugs = buildCompletedChecklistSlugs()
        service.syncWithChecklists(completedChecklistIds: completedSlugs)
        
        // Notify UI to refresh its local in-memory copy
        broadcastUpdate()
    }
}


