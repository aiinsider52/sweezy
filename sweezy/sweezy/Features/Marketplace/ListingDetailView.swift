import SwiftUI

struct ListingDetailView: View {
    let listingId: String
    @Environment(\.dismiss) private var dismiss
    @State private var listing: ServiceListing?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.Colors.darkBackground,
                    Theme.Colors.primaryDark.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if let listing {
                detailContent(listing)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("marketplace.detail_error".localized)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .task { await loadDetail() }
    }

    // MARK: - Detail Content

    private func detailContent(_ listing: ServiceListing) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection(listing)
                infoChipsSection(listing)
                descriptionSection(listing)
                authorSection(listing)

                Spacer(minLength: 20)

                if let contactValue = listing.contactValue, !contactValue.isEmpty {
                    ctaButton(listing: listing, contactValue: contactValue)
                }

                shareSection(listing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Header

    private func headerSection(_ listing: ServiceListing) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(listing.category.color.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: listing.category.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(listing.category.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(listing.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text(listing.category.displayName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
    }

    // MARK: - Info Chips

    private func infoChipsSection(_ listing: ServiceListing) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                detailChip(icon: "mappin.circle.fill",
                           text: listing.canton == "all" ? "🇨🇭 " + "marketplace.canton.all".localized : listing.canton,
                           color: .orange)

                if let price = listing.priceInfo, !price.isEmpty {
                    detailChip(icon: "banknote.fill", text: price, color: Theme.Colors.primary)
                }

                if let date = listing.createdAt {
                    detailChip(icon: "calendar", text: date.formatted(.dateTime.day().month(.abbreviated)), color: .purple)
                }

                detailChip(icon: "eye.fill", text: "\(listing.viewCount)", color: .cyan)
            }
        }
    }

    private func detailChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(text)
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Description

    private func descriptionSection(_ listing: ServiceListing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("marketplace.description".localized, systemImage: "text.alignleft")
                .font(.caption.bold())
                .foregroundColor(.cyan)

            Text(listing.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Colors.adaptiveSurface, lineWidth: 1)
                )
        )
    }

    // MARK: - Author

    private func authorSection(_ listing: ServiceListing) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(String(listing.authorName.prefix(1)).uppercased())
                    .font(.headline.bold())
                    .foregroundColor(Theme.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.authorName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("marketplace.author_label".localized)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Colors.adaptiveSurface, lineWidth: 1)
                )
        )
    }

    // MARK: - CTA Button

    private func ctaButton(listing: ServiceListing, contactValue: String) -> some View {
        Button {
            openContact(type: listing.contactType, value: contactValue)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: listing.contactType.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(ctaLabel(for: listing.contactType))
                    .font(.system(size: 17, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Theme.Colors.primary, Theme.Colors.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: Theme.Colors.primary.opacity(0.35), radius: 12, y: 6)
        }
    }

    // MARK: - Share

    private func shareSection(_ listing: ServiceListing) -> some View {
        ShareLink(
            item: "\(listing.title)\n\(listing.description)",
            subject: Text(listing.title),
            message: Text("marketplace.share_message".localized)
        ) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("marketplace.share".localized)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.Colors.adaptiveSurface)
            .foregroundColor(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private func loadDetail() async {
        isLoading = true
        do {
            listing = try await APIClient.fetchListingDetail(id: listingId)
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func ctaLabel(for type: ContactType) -> String {
        switch type {
        case .telegram:  return "marketplace.contact_via_telegram".localized
        case .whatsapp:  return "marketplace.contact_via_whatsapp".localized
        case .email:     return "marketplace.contact_via_email".localized
        case .phone:     return "marketplace.contact_via_phone".localized
        }
    }

    private func openContact(type: ContactType, value: String) {
        let urlString: String
        switch type {
        case .telegram:
            let username = value.hasPrefix("@") ? String(value.dropFirst()) : value
            urlString = "tg://resolve?domain=\(username)"
        case .whatsapp:
            let cleaned = value.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "+", with: "")
            urlString = "https://wa.me/\(cleaned)"
        case .email:
            urlString = "mailto:\(value)"
        case .phone:
            let cleaned = value.replacingOccurrences(of: " ", with: "")
            urlString = "tel:\(cleaned)"
        }

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url) { success in
            if !success, type == .telegram {
                if let webURL = URL(string: "https://t.me/\(value.hasPrefix("@") ? String(value.dropFirst()) : value)") {
                    UIApplication.shared.open(webURL)
                }
            }
        }
    }
}
