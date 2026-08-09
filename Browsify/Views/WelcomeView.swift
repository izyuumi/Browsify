//
//  WelcomeView.swift
//  Browsify
//

import AppKit
import SwiftUI

struct WelcomeView: View {
    @ObservedObject var browserDetector: BrowserDetector
    let doneAction: () -> Void

    @State private var isDefaultBrowser = false

    private var appIcon: NSImage {
        if let copiedIcon = NSApp.applicationIconImage.copy() as? NSImage {
            copiedIcon.size = NSSize(width: 96, height: 96)
            copiedIcon.isTemplate = false
            return copiedIcon
        }

        return NSImage(systemSymbolName: "link.circle", accessibilityDescription: nil) ?? NSImage()
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)

                Text("Browsify")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Route every link to the right browser.")
                    .foregroundColor(.secondary)
            }

            Text("Browsify catches links you click and routes them to a browser, profile, or app based on your rules; unmatched links show a picker.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. See how Browsify works")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        Button("Test Browsify with a Link…") {
                            (NSApp.delegate as? AppDelegate)?.openTestLink()
                        }

                        Text("Enter any web address to see where Browsify opens it.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("2. Make Browsify your default browser")
                        .font(.headline)

                    HStack {
                        if isDefaultBrowser {
                            Label("Browsify is your default browser", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button("Set as Default Browser") {
                                setAsDefaultBrowser()
                            }

                            Text("macOS will ask for confirmation.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("3. (Optional) Enable browser profiles")
                        .font(.headline)

                    if browserDetector.profileCapableBrowsers.isEmpty {
                        Text("Install a supported browser to enable profile detection.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(browserDetector.profileCapableBrowsers) { browser in
                            ProfileAccessView(browser: browser, browserDetector: browserDetector)
                        }
                    }
                }
            }
            .onAppear(perform: refreshDefaultBrowserStatus)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                refreshDefaultBrowserStatus()
            }

            HStack {
                Spacer()

                Button("Done", action: doneAction)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        // minHeight, not a fixed height: step 3 grows a row per profile-capable browser,
        // and a fixed 520 clipped the Done button once three or more were installed.
        .frame(width: 480)
        .frame(minHeight: 520)
        .accessibilityIdentifier("welcome-screen")
    }

    private func setAsDefaultBrowser() {
        let bundleURL = Bundle.main.bundleURL

        NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpenURLsWithScheme: "http") { _ in }
        NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpenURLsWithScheme: "https") { error in
            DispatchQueue.main.async {
                if let error {
                    NSLog("[WelcomeView] Could not set default browser: \(error.localizedDescription)")
                }
                refreshDefaultBrowserStatus()
            }
        }
    }

    private func refreshDefaultBrowserStatus() {
        guard let httpsURL = URL(string: "https://www.apple.com"),
              let handlerURL = NSWorkspace.shared.urlForApplication(toOpen: httpsURL) else {
            isDefaultBrowser = false
            return
        }

        isDefaultBrowser = Bundle(url: handlerURL)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }
}

private struct ProfileAccessView: View {
    let browser: Browser
    @ObservedObject var browserDetector: BrowserDetector

    var body: some View {
        HStack {
            Text(browser.name)
            Spacer()

            if browserDetector.hasProfileAccess(for: browser) {
                Label("Access granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant Access…") {
                    browserDetector.requestProfileAccess(for: browser)
                }
            }
        }
    }
}
