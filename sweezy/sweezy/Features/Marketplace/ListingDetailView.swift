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
    @State private var scrollOffset: CGFloat = 0
    @State private var showAuth = false
    @State private var showReportReasons = false
    @State private var showBlockConfirmation = false
    @State private var safetyMessage: String?
    @State private var selectedConversation: ChatConversation?
    @State private var pendingChatAfterAuth = false
    @State private var pendingBookingAfterAuth = false
    @State private var showPublicProfile = false
    @State private var showBooking = false
    @State private var publicBusiness: PublicBusinessProfile?

    init(listingId: String, initialListing: ServiceListing? = nil) {
        self.listingId = listingId
        self.initialListing = initialListing
        _listing = State(initialValue: initialListing)
        _isLoading = State(initialValue: initialListing == nil)
    }

    var body: some View {
        ZStack(alignment: .top) {
            JourneyVisual.pageBackground
                .ignoresSafeArea()

            if let listing {
                detailContent(listing)
                    .overlay(alignment: .top) {
                        stickyHeader(listing)
                    }
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
                if pendingBookingAfterAuth {
                    pendingBookingAfterAuth = false
                    showBooking = true
                } else if pendingChatAfterAuth {
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
        .fullScreenCover(isPresented: $showPublicProfile) {
            if let authorID = listing?.authorID {
                PublicProfileView(userID: authorID, listingID: listingId, conversationID: nil)
                    .environmentObject(appContainer)
            }
        }
        .fullScreenCover(isPresented: $showBooking) {
            if let publicBusiness {
                BusinessBookingFlow(profile: publicBusiness, listingID: listingId)
            }
        }
        .confirmationDialog("Чому ви скаржитеся?".localized, isPresented: $showReportReasons, titleVisibility: .visible) {
            Button("Шахрайство".localized) { submitReport(reason: "fraud") }
            Button("Недостовірна інформація".localized) { submitReport(reason: "misleading") }
            Button("Оголошення неактуальне".localized) { submitReport(reason: "outdated") }
            Button("Спам".localized) { submitReport(reason: "spam") }
            Button("Скасувати".localized, role: .cancel) {}
        }
        .confirmationDialog("Заблокувати автора?".localized, isPresented: $showBlockConfirmation, titleVisibility: .visible) {
            Button("Заблокувати".localized, role: .destructive) { blockAuthor() }
            Button("Скасувати".localized, role: .cancel) {}
        } message: {
            Text("Його оголошення більше не з'являтимуться у вашій стрічці.".localized)
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
        .task(id: listing?.authorID) { await loadBusinessProfile() }
        .presentationDragIndicator(.hidden)
        .interactiveSwipeBackEnabled()
    }

    private func detailContent(_ listing: ServiceListing) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection(listing)

                contentSheet(listing)
                    .padding(.top, -26)
            }
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .ignoresSafeArea(edges: .top)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            scrollOffset = offset
        }
        .accessibilityIdentifier("listing.detail.scroll")
    }

    private func heroSection(_ listing: ServiceListing) -> some View {
        let count = listing.resolvedImageURLs.count
        return listingHeroMedia(listing)
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .clipped()
            .overlay(alignment: .top) {
                // Keeps the status bar readable over bright photos.
                LinearGradient(colors: [JourneyVisual.pageBackground.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 100)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                if count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<count, id: \.self) { index in
                            Capsule()
                                .fill(index == selectedImageIndex ? Color.white : Color.white.opacity(0.5))
                                .frame(width: index == selectedImageIndex ? 18 : 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background(.black.opacity(0.28), in: Capsule())
                    .padding(.bottom, 40)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedImageIndex)
                    .accessibilityLabel("\(selectedImageIndex + 1)/\(count)")
                }
            }
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
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: listing.categoryIcon)
                        Text(listing.categoryDisplayName)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(listing.categorySwatch.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(listing.categorySwatch.fill, in: Capsule())

                    HStack(spacing: 5) {
                        Image(systemName: listing.isStale ? "exclamationmark.circle.fill" : "checkmark.seal.fill")
                            .foregroundStyle(listing.isStale ? Color.orange : JourneyVisual.accentStrong)
                        Text(listing.freshnessText)
                            .foregroundStyle(JourneyVisual.secondaryText)
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .semibold))
                }

                Text(listing.title)
                    .font(.system(size: 25, weight: .bold))
                    .tracking(-0.3)
                    .foregroundColor(JourneyVisual.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(displayPrice(for: listing))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(JourneyVisual.lime)
                            .rotationEffect(.degrees(-1.2))
                    )
                    .padding(.top, 2)
                    .accessibilityLabel("\("marketplace.detail.price".localized): \(displayPrice(for: listing))")
            }

            factsStrip(listing)

            authorCard(listing)

            if let value = listing.contactValue?.trimmingCharacters(in: .whitespaces), !value.isEmpty, !isOwnListing(listing) {
                contactCard(type: listing.contactType, value: value)
            }

            descriptionBlock(listing)

            trustNote(listing)

            safetyActions
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(JourneyVisual.pageBackground)
                .shadow(color: .black.opacity(0.1), radius: 16, y: -6)
        )
    }

    /// Place, date and reach in one quiet strip instead of three divided rows.
    private func factsStrip(_ listing: ServiceListing) -> some View {
        HStack(spacing: 0) {
            factCell(icon: "mappin", label: "marketplace.detail.location".localized, value: shortLocationText(for: listing))
            factDivider
            factCell(
                icon: "calendar",
                label: "marketplace.detail.published".localized,
                value: listing.createdAt.map {
                    $0.formatted(.dateTime.day().month(.abbreviated).locale(appContainer.currentLocale))
                } ?? "—"
            )
            factDivider
            factCell(icon: "eye", label: "marketplace.detail.views".localized, value: "\(listing.viewCount)")
        }
        .padding(.vertical, 12)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(JourneyVisual.softBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func factCell(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(JourneyVisual.secondaryText)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(JourneyVisual.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }

    private var factDivider: some View {
        Rectangle()
            .fill(JourneyVisual.softBorder)
            .frame(width: 1, height: 34)
    }

    private func authorCard(_ listing: ServiceListing) -> some View {
        Button { if listing.authorID != nil { showPublicProfile = true } } label: {
            HStack(spacing: 12) {
                Text(String(listing.authorName.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(JourneyVisual.lime, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(listing.authorName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .lineLimit(1)
                    Label(
                        listing.isVerified ? "profile.verified".localized : "profile.community".localized,
                        systemImage: listing.isVerified ? "checkmark.seal.fill" : "person.2.fill"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .labelStyle(.titleAndIcon)
                }

                Spacer(minLength: 8)

                if listing.authorID != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(JourneyVisual.softSurface, in: Circle())
                }
            }
            .padding(12)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(JourneyVisual.softBorder, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
        .disabled(listing.authorID == nil)
        .accessibilityElement(children: .combine)
    }

    private func contactCard(type: ContactType, value: String) -> some View {
        Button { openContact(type: type, value: value) } label: {
            HStack(spacing: 12) {
                Image(systemName: contactIcon(for: type))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(JourneyVisual.accentText)
                    .frame(width: 44, height: 44)
                    .background(JourneyVisual.softSurface, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(ctaLabel(for: type))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                    Text(value)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .frame(width: 30, height: 30)
                    .background(JourneyVisual.softSurface, in: Circle())
            }
            .padding(12)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(JourneyVisual.softBorder, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
        .accessibilityIdentifier("listing.detail.contact")
    }

    private func contactIcon(for type: ContactType) -> String {
        switch type {
        case .telegram: return "paperplane.fill"
        case .whatsapp: return "message.fill"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        }
    }

    private func descriptionBlock(_ listing: ServiceListing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("marketplace.description".localized.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1)
                .foregroundColor(JourneyVisual.secondaryText)

            Text(listing.description)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(JourneyVisual.primaryText.opacity(0.86))
                .lineSpacing(4)
                .lineLimit(descriptionExpanded ? nil : 6)
                .fixedSize(horizontal: false, vertical: true)

            if listing.description.count > 220 {
                Button {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        descriptionExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(descriptionExpanded ? "Згорнути".localized : "Читати повністю".localized)
                        Image(systemName: descriptionExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(JourneyVisual.softSurface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trustNote(_ listing: ServiceListing) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: listing.isStale ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(listing.isStale ? .orange : JourneyVisual.accentStrong)
            Text(listing.isStale
                 ? "Дані могли змінитися. Уточніть ціну й умови перед оплатою.".localized
                 : "Модерація Sweezy пройдена. Не переказуйте гроші наперед незнайомим людям.".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(JourneyVisual.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((listing.isStale ? Color.orange : JourneyVisual.lime).opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var safetyActions: some View {
        HStack(spacing: 18) {
            Button {
                guard sessionManager.isAuthenticated else { showAuth = true; return }
                showReportReasons = true
            } label: {
                Label("Поскаржитися".localized, systemImage: "flag")
            }

            Button {
                guard sessionManager.isAuthenticated else { showAuth = true; return }
                showBlockConfirmation = true
            } label: {
                Label("Блокувати".localized, systemImage: "hand.raised")
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(JourneyVisual.secondaryText)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
    }

    private func stickyHeader(_ listing: ServiceListing) -> some View {
        // Once the photo scrolls away, a paper bar with the title fades in behind the controls.
        let collapsed = scrollOffset > 220
        return HStack(spacing: 10) {
            Button { dismiss() } label: {
                circularControlLabel(icon: "chevron.left")
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94, hapticStyle: .light))
            .accessibilityLabel("common.back".localized)
            .accessibilityIdentifier("listing.detail.back")

            Text(listing.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(JourneyVisual.primaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(collapsed ? 1 : 0)
                .accessibilityHidden(true)

            ShareLink(
                item: "\(listing.title)\n\(listing.description)",
                subject: Text(listing.title),
                message: Text("marketplace.share_message".localized)
            ) {
                circularControlLabel(icon: "square.and.arrow.up")
            }
            .accessibilityLabel("marketplace.share".localized)
            .accessibilityIdentifier("listing.detail.share")

            Button { toggleSaved(listing) } label: {
                circularControlLabel(
                    icon: appContainer.savedItems.isListingSaved(listing.id) ? "heart.fill" : "heart",
                    active: appContainer.savedItems.isListingSaved(listing.id)
                )
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94, hapticStyle: .light))
            .accessibilityLabel(appContainer.savedItems.isListingSaved(listing.id) ? "Збережено".localized : "Зберегти".localized)
            .accessibilityIdentifier("listing.detail.favorite")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(JourneyVisual.pageBackground)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(JourneyVisual.softBorder).frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .top)
                .opacity(collapsed ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.2), value: collapsed)
    }

    private func circularControlLabel(icon: String, active: Bool = false) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(active ? .black : JourneyVisual.primaryText)
            .frame(width: 42, height: 42)
            .background(active ? JourneyVisual.lime : Theme.Colors.card.opacity(0.94), in: Circle())
            .overlay(Circle().strokeBorder(JourneyVisual.softBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
    }

    private func bottomActionBar(listing: ServiceListing) -> some View {
        let own = isOwnListing(listing)
        let chatAvailable = listing.authorID != nil && !own
        let bookable = businessService(for: listing) != nil && !own
        let unavailable = own || listing.authorID == nil
        return HStack(spacing: 10) {
            Button {
                if bookable {
                    guard sessionManager.isAuthenticated else {
                        pendingBookingAfterAuth = true
                        showAuth = true
                        return
                    }
                    showBooking = true
                    return
                }
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
                    Image(systemName: own ? "checkmark.seal.fill" : (bookable ? "calendar.badge.plus" : "bubble.left.and.bubble.right.fill"))
                        .font(.system(size: 16, weight: .bold))
                    Text(
                        own
                            ? "chat.listing.own".localized
                            : (bookable ? "Записатися".localized : (listing.authorID == nil ? "chat.listing.unavailable".localized : "chat.listing.message".localized))
                    )
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .foregroundColor(unavailable ? JourneyVisual.secondaryText : .black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(unavailable ? JourneyVisual.softSurface : JourneyVisual.lime, in: Capsule())
                .shadow(color: JourneyVisual.lime.opacity(unavailable ? 0 : 0.4), radius: 14, y: 6)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
            .disabled(own)
            .accessibilityIdentifier("listing.detail.primary")

            if bookable {
                Button {
                    guard sessionManager.isAuthenticated else {
                        pendingChatAfterAuth = true
                        showAuth = true
                        return
                    }
                    startChat()
                } label: {
                    Image(systemName: "message.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .frame(width: 52, height: 52)
                        .background(Theme.Colors.card, in: Circle())
                        .overlay(Circle().strokeBorder(JourneyVisual.softBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Написати".localized)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(JourneyVisual.softBorder.opacity(0.6))
                .frame(height: 0.5)
        }
    }

    private func isOwnListing(_ listing: ServiceListing) -> Bool {
        guard let authorID = listing.authorID, let userID = sessionManager.currentUser?.id else { return false }
        return authorID == userID
    }

    private func businessService(for listing: ServiceListing) -> BusinessServiceItem? {
        publicBusiness?.services.first(where: { $0.listingID == listing.id })
    }

    private func loadBusinessProfile() async {
        guard let currentListing = listing, let authorID = currentListing.authorID, !isOwnListing(currentListing) else {
            publicBusiness = nil
            return
        }
        do {
            publicBusiness = try await BusinessProAPI.publicProfile(userID: authorID)
        } catch {
            publicBusiness = nil
        }
    }

    private func startChat() {
        Task {
            do {
                await appContainer.chatStore.start()
                selectedConversation = try await appContainer.chatStore.openConversation(for: listingId)
            } catch {
                let raw = ((error as NSError).userInfo["api.detail"] as? String) ?? ""
                if raw.localizedCaseInsensitiveContains("Listing not found")
                    || raw.localizedCaseInsensitiveContains("no seller") {
                    safetyMessage = "chat.listing.no_seller".localized
                } else if raw.localizedCaseInsensitiveContains("Verify your email") {
                    safetyMessage = "chat.listing.verify_email".localized
                } else {
                    safetyMessage = error.localizedDescription
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
            Text("Відкриваємо послугу".localized)
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundColor(JourneyVisual.primaryText)
            Text("Завантажуємо актуальні дані автора".localized)
                .font(.subheadline)
                .foregroundColor(JourneyVisual.secondaryText)
        }
        .padding(28)
        .journeyCard(cornerRadius: 28)
        .padding(24)
    }

    private var listingErrorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text("Не вдалося відкрити послугу".localized)
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(JourneyVisual.primaryText)
                .multilineTextAlignment(.center)
            Text("Перевірте з’єднання або спробуйте ще раз.".localized)
                .font(.subheadline)
                .foregroundColor(JourneyVisual.secondaryText)
                .multilineTextAlignment(.center)
            Button {
                Task { await loadDetail() }
            } label: {
                Label("Спробувати знову".localized, systemImage: "arrow.clockwise")
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

    private func shortLocationText(for listing: ServiceListing) -> String {
        guard listing.subdivisionCode != "all" else { return "country.whole_country".localized }
        let country = ResidenceCountry(rawValue: listing.countryCode) ?? .switzerland
        return CountryCatalog.subdivisionName(country: country, code: listing.subdivisionCode)
    }

    private func displayPrice(for listing: ServiceListing) -> String {
        guard let raw = listing.priceDisplay?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return "За домовленістю".localized
        }

        if raw.range(of: listing.currencyCode, options: .caseInsensitive) != nil || listing.isFree {
            return raw
        }

        let numeric = raw.replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "")
        if Decimal(string: numeric) != nil {
            return "\(listing.currencyCode) \(raw)"
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
                safetyMessage = "Дякуємо. Скаргу передано модераторам. Повторно надсилати її не потрібно.".localized
            } catch {
                safetyMessage = "Не вдалося надіслати скаргу. Перевірте авторизацію та спробуйте ще раз.".localized
            }
        }
    }

    private func blockAuthor() {
        Task {
            do {
                try await APIClient.blockListingAuthor(listingID: listingId)
                safetyMessage = "Автора заблоковано. Його оголошення приховано з вашої стрічки.".localized
            } catch {
                safetyMessage = "Не вдалося заблокувати автора. Спробуйте ще раз.".localized
            }
        }
    }
}
