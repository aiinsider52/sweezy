import Foundation

enum ProfessionalRole: String, Codable, CaseIterable, Identifiable {
    case founder, freelancer, specialist, investor, mentor

    var id: String { rawValue }
    var title: String {
        switch self {
        case .founder: return "Засновник"
        case .freelancer: return "Фрилансер"
        case .specialist: return "Спеціаліст"
        case .investor: return "Інвестор"
        case .mentor: return "Ментор"
        }
    }
    var icon: String {
        switch self {
        case .founder: return "building.2.fill"
        case .freelancer: return "laptopcomputer"
        case .specialist: return "person.crop.circle.badge.checkmark"
        case .investor: return "chart.line.uptrend.xyaxis"
        case .mentor: return "person.2.wave.2.fill"
        }
    }
}

enum ProfessionalGoal: String, Codable, CaseIterable, Identifiable {
    case clients, partners, cofounder, hiring, investing, mentoring, events

    var id: String { rawValue }
    var title: String {
        switch self {
        case .clients: return "Клієнти"
        case .partners: return "Партнери"
        case .cofounder: return "Co-founder"
        case .hiring: return "Команда"
        case .investing: return "Інвестиції"
        case .mentoring: return "Менторство"
        case .events: return "Події"
        }
    }
    var icon: String {
        switch self {
        case .clients: return "person.crop.rectangle.stack.fill"
        case .partners: return "link"
        case .cofounder: return "person.2.fill"
        case .hiring: return "person.badge.plus"
        case .investing: return "francsign.circle.fill"
        case .mentoring: return "lightbulb.fill"
        case .events: return "calendar.badge.clock"
        }
    }
}

struct ProfessionalProfile: Codable, Identifiable, Equatable {
    let userID: String
    let displayName: String
    let headline: String
    let companyName: String?
    let role: ProfessionalRole
    let industry: String
    let canton: String
    let city: String
    let bio: String
    let skills: [String]
    let languages: [String]
    let goals: [ProfessionalGoal]
    let avatarURL: String?
    let websiteURL: String?
    let isVisible: Bool
    let isVerified: Bool
    let isFeatured: Bool
    let openToConnections: Bool
    let connectionState: String
    let connectionID: String?
    let conversationID: String?
    let createdAt: Date
    let updatedAt: Date

    var id: String { userID }
    var initials: String {
        let words = displayName.split(separator: " ")
        return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private enum CodingKeys: String, CodingKey {
        case headline, role, industry, canton, city, bio, skills, languages, goals
        case userID = "user_id"
        case displayName = "display_name"
        case companyName = "company_name"
        case avatarURL = "avatar_url"
        case websiteURL = "website_url"
        case isVisible = "is_visible"
        case isVerified = "is_verified"
        case isFeatured = "is_featured"
        case openToConnections = "open_to_connections"
        case connectionState = "connection_state"
        case connectionID = "connection_id"
        case conversationID = "conversation_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ProfessionalProfilePage: Codable {
    let items: [ProfessionalProfile]
    let total: Int
    let page: Int
    let perPage: Int
    let pages: Int

    private enum CodingKeys: String, CodingKey {
        case items, total, page, pages
        case perPage = "per_page"
    }
}

struct ProfessionalProfileDraft: Codable, Equatable {
    var displayName = ""
    var headline = ""
    var companyName = ""
    var role: ProfessionalRole = .founder
    var industry = ""
    var canton = "ZH"
    var city = "Zürich"
    var bio = ""
    var skills: [String] = []
    var languages: [String] = ["UK"]
    var goals: [ProfessionalGoal] = [.partners]
    var avatarURL = ""
    var websiteURL = ""
    var isVisible = true
    var openToConnections = true

    init() {}

    init(profile: ProfessionalProfile) {
        displayName = profile.displayName
        headline = profile.headline
        companyName = profile.companyName ?? ""
        role = profile.role
        industry = profile.industry
        canton = profile.canton
        city = profile.city
        bio = profile.bio
        skills = profile.skills
        languages = profile.languages
        goals = profile.goals
        avatarURL = profile.avatarURL ?? ""
        websiteURL = profile.websiteURL ?? ""
        isVisible = profile.isVisible
        openToConnections = profile.openToConnections
    }

    private enum CodingKeys: String, CodingKey {
        case headline, role, industry, canton, city, bio, skills, languages, goals
        case displayName = "display_name"
        case companyName = "company_name"
        case avatarURL = "avatar_url"
        case websiteURL = "website_url"
        case isVisible = "is_visible"
        case openToConnections = "open_to_connections"
    }
}

struct ProfessionalConnection: Codable, Identifiable, Equatable {
    let id: String
    let direction: String
    let status: String
    let message: String?
    let conversationID: String?
    let otherProfile: ProfessionalProfile
    let createdAt: Date
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, direction, status, message
        case conversationID = "conversation_id"
        case otherProfile = "other_profile"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
