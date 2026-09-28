import XCTest
import UIKit
@testable import sweezy

final class ResponsiveDesignTests: XCTestCase {
    func testAdaptiveSpacingAcrossSupportedWidths() {
        XCTAssertEqual(Theme.Layout.horizontalPadding(for: 320), 16)
        XCTAssertEqual(Theme.Layout.horizontalPadding(for: 360), 16)
        XCTAssertEqual(Theme.Layout.horizontalPadding(for: 390), 20)
        XCTAssertEqual(Theme.Layout.horizontalPadding(for: 430), 20)
        XCTAssertEqual(Theme.Layout.horizontalPadding(for: 768), 28)
    }

    func testHeroTypeStaysReadableWithoutTakingOverScreen() {
        XCTAssertEqual(Theme.Layout.heroTitleSize(for: 320), 26)
        XCTAssertEqual(Theme.Layout.heroTitleSize(for: 390), 29)
        XCTAssertEqual(Theme.Layout.heroTitleSize(for: 430), 29)
        XCTAssertEqual(Theme.Layout.heroTitleSize(for: 768), 34)
    }

    func testTouchTargetMatchesIOSMinimum() {
        XCTAssertGreaterThanOrEqual(Theme.Layout.minimumTouchTarget, 44)
    }

    func testSemanticBackgroundHasRealLightAndDarkVariants() {
        let dynamic = UIColor(JourneyVisual.pageBackground)
        let light = dynamic.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = dynamic.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))

        XCTAssertGreaterThan(luminance(light), 0.8)
        XCTAssertLessThan(luminance(dark), 0.1)
    }

    private func luminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}
