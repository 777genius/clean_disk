# Pointer Touch Drag Accessibility Standard

## Status

Implementation standard for pointer, touch, stylus, drag, resize, and gesture
interactions in Headless primitives.

## Purpose

Pointer interactions are easy to make visually polished and inaccessible. WCAG
2.2 makes drag alternatives and target size explicit. Headless needs a unified
input model so SplitPane resize, column resize, column reorder, row drag, map
selection, context menus, and touch gestures remain accessible.

## Standards And References

- WCAG 2.2:
  https://www.w3.org/TR/wcag-22/
- W3C What's New in WCAG 2.2:
  https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/
- MDN Pointer Events:
  https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events
- MDN HTML Drag and Drop API:
  https://developer.mozilla.org/docs/Web/API/HTML_Drag_and_Drop_API
- Flutter gestures:
  https://docs.flutter.dev/ui/interactivity/gestures

## Core Rule

Every drag-like operation must have a non-drag alternative unless the movement
itself is essential.

For Headless primitives, drag is almost never essential. Resize, reorder, move,
select, and split-pane changes must be available through keyboard commands or
single-pointer non-drag controls.

## Input Layers

```text
raw pointer
  -> gesture recognizer
  -> semantic operation
  -> reducer command
  -> effects
```

Core Headless owns semantic operation. Platform adapter owns pointer capture,
gesture arena, native drag APIs, and cancellation events.

## Pointer Event Model

Required facts:

- pointer kind: mouse, touch, stylus, trackpad, unknown;
- button or contact state;
- primary pointer flag where available;
- start position;
- current position;
- movement delta;
- cancellation reason;
- capture state;
- target logical key;
- operation id.

Renderer must not infer target authority from screen position after the
operation starts. The operation target is resolved at start and revalidated on
commit.

## Drag Operation State

```text
idle
armed
draggingPreview
commitPending
committed
cancelled
failed
```

Rules:

- pointer down alone does not commit;
- pointer cancellation cancels preview;
- Escape cancels preview where keyboard focus is in the operation;
- commit revalidates target and policy;
- visual preview is not authority;
- cancellation restores focus and state.

## Required Alternatives

SplitPane resize:

- arrow keys;
- Home/End;
- optional stepper buttons;
- reset command.

Column resize:

- keyboard resize handle;
- reset width command;
- size presets in menu.

Column reorder:

- move left/right commands;
- menu actions;
- keyboard reorder mode if supported.

Row reorder:

- move before/after commands;
- explicit choose destination workflow;
- status announcement of new position.

Map selection:

- keyboard navigation;
- list/tree equivalent;
- search/filter equivalent.

## Target Size And Hit Testing

Interactive targets must define:

- visual bounds;
- semantic hit area;
- minimum target policy;
- spacing policy;
- density exception;
- keyboard alternative.

Compact density may reduce visual size only if a larger semantic or adjacent
control path exists.

## Pointer Cancellation

Operations must be cancelable or reversible:

- release outside can cancel or commit only by explicit policy;
- system pointer cancel cancels preview;
- scroll interruption cancels gesture unless operation is scroll-safe;
- lost capture cancels or fails safely;
- route change cancels.

Destructive actions must not commit on pointer down.

## Flutter Adapter Notes

Flutter has raw pointer events and higher-level gestures. The adapter should:

- use `GestureDetector` for ordinary gestures;
- use lower-level pointer handling only when gesture semantics require it;
- respect gesture arena conflicts with scrollables;
- avoid custom recognizers unless the component contract needs them;
- route all recognized gestures into Headless commands;
- keep `Actions` and keyboard commands equivalent.

## Web Adapter Notes

Web adapters should be careful with native HTML drag and drop:

- it is mouse-oriented historically;
- browser behavior differs for dragging data in/out;
- input events can be suppressed during drag;
- mobile support can be inconsistent;
- custom pointer-driven drag may be more predictable for in-app reordering.

If web native drag is used, keyboard and touch alternatives remain mandatory.

## Evidence

Automated:

- drag preview cancel;
- pointer cancel handling;
- keyboard alternative for every drag command;
- target revalidation on commit;
- route change cancellation;
- no destructive commit on down event.

Manual:

- touch device resize/reorder;
- mouse drag with cancellation;
- keyboard-only reorder;
- screen reader announcement of moved/resized result;
- high contrast target visibility.

## Stop Rules

- Do not ship drag-only resize or reorder.
- Do not commit destructive action on pointer down.
- Do not let visual drop target become authority without revalidation.
- Do not rely on native HTML drag/drop as the only web path.
- Do not hide small interactive targets behind density preferences.
