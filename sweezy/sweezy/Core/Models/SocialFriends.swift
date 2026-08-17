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
  let moderationStatus: String
  let moderationReason: String?
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
    case moderationStatus = "moderation_status"
    case moderationReason = "moderation_reason"
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

  init(
    userID: String, displayName: String, canton: String, city: String, bio: String,
    interests: [SocialInterest], languages: [String], meetupFormats: [MeetupFormat],
    availability: [SocialAvailability] = [.flexible], ageBand: String? = nil,
    arrivalYear: Int? = nil, avatarURL: String? = nil, isVisible: Bool = true,
    openToFriends: Bool = true, isVerified: Bool = false, matchScore: Int = 0,
    moderationStatus: String = "approved", moderationReason: String? = nil,
    matchReasons: [String] = [], distanceKM: Int? = nil, residencyStage: String = "established",
    sharedInterests: [SocialInterest] = [], connectionState: String = "none",
    connectionID: String? = nil, conversationID: String? = nil, contextEventID: String? = nil,
    createdAt: Date = Date(), updatedAt: Date = Date()
  ) {
    self.userID = userID
    self.displayName = displayName
    self.canton = canton
    self.city = city
    self.bio = bio
    self.interests = interests
    self.languages = languages
    self.meetupFormats = meetupFormats
    self.availability = availability
    self.ageBand = ageBand
    self.arrivalYear = arrivalYear
    self.avatarURL = avatarURL
    self.isVisible = isVisible
    self.openToFriends = openToFriends
    self.isVerified = isVerified
    self.moderationStatus = moderationStatus
    self.moderationReason = moderationReason
    self.matchScore = matchScore
    self.matchReasons = matchReasons
    self.distanceKM = distanceKM
    self.residencyStage = residencyStage
    self.sharedInterests = sharedInterests
    self.connectionState = connectionState
    self.connectionID = connectionID
    self.conversationID = conversationID
    self.contextEventID = contextEventID
    self.createdAt = createdAt
    self.updatedAt = updatedAt
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
    moderationStatus = (try? c.decode(String.self, forKey: .moderationStatus)) ?? "approved"
    moderationReason = try? c.decode(String.self, forKey: .moderationReason)
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

#if DEBUG
enum SocialFriendPreviewFixtures {
  static let profiles: [SocialProfile] = [
    profile("anna", "Anna Keller", "ZH", "Zürich", "Люблю ранкові прогулянки біля озера, каву та камерні концерти.", [.hiking, .music, .food], ["DE", "UK", "EN"], [.coffee, .walk], 96, 4, true, 2021),
    profile("dmytro", "Dmytro Melnyk", "ZH", "Winterthur", "Працюю в IT, граю у теніс і шукаю компанію для хайкінгу на вихідних.", [.technology, .sports, .hiking], ["UK", "DE", "EN"], [.activity, .event], 91, 18, true, 2023),
    profile("sofia", "Sofia Rossi", "TI", "Lugano", "Фотографую міста, вчу українську й організовую невеликі культурні зустрічі.", [.photography, .art, .languages], ["IT", "EN", "UK"], [.coffee, .event], 88, 42, false, 2019),
    profile("markus", "Markus Frei", "BE", "Bern", "Молодий батько, велосипедист і волонтер. Завжди за сімейну прогулянку.", [.family, .sports, .volunteering], ["DE", "FR", "EN"], [.family, .walk], 84, 7, true, 2017),
    profile("olena", "Olena Hrytsenko", "VD", "Lausanne", "Нещодавно переїхала. Цікавлять французька, книжкові клуби та подорожі Швейцарією.", [.books, .languages, .travel], ["UK", "FR", "EN"], [.coffee, .event], 82, 29, false, 2026),
    profile("lucas", "Lucas Meier", "BS", "Basel", "Дизайнер, музикант і фанат музеїв. Шукаю людей для творчих проєктів.", [.art, .music, .technology], ["DE", "EN", "FR"], [.event, .online], 79, 51, true, 2020),
    profile("iryna", "Iryna Bondar", "LU", "Luzern", "Обожнюю гори, йогу та неспішні розмови за кавою.", [.hiking, .wellness, .travel], ["UK", "DE"], [.walk, .coffee], 77, 12, false, 2024),
    profile("nicolas", "Nicolas Dubois", "GE", "Genève", "Підприємець у сфері sustainability. Відкритий до спорту, нетворкінгу й волонтерства.", [.business, .sports, .volunteering], ["FR", "EN", "DE"], [.activity, .event], 73, 66, true, 2016),
  ]

  private static func profile(
    _ id: String, _ name: String, _ canton: String, _ city: String, _ bio: String,
    _ interests: [SocialInterest], _ languages: [String], _ formats: [MeetupFormat],
    _ score: Int, _ distance: Int, _ verified: Bool, _ arrivalYear: Int
  ) -> SocialProfile {
    SocialProfile(
      userID: "preview-\(id)", displayName: name, canton: canton, city: city, bio: bio,
      interests: interests, languages: languages, meetupFormats: formats,
      availability: [.weekdayEvening, .weekend], ageBand: "25-34", arrivalYear: arrivalYear,
      isVerified: verified, matchScore: score,
      matchReasons: ["Спільні інтереси", "Зручна відстань", "Спільна мова"],
      distanceKM: distance, residencyStage: arrivalYear >= 2025 ? "newcomer" : "established",
      sharedInterests: Array(interests.prefix(3)))
  }
}
#endif

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

struct SocialSwipeDeck: Codable {
  let items: [SocialProfile]
  let likesRemaining: Int?
  let weeklyLimit: Int?
  let isPremium: Bool
  let resetAt: Date?
  enum CodingKeys: String, CodingKey {
    case items
    case likesRemaining = "likes_remaining"
    case weeklyLimit = "weekly_limit"
    case isPremium = "is_premium"
    case resetAt = "reset_at"
  }
}

struct SocialSwipeResult: Codable {
  let targetID: String
  let decision: String
  let isMatch: Bool
  let connectionID, conversationID: String?
  let likesRemaining: Int?
  enum CodingKeys: String, CodingKey {
    case decision
    case targetID = "target_id"
    case isMatch = "is_match"
    case connectionID = "connection_id"
    case conversationID = "conversation_id"
    case likesRemaining = "likes_remaining"
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

struct SocialProfileVisitor: Codable, Identifiable {
  let profile: SocialProfile
  let visitCount: Int
  let lastVisitedAt: Date
  var id: String { profile.id }
  enum CodingKeys: String, CodingKey {
    case profile
    case visitCount = "visit_count"
    case lastVisitedAt = "last_visited_at"
  }
}
