//
//  BrowserPickerView.swift
//  Browsify
//

import SwiftUI

struct BrowserPickerView: View {
    @ObservedObject var urlHandler: URLHandler
    @ObservedObject var browserDetector: BrowserDetector
    @State private var eventMonitor: Any?

    /// The bundle identifier of the browser previously used for this URL's domain, if any.
    private var rememberedBundleId: String? {
        guard let url = urlHandler.pendingURL else { return nil }
        return urlHandler.rememberedBrowserBundleId(for: url)
    }

    private var dynamicWidth: CGFloat {
        let browserCount = CGFloat(browserDetector.browsers.count)
        let iconWidth: CGFloat = 80 // 64px icon + 16px spacing
        let padding: CGFloat = 24 // Minimal left and right padding
        let calculatedWidth = browserCount * iconWidth + padding
        return max(calculatedWidth, 200) // Minimum width 200
    }

    var body: some View {
        VStack(spacing: 12) {
            // URL display
            if let url = urlHandler.pendingURL {
                Text(url.absoluteString)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
                    .help(url.absoluteString)
            }

            if browserDetector.browsers.isEmpty {
                VStack(spacing: 8) {
                    Text("No Browsers Found")
                        .font(.headline)

                    Text("Add or unhide a browser in Settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Open Settings…") {
                        (NSApp.delegate as? AppDelegate)?.showSettings()
                    }
                }
            } else {
                // Browser list with picker shortcuts
                let remembered = rememberedBundleId
                HStack(spacing: 12) {
                    ForEach(Array(browserDetector.browsers.enumerated()), id: \.element.id) { index, browser in
                        BrowserIcon(
                            browser: browser,
                            shortcut: browserDetector.pickerShortcut(for: browser, at: index),
                            isRemembered: browser.identityKey == remembered
                        ) {
                            openWithBrowser(browser)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: dynamicWidth)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
        .allowsHitTesting(true)
        .accessibilityIdentifier("browser-picker-screen")
        .onAppear {
            // Setup keyboard shortcuts and ESC
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Check for ESC key
                if event.keyCode == 53 { // ESC key code
                    self.urlHandler.cancelPicker()
                    return nil
                }

                let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
                guard event.modifierFlags.intersection(disallowedModifiers).isEmpty,
                      let characters = event.characters,
                      let browser = self.browserDetector.browser(forPickerKey: characters) else {
                    return event
                }

                self.openWithBrowser(browser)
                return nil // Consume the event
            }
        }
        .onDisappear {
            // Remove event monitor to prevent memory leak
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }

    private func openWithBrowser(_ browser: Browser) {
        NSLog("[BrowserPickerView] Opening URL with browser: \(browser.name)")
        urlHandler.openWithBrowser(browser, profile: nil)
    }
}

/// A browser's app icon, or a globe when the app's icon can't be loaded.
struct BrowserAppIcon: View {
    let browser: Browser
    let size: CGFloat

    var body: some View {
        Group {
            if let icon = browser.iconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "globe")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size / 8)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct BrowserIcon: View {
    let browser: Browser
    let shortcut: String?
    /// Whether this browser was the last one used for the current URL's domain.
    var isRemembered: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            NSLog("[BrowserIcon] Button action triggered for browser: \(browser.name)")
            action()
        }) {
            VStack(spacing: 6) {
                // Shortcut above icon
                Text(shortcut.map { BrowserPickerShortcut.displayKey($0) } ?? "–")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(isRemembered ? .accentColor : .secondary)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 64)

                // Browser icon with optional remembered-browser ring
                ZStack {
                    BrowserAppIcon(browser: browser, size: 56)

                    // Highlight ring for remembered browser
                    if isRemembered {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 2.5)
                            .frame(width: 60, height: 60)
                    }
                }

                // Browser name shown on hover (always in hierarchy to avoid height flicker)
                Text(browser.name)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 64)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .help(isRemembered ? "\(browser.name) — last used for this site" : browser.name)
        .accessibilityLabel("Open in \(browser.name)")
        .accessibilityValue(isRemembered ? "Last used for this site" : "")
        .accessibilityHint(shortcut.map { "Shortcut: \(BrowserPickerShortcut.displayKey($0))" } ?? "")
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
