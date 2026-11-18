# App Store Metadata — Browsify 1.0.4

## Name (30 chars max)

Browsify
<!-- Fallback if taken: "Browsify: Browser Picker" (24 chars) -->

## Subtitle (30 chars max)

Right browser for every link

## Promotional Text (170 chars max)

Every link, right place. Send links to the browser, profile, or Mac app they belong in — with rules for the routine and a quick, keyboard-friendly picker for the rest.

## Description (4000 chars max)

Every link, right place.

Browsify is a small menu bar app that becomes your default browser and sends each link you click to the browser, browser profile, or Mac app where it belongs. Work links in Chrome, personal links in Safari, meeting links straight into Zoom — without copying and pasting URLs between windows.

RULES FOR THE ROUTINE
• Match a domain (github.com), part of a URL (docs.example.com/*), or the app the link came from (Mail, Slack, Messages)
• Send matches to any browser, a specific browser profile, or a desktop app
• Rules run top to bottom; reorder them or switch one off without deleting it

A QUICK PICKER FOR THE REST
• Links without a rule open a compact picker in the middle of your screen
• Every browser gets a picker key — press 1, 2, 3 or any key you choose
• Reorder or hide browsers, and add browsers Browsify doesn't detect automatically

BROWSER PROFILES
• Open links in a specific Chrome, Brave, Edge, Vivaldi, or Firefox profile
• Profile access is optional and requested only when you use it

MEETINGS AND APPS
• Zoom, Microsoft Teams and Slack links can open directly in their desktop apps

WORK AND PERSONAL MODES
• Group rules into Browsify profiles such as Work and Personal and switch from the menu bar

CLEANER LINKS
• Optionally remove common tracking parameters (utm_*, fbclid and others) before a page opens

TRY IT FIRST
Choose Open a Link… from the menu bar to see exactly where a link would go before you make Browsify your default browser.

PRIVATE BY DESIGN
No account, no analytics, no network requests. Your rules and settings stay on your Mac.

Requires macOS 14.0 or later.

## Keywords (100 chars max)

default,picker,chooser,router,url,profile,chrome,open with,redirect,tracking,menu bar,rules,switcher

## URLs

- Privacy Policy: https://browsify.yumi.to/privacy/
- Support: https://browsify.yumi.to/support/
- Marketing: https://browsify.yumi.to/

## App Privacy

Data Not Collected — app makes no network requests, stores settings locally in user defaults only.

## Category

Primary: Productivity
Secondary (optional): Utilities

## Pricing

Paid up front: USD 4.99 base price with Apple-suggested equivalents in other territories.

## What's New

A cleaner, easier-to-read Browsify.

• Refined layout, spacing and typography in the picker, Welcome window and Settings
• Clearer labels and helpful empty states
• Better VoiceOver labels, keyboard handling and larger-text support
• Polished light and dark appearance

## Review Notes (for App Review)

Browsify is a default-browser utility (same category as long-approved apps like Velja). It never displays web content itself — it receives a clicked http/https link and hands it off to a real browser or app, chosen by the user's rules.

Browsify can be exercised without changing the default browser: choose "Test Browsify with a Link…" from the menu bar icon or Welcome window. It routes the link through the same path as a link clicked in another app.

To test (about one minute):

1. Launch Browsify. A Welcome window appears and an icon is added to the menu bar. There is no Dock icon by design (LSUIElement) — the menu bar icon is the app's interface.
2. Fastest check — in the Welcome window click "Test Browsify with a Link…" (or pick it from the menu bar icon), accept the pre-filled https://www.apple.com, and click Open. Browsify's picker panel appears listing installed browsers; click one or press its displayed shortcut. In Settings > Browsers, click a browser's Picker key button, then press a key. Letters, numbers, symbols, Space, Return, arrows, and function keys are supported; Escape cancels recording, and Command/Control/Option combinations are ignored.
3. Full end-to-end check — in the Welcome window click "Set as Default Browser" and confirm the macOS system prompt. The Welcome window then shows "Browsify is your default browser". Now click any http/https link in another app (Mail, Messages), or run `open https://www.apple.com` in Terminal; the same picker appears. This works whether or not Browsify is already running.
4. For rule-based routing: open Settings from the menu bar icon, go to Rules, add a rule — Match "Domain", Pattern "apple.com", Open With Safari. An apple.com link now opens in Safari immediately with no picker; other links still show the picker.
5. To restore the previous default: System Settings > Desktop & Dock > Default web browser.

Note on step 3: routing links from other apps requires Browsify to be the default browser. Until macOS is told to deliver http/https links to it, no links reach the app. This is inherent to this category of utility (the same as long-approved apps such as Velja), which is why step 2 exists.

Other features reachable from the same UI: routing by URL pattern (github.com/work/*) or by source app; targeting a specific Chrome/Brave/Edge/Vivaldi/Firefox profile; sending Zoom/Teams/Slack links to those desktop apps instead of a browser; stripping utm_*/fbclid tracking parameters.

The optional "Grant Access…" buttons use a standard NSOpenPanel and security-scoped bookmarks to read browser profile names from each browser's own config files; the app functions fully without them (only profile targeting is unavailable). The app is sandboxed, makes no network requests, has no account or server, and stores all settings locally in user defaults.
