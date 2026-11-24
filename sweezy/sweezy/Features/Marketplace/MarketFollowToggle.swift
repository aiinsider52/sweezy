import SwiftUI

/// Remembers the user's marketplace follows for the session, so every rail shows the right bell
/// without asking the server again.
@MainActor
final class MarketFollowStore: ObservableObject {
    static let shared = MarketFollowStore()

    @Published private(set) var follows: [MarketplaceFollow] = []
    private var loaded = false

    func loadIfNeeded() async {
        guard !loaded, NotificationsAPI.isSignedIn else { return }
        if let items = try? await NotificationsAPI.follows() {
            follows = items
            loaded = true
        }
    }

    func follow(country: String, subdivision: String, category: String?) -> MarketplaceFollow? {
        follows.first {
            $0.countryCode == country && $0.subdivisionCode.hasSuffix(subdivision) && ($0.category ?? "") == (category ?? "")
        }
    }

    func toggle(country: String, subdivision: String, category: String?) async throws {
        if let existing = follow(country: country, subdivision: subdivision, category: category) {
            follows.removeAll { $0.id == existing.id }
            do { try await NotificationsAPI.unfollow(existing.id) } catch { follows.append(existing); throw error }
        } else {
            let created = try await NotificationsAPI.follow(country: country, subdivision: subdivision, category: category)
            follows.append(created)
        }
    }
}

/// "Notify me about new listings in <category> in <canton>": one tap subscribes to a push the
/// moment something new is approved there.
struct MarketFollowToggle: View {
    let category: String?
    let categoryTitle: String?
    let requireSignIn: () -> Void

    @EnvironmentObject private var appContainer: AppContainer
    @StateObject private var store = MarketFollowStore.shared
    @State private var isWorking = false

    private var country: ResidenceCountry { appContainer.userProfile?.country ?? ResidenceCountry(rawValue: APIClient.countryCode) ?? .switzerland }
    private var subdivision: String { appContainer.userProfile?.administrativeAreaCode ?? "ZH" }
    private var regionName: String { CountryCatalog.subdivisionName(country: country, code: subdivision) }
    private var isOn: Bool { store.follow(country: country.rawValue, subdivision: subdivision, category: category) != nil }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "bell.fill" : "bell")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isOn ? .black : JourneyVisual.accentText)
                    .frame(width: 32, height: 32)
                    .background(isOn ? JourneyVisual.lime : JourneyVisual.softSurface, in: Circle())
                    .symbolEffect(.bounce, value: isOn)
                VStack(alignment: .leading, spacing: 1) {
                    Text((isOn ? "market.follow.on" : "market.follow.off").localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text([categoryTitle, regionName].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if isWorking {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isOn ? JourneyVisual.accentStrong.opacity(0.5) : JourneyVisual.softBorder))
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
        .disabled(isWorking)
        .task { await store.loadIfNeeded() }
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("market.follow")
    }

    private func toggle() {
        guard NotificationsAPI.isSignedIn else { requireSignIn(); return }
        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            try? await store.toggle(country: country.rawValue, subdivision: subdivision, category: category)
            guard isOn else { return }
            // The follow is useless without pushes, so this is the moment to ask for them.
            let service = appContainer.notificationService
            await service.refreshAuthorizationStatus()
            if service.authorizationStatus == .notDetermined { _ = await service.requestPermission() }
            await SweezyAppDelegate.registerForChatPush()
        }
    }
}
