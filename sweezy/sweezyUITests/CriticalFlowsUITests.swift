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
    func testSwissDiscoveryCatalogIsReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboarding_completed", "YES",
            "-initial_auth_choice_completed", "YES",
            "-screenshotTab", "1",
            "-screenshotDirectoryWorkspace", "tools",
            "--skip-feature-onboarding"
        ]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()

        let discoveryCard = app.buttons["journey.tool.discoverSwitzerland"]
        XCTAssertTrue(discoveryCard.waitForExistence(timeout: 15))
        discoveryCard.tap()

        XCTAssertTrue(app.descendants(matching: .any)["swiss.discovery.screen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["journey.tool.discoverSwitzerland"].exists == false)

        keepScreenshot(app, name: "swiss-discovery-catalog")

        let featuredPlace = app.buttons["swiss.discovery.place.aletsch"]
        XCTAssertTrue(featuredPlace.waitForExistence(timeout: 10))
        featuredPlace.tap()

        XCTAssertTrue(app.descendants(matching: .any)["swiss.discovery.detail.aletsch"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["swiss.discovery.detail.description"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["tab.directory"].exists)
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 3))
        keepScreenshot(app, name: "swiss-discovery-detail")
    }

    @MainActor
    func testPrimaryMapShowsSwissDiscoveryPlaces() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboarding_completed", "YES",
            "-initial_auth_choice_completed", "YES",
            "--skip-feature-onboarding"
        ]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()

        let mapTab = app.buttons["tab.map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 15))
        mapTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["map.screen"].waitForExistence(timeout: 10))
        let discoveryFilter = app.buttons["journey.map.discovery.filter"]
        XCTAssertTrue(discoveryFilter.waitForExistence(timeout: 10))
        discoveryFilter.tap()

        XCTAssertTrue(app.descendants(matching: .any)["journey.map.discovery.card.aletsch"].waitForExistence(timeout: 10))
        keepScreenshot(app, name: "primary-map-swiss-discovery")
    }

    @MainActor
    func testCVBuilderSupportsBackButtonAndInteractiveSwipe() throws {
        var app = launchCVBuilder()
        let directory = app.descendants(matching: .any)["directory.screen"]
        let backButton = app.buttons["cv.builder.back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 10))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.09, dy: 0.085)).tap()
        XCTAssertTrue(directory.waitForExistence(timeout: 10))
        XCTAssertFalse(backButton.exists)

        app.terminate()
        app = launchCVBuilder()
        XCTAssertTrue(app.buttons["cv.builder.back"].waitForExistence(timeout: 10))

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)

        XCTAssertTrue(directory.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["cv.builder.back"].exists)
    }

    @MainActor
    func testCVKeyboardDismissalAndPreviewRemainUsable() throws {
        let app = launchCVBuilder()
        let phone = app.textFields["cv.field.Телефон"]
        XCTAssertTrue(phone.waitForExistence(timeout: 10))
        phone.tap()
        phone.typeText("+41791234567")
        XCTAssertTrue(app.buttons["cv.keyboard.done"].waitForExistence(timeout: 5))
        app.buttons["cv.keyboard.done"].tap()

        let next = app.buttons["cv.navigation.next"]
        XCTAssertTrue(next.isHittable)
        next.tap()
        let summary = app.textViews["cv.textarea.Про мене"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        summary.tap()
        summary.typeText("Керувала 4 проєктами.")
        app.swipeDown()
        XCTAssertTrue(next.isHittable)

        for _ in 0..<4 {
            next.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["cv.preview.card"].waitForExistence(timeout: 10))
        XCTAssertTrue(next.isHittable)
    }

    @MainActor
    func testCareerHubConnectsCVToJobMatches() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-career-hub"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["careerHub.dashboard"].waitForExistence(timeout: 15))
        let primaryAction = app.buttons["careerHub.primaryAction"]
        XCTAssertTrue(primaryAction.exists)
        XCTAssertTrue(primaryAction.isHittable)
        XCTAssertTrue(app.staticTexts["12"].exists)
        XCTAssertTrue(app.staticTexts["AI збігів"].exists)

        keepScreenshot(app, name: "career-hub-dashboard")
    }

    @MainActor
    func testProfessionalNetworkShowsIntentionalDiscoveryExperience() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-network"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["network.screen"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Знайомства\nз наміром"].exists)
        XCTAssertTrue(app.staticTexts["3 нових контактів"].exists)
        XCTAssertTrue(app.staticTexts["Oleksandr Melnyk"].waitForExistence(timeout: 10))

        keepScreenshot(app, name: "professional-network")
    }

    @MainActor
    func testCareerHubIsVisibleFromTools() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-career-tools"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()

        let careerHub = app.buttons["journey.tool.careerHub"]
        XCTAssertTrue(careerHub.waitForExistence(timeout: 15))
        XCTAssertTrue(careerHub.isHittable)
        XCTAssertTrue(app.staticTexts["Кар’єра у Швейцарії"].exists)
        keepScreenshot(app, name: "career-hub-tools-entry")
    }

    @MainActor
    func testFriendsHubFitsPhoneViewport() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-friends"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()

        let screen = app.descendants(matching: .any)["friends.screen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 15))
        let title = app.descendants(matching: .any)["friends.heroTitle"]
        XCTAssertTrue(title.exists)
        XCTAssertGreaterThanOrEqual(title.frame.minX, 0)
        XCTAssertLessThanOrEqual(title.frame.maxX, app.frame.maxX)
        keepScreenshot(app, name: "friends-responsive")
    }

    @MainActor
    private func launchCVBuilder() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboarding_completed", "YES",
            "-initial_auth_choice_completed", "YES",
            "-screenshotTab", "1",
            "-screenshotDirectoryWorkspace", "tools",
            "--skip-feature-onboarding",
            "--ui-test-cv-builder"
        ]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()
        return app
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

    @MainActor
    private func keepScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
