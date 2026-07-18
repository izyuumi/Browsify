//
//  RuleEngineTests.swift
//  BrowsifyTests
//

import XCTest
@testable import Browsify

final class RuleEngineTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "BrowsifyTests.RuleEngineTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDomainRuleMatchesWildcardSubdomain() throws {
        let rule = makeRule(matchType: .domain, pattern: "*.example.com")
        let engine = RuleEngine(defaults: defaults)
        engine.rules = [rule]

        let match = engine.findMatchingRule(
            for: try XCTUnwrap(URL(string: "https://api.example.com/path")),
            sourceApp: nil
        )

        XCTAssertEqual(match?.id, rule.id)
    }

    func testURLPatternRuleMatchesWildcards() throws {
        let rule = makeRule(matchType: .urlPattern, pattern: "example.com/path/*")
        let engine = RuleEngine(defaults: defaults)
        engine.rules = [rule]

        let match = engine.findMatchingRule(
            for: try XCTUnwrap(URL(string: "https://example.com/path/document?mode=edit")),
            sourceApp: nil
        )

        XCTAssertEqual(match?.id, rule.id)
    }

    func testSourceAppRuleMatchesWildcardCaseInsensitively() throws {
        let rule = makeRule(matchType: .sourceApp, pattern: "com.acme.*")
        let engine = RuleEngine(defaults: defaults)
        engine.rules = [rule]

        let match = engine.findMatchingRule(
            for: try XCTUnwrap(URL(string: "https://example.com")),
            sourceApp: "COM.ACME.MAIL"
        )

        XCTAssertEqual(match?.id, rule.id)
    }

    func testFirstMatchingRuleWins() throws {
        let first = makeRule(matchType: .domain, pattern: "example.com", target: .desktopApp(bundleId: "first.app"))
        let second = makeRule(matchType: .domain, pattern: "*.example.com", target: .desktopApp(bundleId: "second.app"))
        let engine = RuleEngine(defaults: defaults)
        engine.rules = [first, second]

        let match = engine.findMatchingRule(
            for: try XCTUnwrap(URL(string: "https://example.com")),
            sourceApp: nil
        )

        XCTAssertEqual(match?.id, first.id)
        XCTAssertEqual(match?.target, .desktopApp(bundleId: "first.app"))
    }

    func testRulesPersistAndReloadFromInjectedDefaults() {
        let rule = makeRule(matchType: .domain, pattern: "persisted.example")
        let writer = RuleEngine(defaults: defaults)
        writer.addRule(rule)

        let reader = RuleEngine(defaults: defaults)

        XCTAssertTrue(reader.rules.contains(where: { $0.id == rule.id }))
    }

    private func makeRule(
        matchType: RuleMatchType,
        pattern: String,
        target: RuleTarget = .desktopApp(bundleId: "com.example.app")
    ) -> RoutingRule {
        RoutingRule(matchType: matchType, pattern: pattern, target: target)
    }
}
