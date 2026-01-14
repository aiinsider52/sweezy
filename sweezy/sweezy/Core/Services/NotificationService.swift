//
//  NotificationService.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation
import UserNotifications
import Combine

/// Protocol for notification services
@MainActor
protocol NotificationServiceProtocol: ObservableObject {
    var authorizationStatus: UNAuthorizationStatus { get }
    var isAuthorized: Bool { get }
    
    func requestPermission() async -> Bool
    func scheduleAppointmentReminder(for appointment: Appointment) async -> Bool
    func scheduleReminder(id: String, title: String, body: String, at date: Date) async -> Bool
    func scheduleTrialEndReminder(endDate: Date) async -> Bool
    func scheduleReengageReminder(afterDays days: Int) async -> Bool
    func cancelNotification(with identifier: String)
    func cancelAllNotifications()
    func getPendingNotifications() async -> [UNNotificationRequest]
}

/// Notification service implementation
@MainActor
class NotificationService: NotificationServiceProtocol {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    init() {
        Task {
            await updateAuthorizationStatus()
        }
    }
    
    func scheduleReminder(id: String, title: String, body: String, at date: Date) async -> Bool {
        guard isAuthorized else { return false }
        // Skip past
        guard date > Date() else { return false }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["type": "generic_reminder"]
        
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            print("Failed to schedule generic reminder: \\(error)")
            return false
        }
    }
    
    func scheduleTrialEndReminder(endDate: Date) async -> Bool {
        guard isAuthorized else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Пробний період закінчується"
        content.body = "Продовжіть доступ до всіх можливостей Sweezy"
        content.sound = .default
        content.categoryIdentifier = "TRIAL_REMINDER"
        content.userInfo = ["type": "trial_end"]
        
        // Fire 24 hours before trial end (if in the future)
        let fireDate = endDate.addingTimeInterval(-24*60*60)
        guard fireDate > Date() else { return false }
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "trial_end_\(Int(endDate.timeIntervalSince1970))", content: content, trigger: trigger)
        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            print("Failed to schedule trial end reminder: \(error)")
            return false
        }
    }
    
    func scheduleReengageReminder(afterDays days: Int) async -> Bool {
        guard isAuthorized else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Повернімося до інтеграції"
        content.body = "Нові кроки та поради вже чекають на вас"
        content.sound = .default
        content.categoryIdentifier = "REENGAGE"
        content.userInfo = ["type": "reengage"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, Double(days * 24 * 3600)), repeats: false)
        let request = UNNotificationRequest(identifier: "reengage_\(days)d", content: content, trigger: trigger)
        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            print("Failed to schedule reengage reminder: \(error)")
            return false
        }
    }
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            await updateAuthorizationStatus()
            return granted
        } catch {
            print("Notification permission request failed: \(error)")
            return false
        }
    }
    
    func scheduleAppointmentReminder(for appointment: Appointment) async -> Bool {
        guard isAuthorized else {
            print("Notifications not authorized")
            return false
        }
        
        guard appointment.reminderSettings.isEnabled else {
            print("Reminders disabled for appointment")
            return false
        }
        
        var success = true
        
        for reminderTime in appointment.reminderSettings.reminderTimes {
            let identifier = "\(appointment.id.uuidString)_\(Int(reminderTime))"
            let triggerDate = appointment.dateTime.addingTimeInterval(-reminderTime)
            
            // Don't schedule notifications for past dates
            guard triggerDate > Date() else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = appointment.reminderSettings.notificationTitle ?? "Appointment Reminder"
            content.body = appointment.reminderSettings.notificationBody ?? "You have an appointment: \(appointment.title)"
            content.sound = .default
            content.badge = 1
            
            // Add custom data
            content.userInfo = [
                "appointmentId": appointment.id.uuidString,
                "type": "appointment_reminder"
            ]
            
            // Create trigger
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // Create request
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            do {
                try await notificationCenter.add(request)
                print("Scheduled notification for appointment: \(appointment.title) at \(triggerDate)")
            } catch {
                print("Failed to schedule notification: \(error)")
                success = false
            }
        }
        
        return success
    }
    
    func cancelNotification(with identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Cancelled notification with identifier: \(identifier)")
    }
    
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("Cancelled all pending notifications")
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    // MARK: - Appointment-specific methods
    
    func cancelAppointmentNotifications(for appointmentId: UUID) {
        Task {
            let pendingNotifications = await getPendingNotifications()
            let appointmentNotifications = pendingNotifications.filter { request in
                request.identifier.hasPrefix(appointmentId.uuidString)
            }
            
            let identifiers = appointmentNotifications.map { $0.identifier }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            
            print("Cancelled \(identifiers.count) notifications for appointment: \(appointmentId)")
        }
    }
    
    func rescheduleAppointmentNotifications(for appointment: Appointment) async -> Bool {
        // Cancel existing notifications
        cancelAppointmentNotifications(for: appointment.id)
        
        // Schedule new notifications
        return await scheduleAppointmentReminder(for: appointment)
    }
    
    // MARK: - Content update notifications
    
    func scheduleContentUpdateNotification(title: String, body: String, delay: TimeInterval = 0) async -> Bool {
        guard isAuthorized else { return false }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["type": "content_update"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        let identifier = "content_update_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            print("Failed to schedule content update notification: \(error)")
            return false
        }
    }
    
    // MARK: - Private methods
    
    private func updateAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
    }
}

// MARK: - Notification Categories and Actions

extension NotificationService {
    /// Setup notification categories with actions
    func setupNotificationCategories() {
        // Appointment reminder category
        let viewAction = UNNotificationAction(
            identifier: "VIEW_APPOINTMENT",
            title: "View",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_REMINDER",
            title: "Remind in 10 min",
            options: []
        )
        
        let appointmentCategory = UNNotificationCategory(
            identifier: "APPOINTMENT_REMINDER",
            actions: [viewAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Content update category
        let openAction = UNNotificationAction(
            identifier: "OPEN_CONTENT",
            title: "View Updates",
            options: [.foreground]
        )
        
        let contentCategory = UNNotificationCategory(
            identifier: "CONTENT_UPDATE",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Trial reminder category
        let upgradeAction = UNNotificationAction(
            identifier: "OPEN_PAYWALL",
            title: "See plans",
            options: [.foreground]
        )
        let trialCategory = UNNotificationCategory(
            identifier: "TRIAL_REMINDER",
            actions: [upgradeAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Re-engage category
        let reengageOpen = UNNotificationAction(
            identifier: "OPEN_HOME",
            title: "Open Sweezy",
            options: [.foreground]
        )
        let reengageCategory = UNNotificationCategory(
            identifier: "REENGAGE",
            actions: [reengageOpen],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([appointmentCategory, contentCategory, trialCategory, reengageCategory])
    }
}

// MARK: - Notification Utilities

extension NotificationService {
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
    
    /// Get available reminder time options
    static var reminderTimeOptions: [(String, TimeInterval)] {
        [
            ("5 minutes before", 300),
            ("15 minutes before", 900),
            ("30 minutes before", 1800),
            ("1 hour before", 3600),
            ("2 hours before", 7200),
            ("1 day before", 86400),
            ("2 days before", 172800),
            ("1 week before", 604800)
        ]
    }
}

