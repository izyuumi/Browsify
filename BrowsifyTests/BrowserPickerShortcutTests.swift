//
//  BrowserPickerShortcutTests.swift
//  BrowsifyTests
//

import XCTest
@testable import Browsify

final class BrowserPickerShortcutTests: XCTestCase {
    func testNumbersRemainDefaultsAndCustomKeyOverridesByStableIdentity() {
        let safariID = UUID()
        let chromeID = UUID()
        let custom = [safariID.uuidString: "s"]

        XCTAssertEqual(
            BrowserPickerShortcut.effectiveKey(browserID: chromeID, index: 1, custom: custom),
            "2"
        )
        XCTAssertEqual(
            BrowserPickerShortcut.effectiveKey(browserID: safariID, index: 0, custom: custom),
            "s"
        )
        XCTAssertEqual(BrowserPickerShortcut.defaultKey(at: 9), "0")
        XCTAssertNil(BrowserPickerShortcut.defaultKey(at: 10))
    }

    func testCustomKeysAcceptAnySingleKeyExceptEscape() {
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey("S"), "s")
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey("1"), "1")
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey("!"), "!")
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey(" "), " ")
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey("\t"), "\t")
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey("\u{19}"), "\t")
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey("\u{3}"), "\r")
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey("\n"), "\r")
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey("\u{8}"), "\u{7f}")
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey("\u{f700}"), "\u{f700}")
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey("é"), "é")
        XCTAssertNil(BrowserPickerShortcut.normalizedCustomKey("\u{1b}"))
        XCTAssertNil(BrowserPickerShortcut.normalizedCustomKey("\u{1}"))
        XCTAssertNil(BrowserPickerShortcut.normalizedCustomKey("\u{f748}"))
        XCTAssertNil(BrowserPickerShortcut.normalizedCustomKey("ab"))
        XCTAssertNil(BrowserPickerShortcut.normalizedCustomKey(""))
    }

    func testExplicitNumberWinsOverConflictingPositionalDefault() {
        let firstID = UUID()
        let secondID = UUID()
        let custom = [secondID.uuidString: "1"]

        XCTAssertNil(
            BrowserPickerShortcut.effectiveKey(browserID: firstID, index: 0, custom: custom)
        )
        XCTAssertEqual(
            BrowserPickerShortcut.effectiveKey(browserID: secondID, index: 1, custom: custom),
            "1"
        )
    }

    func testHiddenCustomKeyDoesNotSuppressVisibleNumericDefault() {
        let visibleID = UUID()
        let hiddenID = UUID()
        let stored = [hiddenID.uuidString: "1"]
        let visibleCustom = BrowserPickerShortcut.pruned(stored, keeping: [visibleID])

        XCTAssertEqual(
            BrowserPickerShortcut.effectiveKey(
                browserID: visibleID,
                index: 0,
                custom: visibleCustom
            ),
            "1"
        )
    }

    func testDisplayNamesMakeSpecialKeysReadable() {
        XCTAssertEqual(BrowserPickerShortcut.displayKey(" "), "Space")
        XCTAssertEqual(BrowserPickerShortcut.displayKey("\t"), "Tab")
        XCTAssertEqual(BrowserPickerShortcut.displayKey("\u{f700}"), "↑")
        XCTAssertEqual(BrowserPickerShortcut.displayKey("\u{f704}"), "F1")
        XCTAssertEqual(BrowserPickerShortcut.displayKey("\u{f727}"), "Insert")
        XCTAssertEqual(BrowserPickerShortcut.displayKey("\u{f746}"), "Help")
    }

    func testCustomKeysMustBeUniqueIgnoringCase() {
        let safariID = UUID()
        let chromeID = UUID()
        let custom = [safariID.uuidString: "s"]

        XCTAssertFalse(
            BrowserPickerShortcut.isAvailable(
                "S",
                for: chromeID,
                custom: custom
            )
        )
        XCTAssertTrue(
            BrowserPickerShortcut.isAvailable(
                "c",
                for: chromeID,
                custom: custom
            )
        )
    }

    func testPruningRemovesMappingsForBrowsersNoLongerPresent() {
        let installedID = UUID()
        let removedID = UUID()
        let shortcuts = [installedID.uuidString: "s", removedID.uuidString: "f"]

        XCTAssertEqual(
            BrowserPickerShortcut.pruned(shortcuts, keeping: [installedID]),
            [installedID.uuidString: "s"]
        )
    }

    func testMappingsRoundTripThroughUserDefaultsUsingBrowserUUID() {
        let suiteName = "BrowserPickerShortcutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let shortcuts = [UUID().uuidString: "s", UUID().uuidString: "c"]

        BrowserPickerShortcut.save(shortcuts, to: defaults)

        XCTAssertEqual(BrowserPickerShortcut.load(from: defaults), shortcuts)
    }
}
