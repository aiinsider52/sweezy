//
//  Appointment.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation

/// Appointment model for reminders and scheduling
struct Appointment: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var description: String?
    var category: AppointmentCategory
    var dateTime: Date
    var duration: TimeInterval // in seconds
    var location: AppointmentLocation?
    var contactInfo: ContactInfo?
    var reminderSettings: ReminderSettings
    var status: AppointmentStatus
    var notes: String
    var attachments: [String] // File paths or URLs
    var createdAt: Date
    var updatedAt: Date
    
    init(
        title: String,
        description: String? = nil,
        category: AppointmentCategory,
        dateTime: Date,
        duration: TimeInterval = 3600, // 1 hour default
        location: AppointmentLocation? = nil,
        contactInfo: ContactInfo? = nil,
        reminderSettings: ReminderSettings = ReminderSettings(),
        notes: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category
        self.dateTime = dateTime
        self.duration = duration
        self.location = location
        self.contactInfo = contactInfo
        self.reminderSettings = reminderSettings
        self.status = .scheduled
        self.notes = notes
        self.attachments = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// End time of appointment
    var endTime: Date {
        dateTime.addingTimeInterval(duration)
    }
    
    /// Check if appointment is in the past
    var isPast: Bool {
        endTime < Date()
    }
    
    /// Check if appointment is today
    var isToday: Bool {
        Calendar.current.isDateInToday(dateTime)
    }
    
    /// Check if appointment is upcoming (within next 7 days)
    var isUpcoming: Bool {
        let sevenDaysFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return dateTime > Date() && dateTime <= sevenDaysFromNow
    }
    
    /// Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateTime)
    }
    
    /// Formatted duration string
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Appointment categories
enum AppointmentCategory: String, CaseIterable, Codable, Hashable {
    case government = "government"
    case healthcare = "healthcare"
    case education = "education"
    case legal = "legal"
    case employment = "employment"
    case housing = "housing"
    case banking = "banking"
    case insurance = "insurance"
    case integration = "integration"
    case personal = "personal"
    case other = "other"
    
    var localizedName: String {
        switch self {
        case .government: return "appointment.category.government".localized
        case .healthcare: return "appointment.category.healthcare".localized
        case .education: return "appointment.category.education".localized
        case .legal: return "appointment.category.legal".localized
        case .employment: return "appointment.category.employment".localized
        case .housing: return "appointment.category.housing".localized
        case .banking: return "appointment.category.banking".localized
        case .insurance: return "appointment.category.insurance".localized
        case .integration: return "appointment.category.integration".localized
        case .personal: return "appointment.category.personal".localized
        case .other: return "appointment.category.other".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .government: return "building.columns" // iOS 13+
        case .healthcare: return "cross.case" // iOS 14+
        case .education: return "graduationcap" // iOS 13+
        case .legal: return "hammer" // safer fallback
        case .employment: return "briefcase" // iOS 13+
        case .housing: return "house" // iOS 13+
        case .banking: return "creditcard" // iOS 13+
        case .insurance: return "shield.fill" // iOS 13+
        case .integration: return "person.2" // iOS 13+
        case .personal: return "person" // iOS 13+
        case .other: return "calendar" // iOS 13+
        }
    }
    
    var color: String {
        switch self {
        case .government: return "blue"
        case .healthcare: return "red"
        case .education: return "green"
        case .legal: return "purple"
        case .employment: return "orange"
        case .housing: return "cyan"
        case .banking: return "yellow"
        case .insurance: return "indigo"
        case .integration: return "pink"
        case .personal: return "gray"
        case .other: return "brown"
        }
    }
}

/// Appointment status
enum AppointmentStatus: String, CaseIterable, Codable, Hashable {
    case scheduled = "scheduled"
    case confirmed = "confirmed"
    case cancelled = "cancelled"
    case completed = "completed"
    case noShow = "no_show"
    case rescheduled = "rescheduled"
    
    var localizedName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .confirmed: return "Confirmed"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        case .noShow: return "No Show"
        case .rescheduled: return "Rescheduled"
        }
    }
    
    var color: String {
        switch self {
        case .scheduled: return "blue"
        case .confirmed: return "green"
        case .cancelled: return "red"
        case .completed: return "gray"
        case .noShow: return "orange"
        case .rescheduled: return "yellow"
        }
    }
}

/// Appointment location information
struct AppointmentLocation: Codable, Hashable, Equatable {
    var name: String
    var address: Address
    var coordinate: Coordinate?
    var room: String?
    var floor: String?
    var instructions: String?
    
    // Explicit Hashable/Equatable to avoid synthesis conflicts if needed
    static func == (lhs: AppointmentLocation, rhs: AppointmentLocation) -> Bool {
        lhs.name == rhs.name &&
        lhs.address == rhs.address &&
        lhs.coordinate == rhs.coordinate &&
        lhs.room == rhs.room &&
        lhs.floor == rhs.floor &&
        lhs.instructions == rhs.instructions
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(address)
        hasher.combine(coordinate?.latitude)
        hasher.combine(coordinate?.longitude)
        hasher.combine(room)
        hasher.combine(floor)
        hasher.combine(instructions)
    }
    
    var fullLocationDescription: String {
        var components: [String] = [name]
        
        if let room = room {
            components.append("Room \(room)")
        }
        
        if let floor = floor {
            components.append("Floor \(floor)")
        }
        
        components.append(address.fullAddress)
        
        return components.joined(separator: ", ")
    }
}

/// Contact information for appointments
struct ContactInfo: Codable, Hashable {
    var name: String?
    var title: String?
    var phoneNumber: String?
    var email: String?
    var website: String?
    var department: String?
    
    var hasContactInfo: Bool {
        phoneNumber != nil || email != nil || website != nil
    }
}

/// Reminder settings for appointments
struct ReminderSettings: Codable, Hashable {
    var isEnabled: Bool
    var reminderTimes: [TimeInterval] // Seconds before appointment
    var notificationTitle: String?
    var notificationBody: String?
    
    init(
        isEnabled: Bool = true,
        reminderTimes: [TimeInterval] = [86400, 3600], // 1 day and 1 hour before
        notificationTitle: String? = nil,
        notificationBody: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.reminderTimes = reminderTimes
        self.notificationTitle = notificationTitle
        self.notificationBody = notificationBody
    }
    
    /// Default reminder time options
    static let defaultReminderOptions: [TimeInterval] = [
        300,    // 5 minutes
        900,    // 15 minutes
        1800,   // 30 minutes
        3600,   // 1 hour
        7200,   // 2 hours
        86400,  // 1 day
        172800, // 2 days
        604800  // 1 week
    ]
    
    /// Format reminder time for display
    static func formatReminderTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let hours = minutes / 60
        let days = hours / 24
        
        if days > 0 {
            return days == 1 ? "1 day before" : "\(days) days before"
        } else if hours > 0 {
            return hours == 1 ? "1 hour before" : "\(hours) hours before"
        } else {
            return minutes == 1 ? "1 minute before" : "\(minutes) minutes before"
        }
    }
}
