//
//  Template.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation
import SwiftUI

/// Document template model for generating letters and forms
struct DocumentTemplate: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let category: TemplateCategory
    let templateType: TemplateType
    let content: String // Template content with placeholders
    let placeholders: [TemplatePlaceholder]
    let requiredFields: Set<String> // Placeholder IDs that are required
    let tags: [String]
    let cantonCodes: [String] // Empty means applies to all cantons
    let language: String // Language code
    let isOfficial: Bool // Official government template
    let lastUpdated: Date
    let createdAt: Date
    let verifiedAt: Date? // When template was last verified
    let source: String? // URL or authority reference
    let heroImage: String? // Hero image path
    
    init(
        title: String,
        description: String,
        category: TemplateCategory,
        templateType: TemplateType,
        content: String,
        placeholders: [TemplatePlaceholder],
        requiredFields: Set<String> = [],
        tags: [String] = [],
        cantonCodes: [String] = [],
        language: String = "en",
        isOfficial: Bool = false,
        verifiedAt: Date? = nil,
        source: String? = nil,
        heroImage: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category
        self.templateType = templateType
        self.content = content
        self.placeholders = placeholders
        self.requiredFields = requiredFields
        self.tags = tags
        self.cantonCodes = cantonCodes
        self.language = language
        self.isOfficial = isOfficial
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.verifiedAt = verifiedAt
        self.source = source
        self.heroImage = heroImage
    }
    
    // Tolerant decoding for invalid UUIDs
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Tolerant UUID decoding
        if let idString = try? container.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        
        self.title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled"
        self.description = (try? container.decode(String.self, forKey: .description)) ?? ""
        self.category = (try? container.decode(TemplateCategory.self, forKey: .category)) ?? .government
        self.templateType = (try? container.decode(TemplateType.self, forKey: .templateType)) ?? .letter
        self.content = (try? container.decode(String.self, forKey: .content)) ?? ""
        self.placeholders = (try? container.decode([TemplatePlaceholder].self, forKey: .placeholders)) ?? []
        self.requiredFields = (try? container.decode(Set<String>.self, forKey: .requiredFields)) ?? []
        self.tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        self.cantonCodes = (try? container.decode([String].self, forKey: .cantonCodes)) ?? []
        self.language = (try? container.decode(String.self, forKey: .language)) ?? "en"
        self.isOfficial = (try? container.decode(Bool.self, forKey: .isOfficial)) ?? false
        self.lastUpdated = (try? container.decode(Date.self, forKey: .lastUpdated)) ?? Date()
        self.createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        self.verifiedAt = try? container.decodeIfPresent(Date.self, forKey: .verifiedAt)
        self.source = try? container.decodeIfPresent(String.self, forKey: .source)
        self.heroImage = try? container.decodeIfPresent(String.self, forKey: .heroImage)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, description, category, templateType, content, placeholders
        case requiredFields, tags, cantonCodes, language, isOfficial
        case lastUpdated, createdAt, verifiedAt, source, heroImage
    }
    
    /// Generate document content with provided values
    func generateContent(with values: [String: String]) -> String {
        var generatedContent = content
        
        for placeholder in placeholders {
            let placeholderPattern = "{{\(placeholder.id)}}"
            let value = values[placeholder.id] ?? placeholder.defaultValue ?? ""
            generatedContent = generatedContent.replacingOccurrences(
                of: placeholderPattern,
                with: value
            )
        }
        
        return generatedContent
    }
    
    /// Check if all required fields are provided
    func hasAllRequiredFields(values: [String: String]) -> Bool {
        for requiredField in requiredFields {
            if values[requiredField]?.isEmpty != false {
                return false
            }
        }
        return true
    }
    
    /// Get missing required fields
    func getMissingRequiredFields(values: [String: String]) -> [TemplatePlaceholder] {
        return placeholders.filter { placeholder in
            requiredFields.contains(placeholder.id) &&
            (values[placeholder.id]?.isEmpty != false)
        }
    }
    
    /// Check if template applies to specific canton
    func appliesTo(canton: Canton) -> Bool {
        cantonCodes.isEmpty || cantonCodes.contains(canton.rawValue)
    }
}

