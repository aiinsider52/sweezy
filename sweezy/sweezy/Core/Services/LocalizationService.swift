//
//  LocalizationService.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation
import Combine
import SwiftUI

/// Protocol for localization services
@MainActor
protocol LocalizationServiceProtocol: ObservableObject {
    var currentLocale: Locale { get }
    var currentLanguage: String { get }
    var availableLanguages: [Language] { get }
    
    func setLocale(_ locale: Locale)
    func localizedString(for key: String, defaultValue: String?) -> String
    func localizedString(for key: String, arguments: CVarArg...) -> String
}

/// Localization service implementation
@MainActor
class LocalizationService: LocalizationServiceProtocol {
    @Published var currentLocale: Locale
    var currentLanguage: String { currentLocale.identifier }
    
    let availableLanguages: [Language] = [
        Language(code: "uk", name: "Українська", nativeName: "Українська", flag: "🇺🇦"),
        Language(code: "en", name: "English", nativeName: "English", flag: "🇺🇸"),
        Language(code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪")
    ]
    
    private var bundle: Bundle
    
    init() {
        let savedLocale = UserDefaults.standard.string(forKey: "selected_locale") ?? "uk"
        self.currentLocale = Locale(identifier: savedLocale)
        self.bundle = Bundle.main
        
        updateBundle()
    }
    
    func setLocale(_ locale: Locale) {
        currentLocale = locale
        UserDefaults.standard.set(locale.identifier, forKey: "selected_locale")
        updateBundle()
    }
    
    func localizedString(for key: String, defaultValue: String? = nil) -> String {
        let localizedString = bundle.localizedString(forKey: key, value: nil, table: nil)
        
        // If the localized string is the same as the key, it means the translation is missing
        if localizedString == key {
            return defaultValue ?? key
        }
        
        return localizedString
    }
    
    func localizedString(for key: String, arguments: CVarArg...) -> String {
        let format = localizedString(for: key)
        return String(format: format, arguments: arguments)
    }
    
    private func updateBundle() {
        let languageCode = currentLocale.identifier
        
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
            LocalizationBundleProvider.shared.bundle = bundle
        } else {
            // Fallback to main bundle if language not found
            self.bundle = Bundle.main
            LocalizationBundleProvider.shared.bundle = Bundle.main
        }
    }
}

// MARK: - Language Model

struct Language: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    let nativeName: String
    let flag: String
    
    var locale: Locale {
        Locale(identifier: code)
    }
}

// MARK: - Localization Keys

/// Centralized localization keys to avoid typos
struct LocalizationKeys {
    
    // MARK: - Common
    struct Common {
        static let ok = "common.ok"
        static let cancel = "common.cancel"
        static let save = "common.save"
        static let delete = "common.delete"
        static let edit = "common.edit"
        static let done = "common.done"
        static let next = "common.next"
        static let back = "common.back"
        static let close = "common.close"
        static let search = "common.search"
        static let filter = "common.filter"
        static let all = "common.all"
        static let loading = "common.loading"
        static let error = "common.error"
        static let retry = "common.retry"
        static let share = "common.share"
        static let copy = "common.copy"
        static let settings = "common.settings"
    }
    
    // MARK: - Onboarding
    struct Onboarding {
        static let welcome = "onboarding.welcome"
        static let title1 = "onboarding.title1"
        static let subtitle1 = "onboarding.subtitle1"
        static let title2 = "onboarding.title2"
        static let subtitle2 = "onboarding.subtitle2"
        static let title3 = "onboarding.title3"
        static let subtitle3 = "onboarding.subtitle3"
        static let selectLanguage = "onboarding.select_language"
        static let getStarted = "onboarding.get_started"
        static let skip = "onboarding.skip"
    }
    
    // MARK: - Home
    struct Home {
        static let welcome = "home.welcome"
        static let welcomeBack = "home.welcome_back"
        static let quickActions = "home.quick_actions"
        static let recentUpdates = "home.recent_updates"
        static let documents = "home.documents"
        static let housing = "home.housing"
        static let insurance = "home.insurance"
        static let work = "home.work"
        static let finance = "home.finance"
        static let education = "home.education"
        static let healthcare = "home.healthcare"
        static let legal = "home.legal"
        static let emergency = "home.emergency"
    }
    
    // MARK: - Guides
    struct Guides {
        static let title = "guides.title"
        static let searchPlaceholder = "guides.search_placeholder"
        static let noResults = "guides.no_results"
        static let readingTime = "guides.reading_time"
        static let updated = "guides.updated"
        static let newGuide = "guides.new"
        static let bookmark = "guides.bookmark"
        static let share = "guides.share"
        static let openLink = "guides.open_link"
    }
    
