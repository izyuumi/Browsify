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

    func removeProfileReferences(_ profileId: UUID) {
        var didChange = false

        for index in rules.indices {
            let updatedProfileIds = rules[index].profileIds.filter { $0 != profileId }
            if updatedProfileIds.count != rules[index].profileIds.count {
                rules[index].profileIds = updatedProfileIds
                didChange = true
            }
        }

        if didChange {
            saveRules()
        }
    }

    func findMatchingRule(for url: URL, sourceApp: String?) -> RoutingRule? {
        let activeProfileId = ProfileManager.shared.activeProfileId
        let availableProfileIds = Set(ProfileManager.shared.profiles.map(\.id))
        // Rules are evaluated in the current order
        for rule in rules {
            let effectiveProfileIds = rule.profileIds.filter { availableProfileIds.contains($0) }
            // No active profile means all rules are eligible, matching the UI's
            // "None (All Rules Active)" behavior.
            let profileMatch = activeProfileId == nil ||
                effectiveProfileIds.isEmpty ||
                activeProfileId.map(effectiveProfileIds.contains) == true
            if profileMatch && rule.matches(url: url, sourceApp: sourceApp) {
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
}
