import XCTest

/// Captures the people, create-listing and guides screens for design review.
final class DesignAuditUITests: XCTestCase {
    @MainActor
    func testCapturePeople() throws {
        let app = launch(["--ui-test-friends"])
        XCTAssertTrue(app.otherElements["friends.screen"].waitForExistence(timeout: 20) || app.wait(for: .runningForeground, timeout: 5))
        Thread.sleep(forTimeInterval: 2)
        keep(app, "people-1")
        let search = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Пошук")).firstMatch
        if search.waitForExistence(timeout: 5) { search.tap() }
        Thread.sleep(forTimeInterval: 1)
        keep(app, "people-2")
        app.swipeUp(); keep(app, "people-3")
        app.swipeUp(); keep(app, "people-4")
    }

    @MainActor
    func testCaptureCreateService() throws { try captureCreate("--ui-test-create-service", name: "create-service") }

    @MainActor
    func testCaptureCreateItem() throws { try captureCreate("--ui-test-create-item", name: "create-item") }

    @MainActor
    func testCaptureGuides() throws {
        let app = launch(["-onboarding_completed", "YES", "-initial_auth_choice_completed", "YES",
                          "--skip-feature-onboarding", "-pending_initial_auth_entry", "NO"])
        XCTAssertTrue(app.buttons["tab.directory"].waitForExistence(timeout: 20))
        app.buttons["tab.directory"].tap()
        Thread.sleep(forTimeInterval: 6)
        keep(app, "guides-1")
        app.swipeUp(); Thread.sleep(forTimeInterval: 1); keep(app, "guides-2")
        app.swipeUp(); Thread.sleep(forTimeInterval: 1); keep(app, "guides-3")
        app.swipeUp(); Thread.sleep(forTimeInterval: 1); keep(app, "guides-4")
        app.buttons["tab.settings"].tap()
        Thread.sleep(forTimeInterval: 2)
        keep(app, "guides-5-settings")
    }

    @MainActor
    func testCaptureGuideArticle() throws {
        let app = launch(["--ui-test-article-layout"])
        Thread.sleep(forTimeInterval: 3)
        keep(app, "article-1")
        app.swipeUp(); keep(app, "article-2")
        app.swipeUp(); keep(app, "article-3")
    }

    @MainActor
    private func captureCreate(_ flag: String, name: String) throws {
        let app = launch([flag])
        Thread.sleep(forTimeInterval: 3)
        keep(app, "\(name)-1")
        for index in 2...5 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.6)
            keep(app, "\(name)-\(index)")
        }
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-selected_locale", "uk", "-AppleLanguages", "(uk)"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()
        return app
    }

    @MainActor
    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
