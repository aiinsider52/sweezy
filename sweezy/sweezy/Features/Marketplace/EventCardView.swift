import SwiftUI

struct EventCardView: View {
    @Environment(\.locale) private var locale

    let event: EventListing

    var body: some View {
        HStack(spacing: 0) {
            cover

            VStack(alignment: .leading, spacing: 9) {
                Text(scheduleText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(JourneyVisual.lime)
                    .textCase(.uppercase)

                Text(event.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Label(locationText, systemImage: "mappin")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    organizerAvatar

                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.organizerName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.88))
                            .lineLimit(1)
                        Text("\(event.viewCount) переглядів")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.48))
                    }

                    Spacer(minLength: 4)

                    Text(priceText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(event.isFree ? .black : .white)
                        .padding(.horizontal, 9)
                        .frame(height: 27)
                        .background(event.isFree ? JourneyVisual.lime : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
        }
        .frame(minHeight: 154)
        .background(JourneyVisual.black.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
    }

    private var cover: some View {
        ZStack(alignment: .topLeading) {
            Image(eventCoverImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 116, height: 154)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.46)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Text(dayText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(monthText)
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
            }
            .foregroundColor(.black)
            .frame(width: 45, height: 48)
            .background(.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .padding(10)
        }
        .frame(width: 116, height: 154)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
    }

    private var organizerAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
            Text(String(event.organizerName.prefix(1)).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(JourneyVisual.lime)
        }
        .frame(width: 28, height: 28)
        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var startDate: Date {
        event.startsAt ?? Date()
    }

    private var dayText: String {
        startDate.formatted(.dateTime.day().locale(locale))
    }

    private var monthText: String {
        startDate.formatted(.dateTime.month(.abbreviated).locale(locale))
    }

    private var scheduleText: String {
        let day = startDate.formatted(.dateTime.weekday(.abbreviated).locale(locale))
        let time = startDate.formatted(.dateTime.hour().minute().locale(locale))
        return "\(day), \(time)"
    }

    private var locationText: String {
        if let venue = event.venueName, !venue.isEmpty {
            return "\(venue), \(event.city)"
        }
        return event.city.isEmpty ? event.canton : event.city
    }

    private var priceText: String {
        event.isFree ? "Безкоштовно" : (event.priceInfo ?? "Квиток")
    }

    private var eventCoverImageName: String {
        switch event.category {
        case .community, .career: return "cityhub-zurich-viadukt"
        case .kids, .sports: return "cityhub-zurich-lake"
        case .education, .language: return "cityhub-zurich-landesmuseum"
        case .legal, .health: return "cityhub-zurich-oldtown"
        case .culture: return "cityhub-zurich-opernhaus"
        case .other: return "cityhub-zurich-sechselaeutenplatz"
        }
    }
}
