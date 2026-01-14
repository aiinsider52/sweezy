//
//  SettingsChipSnapshotTests.swift
//  sweezyTests
//
//  Snapshot of SettingsView profile chip with subscription status.
//

import XCTest
import SwiftUI
@testable import sweezy

@MainActor
final class SettingsChipSnapshotTests: XCTestCase {
    func testSettings_ProfileChip_Light() {
        let app = AppContainer()
        let view = SettingsView()
            .environmentObject(app)
            .environmentObject(ThemeManager())
            .environmentObject(AppLockManager())
        let image = render(view: view, colorScheme: .light, contentSize: .large)
        let attachment = XCTAttachment(image: image)
        attachment.lifetime = .keepAlways
        attachment.name = "Settings_ProfileChip_Light"
        add(attachment)
    }
}

// Reuse helper from PaywallSnapshotTests if needed; duplicate here for isolation
private func render<V: View>(view: V, colorScheme: ColorScheme, contentSize: ContentSizeCategory) -> UIImage {
    let controller = UIHostingController(rootView: view
        .environment(\.colorScheme, colorScheme)
        .environment(\.sizeCategory, contentSize)
    )
    controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
    let window = UIWindow(frame: controller.view.frame)
    window.rootViewController = controller
    window.makeKeyAndVisible()
    let renderer = UIGraphicsImageRenderer(bounds: controller.view.bounds)
    return renderer.image { _ in
        controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
    }
}


