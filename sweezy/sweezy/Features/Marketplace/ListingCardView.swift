import SwiftUI

struct ListingCardView: View {
    let listing: ServiceListing

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !listing.resolvedImageURLs.isEmpty {
                MarketplaceRemoteImageView(url: listing.primaryImageURL, height: 184, cornerRadius: 16)
            }

            // Header: icon + title
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(listing.category.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: listing.category.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(listing.category.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)

                    // Badges
                    HStack(spacing: 6) {
                        ListingBadgePill(text: listing.category.displayName, color: listing.category.color)
                        ListingBadgePill(text: listing.canton == "all" ? "🇨🇭" : listing.canton, color: .orange)
                    }
                }

                Spacer()
            }

            // Price + meta
            HStack {
                if let price = listing.priceInfo, !price.isEmpty {
                    Label(price, systemImage: "banknote.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Label("\(listing.viewCount)", systemImage: "eye.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textTertiary)

                    Text(listing.authorName)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            // Date
            if let date = listing.createdAt {
                Text(date, style: .relative)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
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
