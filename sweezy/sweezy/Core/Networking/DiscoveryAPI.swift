import Foundation

extension APIClient {
    struct DiscoveryReview: Decodable, Identifiable, Equatable {
        let id: String
        let placeID: String
        let rating: Int
        let comment: String
        let authorLabel: String
        let createdAt: String
        let updatedAt: String
        let isMine: Bool

        enum CodingKeys: String, CodingKey {
            case id, rating, comment
            case placeID = "place_id"
            case authorLabel = "author_label"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case isMine = "is_mine"
        }
    }

    struct DiscoveryReviewPage: Decodable {
        let averageRating: Double
        let reviewCount: Int
        let items: [DiscoveryReview]
        let myReview: DiscoveryReview?

        enum CodingKeys: String, CodingKey {
            case items
            case averageRating = "average_rating"
            case reviewCount = "review_count"
            case myReview = "my_review"
        }
    }

    struct DiscoveryRatingSummary: Decodable {
        let placeID: String
        let averageRating: Double
        let reviewCount: Int

        enum CodingKeys: String, CodingKey {
            case placeID = "place_id"
            case averageRating = "average_rating"
            case reviewCount = "review_count"
        }
    }

    private struct DiscoveryReviewPayload: Encodable {
        let rating: Int
        let comment: String
    }

    private struct DiscoveryReportPayload: Encodable {
        let reason: String
    }

    static func fetchDiscoveryRatings() async throws -> [DiscoveryRatingSummary] {
        let request = URLRequest(url: url("discovery/ratings"), timeoutInterval: 15)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateDiscoveryResponse(data: data, response: response)
        return try JSONDecoder().decode([DiscoveryRatingSummary].self, from: data)
    }

    static func fetchDiscoveryReviews(placeID: String) async throws -> DiscoveryReviewPage {
        let request = URLRequest(url: url("discovery/\(placeID)/reviews?limit=30"), timeoutInterval: 15)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateDiscoveryResponse(data: data, response: response)
        return try JSONDecoder().decode(DiscoveryReviewPage.self, from: data)
    }

    static func fetchMyDiscoveryReview(placeID: String) async throws -> DiscoveryReview? {
        var request = URLRequest(url: url("discovery/\(placeID)/reviews/me"), timeoutInterval: 15)
        request.httpMethod = "GET"
        let (data, response) = try await authorizedData(for: request, context: "discovery_review_me")
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 404 { return nil }
        try validateDiscoveryResponse(data: data, response: response)
        return try JSONDecoder().decode(DiscoveryReview.self, from: data)
    }

    static func upsertDiscoveryReview(placeID: String, rating: Int, comment: String) async throws -> DiscoveryReview {
        var request = URLRequest(url: url("discovery/\(placeID)/reviews/me"), timeoutInterval: 15)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DiscoveryReviewPayload(rating: rating, comment: comment))
        let (data, response) = try await authorizedData(for: request, context: "discovery_review_upsert")
        try validateDiscoveryResponse(data: data, response: response)
        return try JSONDecoder().decode(DiscoveryReview.self, from: data)
    }

    static func deleteDiscoveryReview(placeID: String) async throws {
        var request = URLRequest(url: url("discovery/\(placeID)/reviews/me"), timeoutInterval: 15)
        request.httpMethod = "DELETE"
        let (data, response) = try await authorizedData(for: request, context: "discovery_review_delete")
        try validateDiscoveryResponse(data: data, response: response)
    }

    static func reportDiscoveryReview(reviewID: String, reason: String) async throws {
        var request = URLRequest(url: url("discovery/reviews/\(reviewID)/report"), timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DiscoveryReportPayload(reason: reason))
        let (data, response) = try await authorizedData(for: request, context: "discovery_review_report")
        try validateDiscoveryResponse(data: data, response: response)
    }

    private static func validateDiscoveryResponse(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(DiscoveryAPIError.self, from: data).detail)
            throw NSError(
                domain: "DiscoveryAPI",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: detail ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)]
            )
        }
    }

    private struct DiscoveryAPIError: Decodable { let detail: String }
}
