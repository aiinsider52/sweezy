import SwiftUI

struct EventCardView: View {
    let event: EventListing

    private var urgencyBadge: (text: String, color: Color)? {
        guard let date = event.startsAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .init(), to: date).day ?? 999
        if days == 0 { return ("Сьогодні", Theme.Colors.accent) }
        if days == 1 { return ("Завтра", .orange) }
        if days <= 3 { return ("Через \(days) дні", .purple) }
        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: colored date block
            VStack(spacing: 4) {
                Text(dayText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(monthText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.82))
                    .textCase(.uppercase)
            }
            .frame(width: 62)
            .frame(maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [event.category.color, event.category.color.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Right: content
            VStack(alignment: .leading, spacing: 10) {
                // Title + urgency
                VStack(alignment: .leading, spacing: 5) {
                    if let badge = urgencyBadge {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(badge.color)
                                .frame(width: 6, height: 6)
                            Text(badge.text)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(badge.color)
                        }
                    }

                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 5) {
                        ListingBadgePill(text: event.category.displayName, color: event.category.color)
                        ListingBadgePill(text: event.canton == "all" ? "🇨🇭" : event.canton, color: .orange)
                    }
                }

                // Meta
                VStack(alignment: .leading, spacing: 5) {
                    EventMetaRow(icon: "clock.fill", text: timeRangeText)
                    EventMetaRow(icon: "mappin.circle.fill", text: locationText)
                }

                // Price row
                HStack {
                    if event.isFree {
                        HStack(spacing: 4) {
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 11))
                            Text("events.free".localized)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.Colors.primary.opacity(0.1)))
                    } else if let price = event.priceInfo, !price.isEmpty {
                        Text(price)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }

                    Spacer()

                    Label("\(event.viewCount)", systemImage: "eye.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .padding(14)
        }
        .background(Theme.Colors.adaptiveCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(event.category.color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: event.category.color.opacity(0.1), radius: 10, y: 4)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
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
