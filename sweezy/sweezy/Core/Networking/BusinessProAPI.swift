import Foundation

enum BusinessProAPI {
    private struct Empty: Decodable {}

    private static func error(_ data: Data, _ response: URLResponse) -> NSError {
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        var message = "Не вдалося виконати запит".localized
        if let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let detail = value["detail"] {
            if let text = detail as? String { message = text }
            if let object = detail as? [String: Any], let errorCode = object["code"] as? String { message = errorCode.replacingOccurrences(of: "_", with: " ") }
        }
        return NSError(domain: "BusinessProAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        as type: T.Type = T.self
    ) async throws -> T {
        var request = URLRequest(url: APIClient.url("business/\(path)"))
        request.httpMethod = method
        request.timeoutInterval = 30
        if let body { request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await APIClient.authorizedData(for: request, context: "business_\(method.lowercased())_\(path)")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        if T.self == Empty.self, data.isEmpty { return Empty() as! T }
        return try ChatAPI.decoder.decode(T.self, from: data)
    }

    private static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    static func profile() async throws -> BusinessProfile { try await request("profile") }
    static func saveProfile(_ payload: BusinessProfilePayload) async throws -> BusinessProfile { try await request("profile", method: "PUT", body: try encoded(payload)) }
    static func submitProfile() async throws -> BusinessProfile { try await request("profile/submit", method: "POST") }
    static func dashboard() async throws -> BusinessProDashboard { try await request("dashboard") }

    static func aiSettings() async throws -> BusinessAISettings { try await request("ai-settings") }
    static func saveAISettings(_ payload: BusinessAISettings) async throws -> BusinessAISettings { try await request("ai-settings", method: "PUT", body: try encoded(payload)) }
    static func draftReply(_ payload: AIReceptionistDraftPayload) async throws -> AIReceptionistDraft { try await request("ai-receptionist/draft", method: "POST", body: try encoded(payload)) }

    static func services() async throws -> [BusinessServiceItem] { try await request("services") }
    static func createService(_ payload: BusinessServicePayload) async throws -> BusinessServiceItem { try await request("services", method: "POST", body: try encoded(payload)) }
    static func updateService(id: String, payload: BusinessServicePayload) async throws -> BusinessServiceItem { try await request("services/\(id)", method: "PATCH", body: try encoded(payload)) }
    static func deleteService(id: String) async throws { let _: Empty = try await request("services/\(id)", method: "DELETE") }

    static func availability() async throws -> [BusinessAvailabilityRule] { try await request("availability") }
    static func saveAvailability(_ payload: [BusinessAvailabilityPayload]) async throws -> [BusinessAvailabilityRule] { try await request("availability", method: "PUT", body: try encoded(payload)) }

    static func leads() async throws -> [BusinessLead] { try await request("leads") }
    static func updateLead(id: String, payload: BusinessLeadUpdatePayload) async throws -> BusinessLead { try await request("leads/\(id)", method: "PATCH", body: try encoded(payload)) }

    static func clients() async throws -> [BusinessClientItem] { try await request("clients") }
    static func createClient(_ payload: BusinessClientPayload) async throws -> BusinessClientItem { try await request("clients", method: "POST", body: try encoded(payload)) }

    static func bookings() async throws -> [BusinessBooking] { try await request("bookings") }
    static func createBooking(_ payload: BusinessBookingPayload) async throws -> BusinessBooking { try await request("bookings", method: "POST", body: try encoded(payload)) }
    static func updateBooking(id: String, status: String) async throws -> BusinessBooking {
        struct Payload: Encodable { let status: String }
        return try await request("bookings/\(id)", method: "PATCH", body: try encoded(Payload(status: status)))
    }

    static func quickReplies() async throws -> [BusinessQuickReply] { try await request("quick-replies") }
    static func createQuickReply(_ payload: BusinessQuickReplyPayload) async throws -> BusinessQuickReply { try await request("quick-replies", method: "POST", body: try encoded(payload)) }
    static func deleteQuickReply(id: String) async throws { let _: Empty = try await request("quick-replies/\(id)", method: "DELETE") }

    static func team() async throws -> [BusinessTeamMember] { try await request("team") }
    static func addTeamMember(_ payload: BusinessTeamPayload) async throws -> BusinessTeamMember { try await request("team", method: "POST", body: try encoded(payload)) }
    static func removeTeamMember(id: String) async throws { let _: Empty = try await request("team/\(id)", method: "DELETE") }

    static func documents() async throws -> [BusinessDocumentItem] { try await request("documents") }
    static func createDocument(_ payload: BusinessDocumentPayload) async throws -> BusinessDocumentItem { try await request("documents", method: "POST", body: try encoded(payload)) }

    // MARK: Growth: plan, stats, offers, reviews, clubs

    static func plan() async throws -> BusinessPlanInfo { try await request("plan") }
    static func syncApplePurchase(_ signedTransaction: String) async throws -> BusinessPlanInfo {
        struct Payload: Encodable { let signed_transaction: String }
        return try await request("plan/apple", method: "POST", body: try encoded(Payload(signed_transaction: signedTransaction)))
    }
    static func stats(days: Int) async throws -> BusinessStats { try await request("stats?days=\(days)") }

    static func offers() async throws -> [BusinessOffer] { try await request("offers") }
    static func createOffer(_ payload: BusinessOfferPayload) async throws -> BusinessOffer { try await request("offers", method: "POST", body: try encoded(payload)) }
    static func updateOffer(id: String, payload: BusinessOfferPayload) async throws -> BusinessOffer { try await request("offers/\(id)", method: "PATCH", body: try encoded(payload)) }
    static func deleteOffer(id: String) async throws { let _: Empty = try await request("offers/\(id)", method: "DELETE") }

    static func myReviews() async throws -> [BusinessReview] { try await request("reviews") }
    static func replyToReview(id: String, text: String) async throws -> BusinessReview {
        struct Payload: Encodable { let text: String }
        return try await request("reviews/\(id)/reply", method: "POST", body: try encoded(Payload(text: text)))
    }

    static func clubMembers() async throws -> [BusinessClubMember] { try await request("club/members") }
    static func reviewClubMember(id: String, approve: Bool) async throws -> BusinessClubMember {
        struct Payload: Encodable { let status: String }
        return try await request("club/members/\(id)", method: "PATCH", body: try encoded(Payload(status: approve ? "approved" : "rejected")))
    }
    static func removeClubMember(id: String) async throws { let _: Empty = try await request("club/members/\(id)", method: "DELETE") }
    static func myClubs() async throws -> [BusinessClubMember] { try await request("clubs/mine") }
    static func joinClub(clubUserID: String) async throws -> BusinessClubMember { try await request("clubs/\(clubUserID)/join", method: "POST") }

    // MARK: Public discovery

    struct DirectoryQuery: Equatable {
        var kind: BusinessKind?
        var category: BusinessCategory?
        var ukrainianOnly = false
        var verifiedOnly = false
        var search = ""
        var withLocation = false
        var limit = 60
    }

    private static func publicGET<T: Decodable>(_ path: String, items: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: APIClient.url(path), resolvingAgainstBaseURL: false)
        let present = items.filter { !($0.value ?? "").isEmpty }
        if !present.isEmpty { components?.queryItems = present }
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode(T.self, from: data)
    }

    static func directory(_ query: DirectoryQuery) async throws -> BusinessDirectoryPage {
        try await publicGET("businesses/directory", items: [
            URLQueryItem(name: "country", value: APIClient.countryCode),
            URLQueryItem(name: "kind", value: query.kind?.rawValue),
            URLQueryItem(name: "category", value: query.category?.rawValue),
            URLQueryItem(name: "language", value: query.ukrainianOnly ? "uk" : nil),
            URLQueryItem(name: "verified", value: query.verifiedOnly ? "true" : nil),
            URLQueryItem(name: "with_location", value: query.withLocation ? "true" : nil),
            URLQueryItem(name: "q", value: query.search.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "limit", value: String(query.limit))
        ])
    }

    static func contextual(topic: String) async throws -> [BusinessSummary] {
        try await publicGET("businesses/contextual", items: [
            URLQueryItem(name: "topic", value: topic),
            URLQueryItem(name: "country", value: APIClient.countryCode),
            URLQueryItem(name: "subdivision", value: APIClient.subdivisionCode)
        ])
    }

    static func offersFeed() async throws -> [BusinessOffer] {
        try await publicGET("businesses/offers", items: [URLQueryItem(name: "country", value: APIClient.countryCode)])
    }

    static func reviews(businessID: String) async throws -> [BusinessReview] {
        try await publicGET("businesses/\(businessID)/reviews")
    }

    static func reviewEligibility(businessID: String) async throws -> BusinessReviewEligibility {
        let request = URLRequest(url: APIClient.url("businesses/\(businessID)/reviews/eligibility"))
        let (data, response) = try await APIClient.authorizedData(for: request, context: "business_review_eligibility")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode(BusinessReviewEligibility.self, from: data)
    }

    static func writeReview(businessID: String, payload: BusinessReviewPayload) async throws -> BusinessReview {
        var request = URLRequest(url: APIClient.url("businesses/\(businessID)/reviews"))
        request.httpMethod = "POST"
        request.httpBody = try encoded(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await APIClient.authorizedData(for: request, context: "business_review_write")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode(BusinessReview.self, from: data)
    }

    /// Fire-and-forget analytics for the business owner's stats; failures never surface to the visitor.
    static func track(_ event: BusinessTrackEvent, businessID: String) {
        Task.detached(priority: .utility) {
            var request = URLRequest(url: APIClient.url("businesses/\(businessID)/track"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(["event": event.rawValue])
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    static func publicProfile(userID: String) async throws -> PublicBusinessProfile? {
        let url = APIClient.url("businesses/\(userID)")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode(PublicBusinessProfile.self, from: data)
    }

    static func publicSlots(userID: String, serviceID: String, day: Date) async throws -> [BusinessBookingSlot] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        formatter.dateFormat = "yyyy-MM-dd"
        let service = serviceID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? serviceID
        let path = "businesses/\(userID)/slots?service_id=\(service)&date=\(formatter.string(from: day))"
        let (data, response) = try await URLSession.shared.data(from: APIClient.url(path))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode([BusinessBookingSlot].self, from: data)
    }

    static func requestPublicBooking(userID: String, payload: PublicBusinessBookingPayload) async throws -> BusinessBooking {
        var request = URLRequest(url: APIClient.url("businesses/\(userID)/bookings"))
        request.httpMethod = "POST"
        request.httpBody = try encoded(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await APIClient.authorizedData(for: request, context: "business_public_booking")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode(BusinessBooking.self, from: data)
    }

    static func myPublicBookings() async throws -> [BusinessBooking] {
        let request = URLRequest(url: APIClient.url("businesses/me/bookings"))
        let (data, response) = try await APIClient.authorizedData(for: request, context: "business_customer_bookings")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode([BusinessBooking].self, from: data)
    }

    static func cancelPublicBooking(id: String) async throws -> BusinessBooking {
        var request = URLRequest(url: APIClient.url("businesses/me/bookings/\(id)/cancel"))
        request.httpMethod = "POST"
        let (data, response) = try await APIClient.authorizedData(for: request, context: "business_customer_booking_cancel")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode(BusinessBooking.self, from: data)
    }

    static func workspaces() async throws -> [BusinessWorkspace] {
        let request = URLRequest(url: APIClient.url("businesses/me/workspaces"))
        let (data, response) = try await APIClient.authorizedData(for: request, context: "business_workspaces")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode([BusinessWorkspace].self, from: data)
    }

    static func workspaceDashboard(ownerID: String) async throws -> BusinessProDashboard {
        let request = URLRequest(url: APIClient.url("businesses/workspaces/\(ownerID)/dashboard"))
        let (data, response) = try await APIClient.authorizedData(for: request, context: "business_workspace_dashboard")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode(BusinessProDashboard.self, from: data)
    }

    static func updateWorkspaceLead(ownerID: String, id: String, payload: BusinessLeadUpdatePayload) async throws -> BusinessLead {
        var request = URLRequest(url: APIClient.url("businesses/workspaces/\(ownerID)/leads/\(id)"))
        request.httpMethod = "PATCH"
        request.httpBody = try encoded(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await APIClient.authorizedData(for: request, context: "business_workspace_lead")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode(BusinessLead.self, from: data)
    }

    static func updateWorkspaceBooking(ownerID: String, id: String, status: String) async throws -> BusinessBooking {
        struct Payload: Encodable { let status: String }
        var request = URLRequest(url: APIClient.url("businesses/workspaces/\(ownerID)/bookings/\(id)"))
        request.httpMethod = "PATCH"
        request.httpBody = try encoded(Payload(status: status))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await APIClient.authorizedData(for: request, context: "business_workspace_booking")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw error(data, response) }
        return try ChatAPI.decoder.decode(BusinessBooking.self, from: data)
    }
}
