//
//  Browser.swift
//  Browsify
//

import Foundation
import AppKit

struct Browser: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
    let path: String
    let icon: Data?
    var profiles: [BrowserProfile]

    init(id: UUID = UUID(), name: String, bundleIdentifier: String, path: String, icon: Data? = nil, profiles: [BrowserProfile] = []) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.icon = icon
        self.profiles = profiles
    }

    var iconImage: NSImage? {
        if let iconData = icon {
            return NSImage(data: iconData)
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    func openURL(_ url: URL, profile: BrowserProfile? = nil) {
        let configuration = NSWorkspace.OpenConfiguration()

        if let profile = profile, !profile.profilePath.isEmpty {
            // Open with specific profile
            configuration.arguments = profile.launchArguments(for: url)
        }

        NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: path), configuration: configuration) { _, error in
            if let error = error {
                print("Failed to open URL with \(name): \(error.localizedDescription)")
            }
        }
    }
}

struct BrowserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let profilePath: String
    let browserBundleId: String

    init(id: UUID = UUID(), name: String, profilePath: String, browserBundleId: String) {
        self.id = id
        self.name = name
        self.profilePath = profilePath
        self.browserBundleId = browserBundleId
    }

    func launchArguments(for url: URL) -> [String] {
        // Chrome/Chromium-based browsers
        if browserBundleId.contains("chrome") || browserBundleId.contains("chromium") ||
           browserBundleId.contains("brave") || browserBundleId.contains("edge") ||
           browserBundleId.contains("vivaldi") || browserBundleId.contains("arc") {
            return ["--profile-directory=\(profilePath)", url.absoluteString]
        }

        // Firefox
        if browserBundleId.contains("firefox") {
            return ["-P", name, url.absoluteString]
        }

        return [url.absoluteString]
    }
}
