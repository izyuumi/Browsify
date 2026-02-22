//
//  RuleEngine.swift
//  Browsify
//

import Foundation
import Combine
import SwiftUI

class RuleEngine: ObservableObject {
    @Published var rules: [RoutingRule] = []

    init() {
        loadRules()
    }

    func addRule(_ rule: RoutingRule) {
        rules.append(rule)
        saveRules()
    }

    func updateRule(_ rule: RoutingRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveRules()
        }
    }

    func deleteRule(_ rule: RoutingRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
    }

    func findMatchingRule(for url: URL, sourceApp: String?) -> RoutingRule? {
        // Rules are evaluated in the current order
        for (index, rule) in rules.enumerated() {
            if rule.matches(url: url, sourceApp: sourceApp) {
                rules[index].matchCount += 1
                rules[index].lastMatchedAt = Date()
                saveRules()
                return rules[index]
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
            rules = decoded
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
            target: .desktopApp(bundleId: "us.zoom.xos")
        )

        let teamsRule = RoutingRule(
            matchType: .domain,
            pattern: "teams.microsoft.com",
            target: .desktopApp(bundleId: "com.microsoft.teams2")
        )

        rules = [zoomRule, teamsRule]
        saveRules()
    }

    func moveRules(fromOffsets source: IndexSet, toOffset destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        saveRules()
    }
}
