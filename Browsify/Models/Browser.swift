//
//  Browser.swift
//  Browsify
//

import Foundation
import AppKit
import ApplicationServices

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
        // When no explicit profile is requested, try sending the URL to an existing instance first
        if profile == nil, openInRunningInstance(url) {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = false

        if let profile = profile, !profile.profilePath.isEmpty {
            // Launching with a specific profile still requires command-line arguments
            configuration.arguments = profile.launchArguments(for: url)
        }

        NSWorkspace.shared.open(
            [url],
            withApplicationAt: URL(fileURLWithPath: path),
            configuration: configuration,
            completionHandler: nil
        )
    }

    /// Sends a kAEGetURL event directly to a running instance of the browser if available.
    /// Returns true when delivery succeeds so we can avoid launching a new window.
    private func openInRunningInstance(_ url: URL) -> Bool {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty else {
            return false
        }

        let targetDescriptor = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
        let appleEvent = NSAppleEventDescriptor.appleEvent(
            withEventClass: AEEventClass(kInternetEventClass),
            eventID: AEEventID(kAEGetURL),
            targetDescriptor: targetDescriptor,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )

        appleEvent.setParam(NSAppleEventDescriptor(string: url.absoluteString), forKeyword: keyDirectObject)

        do {
            _ = try appleEvent.sendEvent(options: [.neverInteract, .dontRecord], timeout: 1.0)
            return true
        } catch {
            return false
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
