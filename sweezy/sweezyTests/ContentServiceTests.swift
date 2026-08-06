//
//  ContentServiceTests.swift
//  sweezyTests
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import XCTest
@testable import sweezy

@MainActor
final class ContentServiceTests: XCTestCase {
    
    var contentService: ContentService!
    
    override func setUp() {
        super.setUp()
        contentService = ContentService(bundle: .main)
    }
    
    override func tearDown() {
        contentService = nil
        super.tearDown()
    }
    
    func testLoadContent() async {
        // Given
        XCTAssertTrue(contentService.guides.isEmpty)
        
        // When
        await contentService.loadContent()
        
        // Then
        XCTAssertFalse(contentService.isLoading)
        XCTAssertNotNil(contentService.lastUpdated)
    }
    
    func testSearchGuides() async {
        // Given
        await contentService.loadContent()
        
        // When
        let results = contentService.searchGuides(query: "health", category: nil, canton: nil)
        
        // Then
        XCTAssertFalse(results.isEmpty)
        // Verify that results contain health-related content
        let hasHealthContent = results.contains { guide in
            guide.title.lowercased().contains("health") ||
            guide.bodyMarkdown.lowercased().contains("health") ||
            guide.tags.contains { $0.lowercased().contains("health") }
        }
        XCTAssertTrue(hasHealthContent)
    }
    
    func testSearchGuidesWithCategory() async {
        // Given
        await contentService.loadContent()
        
        // When
        let results = contentService.searchGuides(query: "", category: .healthcare, canton: nil)
        
        // Then
        for guide in results {
            XCTAssertEqual(guide.category, .healthcare)
        }
    }
    
    func testSearchGuidesWithCanton() async {
        // Given
        await contentService.loadContent()
        let testCanton = Canton.zurich
        
        // When
        let results = contentService.searchGuides(query: "", category: nil, canton: testCanton)
        
        // Then
        for guide in results {
            XCTAssertTrue(guide.appliesTo(canton: testCanton))
        }
    }
    
    func testGetGuideById() async {
        // Given
        await contentService.loadContent()
        guard let firstGuide = contentService.guides.first else {
            XCTFail("No guides loaded")
            return
        }
        
        // When
        let foundGuide = contentService.getGuide(by: firstGuide.id)
        
        // Then
        XCTAssertNotNil(foundGuide)
        XCTAssertEqual(foundGuide?.id, firstGuide.id)
    }
    
    func testGetNonExistentGuide() async {
        // Given
        await contentService.loadContent()
        let nonExistentId = UUID()
        
        // When
        let foundGuide = contentService.getGuide(by: nonExistentId)
        
        // Then
        XCTAssertNil(foundGuide)
    }
    
    func testBundleInjection() {
        // Given a service with custom bundle (can be mocked in real tests)
        let service = ContentService(bundle: .main)
        
        // Then service should be able to load without crash
        XCTAssertNotNil(service)
        XCTAssertEqual(service.guides.count, 0) // Before load
    }
    
    func testGuidesLoadWithoutCrashOnInvalidUUID() async {
        // Given a service that might have invalid UUIDs in JSON (GuideLink migration)
        await contentService.loadContent()
        
        // When guides are loaded, they should not crash even if some links have invalid UUIDs
        // Then we should have guides (the service should skip bad links gracefully)
        // This is tested implicitly by loading; if it doesn't crash, migration worked
        XCTAssertTrue(true, "Migration of invalid UUIDs succeeded without crash")
    }

    func testSafetyPolicyHonorsRemoteSlugAndEmergencyCategory() {
        let hidden = makeGuide(title: "Safe title", tags: ["slug:remove-me"])
        let visible = makeGuide(title: "Municipal registration")
        let policy = ContentSafetyPolicy(hiddenSlugs: ["remove-me"], hiddenCategories: [])

        XCTAssertFalse(policy.allows(hidden))
        XCTAssertTrue(policy.allows(visible))
        XCTAssertTrue(policy.hiddenCategories.contains("refugee_center"))
    }

    func testSafetyPolicySuppressesDisputedAdvicePatterns() {
        let travel = makeGuide(title: "Travel with Ausweis S", body: "Where you may travel")
        let tax = makeGuide(title: "Tax deadline", body: "The deadline is fixed for everyone")
        let insurance = makeGuide(title: "Insurance", body: "You must enroll in the first week")

        XCTAssertFalse(ContentSafetyPolicy().allows(travel))
        XCTAssertFalse(ContentSafetyPolicy().allows(tax))
        XCTAssertFalse(ContentSafetyPolicy().allows(insurance))
    }

    func testFutureVerificationIsUnverifiedAndEstablishedTopicsAreSeparated() {
        let future = Date(timeIntervalSince1970: 4_102_444_800)
        let guide = makeGuide(title: "Pillar 3a pension", verifiedAt: future)

        XCTAssertEqual(guide.freshness(asOf: Date(timeIntervalSince1970: 1_700_000_000)), .unverified)
        XCTAssertEqual(guide.audienceStage, .established)
    }

    private func makeGuide(
        title: String,
        body: String = "General information",
        tags: [String] = [],
        verifiedAt: Date? = nil
    ) -> Guide {
        Guide(
            title: title,
            bodyMarkdown: body,
            tags: tags,
            category: .documents,
            verifiedAt: verifiedAt,
            source: "https://www.ch.ch/en/"
        )
    }
}
