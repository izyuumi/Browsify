//
//  BrowserDetector.swift
//  Browsify
//

import Foundation
import Combine
import AppKit

struct BrowserApplicationCandidate: Equatable {
    let name: String
    let bundleIdentifier: String?
    /// Symlink-resolved path, used only to recognise two entries as the same application.
    let canonicalPath: String
    /// Path as LaunchServices reported it, used when launching. Symlink-resolved paths can
    /// point into locations a sandboxed process cannot read, so they are never launched from.
    let launchPath: String

    init(name: String, bundleIdentifier: String?, canonicalPath: String, launchPath: String? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.canonicalPath = canonicalPath
        self.launchPath = launchPath ?? canonicalPath
    }

    var stableIdentityKey: String {
        bundleIdentifier ?? canonicalPath
    }
}

enum BrowserDiscovery {
    static func merge(
        known: [BrowserApplicationCandidate],
        dynamic: [BrowserApplicationCandidate],
        mainBundleIdentifier: String?,
        mainBundlePath: String?
    ) -> [BrowserApplicationCandidate] {
        var applications: [BrowserApplicationCandidate] = []
        var bundleIdentifiers = Set<String>()
        var paths = Set<String>()

        for application in known + dynamic {
            if (mainBundleIdentifier != nil && application.bundleIdentifier == mainBundleIdentifier) ||
                (mainBundlePath != nil && application.canonicalPath == mainBundlePath) ||
                (application.bundleIdentifier == nil && application.name == "Browsify") {
                continue
            }

            if paths.contains(application.canonicalPath) {
                continue
            }

            if let bundleIdentifier = application.bundleIdentifier,
               bundleIdentifiers.contains(bundleIdentifier) {
                continue
            }

            applications.append(application)
            paths.insert(application.canonicalPath)
            if let bundleIdentifier = application.bundleIdentifier {
                bundleIdentifiers.insert(bundleIdentifier)
            }
        }

        return applications
    }

    static func applyingSafariFallback<Application>(
        to applications: [Application],
        safari: Application?
    ) -> [Application] {
        applications.isEmpty ? safari.map { [$0] } ?? [] : applications
    }
}

class BrowserDetector: ObservableObject {
    @Published var browsers: [Browser] = []
    @Published var allBrowsers: [Browser] = [] // Includes hidden browsers

    private let customBrowsersKey = "customBrowsers"
    private let hiddenBrowsersKey = "hiddenBrowsers"
    private let browserOrderKey = "browserOrder"
    private let browserUUIDMapKey = "browserUUIDMap" // Maps bundleId -> UUID
    private let accessManager: AccessManager

    // Cache detected browsers to avoid redundant filesystem scans
    private var cachedDetectedBrowsers: [Browser] = []
    private var safariFallbackBrowser: Browser?

    init(accessManager: AccessManager = .shared) {
        self.accessManager = accessManager
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
        updateBrowserVisibility() // Only update visibility, no need to re-scan
    }

    func unhideBrowser(_ browser: Browser) {
        var hiddenIds = loadHiddenBrowserIds()
        hiddenIds.remove(browser.id)
        saveHiddenBrowserIds(hiddenIds)
        updateBrowserVisibility() // Only update visibility, no need to re-scan
    }

    func isHidden(_ browser: Browser) -> Bool {
        let hiddenIds = loadHiddenBrowserIds()
        return hiddenIds.contains(browser.id)
    }

    func saveBrowserDisplayOrder(_ browsers: [Browser]) {
        let order = browsers.map { $0.id }
        saveBrowserOrder(order)
        updateBrowserVisibility()
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

    private func loadBrowserOrder() -> [UUID] {
        guard let data = UserDefaults.standard.data(forKey: browserOrderKey),
              let order = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return order
    }

    private func saveBrowserOrder(_ order: [UUID]) {
        if let data = try? JSONEncoder().encode(order) {
            UserDefaults.standard.set(data, forKey: browserOrderKey)
        }
    }

    private func loadBrowserUUIDMap() -> [String: UUID] {
        guard let data = UserDefaults.standard.data(forKey: browserUUIDMapKey),
              let map = try? JSONDecoder().decode([String: UUID].self, from: data) else {
            return [:]
        }
        return map
    }

    private func saveBrowserUUIDMap(_ map: [String: UUID]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: browserUUIDMapKey)
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
        var uuidMap = loadBrowserUUIDMap()

        let knownApplications = knownBrowsers.compactMap { name, bundleIdentifier -> BrowserApplicationCandidate? in
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                return nil
            }

            return BrowserApplicationCandidate(
                name: name,
                bundleIdentifier: bundleIdentifier,
                canonicalPath: canonicalPath(for: appURL),
                launchPath: appURL.path
            )
        }

        let dynamicApplications = NSWorkspace.shared.urlsForApplications(
            toOpen: URL(string: "https://example.com")!
        ).map { appURL in
            BrowserApplicationCandidate(
                name: displayName(for: appURL),
                bundleIdentifier: Bundle(url: appURL)?.bundleIdentifier,
                canonicalPath: canonicalPath(for: appURL),
                launchPath: appURL.path
            )
        }

        let applications = BrowserDiscovery.merge(
            known: knownApplications,
            dynamic: dynamicApplications,
            mainBundleIdentifier: Bundle.main.bundleIdentifier,
            mainBundlePath: canonicalPath(for: Bundle.main.bundleURL)
        )

        var detectedBrowsers = applications.map { makeBrowser(from: $0, uuidMap: &uuidMap) }
        safariFallbackBrowser = detectedBrowsers.first(where: { $0.bundleIdentifier == "com.apple.Safari" })
            ?? makeSafariFallbackBrowser(uuidMap: &uuidMap)

