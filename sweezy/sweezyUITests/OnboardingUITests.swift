import XCTest

final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-ui-test-state"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()
    }

    @MainActor
    func testCompleteOnboardingWithoutRequestingNotificationPermission() throws {
        XCTAssertTrue(app.staticTexts["onboarding.page.title.1"].waitForExistence(timeout: 15))
        tapNext()

        let ukrainian = app.buttons["onboarding.language.option.uk"]
        XCTAssertTrue(ukrainian.waitForExistence(timeout: 10))
        ukrainian.tap()
        tapNext()

        XCTAssertTrue(app.staticTexts["onboarding.page.title.2"].waitForExistence(timeout: 10))
        tapNext()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.profileDetailsPage"].waitForExistence(timeout: 10))
        tapNext()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.familyDetailsPage"].waitForExistence(timeout: 10))
        tapNext() // theme
        tapNext() // analytics consent
        let declineAnalytics = app.buttons["onboarding.analytics.declineButton"]
        XCTAssertTrue(declineAnalytics.waitForExistence(timeout: 10))
        declineAnalytics.tap()

        XCTAssertTrue(app.descendants(matching: .any)["onboarding.notificationPermissionPage"].waitForExistence(timeout: 10))
        let later = app.buttons["onboarding.notifications.laterButton"]
        let hittable = NSPredicate(format: "exists == true AND hittable == true")
        expectation(for: hittable, evaluatedWith: later)
        waitForExpectations(timeout: 5)
        later.tap()

        let getStarted = app.buttons["onboarding.getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10))
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
}
