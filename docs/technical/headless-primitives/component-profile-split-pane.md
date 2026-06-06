# Component Profile - SplitPane

## Status

Implementation profile for `RSplitPane`.

## Standards

- WAI-ARIA APG Window Splitter:
  https://www.w3.org/WAI/ARIA/apg/patterns/windowsplitter/
- MDN `separator` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/separator_role
- WCAG 2.2 Dragging Movements:
  https://www.w3.org/TR/WCAG22/

## Purpose

Resizable pane layout for dense productivity tools.

Clean Disk use: wide layout target pane, tree table, details pane.

## Required Anatomy

- root;
- primary pane;
- secondary pane;
- separator handle;
- hit target;
- focus ring;
- optional collapse affordance.

## Required State

```text
axis
primarySize
minSize
maxSize
collapsed
lastExpandedSize
focusedHandle
dragState
```

## Keyboard Profile

MUST support:

- Arrow resize by axis;
- Home min;
- End max;
- Enter collapse/restore if collapsible;
- Escape cancel when in keyboard resize preview.

## Semantic Profile

MUST expose:

- separator;
- orientation;
- value min/max/now;
- label;
- disabled/locked if applicable.

## Pointer Profile

Pointer drag is allowed but MUST NOT be the only resize path.

## Conformance Gates

- keyboard resize;
- pointer resize;
- min/max clamp;
- collapse/restore;
- semantic value update;
- controlled state;
- RTL where relevant.

## Stop Rules

- Do not ship pointer-only SplitPane.
- Do not allow unbounded sizes.
- Do not make Clean Disk panes part of Headless API.
