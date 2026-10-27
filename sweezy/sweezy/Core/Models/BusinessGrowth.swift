import Foundation

enum BusinessKind: String, CaseIterable, Identifiable, Codable {
    case business, specialist, club

    var id: String { rawValue }
    var title: String { "business.kind.\(rawValue)".localized }
    var subtitle: String { "business.kind.\(rawValue).subtitle".localized }
    var icon: String {
        switch self {
        case .business: return "storefront.fill"
        case .specialist: return "person.crop.circle.badge.checkmark"
        case .club: return "person.3.fill"
        }
    }
    var swatch: JourneyCategorySwatch {
        switch self {
        case .business: return JourneyCategoryPalette.lime
        case .specialist: return JourneyCategoryPalette.sky
        case .club: return JourneyCategoryPalette.lilac
        }
    }
}

enum BusinessCategory: String, CaseIterable, Identifiable {
    case beauty, food, health, legal, translation, finance, education, it, repair, cleaning, moving, auto, retail, events, community, other

    var id: String { rawValue }
    var title: String { "business.category.\(rawValue)".localized }
    var icon: String {
        switch self {
        case .beauty: return "scissors"
        case .food: return "fork.knife"
        case .health: return "cross.case.fill"
        case .legal: return "building.columns.fill"
        case .translation: return "character.bubble.fill"
        case .finance: return "eurosign.circle.fill"
        case .education: return "graduationcap.fill"
        case .it: return "laptopcomputer"
        case .repair: return "wrench.and.screwdriver.fill"
        case .cleaning: return "sparkles"
        case .moving: return "box.truck.fill"
        case .auto: return "car.fill"
        case .retail: return "bag.fill"
        case .events: return "party.popper.fill"
        case .community: return "person.3.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
    var swatch: JourneyCategorySwatch {
        switch self {
        case .beauty, .events: return JourneyCategoryPalette.coral
        case .food, .retail: return JourneyCategoryPalette.sand
        case .health, .cleaning: return JourneyCategoryPalette.teal
        case .legal, .finance, .it: return JourneyCategoryPalette.sky
        case .translation, .education, .community: return JourneyCategoryPalette.lilac
        case .repair, .moving, .auto: return JourneyCategoryPalette.lime
        case .other: return JourneyCategoryPalette.graphite
        }
    }
}

enum BusinessPlanTier: String, CaseIterable, Identifiable, Comparable {
    case free, pro, business

    var id: String { rawValue }
    var title: String { "business.plan.\(rawValue)".localized }
    private var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

struct BusinessSummary: Codable, Identifiable, Hashable {
    let userID: String
    let kind: String
    let displayName: String
    let tagline: String?
    let category: String
    let countryCode: String
    let subdivisionCode: String
    let city: String
    let languages: [String]
    let logoURL: String?
    let coverURL: String?
    let latitude: Double?
    let longitude: Double?
    let isVerified: Bool
    let averageRating: Double?
    let reviewCount: Int
    let plan: String
    let isSponsored: Bool
    let topOfferLabel: String?

    var id: String { userID }
    var businessKind: BusinessKind { BusinessKind(rawValue: kind) ?? .business }
    var businessCategory: BusinessCategory { BusinessCategory(rawValue: category) ?? .other }
    var tier: BusinessPlanTier { BusinessPlanTier(rawValue: plan) ?? .free }
    var speaksUkrainian: Bool { languages.contains { $0.lowercased() == "uk" } }

    enum CodingKeys: String, CodingKey {
        case kind, tagline, category, city, languages, latitude, longitude, plan
        case userID = "user_id", displayName = "display_name", countryCode = "country_code"
        case subdivisionCode = "subdivision_code", logoURL = "logo_url", coverURL = "cover_url"
        case isVerified = "is_verified", averageRating = "average_rating", reviewCount = "review_count"
        case isSponsored = "is_sponsored", topOfferLabel = "top_offer_label"
    }
}

struct BusinessDirectoryPage: Codable {
    let items: [BusinessSummary]
    let total: Int
}

struct BusinessReview: Codable, Identifiable, Hashable {
    let id: String
    let businessUserID: String
    let authorName: String
    let rating: Int
    let text: String
    let ownerReply: String?
    let ownerRepliedAt: Date?
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, rating, text, status
        case businessUserID = "business_user_id", authorName = "author_name", ownerReply = "owner_reply"
        case ownerRepliedAt = "owner_replied_at", createdAt = "created_at"
    }
}

struct BusinessReviewEligibility: Codable {
    let canReview: Bool
    let reason: String?
    let existing: BusinessReview?
    enum CodingKeys: String, CodingKey { case reason, existing; case canReview = "can_review" }
}

struct BusinessReviewPayload: Encodable {
    let rating: Int
    let text: String
}

struct BusinessOffer: Codable, Identifiable, Hashable {
    let id: String
    let businessUserID: String
    var title: String
    var description: String
    var discountLabel: String
    var promoCode: String?
    var endsAt: Date?
    var isActive: Bool
    let createdAt: Date
    let business: BusinessSummary?

    enum CodingKeys: String, CodingKey {
        case id, title, description, business
        case businessUserID = "business_user_id", discountLabel = "discount_label", promoCode = "promo_code"
        case endsAt = "ends_at", isActive = "is_active", createdAt = "created_at"
    }
}

struct BusinessOfferPayload: Encodable {
    var title = ""
    var description = ""
    var discountLabel = ""
    var promoCode: String?
    var endsAt: Date?
    var isActive = true
    enum CodingKeys: String, CodingKey {
        case title, description
        case discountLabel = "discount_label", promoCode = "promo_code", endsAt = "ends_at", isActive = "is_active"
    }
}

struct BusinessImpressum: Codable, Hashable {
    let legalName: String?
    let representedBy: String?
    let address: String?
    let uidNumber: String?
    let email: String?
    let phone: String?
    var isEmpty: Bool { [legalName, representedBy, address, uidNumber].allSatisfy { ($0 ?? "").isEmpty } }
    enum CodingKeys: String, CodingKey {
        case address, email, phone
        case legalName = "legal_name", representedBy = "represented_by", uidNumber = "uid_number"
    }
}

struct BusinessStats: Codable {
    struct Day: Codable, Identifiable {
        let day: String
        let views: Int
        let actions: Int
        var id: String { day }
        var date: Date {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: day) ?? Date()
        }
    }
    let days: Int
    let maxDays: Int
    let totals: [String: Int]
    let series: [Day]
    var views: Int { totals["view"] ?? 0 }
    var actions: Int { totals.filter { $0.key != "view" }.values.reduce(0, +) }
    enum CodingKeys: String, CodingKey { case days, totals, series; case maxDays = "max_days" }
}

struct BusinessPlanInfo: Codable {
    struct Limits: Codable {
        let services: Int
        let offers: Int
        let quickReplies: Int
        let statsDays: Int
        let documents: Bool
        let aiReceptionist: Bool
        let teamMembers: Int
        enum CodingKeys: String, CodingKey {
            case services, offers, documents
            case quickReplies = "quick_replies", statsDays = "stats_days"
            case aiReceptionist = "ai_receptionist", teamMembers = "team_members"
        }
    }
    let plan: String
    let effectivePlan: String
    let planExpiresAt: Date?
    let planSource: String?
    let boostUntil: Date?
    let isBoosted: Bool
    let limits: Limits
    let usage: [String: Int]
    let productIDs: [String]
    var tier: BusinessPlanTier { BusinessPlanTier(rawValue: effectivePlan) ?? .free }
    enum CodingKeys: String, CodingKey {
        case plan, limits, usage
        case effectivePlan = "effective_plan", planExpiresAt = "plan_expires_at", planSource = "plan_source"
        case boostUntil = "boost_until", isBoosted = "is_boosted", productIDs = "product_ids"
    }
}

struct BusinessClubMember: Codable, Identifiable, Hashable {
    let id: String
    let status: String
    let business: BusinessSummary
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case id, status, business; case createdAt = "created_at" }
}

enum BusinessTrackEvent: String {
    case view, call, website, route, message, booking, offer, share
}
