import SwiftUI

// MARK: - Hero Listing Card (first item)

struct HeroListingCardView: View {
    let listing: ServiceListing

    private var isNew: Bool {
        guard let date = listing.createdAt else { return false }
        return Date().timeIntervalSince(date) < 86_400
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover area
            ZStack(alignment: .bottomLeading) {
                if !listing.resolvedImageURLs.isEmpty {
                    MarketplaceRemoteImageView(url: listing.primaryImageURL, height: 200, cornerRadius: 0)

                    // Bottom-only scrim for text legibility
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                } else {
                    // Calm pastel cover with a large translucent category icon
                    ZStack {
                        Rectangle()
                            .fill(listing.categoryColor.opacity(0.12))
                        Image(systemName: listing.categoryIcon)
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(listing.categoryColor.opacity(0.40))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                            .padding(.trailing, 28)
                    }
                    .frame(height: 200)
                }

                let hasPhoto = !listing.resolvedImageURLs.isEmpty
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            HeroCoverBadge(text: listing.categoryDisplayName, onPhoto: hasPhoto)
                            ForEach(Array(listing.trustBadges.enumerated()), id: \.offset) { _, badge in
                                HeroCoverBadge(text: badge.text, onPhoto: hasPhoto)
                            }
                            if isNew {
                                HeroCoverBadge(text: "Нове", onPhoto: hasPhoto)
                            }
                        }
                        Text(listing.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(hasPhoto ? .white : Theme.Colors.textPrimary)
                            .lineLimit(2)
                    }
                    Spacer()
                    if let price = listing.priceDisplay, !price.isEmpty {
                        Text(price)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(Theme.Colors.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(.white))
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                    }
                }
                .padding(16)
            }

            // Bottom meta strip
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(listing.categoryColor.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: listing.categoryIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(listing.categoryColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(listing.authorName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        if listing.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                    Text(listing.canton == "all" ? "Вся Швейцарія" : listing.canton)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()

                Label("\(listing.viewCount)", systemImage: "eye.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(.ultraThinMaterial.opacity(0.78))
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 16, y: 7)
    }
}

/// Small badge for hero covers: white pill on photos, tinted pill on pastel covers.
private struct HeroCoverBadge: View {
    let text: String
    let onPhoto: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(onPhoto ? Theme.Colors.ink : Theme.Colors.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(onPhoto ? Color.white.opacity(0.92) : Theme.Colors.paperCard)
            )
            .overlay(
                Capsule().stroke(Theme.Colors.adaptiveBorder.opacity(onPhoto ? 0 : 1), lineWidth: 1)
            )
    }
}

// MARK: - Compact Grid Card (no photo)

struct CompactListingCardView: View {
    let listing: ServiceListing

    private var isNew: Bool {
        guard let date = listing.createdAt else { return false }
        return Date().timeIntervalSince(date) < 86_400
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Calm pastel header with a large translucent category icon
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(listing.categoryColor.opacity(0.12))
                    .frame(height: 76)

                Image(systemName: listing.categoryIcon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(listing.categoryColor.opacity(0.50))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isNew {
                    Text("Нове")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.Colors.primary.opacity(0.14)))
                        .padding(8)
                }
            }
            .frame(height: 76)

            VStack(alignment: .leading, spacing: 5) {
                Text(listing.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)

                ForEach(Array(listing.trustBadges.prefix(1).enumerated()), id: \.offset) { _, badge in
                    ListingBadgePill(text: badge.text, color: badge.color)
                }

                if let price = listing.priceDisplay, !price.isEmpty {
                    Text(price)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Theme.Colors.primary)
                } else {
                    Text(listing.categoryDisplayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(listing.categoryColor.opacity(0.85))
                }

                HStack(spacing: 3) {
                    Image(systemName: "mappin")
                        .font(.system(size: 9))
                    Text(listing.canton == "all" ? "CH" : listing.canton)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial.opacity(0.78))
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.26), radius: 14, y: 6)
    }
}