/// Template categories
enum TemplateCategory: String, CaseIterable, Codable, Hashable {
    case government = "government"
    case housing = "housing"
    case employment = "employment"
    case insurance = "insurance"
    case healthcare = "healthcare"
    case education = "education"
    case legal = "legal"
    case banking = "banking"
    case complaint = "complaint"
    case request = "request"
    case application = "application"
    case notification = "notification"
    
    var localizedName: String {
        // Fallback to human-friendly English when translation is missing
        switch self {
        case .government:
            return TemplateCategory.localizedOrFallback("template.category.government", fallback: "Government")
        case .housing:
            return TemplateCategory.localizedOrFallback("template.category.housing", fallback: "Housing")
        case .employment:
            return TemplateCategory.localizedOrFallback("template.category.employment", fallback: "Employment")
        case .insurance:
            return TemplateCategory.localizedOrFallback("template.category.insurance", fallback: "Insurance")
        case .healthcare:
            return TemplateCategory.localizedOrFallback("template.category.healthcare", fallback: "Healthcare")
        case .education:
            return TemplateCategory.localizedOrFallback("template.category.education", fallback: "Education")
        case .legal:
            return TemplateCategory.localizedOrFallback("template.category.legal", fallback: "Legal")
        case .banking:
            return TemplateCategory.localizedOrFallback("template.category.banking", fallback: "Banking")
        case .complaint:
            return TemplateCategory.localizedOrFallback("template.category.complaint", fallback: "Complaint")
        case .request:
            return TemplateCategory.localizedOrFallback("template.category.request", fallback: "Request")
        case .application:
            return TemplateCategory.localizedOrFallback("template.category.application", fallback: "Application")
        case .notification:
            return TemplateCategory.localizedOrFallback("template.category.notification", fallback: "Notification")
        }
    }

    private static func localizedOrFallback(_ key: String, fallback: String) -> String {
        let value = key.localized
        return value == key ? fallback : value
    }
    
    var iconName: String {
        switch self {
        case .government: return "building.columns" // iOS 13+
        case .housing: return "house" // iOS 13+
        case .employment: return "briefcase" // iOS 13+
        case .insurance: return "shield.fill" // iOS 13+
        case .healthcare: return "cross.case" // iOS 14+
        case .education: return "graduationcap" // iOS 13+
        case .legal: return "hammer" // safer fallback
        case .banking: return "creditcard" // iOS 13+
        case .complaint: return "exclamationmark.triangle" // iOS 13+
        case .request: return "hand.raised" // iOS 13+
        case .application: return "doc.text" // iOS 13+
        case .notification: return "bell" // iOS 13+
        }
    }
    
    var color: String {
        switch self {
        case .government: return "blue"
        case .housing: return "green"
        case .employment: return "orange"
        case .insurance: return "purple"
        case .healthcare: return "red"
        case .education: return "indigo"
        case .legal: return "brown"
        case .banking: return "yellow"
        case .complaint: return "red"
        case .request: return "blue"
        case .application: return "green"
        case .notification: return "orange"
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .government: return .blue
        case .housing: return .green
        case .employment: return .orange
        case .insurance: return .purple
        case .healthcare: return .red
        case .education: return .indigo
        case .legal: return .brown
        case .banking: return .yellow
        case .complaint: return .red
        case .request: return .blue
        case .application: return .green
        case .notification: return .orange
        }
    }

    // Be lenient with decoding to support legacy seeds (e.g., "work" -> .employment)
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "government"
        switch raw {
        case "work": self = .employment
        case "employment": self = .employment
        case "government": self = .government
        case "housing": self = .housing
        case "insurance": self = .insurance
        case "healthcare": self = .healthcare
        case "education": self = .education
        case "legal": self = .legal
        case "banking": self = .banking
        case "complaint": self = .complaint
        case "request": self = .request
        case "application": self = .application
        case "notification": self = .notification
        default: self = .government
        }
    }
}

/// Template types
enum TemplateType: String, CaseIterable, Codable, Hashable {
    case letter = "letter"
    case form = "form"
    case email = "email"
    case application = "application"
    case complaint = "complaint"
    case notice = "notice"
    
    var localizedName: String {
        switch self {
        case .letter: return "Letter"
        case .form: return "Form"
        case .email: return "Email"
        case .application: return "Application"
        case .complaint: return "Complaint"
        case .notice: return "Notice"
        }
    }
    
