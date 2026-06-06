# Component Profile - TreeGrid

## Status

Implementation profile for `RTreeGrid`.

## Standards

- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN `treegrid` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/treegrid_role
- Flutter Focus:
  https://docs.flutter.dev/ui/interactivity/focus
- Flutter web accessibility:
  https://docs.flutter.dev/ui/accessibility/web-accessibility

## Purpose

Hierarchical data grid for dense, keyboard-operable, virtualized data.

Clean Disk use: folder/file scan table.

Community use: file managers, outline tables, admin trees, package explorers,
log trees, hierarchical reports.

## Required Anatomy

- root;
- header row;
- header cell;
- row;
- tree cell;
- data cell;
- disclosure control;
- optional selection control;
- optional row action area;
- loading/empty/error states;
- viewport adapter.

## Required State

```text
focusTarget
selection
expandedKeys
sortDescriptors
visibleRange
loadingKeys
disabledPolicy
```

## Keyboard Profile

V1 MUST implement rows-first mode:

- Up/Down row focus;
- Left/Right collapse/expand;
- Home/End;
- Page Up/Page Down;
- Space selection;
- Enter activation;
- Shift + arrows range selection if enabled;
- Shift + F10 context menu.

Cells-first mode MAY be future, but API MUST preserve it.

## Semantic Profile

MUST expose:

- treegrid root;
- row/cell/header facts;
- row and column counts when known;
- row index for visible rows;
- level/depth;
- expanded only for expandable rows;
- selected and focused as separate facts;
- sorted header facts.

## Data Profile

MUST support app-owned visible pages. MUST NOT require the full tree in
Flutter.

Clean Disk: Rust owns sorting, filtering, search, and authoritative metadata.

## Renderer Profile

Renderer MAY draw:

- rows;
- cells;
- focus rings;
- disclosure icons;
- selection visuals;
- size bars;
- sticky header.

Renderer MUST NOT own:

- selection;
- expansion;
- focus;
- product actions;
- scan data.

## Conformance Gates

- keyboard rows-first scenario;
- semantics visible range;
- focus/selection split;
- controlled state;
- virtual viewport built-count gate;
- Material renderer token gate;
- screen-reader smoke before beta.

## Stop Rules

- Do not expose file/disk concepts.
- Do not use indexes as identity.
- Do not pass the full scan tree to Flutter.
- Do not mark stable before performance and AT evidence.
