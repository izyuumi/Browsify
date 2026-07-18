//
//  WelcomeView.swift
//  Browsify
//

import AppKit
import SwiftUI

struct WelcomeView: View {
    @ObservedObject var browserDetector: BrowserDetector
    let doneAction: () -> Void

    @State private var requestedDefaultBrowser = false

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
                    Text("1. Make Browsify your default browser")
                        .font(.headline)

                    HStack {
                        Button("Set as Default Browser") {
                            setAsDefaultBrowser()
                            requestedDefaultBrowser = true
                        }

                        if requestedDefaultBrowser {
                            Text("macOS will ask for confirmation.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("2. (Optional) Enable browser profiles")
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

            Spacer(minLength: 0)

            HStack {
                Spacer()

                Button("Done", action: doneAction)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 480, height: 520)
    }

    private func setAsDefaultBrowser() {
        let bundleURL = Bundle.main.bundleURL

        NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpenURLsWithScheme: "http") { _ in }
        NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpenURLsWithScheme: "https") { _ in }
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
