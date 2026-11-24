import Foundation

/// What the server's letter explainer returns for one letter.
struct LetterExplanation: Codable, Hashable {
    var sender: String
    var senderAddress: String?
    var category: String
    var title: String
    var summary: String
    var whatTheyWant: String
    var urgency: String
    var deadline: String?
    var deadlineLabel: String?
    var amount: Double?
    var currency: String?
    var steps: [String]
    var replyLetter: String?
    var replyLanguage: String?
    var specialist: String?
    var warnings: [String]

    enum CodingKeys: String, CodingKey {
        case sender, category, title, summary, urgency, deadline, amount, currency, steps, specialist, warnings
        case senderAddress = "sender_address"
        case whatTheyWant = "what_they_want"
        case deadlineLabel = "deadline_label"
        case replyLetter = "reply_letter"
        case replyLanguage = "reply_language"
    }

    var deadlineDate: Date? {
        guard let deadline else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: deadline)
    }

    var kind: LetterCategory { LetterCategory(rawValue: category) ?? .other }
}

enum LetterCategory: String, CaseIterable {
    case migration, insurance, tax, municipality, work, housing, bank, school, court, other

    var icon: String {
        switch self {
        case .migration: return "person.text.rectangle.fill"
        case .insurance: return "cross.case.fill"
        case .tax: return "building.columns.fill"
        case .municipality: return "house.and.flag.fill"
        case .work: return "briefcase.fill"
        case .housing: return "key.fill"
        case .bank: return "creditcard.fill"
        case .school: return "graduationcap.fill"
        case .court: return "scale.3d"
        case .other: return "envelope.fill"
        }
    }

    var swatch: JourneyCategorySwatch {
        switch self {
        case .migration, .bank: return JourneyCategoryPalette.sky
        case .insurance: return JourneyCategoryPalette.coral
        case .tax, .court: return JourneyCategoryPalette.sand
        case .municipality, .housing: return JourneyCategoryPalette.teal
        case .work, .school: return JourneyCategoryPalette.lilac
        case .other: return JourneyCategoryPalette.lime
        }
    }

    var title: String { "letters.category.\(rawValue)".localized }
}

/// A payment slip read from the letter's QR code: a Swiss QR-bill ("SPC") or an EPC/GiroCode ("BCD").
struct PaymentSlip: Codable, Hashable {
    var iban: String
    var creditor: String
    var amount: Double?
    var currency: String
    var reference: String?
    var message: String?

    static func parse(_ payload: String) -> PaymentSlip? {
        let lines = payload.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        func line(_ index: Int) -> String { index < lines.count ? lines[index].trimmingCharacters(in: .whitespaces) : "" }

        if line(0) == "SPC" {
            // Swiss QR-bill: 3 IBAN, 5 creditor name, 18 amount, 19 currency, 28 reference, 29 message.
            let iban = line(3)
            guard !iban.isEmpty else { return nil }
            return PaymentSlip(
                iban: iban,
                creditor: line(5),
                amount: Double(line(18)),
                currency: line(19).isEmpty ? "CHF" : line(19),
                reference: line(28).nilIfEmpty,
                message: line(29).nilIfEmpty
            )
        }
        if line(0) == "BCD" {
            // EPC QR / GiroCode: 5 name, 6 IBAN, 7 "EUR12.34", 9 reference, 10 remittance text.
            let iban = line(6)
            guard !iban.isEmpty else { return nil }
            let amountField = line(7)
            let currency = String(amountField.prefix(3))
            return PaymentSlip(
                iban: iban,
                creditor: line(5),
                amount: Double(amountField.dropFirst(3)),
                currency: currency.isEmpty ? "EUR" : currency,
                reference: line(9).nilIfEmpty,
                message: line(10).nilIfEmpty
            )
        }
        return nil
    }

    /// IBAN in groups of four, the way it is printed on a slip.
    var formattedIBAN: String {
        let compact = iban.replacingOccurrences(of: " ", with: "")
        return stride(from: 0, to: compact.count, by: 4).map { offset -> String in
            let start = compact.index(compact.startIndex, offsetBy: offset)
            let end = compact.index(start, offsetBy: min(4, compact.distance(from: start, to: compact.endIndex)))
            return String(compact[start..<end])
        }.joined(separator: " ")
    }
}

/// One letter the user has had explained. Kept only on the phone.
struct SavedLetter: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    var explanation: LetterExplanation
    var payment: PaymentSlip?
    var deadlineAdded: Bool
}

/// The user's explained letters, newest first, stored in a protected file on the device.
@MainActor
final class LetterStore: ObservableObject {
    static let shared = LetterStore()

    @Published private(set) var letters: [SavedLetter] = []

    private let fileURL: URL = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("letters.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode([SavedLetter].self, from: data) {
            letters = stored
        }
    }

    func add(_ letter: SavedLetter) {
        letters.insert(letter, at: 0)
        persist()
    }

    func update(_ letter: SavedLetter) {
        guard let index = letters.firstIndex(where: { $0.id == letter.id }) else { return }
        letters[index] = letter
        persist()
    }

    func remove(_ id: UUID) {
        letters.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(letters)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            #if DEBUG
            print("LetterStore persist failed: \(error)")
            #endif
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
