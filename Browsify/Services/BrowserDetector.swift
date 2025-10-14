//
//  BrowserDetector.swift
//  Browsify
//

import Foundation
import Combine
import AppKit

class BrowserDetector: ObservableObject {
    @Published var browsers: [Browser] = []
    @Published var allBrowsers: [Browser] = [] // Includes hidden browsers

    private let customBrowsersKey = "customBrowsers"
    private let hiddenBrowsersKey = "hiddenBrowsers"

    init() {
        // Auto-detect browsers on initialization
        detectBrowsers()
    }

    func addCustomBrowser(_ browser: Browser) {
        var customBrowsers = loadCustomBrowsers()
        customBrowsers.append(browser)
        saveCustomBrowsers(customBrowsers)
        detectBrowsers()
    }

    func updateCustomBrowser(_ browser: Browser) {
        var customBrowsers = loadCustomBrowsers()
        if let index = customBrowsers.firstIndex(where: { $0.id == browser.id }) {
            customBrowsers[index] = browser
            saveCustomBrowsers(customBrowsers)
            detectBrowsers()
        }
    }

    func deleteCustomBrowser(_ browser: Browser) {
        var customBrowsers = loadCustomBrowsers()
        customBrowsers.removeAll { $0.id == browser.id }
        saveCustomBrowsers(customBrowsers)
        detectBrowsers()
    }

    func isCustomBrowser(_ browser: Browser) -> Bool {
        let customBrowsers = loadCustomBrowsers()
        return customBrowsers.contains(where: { $0.id == browser.id })
    }

    func hideBrowser(_ browser: Browser) {
        var hiddenIds = loadHiddenBrowserIds()
        hiddenIds.insert(browser.id)
        saveHiddenBrowserIds(hiddenIds)
        detectBrowsers()
    }

    func unhideBrowser(_ browser: Browser) {
        var hiddenIds = loadHiddenBrowserIds()
        hiddenIds.remove(browser.id)
        saveHiddenBrowserIds(hiddenIds)
        detectBrowsers()
    }

    func isHidden(_ browser: Browser) -> Bool {
        let hiddenIds = loadHiddenBrowserIds()
        return hiddenIds.contains(browser.id)
    }

    private func loadCustomBrowsers() -> [Browser] {
        guard let data = UserDefaults.standard.data(forKey: customBrowsersKey),
              let browsers = try? JSONDecoder().decode([Browser].self, from: data) else {
            return []
        }
        return browsers
    }

    private func saveCustomBrowsers(_ browsers: [Browser]) {
        if let data = try? JSONEncoder().encode(browsers) {
            UserDefaults.standard.set(data, forKey: customBrowsersKey)
        }
    }

