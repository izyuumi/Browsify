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

    private override init() {
        super.init()
        // URL events are handled by AppDelegate
        defaultBrowserPreference = loadDefaultBrowserPreference()
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

        // Apply saved default browser preference if available
        if case let .browser(browserId) = defaultBrowserPreference,
           let browser = browserDetector.browsers.first(where: { $0.id == browserId }) {
            NSLog("[URLHandler] Using saved default browser '\(browser.name)' for URL: \(cleanedURL.absoluteString)")
            browser.openURL(cleanedURL, profile: nil)
            return
        }

        // No rule matched - show browser picker
        DispatchQueue.main.async {
            self.pendingURL = cleanedURL
            self.sourceApplication = sourceApp
            self.showBrowserPicker = true
        }
    }

    private func applyRule(_ rule: RoutingRule, to url: URL) {
        switch rule.target {
        case .browser(let browserId, let profileId):
            if let browser = browserDetector.browsers.first(where: { $0.id == browserId }) {
                let profile = browser.profiles.first(where: { $0.id == profileId })
                browser.openURL(url, profile: profile)
                URLHistory.shared.add(url: url.absoluteString, browserName: browser.name, ruleMatched: true)
            }

        case .desktopApp(let bundleId):
            NSLog("[URLHandler] Applying rule with desktop app target: \(bundleId)")
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSLog("[URLHandler] Found app at: \(appURL.path)")
                NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { app, error in
                    if let error = error {
                        NSLog("[URLHandler] ERROR: Failed to open with desktop app: \(error.localizedDescription)")
                        // Fallback to browser picker on error
                        DispatchQueue.main.async {
                            self.pendingURL = url
                            self.showBrowserPicker = true
                        }
                    } else {
                        NSLog("[URLHandler] Successfully opened URL with desktop app")
                    }
                }
            } else {
                NSLog("[URLHandler] ERROR: Desktop app with bundleId '\(bundleId)' not found - showing browser picker as fallback")
                // Show browser picker when desktop app is not installed
                DispatchQueue.main.async {
                    self.pendingURL = url
                    self.showBrowserPicker = true
                }
            }
        }
    }

    func openWithBrowser(_ browser: Browser, profile: BrowserProfile? = nil) {
        guard let url = pendingURL else { return }

        // Open the URL first
        browser.openURL(url, profile: profile)
        URLHistory.shared.add(url: url.absoluteString, browserName: browser.name, ruleMatched: false)

        // Clear pending state and close picker
        DispatchQueue.main.async {
            self.pendingURL = nil
            self.sourceApplication = nil
            self.showBrowserPicker = false
        }
    }

    func cancelPicker() {
        // Called when user cancels without selecting a browser
        DispatchQueue.main.async {
            self.pendingURL = nil
            self.sourceApplication = nil
            self.showBrowserPicker = false
        }
    }

    func getBrowserDetector() -> BrowserDetector {
        return browserDetector
    }

    func getRuleEngine() -> RuleEngine {
        return ruleEngine
    }

    func setDefaultBrowserPreference(_ preference: DefaultBrowserPreference) {
        DispatchQueue.main.async {
            self.defaultBrowserPreference = preference
            self.saveDefaultBrowserPreference(preference)
        }
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
}
