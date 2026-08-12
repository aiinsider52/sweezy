import Foundation

enum SocialInterest: String, Codable, CaseIterable, Identifiable {
  case hiking, sports, books, music, art, food, travel, languages, technology, business, family,
    photography, gaming, wellness, volunteering
  var id: String { rawValue }
  var title: String {
    [
      "hiking": "Гори", "sports": "Спорт", "books": "Книги", "music": "Музика", "art": "Мистецтво",
      "food": "Їжа", "travel": "Подорожі", "languages": "Мови", "technology": "Технології",
      "business": "Бізнес", "family": "Сім’я", "photography": "Фото", "gaming": "Ігри",
      "wellness": "Wellness", "volunteering": "Волонтерство",
    ][rawValue] ?? rawValue
  }
  var icon: String {
    [
      "hiking": "mountain.2.fill", "sports": "figure.run", "books": "books.vertical.fill",
      "music": "music.note", "art": "paintpalette.fill", "food": "fork.knife", "travel": "airplane",
      "languages": "globe", "technology": "cpu.fill", "business": "briefcase.fill",
      "family": "figure.2.and.child.holdinghands", "photography": "camera.fill",
      "gaming": "gamecontroller.fill", "wellness": "heart.fill",
      "volunteering": "hands.sparkles.fill",
    ][rawValue] ?? "sparkles"
  }
}

enum MeetupFormat: String, Codable, CaseIterable, Identifiable {
  case coffee, walk, activity, event, online, family
  var id: String { rawValue }
  var title: String {
    [
      "coffee": "Кава", "walk": "Прогулянка", "activity": "Активність", "event": "Подія",
      "online": "Онлайн", "family": "З дітьми",
    ][rawValue] ?? rawValue
  }
}

enum SocialAvailability: String, Codable, CaseIterable, Identifiable {
  case weekdayMorning = "weekday_morning"
  case weekdayEvening = "weekday_evening"
  case weekend, flexible
  var id: String { rawValue }
  var title: String {
    [
      "weekday_morning": "Будні зранку", "weekday_evening": "Будні ввечері", "weekend": "Вихідні",
      "flexible": "Гнучко",
    ][rawValue] ?? rawValue
  }
  var icon: String {
    [
      "weekday_morning": "sunrise.fill", "weekday_evening": "moon.stars.fill",
      "weekend": "calendar", "flexible": "clock.arrow.2.circlepath",
    ][rawValue] ?? "clock"
  }
}

enum SocialAgeBand: String, Codable, CaseIterable, Identifiable {
  case age18to24 = "18-24"
  case age25to34 = "25-34"
  case age35to44 = "35-44"
  case age45to54 = "45-54"
  case age55plus = "55+"
  var id: String { rawValue }
}

struct SocialProfile: Codable, Identifiable, Equatable {
  let userID, displayName, canton, city, bio: String
  let interests: [SocialInterest]
  let languages: [String]
  let meetupFormats: [MeetupFormat]
  let availability: [SocialAvailability]
  let ageBand: String?
  let arrivalYear: Int?
  let avatarURL: String?
  let isVisible, openToFriends, isVerified: Bool
  let matchScore: Int
  let matchReasons: [String]
  let distanceKM: Int?
  let residencyStage: String
  let sharedInterests: [SocialInterest]
  let connectionState: String
  let connectionID, conversationID, contextEventID: String?
  let createdAt, updatedAt: Date
  var id: String { userID }
  var initials: String {
    displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
      .uppercased()
  }
  enum CodingKeys: String, CodingKey {
    case canton, city, bio, interests, languages, availability
    case userID = "user_id"
    case displayName = "display_name"
    case meetupFormats = "meetup_formats"
    case ageBand = "age_band"
    case arrivalYear = "arrival_year"
    case avatarURL = "avatar_url"
    case isVisible = "is_visible"
    case openToFriends = "open_to_friends"
    case isVerified = "is_verified"
    case matchScore = "match_score"
    case matchReasons = "match_reasons"
    case distanceKM = "distance_km"
    case residencyStage = "residency_stage"
    case sharedInterests = "shared_interests"
    case connectionState = "connection_state"
    case connectionID = "connection_id"
    case conversationID = "conversation_id"
    case contextEventID = "context_event_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    userID = try c.decode(String.self, forKey: .userID)
    displayName = try c.decode(String.self, forKey: .displayName)
    canton = try c.decode(String.self, forKey: .canton)
    city = try c.decode(String.self, forKey: .city)
    bio = try c.decode(String.self, forKey: .bio)
    interests = try c.decode([SocialInterest].self, forKey: .interests)
    languages = try c.decode([String].self, forKey: .languages)
    meetupFormats = try c.decode([MeetupFormat].self, forKey: .meetupFormats)
    availability = (try? c.decode([SocialAvailability].self, forKey: .availability)) ?? [.flexible]
    ageBand = try? c.decode(String.self, forKey: .ageBand)
    arrivalYear = try? c.decode(Int.self, forKey: .arrivalYear)
    avatarURL = try? c.decode(String.self, forKey: .avatarURL)
    isVisible = (try? c.decode(Bool.self, forKey: .isVisible)) ?? true
    openToFriends = (try? c.decode(Bool.self, forKey: .openToFriends)) ?? true
    isVerified = (try? c.decode(Bool.self, forKey: .isVerified)) ?? false
    matchScore = (try? c.decode(Int.self, forKey: .matchScore)) ?? 0
    matchReasons = (try? c.decode([String].self, forKey: .matchReasons)) ?? []
    distanceKM = try? c.decode(Int.self, forKey: .distanceKM)
    residencyStage = (try? c.decode(String.self, forKey: .residencyStage)) ?? "established"
    sharedInterests = (try? c.decode([SocialInterest].self, forKey: .sharedInterests)) ?? []
    connectionState = (try? c.decode(String.self, forKey: .connectionState)) ?? "none"
    connectionID = try? c.decode(String.self, forKey: .connectionID)
    conversationID = try? c.decode(String.self, forKey: .conversationID)
    contextEventID = try? c.decode(String.self, forKey: .contextEventID)
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    updatedAt = try c.decode(Date.self, forKey: .updatedAt)
  }
}

