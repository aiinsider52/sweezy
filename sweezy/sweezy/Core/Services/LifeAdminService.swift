import Foundation
import Combine

enum LifeDeadlineCategory: String, Codable, CaseIterable {
    case permit
    case insurance
    case tax
    case registration
    case document
    case appointment
    case personal

    var icon: String {
        switch self {
        case .permit: return "person.text.rectangle"
        case .insurance: return "cross.case.fill"
        case .tax: return "building.columns.fill"
        case .registration: return "house.and.flag.fill"
        case .document: return "doc.text.fill"
        case .appointment: return "calendar.badge.clock"
        case .personal: return "checkmark.circle.fill"
        }
    }
}

struct LifeDeadline: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let dueDate: Date
    let category: LifeDeadlineCategory
    let sourceTitle: String
    let sourceURL: URL?
    let isCompleted: Bool

    var daysRemaining: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: dueDate)
        ).day ?? 0
    }

    var urgency: DeadlineUrgency {
        switch daysRemaining {
        case ..<0: return .overdue
        case 0...7: return .urgent
        case 8...30: return .soon
        default: return .later
        }
    }
}

enum DeadlineUrgency: String {
    case overdue
    case urgent
    case soon
    case later
}

enum ReadinessDocumentCategory: String, Codable, CaseIterable {
    case identity
    case residence
    case health
    case work
    case housing
    case family

    var icon: String {
        switch self {
        case .identity: return "person.text.rectangle"
        case .residence: return "building.columns"
        case .health: return "cross.case"
        case .work: return "briefcase"
        case .housing: return "house"
        case .family: return "person.3"
        }
    }
}

struct ReadinessDocument: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: ReadinessDocumentCategory
    let requiredFor: String
    let sourceTitle: String
    let sourceURLString: String
    var isReady: Bool
    var expiryDate: Date?

    var sourceURL: URL? { URL(string: sourceURLString) }

    var status: ReadinessDocumentStatus {
        guard isReady else { return .missing }
        guard let expiryDate else { return .ready }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
        if days < 0 { return .expired }
        if days <= 90 { return .expiring }
        return .ready
    }
}

enum ReadinessDocumentStatus: String {
    case missing
    case ready
    case expiring
    case expired
}

struct WeeklyDigestSnapshot {
    let urgentDeadlines: [LifeDeadline]
    let nextActions: [LifeDeadline]
    let missingDocuments: [ReadinessDocument]
    let upcomingAppointments: [Appointment]

    var summary: String {
        let urgent = urgentDeadlines.count
        let documents = missingDocuments.count
        let appointments = upcomingAppointments.count
        return "Термінові: \(urgent) · Документи: \(documents) · Зустрічі: \(appointments)"
    }
}

@MainActor
final class LifeAdminService: ObservableObject {
    @Published private(set) var documents: [ReadinessDocument] = []
    @Published private(set) var completedDeadlineIDs: Set<String> = []

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
        NotificationCenter.default.publisher(for: .accountScopeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }

    func prepareDocuments(for profile: UserProfile?) {
        let required = Self.defaultDocuments(for: profile)
        let existing = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
        documents = required.map { template in
            guard let saved = existing[template.id] else { return template }
            var merged = template
            merged.isReady = saved.isReady
            merged.expiryDate = saved.expiryDate
            return merged
        }
        persistDocuments()
    }

