import Foundation

enum NetworkAPI {
    private struct ConnectionPayload: Encodable { let message: String? }
    private struct DecisionPayload: Encodable { let status: String }
    private struct ReportPayload: Encodable { let reason: String; let details: String? }

    private static func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        bodyData: Data? = nil
    ) async throws -> T {
        var request = URLRequest(url: APIClient.url(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        if let bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }
        let (data, response) = try await APIClient.authorizedData(for: request, context: "network_\(method.lowercased())")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"]
            let message = (detail as? String) ?? "Не вдалося виконати запит"
            throw NSError(
                domain: "NetworkAPI",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        return try ChatAPI.decoder.decode(T.self, from: data)
    }

    private static func requestWithoutResponse(
        _ path: String,
        method: String,
        bodyData: Data? = nil
    ) async throws {
        var request = URLRequest(url: APIClient.url(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        if let bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }
        let (data, response) = try await APIClient.authorizedData(for: request, context: "network_\(method.lowercased())")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw NSError(
                domain: "NetworkAPI",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: detail ?? "Не вдалося виконати запит"]
            )
        }
    }

    static func profiles(
        query: String = "",
        canton: String? = nil,
        role: ProfessionalRole? = nil,
        goal: ProfessionalGoal? = nil,
        page: Int = 1
    ) async throws -> ProfessionalProfilePage {
        var components = URLComponents(url: APIClient.url("network/profiles"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            query.isEmpty ? nil : URLQueryItem(name: "q", value: query),
            canton.map { URLQueryItem(name: "canton", value: $0) },
            role.map { URLQueryItem(name: "role", value: $0.rawValue) },
            goal.map { URLQueryItem(name: "goal", value: $0.rawValue) },
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: "30")
        ].compactMap { $0 }

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        let (data, response) = try await APIClient.authorizedData(for: request, context: "network_profiles")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw NSError(domain: "NetworkAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          userInfo: [NSLocalizedDescriptionKey: detail ?? "Каталог тимчасово недоступний"])
        }
        return try ChatAPI.decoder.decode(ProfessionalProfilePage.self, from: data)
    }

    static func myProfile() async throws -> ProfessionalProfile {
        try await request("network/profile/me")
    }

    static func saveProfile(_ draft: ProfessionalProfileDraft) async throws -> ProfessionalProfile {
        try await request("network/profile/me", method: "PUT", bodyData: try JSONEncoder().encode(draft))
    }

    static func profile(userID: String) async throws -> ProfessionalProfile {
        try await request("network/profiles/\(userID)")
    }

    static func connect(userID: String, message: String?) async throws -> ProfessionalConnection {
        try await request(
            "network/profiles/\(userID)/connect",
            method: "POST",
            bodyData: try JSONEncoder().encode(ConnectionPayload(message: message))
        )
    }

    static func connections(box: String = "all") async throws -> [ProfessionalConnection] {
        try await request("network/connections?box=\(box)")
    }

    static func respond(connectionID: String, accept: Bool) async throws -> ProfessionalConnection {
        try await request(
            "network/connections/\(connectionID)",
            method: "PATCH",
            bodyData: try JSONEncoder().encode(DecisionPayload(status: accept ? "accepted" : "declined"))
        )
    }

    static func cancel(connectionID: String) async throws {
        try await requestWithoutResponse("network/connections/\(connectionID)", method: "DELETE")
    }

    static func report(userID: String, reason: String, details: String?) async throws {
        let _: NetworkActionResponse = try await request(
            "network/profiles/\(userID)/report",
            method: "POST",
            bodyData: try JSONEncoder().encode(ReportPayload(reason: reason, details: details))
        )
    }

    static func block(userID: String) async throws {
        let _: NetworkActionResponse = try await request("network/profiles/\(userID)/block", method: "POST")
    }
}

private struct NetworkActionResponse: Decodable {
    let ok: Bool
    let message: String
}
