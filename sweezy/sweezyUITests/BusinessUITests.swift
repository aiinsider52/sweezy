import XCTest

final class BusinessUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBusinessOnboardingRequiresStoryBeforeContinuing() throws {
        let app = launch(["--ui-test-business-onboarding"])

        let start = app.buttons["business.onboarding.start"]
        XCTAssertTrue(scrollToElement(start, in: app))
        keepScreenshot(app, name: "business-onboarding-intro")
        start.tap()

        let next = app.buttons["business.onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertTrue(next.isEnabled, "Kind and category have defaults")
        let business = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Бізнес,'")).firstMatch
        let specialist = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Спеціаліст'")).firstMatch
        XCTAssertTrue(business.isSelected, "Business is the default kind")
        specialist.tap()
        XCTAssertTrue(specialist.isSelected)
        XCTAssertFalse(business.isSelected)
        keepScreenshot(app, name: "business-onboarding-identity")
        next.tap()

        XCTAssertFalse(next.isEnabled, "Name and description are required")
        let name = app.textFields["Назва"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Олена Шевчук")
        let story = app.textFields["Що ти робиш, для кого і чому тобі можна довіряти"]
        story.tap()
        story.typeText("Присяжні переклади документів для Gemeinde і SEM.")
        keepScreenshot(app, name: "business-onboarding-story")
        XCTAssertTrue(next.isEnabled)
    }

    @MainActor
    func testBusinessPlansShowBothPaidTiers() throws {
        let app = launch(["--ui-test-business-plans"])
        XCTAssertTrue(app.buttons["business.plans.buy.pro"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["business.plans.buy.business"].exists)
        keepScreenshot(app, name: "business-plans")
    }

    /// Needs the local seed backend (see BusinessUITests notes); skipped everywhere else.
    @MainActor
    func testDirectoryOpensBusinessPage() throws {
        try XCTSkipUnless(localBackendIsRunning(), "Local seed backend on 127.0.0.1:8765 is not running")
        let app = launch(["-screenshotTab", "3", "-screenshotMarketMode", "businesses"])

        XCTAssertTrue(app.staticTexts["Каталог"].waitForExistence(timeout: 20))
        keepScreenshot(app, name: "business-directory")
        let card = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Борщ & Kaffee'")).firstMatch
        app.swipeUp()
        keepScreenshot(app, name: "business-directory-list")
        app.swipeDown()

        XCTAssertTrue(scrollToElement(card, in: app))
        card.tap()
        XCTAssertTrue(app.buttons["business.page.book"].waitForExistence(timeout: 15))
        keepScreenshot(app, name: "business-page-top")
        app.swipeUp()
        keepScreenshot(app, name: "business-page-offers")
        app.swipeUp()
        app.swipeUp()
        keepScreenshot(app, name: "business-page-reviews")
    }

    /// Needs the local seed backend; business pages with an address appear among map places.
    @MainActor
    func testMapListsBusinessPlaces() throws {
        try XCTSkipUnless(localBackendIsRunning(), "Local seed backend on 127.0.0.1:8765 is not running")
        let app = launch(["-screenshotTab", "2"])
        let business = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'UA Business Club' OR label CONTAINS 'Борщ'")).firstMatch
        XCTAssertTrue(business.waitForExistence(timeout: 25))
        keepScreenshot(app, name: "business-map")
    }

    /// Needs the local seed backend plus `TEST_RUNNER_UITEST_ACCESS_TOKEN` / `TEST_RUNNER_UITEST_USER_ID`.
    @MainActor
    func testOwnerDashboardShowsGrowthTools() throws {
        let environment = ProcessInfo.processInfo.environment
        guard localBackendIsRunning(), let token = environment["UITEST_ACCESS_TOKEN"], let userID = environment["UITEST_USER_ID"] else {
            throw XCTSkip("Local seed backend session is not configured")
        }
        let app = launch(["--ui-test-business-dashboard"], environment: ["UITEST_ACCESS_TOKEN": token, "UITEST_USER_ID": userID])

        let growth = app.buttons["Просування"]
        XCTAssertTrue(growth.waitForExistence(timeout: 20))
        growth.tap()
        XCTAssertTrue(app.staticTexts["Статистика"].waitForExistence(timeout: 10))
        keepScreenshot(app, name: "business-owner-growth")
        app.swipeUp()
        keepScreenshot(app, name: "business-owner-boost")
        app.swipeDown()
        app.swipeDown()
        growth.swipeLeft()
        for tab in ["Акції", "Відгуки"] {
            let button = app.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            // Let the tab cross-fade settle before capturing.
            Thread.sleep(forTimeInterval: 1)
            keepScreenshot(app, name: "business-owner-\(tab == "Акції" ? "offers" : "reviews")")
        }
    }

    @MainActor
    private func launch(_ arguments: [String], environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + [
            "-onboarding_completed", "YES", "-initial_auth_choice_completed", "YES",
            "--skip-feature-onboarding", "-selected_locale", "uk", "-AppleLanguages", "(uk)",
            "-selectedTheme", "light", "-pending_initial_auth_entry", "NO"
        ]
        app.launchEnvironment["UITESTS"] = "1"
        app.launchEnvironment.merge(environment) { _, new in new }
        app.launch()
        return app
    }

    private func localBackendIsRunning() -> Bool {
        guard let url = URL(string: "http://127.0.0.1:8765/health") else { return false }
        let done = expectation(description: "health")
        var ok = false
        URLSession.shared.dataTask(with: url) { _, response, _ in
            ok = (response as? HTTPURLResponse)?.statusCode == 200
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 3)
        return ok
    }

    @MainActor
    private func keepScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 8) -> Bool {
        if element.waitForExistence(timeout: 3), element.isHittable { return true }
        for _ in 0..<attempts {
            app.swipeUp()
            if element.exists, element.isHittable { return true }
        }
        return false
    }
}
