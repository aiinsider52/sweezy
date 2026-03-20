import Foundation
import SwiftUI

@MainActor
final class MarketplaceViewModel: ObservableObject {
    @Published var listings: [ServiceListing] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var selectedCategory: ServiceCategory?
    @Published var selectedCanton: String?
    @Published var searchText = ""
    @Published var error: Error?

    private var currentPage = 1
    private let cacheKey = "marketplace_cache"
    private let cacheTTLSeconds: TimeInterval = 300 // 5 min

    init(initialCategory: ServiceCategory? = nil, initialCanton: String? = nil) {
        self.selectedCategory = initialCategory
        self.selectedCanton = initialCanton
    }

    var filteredListings: [ServiceListing] {
        guard !searchText.isEmpty else { return listings }
        let q = searchText.lowercased()
        return listings.filter {
            $0.title.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.authorName.lowercased().contains(q)
        }
    }

    // MARK: - Public

    func loadListings(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMore = true
        }
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let page = try await APIClient.fetchListings(
                category: selectedCategory,
                canton: selectedCanton,
                page: currentPage
            )
            if refresh {
                listings = page.items
            } else {
                listings.append(contentsOf: page.items)
            }
            hasMore = currentPage < page.pages
            saveCache(page.items)
        } catch {
            self.error = error
            if listings.isEmpty {
                loadCache()
            }
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        currentPage += 1
        await loadListings()
    }

    func refresh() async {
        await loadListings(refresh: true)
    }

    func applyFilters() async {
        await loadListings(refresh: true)
    }

    // MARK: - Cache (UserDefaults, lightweight)

    private func saveCache(_ items: [ServiceListing]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "\(cacheKey)_ts")
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let items = try? JSONDecoder().decode([ServiceListing].self, from: data) else { return }
        let ts = UserDefaults.standard.double(forKey: "\(cacheKey)_ts")
        let age = Date().timeIntervalSince1970 - ts
        if age < cacheTTLSeconds * 12 { // show cache up to 1 hour if offline
            listings = items
        }
    }

    var cacheAgeText: String? {
        let ts = UserDefaults.standard.double(forKey: "\(cacheKey)_ts")
        guard ts > 0 else { return nil }
        let age = Date().timeIntervalSince1970 - ts
        if age < 60 { return "marketplace.updated_just_now".localized }
        let minutes = Int(age / 60)
        return "marketplace.updated_minutes_ago".localized(with: minutes)
    }
}
