//
//  Guide.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation
import SwiftUI

/// Guide article model for information content
struct Guide: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String?
    let bodyMarkdown: String
    let tags: [String]
    let category: GuideCategory
    let cantonCodes: [String] // Empty array means applies to all cantons
    let links: [GuideLink]
    let priority: Int // Higher number = higher priority
    let isNew: Bool
    let isPremium: Bool // Requires premium subscription to read
    let estimatedReadingTime: Int // in minutes
    let lastUpdated: Date
    let createdAt: Date
    let language: String? // ISO 639-1 code (uk, ru, en, de)
    let verifiedAt: Date? // When content was last verified
    let source: String? // URL or authority reference
    let heroImage: String? // Hero image path
    
    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, bodyMarkdown, tags, category, cantonCodes, links
        case priority, isNew, isPremium, estimatedReadingTime, lastUpdated, createdAt
        case language, verifiedAt, source, heroImage
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Lenient id decoding
        if let uuid = try? container.decode(UUID.self, forKey: .id) {
            self.id = uuid
        } else if let idString = try? container.decode(String.self, forKey: .id), let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        self.title = (try? container.decode(String.self, forKey: .title)) ?? ""
        self.subtitle = try? container.decode(String.self, forKey: .subtitle)
        self.bodyMarkdown = (try? container.decode(String.self, forKey: .bodyMarkdown)) ?? ""
        self.tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        self.category = (try? container.decode(GuideCategory.self, forKey: .category)) ?? .documents
        self.cantonCodes = (try? container.decode([String].self, forKey: .cantonCodes)) ?? []
        self.links = (try? container.decode([GuideLink].self, forKey: .links)) ?? []
        self.priority = (try? container.decode(Int.self, forKey: .priority)) ?? 0
        self.isNew = (try? container.decode(Bool.self, forKey: .isNew)) ?? false
        self.isPremium = (try? container.decode(Bool.self, forKey: .isPremium)) ?? false
        self.estimatedReadingTime = (try? container.decode(Int.self, forKey: .estimatedReadingTime)) ?? 5
        self.lastUpdated = (try? container.decode(Date.self, forKey: .lastUpdated)) ?? Date()
        self.createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        
        // Prefer explicit language field, otherwise derive from tags like "lang:uk"
        if let explicitLang = try? container.decode(String.self, forKey: .language),
           !explicitLang.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.language = explicitLang.lowercased()
        } else if let langTag = self.tags.first(where: { $0.lowercased().hasPrefix("lang:") }) {
            let parts = langTag.split(separator: ":")
            if let code = parts.last, !code.isEmpty {
                self.language = String(code).lowercased()
            } else {
                self.language = nil
            }
        } else {
            self.language = nil
        }
        self.verifiedAt = try? container.decode(Date.self, forKey: .verifiedAt)
        self.source = try? container.decode(String.self, forKey: .source)
        self.heroImage = try? container.decode(String.self, forKey: .heroImage)
    }
    
    init(
        title: String,
        subtitle: String? = nil,
        bodyMarkdown: String,
        tags: [String] = [],
        category: GuideCategory,
        cantonCodes: [String] = [],
        links: [GuideLink] = [],
        priority: Int = 0,
        isNew: Bool = false,
        isPremium: Bool = false,
        estimatedReadingTime: Int = 5,
        language: String? = nil,
        verifiedAt: Date? = nil,
        source: String? = nil,
        heroImage: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.bodyMarkdown = bodyMarkdown
        self.tags = tags
        self.category = category
        self.cantonCodes = cantonCodes
        self.links = links
        self.priority = priority
        self.isNew = isNew
        self.isPremium = isPremium
        self.estimatedReadingTime = estimatedReadingTime
        self.lastUpdated = Date()
        self.createdAt = Date()
        self.language = language
        self.verifiedAt = verifiedAt
        self.source = source
        self.heroImage = heroImage
    }
    
    /// Check if guide applies to specific canton
    func appliesTo(canton: Canton) -> Bool {
        cantonCodes.isEmpty || cantonCodes.contains(canton.rawValue)
    }
    
    /// Search relevance score for query
    func searchRelevance(for query: String) -> Double {
        let lowercaseQuery = query.lowercased()
        var score: Double = 0
        
        // Title match (highest weight)
        if title.lowercased().contains(lowercaseQuery) {
            score += 10
        }
        
        // Subtitle match
        if let subtitle = subtitle, subtitle.lowercased().contains(lowercaseQuery) {
            score += 5
        }
        
        // Tags match
        for tag in tags {
            if tag.lowercased().contains(lowercaseQuery) {
                score += 3
            }
        }
        
        // Body content match (lowest weight)
        if bodyMarkdown.lowercased().contains(lowercaseQuery) {
            score += 1
        }
        
        // Category match
        if category.rawValue.lowercased().contains(lowercaseQuery) {
            score += 2
        }
        
        return score
    }
}

