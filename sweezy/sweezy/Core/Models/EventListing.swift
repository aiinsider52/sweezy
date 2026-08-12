import Foundation
import SwiftUI

enum EventCategory: String, Codable, CaseIterable, Identifiable {
    case community, kids, education, career, legal, health, language, culture, sports, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .community: return "events.category.community".localized
        case .kids: return "events.category.kids".localized
        case .education: return "events.category.education".localized
        case .career: return "events.category.career".localized
        case .legal: return "events.category.legal".localized
        case .health: return "events.category.health".localized
        case .language: return "events.category.language".localized
        case .culture: return "events.category.culture".localized
        case .sports: return "events.category.sports".localized
        case .other: return "events.category.other".localized
        }
    }

    var icon: String {
        switch self {
        case .community: return "person.3.fill"
        case .kids: return "figure.and.child.holdinghands"
        case .education: return "book.closed.fill"
        case .career: return "briefcase.fill"
        case .legal: return "scale.3d"
        case .health: return "cross.case.fill"
        case .language: return "globe"
        case .culture: return "music.note.house.fill"
        case .sports: return "figure.run"
        case .other: return "calendar"
        }
    }

    var color: Color {
        switch self {
        case .community: return .cyan
        case .kids: return .pink
        case .education: return .indigo
        case .career: return .orange
        case .legal: return .brown
        case .health: return .red
        case .language: return .green
        case .culture: return .purple
        case .sports: return .blue
        case .other: return .gray
        }
    }
}

enum EventListingStatus: String, Codable {
    case pending, approved, rejected
}

struct EventListing: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let category: EventCategory
    let canton: String
    let city: String
    let venueName: String?
    let address: String?
    let startsAt: Date?
    let endsAt: Date?
    let isFree: Bool
    let isPrivate: Bool
    let priceInfo: String?
    let contactType: ContactType
    let contactValue: String?
    let organizerName: String
    let status: EventListingStatus
    let rejectionReason: String?
    let viewCount: Int
    let isVerified: Bool
    let reportCount: Int
    let lastModeratedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, title, description, category, canton, city, address, status
        case venueName = "venue_name"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case isFree = "is_free"
        case isPrivate = "is_private"
        case priceInfo = "price_info"
        case contactType = "contact_type"
        case contactValue = "contact_value"
        case organizerName = "organizer_name"
        case rejectionReason = "rejection_reason"
        case viewCount = "view_count"
        case isVerified = "is_verified"
        case reportCount = "report_count"
        case lastModeratedAt = "last_moderated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decode(String.self, forKey: .description)
        category = (try? c.decode(EventCategory.self, forKey: .category)) ?? .other
        canton = try c.decode(String.self, forKey: .canton)
        city = (try? c.decode(String.self, forKey: .city)) ?? ""
        venueName = try? c.decode(String.self, forKey: .venueName)
        address = try? c.decode(String.self, forKey: .address)
        isFree = (try? c.decode(Bool.self, forKey: .isFree)) ?? true
        isPrivate = (try? c.decode(Bool.self, forKey: .isPrivate)) ?? false
        priceInfo = try? c.decode(String.self, forKey: .priceInfo)
        contactType = (try? c.decode(ContactType.self, forKey: .contactType)) ?? .telegram
        contactValue = try? c.decode(String.self, forKey: .contactValue)
        organizerName = (try? c.decode(String.self, forKey: .organizerName)) ?? "—"
        status = (try? c.decode(EventListingStatus.self, forKey: .status)) ?? .pending
        rejectionReason = try? c.decode(String.self, forKey: .rejectionReason)
        viewCount = (try? c.decode(Int.self, forKey: .viewCount)) ?? 0
        isVerified = (try? c.decode(Bool.self, forKey: .isVerified)) ?? false
        reportCount = (try? c.decode(Int.self, forKey: .reportCount)) ?? 0

        if let raw = try? c.decode(String.self, forKey: .startsAt) {
            startsAt = Self.parseDate(raw)
        } else {
            startsAt = nil
        }

        if let raw = try? c.decode(String.self, forKey: .endsAt) {
            endsAt = Self.parseDate(raw)
        } else {
            endsAt = nil
        }

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
}

extension EventListing {
    var freshnessDate: Date? { lastModeratedAt ?? updatedAt ?? createdAt }

    var freshnessText: String {
        guard let date = freshnessDate else { return "Дата актуальності не вказана" }
        let days = max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
        if days == 0 { return "Перевірено сьогодні" }
        if days == 1 { return "Перевірено вчора" }
        return "Перевірено \(days) дн. тому"
    }
}

struct EventListingCreate: Codable {
    var title: String
    var description: String
    var category: EventCategory
    var canton: String
    var city: String
    var venueName: String?
    var address: String?
    var startsAt: Date
    var endsAt: Date?
    var isFree: Bool
    var isPrivate: Bool = false
    var priceInfo: String?
    var contactType: ContactType
    var contactValue: String
    var organizerName: String

    private enum CodingKeys: String, CodingKey {
        case title, description, category, canton, city, address
        case venueName = "venue_name"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case isFree = "is_free"
        case isPrivate = "is_private"
        case priceInfo = "price_info"
        case contactType = "contact_type"
        case contactValue = "contact_value"
        case organizerName = "organizer_name"
    }
}

struct EventListingUpdate: Codable {
    var title: String?
    var description: String?
    var venueName: String?
    var address: String?
    var startsAt: Date?
    var endsAt: Date?
    var isFree: Bool?
    var isPrivate: Bool?
    var priceInfo: String?

    private enum CodingKeys: String, CodingKey {
        case title, description, address
        case venueName = "venue_name"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case isFree = "is_free"
        case isPrivate = "is_private"
        case priceInfo = "price_info"
    }
}

struct EventListingPage: Decodable {
    let items: [EventListing]
    let total: Int
    let page: Int
    let perPage: Int
    let pages: Int

    private enum CodingKeys: String, CodingKey {
        case items, total, page, pages
        case perPage = "per_page"
    }
}
