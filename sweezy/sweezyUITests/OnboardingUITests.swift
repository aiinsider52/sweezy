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
        tapNext() // notification permission

        XCTAssertTrue(app.descendants(matching: .any)["onboarding.notificationPermissionPage"].waitForExistence(timeout: 10))
        let later = app.buttons["onboarding.notifications.laterButton"]
        XCTAssertTrue(later.isHittable)
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
    private func tapNext() {
        let next = app.buttons["onboarding.nextButton"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
    }
}
