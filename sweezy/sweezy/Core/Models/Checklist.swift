//
//  Checklist.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation
import SwiftUI

/// Checklist model for step-by-step guides
struct Checklist: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let category: ChecklistCategory
    let estimatedDuration: String // e.g., "1-2 weeks", "3 days"
    let difficulty: Difficulty
    let steps: [ChecklistStep]
    let tags: [String]
    let cantonCodes: [String] // Empty means applies to all cantons
    let priority: Int
    let isNew: Bool
    let createdAt: Date
    let lastUpdated: Date
    let language: String? // ISO 639-1 code (uk, ru, en, de)
    let verifiedAt: Date? // When content was last verified
    let source: String? // URL or authority reference
    let heroImage: String? // Hero image path
    
    init(
        title: String,
        description: String,
        category: ChecklistCategory,
        estimatedDuration: String,
        difficulty: Difficulty = .medium,
        steps: [ChecklistStep],
        tags: [String] = [],
        cantonCodes: [String] = [],
        priority: Int = 0,
        isNew: Bool = false,
        language: String? = nil,
        verifiedAt: Date? = nil,
        source: String? = nil,
        heroImage: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category
        self.estimatedDuration = estimatedDuration
        self.difficulty = difficulty
        self.steps = steps
        self.tags = tags
        self.cantonCodes = cantonCodes
        self.priority = priority
        self.isNew = isNew
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.language = language
        self.verifiedAt = verifiedAt
        self.source = source
        self.heroImage = heroImage
    }
    
    // Tolerant decoding for invalid UUIDs
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Tolerant UUID decoding
        if let idString = try? container.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        
        self.title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled"
        self.description = (try? container.decode(String.self, forKey: .description)) ?? ""
        self.category = (try? container.decode(ChecklistCategory.self, forKey: .category)) ?? .arrival
        self.estimatedDuration = (try? container.decode(String.self, forKey: .estimatedDuration)) ?? "1 week"
        self.difficulty = (try? container.decode(Difficulty.self, forKey: .difficulty)) ?? .medium
        self.steps = (try? container.decode([ChecklistStep].self, forKey: .steps)) ?? []
        self.tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        self.cantonCodes = (try? container.decode([String].self, forKey: .cantonCodes)) ?? []
        self.priority = (try? container.decode(Int.self, forKey: .priority)) ?? 0
        self.isNew = (try? container.decode(Bool.self, forKey: .isNew)) ?? false
        self.createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        self.lastUpdated = (try? container.decode(Date.self, forKey: .lastUpdated)) ?? Date()
        self.language = try? container.decodeIfPresent(String.self, forKey: .language)
        self.verifiedAt = try? container.decodeIfPresent(Date.self, forKey: .verifiedAt)
        self.source = try? container.decodeIfPresent(String.self, forKey: .source)
        self.heroImage = try? container.decodeIfPresent(String.self, forKey: .heroImage)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, description, category, estimatedDuration, difficulty, steps
        case tags, cantonCodes, priority, isNew, createdAt, lastUpdated
        case language, verifiedAt, source, heroImage
    }
    
    /// Check if checklist applies to specific canton
    func appliesTo(canton: Canton) -> Bool {
        cantonCodes.isEmpty || cantonCodes.contains(canton.rawValue)
    }
    
    /// Calculate completion percentage
    func completionPercentage(progress: ChecklistProgress) -> Double {
        guard !steps.isEmpty else { return 0 }
        let completedSteps = steps.filter { progress.completedSteps.contains($0.id) }.count
        return Double(completedSteps) / Double(steps.count)
    }
}

/// Checklist categories
enum ChecklistCategory: String, CaseIterable, Codable, Hashable {
    case arrival = "arrival"
    case housing = "housing"
    case insurance = "insurance"
    case work = "work"
    case education = "education"
    case integration = "integration"
    case family = "family"
    case healthcare = "healthcare"
    case legal = "legal"
    case finance = "finance"
    
    var localizedName: String {
        switch self {
        case .arrival: return "First Steps"
        case .housing: return "Housing"
        case .insurance: return "Insurance"
        case .work: return "Employment"
        case .education: return "Education"
        case .integration: return "Integration"
        case .family: return "Family"
        case .healthcare: return "Healthcare"
        case .legal: return "Legal"
        case .finance: return "Finance"
        }
    }
    
