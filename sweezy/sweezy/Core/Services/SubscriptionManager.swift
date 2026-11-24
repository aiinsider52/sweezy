import Foundation
import StoreKit
import UIKit

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
                return "Підписка ще не доступна в App Store. Спробуйте пізніше.".localized
            case .verificationFailed:
                return "Apple не вдалося підтвердити покупку.".localized
            case .pending:
                return "Покупка очікує підтвердження.".localized
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
    /// Free uses left per metered feature from the server ("letter_explain", "career_kit",
    /// "interview_turns", "cv_tools"); empty until signed in and loaded.
    @Published private(set) var freeUsesRemaining: [String: Int] = [:]
    @Published private(set) var isYearlyTrialEligible = false

    private var updatesTask: Task<Void, Never>?
    private var lastLoadedAt: Date?

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
        guard isPremium else { return "Базовий доступ".localized }
        let period = entitlementPlan == "yearly" ? "Річний план".localized : entitlementPlan == "monthly" ? "Місячний план".localized : "Активний план".localized
        guard let entitlementExpiresAt else { return period }
        return "%@ · до %@".localized(with: "\(period)", "\(entitlementExpiresAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.current.locale)))")
    }

    /// Loads products and entitlements. Many screens call this on appear, so repeat calls within
    /// five minutes are skipped unless `force` is set (purchase, restore, explicit refresh).
    func load(force: Bool = false) async {
        guard !isLoading else { return }
        if !force, !products.isEmpty, let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) < 300 { return }
        isLoading = true
        defer { isLoading = false }
        lastLoadedAt = Date()

        do {
            products = try await Product.products(for: ProductID.all)
                .sorted { $0.price < $1.price }
            if let subscription = monthlyProduct?.subscription,
               subscription.introductoryOffer?.paymentMode == .freeTrial {
                isMonthlyTrialEligible = await subscription.isEligibleForIntroOffer
            } else {
                isMonthlyTrialEligible = false
            }
            if let subscription = yearlyProduct?.subscription,
               subscription.introductoryOffer?.paymentMode == .freeTrial {
                isYearlyTrialEligible = await subscription.isEligibleForIntroOffer
            } else {
                isYearlyTrialEligible = false
            }
            lastError = nil
        } catch {
            products = []
            isMonthlyTrialEligible = false
            lastError = "Не вдалося завантажити тарифи App Store.".localized
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
                if isPremium {
                    isMonthlyTrialEligible = false
                    TelemetryService.current?.track(.plusPurchased, source: "storekit", meta: ["product": productID])
                }
                return isPremium
            case .pending:
                lastError = PurchaseError.pending.localizedDescription
            case .userCancelled:
                break
            @unknown default:
                lastError = "Невідомий статус покупки.".localized
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
                lastError = "Активну підписку не знайдено.".localized
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
            freeUsesRemaining = server.free_uses_remaining ?? ["cv_tools": server.cv_free_uses_remaining]
        } else {
            isPremium = hasActiveSubscription
            entitlementStatus = hasActiveSubscription ? "premium" : "free"
            entitlementPlan = nil
            entitlementProvider = hasActiveSubscription ? "apple" : nil
            entitlementExpiresAt = nil
        }
    }

    /// Length of the free trial on a product in days, from its App Store intro offer (nil if none).
    func trialDays(for productID: String) -> Int? {
        guard let offer = product(id: productID)?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let unitDays: Int
        switch offer.period.unit {
        case .day: unitDays = 1
        case .week: unitDays = 7
        case .month: unitDays = 30
        case .year: unitDays = 365
        @unknown default: unitDays = 1
        }
        return offer.period.value * unitDays * max(offer.periodCount, 1)
    }

    /// How much cheaper a year is than twelve months, in whole percent (nil until both prices load).
    var yearlySavingsPercent: Int? {
        guard let monthly = monthlyProduct?.price, let yearly = yearlyProduct?.price, monthly > 0 else { return nil }
        let twelve = monthly * 12
        let saving = (twelve - yearly) / twelve * 100
        // NSDecimalNumber.intValue is unreliable for fractional decimals; go through Double.
        let value = Int(NSDecimalNumber(decimal: saving).doubleValue.rounded(.down))
        return value > 0 ? value : nil
    }

    /// The yearly price spread over twelve months, formatted like the product's own price.
    var yearlyPricePerMonth: String? {
        guard let yearly = yearlyProduct else { return nil }
        return (yearly.price / 12).formatted(yearly.priceFormatStyle)
    }

    /// Apple's sheet for redeeming offer codes (NGO and community promo codes).
    func presentOfferCodeRedemption() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        Task {
            try? await AppStore.presentOfferCodeRedeemSheet(in: scene)
            await load(force: true)
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
                // Business placement products are credited and finished by BusinessStoreManager.
                guard case .verified(let transaction) = result,
                      ProductID.all.contains(transaction.productID) else { continue }
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
