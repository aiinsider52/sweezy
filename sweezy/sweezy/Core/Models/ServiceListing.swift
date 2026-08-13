import Foundation
import SwiftUI

// MARK: - Service Category

enum ServiceCategory: String, Codable, CaseIterable, Identifiable {
    case translation, documents, tutoring, it, beauty,
         cleaning, accounting, legal, childcare, moving, repair, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .translation: return "marketplace.category.translation".localized
        case .documents:   return "marketplace.category.documents".localized
        case .tutoring:    return "marketplace.category.tutoring".localized
        case .it:          return "marketplace.category.it".localized
        case .beauty:      return "marketplace.category.beauty".localized
        case .cleaning:    return "marketplace.category.cleaning".localized
        case .accounting:  return "marketplace.category.accounting".localized
        case .legal:       return "marketplace.category.legal".localized
        case .childcare:   return "marketplace.category.childcare".localized
        case .moving:      return "marketplace.category.moving".localized
        case .repair:      return "marketplace.category.repair".localized
        case .other:       return "marketplace.category.other".localized
        }
    }

    var icon: String {
        switch self {
        case .translation: return "character.book.closed.fill"
        case .documents:   return "doc.text.fill"
        case .tutoring:    return "graduationcap.fill"
        case .it:          return "desktopcomputer"
        case .beauty:      return "sparkles"
        case .cleaning:    return "bubbles.and.sparkles.fill"
        case .accounting:  return "chart.bar.doc.horizontal.fill"
        case .legal:       return "scale.3d"
        case .childcare:   return "figure.and.child.holdinghands"
        case .moving:      return "shippingbox.fill"
        case .repair:      return "wrench.and.screwdriver.fill"
        case .other:       return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .translation: return .blue
        case .documents:   return .indigo
        case .tutoring:    return .purple
        case .it:          return .cyan
        case .beauty:      return .pink
        case .cleaning:    return .mint
        case .accounting:  return .orange
        case .legal:       return .brown
        case .childcare:   return .teal
        case .moving:      return .yellow
        case .repair:      return .red
        case .other:       return .gray
        }
    }
}

// MARK: - Listing Type

enum ListingType: String, Codable {
    case service, item
}

// MARK: - Item Category (goods marketplace)

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case furniture, electronics, kids, clothing, home, sports, books, free, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .furniture:   return "marketplace.item_category.furniture".localized
        case .electronics: return "marketplace.item_category.electronics".localized
        case .kids:        return "marketplace.item_category.kids".localized
        case .clothing:    return "marketplace.item_category.clothing".localized
        case .home:        return "marketplace.item_category.home".localized
        case .sports:      return "marketplace.item_category.sports".localized
        case .books:       return "marketplace.item_category.books".localized
        case .free:        return "marketplace.item_category.free".localized
        case .other:       return "marketplace.category.other".localized
        }
    }

    var icon: String {
        switch self {
        case .furniture:   return "sofa.fill"
        case .electronics: return "laptopcomputer"
        case .kids:        return "stroller.fill"
        case .clothing:    return "tshirt.fill"
        case .home:        return "house.fill"
        case .sports:      return "figure.run"
        case .books:       return "books.vertical.fill"
        case .free:        return "gift.fill"
        case .other:       return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .furniture:   return Theme.Colors.primary
        case .electronics: return .indigo
        case .kids:        return Theme.Colors.accent
        case .clothing:    return .pink
        case .home:        return .teal
        case .sports:      return Theme.Colors.primaryLight
        case .books:       return .brown
        case .free:        return Theme.Colors.accentCoral
        case .other:       return .gray
        }
    }
}

// MARK: - Item Condition

enum ItemCondition: String, Codable, CaseIterable, Identifiable {
    case new
    case likeNew = "like_new"
    case used

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .new:     return "marketplace.condition.new".localized
        case .likeNew: return "marketplace.condition.like_new".localized
        case .used:    return "marketplace.condition.used".localized
        }
    }
}

// MARK: - Contact Type

