import Foundation

/// Server-side switches for engagement pushes (matches, likes, events nearby, marketplace),
/// saved-listing price watches and "new listings in my canton" follows.
struct EngagementPreferences: Codable, Equatable {
    var locale: String
    var timezone: String
    var socialEnabled: Bool
    var eventsEnabled: Bool
    var marketplaceEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case locale, timezone
        case socialEnabled = "social_enabled"
        case eventsEnabled = "events_enabled"
        case marketplaceEnabled = "marketplace_enabled"
    }

    static let `default` = EngagementPreferences(
        locale: AppLanguage.current.rawValue,
        timezone: TimeZone.current.identifier,
        socialEnabled: true,
        eventsEnabled: true,
        marketplaceEnabled: true
    )
}

struct MarketplaceFollow: Codable, Identifiable, Equatable {
    let id: String
    let countryCode: String
    let subdivisionCode: String
    let category: String?

    enum CodingKeys: String, CodingKey {
        case id, category
        case countryCode = "country_code"
        case subdivisionCode = "subdivision_code"
    }
}

enum NotificationsAPI {
    private struct PreferencesUpdate: Encodable {
        var locale: String?
        var timezone: String?
        var socialEnabled: Bool?
        var eventsEnabled: Bool?
        var marketplaceEnabled: Bool?

        enum CodingKeys: String, CodingKey {
            case locale, timezone
            case socialEnabled = "social_enabled"
            case eventsEnabled = "events_enabled"
            case marketplaceEnabled = "marketplace_enabled"
        }
    }

    private struct FollowCreate: Encodable {
        let countryCode: String
        let subdivisionCode: String
        let category: String?

        enum CodingKeys: String, CodingKey {
            case category
            case countryCode = "country_code"
            case subdivisionCode = "subdivision_code"
        }
    }

    static var isSignedIn: Bool { KeychainStore.get("access_token")?.isEmpty == false }

    private struct NoBody: Encodable {}

    private static func send(_ path: String, method: String) async throws -> Data {
        try await send(path, method: method, body: Optional<NoBody>.none)
    }

    private static func send<Body: Encodable>(_ path: String, method: String, body: Body?) async throws -> Data {
        var request = URLRequest(url: APIClient.url(path), timeoutInterval: 15)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await APIClient.authorizedData(for: request, context: "notifications_\(method.lowercased())")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(
                domain: "NotificationsAPI",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: "chat.error.request".localized]
            )
        }
        return data
    }

    static func preferences() async throws -> EngagementPreferences {
        try JSONDecoder().decode(EngagementPreferences.self, from: try await send("notifications/preferences", method: "GET"))
    }

    @discardableResult
    static func updatePreferences(
        social: Bool? = nil,
        events: Bool? = nil,
        marketplace: Bool? = nil
    ) async throws -> EngagementPreferences {
        let body = PreferencesUpdate(
            locale: AppLanguage.current.rawValue,
            timezone: TimeZone.current.identifier,
            socialEnabled: social,
            eventsEnabled: events,
            marketplaceEnabled: marketplace
        )
        let data = try await send("notifications/preferences", method: "PUT", body: body)
        return try JSONDecoder().decode(EngagementPreferences.self, from: data)
    }

    /// Pushes are written on the server, so it needs the app language and the phone's timezone
    /// (for quiet hours). Called whenever the device registers for push.
    static func syncDeviceContext() async {
        guard isSignedIn else { return }
        _ = try? await updatePreferences()
    }

    static func watchListing(_ id: String, watching: Bool) async {
        guard isSignedIn else { return }
        _ = try? await send("notifications/listing-watches/\(id)", method: watching ? "PUT" : "DELETE")
    }

    static func follows() async throws -> [MarketplaceFollow] {
        try JSONDecoder().decode([MarketplaceFollow].self, from: try await send("notifications/marketplace-follows", method: "GET"))
    }

    static func follow(country: String, subdivision: String, category: String?) async throws -> MarketplaceFollow {
        let body = FollowCreate(countryCode: country, subdivisionCode: subdivision, category: category)
        return try JSONDecoder().decode(MarketplaceFollow.self, from: try await send("notifications/marketplace-follows", method: "POST", body: body))
    }

    static func unfollow(_ id: String) async throws {
        _ = try await send("notifications/marketplace-follows/\(id)", method: "DELETE")
    }
}
