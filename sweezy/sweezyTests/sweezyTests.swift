//
//  sweezyTests.swift
//  sweezyTests
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import XCTest
@testable import sweezy

final class sweezyTests: XCTestCase {

    func testExample() async throws {
        // Placeholder test to ensure test target compiles
        XCTAssertTrue(true)
    }

    func testAPIClientURLKeepsQuerySeparateFromPath() throws {
        let originalBaseURL = APIClient.baseURL
        defer { APIClient.baseURL = originalBaseURL }
        APIClient.baseURL = try XCTUnwrap(URL(string: "https://example.com"))

        let url = APIClient.url("chat/conversations?archived=false&cursor=abc%2B123")

        XCTAssertEqual(url.path, "/api/v1/chat/conversations")
        XCTAssertEqual(url.query, "archived=false&cursor=abc%2B123")
        XCTAssertEqual(url.absoluteString, "https://example.com/api/v1/chat/conversations?archived=false&cursor=abc%2B123")
    }

}
