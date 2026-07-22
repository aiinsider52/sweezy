import XCTest

/// Focused smoke coverage for settings that affect privacy and retention.
final class Phase2SmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNotificationSettingsAreReachableAndExposeMasterControl() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-ui-test-state"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()

        XCTAssertTrue(app.buttons["onboarding.skipButton"].waitForExistence(timeout: 15))
        app.buttons["onboarding.skipButton"].tap()
        XCTAssertTrue(app.buttons["auth.entry.continueAsGuest"].waitForExistence(timeout: 10))
        app.buttons["auth.entry.continueAsGuest"].tap()

        XCTAssertTrue(app.buttons["tab.settings"].waitForExistence(timeout: 15))
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.buttons["settings.notifications.open"].waitForExistence(timeout: 10))
        app.buttons["settings.notifications.open"].tap()
        XCTAssertTrue(app.switches["settings.notifications.masterToggle"].waitForExistence(timeout: 10))
    }
}
