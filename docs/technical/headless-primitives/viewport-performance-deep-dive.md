# Viewport Performance Deep Dive

## Status

Implementation-ready design constraints. Not implemented yet.

## Primary Standards And APIs

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

## Core Decision

Viewport is an adapter. Behavior is not the viewport.

```text
TreeGrid behavior
  focus, selection, expansion, commands, semantics

Viewport adapter
  visible range, lazy building, scrolling, pinned header/columns
```

## Adapter API

```text
ViewportAdapter
  build(context, request)
  visibleRange: ValueListenable<ViewportRange>
  scrollToRow(rowKey | rowIndex, alignment)
  scrollToCell(rowKey, columnKey, alignment)
  estimateVisibleRows()
  supports(feature)
```

Features:

```text
pinnedHeader
pinnedStartColumns
cellVirtualization
rowVirtualization
fixedRowExtent
variableRowExtent
programmaticScrollToKey
semanticIndexes
```

## Rendering Budget

Clean Disk target:

- 50k synthetic visible-row dataset without UI jank;
- only visible rows plus bounded overscan built;
- progress footer updates do not rebuild table rows;
- hover changes rebuild one row, not entire viewport;
- selection changes rebuild affected rows only;
- sort/filter/search does not run full-tree work in Flutter.

## Overscan Policy

```text
OverscanPolicy
  rowsBefore
  rowsAfter
  columnsBefore
  columnsAfter
  maxBuiltCells
```

Default:

- rows: viewport + small constant overscan;
- columns: at least one column ahead for keyboard movement;
- max built cells fails closed in debug if exceeded.

## Fixed Row Height First

V1 invariant:

```text
rowExtent: fixed
```

Why:

- scroll-to-index is reliable;
- virtualization math is cheap;
- semantics row indexes remain stable;
- table density is predictable;
- Clean Disk rows are scan results, not rich documents.

Variable row height is future only.

## Visible Range Contract

```text
ViewportRange
  firstVisibleRow
  lastVisibleRow
  firstBuiltRow
  lastBuiltRow
  firstVisibleColumn
  lastVisibleColumn
  firstBuiltColumn
  lastBuiltColumn
  revision
```

Visible range events must be throttled or coalesced. They are UI observations,
not authoritative backend queries.

## Scroll-To-Key

Virtualized data may not know the current index of a key.

```text
ScrollTarget
  byVisibleIndex(index)
  byKey(key)
  byBackendCursor(cursor)
```

If key index is unknown, component emits:

```text
ResolveScrollTargetRequested(key)
```

Clean Disk can ask Rust indexes for the row position under current sort/filter.

## Test Viewport Adapter

Conformance tests need deterministic viewport:

```text
TestViewportAdapter
  setVisibleRows(start, end)
  setVisibleColumns(start, end)
  captureScrollRequests()
  captureBuiltKeys()
```

Do not disable virtualization by changing production behavior. Inject a test
adapter.

## Flutter Implementation Notes

Option 1 - `ListView` adapter:

- fastest MVP;
- row virtualization only;
- inline columns;
- sticky header outside list;
- good for rows-first Clean Disk.

Option 2 - `TableView` adapter:

- real cell virtualization;
- pinned header;
- column scrolling;
- possible pinned columns;
- more complex semantics and focus mapping.

Option 3 - custom render object:

- only if official primitives fail benchmarks.

## Semantic Indexing

For virtualized grids:

- expose total counts when known;
- expose indexes for visible rows/cells;
- unknown totals stay unknown;
- row count must be backend count, not built row count;
- hidden columns affect semantic column indexes.

## Failure Modes

- focus target is unloaded;
- row key resolves to a different index after sort;
- viewport emits too many range changes;
- KeepAlive grows unbounded;
- column resize triggers relayout of too many cells;
- progress/status rebuilds table root;
- semantics tree becomes too large on web.

## Stop Rules

- Do not require all rows/cells in memory.
- Do not expose `TableView` to Clean Disk feature packages.
- Do not make renderer own viewport state.
- Do not implement variable row height in V1.
- Do not let progress events rebuild the viewport.
