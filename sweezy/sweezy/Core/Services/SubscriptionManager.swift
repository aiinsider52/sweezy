//
//  SubscriptionManager.swift
//  sweezy
//
//  Minimal StoreKit 2 wrapper for purchases and entitlement checks.
//

import Foundation
import Combine
import StoreKit
import UIKit

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    enum Entitlement {
        case free
        case pro
    }
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var entitlement: Entitlement = .free
    @Published private(set) var lastError: String?
    
    // Product identifiers (замени на реальные в App Store Connect)
    private let monthlyId = "sweezy.pro.monthly"
    private let yearlyId = "sweezy.pro.yearly"
    
    // MARK: - Public API
    func load() async {
        await loadProducts()
        await refreshEntitlements()
    }
    
    var isPremium: Bool { entitlement == .pro }
    
    func presentOfferCodeRedemption() {
        #if canImport(StoreKit)
        if #available(iOS 14.0, *) {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
        #endif
    }
    
    func showManageSubscriptions() async {
        #if canImport(StoreKit)
        if #available(iOS 15.0, *) {
            do {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    try await AppStore.showManageSubscriptions(in: scene)
                } else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    _ = await UIApplication.shared.open(url)
                }
            } catch {
                lastError = "Manage failed: \(error)"
            }
        } else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            _ = await UIApplication.shared.open(url)
        }
        #endif
    }
    
    func purchaseMonthly() async -> Bool {
        guard let p = products.first(where: { $0.id == monthlyId }) else { return false }
        return await purchase(p)
    }
    
    func purchaseYearly() async -> Bool {
        guard let p = products.first(where: { $0.id == yearlyId }) else { return false }
        return await purchase(p)
    }
    
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "Restore failed: \(error)"
        }
    }
    
    // MARK: - Internal
    private func loadProducts() async {
        do {
            products = try await Product.products(for: [monthlyId, yearlyId])
        } catch {
            lastError = "Failed to load products: \(error)"
        }
    }
    
    private func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Purchase failed: \(error)"
            return false
        }
    }
    
    private func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == monthlyId || transaction.productID == yearlyId {
                    entitlement = .pro
                    return
                }
            }
        }
        entitlement = .free
    }
}

