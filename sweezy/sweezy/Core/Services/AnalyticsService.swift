//
//  AnalyticsService.swift
//  sweezy
//
//  Lightweight analytics abstraction with optional Amplitude HTTP API.
//

import Foundation

enum AnalyticsConsentStore {
    private static let decisionKey = "privacy.analytics.consent.decided"
    private static let grantedKey = "privacy.analytics.consent.granted"

    static var hasDecision: Bool {
        UserDefaults.standard.bool(forKey: decisionKey)
    }

    static var isGranted: Bool {
        hasDecision && UserDefaults.standard.bool(forKey: grantedKey)
    }

    static func setGranted(_ granted: Bool) {
        UserDefaults.standard.set(true, forKey: decisionKey)
        UserDefaults.standard.set(granted, forKey: grantedKey)
    }
}

@MainActor
protocol AnalyticsServiceProtocol {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool)
    func identify(userId: String?, properties: [String: Any]?)
    func track(_ event: String, properties: [String: Any]?)
}

@MainActor
final class AnalyticsService: AnalyticsServiceProtocol {
    private let defaults = UserDefaults.standard
    private let session = URLSession(configuration: .ephemeral)
    private let apiKey: String?
    
    var isEnabled: Bool {
        AnalyticsConsentStore.isGranted
    }
    
    init(apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "AMPLITUDE_API_KEY") as? String) {
        self.apiKey = Self.normalizedBuildSettingValue(apiKey)
    }
    
    func setEnabled(_ enabled: Bool) {
        AnalyticsConsentStore.setGranted(enabled)
    }
    
    func identify(userId: String?, properties: [String: Any]? = nil) {
        guard isEnabled, let apiKey, !apiKey.isEmpty else { return }
        // Amplitude Identify via HTTP API v2
        let payload: [String: Any] = [
            "api_key": apiKey,
            "identification": [
                [
                    "user_id": userId ?? "anon",
                    "user_properties": properties ?? [:]
                ]
            ]
        ]
        postJSON("https://api2.amplitude.com/identify", payload)
    }
    
    func track(_ event: String, properties: [String: Any]? = nil) {
        guard isEnabled, let apiKey, !apiKey.isEmpty else { return }
        let payload: [String: Any] = [
            "api_key": apiKey,
            "events": [
                [
                    "event_type": event,
                    "user_id": KeychainStore.get("user_id") ?? "anon",
                    "event_properties": properties ?? [:],
                    "time": Int(Date().timeIntervalSince1970 * 1000)
                ]
            ]
        ]
        postJSON("https://api2.amplitude.com/2/httpapi", payload)
    }
    
    private func postJSON(_ url: String, _ body: [String: Any]) {
        guard let u = URL(string: url) else { return }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        // Fire-and-forget
        let task = session.dataTask(with: req)
        task.resume()
    }

    private static func normalizedBuildSettingValue(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // When Info.plist uses $(AMPLITUDE_API_KEY) and the build setting is not defined,
        // Xcode may leave the placeholder in place. Treat that as "not configured".
        if trimmed.hasPrefix("$(") && trimmed.hasSuffix(")") { return nil }
        return trimmed
    }
}

