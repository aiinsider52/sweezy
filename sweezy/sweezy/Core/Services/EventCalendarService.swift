import EventKit
import Foundation

@MainActor
final class EventCalendarService: ObservableObject {
    enum CalendarError: LocalizedError {
        case missingDate
        case denied
        case noCalendar

        var errorDescription: String? {
            switch self {
            case .missingDate: return "Дата події не вказана"
            case .denied: return "Доступ до календаря не надано"
            case .noCalendar: return "Календар недоступний"
            }
        }
    }

    private let store = EKEventStore()

    func add(_ event: EventListing) async throws {
        guard let startsAt = event.startsAt else { throw CalendarError.missingDate }
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw CalendarError.denied }
        guard let calendar = store.defaultCalendarForNewEvents else { throw CalendarError.noCalendar }

        let calendarEvent = EKEvent(eventStore: store)
        calendarEvent.title = event.title
        calendarEvent.startDate = startsAt
        calendarEvent.endDate = event.endsAt ?? startsAt.addingTimeInterval(60 * 60)
        calendarEvent.location = [event.venueName, event.address, event.city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        calendarEvent.notes = event.description
        calendarEvent.calendar = calendar
        calendarEvent.addAlarm(EKAlarm(relativeOffset: -60 * 60))
        try store.save(calendarEvent, span: .thisEvent)
    }
}
