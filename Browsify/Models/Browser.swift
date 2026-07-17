//
//  Browser.swift
//  Browsify
//

import Foundation
import AppKit
import os

struct Browser: Identifiable, Codable, Hashable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yumiizumi.Browsify",
        category: "BrowserLaunch"
    )
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
        let arguments = profile?.profilePath.isEmpty == false ? profile?.launchArguments(for: url) ?? [] : []
        let openBrowser: (URL) -> Void = { applicationURL in
            open(url, withApplicationAt: applicationURL, arguments: arguments, retryWithoutArguments: !arguments.isEmpty)
        }

        // Known browsers are resolved through LaunchServices. Custom browsers retain the
        // security scope received when the user selected their application bundle.
        if AccessManager.shared.withBrowserApplicationAccess(at: path, perform: openBrowser) == nil {
            openBrowser(URL(fileURLWithPath: path))
        }
    }

    private func open(
        _ url: URL,
        withApplicationAt applicationURL: URL,
        arguments: [String],
        retryWithoutArguments: Bool
    ) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = false
        configuration.arguments = arguments

        NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) { _, error in
            guard let error else { return }

            if retryWithoutArguments {
                Self.logger.error("Profile launch failed; retrying without arguments: \(error.localizedDescription, privacy: .public)")
                self.open(url, withApplicationAt: applicationURL, arguments: [], retryWithoutArguments: false)
            } else {
                Self.logger.error("Unable to open URL in browser: \(error.localizedDescription, privacy: .public)")
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
        let normalizedBundleIdentifier = browserBundleId.lowercased()

        // Chrome/Chromium-based browsers
        if normalizedBundleIdentifier.contains("chrome") || normalizedBundleIdentifier.contains("chromium") ||
           normalizedBundleIdentifier.contains("brave") || normalizedBundleIdentifier.contains("edge") ||
           normalizedBundleIdentifier.contains("vivaldi") || normalizedBundleIdentifier.contains("arc") {
            return ["--profile-directory=\(profilePath)", url.absoluteString]
        }

        // Firefox
        if normalizedBundleIdentifier.contains("firefox") {
            return ["-P", name, url.absoluteString]
        }

        return [url.absoluteString]
    }
}
