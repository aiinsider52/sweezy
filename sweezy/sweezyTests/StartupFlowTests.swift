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
    
    func testChecklistsNeverMixLanguages() async {
        let svc = ContentService(bundle: .main, autoLoad: false)
        for language in ["uk", "de", "en"] {
            await svc.loadLocalizedContent(for: language)
            let items = svc.getChecklistsForLocale(language)
            XCTAssertFalse(items.isEmpty, "No \(language) checklists")
            XCTAssertTrue(items.allSatisfy { ($0.language ?? "uk") == language }, "Mixed languages for \(language)")
        }
    }
}



