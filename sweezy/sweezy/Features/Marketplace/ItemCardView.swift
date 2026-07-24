//
//  ItemCardView.swift
//  sweezy
//
//  Photo-first grid card for goods listings (tutti.ch-style),
//  styled per the ink+paper design language.
//

import SwiftUI

struct ItemCardView: View {
    let listing: ServiceListing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photoSection

            VStack(alignment: .leading, spacing: 6) {
                priceRow

                Text(listing.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    if let condition = listing.condition {
                        Text(condition.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.Colors.adaptiveSurface))
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: 9))
                        Text(listing.canton)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .fill(Color.black.opacity(0.34))
                .background(.ultraThinMaterial.opacity(0.78), in: RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
        .shadow(color: Color.black.opacity(0.26), radius: 14, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(listing.title), \(listing.priceDisplay ?? ""), \(listing.canton)")
    }

    private var photoSection: some View {
        ZStack(alignment: .topLeading) {
            if let url = listing.primaryImageURL {
                MarketplaceRemoteImageView(url: url, height: 140)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill((listing.itemCategory?.color ?? Theme.Colors.primary).opacity(0.10))
                    Image(systemName: listing.itemCategory?.icon ?? "shippingbox.fill")
                        .font(.system(size: 32))
                        .foregroundColor((listing.itemCategory?.color ?? Theme.Colors.primary).opacity(0.55))
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 4) {
                if listing.isFree {
                    badge("marketplace.price.free".localized, background: Theme.Colors.accentCoral)
                }
                if listing.isVerified {
                    badge(
                        "marketplace.badge.verified".localized,
                        background: Theme.Colors.primary,
                        foreground: Theme.Colors.textOnPrimary
                    )
                }
            }
            .padding(8)
        }
    }

    private var priceRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if listing.isFree {
                Text("marketplace.price.free".localized)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.accentCoral)
            } else if let price = listing.priceChf {
                Text("CHF \(price)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.primary)
                if listing.negotiable {
                    Text("marketplace.price.negotiable".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func badge(_ text: String, background: Color, foreground: Color = .white) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(background))
    }
}
