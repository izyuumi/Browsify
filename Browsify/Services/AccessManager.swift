//
//  AccessManager.swift
//  Browsify
//

import AppKit
import Darwin
import Foundation

/// Persists user-selected browser-support folders as app-scoped security bookmarks.
/// The App Sandbox does not allow access to these folders until the user selects them.
final class AccessManager {
    static let shared = AccessManager()

    private let folderBookmarksKey = "folderBookmarks"
    private let browserApplicationBookmarksKey = "browserApplicationBookmarks"
    private let userDefaults: UserDefaults

    private struct ProfileFolder {
        let bundleIdentifier: String
        let applicationSupportComponents: [String]
    }

    private let profileFolders: [ProfileFolder] = [
        ProfileFolder(bundleIdentifier: "com.google.Chrome", applicationSupportComponents: ["Google", "Chrome"]),
        ProfileFolder(bundleIdentifier: "com.brave.Browser", applicationSupportComponents: ["BraveSoftware", "Brave-Browser"]),
        ProfileFolder(bundleIdentifier: "com.microsoft.edgemac", applicationSupportComponents: ["Microsoft Edge"]),
        ProfileFolder(bundleIdentifier: "com.vivaldi.Vivaldi", applicationSupportComponents: ["Vivaldi"]),
        ProfileFolder(bundleIdentifier: "org.mozilla.firefox", applicationSupportComponents: ["Firefox"]),
    ]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func supportsProfileDetection(for bundleIdentifier: String) -> Bool {
        profileFolders.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func hasProfileFolderAccess(for bundleIdentifier: String) -> Bool {
        withProfileFolderAccess(for: bundleIdentifier) { _ in true } ?? false
    }

    /// Persists the user-selected application bundle for custom browsers.
    func storeBrowserApplicationBookmark(for applicationURL: URL) {
        do {
            let bookmark = try applicationURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = savedApplicationBookmarks()
            bookmarks[applicationURL.path] = bookmark
            userDefaults.set(bookmarks, forKey: browserApplicationBookmarksKey)
        } catch {
            NSLog("[AccessManager] Failed to create browser application bookmark: \(error.localizedDescription)")
        }
    }

    /// Runs work with a custom-browser application bookmark active when one exists.
    func withBrowserApplicationAccess<T>(at path: String, perform work: (URL) -> T) -> T? {
        guard let bookmark = savedApplicationBookmarks()[path] else {
            return nil
        }

        var isStale = false
        do {
            let applicationURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard applicationURL.startAccessingSecurityScopedResource() else {
                return nil
            }
            defer { applicationURL.stopAccessingSecurityScopedResource() }

            if isStale {
                storeBrowserApplicationBookmark(for: applicationURL)
            }
            return work(applicationURL)
        } catch {
            NSLog("[AccessManager] Failed to resolve browser application bookmark: \(error.localizedDescription)")
            var bookmarks = savedApplicationBookmarks()
            bookmarks.removeValue(forKey: path)
            userDefaults.set(bookmarks, forKey: browserApplicationBookmarksKey)
            return nil
        }
    }

    /// Presents a directory picker focused on the browser's real Application Support folder.
    /// The selected folder must be the expected folder so access is no broader than needed.
    func requestProfileFolderAccess(for bundleIdentifier: String, completion: @escaping (Bool) -> Void) {
        guard let expectedURL = profileFolderURL(for: bundleIdentifier) else {
            completion(false)
            return
        }

        let panel = NSOpenPanel()
        panel.message = "Allow Browsify to read browser profiles"
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = expectedURL

        guard panel.runModal() == .OK, let selectedURL = panel.url,
              selectedURL.standardizedFileURL == expectedURL.standardizedFileURL else {
            completion(false)
            return
        }

        do {
            let bookmark = try selectedURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = savedBookmarks()
            bookmarks[bundleIdentifier] = bookmark
            saveBookmarks(bookmarks)
            completion(true)
        } catch {
            NSLog("[AccessManager] Failed to create security-scoped bookmark: \(error.localizedDescription)")
            completion(false)
        }
    }

    /// Runs work while the security scope for a browser profile folder is active.
    func withProfileFolderAccess<T>(for bundleIdentifier: String, perform work: (URL) -> T) -> T? {
        guard let bookmark = savedBookmarks()[bundleIdentifier] else {
            return nil
        }

        var isStale = false
        do {
            let folderURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard folderURL.startAccessingSecurityScopedResource() else {
                return nil
            }
            defer { folderURL.stopAccessingSecurityScopedResource() }

            if isStale {
                refreshBookmark(for: bundleIdentifier, folderURL: folderURL)
            }

            return work(folderURL)
        } catch {
            NSLog("[AccessManager] Failed to resolve security-scoped bookmark: \(error.localizedDescription)")
            var bookmarks = savedBookmarks()
            bookmarks.removeValue(forKey: bundleIdentifier)
            saveBookmarks(bookmarks)
            return nil
        }
    }

    private func profileFolderURL(for bundleIdentifier: String) -> URL? {
        guard let profileFolder = profileFolders.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return nil
        }

        return profileFolder.applicationSupportComponents.reduce(
            realHomeDirectoryURL().appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        ) { partialURL, component in
            partialURL.appendingPathComponent(component, isDirectory: true)
        }
    }

    /// `homeDirectoryForCurrentUser` points at the app container when sandboxed.
    /// POSIX account data still gives us the real path solely to pre-navigate NSOpenPanel.
    private func realHomeDirectoryURL() -> URL {
        guard let passwd = getpwuid(getuid()), let homeDirectory = passwd.pointee.pw_dir else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(fileURLWithPath: String(cString: homeDirectory), isDirectory: true)
    }

    private func savedBookmarks() -> [String: Data] {
        userDefaults.dictionary(forKey: folderBookmarksKey) as? [String: Data] ?? [:]
    }

    private func saveBookmarks(_ bookmarks: [String: Data]) {
        userDefaults.set(bookmarks, forKey: folderBookmarksKey)
    }

    private func savedApplicationBookmarks() -> [String: Data] {
        userDefaults.dictionary(forKey: browserApplicationBookmarksKey) as? [String: Data] ?? [:]
    }

    private func refreshBookmark(for bundleIdentifier: String, folderURL: URL) {
        guard let refreshedBookmark = try? folderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return
        }

        var bookmarks = savedBookmarks()
        bookmarks[bundleIdentifier] = refreshedBookmark
        saveBookmarks(bookmarks)
    }
}
