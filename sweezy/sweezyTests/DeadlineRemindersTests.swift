import XCTest
@testable import sweezy

@MainActor
final class DeadlineRemindersTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "DeadlineRemindersTests.\(UUID().uuidString)"
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

    private func future(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date())!
    }

    func testPermitDateIsStoredOnTheReadinessDocument() {
        let service = LifeAdminService(defaults: defaults)
        service.prepareDocuments(for: UserProfile(country: .switzerland, permitType: .s))

        service.saveDeadline(kind: .permit, title: nil, date: future(days: 60))

        let permit = service.documents.first { $0.id == "permit" }
        XCTAssertNotNil(permit?.expiryDate)
        XCTAssertEqual(permit?.isReady, true)
        XCTAssertTrue(service.personalDeadlines.isEmpty)
        let item = service.expiryItems.first
        XCTAssertEqual(item?.kind, .permit)
        XCTAssertEqual(item?.title, "deadline.permit_title".localized(with: "S"))
    }

    func testPersonalDeadlinesPersistAndShowUpInThePlan() {
        let service = LifeAdminService(defaults: defaults)
        service.prepareDocuments(for: UserProfile(country: .germany))
        service.saveDeadline(kind: .tax, title: "Steuer 2026", date: future(days: 20))

        let reloaded = LifeAdminService(defaults: defaults)
        XCTAssertEqual(reloaded.personalDeadlines.map(\.title), ["Steuer 2026"])
        let deadlines = reloaded.deadlines(profile: UserProfile(country: .germany), firstWeekTasks: [])
        XCTAssertTrue(deadlines.contains { $0.title == "Steuer 2026" && $0.category == .tax })

        let item = reloaded.expiryItems.first { $0.title == "Steuer 2026" }!
        reloaded.removeDeadline(item)
        XCTAssertTrue(reloaded.personalDeadlines.isEmpty)
    }

    func testReminderWordingSaysExpiresOnlyForDocuments() {
        let permit = ExpiryItem(origin: .document("permit"), kind: .permit, title: "Permit S", date: future(days: 30))
        let tax = ExpiryItem(origin: .personal(UUID()), kind: .tax, title: "Tax", date: future(days: 30))

        XCTAssertEqual(LifeAdminService.reminderTitle(for: permit, lead: 7), "deadline.push.expires_in".localized(with: "7", "Permit S"))
        XCTAssertEqual(LifeAdminService.reminderTitle(for: permit, lead: 1), "deadline.push.expires_tomorrow".localized(with: "Permit S"))
        XCTAssertEqual(LifeAdminService.reminderTitle(for: tax, lead: 30), "deadline.push.due_in".localized(with: "30", "Tax"))
    }

    func testPushTapsOpenTheScreenTheyTalkAbout() {
        XCTAssertEqual(SweezyAppDelegate.deepLink(for: ["type": "friend_match", "conversation_id": "c1"]), .chat(id: "c1"))
        XCTAssertEqual(SweezyAppDelegate.deepLink(for: ["type": "likes_digest"]), .people)
        XCTAssertEqual(SweezyAppDelegate.deepLink(for: ["type": "price_drop", "listing_id": "l1"]), .listing(id: "l1"))
        XCTAssertEqual(SweezyAppDelegate.deepLink(for: ["type": "deadline_reminder"]), .deadlines)
        XCTAssertNil(SweezyAppDelegate.deepLink(for: ["type": "unknown"]))
    }
}
