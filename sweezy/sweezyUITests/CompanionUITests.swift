import XCTest

/// Exercises existing routes and persistence; mascot artwork must never intercept controls.
final class CompanionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        // The simulator can be left in landscape between runs; every layout assertion assumes portrait.
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testDocumentProgressAndCompanionRoutes() throws {
        let app = launch()
        keep(app, "companion-home")
        app.buttons["home.myPlan"].tap()
        let documents = app.buttons["plan.documents"]
        reveal(documents, in: app)
        keep(app, "companion-plan")
        documents.tap()

        let progress = app.staticTexts["documents.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        keep(app, "companion-documents")
        let toggle = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "documents.toggle.")).firstMatch
        reveal(toggle, in: app)
        // Accessibility converts screen coordinates through floating-point transforms.
        XCTAssertGreaterThanOrEqual(toggle.frame.width, 44 - 0.01)
        XCTAssertGreaterThanOrEqual(toggle.frame.height, 44 - 0.01)
        let before = progress.label
        toggle.tap()
        XCTAssertNotEqual(progress.label, before)
        keep(app, "companion-document-reaction")
        // Restore the document state after verifying a real persisted toggle.
        toggle.tap()
        XCTAssertEqual(progress.label, before)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ask = app.buttons["plan.ask"]
        reveal(ask, in: app)
        ask.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10))
        keep(app, "companion-ask")

        app.buttons["tab.people"].tap()
        let signIn = app.buttons["friends.accessGate.signIn"]
        reveal(signIn, in: app)
        keep(app, "companion-people")
        XCTAssertTrue(signIn.isHittable)
    }

    @MainActor
    func testLargeTextKeepsDocumentActionsReachable() throws {
        let app = launch(largeText: true)
        let plan = app.buttons["home.myPlan"]
        reveal(plan, in: app)
        keep(app, "companion-home-large-text")
        plan.tap()
        let documents = app.buttons["plan.documents"]
        reveal(documents, in: app)
        documents.tap()
        let toggle = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "documents.toggle.")).firstMatch
        reveal(toggle, in: app)
        XCTAssertGreaterThanOrEqual(toggle.frame.minX, 0)
        XCTAssertLessThanOrEqual(toggle.frame.maxX, app.frame.maxX)
        let expiry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "documents.expiry.")).firstMatch
        reveal(expiry, in: app)
        XCTAssertLessThanOrEqual(expiry.frame.maxX, app.frame.maxX)
        keep(app, "companion-documents-large-text")
        expiry.tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testPeopleSearchEmptyStateAndFilters() throws {
        let app = launch()
        app.buttons["tab.people"].tap()
        let demo = app.buttons["friends.accessGate.demo"]
        reveal(demo, in: app)
        keep(app, "social-welcome-v2")
        demo.tap()
        let catalogToggle = app.buttons["friends.catalog.toggle"]
        reveal(catalogToggle, in: app)
        catalogToggle.tap()
        let search = app.textFields["friends.search.query"]
        reveal(search, in: app)
        keep(app, "social-search-v2")
        search.tap()
        search.typeText("zzzznomatch\n")
        let filters = app.buttons["friends.search.changeFilters"]
        reveal(filters, in: app)
        keep(app, "social-empty-v2")
        filters.tap()
        XCTAssertTrue(app.switches.firstMatch.waitForExistence(timeout: 5) || app.buttons["Застосувати"].exists)
    }

    @MainActor
    func testIllustratedCityMainTabs() throws {
        let app = launch()
        keep(app, "city-home")
        for (tab, name) in [("tab.directory", "city-directory"), ("tab.map", "city-map"), ("tab.marketplace", "city-market"), ("tab.people", "city-people")] {
            let button = app.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            let screen = tab == "tab.people" ? app.staticTexts["friends.accessGate.title"] : app.descendants(matching: .any)[tab.replacingOccurrences(of: "tab.", with: "") + ".screen"]
            XCTAssertTrue(screen.waitForExistence(timeout: 10))
            // Tab transitions render asynchronously after the accessibility selection changes.
            let settled = expectation(description: "Tab transition finished")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { settled.fulfill() }
            wait(for: [settled], timeout: 2)
            keep(app, name)
        }
    }

    @MainActor
    func testCitySettingsAndRegistration() throws {
        let app = launch()
        app.buttons["home.openSettingsButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.screen"].waitForExistence(timeout: 10))
        keep(app, "city-settings")
        let notifications = app.buttons["settings.notifications.open"]
        reveal(notifications, in: app)
        notifications.tap()
        keep(app, "city-notifications")
        app.terminate()

        let guest = launch()
        guest.buttons["tab.people"].tap()
        let signIn = guest.buttons["friends.accessGate.signIn"]
        reveal(signIn, in: guest)
        signIn.tap()
        let register = guest.buttons["auth.entry.createAccount"]
        reveal(register, in: guest)
        keep(guest, "city-auth")
        register.tap()
        XCTAssertTrue(guest.textFields["auth.registration.name"].waitForExistence(timeout: 10))
        XCTAssertFalse(guest.buttons["auth.registration.submit"].isEnabled)
        keep(guest, "city-registration")
    }

    @MainActor
    func testCitySecondaryScreens() throws {
        let routes = [
            ("--ui-test-cv-builder", "cv.builder.back", "city-cv"),
            ("--ui-test-email-verification", "auth.verify.code", "city-email"),
            ("--ui-test-jobs-gate", "careerHub.guestGate", "city-jobs"),
            ("--ui-test-trip-planner", "trip.planner.screen", "city-trip"),
            ("--ui-test-discovery", "swiss.discovery.back", "city-discovery"),
            ("--ui-test-network", "network.screen", "city-network"),
            ("--ui-test-career-tools", "journey.tool.careerHub", "city-tools"),
            ("--ui-test-article-layout", "guide.article.screen", "city-article")
        ]
        for (route, identifier, name) in routes {
            let app = XCUIApplication()
            app.launchArguments = [route, "-onboarding_completed", "YES", "-initial_auth_choice_completed", "YES",
                "--skip-feature-onboarding", "-selectedTheme", "light", "-AppleInterfaceStyle", "Light",
                "-selected_locale", "uk", "-AppleLanguages", "(uk)"]
            if route == "--ui-test-cv-builder" {
                app.launchArguments += ["-screenshotTab", "1", "-screenshotDirectoryWorkspace", "tools"]
            }
            // Earlier flows can persist a pending auth sheet that would cover this screen.
            app.launchArguments += ["-pending_initial_auth_entry", "NO"]
            app.launchEnvironment["UITESTS"] = "1"
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)[identifier].waitForExistence(timeout: 20), route)
            keep(app, name)
            app.swipeUp()
            keep(app, name + "-body")
            app.terminate()
        }
    }

    @MainActor
    func testCityFormsDoNotRequireSubmission() throws {
        for page in ["listing", "event", "templates", "checklists", "roadmap", "appointments", "language"] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-test-city-form", "--skip-feature-onboarding",
                "-selectedTheme", "light", "-AppleInterfaceStyle", "Light", "-selected_locale", "uk"]
            // Earlier flows can persist a pending auth sheet that would cover this screen.
            app.launchArguments += ["-pending_initial_auth_entry", "NO"]
            app.launchEnvironment["UITESTS"] = "1"
            app.launchEnvironment["CITY_TEST_PAGE"] = page
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["city.form." + page].waitForExistence(timeout: 20))
            keep(app, "city-form-" + page)
            app.swipeUp()
            keep(app, "city-form-" + page + "-body")
            app.terminate()
        }
    }

    @MainActor
    func testPaywallFitsViewportAndKeepsLegalReachable() throws {
        for (name, theme, large) in [("light", "light", false), ("dark", "dark", false), ("large", "light", true)] {
            let app = XCUIApplication()
            app.launchArguments = ["-screenshotPaywall", "YES", "-selectedTheme", theme,
                "-AppleInterfaceStyle", theme == "dark" ? "Dark" : "Light", "-selected_locale", "uk"]
            if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
            // Earlier flows can persist a pending auth sheet that would cover this screen.
            app.launchArguments += ["-pending_initial_auth_entry", "NO"]
            app.launchEnvironment["UITESTS"] = "1"
            app.launch()
            let purchase = app.buttons["subscription.purchase"]
            XCTAssertTrue(purchase.waitForExistence(timeout: 20))
            for control in [purchase, app.buttons["subscription.restore"], app.buttons["subscription.close"]] {
                XCTAssertTrue(control.isHittable)
                XCTAssertGreaterThanOrEqual(control.frame.minX, -0.5)
                XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX + 0.5)
                XCTAssertLessThanOrEqual(control.frame.maxY, app.frame.maxY)
            }
            XCTAssertLessThan(purchase.frame.height, app.frame.height * 0.25)
            keep(app, "polish-paywall-" + name)
            let privacy = app.buttons["subscription.privacy"]
            for _ in 0..<12 {
                if privacy.exists && privacy.isHittable && privacy.frame.maxY < purchase.frame.minY { break }
                app.swipeUp()
            }
            XCTAssertTrue(privacy.isHittable)
            XCTAssertGreaterThanOrEqual(privacy.frame.minX, -0.5)
            XCTAssertLessThanOrEqual(privacy.frame.maxX, app.frame.maxX + 0.5)
            XCTAssertLessThan(privacy.frame.maxY, purchase.frame.minY)
            keep(app, "polish-paywall-" + name + "-plans")
            app.terminate()
        }
    }

    @MainActor
    private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboarding_completed", "YES", "-initial_auth_choice_completed", "YES",
            "-pending_initial_auth_entry", "NO", "--skip-feature-onboarding",
            "-selected_locale", "uk", "-AppleLanguages", "(uk)",
            "-selectedTheme", largeText ? "dark" : "light",
            "-AppleInterfaceStyle", largeText ? "Dark" : "Light"
        ]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["home.myPlan"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if !element.exists { app.swipeUp(); continue }
            let tab = app.buttons["tab.home"]
            let bottom = tab.exists ? tab.frame.minY - 12 : app.frame.maxY - 40
            let requiredBottom = element.frame.height > bottom - 120 ? element.frame.midY : element.frame.maxY
            if element.exists && element.isHittable && element.frame.midY > 100 && requiredBottom < bottom { return }
            if element.exists && element.frame.midY < 100 { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, "Expected an accessible, unobstructed control: \(element)")
    }

    @MainActor
    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
