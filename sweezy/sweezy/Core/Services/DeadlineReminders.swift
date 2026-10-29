import Foundation
import UserNotifications

/// What a date the user entered is about. Decides the icon, the wording ("expires" or just "due")
/// and where "how to renew" points.
enum DeadlineKind: String, Codable, CaseIterable, Identifiable {
    case permit, passport, insurance, tax, drivingLicense = "driving_license", other

    var id: String { rawValue }

    var title: String { "deadline.kind.\(rawValue)".localized }

    var hint: String { "deadline.hint.\(rawValue)".localized }

    var icon: String {
        switch self {
        case .permit: return "person.text.rectangle.fill"
        case .passport: return "book.closed.fill"
        case .insurance: return "cross.case.fill"
        case .tax: return "building.columns.fill"
        case .drivingLicense: return "car.fill"
        case .other: return "calendar"
        }
    }

    var swatch: JourneyCategorySwatch {
        switch self {
        case .permit: return JourneyCategoryPalette.lime
        case .passport: return JourneyCategoryPalette.sky
        case .insurance: return JourneyCategoryPalette.coral
        case .tax: return JourneyCategoryPalette.sand
        case .drivingLicense: return JourneyCategoryPalette.lilac
        case .other: return JourneyCategoryPalette.graphite
        }
    }

    /// Documents run out; a tax return or an appointment is simply due.
    var expires: Bool { self != .tax && self != .other }

    /// The readiness document that already holds this date, so the permit date lives in one place.
    var documentKey: String? {
        switch self {
        case .permit: return "permit"
        case .passport: return "passport"
        case .insurance: return "insurance"
        default: return nil
        }
    }

    func source(for country: ResidenceCountry) -> URL? {
        let raw: String
        switch (self, country) {
        case (.permit, .switzerland): raw = "https://www.sem.admin.ch/sem/en/home/themen/aufenthalt.html"
        case (.permit, .germany): raw = "https://www.germany4ukraine.de/EN/einreise-aufenthalt-und-rueckkehr/ukraine-aufenthaltserlaubnis/seite_node.html"
        case (.permit, .austria): raw = "https://www.bbu.gv.at/ukraine-info-faq-ukrainian"
        case (.passport, _): raw = "https://passport.mfa.gov.ua/en"
        case (.insurance, .switzerland): raw = "https://www.bag.admin.ch/bag/en/home/versicherungen/krankenversicherung.html"
        case (.insurance, .germany): raw = "https://www.germany4ukraine.de/EN/medizinische-versorgung/krankenversicherung-ukrainer/seite_node.html"
        case (.insurance, .austria): raw = "https://www.oesterreich.gv.at/en/themen/gesundheit_und_notfaelle.html"
        case (.tax, .switzerland): raw = "https://www.ch.ch/en/taxes-and-finances/tax-returns/"
        case (.tax, .germany): raw = "https://www.elster.de/eportal/start"
        case (.tax, .austria): raw = "https://www.oesterreich.gv.at/en/themen/steuern_und_finanzen.html"
        case (.drivingLicense, .switzerland): raw = "https://www.ch.ch/en/vehicles-and-traffic/driving-licence/"
        case (.drivingLicense, .germany): raw = "https://www.germany4ukraine.de/EN/home/home_node.html"
        case (.drivingLicense, .austria): raw = "https://www.oesterreich.gv.at/en/themen/mobilitaet/fuehrerschein.html"
        case (.other, _): return nil
        }
        return URL(string: raw)
    }
}

/// A date the user added by hand: their tax deadline, licence exchange, anything with a date.
struct PersonalDeadline: Codable, Identifiable, Hashable {
    let id: UUID
    var kind: DeadlineKind
    var customTitle: String?
    var date: Date

    var title: String {
        let custom = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return custom.isEmpty ? kind.title : custom
    }
}

/// One row on "My deadlines": a document expiry or a personal date.
struct ExpiryItem: Identifiable, Hashable {
    enum Origin: Hashable { case document(String), personal(UUID) }

    let origin: Origin
    let kind: DeadlineKind
    let title: String
    let date: Date

    var id: String {
        switch origin {
        case .document(let id): return "document.\(id)"
        case .personal(let id): return "personal.\(id.uuidString)"
        }
    }

