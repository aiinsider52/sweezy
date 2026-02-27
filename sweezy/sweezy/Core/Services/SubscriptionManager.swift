//
//  SubscriptionManager.swift
//  sweezy
//
//  TEMPORARY (App Store review):
//  In-App Purchases and subscription logic are removed for this build.
//  The app must ship fully unlocked with NO in-app purchase framework usage.
//
//  NOTE:
//  We keep this type (as a tiny stub) so reintroducing IAP later is a single-file change.
//

import Foundation

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    /// Always unlocked while IAP is temporarily disabled.
    var isPremium: Bool { true }

    /// No-op: kept to avoid touching unrelated call sites during the temporary removal.
    func load() async { /* no-op */ }
}

