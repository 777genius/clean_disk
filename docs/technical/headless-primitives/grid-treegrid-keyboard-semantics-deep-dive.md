# Grid And TreeGrid Keyboard Semantics Deep Dive

## Status

Implementation-ready design constraints. Not implemented yet.

## Primary Standards

- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN `treegrid` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/treegrid_role
- MDN `grid` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/grid_role
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- Flutter Focus:
  https://docs.flutter.dev/ui/interactivity/focus

## Core Decision

TreeGrid exposes two focus modes:

```text
rowsFirst
  default for Clean Disk and file-manager style UIs

cellsFirst
  data-grid/spreadsheet style
```

Do not fake cells-first behavior through rows-first APIs. Preserve both in
public contracts even if V1 implements rows-first first.

## APG-Derived Invariants

- A grid is a composite widget.
- Only one focusable descendant is normally in the page Tab sequence.
- Authors must manage focus movement inside the grid.
- Selection and focus are independent in multi-select grids.
- `aria-sort` belongs to header cells, not the grid container.
- Hidden or virtualized rows/columns require row/column count and index facts.
- Treegrid rows can expand/collapse. Non-expandable rows must not expose
  expanded/collapsed state.

## Focus Target Model

```text
TreeGridFocusTarget
  row(rowKey)
  cell(rowKey, columnKey)
  header(columnKey)
  rowAction(rowKey, actionKey)
  none
```

Rules:

- focused target must be visible or produce scroll intent;
- focused row hidden by collapse moves to nearest visible ancestor;
- focused column hidden moves to nearest visible column;
- focused header hidden moves to first visible sortable/header cell;
- focus state is logical, Flutter `FocusNode` is an implementation detail.

## Keyboard Map - Rows-First Mode

| Key | Behavior |
| --- | --- |
| Up | previous visible row |
| Down | next visible row |
| Right | expand collapsed parent, or move to first child by policy |
| Left | collapse expanded parent, or move to parent by policy |
| Home | first visible row |
| End | last visible row if known, otherwise last loaded row |
| Page Up | move by viewport page |
| Page Down | move by viewport page |
| Space | toggle selection if selectable |
| Shift + Up/Down | extend row range |
| Enter | activate row default action |
| Context Menu / Shift + F10 | open row context menu |
| Ctrl/Cmd + A | select configured scope |

Clean Disk default:

- Right expands only, second Right moves to first child if enabled.
- Left collapses, second Left moves parent.
- Ctrl/Cmd + A selects visible or filtered scope only after product policy
  chooses the scope.

## Keyboard Map - Cells-First Mode

| Key | Behavior |
| --- | --- |
| Left/Right | previous/next cell |
| Up/Down | same column previous/next row |
| Home/End | row start/end |
| Ctrl/Cmd + Home/End | grid start/end |
| Page Up/Down | viewport page preserving column |
| Enter | enter cell content or activate default |
| F2 | toggle navigation/content mode |
| Escape | return from content/edit mode to grid navigation |
| Shift + arrows | extend cell selection if enabled |

This mode is future for Clean Disk, but public API must not block it.

## Navigation vs Content Mode

APG notes that arrow keys cannot simultaneously move grid focus and operate an
in-cell widget. Model this:

```text
GridInteractionMode.navigation
GridInteractionMode.content
GridInteractionMode.editing
```

Rules:

- navigation mode consumes arrows for grid movement;
- content mode lets inner controls use arrows;
- Escape exits content/editing mode;
- Enter or F2 enters content/editing mode by policy;
- renderer cannot decide this alone.

## Semantic Contract

Expose platform-neutral facts:

```text
TreeGridSemantics
  role: treeGrid
  readonly
  multiselectable
  rowCount: known | unknown
  columnCount: known | unknown
  hasPopup

RowSemantics
  rowIndex
  level
  expanded: true | false | notExpandable
  selected: true | false | notSelectable
  disabled
  loading

CellSemantics
  columnIndex
  rowHeader
  columnHeader
  sorted
  readonly
  textValue
```

Do not expose ARIA names directly from core. Flutter Semantics and optional web
ARIA bridge map these facts.

## Header Semantics

Column headers are focusable only if they expose action:

- sort;
- filter;
- resize;
- menu;
- select column.

Non-interactive headers can remain semantic labels but not focus targets.

## Virtualization Semantics

For virtualized rows:

- `rowCount` known if backend provides it;
- `rowIndex` is 1-based semantic index when mapping to ARIA;
- unknown totals must stay unknown;
- offscreen focus target produces scroll effect;
- row widgets do not own logical row count.

## Flutter Mapping

Use:

- `Shortcuts` for key to intent mapping;
- `Actions` for dispatching component commands;
- `Focus` or `FocusableActionDetector` for root focus handling;
- internal logical focus separate from individual cell widgets;
- `Semantics` for visible facts;
- `SemanticsService.announce` only through effects, not direct renderer calls.

## Conformance Tests

- one Tab stop enters grid in composite mode;
- arrow navigation works without pointer;
- focus survives row reorder;
- selected row is visually and semantically distinct from focused row;
- hidden row/column normalizes focus;
- sorted header exposes sort fact;
- non-expandable row has no expanded fact;
- virtual row index facts are stable;
- content mode lets inner control use arrow keys.

## Stop Rules

- Do not let every cell enter global Tab order by default.
- Do not collapse focus and selection.
- Do not sort data inside Flutter for backend-owned results.
- Do not expose expanded state on leaf rows.
- Do not use Flutter `FocusNode` identity as model identity.
