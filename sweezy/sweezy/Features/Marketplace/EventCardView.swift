import SwiftUI

struct EventCardView: View {
    let event: EventListing

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 4) {
                    Text(dayText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(monthText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.82))
                        .textCase(.uppercase)
                }
                .frame(width: 58, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [event.category.color, event.category.color.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        ListingBadgePill(text: event.category.displayName, color: event.category.color)
                        ListingBadgePill(text: event.canton == "all" ? "🇨🇭" : event.canton, color: .orange)
                    }
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                EventMetaRow(icon: "clock.fill", text: timeRangeText)
                EventMetaRow(icon: "mappin.circle.fill", text: locationText)
                EventMetaRow(icon: "person.crop.circle.fill", text: event.organizerName)
            }

            HStack {
                if event.isFree {
                    Label("events.free".localized, systemImage: "ticket.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.primary)
                } else if let price = event.priceInfo, !price.isEmpty {
                    Label(price, systemImage: "banknote.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.primary)
                }

                Spacer()

                Label("\(event.viewCount)", systemImage: "eye.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private var startDate: Date {
        event.startsAt ?? Date()
    }

    private var dayText: String {
        startDate.formatted(.dateTime.day())
    }

    private var monthText: String {
        startDate.formatted(.dateTime.month(.abbreviated))
    }

    private var timeRangeText: String {
        let start = startDate.formatted(date: .omitted, time: .shortened)
        if let end = event.endsAt {
            return "\(start) - \(end.formatted(date: .omitted, time: .shortened))"
        }
        return start
    }

    private var locationText: String {
        if let venue = event.venueName, !venue.isEmpty {
            return "\(venue), \(event.city)"
        }
        return "\(event.city), \(event.canton)"
    }
}

private struct EventMetaRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.Colors.textTertiary)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(1)
        }
    }
}
