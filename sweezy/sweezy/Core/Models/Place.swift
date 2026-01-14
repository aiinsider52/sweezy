//
//  Place.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation
import CoreLocation
import SwiftUI

/// Place model for map locations and services
struct Place: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let type: PlaceType
    let category: PlaceCategory
    let description: String?
    let address: Address
    let coordinate: Coordinate
    let canton: Canton
    let phoneNumber: String?
    let email: String?
    let website: String?
    let openingHours: [OpeningHours]
    let languages: [String] // Language codes: uk, ru, en, de, fr, it
    let services: [String]
    let isAccessible: Bool
    let rating: Double?
    let reviewCount: Int
    let lastUpdated: Date
    let verifiedAt: Date? // When information was last verified
    let source: String? // URL or authority reference
    
    init(
        name: String,
        type: PlaceType,
        category: PlaceCategory,
        description: String? = nil,
        address: Address,
        coordinate: Coordinate,
        canton: Canton,
        phoneNumber: String? = nil,
        email: String? = nil,
        website: String? = nil,
        openingHours: [OpeningHours] = [],
        languages: [String] = ["de"],
        services: [String] = [],
        isAccessible: Bool = false,
        rating: Double? = nil,
        reviewCount: Int = 0,
        verifiedAt: Date? = nil,
        source: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.category = category
        self.description = description
        self.address = address
        self.coordinate = coordinate
        self.canton = canton
        self.phoneNumber = phoneNumber
        self.email = email
        self.website = website
        self.openingHours = openingHours
        self.languages = languages
        self.services = services
        self.isAccessible = isAccessible
        self.rating = rating
        self.reviewCount = reviewCount
        self.lastUpdated = Date()
        self.verifiedAt = verifiedAt
        self.source = source
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, type, category, description, address, coordinate, canton,
             phoneNumber, email, website, openingHours, languages, services,
             isAccessible, rating, reviewCount, lastUpdated, verifiedAt, source
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let idString = try? c.decode(String.self, forKey: .id),
           let parsed = UUID(uuidString: idString) {
            self.id = parsed
        } else if let parsed = try? c.decode(UUID.self, forKey: .id) {
            self.id = parsed
        } else {
            self.id = UUID()
        }
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
        self.type = (try? c.decode(PlaceType.self, forKey: .type)) ?? .government
        self.category = (try? c.decode(PlaceCategory.self, forKey: .category)) ?? .migrationOffice
        self.description = try? c.decode(String.self, forKey: .description)
        self.address = (try? c.decode(Address.self, forKey: .address)) ?? Address(street: "", houseNumber: "", postalCode: "", city: "", canton: .zurich)
        self.coordinate = (try? c.decode(Coordinate.self, forKey: .coordinate)) ?? Coordinate(latitude: 0, longitude: 0)
        self.canton = (try? c.decode(Canton.self, forKey: .canton)) ?? .zurich
        self.phoneNumber = try? c.decode(String.self, forKey: .phoneNumber)
        self.email = try? c.decode(String.self, forKey: .email)
        self.website = try? c.decode(String.self, forKey: .website)
        self.openingHours = (try? c.decode([OpeningHours].self, forKey: .openingHours)) ?? []
        self.languages = (try? c.decode([String].self, forKey: .languages)) ?? []
        self.services = (try? c.decode([String].self, forKey: .services)) ?? []
        self.isAccessible = (try? c.decode(Bool.self, forKey: .isAccessible)) ?? false
        self.rating = try? c.decode(Double.self, forKey: .rating)
        self.reviewCount = (try? c.decode(Int.self, forKey: .reviewCount)) ?? 0
        self.lastUpdated = (try? c.decode(Date.self, forKey: .lastUpdated)) ?? Date()
        self.verifiedAt = try? c.decode(Date.self, forKey: .verifiedAt)
        self.source = try? c.decode(String.self, forKey: .source)
    }
    
    /// Calculate distance from user location
    func distance(from userLocation: CLLocation) -> CLLocationDistance {
        let placeLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        return userLocation.distance(from: placeLocation)
    }
    
    /// Check if place is currently open
    func isOpen(at date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentMinutes = hour * 60 + minute
        
        for hours in openingHours {
            if hours.weekday == weekday {
                if hours.isClosed {
                    return false
                }
                let openMinutes = hours.openTime.hour * 60 + hours.openTime.minute
                let closeMinutes = hours.closeTime.hour * 60 + hours.closeTime.minute
                
                if closeMinutes > openMinutes {
                    // Same day
                    return currentMinutes >= openMinutes && currentMinutes <= closeMinutes
                } else {
                    // Crosses midnight
                    return currentMinutes >= openMinutes || currentMinutes <= closeMinutes
                }
            }
        }
        
        return false // No opening hours defined for this day
    }
    
    /// Get formatted address string
    var formattedAddress: String {
        address.fullAddress
    }
    
    /// Check if place supports specific language
    func supportsLanguage(_ languageCode: String) -> Bool {
        languages.contains(languageCode)
    }
}

