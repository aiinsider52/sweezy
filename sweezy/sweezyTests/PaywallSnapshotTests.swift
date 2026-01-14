//
//  PaywallSnapshotTests.swift
//  sweezyTests
//
//  Simple visual snapshot attachments for SubscriptionView in different appearances.
//

import XCTest
import SwiftUI
@testable import sweezy

@MainActor
final class PaywallSnapshotTests: XCTestCase {

    func testPaywallLight_DefaultText() {
        let view = SubscriptionView()
            .environmentObject(AppContainer())
        let image = render(view: view, colorScheme: .light, contentSize: .large)
        let attachment = XCTAttachment(image: image)
        attachment.lifetime = .keepAlways
        attachment.name = "Paywall_Light_DefaultText"
        add(attachment)
    }

    func testPaywallDark_LargeText() {
        let view = SubscriptionView()
            .environmentObject(AppContainer())
        let image = render(view: view, colorScheme: .dark, contentSize: .accessibilityExtraExtraExtraLarge)
        let attachment = XCTAttachment(image: image)
        attachment.lifetime = .keepAlways
        attachment.name = "Paywall_Dark_AccessibilityXXXL"
        add(attachment)
    }
}

// MARK: - Rendering Helper
private func render<V: View>(view: V, colorScheme: ColorScheme, contentSize: ContentSizeCategory) -> UIImage {
    let controller = UIHostingController(rootView: view
        .environment(\.colorScheme, colorScheme)
        .environment(\.sizeCategory, contentSize)
    )
    controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 812) // iPhone 13
    let window = UIWindow(frame: controller.view.frame)
    window.rootViewController = controller
    window.makeKeyAndVisible()
    let renderer = UIGraphicsImageRenderer(bounds: controller.view.bounds)
    return renderer.image { ctx in
        controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
    }
}

