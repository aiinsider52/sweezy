import XCTest
@testable import sweezy

@MainActor
final class StartupFlowTests: XCTestCase {
    func testContentServiceLocalizedFallbackDoesNotCrash() async {
        let svc = ContentService(bundle: .main, autoLoad: false)
        await svc.loadLocalizedContent(for: "en")
        // Should not crash and should return some array (possibly fallback)
        XCTAssertNotNil(svc.checklists)
    }
    
    func testGetChecklistsForLocaleFallback() async {
        let svc = ContentService(bundle: .main, autoLoad: false)
        await svc.loadContent()
        let uk = svc.getChecklistsForLocale("uk")
        let de = svc.getChecklistsForLocale("de")
        XCTAssertFalse(uk.isEmpty || de.isEmpty, "Should have base or fallback checklists")
    }
}



