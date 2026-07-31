import SwiftUI

struct JourneyMarketplaceView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager

    @StateObject private var servicesVM = MarketplaceViewModel()
    @StateObject private var itemsVM = MarketplaceViewModel(listingType: .item)
    @StateObject private var eventsVM = EventsViewModel()
    @StateObject private var calendarService = EventCalendarService()

    @State private var selectedMode: JourneyMarketMode = .services
    @State private var selectedListing: ServiceListing?
    @State private var selectedEvent: EventListing?
    @State private var showCreateListing = false
    @State private var showCreateItem = false
    @State private var showCreateEvent = false
    @State private var showAuth = false
    @State private var pendingCreate = false
    @State private var showExperts = false
    @State private var calendarMessage: String?
    @State private var showInbox = false
    @State private var pendingInbox = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                JourneyVisual.black.ignoresSafeArea()

                marketOverscrollBackdrop
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        marketHero

                        VStack(alignment: .leading, spacing: 16) {
                            MarketSearchField(text: searchBinding, prompt: searchPrompt)
                            filters
                            marketContent
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 132)
                    }
                }
                .refreshable {
                    await refreshSelectedMode()
                }
                .tint(JourneyVisual.lime)

                Button(action: handleCreateTap) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 58, height: 58)
                        .background(JourneyVisual.coral)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
                        .shadow(color: JourneyVisual.coral.opacity(0.38), radius: 18, y: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(createAccessibilityLabel)
                .padding(.trailing, 22)
                .padding(.bottom, 116)
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedListing) { listing in
                ListingDetailView(listingId: listing.id, initialListing: listing)
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(eventId: event.id, initialEvent: event)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showCreateListing) {
                CreateListingView(onCreated: { Task { await servicesVM.refresh() } })
            }
            .sheet(isPresented: $showCreateItem) {
                CreateListingView(listingType: .item, onCreated: { Task { await itemsVM.refresh() } })
            }
            .sheet(isPresented: $showCreateEvent) {
                CreateEventView(onCreated: { Task { await eventsVM.refresh() } })
            }
            .sheet(isPresented: $showAuth) {
                AuthEntryView(showsCloseButton: true) { showAuth = false }
                    .environment(\.locale, appContainer.currentLocale)
                    .environmentObject(appContainer)
                    .environmentObject(lockManager)
                    .environmentObject(sessionManager)
            }
            .fullScreenCover(isPresented: $showExperts) {
                NavigationStack { ExpertsDirectoryView() }
                    .environmentObject(appContainer)
            }
            .fullScreenCover(isPresented: $showInbox) {
                ChatInboxView()
                    .environmentObject(appContainer)
            }
            .alert("journey.marketplace.calendar".localized, isPresented: Binding(
                get: { calendarMessage != nil },
                set: { if !$0 { calendarMessage = nil } }
            )) {
                Button("common.ok".localized) { calendarMessage = nil }
            } message: {
                Text(calendarMessage ?? "")
            }
            .task {
                await loadSelectedMode()
                if sessionManager.isAuthenticated { await appContainer.chatStore.start() }
            }
            .onAppear {
                #if DEBUG
                if let raw = UserDefaults.standard.string(forKey: "screenshotMarketMode"),
                   let mode = JourneyMarketMode(rawValue: raw) {
                    selectedMode = mode
                    loadSelectedModeIfNeeded()
                }
                #endif
            }
            .onChange(of: sessionManager.isAuthenticated) { _, authenticated in
                guard authenticated else { return }
                if pendingCreate {
                    pendingCreate = false
                    showAuth = false
                    presentCreateFlow()
                } else if pendingInbox {
                    pendingInbox = false
                    showAuth = false
                    showInbox = true
                }
            }
            .onChange(of: selectedMode) { _, _ in
                loadSelectedModeIfNeeded()
            }
            #if DEBUG
            .onChange(of: servicesVM.listings) { _, listings in
                guard ProcessInfo.processInfo.arguments.contains("--screenshot-open-first-listing"),
                      selectedListing == nil,
                      let first = listings.first else { return }
                selectedListing = first
            }
            #endif
        }
        .featureOnboarding(.marketplace)
        .accessibilityIdentifier("marketplace.screen")
    }

    /// Continues the hero photo above the fold so pull-to-refresh never reveals a flat black slab.
    private var marketOverscrollBackdrop: some View {
        VStack(spacing: 0) {
            ZStack {
                Image(heroImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .clipped()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.38),
                        Color.black.opacity(0.18),
                        JourneyVisual.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: 300)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var marketHero: some View {
        ZStack(alignment: .bottomLeading) {
            Image(heroImageName)
                .resizable()
                .scaledToFill()
                .frame(height: 258)
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.14), .black.opacity(0.26), JourneyVisual.black],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 15) {
                Text(heroTitle)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 4)

                MarketModeSelector(selection: $selectedMode) { loadSelectedModeIfNeeded() }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .frame(height: 258)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 10) {
                Button { showExperts = true } label: {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.black.opacity(0.5))
                        .background(.ultraThinMaterial.opacity(0.65))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("experts.section.title".localized)

                Button {
                    guard sessionManager.isAuthenticated else {
                        pendingInbox = true
                        showAuth = true
                        return
                    }
                    showInbox = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.black.opacity(0.5))
                            .background(.ultraThinMaterial.opacity(0.65))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                        if appContainer.chatStore.unreadCount > 0 {
                            Text("\(min(appContainer.chatStore.unreadCount, 99))")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.black)
                                .frame(minWidth: 21, minHeight: 21)
                                .background(JourneyVisual.lime)
                                .clipShape(Circle())
                                .offset(x: 3, y: -3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("chat.accessibility.inbox".localized(with: appContainer.chatStore.unreadCount))
            }
            .padding(.top, 52)
            .padding(.trailing, 18)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var filters: some View {
        switch selectedMode {
        case .services:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    MarketFilterChip(title: "common.all".localized, icon: nil, selected: servicesVM.selectedCategory == nil) {
                        servicesVM.selectedCategory = nil
                        Task { await servicesVM.applyFilters() }
                    }
                    ForEach(serviceFilters, id: \.0) { category, title in
                        MarketFilterChip(title: title, icon: category.icon, selected: servicesVM.selectedCategory == category) {
                            servicesVM.selectedCategory = category
                            Task { await servicesVM.applyFilters() }
                        }
                    }
                }
            }
        case .items:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    MarketFilterChip(title: "common.all".localized, icon: nil, selected: itemsVM.selectedItemCategory == nil) {
                        itemsVM.selectedItemCategory = nil
                        Task { await itemsVM.applyFilters() }
                    }
                    ForEach(itemFilters, id: \.0) { category, title in
                        MarketFilterChip(title: title, icon: category.icon, selected: itemsVM.selectedItemCategory == category) {
                            itemsVM.selectedItemCategory = category
                            Task { await itemsVM.applyFilters() }
                        }
                    }
                }
            }
        case .events:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    MarketFilterChip(title: "common.all".localized, icon: nil, selected: eventsVM.selectedCategory == nil) {
                        eventsVM.selectedCategory = nil
                        Task { await eventsVM.applyFilters() }
                    }
                    ForEach(eventFilters, id: \.0) { category, title in
                        MarketFilterChip(title: title, icon: category.icon, selected: eventsVM.selectedCategory == category) {
                            eventsVM.selectedCategory = category
                            Task { await eventsVM.applyFilters() }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var marketContent: some View {
        switch selectedMode {
        case .services: servicesContent
        case .items: itemsContent
        case .events: eventsContent
        }
    }

    private var servicesContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if servicesVM.isLoading && servicesVM.listings.isEmpty {
                MarketLoadingView(title: "journey.marketplace.services.loading".localized)
            } else if servicesVM.filteredListings.isEmpty {
                MarketEmptyCard(
                    icon: "person.2.badge.plus",
                    title: "journey.marketplace.services.empty_title".localized,
                    subtitle: "journey.marketplace.services.empty_subtitle".localized,
                    actionTitle: "journey.marketplace.services.add_action".localized,
                    action: handleCreateTap
                )
            } else {
                sectionHeader(
                    "journey.marketplace.recommended".localized,
                    trailing: servicesVM.isShowingStaleData ? "journey.marketplace.offline_data".localized : "journey.marketplace.verified_profiles".localized
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(spotlightServices) { listing in
                            JourneyServiceSpotlightCard(
                                listing: listing,
                                isSaved: appContainer.savedItems.isListingSaved(listing.id),
                                openAction: { selectedListing = listing },
                                saveAction: { appContainer.savedItems.toggleListing(listing.id) }
                            )
                            .containerRelativeFrame(.horizontal, count: 10, span: 8, spacing: 12)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)

                sectionHeader("journey.marketplace.all_services".localized, trailing: "\(servicesVM.filteredListings.count)")

                serviceMosaic(Array(servicesVM.filteredListings.prefix(12)))
            }
        }
    }

    private func serviceMosaic(_ listings: [ServiceListing]) -> some View {
        let indexed = Array(listings.enumerated())
        let left = indexed.filter { $0.offset.isMultiple(of: 2) }
        let right = indexed.filter { !$0.offset.isMultiple(of: 2) }

        return HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                ForEach(left, id: \.element.id) { index, listing in
                    JourneyServiceMosaicCard(
                        listing: listing,
                        isSaved: appContainer.savedItems.isListingSaved(listing.id),
                        height: index.isMultiple(of: 4) ? 276 : 222,
                        openAction: { selectedListing = listing },
                        saveAction: { appContainer.savedItems.toggleListing(listing.id) }
                    )
                }
            }

            VStack(spacing: 10) {
                ForEach(right, id: \.element.id) { index, listing in
                    JourneyServiceMosaicCard(
                        listing: listing,
                        isSaved: appContainer.savedItems.isListingSaved(listing.id),
                        height: index.isMultiple(of: 4) ? 222 : 276,
                        openAction: { selectedListing = listing },
                        saveAction: { appContainer.savedItems.toggleListing(listing.id) }
                    )
                }
            }
        }
    }

    private var itemsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if itemsVM.isLoading && itemsVM.listings.isEmpty {
                MarketLoadingView(title: "journey.marketplace.items.loading".localized)
            } else if let featuredItem {
                JourneyGoodsFeatureCard(
                    listing: featuredItem,
                    isSaved: appContainer.savedItems.isListingSaved(featuredItem.id),
                    open: { selectedListing = featuredItem },
                    save: { appContainer.savedItems.toggleListing(featuredItem.id) }
                )

                sectionHeader("journey.marketplace.more_nearby".localized, trailing: itemsVM.isShowingStaleData ? "journey.marketplace.offline_data".localized : nil)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    ForEach(remainingItems.prefix(8)) { listing in
                        Button { selectedListing = listing } label: {
                            JourneyGoodsGridCard(
                                listing: listing,
                                isSaved: appContainer.savedItems.isListingSaved(listing.id),
                                save: { appContainer.savedItems.toggleListing(listing.id) }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                MarketEmptyCard(
                    icon: "shippingbox.fill",
                    title: "journey.marketplace.items.empty_title".localized,
                    subtitle: "journey.marketplace.items.empty_subtitle".localized,
                    actionTitle: "journey.marketplace.items.add_action".localized,
                    action: handleCreateTap
                )
            }
        }
    }

    private var eventsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if eventsVM.isLoading && eventsVM.events.isEmpty {
                MarketLoadingView(title: "journey.marketplace.events.loading".localized)
            } else if let featuredEvent {
                JourneyEventFeatureCard(
                    event: featuredEvent,
                    isSaved: appContainer.savedItems.isEventSaved(featuredEvent.id),
                    open: { selectedEvent = featuredEvent },
                    save: { appContainer.savedItems.toggleEvent(featuredEvent.id) },
                    addToCalendar: {
                        Task { await addToCalendar(featuredEvent) }
                    }
                )

                sectionHeader("journey.marketplace.coming_soon".localized, trailing: eventsVM.isShowingStaleData ? "journey.marketplace.offline_data".localized : nil)

                ForEach(remainingEvents.prefix(6)) { event in
                    Button { selectedEvent = event } label: {
                        JourneyUpcomingEventRow(
                            event: event,
                            isSaved: appContainer.savedItems.isEventSaved(event.id),
                            save: { appContainer.savedItems.toggleEvent(event.id) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                MarketEmptyCard(
                    icon: "calendar.badge.plus",
                    title: "journey.marketplace.events.empty_title".localized,
                    subtitle: "journey.marketplace.events.empty_subtitle".localized,
                    actionTitle: "journey.marketplace.events.add_action".localized,
                    action: handleCreateTap
                )
            }
        }
    }

    private func sectionHeader(_ title: String, trailing: String?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(JourneyVisual.lime)
            }
        }
        .padding(.top, 2)
    }

    private var featuredService: ServiceListing? {
        servicesVM.filteredListings.sorted { lhs, rhs in
            if lhs.isVerified != rhs.isVerified { return lhs.isVerified }
            if lhs.isExpert != rhs.isExpert { return lhs.isExpert }
            return lhs.viewCount > rhs.viewCount
        }.first
    }

    private var spotlightServices: [ServiceListing] {
        Array(servicesVM.filteredListings.sorted { lhs, rhs in
            if lhs.isVerified != rhs.isVerified { return lhs.isVerified }
            if lhs.isExpert != rhs.isExpert { return lhs.isExpert }
            if lhs.isFeatured != rhs.isFeatured { return lhs.isFeatured }
            return lhs.viewCount > rhs.viewCount
        }.prefix(5))
    }

    private var remainingServices: [ServiceListing] {
        guard let id = featuredService?.id else { return servicesVM.filteredListings }
        return servicesVM.filteredListings.filter { $0.id != id }
    }

    private var featuredItem: ServiceListing? {
        itemsVM.filteredListings.sorted { lhs, rhs in
            if lhs.isVerified != rhs.isVerified { return lhs.isVerified }
            return (lhs.updatedAt ?? lhs.createdAt ?? .distantPast) > (rhs.updatedAt ?? rhs.createdAt ?? .distantPast)
        }.first
    }

    private var remainingItems: [ServiceListing] {
        guard let id = featuredItem?.id else { return itemsVM.filteredListings }
        return itemsVM.filteredListings.filter { $0.id != id }
    }

    private var featuredEvent: EventListing? { eventsVM.filteredEvents.first }

    private var remainingEvents: [EventListing] {
        guard let id = featuredEvent?.id else { return eventsVM.filteredEvents }
        return eventsVM.filteredEvents.filter { $0.id != id }
    }

    private var searchBinding: Binding<String> {
        switch selectedMode {
        case .services: return $servicesVM.searchText
        case .items: return $itemsVM.searchText
        case .events: return $eventsVM.searchText
        }
    }

    private var searchPrompt: String {
        switch selectedMode {
        case .services: return "journey.marketplace.search.services".localized
        case .items: return "journey.marketplace.search.items".localized
        case .events: return "events.search".localized
        }
    }

    private var heroTitle: String {
        switch selectedMode {
        case .services: return "journey.marketplace.hero.services".localized
        case .items: return "journey.marketplace.hero.items".localized
        case .events: return "journey.marketplace.hero.events".localized
        }
    }

    private var heroImageName: String {
        switch selectedMode {
        case .services: return "cityhub-zurich-oldtown"
        case .items: return "cityhub-zurich-viadukt"
        case .events: return "cityhub-zurich-sechselaeutenplatz"
        }
    }

    private var createAccessibilityLabel: String {
        switch selectedMode {
        case .services: return "journey.marketplace.services.add_action".localized
        case .items: return "journey.marketplace.items.add_action".localized
        case .events: return "journey.marketplace.events.add_action".localized
        }
    }

    private let serviceFilters: [(ServiceCategory, String)] = [
        (.documents, "journey.marketplace.filter.documents".localized),
        (.translation, "journey.marketplace.filter.translation".localized),
        (.legal, "journey.marketplace.filter.legal".localized),
        (.moving, "journey.marketplace.filter.moving".localized)
    ]
    private let itemFilters: [(ItemCategory, String)] = [
        (.furniture, "journey.marketplace.filter.furniture".localized),
        (.electronics, "journey.marketplace.filter.electronics".localized),
        (.kids, "journey.marketplace.filter.kids".localized),
        (.free, "journey.marketplace.filter.free".localized)
    ]
    private let eventFilters: [(EventCategory, String)] = [
        (.community, "events.category.community".localized),
        (.education, "events.category.education".localized),
        (.kids, "journey.marketplace.filter.kids".localized),
        (.culture, "events.category.culture".localized)
    ]

    private func handleCreateTap() {
        guard sessionManager.isAuthenticated else {
            pendingCreate = true
            showAuth = true
            return
        }
        presentCreateFlow()
    }

    private func presentCreateFlow() {
        switch selectedMode {
        case .services: showCreateListing = true
        case .items: showCreateItem = true
        case .events: showCreateEvent = true
        }
    }

    private func loadSelectedModeIfNeeded() {
        Task {
            await loadSelectedMode()
        }
    }

    private func loadSelectedMode() async {
        switch selectedMode {
        case .services where servicesVM.listings.isEmpty: await servicesVM.loadListings(refresh: true)
        case .items where itemsVM.listings.isEmpty: await itemsVM.loadListings(refresh: true)
        case .events where eventsVM.events.isEmpty: await eventsVM.loadEvents(refresh: true)
        default: break
        }
    }

    private func refreshSelectedMode() async {
        switch selectedMode {
        case .services: await servicesVM.refresh()
        case .items: await itemsVM.refresh()
        case .events: await eventsVM.refresh()
        }
    }

    @MainActor
    private func addToCalendar(_ event: EventListing) async {
        do {
            try await calendarService.add(event)
            calendarMessage = "journey.marketplace.event_added_to_calendar".localized
        } catch {
            calendarMessage = error.localizedDescription
        }
    }
}

