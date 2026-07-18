//
//  HelperScriptManager.swift
//  Browsify
//

import AppKit
import Combine
import Foundation

/// Installs the user-approved helper that launches browsers outside the App Sandbox.
@MainActor
final class HelperScriptManager: ObservableObject {
    static let shared = HelperScriptManager()

    @Published private(set) var isInstalled = false

    var scriptURL: URL? {
        applicationScriptsDirectory?.appendingPathComponent("open.sh")
    }

    private let fileManager: FileManager

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        refreshStatus()
    }

    func refreshStatus() {
        guard let scriptURL else {
            isInstalled = false
            return
        }
        isInstalled = fileManager.fileExists(atPath: scriptURL.path)
    }

    @discardableResult
    func installScript() -> Bool {
        guard let applicationScriptsDirectory else {
            showAlert(
                message: "Application Scripts Folder Unavailable",
                informativeText: "Browsify could not locate its Application Scripts folder."
            )
            return false
        }

        let panel = NSOpenPanel()
        panel.message = "Choose Browsify’s Application Scripts folder to enable profile launching."
        panel.prompt = "Install Helper"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = applicationScriptsDirectory

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return false
        }

        guard selectedURL.standardizedFileURL == applicationScriptsDirectory.standardizedFileURL else {
            showAlert(
                message: "Choose the Application Scripts Folder",
                informativeText: "For security, the helper can only be installed in the folder shown by Browsify."
            )
            return false
        }

        guard let scriptURL else {
            return false
        }

        do {
            try "#!/bin/bash\nexec /usr/bin/open \"$@\"\n".write(to: scriptURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            refreshStatus()
            return isInstalled
        } catch {
            showAlert(
                message: "Could Not Install Helper",
                informativeText: error.localizedDescription
            )
            refreshStatus()
            return false
        }
    }

    private var applicationScriptsDirectory: URL? {
        try? fileManager.url(
            for: .applicationScriptsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
    }

    private func showAlert(message: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
