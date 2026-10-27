import Foundation
import StoreKit

/// StoreKit purchases for business placement: monthly Pro/Business plans and consumable 7-day boosts.
/// The backend is the source of truth; a transaction is finished only after the server credited it.
@MainActor
final class BusinessStoreManager: ObservableObject {
    static let shared = BusinessStoreManager()

    enum ProductID {
        static let pro = "sweezy_business_pro_monthly"
        static let business = "sweezy_business_max_monthly"
        static let boost = "sweezy_business_boost_7d"
        static let all: Set<String> = [pro, business, boost]

        static func plan(_ tier: BusinessPlanTier) -> String? {
            switch tier {
            case .free: return nil
            case .pro: return pro
            case .business: return business
            }
        }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasingProductID: String?
    @Published private(set) var lastPlan: BusinessPlanInfo?
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result, ProductID.all.contains(transaction.productID) else { continue }
                if await self?.credit(result.jwsRepresentation) == true {
                    await transaction.finish()
                }
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    func displayPrice(_ id: String, fallback: String) -> String {
        product(id)?.displayPrice ?? fallback
    }

    func load() async {
        guard products.isEmpty else { return }
        do {
            products = try await Product.products(for: ProductID.all)
        } catch {
            lastError = "business.store.load_failed".localized
        }
        await creditUnfinished()
    }

    /// Returns the refreshed plan when the purchase was credited by the server.
    func purchase(_ productID: String) async -> BusinessPlanInfo? {
        if products.isEmpty { await load() }
        guard let product = product(productID) else {
            lastError = "business.store.unavailable".localized
            return nil
        }
        purchasingProductID = productID
        lastError = nil
        defer { purchasingProductID = nil }
        var options: Set<Product.PurchaseOption> = []
        if let rawUserID = KeychainStore.get("user_id"), let token = UUID(uuidString: rawUserID) {
            options.insert(.appAccountToken(token))
        }
        do {
            switch try await product.purchase(options: options) {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "Apple не вдалося підтвердити покупку.".localized
                    return nil
                }
                guard await credit(verification.jwsRepresentation) else { return nil }
                await transaction.finish()
                return lastPlan
            case .pending:
                lastError = "Покупка очікує підтвердження.".localized
            case .userCancelled:
                break
            @unknown default:
                lastError = "Невідомий статус покупки.".localized
            }
        } catch {
            lastError = error.localizedDescription
        }
        return nil
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await creditUnfinished()
    }

    private func creditUnfinished() async {
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result, ProductID.all.contains(transaction.productID) else { continue }
            if await credit(result.jwsRepresentation) {
                await transaction.finish()
            }
        }
    }

    private func credit(_ signedTransaction: String) async -> Bool {
        guard KeychainStore.get("access_token") != nil else { return false }
        do {
            lastPlan = try await BusinessProAPI.syncApplePurchase(signedTransaction)
            return true
        } catch {
            lastError = "business.store.sync_failed".localized
            return false
        }
    }
}
