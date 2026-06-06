# Component Anatomy And Parts Catalog

## Status

Spec-level anatomy catalog.

## Primary References

- Open UI component specification format:
  https://openuispec.org/spec
- WAI-ARIA APG Patterns:
  https://www.w3.org/WAI/ARIA/apg/patterns/
- Radix accessibility/primitives:
  https://www.radix-ui.com/primitives/docs/overview/accessibility

## Purpose

This file defines component anatomy in implementation-agnostic terms. Anatomy
drives slots, renderer contracts, tests, and documentation.

## Anatomy Rule

Each public primitive SHOULD define:

- root;
- interactive parts;
- semantic parts;
- visual-only parts;
- state-bearing parts;
- optional parts;
- forbidden parts.

## TreeGrid Anatomy

Parts:

- root;
- header row;
- header cell;
- row group;
- row;
- tree cell;
- data cell;
- disclosure control;
- selection control;
- row action area;
- loading row;
- error row;
- empty state;
- viewport.

Forbidden:

- product delete action implementation;
- daemon DTO;
- file path identity;
- full-tree data ownership.

## ContextMenu Anatomy

Parts:

- trigger or virtual anchor;
- menu surface;
- item;
- item icon;
- item label;
- shortcut label;
- check/radio indicator;
- submenu indicator;
- separator;
- group label.

Forbidden:

- form fields;
- arbitrary focusable content;
- product callback inside renderer.

## Dialog Anatomy

Parts:

- overlay/backdrop;
- surface;
- title;
- description;
- content;
- action group;
- close control;
- focus guards;
- progress state.

Forbidden:

- destructive product action inside Headless;
- outside-click close by default for destructive confirmation.

## SplitPane Anatomy

Parts:

- root;
- primary pane;
- secondary pane;
- splitter handle;
- hit target;
- focus ring;
- collapse affordance.

Forbidden:

- pointer-only resize;
- unbounded value.

## Tooltip Anatomy

Parts:

- trigger;
- tooltip surface;
- text content;
- optional arrow.

Forbidden:

- buttons;
- links;
- fields;
- independent focus target.

## StatusRegion Anatomy

Parts:

- visible status container;
- status text;
- progress indicator;
- announcement channel.

Forbidden:

- modal behavior;
- focus movement;
- destructive confirmation.

## Slot Mapping

Each part can be:

```text
fixed
replaceable
decoratable
enhanceable
renderer-private
```

Root semantics should be fixed unless an explicit unsafe escape hatch exists.

## Stop Rules

- Do not create stringly part ids.
- Do not allow slots to erase mandatory semantics silently.
- Do not put product-specific anatomy into Headless.