struct SocialProfilePage: Codable {
  let items: [SocialProfile]
  let total, page, perPage, pages: Int
  let isLimited: Bool?
  let visibleLimit: Int?
  let advancedFiltersAvailable: Bool?
  let requestsRemaining: Int?
  enum CodingKeys: String, CodingKey {
    case items, total, page, pages
    case perPage = "per_page"
    case isLimited = "is_limited"
    case visibleLimit = "visible_limit"
    case advancedFiltersAvailable = "advanced_filters_available"
    case requestsRemaining = "requests_remaining"
  }
}

struct SocialProfileDraft: Codable {
  var displayName = "", canton = "ZH", city = "Zürich", bio = ""
  var interests: [SocialInterest] = [.hiking, .travel]
  var languages = ["UK"]
  var meetupFormats: [MeetupFormat] = [.coffee, .event]
  var availability: [SocialAvailability] = [.flexible]
  var ageBand: String? = "25-34"
  var arrivalYear: Int? = Calendar.current.component(.year, from: Date())
  var latitude: Double?
  var longitude: Double?
  var avatarURL = ""
  var isVisible = true, openToFriends = true, guidelinesAccepted = true
  init() {}
  init(_ p: SocialProfile) {
    displayName = p.displayName
    canton = p.canton
    city = p.city
    bio = p.bio
    interests = p.interests
    languages = p.languages
    meetupFormats = p.meetupFormats
    availability = p.availability
    ageBand = p.ageBand
    arrivalYear = p.arrivalYear
    avatarURL = p.avatarURL ?? ""
    isVisible = p.isVisible
    openToFriends = p.openToFriends
  }
  enum CodingKeys: String, CodingKey {
    case canton, city, bio, interests, languages, availability, latitude, longitude
    case displayName = "display_name"
    case meetupFormats = "meetup_formats"
    case ageBand = "age_band"
    case arrivalYear = "arrival_year"
    case avatarURL = "avatar_url"
    case isVisible = "is_visible"
    case openToFriends = "open_to_friends"
    case guidelinesAccepted = "guidelines_accepted"
  }
}

struct FriendConnection: Codable, Identifiable, Equatable {
  let id, direction, status: String
  let message, contextEventID, conversationID: String?
  let sharedInterests: [SocialInterest]
  let otherProfile: SocialProfile
  let createdAt, updatedAt: Date
  enum CodingKeys: String, CodingKey {
    case id, direction, status, message
    case contextEventID = "context_event_id"
    case conversationID = "conversation_id"
    case sharedInterests = "shared_interests"
    case otherProfile = "other_profile"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

struct SocialEvent: Codable, Identifiable, Equatable {
  let eventID, title, category, canton, city: String
  let startsAt: Date
  let isFree: Bool
  let attendeeCount: Int
  let myStatus: String?
  let isPrivate, isRecommended, groupChatAvailable, canInvite: Bool
  let recommendationReason: String?
  var id: String { eventID }
  enum CodingKeys: String, CodingKey {
    case title, category, canton, city
    case eventID = "event_id"
    case startsAt = "starts_at"
    case isFree = "is_free"
    case attendeeCount = "attendee_count"
    case myStatus = "my_status"
    case isPrivate = "is_private"
    case isRecommended = "is_recommended"
    case groupChatAvailable = "group_chat_available"
    case canInvite = "can_invite"
    case recommendationReason = "recommendation_reason"
  }
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    eventID = try c.decode(String.self, forKey: .eventID)
    title = try c.decode(String.self, forKey: .title)
    category = try c.decode(String.self, forKey: .category)
    canton = try c.decode(String.self, forKey: .canton)
    city = try c.decode(String.self, forKey: .city)
    startsAt = try c.decode(Date.self, forKey: .startsAt)
    isFree = (try? c.decode(Bool.self, forKey: .isFree)) ?? true
    attendeeCount = (try? c.decode(Int.self, forKey: .attendeeCount)) ?? 0
    myStatus = try? c.decode(String.self, forKey: .myStatus)
    isPrivate = (try? c.decode(Bool.self, forKey: .isPrivate)) ?? false
    isRecommended = (try? c.decode(Bool.self, forKey: .isRecommended)) ?? false
    groupChatAvailable = (try? c.decode(Bool.self, forKey: .groupChatAvailable)) ?? false
    canInvite = (try? c.decode(Bool.self, forKey: .canInvite)) ?? false
    recommendationReason = try? c.decode(String.self, forKey: .recommendationReason)
  }
}

struct SocialEventMessage: Codable, Identifiable {
  let id, eventID, senderID, senderName, body: String
  let createdAt: Date
  enum CodingKeys: String, CodingKey {
    case id, body
    case eventID = "event_id"
    case senderID = "sender_id"
    case senderName = "sender_name"
    case createdAt = "created_at"
  }
}
