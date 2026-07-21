//
//  UserProfile.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation

/// User profile model for personalization
struct UserProfile: Codable, Identifiable {
    let id: UUID
    var fullName: String
    var canton: Canton
    var permitType: PermitType
    var arrivalDate: Date?
    var permitExpiryDate: Date?
    var goals: [UserGoal]
    var familySize: Int
    var hasChildren: Bool
    var familyStatus: FamilyStatus?
    var preferredLanguage: String
    var address: Address?
    var phoneNumber: String?
    var email: String?
    var emergencyContact: EmergencyContact?
    var lifeEvents: [LifeEvent]
    var createdAt: Date
    var updatedAt: Date

    init(
        fullName: String = "",
        canton: Canton = .zurich,
        permitType: PermitType = .s,
        arrivalDate: Date? = nil,
        permitExpiryDate: Date? = nil,
        goals: [UserGoal] = [],
        familySize: Int = 1,
        hasChildren: Bool = false,
        familyStatus: FamilyStatus? = nil,
        preferredLanguage: String = "uk",
        lifeEvents: [LifeEvent] = []
    ) {
        self.id = UUID()
        self.fullName = fullName
        self.canton = canton
        self.permitType = permitType
        self.arrivalDate = arrivalDate
        self.permitExpiryDate = permitExpiryDate
        self.goals = goals
        self.familySize = familySize
        self.hasChildren = hasChildren
        self.familyStatus = familyStatus
        self.preferredLanguage = preferredLanguage
        self.lifeEvents = lifeEvents
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Months since arrival in Switzerland. Nil if `arrivalDate` is unknown.
    var tenureMonths: Int? {
        guard let arrival = arrivalDate else { return nil }
        let comps = Calendar.current.dateComponents([.month], from: arrival, to: Date())
        return max(0, comps.month ?? 0)
    }

    /// True if user has been in Switzerland for 12+ months — switches roadmap to "settled" branch.
    var isSettledResident: Bool {
        (tenureMonths ?? 0) >= 12
    }

    private enum CodingKeys: String, CodingKey {
        case id, fullName, canton, permitType, arrivalDate, permitExpiryDate
        case goals, familySize, hasChildren, familyStatus, preferredLanguage
        case address, phoneNumber, email, emergencyContact, lifeEvents
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.fullName = try c.decode(String.self, forKey: .fullName)
        self.canton = try c.decode(Canton.self, forKey: .canton)
        self.permitType = try c.decode(PermitType.self, forKey: .permitType)
        self.arrivalDate = try c.decodeIfPresent(Date.self, forKey: .arrivalDate)
        self.permitExpiryDate = try c.decodeIfPresent(Date.self, forKey: .permitExpiryDate)
        self.goals = try c.decode([UserGoal].self, forKey: .goals)
        self.familySize = try c.decode(Int.self, forKey: .familySize)
        self.hasChildren = try c.decode(Bool.self, forKey: .hasChildren)
        self.familyStatus = try c.decodeIfPresent(FamilyStatus.self, forKey: .familyStatus)
        self.preferredLanguage = try c.decode(String.self, forKey: .preferredLanguage)
        self.address = try c.decodeIfPresent(Address.self, forKey: .address)
        self.phoneNumber = try c.decodeIfPresent(String.self, forKey: .phoneNumber)
        self.email = try c.decodeIfPresent(String.self, forKey: .email)
        self.emergencyContact = try c.decodeIfPresent(EmergencyContact.self, forKey: .emergencyContact)
        self.lifeEvents = (try? c.decodeIfPresent([LifeEvent].self, forKey: .lifeEvents)) ?? []
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}

/// Life events that long-term residents can log to switch roadmap focus and unlock relevant moments.
enum LifeEvent: String, CaseIterable, Codable, Hashable, Identifiable {
    case newJob = "new_job"
    case baby = "baby"
    case movedCanton = "moved_canton"
    case gotCPermit = "got_c_permit"
    case planningCitizenship = "planning_citizenship"
    case kidsToSchool = "kids_to_school"
    case freelancing = "freelancing"
    case retiring = "retiring"

    var id: String { rawValue }

    var localizedName: String {
        "user.life_event.\(rawValue)".localized
    }

    var emoji: String {
        switch self {
        case .newJob: return "💼"
        case .baby: return "👶"
        case .movedCanton: return "📦"
        case .gotCPermit: return "🪪"
        case .planningCitizenship: return "🇨🇭"
        case .kidsToSchool: return "🎒"
        case .freelancing: return "🧑‍💻"
        case .retiring: return "🌅"
        }
    }
}

enum FamilyStatus: String, CaseIterable, Codable, Hashable, Identifiable {
    case single
    case married
    case partner
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .single: return "onboarding.family_status.single".localized
        case .married: return "onboarding.family_status.married".localized
        case .partner: return "onboarding.family_status.partner".localized
        }
    }
}

