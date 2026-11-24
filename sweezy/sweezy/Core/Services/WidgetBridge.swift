import Foundation
import WidgetKit

/// What the home-screen widget shows. Keep in sync with `WidgetSnapshot` in the SweezyWidget target:
/// both sides encode the same JSON through the shared App Group.
struct WidgetSnapshot: Codable, Equatable {
    struct Deadline: Codable, Equatable {
        var title: String
        var date: Date
    }

    var nextStepLabel: String
    var nextStepTitle: String
    var progressDone: Int
    var progressTotal: Int
    var deadlineLabel: String
    var deadline: Deadline?
    var daysUnit: String
    var todayWord: String
    var emptyDeadline: String

    static let appGroup = "group.com.sweezy.mobile"
    static let key = "widget.snapshot"
}

/// Writes the widget snapshot from the app's own state and asks WidgetKit to redraw when it changed.
/// Strings are localised here, in the app language, so the widget needs no translations.
@MainActor
enum WidgetBridge {
    static func update(from container: AppContainer) {
        let tasks = container.firstWeekService.tasks
        let done = tasks.filter(\.isDone).count
        let nextTitle = container.firstWeekService.nextDueTask?.displayTitle ?? "journey.home.default_next_step".localized

        // The nearest personal or official date that is not one of the plan steps (those are already
        // the "next step"), and not already past.
        let deadline = container.lifeAdmin.deadlines(
            profile: container.userProfile,
            firstWeekTasks: tasks,
            appointments: container.appointmentRepository.appointments
        )
        .filter { !$0.isCompleted && $0.daysRemaining >= 0 && LifeAdminService.firstWeekTaskID(from: $0.id) == nil }
        .min { $0.dueDate < $1.dueDate }

        let snapshot = WidgetSnapshot(
            nextStepLabel: "widget.next_step".localized,
            nextStepTitle: nextTitle,
            progressDone: done,
            progressTotal: max(tasks.count, 1),
            deadlineLabel: "widget.nearest_deadline".localized,
            deadline: deadline.map { WidgetSnapshot.Deadline(title: $0.title, date: $0.dueDate) },
            daysUnit: "widget.days_short".localized,
            todayWord: "widget.today".localized,
            emptyDeadline: "widget.no_deadlines".localized
        )

        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        if defaults.data(forKey: WidgetSnapshot.key) == data { return }
        defaults.set(data, forKey: WidgetSnapshot.key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Signing out or deleting data must not leave the previous person's plan on the home screen.
    static func clear() {
        UserDefaults(suiteName: WidgetSnapshot.appGroup)?.removeObject(forKey: WidgetSnapshot.key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
