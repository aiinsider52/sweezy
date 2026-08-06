import Foundation

struct PublicProfileListing: Codable, Identifiable, Equatable {
    let id: String
    let listingType: String
    let title: String
    let category: String
    let canton: String
    let priceInfo: String?
    let priceCHF: Int?
    let isFree: Bool
    let imageURLs: [String]
    let isVerified: Bool

    private enum CodingKeys: String, CodingKey {
        case id, title, category, canton
        case listingType = "listing_type"
        case priceInfo = "price_info"
        case priceCHF = "price_chf"
        case isFree = "is_free"
        case imageURLs = "image_urls"
        case isVerified = "is_verified"
    }
}

struct PublicUserProfile: Codable, Identifiable, Equatable {
    let userID: String
    let displayName: String
    let initials: String
    let avatarURL: String?
    let registeredMonth: String
    let isVerified: Bool
    let trustBadges: [String]
    let averageRating: Double?
    let reviewCount: Int
    let activeListings: [PublicProfileListing]
    let viewerHasBlocked: Bool

    var id: String { userID }

    private enum CodingKeys: String, CodingKey {
        case initials
        case userID = "user_id"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case registeredMonth = "registered_month"
        case isVerified = "is_verified"
        case trustBadges = "trust_badges"
        case averageRating = "average_rating"
        case reviewCount = "review_count"
        case activeListings = "active_listings"
        case viewerHasBlocked = "viewer_has_blocked"
    }
}
