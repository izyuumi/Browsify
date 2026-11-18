//
//  SettingsView.swift
//  Browsify
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

enum SettingsTab: Hashable {
    case preferences
    case browsers
    case rules
    case profiles
    case about
}

struct SettingsView: View {
    @ObservedObject var ruleEngine: RuleEngine
    @ObservedObject var browserDetector: BrowserDetector
    @ObservedObject var profileManager: ProfileManager

    @State private var stripTrackingParameters = UserDefaults.browsify.bool(forKey: "stripTrackingParameters")
    @State private var selection: SettingsTab

    init(
        ruleEngine: RuleEngine,
        browserDetector: BrowserDetector,
        profileManager: ProfileManager = .shared,
        initialTab: SettingsTab = .preferences
    ) {
        self.ruleEngine = ruleEngine
        self.browserDetector = browserDetector
        self.profileManager = profileManager
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            PreferencesView(stripTrackingParameters: $stripTrackingParameters)
                .tabItem {
                    Label("Preferences", systemImage: "gear")
                }
                .tag(SettingsTab.preferences)

            BrowsersListView(browserDetector: browserDetector)
                .tabItem {
                    Label("Browsers", systemImage: "app.badge")
                }
                .tag(SettingsTab.browsers)

            RulesListView(
                ruleEngine: ruleEngine,
                browserDetector: browserDetector,
                profileManager: profileManager
            )
            .tabItem {
                Label("Rules", systemImage: "list.bullet")
            }
            .tag(SettingsTab.rules)

            ProfilesListView(
                profileManager: profileManager,
                ruleEngine: ruleEngine
            )
                .tabItem {
                    Label("Profiles", systemImage: "person.2")
                }
                .tag(SettingsTab.profiles)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 700, height: 640)
        .accessibilityIdentifier("settings-screen")
    }
}

struct PreferencesView: View {
    @Binding var stripTrackingParameters: Bool
    @AppStorage(AppDelegate.menuBarIconPreferenceKey, store: .browsify) private var showMenuBarIcon = true

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Strip tracking parameters from URLs", isOn: $stripTrackingParameters)
                    .onChange(of: stripTrackingParameters) { _, newValue in
                        UserDefaults.browsify.set(newValue, forKey: "stripTrackingParameters")
                    }

                Text("Removes UTM parameters and other tracking codes from links before opening them.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Menu Bar") {
                Toggle("Show Browsify in menu bar", isOn: $showMenuBarIcon)
                    .accessibilityIdentifier("menu-bar-toggle")
                    .onChange(of: showMenuBarIcon) { _, isVisible in
                        (NSApp.delegate as? AppDelegate)?.setMenuBarIconVisible(isVisible)
                    }

                Text("If hidden, reopen Browsify from Spotlight or Applications to show Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Default Browser") {
                LabeledContent {
                    Button("Set as Default Browser") {
                        setAsDefaultBrowser()
                    }
                } label: {
                    Text("Make Browsify your default browser")
                    Text("macOS will ask you to confirm.")
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("preferences-screen")
    }

    private func setAsDefaultBrowser() {
        let bundleURL = Bundle.main.bundleURL

        // Set as default for both HTTP and HTTPS
        NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpenURLsWithScheme: "http") { _ in }

        NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpenURLsWithScheme: "https") { _ in }
    }
}

struct RulesListView: View {
    @ObservedObject var ruleEngine: RuleEngine
    @ObservedObject var browserDetector: BrowserDetector
    @ObservedObject var profileManager: ProfileManager

