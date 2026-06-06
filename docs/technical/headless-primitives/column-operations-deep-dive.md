# Column Operations Deep Dive

## Status

Future implementation constraints. Preserve extension points in V1.

## Primary Standards

- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA Grid and Table Properties:
  https://www.w3.org/WAI/ARIA/apg/practices/grid-and-table-properties/
- MDN `aria-sort`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-sort
- TanStack Table column sizing:
  https://tanstack.com/table/v8/docs/guide/column-sizing
- MUI X column dimensions:
  https://mui.com/x/react-data-grid/column-dimensions/

## Core Decision

Column operations are grid state, not renderer-only behavior.

## Column State

```text
ColumnState
  order: List<ColumnKey>
  widths: Map<ColumnKey, ColumnWidth>
  visibility: Map<ColumnKey, bool>
  pinning: Map<ColumnKey, PinState>
  sort: List<SortDescriptor>
  resizeInteraction: ResizeState
```

## V1 Required Fields

```text
ColumnSpec
  key
  label
  minWidth
  maxWidth
  defaultWidth
  flex
  sortable
  resizable
  hideable
  align
  rowHeader
```

Even if resizing/pinning are future, these fields preserve API direction.

## Sort

Sort descriptor:

```text
SortDescriptor
  columnKey
  direction
  priority
  nulls
```

Clean Disk sends sort intent to Rust. Headless does not sort backend-owned data.

Semantic rule:

- sorted fact belongs on header cell;
- only active sorted columns expose sort state;
- multi-sort must expose priority in description or value text where possible.

## Resize State Machine

```text
idle
  -> pointerDragging
  -> keyboardResizing
  -> committing
  -> idle
  -> cancelled
```

Keyboard:

- Enter starts resize mode on focused header/handle;
- Arrow Left/Right changes width;
- Shift modifies larger step;
- Escape cancels;
- Enter commits.

Resize emits intent. Controlled column width comes from parent.

## Visibility

Hidden columns:

- are removed from focus order;
- are removed from semantic column count or represented through indexes
  according to adapter policy;
- cannot receive sort/resizer focus;
- persisted state must be versioned.

## Pinning

Pinning is future:

```text
PinState.none
PinState.start
PinState.end
```

Risk:

- pinned tree column plus horizontal scroll complicates focus, semantics, and
  virtualization. Do not promise before `TableView` adapter proves it.

## Reorder

Reorder is future:

- pointer drag;
- keyboard reorder;
- pinned constraints;
- hidden column constraints;
- persisted versioned order.

V1 should not include reorder.

## Clean Disk Policy

MVP:

- columns fixed by product;
- sort backend-owned;
- widths app-owned later;
- no reorder/pinning.

## Conformance Tests

- sort intent emitted;
- sort semantic fact on header;
- hidden column skipped by focus;
- resize clamps min/max;
- keyboard resize works if enabled;
- controlled width not mutated internally;
- persisted state rejects unknown column keys safely.

## Stop Rules

- Do not sort large backend data in Flutter.
- Do not persist column state without schema version.
- Do not implement pinning before viewport adapter supports it.
- Do not identify columns by localized labels.
