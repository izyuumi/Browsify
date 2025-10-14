//
//  RoutingRule.swift
//  Browsify
//

import Foundation

enum RuleMatchType: String, Codable, CaseIterable {
    case domain = "Domain"
    case urlPattern = "URL Pattern"
    case sourceApp = "Source App"
}

enum RuleTarget: Codable, Hashable {
    case browser(browserId: UUID, profileId: UUID?)
    case desktopApp(bundleId: String)

    var description: String {
        switch self {
        case .browser(let browserId, let profileId):
            return "Browser: \(browserId), Profile: \(profileId?.uuidString ?? "default")"
        case .desktopApp(let bundleId):
            return "Desktop App: \(bundleId)"
        }
    }
}

struct RoutingRule: Identifiable, Codable {
    let id: UUID
    var isEnabled: Bool
    var matchType: RuleMatchType
    var pattern: String
    var target: RuleTarget

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        matchType: RuleMatchType,
        pattern: String,
        target: RuleTarget
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.matchType = matchType
        self.pattern = pattern
        self.target = target
    }

    func matches(url: URL, sourceApp: String?) -> Bool {
        guard isEnabled else { return false }

        switch matchType {
        case .domain:
            return url.host?.contains(pattern) == true

        case .urlPattern:
            let urlString = url.absoluteString
            if pattern.contains("*") {
                // Convert wildcard pattern to regex
                let regexPattern = pattern
                    .replacingOccurrences(of: ".", with: "\\.")
                    .replacingOccurrences(of: "*", with: ".*")
                return urlString.range(of: regexPattern, options: .regularExpression) != nil
            } else {
                return urlString.contains(pattern)
            }

        case .sourceApp:
            guard let sourceApp = sourceApp else { return false }
            return sourceApp.contains(pattern)
        }
    }
}
