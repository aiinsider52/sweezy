import Foundation

struct BusinessProfile: Codable, Identifiable {
    let userID: String
    var displayName: String
    var legalName: String?
    var description: String
    var category: String
    var canton: String
    var city: String
    var address: String?
    var serviceArea: [String]
    var languages: [String]
    var logoURL: String?
    var coverURL: String?
    var phone: String?
    var email: String?
    var website: String?
    var uidNumber: String?
    var deliveryModes: [String]
    var cancellationPolicy: String?
    var paymentLink: String?
    let status: String
    let rejectionReason: String?
    let isVerified: Bool
    let submittedAt: Date?
    let reviewedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    var id: String { userID }

    enum CodingKeys: String, CodingKey {
        case description, category, canton, city, address, languages, phone, email, website, status
        case userID = "user_id"
        case displayName = "display_name"
        case legalName = "legal_name"
        case serviceArea = "service_area"
        case logoURL = "logo_url"
        case coverURL = "cover_url"
        case uidNumber = "uid_number"
        case deliveryModes = "delivery_modes"
        case cancellationPolicy = "cancellation_policy"
        case paymentLink = "payment_link"
        case rejectionReason = "rejection_reason"
        case isVerified = "is_verified"
        case submittedAt = "submitted_at"
        case reviewedAt = "reviewed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BusinessProfilePayload: Encodable {
    var displayName = ""
    var legalName: String?
    var description = ""
    var category = "other"
    var canton = "ZH"
    var city = "Zürich"
    var address: String?
    var serviceArea = ["ZH"]
    var languages = ["de"]
    var logoURL: String?
    var coverURL: String?
    var phone: String?
    var email: String?
    var website: String?
    var uidNumber: String?
    var deliveryModes = ["mobile"]
    var cancellationPolicy: String?
    var paymentLink: String?

