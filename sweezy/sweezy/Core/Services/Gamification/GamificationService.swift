//
//  GamificationService.swift
//  sweezy
//
//  Lightweight XP tracking with idempotent event handling.
//

import Foundation
import Combine

// Central table of XP rewards for each gamification event type.
// UI should use this to display "+XP" so it always matches actual totals.
enum GamificationXP {
    static func value(for type: GamEventType) -> Int {
        switch type {
        case .appDailyOpen:
            // XP handled separately via streak, not numeric reward.
            return 0
        case .guideOpened:
            return 1
        case .guideReadCompleted:
            return 10
        case .checklistStepCompleted:
            return 10
        case .checklistCompleted:
            return 100
        case .roadmapStageCompleted:
            return 15
        case .notificationEnabled:
            return 3
        }
    }
}

@MainActor
final class GamificationService: ObservableObject {
    // MARK: - Published state
    @Published private(set) var totalXP: Int
    @Published private(set) var lastAwardedXP: Int
    @Published private(set) var badges: [String] = []
    @Published private(set) var streakDays: Int
    
    // MARK: - Private state
    private var todayXP: Int
    private var todayKey: String
    private var seenKeys: Set<String>
    private var lastStreakDate: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Storage keys
    private let kTotalXP = "gam.total_xp"
    private let kTodayKey = "gam.today_key"
    private let kTodayXP = "gam.today_xp"
    private let kSeenKeys = "gam.seen_keys"
    private let kStreakDays = "gam.streak_days"
    private let kStreakLastDate = "gam.streak_last_date"
    
    // MARK: - Init
    convenience init() {
        self.init(bus: EventBus.shared)
    }
    
    init(bus: EventBus) {
        // Restore persisted state
        let defaults = UserDefaults.standard
        self.totalXP = defaults.integer(forKey: kTotalXP)
        self.lastAwardedXP = 0
        self.streakDays = defaults.integer(forKey: kStreakDays)
        self.todayKey = GamificationService.makeDayKey(Date())
        if let savedTodayKey = defaults.string(forKey: kTodayKey), savedTodayKey == todayKey {
            self.todayXP = defaults.integer(forKey: kTodayXP)
        } else {
            self.todayXP = 0
            defaults.set(todayKey, forKey: kTodayKey)
            defaults.set(0, forKey: kTodayXP)
        }
        if let data = defaults.data(forKey: kSeenKeys),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.seenKeys = decoded
        } else {
            self.seenKeys = []
        }
        if let last = defaults.object(forKey: kStreakLastDate) as? Date {
            self.lastStreakDate = last
        } else {
            self.lastStreakDate = nil
        }
        
