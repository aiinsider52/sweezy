import Foundation

/// Community place suggestions: users propose, moderators approve, approved places appear on the map.
enum PlaceSuggestionCategory: String, CaseIterable, Codable, Identifiable {
    case community, religious, school, language
    case legalAid = "legal_aid"
    case social, health, food, other

    var id: String { rawValue }

    var title: String { "place.suggest.category.\(rawValue)".localized }

    var icon: String {
        switch self {
        case .community: return "person.3.fill"
        case .religious: return "building.columns.fill"
        case .school: return "graduationcap.fill"
        case .language: return "character.bubble.fill"
        case .legalAid: return "person.badge.shield.checkmark.fill"
        case .social: return "heart.fill"
        case .health: return "cross.case.fill"
        case .food: return "basket.fill"
        case .other: return "mappin.and.ellipse"
        }
    }

    var swatch: JourneyCategorySwatch {
        switch self {
        case .community: return JourneyCategoryPalette.lime
        case .religious: return JourneyCategoryPalette.sand
        case .school, .language: return JourneyCategoryPalette.sky
        case .legalAid: return JourneyCategoryPalette.lilac
        case .social: return JourneyCategoryPalette.coral
        case .health: return JourneyCategoryPalette.teal
        case .food: return JourneyCategoryPalette.sand
        case .other: return JourneyCategoryPalette.graphite
        }
    }

    /// How an approved suggestion is shown among the regular map places.
    var placeKind: (type: PlaceType, category: PlaceCategory) {
        switch self {
        case .community: return (.community, .communityCenter)
        case .religious: return (.community, .religiousCenter)
        case .school: return (.education, .school)
        case .language: return (.education, .languageSchool)
        case .legalAid: return (.legal, .legalAid)
        case .social: return (.social, .socialServices)
        case .health: return (.healthcare, .clinic)
        case .food: return (.social, .foodBank)
        case .other: return (.community, .culturalCenter)
        }
    }
}

extension APIClient {
    struct PlaceSuggestionPayload: Encodable {
        let name: String
        let category: String
        let street: String
        let postalCode: String
        let city: String
        let countryCode: String
        let subdivisionCode: String?
        let website: String?
        let phone: String?
        let note: String

        enum CodingKeys: String, CodingKey {
            case name, category, street, city, website, phone, note
            case postalCode = "postal_code"
            case countryCode = "country_code"
            case subdivisionCode = "subdivision_code"
        }
    }

    struct PlaceSuggestion: Decodable, Identifiable, Equatable {
        let id: String
        let name: String
        let category: String
        let city: String
        let status: String
        let rejectionReason: String?
        let createdAt: String

        enum CodingKeys: String, CodingKey {
            case id, name, category, city, status
            case rejectionReason = "rejection_reason"
            case createdAt = "created_at"
        }
    }

    struct CommunityPlace: Codable, Identifiable, Equatable {
        let id: String
        let name: String
        let category: String
        let street: String
        let postalCode: String
        let city: String
        let countryCode: String
        let subdivisionCode: String?
        let website: String?
        let phone: String?
        let latitude: Double
        let longitude: Double
        let reviewedAt: String?

        enum CodingKeys: String, CodingKey {
            case id, name, category, street, city, website, phone, latitude, longitude
            case postalCode = "postal_code"
            case countryCode = "country_code"
            case subdivisionCode = "subdivision_code"
            case reviewedAt = "reviewed_at"
        }
    }

    static func submitPlaceSuggestion(_ payload: PlaceSuggestionPayload) async throws -> PlaceSuggestion {
        var request = URLRequest(url: url("places/suggestions"), timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await authorizedData(for: request, context: "place_suggestion_create")
        try validatePlaceSuggestionResponse(data: data, response: response)
        return try JSONDecoder().decode(PlaceSuggestion.self, from: data)
    }

    static func fetchMyPlaceSuggestions() async throws -> [PlaceSuggestion] {
        let request = URLRequest(url: url("places/suggestions/me"), timeoutInterval: 15)
        let (data, response) = try await authorizedData(for: request, context: "place_suggestion_mine")
        try validatePlaceSuggestionResponse(data: data, response: response)
        return try JSONDecoder().decode([PlaceSuggestion].self, from: data)
    }

    static func fetchCommunityPlaces(country: String) async throws -> [CommunityPlace] {
        let request = URLRequest(url: url("places/community?country=\(country.uppercased())"), timeoutInterval: 12)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validatePlaceSuggestionResponse(data: data, response: response)
        return try JSONDecoder().decode([CommunityPlace].self, from: data)
    }

    private static func validatePlaceSuggestionResponse(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(
                domain: "PlaceSuggestionsAPI",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: http.statusCode)]
            )
        }
    }
}

extension Place {
    static let communitySource = "sweezy-community"

    var isCommunitySuggested: Bool { source == Self.communitySource }

    init(community place: APIClient.CommunityPlace) {
        let kind = (PlaceSuggestionCategory(rawValue: place.category) ?? .other).placeKind
        let country = place.countryCode.uppercased()
        let canton = country == "CH" ? (place.subdivisionCode.flatMap(Canton.init(rawValue:)) ?? .zurich) : .zurich
        self.init(
            id: UUID(uuidString: place.id) ?? UUID(),
            name: place.name,
            type: kind.type,
            category: kind.category,
            description: "place.suggest.community_description".localized,
            address: Address(street: place.street, houseNumber: "", postalCode: place.postalCode, city: place.city, canton: canton),
            coordinate: Coordinate(latitude: place.latitude, longitude: place.longitude),
            canton: canton,
            countryCode: country,
            subdivisionCode: place.subdivisionCode ?? (country == "CH" ? canton.rawValue : ""),
            phoneNumber: place.phone,
            website: place.website,
            languages: ["uk"],
            verifiedAt: place.reviewedAt.flatMap { ISO8601DateFormatter().date(from: $0) },
            source: Self.communitySource
        )
    }
}
