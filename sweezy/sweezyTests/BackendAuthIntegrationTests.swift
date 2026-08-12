import XCTest

final class BackendAuthIntegrationTests: XCTestCase {
    private var baseURL: URL!
    private var email: String!
    private var password: String!

    override func setUpWithError() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let rawURL = environment["AUTH_E2E_BASE_URL"],
              let resolvedURL = URL(string: rawURL),
              let resolvedEmail = environment["AUTH_E2E_EMAIL"],
              let resolvedPassword = environment["AUTH_E2E_PASSWORD"] else {
            throw XCTSkip("Set AUTH_E2E_BASE_URL, AUTH_E2E_EMAIL and AUTH_E2E_PASSWORD")
        }
        baseURL = resolvedURL
        email = resolvedEmail
        password = resolvedPassword
    }

    func testLoginAuthenticatedRequestRefreshAndInvalidToken() async throws {
        let login = try await request(
            path: "api/v1/auth/login",
            method: "POST",
            body: ["email": email, "password": password]
        )
        XCTAssertEqual(login.statusCode, 200)
        let tokens = try XCTUnwrap(try JSONSerialization.jsonObject(with: login.data) as? [String: Any])
        let accessToken = try XCTUnwrap(tokens["access_token"] as? String)
        let refreshToken = try XCTUnwrap(tokens["refresh_token"] as? String)
        XCTAssertFalse(accessToken.isEmpty)
        XCTAssertFalse(refreshToken.isEmpty)

        let me = try await request(path: "api/v1/auth/me", bearer: accessToken)
        XCTAssertEqual(me.statusCode, 200)
        let user = try XCTUnwrap(try JSONSerialization.jsonObject(with: me.data) as? [String: Any])
        XCTAssertEqual(user["email"] as? String, email)

        let refreshed = try await request(
            path: "api/v1/auth/refresh",
            method: "POST",
            body: ["refresh_token": refreshToken]
        )
        XCTAssertEqual(refreshed.statusCode, 200)
        let refreshedTokens = try XCTUnwrap(try JSONSerialization.jsonObject(with: refreshed.data) as? [String: Any])
        XCTAssertNotNil(refreshedTokens["access_token"] as? String)

        let rejected = try await request(path: "api/v1/auth/me", bearer: "invalid-token")
        XCTAssertEqual(rejected.statusCode, 401)
    }

    private func request(
        path: String,
        method: String = "GET",
        body: [String: String]? = nil,
        bearer: String? = nil
    ) async throws -> (data: Data, statusCode: Int) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 10
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, try XCTUnwrap(response as? HTTPURLResponse).statusCode)
    }
}
