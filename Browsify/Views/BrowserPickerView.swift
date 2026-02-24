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
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
            }

            // Browser list with numbers
            let remembered = rememberedBundleId
            HStack(spacing: 12) {
                ForEach(Array(browserDetector.browsers.enumerated()), id: \.element.id) { index, browser in
                    BrowserIcon(
                        browser: browser,
                        number: index + 1,
                        isRemembered: browser.bundleIdentifier == remembered
                    ) {
                        openWithBrowser(browser)
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
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
        .allowsHitTesting(true)
        .onAppear {
            // Setup keyboard shortcuts for numbers 1-9 and ESC
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Check for ESC key
                if event.keyCode == 53 { // ESC key code
                    self.urlHandler.cancelPicker()
                    return nil
                }

                // Check for number keys 1-9
                guard let characters = event.charactersIgnoringModifiers,
                      let char = characters.first,
                      char.isNumber,
                      let number = Int(String(char)),
                      number >= 1 && number <= self.browserDetector.browsers.count else {
                    return event
                }

                let browser = self.browserDetector.browsers[number - 1]
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

struct BrowserIcon: View {
    let browser: Browser
    let number: Int
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
                // Number above icon
                Text("\(number)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(isRemembered ? .accentColor : .secondary)
                    .fontWeight(.semibold)

                // Browser icon with optional remembered-browser ring
                ZStack {
                    if let icon = browser.iconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 56, height: 56)
                    } else {
                        Image(systemName: "app.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 56, height: 56)
                            .foregroundColor(.secondary)
                    }

                    // Highlight ring for remembered browser
                    if isRemembered {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 2.5)
                            .frame(width: 60, height: 60)
                    }
                }
            }
            .padding(6)
        }
        .buttonStyle(.plain)
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
