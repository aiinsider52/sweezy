import SwiftUI

/// "Who can help with this step": up to three local businesses for a guide topic.
/// Renders nothing until there is at least one match, so guides never show an empty block.
struct BusinessHelpersCard: View {
    let topic: String

    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var helpers: [BusinessSummary] = []
    @State private var selected: BusinessPageTarget?

    var body: some View {
        Group {
            if !helpers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        JourneyCategoryIcon(symbol: "person.2.badge.gearshape.fill", swatch: JourneyCategoryPalette.sky, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("business.helpers.title".localized)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(JourneyVisual.primaryText)
                            Text("business.helpers.subtitle".localized)
                                .font(.system(size: 12))
                                .foregroundStyle(JourneyVisual.secondaryText)
                        }
                    }
                    ForEach(helpers) { business in
                        BusinessDirectoryCard(business: business) { selected = BusinessPageTarget(id: business.userID) }
                    }
                }
                .transition(.opacity)
            }
        }
        .task(id: topic) {
            helpers = (try? await BusinessProAPI.contextual(topic: topic)) ?? []
        }
        .fullScreenCover(item: $selected) { target in
            BusinessPageView(businessID: target.id)
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
    }
}

extension GuideCategory {
    /// Topic key understood by `GET /businesses/contextual`.
    var businessTopic: String? {
        switch self {
        case .documents: return "documents"
        case .housing: return "housing"
        case .insurance, .finance, .banking: return "finance"
        case .work: return "work"
        case .education: return "education"
        case .healthcare: return "health"
        case .legal: return "legal"
        case .integration, .lifestyle: return "community"
        case .transport: return "transport"
        case .emergency: return nil
        }
    }
}