private enum JourneyMarketMode: String, CaseIterable, Identifiable {
    case services
    case items
    case events

    var id: String { rawValue }
    var title: String {
        switch self {
        case .services: return "journey.marketplace.mode.services".localized
        case .items: return "journey.marketplace.mode.items".localized
        case .events: return "journey.marketplace.mode.events".localized
        }
    }
}

private struct MarketModeSelector: View {
    @Binding var selection: JourneyMarketMode
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(JourneyMarketMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) { selection = mode }
                    onChange()
                } label: {
                    Text(mode.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(selection == mode ? .black : .white.opacity(0.76))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(selection == mode ? JourneyVisual.lime : Color.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.48))
        .background(.ultraThinMaterial.opacity(0.55))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
    }
}

private struct MarketSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.58))
            TextField(prompt, text: $text)
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("journey.marketplace.clear_search".localized)
            }
        }
        .font(.system(size: 15, weight: .medium))
        .padding(.horizontal, 15)
        .frame(height: 46)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
    }
}

private struct MarketFilterChip: View {
    let title: String
    let icon: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(selected ? .black : .white.opacity(0.74))
            .padding(.horizontal, 13)
            .frame(height: 36)
            .background(selected ? JourneyVisual.lime : Color.white.opacity(0.07))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(selected ? 0 : 0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct JourneyServiceFeatureCard: View {
    let listing: ServiceListing?
    let openAction: () -> Void
    let saveAction: () -> Void

    var body: some View {
        Button(action: openAction) {
            ZStack(alignment: .bottomLeading) {
                JourneyRemoteImage(url: listing?.primaryImageURL, fallbackAsset: "journey-market-consultant")
                    .frame(height: 330)
                    .frame(maxWidth: .infinity)
                    .clipped()

                LinearGradient(colors: [.clear, .black.opacity(0.2), .black.opacity(0.96)], startPoint: .top, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Label(listing?.expertLanguages.first?.uppercased() ?? "journey.marketplace.language_uk".localized, systemImage: "globe")
                            .marketPill(background: Color.black.opacity(0.62))
                        Spacer()
                        if listing?.isVerified ?? true {
                            Label("map.verified".localized, systemImage: "checkmark.seal.fill")
                                .marketPill(foreground: .black, background: JourneyVisual.lime)
                        } else {
                            Text("journey.marketplace.community".localized)
                                .marketPill(background: Color.black.opacity(0.62))
                        }
                    }

                    Spacer()

                    Text(listing?.title ?? "journey.marketplace.sample_service_title".localized)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(listing?.authorName ?? "journey.marketplace.sample_author".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.72))

                    HStack(spacing: 16) {
                        Label(listing.map(\.freshnessText) ?? "journey.marketplace.sample_freshness".localized, systemImage: "clock.badge.checkmark")
                        Label(responseText, systemImage: "message")
                        Spacer()
                        Text(listing?.priceDisplay ?? "journey.marketplace.sample_price".localized)
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.82))
                }
                .padding(16)

                Button(action: saveAction) {
                    Image(systemName: "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.64))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var responseText: String {
        guard let hours = listing?.responseTimeHours else { return "journey.marketplace.responds_default".localized }
        return hours < 24 ? "journey.marketplace.responds_hours".localized(with: hours) : "journey.marketplace.responds_within_day".localized
    }
}

private struct JourneyServiceSpotlightCard: View {
    let listing: ServiceListing
    let isSaved: Bool
    let openAction: () -> Void
    let saveAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: openAction) {
                ZStack(alignment: .bottomLeading) {
                    JourneyRemoteImage(url: listing.primaryImageURL, fallbackAsset: listing.marketplaceFallbackAsset)
                        .frame(maxWidth: .infinity)
                        .frame(height: 324)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.16), .black.opacity(0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 9) {
                        Spacer()

                        Text(listing.categoryDisplayName.uppercased())
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(0.7)
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(JourneyVisual.lime)
                            .clipShape(Capsule())

                        Text(listing.title)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 7) {
                            Text(listing.authorName)
                                .fontWeight(.bold)
                            Circle()
                                .fill(.white.opacity(0.42))
                                .frame(width: 3, height: 3)
                            Label(listing.canton, systemImage: "mappin")
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(1)

                        HStack(spacing: 10) {
                            Label(listing.freshnessText, systemImage: "clock.badge.checkmark")
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(listing.priceDisplay ?? "journey.marketplace.negotiable_price".localized)
                                .fontWeight(.black)
                                .foregroundColor(.white)
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.68))
                    }
                    .padding(16)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                if listing.isVerified {
                    Label("map.verified".localized, systemImage: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(.white)
                        .clipShape(Capsule())
                }

                Button(action: saveAction) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isSaved ? .black : .white)
                        .frame(width: 42, height: 42)
                        .background(isSaved ? JourneyVisual.lime : Color.black.opacity(0.58))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSaved ? "journey.marketplace.remove_saved".localized : "journey.marketplace.save".localized)
            }
            .padding(13)
        }
        .frame(height: 324)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.26), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.34), radius: 22, y: 12)
    }
}

