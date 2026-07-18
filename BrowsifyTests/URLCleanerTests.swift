//
//  URLCleanerTests.swift
//  BrowsifyTests
//

import XCTest
@testable import Browsify

final class URLCleanerTests: XCTestCase {
    private let cleaner = URLCleaner.shared

    func testRemovesTrackingParameters() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/article?utm_source=newsletter&fbclid=abc123&title=hello"))

        let cleaned = cleaner.cleanURL(url)

        XCTAssertEqual(cleaned.absoluteString, "https://example.com/article?title=hello")
    }

    func testPreservesNonTrackingParameters() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/search?q=swift&page=2&utm_medium=email"))

        let cleaned = cleaner.cleanURL(url)

        XCTAssertEqual(cleaned.query, "q=swift&page=2")
    }

    func testCleaningIsIdempotent() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/?utm_campaign=launch&ref=feed&id=42"))

        let once = cleaner.cleanURL(url)
        let twice = cleaner.cleanURL(once)

        XCTAssertEqual(twice, once)
    }

    func testURLWithoutQueryIsUnchanged() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/path#section"))

        XCTAssertEqual(cleaner.cleanURL(url), url)
    }
}
