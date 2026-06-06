# Headless Viewport Virtualization RFC

## Status

Accepted design direction. Not implemented yet.

## Problem

Large collection primitives need lazy viewport rendering without binding
Headless behavior contracts to one Flutter viewport package. Clean Disk can
show hundreds of thousands or millions of logical rows, but Flutter must only
build the visible window.

## Standards And References

- Flutter `TwoDimensionalScrollView`:
  https://api.flutter.dev/flutter/widgets/TwoDimensionalScrollView-class.html
- Flutter `two_dimensional_scrollables`:
  https://pub.dev/packages/two_dimensional_scrollables
- Flutter `TableView`:
  https://pub.dev/documentation/two_dimensional_scrollables/latest/two_dimensional_scrollables/TableView-class.html
- Flutter `TreeView`:
  https://pub.dev/documentation/two_dimensional_scrollables/latest/two_dimensional_scrollables/TreeView-class.html
- WAI-ARIA Grid and Table Properties:
  https://www.w3.org/WAI/ARIA/apg/practices/grid-and-table-properties/

## Accepted Direction

Create a viewport adapter boundary. Do not make `two_dimensional_scrollables`
the core behavior dependency.

```text
TreeGridViewportAdapter
  buildViewport(request)
  visibleRangeListenable
  scrollToRow(key/index)
  scrollToCell(rowKey, columnKey)
  supportsPinnedHeader
  supportsPinnedColumns
  supportsVariableRowHeight
```

## Top Options

1. Adapter boundary plus official Flutter viewport adapters - 🎯 9   🛡️ 8
   🧠 8, roughly 900-2200 LOC.

   Best balance. `ListView` adapter for simple/stable MVP, `TableView` adapter
   for real 2D virtualization.

2. Hard-code `TableView` into `RTreeGrid` - 🎯 7   🛡️ 6   🧠 6,
   roughly 700-1500 LOC.

   Faster, but hard to test, hard to replace, and couples behavior to layout.

3. Custom render object - 🎯 4   🛡️ 6   🧠 10,
   roughly 2500-6000 LOC.

   Only justified after proving official primitives cannot meet requirements.

Accepted: option 1.

## Adapter Requirements

- fixed row height first;
- bounded overscan;
- expose visible row/column range;
- support scroll-to-focused target;
- support semantics row/column indexes;
- do not rebuild all visible rows for hover/focus changes;
- stable row/cell keys;
- test adapter for deterministic widget tests;
- support offscreen focus by returning scroll intent.

## Clean Disk MVP

Clean Disk can start with:

```text
ListViewTreeGridViewportAdapter
  fixed row height
  row virtualization only
  inline columns
  sticky header outside list
```

This is acceptable only if the public contract already preserves a later
`TableViewTreeGridViewportAdapter`.

## TableView Stage

Use `TableView` when we need:

- bidirectional scrolling;
- pinned header;
- possible pinned tree column;
- column decorations;
- column resize;
- row/column cache extent;
- real cell virtualization.

## Accessibility Rules

Virtualization must not hide logical structure:

- total row count and column count should be available when known;
- visible rows/cells need indexes;
- stale or unknown counts must be represented as unknown, not fake totals;
- scroll-to-accessibility-focus must be reliable;
- tests must verify semantic facts for visible windows.

## Performance Rules

- no full-tree flattening for Clean Disk;
- no full collection sorting/filtering in Flutter for backend-owned data;
- row height should be stable in V1;
- avoid nested scrollables unless adapter owns the full scroll policy;
- avoid unbounded keep-alive;
- throttle visible range change events.

## Stop Rules

- Do not expose `TableView` types in product feature packages.
- Do not require all rows/cells in memory.
- Do not implement variable row height before fixed-height behavior passes.
- Do not hide viewport behavior inside renderers.
