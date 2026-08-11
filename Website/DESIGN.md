# Browsify Website Design

## Intent

A simple, tactile native-Mac product page with one dominant interactive routing playground. The physical scene is a bright Mac workspace where a clicked link visibly travels to the right context.

## Color

- Canvas: cool near-white with deep navy text.
- Product stage: deep navy from the app icon (`#06142D`, `#102A66`, `#281445`).
- Route A: cyan (`#73F7FF`, `#2CCBFF`, `#3380FF`).
- Route B: violet (`#8F7CFF`, `#A557F3`, `#EC4CC6`).
- Strategy: restrained light page with one committed dark product stage. Cyan and violet identify routing paths; they do not color ordinary body copy.

## Typography

Use the macOS system stack deliberately. Display text is large but restrained, no tighter than `-0.04em`. Body copy stays within 68 characters per line.

## Composition

- Compact sticky identity and App Store action in the header.
- Centered hero copy and icon establish the promise.
- A wide, interactive route playground is the dominant artifact.
- A real product screenshot and concise feature rows provide proof.
- A dark closing stage repeats the decision point.

## Components

- Wordmark: small app icon plus Browsify name.
- Primary action: solid near-white rounded button, dark text, clear arrow.
- Secondary action: quiet text link with visible underline on hover/focus.
- Product stage: interactive source-to-destination route with four real-world examples.
- Product screenshot: lightly rotated Mac window with a short shadow, never glass.

## Motion

One icon entrance, route particle motion, small hover responses, and pointer-following color inside the playground. Core content remains visible without JavaScript. Disable transforms and animations under `prefers-reduced-motion: reduce`.

## Responsive Behavior

The hero collapses to one column below tablet width. Routing nodes stack vertically on narrow screens. All padding and type use fluid clamps; no horizontal overflow at 320px.
