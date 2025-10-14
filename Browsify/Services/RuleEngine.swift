//
//  RuleEngine.swift
//  Browsify
//

import Foundation
import Combine

class RuleEngine: ObservableObject {
    @Published var rules: [RoutingRule] = []

    init() {
        loadRules()
    }

    func addRule(_ rule: RoutingRule) {
        insertSorted(rule)
        saveRules()
    }

    func updateRule(_ rule: RoutingRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules.remove(at: index)
            insertSorted(rule)
            saveRules()
        }
    }

    func deleteRule(_ rule: RoutingRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
    }

    func findMatchingRule(for url: URL, sourceApp: String?) -> RoutingRule? {
        // Rules are already sorted by priority (higher priority first)
        for rule in rules {
            if rule.matches(url: url, sourceApp: sourceApp) {
                return rule
            }
        }

        return nil
    }

    private func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: "routingRules")
        }
    }

    private func loadRules() {
        if let data = UserDefaults.standard.data(forKey: "routingRules"),
           let decoded = try? JSONDecoder().decode([RoutingRule].self, from: data) {
            rules = decoded.sorted { $0.priority > $1.priority }
        } else {
            // Create some default rules
            createDefaultRules()
        }
    }

    private func createDefaultRules() {
        // Example default rules - these would be customized by user
        let zoomRule = RoutingRule(
            matchType: .domain,
            pattern: "zoom.us",
            target: .desktopApp(bundleId: "us.zoom.xos"),
            priority: 100
        )

        let teamsRule = RoutingRule(
            matchType: .domain,
            pattern: "teams.microsoft.com",
            target: .desktopApp(bundleId: "com.microsoft.teams2"),
            priority: 100
        )

        rules = [zoomRule, teamsRule].sorted { $0.priority > $1.priority }
        saveRules()
    }

    private func insertSorted(_ rule: RoutingRule) {
        // Find the correct position to insert (higher priority first)
        let insertIndex = rules.firstIndex { $0.priority < rule.priority } ?? rules.count
        rules.insert(rule, at: insertIndex)
    }
}
