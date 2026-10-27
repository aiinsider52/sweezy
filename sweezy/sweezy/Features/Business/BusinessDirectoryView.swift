import SwiftUI

@MainActor
final class BusinessDirectoryModel: ObservableObject {
    @Published var query = BusinessProAPI.DirectoryQuery()
    @Published private(set) var items: [BusinessSummary] = []
    @Published private(set) var offers: [BusinessOffer] = []
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false
    private var loadedQuery: BusinessProAPI.DirectoryQuery?
    private var searchTask: Task<Void, Never>?

    var hasLoaded: Bool { loadedQuery != nil }

    func loadIfNeeded() async {
        guard loadedQuery == nil else { return }
        await load()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let current = query
        do {
            async let page = BusinessProAPI.directory(current)
            async let feed = BusinessProAPI.offersFeed()
            let result = try await page
            items = result.items
            total = result.total
            offers = (try? await feed) ?? offers
            loadedQuery = current
            loadFailed = false
        } catch {
            loadFailed = items.isEmpty
        }
    }

    func apply(_ change: (inout BusinessProAPI.DirectoryQuery) -> Void) {
        change(&query)
        Task { await load() }
    }

    /// Debounces typing in the shared marketplace search field.
    func searchChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await load()
        }
    }
}

/// Business catalog shown as a marketplace mode: kinds, categories, offers and the ranked directory.
struct BusinessDirectoryContent: View {
    @ObservedObject var model: BusinessDirectoryModel
    let openBusiness: (String) -> Void
    let openOwnerHub: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            kindSelector
            filterRow
            categoryRail
            if !model.offers.isEmpty { offersRail }
            ownerInvite
            results
        }
        .task { await model.loadIfNeeded() }
    }

    private var kindSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                BusinessFilterChip(title: "common.all".localized, icon: "square.grid.2x2.fill", selected: model.query.kind == nil) {
                    model.apply { $0.kind = nil }
                }
                ForEach(BusinessKind.allCases) { kind in
                    BusinessFilterChip(title: kind.title, icon: kind.icon, selected: model.query.kind == kind) {
                        model.apply { $0.kind = $0.kind == kind ? nil : kind }
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                BusinessFilterChip(title: "business.filter.ukrainian".localized, icon: "bubble.left.and.text.bubble.right.fill", selected: model.query.ukrainianOnly) {
                    model.apply { $0.ukrainianOnly.toggle() }
                }
                BusinessFilterChip(title: "business.filter.verified".localized, icon: "checkmark.seal.fill", selected: model.query.verifiedOnly) {
                    model.apply { $0.verifiedOnly.toggle() }
                }
            }
        }
        .scrollClipDisabled()
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BusinessCategory.allCases.filter { $0 != .other }) { category in
                    let selected = model.query.category == category
                    Button {
                        model.apply { $0.category = selected ? nil : category }
                    } label: {
                        VStack(spacing: 8) {
                            JourneyCategoryIcon(symbol: category.icon, swatch: category.swatch, size: 38, selected: selected)
                            Text(category.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selected ? JourneyVisual.primaryText : JourneyVisual.secondaryText)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 82, height: 88)
                        .background(selected ? JourneyVisual.lime.opacity(0.18) : JourneyVisual.softSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selected ? JourneyVisual.lime : JourneyVisual.softBorder, lineWidth: selected ? 1.5 : 1))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96, hapticStyle: .light))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    private var offersRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            BusinessSectionHeader(title: "business.offers.title".localized, trailing: "business.offers.subtitle".localized)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.offers.prefix(12)) { offer in
                        Button {
                            BusinessProAPI.track(.offer, businessID: offer.businessUserID)
                            openBusiness(offer.businessUserID)
                        } label: {
                            BusinessOfferTicket(offer: offer, businessName: offer.business?.displayName, compact: true)
                                .frame(width: 290)
                        }
                        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var ownerInvite: some View {
        Button(action: openOwnerHub) {
            HStack(spacing: 14) {
                SweezyCompanion(pose: .people, size: 70)
                VStack(alignment: .leading, spacing: 4) {
                    Text("business.invite.title".localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(JourneyVisual.primaryText)
                    Text("business.invite.subtitle".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(JourneyVisual.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(JourneyVisual.lime, in: Circle())
            }
            .padding(14)
            .businessCard(stroke: JourneyVisual.lime.opacity(0.45))
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
        .accessibilityIdentifier("business.invite")
    }

    @ViewBuilder
    private var results: some View {
        if model.isLoading && model.items.isEmpty {
            SkeletonList(rows: 3)
        } else if model.items.isEmpty {
            MascotEmptyState(
                title: model.loadFailed ? "business.directory.error_title".localized : "business.directory.empty_title".localized,
                subtitle: model.loadFailed ? "business.directory.error_subtitle".localized : "business.directory.empty_subtitle".localized,
                pose: .people,
                actionTitle: model.loadFailed ? "common.retry".localized : "business.invite.cta".localized,
                action: model.loadFailed ? { Task { await model.load() } } : openOwnerHub
            )
        } else {
            BusinessSectionHeader(
                title: "business.directory.title".localized,
                trailing: "business.directory.count".localized(with: model.total)
            )
            LazyVStack(spacing: 12) {
                ForEach(model.items) { business in
                    BusinessDirectoryCard(business: business) { openBusiness(business.userID) }
                }
            }
            if model.items.contains(where: \.isSponsored) {
                Text("business.sponsored.explainer".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
            }
        }
    }
}

struct BusinessFilterChip: View {
    let title: String
    var icon: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(selected ? Color.black : JourneyVisual.secondaryText)
            .padding(.horizontal, 13)
            .frame(minHeight: Theme.Layout.minimumTouchTarget)
            .background(selected ? JourneyVisual.lime : JourneyVisual.softSurface, in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.clear : JourneyVisual.softBorder, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97, hapticStyle: .light))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
