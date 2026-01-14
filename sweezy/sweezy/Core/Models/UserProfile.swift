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
    var preferredLanguage: String
    var address: Address?
    var phoneNumber: String?
    var email: String?
    var emergencyContact: EmergencyContact?
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
        preferredLanguage: String = "uk"
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
        self.preferredLanguage = preferredLanguage
        self.createdAt = Date()
        self.updatedAt = Date()
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
        case .housing: return "Знайти житло"
        case .work: return "Знайти роботу"
        case .language: return "Вивчити мову"
        case .education: return "Освіта"
        case .documents: return "Оформити документи"
        case .finance: return "Фінанси"
        case .health: return "Медицина"
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
    
    var localizedName: String {
        switch self {
        case .s: return "S - Protection Status"
        case .b: return "B - Residence Permit"
        case .c: return "C - Settlement Permit"
        case .f: return "F - Provisional Admission"
        case .n: return "N - Asylum Seeker"
        case .l: return "L - Short-term Residence"
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
