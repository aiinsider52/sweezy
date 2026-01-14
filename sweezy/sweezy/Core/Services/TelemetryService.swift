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
    
    func warn(_ type: String, source: String, message: String? = nil, meta: [String: String] = [:]) {
        log(level: "warn", type: type, source: source, message: message, meta: meta)
    }
    
    func error(_ type: String, source: String, message: String? = nil, meta: [String: String] = [:]) {
        log(level: "error", type: type, source: source, message: message, meta: meta)
    }
    
    private func log(level: String, type: String, source: String, message: String?, meta: [String: String]) {
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
}



