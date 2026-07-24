import Foundation

enum ChatAPI {
    private struct ConversationCreatePayload: Encodable { let listingID: String; enum CodingKeys: String, CodingKey { case listingID = "listing_id" } }
    private struct MessageCreatePayload: Encodable { let clientMessageID: String; let body: String; enum CodingKeys: String, CodingKey { case clientMessageID = "client_message_id"; case body } }
    private struct ReadPayload: Encodable { let messageID: String; enum CodingKeys: String, CodingKey { case messageID = "message_id" } }
    private struct ConversationUpdatePayload: Encodable { let muted: Bool?; let archived: Bool? }
    private struct ReportPayload: Encodable { let reason: String; let details: String? }
    private struct ReviewPayload: Encodable { let rating: Int; let comment: String? }
    private struct UnreadResponse: Decodable { let count: Int }
    private struct PushPayload: Encodable { let token: String; let environment: String }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
        }
        return decoder
    }()

    private static func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        as type: T.Type
    ) async throws -> T {
        var request = URLRequest(url: APIClient.url(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        let (data, response) = try await APIClient.authorizedData(for: request, context: "chat_\(method.lowercased())")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw NSError(domain: "ChatAPI", code: status, userInfo: [NSLocalizedDescriptionKey: detail ?? "Не вдалося виконати запит"])
        }
        return try decoder.decode(type, from: data)
    }

    private static func requestWithoutResponse(_ path: String, method: String, body: Encodable? = nil) async throws {
        var request = URLRequest(url: APIClient.url(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        let (data, response) = try await APIClient.authorizedData(for: request, context: "chat_\(method.lowercased())")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw NSError(domain: "ChatAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          userInfo: [NSLocalizedDescriptionKey: detail ?? "Не вдалося виконати запит"])
        }
    }

    static func createConversation(listingID: String) async throws -> ChatConversation {
        try await request("chat/conversations", method: "POST", body: ConversationCreatePayload(listingID: listingID), as: ChatConversation.self)
    }

    static func conversation(id: String) async throws -> ChatConversation {
        try await request("chat/conversations/\(id)", as: ChatConversation.self)
    }

    static func conversations(archived: Bool = false, cursor: String? = nil) async throws -> ChatConversationPage {
        var path = "chat/conversations?archived=\(archived)"
        if let cursor, let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "&cursor=\(encoded)"
        }
        return try await request(path, as: ChatConversationPage.self)
    }

    static func messages(conversationID: String, before: String? = nil) async throws -> ChatMessagePage {
        var path = "chat/conversations/\(conversationID)/messages"
        if let before, let encoded = before.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?before=\(encoded)"
        }
        return try await request(path, as: ChatMessagePage.self)
    }

    static func send(conversationID: String, clientMessageID: String, body: String) async throws -> ChatMessage {
        try await request(
            "chat/conversations/\(conversationID)/messages",
            method: "POST",
            body: MessageCreatePayload(clientMessageID: clientMessageID, body: body),
            as: ChatMessage.self
        )
    }

    static func markRead(conversationID: String, messageID: String) async throws {
        try await requestWithoutResponse(
            "chat/conversations/\(conversationID)/read",
            method: "POST",
            body: ReadPayload(messageID: messageID)
        )
    }

    static func update(conversationID: String, muted: Bool? = nil, archived: Bool? = nil) async throws -> ChatConversation {
        try await request(
            "chat/conversations/\(conversationID)",
            method: "PATCH",
            body: ConversationUpdatePayload(muted: muted, archived: archived),
            as: ChatConversation.self
        )
    }

    static func close(conversationID: String) async throws -> ChatConversation {
        try await request("chat/conversations/\(conversationID)/close", method: "POST", as: ChatConversation.self)
    }

    static func report(messageID: String, reason: String, details: String? = nil) async throws {
        try await requestWithoutResponse(
            "chat/messages/\(messageID)/report",
            method: "POST",
            body: ReportPayload(reason: reason, details: details)
        )
    }

    static func block(conversationID: String) async throws {
        try await requestWithoutResponse("chat/conversations/\(conversationID)/block", method: "POST")
    }

    static func review(conversationID: String, rating: Int, comment: String?) async throws {
        try await requestWithoutResponse(
            "chat/conversations/\(conversationID)/review",
            method: "POST",
            body: ReviewPayload(rating: rating, comment: comment)
        )
    }

    static func unreadCount() async throws -> Int {
        let response: UnreadResponse = try await request("chat/conversations/unread-count", as: UnreadResponse.self)
        return response.count
    }

    static func registerPush(token: String, environment: String) async throws {
        try await requestWithoutResponse("devices/push", method: "POST", body: PushPayload(token: token, environment: environment))
    }

    static func unregisterPush(token: String) async throws {
        try await requestWithoutResponse("devices/push/\(token)", method: "DELETE")
    }

    /// Logout-safe variant: uses the captured access token even after local credentials are cleared.
    static func unregisterPush(token: String, accessToken: String) async throws {
        var request = URLRequest(url: APIClient.url("devices/push/\(token)"))
        request.httpMethod = "DELETE"
        request.timeoutInterval = 10
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(
                domain: "ChatAPI",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: "Не вдалося відключити push-сповіщення"]
            )
        }
    }

    static func webSocketRequest() -> URLRequest? {
        var components = URLComponents(url: APIClient.url("chat/ws"), resolvingAgainstBaseURL: false)
        let isSecure = components?.scheme == "https"
        components?.scheme = isSecure ? "wss" : "ws"
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        APIClient.attachAuth(&request)
        return request
    }
}

private struct AnyEncodable: Encodable {
    private let encodeBlock: (Encoder) throws -> Void
    init(_ value: Encodable) { encodeBlock = value.encode }
    func encode(to encoder: Encoder) throws { try encodeBlock(encoder) }
}
