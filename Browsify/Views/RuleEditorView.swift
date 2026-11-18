//
//  RuleEditorView.swift
//  Browsify
//

import SwiftUI

struct RuleEditorView: View {
    @ObservedObject var ruleEngine: RuleEngine
    @ObservedObject var browserDetector: BrowserDetector
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) var dismiss

    let rule: RoutingRule?

    @State private var matchType: RuleMatchType
    @State private var pattern: String
    @State private var selectedBrowser: Browser?
    @State private var selectedProfile: BrowserProfile?
    @State private var selectedDesktopApp: DesktopApp?
    @State private var targetType: TargetType = .browser
    @State private var selectedProfileIds: Set<UUID>

    enum TargetType {
        case browser
        case desktopApp
    }

    init(ruleEngine: RuleEngine, browserDetector: BrowserDetector, profileManager: ProfileManager, rule: RoutingRule?) {
        self.ruleEngine = ruleEngine
        self.browserDetector = browserDetector
        self.profileManager = profileManager
        self.rule = rule

        _matchType = State(initialValue: rule?.matchType ?? .domain)
        _pattern = State(initialValue: rule?.pattern ?? "")
        _selectedProfileIds = State(initialValue: Set(rule?.profileIds ?? []))

        if let rule = rule {
            switch rule.target {
            case .browser(let browserId, let profileId):
                _targetType = State(initialValue: .browser)
                _selectedBrowser = State(initialValue: browserDetector.browsers.first(where: { $0.id == browserId }))
                if let profileId = profileId {
                    _selectedProfile = State(initialValue: _selectedBrowser.wrappedValue?.profiles.first(where: { $0.id == profileId }))
                }
            case .desktopApp(let bundleId):
                _targetType = State(initialValue: .desktopApp)
                let foundApp = DesktopApp.knownApps.first(where: { $0.bundleIdentifier == bundleId })
                NSLog("[RuleEditorView] Loading rule with desktop app target: \(bundleId)")
                if let app = foundApp {
                    NSLog("[RuleEditorView] Found app: \(app.name), isInstalled: \(app.isInstalled)")
                    if !app.isInstalled {
                        NSLog("[RuleEditorView] WARNING: Selected desktop app '\(app.name)' is not installed - clearing selection")
                        // Don't set an uninstalled app as selection - it will cause Picker tag errors
                        _selectedDesktopApp = State(initialValue: nil)
                    } else {
                        _selectedDesktopApp = State(initialValue: foundApp)
                    }
                } else {
                    NSLog("[RuleEditorView] WARNING: Desktop app with bundleId '\(bundleId)' not found in knownApps")
                    _selectedDesktopApp = State(initialValue: nil)
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(rule == nil ? "Add Rule" : "Edit Rule")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .accessibilityAddTraits(.isHeader)

            Divider()

            // Form
            Form {
                Section("When a Link Matches") {
                    Picker("Match", selection: $matchType) {
                        ForEach(RuleMatchType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Pattern", text: $pattern, prompt: Text(patternPrompt))
                        .accessibilityHint(matchTypeHint)

                    Text(matchTypeHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !profileManager.profiles.isEmpty {
                    Section {
                        ForEach(profileManager.profiles) { profile in
                            Toggle(profile.name, isOn: Binding(
                                get: { selectedProfileIds.contains(profile.id) },
                                set: { checked in
                                    if checked { selectedProfileIds.insert(profile.id) }
                                    else { selectedProfileIds.remove(profile.id) }
                                }
                            ))
                        }
                    } header: {
                        Text("Only in Profiles")
                    } footer: {
                        Text("Leave all unchecked to apply this rule in every profile.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Open With") {
                    Picker("Open with", selection: $targetType) {
                        Text("Browser").tag(TargetType.browser)
                        Text("Desktop App").tag(TargetType.desktopApp)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if targetType == .browser {
                        Picker("Browser", selection: $selectedBrowser) {
                            Text("Choose a Browser").tag(nil as Browser?)
                            ForEach(browserDetector.browsers) { browser in
                                Text(browser.name).tag(browser as Browser?)
                            }
                        }

                        if let browser = selectedBrowser, !browser.profiles.isEmpty {
                            Picker("Profile", selection: $selectedProfile) {
                                Text("Default Profile").tag(nil as BrowserProfile?)
                                ForEach(browser.profiles) { profile in
                                    Text(profile.name).tag(profile as BrowserProfile?)
                                }
                            }
                        }
                    } else {
                        let installedApps = DesktopApp.knownApps.filter { $0.isInstalled }
                        Picker("Desktop App", selection: $selectedDesktopApp) {
                            Text("Choose an App").tag(nil as DesktopApp?)
                            ForEach(installedApps) { app in
                                Text(app.name).tag(app as DesktopApp?)
                            }
                        }
                        .disabled(installedApps.isEmpty)

                        if installedApps.isEmpty {
                            Text("None of the supported apps (\(DesktopApp.knownApps.map(\.name).joined(separator: ", "))) are installed.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(rule == nil ? "Add" : "Save") {
                    saveRule()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding()
        }
        // Keep the sheet inside the default 500-point Settings content area.
        // Form supplies scrolling when profile rows need more space.
        .frame(width: 500, height: 480)
        .accessibilityIdentifier("rule-editor-screen")
        .onAppear {
            browserDetector.detectBrowsers()
        }
    }

    private var matchTypeHint: String {
        switch matchType {
        case .domain:
            return "Match the host name. Supports wildcards, e.g. *.google.com, mail.* or github.com"
        case .urlPattern:
            return "Match the full URL. Supports wildcards, e.g. https://meet.google.com/*, *zoom.us*"
        case .sourceApp:
            return "Match the source application bundle ID, e.g. com.apple.mail, com.microsoft.Outlook"
        }
    }

    private var patternPrompt: String {
        switch matchType {
        case .domain: return "github.com"
        case .urlPattern: return "https://meet.google.com/*"
        case .sourceApp: return "com.apple.mail"
        }
    }

    private var canSave: Bool {
        !pattern.isEmpty && (
            (targetType == .browser && selectedBrowser != nil) ||
            (targetType == .desktopApp && selectedDesktopApp != nil)
        )
    }

    private func saveRule() {
        let availableProfileIds = Set(profileManager.profiles.map(\.id))
        let target: RuleTarget
        if targetType == .browser, let browser = selectedBrowser {
            target = .browser(browserId: browser.id, profileId: selectedProfile?.id)
        } else if targetType == .desktopApp, let app = selectedDesktopApp {
            target = .desktopApp(bundleId: app.bundleIdentifier)
        } else {
            return
        }

        let newRule = RoutingRule(
            id: rule?.id ?? UUID(),
            isEnabled: rule?.isEnabled ?? true,
            matchType: matchType,
            pattern: pattern,
            target: target,
            profileIds: Array(selectedProfileIds.intersection(availableProfileIds))
        )

        if rule != nil {
            ruleEngine.updateRule(newRule)
        } else {
            ruleEngine.addRule(newRule)
        }

        dismiss()
    }
}
