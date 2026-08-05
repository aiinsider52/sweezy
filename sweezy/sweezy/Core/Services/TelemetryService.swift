//
//  TelemetryService.swift
//  sweezy
//
//  Lightweight client‑side telemetry: buffered events with periodic flush.
//

import Foundation
import SwiftUI

@MainActor
final class TelemetryService {
    enum ProductEvent: String {
        case sessionStarted = "session_started"
        case sessionHeartbeat = "session_heartbeat"
        case sessionBackgrounded = "session_backgrounded"
        case onboardingStepCompleted = "onboarding_step_completed"
        case onboardingCompleted = "onboarding_completed"
        case analyticsConsentUpdated = "analytics_consent_updated"
        case dailyOpen = "daily_open"
        case guideRead = "guide_read"
        case checklistStepCompleted = "checklist_step_completed"
        case checklistCompleted = "checklist_completed"
    }

    enum RetentionEvent: String {
        case onboardingProfileSaved = "retention_onboarding_profile_saved"
        case roadmapSeeded = "retention_roadmap_seeded"
        case nextActionViewed = "retention_next_action_viewed"
        case nextActionTapped = "retention_next_action_tapped"
        case roadmapTaskCompleted = "retention_roadmap_task_completed"
        case contentOpened = "retention_content_opened"
        case firstWeekReminderScheduled = "retention_first_week_reminder_scheduled"
        case marketplaceListingViewed = "retention_marketplace_listing_viewed"
        case marketplaceContactTapped = "retention_marketplace_contact_tapped"
        case jobSearchPerformed = "retention_job_search_performed"
        case notificationPermissionUpdated = "retention_notification_permission_updated"
        case lifeEventLogged = "retention_life_event_logged"
        case settledBranchActivated = "retention_settled_branch_activated"
        case momentSeen = "retention_moment_seen"
        case momentActionTaken = "retention_moment_action_taken"
        case deadlineReminderScheduled = "retention_deadline_reminder_scheduled"
        case expertViewed = "retention_expert_viewed"
        case expertQuestionAsked = "retention_expert_question_asked"
    }

    struct Event: Codable {
        let id: String
        let ts: String
        let level: String
        let source: String
        let type: String
        let message: String?
        let meta: [String: String]?
    }
    
    private var buffer: [Event] = []
    private var isFlushScheduled = false
    private var heartbeatTimer: Timer?
    private var sessionID: String?
    private var sessionStartedAt: Date?
    private let installID: String
    private let encoder = JSONEncoder()
    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init(defaults: UserDefaults = .standard) {
        let key = "privacy.analytics.install_id"
        if let existing = defaults.string(forKey: key), UUID(uuidString: existing) != nil {
            installID = existing
        } else {
            let generated = UUID().uuidString
            defaults.set(generated, forKey: key)
            installID = generated
        }
    }
    
    func info(_ type: String, source: String, message: String? = nil, meta: [String: String] = [:]) {
        log(level: "info", type: type, source: source, message: message, meta: meta)
    }

    func retention(_ event: RetentionEvent, source: String, message: String? = nil, meta: [String: String] = [:]) {
        info(event.rawValue, source: source, message: message, meta: meta)
    }

    func track(_ event: ProductEvent, source: String, meta: [String: String] = [:]) {
        info(event.rawValue, source: source, meta: meta)
    }

    func track(_ event: String, source: String = "app", properties: [String: Any]? = nil) {
        let meta = properties?.reduce(into: [String: String]()) { result, item in
            guard let value = Self.safeString(item.value) else { return }
            result[item.key] = value
        } ?? [:]
        info(Self.normalizedName(event), source: source, meta: meta)
    }

