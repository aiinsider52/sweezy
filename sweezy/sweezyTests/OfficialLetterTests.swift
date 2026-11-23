import CoreImage.CIFilterBuiltins
import UIKit
import XCTest
@testable import sweezy

final class OfficialLetterTests: XCTestCase {
    func testParsesSwissQRBill() throws {
        let payload = [
            "SPC", "0200", "1", "CH4431999123000889012",
            "S", "Kantonales Steueramt Zürich", "Bändliweg", "21", "8090", "Zürich", "CH",
            "", "", "", "", "", "", "",
            "1240.50", "CHF",
            "S", "Olena Kovalenko", "Seestrasse", "5", "8002", "Zürich", "CH",
            "QRR", "210000000003139471430009017", "Staatssteuern 2025", "EPD",
        ].joined(separator: "\r\n")

        let slip = try XCTUnwrap(PaymentSlip.parse(payload))

        XCTAssertEqual(slip.iban, "CH4431999123000889012")
        XCTAssertEqual(slip.creditor, "Kantonales Steueramt Zürich")
        XCTAssertEqual(slip.amount, 1240.50)
        XCTAssertEqual(slip.currency, "CHF")
        XCTAssertEqual(slip.reference, "210000000003139471430009017")
        XCTAssertEqual(slip.message, "Staatssteuern 2025")
        XCTAssertEqual(slip.formattedIBAN, "CH44 3199 9123 0008 8901 2")
    }

    func testParsesSwissQRBillWithoutAmount() throws {
        var lines = Array(repeating: "", count: 31)
        lines[0] = "SPC"; lines[3] = "CH5604835012345678009"; lines[5] = "Gemeinde Bern"; lines[19] = "CHF"; lines[27] = "NON"; lines[30] = "EPD"

        let slip = try XCTUnwrap(PaymentSlip.parse(lines.joined(separator: "\n")))

        XCTAssertNil(slip.amount)
        XCTAssertNil(slip.reference)
    }

    func testParsesEPCGiroCode() throws {
        let payload = ["BCD", "002", "1", "SCT", "COBADEFFXXX", "Stadtkasse München", "DE89370400440532013000", "EUR89.90", "", "RF18539007547034", "Rundfunkbeitrag"].joined(separator: "\n")

        let slip = try XCTUnwrap(PaymentSlip.parse(payload))

        XCTAssertEqual(slip.iban, "DE89370400440532013000")
        XCTAssertEqual(slip.creditor, "Stadtkasse München")
        XCTAssertEqual(slip.amount, 89.90)
        XCTAssertEqual(slip.currency, "EUR")
        XCTAssertEqual(slip.reference, "RF18539007547034")
    }

    func testIgnoresOtherQRCodes() {
        XCTAssertNil(PaymentSlip.parse("https://www.sweezy.world"))
        XCTAssertNil(PaymentSlip.parse("SPC\n0200\n1\n"))
    }

    func testDecodesServerExplanation() throws {
        let json = """
        {"sender":"Steueramt","sender_address":null,"category":"tax","title":"Рахунок","summary":"s","what_they_want":"w",
         "urgency":"high","deadline":"2026-12-23","deadline_label":"Сплатити","amount":1240.5,"currency":"CHF",
         "steps":["a"],"reply_letter":null,"reply_language":null,"specialist":"accounting","warnings":[],"generated_by_ai":true}
        """.data(using: .utf8)!

        let explanation = try JSONDecoder().decode(LetterExplanation.self, from: json)

        XCTAssertEqual(explanation.kind, .tax)
        XCTAssertEqual(explanation.amount, 1240.5)
        let components = try XCTUnwrap(explanation.deadlineDate).description
        XCTAssertTrue(components.hasPrefix("2026-12-2"))
    }

    func testReaderRecognisesGermanTextAndQRBillOnDevice() async throws {
        let qrPayload = [
            "SPC", "0200", "1", "CH4431999123000889012",
            "S", "Kantonales Steueramt Zürich", "Bändliweg", "21", "8090", "Zürich", "CH",
            "", "", "", "", "", "", "",
            "1240.50", "CHF",
            "", "", "", "", "", "", "",
            "NON", "", "Staatssteuern 2025", "EPD",
        ].joined(separator: "\n")
        let page = Self.renderLetter(lines: [
            "Kantonales Steueramt Zürich",
            "Schlussrechnung Staats- und Gemeindesteuern 2025",
            "Sehr geehrte Frau Kovalenko",
            "Bitte bezahlen Sie den Betrag von CHF 1240.50",
            "innert 30 Tagen ab Rechnungsdatum.",
        ], qr: qrPayload)

        let result = try await LetterReader.read([page])

        XCTAssertTrue(result.text.contains("Steueramt"), result.text)
        XCTAssertTrue(result.text.contains("1240.50"), result.text)
        XCTAssertEqual(result.payment?.iban, "CH4431999123000889012")
        XCTAssertEqual(result.payment?.amount, 1240.50)
    }

    func testReaderRejectsBlankPage() async {
        do {
            _ = try await LetterReader.read([Self.renderLetter(lines: [], qr: nil)])
            XCTFail("Blank page should not be read as a letter")
        } catch {
            XCTAssertTrue(error is LetterReader.ReadError)
        }
    }

    private static func renderLetter(lines: [String], qr: String?) -> UIImage {
        let size = CGSize(width: 1240, height: 1754)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 34), .foregroundColor: UIColor.black]
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(at: CGPoint(x: 110, y: 160 + CGFloat(index) * 64), withAttributes: attributes)
            }
            if let qr {
                let filter = CIFilter.qrCodeGenerator()
                filter.message = Data(qr.utf8)
                filter.correctionLevel = "M"
                if let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 9, y: 9)),
                   let cgImage = CIContext().createCGImage(output, from: output.extent) {
                    UIImage(cgImage: cgImage).draw(in: CGRect(x: 110, y: 1000, width: output.extent.width, height: output.extent.height))
                }
            }
        }
    }
}
