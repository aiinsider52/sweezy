import SwiftUI

/// Logo plate: uploaded logo, otherwise the business initial on its category swatch.
struct BusinessAvatar: View {
    let logoURL: String?
    let name: String
    let category: BusinessCategory
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(category.swatch.fill)
            if let url = logoURL.flatMap(APIClient.resolveMediaURL) {
                CachedAsyncImage(url: url) { monogram }
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
        .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var monogram: some View {
        Text(name.prefix(1).uppercased())
            .font(.system(size: size * 0.42, weight: .black))
            .foregroundStyle(category.swatch.ink)
    }
}

struct BusinessSponsoredBadge: View {
    var body: some View {
        Text("business.sponsored".localized)
            .font(.system(size: 10, weight: .black))
            .tracking(0.4)
            .foregroundStyle(JourneyVisual.secondaryText)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(JourneyVisual.softSurface, in: Capsule())
            .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
            .accessibilityLabel("business.sponsored.accessibility".localized)
    }
}

struct BusinessRatingLabel: View {
    let rating: Double?
    let count: Int

    var body: some View {
        if let rating, count > 0 {
            HStack(spacing: 3) {
                Image(systemName: "star.fill").foregroundStyle(JourneyCategoryPalette.sand.ink)
                Text(rating.formatted(.number.precision(.fractionLength(1))))
                    .fontWeight(.bold)
                    .foregroundStyle(JourneyVisual.primaryText)
                Text("(\(count))").foregroundStyle(JourneyVisual.secondaryText)
            }
            .font(.system(size: 12, weight: .semibold))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("business.rating.accessibility".localized(with: rating, count))
        } else {
            Text("business.rating.new".localized)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(JourneyVisual.accentText)
        }
    }
}

struct BusinessPill: View {
    let title: String
    var icon: String?
    var highlighted = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .bold)) }
            Text(title).lineLimit(1)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(highlighted ? Color.black : JourneyVisual.primaryText)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(highlighted ? JourneyVisual.lime : JourneyVisual.softSurface, in: Capsule())
    }
}

/// Directory row: logo, name, trust signals and the live offer, with an ad label when sponsored.
struct BusinessDirectoryCard: View {
    let business: BusinessSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    BusinessAvatar(logoURL: business.logoURL, name: business.displayName, category: business.businessCategory, size: 56)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(business.displayName)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(JourneyVisual.primaryText)
                                .lineLimit(1)
                            if business.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(JourneyVisual.accentStrong)
                                    .accessibilityLabel("map.verified".localized)
                            }
                            Spacer(minLength: 4)
                            if business.isSponsored { BusinessSponsoredBadge() }
                        }
                        Text(business.tagline ?? business.businessCategory.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(JourneyVisual.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 8) {
                            BusinessRatingLabel(rating: business.averageRating, count: business.reviewCount)
                            Label(business.city, systemImage: "mappin")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(JourneyVisual.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                HStack(spacing: 6) {
                    BusinessPill(title: business.businessKind.title, icon: business.businessKind.icon)
                    if business.speaksUkrainian { BusinessPill(title: "business.speaks_ukrainian".localized, icon: "bubble.left.fill") }
                    if let offer = business.topOfferLabel { BusinessPill(title: offer, icon: "tag.fill", highlighted: true) }
                    Spacer(minLength: 0)
                }
            }
            .padding(15)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(business.isSponsored ? JourneyVisual.lime.opacity(0.55) : JourneyVisual.softBorder, lineWidth: business.isSponsored ? 1.5 : 1)
            )
            .shadow(color: JourneyVisual.black.opacity(0.06), radius: 10, y: 5)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
        .accessibilityElement(children: .combine)
        .accessibilityHint("business.open_page".localized)
    }
}

/// Offer ticket used in the offers rail and on business pages.
struct BusinessOfferTicket: View {
    let offer: BusinessOffer
    var businessName: String?
    var compact = false

    var body: some View {
        HStack(spacing: 0) {
            Text(offer.discountLabel)
                .font(.system(size: compact ? 18 : 22, weight: .black))
                .foregroundStyle(.black)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(width: compact ? 78 : 92)
                .frame(maxHeight: .infinity)
                .background(JourneyVisual.lime)
            VStack(alignment: .leading, spacing: 4) {
                if let businessName {
                    Text(businessName.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .tracking(0.5)
                        .foregroundStyle(JourneyVisual.secondaryText)
                        .lineLimit(1)
                }
                Text(offer.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if let code = offer.promoCode, !code.isEmpty {
                        Text(code)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(JourneyVisual.primaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(style: StrokeStyle(lineWidth: 1, dash: [3])))
                    }
                    if let endsAt = offer.endsAt {
                        Text("business.offer.until".localized(with: endsAt.formatted(date: .abbreviated, time: .omitted)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(JourneyVisual.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Spacer(minLength: 0)
        }
        .frame(height: compact ? 92 : 104)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct BusinessStarPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { value in
                Button { rating = value } label: {
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(value <= rating ? JourneyCategoryPalette.sand.ink : JourneyVisual.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.9, hapticStyle: .light))
                .accessibilityLabel("business.review.stars".localized(with: value))
                .accessibilityAddTraits(value == rating ? .isSelected : [])
            }
        }
    }
}

struct BusinessSectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(JourneyVisual.primaryText)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(JourneyVisual.secondaryText)
            }
        }
    }
}

extension View {
    func businessCard(stroke: Color = JourneyVisual.softBorder) -> some View {
        background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(stroke, lineWidth: 1))
    }
}
