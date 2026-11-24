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
