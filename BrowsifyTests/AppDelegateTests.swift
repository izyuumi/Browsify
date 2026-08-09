import XCTest
@testable import Browsify

final class AppDelegateTests: XCTestCase {
    func testMenuBarIconDefaultsToVisible() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        XCTAssertTrue(AppDelegate.menuBarIconIsEnabled(in: defaults))

        defaults.set(false, forKey: AppDelegate.menuBarIconPreferenceKey)
        XCTAssertFalse(AppDelegate.menuBarIconIsEnabled(in: defaults))
    }

    func testHiddenManualLaunchShowsSettingsWithoutInterruptingURLLaunches() {
        XCTAssertTrue(AppDelegate.shouldShowSettingsOnLaunch(
            hasCompletedWelcome: true,
            menuBarIconIsVisible: false,
            receivedURLDuringLaunch: false
        ))
        XCTAssertFalse(AppDelegate.shouldShowSettingsOnLaunch(
            hasCompletedWelcome: true,
            menuBarIconIsVisible: false,
            receivedURLDuringLaunch: true
        ))
        XCTAssertFalse(AppDelegate.shouldShowSettingsOnLaunch(
            hasCompletedWelcome: false,
            menuBarIconIsVisible: false,
            receivedURLDuringLaunch: false
        ))
    }
}
