import XCTest
import UIKit
@testable import sweezy

final class SweezyCompanionTests: XCTestCase {
    func testEveryPoseIsBundledWithTransparentCorners() throws {
        for pose in SweezyCompanionPose.allCases {
            let image = try XCTUnwrap(UIImage(named: pose.assetName), "Missing \(pose.assetName)")
            let cgImage = try XCTUnwrap(image.cgImage)
            XCTAssertGreaterThanOrEqual(cgImage.width, 512)
            let width = 32
            var pixels = [UInt8](repeating: 0, count: width * width * 4)
            let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(
                    data: buffer.baseAddress, width: width, height: width,
                    bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return false }
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: width))
                return true
            }
            XCTAssertTrue(rendered)
            for index in [0, width - 1, width * (width - 1), width * width - 1] {
                XCTAssertLessThan(pixels[index * 4 + 3], 8, "Opaque corner in \(pose.assetName)")
            }
            XCTAssertTrue(stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 200 }, "Blank asset")
        }
    }
}
