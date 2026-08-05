# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Browsify is a macOS menu bar application (Swift/SwiftUI) that intercepts HTTP/HTTPS URLs and intelligently routes them to different browsers or desktop applications based on user-defined rules. It acts as a "default browser picker" with advanced routing capabilities.

## Build Commands

```bash
# Build the project
xcodebuild -project Browsify.xcodeproj -scheme Browsify -configuration Debug build

# Build for release
xcodebuild -project Browsify.xcodeproj -scheme Browsify -configuration Release build

# Clean build folder
xcodebuild -project Browsify.xcodeproj -scheme Browsify clean
```

**Note:** The project requires Xcode 26+ and targets macOS 14.0+.

## Architecture Overview

### URL Handling Flow

The core functionality follows this flow:

1. **URL Interception** (BrowsifyApp.swift): App registers as HTTP/HTTPS handler via Info.plist, receives URLs through NSAppleEventManager. The handler **must** be installed in `applicationWillFinishLaunching` — a link click cold-launches the app and macOS delivers `kAEGetURL` during launch, so registering any later silently drops the link (this caused an App Review 2.1(a) rejection)
2. **URL Cleaning** (URLCleaner.swift): Strips tracking parameters (utm_*, fbclid, etc.) if enabled
3. **Desktop App Routing** (URLHandler.swift:32): Checks if URL matches desktop app patterns (Zoom, Teams, Slack, etc.)
4. **Rule Matching** (URLHandler.swift:40): RuleEngine evaluates routing rules in list order (top-most rule wins)
5. **Browser Picker** (URLHandler.swift:46): If no match, shows interactive browser selection panel
6. **URL Opening** (Browser.swift:33): Opens URL in selected browser with optional profile

### Key Components

**URLHandler (Services/URLHandler.swift)**
- Central coordinator for all URL handling logic
- Singleton that manages pendingURL state and showBrowserPicker flag
- Orchestrates URLCleaner, RuleEngine, and BrowserDetector
- Uses Combine's @Published properties to trigger UI updates

**RuleEngine (Services/RuleEngine.swift)**
- Evaluates routing rules in the stored order (users can reorder the list; first match wins)
- Rules persist to UserDefaults as JSON
- Three match types: domain, urlPattern (supports wildcards), sourceApp
- Targets can be browser+profile or desktop app bundle ID

**BrowserDetector (Services/BrowserDetector.swift)**
- Auto-detects installed browsers from known list (Safari, Chrome, Firefox, Arc, etc.)
- Reads browser profiles from config files:
  - Chrome-based: reads Local State JSON for profile info_cache
  - Firefox: parses profiles.ini INI format
- Supports custom browsers and hidden browsers (via UserDefaults)

**InteractivePanel (InteractivePanel.swift)**
- Custom NSPanel subclass that allows keyboard/mouse input while maintaining .accessory app status
- Critical: overrides canBecomeKey=true but canBecomeMain=false
- Used for browser picker to avoid showing in Dock

### State Management

**Persistence Layer:**
- All state stored in UserDefaults (no Core Data or files)
- Keys: "routingRules", "customBrowsers", "hiddenBrowsers", "browserOrder", "browserUUIDMap", "stripTrackingParameters"
- RuleEngine, BrowserDetector use @Published to sync changes to UI
- browserUUIDMap maintains stable UUIDs for auto-detected browsers across app restarts (maps bundleId -> UUID)

**Reactive Updates:**
- URLHandler.$showBrowserPicker observed in AppDelegate (line 69) with debouncing
- Prevents multiple picker panels and handles state synchronization
- Uses Combine's sink/store pattern for memory management

### macOS Integration

**Menu Bar App Pattern:**
- NSApp.setActivationPolicy(.accessory) keeps app out of Dock
- Continuous enforcement via Timer (BrowsifyApp.swift:193) prevents policy changes
- Settings window temporarily shows in Dock when opened

**URL Scheme Registration:**
- Info.plist declares CFBundleURLTypes for http/https schemes
- LSUIElement=true prevents app from appearing in Dock
- User must set Browsify as default browser in System Settings

## Common Development Patterns

### Adding a New Browser

1. Add bundle ID to knownBrowsers array in BrowserDetector.swift:97
2. If browser has profiles, implement detection in detectProfiles() (line 150)
3. Add profile launch arguments in BrowserProfile.launchArguments() (line 62)

### Adding a New Desktop App

Add entry to DesktopApp.knownApps in DesktopApp.swift:59 with:
- Bundle identifier
- URL schemes it handles
- Domain patterns for web-based deep linking

### Sandbox Constraints

The app is sandboxed for the Mac App Store. Two rules follow from prior App Review rejections:

- **Never write executable code outside the app bundle.** A previous build wrote a launch helper script into `~/Library/Application Scripts/` and was rejected under guideline 2.4.5(ii). Don't reintroduce anything like it. (Note that the app cannot clean such a script up afterwards either — the sandbox grants only read access to that folder, so a leftover `open.sh` from a dev build stays until removed by hand.)
- **Launch browsers via LaunchServices, not stored resolved paths.** `Browser.launchCandidateURLs()` asks `NSWorkspace` for the app by bundle identifier first and falls back to the recorded path. `BrowserApplicationCandidate` keeps `canonicalPath` (symlink-resolved, for dedup) separate from `launchPath` (as reported, for launching) because resolved paths can point into read-protected locations such as the system cryptex.

### Testing URL Routing

The menu bar icon has an **"Open a Link…"** item (`AppDelegate.openTestLink`) that routes a URL through the full pipeline without Browsify being the system default. Use it for quick checks; it is also step 1 of the Welcome window and is what App Review is directed to.

To test from outside the app, send a URL straight to it — this delivers the same `kAEGetURL` Apple Event the system sends when Browsify *is* the default:

```bash
open -b to.yumi.Browsify https://example.com
```

To test the real end-to-end path (links originating from other apps, source-app rules), set Browsify as default via the Welcome window's "Set as Default Browser" button, then click a link elsewhere.

## Important Files

- **BrowsifyApp.swift**: App entry point, AppDelegate manages menu bar and panels
- **URLHandler.swift**: Core URL routing logic and state management
- **RuleEngine.swift**: Rule evaluation and persistence
- **BrowserDetector.swift**: Browser discovery and profile detection
- **Info.plist**: URL scheme registration (http/https), required for URL interception
