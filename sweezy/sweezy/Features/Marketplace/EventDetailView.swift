import SwiftUI

struct EventDetailView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let eventId: String
    private let initialEvent: EventListing?

    @State private var event: EventListing?
    @State private var isLoading = true
    @State private var error: Error?
    @StateObject private var calendarService = EventCalendarService()
    @State private var actionMessage: String?

    init(eventId: String, initialEvent: EventListing? = nil) {
        self.eventId = eventId
        self.initialEvent = initialEvent
        _event = State(initialValue: initialEvent)
        _isLoading = State(initialValue: initialEvent == nil)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            JourneyVisual.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(JourneyVisual.lime)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let event {
                detailContent(event)
            } else {
                errorState
            }

            closeButton
        }
        .interactiveSwipeBackEnabled()
        .task { await loadDetail() }
        .safeAreaInset(edge: .bottom) {
            if let event {
                bottomActionBar(event: event)
            }
        }
    }

    private func detailContent(_ event: EventListing) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroSection(event)

                VStack(alignment: .leading, spacing: 14) {
                    scheduleCard(event)
                    eventActionsCard(event)
                    organizerCard(event)
                    descriptionCard(event)
                    locationCard(event)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 42)
            }
        }
    }

    private func eventActionsCard(_ event: EventListing) -> some View {
        JourneyGlassPanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    eventAction(
                        title: appContainer.savedItems.isEventSaved(event.id) ? "journey.event.saved".localized : "common.save".localized,
                        icon: appContainer.savedItems.isEventSaved(event.id) ? "heart.fill" : "heart"
                    ) {
                        appContainer.savedItems.toggleEvent(event.id)
                        actionMessage = appContainer.savedItems.isEventSaved(event.id) ? "journey.event.saved_message".localized : "journey.event.removed_message".localized
                    }
                    eventAction(title: "journey.marketplace.calendar".localized, icon: "calendar.badge.plus") {
                        Task { @MainActor in
                            do {
                                try await calendarService.add(event)
                                actionMessage = "journey.event.added_to_calendar".localized
                            } catch {
                                actionMessage = error.localizedDescription
                            }
                        }
                    }
                    eventAction(title: "journey.event.remind_me".localized, icon: "bell.badge") {
                        scheduleEventReminder(event)
                    }
                }
                if let actionMessage {
                    Text(actionMessage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(JourneyVisual.lime)
                }
            }
            .padding(13)
        }
    }

    private func eventAction(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(Color.black.opacity(0.24))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func heroSection(_ event: EventListing) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(eventCoverImageName(event))
                .resizable()
                .scaledToFill()
                .frame(height: 344)
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.08), .black.opacity(0.18), JourneyVisual.black],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text(event.category.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())

                    if !event.city.isEmpty {
                        Label(event.city, systemImage: "mappin")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }

                Text(event.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Label(priceText(event), systemImage: "ticket")
                    Circle()
                        .fill(Color.white.opacity(0.34))
                        .frame(width: 3, height: 3)
                    Label("journey.event.views_count".localized(with: event.viewCount), systemImage: "person.2")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.68))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .frame(height: 344)
    }

    private func scheduleCard(_ event: EventListing) -> some View {
        JourneyGlassPanel(cornerRadius: 24) {
            HStack(spacing: 15) {
                VStack(spacing: 1) {
                    Text(monthText(event))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black.opacity(0.64))
                        .textCase(.uppercase)
                    Text(dayText(event))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                }
                .frame(width: 58, height: 64)
                .background(JourneyVisual.lime)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(dateText(event))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Label(timeText(event), systemImage: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.62))
                    Label(fullLocationText(event), systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(15)
        }
    }

    private func organizerCard(_ event: EventListing) -> some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                Text(String(event.organizerName.prefix(1)).uppercased())
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(JourneyVisual.lime)
            }
            .frame(width: 50, height: 50)
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text("journey.event.organizer".localized)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.46))
                    .textCase(.uppercase)
                Text(event.organizerName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 19))
                .foregroundColor(JourneyVisual.lime)
        }
        .padding(15)
        .background(Color.white.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func descriptionCard(_ event: EventListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("journey.event.about".localized)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(event.description)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.72))
                .lineSpacing(4)
        }
        .padding(.vertical, 8)
    }

    private func locationCard(_ event: EventListing) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("journey.event.location".localized)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(JourneyVisual.lime)
                        .textCase(.uppercase)
                    Text(locationTitle(event))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                Image(systemName: "map.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.5))
            }

            if let address = event.address, !address.isEmpty {
                Text(address)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
            }
        }
        .padding(16)
        .background(
            Image("cityhub-zurich-limmat")
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.68))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func bottomActionBar(event: EventListing) -> some View {
        HStack(spacing: 10) {
            if let contactValue = event.contactValue, !contactValue.isEmpty {
                Button {
                    openContact(type: event.contactType, value: contactValue)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: event.contactType.icon)
                        Text("journey.event.register".localized)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            ShareLink(item: "\(event.title)\n\(event.description)") {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 54, height: 54)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color.black.opacity(0.58))
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial.opacity(0.88))
                .background(Color.black.opacity(0.22))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.trailing, 16)
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(JourneyVisual.lime)
            Text("events.detail_error".localized)
                .foregroundColor(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dayText(_ event: EventListing) -> String {
        event.startsAt?.formatted(.dateTime.day().locale(locale)) ?? "—"
    }

    private func monthText(_ event: EventListing) -> String {
        event.startsAt?.formatted(.dateTime.month(.abbreviated).locale(locale)) ?? ""
    }

    private func dateText(_ event: EventListing) -> String {
        event.startsAt?.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale)) ?? "journey.event.date_tbd".localized
    }

    private func timeText(_ event: EventListing) -> String {
        guard let startsAt = event.startsAt else { return "journey.event.time_tbd".localized }
        let start = startsAt.formatted(.dateTime.hour().minute().locale(locale))
        if let endsAt = event.endsAt {
            return "\(start) — \(endsAt.formatted(.dateTime.hour().minute().locale(locale)))"
        }
        return start
    }

    private func fullLocationText(_ event: EventListing) -> String {
        let values = [event.venueName, event.city, event.canton]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return values.isEmpty ? "journey.event.location_tbd".localized : values.joined(separator: ", ")
    }

    private func locationTitle(_ event: EventListing) -> String {
        if let venueName = event.venueName, !venueName.isEmpty {
            return venueName
        }
        return event.city.isEmpty ? event.canton : event.city
    }

    private func priceText(_ event: EventListing) -> String {
        event.isFree ? "journey.marketplace.free".localized : (event.priceInfo ?? "journey.event.ticket".localized)
    }

    private func eventCoverImageName(_ event: EventListing) -> String {
        switch event.category {
        case .community, .career: return "cityhub-zurich-viadukt"
        case .kids, .sports: return "cityhub-zurich-lake"
        case .education, .language: return "cityhub-zurich-landesmuseum"
        case .legal, .health: return "cityhub-zurich-oldtown"
        case .culture: return "cityhub-zurich-opernhaus"
        case .other: return "cityhub-zurich-sechselaeutenplatz"
        }
    }

    private func loadDetail() async {
        if let initialEvent {
            event = initialEvent
            isLoading = false
            guard initialEvent.status == .approved else { return }
            do {
                event = try await APIClient.fetchEventDetail(id: eventId)
            } catch {
                self.error = error
            }
            return
        }
        isLoading = true
        do {
            event = try await APIClient.fetchEventDetail(id: eventId)
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func openContact(type: ContactType, value: String) {
        let urlString: String
        switch type {
        case .telegram:
            let username = value.hasPrefix("@") ? String(value.dropFirst()) : value
            urlString = "tg://resolve?domain=\(username)"
        case .whatsapp:
            let cleaned = value.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
            urlString = "https://wa.me/\(cleaned)"
        case .email:
            urlString = "mailto:\(value)"
        case .phone:
            let cleaned = value.replacingOccurrences(of: " ", with: "")
            urlString = "tel:\(cleaned)"
        }

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url) { success in
            if !success, type == .telegram,
               let webURL = URL(string: "https://t.me/\(value.hasPrefix("@") ? String(value.dropFirst()) : value)") {
                UIApplication.shared.open(webURL)
            }
        }
    }

    private func scheduleEventReminder(_ event: EventListing) {
        guard let startsAt = event.startsAt,
              let fireDate = Calendar.current.date(byAdding: .day, value: -1, to: startsAt) else {
            actionMessage = "journey.event.date_missing".localized
            return
        }
        Task { @MainActor in
            if appContainer.notificationService.authorizationStatus == .notDetermined {
                _ = await appContainer.notificationService.requestPermission()
            }
            let success = await appContainer.notificationService.scheduleReminder(
                id: "event.\(event.id)",
                title: event.title,
                body: "journey.event.reminder_body_format".localized(with: fullLocationText(event)),
                at: fireDate
            )
            if success {
                if !appContainer.savedItems.isEventSaved(event.id) { appContainer.savedItems.toggleEvent(event.id) }
                actionMessage = "moments.reminder.scheduled".localized
            } else {
                actionMessage = "journey.event.reminder_failed".localized
            }
        }
    }
}
