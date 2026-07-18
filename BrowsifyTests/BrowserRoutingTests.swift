//
//  BrowserRoutingTests.swift
//  BrowsifyTests
//

import XCTest
@testable import Browsify

final class BrowserRoutingTests: XCTestCase {
    func testChromiumProfileUsesProfileDirectoryArgument() throws {
        let profile = BrowserProfile(
            name: "Work",
            profilePath: "Profile 3",
            browserBundleId: "com.google.Chrome"
        )
        let url = try XCTUnwrap(URL(string: "https://example.com/path"))

        XCTAssertEqual(
            profile.launchArguments(for: url),
            ["--profile-directory=Profile 3", "https://example.com/path"]
        )
    }

    func testFirefoxProfileUsesProfileNameArgument() throws {
        let profile = BrowserProfile(
            name: "Personal",
            profilePath: "unused",
            browserBundleId: "org.mozilla.firefox"
        )
        let url = try XCTUnwrap(URL(string: "https://example.com"))

        XCTAssertEqual(profile.launchArguments(for: url), ["-P", "Personal", "https://example.com"])
    }

    func testIncidentalBundleIdentifierIsNotChromium() {
        XCTAssertFalse(BrowserProfile.isChromiumFamilyBundleIdentifier("com.example.search"))
    }

    func testArcIsNotChromium() {
        XCTAssertFalse(BrowserProfile.isChromiumFamilyBundleIdentifier("company.thebrowser.Browser"))
    }

    func testFirefoxBundleIdentifierUsesFirefoxProfile() {
        XCTAssertTrue(BrowserProfile.usesFirefoxProfile("org.mozilla.firefox"))
    }
}