enum ContactType: String, Codable, CaseIterable, Identifiable {
    case telegram, whatsapp, email, phone

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .telegram:  return "Telegram"
        case .whatsapp:  return "WhatsApp"
        case .email:     return "Email"
        case .phone:     return "marketplace.contact.phone".localized
        }
    }

    var icon: String {
        switch self {
        case .telegram:  return "paperplane.fill"
        case .whatsapp:  return "phone.bubble.fill"
        case .email:     return "envelope.fill"
        case .phone:     return "phone.fill"
        }
    }

    var placeholder: String {
        switch self {
        case .telegram:  return "@username"
        case .whatsapp:  return "+41 79 123 45 67"
        case .email:     return "email@example.com"
        case .phone:     return "+41 79 123 45 67"
        }
    }
}

// MARK: - Listing Status

enum ListingStatus: String, Codable {
    case pending, approved, rejected
}

// MARK: - Service Listing

struct ServiceListing: Codable, Identifiable, Equatable {
    let id: String
    let listingType: ListingType
    let title: String
    let description: String
    /// Raw category string from backend — ServiceCategory for services, ItemCategory for items
    let rawCategory: String
    var category: ServiceCategory { ServiceCategory(rawValue: rawCategory) ?? .other }
    let canton: String
    let priceInfo: String?
    let priceChf: Int?
    let isFree: Bool
    let condition: ItemCondition?
    let negotiable: Bool
    let contactType: ContactType
    let contactValue: String?
    let imageURLs: [String]
    let authorID: String?
    let authorName: String
    let status: ListingStatus
    let viewCount: Int
    let rejectionReason: String?
    let isVerified: Bool
    let isFeatured: Bool
    let featuredUntil: Date?
    let trustLevel: String
    let partnerLabel: String?
    let moderationNotes: String?
    let isExpert: Bool
    let expertSpecialty: String?
    let expertLanguages: [String]
    let responseTimeHours: Int?
    let expertBio: String?
    let reportCount: Int
    let lastModeratedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, title, description, canton, negotiable, condition
        case rawCategory = "category"
        case listingType = "listing_type"
        case priceInfo = "price_info"
        case priceChf = "price_chf"
        case isFree = "is_free"
        case contactType = "contact_type"
        case contactValue = "contact_value"
        case imageURLs = "image_urls"
        case authorID = "author_id"
        case authorName = "author_name"
        case status
        case viewCount = "view_count"
        case rejectionReason = "rejection_reason"
        case isVerified = "is_verified"
        case isFeatured = "is_featured"
        case featuredUntil = "featured_until"
        case trustLevel = "trust_level"
        case partnerLabel = "partner_label"
        case moderationNotes = "moderation_notes"
        case isExpert = "is_expert"
        case expertSpecialty = "expert_specialty"
        case expertLanguages = "expert_languages"
        case responseTimeHours = "response_time_hours"
        case expertBio = "expert_bio"
        case reportCount = "report_count"
        case lastModeratedAt = "last_moderated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        listingType = (try? c.decode(ListingType.self, forKey: .listingType)) ?? .service
        title = try c.decode(String.self, forKey: .title)
        description = try c.decode(String.self, forKey: .description)
        rawCategory = (try? c.decode(String.self, forKey: .rawCategory)) ?? "other"
        canton = try c.decode(String.self, forKey: .canton)
        priceInfo = try? c.decode(String.self, forKey: .priceInfo)
        priceChf = try? c.decode(Int.self, forKey: .priceChf)
        isFree = (try? c.decode(Bool.self, forKey: .isFree)) ?? false
        condition = try? c.decode(ItemCondition.self, forKey: .condition)
        negotiable = (try? c.decode(Bool.self, forKey: .negotiable)) ?? false
        contactType = (try? c.decode(ContactType.self, forKey: .contactType)) ?? .telegram
        contactValue = try? c.decode(String.self, forKey: .contactValue)
        imageURLs = (try? c.decode([String].self, forKey: .imageURLs)) ?? []
        authorID = try? c.decode(String.self, forKey: .authorID)
        authorName = (try? c.decode(String.self, forKey: .authorName)) ?? "—"
        status = (try? c.decode(ListingStatus.self, forKey: .status)) ?? .pending
        viewCount = (try? c.decode(Int.self, forKey: .viewCount)) ?? 0
        rejectionReason = try? c.decode(String.self, forKey: .rejectionReason)
        isVerified = (try? c.decode(Bool.self, forKey: .isVerified)) ?? false
        isFeatured = (try? c.decode(Bool.self, forKey: .isFeatured)) ?? false
        if let raw = try? c.decode(String.self, forKey: .featuredUntil) {
            featuredUntil = Self.parseDate(raw)
        } else {
            featuredUntil = nil
        }
        trustLevel = (try? c.decode(String.self, forKey: .trustLevel)) ?? "community"
        partnerLabel = try? c.decode(String.self, forKey: .partnerLabel)
        moderationNotes = try? c.decode(String.self, forKey: .moderationNotes)
        isExpert = (try? c.decode(Bool.self, forKey: .isExpert)) ?? false
        expertSpecialty = try? c.decode(String.self, forKey: .expertSpecialty)
        expertLanguages = (try? c.decode([String].self, forKey: .expertLanguages)) ?? []
        responseTimeHours = try? c.decode(Int.self, forKey: .responseTimeHours)
        expertBio = try? c.decode(String.self, forKey: .expertBio)
        reportCount = (try? c.decode(Int.self, forKey: .reportCount)) ?? 0