    @State private var showingAddRule = false
    @State private var editingRule: RoutingRule?
    @State private var isReorderMode = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                if !ruleEngine.rules.isEmpty {
                    Section {
                        Text(isReorderMode
                            ? "Drag rules to change their order, then click Done."
                            : ruleEngine.rules.count > 1
                                ? "Rules are checked from top to bottom; the first match wins. Click Reorder to change the order."
                                : "Rules are checked from top to bottom; the first match wins.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(ruleEngine.rules) { rule in
                    RuleRowView(
                        rule: rule,
                        browserDetector: browserDetector,
                        profileManager: profileManager,
                        isReorderMode: isReorderMode
                    ) {
                        editingRule = rule
                    } deleteAction: {
                        ruleEngine.deleteRule(rule)
                    } toggleAction: {
                        var updatedRule = rule
                        updatedRule.isEnabled.toggle()
                        ruleEngine.updateRule(updatedRule)
                    }
                }
                .if(isReorderMode) { view in
                    view.onMove(perform: moveRules)
                }
            }
            .overlay {
                if ruleEngine.rules.isEmpty {
                    ContentUnavailableView {
                        Label("No Rules", systemImage: "arrow.triangle.branch")
                    } description: {
                        Text("Click Add Rule to send matching links to a specific browser, profile, or app.")
                    }
                }
            }

            Divider()

            HStack {
                Button(action: { showingAddRule = true }) {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button(action: toggleReorderMode) {
                    Label(
                        isReorderMode ? "Done" : "Reorder",
                        systemImage: isReorderMode ? "checkmark.circle" : "arrow.up.arrow.down"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(ruleEngine.rules.count < 2 && !isReorderMode)

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingAddRule) {
            RuleEditorView(
                ruleEngine: ruleEngine,
                browserDetector: browserDetector,
                profileManager: profileManager,
                rule: nil
            )
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorView(
                ruleEngine: ruleEngine,
                browserDetector: browserDetector,
                profileManager: profileManager,
                rule: rule
            )
        }
        .accessibilityIdentifier("rules-screen")
    }
}

struct RuleRowView: View {
    let rule: RoutingRule
    @ObservedObject var browserDetector: BrowserDetector
    @ObservedObject var profileManager: ProfileManager
    let isReorderMode: Bool
    let editAction: () -> Void
    let deleteAction: () -> Void
    let toggleAction: () -> Void

    // MARK: - Helpers

    private var targetDescription: String {
        switch rule.target {
        case .browser(let browserId, let profileId):
            if let browser = browserDetector.allBrowsers.first(where: { $0.id == browserId }) {
                if let profileId = profileId,
                   let profile = browser.profiles.first(where: { $0.id == profileId }) {
                    return "\(browser.name) · \(profile.name)"
                }
                return browser.name
            }
            return "Unknown browser"
        case .desktopApp(let bundleId):
            if let app = DesktopApp.knownApps.first(where: { $0.bundleIdentifier == bundleId }) {
                return app.name
            }
            return bundleId
        }
    }

    /// NSCache is thread-safe and evicts entries automatically under memory pressure.
    private static let appIconCache = NSCache<NSString, NSImage>()

    private var targetIcon: NSImage? {
        switch rule.target {
        case .browser(let browserId, _):
            return browserDetector.allBrowsers.first(where: { $0.id == browserId })?.iconImage
        case .desktopApp(let bundleId):
            if let cached = Self.appIconCache.object(forKey: bundleId as NSString) {
                return cached
            }
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                Self.appIconCache.setObject(icon, forKey: bundleId as NSString)
                return icon
            }
            return nil
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            if !isReorderMode {
                Toggle("Enabled", isOn: Binding(get: { rule.isEnabled }, set: { _ in toggleAction() }))
                    .labelsHidden()
                    .help(rule.isEnabled ? "Turn Off Rule" : "Turn On Rule")
                    .accessibilityLabel("Rule for \(rule.pattern)")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.pattern)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    Text(rule.matchType.rawValue)
                    if !rule.isEnabled {
                        Text("· Off")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                if !rule.profileIds.isEmpty {
                    let names = rule.profileIds.compactMap { id in
                        profileManager.profiles.first(where: { $0.id == id })?.name
                    }.joined(separator: ", ")
                    if !names.isEmpty {
                        Label("Profiles: \(names)", systemImage: "person.crop.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .opacity(rule.isEnabled ? 1.0 : 0.6)

            Spacer()

            // Target display
            HStack(spacing: 6) {
                if let icon = targetIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .accessibilityHidden(true)
                }
                Text(targetDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .opacity(rule.isEnabled ? 1.0 : 0.6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Opens in \(targetDescription)")

            if !isReorderMode {
                Button(action: editAction) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit Rule")
                .accessibilityLabel("Edit rule for \(rule.pattern)")

                Button(action: deleteAction) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete Rule")
                .accessibilityLabel("Delete rule for \(rule.pattern)")
            }
        }
        .padding(.vertical, 2)
    }
}

private extension RulesListView {
    func moveRules(from source: IndexSet, to destination: Int) {
        ruleEngine.moveRules(fromOffsets: source, toOffset: destination)
    }

    func toggleReorderMode() {
        withAnimation {
            isReorderMode.toggle()
        }
    }
}

struct AboutView: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Browsify"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (\(build))"
    }

    private var appIcon: NSImage {
        if let copiedIcon = NSApplication.shared.applicationIconImage.copy() as? NSImage {
            copiedIcon.size = NSSize(width: 96, height: 96)
            copiedIcon.isTemplate = false
            return copiedIcon
        }

        return NSImage(systemSymbolName: "link.circle", accessibilityDescription: nil) ?? NSImage()
    }

    private var copyright: String? {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .cornerRadius(20)
                .shadow(radius: 4, x: 0, y: 2)
                .accessibilityHidden(true)

            Text(appName)
                .font(.title2)
                .fontWeight(.semibold)

            Text(appVersion)
                .font(.callout)
                .foregroundColor(.secondary)

            Text("Route links to the right browser without breaking your flow.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 60)

            if let copyright {
                Text(copyright)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 48)
        .padding(.bottom)
    }
}

struct BrowsersListView: View {
    @ObservedObject var browserDetector: BrowserDetector

    @State private var showingAddBrowser = false
    @State private var editingBrowser: Browser?
    @State private var orderedBrowsers: [Browser] = []

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    if orderedBrowsers.isEmpty {
                        Text("No browsers found. Click Add Browser to add one.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(orderedBrowsers) { browser in
                            BrowserRowView(
                                browser: browser,
                                browserDetector: browserDetector
                            ) {
                                editingBrowser = browser
                            }
                        }
                        .onMove(perform: moveBrowsers)
                    }
                } header: {
                    Text("Browsers")
                } footer: {
                    Text("Drag to change the order in the picker. Hidden browsers don’t appear in the picker.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if browserDetector.profileCapableBrowsers.isEmpty {
                        Text("Install a supported browser to enable profile detection.")
                            .foregroundStyle(.secondary)
                    } else {
                        // Distinct row IDs: the same browsers also appear in the Browsers section above,
                        // and shared IDs make List reuse rows across the two sections.
                        ForEach(browserDetector.profileCapableBrowsers, id: \.profileAccessRowID) { browser in
                            ProfileAccessRowView(browser: browser, browserDetector: browserDetector)
                        }
                    }
                } header: {
                    Text("Browser Profiles")
                } footer: {
                    Text("Grant access so rules can open a specific browser profile.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Button(action: { showingAddBrowser = true }) {
                    Label("Add Browser", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Text("\(browserDetector.browsers.count) of \(browserDetector.allBrowsers.count) shown in picker")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .onAppear {
            orderedBrowsers = browserDetector.allBrowsers
        }
        .onChange(of: browserDetector.allBrowsers) { _, newBrowsers in
            orderedBrowsers = newBrowsers
        }
        .sheet(isPresented: $showingAddBrowser) {
            BrowserEditorView(
                browserDetector: browserDetector,
                browser: nil
            )
        }
        .sheet(item: $editingBrowser) { browser in
            BrowserEditorView(
                browserDetector: browserDetector,
                browser: browser
            )
        }
        .accessibilityIdentifier("browsers-screen")
    }

    private func moveBrowsers(from source: IndexSet, to destination: Int) {
        orderedBrowsers.move(fromOffsets: source, toOffset: destination)
        browserDetector.saveBrowserDisplayOrder(orderedBrowsers)
    }
}

private extension Browser {
    var profileAccessRowID: String { "profile-access-\(id.uuidString)" }
}

private struct ProfileAccessRowView: View {
    let browser: Browser
    @ObservedObject var browserDetector: BrowserDetector

    var body: some View {
        HStack {
            BrowserAppIcon(browser: browser, size: 20)
            Text(browser.name)
            Spacer()

            if browserDetector.hasProfileAccess(for: browser) {
                Label("Access Granted", systemImage: "checkmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(.secondary)
            } else {
                Button("Grant Access…") {
                    browserDetector.requestProfileAccess(for: browser)
                }
            }
        }
    }
}

struct BrowserRowView: View {
    let browser: Browser
    @ObservedObject var browserDetector: BrowserDetector
    let editAction: () -> Void

    @State private var shortcutError: String?
    @State private var isRecordingShortcut = false
    @FocusState private var isShortcutFocused: Bool

    var isCustom: Bool {
        browserDetector.isCustomBrowser(browser)
    }

    var isHidden: Bool {
        browserDetector.isHidden(browser)
    }

    var pickerShortcutDisplay: String {
        browserDetector.customPickerShortcut(for: browser)
            .map { BrowserPickerShortcut.displayKey($0) }
            ?? browserDetector.defaultPickerShortcut(for: browser)
                .map { BrowserPickerShortcut.displayKey($0) }
            ?? "—"
    }

    var body: some View {
        HStack(spacing: 10) {
            BrowserAppIcon(browser: browser, size: 32)
                .opacity(isHidden ? 0.5 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(browser.name)
                        .font(.body.weight(.medium))
                        .opacity(isHidden ? 0.5 : 1.0)

                    if isHidden {
                        BadgeText("Hidden")
                    }

                    if isCustom {
                        BadgeText("Custom")
                    }
                }
                Text(browser.bundleIdentifier ?? "Bundle ID unavailable")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .opacity(isHidden ? 0.5 : 1.0)

                if let shortcutError {
                    Label(shortcutError, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Picker Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Button {
                    isRecordingShortcut = true
                    isShortcutFocused = true
                } label: {
                    Text(
                        isRecordingShortcut
                            ? "Press key…"
                            : pickerShortcutDisplay
                    )
                }
                    .buttonStyle(.plain)
                    .frame(minWidth: 36)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.background, in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isShortcutFocused ? Color.accentColor : Color.secondary.opacity(0.35))
                    }
                    .contentShape(Rectangle())
                    .focused($isShortcutFocused)
                    .onKeyPress(phases: .down) { press in
                        guard isRecordingShortcut else { return .ignored }

                        if press.key == .escape {
                            shortcutError = nil
                            isRecordingShortcut = false
                            isShortcutFocused = false
                            return .handled
                        }

                        let disallowedModifiers: EventModifiers = [.command, .control, .option]
                        guard press.modifiers.intersection(disallowedModifiers).isEmpty else {
                            return .ignored
                        }

                        let error = browserDetector.setCustomPickerShortcut(
                            press.characters.isEmpty ? String(press.key.character) : press.characters,
                            for: browser
                        )
                        shortcutError = error
                        if error == nil {
                            isRecordingShortcut = false
                            isShortcutFocused = false
                        }
                        return .handled
                    }
                    .onChange(of: isShortcutFocused) { _, focused in
                        if !focused {
                            isRecordingShortcut = false
                        }
                    }
                    .disabled(isHidden)
                    .help("Click, then press any key. Escape is reserved.")
                    .accessibilityLabel("Picker key for \(browser.name)")
                    .accessibilityValue(isRecordingShortcut ? "Press key" : pickerShortcutDisplay)
                    .accessibilityHint("Click, then press a key to assign it")

                if browserDetector.customPickerShortcut(for: browser) != nil {
                    Button {
                        shortcutError = browserDetector.setCustomPickerShortcut("", for: browser)
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .buttonStyle(.plain)
                    .disabled(isHidden)
                    .help("Restore Default Key")
                    .accessibilityLabel("Restore default picker key for \(browser.name)")
                }
            }

            // Hide/Unhide button for all browsers
            Button(action: {
                if isHidden {
                    browserDetector.unhideBrowser(browser)
                } else {
                    browserDetector.hideBrowser(browser)
                }
            }) {
                Image(systemName: isHidden ? "eye" : "eye.slash")
                    .frame(width: 20)
            }
            .buttonStyle(.borderless)
            .help(isHidden ? "Show in Picker" : "Hide from Picker")
            .accessibilityLabel(isHidden ? "Show \(browser.name) in picker" : "Hide \(browser.name) from picker")

            // Edit button only for custom browsers
            if isCustom {
                Button(action: editAction) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit Browser")
                .accessibilityLabel("Edit \(browser.name)")

                Button(action: {
                    browserDetector.deleteCustomBrowser(browser)
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete Browser")
                .accessibilityLabel("Delete \(browser.name)")
            }
        }
        .padding(.vertical, 2)
    }
}

/// Small secondary tag shown next to a name, e.g. "Hidden".
private struct BadgeText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.15), in: Capsule())
    }
}

struct BrowserEditorView: View {
    @ObservedObject var browserDetector: BrowserDetector
    let browser: Browser?

    @State private var name: String
    @State private var bundleIdentifier: String
    @State private var path: String

    @Environment(\.dismiss) var dismiss

    init(browserDetector: BrowserDetector, browser: Browser?) {
        self.browserDetector = browserDetector
        self.browser = browser

        _name = State(initialValue: browser?.name ?? "")
        _bundleIdentifier = State(initialValue: browser?.bundleIdentifier ?? "")
        _path = State(initialValue: browser?.path ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(browser == nil ? "Add Browser" : "Edit Browser")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .accessibilityAddTraits(.isHeader)

            Divider()

            Form {
                LabeledContent("Application") {
                    HStack {
                        Text(path.isEmpty ? "None selected" : path)
                            .foregroundStyle(path.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(path)
                        Button("Choose…") {
                            selectBrowserApp()
                        }
                        .help("Choose Browser App")
                    }
                }

                TextField("Name", text: $name, prompt: Text("Browser name"))
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveBrowser()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || path.isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: 260)
        .accessibilityIdentifier("browser-editor-screen")
    }

    private func selectBrowserApp() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
            AccessManager.shared.storeBrowserApplicationBookmark(for: url)

            // Try to get bundle identifier from the app
            if let bundle = Bundle(url: url) {
                if let bundleId = bundle.bundleIdentifier {
                    bundleIdentifier = bundleId
                }
                if let displayName = bundle.infoDictionary?["CFBundleName"] as? String, name.isEmpty {
                    name = displayName
                }
            }

            // Fallback: generate bundle ID from app name if not found
            if bundleIdentifier.isEmpty {
                let appName = url.deletingPathExtension().lastPathComponent
                bundleIdentifier = "custom.browsify.\(appName.lowercased().replacingOccurrences(of: " ", with: ""))"

                // Auto-fill name if empty
                if name.isEmpty {
                    name = appName
                }
            }
        }
    }

    private func saveBrowser() {
        if let existingBrowser = browser {
            // Update existing browser
            let updatedBrowser = Browser(
                id: existingBrowser.id,
                name: name,
                bundleIdentifier: bundleIdentifier,
                path: path,
                icon: nil,
                profiles: []
            )
            browserDetector.updateCustomBrowser(updatedBrowser)
        } else {
            // Add new browser
            let newBrowser = Browser(
                name: name,
                bundleIdentifier: bundleIdentifier,
                path: path,
                icon: nil,
                profiles: []
            )
            browserDetector.addCustomBrowser(newBrowser)
        }
        dismiss()
    }
}

struct ProfilesListView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var ruleEngine: RuleEngine
    @State private var showingAddProfile = false
    @State private var newProfileName = ""
    @FocusState private var isNameFieldFocused: Bool

    init(profileManager: ProfileManager, ruleEngine: RuleEngine, showingAddProfile: Bool = false) {
        self.profileManager = profileManager
        self.ruleEngine = ruleEngine
        _showingAddProfile = State(initialValue: showingAddProfile)
    }

    private var trimmedProfileName: String {
        newProfileName.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(spacing: 0) {
            if profileManager.profiles.isEmpty {
                ContentUnavailableView {
                    Label("No Profiles", systemImage: "person.2")
                } description: {
                    Text("Profiles group your rules, such as Work and Personal. Click Add Profile to create one.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(profileManager.profiles) { profile in
                            let isActive = profileManager.activeProfileId == profile.id
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .opacity(isActive ? 1 : 0)
                                    .accessibilityHidden(true)

                                Text(profile.name)
                                    .font(.body.weight(isActive ? .semibold : .regular))

                                if isActive {
                                    Text("Active")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(isActive ? "Deactivate" : "Activate") {
                                    profileManager.setActiveProfile(isActive ? nil : profile)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel(isActive ? "Deactivate \(profile.name)" : "Activate \(profile.name)")

                                Button(action: {
                                    ruleEngine.removeProfileReferences(profile.id)
                                    profileManager.deleteProfile(profile)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                                .help("Delete Profile")
                                .accessibilityLabel("Delete \(profile.name)")
                            }
                            .padding(.vertical, 2)
                        }
                    } footer: {
                        Text("Rules assigned to a profile apply only while it’s active. Rules without a profile always apply.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            HStack {
                if showingAddProfile {
                    TextField("Profile name", text: $newProfileName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFieldFocused)
                        .onAppear { isNameFieldFocused = true }

                    Button("Add") {
                        guard !trimmedProfileName.isEmpty else { return }
                        profileManager.addProfile(Profile(name: trimmedProfileName))
                        newProfileName = ""
                        showingAddProfile = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedProfileName.isEmpty)
                    .keyboardShortcut(.defaultAction)

                    Button("Cancel") {
                        newProfileName = ""
                        showingAddProfile = false
                    }
                    .keyboardShortcut(.cancelAction)
                } else {
                    Button(action: { showingAddProfile = true }) {
                        Label("Add Profile", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()

                if profileManager.activeProfileId != nil {
                    Button("Clear Active Profile") {
                        profileManager.setActiveProfile(nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .accessibilityIdentifier("profiles-screen")
    }
}

// Extension to conditionally apply view modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
