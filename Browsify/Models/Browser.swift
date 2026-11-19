//
//  Browser.swift
//  Browsify
//

import Foundation
import AppKit
import CryptoKit
import os

struct Browser: Identifiable, Codable, Hashable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Browsify",
        category: "BrowserLaunch"
    )
    let id: UUID
    let name: String
    let bundleIdentifier: String?
    let path: String
    let icon: Data?
    var profiles: [BrowserProfile]

    init(id: UUID = UUID(), name: String, bundleIdentifier: String?, path: String, icon: Data? = nil, profiles: [BrowserProfile] = []) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.icon = icon
        self.profiles = profiles
    }

    /// A stable identifier for persistence when a sandboxed process cannot read an app bundle identifier.
    var identityKey: String {
        bundleIdentifier ?? path
    }

    var iconImage: NSImage? {
        if let iconData = icon {
            return NSImage(data: iconData)
        }
        if FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        // The recorded path can be stale or unreadable from the sandbox; ask LaunchServices.
        // Returns nil rather than a generic document icon so views can show a clear fallback.
        if let bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }

    func openURL(_ url: URL, profile: BrowserProfile? = nil) {
        #if DEBUG
        // Demo data must never launch the user's real browsers or create real browser profiles.
        if DemoData.isEnabled {
            NSLog("[Demo] Would open \(url.absoluteString) in \(name)")
            return
        }
        #endif
        let arguments = profile?.profilePath.isEmpty == false ? profile?.launchArguments(for: url) ?? [] : []

        // Custom browsers retain the security scope received when the user selected their
        // application bundle; opening through it keeps that grant active for the launch.
        let openedWithBookmark = AccessManager.shared.withBrowserApplicationAccess(at: path) { applicationURL in
            open(url, in: [applicationURL], arguments: arguments)
        }

        guard openedWithBookmark == nil else { return }

        open(url, in: launchCandidateURLs(), arguments: arguments)
    }

    /// Locations to try, in order, when launching this browser.
    ///
    /// The bundle identifier is asked of LaunchServices at launch time rather than reusing a
    /// stored path: a stored path can be stale, and for system apps it may point into a
    /// read-protected location (Safari lives under `/System/Volumes/Preboot/Cryptexes`, which a
    /// sandboxed process cannot reach). Asking LaunchServices keeps the launch working in both
    /// cases, and the recorded path stays as a fallback for browsers without a readable bundle ID.
    private func launchCandidateURLs() -> [URL] {
        var candidates: [URL] = []

        if let bundleIdentifier,
           let resolvedURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            candidates.append(resolvedURL)
        }

        if !path.isEmpty {
            let recordedURL = URL(fileURLWithPath: path)
            if !candidates.contains(recordedURL) {
                candidates.append(recordedURL)
            }
        }

        return candidates
    }

    /// Opens the URL in the first candidate that accepts it, degrading to a plain launch
    /// (no profile arguments) before giving up so a link never silently fails to open.
    private func open(_ url: URL, in candidateURLs: [URL], arguments: [String]) {
        guard let applicationURL = candidateURLs.first else {
            Self.logger.error("No launchable location for browser \(name, privacy: .public)")
            return
        }

        let remainingCandidates = Array(candidateURLs.dropFirst())

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = !arguments.isEmpty
        configuration.arguments = arguments

        NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) { _, error in
            guard let error else { return }

            Self.logger.error("Unable to open URL at \(applicationURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")

            if !remainingCandidates.isEmpty {
                self.open(url, in: remainingCandidates, arguments: arguments)
            } else if !arguments.isEmpty {
                // The profile arguments may be what the browser rejected — retry plainly.
                self.open(url, in: candidateURLs, arguments: [])
            }
        }
    }
}

struct BrowserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let profilePath: String
    let browserBundleId: String

    init(id: UUID? = nil, name: String, profilePath: String, browserBundleId: String) {
        self.id = id ?? Self.detectedID(browserBundleId: browserBundleId, profilePath: profilePath)
        self.name = name
        self.profilePath = profilePath
        self.browserBundleId = browserBundleId
    }

    private static func detectedID(browserBundleId: String, profilePath: String) -> UUID {
        let identity = Data("\(browserBundleId):\(profilePath)".utf8)
        var bytes = Array(SHA256.hash(data: identity).prefix(16))
        // Mark the hash-derived identifier as a version 8 UUID with the RFC variant.
        bytes[6] = (bytes[6] & 0x0F) | 0x80
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return NSUUID(uuidBytes: bytes) as UUID
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
