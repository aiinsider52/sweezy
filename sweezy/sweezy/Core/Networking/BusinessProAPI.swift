import Foundation

enum BusinessProAPI {
    private struct Empty: Decodable {}

    private static func error(_ data: Data, _ response: URLResponse) -> NSError {
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        var message = "Не вдалося виконати запит"
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
