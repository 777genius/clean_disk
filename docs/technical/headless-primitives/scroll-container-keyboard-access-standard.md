# Scroll Container Keyboard Access Standard

## Status

Implementation standard for scroll containers, sticky regions, overflow areas,
and keyboard access in virtualized primitives.

## Purpose

Dense tools rely on scrollable panes, virtualized grids, sticky headers,
pinned columns, details panels, and bottom status bars. These layouts often
hide focus, trap keyboard users, or create inaccessible horizontal overflow.
Headless and design-system wrappers need explicit scroll contracts.

## Standards And References

- WCAG 2.2:
  https://www.w3.org/TR/wcag-22/
- WCAG 2.2 Focus Not Obscured:
  https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- Flutter scrolling:
  https://docs.flutter.dev/ui/layout/scrolling
- Flutter performance profiling:
  https://docs.flutter.dev/perf/ui-performance

## Core Rule

Every scrollable region that contains interactive content must be reachable,
operable, and escapable by keyboard.

```text
scroll position
  != focus
  != active row
  != selection
```

## Scroll Region Facts

Every scroll adapter declares:

- axis;
- viewport size;
- content extent if known;
- visible range;
- sticky regions;
- pinned regions;
- scroll controllers;
- keyboard scroll commands;
- focus-obscuring overlays;
- restoration key.

## Keyboard Access

Required commands:

- move focus into region;
- move focus out of region;
- page up/down where appropriate;
- scroll horizontally where required;
- scroll to active item;
- restore focus after scroll.

Do not require pointer wheel/trackpad to access hidden interactive content.

## Focus Visibility

When focus moves:

- focused item must be at least partially visible;
- sticky header/footer must not fully obscure it;
- scroll-to-focused should use safe padding;
- focus ring must not be clipped;
- pinned column duplicate must not show two focus rings.

## Horizontal Overflow

Horizontal scrolling is allowed for data grids, but:

- horizontal scroll must have keyboard path;
- hidden columns must have details/export path;
- column headers remain associated with cells;
- screen reader path must not depend only on visual horizontal movement;
- compact layout can move low-priority columns into details panel.

## Virtualized Scroll

Virtualized scroll must:

- not require all rows mounted;
- keep logical active key;
- maintain semantic visible range;
- cancel stale scroll-to-key operations;
- report target unavailable if row/column missing;
- coalesce scroll events.

## Sticky And Pinned Regions

Sticky/pinned renderers must:

- avoid duplicate semantics;
- keep focus order logical;
- not intercept unrelated pointer events;
- not obscure focused content;
- not trap screen reader in duplicated header clone.

## Clean Disk Layout

Wide:

- left sidebar;
- central TreeGrid;
- right details;
- bottom progress.

Compact:

- central TreeGrid;
- details below;
- sticky bottom progress.

Both layouts must keep TreeGrid focus, bottom progress, and details actions
reachable without pointer-only interaction.

## Required Tests

Automated:

- keyboard enters and exits scroll region;
- scroll-to-focused avoids sticky obstruction;
- pinned clone has no duplicate semantics;
- horizontal hidden cell reachable by keyboard or details path;
- scroll event coalescing;
- viewport rebuild bounded.

Manual:

- keyboard-only scan table navigation;
- high text scale with sticky footer;
- screen reader virtualized row path;
- touchpad and keyboard scroll parity.

## Stop Rules

- Do not make scroll wheel the only access path.
- Do not let sticky footer hide focused row.
- Do not duplicate pinned cells in semantics.
- Do not treat scroll offset as selection.
- Do not restore stale scroll position as destructive authority.