        // Subscribe to events
        bus.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.handle(event)
                }
            }
            .store(in: &cancellables)
        
        // Seed badges from current state
        recalcBadges()
    }
    
    // MARK: - Public API
    func xpGainedToday() -> Int { todayXP }
    func currentStreak() -> Int { streakDays }
    
    func level() -> Int {
        switch totalXP {
        case 0..<100: return 1
        case 100..<300: return 2
        case 300..<600: return 3
        case 600..<1000: return 4
        case 1000..<1500: return 5
        case 1500..<2200: return 6
        case 2200..<3000: return 7
        default: return 8
        }
    }
    
    func xpForNextLevel() -> Int {
        switch level() {
        case 1: return 100
        case 2: return 300
        case 3: return 600
        case 4: return 1000
        case 5: return 1500
        case 6: return 2200
        case 7: return 3000
        default: return 4000
        }
    }
    
    // MARK: - Internal
    private func handle(_ event: GamEvent) {
        // Update login streak for daily app opens (doesn't depend on XP)
        if event.type == .appDailyOpen {
            updateStreak(for: event.timestamp)
        }
        
        // Rotate "today" if needed
        rotateTodayIfNeeded()
        
        // Idempotency check
        if seenKeys.contains(event.idempotencyKey) {
            return
        }
        
        let award = awardFor(event.type, metadata: event.metadata)
        guard award > 0 else {
            // Still mark key as seen to avoid reprocessing noisy events
            rememberKey(event.idempotencyKey)
            return
        }
        
        totalXP += award
        lastAwardedXP = award
        todayXP += award
        rememberKey(event.idempotencyKey)
        persist()
        recalcBadges()
    }
    
    private func awardFor(_ type: GamEventType, metadata: [String: String]) -> Int {
        // Currently metadata does not affect XP amount, but keeping the signature
        // allows future tuning (e.g. dynamic rewards) without touching callers.
        return GamificationXP.value(for: type)
    }
    
    private func rotateTodayIfNeeded() {
        let key = GamificationService.makeDayKey(Date())
        if key != todayKey {
            todayKey = key
            todayXP = 0
            UserDefaults.standard.set(todayKey, forKey: kTodayKey)
            UserDefaults.standard.set(0, forKey: kTodayXP)
        }
    }
    
    private func rememberKey(_ key: String) {
        seenKeys.insert(key)
    }
    
    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(totalXP, forKey: kTotalXP)
        defaults.set(todayXP, forKey: kTodayXP)
        if streakDays > 0 {
            defaults.set(streakDays, forKey: kStreakDays)
        } else {
            defaults.removeObject(forKey: kStreakDays)
        }
        if let last = lastStreakDate {
            defaults.set(last, forKey: kStreakLastDate)
        } else {
            defaults.removeObject(forKey: kStreakLastDate)
        }
        if let data = try? JSONEncoder().encode(seenKeys) {
            defaults.set(data, forKey: kSeenKeys)
        }
    }
    
    private func updateStreak(for date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        
        if let last = lastStreakDate {
            let lastDay = calendar.startOfDay(for: last)
            
            if calendar.isDate(today, inSameDayAs: lastDay) {
                // Same day – nothing changes
            } else if let diff = calendar.dateComponents([.day], from: lastDay, to: today).day,
                      diff == 1 {
                // Consecutive day – grow streak
                streakDays = min(streakDays + 1, 999)
            } else {
                // Break in streak – start from 0 again
                streakDays = 0
            }
        } else {
            // First tracked day: remember it, streak visually starts from 0
            streakDays = 0
        }
        
        lastStreakDate = today
        persist()
    }
    
    private func recalcBadges() {
        var newBadges: [String] = []
        // Very lightweight heuristic badges based on XP
        if totalXP >= 10 { newBadges.append("reader_1") }
        if totalXP >= 100 { newBadges.append("reader_5") }
        if totalXP >= 150 { newBadges.append("organizer_1") }
        
        // Winter badges (Dec 15 - Jan 10)
        if WinterTheme.isActive {
            // Winter Pioneer - first launch during winter
            if UserDefaults.standard.bool(forKey: "winter_first_launch_2024") {
                newBadges.append("winter_pioneer")
            } else {
                UserDefaults.standard.set(true, forKey: "winter_first_launch_2024")
                newBadges.append("winter_pioneer")
            }
            
            // Festive Organizer - 5+ checklists completed in December
            if totalXP >= 50 && Calendar.current.component(.month, from: Date()) == 12 {
                newBadges.append("festive_organizer")
            }
            
            // New Year Hero - 10+ guides read during festive period
            if totalXP >= 100 {
                newBadges.append("new_year_hero")
            }
        }
        
        badges = newBadges
    }
    
    private static func makeDayKey(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }
    
    // Reset all gamification data when a completely new user is created / logged in
    func resetForNewUser() {
        totalXP = 0
        lastAwardedXP = 0
        todayKey = GamificationService.makeDayKey(Date())
        todayXP = 0
        streakDays = 0
        lastStreakDate = nil
        seenKeys.removeAll()
        badges = []
        
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: kTotalXP)
        defaults.removeObject(forKey: kTodayXP)
        defaults.set(todayKey, forKey: kTodayKey)
        defaults.removeObject(forKey: kSeenKeys)
        defaults.removeObject(forKey: kStreakDays)
        defaults.removeObject(forKey: kStreakLastDate)
    }
}


