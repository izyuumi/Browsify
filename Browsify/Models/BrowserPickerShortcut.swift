//
//  BrowserPickerShortcut.swift
//  Browsify
//

import Foundation

enum BrowserPickerShortcut {
    static let storageKey = "browserPickerShortcuts"

    static func load(from defaults: UserDefaults = .standard) -> [String: String] {
        defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }

    static func save(_ shortcuts: [String: String], to defaults: UserDefaults = .standard) {
        defaults.set(shortcuts, forKey: storageKey)
    }

    static func pruned(_ shortcuts: [String: String], keeping browserIDs: Set<UUID>) -> [String: String] {
        shortcuts.filter { browserID, _ in
            UUID(uuidString: browserID).map(browserIDs.contains) == true
        }
    }

    static func defaultKey(at index: Int) -> String? {
        switch index {
        case 0...8: String(index + 1)
        case 9: "0"
        default: nil
        }
    }

    static func effectiveKey(browserID: UUID, index: Int, custom: [String: String]) -> String? {
        custom[browserID.uuidString] ?? defaultKey(at: index)
    }

    static func normalizedEventKey(_ rawValue: String) -> String? {
        guard isASCIIAlphanumeric(rawValue) else { return nil }
        return rawValue.lowercased()
    }

    static func normalizedCustomKey(_ rawValue: String) -> String? {
        guard rawValue.utf8.count == 1,
              let byte = rawValue.utf8.first,
              (65...90).contains(byte) || (97...122).contains(byte) else {
            return nil
        }

        return rawValue.lowercased()
    }

    static func isAvailable(
        _ key: String,
        for browserID: UUID,
        custom: [String: String]
    ) -> Bool {
        let browserIDString = browserID.uuidString
        return !custom.contains { otherBrowserID, otherKey in
            otherBrowserID != browserIDString && otherKey.caseInsensitiveCompare(key) == .orderedSame
        }
    }

    private static func isASCIIAlphanumeric(_ rawValue: String) -> Bool {
        guard rawValue.utf8.count == 1, let byte = rawValue.utf8.first else { return false }
        return (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
    }
}
