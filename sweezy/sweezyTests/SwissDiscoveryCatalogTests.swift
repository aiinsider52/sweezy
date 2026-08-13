import XCTest
@testable import sweezy

final class SwissDiscoveryCatalogTests: XCTestCase {
    func testCatalogContainsUniqueProductionReadyPlaces() {
        let places = SwissDiscoveryCatalog.places

        XCTAssertEqual(places.count, 30)
        XCTAssertEqual(Set(places.map(\.id)).count, places.count)
        XCTAssertEqual(Set(places.map(\.imageName)).count, places.count)
        XCTAssertTrue(places.allSatisfy { $0.imageNames.count >= 3 })
        XCTAssertEqual(Set(places.flatMap(\.imageNames)).count, places.flatMap(\.imageNames).count)
        XCTAssertTrue(places.allSatisfy { $0.officialURL.scheme == "https" })
        XCTAssertTrue(places.allSatisfy { $0.officialURL.host?.contains("myswitzerland.com") == true })
        XCTAssertTrue(places.allSatisfy { $0.details.count > $0.summary.count })
        XCTAssertTrue(places.allSatisfy { (-90...90).contains($0.latitude) })
        XCTAssertTrue(places.allSatisfy { (-180...180).contains($0.longitude) })
        XCTAssertTrue(places.allSatisfy { !$0.settings.isEmpty })
    }

    func testFiltersReturnRelevantPlaces() {
        let nature = SwissDiscoveryCatalog.places.filter {
            $0.matches(query: "", filter: .nature)
        }
        let culture = SwissDiscoveryCatalog.places.filter {
            $0.matches(query: "", filter: .culture)
        }

        XCTAssertFalse(nature.isEmpty)
        XCTAssertFalse(culture.isEmpty)
        XCTAssertTrue(nature.allSatisfy { $0.filters.contains(.nature) })
        XCTAssertTrue(culture.allSatisfy { $0.filters.contains(.culture) })
    }

    func testProgressStorePersistsSavedAndVisitedIDs() throws {
        let suiteName = "SwissDiscoveryCatalogTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let saved: Set<String> = ["aletsch", "lavaux"]
        let visited: Set<String> = ["rhine-falls"]
        SwissDiscoveryProgressStore.save(saved, defaults: defaults)
        SwissDiscoveryProgressStore.saveVisited(visited, defaults: defaults)

        XCTAssertEqual(SwissDiscoveryProgressStore.savedPlaceIDs(defaults: defaults), saved)
        XCTAssertEqual(SwissDiscoveryProgressStore.visitedPlaceIDs(defaults: defaults), visited)
    }

    func testTripPlannerHonorsFamilyTransitAndWeather() throws {
        let plan = try XCTUnwrap(SwissTripPlanner.plan(
            origin: "Zürich", budget: 80, transport: .publicTransit, family: true, weather: .rain
        ))
        XCTAssertEqual(plan.budgetCHF, 80)
        XCTAssertEqual(plan.transport, .publicTransit)
        XCTAssertTrue(plan.place.filters.contains(.family) || plan.place.filters.contains(.easy))
        XCTAssertTrue(plan.place.filters.contains(.culture) || plan.place.settings.contains(.city))
    }

    func testTripPlannerIsStableForSameDailyInput() throws {
        let first = try XCTUnwrap(SwissTripPlanner.plan(origin: "Bern", budget: 120, transport: .car, family: false, weather: .sun))
        let second = try XCTUnwrap(SwissTripPlanner.plan(origin: "Bern", budget: 120, transport: .car, family: false, weather: .sun))
        XCTAssertEqual(first.place.id, second.place.id)
    }
}
