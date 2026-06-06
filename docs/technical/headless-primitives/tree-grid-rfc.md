# Headless TreeGrid RFC

## Status

Accepted design direction. Not implemented yet.

## Problem

TreeGrid is the central primitive for Clean Disk's folder/file table and a
major community-grade component for Headless. It combines tree hierarchy, grid
columns, large virtualization, selection, focus, sorting, context actions, and
accessibility.

## Standards And References

- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN `treegrid` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/treegrid_role
- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- MUI X Data Grid accessibility:
  https://mui.com/x/react-data-grid/accessibility/
- AG Grid accessibility:
  https://www.ag-grid.com/react-data-grid/accessibility/

## Accepted Direction

`RTreeGrid` composes:

- collection foundation;
- tree foundation;
- grid foundation;
- viewport adapter;
- renderer contracts.

It does not own product data, backend fetching, delete behavior, or app
workflow.

```text
components/headless_tree_grid
  lib/
    src/
      domain/
        tree_grid_ids.dart
        tree_grid_state.dart
        tree_grid_events.dart
        tree_grid_commands.dart
      presentation/
        r_tree_grid.dart
        r_tree_grid_controller.dart
        tree_grid_reducer.dart
        tree_grid_effects.dart
        tree_grid_semantics.dart
        tree_grid_render_request_composer.dart
      infra/
        viewport_adapters/
```

## Top Options

1. Compose foundation layers - 🎯 9   🛡️ 9   🧠 9,
   roughly 1200-2500 LOC after foundation.

   Best public primitive. Keeps behavior reusable and renderer-independent.

2. One component with all behavior - 🎯 6   🛡️ 6   🧠 7,
   roughly 1800-3500 LOC.

   Faster to start, but becomes hard to split later.

3. App-only Clean Disk table - 🎯 3   🛡️ 4   🧠 4,
   roughly 700-1400 LOC.

   Only acceptable as a throwaway prototype.

Accepted: option 1.

## Public API Shape

```dart
RTreeGrid<TNode, TColumn>(
  controller: controller,
  columns: columns,
  rows: rows,
  rowKeyOf: rowKeyOf,
  columnKeyOf: columnKeyOf,
  focusMode: TreeGridFocusMode.rowsFirst,
  selectionMode: TreeGridSelectionMode.multiple,
  tabPolicy: TreeGridTabPolicy.composite,
  viewportAdapter: adapter,
  slots: slots,
)
```

`rows` may be eager rows or app-owned visible page rows. The component should
not directly call Clean Disk daemon APIs.

## Keyboard Model

Support from V1:

- rows-first mode;
- cells-first mode reserved by public API;
- Tab enters/leaves the composite;
- arrow keys move inside;
- Home/End/Page Up/Page Down work by policy;
- Left/Right expand/collapse or move between cells depending on focus mode;
- Space toggles selection when selection is enabled;
- Enter activates row or cell default action;
- Shift + arrows extend selection where enabled;
- context menu shortcut opens menu through command event.

Clean Disk default: rows-first composite mode.

## Accessibility Model

Expose semantic intents:

- role treegrid;
- row/cell/header roles;
- row count and column count when known;
- row index and column index for visible items;
- level/depth;
- expanded/collapsed only for expandable rows;
- selected, selectable, disabled;
- readonly when cells are not editable;
- sorted state on headers;
- context menu availability;
- loading/error row state.

Important: rows that cannot expand must not expose expanded/collapsed state.

## Renderer Contracts

Minimum contracts:

```text
RTreeGridRenderer
RTreeGridHeaderRenderer
RTreeGridRowRenderer
RTreeGridCellRenderer
RTreeGridDisclosureRenderer
RTreeGridSelectionRenderer
RTreeGridTokenResolver
```

Renderer receives command objects:

- `toggleExpansion`;
- `focusRow`;
- `focusCell`;
- `toggleSelection`;
- `activate`;
- `openContextMenu`;
- `sortColumn`.

Renderer must not call product callbacks directly.

## Clean Disk Usage

Clean Disk maps daemon pages into row view models:

```text
ScanTreeTable
  -> AppTreeGrid
    -> RTreeGrid
```

Rust owns:

- scan tree;
- sorting;
- filtering;
- search;
- pagination;
- authoritative node metadata.

Flutter owns:

- visible pages;
- selected row;
- display density;
- cleanup queue UI intent;
- command dispatch to use cases.

Headless owns:

- focus;
- keyboard behavior;
- expansion intent;
- selection interaction;
- semantic structure;
- render request shape.

## Conformance Tests

- rows-first keyboard model;
- focus and selection split;
- multi-select;
- expansion/collapse;
- non-expandable rows do not expose expandable semantics;
- sorted header semantics;
- disabled row behavior;
- virtualized visible range semantics;
- controlled controller state;
- missing renderer diagnostic;
- Material renderer conformance.

## Stop Rules

- Do not expose disk/file concepts.
- Do not pass the full Clean Disk scan tree into Flutter.
- Do not implement cleanup/delete inside Headless.
- Do not couple public behavior API to `TableView`.
- Do not let renderer own root focus or activation.
