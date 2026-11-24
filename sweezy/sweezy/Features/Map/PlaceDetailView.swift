import SwiftUI

/// Full card for a map place: real photo on top, then what it is, when it is open and how to reach it.
struct PlaceDetailView: View {
    let place: Place
    let fallbackAsset: String
    let categoryTitle: String
    let categoryIcon: String
    let locationLine: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appContainer: AppContainer

    private var description: String? {
        place.localizedDescription(for: appContainer.currentLocale)
    }

    /// Monday first, the way a Swiss or German week reads.
    private var weekHours: [OpeningHours] {
        place.openingHours.sorted { ($0.weekday + 5) % 7 < ($1.weekday + 5) % 7 }
    }

    /// Services minus the one the category badge on the photo already says.
    private var services: [String] {
        place.services.filter { $0.caseInsensitiveCompare(categoryTitle) != .orderedSame }
    }

    private var todayWeekday: Int { Calendar.current.component(.weekday, from: Date()) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                hero
                sheet.padding(.top, -24)
            }
            .padding(.bottom, 20)
        }
        .background(JourneyVisual.pageBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .topTrailing) { topControls }
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
    }

    private var hero: some View {
        PlacePhotoView(place: place, fallbackAsset: fallbackAsset)
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .overlay(alignment: .bottomLeading) {
                Label(categoryTitle, systemImage: categoryIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(JourneyVisual.lime, in: Capsule())
                    .padding(.leading, 16)
                    .padding(.bottom, 36)
            }
            .accessibilityHidden(true)
    }

    private var topControls: some View {
        HStack(spacing: 10) {
            let saved = appContainer.savedItems.isPlaceSaved(place.id)
            Button { appContainer.savedItems.togglePlace(place.id) } label: {
                circleIcon(saved ? "heart.fill" : "heart", active: saved)
            }
            .accessibilityLabel("journey.map.save_place".localized)
            Button { dismiss() } label: { circleIcon("xmark") }
                .accessibilityLabel("common.close".localized)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94, hapticStyle: .light))
        .padding(.trailing, 16)
        .padding(.top, 14)
    }

    private func circleIcon(_ name: String, active: Bool = false) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(active ? .black : JourneyVisual.primaryText)
            .frame(width: 38, height: 38)
            .background(active ? JourneyVisual.lime : Theme.Colors.card.opacity(0.94), in: Circle())
            .overlay(Circle().stroke(JourneyVisual.softBorder))
            .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(place.name)
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.3)
                    .foregroundColor(JourneyVisual.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Label(addressLine, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let description {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(JourneyVisual.primaryText.opacity(0.86))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !services.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(services, id: \.self) { service in
                        Text(service)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(JourneyVisual.primaryText)
                            .padding(.horizontal, 12).frame(height: 32)
                            .background(Theme.Colors.card, in: Capsule())
                            .overlay(Capsule().stroke(JourneyVisual.softBorder))
                    }
                }
            }

            hoursBlock

            contactBlock

            if let source = place.source, let url = URL(string: source) {
                Button { openURL(url) } label: {
                    Label("place.detail.source".localized, systemImage: "checkmark.shield")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                .fill(JourneyVisual.pageBackground)
        )
    }

    private var addressLine: String {
        let street = [place.address.street, place.address.houseNumber].filter { !$0.isEmpty }.joined(separator: " ")
        let city = [place.address.postalCode, place.address.city].filter { !$0.isEmpty }.joined(separator: " ")
        let parts = [street, city].filter { !$0.isEmpty }
        return parts.isEmpty ? locationLine : parts.joined(separator: ", ")
    }

    @ViewBuilder private var hoursBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("place.detail.hours".localized)
            if weekHours.isEmpty {
                Text("map.hours_unknown".localized)
                    .font(.system(size: 14))
                    .foregroundColor(JourneyVisual.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(weekHours, id: \.weekday) { hours in
                        let today = hours.weekday == todayWeekday
                        HStack {
                            Text(hours.weekdayName.capitalized(with: AppLanguage.current.locale))
                            Spacer()
                            Text(hours.isClosed ? "map.closed_today".localized : "\(hours.openTime.formatted) – \(hours.closeTime.formatted)")
                        }
                        .font(.system(size: 14, weight: today ? .bold : .regular))
                        .foregroundColor(today ? JourneyVisual.primaryText : JourneyVisual.secondaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(today ? JourneyVisual.lime.opacity(0.18) : .clear)
                    }
                }
                .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(JourneyVisual.softBorder))
            }
        }
    }

    @ViewBuilder private var contactBlock: some View {
        let rows = contactRows
        if !rows.isEmpty {
            VStack(spacing: 8) {
                ForEach(rows, id: \.title) { row in
                    Button { openURL(row.url) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: row.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(JourneyVisual.accentText)
                                .frame(width: 36, height: 36)
                                .background(JourneyVisual.softSurface, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(JourneyVisual.secondaryText)
                                Text(row.value)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(JourneyVisual.primaryText)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(JourneyVisual.secondaryText)
                        }
                        .padding(10)
                        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(JourneyVisual.softBorder))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
                }
            }
        }
    }

    private struct ContactRow { let icon: String; let title: String; let value: String; let url: URL }

    private var contactRows: [ContactRow] {
        var rows: [ContactRow] = []
        if let phone = place.phoneNumber, !phone.isEmpty,
           let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
            rows.append(ContactRow(icon: "phone.fill", title: "map.call".localized, value: phone, url: url))
        }
        if let website = place.website, let url = URL(string: website) {
            rows.append(ContactRow(icon: "globe", title: "map.website".localized, value: url.host() ?? website, url: url))
        }
        if let email = place.email, !email.isEmpty, let url = URL(string: "mailto:\(email)") {
            rows.append(ContactRow(icon: "envelope.fill", title: "Email", value: email, url: url))
        }
        return rows
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .tracking(1)
            .foregroundColor(JourneyVisual.secondaryText)
    }

    private var actionBar: some View {
        Button {
            let c = place.coordinate.clLocationCoordinate
            let name = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.name
            if let url = URL(string: "http://maps.apple.com/?daddr=\(c.latitude),\(c.longitude)&q=\(name)") {
                openURL(url)
            }
        } label: {
            Label("map.directions".localized, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(JourneyVisual.lime, in: Capsule())
                .shadow(color: JourneyVisual.lime.opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
    }
}