    init() {}
    init(profile: BusinessProfile) {
        displayName = profile.displayName; legalName = profile.legalName; description = profile.description
        category = profile.category; canton = profile.canton; city = profile.city; address = profile.address
        serviceArea = profile.serviceArea; languages = profile.languages; logoURL = profile.logoURL
        coverURL = profile.coverURL; phone = profile.phone; email = profile.email; website = profile.website
        uidNumber = profile.uidNumber; deliveryModes = profile.deliveryModes
        cancellationPolicy = profile.cancellationPolicy; paymentLink = profile.paymentLink
    }
    enum CodingKeys: String, CodingKey {
        case description, category, canton, city, address, languages, phone, email, website
        case displayName = "display_name", legalName = "legal_name", serviceArea = "service_area"
        case logoURL = "logo_url", coverURL = "cover_url", uidNumber = "uid_number"
        case deliveryModes = "delivery_modes", cancellationPolicy = "cancellation_policy", paymentLink = "payment_link"
    }
}

struct BusinessAISettings: Codable {
    var aiEnabled: Bool
    var aiAutoReply: Bool
    var aiTone: String
    var aiBusinessFacts: String
    var aiInstructions: String
    var aiGreeting: String?
    var aiFAQ: [[String: String]]
    var aiHandoffTopics: [String]
    var aiAllowedLanguages: [String]
    enum CodingKeys: String, CodingKey {
        case aiEnabled = "ai_enabled", aiAutoReply = "ai_auto_reply", aiTone = "ai_tone"
        case aiBusinessFacts = "ai_business_facts", aiInstructions = "ai_instructions"
        case aiGreeting = "ai_greeting", aiFAQ = "ai_faq", aiHandoffTopics = "ai_handoff_topics"
        case aiAllowedLanguages = "ai_allowed_languages"
    }
    static let empty = BusinessAISettings(
        aiEnabled: true, aiAutoReply: false, aiTone: "friendly_professional",
        aiBusinessFacts: "", aiInstructions: "", aiGreeting: nil, aiFAQ: [],
        aiHandoffTopics: ["refund", "complaint", "legal"], aiAllowedLanguages: ["de", "uk"]
    )
}

struct BusinessServiceItem: Codable, Identifiable {
    let id: String
    let businessUserID: String
    var listingID: String?
    var title: String
    var description: String
    var category: String
    var durationMinutes: Int
    var priceCents: Int?
    var priceToCents: Int?
    var currency: String
    var deliveryMode: String
    var bufferMinutes: Int
    var isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    enum CodingKeys: String, CodingKey {
        case id, title, description, category, currency
        case businessUserID = "business_user_id", listingID = "listing_id", durationMinutes = "duration_minutes"
        case priceCents = "price_cents", priceToCents = "price_to_cents", deliveryMode = "delivery_mode"
        case bufferMinutes = "buffer_minutes", isActive = "is_active", createdAt = "created_at", updatedAt = "updated_at"
    }
    var priceText: String {
        guard let priceCents else { return "Ціна за домовленістю" }
        let from = Double(priceCents) / 100
        if let priceToCents { return String(format: "CHF %.2f–%.2f", from, Double(priceToCents) / 100) }
        return String(format: "CHF %.2f", from)
    }
}

struct BusinessServicePayload: Encodable {
    var listingID: String?
    var title = ""
    var description = ""
    var category = "other"
    var durationMinutes = 60
    var priceCents: Int?
    var priceToCents: Int?
    var currency = "CHF"
    var deliveryMode = "onsite"
    var bufferMinutes = 0
    var isActive = true
    enum CodingKeys: String, CodingKey {
        case title, description, category, currency
        case listingID = "listing_id"
        case durationMinutes = "duration_minutes", priceCents = "price_cents", priceToCents = "price_to_cents"
        case deliveryMode = "delivery_mode", bufferMinutes = "buffer_minutes", isActive = "is_active"
    }
}

struct BusinessAvailabilityRule: Codable, Identifiable {
    let id: String
    var weekday: Int
    var startTime: String
    var endTime: String
    var isActive: Bool
    enum CodingKeys: String, CodingKey { case id, weekday; case startTime = "start_time", endTime = "end_time", isActive = "is_active" }
}

struct BusinessAvailabilityPayload: Encodable {
    let weekday: Int
    let startTime: String
    let endTime: String
    let isActive: Bool
    enum CodingKeys: String, CodingKey { case weekday; case startTime = "start_time", endTime = "end_time", isActive = "is_active" }
}

struct BusinessLead: Codable, Identifiable {
    let id: String
    let businessUserID: String
    let conversationID: String?
    let customerUserID: String?
    var serviceID: String?
    var customerName: String
    var customerLanguage: String?
    var contactValue: String?
    var status: String
    var source: String
    var budgetCents: Int?
    var desiredAt: Date?
    var notes: String
    var nextAction: String?
    var nextActionAt: Date?
    var assigneeName: String?
    let createdAt: Date
    let updatedAt: Date
    enum CodingKeys: String, CodingKey {
        case id, status, source, notes
        case businessUserID = "business_user_id", conversationID = "conversation_id", customerUserID = "customer_user_id"
        case serviceID = "service_id", customerName = "customer_name", customerLanguage = "customer_language"
        case contactValue = "contact_value", budgetCents = "budget_cents", desiredAt = "desired_at"
        case nextAction = "next_action", nextActionAt = "next_action_at", assigneeName = "assignee_name"
        case createdAt = "created_at", updatedAt = "updated_at"
    }
}

struct BusinessLeadUpdatePayload: Encodable {
    var status: String?
    var notes: String?
    var nextAction: String?
    var nextActionAt: Date?
    enum CodingKeys: String, CodingKey { case status, notes; case nextAction = "next_action", nextActionAt = "next_action_at" }
}

struct BusinessClientItem: Codable, Identifiable {
    let id: String
    let businessUserID: String
    let customerUserID: String?
    var displayName: String
    var email: String?
    var phone: String?
    var language: String?
    var notes: String
    var tags: [String]
    let bookingCount: Int
    let completedCount: Int
    let totalSpendCents: Int
    let lastActivityAt: Date?
    let createdAt: Date
    let updatedAt: Date
    enum CodingKeys: String, CodingKey {
        case id, email, phone, language, notes, tags
        case businessUserID = "business_user_id", customerUserID = "customer_user_id", displayName = "display_name"
        case bookingCount = "booking_count", completedCount = "completed_count", totalSpendCents = "total_spend_cents"
        case lastActivityAt = "last_activity_at", createdAt = "created_at", updatedAt = "updated_at"
    }
}

struct BusinessClientPayload: Encodable {
    var displayName = ""
    var email: String?
    var phone: String?
    var language: String?
    var notes = ""
    var tags: [String] = []
    enum CodingKeys: String, CodingKey { case email, phone, language, notes, tags; case displayName = "display_name" }
}

struct BusinessBooking: Codable, Identifiable {
    let id: String
    let businessUserID: String
    let clientID: String?
    let leadID: String?
    let serviceID: String?
    let customerName: String
    var startsAt: Date
    var endsAt: Date
    var status: String
    var location: String?
    var notes: String
    var priceCents: Int?
    let currency: String
    var reminderMinutes: Int
    let createdAt: Date
    let updatedAt: Date
    let businessName: String?
    let serviceTitle: String?
    enum CodingKeys: String, CodingKey {
        case id, status, location, notes, currency
        case businessUserID = "business_user_id", clientID = "client_id", leadID = "lead_id", serviceID = "service_id"
        case customerName = "customer_name", startsAt = "starts_at", endsAt = "ends_at"
        case priceCents = "price_cents", reminderMinutes = "reminder_minutes", createdAt = "created_at", updatedAt = "updated_at"
        case businessName = "business_name", serviceTitle = "service_title"
    }
}

struct BusinessBookingPayload: Encodable {
    var clientID: String?
    var leadID: String?
    var serviceID: String?
    var customerName = ""
    var startsAt = Date().addingTimeInterval(3600)
    var endsAt = Date().addingTimeInterval(7200)
    var status = "confirmed"
    var location: String?
    var notes = ""
    var priceCents: Int?
    var currency = "CHF"
    var reminderMinutes = 1440
    enum CodingKeys: String, CodingKey {
        case status, location, notes, currency
        case clientID = "client_id", leadID = "lead_id", serviceID = "service_id", customerName = "customer_name"
        case startsAt = "starts_at", endsAt = "ends_at", priceCents = "price_cents", reminderMinutes = "reminder_minutes"
    }
}

struct BusinessQuickReply: Codable, Identifiable {
    let id: String
    var title: String
    var body: String
    var language: String
    var category: String
    var sortOrder: Int
    var isActive: Bool
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case id, title, body, language, category; case sortOrder = "sort_order", isActive = "is_active", createdAt = "created_at" }
}

