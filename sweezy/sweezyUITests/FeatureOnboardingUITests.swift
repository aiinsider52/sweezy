import XCTest

/// Captures the first-visit section onboarding mid-animation and on its second slide.
final class FeatureOnboardingUITests: XCTestCase {
    @MainActor
    func testCaptureDirectoryOnboarding() throws { try capture(tab: "tab.directory", name: "onb-directory") }

    @MainActor
    func testCapturePeopleOnboarding() throws { try capture(tab: "tab.people", name: "onb-people") }

    @MainActor
    private func capture(tab: String, name: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarding_completed", "YES", "-initial_auth_choice_completed", "YES",
                               "-pending_initial_auth_entry", "NO", "-selected_locale", "uk", "-AppleLanguages", "(uk)"]
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 20))
        app.buttons[tab].tap()
        let close = app.buttons["featureOnboarding.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.25)
        keep(app, "\(name)-1")
        Thread.sleep(forTimeInterval: 1.4)
        keep(app, "\(name)-2")
        app.swipeLeft()
        Thread.sleep(forTimeInterval: 1.4)
        keep(app, "\(name)-3")
    }

    @MainActor
    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