private struct JourneyServiceMosaicCard: View {
    let listing: ServiceListing
    let isSaved: Bool
    let height: CGFloat
    let openAction: () -> Void
    let saveAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: openAction) {
                ZStack(alignment: .bottomLeading) {
                    JourneyRemoteImage(url: listing.primaryImageURL, fallbackAsset: listing.marketplaceFallbackAsset)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .clipped()

                    LinearGradient(
                        colors: [.black.opacity(0.04), .black.opacity(0.12), .black.opacity(0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 7) {
                        Spacer()

                        HStack(spacing: 5) {
                            Image(systemName: listing.categoryIcon)
                            Text(listing.categoryDisplayName.uppercased())
                                .lineLimit(1)
                        }
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())

                        Text(listing.title)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)

                        Text(listing.authorName)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Label(listing.canton == "all" ? "CH" : listing.canton, systemImage: "mappin")
                            Spacer(minLength: 2)
                            Text(listing.priceDisplay ?? "journey.marketplace.negotiable_price".localized)
                                .fontWeight(.black)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.64))
                    }
                    .padding(13)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("marketplace.open".localized)

            Button(action: saveAction) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSaved ? .black : .white.opacity(0.72))
                    .frame(width: 38, height: 38)
                    .background(isSaved ? JourneyVisual.lime : Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel(isSaved ? "journey.marketplace.remove_saved".localized : "journey.marketplace.save".localized)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.22), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 16, y: 9)
    }
}

