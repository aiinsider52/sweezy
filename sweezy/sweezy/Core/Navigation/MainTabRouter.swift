import Foundation

@MainActor
final class MainTabRouter: ObservableObject {
    @Published private(set) var selectedTab = 0
    @Published private(set) var isBottomBarHidden = false
    @Published private(set) var requestedDirectorySection: DovidnykRouteSection?
    @Published private(set) var requestedDirectoryRouteID = UUID()
    @Published private(set) var activeDeepLink: DeepLink?
    /// Whether the last tab change went right along the dock; drives the slide direction.
    private(set) var movesForward = true

    nonisolated static let settingsTab = 5

    func select(tab: Int) {
        let target = min(max(tab, 0), Self.settingsTab)
        // Tapping the tab you are already on takes it back to its first screen, as in system apps.
        if target == selectedTab {
            NotificationCenter.default.post(name: .journeyTabReselected, object: target)
        }
        move(to: target)
    }

    private func move(to tab: Int) {
        movesForward = tab >= selectedTab
        selectedTab = tab
    }

    func open(_ payload: SwitchTabPayload) {
        move(to: min(max(payload.tab, 0), Self.settingsTab))
        guard payload.tab == 1 else { return }
        requestedDirectorySection = payload.section
        requestedDirectoryRouteID = payload.routeID
    }

    func setBottomBarHidden(_ hidden: Bool) {
        isBottomBarHidden = hidden
    }

    func open(_ deepLink: DeepLink) {
        if let tab = deepLink.rootTabIndex {
            move(to: tab)
        }
        activeDeepLink = deepLink
    }

    func consumeDeepLink() {
        activeDeepLink = nil
    }
}
