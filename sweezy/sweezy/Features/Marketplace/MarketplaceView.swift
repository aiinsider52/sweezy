import SwiftUI

struct MarketplaceView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var vm: MarketplaceViewModel
    @StateObject private var eventsVM: EventsViewModel
    @State private var selectedMode: MarketplaceMode = .services
    @State private var showCreateSheet = false
    @State private var showCreateEventSheet = false
    @State private var showAuthEntry = false
    @State private var showMyListings = false
    @State private var showMyEvents = false
    @State private var pendingCreateAfterAuth = false
    @State private var pendingCabinetAfterAuth = false
    @State private var pendingEventCreateAfterAuth = false
    @State private var pendingEventCabinetAfterAuth = false
    @State private var selectedListing: ServiceListing?
    @State private var selectedEvent: EventListing?
    @State private var showCantonPicker = false

    init(initialCategory: ServiceCategory? = nil, initialCanton: String? = nil) {
        _vm = StateObject(wrappedValue: MarketplaceViewModel(initialCategory: initialCategory, initialCanton: initialCanton))
        _eventsVM = StateObject(wrappedValue: EventsViewModel(initialCanton: initialCanton))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AdaptivePageBackground()

                VStack(spacing: 0) {
                    filtersSection
                    contentSection
                }

                // FAB
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    handleCreateTap()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [Theme.Colors.primary, Theme.Colors.primaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 12, y: 6)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 16)
                .accessibilityLabel("marketplace.create_listing".localized)
            }
            .navigationTitle("marketplace.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        handleCabinetTap()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: sessionManager.isAuthenticated ? "person.crop.circle.fill" : "person.crop.circle")
                                .font(.system(size: 22))
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                    .accessibilityLabel(selectedMode == .services ? "marketplace.my_listings".localized : "events.my_events".localized)
                }
            }
            .featureOnboarding(.marketplace)
            .searchable(text: activeSearchBinding, prompt: Text(searchPrompt))
            .refreshable { await refreshActiveMode() }
            .sheet(item: $selectedListing) { listing in
                ListingDetailView(listingId: listing.id)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(eventId: event.id)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateListingView(onCreated: {
                    Task { await vm.refresh() }
                })
            }
            .sheet(isPresented: $showCreateEventSheet) {
                CreateEventView(onCreated: {
                    Task { await eventsVM.refresh() }
                })
            }
            .sheet(isPresented: $showMyListings) {
                MyListingsView(onListingsChanged: {
                    Task { await vm.refresh() }
                })
            }
            .sheet(isPresented: $showMyEvents) {
                MyEventsView(onEventsChanged: {
                    Task { await eventsVM.refresh() }
                })
            }
            .sheet(isPresented: $showAuthEntry) {
                AuthEntryView(
                    showsCloseButton: true,
                    onComplete: {
                        showAuthEntry = false
                    }
                )
                .environment(\.locale, appContainer.currentLocale)
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
            }
            .sheet(isPresented: $showCantonPicker) {
                cantonPickerSheet
            }
            .task { await vm.loadListings(refresh: true) }
            .task { await eventsVM.loadEvents(refresh: true) }
            .onChange(of: selectedMode) { _, mode in
                Task {
                    if mode == .services, vm.listings.isEmpty {
                        await vm.loadListings(refresh: true)
                    } else if mode == .events, eventsVM.events.isEmpty {
                        await eventsVM.loadEvents(refresh: true)
                    }
                }
            }
            .onChange(of: sessionManager.isAuthenticated) { _, isAuthenticated in
                showAuthEntry = false
                if isAuthenticated, pendingCreateAfterAuth {
                    pendingCreateAfterAuth = false
                    showCreateSheet = true
                }
                if isAuthenticated, pendingCabinetAfterAuth {
                    pendingCabinetAfterAuth = false
                    showMyListings = true
                }
                if isAuthenticated, pendingEventCreateAfterAuth {
                    pendingEventCreateAfterAuth = false
                    showCreateEventSheet = true
                }
                if isAuthenticated, pendingEventCabinetAfterAuth {
                    pendingEventCabinetAfterAuth = false
                    showMyEvents = true
                }
            }
            .onChange(of: showAuthEntry) { _, isPresented in
                if !isPresented, !sessionManager.isAuthenticated {
                    pendingCreateAfterAuth = false
                    pendingCabinetAfterAuth = false
                    pendingEventCreateAfterAuth = false
                    pendingEventCabinetAfterAuth = false
                }
            }
        }
    }

    // MARK: - Filters

    private var filtersSection: some View {
        VStack(spacing: 8) {
            Picker("marketplace.content_mode".localized, selection: $selectedMode) {
                ForEach(MarketplaceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        showCantonPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                            Text(cantonLabel)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(activeSelectedCanton != nil
                                      ? Theme.Colors.primary.opacity(0.2)
                                      : Theme.Colors.adaptiveCard)
                        )
                        .overlay(
                            Capsule()
                                .stroke(activeSelectedCanton != nil
                                        ? Theme.Colors.primary.opacity(0.4)
                                        : Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: 1)
                        )
                        .foregroundColor(activeSelectedCanton != nil ? Theme.Colors.primary : Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)

                    MapFilterChip(
                        title: "common.all".localized,
                        isSelected: selectedMode == .services ? vm.selectedCategory == nil : eventsVM.selectedCategory == nil,
                        color: Theme.Colors.primary
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if selectedMode == .services {
                            vm.selectedCategory = nil
                        } else {
                            eventsVM.selectedCategory = nil
                        }
                        Task { await applyActiveFilters() }
                    }

                    if selectedMode == .services {
                        ForEach(ServiceCategory.allCases) { cat in
                            MarketplaceCategoryChip(
                                category: cat,
                                isSelected: vm.selectedCategory == cat
                            ) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                vm.selectedCategory = vm.selectedCategory == cat ? nil : cat
                                Task { await vm.applyFilters() }
                            }
                        }
                    } else {
                        ForEach(EventCategory.allCases) { cat in
                            EventCategoryChip(
                                category: cat,
                                isSelected: eventsVM.selectedCategory == cat
                            ) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                eventsVM.selectedCategory = eventsVM.selectedCategory == cat ? nil : cat
                                Task { await eventsVM.applyFilters() }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)

            if activeHasOfflineBanner, let age = activeCacheAgeText {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.caption2)
                    Text(age)
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.Colors.warning.opacity(0.85)))
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Content

    private var contentSection: some View {
        Group {
            if selectedMode == .services, vm.isLoading && vm.listings.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            ListingSkeletonCard()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            } else if selectedMode == .events, eventsVM.isLoading && eventsVM.events.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            ListingSkeletonCard()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            } else if selectedMode == .services, vm.filteredListings.isEmpty {
                emptyState
            } else if selectedMode == .events, eventsVM.filteredEvents.isEmpty {
                eventsEmptyState
            } else {
                ScrollView {
                    if selectedMode == .services {
                        servicesContent
                    } else {
                        eventsTimelineContent
                    }
                }
            }
        }
    }

    // MARK: - Services Content (Hero + Grid/List)

    private var servicesContent: some View {
        let listings = vm.filteredListings
        return LazyVStack(spacing: 12) {
            ForEach(Array(listings.enumerated()), id: \.element.id) { index, listing in
                Group {
                    if index == 0 {
                        HeroListingCardView(listing: listing)
                    } else if listing.resolvedImageURLs.isEmpty {
                        EmptyView() // handled in grid below
                    } else {
                        ListingCardView(listing: listing)
                    }
                }
                .onTapGesture {
                    selectedListing = listing
                }
                .onAppear {
                    if listing.id == listings.last?.id {
                        Task { await vm.loadMore() }
                    }
                }
            }

            // Grid section for listings without photos (skip first)
            let noPhotoListings = listings.dropFirst().filter { $0.resolvedImageURLs.isEmpty }
            if !noPhotoListings.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Array(noPhotoListings)) { listing in
                        CompactListingCardView(listing: listing)
                            .onTapGesture { selectedListing = listing }
                    }
                }
            }

            if vm.isLoading && !vm.listings.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 80)
    }

    // MARK: - Events Timeline Content

    private var eventsTimelineContent: some View {
        let grouped = groupedEvents
        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(grouped, id: \.label) { group in
                VStack(alignment: .leading, spacing: 10) {
                    // Section header
                    HStack(spacing: 8) {
                        Text(group.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(group.accentColor)
                        Rectangle()
                            .fill(group.accentColor.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 4)

                    ForEach(group.events) { event in
                        EventCardView(event: event)
                            .padding(.horizontal, 16)
                            .onTapGesture { selectedEvent = event }
                            .onAppear {
                                if event.id == eventsVM.filteredEvents.last?.id {
                                    Task { await eventsVM.loadMore() }
                                }
                            }
                    }
                }
            }

            if eventsVM.isLoading && !eventsVM.events.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding(.bottom, 80)
    }

    private struct EventGroup {
        let label: String
        let accentColor: Color
        let events: [EventListing]
    }

    private var groupedEvents: [EventGroup] {
        let events = eventsVM.filteredEvents
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let startOfNextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfToday)!
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfToday)!

        var today: [EventListing] = []
        var thisWeek: [EventListing] = []
        var nextWeek: [EventListing] = []
        var thisMonth: [EventListing] = []
        var later: [EventListing] = []

        for event in events {
            let date = event.startsAt ?? .distantFuture
            if date < startOfTomorrow {
                today.append(event)
            } else if date < startOfNextWeek {
                thisWeek.append(event)
            } else if date < calendar.date(byAdding: .weekOfYear, value: 2, to: startOfToday)! {
                nextWeek.append(event)
            } else if date < startOfNextMonth {
                thisMonth.append(event)
            } else {
                later.append(event)
            }
        }

        var result: [EventGroup] = []
        if !today.isEmpty { result.append(.init(label: "Сьогодні", accentColor: Theme.Colors.accent, events: today)) }
        if !thisWeek.isEmpty { result.append(.init(label: "Цього тижня", accentColor: Theme.Colors.primary, events: thisWeek)) }
        if !nextWeek.isEmpty { result.append(.init(label: "Наступного тижня", accentColor: .purple, events: nextWeek)) }
        if !thisMonth.isEmpty { result.append(.init(label: "Цього місяця", accentColor: .orange, events: thisMonth)) }
        if !later.isEmpty { result.append(.init(label: "Пізніше", accentColor: Theme.Colors.textSecondary, events: later)) }
        return result
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "storefront")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Colors.primary, Theme.Colors.primaryLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("marketplace.empty_title".localized)
                .font(.title3.bold())
                .foregroundColor(Theme.Colors.textPrimary)
            Text("marketplace.empty_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var eventsEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Theme.Colors.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("events.empty_title".localized)
                .font(.title3.bold())
                .foregroundColor(Theme.Colors.textPrimary)
            Text("events.empty_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Canton Picker

    private var cantonLabel: String {
        if let code = activeSelectedCanton {
            return SwissCanton.all.first { $0.code == code }?.name ?? code
        }
        return "marketplace.canton_filter".localized
    }

    private var cantonPickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    setActiveCanton(nil)
                    showCantonPicker = false
                    Task { await applyActiveFilters() }
                } label: {
                    HStack {
                        Text("marketplace.canton.all_cantons".localized)
                        Spacer()
                        if activeSelectedCanton == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                }

                ForEach(SwissCanton.all.dropFirst(), id: \.code) { canton in
                    Button {
                        setActiveCanton(canton.code)
                        showCantonPicker = false
                        Task { await applyActiveFilters() }
                    } label: {
                        HStack {
                            Text("\(canton.code) — \(canton.name)")
                            Spacer()
                            if activeSelectedCanton == canton.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.Colors.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("marketplace.select_canton".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { showCantonPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func handleCreateTap() {
        switch selectedMode {
        case .services:
            guard sessionManager.isAuthenticated else {
                pendingCreateAfterAuth = true
                showAuthEntry = true
                return
            }
            showCreateSheet = true
        case .events:
            guard sessionManager.isAuthenticated else {
                pendingEventCreateAfterAuth = true
                showAuthEntry = true
                return
            }
            showCreateEventSheet = true
        }
    }

    private func handleCabinetTap() {
        switch selectedMode {
        case .services:
            guard sessionManager.isAuthenticated else {
                pendingCabinetAfterAuth = true
                showAuthEntry = true
                return
            }
            showMyListings = true
        case .events:
            guard sessionManager.isAuthenticated else {
                pendingEventCabinetAfterAuth = true
                showAuthEntry = true
                return
            }
            showMyEvents = true
        }
    }

    private var activeSearchBinding: Binding<String> {
        Binding(
            get: { selectedMode == .services ? vm.searchText : eventsVM.searchText },
            set: { newValue in
                if selectedMode == .services {
                    vm.searchText = newValue
                } else {
                    eventsVM.searchText = newValue
                }
            }
        )
    }

    private var searchPrompt: String {
        selectedMode == .services ? "marketplace.search".localized : "events.search".localized
    }

    private var activeSelectedCanton: String? {
        selectedMode == .services ? vm.selectedCanton : eventsVM.selectedCanton
    }

    private var activeHasOfflineBanner: Bool {
        (selectedMode == .services && vm.isShowingStaleData && !vm.listings.isEmpty)
            || (selectedMode == .events && eventsVM.isShowingStaleData && !eventsVM.events.isEmpty)
    }

    private var activeCacheAgeText: String? {
        selectedMode == .services ? vm.cacheAgeText : eventsCacheAgeText
    }

    private var eventsCacheAgeText: String? {
        let ts = UserDefaults.standard.double(forKey: "events_cache_ts")
        guard ts > 0 else { return nil }
        let age = Date().timeIntervalSince1970 - ts
        if age < 60 { return "marketplace.updated_just_now".localized }
        return "marketplace.updated_minutes_ago".localized(with: Int(age / 60))
    }

    private func setActiveCanton(_ value: String?) {
        if selectedMode == .services {
            vm.selectedCanton = value
        } else {
            eventsVM.selectedCanton = value
        }
    }

    private func applyActiveFilters() async {
        if selectedMode == .services {
            await vm.applyFilters()
        } else {
            await eventsVM.applyFilters()
        }
    }

    private func refreshActiveMode() async {
        if selectedMode == .services {
            await vm.refresh()
        } else {
            await eventsVM.refresh()
        }
    }
}

private enum MarketplaceMode: String, CaseIterable, Identifiable {
    case services
    case events

    var id: String { rawValue }

    var title: String {
        switch self {
        case .services: return "marketplace.mode.services".localized
        case .events: return "marketplace.mode.events".localized
        }
    }
}

// MARK: - Category Chip

private struct MarketplaceCategoryChip: View {
    let category: ServiceCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                Text(category.displayName)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(
                        isSelected
                        ? category.color.opacity(0.25)
                        : Theme.Colors.adaptiveCard
                    )
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? category.color.opacity(0.4) : Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: 1)
            )
            .foregroundColor(isSelected ? category.color : Theme.Colors.textPrimary)
        }
        .buttonStyle(.plain)
    }
}

private struct EventCategoryChip: View {
    let category: EventCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                Text(category.displayName)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected ? category.color.opacity(0.16) : Theme.Colors.adaptiveCard)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? category.color.opacity(0.5) : Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: 1)
            )
            .foregroundColor(isSelected ? category.color : Theme.Colors.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
