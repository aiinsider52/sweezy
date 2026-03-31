import SwiftUI

struct ListingDetailView: View {
    let listingId: String
    @State private var listing: ServiceListing?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        ZStack {
            AdaptivePageBackground()

            if isLoading {
                ProgressView()
                    .tint(Theme.Colors.primary)
            } else if let listing {
                detailContent(listing)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("marketplace.detail_error".localized)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .task { await loadDetail() }
        .safeAreaInset(edge: .bottom) {
            if let listing, let contactValue = listing.contactValue, !contactValue.isEmpty {
                bottomActionBar(listing: listing, contactValue: contactValue)
            }
        }
    }

    private func detailContent(_ listing: ServiceListing) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                heroSection(listing)
                metricsGrid(listing)
                descriptionSection(listing)
                authorSection(listing)
                detailsFootnote(listing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 140)
        }
    }

    private func heroSection(_ listing: ServiceListing) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !listing.resolvedImageURLs.isEmpty {
                MarketplaceListingImageCarousel(urls: listing.resolvedImageURLs, height: 260, cornerRadius: 28)
            }

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                listing.category.color.opacity(0.95),
                                Theme.Colors.primaryDark.opacity(0.9),
                                Theme.Colors.darkBackground
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 160, height: 160)
                    .blur(radius: 8)
                    .offset(x: 40, y: -34)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        HStack(spacing: 8) {
                            pill(text: listing.category.displayName, icon: listing.category.icon, tint: .white.opacity(0.18))
                            pill(
                                text: listing.canton == "all" ? "marketplace.canton.all".localized : listing.canton,
                                icon: "mappin.circle.fill",
                                tint: .white.opacity(0.12)
                            )
                        }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(listing.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        if let price = listing.priceInfo, !price.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "banknote.fill")
                                Text(price)
                                    .font(.headline.weight(.bold))
                            }
                            .foregroundColor(.white.opacity(0.96))
                        }
                    }

                    HStack(spacing: 18) {
                        heroMeta(icon: "eye.fill", text: "\(listing.viewCount)")
                        if let date = listing.createdAt {
                            heroMeta(icon: "calendar", text: date.formatted(.dateTime.day().month(.abbreviated)))
                        }
                        heroMeta(icon: "person.fill", text: listing.authorName)
                    }
                }
                .padding(22)
            }
            .shadow(color: listing.category.color.opacity(0.22), radius: 24, y: 14)
        }
    }

    private func metricsGrid(_ listing: ServiceListing) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            detailMetricCard(
                title: "marketplace.detail.location".localized,
                value: listing.canton == "all" ? "marketplace.canton.all".localized : listing.canton,
                icon: "mappin.and.ellipse",
                color: .orange
            )
            detailMetricCard(
                title: "marketplace.detail.contact".localized,
                value: listing.contactType.displayName,
                icon: listing.contactType.icon,
                color: listing.category.color
            )
            detailMetricCard(
                title: "marketplace.detail.views".localized,
                value: "\(listing.viewCount)",
                icon: "eye.fill",
                color: .cyan
            )
            detailMetricCard(
                title: "marketplace.detail.published".localized,
                value: listing.createdAt?.formatted(.dateTime.day().month(.abbreviated)) ?? "—",
                icon: "calendar",
                color: .purple
            )
        }
    }

    private func detailMetricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private func descriptionSection(_ listing: ServiceListing) -> some View {
        sectionCard(title: "marketplace.description".localized, icon: "text.alignleft", accent: .cyan) {
            Text(listing.description)
                .font(.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }

    private func authorSection(_ listing: ServiceListing) -> some View {
        sectionCard(title: "marketplace.author_label".localized, icon: "person.crop.circle.fill", accent: Theme.Colors.primary) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.primary.opacity(0.2), listing.category.color.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Text(String(listing.authorName.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.authorName)
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("marketplace.detail.author_hint".localized)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()
            }
        }
    }

    private func detailsFootnote(_ listing: ServiceListing) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("marketplace.detail.footer".localized)
                .font(.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionCard<Content: View>(title: String, icon: String, accent: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(accent)
                Text(title)
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private func pill(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.caption.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(tint))
    }

    private func heroMeta(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.white.opacity(0.82))
    }

    private func bottomActionBar(listing: ServiceListing, contactValue: String) -> some View {
        VStack(spacing: 10) {
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
                .cornerRadius(18)
                .shadow(color: Theme.Colors.primary.opacity(0.28), radius: 14, y: 8)
            }

            ShareLink(
                item: "\(listing.title)\n\(listing.description)",
                subject: Text(listing.title),
                message: Text("marketplace.share_message".localized)
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("marketplace.share".localized)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.Colors.adaptiveSurface)
                .foregroundColor(Theme.Colors.textPrimary)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }

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
