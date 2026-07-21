import Foundation
import Combine

@MainActor
final class SavedItemsService: ObservableObject {
    @Published private(set) var eventIDs: Set<String> = []
    @Published private(set) var placeIDs: Set<UUID> = []
    @Published private(set) var listingIDs: Set<String> = []

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
        NotificationCenter.default.publisher(for: .accountScopeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }

    func toggleEvent(_ id: String) {
        Self.toggle(id, in: &eventIDs)
        defaults.set(Array(eventIDs), forKey: key("events"))
    }

    func toggleListing(_ id: String) {
        Self.toggle(id, in: &listingIDs)
        defaults.set(Array(listingIDs), forKey: key("listings"))
    }

    func togglePlace(_ id: UUID) {
        if placeIDs.contains(id) { placeIDs.remove(id) } else { placeIDs.insert(id) }
        defaults.set(placeIDs.map(\.uuidString), forKey: key("places"))
    }

    func isEventSaved(_ id: String) -> Bool { eventIDs.contains(id) }
    func isPlaceSaved(_ id: UUID) -> Bool { placeIDs.contains(id) }
    func isListingSaved(_ id: String) -> Bool { listingIDs.contains(id) }

    private static func toggle(_ id: String, in set: inout Set<String>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    private func key(_ suffix: String) -> String { AccountScopedStorage.namespaced("saved.\(suffix).v1") }

    private func reload() {
        eventIDs = Set(defaults.stringArray(forKey: key("events")) ?? [])
        listingIDs = Set(defaults.stringArray(forKey: key("listings")) ?? [])
        placeIDs = Set((defaults.stringArray(forKey: key("places")) ?? []).compactMap(UUID.init(uuidString:)))
    }
}
