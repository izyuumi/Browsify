#if DEBUG
import AppKit
import SwiftUI

/// Renders every screen offscreen with `DemoData` (export always runs in demo mode,
/// so no real browsers, profiles, rules, or settings are read).
@MainActor
enum UIScreenshotExporter {
    static func export() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowsifyUIScreens-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let handler = URLHandler.shared
        let detector = handler.getBrowserDetector()
        let rules = handler.getRuleEngine()
        let profileManager = ProfileManager.shared
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        try capture(
            WelcomeView(browserDetector: detector, doneAction: {}),
            size: NSSize(width: 480, height: 520),
            title: "Welcome to Browsify",
            fitContentHeight: true,
            name: "01-welcome",
            directory: directory
        )

        handler.pendingURL = DemoData.pickerURL
        try capture(
            BrowserPickerView(urlHandler: handler, browserDetector: detector),
            size: NSSize(width: 344, height: 132),
            styleMask: [.titled, .fullSizeContentView],
            fitContentHeight: true,
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
                size: NSSize(width: 700, height: 640),
                title: "Settings",
                name: String(format: "%02d-%@", index, name),
                directory: directory
            )
        }

        try capture(
            BrowserEditorView(browserDetector: detector, browser: nil),
            size: NSSize(width: 480, height: 260),
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
            name: "11-add-rule",
            directory: directory
        )
        try capture(
            ProfilesListView(profileManager: profileManager, ruleEngine: rules, showingAddProfile: true),
            size: NSSize(width: 700, height: 640),
            title: "Settings",
            name: "12-add-profile",
            directory: directory
        )

        return directory
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
        let scale: CGFloat = 4
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(view.bounds.width * scale),
            pixelsHigh: Int(view.bounds.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw ScreenshotError.bitmap(name)
        }
        bitmap.size = view.bounds.size
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
