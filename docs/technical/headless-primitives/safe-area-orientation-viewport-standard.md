# Safe Area Orientation And Viewport Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN CSS `env()`: https://developer.mozilla.org/en-US/docs/Web/CSS/env
- MDN Visual Viewport API: https://developer.mozilla.org/en-US/docs/Web/API/Visual_Viewport_API
- WCAG 1.3.4 Orientation: https://www.w3.org/WAI/WCAG22/Understanding/orientation.html
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- WCAG 2.4.11 Focus Not Obscured Minimum: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- Flutter adaptive and responsive design: https://docs.flutter.dev/ui/adaptive-responsive

## Scope

This standard defines how Headless primitives adapt to safe areas, viewport
changes, orientation, keyboard insets, window controls, split views, foldable
segments, and focus visibility.

It applies to:

- app shell;
- side panels;
- bottom progress bars;
- dialogs;
- popovers;
- toolbars;
- tables;
- virtualized lists;
- command palettes;
- cleanup confirmation flows.

It does not define final layout. It defines constraints that renderer and app
shell must respect.

## Decision Options

Option A: Use fixed padding and breakpoints - 🎯 4   🛡️ 4   🧠 2, about
100-300 LOC.

- Fast.
- Breaks with notches, window controls, virtual keyboard, zoom, and split
  views.

Option B: App shell handles all viewport adaptation - 🎯 6   🛡️ 6   🧠 4,
about 300-800 LOC.

- Reasonable for one app.
- Primitive overlays and popovers still need safe placement rules.

Option C: Headless viewport environment contract - 🎯 9   🛡️ 9   🧠 7,
about 900-1700 LOC.

- Accepted direction.
- App shell provides environment facts.
- Primitives resolve placement, focus visibility, and overflow through shared
  constraints.

## Accepted Direction

Headless must define a `ViewportEnvironment`.

It includes:

- logical viewport size;
- visual viewport size;
- safe area insets;
- keyboard insets;
- window control overlay insets;
- fold or segment information;
- orientation;
- text scale bucket;
- zoom bucket;
- scroll container facts;
- focus obscuration risks.

## Safe Area Rules

Interactive and required content must not be hidden behind:

- display cutouts;
- rounded screen corners;
- OS window controls;
- title bars;
- bottom home indicators;
- virtual keyboard;
- sticky app bars;
- sticky footers;
- overlays.

Renderer may use decorative background under unsafe areas, but commands and
text must remain reachable and readable.

## Orientation Rules

Components must not require a single orientation unless essential.

If layout is better in one orientation:

- provide alternative layout;
- preserve route and focus;
- avoid hiding required commands;
- avoid destructive confirmation overflow;
- keep keyboard access.

Clean Disk is desktop-first, but compact web or tablet modes still need
orientation-safe behavior.

## Visual Viewport Rules

Visual viewport can differ from layout viewport due to:

- browser zoom;
- virtual keyboard;
- pinch zoom;
- on-screen controls;
- split-screen windows.

Overlay placement must respond to visual viewport changes without losing focus
or trapping content off-screen.

## Focus Not Obscured Rules

Focused element must remain at least partially visible, and preferably fully
visible for critical controls.

Rules:

- sticky footer must not cover focused row action;
- modal action buttons must not be under virtual keyboard;
- scroll-to-focus must respect safe area and sticky regions;
- focus ring must not be clipped by viewport padding;
- popover must reposition or fall back to dialog.

## Segment And Split View Rules

For multi-segment viewports:

- do not place a single interactive control across hinge or segment gap;
- dialogs should choose one segment or full safe layout;
- tree table may use one segment and details another only when focus order
  remains logical;
- export or destructive confirmation should avoid split controls.

## Clean Disk Requirements

Clean Disk must validate:

- wide desktop with window chrome;
- compact narrow window;
- bottom progress footer;
- right details panel;
- dialog confirmation;
- virtual keyboard for search on web/mobile shell;
- high zoom;
- safe focus for delete queue actions.

Rule:

- cleanup confirmation must never be partly hidden by safe area or keyboard.

## API Shape Sketch

```text
ViewportEnvironment
  layoutSize
  visualSize
  safeInsets
  keyboardInsets
  windowControlInsets
  segments
  orientation
  zoomBucket
  textScaleBucket

PlacementConstraint
  avoidInsets
  keepFocusVisible
  fallbackSurface
```

## Conformance Scenarios

- bottom progress bar does not cover focused table row;
- dialog action buttons remain visible with virtual keyboard;
- popover falls back when no safe placement exists;
- route focus restore accounts for sticky header;
- compact layout does not require landscape;
- foldable segment does not split one destructive button;
- visual viewport resize keeps command palette visible;
- safe area padding does not create unreachable dead space.

## Failure Catalog

- fixed bottom bar hiding focused content;
- dialog button under virtual keyboard;
- popover placed off-screen;
- focus ring clipped by safe-area container;
- app requires landscape for ordinary task;
- destructive controls split across viewport segments;
- layout viewport used when visual viewport changed;
- safe area used only for page shell but not overlays;
- high zoom creates unreachable confirmation footer;
- scroll-to-focus ignores sticky header.

