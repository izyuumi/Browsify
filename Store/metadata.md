# App Store Metadata — Browsify 1.0

## Name (30 chars max)

Browsify
<!-- Fallback if taken: "Browsify: Browser Picker" (24 chars) -->

## Subtitle (30 chars max)

Route links to the right app

## Promotional Text (170 chars max)

Stop pasting links between browsers. Browsify sends every link to the right browser, profile, or app — automatically, based on your rules.

## Description (4000 chars max)

Browsify is a smart default browser for your Mac. Set it once, and every link you click goes exactly where you want it — the right browser, the right profile, or the right app.

WHY BROWSIFY

If you use more than one browser — Safari for personal, Chrome for work, Firefox for testing — macOS makes you pick a single default. Browsify removes that limit. It quietly lives in your menu bar, catches every link you click, and routes it by rules you control.

ROUTING RULES

• Route by domain, with wildcard support (*.example.com)
• Route by URL pattern (github.com/work/*)
• Route by source app — links from Slack open differently than links from Mail
• Rules evaluate top to bottom; drag to reorder, first match wins

BROWSER PROFILES

Work and personal Chrome profiles? Browsify can route links straight into a specific profile of Chrome, Brave, Edge, Vivaldi, or Firefox. Profile detection is optional and permission-based — you grant read access explicitly, and Browsify guarantees the link opens in the profile you chose, even when the browser is already running.

STRAIGHT TO APPS

Zoom, Teams, Slack, and other meeting or chat links can skip the browser entirely and open in their desktop apps.

INTERACTIVE PICKER

No rule matched? A minimal picker appears at your cursor. Hit 1, 2, 3… to choose a browser and keep moving. Your hands never leave the keyboard.

CLEANER LINKS

Optionally strip tracking parameters (utm_*, fbclid, and friends) from every URL before it opens.

PRIVATE BY DESIGN

Browsify collects no data. No analytics, no network requests, no accounts. Everything stays on your Mac. It runs sandboxed, and every permission is explicit and optional.

DETAILS

• Lives in the menu bar — no Dock icon, no clutter
• Auto-detects installed browsers, including custom ones
• Hide browsers you never use; reorder the rest
• Test your rules any time with "Open a Link…" in the menu bar
• Open source — inspect the code on GitHub

Requires macOS 14.0 or later. To use Browsify, set it as your default browser in System Settings — the welcome screen walks you through it.

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

Paid up front: USD 4.99 base price (Apple-suggested equivalents in all other territories, e.g. ¥700 JPY).

## Review Notes (for App Review)

Browsify is a default-browser utility (same category as long-approved apps like Velja). It never displays web content itself — it receives a clicked http/https link and hands it off to a real browser or app, chosen by the user's rules.

FIXES IN THIS BUILD, addressing the August 3 review of build 3:

- Guideline 2.1(a) — the reported bug is fixed and its cause identified. The previous build installed its URL event handler after launch had finished. When a link click launched Browsify (the normal case, since a menu bar utility is usually not already running), macOS delivered the link during launch and it was discarded, so no browser opened and no picker appeared. The handler is now installed in applicationWillFinishLaunching, before the event is delivered. Verified by cold-launching a link with the app not running: the picker appears and the chosen browser opens.
- Guideline 2.4.5(ii) — removed. Build 3 offered, through an NSOpenPanel, to write a small shell script into the app's own Application Scripts folder so browsers could be launched with profile arguments. That code and the UI that offered it are gone. This build writes no code anywhere, ships no scripts or helper executables (the bundle contains only the main binary and its resources), and links are launched entirely through NSWorkspace.

Browsify can now be exercised WITHOUT changing the default browser: choose "Open a Link…" from the menu bar icon (also offered as step 1 of the Welcome window). It routes the link through exactly the same path as a link clicked in another app.

To test (about one minute):

1. Launch Browsify. A Welcome window appears and an icon is added to the menu bar. There is no Dock icon by design (LSUIElement) — the menu bar icon is the app's interface.
2. Fastest check — in the Welcome window click "Open a Link…" (or pick it from the menu bar icon), accept the pre-filled https://www.apple.com, and click Open. Browsify's picker panel appears listing installed browsers; click one, or press 1, 2, 3…, and the link opens in that browser.
3. Full end-to-end check — in the Welcome window click "Set as Default Browser" and confirm the macOS system prompt. The Welcome window then shows "Browsify is your default browser". Now click any http/https link in another app (Mail, Messages), or run `open https://www.apple.com` in Terminal; the same picker appears. This works whether or not Browsify is already running.
4. For rule-based routing: open Settings from the menu bar icon, go to Rules, add a rule — match type "Domain", value "apple.com", target Safari. An apple.com link now opens in Safari immediately with no picker; other links still show the picker.
5. To restore the previous default: System Settings > Desktop & Dock > Default web browser.

Note on step 3: routing links from other apps requires Browsify to be the default browser. Until macOS is told to deliver http/https links to it, no links reach the app. This is inherent to this category of utility (the same as long-approved apps such as Velja), which is why step 2 exists.

Other features reachable from the same UI: routing by URL pattern (github.com/work/*) or by source app; targeting a specific Chrome/Brave/Edge/Vivaldi/Firefox profile; sending Zoom/Teams/Slack links to those desktop apps instead of a browser; stripping utm_*/fbclid tracking parameters.

The optional "Grant Access…" buttons use a standard NSOpenPanel and security-scoped bookmarks to read browser profile names from each browser's own config files; the app functions fully without them (only profile targeting is unavailable). The app is sandboxed, makes no network requests, has no account or server, and stores all settings locally in user defaults.
