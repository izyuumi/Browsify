//
//  BrowsifyApp.swift
//  Browsify
//
//  Created by Yumi Izumi on 2025/10/14.
//

import SwiftUI
import Combine
import AppKit

@main
struct BrowsifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                ruleEngine: URLHandler.shared.getRuleEngine(),
                browserDetector: URLHandler.shared.getBrowserDetector()
            )
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var browserPickerPanel: NSPanel?
    var settingsWindow: NSWindow?
    var welcomeWindow: NSWindow?
    var cancellables = Set<AnyCancellable>()
    var isPickerOpen = false
    var policyEnforcementTimer: Timer?
    var settingsWindowObserver: NSObjectProtocol?
    var welcomeWindowObserver: NSObjectProtocol?
    var pickerSizeCancellable: AnyCancellable?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Must be installed before launch finishes: when a link click cold-launches Browsify,
        // the kAEGetURL event is delivered during launch and is dropped if no handler exists yet.
        setupURLHandling()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (menu bar only)
        NSApp.setActivationPolicy(.accessory)

        // Create menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "link.circle", accessibilityDescription: "Browsify")
        }

        // Initialize URLHandler (which will auto-detect browsers)
        let urlHandler = URLHandler.shared
        let browserDetector = urlHandler.getBrowserDetector()

        rebuildStatusMenu()

        // Observe showBrowserPicker changes and react immediately
        // The current value is delivered on subscribe: a link that cold-launched the app is
        // handled before this point, so skipping it would leave the picker unshown.
        urlHandler.$showBrowserPicker
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

        // Update menu when detected browsers change
        browserDetector.$browsers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                urlHandler.resetDefaultBrowserPreferenceIfInvalid(with: browserDetector.allBrowsers)
                self?.rebuildStatusMenu()
            }
            .store(in: &cancellables)

        // Update menu when default preference changes
        urlHandler.$defaultBrowserPreference
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildStatusMenu()
            }
            .store(in: &cancellables)

        // Update menu when profiles change
        ProfileManager.shared.$profiles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildStatusMenu()
            }
            .store(in: &cancellables)

        ProfileManager.shared.$activeProfileId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildStatusMenu()
            }
            .store(in: &cancellables)

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--export-ui-screens") {
            DispatchQueue.main.async {
                do {
                    let directory = try UIScreenshotExporter.export()
                    print("BROWSIFY_UI_SCREENSHOT_DIR=\(directory.path)")
                    fflush(stdout)
                    NSApp.terminate(nil)
                } catch {
                    fputs("BROWSIFY_UI_SCREENSHOT_ERROR=\(error)\n", stderr)
                    fflush(stderr)
                    NSApp.terminate(nil)
                }
            }
        } else if let uiTestScreen = Self.uiTestScreen {
            DispatchQueue.main.async { [weak self] in
                self?.showUITestScreen(uiTestScreen)
            }
        } else if !UserDefaults.standard.bool(forKey: "hasCompletedWelcome") {
            DispatchQueue.main.async { [weak self] in
                self?.showWelcome()
            }
        }
        #else
        if !UserDefaults.standard.bool(forKey: "hasCompletedWelcome") {
            DispatchQueue.main.async { [weak self] in
                self?.showWelcome()
            }
        }
        #endif
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

            // Use custom InteractivePanel that can accept input while maintaining accessory status
            let panel = InteractivePanel(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 140),
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

            self.browserPickerPanel = panel
            self.isPickerOpen = true

            self.resizePickerPanel(panel, hostingController: hostingController, display: false)
            self.pickerSizeCancellable = browserDetector.$browsers
                .receive(on: RunLoop.main)
                .sink { [weak self, weak panel, weak hostingController] _ in
                    guard let self, let panel, let hostingController else { return }
                    self.resizePickerPanel(panel, hostingController: hostingController, display: panel.isVisible)
                }

            // CRITICAL: Force activation policy to .accessory BEFORE making key
            NSApp.setActivationPolicy(.accessory)

            // Use makeKeyAndOrderFront to allow the panel to accept input
            NSLog("[AppDelegate] Making panel key and ordering front. Panel isKeyWindow: \(panel.isKeyWindow), NSApp.isActive: \(NSApp.isActive)")
            panel.makeKeyAndOrderFront(nil)

            DispatchQueue.main.async { [weak self, weak panel, weak hostingController] in
                guard let self, let panel, let hostingController else { return }
                self.resizePickerPanel(panel, hostingController: hostingController, display: true)
            }

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

    private func resizePickerPanel(
        _ panel: NSPanel,
        hostingController: NSHostingController<BrowserPickerView>,
        display: Bool
    ) {
        guard browserPickerPanel === panel else { return }

        let maximumSize = NSSize(
            width: (panel.screen ?? NSScreen.main)?.visibleFrame.width ?? 1_000,
            height: (panel.screen ?? NSScreen.main)?.visibleFrame.height ?? 800
        )
        panel.identifier = NSUserInterfaceItemIdentifier("browser-picker-window")
        let contentSize = hostingController.sizeThatFits(in: maximumSize)
        guard contentSize.width > 0, contentSize.height > 0 else { return }

        let frameSize = panel.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
        let screenFrame = (panel.screen ?? NSScreen.main)?.visibleFrame
        let origin = screenFrame.map {
            NSPoint(
                x: $0.midX - frameSize.width / 2,
                y: $0.midY - frameSize.height / 2
            )
        } ?? panel.frame.origin
        panel.setFrame(NSRect(origin: origin, size: frameSize), display: display, animate: false)
    }

    func closeBrowserPicker() {
        DispatchQueue.main.async {
            guard self.isPickerOpen else {
                return
            }

            // Stop enforcement timer first
            self.policyEnforcementTimer?.invalidate()
            self.policyEnforcementTimer = nil
            self.pickerSizeCancellable?.cancel()
            self.pickerSizeCancellable = nil

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
        if let existingWindow = settingsWindow {
            NSApp.setActivationPolicy(.regular)
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView(
                ruleEngine: URLHandler.shared.getRuleEngine(),
                browserDetector: URLHandler.shared.getBrowserDetector()
            )
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.identifier = NSUserInterfaceItemIdentifier("settings-window")
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = hostingController
        #if DEBUG
        if Self.uiTestScreen == nil {
            window.setFrameAutosaveName("BrowsifySettingsWindow")
        }
        #else
        window.setFrameAutosaveName("BrowsifySettingsWindow")
        #endif

        settingsWindow = window

        // Remove existing observer if any before attaching a new one
        if let observer = settingsWindowObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        settingsWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            // Switch back to accessory mode when settings window closes
            NSApp.setActivationPolicy(.accessory)

            if let observer = self?.settingsWindowObserver {
                NotificationCenter.default.removeObserver(observer)
                self?.settingsWindowObserver = nil
            }

            self?.settingsWindow = nil
        }

        // Temporarily change to regular app to present the settings window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showWelcome() {
        if let existingWindow = welcomeWindow {
            NSApp.setActivationPolicy(.regular)
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Browsify"
        window.identifier = NSUserInterfaceItemIdentifier("welcome-window")
        window.isReleasedWhenClosed = false
        window.center()
        let controller = NSHostingController(
            rootView: WelcomeView(
                browserDetector: URLHandler.shared.getBrowserDetector()
            ) { [weak window] in
                window?.close()
            }
        )
        window.contentViewController = controller

        // SwiftUI's minimum height does not resize an already-created AppKit window.
        // Measure the actual onboarding content so profile rows cannot cover the footer.
        let fittedSize = controller.sizeThatFits(
            in: NSSize(width: 480, height: 2_000)
        )
        window.setContentSize(
            NSSize(width: 480, height: max(520, fittedSize.height))
        )
        window.center()

        welcomeWindow = window

        if let observer = welcomeWindowObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        welcomeWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
            NSApp.setActivationPolicy(.accessory)

            if let observer = self?.welcomeWindowObserver {
                NotificationCenter.default.removeObserver(observer)
                self?.welcomeWindowObserver = nil
            }

            self?.welcomeWindow = nil
        }

        // Temporarily change to regular app to present the welcome window.
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Routes a link through the full pipeline without Browsify being the system default,
    /// so routing can be exercised (and demonstrated) before changing the default browser.
    @objc func openTestLink() {
        let (alert, field) = makeOpenLinkAlert()

        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let entered = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = entered.isEmpty ? "https://www.apple.com" : entered
        let normalized = candidate.contains("://") ? candidate : "https://\(candidate)"

        guard let url = URL(string: normalized), url.host != nil else {
            let error = makeInvalidAddressAlert()
            error.runModal()
            return
        }

        URLHandler.shared.handleURL(url, sourceApp: Bundle.main.bundleIdentifier)
    }

    func makeOpenLinkAlert() -> (NSAlert, NSTextField) {
        let alert = NSAlert()
        alert.messageText = "Open a Link"
        alert.informativeText = "Browsify will route this link exactly as it would a link clicked in another app."
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.identifier = NSUserInterfaceItemIdentifier("ui-test-url-field")
        field.stringValue = "https://www.apple.com"
        field.placeholderString = "https://www.apple.com"
        alert.accessoryView = field
        return (alert, field)
    }

    func makeInvalidAddressAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "That doesn’t look like a web address"
        alert.informativeText = "Enter an address such as https://www.apple.com."
        alert.addButton(withTitle: "OK")
        return alert
    }

    @objc func quit() {
        NSApplication.shared.terminate(self)
    }

    #if DEBUG
    private static var uiTestScreen: String? {
        let prefix = "--ui-test-screen="
        return ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(prefix) })?
            .dropFirst(prefix.count)
            .description
    }

    private func showUITestScreen(_ screen: String) {
        switch screen {
        case "menu":
            statusItem?.button?.performClick(nil)
        case "welcome":
            showWelcome()
        case "link-alert":
            openTestLink()
        case "picker":
            let handler = URLHandler.shared
            handler.pendingURL = URL(string: "https://browsify-ui-test.invalid/a/long/path?query=screenshot")
            handler.sourceApplication = Bundle.main.bundleIdentifier
            handler.showBrowserPicker = true
        case "settings":
            showSettings()
        default:
            assertionFailure("Unknown UI-test screen: \(screen)")
        }
    }
    #endif

    @objc private func selectNoProfile(_ sender: NSMenuItem) {
        ProfileManager.shared.setActiveProfile(nil)
    }

    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? Profile else { return }
        ProfileManager.shared.setActiveProfile(profile)
    }

    private func rebuildStatusMenu() {
        DispatchQueue.main.async {
            guard let statusItem = self.statusItem else { return }

            let menu = NSMenu()
            menu.autoenablesItems = false

            let urlHandler = URLHandler.shared
            let browserDetector = urlHandler.getBrowserDetector()
            let defaultPreference = urlHandler.defaultBrowserPreference

            // Profiles section
            let profileManager = ProfileManager.shared
            if !profileManager.profiles.isEmpty {
                let headerItem = NSMenuItem(title: "Profile", action: nil, keyEquivalent: "")
                headerItem.isEnabled = false
                menu.addItem(headerItem)

                let noneItem = NSMenuItem(title: "None (All Rules Active)", action: #selector(self.selectNoProfile(_:)), keyEquivalent: "")
                noneItem.target = self
                noneItem.state = profileManager.activeProfileId == nil ? .on : .off
                menu.addItem(noneItem)

                for profile in profileManager.profiles {
                    let item = NSMenuItem(title: profile.name, action: #selector(self.selectProfile(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = profile
                    item.state = profileManager.activeProfileId == profile.id ? .on : .off
                    menu.addItem(item)
                }

                menu.addItem(NSMenuItem.separator())
            }

            // Prompt option
            let promptItem = NSMenuItem(title: "Prompt", action: #selector(self.selectPromptOption(_:)), keyEquivalent: "")
            promptItem.target = self
            promptItem.state = defaultPreference == .prompt ? .on : .off
            if let shortcut = self.shortcutKey(forPosition: 1) {
                promptItem.keyEquivalent = shortcut
                promptItem.keyEquivalentModifierMask = [.command]
            }
            menu.addItem(promptItem)

            // Browser entries
            let browsers = browserDetector.browsers
            if browsers.isEmpty {
                let placeholder = NSMenuItem(title: "No browsers detected", action: nil, keyEquivalent: "")
                placeholder.isEnabled = false
                menu.addItem(placeholder)
            } else {
                for (index, browser) in browsers.enumerated() {
                    let browserItem = NSMenuItem(title: browser.name, action: #selector(self.selectBrowserOption(_:)), keyEquivalent: "")
                    browserItem.target = self
                    browserItem.representedObject = browser
                    if let icon = self.menuIcon(for: browser) {
                        browserItem.image = icon
                    }
                    if case let .browser(selectedId) = defaultPreference, selectedId == browser.id {
                        browserItem.state = .on
                    }
                    if let shortcut = self.shortcutKey(forPosition: index + 2) {
                        browserItem.keyEquivalent = shortcut
                        browserItem.keyEquivalentModifierMask = [.command]
                    }
                    menu.addItem(browserItem)
                }
            }

            menu.addItem(NSMenuItem.separator())

            let testLinkItem = NSMenuItem(title: "Open a Link…", action: #selector(self.openTestLink), keyEquivalent: "o")
            testLinkItem.target = self
            menu.addItem(testLinkItem)

            menu.addItem(NSMenuItem.separator())

            let settingsItem = NSMenuItem(title: "Settings...", action: #selector(self.showSettings), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)

            let welcomeItem = NSMenuItem(title: "Welcome to Browsify…", action: #selector(self.showWelcome), keyEquivalent: "")
            welcomeItem.target = self
            menu.addItem(welcomeItem)

            menu.addItem(NSMenuItem.separator())

            let quitItem = NSMenuItem(title: "Quit Browsify", action: #selector(self.quit), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)

            statusItem.menu = menu
        }
    }

    @objc private func selectPromptOption(_ sender: NSMenuItem) {
        URLHandler.shared.setDefaultBrowserPreference(.prompt)
    }

    @objc private func selectBrowserOption(_ sender: NSMenuItem) {
        guard let browser = sender.representedObject as? Browser else {
            return
        }

        URLHandler.shared.setDefaultBrowserPreference(.browser(browser.id))
    }

    private func shortcutKey(forPosition position: Int) -> String? {
        switch position {
        case 1...9:
            return String(position)
        case 10:
            return "0"
        default:
            return nil
        }
    }

    private func menuIcon(for browser: Browser) -> NSImage? {
        guard let icon = browser.iconImage else {
            return nil
        }

        let targetSize = NSSize(width: 18, height: 18)
        let resizedIcon = NSImage(size: targetSize)

        resizedIcon.lockFocus()
        let sourceSize = icon.size
        let sourceRect = NSRect(origin: .zero, size: (sourceSize.width <= 0 || sourceSize.height <= 0) ? targetSize : sourceSize)
        icon.draw(in: NSRect(origin: .zero, size: targetSize), from: sourceRect, operation: .copy, fraction: 1.0, respectFlipped: true, hints: nil)
        resizedIcon.unlockFocus()
        resizedIcon.isTemplate = false

        return resizedIcon
    }
}
