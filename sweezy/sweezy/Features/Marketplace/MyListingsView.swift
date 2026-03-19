import SwiftUI

struct MyListingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var listings: [ServiceListing] = []
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptivePageBackground()

                Group {
                    if isLoading {
                        ProgressView("common.loading".localized)
                    } else if listings.isEmpty {
                        emptyState
                    } else {
                        listContent
                    }
                }
            }
            .navigationTitle("marketplace.my_listings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) { dismiss() }
                }
            }
            .refreshable { await loadListings() }
            .task { await loadListings() }
        }
    }

    // MARK: - List

    private var listContent: some View {
        List {
            ForEach(listings) { listing in
                MyListingRow(listing: listing)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
            }
            .onDelete { indexSet in
                Task { await deleteListing(at: indexSet) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty

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
    }

    // MARK: - Actions

    private func loadListings() async {
        isLoading = listings.isEmpty
        do {
            listings = try await APIClient.fetchMyListings()
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func deleteListing(at offsets: IndexSet) async {
        for index in offsets {
            let listing = listings[index]
            do {
                try await APIClient.deleteListing(id: listing.id)
                listings.remove(at: index)
            } catch {
                self.error = error
            }
        }
    }
}

// MARK: - Row

private struct MyListingRow: View {
    let listing: ServiceListing

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(listing.category.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: listing.category.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(listing.category.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)

                    statusBadge
                }

                Spacer()

                if let date = listing.createdAt {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }

            if listing.status == .rejected, let reason = listing.rejectionReason, !reason.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.error)
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.error.opacity(0.9))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.Colors.error.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.Colors.error.opacity(0.15), lineWidth: 1)
                        )
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.caption.bold())
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.12))
        )
    }

    private var statusColor: Color {
        switch listing.status {
        case .pending:  return .orange
        case .approved: return Theme.Colors.primary
        case .rejected: return Theme.Colors.error
        }
    }

    private var statusText: String {
        switch listing.status {
        case .pending:  return "marketplace.status.pending".localized
        case .approved: return "marketplace.status.approved".localized
        case .rejected: return "marketplace.status.rejected".localized
        }
    }
}