/// Guide categories for organization
enum GuideCategory: String, CaseIterable, Codable, Hashable {
    case documents = "documents"
    case housing = "housing"
    case insurance = "insurance"
    case work = "work"
    case finance = "finance"
    case education = "education"
    case healthcare = "healthcare"
    case legal = "legal"
    case emergency = "emergency"
    case integration = "integration"
    case transport = "transport"
    case banking = "banking"
    
    var localizedName: String {
        switch self {
        case .documents: return "guide.category.documents".localized
        case .housing: return "guide.category.housing".localized
        case .insurance: return "guide.category.insurance".localized
        case .work: return "guide.category.work".localized
        case .finance: return "guide.category.finance".localized
        case .education: return "guide.category.education".localized
        case .healthcare: return "guide.category.healthcare".localized
        case .legal: return "guide.category.legal".localized
        case .emergency: return "guide.category.emergency".localized
        case .integration: return "guide.category.integration".localized
        case .transport: return "guide.category.transport".localized
        case .banking: return "guide.category.banking".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .documents: return "doc.text" // iOS 13+
        case .housing: return "house" // iOS 13+
        case .insurance: return "shield.fill" // iOS 13+
        case .work: return "briefcase" // iOS 13+
        case .finance: return "creditcard" // iOS 13+
        case .education: return "graduationcap" // iOS 13+
        case .healthcare: return "cross.case" // iOS 14+
        case .legal: return "hammer" // safer fallback
        case .emergency: return "exclamationmark.triangle" // iOS 13+
        case .integration: return "person.2" // iOS 13+
        case .transport: return "bus" // iOS 13+
        case .banking: return "building.columns" // iOS 13+
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .documents: return .blue
        case .housing: return .green
        case .insurance: return .purple
        case .work: return .orange
        case .finance: return .red
        case .education: return .indigo
        case .healthcare: return .pink
        case .legal: return .brown
        case .emergency: return .red
        case .integration: return .cyan
        case .transport: return .mint
        case .banking: return .yellow
        }
    }
}

/// External links in guides
struct GuideLink: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let url: String
    let type: LinkType
    let description: String?
    
    init(title: String, url: String, type: LinkType, description: String? = nil) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.type = type
        self.description = description
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, url, type, description
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Be lenient with id: accept UUID, String(UUID), or generate
        if let uuid = try? container.decode(UUID.self, forKey: .id) {
            self.id = uuid
        } else if let idString = try? container.decode(String.self, forKey: .id), let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        self.title = (try? container.decode(String.self, forKey: .title)) ?? ""
        self.url = (try? container.decode(String.self, forKey: .url)) ?? ""
        self.type = (try? container.decode(LinkType.self, forKey: .type)) ?? .website
        self.description = try? container.decode(String.self, forKey: .description)
    }
    
    enum LinkType: String, Codable, Hashable {
        case website = "website"
        case phone = "phone"
        case email = "email"
        case pdf = "pdf"
        case form = "form"
        case video = "video"
        
        var iconName: String {
            switch self {
            case .website: return "globe"
            case .phone: return "phone"
            case .email: return "envelope"
            case .pdf: return "doc.text"
            case .form: return "square.and.pencil"
            case .video: return "play.rectangle"
            }
        }
    }

    var asURL: URL? {
        guard let url = URL(string: url) else { return nil }
        if let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return url
        }
        return nil
    }
}

/// Guide reading progress tracking
struct GuideProgress: Codable {
    let guideId: UUID
    var isRead: Bool
    var isBookmarked: Bool
    var readingProgress: Double // 0.0 to 1.0
    var lastReadAt: Date?
    var completedActions: Set<String> // IDs of completed actions/links
    
    init(guideId: UUID) {
        self.guideId = guideId
        self.isRead = false
        self.isBookmarked = false
        self.readingProgress = 0.0
        self.completedActions = []
    }
}

