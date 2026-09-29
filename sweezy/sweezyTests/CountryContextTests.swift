import XCTest
@testable import sweezy

final class CountryContextTests: XCTestCase {
    func testCountryCatalogContainsCompleteAdministrativeAreas() {
        XCTAssertEqual(CountryCatalog.subdivisions(for: .switzerland).count, 26)
        XCTAssertEqual(CountryCatalog.subdivisions(for: .germany).count, 16)
        XCTAssertEqual(CountryCatalog.subdivisions(for: .austria).count, 9)
        XCTAssertEqual(ResidenceCountry.switzerland.currencyCode, "CHF")
        XCTAssertEqual(ResidenceCountry.germany.currencyCode, "EUR")
        XCTAssertEqual(ResidenceCountry.austria.timeZoneIdentifier, "Europe/Vienna")
    }

    func testCountryNamesUsedByHomeFollowSelectedCountryAndLanguage() {
        XCTAssertEqual(ResidenceCountry.germany.homeHeroName(languageIdentifier: "uk"), "Німеччині")
        XCTAssertEqual(ResidenceCountry.germany.homeHeroName(languageIdentifier: "de-DE"), "in Deutschland")
        XCTAssertEqual(ResidenceCountry.austria.homeHeroName(languageIdentifier: "en_GB"), "in Austria")
        XCTAssertEqual(ResidenceCountry.germany.ukrainianGenitiveName, "Німеччини")
        XCTAssertEqual(ResidenceCountry.austria.currencyCode, "EUR")
    }

    func testCountryScopedURLReplacesStaleScope() throws {
        let originalBaseURL = APIClient.baseURL
        let originalCountry = APIClient.countryCode
        let originalSubdivision = APIClient.subdivisionCode
        let originalLanguage = APIClient.preferredLanguage
        defer {
            APIClient.baseURL = originalBaseURL
            APIClient.configureCountry(
                country: originalCountry,
                subdivision: originalSubdivision,
                language: originalLanguage
            )
        }

        APIClient.baseURL = try XCTUnwrap(URL(string: "https://example.com"))
        APIClient.configureCountry(country: "DE", subdivision: "DE-BE", language: "de-DE")

        let url = APIClient.countryScopedURL(
            "marketplace?country_code=CH&language=uk&page=2",
            includeSubdivision: true,
            language: APIClient.preferredLanguage
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(components.path, "/api/v1/marketplace")
        XCTAssertEqual(query["country_code"], "DE")
        XCTAssertEqual(query["subdivision_code"], "DE-BE")
        XCTAssertEqual(query["language"], "de")
        XCTAssertEqual(query["page"], "2")
    }

    func testSwissOtherStatusMatchesLegacyPermitType() {
        let codes = CountryCatalog.statuses(for: .switzerland).map(\.code)
        XCTAssertTrue(codes.contains(PermitType.other.rawValue))
        XCTAssertTrue(codes.allSatisfy { PermitType(rawValue: $0) != nil })
    }

    func testRegionalPlaceDecodingKeepsCountryAndSubdivision() throws {
        let data = Data(#"""
        {
          "id":"de000001-0000-4000-8000-000000000001",
          "name":"Landesamt für Einwanderung Berlin",
          "type":"government",
          "category":"migration_office",
          "address":{"street":"Friedrich-Krause-Ufer","houseNumber":"24","postalCode":"13353","city":"Berlin","canton":"ZH"},
          "coordinate":{"latitude":52.538481,"longitude":13.356701},
          "canton":"ZH",
          "countryCode":"DE",
          "subdivisionCode":"DE-BE"
        }
        """#.utf8)

        let place = try JSONDecoder().decode(Place.self, from: data)

        XCTAssertEqual(place.countryCode, "DE")
        XCTAssertEqual(place.subdivisionCode, "DE-BE")
        XCTAssertEqual(place.formattedAddress, "Friedrich-Krause-Ufer 24, 13353 Berlin")
    }
}
