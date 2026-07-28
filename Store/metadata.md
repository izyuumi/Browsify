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
• Test your rules with a built-in test picker
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

IMPORTANT — setting Browsify as the default browser is required before it can do anything. Until macOS is told to deliver http/https links to Browsify, no links reach the app and it will appear to do nothing. This is inherent to this category of utility.

To test (about one minute):

1. Launch Browsify. A Welcome window appears and an icon is added to the menu bar. There is no Dock icon by design (LSUIElement) — the menu bar icon is the app's interface.
2. In the Welcome window click "Set as Default Browser" and confirm the macOS system prompt.
3. Click any http/https link in another app (Mail, Messages), or run `open https://www.apple.com` in Terminal. Browsify's picker panel appears at the cursor listing installed browsers; choose one and the link opens there. Number keys 1, 2, 3… also select.
4. For rule-based routing: open Settings from the menu bar icon, go to Rules, add a rule — match type "Domain", value "apple.com", target Safari. An apple.com link now opens in Safari immediately with no picker; other links still show the picker.
5. To restore the previous default: System Settings > Desktop & Dock > Default web browser.

Other features reachable from the same UI: routing by URL pattern (github.com/work/*) or by source app; targeting a specific Chrome/Brave/Edge/Vivaldi/Firefox profile; sending Zoom/Teams/Slack links to those desktop apps instead of a browser; stripping utm_*/fbclid tracking parameters.

The optional "Grant Access…" buttons use a standard NSOpenPanel and security-scoped bookmarks to read browser profile names from each browser's own config files; the app functions fully without them (only profile targeting is unavailable). The app is sandboxed, makes no network requests, has no account or server, and stores all settings locally in user defaults.
