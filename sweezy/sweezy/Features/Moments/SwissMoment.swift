//
//  SwissMoment.swift
//  sweezy
//
//  Time-sensitive Swiss "moments" surfaced on Home for settled residents.
//

import Foundation
import SwiftUI

enum MomentCtaKind: String, Codable {
    case link
    case checklist
    case calculator
    case deeplink

    var localizedCtaKey: String {
        switch self {
        case .link: return "moments.cta.open"
        case .checklist: return "moments.cta.checklist"
        case .calculator: return "moments.cta.calculator"
        case .deeplink: return "moments.cta.open"
        }
    }
}

struct SwissMoment: Identifiable, Codable, Hashable {
    let id: String
    let key: String
    let title: String
    let descriptionMd: String
    let startsAt: Date
    let endsAt: Date
    let recurrence: String
    let audienceFilters: [String: AnyCodableValue]
    let ctaKind: MomentCtaKind
    let ctaPayload: [String: AnyCodableValue]
    let priority: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, key, title
        case descriptionMd = "description_md"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case recurrence
        case audienceFilters = "audience_filters"
        case ctaKind = "cta_kind"
        case ctaPayload = "cta_payload"
        case priority
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.key = try c.decode(String.self, forKey: .key)
        self.title = try c.decode(String.self, forKey: .title)
        self.descriptionMd = (try? c.decode(String.self, forKey: .descriptionMd)) ?? ""
        self.recurrence = (try? c.decode(String.self, forKey: .recurrence)) ?? "yearly"
        self.priority = (try? c.decode(Int.self, forKey: .priority)) ?? 0
        self.isActive = (try? c.decode(Bool.self, forKey: .isActive)) ?? true
        let kindRaw = (try? c.decode(String.self, forKey: .ctaKind)) ?? "link"
        self.ctaKind = MomentCtaKind(rawValue: kindRaw) ?? .link
        self.audienceFilters = (try? c.decode([String: AnyCodableValue].self, forKey: .audienceFilters)) ?? [:]
        self.ctaPayload = (try? c.decode([String: AnyCodableValue].self, forKey: .ctaPayload)) ?? [:]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let altFormatter = ISO8601DateFormatter()
        altFormatter.formatOptions = [.withInternetDateTime]

        func parseDate(_ key: CodingKeys) throws -> Date {
            let raw = try c.decode(String.self, forKey: key)
            if let d = formatter.date(from: raw) { return d }
            if let d = altFormatter.date(from: raw) { return d }
            throw DecodingError.dataCorruptedError(forKey: key, in: c, debugDescription: "Bad date \(raw)")
        }

        self.startsAt = try parseDate(.startsAt)
        self.endsAt = try parseDate(.endsAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(key, forKey: .key)
        try c.encode(title, forKey: .title)
        try c.encode(descriptionMd, forKey: .descriptionMd)
        try c.encode(recurrence, forKey: .recurrence)
        try c.encode(priority, forKey: .priority)
        try c.encode(isActive, forKey: .isActive)
        try c.encode(ctaKind.rawValue, forKey: .ctaKind)
        try c.encode(audienceFilters, forKey: .audienceFilters)
        try c.encode(ctaPayload, forKey: .ctaPayload)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try c.encode(formatter.string(from: startsAt), forKey: .startsAt)
        try c.encode(formatter.string(from: endsAt), forKey: .endsAt)
    }

    /// Days until `endsAt` (positive when in the future, negative if already past).
    var daysUntilDeadline: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: endsAt).day ?? 0
    }

    /// True if the moment window is open right now.
    var isLive: Bool {
        let now = Date()
        return now >= startsAt && now <= endsAt
    }

    var ctaLinkURL: URL? {
        guard ctaKind == .link, let raw = ctaPayload["url"]?.stringValue else { return nil }
        return URL(string: raw)
    }

    var ctaToolKey: String? {
        ctaPayload["tool"]?.stringValue
    }
}

// MARK: - AnyCodableValue (small helper for free-form JSON fields)

enum AnyCodableValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dict([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([AnyCodableValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: AnyCodableValue].self) { self = .dict(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .dict(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    var stringValue: String? {
        if case let .string(v) = self { return v }
        return nil
    }
    var intValue: Int? {
        if case let .int(v) = self { return v }
        if case let .double(v) = self { return Int(v) }
        return nil
    }
    var stringArray: [String]? {
        if case let .array(v) = self { return v.compactMap { $0.stringValue } }
        return nil
    }
}
