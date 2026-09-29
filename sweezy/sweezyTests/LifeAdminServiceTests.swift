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

    func testSwissDocumentProgressSurvivesRelaunchWithLegacyIDs() {
        let first = LifeAdminService(defaults: defaults)
        first.prepareDocuments(for: nil)
        XCTAssertTrue(first.documents.contains { $0.id == "passport" })
        XCTAssertTrue(first.documents.contains { $0.id == "municipality" })
        first.toggleDocument("passport")

        let relaunched = LifeAdminService(defaults: defaults)
        relaunched.prepareDocuments(for: UserProfile(country: .switzerland))

        XCTAssertEqual(relaunched.documents.first { $0.id == "passport" }?.isReady, true)
    }

    func testSwitchingCountryAndBackKeepsSwissDocumentProgress() {
        let service = LifeAdminService(defaults: defaults)
        service.prepareDocuments(for: UserProfile(country: .switzerland))
        service.toggleDocument("passport")

        service.prepareDocuments(for: UserProfile(country: .germany))
        XCTAssertEqual(service.documents.first { $0.id == "de.passport" }?.isReady, false)

        service.prepareDocuments(for: UserProfile(country: .switzerland))
        XCTAssertEqual(service.documents.first { $0.id == "passport" }?.isReady, true)
    }

    func testSwissDeadlinesKeepLegacyIDsSoCompletionPersists() {
        let service = LifeAdminService(defaults: defaults)
        service.setDeadlineCompleted("insurance.health", completed: true)

        let ids = service.deadlines(profile: UserProfile(country: .switzerland), firstWeekTasks: []).map(\.id)

        XCTAssertTrue(ids.contains("registration.municipality"))
        XCTAssertFalse(ids.contains("insurance.health"))
        XCTAssertTrue(service.deadlines(profile: UserProfile(country: .germany), firstWeekTasks: []).map(\.id).contains("de.registration"))
    }
}
