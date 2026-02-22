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

    // MARK: - Import / Export

    func exportRules() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(rules)
    }

    func importRules(from data: Data, replacing: Bool) throws {
        let decoder = JSONDecoder()
        let imported = try decoder.decode([RoutingRule].self, from: data)
        if replacing {
            rules = imported
        } else {
            let existingIds = Set(rules.map(\.id))
            let newRules = imported.filter { !existingIds.contains($0.id) }
            rules.append(contentsOf: newRules)
        }
        saveRules()
    }
}
