import PDFKit
import XCTest
@testable import sweezy

@MainActor
final class JobSearchReportTests: XCTestCase {
    func testTrackerStatusMapsToReportOutcome() {
        XCTAssertEqual(JobSearchLogStore.outcome(for: "applied"), .pending)
        XCTAssertEqual(JobSearchLogStore.outcome(for: "interview"), .interview)
        XCTAssertEqual(JobSearchLogStore.outcome(for: "offer"), .offer)
        XCTAssertEqual(JobSearchLogStore.outcome(for: "rejected"), .rejected)
        XCTAssertEqual(JobSearchLogStore.outcome(for: "withdrawn"), .withdrawn)
    }

    func testParsesServerTimestamps() {
        XCTAssertNotNil(JobSearchLogStore.parse("2026-11-03T09:15:00.123456Z") ?? JobSearchLogStore.parse("2026-11-03T09:15:00Z"))
        XCTAssertNil(JobSearchLogStore.parse(nil))
    }

    func testRendersGermanTableAcrossPages() throws {
        let entries = (1...30).map { index in
            JobSearchEntry(id: "\(index)", date: Date(), company: "Firma \(index) AG", location: "Zürich",
                           position: "Logistiker/in EFZ \(index)", method: .email, workload: "80", contact: "Frau Muster",
                           outcome: index.isMultiple(of: 3) ? .rejected : .pending, trackerJobID: nil)
        }

        let url = try JobSearchReportPDF.render(entries: entries, month: Date(), name: "Olena Kovalenko", country: .switzerland)

        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(document.pageCount, 1, "30 rows should not fit on one landscape page")
        let text = try XCTUnwrap(document.string)
        XCTAssertTrue(text.contains("Übersicht der persönlichen Arbeitsbemühungen"))
        XCTAssertTrue(text.contains("Olena Kovalenko"))
        XCTAssertTrue(text.contains("Absage"))
        XCTAssertTrue(text.contains("RAV"))
    }
}
