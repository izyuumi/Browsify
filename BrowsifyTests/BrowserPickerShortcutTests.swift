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

    func testCustomKeysAreSingleASCIILetters() {
        XCTAssertEqual(BrowserPickerShortcut.normalizedCustomKey("S"), "s")
        XCTAssertNil(BrowserPickerShortcut.normalizedCustomKey("1"))
        XCTAssertNil(BrowserPickerShortcut.normalizedCustomKey(" "))
        XCTAssertNil(BrowserPickerShortcut.normalizedCustomKey("\r"))
        XCTAssertNil(BrowserPickerShortcut.normalizedCustomKey("ab"))
        XCTAssertNil(BrowserPickerShortcut.normalizedCustomKey("é"))
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
