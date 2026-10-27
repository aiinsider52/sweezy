import UIKit
import XCTest
@testable import sweezy

final class IllustrationAssetsTests: XCTestCase {
    func testEveryTabSceneExistsForEveryCountry() {
        for scene in ["home", "directory", "map", "market", "people", "business"] {
            for country in ["CH", "DE", "AT"] {
                let name = CityArtwork.name(scene, country: country)
                XCTAssertEqual(name, "city-scene-\(scene)-\(country.lowercased())")
                XCTAssertNotNil(UIImage(named: name), name)
            }
        }
        XCTAssertEqual(CityArtwork.name("home", country: "FR"), "city-scene-home-ch")
    }

    func testBusinessCategoriesHaveCovers() {
        for category in BusinessCategory.allCases {
            XCTAssertNotNil(UIImage(named: category.coverAsset), category.coverAsset)
        }
    }

    func testEmptyStateSpotsExist() {
        let spots: [EmptyStateSpot] = [.noResults, .offline, .emptyInbox, .noBookings, .noOffers, .noReviews, .club, .sent, .locked, .savedEmpty]
        for spot in spots {
            XCTAssertNotNil(UIImage(named: spot.asset), spot.asset)
        }
    }
}