private struct JourneyGoodsFeatureCard: View {
    let listing: ServiceListing
    let isSaved: Bool
    let open: () -> Void
    let save: () -> Void

    var body: some View {
        Button(action: open) {
            ZStack(alignment: .bottomLeading) {
                JourneyRemoteImage(url: listing.primaryImageURL, fallbackAsset: "cityhub-zurich-viadukt")
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(listing.condition?.displayName ?? "journey.marketplace.condition_unspecified".localized)
                            .marketPill(background: Color.black.opacity(0.64))
                        Spacer()
                        Text(listing.isVerified ? "journey.marketplace.verified_seller".localized : "journey.marketplace.community".localized)
                            .marketPill(foreground: listing.isVerified ? .black : .white, background: listing.isVerified ? JourneyVisual.lime : Color.black.opacity(0.64))
                    }
                    Spacer()
                    Text(listing.priceDisplay ?? "journey.marketplace.free".localized)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(listing.title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    HStack {
                        Label(listing.canton, systemImage: "mappin")
                        Spacer()
                        Label(listing.freshnessText, systemImage: "clock")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                }
                .padding(15)
                Button(action: save) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .foregroundColor(isSaved ? JourneyVisual.lime : .white)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.58))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct JourneyGoodsGridCard: View {
    let listing: ServiceListing
    let isSaved: Bool
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                JourneyRemoteImage(url: listing.primaryImageURL, fallbackAsset: "cityhub-zurich-kreis4")
                    .frame(height: 112)
                    .frame(maxWidth: .infinity)
                    .clipped()
                Button(action: save) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSaved ? JourneyVisual.lime : .white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.56))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(7)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(listing.priceDisplay ?? "journey.marketplace.free".localized)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(JourneyVisual.lime)
                Text(listing.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                HStack {
                    Text(listing.canton)
                    Spacer()
                    Text(shortFreshness(listing.freshnessDate))
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.48))
            }
            .padding(10)
        }
        .background(Color.white.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func shortFreshness(_ date: Date?) -> String {
        guard let date else { return "journey.marketplace.no_date".localized }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

private struct JourneyEventFeatureCard: View {
    @Environment(\.locale) private var locale
    let event: EventListing
    let isSaved: Bool
    let open: () -> Void
    let save: () -> Void
    let addToCalendar: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(eventImageName)
                .resizable()
                .scaledToFill()
                .frame(height: 270)
                .frame(maxWidth: .infinity)
                .clipped()
            LinearGradient(colors: [.black.opacity(0.06), .black.opacity(0.16), .black.opacity(0.94)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(spacing: -2) {
                        Text(dayText).font(.system(size: 24, weight: .bold, design: .rounded))
                        Text(monthText).font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(width: 54, height: 58)
                    .background(JourneyVisual.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Spacer()
                    Button(action: save) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .foregroundColor(isSaved ? JourneyVisual.lime : .white)
                            .frame(width: 42, height: 42)
                            .background(Color.black.opacity(0.56))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button(action: open) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Label(scheduleAndPlace, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.74))
                        Label(eventTrustText, systemImage: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(JourneyVisual.lime)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Button(action: addToCalendar) {
                        Label("journey.marketplace.add_to_calendar".localized, systemImage: "calendar.badge.plus")
                            .marketActionButton()
                    }
                    .buttonStyle(.plain)
                    ShareLink(item: shareText) {
                        Label("common.share".localized, systemImage: "square.and.arrow.up")
                            .marketActionButton()
                    }
                }
            }
            .padding(15)
        }
        .frame(height: 270)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 1))
    }

    private var date: Date { event.startsAt ?? Date() }
    private var dayText: String { date.formatted(.dateTime.day().locale(locale)) }
    private var monthText: String { date.formatted(.dateTime.month(.abbreviated).locale(locale)).uppercased() }
    private var scheduleAndPlace: String {
        let schedule = date.formatted(.dateTime.weekday(.abbreviated).hour().minute().locale(locale))
        let place = event.city.isEmpty == false ? event.city : "Zürich"
        return "\(schedule) · \(place)"
    }
    private var eventTrustText: String {
        event.isVerified ? "journey.marketplace.verified_organizer".localized(with: event.freshnessText) : "journey.marketplace.moderated_by_sweezy".localized(with: event.freshnessText)
    }
    private var shareText: String { "\(event.title) — \(scheduleAndPlace)" }
    private var eventImageName: String {
        switch event.category {
        case .community, .career: return "cityhub-zurich-viadukt"
        case .kids, .sports: return "cityhub-zurich-lake"
        case .education, .language: return "cityhub-zurich-landesmuseum"
        case .legal, .health: return "cityhub-zurich-oldtown"
        case .culture: return "cityhub-zurich-opernhaus"
        case .other: return "cityhub-zurich-sechselaeutenplatz"
        }
    }
}

