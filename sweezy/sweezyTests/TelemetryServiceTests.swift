import Testing
@testable import sweezy

@MainActor
struct TelemetryServiceTests {
    @Test func eventNamesAreNormalized() {
        #expect(TelemetryService.normalizedName("Guide Read!") == "guide_read")
    }

    @Test func metadataDropsLikelyPIIAndCredentials() {
        let result = TelemetryService.sanitizedMetadata([
            "category": "housing",
            "email": "person@example.com",
            "user_name": "Person",
            "access_token": "secret",
            "message_body": "private",
        ])

        #expect(result == ["category": "housing"])
    }

    @Test func metadataValuesAreBounded() {
        let result = TelemetryService.sanitizedMetadata(["value": String(repeating: "x", count: 300)])
        #expect(result["value"]?.count == 256)
    }
}
