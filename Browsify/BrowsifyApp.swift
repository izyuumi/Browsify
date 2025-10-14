//
//  BrowsifyApp.swift
//  Browsify
//
//  Created by Yumi Izumi on 2025/10/14.
//

import SwiftUI
import Combine

@main
struct BrowsifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar only app - Settings scene prevents empty window from appearing
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var browserPickerPanel: NSPanel?
    var settingsWindow: NSWindow?
    var cancellables = Set<AnyCancellable>()
    var isPickerOpen = false
    var policyEnforcementTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (menu bar only)
        NSApp.setActivationPolicy(.accessory)

        // Create menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "link.circle", accessibilityDescription: "Browsify")
        }

        let menu = NSMenu()

        let testItem = NSMenuItem(title: "Test Picker...", action: #selector(testPicker), keyEquivalent: "t")
        testItem.target = self
        menu.addItem(testItem)
        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About Browsify", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Browsify", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu

        // Initialize URLHandler (which will auto-detect browsers)
        _ = URLHandler.shared

        // Observe showBrowserPicker changes and react immediately
        URLHandler.shared.$showBrowserPicker
            .dropFirst() // Skip initial value to avoid premature firing
            .removeDuplicates() // Ignore duplicate values
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main) // Debounce rapid changes
            .sink { [weak self] shouldShow in
                if shouldShow && self?.isPickerOpen == false {
                    self?.showBrowserPicker()
                } else if !shouldShow && self?.isPickerOpen == true {
                    self?.closeBrowserPicker()
                }
            }
            .store(in: &cancellables)

        // Listen for URL events
        setupURLHandling()
    }

    private func setupURLHandling() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        URLHandler.shared.handleURL(url, sourceApp: sourceApp)
        // Browser picker will show automatically via Combine observer when showBrowserPicker becomes true
    }

    @objc func showBrowserPicker() {
        DispatchQueue.main.async {
            guard !self.isPickerOpen else {
                return
            }

            // Close existing panel if any (without triggering state changes)
            if let existingPanel = self.browserPickerPanel {
                existingPanel.close()
                self.browserPickerPanel = nil
            }

            // Recreate panel each time for fresh state
            let browserDetector = URLHandler.shared.getBrowserDetector()

            let pickerView = BrowserPickerView(
                urlHandler: URLHandler.shared,
                browserDetector: browserDetector
            )

            let hostingController = NSHostingController(rootView: pickerView)

            // Calculate dynamic width based on browser count
            let browserCount = CGFloat(browserDetector.browsers.count)
            let iconWidth: CGFloat = 80 // 56px icon + 12px spacing + padding
            let padding: CGFloat = 24 // Minimal left and right padding
            let dynamicWidth = max(browserCount * iconWidth + padding, 200)
            let panelHeight: CGFloat = 140 // Minimal design, compact height

            // Use custom InteractivePanel that can accept input while maintaining accessory status
            let panel = InteractivePanel(
                contentRect: NSRect(x: 0, y: 0, width: dynamicWidth, height: panelHeight),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            panel.contentViewController = hostingController
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .floating  // Changed from .statusBar to .floating for better interaction
            panel.isMovableByWindowBackground = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.animationBehavior = .utilityWindow
            panel.hidesOnDeactivate = false
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden
            panel.standardWindowButton(.closeButton)?.isHidden = true
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.acceptsMouseMovedEvents = true
            panel.ignoresMouseEvents = false  // Ensure panel accepts mouse events
            panel.worksWhenModal = true  // Allow panel to receive events even when modal
            panel.becomesKeyOnlyIfNeeded = false  // Always become key to ensure focus

            // Set the frame to our calculated size
            panel.setFrame(NSRect(x: 0, y: 0, width: dynamicWidth, height: panelHeight), display: false)

            self.browserPickerPanel = panel
            self.isPickerOpen = true

            // Position at center of screen using the calculated dimensions
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                // Center the window: screen center minus half the panel size
                let x = screenFrame.origin.x + (screenFrame.width - dynamicWidth) / 2
                let y = screenFrame.origin.y + (screenFrame.height - panelHeight) / 2
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }

            // CRITICAL: Force activation policy to .accessory BEFORE making key
            NSApp.setActivationPolicy(.accessory)

            // Use makeKeyAndOrderFront to allow the panel to accept input
            NSLog("[AppDelegate] Making panel key and ordering front. Panel isKeyWindow: \(panel.isKeyWindow), NSApp.isActive: \(NSApp.isActive)")
            panel.makeKeyAndOrderFront(nil)

            // CRITICAL: Force app activation to ensure panel receives focus
            NSApp.activate(ignoringOtherApps: true)

            NSLog("[AppDelegate] After makeKeyAndOrderFront + activate. Panel isKeyWindow: \(panel.isKeyWindow), NSApp.isActive: \(NSApp.isActive)")

            // CRITICAL: Delay accessory policy enforcement to allow panel to fully activate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSApp.setActivationPolicy(.accessory)
                NSLog("[AppDelegate] Delayed setActivationPolicy to .accessory. Panel isKeyWindow: \(panel.isKeyWindow)")
            }

            // Start continuous enforcement timer
            self.startPolicyEnforcementTimer()
        }
    }

    private func startPolicyEnforcementTimer() {
        // Stop existing timer if any
        policyEnforcementTimer?.invalidate()

        // Create timer to continuously enforce .accessory policy
        policyEnforcementTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard self?.isPickerOpen == true else {
                self?.policyEnforcementTimer?.invalidate()
                self?.policyEnforcementTimer = nil
                return
            }

            if NSApp.activationPolicy() != .accessory {
                NSLog("[AppDelegate] Policy enforcement timer: Resetting to .accessory")
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    func closeBrowserPicker() {
        DispatchQueue.main.async {
            guard self.isPickerOpen else {
                return
            }

            // Stop enforcement timer first
            self.policyEnforcementTimer?.invalidate()
            self.policyEnforcementTimer = nil

            if let panel = self.browserPickerPanel {
                panel.orderOut(nil)  // Hide the panel first
                panel.close()
                self.browserPickerPanel = nil
            }

            self.isPickerOpen = false

            // CRITICAL: Ensure we stay as accessory app (no dock icon)
            NSApp.setActivationPolicy(.accessory)

            // Deactivate the app to remove any lingering dock icon
            NSApp.deactivate()
        }
    }

    @objc func showSettings() {
        DispatchQueue.main.async {
            if self.settingsWindow == nil {
                let settingsView = SettingsView(
                    ruleEngine: URLHandler.shared.getRuleEngine(),
                    browserDetector: URLHandler.shared.getBrowserDetector()
                )

                let hostingController = NSHostingController(rootView: settingsView)
                let window = NSWindow(contentViewController: hostingController)
                window.title = "Browsify Settings"
                window.styleMask = [.titled, .closable, .resizable]
                window.setContentSize(NSSize(width: 700, height: 500))
                window.center()

                self.settingsWindow = window
            }

            self.settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }

    @objc func testPicker() {
        let testURL = URL(string: "https://www.example.com")!
        URLHandler.shared.handleURL(testURL, sourceApp: nil)
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
}