        if let raw = try? c.decode(String.self, forKey: .createdAt) {
            createdAt = Self.parseDate(raw)
        } else {
            createdAt = nil
        }
        if let raw = try? c.decode(String.self, forKey: .updatedAt) {
            updatedAt = Self.parseDate(raw)
        } else {
            updatedAt = nil
        }
        if let raw = try? c.decode(String.self, forKey: .lastModeratedAt) {
            lastModeratedAt = Self.parseDate(raw)
        } else {
            lastModeratedAt = nil
        }
    }

    private static func parseDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    static func == (lhs: ServiceListing, rhs: ServiceListing) -> Bool {
        lhs.id == rhs.id
    }

    var trustBadges: [(text: String, color: Color)] {
        var badges: [(String, Color)] = []
        if isFeatured {
            badges.append((partnerLabel?.isEmpty == false ? partnerLabel! : "marketplace.badge.partner".localized, .orange))
        }
        if isVerified {
            badges.append(("marketplace.badge.verified".localized, .blue))
        }
        return badges
    }

    var expertSpecialtyEnum: ExpertSpecialty? {
        guard let raw = expertSpecialty else { return nil }
        return ExpertSpecialty(rawValue: raw)
    }

    var itemCategory: ItemCategory? {
        guard listingType == .item else { return nil }
        return ItemCategory(rawValue: rawCategory) ?? .other
    }

    // Unified category display helpers (work for both services and items)
    var categoryDisplayName: String { itemCategory?.displayName ?? category.displayName }
    var categoryIcon: String { itemCategory?.icon ?? category.icon }
    var categoryColor: Color { itemCategory?.color ?? category.color }

    /// "Free" / "CHF 250" / legacy text price for services
    var priceDisplay: String? {
        switch listingType {
        case .item:
            if isFree { return "marketplace.price.free".localized }
            guard let priceChf else { return nil }
            return "CHF \(priceChf)"
        case .service:
            return priceInfo
        }
    }

    var freshnessDate: Date? { lastModeratedAt ?? updatedAt ?? createdAt }

    var freshnessText: String {
        guard let date = freshnessDate else { return "Дата актуальності не вказана" }
        let days = max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
        if days == 0 { return "Перевірено сьогодні" }
        if days == 1 { return "Перевірено вчора" }
        return "Перевірено \(days) дн. тому"
    }

    var isStale: Bool {
        guard let date = freshnessDate else { return true }
        return date < Calendar.current.date(byAdding: .day, value: -45, to: Date())!
    }
}

// MARK: - Create Payload

struct ServiceListingCreate: Codable {
    var listingType: ListingType = .service
    var title: String
    var description: String
    /// Raw category value: ServiceCategory for services, ItemCategory for items
    var category: String
    var canton: String
    var priceInfo: String?
    var priceChf: Int?
    var isFree: Bool = false
    var condition: ItemCondition?
    var negotiable: Bool = false
    var contactType: ContactType
    var contactValue: String
    var authorName: String
    var imageURLs: [String]

    private enum CodingKeys: String, CodingKey {
        case title, description, category, canton, negotiable, condition
        case listingType = "listing_type"
        case priceInfo = "price_info"
        case priceChf = "price_chf"
        case isFree = "is_free"
        case contactType = "contact_type"
        case contactValue = "contact_value"
        case authorName = "author_name"
        case imageURLs = "image_urls"
    }
}