    private func loadHiddenBrowserIds() -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: hiddenBrowsersKey),
              let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) else {
            return []
        }
        return ids
    }

    private func saveHiddenBrowserIds(_ ids: Set<UUID>) {
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: hiddenBrowsersKey)
        }
    }

    private let knownBrowsers: [(name: String, bundleId: String)] = [
        ("Safari", "com.apple.Safari"),
        ("Google Chrome", "com.google.Chrome"),
        ("Firefox", "org.mozilla.firefox"),
        ("Microsoft Edge", "com.microsoft.edgemac"),
        ("Brave Browser", "com.brave.Browser"),
        ("Opera", "com.operasoftware.Opera"),
        ("Vivaldi", "com.vivaldi.Vivaldi"),
        ("Arc", "company.thebrowser.Browser"),
        ("Chromium", "org.chromium.Chromium"),
        ("Safari Technology Preview", "com.apple.SafariTechnologyPreview"),
        ("DuckDuckGo", "com.duckduckgo.macos.browser"),
        ("Orion", "com.kagi.kagimacOS"),
    ]

    func detectBrowsers() {
        var detectedBrowsers: [Browser] = []

        // Auto-detect known browsers
        for (name, bundleId) in knownBrowsers {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let path = appURL.path

                // Detect profiles for this browser
                let profiles = detectProfiles(for: bundleId, name: name)

                let browser = Browser(
                    name: name,
                    bundleIdentifier: bundleId,
                    path: path,
                    icon: nil, // Let iconImage computed property handle icon loading
                    profiles: profiles
                )

                detectedBrowsers.append(browser)
            }
        }

        // Add custom browsers
        let customBrowsers = loadCustomBrowsers()
        detectedBrowsers.append(contentsOf: customBrowsers)

        let sortedBrowsers = detectedBrowsers.sorted { $0.name < $1.name }
        let hiddenIds = loadHiddenBrowserIds()

        DispatchQueue.main.async {
            // allBrowsers includes hidden browsers (for settings view)
            self.allBrowsers = sortedBrowsers
            // browsers excludes hidden browsers (for picker view)
            self.browsers = sortedBrowsers.filter { !hiddenIds.contains($0.id) }
        }
    }

    private func detectProfiles(for bundleId: String, name: String) -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []

        // Chrome-based browsers
        if bundleId.contains("chrome") || bundleId == "com.brave.Browser" ||
           bundleId == "com.microsoft.edgemac" || bundleId == "com.vivaldi.Vivaldi" {
            profiles = detectChromeProfiles(bundleId: bundleId)
        }

        // Firefox
        if bundleId.contains("firefox") {
            profiles = detectFirefoxProfiles(bundleId: bundleId)
        }

        // Arc (uses separate "Spaces" concept, not traditional profiles)
        if bundleId == "company.thebrowser.Browser" {
            profiles = []
        }

        return profiles
    }

    private func detectChromeProfiles(bundleId: String) -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []

        // Determine the Chrome config directory based on bundle ID
        var configDir = ""
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        switch bundleId {
        case "com.google.Chrome":
            configDir = "\(homeDir)/Library/Application Support/Google/Chrome"
        case "com.brave.Browser":
            configDir = "\(homeDir)/Library/Application Support/BraveSoftware/Brave-Browser"
        case "com.microsoft.edgemac":
            configDir = "\(homeDir)/Library/Application Support/Microsoft Edge"
        case "com.vivaldi.Vivaldi":
            configDir = "\(homeDir)/Library/Application Support/Vivaldi"
        default:
            return profiles
        }

        // Check for Local State file which contains profile info
        let localStatePath = "\(configDir)/Local State"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: localStatePath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileInfo = json["profile"] as? [String: Any],
              let infoCache = profileInfo["info_cache"] as? [String: Any] else {
            return profiles
        }

        for (profilePath, profileData) in infoCache {
            if let profileDict = profileData as? [String: Any],
               let profileName = profileDict["name"] as? String {
                let profile = BrowserProfile(
                    name: profileName,
                    profilePath: profilePath,
                    browserBundleId: bundleId
                )
                profiles.append(profile)
            }
        }

        return profiles.sorted { $0.name < $1.name }
    }

    private func detectFirefoxProfiles(bundleId: String) -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let profilesPath = "\(homeDir)/Library/Application Support/Firefox/profiles.ini"

        guard let profilesData = try? String(contentsOfFile: profilesPath, encoding: .utf8),
              !profilesData.isEmpty else {
            return profiles
        }

        // Parse INI format
        var currentProfile: [String: String] = [:]

        for line in profilesData.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                // Save previous profile
                if let name = currentProfile["Name"], let path = currentProfile["Path"] {
                    let profile = BrowserProfile(
                        name: name,
                        profilePath: path,
                        browserBundleId: bundleId
                    )
                    profiles.append(profile)
                }

                // Start new section
                currentProfile = [:]
            } else if let range = trimmed.range(of: "=") {
                let key = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                currentProfile[key] = value
            }
        }

        // Don't forget the last profile
        if let name = currentProfile["Name"], let path = currentProfile["Path"] {
            let profile = BrowserProfile(
                name: name,
                profilePath: path,
                browserBundleId: bundleId
            )
            profiles.append(profile)
        }

        return profiles.sorted { $0.name < $1.name }
    }
}
