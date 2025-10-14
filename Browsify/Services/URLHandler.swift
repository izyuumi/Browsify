//
//  URLHandler.swift
//  Browsify
//

import Foundation
import Combine
import AppKit
import SwiftUI

class URLHandler: NSObject, ObservableObject {
    static let shared = URLHandler()

    @Published var pendingURL: URL?
    @Published var sourceApplication: String?
    @Published var showBrowserPicker = false

    private let browserDetector = BrowserDetector()
    private let ruleEngine = RuleEngine()
    private let urlCleaner = URLCleaner.shared

    private override init() {
        super.init()
        // URL events are handled by AppDelegate
    }

    func handleURL(_ url: URL, sourceApp: String?) {
        // Clean URL (strip tracking parameters)
        let cleanedURL = urlCleaner.cleanURL(url, stripTracking: urlCleaner.shouldStripTracking())

        // Check for desktop app handlers first
        for desktopApp in DesktopApp.knownApps {
            if desktopApp.canHandle(url: cleanedURL) {
                desktopApp.openURL(cleanedURL)
                return
            }
        }

        // Check routing rules
        if let matchingRule = ruleEngine.findMatchingRule(for: cleanedURL, sourceApp: sourceApp) {
            applyRule(matchingRule, to: cleanedURL)
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
            }

        case .desktopApp(let bundleId):
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            }
        }
    }

    func openWithBrowser(_ browser: Browser, profile: BrowserProfile? = nil) {
        guard let url = pendingURL else { return }

        // Open the URL first
        browser.openURL(url, profile: profile)

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
}
