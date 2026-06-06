# Touch Screen Reader Exploration Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
- WCAG 2.5.1 Pointer Gestures: https://www.w3.org/WAI/WCAG22/Understanding/pointer-gestures.html
- WCAG 2.5.2 Pointer Cancellation: https://www.w3.org/WAI/WCAG22/Understanding/pointer-cancellation.html
- WCAG 2.5.5 Target Size: https://www.w3.org/WAI/WCAG22/Understanding/target-size.html
- Apple VoiceOver for iPhone: https://support.apple.com/guide/iphone/turn-on-and-practice-voiceover-iph3e2e415f/ios
- Android TalkBack: https://support.google.com/accessibility/android/answer/6283677

## Problem

Touch screen-reader users explore by touch, swipe through semantic targets, and
activate with screen-reader gestures. A UI that works with mouse, keyboard, and
desktop screen readers can still fail on touch if hit regions are tiny,
overlapping, visually detached from semantics, or if custom gestures conflict
with assistive gestures.

Headless needs a touch exploration contract for Flutter mobile, tablets, and
touch-enabled desktop or web surfaces.

## Decision Options

1. Treat touch screen readers as pointer plus semantics - 🎯 4   🛡️ 4   🧠 2,
   about 0-100 LOC. Misses gesture conflict and semantic hit testing.
2. Add semantic hit target and exploration order policy - 🎯 9   🛡️ 9
   🧠 6, about 350-850 LOC. Best balance for Headless.
3. Build separate mobile-only components - 🎯 3   🛡️ 5   🧠 9, about
   1800-3500 LOC. Fragments public API and duplicates behavior.

Accepted: option 2.

## Accepted Contract

Every touch-capable primitive exposes semantic hit facts:

```dart
final class RTouchExplorationTarget {
  final RSemanticId id;
  final Rect semanticBounds;
  final Rect visualBounds;
  final String label;
  final bool isActionable;
  final bool isScrollable;
  final bool hasCustomGesture;
  final RTouchTargetRisk risk;
}
```

The target list is used for conformance tests and debug overlays.

## Touch Exploration Rules

- Semantic bounds match or intentionally contain the visual affordance.
- Adjacent targets maintain enough spacing for the active target profile.
- Invisible hit regions are allowed only when they expand a visible target.
- Custom gestures have non-gesture alternatives.
- A screen-reader double tap activates the same command as normal activation.
- Drag, pan, resize, and reorder all have discrete alternatives.
- Scrollable regions expose scroll semantics and do not trap exploration.
- Overlays block background exploration while modal.

## Clean Disk Requirements

Clean Disk is desktop-first, but compact and future tablet modes must support:

- touch exploration of top controls;
- folder row exploration with row summary;
- row action menu activation;
- details panel exploration;
- cleanup queue review;
- confirmation dialog activation;
- progress footer status.

The TreeGrid must not rely on tiny inline icons as the only touch targets in
compact mode.

## Gesture Conflict Rules

Headless components must avoid requiring:

- multi-finger gestures for core actions;
- drag-only cleanup queue movement;
- long press as the only menu access;
- hover preview;
- precise slider drag without step controls;
- swipe gestures that conflict with screen-reader navigation.

When a custom gesture exists, command metadata documents the equivalent action.

## Testing Requirements

- Run semantic hit target snapshot tests at compact widths.
- Verify semantic bounds overlap visible affordances.
- Verify no modal leaks background targets.
- Verify action menus can open without long press.
- Verify swipe order matches meaningful reading order.
- Verify large text and high zoom do not overlap hit targets.

## Failure Catalog

- A visible icon button has a 12 px semantic target.
- A row action is available only through swipe gesture.
- Screen-reader focus lands on a decorative progress bar segment.
- Modal confirmation still exposes background rows.
- Semantics bounds remain where a virtualized row used to be.
- Touch target label does not include row context.

## Release Gates

- Touch-capable primitives export semantic hit target facts.
- Compact layouts must pass target-size and overlap checks.
- Custom gestures require documented command alternatives.
- Touch exploration fixtures run for TreeGrid, menus, dialogs, sliders, and
  side panels.

## Summary

Touch screen-reader support is about semantic hit testing, gesture alternatives,
and meaningful exploration order. Headless must make these facts testable before
visual renderers specialize them.
