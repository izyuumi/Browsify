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
        let helperScriptURL: URL? = MainActor.assumeIsolated {
            let helperScriptManager = HelperScriptManager.shared
            return helperScriptManager.isInstalled ? helperScriptManager.scriptURL : nil
        }
        let openBrowser: (URL) -> Void = { applicationURL in
            open(
                url,
                withApplicationAt: applicationURL,
                arguments: arguments,
                retryWithoutArguments: !arguments.isEmpty,
                helperScriptURL: helperScriptURL
            )
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
        retryWithoutArguments: Bool,
        helperScriptURL: URL?
    ) {
        if !arguments.isEmpty, let helperScriptURL {
            do {
                let task = try NSUserUnixTask(url: helperScriptURL)
                try task.execute(withArguments: ["-na", applicationURL.path, "--args"] + arguments) { error in
                    guard let error else { return }

                    Self.logger.error("Helper profile launch failed; opening in default profile: \(error.localizedDescription, privacy: .public)")
                    self.open(
                        url,
                        withApplicationAt: applicationURL,
                        arguments: [],
                        retryWithoutArguments: false,
                        helperScriptURL: nil
                    )
                }
                return
            } catch {
                Self.logger.error("Unable to start helper profile launch; opening in default profile: \(error.localizedDescription, privacy: .public)")
                open(
                    url,
                    withApplicationAt: applicationURL,
                    arguments: [],
                    retryWithoutArguments: false,
                    helperScriptURL: nil
                )
                return
            }
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = !arguments.isEmpty
        configuration.arguments = arguments

        NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) { _, error in
            guard let error else { return }

            if retryWithoutArguments {
                Self.logger.error("Profile launch failed; retrying without arguments: \(error.localizedDescription, privacy: .public)")
                self.open(
                    url,
                    withApplicationAt: applicationURL,
                    arguments: [],
                    retryWithoutArguments: false,
                    helperScriptURL: nil
                )
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

    private static let chromiumFamilyBundleIdentifiers: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "org.chromium.Chromium",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi",
    ]

    static func isChromiumFamilyBundleIdentifier(_ bundleIdentifier: String) -> Bool {
        chromiumFamilyBundleIdentifiers.contains(bundleIdentifier)
    }

    static func usesFirefoxProfile(_ bundleIdentifier: String) -> Bool {
        bundleIdentifier.hasPrefix("org.mozilla.firefox")
    }

    func launchArguments(for url: URL) -> [String] {
        // Chrome/Chromium-based browsers
        if Self.isChromiumFamilyBundleIdentifier(browserBundleId) {
            return ["--profile-directory=\(profilePath)", url.absoluteString]
        }

        // Firefox
        if Self.usesFirefoxProfile(browserBundleId) {
            return ["-P", name, url.absoluteString]
        }

        return [url.absoluteString]
    }
}
