# Virtual Keyboard Input Viewport Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN VirtualKeyboard API: https://developer.mozilla.org/en-US/docs/Web/API/VirtualKeyboard_API
- MDN Visual Viewport API: https://developer.mozilla.org/en-US/docs/Web/API/Visual_Viewport_API
- MDN viewport concepts: https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/CSSOM_view/Viewport_concepts
- MDN CSS `env()`: https://developer.mozilla.org/en-US/docs/Web/CSS/env
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
- WCAG 2.4.11 Focus Not Obscured: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- Safe area orientation and viewport standard: safe-area-orientation-viewport-standard.md

## Problem

Onscreen keyboards can shrink the visual viewport, overlay content, move the
visual viewport without changing layout viewport, and hide focused fields,
dialogs, command bars, or bottom sheets. Browser behavior differs by platform,
PWA mode, and viewport configuration.

Headless needs a focused virtual-keyboard contract for input surfaces.

## Decision Options

1. Rely on platform default keyboard behavior - 🎯 5   🛡️ 5   🧠 2, about
   0-80 LOC. Works for simple pages, weak for dense app shells.
2. Add virtual keyboard viewport adapter - 🎯 9   🛡️ 9   🧠 6, about 350-850
   LOC. Best fit.
3. Force custom keyboard-aware layout system - 🎯 4   🛡️ 6   🧠 9, about
   1600-3500 LOC. Too heavy and brittle.

Accepted: option 2.

## Accepted Contract

Headless exposes keyboard viewport facts:

```dart
final class RVirtualKeyboardViewportState {
  final bool keyboardVisible;
  final Rect? keyboardBounds;
  final EdgeInsets keyboardInsets;
  final Rect visualViewportRect;
  final bool overlaysContent;
  final RKeyboardViewportEvidence evidence;
}
```

The adapter normalizes VirtualKeyboard API, VisualViewport API, Flutter
insets, and native platform facts where available.

## Rules

- Focused text input must not be fully obscured.
- Dialog primary actions remain reachable when keyboard is visible.
- Bottom sheets and sticky footers account for keyboard insets.
- Scroll-to-focused-field uses stable semantic id.
- Keyboard appearance does not trigger destructive commands.
- Layout changes preserve text selection and composition state.
- Unknown keyboard bounds degrade to safe scroll padding.
- Product search bars do not cover TreeGrid results with no escape.

## Clean Disk Requirements

Clean Disk needs this for:

- search field;
- filter input;
- custom path field;
- pairing token entry;
- support bundle note field;
- command palette.

Compact layout must keep scan progress and input recovery accessible when the
keyboard is open.

## Adapter Evidence

```text
virtualKeyboardApi:
  explicit keyboard geometry available

visualViewport:
  viewport shrink or offset observed

flutterInsets:
  platform view inset observed

heuristic:
  inferred from focus and viewport change

unknown:
  no trustworthy keyboard geometry
```

Heuristic evidence must not be used for precise destructive UI placement.

## Testing Requirements

- Focused input remains visible with keyboard open.
- Dialog action buttons are reachable.
- Search field retains composition state across viewport resize.
- Compact layout does not overlap bottom footer and keyboard.
- Unknown keyboard geometry still adds safe scroll padding.
- VirtualKeyboard API unavailable path is covered.

## Failure Catalog

- Pairing token field is hidden behind keyboard.
- Move to Trash button is pushed under keyboard.
- Viewport resize cancels IME composition.
- Search suggestions remain below visible viewport.
- Keyboard opens and scroll position jumps to wrong TreeGrid row.
- PWA standalone mode behaves differently with no test coverage.

## Release Gates

- Text-input primitives consume keyboard viewport state.
- Modal and bottom-sheet primitives register keyboard obstruction.
- Compact layout keyboard tests pass before mobile or tablet claims.
- Clean Disk destructive dialogs are never hidden by keyboard.

## Summary

Virtual keyboards are viewport obstructions. Headless should normalize keyboard
geometry and protect focus, actions, composition, and compact layouts.
