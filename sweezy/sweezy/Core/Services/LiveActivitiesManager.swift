//
//  LiveActivitiesManager.swift
//  sweezy
//
//  Starts/updates Live Activities for nearest task and permit deadline.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class LiveActivitiesManager {
    static let shared = LiveActivitiesManager()
    private init() {}
    
    struct NextTaskInfo {
        let title: String
        let dueDate: Date
    }
    
    func updateNextTask(_ info: NextTaskInfo?) {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            Task { await updateNextTaskActivity(info) }
        }
        #endif
    }
    
    func updatePermitDeadline(_ date: Date?) {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            Task { await updatePermitActivity(date) }
        }
        #endif
    }
}

#if canImport(ActivityKit)
@available(iOS 16.1, *)
extension LiveActivitiesManager {
    // Define attributes
    struct SweezyAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            var title: String
            var due: Date
        }
        var kind: String
    }
    
    private func updateNextTaskActivity(_ info: NextTaskInfo?) async {
        let existing = Activity<SweezyAttributes>.activities.filter { $0.attributes.kind == "next_task" }
        if let info {
            let state = SweezyAttributes.ContentState(title: info.title, due: info.dueDate)
            let content = ActivityContent<SweezyAttributes.ContentState>(
                state: state,
                staleDate: nil
            )
            if let activity = existing.first {
                await activity.update(content)
            } else {
                _ = try? Activity<SweezyAttributes>.request(
                    attributes: .init(kind: "next_task"),
                    content: content,
                    pushType: nil
                )
            }
        } else {
            for a in existing { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }
    
    private func updatePermitActivity(_ date: Date?) async {
        let existing = Activity<SweezyAttributes>.activities.filter { $0.attributes.kind == "permit_deadline" }
        if let date {
            let state = SweezyAttributes.ContentState(title: "Дедлайн дозволу", due: date)
            let content = ActivityContent<SweezyAttributes.ContentState>(
                state: state,
                staleDate: nil
            )
            if let activity = existing.first {
                await activity.update(content)
            } else {
                _ = try? Activity<SweezyAttributes>.request(
                    attributes: .init(kind: "permit_deadline"),
                    content: content,
                    pushType: nil
                )
            }
        } else {
            for a in existing { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
#endif


