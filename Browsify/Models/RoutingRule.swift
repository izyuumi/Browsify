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
            guard let host = url.host else { return false }
            return RoutingRule.wildcardMatch(text: host, pattern: pattern)

        case .urlPattern:
            let urlString = url.absoluteString
            return RoutingRule.wildcardMatch(text: urlString, pattern: pattern)

        case .sourceApp:
            guard let sourceApp = sourceApp else { return false }
            return sourceApp.contains(pattern)
        }
    }

    // MARK: - Wildcard Matching

    /// Cache of compiled NSRegularExpression objects keyed by wildcard pattern.
    private static var regexCache: [String: NSRegularExpression] = [:]

    /// Matches `text` against `pattern`, where `*` is a wildcard that matches
    /// any sequence of characters (including none). Falls back to substring
    /// containment when the pattern contains no wildcards.
    static func wildcardMatch(text: String, pattern: String) -> Bool {
        guard pattern.contains("*") else {
            return text.lowercased().contains(pattern.lowercased())
        }

        // Build a regex from the wildcard pattern:
        //   1. Escape regex metacharacters (except *)
        //   2. Replace * with .*
        let regexPattern: String = {
            let escaped = NSRegularExpression.escapedPattern(for: pattern)
                .replacingOccurrences(of: "\\*", with: ".*")
            return "^" + escaped + "$"
        }()

        let regex: NSRegularExpression
        if let cached = regexCache[regexPattern] {
            regex = cached
        } else {
            guard let compiled = try? NSRegularExpression(
                pattern: regexPattern,
                options: [.caseInsensitive]
            ) else {
                return text.lowercased().contains(pattern.lowercased())
            }
            regexCache[regexPattern] = compiled
            regex = compiled
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
