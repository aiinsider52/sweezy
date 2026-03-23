import SwiftUI

struct EventDetailView: View {
    let eventId: String
    private let initialEvent: EventListing?

    @State private var event: EventListing?
    @State private var isLoading = true
    @State private var error: Error?

    init(eventId: String, initialEvent: EventListing? = nil) {
        self.eventId = eventId
        self.initialEvent = initialEvent
        _event = State(initialValue: initialEvent)
        _isLoading = State(initialValue: initialEvent == nil)
    }

    var body: some View {
        ZStack {
            AdaptivePageBackground()

            if isLoading {
                ProgressView()
                    .tint(Theme.Colors.primary)
            } else if let event {
                detailContent(event)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("events.detail_error".localized)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .task { await loadDetail() }
        .safeAreaInset(edge: .bottom) {
            if let event, let contactValue = event.contactValue, !contactValue.isEmpty {
                bottomActionBar(event: event, contactValue: contactValue)
            }
        }
    }

    private func detailContent(_ event: EventListing) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                heroSection(event)
                infoGrid(event)
                descriptionSection(event)
                organizerSection(event)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 140)
        }
    }

    private func heroSection(_ event: EventListing) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [event.category.color.opacity(0.95), Theme.Colors.primaryDark, Theme.Colors.darkBackground],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 180, height: 180)
                .blur(radius: 10)
                .offset(x: 60, y: -40)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ListingBadgePill(text: event.category.displayName, color: .white)
                    ListingBadgePill(text: event.canton == "all" ? "events.all_switzerland".localized : event.canton, color: .white)
                }

                Text(event.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    heroMeta(icon: "calendar", text: dateText(event))
                    heroMeta(icon: "clock.fill", text: timeText(event))
                    heroMeta(icon: "mappin.circle.fill", text: fullLocationText(event))
                }
            }
            .padding(22)
        }
        .frame(minHeight: 240)
        .shadow(color: event.category.color.opacity(0.24), radius: 22, y: 12)
    }

    private func infoGrid(_ event: EventListing) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            infoCard(title: "events.city".localized, value: event.city, icon: "building.2.fill", color: .cyan)
            infoCard(title: "events.organizer".localized, value: event.organizerName, icon: "person.fill", color: event.category.color)
            infoCard(title: "events.price".localized, value: event.isFree ? "events.free".localized : (event.priceInfo ?? "—"), icon: "banknote.fill", color: Theme.Colors.primary)
            infoCard(title: "events.views".localized, value: "\(event.viewCount)", icon: "eye.fill", color: .orange)
        }
    }

    private func infoCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private func descriptionSection(_ event: EventListing) -> some View {
        sectionCard(title: "marketplace.description".localized, icon: "text.alignleft", accent: .cyan) {
            Text(event.description)
                .font(.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineSpacing(2)

            if let address = event.address, !address.isEmpty {
                Divider().padding(.vertical, 6)
                Label(address, systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    private func organizerSection(_ event: EventListing) -> some View {
        sectionCard(title: "events.organizer".localized, icon: "person.crop.circle.fill", accent: Theme.Colors.primary) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.primary.opacity(0.2), event.category.color.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Text(String(event.organizerName.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.organizerName)
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("events.organizer_hint".localized)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Spacer()
            }
        }
    }

    private func sectionCard<Content: View>(title: String, icon: String, accent: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(accent)
                Text(title)
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private func heroMeta(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.white.opacity(0.84))
    }

    private func bottomActionBar(event: EventListing, contactValue: String) -> some View {
        VStack(spacing: 10) {
            Button {
                openContact(type: event.contactType, value: contactValue)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: event.contactType.icon)
                    Text("events.contact_organizer".localized)
                        .font(.system(size: 17, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Theme.Colors.primary, Theme.Colors.primaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(18)
            }

            ShareLink(item: "\(event.title)\n\(event.description)") {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("marketplace.share".localized)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.Colors.adaptiveSurface)
                .foregroundColor(Theme.Colors.textPrimary)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Rectangle().fill(.ultraThinMaterial).ignoresSafeArea())
    }

    private func dateText(_ event: EventListing) -> String {
        guard let startsAt = event.startsAt else { return "—" }
        return startsAt.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func timeText(_ event: EventListing) -> String {
        guard let startsAt = event.startsAt else { return "—" }
        let start = startsAt.formatted(date: .omitted, time: .shortened)
        if let endsAt = event.endsAt {
            return "\(start) - \(endsAt.formatted(date: .omitted, time: .shortened))"
        }
        return start
    }

    private func fullLocationText(_ event: EventListing) -> String {
        let base = [event.venueName, event.city, event.canton].compactMap { $0 }.filter { !$0.isEmpty }
        return base.joined(separator: ", ")
    }

    private func loadDetail() async {
        if let initialEvent, initialEvent.status != .approved {
            event = initialEvent
            isLoading = false
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
            if !success, type == .telegram {
                if let webURL = URL(string: "https://t.me/\(value.hasPrefix("@") ? String(value.dropFirst()) : value)") {
                    UIApplication.shared.open(webURL)
                }
            }
        }
    }
}
