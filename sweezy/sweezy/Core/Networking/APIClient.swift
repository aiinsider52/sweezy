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

        let parts = p.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let endpoint = baseURL.appendingPathComponent(String(parts[0]))
        guard parts.count == 2,
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return endpoint
        }

        components.percentEncodedQuery = String(parts[1])
        return components.url ?? endpoint
    }

    // MARK: - Auth

    struct TokenPair: Decodable {
        let access_token: String
        let refresh_token: String
        let token_type: String?
        let expires_in: Int?
        let user_id: String
        let email: String
    }

    struct AuthStatusResponse: Decodable {
        let status: String
        let user_id: String?
        let email: String?
        let message: String?
    }

    struct SocialAuthResponse: Decodable, Identifiable {
        let status: String
        let email: String?
        let message: String?
        let provider: String?
        let name: String?
        let access_token: String?
        let refresh_token: String?
        let token_type: String?
        let expires_in: Int?
        let link_token: String?
        let user_id: String?

        var id: String {
            if let linkToken = link_token, !linkToken.isEmpty { return linkToken }
            if let accessToken = access_token, !accessToken.isEmpty { return accessToken }
            return "\(provider ?? "social"):\(email ?? "unknown"):\(status)"
        }

        var tokenPair: TokenPair? {
            guard let access_token, let refresh_token else { return nil }
            return TokenPair(
                access_token: access_token,
                refresh_token: refresh_token,
                token_type: token_type,
                expires_in: expires_in,
                user_id: user_id ?? "",
                email: email ?? ""
            )
        }
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

    static func signInWithApple(
        idToken: String,
        authorizationCode: String?,
        nonce: String?,
        fullName: String?
    ) async throws -> SocialAuthResponse {
        let url = url("auth/oauth/apple")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "id_token": idToken,
            "authorization_code": authorizationCode as Any,
            "nonce": nonce as Any,
            "full_name": fullName as Any,
        ].compactMapValues { $0 })

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(httpResp.statusCode) else {
            throw makeAPIError(data: data, response: httpResp, fallback: "Apple Sign-In failed")
        }
        return try JSONDecoder().decode(SocialAuthResponse.self, from: data)
    }

    static func signInWithGoogle(
        idToken: String,
        fullName: String?
    ) async throws -> SocialAuthResponse {
        let url = url("auth/oauth/google")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "id_token": idToken,
            "full_name": fullName as Any,
        ].compactMapValues { $0 })

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(httpResp.statusCode) else {
            throw makeAPIError(data: data, response: httpResp, fallback: "Google Sign-In failed")
        }
        return try JSONDecoder().decode(SocialAuthResponse.self, from: data)
    }

    static func confirmSocialLink(
        email: String,
        password: String,
        linkToken: String
    ) async throws -> SocialAuthResponse {
        let url = url("auth/oauth/link/confirm")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "link_token": linkToken,
        ])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(httpResp.statusCode) else {
            throw makeAPIError(data: data, response: httpResp, fallback: "Account link confirmation failed")
        }
        return try JSONDecoder().decode(SocialAuthResponse.self, from: data)
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
        try KeychainStore.save(tokens.user_id, for: "user_id")
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
        let req = URLRequest(url: url)
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
    struct BackendGuide: Decodable { let id: String; let title: String; let slug: String; let description: String?; let content: String?; let category: String?; let image_url: String?; let source_url: String?; let source_title: String?; let verified_at: String?; let is_published: Bool? }
    struct BackendTemplate: Decodable { let id: String; let name: String; let category: String?; let content: String }
    struct BackendChecklist: Decodable { let id: String; let title: String; let description: String?; let items: [String]; let source_url: String?; let source_title: String?; let verified_at: String?; let is_published: Bool? }
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
        let workplace_type: String?
        let workload_min: Int?
        let workload_max: Int?
        let salary: String?
        let salary_min: Int?
        let salary_max: Int?
        let salary_currency: String?
        let salary_period: String?
        let snippet: String?
        let description: String?
        let languages: [String]?
        let skills: [String]?
        let permit_requirements: [String]?
        let experience_level: String?
        let no_experience_required: Bool?
        let degree_required: Bool?
        let recognition_required: Bool?
        let latitude: Double?
        let longitude: Double?
        let is_verified: Bool?
        let is_promoted: Bool?
        let can_message: Bool?
        let status: String?
        let freshness: String?
        let expires_at: String?
    }
    struct JobProviderHealth: Codable, Hashable {
        let provider: String
        let configured: Bool
        let status: String
        let last_success_at: String?
        let last_item_count: Int
        let message: String?
    }
    struct JobSearchResponse: Codable {
        let items: [JobItem]
        let total: Int?
        let page: Int?
        let per_page: Int?
        let pages: Int?
        let sources: [String:Int]?
        let catalog_status: String?
        let is_stale: Bool?
        let providers: [JobProviderHealth]?
    }
    
    static func searchJobs(
        keyword: String,
        canton: String?,
        employmentType: String? = nil,
        workplaceType: String? = nil,
        noExperience: Bool? = nil,
        noDegree: Bool? = nil,
        minSalary: Int? = nil,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> JobSearchResponse {
        // Build URL safely
        var comps = URLComponents(url: url("jobs/search"), resolvingAgainstBaseURL: false)
        var qItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        if let canton, !canton.isEmpty { qItems.append(URLQueryItem(name: "canton", value: canton)) }
        if let employmentType, !employmentType.isEmpty { qItems.append(URLQueryItem(name: "employment_type", value: employmentType)) }
        if let workplaceType, !workplaceType.isEmpty { qItems.append(URLQueryItem(name: "workplace_type", value: workplaceType)) }
        if let noExperience { qItems.append(URLQueryItem(name: "no_experience", value: String(noExperience))) }
        if let noDegree { qItems.append(URLQueryItem(name: "no_degree", value: String(noDegree))) }
        if let minSalary { qItems.append(URLQueryItem(name: "min_salary", value: String(minSalary))) }
        comps?.queryItems = qItems
        guard let finalURL = comps?.url ?? URL(string: url("jobs/search").absoluteString + "?q=\(keyword)") else {
            throw URLError(.badURL)
        }
        
        // Catalog is server-backed. Keep short offline cache; never cache empty/provider-error states.
        let cacheKey = "jobs|q=\(keyword)|canton=\(canton ?? "")|employment=\(employmentType ?? "")|workplace=\(workplaceType ?? "")|experience=\(String(describing: noExperience))|degree=\(String(describing: noDegree))|salary=\(minSalary ?? 0)|page=\(page)|per=\(perPage)"
        let ttl: TimeInterval = 300
        
        do {
            let (data, resp) = try await timedData(from: finalURL, context: "jobs_search")
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                if let cached = loadJobSearchCache(for: cacheKey, ttl: ttl) { return cached }
                guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                throw makeAPIError(data: data, response: http, fallback: "Job catalog unavailable")
            }
            let decoded = try JSONDecoder().decode(JobSearchResponse.self, from: data)
            if !decoded.items.isEmpty && decoded.catalog_status != "source_unavailable" {
                saveJobSearchCache(decoded, for: cacheKey)
            }
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
    struct JobFavorite: Decodable {
        let id: String
        let job_id: String
    }
    
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
        var req = URLRequest(url: url("jobs/favorites/by-job/\(jobId)"))
        req.httpMethod = "DELETE"
        attachAuth(&req)
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) { return true }
        } catch {
            // fallthrough to query-variant
        }
        return false
    }

    struct JobApplication: Codable, Identifiable {
        let id: String
        let job_id: String
        let job_title: String
        let company: String?
        let location: String?
        let source: String
        let job_url: String
        let status: String
        let notes: String?
        let cover_letter: String?
        let applied_at: String?
        let next_action_at: String?
        let created_at: String
        let updated_at: String
    }

    struct EmployerJobApplication: Codable, Identifiable {
        let id: String
        let job_id: String
        let job_title: String
        let company: String?
        let location: String?
        let source: String
        let job_url: String
        let status: String
        let notes: String?
        let cover_letter: String?
        let applied_at: String?
        let next_action_at: String?
        let created_at: String
        let updated_at: String
        let candidate_id: String
        let candidate_email: String
    }

    static func listJobApplications() async throws -> [JobApplication] {
        let (data, response) = try await authorizedData(from: url("jobs/applications"))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([JobApplication].self, from: data)
    }

    static func updateJobApplication(
        jobId: String,
        status: String,
        notes: String? = nil,
        coverLetter: String? = nil,
        nextActionAt: Date? = nil
    ) async throws -> JobApplication {
        var request = URLRequest(url: url("jobs/applications/\(jobId)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = ["job_id": jobId, "status": status]
        if let notes { payload["notes"] = notes }
        if let coverLetter { payload["cover_letter"] = coverLetter }
        if let nextActionAt { payload["next_action_at"] = ISO8601DateFormatter().string(from: nextActionAt) }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await authorizedData(for: request, context: "job_application_update")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(JobApplication.self, from: data)
    }

    struct JobAlert: Codable, Identifiable {
        let id: String
        let name: String
        let keywords: String
        let canton: String?
        let employment_type: String?
        let workplace_type: String?
        let min_salary: Int?
        let enabled: Bool
        let last_notified_at: String?
        let created_at: String
        let updated_at: String
    }

    static func listJobAlerts() async throws -> [JobAlert] {
        let (data, response) = try await authorizedData(from: url("jobs/alerts"))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([JobAlert].self, from: data)
    }

    static func createJobAlert(name: String, keywords: String, canton: String?, employmentType: String?, workplaceType: String?) async throws -> JobAlert {
        var request = URLRequest(url: url("jobs/alerts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = ["name": name, "keywords": keywords, "enabled": true]
        if let canton, !canton.isEmpty { payload["canton"] = canton }
        if let employmentType, !employmentType.isEmpty { payload["employment_type"] = employmentType }
        if let workplaceType, !workplaceType.isEmpty { payload["workplace_type"] = workplaceType }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await authorizedData(for: request, context: "job_alert_create")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(JobAlert.self, from: data)
    }

    static func deleteJobAlert(id: String) async throws {
        var request = URLRequest(url: url("jobs/alerts/\(id)"))
        request.httpMethod = "DELETE"
        let (_, response) = try await authorizedData(for: request, context: "job_alert_delete")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    static func reportJob(id: String, reason: String, details: String? = nil) async throws {
        var request = URLRequest(url: url("jobs/\(id)/report"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = ["reason": reason]
        if let details { payload["details"] = details }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await authorizedData(for: request, context: "job_report")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    struct JobTranslation: Codable {
        let job_id: String
        let language: String
        let text: String
        let cached: Bool
    }

    static func translateJob(id: String, language: String) async throws -> JobTranslation {
        var request = URLRequest(url: url("jobs/\(id)/translation"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["language": language])
        let (data, response) = try await authorizedData(for: request, context: "job_translation")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw makeAPIError(
                data: data,
                response: response as? HTTPURLResponse,
                fallback: "Job translation unavailable"
            )
        }
        return try JSONDecoder().decode(JobTranslation.self, from: data)
    }

    struct JobEmployerProfile: Codable {
        let user_id: String
        let company_name: String
        let website: String?
        let canton: String
        let contact_name: String
        let contact_email: String
        let description: String?
        let is_verified: Bool
        let created_at: String
        let updated_at: String
    }

    struct JobEmployerProfilePayload: Encodable {
        let company_name: String
        let website: String?
        let canton: String
        let contact_name: String
        let contact_email: String
        let description: String?
    }

    struct EmployerJobPayload: Encodable {
        let title: String
        let description: String
        let location: String
        let canton: String
        let employment_type: String?
        let workplace_type: String?
        let workload_min: Int?
        let workload_max: Int?
        let salary_min: Int?
        let salary_max: Int?
        let salary_period: String?
        let languages: [String]
        let skills: [String]
        let permit_requirements: [String]
        let experience_level: String?
        let no_experience_required: Bool
        let degree_required: Bool
        let recognition_required: Bool
        let apply_url: String?
        let expires_at: String?
    }

    static func getJobEmployerProfile() async throws -> JobEmployerProfile {
        let (data, response) = try await authorizedData(from: url("jobs/employer/profile"))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw makeAPIError(data: data, response: response as? HTTPURLResponse, fallback: "Employer profile unavailable")
        }
        return try JSONDecoder().decode(JobEmployerProfile.self, from: data)
    }

    static func saveJobEmployerProfile(_ payload: JobEmployerProfilePayload) async throws -> JobEmployerProfile {
        var request = URLRequest(url: url("jobs/employer/profile"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await authorizedData(for: request, context: "job_employer_profile")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw makeAPIError(data: data, response: response as? HTTPURLResponse, fallback: "Could not save employer profile")
        }
        return try JSONDecoder().decode(JobEmployerProfile.self, from: data)
    }

    static func listEmployerJobs() async throws -> [JobItem] {
        let (data, response) = try await authorizedData(from: url("jobs/employer/jobs"))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw makeAPIError(data: data, response: response as? HTTPURLResponse, fallback: "Employer jobs unavailable")
        }
        return try JSONDecoder().decode([JobItem].self, from: data)
    }

    static func listEmployerJobApplications() async throws -> [EmployerJobApplication] {
        let (data, response) = try await authorizedData(from: url("jobs/employer/applications"))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw makeAPIError(data: data, response: response as? HTTPURLResponse, fallback: "Employer applications unavailable")
        }
        return try JSONDecoder().decode([EmployerJobApplication].self, from: data)
    }

    static func updateEmployerJobApplication(id: String, status: String) async throws -> EmployerJobApplication {
        var request = URLRequest(url: url("jobs/employer/applications/\(id)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["status": status])
        let (data, response) = try await authorizedData(for: request, context: "job_employer_application_update")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw makeAPIError(data: data, response: response as? HTTPURLResponse, fallback: "Could not update application")
        }
        return try JSONDecoder().decode(EmployerJobApplication.self, from: data)
    }

    static func createEmployerJob(_ payload: EmployerJobPayload) async throws -> JobItem {
        var request = URLRequest(url: url("jobs/employer/jobs"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await authorizedData(for: request, context: "job_employer_publish")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw makeAPIError(data: data, response: response as? HTTPURLResponse, fallback: "Could not submit vacancy")
        }
        return try JSONDecoder().decode(JobItem.self, from: data)
    }

    struct JobMatchResult: Decodable {
        let job: JobItem
        let score: Int
        let reasons: [String]
        let missing: [String]
        let method: String
    }
    struct JobMatchResponse: Decodable {
        let items: [JobMatchResult]
        let method: String
        let profile_quality: Int
    }

    static func matchJobs(
        desiredPosition: String,
        skills: [String],
        canton: String?,
        employmentType: String?,
        remote: Bool,
        experienceLevel: String?
    ) async throws -> JobMatchResponse {
        var request = URLRequest(url: url("jobs/match"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = [
            "desired_position": desiredPosition,
            "skills": skills,
            "remote": remote,
            "limit": 20
        ]
        if let canton { payload["canton"] = canton }
        if let employmentType { payload["employment_type"] = employmentType }
        if let experienceLevel { payload["experience_level"] = experienceLevel }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await authorizedData(for: request, context: "jobs_match")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(JobMatchResponse.self, from: data)
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

    static func resolveMediaURL(_ raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        if let absolute = URL(string: raw), absolute.scheme != nil {
            return absolute
        }
        let normalized = raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
        return baseURL.appendingPathComponent(normalized)
    }

    private struct MediaUploadResponse: Decodable {
        let url: String
        let filename: String
    }

    static func uploadMarketplaceImage(data: Data, filename: String, mimeType: String = "image/jpeg") async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url("media/upload"))
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        req.httpBody = body

        let (responseData, response) = try await authorizedData(for: req, context: "marketplace_image_upload")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw httpError(data: responseData, response: response)
        }

        return try JSONDecoder().decode(MediaUploadResponse.self, from: responseData).url
    }

    static func fetchListings(category: String? = nil,
                              canton: String? = nil,
                              listingType: ListingType? = nil,
                              page: Int = 1) async throws -> ServiceListingPage {
        var comps = URLComponents(url: url("marketplace"), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = [URLQueryItem(name: "page", value: String(page))]
        if let category { items.append(URLQueryItem(name: "category", value: category)) }
        if let listingType { items.append(URLQueryItem(name: "listing_type", value: listingType.rawValue)) }
        if let canton, canton != "all" { items.append(URLQueryItem(name: "canton", value: canton)) }
        comps?.queryItems = items
        guard let finalURL = comps?.url else { throw URLError(.badURL) }
        let (data, resp) = try await authorizedData(from: finalURL)
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

    private struct MarketplaceReportPayload: Encodable {
        let reason: String
        let details: String?
    }

    static func reportListing(id: String, reason: String, details: String? = nil) async throws {
        var req = URLRequest(url: url("marketplace/\(id)/report"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(MarketplaceReportPayload(reason: reason, details: details))
        let (data, resp) = try await authorizedData(for: req, context: "marketplace_report")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw httpError(data: data, response: resp)
        }
    }

    static func blockListingAuthor(listingID: String) async throws {
        var req = URLRequest(url: url("marketplace/\(listingID)/block"))
        req.httpMethod = "POST"
        let (data, resp) = try await authorizedData(for: req, context: "marketplace_block")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw httpError(data: data, response: resp)
        }
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
        guard AnalyticsConsentStore.isGranted, !events.isEmpty else { return }
        guard let token = KeychainStore.get("access_token"), !token.isEmpty else { return }
        let url = url("telemetry/batch")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("granted", forHTTPHeaderField: "X-Analytics-Consent")
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
        guard AnalyticsConsentStore.isGranted else { return }
        Task.detached {
            let payload = TelemetryEventPayload(id: UUID().uuidString, ts: isoNow(), level: level, source: source, type: type, message: message, meta: meta)
            try? await sendTelemetryBatch(events: [payload])
        }
    }

    // MARK: - Swiss Moments

    static func fetchMoments(
        canton: String? = nil,
        permit: String? = nil,
        tenureMonths: Int? = nil,
        hasChildren: Bool? = nil,
        lifeEvents: [String] = [],
        horizonDays: Int = 60
    ) async throws -> [SwissMoment] {
        var comps = URLComponents(url: url("moments"), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = [URLQueryItem(name: "horizon_days", value: String(horizonDays))]
        if let canton, !canton.isEmpty { items.append(URLQueryItem(name: "canton", value: canton)) }
        if let permit, !permit.isEmpty { items.append(URLQueryItem(name: "permit", value: permit)) }
        if let tenureMonths { items.append(URLQueryItem(name: "tenure_months", value: String(tenureMonths))) }
        if let hasChildren { items.append(URLQueryItem(name: "has_children", value: hasChildren ? "true" : "false")) }
        if !lifeEvents.isEmpty { items.append(URLQueryItem(name: "life_events", value: lifeEvents.joined(separator: ","))) }
        comps?.queryItems = items
        guard let finalURL = comps?.url else { throw URLError(.badURL) }
        let (data, resp) = try await timedData(from: finalURL, context: "moments_list")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([SwissMoment].self, from: data)
    }

    // MARK: - Experts

    static func fetchExperts(
        specialty: String? = nil,
        language: String? = nil,
        canton: String? = nil
    ) async throws -> [ServiceListing] {
        var comps = URLComponents(url: url("experts"), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = []
        if let specialty, !specialty.isEmpty { items.append(URLQueryItem(name: "specialty", value: specialty)) }
        if let language, !language.isEmpty { items.append(URLQueryItem(name: "language", value: language)) }
        if let canton, !canton.isEmpty, canton != "all" { items.append(URLQueryItem(name: "canton", value: canton)) }
        comps?.queryItems = items
        guard let finalURL = comps?.url else { throw URLError(.badURL) }
        let (data, resp) = try await timedData(from: finalURL, context: "experts_list")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([ServiceListing].self, from: data)
    }

    static func fetchExpertQuestions(listingId: String) async throws -> [ExpertQuestion] {
        let endpoint = url("experts/\(listingId)/questions")
        let (data, resp) = try await timedData(from: endpoint, context: "experts_questions")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([ExpertQuestion].self, from: data)
    }

    static func askExpert(
        listingId: String,
        questionText: String,
        askerName: String? = nil,
        askerLanguage: String? = nil
    ) async throws -> ExpertQuestion {
        var req = URLRequest(url: url("experts/questions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["listing_id": listingId, "question_text": questionText]
        if let askerName { body["asker_name"] = askerName }
        if let askerLanguage { body["asker_language"] = askerLanguage }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await authorizedData(for: req, context: "experts_ask")
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw httpError(data: data, response: resp)
        }
        return try JSONDecoder().decode(ExpertQuestion.self, from: data)
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
        let req = URLRequest(url: url)
        return try await timedData(for: req, context: context)
    }
}
