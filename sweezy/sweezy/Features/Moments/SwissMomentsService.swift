//
//  SwissMomentsService.swift
//  sweezy
//
//  Loads Swiss "moments" from the backend and orchestrates local reminders.
//

import Foundation
import SwiftUI

@MainActor
final class SwissMomentsService: ObservableObject {
    @Published private(set) var moments: [SwissMoment] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?

    private let scheduledKey = "moments.scheduled.v1"
    private let defaults = UserDefaults.standard

    func refresh(profile: UserProfile?, telemetry: TelemetryService? = nil) async {
        isLoading = true
        defer { isLoading = false }

        let canton = profile?.canton.rawValue
        let permit = profile?.permitType.rawValue
        let tenure = profile?.tenureMonths
        let hasChildren = profile?.hasChildren
        let events = profile?.lifeEvents.map { $0.rawValue } ?? []

        do {
            let result = try await APIClient.fetchMoments(
                canton: canton,
                permit: permit,
                tenureMonths: tenure,
                hasChildren: hasChildren,
                lifeEvents: events
            )
            self.moments = result.sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.endsAt < rhs.endsAt
            }
            self.lastError = nil
            telemetry?.retention(.momentSeen, source: "moments_service", message: nil, meta: [
                "count": String(result.count)
            ])
        } catch {
            self.lastError = "\(error)"
        }
    }

    /// Schedules T-14 / T-3 reminders for the active moments, idempotent across calls.
    func scheduleReminders(using notifications: any NotificationServiceProtocol, telemetry: TelemetryService?) async {
        let already = Set(defaults.stringArray(forKey: scheduledKey) ?? [])
        var newlyScheduled: [String] = []

        let calendar = Calendar.current
        for moment in moments {
            for (offsetDays, suffix) in [(-14, "t14"), (-3, "t3")] {
                guard let triggerDate = calendar.date(byAdding: .day, value: offsetDays, to: moment.endsAt),
                      triggerDate > Date() else { continue }
                let id = "moment.\(moment.key).\(suffix)"
                if already.contains(id) { continue }
                let title = moment.title
                let body = String(format: NSLocalizedString("moments.deadline.in_days", comment: ""), abs(offsetDays))
                let ok = await notifications.scheduleReminder(id: id, title: title, body: body, at: triggerDate)
                if ok {
                    newlyScheduled.append(id)
                    EventBus.shared.emit(GamEvent(
                        type: .deadlineTracked,
                        metadata: [
                            "entityId": id,
                            "title": moment.title,
                            "momentKey": moment.key
                        ]
                    ))
                    telemetry?.retention(.deadlineReminderScheduled, source: "moments_service", message: nil, meta: [
                        "key": moment.key,
                        "offset_days": String(offsetDays)
                    ])
                }
            }
        }

        if !newlyScheduled.isEmpty {
            let combined = Array(already.union(newlyScheduled))
            defaults.set(combined, forKey: scheduledKey)
        }
    }
}
