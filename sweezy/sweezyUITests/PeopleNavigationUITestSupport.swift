import XCTest

extension XCUIApplication {
    /// People has no tab any more: it opens from the "People" card on the home page.
    func openPeople(file: StaticString = #filePath, line: UInt = #line) {
        buttons["tab.home"].tap()
        let card = buttons["home.explore.people"]
        var swipes = 0
        while !(card.exists && card.isHittable) && swipes < 8 {
            swipeUp()
            swipes += 1
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "People card not found on home", file: file, line: line)
        card.tap()
    }
}
