//
//  RoadmapModels.swift
//  sweezy
//
//  Mountain-style integration roadmap with 10 levels
//

import SwiftUI

// MARK: - Level Task Model
struct LevelTask: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let type: TaskType
    let targetId: String? // checklist slug, guide category, or special action
    /// Legacy/static reward, kept for potential future tuning.
    /// UI should prefer `effectiveXPReward`, which is derived from `GamificationXP`
    /// to stay in sync with global XP rules.
    let xpReward: Int
    let isPremiumOnly: Bool
    
    enum TaskType: String, Codable {
        case checklist = "checklist"
        case guideCategory = "guide_category"
        case guide = "guide"
        case action = "action" // special actions like "visit map", "set reminder"
    }
    
    /// XP used for display and roadmap summaries.
    /// Built on top of `GamificationXP`, so numbers in Roadmap
    /// are always aligned with global rules.
    var effectiveXPReward: Int {
        switch type {
        case .checklist:
            return GamificationXP.value(for: .checklistCompleted)
        case .guideCategory, .guide:
            return GamificationXP.value(for: .guideReadCompleted)
        case .action:
            return GamificationXP.value(for: .roadmapStageCompleted)
        }
    }
}

// MARK: - Roadmap Level Model
struct RoadmapLevel: Identifiable, Codable {
    let id: Int
    let title: String
    let subtitle: String
    let description: String
    let iconName: String
    let requiredProgress: Int // % of previous level to unlock
    let estimatedDays: String
    let isPremiumOnly: Bool
    let relatedChecklistIds: [String]
    let relatedGuideCategories: [String]
    let tips: [String]
    let premiumTips: [String] // Extra tips for premium users
    let tasks: [LevelTask] // Detailed tasks for this level
    
    var altitude: Int { id * 500 } // Meters for mountain visualization
}

// MARK: - Level Status
enum LevelStatus: Codable {
    case locked
    case available
    case inProgress
    case completed
    
    var iconName: String {
        switch self {
        case .locked: return "lock.fill"
        case .available: return "play.circle.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .locked: return Theme.Colors.textTertiary
        case .available: return Theme.Colors.primary
        case .inProgress: return Theme.Colors.accent
        case .completed: return Theme.Colors.success
        }
    }
}

// MARK: - User Progress
struct RoadmapProgress: Codable {
    var currentLevel: Int
    var levelProgress: [Int: Double] // levelId: progress 0.0-1.0
    var completedLevels: Set<Int>
    var skippedLevels: Set<Int> // Premium feature
    var unlockedAt: [Int: Date]
    var completedAt: [Int: Date]
    
    static var empty: RoadmapProgress {
        RoadmapProgress(
            currentLevel: 1,
            levelProgress: [1: 0.0],
            completedLevels: [],
            skippedLevels: [],
            unlockedAt: [1: Date()],
            completedAt: [:]
        )
    }
    
    func status(for levelId: Int, isPremium: Bool) -> LevelStatus {
        if completedLevels.contains(levelId) || skippedLevels.contains(levelId) {
            return .completed
        }
        if levelId == currentLevel {
            return .inProgress
        }
        if levelId < currentLevel {
            return .completed
        }
        // Check if previous level is 80% complete or premium can skip
        let previousProgress = levelProgress[levelId - 1] ?? 0
        if previousProgress >= 0.8 || (isPremium && levelId <= currentLevel + 2) {
            return .available
        }
        return .locked
    }
    
    func progress(for levelId: Int) -> Double {
        levelProgress[levelId] ?? 0.0
    }
}