    func appDidBecomeActive() {
        guard AnalyticsConsentStore.isGranted else { return }
        if sessionID == nil {
            sessionID = UUID().uuidString
            sessionStartedAt = Date()
            track(.sessionStarted, source: "lifecycle")
        }
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let started = self.sessionStartedAt else { return }
                self.track(
                    .sessionHeartbeat,
                    source: "lifecycle",
                    meta: ["elapsed_seconds": String(Int(Date().timeIntervalSince(started)))]
                )
            }
        }
    }

    func appDidEnterBackground() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        if let started = sessionStartedAt {
            track(
                .sessionBackgrounded,
                source: "lifecycle",
                meta: ["duration_seconds": String(Int(Date().timeIntervalSince(started)))]
            )
        }
        Task { await flush() }
        sessionID = nil
        sessionStartedAt = nil
    }
    
    func warn(_ type: String, source: String, message: String? = nil, meta: [String: String] = [:]) {
        log(level: "warn", type: type, source: source, message: message, meta: meta)
    }
    
    func error(_ type: String, source: String, message: String? = nil, meta: [String: String] = [:]) {
        log(level: "error", type: type, source: source, message: message, meta: meta)
    }
    
    private func log(level: String, type: String, source: String, message: String?, meta: [String: String]) {
        guard AnalyticsConsentStore.isGranted else { return }
        var safeMeta = Self.sanitizedMetadata(meta)
        safeMeta["install_id"] = installID
        if let sessionID {
            safeMeta["session_id"] = sessionID
        }
        let event = Event(
            id: UUID().uuidString,
            ts: iso.string(from: Date()),
            level: level,
            source: source,
            type: Self.normalizedName(type),
            message: message.map { String($0.prefix(256)) },
            meta: safeMeta.isEmpty ? nil : safeMeta
        )
        buffer.append(event)
        // Cap buffer to avoid memory growth
        if buffer.count > 200 {
            buffer.removeFirst(buffer.count - 200)
        }
        scheduleFlush()
    }
    
    private func scheduleFlush() {
        guard !isFlushScheduled else { return }
        isFlushScheduled = true
        // Flush after a short delay to batch events
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            Task { @MainActor in
                await self?.flush()
            }
        }
    }
    
    func flush() async {
        isFlushScheduled = false
        guard AnalyticsConsentStore.isGranted else {
            buffer.removeAll(keepingCapacity: false)
            return
        }
        guard !buffer.isEmpty else { return }
        let events = buffer
        buffer.removeAll(keepingCapacity: true)
        do {
            try await APIClient.sendTelemetryBatch(events: events.map {
                APIClient.TelemetryEventPayload(
                    id: $0.id, ts: $0.ts, level: $0.level, source: $0.source, type: $0.type, message: $0.message, meta: $0.meta
                )
            })
        } catch {
            // On failure, return events to buffer (but keep cap)
            buffer.insert(contentsOf: events, at: 0)
            if buffer.count > 200 {
                buffer = Array(buffer.suffix(200))
            }
        }
    }

    func consentDidChange() {
        if AnalyticsConsentStore.isGranted {
            appDidBecomeActive()
            scheduleFlush()
        } else {
            heartbeatTimer?.invalidate()
            heartbeatTimer = nil
            sessionID = nil
            sessionStartedAt = nil
            buffer.removeAll(keepingCapacity: false)
            isFlushScheduled = false
        }
    }

    static func normalizedName(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
            .prefix(80)
            .description
    }

    static func sanitizedMetadata(_ meta: [String: String]) -> [String: String] {
        let blocked = ["email", "name", "phone", "address", "token", "password", "message"]
        return meta.reduce(into: [:]) { result, item in
            let key = normalizedName(item.key)
            guard !blocked.contains(where: { key.contains($0) }) else { return }
            result[key] = String(item.value.prefix(256))
        }
    }

    private static func safeString(_ value: Any) -> String? {
        switch value {
        case let value as String: return String(value.prefix(256))
        case let value as Bool: return String(value)
        case let value as Int: return String(value)
        case let value as Double where value.isFinite: return String(value)
        case let value as Float where value.isFinite: return String(value)
        default: return nil
        }
    }
}


