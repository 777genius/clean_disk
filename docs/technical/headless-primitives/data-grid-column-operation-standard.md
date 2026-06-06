# Data Grid Column Operation Standard

## Status

Implementation standard for column sizing, ordering, sorting, filtering, and
pinned regions in grid-like primitives.

## Purpose

TreeGrid and future DataGrid primitives need column operations, but these
features can easily break keyboard access, virtualization, renderer
independence, and application-owned query semantics. This file defines the
boundary.

## Standards And References

- WAI-ARIA APG Grid Pattern:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Treegrid Pattern:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN `columnheader` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/columnheader_role
- MDN `aria-sort`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-sort
- WCAG 2.2 Dragging Movements:
  https://www.w3.org/TR/wcag-22/#dragging-movements
- Flutter `two_dimensional_scrollables`:
  https://pub.dev/packages/two_dimensional_scrollables

## Column Descriptor

Column must be described by stable data:

```text
columnKey
semanticName
headerRendererKey
cellRendererKey
widthPolicy
sortCapability
filterCapability
resizeCapability
pinCapability
visibilityCapability
privacyClass
```

Column label is display text, not identity.

## Sort Boundary

Headless may own:

- sorted header state;
- keyboard interaction for header command;
- sort direction cycle policy;
- accessible sort announcement;
- command emission.

Application owns:

- actual data sorting for large/product data;
- server/Rust query semantics;
- locale-sensitive collation;
- persisted user preference;
- permission to sort.

For Clean Disk, Flutter must not sort the full scan tree. It sends typed query
or sort descriptors to application/Rust contracts.

## Filter Boundary

Headless may own:

- filter button/menu opening behavior;
- header focus behavior;
- active filter visual/semantic state;
- command emission.

Application owns:

- filter expression;
- query execution;
- result count;
- stale result handling;
- privacy of filter text.

## Resize Boundary

Column resize must support:

- pointer drag;
- keyboard alternative;
- double-click or command reset if provided;
- min/max width;
- persisted width through app layer;
- high contrast handle;
- reduced motion behavior.

Resize state:

```text
idle
previewing
committed
cancelled
```

The renderer can draw preview line. Headless owns command semantics. App owns
persistence.

## Reorder Boundary

Column reorder is advanced and should be optional.

If supported:

- drag must have non-drag alternative;
- keyboard reorder commands must exist;
- screen reader announcement must describe move;
- pinned columns restrict legal moves;
- hidden columns cannot receive focus;
- persisted order belongs to app preferences.

## Pinned Regions

Pinned columns/headers affect:

- focus traversal;
- virtualization;
- semantic row/column indexes;
- hit testing;
- scroll synchronization;
- focus not obscured.

Pinned visuals must not duplicate semantic cells. If cells are visually cloned
for rendering, only one semantic owner is active.

## Header Interaction

Header cell can expose:

- sort command;
- menu command;
- resize handle;
- filter state;
- visibility state.

Rules:

- header focus must be reachable if header has action;
- icon-only header actions require labels;
- resize handle must not steal sort activation;
- header context menu restores focus to header;
- disabled sort state is announced or omitted consistently.

## Required Tests

Automated:

- sort command cycles state and emits descriptor;
- sorted header semantic state exists;
- resize keyboard path;
- resize pointer path;
- drag alternative for reorder;
- pinned column focus traversal;
- hidden column not focusable;
- visual cloned pinned cells not duplicated in semantics.

Manual:

- screen reader announces sortable/sorted header;
- keyboard user can resize or reset width;
- high contrast shows resize handle and focus;
- text scale does not hide header actions.

## Stop Rules

- Do not let Headless perform product data sorting for large remote datasets.
- Do not support drag-only column reorder.
- Do not duplicate pinned cells in semantics.
- Do not use localized column label as column key.
- Do not let renderer own persisted column state.
