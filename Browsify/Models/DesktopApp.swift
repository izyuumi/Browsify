//
//  DesktopApp.swift
//  Browsify
//

import Foundation
import AppKit

struct DesktopApp: Identifiable, Hashable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
    let urlSchemes: [String]
    let domainPatterns: [String]

    init(id: UUID = UUID(), name: String, bundleIdentifier: String, urlSchemes: [String], domainPatterns: [String] = []) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.urlSchemes = urlSchemes
        self.domainPatterns = domainPatterns
    }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    func canHandle(url: URL) -> Bool {
        guard isInstalled else { return false }

        // Check URL scheme
        if let scheme = url.scheme, urlSchemes.contains(scheme) {
            return true
        }

        // Check domain patterns
        if let host = url.host {
            for pattern in domainPatterns {
                if pattern.contains("*") {
                    let regexPattern = pattern
                        .replacingOccurrences(of: ".", with: "\\.")
                        .replacingOccurrences(of: "*", with: ".*")
                    if host.range(of: regexPattern, options: .regularExpression) != nil {
                        return true
                    }
                } else if host.contains(pattern) {
                    return true
                }
            }
        }

        return false
    }

    func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static let knownApps: [DesktopApp] = [
        DesktopApp(name: "Zoom", bundleIdentifier: "us.zoom.xos",
                   urlSchemes: ["zoommtg", "zoomus"],
                   domainPatterns: ["zoom.us"]),
        DesktopApp(name: "Microsoft Teams", bundleIdentifier: "com.microsoft.teams2",
                   urlSchemes: ["msteams"],
                   domainPatterns: ["teams.microsoft.com", "teams.live.com"]),
        DesktopApp(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap",
                   urlSchemes: ["slack"],
                   domainPatterns: ["*.slack.com"]),
        DesktopApp(name: "Figma", bundleIdentifier: "com.figma.Desktop",
                   urlSchemes: ["figma"],
                   domainPatterns: ["figma.com"]),
        DesktopApp(name: "Spotify", bundleIdentifier: "com.spotify.client",
                   urlSchemes: ["spotify"],
                   domainPatterns: ["open.spotify.com"]),
        DesktopApp(name: "Discord", bundleIdentifier: "com.hnc.Discord",
                   urlSchemes: ["discord"],
                   domainPatterns: ["discord.com", "discord.gg"]),
        DesktopApp(name: "Notion", bundleIdentifier: "notion.id",
                   urlSchemes: ["notion"],
                   domainPatterns: ["notion.so"]),
        DesktopApp(name: "Linear", bundleIdentifier: "com.linear",
                   urlSchemes: ["linear"],
                   domainPatterns: ["linear.app"]),
        DesktopApp(name: "Miro", bundleIdentifier: "com.realtimeboard.miro",
                   urlSchemes: ["miro"],
                   domainPatterns: ["miro.com"]),
    ]
}