struct BusinessQuickReplyPayload: Encodable {
    var title = ""
    var body = ""
    var language = "de"
    var category = "general"
    var sortOrder = 0
    var isActive = true
    enum CodingKeys: String, CodingKey { case title, body, language, category; case sortOrder = "sort_order", isActive = "is_active" }
}

struct BusinessTeamMember: Codable, Identifiable {
    let id: String
    let memberUserID: String?
    let email: String
    let displayName: String
    let role: String
    let status: String
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case id, email, role, status; case memberUserID = "member_user_id", displayName = "display_name", createdAt = "created_at" }
}

struct BusinessTeamPayload: Encodable {
    var email = ""
    var displayName = ""
    var role = "staff"
    enum CodingKeys: String, CodingKey { case email, role; case displayName = "display_name" }
}

struct BusinessWorkspace: Codable, Identifiable {
    let ownerUserID: String
    let displayName: String
    let role: String
    let profileStatus: String
    let isVerified: Bool
    var id: String { ownerUserID }
    enum CodingKeys: String, CodingKey {
        case role
        case ownerUserID = "owner_user_id", displayName = "display_name"
        case profileStatus = "profile_status", isVerified = "is_verified"
    }
}

struct BusinessDocumentItem: Codable, Identifiable {
    let id: String
    let businessUserID: String
    let clientID: String?
    let leadID: String?
    let documentType: String
    let number: String
    let title: String
    let status: String
    let lineItems: [[String: JSONValue]]
    let notes: String
    let totalCents: Int
    let currency: String
    let dueAt: Date?
    let createdAt: Date
    let updatedAt: Date
    enum CodingKeys: String, CodingKey {
        case id, number, title, status, notes, currency
        case businessUserID = "business_user_id", clientID = "client_id", leadID = "lead_id", documentType = "document_type"
        case lineItems = "line_items", totalCents = "total_cents", dueAt = "due_at", createdAt = "created_at", updatedAt = "updated_at"
    }
}

