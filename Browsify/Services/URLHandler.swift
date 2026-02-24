//
//  URLHandler.swift
//  Browsify
//

import Foundation
import Combine
import AppKit
import SwiftUI

enum DefaultBrowserPreference: Equatable {
    case prompt
    case browser(UUID)
}

@MainActor
class URLHandler: NSObject, ObservableObject {
    static let shared = URLHandler()

    @Published var pendingURL: URL?
    @Published var sourceApplication: String?
    @Published var showBrowserPicker = false
    @Published private(set) var defaultBrowserPreference: DefaultBrowserPreference = .prompt

    private let browserDetector = BrowserDetector()
    private let ruleEngine = RuleEngine()
    private let urlCleaner = URLCleaner.shared
    private let defaultBrowserPreferenceKey = "defaultBrowserPreference"
    private let domainBrowserMapKey = "domainBrowserMap"
    private let maxDomainBrowserMapSize = 500
    private var domainBrowserMap: [String: String] = [:]

    private override init() {
        super.init()
        // URL events are handled by AppDelegate
        defaultBrowserPreference = loadDefaultBrowserPreference()
        domainBrowserMap = loadDomainBrowserMap()
    }

    func handleURL(_ url: URL, sourceApp: String?) {
        // Clean URL (strip tracking parameters)
        let cleanedURL = urlCleaner.cleanURL(url, stripTracking: urlCleaner.shouldStripTracking())

        // Check for desktop app handlers first
        NSLog("[URLHandler] Checking desktop app handlers for URL: \(cleanedURL.absoluteString)")
        for desktopApp in DesktopApp.knownApps {
            if desktopApp.canHandle(url: cleanedURL) {
                NSLog("[URLHandler] Desktop app '\(desktopApp.name)' can handle URL")
                desktopApp.openURL(cleanedURL)
                return
            }
        }
        NSLog("[URLHandler] No desktop app can handle URL")

        // Check routing rules
        if let matchingRule = ruleEngine.findMatchingRule(for: cleanedURL, sourceApp: sourceApp) {
            applyRule(matchingRule, to: cleanedURL)
            return
        }

        // Check domain-specific browser memory (more specific than global default)
        if let remembered = rememberedBrowser(for: cleanedURL) {
            NSLog("[URLHandler] Using remembered browser '\(remembered.name)' for domain of URL: \(cleanedURL.absoluteString)")
            remembered.openURL(cleanedURL, profile: nil)
            return
        }

        // Apply saved default browser preference if available
        if case let .browser(browserId) = defaultBrowserPreference,
           let browser = browserDetector.browsers.first(where: { $0.id == browserId }) {
            NSLog("[URLHandler] Using saved default browser '\(browser.name)' for URL: \(cleanedURL.absoluteString)")
            browser.openURL(cleanedURL, profile: nil)
            return
        }

        // No rule matched - show browser picker
        pendingURL = cleanedURL
        sourceApplication = sourceApp
        showBrowserPicker = true
    }