// MARK: - Default Levels Data
extension RoadmapLevel {
    static var allLevels: [RoadmapLevel] { [

        // LEVEL 1
        RoadmapLevel(
            id: 1,
            title: "roadmap.level.1.title",
            subtitle: "roadmap.level.1.subtitle",
            description: "roadmap.level.1.description",
            iconName: "flag.fill",
            requiredProgress: 0,
            estimatedDays: "roadmap.level.1.estimatedDays",
            isPremiumOnly: false,
            relatedChecklistIds: ["arrival"],
            relatedGuideCategories: ["documents", "emergency"],
            tips: [
                "roadmap.level.1.tip.1",
                "roadmap.level.1.tip.2",
                "roadmap.level.1.tip.3"
            ],
            premiumTips: [
                "roadmap.level.1.premium_tip.1",
                "roadmap.level.1.premium_tip.2"
            ],
            tasks: [
                LevelTask(id: "1-1", title: "roadmap.task.1-1.title", description: "roadmap.task.1-1.description", iconName: "checklist", type: .checklist, targetId: "arrival", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "1-2", title: "roadmap.task.1-2.title", description: "roadmap.task.1-2.description", iconName: "doc.text", type: .guideCategory, targetId: "documents", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "1-3", title: "roadmap.task.1-3.title", description: "roadmap.task.1-3.description", iconName: "phone.badge.plus", type: .action, targetId: "save-contacts", xpReward: 20, isPremiumOnly: false),
                LevelTask(id: "1-4", title: "roadmap.task.1-4.title", description: "roadmap.task.1-4.description", iconName: "map", type: .action, targetId: "map-gemeinde", xpReward: 20, isPremiumOnly: false),
                LevelTask(id: "1-5", title: "roadmap.task.1-5.title", description: "roadmap.task.1-5.description", iconName: "exclamationmark.triangle", type: .guideCategory, targetId: "emergency", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "1-6", title: "roadmap.task.1-6.title", description: "roadmap.task.1-6.description", iconName: "envelope.open", type: .action, targetId: "check-mailbox", xpReward: 15, isPremiumOnly: false)
            ]
        ),

        // LEVEL 2
        RoadmapLevel(
            id: 2,
            title: "roadmap.level.2.title",
            subtitle: "roadmap.level.2.subtitle",
            description: "roadmap.level.2.description",
            iconName: "creditcard.fill",
            requiredProgress: 80,
            estimatedDays: "roadmap.level.2.estimatedDays",
            isPremiumOnly: false,
            relatedChecklistIds: [],
            relatedGuideCategories: ["banking", "finance"],
            tips: [
                "roadmap.level.2.tip.1",
                "roadmap.level.2.tip.2",
                "roadmap.level.2.tip.3"
            ],
            premiumTips: [
                "roadmap.level.2.premium_tip.1",
                "roadmap.level.2.premium_tip.2"
            ],
            tasks: [
                LevelTask(id: "2-1", title: "roadmap.task.2-1.title", description: "roadmap.task.2-1.description", iconName: "building.columns", type: .action, targetId: "open-bank-account", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "2-2", title: "roadmap.task.2-2.title", description: "roadmap.task.2-2.description", iconName: "simcard.fill", type: .action, targetId: "get-sim", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "2-3", title: "roadmap.task.2-3.title", description: "roadmap.task.2-3.description", iconName: "building.columns.circle", type: .guideCategory, targetId: "banking", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "2-4", title: "roadmap.task.2-4.title", description: "roadmap.task.2-4.description", iconName: "qrcode", type: .action, targetId: "setup-twint", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "2-5", title: "roadmap.task.2-5.title", description: "roadmap.task.2-5.description", iconName: "percent", type: .guideCategory, targetId: "finance", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "2-6", title: "roadmap.task.2-6.title", description: "roadmap.task.2-6.description", iconName: "bolt.fill", type: .action, targetId: "setup-ebill", xpReward: 20, isPremiumOnly: false)
            ]
        ),

        // LEVEL 3
        RoadmapLevel(
            id: 3,
            title: "roadmap.level.3.title",
            subtitle: "roadmap.level.3.subtitle",
            description: "roadmap.level.3.description",
            iconName: "house.fill",
            requiredProgress: 80,
            estimatedDays: "roadmap.level.3.estimatedDays",
            isPremiumOnly: false,
            relatedChecklistIds: ["insurance", "housing"],
            relatedGuideCategories: ["insurance", "housing"],
            tips: [
                "roadmap.level.3.tip.1",
                "roadmap.level.3.tip.2",
                "roadmap.level.3.tip.3"
            ],
            premiumTips: [
                "roadmap.level.3.premium_tip.1",
                "roadmap.level.3.premium_tip.2"
            ],
            tasks: [
                LevelTask(id: "3-1", title: "roadmap.task.3-1.title", description: "roadmap.task.3-1.description", iconName: "cross.case.fill", type: .checklist, targetId: "insurance", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "3-2", title: "roadmap.task.3-2.title", description: "roadmap.task.3-2.description", iconName: "house.fill", type: .checklist, targetId: "housing", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "3-3", title: "roadmap.task.3-3.title", description: "roadmap.task.3-3.description", iconName: "shield.fill", type: .guideCategory, targetId: "insurance", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "3-4", title: "roadmap.task.3-4.title", description: "roadmap.task.3-4.description", iconName: "chart.bar.fill", type: .action, targetId: "compare-insurance", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "3-5", title: "roadmap.task.3-5.title", description: "roadmap.task.3-5.description", iconName: "stethoscope", type: .action, targetId: "find-hausarzt", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "3-6", title: "roadmap.task.3-6.title", description: "roadmap.task.3-6.description", iconName: "doc.badge.plus", type: .guideCategory, targetId: "housing", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "3-7", title: "roadmap.task.3-7.title", description: "roadmap.task.3-7.description", iconName: "tag.fill", type: .action, targetId: "apply-premienverbilligung", xpReward: 40, isPremiumOnly: true)
            ]
        ),

        // LEVEL 4
        RoadmapLevel(
            id: 4,
            title: "roadmap.level.4.title",
            subtitle: "roadmap.level.4.subtitle",
            description: "roadmap.level.4.description",
            iconName: "briefcase.fill",
            requiredProgress: 80,
            estimatedDays: "roadmap.level.4.estimatedDays",
            isPremiumOnly: false,
            relatedChecklistIds: ["work"],
            relatedGuideCategories: ["work", "finance"],
            tips: [
                "roadmap.level.4.tip.1",
                "roadmap.level.4.tip.2",
                "roadmap.level.4.tip.3"
            ],
            premiumTips: [
                "roadmap.level.4.premium_tip.1",
                "roadmap.level.4.premium_tip.2"
            ],
            tasks: [
                LevelTask(id: "4-1", title: "roadmap.task.4-1.title", description: "roadmap.task.4-1.description", iconName: "checklist", type: .checklist, targetId: "work", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "4-2", title: "roadmap.task.4-2.title", description: "roadmap.task.4-2.description", iconName: "building.2.fill", type: .action, targetId: "register-rav", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "4-3", title: "roadmap.task.4-3.title", description: "roadmap.task.4-3.description", iconName: "doc.text.fill", type: .guideCategory, targetId: "work", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "4-4", title: "roadmap.task.4-4.title", description: "roadmap.task.4-4.description", iconName: "paperplane.fill", type: .action, targetId: "apply-jobs", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "4-5", title: "roadmap.task.4-5.title", description: "roadmap.task.4-5.description", iconName: "doc.text.magnifyingglass", type: .guideCategory, targetId: "finance", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "4-6", title: "roadmap.task.4-6.title", description: "roadmap.task.4-6.description", iconName: "graduationcap.fill", type: .action, targetId: "diploma-recognition", xpReward: 45, isPremiumOnly: false),
                LevelTask(id: "4-7", title: "roadmap.task.4-7.title", description: "roadmap.task.4-7.description", iconName: "person.crop.square.filled.and.at.rectangle", type: .action, targetId: "create-linkedin", xpReward: 30, isPremiumOnly: true)
            ]
        ),

        // LEVEL 5
        RoadmapLevel(
            id: 5,
            title: "roadmap.level.5.title",
            subtitle: "roadmap.level.5.subtitle",
            description: "roadmap.level.5.description",
            iconName: "book.fill",
            requiredProgress: 80,
            estimatedDays: "roadmap.level.5.estimatedDays",
            isPremiumOnly: false,
            relatedChecklistIds: [],
            relatedGuideCategories: ["education", "integration"],
            tips: [
                "roadmap.level.5.tip.1",
                "roadmap.level.5.tip.2",
                "roadmap.level.5.tip.3"
            ],
            premiumTips: [
                "roadmap.level.5.premium_tip.1",
                "roadmap.level.5.premium_tip.2"
            ],
            tasks: [
                LevelTask(id: "5-1", title: "roadmap.task.5-1.title", description: "roadmap.task.5-1.description", iconName: "character.bubble.fill", type: .action, targetId: "enroll-language", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "5-2", title: "roadmap.task.5-2.title", description: "roadmap.task.5-2.description", iconName: "book.closed.fill", type: .guideCategory, targetId: "education", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "5-3", title: "roadmap.task.5-3.title", description: "roadmap.task.5-3.description", iconName: "person.3.fill", type: .guideCategory, targetId: "integration", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "5-4", title: "roadmap.task.5-4.title", description: "roadmap.task.5-4.description", iconName: "person.2.fill", type: .action, targetId: "find-tandem", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "5-5", title: "roadmap.task.5-5.title", description: "roadmap.task.5-5.description", iconName: "checkmark.seal.fill", type: .action, targetId: "language-test-a2", xpReward: 60, isPremiumOnly: false),
                LevelTask(id: "5-6", title: "roadmap.task.5-6.title", description: "roadmap.task.5-6.description", iconName: "figure.socialdance", type: .action, targetId: "join-club", xpReward: 40, isPremiumOnly: false)
            ]
        ),

        // LEVEL 6
        RoadmapLevel(
            id: 6,
            title: "roadmap.level.6.title",
            subtitle: "roadmap.level.6.subtitle",
            description: "roadmap.level.6.description",
            iconName: "chart.line.uptrend.xyaxis",
            requiredProgress: 80,
            estimatedDays: "roadmap.level.6.estimatedDays",
            isPremiumOnly: false,
            relatedChecklistIds: [],
            relatedGuideCategories: ["finance", "lifestyle"],
            tips: [
                "roadmap.level.6.tip.1",
                "roadmap.level.6.tip.2",
                "roadmap.level.6.tip.3"
            ],
            premiumTips: [
                "roadmap.level.6.premium_tip.1",
                "roadmap.level.6.premium_tip.2"
            ],
            tasks: [
                LevelTask(id: "6-1", title: "roadmap.task.6-1.title", description: "roadmap.task.6-1.description", iconName: "banknote.fill", type: .action, targetId: "open-3a", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "6-2", title: "roadmap.task.6-2.title", description: "roadmap.task.6-2.description", iconName: "doc.text.magnifyingglass", type: .action, targetId: "check-pillar2", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "6-3", title: "roadmap.task.6-3.title", description: "roadmap.task.6-3.description", iconName: "chart.pie.fill", type: .guideCategory, targetId: "finance", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "6-4", title: "roadmap.task.6-4.title", description: "roadmap.task.6-4.description", iconName: "sparkles", type: .guideCategory, targetId: "lifestyle", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "6-5", title: "roadmap.task.6-5.title", description: "roadmap.task.6-5.description", iconName: "tray.and.arrow.up.fill", type: .action, targetId: "file-tax-return", xpReward: 60, isPremiumOnly: false),
                LevelTask(id: "6-6", title: "roadmap.task.6-6.title", description: "roadmap.task.6-6.description", iconName: "arrow.clockwise", type: .action, targetId: "setup-3a-autopay", xpReward: 30, isPremiumOnly: true)
            ]
        ),

        // LEVEL 7
        RoadmapLevel(
            id: 7,
            title: "roadmap.level.7.title",
            subtitle: "roadmap.level.7.subtitle",
            description: "roadmap.level.7.description",
            iconName: "tram.fill",
            requiredProgress: 80,
            estimatedDays: "roadmap.level.7.estimatedDays",
            isPremiumOnly: false,
            relatedChecklistIds: [],
            relatedGuideCategories: ["transport"],
            tips: [
                "roadmap.level.7.tip.1",
                "roadmap.level.7.tip.2",
                "roadmap.level.7.tip.3"
            ],
            premiumTips: [
                "roadmap.level.7.premium_tip.1",
                "roadmap.level.7.premium_tip.2"
            ],
            tasks: [
                LevelTask(id: "7-1", title: "roadmap.task.7-1.title", description: "roadmap.task.7-1.description", iconName: "ticket.fill", type: .action, targetId: "get-halbtax", xpReward: 60, isPremiumOnly: false),
                LevelTask(id: "7-2", title: "roadmap.task.7-2.title", description: "roadmap.task.7-2.description", iconName: "iphone.gen3", type: .action, targetId: "download-sbb", xpReward: 20, isPremiumOnly: false),
                LevelTask(id: "7-3", title: "roadmap.task.7-3.title", description: "roadmap.task.7-3.description", iconName: "bus.fill", type: .guideCategory, targetId: "transport", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "7-4", title: "roadmap.task.7-4.title", description: "roadmap.task.7-4.description", iconName: "car.fill", type: .action, targetId: "exchange-license", xpReward: 70, isPremiumOnly: false),
                LevelTask(id: "7-5", title: "roadmap.task.7-5.title", description: "roadmap.task.7-5.description", iconName: "equal.circle.fill", type: .action, targetId: "calculate-ga-vs-halbtax", xpReward: 20, isPremiumOnly: false),
                LevelTask(id: "7-6", title: "roadmap.task.7-6.title", description: "roadmap.task.7-6.description", iconName: "bicycle", type: .action, targetId: "register-bicycle", xpReward: 15, isPremiumOnly: true)
            ]
        ),

        // LEVEL 8
        RoadmapLevel(
            id: 8,
            title: "roadmap.level.8.title",
            subtitle: "roadmap.level.8.subtitle",
            description: "roadmap.level.8.description",
            iconName: "figure.2.and.child.holdinghands",
            requiredProgress: 80,
            estimatedDays: "roadmap.level.8.estimatedDays",
            isPremiumOnly: false,
            relatedChecklistIds: ["family", "healthcare"],
            relatedGuideCategories: ["education", "healthcare"],
            tips: [
                "roadmap.level.8.tip.1",
                "roadmap.level.8.tip.2",
                "roadmap.level.8.tip.3"
            ],
            premiumTips: [
                "roadmap.level.8.premium_tip.1",
                "roadmap.level.8.premium_tip.2"
            ],
            tasks: [
                LevelTask(id: "8-1", title: "roadmap.task.8-1.title", description: "roadmap.task.8-1.description", iconName: "person.2.badge.plus", type: .checklist, targetId: "family", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "8-2", title: "roadmap.task.8-2.title", description: "roadmap.task.8-2.description", iconName: "cross.case.fill", type: .checklist, targetId: "healthcare", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "8-3", title: "roadmap.task.8-3.title", description: "roadmap.task.8-3.description", iconName: "graduationcap.fill", type: .guideCategory, targetId: "education", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "8-4", title: "roadmap.task.8-4.title", description: "roadmap.task.8-4.description", iconName: "banknote.fill", type: .action, targetId: "apply-kinderzulagen", xpReward: 60, isPremiumOnly: false),
                LevelTask(id: "8-5", title: "roadmap.task.8-5.title", description: "roadmap.task.8-5.description", iconName: "figure.run", type: .action, targetId: "find-activities", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "8-6", title: "roadmap.task.8-6.title", description: "roadmap.task.8-6.description", iconName: "heart.text.square.fill", type: .guideCategory, targetId: "healthcare", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "8-7", title: "roadmap.task.8-7.title", description: "roadmap.task.8-7.description", iconName: "waveform.path.ecg", type: .action, targetId: "health-checkup", xpReward: 30, isPremiumOnly: true)
            ]
        ),

        // LEVEL 9
        RoadmapLevel(
            id: 9,
            title: "roadmap.level.9.title",
            subtitle: "roadmap.level.9.subtitle",
            description: "roadmap.level.9.description",
            iconName: "person.badge.shield.checkmark.fill",
            requiredProgress: 80,
            estimatedDays: "roadmap.level.9.estimatedDays",
            isPremiumOnly: false,
            relatedChecklistIds: ["legal"],
            relatedGuideCategories: ["legal", "lifestyle"],
            tips: [
                "roadmap.level.9.tip.1",
                "roadmap.level.9.tip.2",
                "roadmap.level.9.tip.3"
            ],
            premiumTips: [
                "roadmap.level.9.premium_tip.1",
                "roadmap.level.9.premium_tip.2"
            ],
            tasks: [
                LevelTask(id: "9-1", title: "roadmap.task.9-1.title", description: "roadmap.task.9-1.description", iconName: "checklist", type: .checklist, targetId: "legal", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "9-2", title: "roadmap.task.9-2.title", description: "roadmap.task.9-2.description", iconName: "hammer.fill", type: .guideCategory, targetId: "legal", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "9-3", title: "roadmap.task.9-3.title", description: "roadmap.task.9-3.description", iconName: "person.badge.key.fill", type: .guideCategory, targetId: "lifestyle", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "9-4", title: "roadmap.task.9-4.title", description: "roadmap.task.9-4.description", iconName: "checkmark.seal.fill", type: .action, targetId: "fide-b1-test", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "9-5", title: "roadmap.task.9-5.title", description: "roadmap.task.9-5.description", iconName: "doc.text.magnifyingglass", type: .action, targetId: "check-betreibung", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "9-6", title: "roadmap.task.9-6.title", description: "roadmap.task.9-6.description", iconName: "flag.checkered.2.crossed", type: .action, targetId: "naturalization-check", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "9-7", title: "roadmap.task.9-7.title", description: "roadmap.task.9-7.description", iconName: "tray.and.arrow.up.fill", type: .action, targetId: "apply-permit-c", xpReward: 150, isPremiumOnly: true)
            ]
        ),

        // LEVEL 10
        RoadmapLevel(
            id: 10,
            title: "roadmap.level.10.title",
            subtitle: "roadmap.level.10.subtitle",
            description: "roadmap.level.10.description",
            iconName: "star.fill",
            requiredProgress: 80,
            estimatedDays: "roadmap.level.10.estimatedDays",
            isPremiumOnly: false,
            relatedChecklistIds: [],
            relatedGuideCategories: ["lifestyle", "integration"],
            tips: [
                "roadmap.level.10.tip.1",
                "roadmap.level.10.tip.2",
                "roadmap.level.10.tip.3"
            ],
            premiumTips: [
                "roadmap.level.10.premium_tip.1",
                "roadmap.level.10.premium_tip.2"
            ],
            tasks: [
                LevelTask(id: "10-1", title: "roadmap.task.10-1.title", description: "roadmap.task.10-1.description", iconName: "sun.horizon.fill", type: .guideCategory, targetId: "lifestyle", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "10-2", title: "roadmap.task.10-2.title", description: "roadmap.task.10-2.description", iconName: "person.3.fill", type: .action, targetId: "join-verein", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "10-3", title: "roadmap.task.10-3.title", description: "roadmap.task.10-3.description", iconName: "globe.europe.africa.fill", type: .guideCategory, targetId: "integration", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "10-4", title: "roadmap.task.10-4.title", description: "roadmap.task.10-4.description", iconName: "heart.fill", type: .action, targetId: "volunteer", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "10-5", title: "roadmap.task.10-5.title", description: "roadmap.task.10-5.description", iconName: "checkmark.rectangle.stack.fill", type: .action, targetId: "vote", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "10-6", title: "roadmap.task.10-6.title", description: "roadmap.task.10-6.description", iconName: "flag.checkered", type: .action, targetId: "start-naturalization", xpReward: 200, isPremiumOnly: false),
                LevelTask(id: "10-7", title: "roadmap.task.10-7.title", description: "roadmap.task.10-7.description", iconName: "quote.bubble.fill", type: .action, targetId: "share-story", xpReward: 100, isPremiumOnly: true)
            ]
        )

    ] }
}

// MARK: - Mountain Theme Colors
struct MountainTheme {
    static let skyGradient = LinearGradient(
        colors: [
            Theme.Colors.primaryBackground,
            Theme.Colors.secondaryBackground,
            Theme.Colors.primaryBackground
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let snowColor = Theme.Colors.adaptiveSurface
    static let rockColor = Theme.Colors.secondaryBackground
    static let grassColor = Theme.Colors.primary.opacity(0.18)
    static let pathColor = Theme.Colors.accent
    static let lockedColor = Theme.Colors.adaptiveSurface
    static let glowColor = Theme.Colors.primary
    
    static func altitudeColor(for altitude: Int) -> Color {
        switch altitude {
        case 0..<1500: return grassColor
        case 1500..<3000: return rockColor
        case 3000..<4000: return Color(red: 0.6, green: 0.6, blue: 0.65)
        default: return snowColor
        }
    }
}
