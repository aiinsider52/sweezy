import PDFKit
import XCTest
@testable import sweezy

final class CVDocumentFormatterTests: XCTestCase {
    private let formatter = CVDocumentFormatter()

    func testUkrainianGoldenTextUsesLabeledContactsAndStableSections() {
        let text = formatter.text(from: fixture(), language: .ukrainian)

        XCTAssertEqual(text, """
        Olena Kovalenko
        Product Manager
        Email: olena@example.com
        Телефон: +41 79 123 45 67
        Місце проживання: Zürich, ZH

        ПРОФІЛЬ
        Builds useful products.

        ДОСВІД РОБОТИ
        Product Manager — Private AG
        Період: 2022–2025
        Місце проживання: Zürich
        Improved activation by 20%.

        ОСВІТА
        MSc — Private University
        Період: 2018–2020
        Economics

        НАВИЧКИ
        Analytics
        Roadmaps

        МОВИ
        Deutsch: B2
        """)
    }

    func testGermanGoldenTextUsesGermanLabels() {
        let text = formatter.text(from: fixture(), language: .german)

        XCTAssertTrue(text.contains("E-Mail: olena@example.com"))
        XCTAssertTrue(text.contains("Telefon: +41 79 123 45 67"))
        XCTAssertTrue(text.contains("Wohnort: Zürich, ZH"))
        XCTAssertTrue(text.contains("\nPROFIL\n"))
        XCTAssertTrue(text.contains("\nBERUFSERFAHRUNG\n"))
        XCTAssertTrue(text.contains("\nAUSBILDUNG\n"))
        XCTAssertTrue(text.contains("\nFÄHIGKEITEN\n"))
        XCTAssertTrue(text.contains("\nSPRACHEN\n"))
    }

    func testCandidateSummaryExcludesDirectAndIndirectIdentifiers() throws {
        let summary = try XCTUnwrap(formatter.candidateSummary(from: fixture(), language: .german))

        XCTAssertFalse(summary.contains("Olena"))
        XCTAssertFalse(summary.contains("olena@example.com"))
        XCTAssertFalse(summary.contains("+41"))
        XCTAssertFalse(summary.contains("Zürich"))
        XCTAssertFalse(summary.contains("Private AG"))
        XCTAssertFalse(summary.contains("Private University"))
        XCTAssertTrue(summary.contains("Product Manager"))
        XCTAssertTrue(summary.contains("Analytics"))
        XCTAssertLessThanOrEqual(summary.count, 4_000)
    }

    func testFilenameIsSafeAndLanguageSpecific() {
        var resume = fixture()
        resume.personal.fullName = "  Olena / Kovalenko  "

        XCTAssertEqual(formatter.filename(for: resume, language: .german), "Olena_Kovalenko_CV_de.pdf")
    }

    func testGermanTranslationCacheInvalidatesAfterAnySourceEdit() {
        let original = fixture()
        var edited = original
        edited.education[0].details = "Updated diploma details"

        XCTAssertFalse(CVTranslationCachePolicy.shouldInvalidate(cachedSource: original, currentSource: original))
        XCTAssertTrue(CVTranslationCachePolicy.shouldInvalidate(cachedSource: original, currentSource: edited))
    }

    func testPDFPaginatesAndKeepsSelectableText() throws {
        let marker = "SELECTABLE ATS MARKER"
        let longText = Array(repeating: "\(marker)\nExperienced product manager with measurable results.", count: 180)
            .joined(separator: "\n")
        let url = try PaginatedTextPDFExporter().export(
            text: longText,
            filename: "Candidate_CV_de.pdf",
            title: "ATS CV"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(document.pageCount, 1)
        XCTAssertTrue(document.string?.contains(marker) == true)
    }

    private func fixture() -> CVResume {
        var resume = CVResume.empty
        resume.personal = CVPersonal(
            fullName: "Olena Kovalenko",
            title: "Product Manager",
            email: "olena@example.com",
            phone: "+41 79 123 45 67",
            location: "Zürich, ZH",
            summary: "Builds useful products."
        )
        resume.experience = [
            CVExperience(
                role: "Product Manager",
                company: "Private AG",
                period: "2022–2025",
                location: "Zürich",
                achievements: "Improved activation by 20%."
            )
        ]
        resume.education = [
            CVEducation(
                school: "Private University",
                degree: "MSc",
                period: "2018–2020",
                details: "Economics"
            )
        ]
        resume.skills = ["Analytics", "Roadmaps"]
        resume.languages = [CVLanguage(name: "Deutsch", level: "B2")]
        return resume
    }
}
