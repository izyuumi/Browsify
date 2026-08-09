# App Store Metadata — Browsify 1.0.2

## Name (30 chars max)

Browsify
<!-- Fallback if taken: "Browsify: Browser Picker" (24 chars) -->

## Subtitle (30 chars max)

Route links to the right app

## Promotional Text (170 chars max)

Stop pasting links between browsers. Browsify sends every link to the right browser, profile, or app — automatically, based on your rules.

## Description (4000 chars max)

Browsify helps you use more than one browser on your Mac without constantly copying and pasting links.

Set Browsify as your default browser, then choose what happens when you open a link. You can pick a browser each time, choose a regular default, or make rules for specific sites and apps.

For example, work links can open in Chrome, personal links in Safari, testing links in Firefox, and meeting links directly in Zoom or Teams. Rules can match a domain, part of a URL, or the app the link came from.

Browsify can also open links in a specific Chrome, Brave, Edge, Vivaldi, or Firefox profile. Profile access is optional and requested only when you use it.

You can reorder or hide browsers, assign a custom picker key to each browser, add custom browsers, test routing with a link, hide Browsify's menu bar icon, and optionally remove common tracking parameters before a page opens.

Browsify has no accounts, analytics, or online service. Settings stay on your Mac.

Requires macOS 14.0 or later.

## Keywords (100 chars max)

browser,picker,default,chooser,link,router,url,profile,chrome,open,redirect,tracking,menu bar

## URLs

- Privacy Policy: https://github.com/izyuumi/Browsify/blob/main/PRIVACY.md
- Support: https://github.com/izyuumi/Browsify/issues
- Marketing (optional): https://github.com/izyuumi/Browsify

## App Privacy

Data Not Collected — app makes no network requests, stores settings locally in user defaults only.

## Category

Primary: Productivity
Secondary (optional): Utilities

## Pricing

Paid up front: USD 4.99 base price with Apple-suggested equivalents in other territories.

## What's New

Customize picker keyboard shortcuts for each browser. Number keys remain the default. This update also improves onboarding and lets you hide Browsify's menu bar icon.

## Review Notes (for App Review)

Browsify is a default-browser utility (same category as long-approved apps like Velja). It never displays web content itself — it receives a clicked http/https link and hands it off to a real browser or app, chosen by the user's rules.

Browsify can be exercised without changing the default browser: choose "Test Browsify with a Link…" from the menu bar icon or Welcome window. It routes the link through the same path as a link clicked in another app.

To test (about one minute):

1. Launch Browsify. A Welcome window appears and an icon is added to the menu bar. There is no Dock icon by design (LSUIElement) — the menu bar icon is the app's interface.
2. Fastest check — in the Welcome window click "Test Browsify with a Link…" (or pick it from the menu bar icon), accept the pre-filled https://www.apple.com, and click Open. Browsify's picker panel appears listing installed browsers; click one or press its displayed shortcut. Number keys are the defaults, and custom A–Z keys can be assigned in Settings > Browsers.
3. Full end-to-end check — in the Welcome window click "Set as Default Browser" and confirm the macOS system prompt. The Welcome window then shows "Browsify is your default browser". Now click any http/https link in another app (Mail, Messages), or run `open https://www.apple.com` in Terminal; the same picker appears. This works whether or not Browsify is already running.
4. For rule-based routing: open Settings from the menu bar icon, go to Rules, add a rule — match type "Domain", value "apple.com", target Safari. An apple.com link now opens in Safari immediately with no picker; other links still show the picker.
5. To restore the previous default: System Settings > Desktop & Dock > Default web browser.

Note on step 3: routing links from other apps requires Browsify to be the default browser. Until macOS is told to deliver http/https links to it, no links reach the app. This is inherent to this category of utility (the same as long-approved apps such as Velja), which is why step 2 exists.

Other features reachable from the same UI: routing by URL pattern (github.com/work/*) or by source app; targeting a specific Chrome/Brave/Edge/Vivaldi/Firefox profile; sending Zoom/Teams/Slack links to those desktop apps instead of a browser; stripping utm_*/fbclid tracking parameters.

The optional "Grant Access…" buttons use a standard NSOpenPanel and security-scoped bookmarks to read browser profile names from each browser's own config files; the app functions fully without them (only profile targeting is unavailable). The app is sandboxed, makes no network requests, has no account or server, and stores all settings locally in user defaults.
