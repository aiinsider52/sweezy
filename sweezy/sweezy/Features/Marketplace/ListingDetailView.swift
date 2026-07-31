import SwiftUI

struct ListingDetailView: View {
    let listingId: String
    let initialListing: ServiceListing?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var listing: ServiceListing?
    @State private var isLoading: Bool
    @State private var error: Error?
    @State private var selectedImageIndex = 0
    @State private var descriptionExpanded = false
    @State private var showAuth = false
    @State private var showReportReasons = false
    @State private var showBlockConfirmation = false
    @State private var safetyMessage: String?
    @State private var selectedConversation: ChatConversation?
    @State private var pendingChatAfterAuth = false

    init(listingId: String, initialListing: ServiceListing? = nil) {
        self.listingId = listingId
        self.initialListing = initialListing
        _listing = State(initialValue: initialListing)
        _isLoading = State(initialValue: initialListing == nil)
    }

    var body: some View {
        ZStack {
            JourneyVisual.black.ignoresSafeArea()

            if let listing {
                detailContent(listing)
            } else if isLoading {
                listingLoadingState
            } else {
                listingErrorState
            }
        }
        .task { await loadDetail() }
        .sheet(isPresented: $showAuth) {
            AuthEntryView(showsCloseButton: true, onComplete: {
                showAuth = false
                if pendingChatAfterAuth {
                    pendingChatAfterAuth = false
                    startChat()
                }
            })
                .environment(\.locale, appContainer.currentLocale)
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
        .fullScreenCover(item: $selectedConversation) { conversation in
            ChatConversationView(conversation: conversation)
                .environmentObject(appContainer)
        }
        .confirmationDialog("Чому ви скаржитеся?", isPresented: $showReportReasons, titleVisibility: .visible) {
            Button("Шахрайство") { submitReport(reason: "fraud") }
            Button("Недостовірна інформація") { submitReport(reason: "misleading") }
            Button("Оголошення неактуальне") { submitReport(reason: "outdated") }
            Button("Спам") { submitReport(reason: "spam") }
            Button("Скасувати", role: .cancel) {}
        }
        .confirmationDialog("Заблокувати автора?", isPresented: $showBlockConfirmation, titleVisibility: .visible) {
            Button("Заблокувати", role: .destructive) { blockAuthor() }
            Button("Скасувати", role: .cancel) {}
        } message: {
            Text("Його оголошення більше не з'являтимуться у вашій стрічці.")
        }
        .alert("marketplace.error_title".localized, isPresented: Binding(
            get: { safetyMessage != nil },
            set: { if !$0 { safetyMessage = nil } }
        )) {
            Button("common.ok".localized, role: .cancel) { safetyMessage = nil }
        } message: {
            Text(safetyMessage ?? "")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let listing {
                bottomActionBar(listing: listing)
            }
        }
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private func detailContent(_ listing: ServiceListing) -> some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    heroSection(listing, topInset: geometry.safeAreaInsets.top)

                    contentSheet(listing)
                        .offset(y: -34)
                        .padding(.bottom, -34)
                }
                .padding(.bottom, 36)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private func heroSection(_ listing: ServiceListing, topInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            listingHeroMedia(listing)

            LinearGradient(
                colors: [.clear, .black.opacity(0.04), .black.opacity(0.56)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                HStack {
                    circularControl(icon: "chevron.left", accessibilityLabel: "common.back".localized) {
                        dismiss()
                    }

                    Spacer()

                    ShareLink(
                        item: "\(listing.title)\n\(listing.description)",
                        subject: Text(listing.title),
                        message: Text("marketplace.share_message".localized)
                    ) {
                        circularControlLabel(icon: "square.and.arrow.up")
                    }
                    .accessibilityLabel("marketplace.share".localized)

                    Button {
                        toggleSaved(listing)
                    } label: {
                        circularControlLabel(
                            icon: appContainer.savedItems.isListingSaved(listing.id) ? "heart.fill" : "heart"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appContainer.savedItems.isListingSaved(listing.id) ? "Збережено" : "Зберегти")
                }
                .padding(.horizontal, 20)
                .padding(.top, max(topInset, 44) + 10)

                Spacer()

                HStack(alignment: .bottom) {
                    Label(listing.categoryDisplayName, systemImage: listing.categoryIcon)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())

                    Spacer()

                    if listing.resolvedImageURLs.count > 1 {
                        Text("\(selectedImageIndex + 1)/\(listing.resolvedImageURLs.count)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(Color.black.opacity(0.56))
                            .background(.ultraThinMaterial.opacity(0.54))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
            }
        }
        .frame(height: 520)
        .clipped()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func listingHeroMedia(_ listing: ServiceListing) -> some View {
        let urls = listing.resolvedImageURLs

        if urls.isEmpty {
            fallbackImage(for: listing)
        } else if urls.count == 1 {
            CachedAsyncImage(url: urls[0]) {
                fallbackImage(for: listing)
            }
        } else {
            TabView(selection: $selectedImageIndex) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    CachedAsyncImage(url: url) {
                        fallbackImage(for: listing)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private func fallbackImage(for listing: ServiceListing) -> some View {
        Image(fallbackAssetName(for: listing))
            .resizable()
            .scaledToFill()
    }

    private func fallbackAssetName(for listing: ServiceListing) -> String {
        listing.listingType == .service ? listing.marketplaceFallbackAsset : "cityhub-zurich-kreis4"
    }

    private func contentSheet(_ listing: ServiceListing) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(listing.title)
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineSpacing(-1)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 9) {
                Image(systemName: "mappin")
                    .foregroundColor(JourneyVisual.lime)
                Text(locationText(for: listing))
                    .foregroundColor(.white.opacity(0.72))
            }
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .padding(.top, 14)

            detailDivider
                .padding(.vertical, 18)

            providerPriceRow(listing)

            detailDivider
                .padding(.vertical, 18)

            metadataRow(listing)

            detailDivider
                .padding(.vertical, 18)

            descriptionBlock(listing)

            trustBlock(listing)
                .padding(.top, 20)

            safetyActions
                .padding(.top, 18)

            detailsFootnote
                .padding(.top, 18)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 30)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color(red: 0.035, green: 0.055, blue: 0.043).opacity(0.94))
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 34,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 34,
            style: .continuous
        ))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 34,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 34,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.42), radius: 28, y: -8)
    }

