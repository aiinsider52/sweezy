import XCTest
import StoreKitTest

final class StoreKitSubscriptionTests: XCTestCase {
    private var session: SKTestSession!
    private var configurationURL: URL!
    private let monthlyID = "sweezy_plus_monthly"
    private let yearlyID = "sweezy_plus_yearly"

    override func setUpWithError() throws {
        configurationURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("SweezyPlus.storekit")
        session = try SKTestSession(contentsOf: configurationURL)
        session.clearTransactions()
        session.resetToDefaultState()
        session.disableDialogs = true
    }

    override func tearDownWithError() throws {
        session.clearTransactions()
        session.resetToDefaultState()
        session = nil
    }

    func testConfigurationMatchesProductionProductContract() throws {
        let data = try Data(contentsOf: configurationURL)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let groups = try XCTUnwrap(root["subscriptionGroups"] as? [[String: Any]])
        let subscriptions = groups.flatMap { $0["subscriptions"] as? [[String: Any]] ?? [] }
        let monthly = try XCTUnwrap(subscriptions.first { $0["productID"] as? String == monthlyID })
        let yearly = try XCTUnwrap(subscriptions.first { $0["productID"] as? String == yearlyID })

        XCTAssertEqual(monthly["displayPrice"] as? String, "4.95")
        XCTAssertEqual(monthly["recurringSubscriptionPeriod"] as? String, "P1M")
        let trial = try XCTUnwrap(monthly["introductoryOffer"] as? [String: Any])
        XCTAssertEqual(trial["paymentMode"] as? String, "free")
        XCTAssertEqual(trial["subscriptionPeriod"] as? String, "P1M")
        XCTAssertEqual(yearly["recurringSubscriptionPeriod"] as? String, "P1Y")
    }

    func testPurchaseRestoreRenewAndRefundLifecycle() throws {
        try session.buyProduct(productIdentifier: monthlyID)
        let purchased = try XCTUnwrap(session.allTransactions().last)
        XCTAssertNil(purchased.cancelDate)
        XCTAssertTrue(purchased.autoRenewingEnabled)

        let restoredSession = try SKTestSession(contentsOf: configurationURL)
        restoredSession.disableDialogs = true
        XCTAssertTrue(restoredSession.allTransactions().contains { $0.originalTransactionIdentifier == purchased.originalTransactionIdentifier })

        let beforeRenewal = session.allTransactions().count
        try session.forceRenewalOfSubscription(productIdentifier: monthlyID)
        XCTAssertGreaterThan(session.allTransactions().count, beforeRenewal)

        let renewed = try XCTUnwrap(session.allTransactions().last)
        try session.refundTransaction(identifier: renewed.identifier)
        XCTAssertNotNil(session.allTransactions().last?.cancelDate)
    }

    func testBillingGracePeriodAndRecovery() throws {
        session.billingGracePeriodIsEnabled = true
        session.shouldEnterBillingRetryOnRenewal = true
        try session.buyProduct(productIdentifier: monthlyID)
        try session.forceRenewalOfSubscription(productIdentifier: monthlyID)
        let graceTransaction = try XCTUnwrap(session.allTransactions().last { $0.hasPurchaseIssue })
        XCTAssertNil(graceTransaction.cancelDate)

        session.shouldEnterBillingRetryOnRenewal = false
        try session.resolveIssueForTransaction(identifier: graceTransaction.identifier)
        XCTAssertFalse(try XCTUnwrap(session.allTransactions().last).hasPurchaseIssue)
    }
}
