//
//  sweezyUITestsLaunchTests.swift
//  sweezyUITests
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import XCTest

final class sweezyUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        // The simulator can be left in landscape between runs; every layout assertion assumes portrait.
        XCUIDevice.shared.orientation = .portrait
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
