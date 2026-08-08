#if DEBUG
import AppKit
import SwiftUI

@MainActor
enum UIScreenshotExporter {
    static func export() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowsifyUIScreens-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let detector = makeBrowserDetector()
        let rules = makeRuleEngine(browsers: detector.browsers)
        let profileManager = ProfileManager.shared
        let savedProfiles = profileManager.profiles
        let savedActiveProfileId = profileManager.activeProfileId
        defer {
            profileManager.profiles = savedProfiles
            profileManager.activeProfileId = savedActiveProfileId
        }

        let profiles = [
            Profile(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, name: "Work"),
            Profile(id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!, name: "Personal")
        ]
        profileManager.profiles = profiles
        profileManager.activeProfileId = profiles.first?.id

        try capture(
            WelcomeView(browserDetector: detector, doneAction: {}),
            size: NSSize(width: 480, height: 520),
            title: "Welcome to Browsify",
            fitContentHeight: true,
            name: "01-welcome",
            directory: directory
        )

        let handler = URLHandler.shared
        let handlerDetector = handler.getBrowserDetector()
        handlerDetector.allBrowsers = detector.allBrowsers
        handlerDetector.browsers = detector.browsers
        handler.pendingURL = URL(string: "https://browsify-ui-test.invalid/a/long/path?query=screenshot")
        try capture(
            BrowserPickerView(urlHandler: handler, browserDetector: handlerDetector),
            size: NSSize(width: 264, height: 132),
            styleMask: [.titled, .fullSizeContentView],
            name: "02-browser-picker",
            directory: directory
        )

        let delegate = AppDelegate()
        let (openLinkAlert, _) = delegate.makeOpenLinkAlert()
        try capture(alert: openLinkAlert, name: "03-open-link-alert", directory: directory)
        try capture(alert: delegate.makeInvalidAddressAlert(), name: "04-invalid-address-alert", directory: directory)

        for (index, tab, name) in [
            (5, SettingsTab.preferences, "settings-preferences"),
            (6, SettingsTab.browsers, "settings-browsers"),
            (7, SettingsTab.rules, "settings-rules"),
            (8, SettingsTab.profiles, "settings-profiles"),
            (9, SettingsTab.about, "settings-about")
        ] {
            try capture(
                SettingsView(
                    ruleEngine: rules,
                    browserDetector: detector,
                    profileManager: profileManager,
                    initialTab: tab
                ),
                size: NSSize(width: 700, height: 500),
                title: "Settings",
                name: String(format: "%02d-%@", index, name),
                directory: directory
            )
        }

        try capture(
            BrowserEditorView(browserDetector: detector, browser: nil),
            size: NSSize(width: 500, height: 300),
            title: "Add Browser",
            name: "10-add-browser",
            directory: directory
        )
        try capture(
            RuleEditorView(
                ruleEngine: rules,
                browserDetector: detector,
                profileManager: profileManager,
                rule: nil
            ),
            size: NSSize(width: 500, height: 480),
            title: "Add Rule",
            name: "11-add-rule",
            directory: directory
        )
        try capture(
            ProfilesListView(profileManager: profileManager, ruleEngine: rules, showingAddProfile: true),
            size: NSSize(width: 700, height: 500),
            title: "Add Profile",
            name: "12-add-profile",
            directory: directory
        )

        return directory
    }

    private static func makeBrowserDetector() -> BrowserDetector {
        let detector = BrowserDetector()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        let browsers = [
            Browser(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                name: "Brave Browser",
                bundleIdentifier: "com.brave.Browser",
                path: "/Applications/Brave Browser.app"
            ),
            Browser(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                name: "Firefox",
                bundleIdentifier: "org.mozilla.firefox",
                path: "/Applications/Firefox.app"
            ),
            Browser(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                name: "Google Chrome",
                bundleIdentifier: "com.google.Chrome",
                path: "/Applications/Google Chrome.app"
            )
        ]
        detector.allBrowsers = browsers
        detector.browsers = browsers
        return detector
    }

    private static func makeRuleEngine(browsers: [Browser]) -> RuleEngine {
        let defaults = UserDefaults(suiteName: "to.yumi.Browsify.UIScreens.\(UUID().uuidString)")!
        let engine = RuleEngine(defaults: defaults)
        engine.rules = [
            RoutingRule(matchType: .domain, pattern: "github.com", target: .browser(browserId: browsers[0].id, profileId: nil)),
            RoutingRule(isEnabled: false, matchType: .urlPattern, pattern: "*.example.com/*", target: .browser(browserId: browsers[2].id, profileId: nil)),
            RoutingRule(matchType: .sourceApp, pattern: "com.apple.mail", target: .desktopApp(bundleId: "com.tinyspeck.slackmacgap"))
        ]
        return engine
    }

    private static func capture<V: View>(
        _ view: V,
        size: NSSize,
        title: String = "Browsify",
        styleMask: NSWindow.StyleMask = [.titled, .closable],
        fitContentHeight: Bool = false,
        name: String,
        directory: URL
    ) throws {
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = controller
        let contentHeight = fitContentHeight
            ? max(size.height, controller.sizeThatFits(
                in: NSSize(width: size.width, height: 2_000)
            ).height)
            : size.height
        window.setContentSize(NSSize(width: size.width, height: contentHeight))
        window.center()
        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        defer { window.close() }

        guard let frameView = window.contentView?.superview else {
            throw ScreenshotError.missingView(name)
        }
        try write(frameView, name: name, directory: directory)
    }

    private static func capture(alert: NSAlert, name: String, directory: URL) throws {
        alert.layout()
        let window = alert.window
        window.center()
        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        defer { window.close() }

        guard let frameView = window.contentView?.superview else {
            throw ScreenshotError.missingView(name)
        }
        try write(frameView, name: name, directory: directory)
    }

    private static func write(_ view: NSView, name: String, directory: URL) throws {
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw ScreenshotError.bitmap(name)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.encoding(name)
        }
        try data.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
    }

    private enum ScreenshotError: LocalizedError {
        case missingView(String)
        case bitmap(String)
        case encoding(String)

        var errorDescription: String? {
            switch self {
            case .missingView(let name): "Missing frame view: \(name)"
            case .bitmap(let name): "Could not create bitmap: \(name)"
            case .encoding(let name): "Could not encode PNG: \(name)"
            }
        }
    }
}
#endif