    func toggleDocument(_ id: String) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[index].isReady.toggle()
        persistDocuments()
    }

    func setExpiry(_ date: Date?, for id: String) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[index].expiryDate = date
        persistDocuments()
    }

    func setDeadlineCompleted(_ id: String, completed: Bool) {
        if completed { completedDeadlineIDs.insert(id) } else { completedDeadlineIDs.remove(id) }
        defaults.set(Array(completedDeadlineIDs), forKey: completedKey)
    }

    static func firstWeekTaskID(from deadlineID: String) -> UUID? {
        guard deadlineID.hasPrefix("task.") else { return nil }
        return UUID(uuidString: String(deadlineID.dropFirst("task.".count)))
    }

    func deadlines(
        profile: UserProfile?,
        firstWeekTasks: [FirstWeekChecklistService.TaskItem],
        moments: [SwissMoment] = [],
        appointments: [Appointment] = []
    ) -> [LifeDeadline] {
        var result: [LifeDeadline] = []
        let calendar = Calendar.current
        let arrival = profile?.arrivalDate ?? Date()

        func add(
            id: String,
            title: String,
            detail: String,
            date: Date?,
            category: LifeDeadlineCategory,
            sourceTitle: String,
            sourceURL: String
        ) {
            guard let date else { return }
            result.append(
                LifeDeadline(
                    id: id,
                    title: title,
                    detail: detail,
                    dueDate: date,
                    category: category,
                    sourceTitle: sourceTitle,
                    sourceURL: URL(string: sourceURL),
                    isCompleted: completedDeadlineIDs.contains(id)
                )
            )
        }

        add(
            id: "registration.municipality",
            title: "Реєстрація у громаді",
            detail: "Перевір термін реєстрації у своєму кантоні та громаді.",
            date: calendar.date(byAdding: .day, value: 14, to: arrival),
            category: .registration,
            sourceTitle: "ch.ch",
            sourceURL: "https://www.ch.ch/en/foreign-nationals-in-switzerland/entry-and-stay-in-switzerland/"
        )
        add(
            id: "insurance.health",
            title: "Оформити медичне страхування",
            detail: "Базове страхування потрібно оформити протягом трьох місяців після переїзду.",
            date: calendar.date(byAdding: .month, value: 3, to: arrival),
            category: .insurance,
            sourceTitle: "Federal Office of Public Health",
            sourceURL: "https://www.bag.admin.ch/bag/en/home/versicherungen/krankenversicherung.html"
        )
        if let expiry = profile?.permitExpiryDate {
            add(
                id: "permit.renewal",
                title: "Почати продовження permit",
                detail: "Підготуй пакет документів завчасно. Точний строк залежить від кантону.",
                date: calendar.date(byAdding: .day, value: -90, to: expiry),
                category: .permit,
                sourceTitle: "State Secretariat for Migration",
                sourceURL: "https://www.sem.admin.ch/sem/en/home/themen/aufenthalt.html"
            )
        }

        let year = calendar.component(.year, from: Date())
        var taxComponents = DateComponents()
        taxComponents.year = year
        taxComponents.month = 3
        taxComponents.day = 31
        var taxDate = calendar.date(from: taxComponents)
        if let date = taxDate, date < Date() {
            taxComponents.year = year + 1
            taxDate = calendar.date(from: taxComponents)
        }
        add(
            id: "tax.declaration.\(taxComponents.year ?? year)",
            title: "Перевірити податкову декларацію",
            detail: "Кантональні строки різняться. Перевір особистий лист або портал кантону.",
            date: taxDate,
            category: .tax,
            sourceTitle: "Federal Tax Administration",
            sourceURL: "https://www.estv.admin.ch/estv/en/home.html"
        )

        for task in firstWeekTasks {
            let deadlineID = "task.\(task.id.uuidString)"
            result.append(
                LifeDeadline(
                    id: deadlineID,
                    title: task.title,
                    detail: task.details ?? "Наступний крок персонального плану.",
                    dueDate: task.dueDate,
                    category: .personal,
                    sourceTitle: "Sweezy My Plan",
                    sourceURL: nil,
                    isCompleted: task.isDone || completedDeadlineIDs.contains(deadlineID)
                )
            )
        }

        for moment in moments {
            add(
                id: "moment.\(moment.id)",
                title: moment.title,
                detail: moment.descriptionMd.split(separator: "\n").first.map(String.init) ?? "",
                date: moment.endsAt,
                category: .personal,
                sourceTitle: "Sweezy verified moment",
                sourceURL: "https://www.ch.ch/en/"
            )
        }

        for appointment in appointments where !appointment.isPast && appointment.status != .cancelled {
            result.append(
                LifeDeadline(
                    id: "appointment.\(appointment.id.uuidString)",
                    title: appointment.title,
                    detail: appointment.description ?? appointment.category.localizedName,
                    dueDate: appointment.dateTime,
                    category: .appointment,
                    sourceTitle: "Мої зустрічі",
                    sourceURL: nil,
                    isCompleted: appointment.status == .completed
                )
            )
        }

        for document in documents where document.isReady {
            guard let expiry = document.expiryDate else { continue }
            add(
                id: "document.\(document.id)",
                title: "Оновити: \(document.title)",
                detail: document.requiredFor,
                date: calendar.date(byAdding: .day, value: -30, to: expiry),
                category: .document,
                sourceTitle: document.sourceTitle,
                sourceURL: document.sourceURLString
            )
        }

        return result
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func scheduleReminders(
        for deadlines: [LifeDeadline],
        using notificationService: any NotificationServiceProtocol
    ) async -> Int {
        if notificationService.authorizationStatus == .notDetermined {
            _ = await notificationService.requestPermission()
        }
        guard notificationService.isAuthorized else { return 0 }
        var count = 0
        for deadline in deadlines.prefix(20) {
            let leadDays = deadline.urgency == .urgent ? 1 : 7
            guard let fireDate = Calendar.current.date(byAdding: .day, value: -leadDays, to: deadline.dueDate) else { continue }
            let didSchedule = await notificationService.scheduleReminder(
                id: "life.deadline.\(deadline.id)",
                title: deadline.title,
                body: deadline.detail,
                at: fireDate
            )
            if didSchedule { count += 1 }
        }
        return count
    }

    func makeDigest(deadlines: [LifeDeadline], appointments: [Appointment]) -> WeeklyDigestSnapshot {
        WeeklyDigestSnapshot(
            urgentDeadlines: deadlines.filter { $0.urgency == .overdue || $0.urgency == .urgent },
            nextActions: Array(deadlines.prefix(5)),
            missingDocuments: documents.filter { $0.status == .missing || $0.status == .expired },
            upcomingAppointments: appointments.filter { !$0.isPast }.prefix(5).map { $0 }
        )
    }

    func scheduleWeeklyDigest(
        _ digest: WeeklyDigestSnapshot,
        using notificationService: any NotificationServiceProtocol
    ) async -> Bool {
        if notificationService.authorizationStatus == .notDetermined {
            _ = await notificationService.requestPermission()
        }
        guard notificationService.isAuthorized else { return false }
        return await notificationService.scheduleWeeklyReminder(
            id: "life.weekly.digest",
            title: "Твій тиждень у Швейцарії",
            body: digest.summary,
            weekday: 2,
            hour: 9
        )
    }

    private var documentsKey: String { AccountScopedStorage.namespaced("life.documents.v1") }
    private var completedKey: String { AccountScopedStorage.namespaced("life.deadlines.completed.v1") }

    private func reload() {
        if let data = defaults.data(forKey: documentsKey),
           let decoded = try? JSONDecoder().decode([ReadinessDocument].self, from: data) {
            documents = decoded
        } else {
            documents = []
        }
        completedDeadlineIDs = Set(defaults.stringArray(forKey: completedKey) ?? [])
    }

    private func persistDocuments() {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        defaults.set(data, forKey: documentsKey)
    }

    private static func defaultDocuments(for profile: UserProfile?) -> [ReadinessDocument] {
        var result: [ReadinessDocument] = [
            ReadinessDocument(id: "passport", title: "Паспорт", category: .identity, requiredFor: "Ідентифікація, permit, банк", sourceTitle: "ch.ch", sourceURLString: "https://www.ch.ch/en/documents-and-register-extracts/", isReady: false, expiryDate: nil),
            ReadinessDocument(id: "permit", title: "Дозвіл на проживання", category: .residence, requiredFor: "Проживання та працевлаштування", sourceTitle: "SEM", sourceURLString: "https://www.sem.admin.ch/sem/en/home/themen/aufenthalt.html", isReady: false, expiryDate: profile?.permitExpiryDate),
            ReadinessDocument(id: "insurance", title: "Поліс медичного страхування", category: .health, requiredFor: "Медична допомога та реєстрація", sourceTitle: "FOPH", sourceURLString: "https://www.bag.admin.ch/bag/en/home/versicherungen/krankenversicherung.html", isReady: false, expiryDate: nil),
            ReadinessDocument(id: "municipality", title: "Підтвердження реєстрації", category: .residence, requiredFor: "Банк, житло, офіційні процедури", sourceTitle: "ch.ch", sourceURLString: "https://www.ch.ch/en/foreign-nationals-in-switzerland/entry-and-stay-in-switzerland/", isReady: false, expiryDate: nil),
            ReadinessDocument(id: "employment", title: "Трудовий договір", category: .work, requiredFor: "Робота, житло, деякі permit-процедури", sourceTitle: "SECO", sourceURLString: "https://www.seco.admin.ch/seco/en/home/Arbeit/Arbeitsbedingungen.html", isReady: false, expiryDate: nil),
            ReadinessDocument(id: "rental", title: "Договір оренди", category: .housing, requiredFor: "Адреса та реєстрація", sourceTitle: "ch.ch", sourceURLString: "https://www.ch.ch/en/housing/rent/", isReady: false, expiryDate: nil)
        ]
        if profile?.hasChildren == true {
            result.append(ReadinessDocument(id: "children.school", title: "Документи дитини для школи", category: .family, requiredFor: "Запис до школи", sourceTitle: "ch.ch", sourceURLString: "https://www.ch.ch/en/school-and-education/", isReady: false, expiryDate: nil))
        }
        return result
    }
}
