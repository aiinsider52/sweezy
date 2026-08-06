import XCTest
@testable import sweezy

@MainActor
final class LifeAdminServiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "LifeAdminServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        if let suiteName {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFirstWeekTaskDeadlineIDRoundTrips() {
        let taskID = UUID()

        XCTAssertEqual(
            LifeAdminService.firstWeekTaskID(from: "task.\(taskID.uuidString)"),
            taskID
        )
        XCTAssertNil(LifeAdminService.firstWeekTaskID(from: "appointment.\(taskID.uuidString)"))
        XCTAssertNil(LifeAdminService.firstWeekTaskID(from: "task.not-a-uuid"))
    }

    func testCompletedOverdueFirstWeekTaskIsExcludedFromDeadlines() {
        let service = LifeAdminService(defaults: defaults)
        let task = FirstWeekChecklistService.TaskItem(
            title: "Overdue task",
            dueDate: Date().addingTimeInterval(-86_400),
            isDone: true
        )

        let deadlines = service.deadlines(profile: nil, firstWeekTasks: [task])

        XCTAssertFalse(deadlines.contains { $0.id == "task.\(task.id.uuidString)" })
    }

    func testIncompleteOverdueFirstWeekTaskRemainsActionable() {
        let service = LifeAdminService(defaults: defaults)
        let task = FirstWeekChecklistService.TaskItem(
            title: "Overdue task",
            dueDate: Date().addingTimeInterval(-86_400),
            isDone: false
        )

        let deadlines = service.deadlines(profile: nil, firstWeekTasks: [task])
        let deadline = deadlines.first { $0.id == "task.\(task.id.uuidString)" }

        XCTAssertEqual(deadline?.urgency, .overdue)
        XCTAssertEqual(deadline?.isCompleted, false)
    }
}
