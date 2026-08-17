import Foundation
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    enum ProductID {
        static let monthly = "sweezy_plus_monthly"
        static let yearly = "sweezy_plus_yearly"
        static let all: Set<String> = [monthly, yearly]
    }

    enum PurchaseError: LocalizedError {
        case productUnavailable
        case verificationFailed
        case pending

        var errorDescription: String? {
            switch self {
            case .productUnavailable:
                return "Підписка ще не доступна в App Store. Спробуйте пізніше."
            case .verificationFailed:
                return "Apple не вдалося підтвердити покупку."
            case .pending:
                return "Покупка очікує підтвердження."
            }
        }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium = false
    @Published private(set) var isLoading = false
    @Published private(set) var purchasingProductID: String?
    @Published private(set) var backendSyncPending = false
    @Published private(set) var isMonthlyTrialEligible = false
    @Published private(set) var entitlementStatus = "free"
    @Published private(set) var entitlementPlan: String?
    @Published private(set) var entitlementProvider: String?
    @Published private(set) var entitlementExpiresAt: Date?
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = observeTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    var monthlyProduct: Product? { product(id: ProductID.monthly) }
    var yearlyProduct: Product? { product(id: ProductID.yearly) }
    var planDisplayName: String {
        guard isPremium else { return "Sweezy Free" }
        return entitlementStatus == "trial" ? "Sweezy Plus · Trial" : "Sweezy Plus"
    }
    var planDetails: String {
        guard isPremium else { return "Базовий доступ" }
        let period = entitlementPlan == "yearly" ? "Річний план" : entitlementPlan == "monthly" ? "Місячний план" : "Активний план"
        guard let entitlementExpiresAt else { return period }
        return "\(period) · до \(entitlementExpiresAt.formatted(date: .abbreviated, time: .omitted))"
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: ProductID.all)
                .sorted { $0.price < $1.price }
            if let subscription = monthlyProduct?.subscription,
               subscription.introductoryOffer?.paymentMode == .freeTrial {
                isMonthlyTrialEligible = await subscription.isEligibleForIntroOffer
            } else {
                isMonthlyTrialEligible = false
            }
            lastError = nil
        } catch {
            products = []
            isMonthlyTrialEligible = false
            lastError = "Не вдалося завантажити тарифи App Store."
        }

        await refreshEntitlements()
    }

    func purchase(productID: String) async -> Bool {
        guard let product = product(id: productID) else {
            lastError = PurchaseError.productUnavailable.localizedDescription
            return false
        }

        purchasingProductID = productID
        lastError = nil
        defer { purchasingProductID = nil }

        do {
            let options: Set<Product.PurchaseOption>
            if let rawUserID = KeychainStore.get("user_id"), let accountToken = UUID(uuidString: rawUserID) {
                options = [.appAccountToken(accountToken)]
            } else {
                options = []
            }
            switch try await product.purchase(options: options) {
            case .success(let verification):
                let transaction = try verified(verification)
                await syncWithBackend(verification.jwsRepresentation)
                await transaction.finish()
                await refreshEntitlements()
                if isPremium { isMonthlyTrialEligible = false }
                return isPremium
            case .pending:
                lastError = PurchaseError.pending.localizedDescription
            case .userCancelled:
                break
            @unknown default:
                lastError = "Невідомий статус покупки."
            }
        } catch {
            lastError = error.localizedDescription
        }
        return false
    }

    func restorePurchases() async {
        lastError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremium {
                lastError = "Активну підписку не знайдено."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  ProductID.all.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }

            if let expirationDate = transaction.expirationDate,
               expirationDate <= Date() { continue }

            hasActiveSubscription = true
            await syncWithBackend(result.jwsRepresentation)
            break
        }

        if KeychainStore.get("access_token") != nil,
           let server = await APIClient.fetchEntitlements() {
            isPremium = hasActiveSubscription || server.is_premium
            entitlementStatus = server.status
            entitlementPlan = server.plan
            entitlementProvider = server.provider
            entitlementExpiresAt = Self.parseDate(server.expire_at)
        } else {
            isPremium = hasActiveSubscription
            entitlementStatus = hasActiveSubscription ? "premium" : "free"
            entitlementPlan = nil
            entitlementProvider = hasActiveSubscription ? "apple" : nil
            entitlementExpiresAt = nil
        }
    }

    func displayPrice(for productID: String, fallback: String) -> String {
        product(id: productID)?.displayPrice ?? fallback
    }

    private func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw PurchaseError.verificationFailed
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }
                await self?.syncWithBackend(result.jwsRepresentation)
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    private func syncWithBackend(_ signedTransaction: String) async {
        guard KeychainStore.get("access_token") != nil else {
            backendSyncPending = true
            return
        }
        do {
            _ = try await APIClient.syncAppleTransaction(signedTransaction)
            backendSyncPending = false
        } catch {
            backendSyncPending = true
        }
    }
}