/// Place types for categorization
enum PlaceType: String, CaseIterable, Codable, Hashable {
    case government = "government"
    case healthcare = "healthcare"
    case education = "education"
    case legal = "legal"
    case social = "social"
    case employment = "employment"
    case housing = "housing"
    case transport = "transport"
    case banking = "banking"
    case shopping = "shopping"
    case emergency = "emergency"
    case community = "community"
    
    var localizedName: String {
        switch self {
        case .government: return "map.type.government".localized
        case .healthcare: return "map.type.healthcare".localized
        case .education: return "map.type.education".localized
        case .legal: return "map.type.legal".localized
        case .social: return "map.type.social".localized
        case .employment: return "map.type.employment".localized
        case .housing: return "map.type.housing".localized
        case .transport: return "map.type.transport".localized
        case .banking: return "map.type.banking".localized
        case .shopping: return "map.type.shopping".localized
        case .emergency: return "map.type.emergency".localized
        case .community: return "map.type.community".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .government: return "building.columns"
        case .healthcare: return "cross.case"
        case .education: return "graduationcap"
        case .legal: return "hammer"
        case .social: return "person.2"
        case .employment: return "briefcase"
        case .housing: return "house"
        case .transport: return "bus"
        case .banking: return "creditcard"
        case .shopping: return "cart"
        case .emergency: return "exclamationmark.triangle"
        case .community: return "person.3.fill"
        }
    }
    
    var color: String {
        switch self {
        case .government: return "blue"
        case .healthcare: return "red"
        case .education: return "green"
        case .legal: return "purple"
        case .social: return "orange"
        case .employment: return "brown"
        case .housing: return "cyan"
        case .transport: return "mint"
        case .banking: return "yellow"
        case .shopping: return "pink"
        case .emergency: return "red"
        case .community: return "indigo"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .government: return .blue
        case .healthcare: return .red
        case .education: return .green
        case .legal: return .purple
        case .social: return .orange
        case .employment: return .brown
        case .housing: return .cyan
        case .transport: return .mint
        case .banking: return .yellow
        case .shopping: return .pink
        case .emergency: return .red
        case .community: return Color(red: 0.61, green: 0.78, blue: 1.0) // #9CC7FF
        }
    }
}

/// Specific place categories
enum PlaceCategory: String, CaseIterable, Codable, Hashable {
    // Government
    case migrationOffice = "migration_office"
    case gemeinde = "gemeinde"
    case embassy = "embassy"
    case policeStation = "police_station"
    
    // Healthcare
    case hospital = "hospital"
    case clinic = "clinic"
    case pharmacy = "pharmacy"
    case dentist = "dentist"
    case psychologist = "psychologist"
    case counselingCenter = "counseling_center"     // e.g. HEKS Gesundheitsberatung
    case mentalHealth = "mental_health"             // generic mental health services
    case emergencyRoom = "emergency_room"           // ER mapping for JSON
    
