# Headless Grid Foundation RFC

## Status

Accepted design direction. Not implemented yet.

## Problem

TreeGrid and DataGrid need 2D focus, header focus, cell coordinates, column
state, sort descriptors, and composite keyboard rules. These must be reusable
foundation mechanics, not hardcoded inside a single `RTreeGrid` widget.

## Standards And References

- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- MDN ARIA grid role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/grid_role
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Accepted Direction

Create a grid foundation in `headless_foundation`:

```text
headless_foundation/lib/src/grid/
  grid_axis.dart
  grid_cell_key.dart
  grid_column_key.dart
  grid_column_spec.dart
  grid_focus_model.dart
  grid_focus_controller.dart
  grid_keyboard_policy.dart
  grid_sort_descriptor.dart
  grid_tab_policy.dart
  grid_navigation.dart
  grid_state.dart
```

This layer is not a widget. It models 2D movement and grid state.

## Top Options

1. Dedicated grid foundation - 🎯 9   🛡️ 8   🧠 8,
   roughly 800-1600 LOC.

   Best for community reuse. Supports `RDataGrid`, `RTreeGrid`, date pickers,
   layout grids, spreadsheet-like tools, and large command surfaces.

2. Put 2D focus only into `RTreeGrid` - 🎯 6   🛡️ 6   🧠 6,
   roughly 500-1000 LOC.

   Faster, but blocks a clean future `RDataGrid` and repeats APG grid work.

3. Let Flutter Focus traversal handle everything - 🎯 4   🛡️ 5   🧠 4,
   roughly 200-500 LOC.

   Too weak. Flutter focus traversal does not know app grid semantics, row
   counts, virtualized indexes, selection scopes, or APG key rules.

Accepted: option 1.

## Core Concepts

```text
GridColumnKey
GridRowKey
GridCellKey(rowKey, columnKey)

GridColumnSpec
  key
  label
  width
  minWidth
  maxWidth
  sortable
  resizable
  pinned
  hidden
  alignment
  isRowHeader

GridFocusTarget
  row(rowKey)
  cell(rowKey, columnKey)
  header(columnKey)
```

## Keyboard Policies

The foundation must support:

```text
GridFocusMode.rowsFirst
GridFocusMode.cellsFirst
GridFocusMode.cellsOnly

GridTabPolicy.composite
GridTabPolicy.content
GridTabPolicy.header
GridTabPolicy.all
```

APG distinguishes page tab sequence from navigation inside composite widgets.
The default for large grids should be one composite tab stop, with arrow keys
moving inside.

## Navigation Commands

Required commands:

- move left/right/up/down;
- move page up/down;
- move row start/end;
- move grid start/end;
- focus header;
- return from in-cell content to grid navigation;
- select row/cell/column if selection policy allows;
- sort focused header;
- open header menu;
- open cell context menu.

## Cell Content Mode

APG warns that arrow keys cannot both move grid focus and operate an in-cell
control at the same time.

Model this explicitly:

```text
GridInteractionMode.navigation
GridInteractionMode.cellContent
GridInteractionMode.editing
```

Clean Disk default: `navigation`. Enter activates row/details. Context actions
stay in row actions/menu, not in-cell text editing.

## Sort Contract

Sort belongs to column headers:

```text
GridSortDescriptor(columnKey, direction, priority)
GridSortDirection.none
GridSortDirection.ascending
GridSortDirection.descending
```

The foundation emits sort intent. It does not sort product data unless an eager
collection adapter explicitly asks it to.

Clean Disk sends sort to Rust.

## Semantics Intent

Expose facts, not ARIA attributes:

```text
GridSemanticFact.rowCount
GridSemanticFact.columnCount
GridSemanticFact.rowIndex
GridSemanticFact.columnIndex
GridSemanticFact.sorted
GridSemanticFact.readonly
GridSemanticFact.selected
GridSemanticFact.disabled
GridSemanticFact.focused
```

Flutter and web adapters translate these to platform semantics.

## Conformance Tests

- one tab stop enters composite mode by default;
- arrow keys move inside grid;
- Home/End and Ctrl/Cmd Home/End behave by policy;
- focus and selection are independent;
- hidden columns are skipped;
- disabled cells follow configured policy;
- header focus and sort intent work;
- in-cell mode captures arrow keys until exit;
- virtualized offscreen target returns scroll intent instead of failing.

## Stop Rules

- Do not render cells here.
- Do not sort backend data here.
- Do not depend on `two_dimensional_scrollables`.
- Do not make every cell a global Tab stop by default.