    var iconName: String {
        switch self {
        case .letter: return "envelope"
        case .form: return "doc.text"
        case .email: return "at"
        case .application: return "square.and.pencil"
        case .complaint: return "exclamationmark.triangle"
        case .notice: return "bell"
        }
    }
}

/// Template placeholder for dynamic content
struct TemplatePlaceholder: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let description: String?
    let type: PlaceholderType
    let defaultValue: String?
    let options: [String]? // For dropdown/selection types
    let validation: PlaceholderValidation?
    let isRequired: Bool
    let order: Int
    
    init(
        id: String,
        label: String,
        description: String? = nil,
        type: PlaceholderType = .text,
        defaultValue: String? = nil,
        options: [String]? = nil,
        validation: PlaceholderValidation? = nil,
        isRequired: Bool = false,
        order: Int = 0
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.type = type
        self.defaultValue = defaultValue
        self.options = options
        self.validation = validation
        self.isRequired = isRequired
        self.order = order
    }
}

/// Placeholder input types
enum PlaceholderType: String, CaseIterable, Codable, Hashable {
    case text = "text"
    case multilineText = "multiline_text"
    case number = "number"
    case date = "date"
    case email = "email"
    case phone = "phone"
    case dropdown = "dropdown"
    case checkbox = "checkbox"
    case address = "address"
    case currency = "currency"
    
    var localizedName: String {
        switch self {
        case .text: return "Text"
        case .multilineText: return "Long Text"
        case .number: return "Number"
        case .date: return "Date"
        case .email: return "Email"
        case .phone: return "Phone"
        case .dropdown: return "Selection"
        case .checkbox: return "Yes/No"
        case .address: return "Address"
        case .currency: return "Currency"
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "text"
        switch raw {
        case "multiline_text", "multilineText":
            self = .multilineText
        case "text": self = .text
        case "number": self = .number
        case "date": self = .date
        case "email": self = .email
        case "phone": self = .phone
        case "dropdown": self = .dropdown
        case "checkbox": self = .checkbox
        case "address": self = .address
        case "currency": self = .currency
        default:
            self = .text
        }
    }
}

/// Validation rules for placeholders
struct PlaceholderValidation: Codable, Hashable {
    let minLength: Int?
    let maxLength: Int?
    let pattern: String? // Regex pattern
    let customMessage: String?
    
    func validate(_ value: String) -> ValidationResult {
        if let minLength = minLength, value.count < minLength {
            return .invalid(customMessage ?? "Value is too short")
        }
        
        if let maxLength = maxLength, value.count > maxLength {
            return .invalid(customMessage ?? "Value is too long")
        }
        
        if let pattern = pattern {
            let regex = try? NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: value.utf16.count)
            if regex?.firstMatch(in: value, options: [], range: range) == nil {
                return .invalid(customMessage ?? "Invalid format")
            }
        }
        
        return .valid
    }
    
    enum ValidationResult {
        case valid
        case invalid(String)
    }
}

/// Generated document from template
struct GeneratedDocument: Codable, Identifiable {
    let id: UUID
    let templateId: UUID
    let title: String
    let content: String
    let values: [String: String] // Placeholder values used
    let format: DocumentFormat
    let createdAt: Date
    var lastModified: Date
    var isFavorite: Bool
    var tags: [String]
    
    init(
        templateId: UUID,
        title: String,
        content: String,
        values: [String: String],
        format: DocumentFormat = .text
    ) {
        self.id = UUID()
        self.templateId = templateId
        self.title = title
        self.content = content
        self.values = values
        self.format = format
        self.createdAt = Date()
        self.lastModified = Date()
        self.isFavorite = false
        self.tags = []
    }
}

/// Document output formats
enum DocumentFormat: String, CaseIterable, Codable {
    case text = "text"
    case pdf = "pdf"
    case html = "html"
    
    var localizedName: String {
        switch self {
        case .text: return "Text"
        case .pdf: return "PDF"
        case .html: return "HTML"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .pdf: return "pdf"
        case .html: return "html"
        }
    }
    
    var mimeType: String {
        switch self {
        case .text: return "text/plain"
        case .pdf: return "application/pdf"
        case .html: return "text/html"
        }
    }
}
