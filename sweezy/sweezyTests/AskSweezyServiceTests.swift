import XCTest
@testable import sweezy

final class AskSweezyServiceTests: XCTestCase {
    func testOfficialHostsCoverAllThreeCountries() {
        XCTAssertTrue(AskSweezyService.isOfficialHost("www.sem.admin.ch"))
        XCTAssertTrue(AskSweezyService.isOfficialHost("ch.ch"))
        XCTAssertTrue(AskSweezyService.isOfficialHost("www.be.ch"))
        XCTAssertTrue(AskSweezyService.isOfficialHost("zh.ch"))
        XCTAssertTrue(AskSweezyService.isOfficialHost("www.bamf.de"))
        XCTAssertTrue(AskSweezyService.isOfficialHost("www.oesterreich.gv.at"))
        XCTAssertTrue(AskSweezyService.isOfficialHost("www.ams.at"))

        XCTAssertFalse(AskSweezyService.isOfficialHost("comparis.ch"))
        XCTAssertFalse(AskSweezyService.isOfficialHost("example.com"))
        XCTAssertFalse(AskSweezyService.isOfficialHost("notbamf.de"))
    }

    func testPlainSentencesDropMarkdownNoise() {
        let markdown = """
        # Перегляд квартири
        ## Що перевірити:
        - [ ] Пошкодження чужого майна покриває страхування відповідальності
        ❌ Нижчі зарплати в гастрономії на старті
        Детальніше на [ch.ch](https://www.ch.ch/de/wohnen) про оренду житла.
        """
        let lines = AskSweezyService.plainSentences(from: markdown)
        XCTAssertEqual(lines, [
            "Пошкодження чужого майна покриває страхування відповідальності",
            "Нижчі зарплати в гастрономії на старті",
            "Детальніше на ch.ch про оренду житла."
        ])
    }
}

final class StreakRulesTests: XCTestCase {
    func testStreakForgivesOneQuietDay() {
        XCTAssertEqual(GamificationService.nextStreak(current: 0, gapDays: nil), 1, "first open is day 1")
        XCTAssertEqual(GamificationService.nextStreak(current: 4, gapDays: 0), 4, "same day")
        XCTAssertEqual(GamificationService.nextStreak(current: 4, gapDays: 1), 5, "next day")
        XCTAssertEqual(GamificationService.nextStreak(current: 4, gapDays: 2), 4, "one day skipped is frozen")
        XCTAssertEqual(GamificationService.nextStreak(current: 4, gapDays: 5), 1, "long break restarts")
        XCTAssertEqual(GamificationService.nextStreak(current: 999, gapDays: 1), 999, "capped")
    }
}
