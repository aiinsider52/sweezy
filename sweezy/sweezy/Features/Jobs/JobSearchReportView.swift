import SwiftUI
import UIKit

/// One application in the monthly job-search report: from the tracker or added by hand.
struct JobSearchEntry: Codable, Identifiable, Hashable {
    enum Method: String, Codable, CaseIterable {
        case online, email, letter, inPerson, phone

        var german: String {
            switch self {
            case .online: return "Online-Bewerbung"
            case .email: return "E-Mail"
            case .letter: return "Schriftlich (Post)"
            case .inPerson: return "Persönlich"
            case .phone: return "Telefonisch"
            }
        }

        var title: String { "career.report.method.\(rawValue)".localized }
    }

    enum Outcome: String, Codable, CaseIterable {
        case pending, interview, offer, rejected, withdrawn

        var german: String {
            switch self {
            case .pending: return "Offen"
            case .interview: return "Vorstellungsgespräch"
            case .offer: return "Zusage"
            case .rejected: return "Absage"
            case .withdrawn: return "Zurückgezogen"
            }
        }

        var title: String { "career.report.outcome.\(rawValue)".localized }
    }

    var id: String
    var date: Date
    var company: String
    var location: String
    var position: String
    var method: Method
    var workload: String
    var contact: String
    var outcome: Outcome
    /// Set for entries that come from the tracker; their date, company and status follow the tracker.
    var trackerJobID: String?
}

/// Hand-added applications and the extra details the report needs, kept on the device.
@MainActor
final class JobSearchLogStore: ObservableObject {
    static let shared = JobSearchLogStore()

    @Published private(set) var manual: [JobSearchEntry] = []
    @Published private(set) var details: [String: JobSearchEntry] = [:]
    @Published var monthlyGoal: Int {
        didSet { UserDefaults.standard.set(monthlyGoal, forKey: Self.goalKey) }
    }

    private static let goalKey = "jobs.report.monthly_goal"
    private struct Stored: Codable { var manual: [JobSearchEntry]; var details: [String: JobSearchEntry] }

    /// The job-search log names employers and outcomes, so it belongs to one account.
    private var fileURL: URL { AccountScopedStorage.fileURL(named: "job-search-log.json") }
    private var scopeObserver: NSObjectProtocol?

