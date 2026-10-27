import SwiftUI

/// DEBUG-only entry points used by UI tests and screenshot runs (`UITESTS=1`).
struct BusinessUITestHost: View {
    enum Screen {
        case onboarding
        case plans
        case page(String)
        case dashboard
    }

    let screen: Screen
    @StateObject private var model = BusinessProViewModel()
    @StateObject private var growth = BusinessGrowthModel()

    init(screen: Screen) {
        self.screen = screen
        #if DEBUG
        // Local seed backends hand UI tests a session for a test business owner.
        let environment = ProcessInfo.processInfo.environment
        if case .dashboard = screen, let token = environment["UITEST_ACCESS_TOKEN"], let userID = environment["UITEST_USER_ID"] {
            try? KeychainStore.save(token, for: "access_token")
            try? KeychainStore.save(userID, for: "user_id")
        }
        #endif
    }

    var body: some View {
        switch screen {
        case .onboarding: BusinessOnboardingFlow(model: model)
        case .plans: BusinessPlansView(growth: growth)
        case .page(let id): BusinessPageView(businessID: id)
        case .dashboard: MarketplaceProDashboardView(dashboard: nil, listings: []) { _ in }
        }
    }
}
