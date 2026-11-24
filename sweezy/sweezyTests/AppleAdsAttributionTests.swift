import XCTest
@testable import sweezy

@MainActor
final class AppleAdsAttributionTests: XCTestCase {
    func testParsesSearchAdsAttribution() {
        let result = AppleAdsAttribution.parse([
            "attribution": true, "orgId": 40669820, "campaignId": 542370539, "adGroupId": 542317095,
            "keywordId": 87675432, "countryOrRegion": "CH", "conversionType": "Download",
        ])

        XCTAssertEqual(result["source"], "apple_search_ads")
        XCTAssertEqual(result["campaign_id"], "542370539")
        XCTAssertEqual(result["keyword_id"], "87675432")
        XCTAssertEqual(result["country"], "CH")
        XCTAssertNil(result["org_id"])
    }

    func testNonAttributedInstallIsOrganic() {
        XCTAssertEqual(AppleAdsAttribution.parse(["attribution": false]), ["source": "organic"])
    }
}