    private func applyRule(_ rule: RoutingRule, to url: URL) {
        switch rule.target {
        case .browser(let browserId, let profileId):
            if let browser = browserDetector.browsers.first(where: { $0.id == browserId }) {
                let profile = browser.profiles.first(where: { $0.id == profileId })
                browser.openURL(url, profile: profile)
            }

        case .desktopApp(let bundleId):
            NSLog("[URLHandler] Applying rule with desktop app target: \(bundleId)")
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSLog("[URLHandler] Found app at: \(appURL.path)")
                NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { [weak self] app, error in
                    if let error = error {
                        NSLog("[URLHandler] ERROR: Failed to open with desktop app: \(error.localizedDescription)")
                        // Fallback to browser picker on error
                        Task { @MainActor [weak self] in
                            self?.pendingURL = url
                            self?.showBrowserPicker = true
                        }
                    } else {
                        NSLog("[URLHandler] Successfully opened URL with desktop app")
                    }
                }
            } else {
                NSLog("[URLHandler] ERROR: Desktop app with bundleId '\(bundleId)' not found - showing browser picker as fallback")
                // Show browser picker when desktop app is not installed
                pendingURL = url
                showBrowserPicker = true
            }
        }
    }

    func openWithBrowser(_ browser: Browser, profile: BrowserProfile? = nil) {
        guard let url = pendingURL else { return }

        // Remember this browser for the domain so future visits auto-open it
        saveRememberedBrowser(browser, for: url)

        // Open the URL first
        browser.openURL(url, profile: profile)

        // Clear pending state and close picker
        pendingURL = nil
        sourceApplication = nil
        showBrowserPicker = false
    }

    /// Returns the browser previously used for the domain of the given URL, if any.
    private func rememberedBrowser(for url: URL) -> Browser? {
        guard let domain = extractDomain(from: url) else { return nil }
        guard let bundleId = domainBrowserMap[domain] else { return nil }
        return browserDetector.browsers.first(where: { $0.bundleIdentifier == bundleId })
    }

    /// Returns the bundle identifier of the remembered browser for the current pending URL, if any.
    func rememberedBrowserBundleId(for url: URL) -> String? {
        guard let domain = extractDomain(from: url) else { return nil }
        return domainBrowserMap[domain]
    }

    /// Removes the remembered browser for the domain of the given URL.
    func clearRememberedBrowser(for url: URL) {
        guard let domain = extractDomain(from: url) else { return }
        domainBrowserMap.removeValue(forKey: domain)
        UserDefaults.standard.set(domainBrowserMap, forKey: domainBrowserMapKey)
        NSLog("[URLHandler] Cleared remembered browser for domain '\(domain)'")
    }

    /// Removes all remembered browser–domain associations.
    func clearAllRememberedBrowsers() {
        domainBrowserMap.removeAll()
        UserDefaults.standard.removeObject(forKey: domainBrowserMapKey)
        NSLog("[URLHandler] Cleared all remembered browsers")
    }

    func cancelPicker() {
        // Called when user cancels without selecting a browser
        pendingURL = nil
        sourceApplication = nil
        showBrowserPicker = false
    }

    func getBrowserDetector() -> BrowserDetector {
        return browserDetector
    }

    func getRuleEngine() -> RuleEngine {
        return ruleEngine
    }

    func setDefaultBrowserPreference(_ preference: DefaultBrowserPreference) {
        defaultBrowserPreference = preference
        saveDefaultBrowserPreference(preference)
    }

    func isDefaultBrowser(_ browser: Browser) -> Bool {
        if case let .browser(browserId) = defaultBrowserPreference {
            return browser.id == browserId
        }
        return false
    }

    func resetDefaultBrowserPreferenceIfInvalid(with browsers: [Browser]) {
        guard !browsers.isEmpty else { return }

        if case let .browser(browserId) = defaultBrowserPreference,
           browsers.first(where: { $0.id == browserId }) == nil {
            setDefaultBrowserPreference(.prompt)
        }
    }

    private func loadDefaultBrowserPreference() -> DefaultBrowserPreference {
        guard let storedValue = UserDefaults.standard.string(forKey: defaultBrowserPreferenceKey) else {
            return .prompt
        }

        if storedValue == "prompt" {
            return .prompt
        }

        if let uuid = UUID(uuidString: storedValue) {
            return .browser(uuid)
        }

        return .prompt
    }

    private func saveDefaultBrowserPreference(_ preference: DefaultBrowserPreference) {
        switch preference {
        case .prompt:
            UserDefaults.standard.set("prompt", forKey: defaultBrowserPreferenceKey)
        case .browser(let browserId):
            UserDefaults.standard.set(browserId.uuidString, forKey: defaultBrowserPreferenceKey)
        }
    }

    // MARK: - Domain Browser Memory

    /// Extracts a normalised domain (without "www." prefix) from a URL.
    private func extractDomain(from url: URL) -> String? {
        guard let host = url.host, !host.isEmpty else { return nil }
        let normalized = host.lowercased()
        return normalized.hasPrefix("www.") ? String(normalized.dropFirst(4)) : normalized
    }

    /// Persists a domain → browser mapping so the same browser is auto-selected next time.
    /// Enforces a cap of `maxDomainBrowserMapSize` entries, evicting excess entries when exceeded.
    private func saveRememberedBrowser(_ browser: Browser, for url: URL) {
        guard let domain = extractDomain(from: url) else { return }
        domainBrowserMap[domain] = browser.bundleIdentifier
        // Enforce size cap: evict excess entries when limit is exceeded
        if domainBrowserMap.count > maxDomainBrowserMapSize {
            let excess = domainBrowserMap.count - maxDomainBrowserMapSize
            let keysToRemove = Array(domainBrowserMap.keys.prefix(excess))
            keysToRemove.forEach { domainBrowserMap.removeValue(forKey: $0) }
        }
        UserDefaults.standard.set(domainBrowserMap, forKey: domainBrowserMapKey)
        NSLog("[URLHandler] Remembered browser '\(browser.name)' for domain '\(domain)'")
    }

    private func loadDomainBrowserMap() -> [String: String] {
        return UserDefaults.standard.dictionary(forKey: domainBrowserMapKey) as? [String: String] ?? [:]
    }
}
