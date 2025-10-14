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

**Note:** The project requires Xcode 26+ and targets macOS 13.0+.

## Architecture Overview

### URL Handling Flow

The core functionality follows this flow:

1. **URL Interception** (BrowsifyApp.swift:95): App registers as HTTP/HTTPS handler via Info.plist, receives URLs through NSAppleEventManager
2. **URL Cleaning** (URLCleaner.swift): Strips tracking parameters (utm_*, fbclid, etc.) if enabled
3. **Desktop App Routing** (URLHandler.swift:32): Checks if URL matches desktop app patterns (Zoom, Teams, Slack, etc.)
4. **Rule Matching** (URLHandler.swift:40): RuleEngine evaluates routing rules by priority
5. **Browser Picker** (URLHandler.swift:46): If no match, shows interactive browser selection panel
6. **URL Opening** (Browser.swift:33): Opens URL in selected browser with optional profile

### Key Components

**URLHandler (Services/URLHandler.swift)**
- Central coordinator for all URL handling logic
- Singleton that manages pendingURL state and showBrowserPicker flag
- Orchestrates URLCleaner, RuleEngine, and BrowserDetector
- Uses Combine's @Published properties to trigger UI updates

**RuleEngine (Services/RuleEngine.swift)**
- Evaluates routing rules in priority order (higher priority first)
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
- Keys: "routingRules", "customBrowsers", "hiddenBrowsers", "stripTrackingParameters"
- RuleEngine, BrowserDetector use @Published to sync changes to UI

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

### Testing URL Routing

Use "Test Picker..." menu item (BrowsifyApp.swift:254) to simulate URL handling without setting as default browser.

## Important Files

- **BrowsifyApp.swift**: App entry point, AppDelegate manages menu bar and panels
- **URLHandler.swift**: Core URL routing logic and state management
- **RuleEngine.swift**: Rule evaluation and persistence
- **BrowserDetector.swift**: Browser discovery and profile detection
- **Info.plist**: URL scheme registration (http/https), required for URL interception
