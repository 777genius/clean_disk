# Migration And Adoption Path

## Status

Spec-level adoption plan.

## Purpose

Headless already has button, dropdown, text field, checkbox, switch, overlay,
listbox, and menu pieces. New primitives must integrate without forcing a risky
rewrite.

## Adoption Stages

Stage 0 - Docs and contracts:

- keep existing components stable;
- add RFC and conformance plan;
- do not publish experimental APIs as stable.

Stage 1 - Foundation extraction:

- collection mechanics extracted from listbox where reusable;
- grid/tree foundations added behind experimental exports;
- no existing component API break.

Stage 2 - Component prototype:

- `RTreeGrid` experimental;
- test viewport adapter;
- Material placeholder renderer;
- Clean Disk synthetic fixture only.

Stage 3 - Clean Disk wrapper:

- `AppTreeGrid` in design system;
- scan feature consumes wrapper;
- no direct feature dependency on Headless internals.

Stage 4 - Public beta:

- conformance report;
- keyboard tables;
- known limitations;
- performance fixture;
- screen-reader smoke.

Stage 5 - Stable:

- API freeze;
- migration docs;
- full conformance evidence.

## Existing Component Migration

Listbox:

- keep current API;
- optionally rebase internals on collection foundation;
- maintain conformance report.

Dropdown:

- keep overlay/listbox behavior;
- adopt command/effect taxonomy only internally.

Autocomplete:

- keep text field/menu integration;
- adopt collection identity where useful.

## Clean Disk Migration

MVP can use:

- design-system `AppTreeGrid`;
- fixed row height;
- rows-first navigation;
- app-owned visible pages.

Do not wait for:

- cell editing;
- pinned columns;
- variable row height;
- web ARIA bridge.

## Stop Rules

- Do not break existing components to land TreeGrid.
- Do not expose experimental APIs as stable.
- Do not migrate Clean Disk feature code directly to Headless internals.
