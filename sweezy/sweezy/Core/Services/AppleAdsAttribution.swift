import AdServices
import Foundation

/// Where this install came from: Apple Search Ads campaign or organic. Asked once per install,
/// only with analytics consent, through Apple's AdServices token (no tracking permission needed).
/// The answer goes into the normal telemetry stream as `install_attributed`.
@MainActor
enum AppleAdsAttribution {
    private static let doneKey = "analytics.attribution.done"
    private static let attemptsKey = "analytics.attribution.attempts"
    private static var running = false

    static func resolveIfNeeded(telemetry: TelemetryService, defaults: UserDefaults = .standard) {
        guard AnalyticsConsentStore.isGranted, !defaults.bool(forKey: doneKey), !running else { return }
        // Apple keeps the token valid for 24 hours; a few tries over separate launches is plenty.
        let attempts = defaults.integer(forKey: attemptsKey)
        guard attempts < 4 else { return }
        defaults.set(attempts + 1, forKey: attemptsKey)
        running = true
        Task {
            defer { running = false }
            guard let result = await fetch() else { return }
            telemetry.track(.installAttributed, source: "attribution", meta: result)
            defaults.set(true, forKey: doneKey)
        }
    }

    /// Calls Apple's attribution API with the device token. Returns nil when Apple has no record yet.
    private static func fetch() async -> [String: String]? {
        guard let token = try? AAAttribution.attributionToken() else {
            // No token: simulator, restricted device, or AdServices unavailable. Count it as organic.
            return ["source": "organic", "reason": "no_token"]
        }
        var request = URLRequest(url: URL(string: "https://api-adservices.apple.com/api/v1/")!, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(token.utf8)

        for attempt in 0..<3 {
            if attempt > 0 { try? await Task.sleep(for: .seconds(5)) }
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let status = (response as? HTTPURLResponse)?.statusCode else { continue }
            // 404 means the record isn't ready yet; try again shortly.
            if status == 404 { continue }
            guard status == 200, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return parse(json)
        }
        return nil
    }

    static func parse(_ json: [String: Any]) -> [String: String] {
        guard json["attribution"] as? Bool == true else { return ["source": "organic"] }
        var result = ["source": "apple_search_ads"]
        for (key, name) in [
            ("campaignId", "campaign_id"), ("adGroupId", "ad_group_id"), ("keywordId", "keyword_id"),
            ("adId", "ad_id"), ("countryOrRegion", "country"), ("conversionType", "conversion_type"),
        ] {
            if let value = json[key] { result[name] = "\(value)" }
        }
        return result
    }
}
