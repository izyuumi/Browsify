//
//  RuleEditorView.swift
//  Browsify
//

import SwiftUI

struct RuleEditorView: View {
    @ObservedObject var ruleEngine: RuleEngine
    @ObservedObject var browserDetector: BrowserDetector
    @Environment(\.dismiss) var dismiss

    let rule: RoutingRule?

    @State private var matchType: RuleMatchType
    @State private var pattern: String
    @State private var selectedBrowser: Browser?
    @State private var selectedProfile: BrowserProfile?
    @State private var selectedDesktopApp: DesktopApp?
    @State private var targetType: TargetType = .browser

    enum TargetType {
        case browser
        case desktopApp
    }

    init(ruleEngine: RuleEngine, browserDetector: BrowserDetector, rule: RoutingRule?) {
        self.ruleEngine = ruleEngine
        self.browserDetector = browserDetector
        self.rule = rule

        _matchType = State(initialValue: rule?.matchType ?? .domain)
        _pattern = State(initialValue: rule?.pattern ?? "")

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
            HStack {
                Text(rule == nil ? "Add Rule" : "Edit Rule")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Match Condition") {
                    Picker("Type", selection: $matchType) {
                        ForEach(RuleMatchType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Pattern", text: $pattern)
                        .textFieldStyle(.roundedBorder)

                    Text(matchTypeHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Target") {
                    Picker("Open with", selection: $targetType) {
                        Text("Browser").tag(TargetType.browser)
                        Text("Desktop App").tag(TargetType.desktopApp)
                    }
                    .pickerStyle(.segmented)

                    if targetType == .browser {
                        Picker("Browser", selection: $selectedBrowser) {
                            Text("Select Browser").tag(nil as Browser?)
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
                        Picker("Desktop App", selection: $selectedDesktopApp) {
                            Text("Select App").tag(nil as DesktopApp?)
                            ForEach(DesktopApp.knownApps.filter { $0.isInstalled }) { app in
                                Text(app.name).tag(app as DesktopApp?)
                            }
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

                Spacer()

                Button(rule == nil ? "Add" : "Save") {
                    saveRule()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding()
        }
        .frame(width: 500, height: 550)
        .onAppear {
            browserDetector.detectBrowsers()
        }
    }

    private var matchTypeHint: String {
        switch matchType {
        case .domain:
            return "Example: google.com, github.com"
        case .urlPattern:
            return "Example: https://meet.google.com/*, *zoom.us*"
        case .sourceApp:
            return "Example: com.apple.mail, com.microsoft.Outlook"
        }
    }

    private var canSave: Bool {
        !pattern.isEmpty && (
            (targetType == .browser && selectedBrowser != nil) ||
            (targetType == .desktopApp && selectedDesktopApp != nil)
        )
    }

    private func saveRule() {
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
            target: target
        )

        if rule != nil {
            ruleEngine.updateRule(newRule)
        } else {
            ruleEngine.addRule(newRule)
        }

        dismiss()
    }
}
