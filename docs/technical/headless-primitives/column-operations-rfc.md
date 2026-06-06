# Headless Column Operations RFC

## Status

Future design direction. Do not implement before TreeGrid V1 passes.

## Problem

Large tables eventually need column resize, visibility, ordering, pinning,
sorting, and maybe grouping. Clean Disk needs at least stable widths, sort
state, and maybe user-visible column preferences. Community TreeGrid/DataGrid
needs a path to richer column operations without breaking V1.

## Standards And References

- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- WAI-ARIA Grid and Table Properties:
  https://www.w3.org/WAI/ARIA/apg/practices/grid-and-table-properties/
- MUI X Data Grid column features:
  https://mui.com/x/react-data-grid/column-dimensions/
- TanStack Table column sizing:
  https://tanstack.com/table/v8/docs/guide/column-sizing

## Accepted Direction

Column operations are grid foundation contracts first, renderer UI second.

```text
GridColumnState
  order
  widths
  visibility
  pinned
  sort
  resizeInteraction
```

Do not bake all column operations into TreeGrid V1.

## Top Options

1. V1 descriptors plus future column operation controllers - 🎯 8   🛡️ 8
   🧠 7, roughly 500-1000 LOC now, 900-1800 LOC later.

   Best staged approach. Preserves API extension points without pulling all
   complexity forward.

2. Full column operations in V1 - 🎯 5   🛡️ 7   🧠 9,
   roughly 1800-3500 LOC.

   Too much for MVP. Risk of unstable public API.

3. No column operation contracts - 🎯 4   🛡️ 5   🧠 3,
   roughly 100-300 LOC.

   Fast now, painful later.

Accepted: option 1.

## V1 Must Preserve

V1 column spec must include:

- stable column key;
- label;
- width policy;
- min/max width;
- sortable flag;
- resizable flag;
- visible flag;
- row-header flag;
- alignment;
- semantic sort state.

## Resize

Column resize behavior:

- resize handle is keyboard and pointer operable;
- handle has semantic label and value where applicable;
- resize emits intent;
- controlled column widths are not mutated internally;
- double-click auto-size is future only;
- min/max always enforced.

Keyboard possibilities:

- Enter starts resize mode;
- Arrow Left/Right changes width;
- Escape cancels;
- Enter commits;
- Home/End min/max optional.

## Pinning

Pinning is future:

```text
ColumnPin.none
ColumnPin.start
ColumnPin.end
```

Risk: pinned tree column plus horizontal scroll is complex. Do not promise
until `TableView` adapter proves it.

## Reorder

Reorder is future:

- drag/drop column headers;
- keyboard reorder;
- stable persisted order;
- hidden column conflict policy;
- pinned column constraints.

Do not implement for Clean Disk MVP.

## Clean Disk Usage

MVP:

- fixed columns: name, size, percent, items, modified;
- sort is backend query;
- column widths can be app preference later;
- no drag reorder in MVP.

## Conformance Tests

- sort semantics on header;
- hidden column skipped by focus;
- resized width respects min/max;
- controlled width does not mutate;
- resize keyboard mode if implemented;
- pinned columns do not break row/cell identity.

## Stop Rules

- Do not make column order localized labels.
- Do not sort large backend data in Flutter.
- Do not implement pinning before viewport adapter supports it.
- Do not persist column state without schema/version.
