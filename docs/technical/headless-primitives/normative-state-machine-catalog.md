# Normative State Machine Catalog

## Status

Normative state-machine catalog for implementation.

## Purpose

State machines prevent hidden behavior in renderers and make conformance
testable. Every complex primitive should implement these states explicitly or
document a compatible subset.

## Overlay

```text
closed
  -> opening
  -> open
  -> closing
  -> closed
  -> disposed
```

Invariants:

- close completion happens exactly once;
- renderer exit animation must complete or fail-safe completes;
- cancelled close returns to open;
- focus restore happens after logical close.

## Dialog

```text
closed
  -> opening
  -> open
  -> submitting
  -> closing
  -> closed
```

Invariants:

- focus trap active only in open/submitting;
- destructive submit requires valid confirmation state;
- submitting blocks duplicate activation;
- Escape follows dismiss policy.

## Menu Stack

```text
closed
  -> openingRoot
  -> rootOpen
  -> submenuOpening
  -> submenuOpen
  -> closingSubmenu
  -> closingAll
  -> closed
```

Invariants:

- separator never focusable;
- disabled item focus policy explicit;
- submenu close restores parent item focus;
- context menu close restores logical invoking target.

## Tooltip

```text
closed
  -> openingDelay
  -> open
  -> closingDelay
  -> closed
```

Invariants:

- focus remains on trigger;
- Escape closes;
- tooltip never contains focusable descendants.

## StatusRegion

```text
idle
  -> pendingAnnouncement
  -> announcing
  -> coalescing
  -> idle
```

Invariants:

- no focus movement;
- ordinary progress coalesced;
- assertive only for urgent updates.

## Tree Node

```text
leaf
collapsed
  -> expanding
  -> expanded
  -> collapsing
  -> collapsed
failed
stale
```

Invariants:

- leaf never exposes expanded/collapsed;
- loading/error rows are synthetic;
- stale async response cannot overwrite newer state.

## TreeGrid Focus

```text
unfocused
  -> focusedRow
  -> focusedCell
  -> focusedHeader
  -> contentMode
  -> restoring
```

Invariants:

- focus and selection independent;
- hidden focused row normalizes to visible ancestor or fallback;
- offscreen target emits scroll effect.

## SplitPane

```text
idle
  -> focused
  -> pointerDragging
  -> keyboardResizing
  -> committing
  -> idle
  -> cancelled
  -> collapsed
  -> restored
```

Invariants:

- value clamped to min/max;
- keyboard alternative exists;
- collapse remembers last expanded size.

## Column Resize

```text
idle
  -> pointerDragging
  -> keyboardResizing
  -> previewing
  -> committing
  -> idle
  -> cancelled
```

Invariants:

- controlled width updated only by parent;
- Escape cancels preview;
- min/max always enforced.

## Conformance Rule

Each state transition must be testable through public API or test harness.
Renderer-private states may exist only for visuals and cannot replace these
component states.

## Stop Rules

- Do not hide open/close/focus state inside renderer.
- Do not skip fail-safe close for overlays.
- Do not make loading/error rows real domain rows.
- Do not allow stale async response to mutate current state.
