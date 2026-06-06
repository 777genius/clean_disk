# Spatial Navigation And D-pad Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- CSS Spatial Navigation Level 1: https://www.w3.org/TR/css-nav-1/
- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
- WCAG 2.4.11 Focus Not Obscured: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- WCAG 2.5.5 Target Size: https://www.w3.org/WAI/WCAG22/Understanding/target-size.html

## Problem

Some environments use directional input: TV remotes, D-pads, kiosks, game
controllers, desktop accessibility tools, and keyboard arrows in spatial mode.
Normal tab order is linear. Spatial navigation is two-dimensional and depends on
geometry, focus grouping, scroll containers, and visible obstruction.

Headless needs a spatial focus model that does not fight the ordinary keyboard
model.

## Decision Options

1. Reuse tab order for D-pad - 🎯 4   🛡️ 4   🧠 2, about 40-120 LOC. Simple,
   but terrible for grid-like layouts.
2. Add spatial navigation graph as optional focus projection - 🎯 9   🛡️ 9
   🧠 7, about 500-1100 LOC. Best fit for Headless.
3. Depend on browser CSS Spatial Navigation only - 🎯 4   🛡️ 5   🧠 3, about
   80-180 LOC. Too immature and web-only for a Flutter-first kit.

Accepted: option 2.

## Accepted Contract

Headless exposes spatial candidates:

```dart
final class RSpatialNavigationNode {
  final RSemanticId id;
  final Rect bounds;
  final bool focusable;
  final bool disabled;
  final RSpatialGroupId groupId;
  final RSpatialPriority priority;
  final Set<RSpatialDirection> allowedDirections;
}
```

The component owns behavior. The renderer provides current geometry.

## Rules

- Spatial navigation is optional and capability-gated.
- Linear tab order remains valid.
- Directional movement prefers candidates inside the current logical group.
- Disabled and hidden nodes are excluded.
- Obscured nodes are excluded unless the target can be scrolled into view.
- Focus does not jump from a dialog to background content.
- A spatial move that scrolls must keep the focused item visible afterward.
- Destructive actions are not auto-selected as default directional targets.

## Clean Disk Requirements

Clean Disk desktop MVP does not need D-pad mode, but the central TreeGrid should
not make it impossible:

- row movement maps naturally to up/down;
- details and queue panels are separate spatial groups;
- bottom progress footer is not accidentally selected during row movement;
- modal confirmation traps spatial focus;
- compact layout has predictable left/right movement.

## Geometry Model

```text
primary axis:
  requested direction from focused node

beam:
  projected overlap area in requested direction

distance:
  weighted major and minor axis distance

group boundary:
  logical container that should be searched before outer regions
```

Implementations may tune the algorithm, but they must publish deterministic
candidate selection for tests.

## Testing Requirements

- D-pad traversal snapshot for wide and compact layouts.
- Modal overlay blocks background directional movement.
- Virtualized TreeGrid scrolls and keeps focus stable.
- Sticky footer does not obscure focused row.
- Disabled and hidden nodes are skipped.
- Directional movement is deterministic under equal-distance candidates.

## Failure Catalog

- Down from a row jumps to the footer instead of next row.
- Right from a selected row activates Move to Trash.
- D-pad mode traps focus inside a scroll container.
- Virtualized row geometry points to a recycled item.
- Spatial order differs between frames because layout animation is running.
- Browser spatial navigation and Headless spatial navigation both run.

## Release Gates

- Spatial mode is disabled unless adapter declares support.
- Focus graph snapshot exists for each supported complex primitive.
- D-pad support never replaces standard keyboard support.
- Geometry provider is tested under high zoom and text scaling.

## Summary

Spatial navigation is a separate focus projection. Headless should support it as
an optional deterministic graph while preserving normal keyboard behavior.
