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
    let title: String
    let description: String
    let category: ServiceCategory
    let canton: String
    let priceInfo: String?
    let contactType: ContactType
    let contactValue: String?
    let authorName: String
    let status: ListingStatus
    let viewCount: Int
    let rejectionReason: String?
    let createdAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, title, description, category, canton
        case priceInfo = "price_info"
        case contactType = "contact_type"
        case contactValue = "contact_value"
        case authorName = "author_name"
        case status
        case viewCount = "view_count"
        case rejectionReason = "rejection_reason"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decode(String.self, forKey: .description)
        category = (try? c.decode(ServiceCategory.self, forKey: .category)) ?? .other
        canton = try c.decode(String.self, forKey: .canton)
        priceInfo = try? c.decode(String.self, forKey: .priceInfo)
        contactType = (try? c.decode(ContactType.self, forKey: .contactType)) ?? .telegram
        contactValue = try? c.decode(String.self, forKey: .contactValue)
        authorName = (try? c.decode(String.self, forKey: .authorName)) ?? "—"
        status = (try? c.decode(ListingStatus.self, forKey: .status)) ?? .pending
        viewCount = (try? c.decode(Int.self, forKey: .viewCount)) ?? 0
        rejectionReason = try? c.decode(String.self, forKey: .rejectionReason)

        if let raw = try? c.decode(String.self, forKey: .createdAt) {
            createdAt = Self.parseDate(raw)
        } else {
            createdAt = nil
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
}

// MARK: - Create Payload

struct ServiceListingCreate: Codable {
    var title: String
    var description: String
    var category: ServiceCategory
    var canton: String
    var priceInfo: String?
    var contactType: ContactType
    var contactValue: String
    var authorName: String

    private enum CodingKeys: String, CodingKey {
        case title, description, category, canton
        case priceInfo = "price_info"
        case contactType = "contact_type"
        case contactValue = "contact_value"
        case authorName = "author_name"
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
