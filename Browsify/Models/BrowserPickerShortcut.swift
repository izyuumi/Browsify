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
        let browserIDString = browserID.uuidString
        if let customKey = custom[browserIDString] {
            return customKey
        }

        guard let defaultKey = defaultKey(at: index) else { return nil }
        return custom.contains { otherBrowserID, customKey in
            otherBrowserID != browserIDString && keysMatch(customKey, defaultKey)
        } ? nil : defaultKey
    }

    static func normalizedEventKey(_ rawValue: String) -> String? {
        normalizedKey(rawValue)
    }

    static func normalizedCustomKey(_ rawValue: String) -> String? {
        normalizedKey(rawValue)
    }

    static func displayKey(_ key: String) -> String {
        switch key {
        case " ": return "Space"
        case "\t": return "Tab"
        case "\r", "\n": return "↩"
        case "\u{c}": return "Clear"
        case "\u{7f}", "\u{8}": return "⌫"
        case "\u{f700}": return "↑"
        case "\u{f701}": return "↓"
        case "\u{f702}": return "←"
        case "\u{f703}": return "→"
        default:
            if key.unicodeScalars.count == 1,
               let scalar = key.unicodeScalars.first {
                if (0xf704...0xf726).contains(scalar.value) {
                    return "F\(scalar.value - 0xf703)"
                }
                if let name = specialKeyNames[scalar.value] {
                    return name
                }
            }
            return key.uppercased()
        }
    }

    static func isAvailable(
        _ key: String,
        for browserID: UUID,
        custom: [String: String]
    ) -> Bool {
        let browserIDString = browserID.uuidString
        return !custom.contains { otherBrowserID, otherKey in
            otherBrowserID != browserIDString && keysMatch(otherKey, key)
        }
    }

    private static func normalizedKey(_ rawValue: String) -> String? {
        guard rawValue.count == 1,
              let scalar = rawValue.unicodeScalars.first,
              rawValue.unicodeScalars.count == 1,
              scalar.value != 0x1b else {
            return nil
        }

        switch rawValue {
        case "\u{3}", "\n", "\r", "\u{2028}", "\u{2029}": return "\r"
        case "\u{8}", "\u{7f}": return "\u{7f}"
        case "\u{19}": return "\t"
        default:
            if scalar.value < 0x20,
               ![0x09, 0x0c].contains(scalar.value) {
                return nil
            }
            if (0xe000...0xf8ff).contains(scalar.value),
               !(0xf700...0xf747).contains(scalar.value) {
                return nil
            }
            let lowercased = rawValue.lowercased()
            return lowercased.count == 1 ? lowercased : rawValue
        }
    }

    private static func keysMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }

    private static let specialKeyNames: [UInt32: String] = [
        0xf727: "Insert",
        0xf728: "⌦",
        0xf729: "Home",
        0xf72a: "Begin",
        0xf72b: "End",
        0xf72c: "PgUp",
        0xf72d: "PgDn",
        0xf72e: "PrtSc",
        0xf72f: "ScrLk",
        0xf730: "Pause",
        0xf731: "SysReq",
        0xf732: "Break",
        0xf733: "Reset",
        0xf734: "Stop",
        0xf735: "Menu",
        0xf736: "User",
        0xf737: "System",
        0xf738: "Print",
        0xf739: "ClrLn",
        0xf73a: "ClrDisp",
        0xf73b: "InsLn",
        0xf73c: "DelLn",
        0xf73d: "InsChar",
        0xf73e: "DelChar",
        0xf73f: "Previous",
        0xf740: "Next",
        0xf741: "Select",
        0xf742: "Exec",
        0xf743: "Undo",
        0xf744: "Redo",
        0xf745: "Find",
        0xf746: "Help",
        0xf747: "Mode"
    ]
}
