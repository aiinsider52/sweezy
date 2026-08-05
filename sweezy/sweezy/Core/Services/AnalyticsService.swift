//
//  AnalyticsService.swift
//  sweezy
//
//  Compatibility facade for the first-party telemetry pipeline.
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
    private let telemetry: TelemetryService
    
    var isEnabled: Bool {
        AnalyticsConsentStore.isGranted
    }
    
    init(telemetry: TelemetryService) {
        self.telemetry = telemetry
    }
    
    func setEnabled(_ enabled: Bool) {
        AnalyticsConsentStore.setGranted(enabled)
        telemetry.consentDidChange()
    }
    
    func identify(userId: String?, properties: [String: Any]? = nil) {
        // Intentionally does not transmit account identifiers. The first-party
        // pipeline uses pseudonymous install/session IDs for guests and members.
    }
    
    func track(_ event: String, properties: [String: Any]? = nil) {
        telemetry.track(event, properties: properties)
    }
}

