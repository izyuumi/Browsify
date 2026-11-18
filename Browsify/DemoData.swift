//
//  DemoData.swift
//  Browsify
//

import AppKit

extension UserDefaults {
    /// Store for all of Browsify's settings. Release builds always use `.standard`;
    /// DEBUG `--demo-data` swaps in a throwaway suite so captures never touch real settings.
    static let browsify: UserDefaults = {
        #if DEBUG
        if DemoData.isEnabled { return DemoData.makeDefaults() }
        #endif
        return .standard
    }()
}

#if DEBUG
/// Fixed, non-personal data for screenshots and preview videos.
///
/// Enabled by `--demo-data` (and always by `--export-ui-screens`). In demo mode Browsify reads
/// and writes a dedicated suite that is wiped on every launch and on quit, lists only the
/// browsers below, and never reads browser profile folders or security-scoped bookmarks.
enum DemoData {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("--demo-data")
        || ProcessInfo.processInfo.arguments.contains("--export-ui-screens")

    static let suiteName = (Bundle.main.bundleIdentifier ?? "Browsify") + ".DemoData"
    static let pickerURL = URL(string: "https://docs.example.com/q4-roadmap")!

    /// Value of a `--name=value` launch argument.
    static func argument(_ name: String) -> String? {
        let prefix = "--\(name)="
        return ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(prefix) })
            .map { String($0.dropFirst(prefix.count)) }
    }

    static let profiles = [
        Profile(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, name: "Work"),
        Profile(id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!, name: "Personal")
    ]

    static let chromeProfiles = [
        BrowserProfile(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            name: "Work",
            profilePath: "Profile 1",
            browserBundleId: "com.google.Chrome"
        ),
        BrowserProfile(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
            name: "Personal",
            profilePath: "Default",
            browserBundleId: "com.google.Chrome"
        )
    ]

    static let browsers: [Browser] = [
        browser(1, "Safari", "com.apple.Safari"),
        browser(2, "Google Chrome", "com.google.Chrome", profiles: chromeProfiles),
        browser(
            3, "Firefox", "org.mozilla.firefox",
            path: ProcessInfo.processInfo.environment["BROWSIFY_SCREENSHOT_FIREFOX_PATH"]
        ),
        browser(4, "Brave Browser", "com.brave.Browser")
    ]

    static var rules: [RoutingRule] {
        let safari = browsers[0].id
        let chrome = browsers[1].id
        return [
            RoutingRule(
                matchType: .domain,
                pattern: "github.com",
                target: .browser(browserId: chrome, profileId: chromeProfiles[0].id),
                profileIds: [profiles[0].id]
            ),
            RoutingRule(matchType: .domain, pattern: "*.zoom.us", target: .desktopApp(bundleId: "us.zoom.xos")),
            RoutingRule(matchType: .domain, pattern: "docs.example.com", target: .browser(browserId: safari, profileId: nil)),
            RoutingRule(matchType: .sourceApp, pattern: "com.apple.mail", target: .browser(browserId: safari, profileId: nil))
        ]
    }

    /// A clean suite seeded with demo rules and profiles.
    static func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(try? JSONEncoder().encode(rules), forKey: "routingRules")
        defaults.set(try? JSONEncoder().encode(profiles), forKey: "profiles")
        defaults.set(profiles[0].id.uuidString, forKey: "activeProfileId")
        defaults.set(true, forKey: "stripTrackingParameters")
        return defaults
    }

    static func wipe() {
        UserDefaults.browsify.removePersistentDomain(forName: suiteName)
    }

    /// Applies `--appearance=light|dark`.
    static func applyAppearance() {
        switch argument("appearance") {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
    }

    /// `--settings-tab=preferences|browsers|rules|profiles|about`.
    static var settingsTab: SettingsTab? {
        switch argument("settings-tab") {
        case "preferences": .preferences
        case "browsers": .browsers
        case "rules": .rules
        case "profiles": .profiles
        case "about": .about
        default: nil
        }
    }

    private static func browser(
        _ index: Int,
        _ name: String,
        _ bundleIdentifier: String,
        path: String? = nil,
        profiles: [BrowserProfile] = []
    ) -> Browser {
        Browser(
            id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", index))!,
            name: name,
            bundleIdentifier: bundleIdentifier,
            // A missing app falls back to a generic globe icon (see Browser.iconImage).
            path: path
                ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)?.path
                ?? "/Applications/\(name).app",
            profiles: profiles
        )
    }
}
#endif
