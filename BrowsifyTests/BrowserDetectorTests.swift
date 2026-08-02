//
//  BrowserDetectorTests.swift
//  BrowsifyTests
//

import XCTest
@testable import Browsify

final class BrowserDetectorTests: XCTestCase {
    func testMergePrefersKnownDisplayNameForDynamicDuplicate() {
        let known = BrowserApplicationCandidate(
            name: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            canonicalPath: "/Applications/Google Chrome.app"
        )
        let dynamic = BrowserApplicationCandidate(
            name: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            canonicalPath: "/Applications/Google Chrome.app"
        )

        let result = BrowserDiscovery.merge(
            known: [known],
            dynamic: [dynamic],
            mainBundleIdentifier: "to.yumi.Browsify",
            mainBundlePath: "/Applications/Browsify.app"
        )

        XCTAssertEqual(result, [known])
    }

    func testMergeExcludesBrowsifyAndStaleCopiesIncludingUnreadableBundleIdentifier() {
        let safari = BrowserApplicationCandidate(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            canonicalPath: "/System/Applications/Safari.app"
        )
        let currentBrowsify = BrowserApplicationCandidate(
            name: "Browsify",
            bundleIdentifier: "to.yumi.Browsify",
            canonicalPath: "/Applications/Browsify.app"
        )
        let staleBrowsify = BrowserApplicationCandidate(
            name: "Browsify Debug",
            bundleIdentifier: "to.yumi.Browsify",
            canonicalPath: "/DerivedData/Browsify.app"
        )
        let unreadableBrowsify = BrowserApplicationCandidate(
            name: "Browsify",
            bundleIdentifier: nil,
            canonicalPath: "/DerivedData/Unreadable/Browsify.app"
        )

        let result = BrowserDiscovery.merge(
            known: [],
            dynamic: [safari, currentBrowsify, staleBrowsify, unreadableBrowsify],
            mainBundleIdentifier: "to.yumi.Browsify",
            mainBundlePath: "/Applications/Browsify.app"
        )

        XCTAssertEqual(result, [safari])
    }

    func testMergeKeepsUnreadableBundleIdentifierAndKeysItByPath() {
        let unreadableApp = BrowserApplicationCandidate(
            name: "Google Chrome for Testing",
            bundleIdentifier: nil,
            canonicalPath: "/Users/example/Library/Caches/Google Chrome for Testing.app"
        )

        let result = BrowserDiscovery.merge(
            known: [],
            dynamic: [unreadableApp],
            mainBundleIdentifier: "to.yumi.Browsify",
            mainBundlePath: "/Applications/Browsify.app"
        )

        XCTAssertEqual(result, [unreadableApp])
        XCTAssertEqual(result.first?.stableIdentityKey, unreadableApp.canonicalPath)
    }

    func testSafariFallbackSuppliesSafariWhenNoApplicationsWereDetected() {
        let safari = BrowserApplicationCandidate(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            canonicalPath: "/System/Applications/Safari.app"
        )

        XCTAssertEqual(BrowserDiscovery.applyingSafariFallback(to: [], safari: safari), [safari])
    }
}
