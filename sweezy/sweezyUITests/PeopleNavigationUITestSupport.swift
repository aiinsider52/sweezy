import XCTest

extension XCUIApplication {
    /// People has no tab any more: it opens from the "People" card in the home explore carousel.
    func openPeople(file: StaticString = #filePath, line: UInt = #line) {
        buttons["tab.home"].tap()
        let card = buttons["home.explore.people"]
        let firstCard = buttons["home.explore.directory"]

        // Scroll the page until the carousel row is on screen (above the floating dock).
        var swipes = 0
        while !isOnScreen(firstCard) && !isOnScreen(card) && swipes < 8 {
            swipeUp()
            swipes += 1
        }

        // Then drag the row sideways until the People card is fully in view.
        var sideSwipes = 0
        while !isOnScreen(card) && sideSwipes < 5 {
            guard let anchor = [firstCard, card].first(where: \.exists) else { break }
            let rowY = anchor.frame.midY
            let start = coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0)).withOffset(CGVector(dx: 0, dy: rowY))
            let end = coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0)).withOffset(CGVector(dx: 0, dy: rowY))
            start.press(forDuration: 0.05, thenDragTo: end)
            sideSwipes += 1
        }

        XCTAssertTrue(isOnScreen(card), "People card not found on home", file: file, line: line)
        card.tap()
    }

    /// Whether the element's centre is inside the visible part of the screen, without asking for
    /// hittability (which throws for elements scrolled out of a horizontal stack).
    private func isOnScreen(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let elementFrame = element.frame
        guard !elementFrame.isEmpty else { return false }
        let visible = frame.inset(by: UIEdgeInsets(top: 60, left: 0, bottom: 120, right: 0))
        return visible.contains(CGPoint(x: elementFrame.midX, y: elementFrame.midY))
    }
}
