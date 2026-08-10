import Foundation

enum SocialInterest: String, Codable, CaseIterable, Identifiable {
    case hiking, sports, books, music, art, food, travel, languages, technology, business, family, photography, gaming, wellness, volunteering
    var id: String { rawValue }
    var title: String { ["hiking":"Гори", "sports":"Спорт", "books":"Книги", "music":"Музика", "art":"Мистецтво", "food":"Їжа", "travel":"Подорожі", "languages":"Мови", "technology":"Технології", "business":"Бізнес", "family":"Сім’я", "photography":"Фото", "gaming":"Ігри", "wellness":"Wellness", "volunteering":"Волонтерство"][rawValue] ?? rawValue }
    var icon: String { ["hiking":"mountain.2.fill", "sports":"figure.run", "books":"books.vertical.fill", "music":"music.note", "art":"paintpalette.fill", "food":"fork.knife", "travel":"airplane", "languages":"globe", "technology":"cpu.fill", "business":"briefcase.fill", "family":"figure.2.and.child.holdinghands", "photography":"camera.fill", "gaming":"gamecontroller.fill", "wellness":"heart.fill", "volunteering":"hands.sparkles.fill"][rawValue] ?? "sparkles" }
}

enum MeetupFormat: String, Codable, CaseIterable, Identifiable {
    case coffee, walk, activity, event, online, family
    var id: String { rawValue }
    var title: String { ["coffee":"Кава", "walk":"Прогулянка", "activity":"Активність", "event":"Подія", "online":"Онлайн", "family":"З дітьми"][rawValue] ?? rawValue }
}

struct SocialProfile: Codable, Identifiable, Equatable {
    let userID, displayName, canton, city, bio: String
    let interests: [SocialInterest]
    let languages: [String]
    let meetupFormats: [MeetupFormat]
    let avatarURL: String?
    let isVisible, openToFriends, isVerified: Bool
    let matchScore: Int
    let sharedInterests: [SocialInterest]
    let connectionState: String
    let connectionID, conversationID, contextEventID: String?
    let createdAt, updatedAt: Date
    var id: String { userID }
    var initials: String { displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
    enum CodingKeys: String, CodingKey { case canton, city, bio, interests, languages; case userID="user_id", displayName="display_name", meetupFormats="meetup_formats", avatarURL="avatar_url", isVisible="is_visible", openToFriends="open_to_friends", isVerified="is_verified", matchScore="match_score", sharedInterests="shared_interests", connectionState="connection_state", connectionID="connection_id", conversationID="conversation_id", contextEventID="context_event_id", createdAt="created_at", updatedAt="updated_at" }
}

struct SocialProfilePage: Codable { let items: [SocialProfile]; let total, page, perPage, pages: Int; enum CodingKeys: String, CodingKey { case items,total,page,pages; case perPage="per_page" } }

struct SocialProfileDraft: Codable {
    var displayName = "", canton = "ZH", city = "Zürich", bio = ""
    var interests: [SocialInterest] = [.hiking, .travel]
    var languages = ["UK"]
    var meetupFormats: [MeetupFormat] = [.coffee, .event]
    var avatarURL = ""
    var isVisible = true, openToFriends = true, guidelinesAccepted = true
    init() {}
    init(_ p: SocialProfile) { displayName=p.displayName; canton=p.canton; city=p.city; bio=p.bio; interests=p.interests; languages=p.languages; meetupFormats=p.meetupFormats; avatarURL=p.avatarURL ?? ""; isVisible=p.isVisible; openToFriends=p.openToFriends }
    enum CodingKeys: String, CodingKey { case canton,city,bio,interests,languages; case displayName="display_name", meetupFormats="meetup_formats", avatarURL="avatar_url", isVisible="is_visible", openToFriends="open_to_friends", guidelinesAccepted="guidelines_accepted" }
}

struct FriendConnection: Codable, Identifiable, Equatable {
    let id, direction, status: String; let message, contextEventID, conversationID: String?; let sharedInterests: [SocialInterest]; let otherProfile: SocialProfile; let createdAt, updatedAt: Date
    enum CodingKeys: String, CodingKey { case id,direction,status,message; case contextEventID="context_event_id", conversationID="conversation_id", sharedInterests="shared_interests", otherProfile="other_profile", createdAt="created_at", updatedAt="updated_at" }
}

struct SocialEvent: Codable, Identifiable, Equatable {
    let eventID, title, category, canton, city: String; let startsAt: Date; let isFree: Bool; let attendeeCount: Int; let myStatus: String?
    var id: String { eventID }
    enum CodingKeys: String, CodingKey { case title,category,canton,city; case eventID="event_id", startsAt="starts_at", isFree="is_free", attendeeCount="attendee_count", myStatus="my_status" }
}
