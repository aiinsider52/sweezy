import SwiftUI

struct PublicProfileView: View {
    let userID: String
    let listingID: String?
    let conversationID: String?

    @Environment(\.dismiss) private var dismiss
    @State private var profile: PublicUserProfile?
    @State private var errorMessage: String?
    @State private var selectedListing: PublicProfileListing?

    var body: some View {
        ZStack {
            JourneyVisual.black.ignoresSafeArea()
            if let profile {
                ScrollView {
                    VStack(spacing: 22) {
                        profileHeader(profile)
                        if profile.activeListings.isEmpty {
                            ContentUnavailableView(
                                "profile.listings.empty.title".localized,
                                systemImage: "rectangle.stack",
                                description: Text("profile.listings.empty.body".localized)
                            )
                            .foregroundStyle(.white)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("profile.listings.title".localized)
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                ForEach(profile.activeListings) { listing in
                                    Button { selectedListing = listing } label: {
                                        PublicProfileListingCard(listing: listing)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("profile.error.title".localized, systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("common.retry".localized) { Task { await load() } }
                }
                .foregroundStyle(.white)
            } else {
                ProgressView("profile.loading".localized).tint(JourneyVisual.lime).foregroundStyle(.white)
            }
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    .background(.ultraThinMaterial).clipShape(Circle())
            }
            .foregroundStyle(.white).padding(16)
        }
        .task { await load() }
        .fullScreenCover(item: $selectedListing) { listing in
            ListingDetailView(listingId: listing.id)
        }
    }

    private func profileHeader(_ profile: PublicUserProfile) -> some View {
        VStack(spacing: 12) {
            Text(profile.initials)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 88, height: 88)
                .background(JourneyVisual.lime)
                .clipShape(Circle())
            Text(profile.displayName).font(.title2.bold()).foregroundStyle(.white)
            Text(String(format: "profile.member_since.format".localized, profile.registeredMonth))
                .font(.caption).foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 10) {
                if profile.isVerified {
                    Label("profile.verified".localized, systemImage: "checkmark.seal.fill")
                }
                if let rating = profile.averageRating {
                    Label(String(format: "%.1f (%d)", rating, profile.reviewCount), systemImage: "star.fill")
                }
            }
            .font(.caption.bold()).foregroundStyle(JourneyVisual.lime)
        }
        .frame(maxWidth: .infinity).padding(.top, 54)
    }

    private func load() async {
        errorMessage = nil
        do {
            profile = try await ChatAPI.publicProfile(
                userID: userID,
                listingID: listingID,
                conversationID: conversationID
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PublicProfileListingCard: View {
    let listing: PublicProfileListing

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                JourneyVisual.lime.opacity(0.12)
                Image(systemName: listing.listingType == "item" ? "shippingbox.fill" : "person.2.fill")
                    .foregroundStyle(JourneyVisual.lime)
            }
            .frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
                Text(listing.title).font(.headline).foregroundStyle(.white).lineLimit(2)
                Text(listing.isFree ? "marketplace.free".localized : (listing.priceInfo ?? listing.priceCHF.map { "CHF \($0)" } ?? ""))
                    .font(.caption.bold()).foregroundStyle(JourneyVisual.lime)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.35))
        }
        .padding(13).background(.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
