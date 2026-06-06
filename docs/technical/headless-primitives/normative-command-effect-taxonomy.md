# Normative Command And Effect Taxonomy

## Status

Normative taxonomy for implementation and conformance.

## Purpose

Headless must distinguish user callbacks, component commands, internal events,
effects, and product use cases. Without this split, renderers start owning
behavior and app workflows leak into primitives.

## Terms

```text
UserCallback
  application-provided callback such as onChanged

Command
  imperative behavior surface exposed to renderer/request

Event
  reducer input describing what happened

Effect
  side effect requested by reducer

UseCase
  application/domain action outside Headless
```

## Direction Of Flow

```text
User input
  -> component event
  -> reducer
  -> new state
  -> effects
  -> render request
  -> renderer visuals

Renderer action surface
  -> command
  -> component event
```

Renderer never jumps directly to product use case.

## Command Categories

| Category | Examples | Owner |
| --- | --- | --- |
| focus | focus row, focus cell, restore focus | component |
| selection | toggle, range, clear | component |
| expansion | expand, collapse, toggle | component |
| overlay | open, close, complete close | component |
| menu | highlight item, activate command | component plus app callback |
| dialog | submit, cancel, close | component plus app callback |
| viewport | scroll target into view | effect adapter |
| product | reveal file, copy path, delete plan | application |

## Effect Categories

```text
FocusEffect
  requestFocus
  restoreFocus

ViewportEffect
  scrollToKey
  scrollToCell

OverlayEffect
  showOverlay
  updateOverlay
  closeOverlay

AnnouncementEffect
  announcePolite
  announceAssertive

ScheduleEffect
  postFrame
  coalesceNextFrame
```

Effects must be idempotent where practical.

## Product Boundary

Headless emits:

```text
CommandIntent(commandId, context)
```

Application maps it to:

```text
UseCase.execute(intent)
```

Clean Disk examples:

- `copyPath` is product command;
- `addToCleanupQueue` is product command;
- `toggleRowSelection` is Headless command;
- `moveToTrash` is never Headless.

## Renderer Boundary

Renderer receives commands:

```text
TreeGridCommands.toggleSelection(rowKey)
TreeGridCommands.openContextMenu(rowKey)
DialogCommands.submit()
MenuCommands.activate(commandId)
```

Renderer must not receive raw `onDelete`, `onCopyPath`, or daemon clients.

## Conformance Checks

- renderer command goes through component state;
- app callback fires once per user action;
- disabled command does not call app callback;
- product command context redacted in diagnostics;
- effect runs after reducer state update;
- duplicate close effect completes once.

## Stop Rules

- Do not pass product use cases to renderer.
- Do not let renderer mutate controller state directly.
- Do not run side effects inside pure reducer.
- Do not use display label as command id.
