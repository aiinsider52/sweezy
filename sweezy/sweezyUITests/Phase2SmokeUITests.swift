import XCTest

final class Phase2SmokeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNewUserJourneyAndRepeatLaunch() throws {
        let app = launchApp()

        advanceToProfileDetails(app)

        XCTAssertTrue(app.staticTexts["Расскажи о себе"].waitForExistence(timeout: 10))

        // Keep the preselected canton/date values and explicitly choose a permit option
        // so the profile step is actively exercised instead of only skipped through.
        let permitOption = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Residence Permit")).firstMatch
        if permitOption.waitForExistence(timeout: 5) {
            permitOption.tap()
        }

        tapNext(app)
        XCTAssertTrue(app.staticTexts["Твоя семья"].waitForExistence(timeout: 10))

        completeOnboardingFromFamilyStep(app)

        XCTAssertTrue(app.staticTexts["Першочергові задачі"].waitForExistence(timeout: 15))

        // Verify the explicit Settings sheet entry point from Home does not crash.
        let settingsButton = app.buttons["home.openSettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        app.swipeDown()

        // Quick action: CV Builder
        let cvBuilderButton = app.buttons["home.quickAction.cvBuilder"]
        XCTAssertTrue(cvBuilderButton.waitForExistence(timeout: 10))
        cvBuilderButton.tap()
        XCTAssertTrue(app.navigationBars["CV Builder"].waitForExistence(timeout: 10))
        app.buttons["Закрити"].tap()

        // Quick action: Templates
        let templatesButton = app.buttons["home.quickAction.templates"]
        XCTAssertTrue(templatesButton.waitForExistence(timeout: 10))
        templatesButton.tap()
        XCTAssertTrue(app.staticTexts["Шаблони документів"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Quick action: Guides -> must land on Guides content
        let guidesButton = app.buttons["home.quickAction.guides"]
        XCTAssertTrue(guidesButton.waitForExistence(timeout: 10))
        guidesButton.tap()
        XCTAssertTrue(app.scrollViews["dovidnyk.guides.content"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 0).tap()

        // "Show all tasks" -> must land on Checklists content
        let showAllTasksButton = app.buttons["home.showAllTasksButton"]
        XCTAssertTrue(showAllTasksButton.waitForExistence(timeout: 10))
        showAllTasksButton.tap()
        XCTAssertTrue(app.scrollViews["dovidnyk.checklists.content"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 0).tap()

        // Quick action: Map
        let mapButton = app.buttons["home.quickAction.map"]
        XCTAssertTrue(mapButton.waitForExistence(timeout: 10))
        mapButton.tap()
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 10))

        // Settings tab: no monetization review artifacts
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Unlocked")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "subscription")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "trial")).firstMatch.exists)

        // Repeat launch: onboarding must not appear again and personalized home stays.
        app.terminate()
        app.launch()

        XCTAssertFalse(app.buttons["onboarding.skipButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Першочергові задачі"].waitForExistence(timeout: 15))
    }

    @MainActor
    func testSkipProfileJourneyGracefullyLoadsHome() throws {
        let app = launchApp()

        advanceToProfileDetails(app)
        XCTAssertTrue(app.staticTexts["Расскажи о себе"].waitForExistence(timeout: 10))

        app.buttons["onboarding.profile.skipButton"].tap()
        XCTAssertTrue(app.staticTexts["Твоя семья"].waitForExistence(timeout: 10))

        app.buttons["onboarding.family.skipButton"].tap()
        completeOnboardingFromThemeStep(app)

        XCTAssertTrue(app.buttons["home.quickAction.cvBuilder"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Першочергові задачі"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    // MARK: - Helpers

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()
        dismissSystemAlertIfNeeded(timeout: 8)
        return app
    }

    @MainActor
    private func advanceToProfileDetails(_ app: XCUIApplication) {
        dismissSystemAlertIfNeeded(timeout: 3)
        XCTAssertTrue(app.buttons["onboarding.nextButton"].waitForExistence(timeout: 30))
        tapNext(app)
        tapNext(app)
        tapNext(app)
        dismissSystemAlertIfNeeded(timeout: 2)
    }

    @MainActor
    private func completeOnboardingFromFamilyStep(_ app: XCUIApplication) {
        tapNext(app) // Family -> Theme
        completeOnboardingFromThemeStep(app)
    }

    @MainActor
    private func completeOnboardingFromThemeStep(_ app: XCUIApplication) {
        tapNext(app) // Theme -> Success
        let getStarted = app.buttons["onboarding.getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 20))
        getStarted.tap()
    }

    @MainActor
    private func tapNext(_ app: XCUIApplication) {
        dismissSystemAlertIfNeeded(timeout: 1)
        let nextButton = app.buttons["onboarding.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 20))
        nextButton.tap()
        dismissSystemAlertIfNeeded(timeout: 2)
        Thread.sleep(forTimeInterval: 0.6)
    }

    @MainActor
    private func dismissSystemAlertIfNeeded(timeout: TimeInterval) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: timeout) {
            alert.buttons.element(boundBy: 0).tap()
        }
    }
}