    private init() {
        let goal = UserDefaults.standard.integer(forKey: Self.goalKey)
        monthlyGoal = goal > 0 ? goal : 8
        reload()
        scopeObserver = NotificationCenter.default.addObserver(forName: .accountScopeDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    private func reload() {
        if let data = try? Data(contentsOf: fileURL), let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            manual = stored.manual
            details = stored.details
        } else {
            manual = []
            details = [:]
        }
    }

    func removeAll() {
        manual = []
        details = [:]
        try? FileManager.default.removeItem(at: fileURL)
    }

    func entries(in month: Date, applications: [APIClient.JobApplication]) -> [JobSearchEntry] {
        let calendar = Calendar.current
        let tracked: [JobSearchEntry] = applications.compactMap { application in
            guard let date = Self.parse(application.applied_at) else { return nil }
            var entry = details[application.job_id] ?? JobSearchEntry(
                id: "tracker.\(application.job_id)", date: date, company: application.company ?? "",
                location: application.location ?? "", position: application.job_title,
                method: .online, workload: "", contact: "", outcome: .pending, trackerJobID: application.job_id
            )
            entry.date = date
            entry.company = application.company ?? entry.company
            entry.position = application.job_title
            entry.outcome = Self.outcome(for: application.status)
            return entry
        }
        return (tracked + manual)
            .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            .sorted { $0.date < $1.date }
    }

    func save(_ entry: JobSearchEntry) {
        if let jobID = entry.trackerJobID {
            details[jobID] = entry
        } else if let index = manual.firstIndex(where: { $0.id == entry.id }) {
            manual[index] = entry
        } else {
            manual.append(entry)
        }
        persist()
    }

    func delete(_ entry: JobSearchEntry) {
        guard entry.trackerJobID == nil else { return }
        manual.removeAll { $0.id == entry.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(Stored(manual: manual, details: details)) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    static func outcome(for status: String) -> JobSearchEntry.Outcome {
        switch status {
        case "interview": return .interview
        case "offer": return .offer
        case "rejected": return .rejected
        case "withdrawn": return .withdrawn
        default: return .pending
        }
    }

    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let full = ISO8601DateFormatter()
        full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return full.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
}

/// Monthly list of applications to hand in to RAV (CH), Jobcenter/Agentur für Arbeit (DE) or AMS (AT),
/// built from the tracker plus anything added by hand, exported as a PDF in German.
struct JobSearchReportView: View {
    let applications: [APIClient.JobApplication]
    let applicantName: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = JobSearchLogStore.shared
    @State private var month = Date()
    @State private var editing: JobSearchEntry?

    private var entries: [JobSearchEntry] { store.entries(in: month, applications: applications) }
    private var country: ResidenceCountry { ResidenceCountry(rawValue: APIClient.countryCode) ?? .switzerland }

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.pageBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("career.report.title".localized)
                                .font(.system(size: 30, weight: .heavy))
                                .foregroundColor(JourneyVisual.primaryText)
                            Text("career.report.subtitle.\(country.rawValue.lowercased())".localized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(JourneyVisual.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        monthHeader
                        ForEach(entries) { entry in
                            Button { editing = entry } label: { row(entry) }
                                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
                        }
                        if entries.isEmpty {
                            CareerNotice(icon: "tray", text: "career.report.empty".localized)
                        }
                        Button { editing = newEntry() } label: {
                            Label("career.report.add".localized, systemImage: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(JourneyVisual.primaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Theme.Colors.card, in: Capsule())
                                .overlay(Capsule().stroke(JourneyVisual.softBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                        }
                        Button(action: exportPDF) {
                            Label("career.report.export".localized, systemImage: "doc.richtext.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(JourneyVisual.lime, in: Capsule())
                                .shadow(color: JourneyVisual.lime.opacity(0.4), radius: 14, y: 6)
                        }
                        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
                        .disabled(entries.isEmpty)
                        .opacity(entries.isEmpty ? 0.5 : 1)
                        Text("career.report.note.\(country.rawValue.lowercased())".localized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.close".localized) { dismiss() } }
            }
            .sheet(item: $editing) { entry in
                JobSearchEntryEditor(entry: entry, isNew: !store.manual.contains(where: { $0.id == entry.id }) && entry.trackerJobID == nil) { saved in
                    store.save(saved)
                    if saved.trackerJobID == nil && !entries.contains(where: { $0.id == saved.id }) { Celebration.fire() }
                } onDelete: { deleted in
                    store.delete(deleted)
                }
                .presentationDetents([.large])
            }
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 14) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            VStack(spacing: 2) {
                Text(month.formatted(.dateTime.month(.wide).year()).capitalized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                Text("career.report.count".localized(with: entries.count, store.monthlyGoal))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText)
            }
            .frame(maxWidth: .infinity)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
            // The ring doubles as the goal picker: everyone's required number differs.
            Menu {
                Section("career.report.goal_title".localized) {
                    ForEach([4, 6, 8, 10, 12, 15, 20], id: \.self) { goal in
                        Button { store.monthlyGoal = goal } label: {
                            if goal == store.monthlyGoal { Label("\(goal)", systemImage: "checkmark") } else { Text("\(goal)") }
                        }
                    }
                }
            } label: {
                JourneyProgressRing(done: entries.count, total: max(store.monthlyGoal, 1), size: 50, lineWidth: 6)
            }
            .accessibilityLabel("career.report.goal_title".localized)
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(JourneyVisual.primaryText)
        .padding(14)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.softBorder))
    }

    private func row(_ entry: JobSearchEntry) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(entry.date.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .heavy))
                Text(entry.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(width: 48, height: 48)
            .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.position)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .lineLimit(1)
                Text([entry.company, entry.method.title].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(entry.outcome.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(JourneyVisual.primaryText)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(JourneyVisual.softSurface, in: Capsule())
        }
        .padding(12)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JourneyVisual.softBorder))
    }

    private func shift(_ months: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            month = Calendar.current.date(byAdding: .month, value: months, to: month) ?? month
        }
    }

    private func newEntry() -> JobSearchEntry {
        let calendar = Calendar.current
        let date = calendar.isDate(month, equalTo: Date(), toGranularity: .month) ? Date() : (calendar.dateInterval(of: .month, for: month)?.start ?? Date())
        return JobSearchEntry(id: UUID().uuidString, date: date, company: "", location: "", position: "",
                              method: .online, workload: "100", contact: "", outcome: .pending, trackerJobID: nil)
    }

    private func exportPDF() {
        guard let url = try? JobSearchReportPDF.render(entries: entries, month: month, name: applicantName, country: country) else { return }
        presentShare([url])
    }
}

private struct JobSearchEntryEditor: View {
    @State var entry: JobSearchEntry
    let isNew: Bool
    let onSave: (JobSearchEntry) -> Void
    let onDelete: (JobSearchEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("career.report.field.date".localized, selection: $entry.date, displayedComponents: .date)
                    TextField("career.report.field.position".localized, text: $entry.position)
                        .disabled(entry.trackerJobID != nil)
                    TextField("career.report.field.company".localized, text: $entry.company)
                    TextField("career.report.field.location".localized, text: $entry.location)
                }
                Section {
                    Picker("career.report.field.method".localized, selection: $entry.method) {
                        ForEach(JobSearchEntry.Method.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    LabeledContent("career.report.field.workload".localized) {
                        TextField("100", text: $entry.workload)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    TextField("career.report.field.contact".localized, text: $entry.contact)
                    Picker("career.report.field.outcome".localized, selection: $entry.outcome) {
                        ForEach(JobSearchEntry.Outcome.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .disabled(entry.trackerJobID != nil)
                } footer: {
                    if entry.trackerJobID != nil { Text("career.report.from_tracker".localized) }
                }
                if !isNew && entry.trackerJobID == nil {
                    Section {
                        Button("common.delete".localized, role: .destructive) {
                            onDelete(entry)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "career.report.add".localized : entry.position)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel".localized) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save".localized) {
                        onSave(entry)
                        dismiss()
                    }
                    .disabled(entry.position.trimmingCharacters(in: .whitespaces).isEmpty || entry.company.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// A4 landscape table in German, the language the authorities work in.
enum JobSearchReportPDF {
    static func render(entries: [JobSearchEntry], month: Date, name: String, country: ResidenceCountry) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 841.8, height: 595.2)
        let margin: CGFloat = 36
        let german = Locale(identifier: "de_CH")
        let monthTitle = month.formatted(Date.FormatStyle(locale: german).month(.wide).year())
        let title: String
        switch country {
        case .germany: title = "Nachweis der Eigenbemühungen"
        case .austria: title = "Übersicht der Bewerbungsaktivitäten"
        default: title = "Übersicht der persönlichen Arbeitsbemühungen"
        }
        let columns: [(String, CGFloat)] = [
            ("Datum", 0.09), ("Arbeitgeber / Ort", 0.22), ("Stelle", 0.21), ("Art der Bewerbung", 0.13),
            ("Pensum", 0.07), ("Kontaktperson", 0.13), ("Ergebnis", 0.15),
        ]
        let tableWidth = page.width - margin * 2
        let dateFormat = Date.FormatStyle(locale: german).day(.twoDigits).month(.twoDigits).year()

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: "\(title) — \(monthTitle)", kCGPDFContextCreator as String: "Sweezy"]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Arbeitsbemuehungen_\(month.formatted(.iso8601.year().month())).pdf")

        try UIGraphicsPDFRenderer(bounds: page, format: format).writePDF(to: url) { context in
            var y: CGFloat = 0
            func newPage() {
                context.beginPage()
                y = margin
                draw(title, font: .systemFont(ofSize: 18, weight: .bold), at: CGPoint(x: margin, y: y))
                y += 26
                draw("Name: \(name.isEmpty ? "______________________" : name)      Monat: \(monthTitle)      Anzahl: \(entries.count)",
                     font: .systemFont(ofSize: 10.5), at: CGPoint(x: margin, y: y))
                y += 24
                var x = margin
                UIColor(white: 0.92, alpha: 1).setFill()
                UIRectFill(CGRect(x: margin, y: y, width: tableWidth, height: 22))
                for (label, share) in columns {
                    draw(label, font: .systemFont(ofSize: 9.5, weight: .semibold), at: CGPoint(x: x + 5, y: y + 5))
                    x += tableWidth * share
                }
                y += 22
            }
            newPage()
            for entry in entries {
                let cells = [
                    entry.date.formatted(dateFormat),
                    [entry.company, entry.location].filter { !$0.isEmpty }.joined(separator: ", "),
                    entry.position,
                    entry.method.german,
                    entry.workload.isEmpty ? "" : "\(entry.workload) %",
                    entry.contact,
                    entry.outcome.german,
                ]
                let font = UIFont.systemFont(ofSize: 9.5)
                let heights = zip(cells, columns).map { cell, column in
                    (cell as NSString).boundingRect(
                        with: CGSize(width: tableWidth * column.1 - 10, height: 200), options: .usesLineFragmentOrigin,
                        attributes: [.font: font], context: nil
                    ).height
                }
                let rowHeight = max(22, (heights.max() ?? 12) + 10)
                if y + rowHeight > page.height - margin - 30 { newPage() }
                var x = margin
                for (cell, column) in zip(cells, columns) {
                    (cell as NSString).draw(
                        in: CGRect(x: x + 5, y: y + 5, width: tableWidth * column.1 - 10, height: rowHeight - 8),
                        withAttributes: [.font: font, .foregroundColor: UIColor.black]
                    )
                    x += tableWidth * column.1
                }
                UIColor(white: 0.8, alpha: 1).setFill()
                UIRectFill(CGRect(x: margin, y: y + rowHeight - 0.5, width: tableWidth, height: 0.5))
                y += rowHeight
            }
            let footer: String
            switch country {
            case .germany: footer = "Eigene Aufstellung. Bei Bedarf in das Formular des Jobcenters bzw. der Agentur für Arbeit übertragen."
            case .austria: footer = "Eigene Aufstellung. Bei Bedarf in das eAMS-Konto bzw. das Formular des AMS übertragen."
            default: footer = "Eigene Aufstellung. Bei Bedarf in das RAV-Formular oder auf Job-Room übertragen."
            }
            draw(footer + "  Erstellt mit Sweezy.", font: .systemFont(ofSize: 8.5), at: CGPoint(x: margin, y: page.height - margin))
        }
        return url
    }

    private static func draw(_ text: String, font: UIFont, at point: CGPoint) {
        (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: UIColor.black])
    }
}
