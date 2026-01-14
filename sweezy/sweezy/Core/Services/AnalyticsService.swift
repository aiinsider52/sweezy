//
//  AnalyticsService.swift
//  sweezy
//
//  Lightweight analytics abstraction with optional Amplitude HTTP API.
//

import Foundation

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
    private let keyEnabled = "analytics.enabled"
    private let session = URLSession(configuration: .ephemeral)
    private let apiKey: String?
    
    var isEnabled: Bool {
        defaults.bool(forKey: keyEnabled)
    }
    
    init(apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "AMPLITUDE_API_KEY") as? String) {
        self.apiKey = apiKey
    }
    
    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: keyEnabled)
    }
    
    func identify(userId: String?, properties: [String: Any]? = nil) {
        guard isEnabled else { return }
        // Amplitude Identify via HTTP API v2
        let payload: [String: Any] = [
            "api_key": apiKey ?? "",
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
        guard isEnabled else { return }
        let payload: [String: Any] = [
            "api_key": apiKey ?? "",
            "events": [
                [
                    "event_type": event,
                    "user_id": defaults.string(forKey: "user.id") ?? "anon",
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
}