    var daysLeft: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
    }

    var countdown: String {
        switch daysLeft {
        case ..<0: return "deadline.countdown.past".localized
        case 0: return "deadline.countdown.today".localized
        case 1: return "deadline.countdown.tomorrow".localized
        default: return "deadline.countdown.days".localized(with: "\(daysLeft)")
        }
    }
}

enum DeadlineReminderPreference {
    static let key = "deadlineRemindersEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

extension LifeAdminService {
    static let reminderLeadDays = [30, 7, 1]
    static let reminderPrefix = "life.expiry."
    /// iOS keeps at most 64 pending local notifications for the whole app; leave room for the rest.
    static let maxRemindedItems = 12

    /// Document expiries and personal dates, soonest first.
    var expiryItems: [ExpiryItem] {
        let country = reminderCountry
        let documentsWithDates: [ExpiryItem] = documents.compactMap { document in
            guard let expiry = document.expiryDate else { return nil }
            let kind = DeadlineKind.allCases.first { $0.documentKey.map(document.id.hasSuffix) ?? false } ?? .other
            let title = kind == .permit && country == .switzerland
                ? "deadline.permit_title".localized(with: reminderPermitCode)
                : document.displayTitle
            return ExpiryItem(origin: .document(document.id), kind: kind, title: title, date: expiry)
        }
        let personal = personalDeadlines.map {
            ExpiryItem(origin: .personal($0.id), kind: $0.kind, title: $0.title, date: $0.date)
        }
        return (documentsWithDates + personal).sorted { $0.date < $1.date }
    }

    /// Stores the date where it belongs: on the matching readiness document, or as a personal date.
    func saveDeadline(kind: DeadlineKind, title: String?, date: Date, editing item: ExpiryItem? = nil) {
        if case .personal(let id)? = item?.origin, kind.documentKey != nil {
            removePersonalDeadline(id)
        }
        if let key = kind.documentKey, let document = documents.first(where: { $0.id.hasSuffix(key) }) {
            if case .document(let oldID)? = item?.origin, oldID != document.id { setExpiry(nil, for: oldID) }
            setExpiry(date, for: document.id)
            if !document.isReady { toggleDocument(document.id) }
            return
        }
        if case .document(let oldID)? = item?.origin { setExpiry(nil, for: oldID) }
        if case .personal(let id)? = item?.origin, let index = personalDeadlines.firstIndex(where: { $0.id == id }) {
            personalDeadlines[index].kind = kind
            personalDeadlines[index].customTitle = title
            personalDeadlines[index].date = date
        } else {
            personalDeadlines.append(PersonalDeadline(id: UUID(), kind: kind, customTitle: title, date: date))
        }
        persistPersonalDeadlines()
    }

    func removeDeadline(_ item: ExpiryItem) {
        switch item.origin {
        case .document(let id): setExpiry(nil, for: id)
        case .personal(let id): removePersonalDeadline(id)
        }
    }

    private func removePersonalDeadline(_ id: UUID) {
        personalDeadlines.removeAll { $0.id == id }
        persistPersonalDeadlines()
    }

    /// Rebuilds the 30/7/1-day reminders from scratch, so edits and deletions never leave a stale alert.
    func syncExpiryReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.reminderPrefix) }
        )
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        guard authorized, NotificationPreference.isEnabled, DeadlineReminderPreference.isEnabled else { return }

        let now = Date()
        let calendar = Calendar.current
        for item in expiryItems.filter({ $0.date > now }).prefix(Self.maxRemindedItems) {
            for lead in Self.reminderLeadDays {
                guard let day = calendar.date(byAdding: .day, value: -lead, to: calendar.startOfDay(for: item.date)),
                      let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                      fire > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = Self.reminderTitle(for: item, lead: lead)
                content.body = item.kind.hint
                content.sound = .default
                content.userInfo = ["type": "deadline_reminder", "deadline_id": item.id]
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
                    repeats: false
                )
                let request = UNNotificationRequest(identifier: "\(Self.reminderPrefix)\(item.id).\(lead)", content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    static func reminderTitle(for item: ExpiryItem, lead: Int) -> String {
        switch (item.kind.expires, lead) {
        case (true, 1): return "deadline.push.expires_tomorrow".localized(with: item.title)
        case (true, _): return "deadline.push.expires_in".localized(with: "\(lead)", item.title)
        case (false, 1): return "deadline.push.due_tomorrow".localized(with: item.title)
        case (false, _): return "deadline.push.due_in".localized(with: "\(lead)", item.title)
        }
    }
}
