import SwiftUI

struct MyListingsView: View {
    var onListingsChanged: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var listings: [ServiceListing] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedListing: ServiceListing?
    @State private var listingToEdit: ServiceListing?
    @State private var listingToDelete: ServiceListing?

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptivePageBackground()

                if isLoading {
                    ProgressView("common.loading".localized)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            summaryHero

                            if listings.isEmpty {
                                emptyState
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(listings) { listing in
                                        MyListingCard(
                                            listing: listing,
                                            onOpen: { selectedListing = listing },
                                            onEdit: { listingToEdit = listing },
                                            onDelete: { listingToDelete = listing }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .padding(.bottom, 24)
                    }
                    .refreshable { await loadListings() }
                }
            }
            .navigationTitle("marketplace.my_listings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) { dismiss() }
                }
            }
            .task { await loadListings() }
            .sheet(item: $selectedListing) { listing in
                ListingDetailView(listingId: listing.id)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $listingToEdit) { listing in
                EditListingView(listing: listing) { updated in
                    replaceListing(updated)
                    onListingsChanged?()
                }
            }
            .alert("marketplace.delete_title".localized, isPresented: .init(
                get: { listingToDelete != nil },
                set: { if !$0 { listingToDelete = nil } }
            )) {
                Button("common.cancel".localized, role: .cancel) {
                    listingToDelete = nil
                }
                Button("common.delete".localized, role: .destructive) {
                    guard let listingToDelete else { return }
                    Task { await deleteListing(listingToDelete) }
                }
            } message: {
                Text("marketplace.delete_message".localized)
            }
            .alert("marketplace.error_title".localized, isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("common.ok".localized) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var summaryHero: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.Colors.primaryDark.opacity(0.95),
                            Theme.Colors.primary.opacity(0.82),
                            Theme.Colors.accentTurquoise.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 140, height: 140)
                .blur(radius: 12)
                .offset(x: 40, y: -30)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("marketplace.cabinet_title".localized)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("marketplace.cabinet_subtitle".localized)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.78))
                    }

                    Spacer()

                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                }

                HStack(spacing: 10) {
                    summaryPill(title: "marketplace.cabinet.total".localized, value: listings.count, tint: .white)
                    summaryPill(title: "marketplace.status.approved".localized, value: approvedCount, tint: Theme.Colors.primaryLight)
                    summaryPill(title: "marketplace.status.pending".localized, value: pendingCount, tint: .orange)
                    summaryPill(title: "marketplace.status.rejected".localized, value: rejectedCount, tint: .red.opacity(0.9))
                }
            }
            .padding(18)
        }
        .shadow(color: Theme.Colors.primary.opacity(0.22), radius: 20, y: 10)
    }

    private func summaryPill(title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("marketplace.my_empty_title".localized)
                .font(.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("marketplace.my_empty_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var approvedCount: Int {
        listings.filter { $0.status == .approved }.count
    }

    private var pendingCount: Int {
        listings.filter { $0.status == .pending }.count
    }

    private var rejectedCount: Int {
        listings.filter { $0.status == .rejected }.count
    }

    private func loadListings() async {
        isLoading = listings.isEmpty
        do {
            listings = try await APIClient.fetchMyListings()
        } catch {
            if (error as NSError).code == 401 {
                sessionManager.signOut()
                errorMessage = "auth.session_expired".localized
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func deleteListing(_ listing: ServiceListing) async {
        do {
            try await APIClient.deleteListing(id: listing.id)
            listings.removeAll { $0.id == listing.id }
            listingToDelete = nil
            onListingsChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replaceListing(_ updated: ServiceListing) {
        if let index = listings.firstIndex(where: { $0.id == updated.id }) {
            listings[index] = updated
        }
    }
}

private struct MyListingCard: View {
    let listing: ServiceListing
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !listing.resolvedImageURLs.isEmpty {
                MarketplaceRemoteImageView(url: listing.primaryImageURL, height: 176, cornerRadius: 18)
            }

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(listing.category.color.opacity(0.16))
                        .frame(width: 48, height: 48)
                    Image(systemName: listing.category.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(listing.category.color)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(listing.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        StatusBadge(status: listing.status)
                        ListingBadgePill(text: listing.category.displayName, color: listing.category.color)
                    }
                }

                Spacer()
            }

            HStack(spacing: 14) {
                Label(listing.canton == "all" ? "🇨🇭" : listing.canton, systemImage: "mappin.circle.fill")
                Label("\(listing.viewCount)", systemImage: "eye.fill")
                if let date = listing.createdAt {
                    Text(date, style: .relative)
                }
            }
            .font(.caption)
            .foregroundColor(Theme.Colors.textSecondary)

            if let price = listing.priceInfo, !price.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "banknote.fill")
                        .foregroundColor(Theme.Colors.primary)
                    Text(price)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.Colors.primary)
                }
            }

            if listing.status == .rejected, let reason = listing.rejectionReason, !reason.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.Colors.error)
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.error.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.Colors.error.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.Colors.error.opacity(0.16), lineWidth: 1)
                        )
                )
            }

            HStack(spacing: 10) {
                actionButton(title: "marketplace.open".localized, icon: "arrow.up.right.square", fill: Theme.Colors.adaptiveSurface, tint: Theme.Colors.textPrimary, action: onOpen)
                actionButton(title: "marketplace.edit".localized, icon: "pencil", fill: listing.category.color.opacity(0.14), tint: listing.category.color, action: onEdit)
                actionButton(title: "common.delete".localized, icon: "trash", fill: Theme.Colors.error.opacity(0.12), tint: Theme.Colors.error, action: onDelete)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private func actionButton(title: String, icon: String, fill: Color, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StatusBadge: View {
    let status: ListingStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption.bold())
                .foregroundColor(color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private var color: Color {
        switch status {
        case .pending: return .orange
        case .approved: return Theme.Colors.primary
        case .rejected: return Theme.Colors.error
        }
    }

    private var text: String {
        switch status {
        case .pending: return "marketplace.status.pending".localized
        case .approved: return "marketplace.status.approved".localized
        case .rejected: return "marketplace.status.rejected".localized
        }
    }
}
