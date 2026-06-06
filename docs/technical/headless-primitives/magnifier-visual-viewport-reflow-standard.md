# Magnifier Visual Viewport And Reflow Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WCAG 1.4.4 Resize Text: https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
- WCAG 2.4.11 Focus Not Obscured: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- WCAG 2.5.5 Target Size: https://www.w3.org/WAI/WCAG22/Understanding/target-size.html
- MDN Visual Viewport API: https://developer.mozilla.org/en-US/docs/Web/API/Visual_Viewport_API
- MDN CSS `env()`: https://developer.mozilla.org/en-US/docs/Web/CSS/env
- MDN `overflow`: https://developer.mozilla.org/en-US/docs/Web/CSS/overflow
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility

## Problem

Screen magnifier and high zoom users see only a portion of the UI at a time.
Dense productivity surfaces fail when focus moves outside the magnified region,
sticky headers hide the focused item, panels require two-dimensional scrolling
without shortcuts, or text scaling breaks row geometry.

Headless needs a viewport and reflow contract that treats magnification as a
first-class accessibility environment.

## Decision Options

1. Depend only on responsive layout breakpoints - 🎯 4   🛡️ 4   🧠 2, about
   80-160 LOC. Helps small screens, but not magnifier focus movement.
2. Add a visual viewport and focus visibility policy - 🎯 9   🛡️ 9   🧠 6,
   about 350-850 LOC. Best fit for Headless primitives.
3. Build a full magnifier simulation framework - 🎯 5   🛡️ 8   🧠 9, about
   1600-3200 LOC. Useful for labs, too heavy for MVP primitives.

Accepted: option 2.

## Accepted Contract

Headless exposes a viewport facts object:

```dart
final class RVisualViewportFacts {
  final Size layoutViewportSize;
  final Rect? visualViewportRect;
  final EdgeInsets safeAreaInsets;
  final double textScaleFactor;
  final double devicePixelRatio;
  final bool isMagnified;
  final RViewportEvidence evidence;
}
```

Flutter native adapters may not know the exact external magnifier viewport. In
that case, they still publish text scale, safe areas, focus geometry, and
unknown magnifier evidence.

## Focus Visibility Rules

- When focus changes, the focused target must be scrolled into a visible and
  unobscured region.
- Sticky headers, footers, overlays, and side panels must register obstruction
  geometry.
- Focus rings cannot be clipped by row containers, cards, or viewport masks.
- Programmatic scroll must preserve user orientation by avoiding unnecessary
  jumps.
- Virtualized lists must resolve focus by stable semantic id, not current
  recycled child position.

## Reflow Rules

- Content supports compact, medium, and wide semantic layouts.
- Reflow may change panel placement, but must preserve command availability.
- Two-dimensional surfaces expose shortcuts to row, column, details, and command
  regions.
- Horizontal scrolling is allowed for data grids, but core commands and current
  focus cannot require hidden horizontal discovery.
- Text scaling can increase row height. Fixed-height rows are allowed only with
  clipping-free content policy and accessible full text alternative.

## Clean Disk Requirements

Clean Disk must support magnifier-safe operation for:

- folder tree navigation;
- selected row visibility;
- details panel access;
- bottom scan progress visibility;
- delete queue review;
- confirmation dialogs;
- treemap and chart summaries.

The compact reference layout is not only a mobile layout. It is also the escape
path for high zoom and narrow visual viewport use.

## Geometry Registry

Primitives publish obstruction and focus geometry:

```dart
final class RViewportGeometryRegistry {
  void registerObstruction(RSemanticId id, Rect rect, RObstructionKind kind);
  void registerFocusable(RSemanticId id, Rect rect);
  RFocusVisibilityResult check(RSemanticId id);
}
```

The registry is not a business data source. It is a runtime accessibility
mechanism.

## Testing Requirements

- Test at 200 percent browser zoom or equivalent viewport scaling.
- Test text scale 2.0 with compact layout.
- Test sticky footer plus focused row near bottom.
- Test modal dialog under small visual viewport.
- Test horizontal grid scroll with focus movement.
- Test safe-area inset changes.
- Test visual viewport resize during onscreen keyboard display where relevant.

## Failure Catalog

- Focus lands behind a sticky footer.
- A row is selected but its action menu is outside the magnified area.
- Text scale clips folder names or buttons.
- Horizontal scroll hides the focused cell with no visible cue.
- A modal centers itself in the layout viewport but not in the visual viewport.
- Virtualized row focus jumps after scrolling.
- Progress footer covers the last focused row.

## Release Gates

- Every overlay and sticky primitive must publish obstruction geometry.
- Every focusable primitive must support scroll-to-visible through stable id.
- Compact semantic layout must preserve command reachability.
- Visual viewport evidence must be visible in conformance reports.

## Summary

Magnifier support is a geometry and focus problem, not only a responsive design
problem. Headless must keep focus visible, commands reachable, and layouts
reflowable under high zoom.
