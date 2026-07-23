import XCTest

/// Network-independent coverage for the routes every user must be able to reach.
final class CriticalFlowsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGuestCanReachEveryPrimaryTabAndStatePersists() throws {
        let app = launchCleanApp()
        finishOnboardingAsGuest(app)

        assertScreen(app, tab: "tab.home", screen: "home.screen")
        assertScreen(app, tab: "tab.directory", screen: "directory.screen")
        assertScreen(app, tab: "tab.map", screen: "map.screen")
        assertScreen(app, tab: "tab.marketplace", screen: "marketplace.screen")
        assertScreen(app, tab: "tab.settings", screen: "settings.screen")

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertFalse(app.buttons["onboarding.skipButton"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["auth.entry.continueAsGuest"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testRegistrationRejectsIncompleteCredentialsWithoutNetworkRequest() throws {
        let app = launchCleanApp()
        let skip = app.buttons["onboarding.skipButton"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        skip.tap()

        let createAccount = app.buttons["auth.entry.createAccount"]
        XCTAssertTrue(createAccount.waitForExistence(timeout: 10))
        createAccount.tap()

        XCTAssertTrue(app.textFields["auth.registration.name"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["auth.registration.email"].exists)
        XCTAssertTrue(app.secureTextFields["auth.registration.password"].exists)
        XCTAssertTrue(app.buttons["auth.registration.submit"].exists)
        XCTAssertFalse(app.buttons["auth.registration.submit"].isEnabled)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "registration-redesign"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testEmailVerificationRedesignStartsInSafeState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-email-verification"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()

        XCTAssertTrue(app.textFields["auth.verify.code"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["auth.verify.submit"].exists)
        XCTAssertFalse(app.buttons["auth.verify.submit"].isEnabled)
        XCTAssertTrue(app.buttons["auth.verify.resend"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "email-verification-redesign"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func launchCleanApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-ui-test-state"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()
        return app
    }

    @MainActor
    private func finishOnboardingAsGuest(_ app: XCUIApplication) {
        let skip = app.buttons["onboarding.skipButton"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        skip.tap()

        let guest = app.buttons["auth.entry.continueAsGuest"]
        XCTAssertTrue(guest.waitForExistence(timeout: 10))
        guest.tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 15))
    }

    @MainActor
    private func assertScreen(_ app: XCUIApplication, tab: String, screen: String) {
        let tabButton = app.buttons[tab]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 10), "Missing tab: \(tab)")
        tabButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)[screen].waitForExistence(timeout: 10), "Missing screen: \(screen)")
    }
}