struct ServiceListingUpdate: Codable {
    var title: String?
    var description: String?
    var priceInfo: String?
    var priceChf: Int?
    var isFree: Bool?
    var condition: ItemCondition?
    var negotiable: Bool?
    var imageURLs: [String]?

    private enum CodingKeys: String, CodingKey {
        case title, description, negotiable, condition
        case priceInfo = "price_info"
        case priceChf = "price_chf"
        case isFree = "is_free"
        case imageURLs = "image_urls"
    }
}

// MARK: - Paginated Response

struct ServiceListingPage: Decodable {
    let items: [ServiceListing]
    let total: Int
    let page: Int
    let perPage: Int
    let pages: Int

    private enum CodingKeys: String, CodingKey {
        case items, total, page
        case perPage = "per_page"
        case pages
    }
}

struct MarketplaceProClient: Decodable, Identifiable {
    let conversationID: String
    let displayName: String
    let listingTitle: String
    let lastMessagePreview: String?
    let lastMessageAt: Date?
    var id: String { conversationID }
    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case displayName = "display_name"
        case listingTitle = "listing_title"
        case lastMessagePreview = "last_message_preview"
        case lastMessageAt = "last_message_at"
    }
}

struct MarketplaceProDashboard: Decodable {
    let totalListings, activeListings, totalViews, inquiries, publicationLimit: Int
    let proBadge: Bool
    let clients: [MarketplaceProClient]
    enum CodingKeys: String, CodingKey {
        case clients
        case totalListings = "total_listings"
        case activeListings = "active_listings"
        case totalViews = "total_views"
        case inquiries
        case publicationLimit = "publication_limit"
        case proBadge = "pro_badge"
    }
}

// MARK: - Swiss Cantons

enum SwissCanton {
    static let all: [(code: String, name: String)] = [
        ("all", "marketplace.canton.all".localized),
        ("ZH", "Zürich"), ("BE", "Bern"), ("LU", "Luzern"),
        ("UR", "Uri"), ("SZ", "Schwyz"), ("OW", "Obwalden"),
        ("NW", "Nidwalden"), ("GL", "Glarus"), ("ZG", "Zug"),
        ("FR", "Fribourg"), ("SO", "Solothurn"), ("BS", "Basel-Stadt"),
        ("BL", "Basel-Landschaft"), ("SH", "Schaffhausen"), ("AR", "Appenzell A.Rh."),
        ("AI", "Appenzell I.Rh."), ("SG", "St. Gallen"), ("GR", "Graubünden"),
        ("AG", "Aargau"), ("TG", "Thurgau"), ("TI", "Ticino"),
        ("VD", "Vaud"), ("VS", "Valais"), ("NE", "Neuchâtel"),
        ("GE", "Genève"), ("JU", "Jura"),
    ]
}

extension ServiceListing {
    var primaryImageURL: URL? {
        imageURLs.first.flatMap(APIClient.resolveMediaURL)
    }

    var resolvedImageURLs: [URL] {
        imageURLs.compactMap(APIClient.resolveMediaURL)
    }

    /// Stable local artwork for listings without uploaded media.
    /// Uses category-aware pools and a deterministic ID seed, so nearby cards do not repeat one placeholder.
    var marketplaceFallbackAsset: String {
        let pool: [String]
        switch category {
        case .moving, .repair, .cleaning:
            pool = ["marketplace-service-moving", "journey-place-housing", "cityhub-zurich-viadukt"]
        case .beauty:
            pool = ["marketplace-service-beauty", "cityhub-zurich-rietberg", "cityhub-zurich-kunsthaus"]
        case .childcare:
            pool = ["marketplace-service-family", "journey-place-community", "cityhub-zurich-lake"]
        case .it, .accounting:
            pool = ["marketplace-service-business", "journey-market-consultant", "journey-place-employment"]
        case .translation, .tutoring:
            pool = ["journey-place-education", "marketplace-service-business", "cityhub-zurich-landesmuseum"]
        case .documents, .legal:
            pool = ["journey-place-government", "marketplace-service-business", "cityhub-zurich-fraumuenster"]
        case .other:
            pool = ["marketplace-service-business", "marketplace-service-family", "cityhub-zurich-kreis4", "cityhub-zurich-limmat"]
        }

        let seed = id.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) % pool.count
        }
        return pool[seed]
    }
}
