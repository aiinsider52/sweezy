//
//  SubscriptionLiveService.swift
//  sweezy
//
//  TEMPORARY (App Store review):
//  Subscription / entitlement streaming is disabled.
//  This no-op placeholder remains so the original architecture can be restored later.
//

import Foundation

@MainActor
final class SubscriptionLiveService {
    init() {}
    func start() {}
    func stop() {}
}

extension Notification.Name {
    static let subscriptionLiveUpdated = Notification.Name("subscription_live_updated")
}