    // Legal
    case legalAid = "legal_aid"
    case lawyer = "lawyer"
    case notary = "notary"
    
    // Social
    case socialServices = "social_services"
    case refugeeCenter = "refugee_center"
    case integrationCenter = "integration_center"
    // Social (extended)
    case foodAssistance = "food_assistance"         // discounted groceries, social markets
    case foodBank = "food_bank"                     // free food distribution
    case secondhandShop = "secondhand_shop"         // clothing/furniture reuse
    
    // Employment
    case jobCenter = "job_center"
    case employmentAgency = "employment_agency"
    // Employment (extended)
    case careerCounseling = "career_counseling"
    
    // Education
    case school = "school"
    case university = "university"
    case languageSchool = "language_school"
    case library = "library"
    // Education/Community (extended)
    case languageCafe = "language_cafe"
    
    // Banking & Insurance
    case bank = "bank"
    case insuranceCompany = "insurance_company"
    case postOffice = "post_office"
    
    // Transport
    case trainStation = "train_station"
    case busStop = "bus_stop"
    case airport = "airport"
    
    // Community
    case communityCenter = "community_center"
    case religiousCenter = "religious_center"
    case culturalCenter = "cultural_center"
    case communityCafe = "community_cafe"
    
    // Shopping and retail (extended)
    case supermarket = "supermarket"
    case youthCenter = "youth_center"
    
    var localizedName: String {
        switch self {
        case .migrationOffice: return "Migration Office"
        case .gemeinde: return "Municipality"
        case .embassy: return "Embassy"
        case .policeStation: return "Police Station"
        case .hospital: return "Hospital"
        case .clinic: return "Clinic"
        case .pharmacy: return "Pharmacy"
        case .dentist: return "Dentist"
        case .psychologist: return "Psychologist"
        case .counselingCenter: return "Counseling Center"
        case .mentalHealth: return "Mental Health"
        case .emergencyRoom: return "Emergency Room"
        case .legalAid: return "Legal Aid"
        case .lawyer: return "Lawyer"
        case .notary: return "Notary"
        case .socialServices: return "Social Services"
        case .refugeeCenter: return "Refugee Center"
        case .integrationCenter: return "Integration Center"
        case .foodAssistance: return "Food Assistance"
        case .foodBank: return "Food Bank"
        case .secondhandShop: return "Secondhand Shop"
        case .jobCenter: return "Job Center"
        case .employmentAgency: return "Employment Agency"
        case .careerCounseling: return "Career Counseling"
        case .school: return "School"
        case .university: return "University"
        case .languageSchool: return "Language School"
        case .library: return "Library"
        case .languageCafe: return "Language Café"
        case .bank: return "Bank"
        case .insuranceCompany: return "Insurance Company"
        case .postOffice: return "Post Office"
        case .trainStation: return "Train Station"
        case .busStop: return "Bus Stop"
        case .airport: return "Airport"
        case .communityCenter: return "Community Center"
        case .religiousCenter: return "Religious Center"
        case .culturalCenter: return "Cultural Center"
        case .communityCafe: return "Community Café"
        case .supermarket: return "Supermarket"
        case .youthCenter: return "Youth Center"
        }
    }
}

/// Coordinate for map locations
struct Coordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    /// Convert to CLLocationCoordinate2D
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Opening hours for places
struct OpeningHours: Codable, Hashable, Equatable {
    let weekday: Int // 1 = Sunday, 2 = Monday, etc.
    let openTime: Time
    let closeTime: Time
    let isClosed: Bool
    
    init(weekday: Int, openTime: Time, closeTime: Time, isClosed: Bool = false) {
        self.weekday = weekday
        self.openTime = openTime
        self.closeTime = closeTime
        self.isClosed = isClosed
    }
    
    var weekdayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.weekdaySymbols[weekday - 1]
    }
}

/// Time representation
struct Time: Codable, Hashable {
    let hour: Int
    let minute: Int
    
    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
    
    var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }
}
