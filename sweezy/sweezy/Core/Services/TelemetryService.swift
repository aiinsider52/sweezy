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
    private let encoder = JSONEncoder()
    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    func info(_ type: String, source: String, message: String? = nil, meta: [String: String] = [:]) {
        log(level: "info", type: type, source: source, message: message, meta: meta)
    }

    func retention(_ event: RetentionEvent, source: String, message: String? = nil, meta: [String: String] = [:]) {
        info(event.rawValue, source: source, message: message, meta: meta)
    }
    
    func warn(_ type: String, source: String, message: String? = nil, meta: [String: String] = [:]) {
        log(level: "warn", type: type, source: source, message: message, meta: meta)
    }
    
    func error(_ type: String, source: String, message: String? = nil, meta: [String: String] = [:]) {
        log(level: "error", type: type, source: source, message: message, meta: meta)
    }
    
    private func log(level: String, type: String, source: String, message: String?, meta: [String: String]) {
        guard AnalyticsConsentStore.isGranted else { return }
        let event = Event(
            id: UUID().uuidString,
            ts: iso.string(from: Date()),
            level: level,
            source: source,
            type: type,
            message: message,
            meta: meta.isEmpty ? nil : meta
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
            scheduleFlush()
        } else {
            buffer.removeAll(keepingCapacity: false)
            isFlushScheduled = false
        }
    }
}