private struct JourneyUpcomingEventRow: View {
    @Environment(\.locale) private var locale
    let event: EventListing
    let isSaved: Bool
    let save: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: -2) {
                Text((event.startsAt ?? Date()).formatted(.dateTime.day().locale(locale)))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text((event.startsAt ?? Date()).formatted(.dateTime.month(.abbreviated).locale(locale)).uppercased())
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(width: 50, height: 55)
            .background(JourneyVisual.lime)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text("\(event.city) · \(event.organizerName)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
                Text(event.isVerified ? "journey.marketplace.organizer_verified".localized : "journey.marketplace.moderated_by_sweezy_short".localized)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(JourneyVisual.lime)
            }
            Spacer()
            Button(action: save) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .foregroundColor(isSaved ? JourneyVisual.lime : .white.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

private struct MarketLoadingView: View {
    let title: String
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().tint(JourneyVisual.lime)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.66))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct MarketEmptyCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(JourneyVisual.lime)
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.58))
                .multilineTextAlignment(.center)
            Button(actionTitle, action: action)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(JourneyVisual.lime)
                .clipShape(Capsule())
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

private extension View {
    func marketPill(foreground: Color = .white, background: Color) -> some View {
        self
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(foreground)
            .padding(.horizontal, 9)
            .frame(height: 27)
            .background(background)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
    }

    func marketActionButton() -> some View {
        self
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(Color.black.opacity(0.64))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
    }
}
