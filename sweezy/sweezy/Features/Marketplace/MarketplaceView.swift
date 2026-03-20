import SwiftUI

struct MarketplaceView: View {
    @StateObject private var vm: MarketplaceViewModel
    @State private var showCreateSheet = false
    @State private var selectedListing: ServiceListing?
    @State private var showCantonPicker = false

    init(initialCategory: ServiceCategory? = nil, initialCanton: String? = nil) {
        _vm = StateObject(wrappedValue: MarketplaceViewModel(initialCategory: initialCategory, initialCanton: initialCanton))
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
                    showCreateSheet = true
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
            .searchable(text: $vm.searchText, prompt: Text("marketplace.search".localized))
            .refreshable { await vm.refresh() }
            .sheet(item: $selectedListing) { listing in
                ListingDetailView(listingId: listing.id)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateListingView(onCreated: {
                    Task { await vm.refresh() }
                })
            }
            .sheet(isPresented: $showCantonPicker) {
                cantonPickerSheet
            }
            .task { await vm.loadListings(refresh: true) }
        }
    }

    // MARK: - Filters

    private var filtersSection: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Canton filter button
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
                                .fill(vm.selectedCanton != nil
                                      ? Theme.Colors.primary.opacity(0.2)
                                      : Theme.Colors.adaptiveCard)
                        )
                        .overlay(
                            Capsule()
                                .stroke(vm.selectedCanton != nil
                                        ? Theme.Colors.primary.opacity(0.4)
                                        : Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: 1)
                        )
                        .foregroundColor(vm.selectedCanton != nil ? Theme.Colors.primary : Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)

                    // Category: "all"
                    MapFilterChip(
                        title: "common.all".localized,
                        isSelected: vm.selectedCategory == nil,
                        color: Theme.Colors.primary
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        vm.selectedCategory = nil
                        Task { await vm.applyFilters() }
                    }

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
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)

            // Offline banner
            if vm.error != nil, !vm.listings.isEmpty, let age = vm.cacheAgeText {
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
            if vm.isLoading && vm.listings.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            ListingSkeletonCard()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            } else if vm.filteredListings.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.filteredListings) { listing in
                            ListingCardView(listing: listing)
                                .onTapGesture {
                                    selectedListing = listing
                                }
                                .onAppear {
                                    if listing.id == vm.filteredListings.last?.id {
                                        Task { await vm.loadMore() }
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
            }
        }
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

    // MARK: - Canton Picker

    private var cantonLabel: String {
        if let code = vm.selectedCanton {
            return SwissCanton.all.first { $0.code == code }?.name ?? code
        }
        return "marketplace.canton_filter".localized
    }

    private var cantonPickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    vm.selectedCanton = nil
                    showCantonPicker = false
                    Task { await vm.applyFilters() }
                } label: {
                    HStack {
                        Text("marketplace.canton.all_cantons".localized)
                        Spacer()
                        if vm.selectedCanton == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                }

                ForEach(SwissCanton.all.dropFirst(), id: \.code) { canton in
                    Button {
                        vm.selectedCanton = canton.code
                        showCantonPicker = false
                        Task { await vm.applyFilters() }
                    } label: {
                        HStack {
                            Text("\(canton.code) — \(canton.name)")
                            Spacer()
                            if vm.selectedCanton == canton.code {
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
