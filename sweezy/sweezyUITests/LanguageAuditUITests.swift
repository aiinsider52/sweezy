import XCTest

/// Captures the main screens per language so mixed-language strings are easy to spot.
final class LanguageAuditUITests: XCTestCase {
    @MainActor
    func testCaptureMainScreensInGerman() throws { try capture(language: "de") }

    @MainActor
    func testCaptureMainScreensInEnglish() throws { try capture(language: "en") }

    @MainActor
    func testCaptureMainScreensInUkrainian() throws { try capture(language: "uk") }

    @MainActor
    private func capture(language: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarding_completed", "YES", "-initial_auth_choice_completed", "YES",
                               "--skip-feature-onboarding", "-selected_locale", language,
                               "-AppleLanguages", "(\(language))", "-pending_initial_auth_entry", "NO"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["home.myPlan"].waitForExistence(timeout: 20))
        keep(app, "\(language)-home-1")
        app.swipeUp(); keep(app, "\(language)-home-2")
        app.swipeUp(); keep(app, "\(language)-home-3")
        for tab in ["tab.directory", "tab.map", "tab.marketplace", "tab.people"] {
            app.buttons[tab].tap()
            Thread.sleep(forTimeInterval: 1.5)
            keep(app, "\(language)-\(tab)")
        }
        app.buttons["tab.home"].tap()
        app.buttons["home.myPlan"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        keep(app, "\(language)-plan")
    }

    @MainActor
    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
