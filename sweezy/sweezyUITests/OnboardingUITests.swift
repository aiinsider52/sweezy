import XCTest

final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        // The simulator can be left in landscape between runs; every layout assertion assumes portrait.
        XCUIDevice.shared.orientation = .portrait
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-ui-test-state"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()
    }

    @MainActor
    func testCompleteOnboardingWithoutRequestingNotificationPermission() throws {
        XCTAssertTrue(app.staticTexts["onboarding.page.title.1"].waitForExistence(timeout: 15))
        keepStep("onboarding-1-welcome")
        tapNext()

        let ukrainian = app.buttons["onboarding.language.option.uk"]
        XCTAssertTrue(ukrainian.waitForExistence(timeout: 10))
        ukrainian.tap()
        keepStep("onboarding-2-language")
        tapNext()

        XCTAssertTrue(app.staticTexts["onboarding.page.title.2"].waitForExistence(timeout: 10))
        keepStep("onboarding-3-plan")
        tapNext()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.profileDetailsPage"].waitForExistence(timeout: 10))
        keepStep("onboarding-4-profile")
        tapNext()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.familyDetailsPage"].waitForExistence(timeout: 10))
        keepStep("onboarding-5-family")
        tapNext() // theme
        keepStep("onboarding-6-theme")
        tapNext() // analytics consent
        let declineAnalytics = app.buttons["onboarding.analytics.declineButton"]
        XCTAssertTrue(declineAnalytics.waitForExistence(timeout: 10))
        keepStep("onboarding-7-analytics")
        declineAnalytics.tap()

        XCTAssertTrue(app.descendants(matching: .any)["onboarding.notificationPermissionPage"].waitForExistence(timeout: 10))
        keepStep("onboarding-8-notifications")
        let later = app.buttons["onboarding.notifications.laterButton"]
        let hittable = NSPredicate(format: "exists == true AND hittable == true")
        expectation(for: hittable, evaluatedWith: later)
        waitForExpectations(timeout: 5)
        later.tap()

        let getStarted = app.buttons["onboarding.getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 2.2)
        keepStep("onboarding-9-ready")
        getStarted.tap()
        XCTAssertTrue(app.buttons["auth.entry.continueAsGuest"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSkipOnboardingStillRequiresExplicitAuthChoice() throws {
        let skip = app.buttons["onboarding.skipButton"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        XCTAssertTrue(skip.isHittable)
        skip.tap()
        XCTAssertTrue(app.buttons["auth.entry.continueAsGuest"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testProfilePageScrollAndPagingControlsRemainInteractive() throws {
        XCTAssertTrue(app.staticTexts["onboarding.page.title.1"].waitForExistence(timeout: 15))
        tapNext()
        tapNext()
        tapNext()

        let profilePage = app.scrollViews["onboarding.profileDetailsPage"]
        XCTAssertTrue(profilePage.waitForExistence(timeout: 10))
        profilePage.swipeUp()
        profilePage.swipeDown()

        let back = app.buttons["onboarding.backButton"]
        let next = app.buttons["onboarding.nextButton"]
        XCTAssertTrue(back.isHittable)
        XCTAssertTrue(next.isHittable)
        back.tap()
        XCTAssertTrue(app.staticTexts["onboarding.page.title.2"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func tapNext() {
        let next = app.buttons["onboarding.nextButton"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
    }

    /// Captures a step after its entrance animation settles (attachments are kept for design review).
    @MainActor
    private func keepStep(_ name: String) {
        Thread.sleep(forTimeInterval: 1.2)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