        // Add custom browsers (they have their own stable UUIDs)
        let customBrowsers = loadCustomBrowsers()
        detectedBrowsers.append(contentsOf: customBrowsers)

        // Save the updated UUID map
        saveBrowserUUIDMap(uuidMap)

        let sortedBrowsers = detectedBrowsers.sorted { $0.name < $1.name }

        // Cache the detected browsers to avoid re-scanning on visibility changes
        cachedDetectedBrowsers = sortedBrowsers

        // Update the published arrays with visibility filtering
        updateBrowserVisibility()
    }

    private func canonicalPath(for appURL: URL) -> String {
        appURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func displayName(for appURL: URL) -> String {
        let displayName = FileManager.default.displayName(atPath: appURL.path)
        return displayName.hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName
    }

    private func makeBrowser(
        from application: BrowserApplicationCandidate,
        uuidMap: inout [String: UUID]
    ) -> Browser {
        let identityKey = application.stableIdentityKey
        let browserId = uuidMap[identityKey] ?? UUID()
        uuidMap[identityKey] = browserId

        let profiles = application.bundleIdentifier.map {
            detectProfiles(for: $0, name: application.name)
        } ?? []

        return Browser(
            id: browserId,
            name: application.name,
            bundleIdentifier: application.bundleIdentifier,
            path: application.launchPath,
            icon: nil,
            profiles: profiles
        )
    }

    private func makeSafariFallbackBrowser(uuidMap: inout [String: UUID]) -> Browser? {
        guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") else {
            return nil
        }

        return makeBrowser(
            from: BrowserApplicationCandidate(
                name: "Safari",
                bundleIdentifier: "com.apple.Safari",
                canonicalPath: canonicalPath(for: safariURL),
                launchPath: safariURL.path
            ),
            uuidMap: &uuidMap
        )
    }

    /// Installed browsers whose profile metadata can be read after a user grant.
    var profileCapableBrowsers: [Browser] {
        allBrowsers.filter {
            $0.bundleIdentifier.map { accessManager.supportsProfileDetection(for: $0) } ?? false
        }
    }

    func hasProfileAccess(for browser: Browser) -> Bool {
        browser.bundleIdentifier.map { accessManager.hasProfileFolderAccess(for: $0) } ?? false
    }

    func requestProfileAccess(for browser: Browser) {
        guard let bundleIdentifier = browser.bundleIdentifier else { return }
        accessManager.requestProfileFolderAccess(for: bundleIdentifier) { [weak self] granted in
            guard granted else { return }
            self?.detectBrowsers()
        }
    }

    /// Updates browser visibility filtering without performing filesystem scans.
    /// This method uses cached detection results and only filters based on hidden status.
    /// Use this instead of detectBrowsers() when only hide/unhide operations occur.
    private func updateBrowserVisibility() {
        let hiddenIds = loadHiddenBrowserIds()

        let savedOrder = loadBrowserOrder()

        if !savedOrder.isEmpty {
            // Create lookup dictionary for fast access
            let browserDict = cachedDetectedBrowsers.reduce(into: [UUID: Browser]()) { dict, browser in
                dict[browser.id] = browser
            }

            // Build ordered array
            var orderedBrowsers: [Browser] = []
            for id in savedOrder {
                if let browser = browserDict[id] {
                    orderedBrowsers.append(browser)
                }
            }

            // Add any browsers not in saved order (newly detected browsers)
            let orderedIds = Set(savedOrder)
            let remainingBrowsers = cachedDetectedBrowsers.filter { !orderedIds.contains($0.id) }
            orderedBrowsers.append(contentsOf: remainingBrowsers)

            // Apply ordering to cached browsers
            cachedDetectedBrowsers = orderedBrowsers
        }

        DispatchQueue.main.async {
            // allBrowsers includes hidden browsers (for settings view)
            self.allBrowsers = self.cachedDetectedBrowsers
            // browsers excludes hidden browsers (for picker view)
            let visibleBrowsers = self.cachedDetectedBrowsers.filter { !hiddenIds.contains($0.id) }
            self.browsers = BrowserDiscovery.applyingSafariFallback(
                to: visibleBrowsers,
                safari: self.safariFallbackBrowser
            )
        }
    }

    private func detectProfiles(for bundleId: String, name: String) -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []

        // Chrome/Chromium-based browsers
        if BrowserProfile.isChromiumFamilyBundleIdentifier(bundleId) {
            profiles = detectChromeProfiles(bundleId: bundleId)
        }

        // Firefox
        if BrowserProfile.usesFirefoxProfile(bundleId) {
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
        accessManager.withProfileFolderAccess(for: bundleId) { configDirectory in
            // Local State contains the Chrome-family profile info cache.
            let localStateURL = configDirectory.appendingPathComponent("Local State")
            guard let data = try? Data(contentsOf: localStateURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let profileInfo = json["profile"] as? [String: Any],
                  let infoCache = profileInfo["info_cache"] as? [String: Any] else {
                return
            }

            for (profilePath, profileData) in infoCache {
                if let profileDict = profileData as? [String: Any],
                   let profileName = profileDict["name"] as? String {
                    profiles.append(BrowserProfile(
                        name: profileName,
                        profilePath: profilePath,
                        browserBundleId: bundleId
                    ))
                }
            }
        }

        return profiles.sorted { $0.name < $1.name }
    }

    private func detectFirefoxProfiles(bundleId: String) -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []
        guard let optionalProfilesData = accessManager.withProfileFolderAccess(for: bundleId, perform: {
            try? String(contentsOf: $0.appendingPathComponent("profiles.ini"), encoding: .utf8)
        }),
        let profilesData = optionalProfilesData,
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
