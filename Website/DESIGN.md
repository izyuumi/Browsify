# Browsify Website Design

## Intent

A modern native-Mac product page with one dominant product artifact. The physical scene is a Mac user moving between browser contexts at night: dark desktop, crisp system type, bright routing signals.

## Color

- Canvas: deep navy from the app icon (`#06142D`, `#102A66`, `#281445`).
- Text: near-white with cool blue-gray secondary text.
- Route A: cyan (`#73F7FF`, `#2CCBFF`, `#3380FF`).
- Route B: violet (`#8F7CFF`, `#A557F3`, `#EC4CC6`).
- Strategy: committed dark palette. Cyan and violet identify routing paths; they do not color ordinary body copy.

## Typography

Use the macOS system stack deliberately. Display text is large but restrained, no tighter than `-0.04em`. Body copy stays within 68 characters per line with generous line-height on the dark canvas.

## Composition

- Compact persistent identity in the header.
- Hero copy and icon establish the promise.
- A wide, real product screenshot is the dominant artifact.
- Feature explanation follows as editorial rows and a routing line, not repeated cards.
- Privacy becomes a contrasting proof band near the decision point.

## Components

- Wordmark: small app icon plus Browsify name.
- Primary action: solid near-white rounded button, dark text, clear arrow.
- Secondary action: quiet text link with visible underline on hover/focus.
- Product stage: screenshot with a restrained border and short shadow, never glass.
- Route strip: semantic list with connected nodes for source, rule, and destination.

## Motion

One soft icon drift and one product-stage entrance. Content remains visible without JavaScript. Disable transforms and animations under `prefers-reduced-motion: reduce`.

## Responsive Behavior

The hero collapses to one column below tablet width. Routing nodes stack vertically on narrow screens. All padding and type use fluid clamps; no horizontal overflow at 320px.