/// Personal goals to tailor content
enum UserGoal: String, CaseIterable, Codable, Hashable, Identifiable {
    case housing
    case work
    case language
    case education
    case documents
    case finance
    case health
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .housing: return "user.goal.housing".localized
        case .work: return "user.goal.work".localized
        case .language: return "user.goal.language".localized
        case .education: return "user.goal.education".localized
        case .documents: return "user.goal.documents".localized
        case .finance: return "user.goal.finance".localized
        case .health: return "user.goal.health".localized
        }
    }
}

/// Swiss cantons
enum Canton: String, CaseIterable, Codable, Hashable {
    case zurich = "ZH"
    case bern = "BE"
    case geneva = "GE"
    case basel = "BS"
    case vaud = "VD"
    case aargau = "AG"
    case stGallen = "SG"
    case grisons = "GR"
    case ticino = "TI"
    case valais = "VS"
    case fribourg = "FR"
    case lucerne = "LU"
    case thurgau = "TG"
    case solothurn = "SO"
    case neuchatel = "NE"
    case schaffhausen = "SH"
    case appenzellAR = "AR"
    case appenzellAI = "AI"
    case nidwalden = "NW"
    case obwalden = "OW"
    case glarus = "GL"
    case jura = "JU"
    case uri = "UR"
    case schwyz = "SZ"
    case zug = "ZG"
    case baselLand = "BL"
    
    var localizedName: String {
        switch self {
        case .zurich: return "Zürich"
        case .bern: return "Bern"
        case .geneva: return "Geneva"
        case .basel: return "Basel-Stadt"
        case .vaud: return "Vaud"
        case .aargau: return "Aargau"
        case .stGallen: return "St. Gallen"
        case .grisons: return "Grisons"
        case .ticino: return "Ticino"
        case .valais: return "Valais"
        case .fribourg: return "Fribourg"
        case .lucerne: return "Lucerne"
        case .thurgau: return "Thurgau"
        case .solothurn: return "Solothurn"
        case .neuchatel: return "Neuchâtel"
        case .schaffhausen: return "Schaffhausen"
        case .appenzellAR: return "Appenzell A.Rh."
        case .appenzellAI: return "Appenzell I.Rh."
        case .nidwalden: return "Nidwalden"
        case .obwalden: return "Obwalden"
        case .glarus: return "Glarus"
        case .jura: return "Jura"
        case .uri: return "Uri"
        case .schwyz: return "Schwyz"
        case .zug: return "Zug"
        case .baselLand: return "Basel-Landschaft"
        }
    }
}

/// Swiss residence permit types
enum PermitType: String, CaseIterable, Codable, Hashable {
    case s = "S"  // Protection status (temporary)
    case b = "B"  // Residence permit
    case c = "C"  // Settlement permit
    case f = "F"  // Provisional admission
    case n = "N"  // Asylum seeker
    case l = "L"  // Short-term residence
    case other = "Other"
    
    var localizedName: String {
        switch self {
        case .s: return "S - Protection Status"
        case .b: return "B - Residence Permit"
        case .c: return "C - Settlement Permit"
        case .f: return "F - Provisional Admission"
        case .n: return "N - Asylum Seeker"
        case .l: return "L - Short-term Residence"
        case .other: return "Other"
        }
    }
    
    var description: String {
        switch self {
        case .s: return "Temporary protection for Ukrainian refugees"
        case .b: return "Residence permit for foreign nationals"
        case .c: return "Settlement permit (permanent residence)"
        case .f: return "Provisional admission"
        case .n: return "Asylum seeker permit"
        case .l: return "Short-term residence permit"
        case .other: return "Other permit or status"
        }
    }
}

/// Address information
struct Address: Codable, Hashable {
    var street: String
    var houseNumber: String
    var postalCode: String
    var city: String
    var canton: Canton
    
    var fullAddress: String {
        "\(street) \(houseNumber), \(postalCode) \(city)"
    }
}

/// Emergency contact information
struct EmergencyContact: Codable {
    var name: String
    var relationship: String
    var phoneNumber: String
    var email: String?
}
