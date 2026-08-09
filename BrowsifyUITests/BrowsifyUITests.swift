import XCTest

final class BrowsifyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func tearDown() {
        app?.terminate()
        app = nil
        super.tearDown()
    }

    private func launch(_ screen: String) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-test-screen=\(screen)", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
    }

    private func attach(_ name: String, element: XCUIElement? = nil) {
        let screenshot = element?.screenshot() ?? XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func selectTab(_ name: String) {
        let tab = app.tabs[name].firstMatch
        if tab.exists {
            tab.click()
            return
        }

        let button = app.buttons[name].firstMatch
        if button.exists {
            button.click()
            return
        }

        let radioButton = app.radioButtons[name].firstMatch
        XCTAssertTrue(radioButton.waitForExistence(timeout: 2), "Missing \(name) tab")
        radioButton.click()
    }

    func testWelcomeScreen() {
        launch("welcome")

        let window = app.windows["Welcome to Browsify"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 2))
        XCTAssertTrue(done.isHittable)
        XCTAssertTrue(window.frame.contains(done.frame), "Done button is clipped outside welcome window")
        XCTAssertTrue(app.buttons["Test Browsify with a Link…"].exists)
        XCTAssertTrue(app.staticTexts["Enter any web address to see where Browsify opens it."].exists)
        attach("01-welcome", element: window)
    }

    func testStatusMenu() {
        launch("menu")

        XCTAssertTrue(app.menuItems["Open a Link…"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["Settings..."].exists)
        XCTAssertTrue(app.menuItems["Welcome to Browsify…"].exists)
        XCTAssertTrue(app.menuItems["Brave Browser"].exists)
        attach("02-status-menu")
    }

    func testOpenLinkAndInvalidAddressAlerts() {
        launch("link-alert")

        let open = app.dialogs.buttons["Open"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        attach("03-open-link-alert")

        let field = app.textFields["ui-test-url-field"].firstMatch.exists
            ? app.textFields["ui-test-url-field"].firstMatch
            : app.textFields.firstMatch
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("not a web address")
        open.click()

        let error = app.staticTexts["That doesn’t look like a web address"]
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        attach("04-invalid-address-alert")
    }

    func testBrowserPicker() {
        launch("picker")

        let picker = app.dialogs["browser-picker-window"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["browser-picker-screen"].exists)
        attach("05-browser-picker")
    }

    func testSettingsScreensAndEditors() {
        launch("settings")

        let window = app.windows["Settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let menuBarToggle = app.descendants(matching: .any)["menu-bar-toggle"].firstMatch
        XCTAssertTrue(menuBarToggle.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["If hidden, reopen Browsify from Spotlight or Applications to show Settings."].exists)
        XCTAssertTrue(app.buttons["Set as Default Browser"].waitForExistence(timeout: 2))
        attach("06-settings-preferences", element: window)

        selectTab("Browsers")
        XCTAssertTrue(app.buttons["Add Browser"].waitForExistence(timeout: 2))
        attach("07-settings-browsers", element: window)
        app.buttons["Add Browser"].click()
        XCTAssertTrue(app.staticTexts["Add Browser"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        attach("08-add-browser", element: window)
        app.buttons["Cancel"].click()

        selectTab("Rules")
        XCTAssertTrue(app.buttons["Add Rule"].waitForExistence(timeout: 2))
        attach("09-settings-rules", element: window)
        app.buttons["Add Rule"].click()
        XCTAssertTrue(app.staticTexts["Add Rule"].waitForExistence(timeout: 2))
        let addRule = app.buttons["Add"].firstMatch
        let cancelRule = app.buttons["Cancel"].firstMatch
        XCTAssertFalse(addRule.isEnabled)
        XCTAssertTrue(window.frame.contains(addRule.frame), "Add button is clipped outside Settings")
        XCTAssertTrue(window.frame.contains(cancelRule.frame), "Cancel button is clipped outside Settings")
        attach("10-add-rule", element: window)
        cancelRule.click()

        selectTab("Profiles")
        XCTAssertTrue(app.buttons["Add Profile"].waitForExistence(timeout: 2))
        attach("11-settings-profiles", element: window)
        app.buttons["Add Profile"].click()
        XCTAssertTrue(app.textFields["Profile name"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Add"].isEnabled)
        attach("12-add-profile", element: window)

        selectTab("About")
        XCTAssertTrue(app.staticTexts["Browsify"].waitForExistence(timeout: 2))
        attach("13-settings-about", element: window)
    }
}
