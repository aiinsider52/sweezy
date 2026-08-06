import Foundation
import UIKit

enum CVDocumentLanguage: String {
    case ukrainian = "uk"
    case german = "de"
}

struct CVDocumentFormatter {
    func text(from resume: CVResume, language: CVDocumentLanguage) -> String {
        let labels = Labels(language: language)
        var lines = nonEmpty([resume.personal.fullName, resume.personal.title])

        appendLabeled(resume.personal.email, label: labels.email, to: &lines)
        appendLabeled(resume.personal.phone, label: labels.phone, to: &lines)
        appendLabeled(resume.personal.location, label: labels.location, to: &lines)

        appendSection(labels.profile, lines: nonEmpty([resume.personal.summary]), to: &lines)

        let experience = resume.experience.filter {
            !$0.company.trimmed.isEmpty || !$0.role.trimmed.isEmpty
        }.flatMap { item -> [String] in
            var result = nonEmpty([
                [item.role.trimmed, item.company.trimmed].filter { !$0.isEmpty }.joined(separator: " — "),
                labels.periodLine(item.period.trimmed),
                labels.locationLine(item.location.trimmed)
            ])
            result.append(contentsOf: item.achievements.normalizedLines)
            return result
        }
        appendSection(labels.experience, lines: experience, to: &lines)

        let education = resume.education.filter {
            !$0.school.trimmed.isEmpty || !$0.degree.trimmed.isEmpty
        }.flatMap { item in
            nonEmpty([
                [item.degree.trimmed, item.school.trimmed].filter { !$0.isEmpty }.joined(separator: " — "),
                labels.periodLine(item.period.trimmed),
                item.details.trimmed
            ])
        }
        appendSection(labels.education, lines: education, to: &lines)

        appendSection(labels.skills, lines: resume.skills.map(\.trimmed).filter { !$0.isEmpty }, to: &lines)
        appendSection(
            labels.languages,
            lines: resume.languages.filter { !$0.name.trimmed.isEmpty }.map {
                "\($0.name.trimmed): \($0.level.trimmed)"
            },
            to: &lines
        )

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Excludes direct identifiers and contact details before CV context leaves the device.
    func candidateSummary(from resume: CVResume, language: CVDocumentLanguage) -> String? {
        let labels = Labels(language: language)
        var sections: [String] = []
        appendSection(labels.profile, lines: nonEmpty([resume.personal.summary]), to: &sections)
        appendSection(
            labels.experience,
            lines: resume.experience.prefix(5).flatMap {
                nonEmpty([$0.role.trimmed, $0.achievements.trimmed])
            },
            to: &sections
        )
        appendSection(labels.education, lines: resume.education.prefix(4).flatMap {
            nonEmpty([$0.degree.trimmed, $0.details.trimmed])
        }, to: &sections)
        appendSection(labels.skills, lines: resume.skills.prefix(30).map(\.trimmed), to: &sections)
        appendSection(labels.languages, lines: resume.languages.prefix(10).map {
            "\($0.name.trimmed): \($0.level.trimmed)"
        }, to: &sections)

        let sensitiveValues = [
            resume.personal.fullName,
            resume.personal.email,
            resume.personal.phone,
            resume.personal.location
        ] + resume.experience.flatMap { [$0.company, $0.location] }
          + resume.education.map(\.school)
        let redacted = sensitiveValues
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .reduce(sections.joined(separator: "\n")) { value, sensitive in
                value.replacingOccurrences(of: sensitive, with: "", options: .caseInsensitive)
            }
        let value = redacted
            .components(separatedBy: .newlines)
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !value.isEmpty else { return nil }
        return String(value.prefix(4_000))
    }

    func filename(for resume: CVResume, language: CVDocumentLanguage) -> String {
        let nameParts = resume.personal.fullName
            .split(whereSeparator: \.isWhitespace)
            .map(sanitizeFilenamePart)
            .filter { !$0.isEmpty }
            .prefix(2)
        let name = nameParts.isEmpty ? "Candidate" : nameParts.joined(separator: "_")
        return "\(name)_CV_\(language.rawValue).pdf"
    }

    private func appendLabeled(_ value: String, label: String, to lines: inout [String]) {
        let value = value.trimmed
        if !value.isEmpty { lines.append("\(label): \(value)") }
    }

    private func appendSection(_ title: String, lines sectionLines: [String], to lines: inout [String]) {
        let clean = sectionLines.map(\.trimmed).filter { !$0.isEmpty }
        guard !clean.isEmpty else { return }
        if !lines.isEmpty { lines.append("") }
        lines.append(title)
        lines.append(contentsOf: clean)
    }

    private func nonEmpty(_ values: [String]) -> [String] {
        values.map(\.trimmed).filter { !$0.isEmpty }
    }

    private func sanitizeFilenamePart(_ value: Substring) -> String {
        let latin = String(value).folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
        return latin.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? String($0) : "_"
        }.joined().trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private struct Labels {
        let email: String
        let phone: String
        let location: String
        let profile: String
        let experience: String
        let education: String
        let skills: String
        let languages: String
        let period: String

        init(language: CVDocumentLanguage) {
            switch language {
            case .ukrainian:
                email = "Email"
                phone = "Телефон"
                location = "Місце проживання"
                profile = "ПРОФІЛЬ"
                experience = "ДОСВІД РОБОТИ"
                education = "ОСВІТА"
                skills = "НАВИЧКИ"
                languages = "МОВИ"
                period = "Період"
            case .german:
                email = "E-Mail"
                phone = "Telefon"
                location = "Wohnort"
                profile = "PROFIL"
                experience = "BERUFSERFAHRUNG"
                education = "AUSBILDUNG"
                skills = "FÄHIGKEITEN"
                languages = "SPRACHEN"
                period = "Zeitraum"
            }
        }

        func periodLine(_ value: String) -> String { value.isEmpty ? "" : "\(period): \(value)" }
        func locationLine(_ value: String) -> String { value.isEmpty ? "" : "\(location): \(value)" }
    }
}

struct PaginatedTextPDFExporter {
    enum ExportError: Error {
        case emptyContent
    }

    func export(text: String, filename: String, title: String) throws -> URL {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExportError.emptyContent
        }

        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let contentRect = pageRect.insetBy(dx: 48, dy: 52)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 5
        let attributed = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ])

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "Sweezy"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let safeName = filename.replacingOccurrences(of: "/", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)

        try renderer.writePDF(to: url) { context in
            let storage = NSTextStorage(attributedString: attributed)
            let layoutManager = NSLayoutManager()
            storage.addLayoutManager(layoutManager)
            var renderedGlyphs = 0

            while renderedGlyphs < layoutManager.numberOfGlyphs {
                context.beginPage()
                let container = NSTextContainer(size: contentRect.size)
                container.lineFragmentPadding = 0
                layoutManager.addTextContainer(container)
                let range = layoutManager.glyphRange(for: container)
                layoutManager.drawBackground(forGlyphRange: range, at: contentRect.origin)
                layoutManager.drawGlyphs(forGlyphRange: range, at: contentRect.origin)
                renderedGlyphs = NSMaxRange(range)
                if range.length == 0 { break }
            }
        }
        return url
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var normalizedLines: [String] {
        components(separatedBy: .newlines).map(\.trimmed).filter { !$0.isEmpty }
    }
}
