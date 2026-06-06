# SplitPane Deep Dive

## Status

Implementation-ready design constraints. Not implemented yet.

## Primary Standards

- WAI-ARIA APG Window Splitter:
  https://www.w3.org/WAI/ARIA/apg/patterns/windowsplitter/
- MDN `separator` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/separator_role
- Flutter Focus:
  https://docs.flutter.dev/ui/interactivity/focus
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Core Decision

SplitPane is not just a draggable divider. It is a focusable range-like
separator with keyboard control and semantic values.

## State Model

```text
SplitPaneState
  axis
  primaryPaneId
  secondaryPaneId
  primarySize
  minSize
  maxSize
  collapsed
  lastExpandedSize
  dragging
  focusedHandle
```

## Size Units

```text
SplitPaneUnit
  pixels
  fraction
  intrinsic
```

V1 should support pixels and fraction. Intrinsic can be future.

## Keyboard Map

Vertical separator between left/right panes:

- Left decreases primary pane size;
- Right increases primary pane size;
- Home moves to minimum;
- End moves to maximum;
- Enter toggles collapsed/restored state.

Horizontal separator:

- Up decreases primary pane size;
- Down increases primary pane size;
- Home/End min/max;
- Enter collapse/restore.

Step policy:

```text
smallStepPx
largeStepPx
homeEndEnabled
collapseEnabled
```

## Semantic Contract

Expose:

- role separator;
- orientation;
- value min;
- value max;
- value now;
- value text;
- label;
- controlled pane relation;
- disabled/locked state.

Flutter adapter maps to `Semantics` value/increase/decrease actions where
possible.

## Pointer Interaction

Pointer drag rules:

- drag start captures initial size;
- updates are clamped to min/max;
- drag end emits commit event;
- Escape during drag cancels if keyboard initiated;
- double-click collapse is optional future.

## Layout Constraints

SplitPane must handle:

- parent resize;
- min/max conflicts;
- hidden secondary pane;
- compact layout where split panes are disabled;
- high DPI pointer deltas;
- persisted size from previous window.

## Clean Disk Usage

Wide:

- left target pane;
- center TreeGrid;
- right details/queue;
- bottom scan status outside split group.

Compact:

- no permanent split pane;
- panels become stacked/collapsible.

## Conformance Tests

- keyboard resize updates value;
- pointer resize updates value;
- min/max clamp;
- collapse/restore preserves last size;
- semantics value updates;
- controlled mode;
- parent resize normalizes state;
- renderer missing diagnostic.

## Stop Rules

- Do not make drag the only interaction.
- Do not expose Clean Disk pane names in Headless.
- Do not allow size outside bounds.
- Do not let renderer mutate layout state.
