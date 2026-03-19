//
//  CV.swift
//  sweezy
//
//  Lightweight data models for the CV Builder feature
//

import Foundation
import SwiftUI

struct CVResume: Codable {
    var personal: CVPersonal = CVPersonal()
    var education: [CVEducation] = []
    var experience: [CVExperience] = []
    var languages: [CVLanguage] = []
    var skills: [String] = []
    var hobbies: [String] = []
    var links: [CVLink] = []
    
    static let empty = CVResume()
}

struct CVPersonal: Codable {
    var fullName: String = ""
    var title: String = ""
    var email: String = ""
    var phone: String = ""
    var location: String = ""
    var summary: String = ""
    // Optional local photo data-url or remote url string
    var photoData: Data? = nil
}

struct CVEducation: Codable, Identifiable {
    var id: UUID
    var school: String
    var degree: String
    var period: String
    var details: String
    
    init(id: UUID = UUID(), school: String = "", degree: String = "", period: String = "", details: String = "") {
        self.id = id; self.school = school; self.degree = degree; self.period = period; self.details = details
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        school = (try? c.decode(String.self, forKey: .school)) ?? ""
        degree = (try? c.decode(String.self, forKey: .degree)) ?? ""
        period = (try? c.decode(String.self, forKey: .period)) ?? ""
        details = (try? c.decode(String.self, forKey: .details)) ?? ""
    }
}

struct CVExperience: Codable, Identifiable {
    var id: UUID
    var role: String
    var company: String
    var period: String
    var location: String
    var achievements: String
    
    init(id: UUID = UUID(), role: String = "", company: String = "", period: String = "", location: String = "", achievements: String = "") {
        self.id = id; self.role = role; self.company = company; self.period = period; self.location = location; self.achievements = achievements
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        role = (try? c.decode(String.self, forKey: .role)) ?? ""
        company = (try? c.decode(String.self, forKey: .company)) ?? ""
        period = (try? c.decode(String.self, forKey: .period)) ?? ""
        location = (try? c.decode(String.self, forKey: .location)) ?? ""
        achievements = (try? c.decode(String.self, forKey: .achievements)) ?? ""
    }
}

struct CVLanguage: Codable, Identifiable {
    var id: UUID
    var name: String
    var level: String
    
    init(id: UUID = UUID(), name: String = "", level: String = "") {
        self.id = id; self.name = name; self.level = level
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        level = (try? c.decode(String.self, forKey: .level)) ?? ""
    }
}

struct CVLink: Codable, Identifiable {
    var id: UUID
    var label: String
    var url: String
    
    init(id: UUID = UUID(), label: String = "", url: String = "") {
        self.id = id; self.label = label; self.url = url
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        label = (try? c.decode(String.self, forKey: .label)) ?? ""
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
    }
}