struct BusinessDocumentPayload: Encodable {
    struct LineItem: Encodable, Identifiable {
        let id = UUID()
        var title: String
        var quantity: Int
        var unitPriceCents: Int
        enum CodingKeys: String, CodingKey { case title, quantity; case unitPriceCents = "unit_price_cents" }
    }
    var clientID: String?
    var leadID: String?
    var documentType = "quote"
    var title = ""
    var status = "draft"
    var lineItems: [LineItem] = []
    var notes = ""
    var currency = "CHF"
    var dueAt: Date?
    enum CodingKeys: String, CodingKey {
        case title, status, notes, currency
        case clientID = "client_id", leadID = "lead_id", documentType = "document_type"
        case lineItems = "line_items", dueAt = "due_at"
    }
}

struct PublicBusinessProfile: Codable, Identifiable {
    let userID: String
    let displayName: String
    let description: String
    let category: String
    let canton: String
    let city: String
    let serviceArea: [String]
    let languages: [String]
    let logoURL: String?
    let coverURL: String?
    let website: String?
    let deliveryModes: [String]
    let cancellationPolicy: String?
    let isVerified: Bool
    let services: [BusinessServiceItem]
    let averageRating: Double?
    let reviewCount: Int
    var id: String { userID }
    enum CodingKeys: String, CodingKey {
        case description, category, canton, city, languages, website, services
        case userID = "user_id", displayName = "display_name", serviceArea = "service_area"
        case logoURL = "logo_url", coverURL = "cover_url", deliveryModes = "delivery_modes"
        case cancellationPolicy = "cancellation_policy", isVerified = "is_verified"
        case averageRating = "average_rating", reviewCount = "review_count"
    }
}

struct BusinessBookingSlot: Codable, Identifiable, Hashable {
    let startsAt: Date
    let endsAt: Date
    var id: Date { startsAt }
    enum CodingKeys: String, CodingKey { case startsAt = "starts_at", endsAt = "ends_at" }
}

struct PublicBusinessBookingPayload: Encodable {
    let serviceID: String
    let startsAt: Date
    let notes: String
    enum CodingKeys: String, CodingKey { case notes; case serviceID = "service_id", startsAt = "starts_at" }
}

enum JSONValue: Codable {
    case string(String), int(Int), double(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else { self = .string(try c.decode(String.self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .string(let v): try c.encode(v); case .int(let v): try c.encode(v); case .double(let v): try c.encode(v); case .bool(let v): try c.encode(v); case .null: try c.encodeNil() }
    }
}

struct AIReceptionistDraft: Codable {
    let reply: String
    let detectedLanguage: String
    let leadSummary: String
    let suggestedStatus: String
    let missingInformation: [String]
    let shouldHandoff: Bool
    let handoffReason: String?
    let generatedByAI: Bool
    enum CodingKeys: String, CodingKey {
        case reply
        case detectedLanguage = "detected_language", leadSummary = "lead_summary", suggestedStatus = "suggested_status"
        case missingInformation = "missing_information", shouldHandoff = "should_handoff", handoffReason = "handoff_reason"
        case generatedByAI = "generated_by_ai"
    }
}

struct AIReceptionistDraftPayload: Encodable {
    struct Message: Encodable { let role: String; let content: String }
    let conversationID: String?
    let customerName: String?
    let customerLanguage: String?
    let messages: [Message]
    enum CodingKeys: String, CodingKey { case messages; case conversationID = "conversation_id", customerName = "customer_name", customerLanguage = "customer_language" }
}

struct BusinessProDashboard: Codable {
    let profile: BusinessProfile
    let totalListings: Int
    let activeListings: Int
    let totalViews: Int
    let inquiries: Int
    let openLeads: Int
    let bookingsToday: Int
    let upcomingBookings: Int
    let clientsTotal: Int
    let averageRating: Double?
    let reviewCount: Int
    let responseRatePercent: Int
    let conversionPercent: Int
    let publicationLimit: Int
    let leads: [BusinessLead]
    let bookings: [BusinessBooking]
    let clients: [BusinessClientItem]
    let quickReplies: [BusinessQuickReply]
    enum CodingKeys: String, CodingKey {
        case profile, inquiries, leads, bookings, clients
        case totalListings = "total_listings", activeListings = "active_listings", totalViews = "total_views"
        case openLeads = "open_leads", bookingsToday = "bookings_today", upcomingBookings = "upcoming_bookings"
        case clientsTotal = "clients_total", averageRating = "average_rating", reviewCount = "review_count"
        case responseRatePercent = "response_rate_percent", conversionPercent = "conversion_percent"
        case publicationLimit = "publication_limit", quickReplies = "quick_replies"
    }
}
