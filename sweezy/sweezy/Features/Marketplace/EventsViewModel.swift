import Foundation
import SwiftUI

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var events: [EventListing] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var isShowingStaleData = false
    @Published var selectedCategory: EventCategory?
    @Published var selectedCanton: String?
    @Published var searchText = ""
    @Published var error: Error?

    private var currentPage = 1
    private let cacheKey = "events_cache"
    private let cacheTTLSeconds: TimeInterval = 300

    init(initialCategory: EventCategory? = nil, initialCanton: String? = nil) {
        self.selectedCategory = initialCategory
        self.selectedCanton = initialCanton
    }

    var filteredEvents: [EventListing] {
        guard !searchText.isEmpty else { return events }
        let q = searchText.lowercased()
        return events.filter {
            $0.title.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.organizerName.lowercased().contains(q) ||
            $0.city.lowercased().contains(q)
        }
    }

    func loadEvents(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMore = true
        }
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let page = try await APIClient.fetchEvents(
                category: selectedCategory,
                canton: selectedCanton,
                page: currentPage
            )
            if refresh {
                events = page.items
            } else {
                events.append(contentsOf: page.items)
            }
            hasMore = currentPage < page.pages
            isShowingStaleData = false
            saveCache(events)
        } catch {
            self.error = error
            if refresh || currentPage == 1 {
                isShowingStaleData = true
                if events.isEmpty {
                    loadCache()
                }
            } else {
                currentPage = max(1, currentPage - 1)
            }
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        currentPage += 1
        await loadEvents()
    }

    func refresh() async {
        await loadEvents(refresh: true)
    }

    func applyFilters() async {
        await loadEvents(refresh: true)
    }

    private func saveCache(_ items: [EventListing]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "\(cacheKey)_ts")
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let items = try? JSONDecoder().decode([EventListing].self, from: data) else { return }
        let ts = UserDefaults.standard.double(forKey: "\(cacheKey)_ts")
        let age = Date().timeIntervalSince1970 - ts
        if age < cacheTTLSeconds * 12 {
            events = items
        }
    }
}
