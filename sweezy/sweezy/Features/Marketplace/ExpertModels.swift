//
//  ExpertModels.swift
//  sweezy
//
//  Shared models for the verified-expert directory and lightweight Q&A.
//

import Foundation

enum ExpertSpecialty: String, Codable, CaseIterable, Identifiable {
    case tax
    case legal
    case insurance
    case relocation
    case career
    case family

    var id: String { rawValue }

    var localizedName: String {
        "experts.specialty.\(rawValue)".localized
    }

    var emoji: String {
        switch self {
        case .tax: return "🧾"
        case .legal: return "⚖️"
        case .insurance: return "🛡️"
        case .relocation: return "📦"
        case .career: return "💼"
        case .family: return "👨‍👩‍👧"
        }
    }
}

struct ExpertQuestion: Identifiable, Codable, Hashable {
    let id: String
    let listingId: String
    let askerName: String?
    let askerLanguage: String?
    let questionText: String
    let answerText: String?
    let status: String
    let answeredAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case askerName = "asker_name"
        case askerLanguage = "asker_language"
        case questionText = "question_text"
        case answerText = "answer_text"
        case status
        case answeredAt = "answered_at"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.listingId = try c.decode(String.self, forKey: .listingId)
        self.askerName = try c.decodeIfPresent(String.self, forKey: .askerName)
        self.askerLanguage = try c.decodeIfPresent(String.self, forKey: .askerLanguage)
        self.questionText = try c.decode(String.self, forKey: .questionText)
        self.answerText = try c.decodeIfPresent(String.self, forKey: .answerText)
        self.status = try c.decode(String.self, forKey: .status)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let altFormatter = ISO8601DateFormatter()
        altFormatter.formatOptions = [.withInternetDateTime]

        func parseDate(_ raw: String?) -> Date? {
            guard let raw, !raw.isEmpty else { return nil }
            return formatter.date(from: raw) ?? altFormatter.date(from: raw)
        }

        self.answeredAt = parseDate(try c.decodeIfPresent(String.self, forKey: .answeredAt))
        self.createdAt = parseDate(try c.decodeIfPresent(String.self, forKey: .createdAt)) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(listingId, forKey: .listingId)
        try c.encodeIfPresent(askerName, forKey: .askerName)
        try c.encodeIfPresent(askerLanguage, forKey: .askerLanguage)
        try c.encode(questionText, forKey: .questionText)
        try c.encodeIfPresent(answerText, forKey: .answerText)
        try c.encode(status, forKey: .status)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let answeredAt { try c.encode(formatter.string(from: answeredAt), forKey: .answeredAt) }
        try c.encode(formatter.string(from: createdAt), forKey: .createdAt)
    }
}
