# TreeGrid Row Cell Interaction And Edit Mode Standard

## Status

Implementation standard for TreeGrid row focus, cell focus, embedded controls,
and edit mode.

## Purpose

TreeGrid is the hardest Clean Disk primitive because it can contain rows,
columns, hierarchy, row actions, checkboxes, progress bars, warnings, inline
actions, and future editable cells. APG grid and treegrid patterns make row and
cell focus important, but product UX often wants rows-first navigation. This
file defines the contract so we can support both without breaking
accessibility.

## Standards And References

- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN `treegrid` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/treegrid_role
- MDN `gridcell` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/gridcell_role
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- Flutter Focus:
  https://docs.flutter.dev/ui/interactivity/focus

## Focus Modes

Supported modes:

```text
rowsFirst
cellsFirst
rowWithActionableCells
editingSpreadsheet
readonlyTreeTable
```

Clean Disk starts with `rowsFirst`.

Public Headless must keep the API open for `cellsFirst` and
`editingSpreadsheet` without making Clean Disk pay the full complexity in MVP.

## Rows-First Mode

Rows-first is appropriate when:

- primary task is scan/explore hierarchy;
- row has one primary identity;
- most columns are read-only facts;
- actions are available through row action menu or detail panel;
- keyboard user benefits from fast vertical navigation.

Rules:

- Up/Down moves row focus;
- Left/Right expands/collapses or navigates hierarchy by policy;
- Enter activates primary row command or toggles expansion by policy;
- Space selects or queues by explicit policy;
- Tab leaves TreeGrid or enters row actions depending on tab policy;
- column facts are announced through row summary and details path.

## Cells-First Mode

Cells-first is appropriate when:

- cell-level comparison matters;
- column actions are common;
- screen reader users need per-cell context;
- spreadsheet-like editing exists.

Rules:

- arrows move cell focus;
- Home/End move within row or grid by modifier policy;
- row expansion command remains available from hierarchy cell;
- header focus exists if sorting/filtering/resizing is available;
- selected row/cell semantics are explicit.

## Embedded Controls

Embedded row controls include:

- checkbox;
- reveal button;
- context menu button;
- queue button;
- warning/details button;
- inline link;
- progress/status action.

Rules:

- embedded controls have accessible names;
- row navigation can reach or invoke controls without pointer;
- controls do not add every row action to global Tab sequence by default;
- action menu can expose secondary row actions;
- icon-only controls require labels;
- disabled control state matches command state.

## Edit Mode

Edit mode is separate from navigation mode.

States:

```text
navigation
actionable
editPending
editing
validating
committing
error
```

Commands:

- Enter or F2 enters edit mode when editable;
- Escape leaves edit mode or cancels composition first;
- Tab commit/move policy is explicit;
- arrows move caret in edit mode;
- arrows navigate grid in navigation mode;
- validation error returns focus to editor or error summary by policy.

## Header Interaction

Header cells:

- are focusable when they expose sort/filter/menu/resize;
- expose sort state when sorted;
- expose resize handle through keyboard path;
- keep header focus separate from body focus;
- restore body focus after header menu closes.

## Row Summary Contract

Rows-first mode needs row summary so screen reader users do not lose cell
context.

Row summary can include:

- row name;
- depth/level;
- expanded/collapsed;
- selected/queued;
- size;
- warning status;
- modified date;
- item count.

Row summary must not include:

- every cell in long tables;
- raw sensitive values unless product chooses;
- debug ids;
- hidden destructive authority.

## Virtualization Interaction

- active row/cell key is logical;
- mounted cells are only renderer artifacts;
- hidden columns are not focus targets;
- offscreen cells cannot receive physical focus;
- scroll-to-cell returns explicit failure if column or row is unavailable.

## Required Tests

Automated:

- rows-first keyboard map;
- cells-first keyboard map fixture;
- edit mode blocks navigation keys;
- embedded button reachable and labelled;
- disabled row action cannot run;
- header sort/menu focus restore;
- virtualization does not lose active row/cell.

Manual:

- VoiceOver row summary;
- NVDA cell navigation in cells-first fixture;
- keyboard-only row action path;
- edit mode with IME;
- high contrast focus ring on row and cell.

## Stop Rules

- Do not hardcode rows-first as the only public Headless model.
- Do not put every row action in the global Tab order by default.
- Do not let edit mode leak arrow keys to grid navigation.
- Do not make hidden columns focusable.
- Do not use selected row as cleanup authority.