    // MARK: - Checklists
    struct Checklists {
        static let title = "checklists.title"
        static let progress = "checklists.progress"
        static let completed = "checklists.completed"
        static let remaining = "checklists.remaining"
        static let estimatedTime = "checklists.estimated_time"
        static let difficulty = "checklists.difficulty"
        static let markComplete = "checklists.mark_complete"
        static let addNote = "checklists.add_note"
        static let viewDetails = "checklists.view_details"
    }
    
    // MARK: - Calculator
    struct Calculator {
        static let title = "calculator.title"
        static let income = "calculator.income"
        static let familySize = "calculator.family_size"
        static let hasChildren = "calculator.has_children"
        static let canton = "calculator.canton"
        static let permitType = "calculator.permit_type"
        static let calculate = "calculator.calculate"
        static let results = "calculator.results"
        static let eligible = "calculator.eligible"
        static let notEligible = "calculator.not_eligible"
        static let estimatedAmount = "calculator.estimated_amount"
        static let disclaimer = "calculator.disclaimer"
        static let applyNow = "calculator.apply_now"
        static let learnMore = "calculator.learn_more"
        static let generalTitle = "calculator.general.title"
    }
    
    // MARK: - Map
    struct Map {
        static let title = "map.title"
        static let nearbyServices = "map.nearby_services"
        static let distance = "map.distance"
        static let openingHours = "map.opening_hours"
        static let contact = "map.contact"
        static let directions = "map.directions"
        static let call = "map.call"
        static let website = "map.website"
        static let closed = "map.closed"
        static let open = "map.open"
        static let locationPermission = "map.location_permission"
        static let enableLocation = "map.enable_location"
    }
    
    // MARK: - Appointments
    struct Appointments {
        static let title = "appointments.title"
        static let addAppointment = "appointments.add"
        static let editAppointment = "appointments.edit"
        static let deleteAppointment = "appointments.delete"
        static let appointmentTitle = "appointments.appointment_title"
        static let date = "appointments.date"
        static let time = "appointments.time"
        static let location = "appointments.location"
        static let notes = "appointments.notes"
        static let reminders = "appointments.reminders"
        static let upcoming = "appointments.upcoming"
        static let past = "appointments.past"
        static let today = "appointments.today"
        static let noAppointments = "appointments.no_appointments"
    }
    
    // MARK: - Templates
    struct Templates {
        static let title = "templates.title"
        static let selectTemplate = "templates.select"
        static let fillForm = "templates.fill_form"
        static let preview = "templates.preview"
        static let generate = "templates.generate"
        static let export = "templates.export"
        static let requiredField = "templates.required_field"
        static let optionalField = "templates.optional_field"
        static let savedDocuments = "templates.saved_documents"
        static let documentTitle = "templates.document_title"
    }
    
    // MARK: - Settings
    struct Settings {
        static let title = "settings.title"
        static let profile = "settings.profile"
        static let language = "settings.language"
        static let notifications = "settings.notifications"
        static let privacy = "settings.privacy"
        static let about = "settings.about"
        static let version = "settings.version"
        static let fullName = "settings.full_name"
        static let email = "settings.email"
        static let phone = "settings.phone"
        static let address = "settings.address"
        static let exportData = "settings.export_data"
        static let importData = "settings.import_data"
        static let deleteAllData = "settings.delete_all_data"
    }
    
    // MARK: - Errors
    struct Errors {
        static let genericError = "errors.generic"
        static let networkError = "errors.network"
        static let locationError = "errors.location"
        static let permissionDenied = "errors.permission_denied"
        static let dataCorrupted = "errors.data_corrupted"
        static let fileNotFound = "errors.file_not_found"
        static let invalidInput = "errors.invalid_input"
    }
}

// MARK: - Bundle Provider and Convenience

final class LocalizationBundleProvider {
    static let shared = LocalizationBundleProvider()
    var bundle: Bundle = .main
}

extension String {
    var localized: String {
        let bundle = LocalizationBundleProvider.shared.bundle
        return bundle.localizedString(forKey: self, value: self, table: nil)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        let format = LocalizationBundleProvider.shared.bundle.localizedString(forKey: self, value: self, table: nil)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Formatting Utilities

extension LocalizationService {
    func formatCurrency(_ amount: Double, currency: String = "CHF", locale: Locale? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = locale ?? currentLocale
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
    
    func formatNumber(_ value: Double, locale: Locale? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.locale = locale ?? currentLocale
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    func formatDate(_ date: Date, style: DateFormatter.Style = .medium, locale: Locale? = nil) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.locale = locale ?? currentLocale
        return formatter.string(from: date)
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

extension View {
    /// Apply localized text
    func localizedText(_ key: String) -> some View {
        self.modifier(LocalizedTextModifier(key: key))
    }
}

struct LocalizedTextModifier: ViewModifier {
    let key: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(key.localized)
    }
}

