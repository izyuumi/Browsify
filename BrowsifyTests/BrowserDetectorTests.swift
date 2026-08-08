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

    func testMergeDropsUnreadableUpdateCopyWithSameBrowserName() {
        let installed = BrowserApplicationCandidate(
            name: "Brave Browser",
            bundleIdentifier: "com.brave.Browser",
            canonicalPath: "/Applications/Brave Browser.app"
        )
        let cachedUpdate = BrowserApplicationCandidate(
            name: "Brave Browser",
            bundleIdentifier: nil,
            canonicalPath: "/Users/example/Library/Caches/Brave Browser.app"
        )

        let result = BrowserDiscovery.merge(
            known: [installed],
            dynamic: [cachedUpdate],
            mainBundleIdentifier: "to.yumi.Browsify",
            mainBundlePath: "/Applications/Browsify.app"
        )

        XCTAssertEqual(result, [installed])
    }

    func testMergeDeduplicatesBySymlinkResolvedPathWhileKeepingTheLaunchPath() {
        // Safari is reported at /Applications/Safari.app but resolves into the read-protected
        // system cryptex; the resolved path identifies it, the reported path launches it.
        let known = BrowserApplicationCandidate(
            name: "Safari",
            bundleIdentifier: nil,
            canonicalPath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
            launchPath: "/Applications/Safari.app"
        )
        let duplicate = BrowserApplicationCandidate(
            name: "Safari",
            bundleIdentifier: nil,
            canonicalPath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
            launchPath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
        )

        let result = BrowserDiscovery.merge(
            known: [known],
            dynamic: [duplicate],
            mainBundleIdentifier: "to.yumi.Browsify",
            mainBundlePath: "/Applications/Browsify.app"
        )

        XCTAssertEqual(result, [known])
        XCTAssertEqual(result.first?.launchPath, "/Applications/Safari.app")
    }

    func testCandidateLaunchPathDefaultsToCanonicalPath() {
        let candidate = BrowserApplicationCandidate(
            name: "Firefox",
            bundleIdentifier: "org.mozilla.firefox",
            canonicalPath: "/Applications/Firefox.app"
        )

        XCTAssertEqual(candidate.launchPath, "/Applications/Firefox.app")
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
