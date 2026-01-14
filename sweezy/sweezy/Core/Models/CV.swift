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
    var id = UUID()
    var school: String = ""
    var degree: String = ""
    var period: String = ""
    var details: String = ""
}

struct CVExperience: Codable, Identifiable {
    var id = UUID()
    var role: String = ""
    var company: String = ""
    var period: String = ""
    var location: String = ""
    var achievements: String = "" // bullet list or paragraph
}

struct CVLanguage: Codable, Identifiable {
    var id = UUID()
    var name: String = ""
    var level: String = "" // e.g., B2, C1, Native
}

struct CVLink: Codable, Identifiable {
    var id = UUID()
    var label: String = ""
    var url: String = ""
}


