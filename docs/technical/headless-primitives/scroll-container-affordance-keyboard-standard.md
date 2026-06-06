# Scroll Container Affordance Keyboard Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `overflow`: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/overflow
- MDN CSS Scroll Snap: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Scroll_Snap
- MDN Scroll Anchoring: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_scroll_anchoring
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.4.11 Focus Not Obscured Minimum: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- WAI-ARIA APG Landmarks Guidance: https://www.w3.org/WAI/ARIA/apg/practices/landmark-regions/

## Scope

This standard covers scroll containers, nested scroll regions, virtualized list
viewports, horizontal table scroll, sticky headers/footers, scrollbars,
scroll-to-focused-row behavior, scroll anchoring, and keyboard scroll access.

It extends viewport virtualization, sticky scroll anchoring, dense target,
focus visibility, and app shell landmark standards.

## Problem

Dense workbench apps often create many scroll containers: central grid, side
pane, details panel, footer log, menu popup, and dialog content. If Headless
does not define scroll ownership, keyboard and assistive technology users can
get stuck, focus can move offscreen, sticky elements can hide focused controls,
and virtualized rows can jump unpredictably.

## Decision Options

1. Explicit scroll container contract with focus and affordance policy -
   🎯 10   🛡️ 9   🧠 8, roughly 1000-2200 LOC.
   Best fit. It gives virtualized primitives predictable keyboard and screen
   reader behavior across renderers.
2. Leave scroll behavior entirely to renderer/framework defaults -
   🎯 5   🛡️ 5   🧠 2, roughly 100-300 LOC.
   Fast, but nested panes and virtualized grids will diverge by platform.
3. Avoid nested scroll regions -
   🎯 5   🛡️ 7   🧠 4, roughly 300-900 LOC.
   Good principle, but unrealistic for desktop workbench layouts.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- scroll region identity;
- scroll intent commands;
- focused item visibility policy;
- sticky obstruction facts;
- keyboard scroll behavior;
- nested scroll handoff rules;
- virtualized extent metadata;
- accessible name requirement for focusable regions.

Renderer owns:

- actual scrolling implementation;
- scrollbar visuals;
- physics;
- snap behavior;
- platform scrollbars;
- viewport measurements.

Application owns:

- layout composition;
- pane persistence;
- restored scroll position policy;
- route-level scroll behavior;
- product-specific sticky regions.

## Scroll Region Identity

Every interactive scroll region has:

- stable id;
- accessible name;
- role/profile;
- orientation;
- scroll extent facts;
- focusable policy;
- parent scroll region id;
- sticky obstruction facts;
- virtualization facts.

Rules:

- ordinary page scroll should remain default when possible;
- nested scroll regions must have a reason;
- focusable scroll regions need a useful accessible name;
- regions that are only implementation details should not add extra tab stops;
- virtualized regions expose logical extent separately from rendered children.

## Keyboard Rules

Rules:

- arrow keys belong to the focused widget first;
- page keys scroll the active widget when that widget owns paging;
- `Home` and `End` follow widget semantics before page semantics;
- `Space` should not unexpectedly scroll when it activates a focused control;
- keyboard users need a way to reach and scroll each important region;
- Escape from an overlay returns to the prior scroll context.

For TreeGrid, row focus movement may scroll the viewport, but scroll movement
alone must not change selection or cleanup queue state.

## Focus Visibility Rules

When focus changes:

- focused item is scrolled into view;
- sticky header/footer offsets are considered;
- focus ring is not clipped by row viewport;
- focused row remains stable during async item insertion;
- virtualized row mount does not steal focus;
- scroll restoration does not restore destructive authority.

## Scrollbar And Affordance Rules

Rules:

- do not hide essential scrollbars without another obvious affordance;
- horizontal scroll in tables must be discoverable;
- scroll shadows are supplemental, not the only affordance;
- drag-only scroll is not enough;
- wheel-only scroll is not enough;
- compact mode may reduce but not remove critical affordance.

## Clean Disk Usage

Scroll regions:

- main TreeTable viewport;
- target sidebar;
- details pane;
- cleanup queue;
- bottom status/log region;
- modal confirmation content;
- map visualization viewport.

Rules:

- central TreeTable owns primary keyboard navigation;
- bottom status footer cannot cover the focused final row;
- cleanup queue collapse does not lose focus into nowhere;
- path reveal tooltip does not become trapped inside clipped row cell;
- restore route scroll position only after session/snapshot compatibility is
  known.

## Community API Sketch

```dart
final class RScrollRegionState {
  const RScrollRegionState({
    required this.id,
    required this.axis,
    required this.focusPolicy,
    required this.stickyInsets,
    required this.virtualExtent,
  });

  final String id;
  final Axis axis;
  final RScrollFocusPolicy focusPolicy;
  final RScrollInsets stickyInsets;
  final RVirtualExtent? virtualExtent;
}
```

## Conformance Scenarios

- keyboard user can scroll each important region;
- focused row is not hidden behind sticky footer;
- horizontal table overflow is discoverable;
- nested scroll handoff does not trap wheel or keyboard input;
- virtualized row focus survives row recycle;
- scroll restoration waits for compatible data version;
- screen reader hears a useful region name for focusable scroll pane.

## Anti-Patterns

- `overflow: hidden` clipping focusable content;
- invisible scroll containers with no keyboard access;
- nested scroll panes with no ownership;
- scroll snap that prevents reading overflowed content;
- scroll position used as selected item truth;
- restoring scroll before data compatibility check;
- hiding scrollbars in dense productivity tables.

## Clean Architecture Note

Headless owns scroll semantics and commands. Renderer adapters own platform
scroll mechanics. Application state may remember scroll preferences, but scroll
position never becomes domain state or destructive-operation authority.

