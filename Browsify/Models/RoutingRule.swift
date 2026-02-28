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
            return RoutingRule.wildcardMatch(text: host, pattern: pattern, caseInsensitive: true)

        case .urlPattern:
            let urlString = url.absoluteString
            return RoutingRule.wildcardMatch(text: urlString, pattern: pattern, caseInsensitive: false)

        case .sourceApp:
            guard let sourceApp = sourceApp else { return false }
            return sourceApp.contains(pattern)
        }
    }

    // MARK: - Wildcard Matching

    /// Cache of compiled NSRegularExpression objects keyed by wildcard pattern.
    /// NSCache is thread-safe and evicts entries automatically under memory pressure.
    private static let regexCache = NSCache<NSString, NSRegularExpression>()

    /// Matches `text` against `pattern`, where `*` is a wildcard that matches
    /// any sequence of characters (including none). Falls back to substring
    /// containment when the pattern contains no wildcards.
    static func wildcardMatch(text: String, pattern: String, caseInsensitive: Bool) -> Bool {
        guard pattern.contains("*") else {
            let options: String.CompareOptions = caseInsensitive ? [.caseInsensitive] : []
            return text.range(of: pattern, options: options) != nil
        }

        // Build a regex from the wildcard pattern:
        //   1. Escape regex metacharacters (except *)
        //   2. Replace * with .*
        let regexPattern = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
        let cacheKey = "\(caseInsensitive ? "i" : "s"):\(regexPattern)"

        let regex: NSRegularExpression
        if let cached = regexCache.object(forKey: cacheKey as NSString) {
            regex = cached
        } else {
            guard let compiled = try? NSRegularExpression(
                pattern: regexPattern,
                options: caseInsensitive ? [.caseInsensitive] : []
            ) else {
                let options: String.CompareOptions = caseInsensitive ? [.caseInsensitive] : []
                return text.range(of: pattern, options: options) != nil
            }
            regexCache.setObject(compiled, forKey: cacheKey as NSString)
            regex = compiled
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