// MARK: - Standard Listing Card

struct ListingCardView: View {
    let listing: ServiceListing

    private var isNew: Bool {
        guard let date = listing.createdAt else { return false }
        return Date().timeIntervalSince(date) < 86_400
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image or colored header stripe
            if !listing.resolvedImageURLs.isEmpty {
                MarketplaceRemoteImageView(url: listing.primaryImageURL, height: 168, cornerRadius: 0)
                    .clipShape(
                        MarketplaceRoundedCornerShape(corners: [.topLeft, .topRight], radius: 16)
                    )
            } else {
                Rectangle()
                    .fill(listing.categoryColor.opacity(0.30))
                    .frame(height: 4)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(listing.categoryColor.opacity(0.14))
                            .frame(width: 42, height: 42)
                        Image(systemName: listing.categoryIcon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(listing.categoryColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(listing.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)

                        HStack(spacing: 5) {
                            ForEach(Array(listing.trustBadges.enumerated()), id: \.offset) { _, badge in
                                ListingBadgePill(text: badge.text, color: badge.color)
                            }
                            ListingBadgePill(text: listing.categoryDisplayName, color: listing.categoryColor)
                            ListingBadgePill(text: listing.canton == "all" ? "🇨🇭" : listing.canton, color: .orange)
                            if isNew {
                                ListingBadgePill(text: "Нове", color: .green)
                            }
                        }
                    }
                    Spacer()
                }

                HStack {
                    if let price = listing.priceDisplay, !price.isEmpty {
                        Text(price)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Label("\(listing.viewCount)", systemImage: "eye.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textTertiary)
                        Text(listing.authorName)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                if let date = listing.createdAt {
                    Text(date, style: .relative)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .padding(14)
        }
        .background(.ultraThinMaterial.opacity(0.78))
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.26), radius: 14, y: 6)
    }
}

// MARK: - Rounded corner helper

private struct MarketplaceRoundedCornerShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Badge Pill

struct ListingBadgePill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 0.5))
            )
    }
}

// MARK: - Skeleton Card

struct ListingSkeletonCard: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Colors.adaptiveSurface)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.adaptiveSurface)
                        .frame(height: 14)
                        .frame(maxWidth: 200)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.adaptiveSurface)
                        .frame(height: 10)
                        .frame(maxWidth: 120)
                }
                Spacer()
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.Colors.adaptiveSurface)
                .frame(height: 10)
                .frame(maxWidth: 160)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
        )
        .opacity(shimmer ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: shimmer)
        .onAppear { shimmer = true }
    }
}

struct MarketplaceListingImageCarousel: View {
    let urls: [URL]
    var height: CGFloat
    var cornerRadius: CGFloat = 20

    @State private var selectedIndex = 0

    var body: some View {
        VStack(spacing: 10) {
            if urls.count <= 1 {
                MarketplaceRemoteImageView(url: urls.first, height: height, cornerRadius: cornerRadius)
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        MarketplaceRemoteImageView(url: url, height: height, cornerRadius: cornerRadius)
                            .tag(index)
                    }
                }
                .frame(height: height)
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(Array(urls.indices), id: \.self) { index in
                        Capsule()
                            .fill(index == selectedIndex ? Theme.Colors.primary : Theme.Colors.adaptiveBorder.opacity(0.6))
                            .frame(width: index == selectedIndex ? 18 : 6, height: 6)
                    }
                }
            }
        }
    }
}

struct MarketplaceRemoteImageView: View {
    let url: URL?
    var height: CGFloat
    var cornerRadius: CGFloat = 20

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder
            case .empty:
                placeholder.overlay {
                    ProgressView()
                        .tint(Theme.Colors.primary)
                }
            @unknown default:
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
        )
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.Colors.primary.opacity(0.18),
                    Theme.Colors.accentTurquoise.opacity(0.14),
                    Theme.Colors.adaptiveSurface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Theme.Colors.primary.opacity(0.8))
                Text("marketplace.photos_empty".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }
}
