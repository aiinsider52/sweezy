import Foundation

enum APIClient {
    /// Base URL for the backend. Defaults to local dev server.
    static var baseURL: URL = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        // Default (validated) - production backend
        if let url = URL(string: "https://sweezy-9xyk.onrender.com") {
            return url
        }
        // Last-resort fallback (never used, but avoids force‑unwrap)
        return URL(fileURLWithPath: "/")
    }()

    private static let apiPrefix = "api/v1"

    static func url(_ path: String) -> URL {
        var p = path
        if p.hasPrefix("/") { p = String(p.dropFirst()) }
        if !p.hasPrefix("api/") { p = "\(apiPrefix)/\(p)" }
        return baseURL.appendingPathComponent(p)
    }

    // MARK: - Auth

    struct TokenPair: Decodable {
        let access_token: String
        let refresh_token: String
        let token_type: String?
        let expires_in: Int?
    }

    struct AuthStatusResponse: Decodable {
        let status: String
        let email: String?
        let message: String?
    }

    static func register(email: String, password: String) async throws -> AuthStatusResponse {
        let url = url("auth/register")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        let body = ["email": email, "password": password]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard httpResp.statusCode == 201 || httpResp.statusCode == 200 else {
            throw makeAPIError(data: data, response: httpResp, fallback: "Registration failed")
        }
        return try JSONDecoder().decode(AuthStatusResponse.self, from: data)
    }

    static func login(email: String, password: String) async throws -> TokenPair {
        let url = url("auth/login")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        let body = ["email": email, "password": password]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard httpResp.statusCode == 200 else {
            throw makeAPIError(data: data, response: httpResp, fallback: "Login failed")
        }
        return try JSONDecoder().decode(TokenPair.self, from: data)
    }

    static func requestEmailVerification(email: String) async throws -> AuthStatusResponse {
        let url = url("auth/verify-email/request")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(httpResp.statusCode) else {
            throw makeAPIError(data: data, response: httpResp, fallback: "Verification request failed")
        }
        return try JSONDecoder().decode(AuthStatusResponse.self, from: data)
    }

    static func confirmEmailVerification(email: String, code: String) async throws -> TokenPair {
        let url = url("auth/verify-email/confirm")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "code": code])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard httpResp.statusCode == 200 else {
            throw makeAPIError(data: data, response: httpResp, fallback: "Verification failed")
        }
        return try JSONDecoder().decode(TokenPair.self, from: data)
    }

    static func isEmailNotVerified(_ error: Error) -> Bool {
        let nsError = error as NSError
        return (nsError.userInfo["api.code"] as? String) == "EMAIL_NOT_VERIFIED"
    }

    static func refreshAccessToken() async throws -> TokenPair {
        guard let refreshToken = KeychainStore.get("refresh_token"), !refreshToken.isEmpty else {
            throw NSError(domain: "API", code: 401, userInfo: [NSLocalizedDescriptionKey: "Session expired. Please sign in again."])
        }

        let endpoint = url("auth/refresh")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResp.statusCode == 200 else {
            if let message = String(data: data, encoding: .utf8), !message.isEmpty {
                throw NSError(domain: "API", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw NSError(domain: "API", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: "Session expired. Please sign in again."])
        }
        let tokens = try JSONDecoder().decode(TokenPair.self, from: data)
        try KeychainStore.save(tokens.access_token, for: "access_token")
        try KeychainStore.save(tokens.refresh_token, for: "refresh_token")
        return tokens
    }

    static func deleteAccount() async throws {
        let url = url("auth/me")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.timeoutInterval = 15
        attachAuth(&req)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse, (200..<300).contains(httpResp.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Authorization helpers
    static func attachAuth(_ request: inout URLRequest) {
        if let token = KeychainStore.get("access_token"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    static func authorizedData(from url: URL) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url)
        return try await authorizedData(for: req, context: "authorized:\(url.lastPathComponent)")
    }

    static func authorizedData(for request: URLRequest, context: String) async throws -> (Data, URLResponse) {
        var req = request
        attachAuth(&req)
        let result = try await timedData(for: req, context: context)
        if let http = result.1 as? HTTPURLResponse, http.statusCode == 401 {
            let body = String(data: result.0, encoding: .utf8) ?? ""
            if body.localizedCaseInsensitiveContains("invalid authentication")
                || body.localizedCaseInsensitiveContains("invalid token")
                || body.localizedCaseInsensitiveContains("invalid user") {
                do {
                    _ = try await refreshAccessToken()
                    var retryReq = request
                    attachAuth(&retryReq)
                    return try await timedData(for: retryReq, context: "\(context)-retry")
                } catch {
                    KeychainStore.delete("access_token")
                    KeychainStore.delete("refresh_token")
                    throw error
                }
            }
        }
        return result
    }

    // MARK: - Content
    struct BackendGuide: Decodable { let id: String; let title: String; let slug: String; let description: String?; let content: String?; let category: String?; let image_url: String?; let is_published: Bool? }
    struct BackendTemplate: Decodable { let id: String; let name: String; let category: String?; let content: String }
    struct BackendChecklist: Decodable { let id: String; let title: String; let description: String?; let items: [String]; let is_published: Bool? }
    struct BackendNewsItem: Decodable { let id: String; let title: String; let summary: String; let content: String?; let url: String; let source: String; let language: String; let published_at: String; let image_url: String? }

    static func fetchGuides(limit: Int = 1000) async throws -> [BackendGuide] {
        let url = url("guides?limit=\(limit)")
        let (data, resp) = try await authorizedData(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
        return try JSONDecoder().decode([BackendGuide].self, from: data)
    }

    static func fetchTemplates(limit: Int = 1000) async throws -> [BackendTemplate] {
        let url = url("templates?limit=\(limit)")
        let (data, resp) = try await authorizedData(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
        return try JSONDecoder().decode([BackendTemplate].self, from: data)
    }

    static func fetchChecklists(limit: Int = 1000) async throws -> [BackendChecklist] {
        let url = url("checklists?limit=\(limit)")
        let (data, resp) = try await authorizedData(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
        return try JSONDecoder().decode([BackendChecklist].self, from: data)
    }
    
    static func fetchNews(limit: Int = 50, language: String? = nil) async throws -> [BackendNewsItem] {
        var path = "news?limit=\(limit)"
        if let language { path += "&language=\(language)" }
        let url = url(path)
        let (data, resp) = try await authorizedData(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
        return try JSONDecoder().decode([BackendNewsItem].self, from: data)
    }
    
    // MARK: - AI
    // Narrow payloads to avoid large/unsupported fields (e.g., photoData)
    private struct CVPersonalPayload: Encodable {
        let fullName: String
        let title: String
        let email: String
        let phone: String
        let location: String
        let summary: String
    }
    private struct CVEducationPayload: Encodable { let school: String; let degree: String; let period: String; let details: String }
    private struct CVExperiencePayload: Encodable { let id: String; let role: String; let company: String; let period: String; let location: String; let achievements: String }
    private struct CVLanguagePayload: Encodable { let name: String; let level: String }
    private struct CVAIRequest: Encodable {
        let personal: CVPersonalPayload
        let education: [CVEducationPayload]
        let experience: [CVExperiencePayload]
        let languages: [CVLanguagePayload]
        let skills: [String]
        let hobbies: [String]
        let target: String
    }
    struct CVAIResponse: Decodable { let text: String }
    
    enum CVGenerationTarget {
        case summary
        case experience(id: UUID)
    }
    
    static func generateCVText(resume: CVResume, target: CVGenerationTarget) async throws -> String {
        var targetKey = "summary"
        switch target {
        case .summary: targetKey = "summary"
        case .experience(let id): targetKey = "experience:\(id.uuidString)"
        }
        let url = url("ai/cv-suggest")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        attachAuth(&req)
        let payload = CVAIRequest(
            personal: .init(
                fullName: resume.personal.fullName,
                title: resume.personal.title,
                email: resume.personal.email,
                phone: resume.personal.phone,
                location: resume.personal.location,
                summary: resume.personal.summary
            ),
            education: resume.education.map { .init(school: $0.school, degree: $0.degree, period: $0.period, details: $0.details) },
            experience: resume.experience.map { .init(id: $0.id.uuidString, role: $0.role, company: $0.company, period: $0.period, location: $0.location, achievements: $0.achievements) },
            languages: resume.languages.map { .init(name: $0.name, level: $0.level) },
            skills: resume.skills,
            hobbies: resume.hobbies,
            target: targetKey
        )
        req.httpBody = try JSONEncoder().encode(payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(CVAIResponse.self, from: data)
        return decoded.text
    }
    
    // MARK: - Jobs
    struct JobItem: Codable, Identifiable, Hashable {
        let id: String
        let source: String
        let title: String
        let company: String?
        let location: String?
        let canton: String?
        let url: String
        let posted_at: String?
        let employment_type: String?
        let salary: String?
        let snippet: String?
    }
    struct JobSearchResponse: Codable { let items: [JobItem]; let total: Int?; let sources: [String:Int]? }
    
    static func searchJobs(keyword: String, canton: String?, page: Int = 1, perPage: Int = 20) async throws -> JobSearchResponse {
        // Build URL safely
        var comps = URLComponents(url: url("jobs/search"), resolvingAgainstBaseURL: false)
        var qItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        if let canton, !canton.isEmpty { qItems.append(URLQueryItem(name: "canton", value: canton)) }
        comps?.queryItems = qItems
        guard let finalURL = comps?.url ?? URL(string: url("jobs/search").absoluteString + "?q=\(keyword)") else {
            return JobSearchResponse(items: [], total: 0, sources: [:])
        }
        
        // Cache key (1h TTL)
        let cacheKey = "jobs|q=\(keyword)|canton=\(canton ?? "")|page=\(page)|per=\(perPage)"
        let ttl: TimeInterval = 3600
        
        do {
            let (data, resp) = try await timedData(from: finalURL, context: "jobs_search")
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                if let cached = loadJobSearchCache(for: cacheKey, ttl: ttl) { return cached }
                return JobSearchResponse(items: [], total: 0, sources: [:])
            }
            let decoded = (try? JSONDecoder().decode(JobSearchResponse.self, from: data)) ?? JobSearchResponse(items: [], total: 0, sources: [:])
            saveJobSearchCache(decoded, for: cacheKey)
            return decoded
        } catch {
            if let cached = loadJobSearchCache(for: cacheKey, ttl: ttl) { return cached }
            throw error
        }
    }
    
    static func draftJobApplication(title: String, company: String?, description: String?, language: String?) async -> String? {
        let url = url("ai/job-apply")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any?] = [
            "jobTitle": title,
            "company": company,
            "description": description,
            "language": language
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            let decoded = try JSONDecoder().decode(CVAIResponse.self, from: data)
            return decoded.text
        } catch {
            return nil
        }
    }
    
    // MARK: - Subscriptions
    struct SubscriptionCurrent: Decodable {
        let status: String
        let expire_at: String?
    }
    struct Entitlements: Decodable {
        let status: String
        let expire_at: String?
        let is_premium: Bool
        let ai_access: Bool
        let favorites_limit: Int?
        let guides_full_access: Bool
        let pdf_download: Bool
    }
    
    static func subscriptionCurrent() async -> SubscriptionCurrent? {
        let url = url("subscriptions/current")
        do {
            let (data, resp) = try await authorizedData(from: url)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return try JSONDecoder().decode(SubscriptionCurrent.self, from: data)
        } catch {
            return nil
        }
    }
    
    static func fetchEntitlements() async -> Entitlements? {
        let url = url("subscriptions/entitlements")
        do {
            let (data, resp) = try await authorizedData(from: url)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return try JSONDecoder().decode(Entitlements.self, from: data)
        } catch {
            return nil
        }
    }
    
    static func startTrial() async -> SubscriptionCurrent? {
        let url = url("subscriptions/trial")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        attachAuth(&req)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return try JSONDecoder().decode(SubscriptionCurrent.self, from: data)
        } catch {
            return nil
        }
    }
    
    static func createCheckout(plan: String, promotionCode: String? = nil) async -> URL? {
        let url = url("subscriptions/checkout")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        attachAuth(&req)
        // Use backend base URL as success/cancel for browser flow
        let success = baseURL.appendingPathComponent("ready").absoluteString
        let cancel = baseURL.appendingPathComponent("ready").absoluteString
        var body: [String: Any] = ["plan": plan, "success_url": success, "cancel_url": cancel]
        if let promotionCode, !promotionCode.isEmpty {
            body["promotion_code"] = promotionCode
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let urlStr = dict["url"] as? String, let u = URL(string: urlStr) {
                return u
            }
            return nil
        } catch {
            return nil
        }
    }
    
    // MARK: - Job Favorites
    enum AddFavoriteOutcome {
        case success
        case upgradeRequired
        case failure
    }
    struct JobFavorite: Decodable { let id: String }
    
    static func listJobFavorites() async -> [JobFavorite] {
        let url = url("jobs/favorites")
        do {
            let (data, resp) = try await authorizedData(from: url)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
            return (try? JSONDecoder().decode([JobFavorite].self, from: data)) ?? []
        } catch {
            return []
        }
    }
    @discardableResult
    static func addJobFavorite(job: JobItem) async -> AddFavoriteOutcome {
        let url = url("jobs/favorites")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        attachAuth(&req)
        let payload: [String: Any?] = [
            "job_id": job.id,
            "source": job.source,
            "title": job.title,
            "company": job.company,
            "location": job.location,
            "canton": job.canton,
            "url": job.url
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 })
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return .failure }
            if (200..<300).contains(http.statusCode) { return .success }
            if http.statusCode == 402 { return .upgradeRequired }
            return .failure
        } catch {
            return .failure
        }
    }
    
    @discardableResult
    static func removeJobFavorite(jobId: String, source: String) async -> Bool {
        // Try path variant first
        var req = URLRequest(url: url("jobs/favorites/\(jobId)"))
        req.httpMethod = "DELETE"
        attachAuth(&req)
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) { return true }
        } catch {
            // fallthrough to query-variant
        }
        // Fallback variant with query
        var comps = URLComponents(url: url("jobs/favorites"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "job_id", value: jobId), URLQueryItem(name: "source", value: source)]
        guard let url2 = comps?.url else { return false }
        var req2 = URLRequest(url: url2)
        req2.httpMethod = "DELETE"
        attachAuth(&req2)
        do {
            let (_, resp) = try await URLSession.shared.data(for: req2)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Live place status
    struct BackendPlaceLiveStatus: Decodable {
        let wait_minutes: Int?
        let busy_level: String?
        let closes_at: String?
        let updated_at: String
        let provider: String
        let hours_text: String?
    }
    
    static func fetchPlaceLiveStatus(name: String, category: String?, canton: String?, lat: Double?, lng: Double?) async -> BackendPlaceLiveStatus? {
        var comps = URLComponents(url: url("live/place-status"), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = [URLQueryItem(name: "name", value: name)]
        if let category { items.append(URLQueryItem(name: "category", value: category)) }
        if let canton { items.append(URLQueryItem(name: "canton", value: canton)) }
        if let lat { items.append(URLQueryItem(name: "lat", value: String(lat))) }
        if let lng { items.append(URLQueryItem(name: "lng", value: String(lng))) }
        comps?.queryItems = items
        guard let finalURL = comps?.url else { return nil }
        do {
            let (data, resp) = try await timedData(from: finalURL, context: "place_live_status")
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return try JSONDecoder().decode(BackendPlaceLiveStatus.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Password reset (optional backend)
    static func requestPasswordReset(email: String) async throws -> AuthStatusResponse {
        let url = url("auth/password/forgot")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        AppLogger.auth("password/forgot status = \(http.statusCode)")
        guard (200..<300).contains(http.statusCode) else {
            if let body = String(data: data, encoding: .utf8) {
                AppLogger.auth("password/forgot error body: \(body)", isError: true)
            }
            throw makeAPIError(data: data, response: http, fallback: "Password reset request failed")
        }
        return try JSONDecoder().decode(AuthStatusResponse.self, from: data)
    }

    static func resetPassword(email: String, code: String, newPassword: String) async throws -> AuthStatusResponse {
        let url = url("auth/password/reset")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "code": code, "password": newPassword])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            throw makeAPIError(data: data, response: http, fallback: "Password reset failed")
        }
        return try JSONDecoder().decode(AuthStatusResponse.self, from: data)
    }
}

// MARK: - Marketplace
extension APIClient {
    private static func makeAPIError(data: Data, response: HTTPURLResponse?, fallback: String) -> NSError {
        let status = response?.statusCode ?? 0
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = jsonObject["detail"] {
            if let detailString = detail as? String {
                return NSError(domain: "API", code: status, userInfo: [NSLocalizedDescriptionKey: detailString])
            }
            if let detailObject = detail as? [String: Any] {
                let message = (detailObject["message"] as? String) ?? fallback
                var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
                if let apiCode = detailObject["code"] as? String {
                    userInfo["api.code"] = apiCode
                }
                return NSError(domain: "API", code: status, userInfo: userInfo)
            }
        }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return NSError(domain: "API", code: status, userInfo: [NSLocalizedDescriptionKey: text])
        }
        return NSError(domain: "API", code: status, userInfo: [NSLocalizedDescriptionKey: fallback])
    }

    private static func httpError(data: Data, response: URLResponse?) -> Error {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return NSError(domain: "API", code: status, userInfo: [NSLocalizedDescriptionKey: text])
        }
        return URLError(.badServerResponse)
    }

    private static func marketplaceJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }

    static func fetchListings(category: ServiceCategory? = nil,
                              canton: String? = nil,
                              page: Int = 1) async throws -> ServiceListingPage {
        var comps = URLComponents(url: url("marketplace"), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = [URLQueryItem(name: "page", value: String(page))]
        if let category { items.append(URLQueryItem(name: "category", value: category.rawValue)) }
        if let canton, canton != "all" { items.append(URLQueryItem(name: "canton", value: canton)) }
        comps?.queryItems = items
        guard let finalURL = comps?.url else { throw URLError(.badURL) }
        let (data, resp) = try await timedData(from: finalURL, context: "marketplace_list")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ServiceListingPage.self, from: data)
    }

    static func fetchListingDetail(id: String) async throws -> ServiceListing {
        let (data, resp) = try await timedData(from: url("marketplace/\(id)"), context: "marketplace_detail")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ServiceListing.self, from: data)
    }

    static func createListing(_ listing: ServiceListingCreate) async throws -> ServiceListing {
        let endpoint = url("marketplace")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = try marketplaceJSONEncoder().encode(listing)
        let (data, resp) = try await authorizedData(for: req, context: "marketplace_create")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let msg = String(data: data, encoding: .utf8) {
                throw NSError(domain: "API", code: (resp as? HTTPURLResponse)?.statusCode ?? 0,
                              userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ServiceListing.self, from: data)
    }

    static func fetchMyListings() async throws -> [ServiceListing] {
        let endpoint = url("marketplace/my")
        let (data, resp) = try await authorizedData(from: endpoint)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw httpError(data: data, response: resp)
        }
        return try JSONDecoder().decode([ServiceListing].self, from: data)
    }

    static func updateListing(id: String, payload: ServiceListingUpdate) async throws -> ServiceListing {
        var req = URLRequest(url: url("marketplace/\(id)"))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = try JSONEncoder().encode(payload)
        let (data, resp) = try await authorizedData(for: req, context: "marketplace_update")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let msg = String(data: data, encoding: .utf8) {
                throw NSError(
                    domain: "API",
                    code: (resp as? HTTPURLResponse)?.statusCode ?? 0,
                    userInfo: [NSLocalizedDescriptionKey: msg]
                )
            }
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ServiceListing.self, from: data)
    }

    static func fetchEvents(category: EventCategory? = nil,
                            canton: String? = nil,
                            page: Int = 1) async throws -> EventListingPage {
        var comps = URLComponents(url: url("events"), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "upcoming_only", value: "true"),
        ]
        if let category { items.append(URLQueryItem(name: "category", value: category.rawValue)) }
        if let canton, canton != "all" { items.append(URLQueryItem(name: "canton", value: canton)) }
        comps?.queryItems = items
        guard let finalURL = comps?.url else { throw URLError(.badURL) }
        let (data, resp) = try await timedData(from: finalURL, context: "events_list")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(EventListingPage.self, from: data)
    }

    static func fetchEventDetail(id: String) async throws -> EventListing {
        let (data, resp) = try await timedData(from: url("events/\(id)"), context: "event_detail")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(EventListing.self, from: data)
    }

    static func createEvent(_ event: EventListingCreate) async throws -> EventListing {
        let endpoint = url("events")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = try marketplaceJSONEncoder().encode(event)
        let (data, resp) = try await authorizedData(for: req, context: "events_create")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let msg = String(data: data, encoding: .utf8) {
                throw NSError(domain: "API", code: (resp as? HTTPURLResponse)?.statusCode ?? 0,
                              userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(EventListing.self, from: data)
    }

    static func fetchMyEvents() async throws -> [EventListing] {
        let endpoint = url("events/my")
        let (data, resp) = try await authorizedData(from: endpoint)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw httpError(data: data, response: resp)
        }
        return try JSONDecoder().decode([EventListing].self, from: data)
    }

    static func updateEvent(id: String, payload: EventListingUpdate) async throws -> EventListing {
        var req = URLRequest(url: url("events/\(id)"))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = try marketplaceJSONEncoder().encode(payload)
        let (data, resp) = try await authorizedData(for: req, context: "events_update")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let msg = String(data: data, encoding: .utf8) {
                throw NSError(domain: "API", code: (resp as? HTTPURLResponse)?.statusCode ?? 0,
                              userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(EventListing.self, from: data)
    }

    static func deleteEvent(id: String) async throws {
        var req = URLRequest(url: url("events/\(id)"))
        req.httpMethod = "DELETE"
        req.timeoutInterval = 15
        let (_, resp) = try await authorizedData(for: req, context: "events_delete")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    static func deleteListing(id: String) async throws {
        var req = URLRequest(url: url("marketplace/\(id)"))
        req.httpMethod = "DELETE"
        req.timeoutInterval = 15
        let (_, resp) = try await authorizedData(for: req, context: "marketplace_delete")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - Analytics
extension APIClient {
    static func logPaywall(eventType: String, context: String?) {
        Task.detached {
            let url = url("analytics/paywall")
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            attachAuth(&req)
            var body: [String: Any] = ["event_type": eventType]
            if let context, !context.isEmpty { body["context"] = context }
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: req)
        }
    }
}

// MARK: - Telemetry
extension APIClient {
    struct TelemetryEventPayload: Encodable {
        let id: String
        let ts: String
        let level: String
        let source: String
        let type: String
        let message: String?
        let meta: [String: String]?
    }
    
    static func sendTelemetryBatch(events: [TelemetryEventPayload]) async throws {
        guard !events.isEmpty else { return }
        let url = url("telemetry/batch")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        attachAuth(&req)
        let body = ["events": events.map { e -> [String: Any] in
            var dict: [String: Any] = [
                "id": e.id, "ts": e.ts, "level": e.level, "source": e.source, "type": e.type
            ]
            if let m = e.message { dict["message"] = m }
            if let meta = e.meta { dict["meta"] = meta }
            return dict
        }]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    private static func isoNow() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
    }
    
    static func quickTelemetry(level: String = "info", source: String, type: String, message: String? = nil, meta: [String:String]? = nil) {
        Task.detached {
            let payload = TelemetryEventPayload(id: UUID().uuidString, ts: isoNow(), level: level, source: source, type: type, message: message, meta: meta)
            try? await sendTelemetryBatch(events: [payload])
        }
    }
}

// MARK: - Simple file cache for job search
extension APIClient {
    private static func jobsCacheURL(for key: String) -> URL? {
        do {
            let dir = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let name = "jobs-\(key.hashValue).json"
            return dir.appendingPathComponent(name)
        } catch {
            return nil
        }
    }
    
    private static func saveJobSearchCache(_ resp: JobSearchResponse, for key: String) {
        guard let url = jobsCacheURL(for: key) else { return }
        do {
            let data = try JSONEncoder().encode(resp)
            try data.write(to: url, options: .atomic)
        } catch { /* ignore */ }
    }
    
    private static func loadJobSearchCache(for key: String, ttl: TimeInterval) -> JobSearchResponse? {
        guard let url = jobsCacheURL(for: key) else { return nil }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let mdate = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(mdate) <= ttl else { return nil }
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(JobSearchResponse.self, from: data) else { return nil }
        return decoded
    }
}

// MARK: - Backend DTOs

struct BackendRemoteConfig: Decodable {
    let app_version: String
    let flags: [String: Bool]
}

// MARK: - Network helpers (timing + lightweight retry/backoff)
extension APIClient {
    private static func shouldRetry(error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
    
    static func timedData(for request: URLRequest, context: String) async throws -> (Data, URLResponse) {
        var attempt = 0
        var currentDelay: UInt64 = 250_000_000 // 250ms
        while true {
            let start = CFAbsoluteTimeGetCurrent()
            do {
                let result = try await URLSession.shared.data(for: request)
                let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
                if ms > 2000 {
                    quickTelemetry(level: "warn", source: "network", type: "slow", message: nil, meta: ["ctx": context, "ms": String(format: "%.0f", ms)])
                }
                return result
            } catch {
                if let urlError = error as? URLError, shouldRetry(error: urlError), attempt < 1 {
                    attempt += 1
                    try? await Task.sleep(nanoseconds: currentDelay)
                    currentDelay *= 2
                    continue
                } else {
                    quickTelemetry(level: "error", source: "network", type: "failure", message: "\(error)", meta: ["ctx": context])
                    throw error
                }
            }
        }
    }
    
    static func timedData(from url: URL, context: String) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url)
        return try await timedData(for: req, context: context)
    }
}


