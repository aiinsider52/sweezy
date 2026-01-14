//
//  EventBus.swift
//  sweezy
//
//  Lightweight in-app event bus for gamification and analytics.
//

import Foundation
import Combine

enum GamEventType: String {
    case appDailyOpen = "app.daily.open"
    case guideReadCompleted = "guide.read.completed"
    case guideOpened = "guide.view.opened"
    case checklistStepCompleted = "checklist.step.completed"
    case checklistCompleted = "checklist.completed"
    case roadmapStageCompleted = "roadmap.stage.completed"
    case notificationEnabled = "system.notifications.enabled"
}

struct GamEvent {
    let type: GamEventType
    let idempotencyKey: String
    let timestamp: Date
    let metadata: [String: String]
    
    init(type: GamEventType, idempotencyKey: String? = nil, metadata: [String: String] = [:]) {
        self.type = type
        self.timestamp = Date()
        self.metadata = metadata
        if let key = idempotencyKey {
            self.idempotencyKey = key
        } else {
            // default key: type + entityId or date (for daily)
            if let entity = metadata["entityId"] {
                self.idempotencyKey = "\(type.rawValue):\(entity)"
            } else {
                self.idempotencyKey = "\(type.rawValue):\(ISO8601DateFormatter().string(from: Self.dayFloor(Date())))"
            }
        }
    }
    
    private static func dayFloor(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.startOfDay(for: date)
    }
}

@MainActor
final class EventBus: ObservableObject {
    static let shared = EventBus()
    
    private let subject = PassthroughSubject<GamEvent, Never>()
    
    var publisher: AnyPublisher<GamEvent, Never> {
        subject.eraseToAnyPublisher()
    }
    
    func emit(_ event: GamEvent) {
        subject.send(event)
    }
}


