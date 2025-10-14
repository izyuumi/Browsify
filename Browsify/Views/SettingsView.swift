//
//  SettingsView.swift
//  Browsify
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var ruleEngine: RuleEngine
    @ObservedObject var browserDetector: BrowserDetector

    @State private var stripTrackingParameters = UserDefaults.standard.bool(forKey: "stripTrackingParameters")

    var body: some View {
        TabView {
            PreferencesView(stripTrackingParameters: $stripTrackingParameters)
                .tabItem {
                    Label("Preferences", systemImage: "gear")
                }

            BrowsersListView(browserDetector: browserDetector)
                .tabItem {
                    Label("Browsers", systemImage: "app.badge")
                }

            RulesListView(
                ruleEngine: ruleEngine,
                browserDetector: browserDetector
            )
            .tabItem {
                Label("Rules", systemImage: "list.bullet")
            }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 700, height: 500)
    }
}

struct PreferencesView: View {
    @Binding var stripTrackingParameters: Bool

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Strip tracking parameters from URLs", isOn: $stripTrackingParameters)
                    .onChange(of: stripTrackingParameters) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "stripTrackingParameters")
                    }

                Text("Removes UTM parameters and other tracking codes from URLs before opening them.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Default Browser") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set Browsify as Default Browser")
                        .font(.headline)

                    Text("Click the button below to set Browsify as your default browser. macOS will show a confirmation dialog.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Set as Default Browser") {
                        setAsDefaultBrowser()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
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

    @State private var showingAddRule = false
    @State private var editingRule: RoutingRule?
    @State private var isReorderMode = false

    var body: some View {
        VStack {
            List {
                Section {
                    Text("Drag rules to reorder. The first match wins.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach(ruleEngine.rules) { rule in
                    RuleRowView(rule: rule, isReorderMode: isReorderMode) {
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

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingAddRule) {
            RuleEditorView(
                ruleEngine: ruleEngine,
                browserDetector: browserDetector,
                rule: nil
            )
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorView(
                ruleEngine: ruleEngine,
                browserDetector: browserDetector,
                rule: rule
            )
        }
    }
}

struct RuleRowView: View {
    let rule: RoutingRule
    let isReorderMode: Bool
    let editAction: () -> Void
    let deleteAction: () -> Void
    let toggleAction: () -> Void

    var body: some View {
        HStack {
            if !isReorderMode {
                Toggle("", isOn: .constant(rule.isEnabled))
                    .labelsHidden()
                    .onChange(of: rule.isEnabled) { _, _ in
                        toggleAction()
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(rule.pattern)
                    .font(.system(.body, weight: .medium))
                HStack {
                    Text(rule.matchType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !isReorderMode {
                Button(action: editAction) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)

                Button(action: deleteAction) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(rule.isEnabled ? 1.0 : 0.5)
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
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "link.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)

            Text("Browsify")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Smart Browser Switcher")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(appVersion)
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "arrow.triangle.branch", title: "Smart Routing", description: "Automatically open links in the right browser")
                FeatureRow(icon: "person.crop.circle", title: "Profile Support", description: "Choose specific browser profiles")
                FeatureRow(icon: "app.badge", title: "Desktop Apps", description: "Open links in native apps like Zoom and Teams")
                FeatureRow(icon: "shield.lefthalf.filled", title: "Privacy", description: "Strip tracking parameters from URLs")
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, weight: .medium))
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BrowsersListView: View {
    @ObservedObject var browserDetector: BrowserDetector

    @State private var showingAddBrowser = false
    @State private var editingBrowser: Browser?
    @State private var orderedBrowsers: [Browser] = []

    var body: some View {
        VStack {
            List {
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

            Divider()

            HStack {
                Button(action: { showingAddBrowser = true }) {
                    Label("Add Browser", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Text("\(browserDetector.browsers.count) visible, \(browserDetector.allBrowsers.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    }

    private func moveBrowsers(from source: IndexSet, to destination: Int) {
        orderedBrowsers.move(fromOffsets: source, toOffset: destination)
        browserDetector.saveBrowserDisplayOrder(orderedBrowsers)
    }
}

struct BrowserRowView: View {
    let browser: Browser
    @ObservedObject var browserDetector: BrowserDetector
    let editAction: () -> Void

    var isCustom: Bool {
        browserDetector.isCustomBrowser(browser)
    }

    var isHidden: Bool {
        browserDetector.isHidden(browser)
    }

    var body: some View {
        HStack {
            if let icon = browser.iconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .opacity(isHidden ? 0.5 : 1.0)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary)
                    .opacity(isHidden ? 0.5 : 1.0)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(browser.name)
                        .font(.system(.body, weight: .medium))
                        .opacity(isHidden ? 0.5 : 1.0)

                    if isHidden {
                        Text("Hidden")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !isCustom {
                        Text("Auto-detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Text(browser.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(isHidden ? 0.5 : 1.0)
            }

            Spacer()

            // Hide/Unhide button for all browsers
            Button(action: {
                if isHidden {
                    browserDetector.unhideBrowser(browser)
                } else {
                    browserDetector.hideBrowser(browser)
                }
            }) {
                Image(systemName: isHidden ? "eye" : "eye.slash")
            }
            .buttonStyle(.plain)
            .help(isHidden ? "Show in picker" : "Hide from picker")

            // Edit button only for custom browsers
            if isCustom {
                Button(action: editAction) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help("Edit browser")

                Button(action: {
                    browserDetector.deleteCustomBrowser(browser)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete browser")
            }
        }
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
        VStack(spacing: 20) {
            Text(browser == nil ? "Add Browser" : "Edit Browser")
                .font(.headline)
                .padding(.top)

            Form {
                TextField("Browser Name", text: $name)

                HStack {
                    TextField("Application Path", text: $path)
                        .disabled(true)
                    Button("Browse...") {
                        selectBrowserApp()
                    }
                }
                .help("Select the browser application file")
            }
            .padding()

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save") {
                    saveBrowser()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || path.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 300)
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