    var iconName: String {
        switch self {
        case .arrival: return "airplane.arrival"
        case .housing: return "house"
        case .insurance: return "shield"
        case .work: return "briefcase"
        case .education: return "graduationcap"
        case .integration: return "person.2"
        case .family: return "figure.2.and.child.holdinghands"
        case .healthcare: return "cross"
        case .legal: return "hammer"
        case .finance: return "creditcard"
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .arrival: return .blue
        case .housing: return .green
        case .insurance: return .purple
        case .work: return .orange
        case .education: return .indigo
        case .integration: return .cyan
        case .family: return .pink
        case .healthcare: return .red
        case .legal: return .brown
        case .finance: return .yellow
        }
    }
}

/// Difficulty levels
enum Difficulty: String, CaseIterable, Codable, Hashable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var localizedName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Complex"
        }
    }
    
    var iconName: String {
        switch self {
        case .easy: return "1.circle"
        case .medium: return "2.circle"
        case .hard: return "3.circle"
        }
    }
    
    var color: String {
        switch self {
        case .easy: return "green"
        case .medium: return "orange"
        case .hard: return "red"
        }
    }
}

/// Individual checklist step
struct ChecklistStep: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let estimatedTime: String? // e.g., "30 minutes", "1 hour"
    let isOptional: Bool
    let links: [GuideLink]
    let requiredDocuments: [String]
    let tips: [String]
    let order: Int
    
    init(
        title: String,
        description: String,
        estimatedTime: String? = nil,
        isOptional: Bool = false,
        links: [GuideLink] = [],
        requiredDocuments: [String] = [],
        tips: [String] = [],
        order: Int
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.estimatedTime = estimatedTime
        self.isOptional = isOptional
        self.links = links
        self.requiredDocuments = requiredDocuments
        self.tips = tips
        self.order = order
    }
    
    // Tolerant decoding for invalid UUIDs
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Tolerant UUID decoding
        if let idString = try? container.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        
        self.title = (try? container.decode(String.self, forKey: .title)) ?? "Step"
        self.description = (try? container.decode(String.self, forKey: .description)) ?? ""
        self.estimatedTime = try? container.decodeIfPresent(String.self, forKey: .estimatedTime)
        self.isOptional = (try? container.decode(Bool.self, forKey: .isOptional)) ?? false
        self.links = (try? container.decode([GuideLink].self, forKey: .links)) ?? []
        self.requiredDocuments = (try? container.decode([String].self, forKey: .requiredDocuments)) ?? []
        self.tips = (try? container.decode([String].self, forKey: .tips)) ?? []
        self.order = (try? container.decode(Int.self, forKey: .order)) ?? 0
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, description, estimatedTime, isOptional, links, requiredDocuments, tips, order
    }
}

/// Checklist progress tracking
struct ChecklistProgress: Codable {
    let checklistId: UUID
    var completedSteps: Set<UUID>
    var startedAt: Date?
    var lastUpdatedAt: Date
    var notes: [UUID: String] // Step ID -> user notes
    var estimatedCompletionDate: Date?
    
    init(checklistId: UUID) {
        self.checklistId = checklistId
        self.completedSteps = []
        self.lastUpdatedAt = Date()
        self.notes = [:]
    }
    
    mutating func toggleStep(_ stepId: UUID) {
        if completedSteps.contains(stepId) {
            completedSteps.remove(stepId)
        } else {
            completedSteps.insert(stepId)
            if startedAt == nil {
                startedAt = Date()
            }
        }
        lastUpdatedAt = Date()
    }
    
    mutating func addNote(for stepId: UUID, note: String) {
        notes[stepId] = note
        lastUpdatedAt = Date()
    }
    
    var isCompleted: Bool {
        // This would need to be calculated against the actual checklist
        // For now, just check if any steps are completed
        return !completedSteps.isEmpty
    }
    
    var completionPercentage: Double {
        // This would need the total step count from the checklist
        // Placeholder implementation
        return completedSteps.isEmpty ? 0.0 : 0.5
    }
}

