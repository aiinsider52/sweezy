import SwiftUI

struct ListingCardView: View {
    let listing: ServiceListing

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