    private func providerPriceRow(_ listing: ServiceListing) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                Text(String(listing.authorName.prefix(1)).uppercased())
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 5) {
                Text(listing.authorName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Label(
                    listing.isVerified ? "Перевірений профіль" : "Спільнота Sweezy",
                    systemImage: listing.isVerified ? "checkmark.seal.fill" : "person.2.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundColor(listing.isVerified ? JourneyVisual.lime : .white.opacity(0.58))
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(displayPrice(for: listing))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 17)
                .frame(minHeight: 52)
                .background(JourneyVisual.lime)
                .clipShape(Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    private func metadataRow(_ listing: ServiceListing) -> some View {
        HStack(spacing: 0) {
            metadataItem(icon: "eye", text: "\(listing.viewCount) переглядів")

            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 1, height: 28)
                .padding(.horizontal, 16)

            metadataItem(
                icon: "calendar",
                text: listing.createdAt.map {
                    "Опубліковано \($0.formatted(.dateTime.day().month(.wide).locale(appContainer.currentLocale)))"
                } ?? "Дата не вказана"
            )
        }
        .accessibilityElement(children: .combine)
    }

    private func metadataItem(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(2)
        }
        .foregroundColor(.white.opacity(0.62))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func descriptionBlock(_ listing: ServiceListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "text.alignleft")
                    .foregroundColor(JourneyVisual.lime)
                Text("marketplace.description".localized)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text(listing.description)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.84))
                .lineSpacing(4)
                .lineLimit(descriptionExpanded ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)

            if listing.description.count > 220 {
                Button(descriptionExpanded ? "Згорнути" : "Читати повністю") {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        descriptionExpanded.toggle()
                    }
                }
                .font(.subheadline.bold())
                .foregroundColor(JourneyVisual.lime)
                .buttonStyle(.plain)
            }
        }
    }

    private func trustBlock(_ listing: ServiceListing) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: listing.isStale ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(listing.isStale ? .orange : JourneyVisual.lime)

            VStack(alignment: .leading, spacing: 5) {
                Text(listing.freshnessText)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(listing.isStale
                     ? "Дані могли змінитися. Уточніть ціну й умови перед оплатою."
                     : "Модерація Sweezy пройдена. Не переказуйте гроші наперед незнайомим людям.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var safetyActions: some View {
        HStack(spacing: 10) {
            Button {
                guard sessionManager.isAuthenticated else { showAuth = true; return }
                showReportReasons = true
            } label: {
                Label("Поскаржитися", systemImage: "exclamationmark.bubble")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                guard sessionManager.isAuthenticated else { showAuth = true; return }
                showBlockConfirmation = true
            } label: {
                Label("Блокувати", systemImage: "person.crop.circle.badge.xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .font(.caption.bold())
        .tint(.white.opacity(0.5))
    }

    private var detailsFootnote: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
            Text("marketplace.detail.footer".localized)
        }
        .font(.caption)
        .foregroundColor(.white.opacity(0.4))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var detailDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(height: 1)
    }

    private func circularControl(icon: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            circularControlLabel(icon: icon)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func circularControlLabel(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 19, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 52, height: 52)
            .background(Color.black.opacity(0.48))
            .background(.ultraThinMaterial.opacity(0.72))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
    }

    private func bottomActionBar(listing: ServiceListing) -> some View {
        let chatAvailable = listing.authorID != nil && !isOwnListing(listing)
        return HStack(spacing: 12) {
            Button {
                guard chatAvailable else {
                    if listing.authorID == nil {
                        safetyMessage = "chat.listing.no_seller".localized
                    }
                    return
                }
                guard sessionManager.isAuthenticated else {
                    pendingChatAfterAuth = true
                    showAuth = true
                    return
                }
                startChat()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isOwnListing(listing) ? "person.crop.circle.badge.checkmark" : "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 19, weight: .bold))
                    Text(
                        isOwnListing(listing)
                            ? "chat.listing.own".localized
                            : (listing.authorID == nil ? "chat.listing.unavailable".localized : "chat.listing.message".localized)
                    )
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background((isOwnListing(listing) || listing.authorID == nil) ? Color.gray : JourneyVisual.lime)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isOwnListing(listing))

            Button {
                toggleSaved(listing)
            } label: {
                Image(systemName: appContainer.savedItems.isListingSaved(listing.id) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(appContainer.savedItems.isListingSaved(listing.id) ? JourneyVisual.lime : .white)
                    .frame(width: 58, height: 58)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appContainer.savedItems.isListingSaved(listing.id) ? "Збережено" : "Зберегти")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial.opacity(0.96))
        .background(Color.black.opacity(0.84))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
    }

    private func isOwnListing(_ listing: ServiceListing) -> Bool {
        guard let authorID = listing.authorID, let userID = sessionManager.currentUser?.id else { return false }
        return authorID == userID
    }

    private func startChat() {
        Task {
            do {
                await appContainer.chatStore.start()
                selectedConversation = try await appContainer.chatStore.openConversation(for: listingId)
            } catch {
                let raw = error.localizedDescription
                if raw.localizedCaseInsensitiveContains("Listing not found")
                    || raw.localizedCaseInsensitiveContains("no seller") {
                    safetyMessage = "chat.listing.no_seller".localized
                } else if raw.localizedCaseInsensitiveContains("Verify your email") {
                    safetyMessage = "chat.listing.verify_email".localized
                } else {
                    safetyMessage = raw
                }
            }
        }
    }

    private var listingLoadingState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(JourneyVisual.lime.opacity(0.14))
                    .frame(width: 82, height: 82)
                ProgressView()
                    .controlSize(.large)
                    .tint(JourneyVisual.lime)
            }
            Text("Відкриваємо послугу")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Завантажуємо актуальні дані автора")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.62))
        }
        .padding(28)
        .journeyCard(cornerRadius: 28)
        .padding(24)
    }

    private var listingErrorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(JourneyVisual.lime)
            Text("Не вдалося відкрити послугу")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Перевірте з’єднання або спробуйте ще раз.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.68))
                .multilineTextAlignment(.center)
            Button {
                Task { await loadDetail() }
            } label: {
                Label("Спробувати знову", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .journeyCard(cornerRadius: 28)
        .padding(24)
    }

    private func locationText(for listing: ServiceListing) -> String {
        guard listing.canton != "all" else { return "marketplace.canton.all".localized }
        let name = SwissCanton.all.first(where: { $0.code == listing.canton })?.name
        guard let name, name != listing.canton else { return listing.canton }
        return "\(name) · \(listing.canton)"
    }

    private func displayPrice(for listing: ServiceListing) -> String {
        guard let raw = listing.priceDisplay?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return "За домовленістю"
        }

        if raw.range(of: "CHF", options: .caseInsensitive) != nil || listing.isFree {
            return raw
        }

        let numeric = raw.replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "")
        if Decimal(string: numeric) != nil {
            return "CHF \(raw)"
        }
        return raw
    }

    private func toggleSaved(_ listing: ServiceListing) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        appContainer.savedItems.toggleListing(listing.id)
    }

    private func loadDetail() async {
        if listing == nil {
            isLoading = true
        }
        error = nil
        defer { isLoading = false }

        do {
            listing = try await APIClient.fetchListingDetail(id: listingId)
            if let listing {
                APIClient.quickTelemetry(
                    source: "marketplace",
                    type: TelemetryService.RetentionEvent.marketplaceListingViewed.rawValue,
                    meta: ["listing_id": listing.id, "category": listing.rawCategory, "trust_level": listing.trustLevel]
                )
            }
        } catch {
            self.error = error
        }
    }

    private func ctaLabel(for type: ContactType) -> String {
        switch type {
        case .telegram: return "marketplace.contact_via_telegram".localized
        case .whatsapp: return "marketplace.contact_via_whatsapp".localized
        case .email: return "marketplace.contact_via_email".localized
        case .phone: return "marketplace.contact_via_phone".localized
        }
    }

    private func openContact(type: ContactType, value: String) {
        APIClient.quickTelemetry(
            source: "marketplace",
            type: TelemetryService.RetentionEvent.marketplaceContactTapped.rawValue,
            meta: ["listing_id": listingId, "contact_type": type.rawValue]
        )

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
            if !success, type == .telegram,
               let webURL = URL(string: "https://t.me/\(value.hasPrefix("@") ? String(value.dropFirst()) : value)") {
                UIApplication.shared.open(webURL)
            }
        }
    }

    private func submitReport(reason: String) {
        Task {
            do {
                try await APIClient.reportListing(id: listingId, reason: reason)
                safetyMessage = "Дякуємо. Скаргу передано модераторам. Повторно надсилати її не потрібно."
            } catch {
                safetyMessage = "Не вдалося надіслати скаргу. Перевірте авторизацію та спробуйте ще раз."
            }
        }
    }

    private func blockAuthor() {
        Task {
            do {
                try await APIClient.blockListingAuthor(listingID: listingId)
                safetyMessage = "Автора заблоковано. Його оголошення приховано з вашої стрічки."
            } catch {
                safetyMessage = "Не вдалося заблокувати автора. Спробуйте ще раз."
            }
        }
    }
}
