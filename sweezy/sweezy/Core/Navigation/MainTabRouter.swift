import Foundation

@MainActor
final class MainTabRouter: ObservableObject {
    @Published private(set) var selectedTab = 0
    @Published private(set) var isBottomBarHidden = false
    @Published private(set) var requestedDirectorySection: DovidnykRouteSection?
    @Published private(set) var requestedDirectoryRouteID = UUID()

    func select(tab: Int) {
        selectedTab = min(max(tab, 0), 4)
    }

    func open(_ payload: SwitchTabPayload) {
        selectedTab = min(max(payload.tab, 0), 4)
        guard payload.tab == 1 else { return }
        requestedDirectorySection = payload.section
        requestedDirectoryRouteID = payload.routeID
    }

    func setBottomBarHidden(_ hidden: Bool) {
        isBottomBarHidden = hidden
    }
}
