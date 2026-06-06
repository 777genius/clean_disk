# Undo Redo And Operation History Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- WCAG 3.3.4 Error Prevention: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html
- WCAG 2.2.1 Timing Adjustable: https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- MDN `beforeunload`: https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeunload_event

## Scope

This standard defines how Headless primitives describe reversible UI actions,
operation history, undo and redo affordances, dirty state, command receipts,
and irreversible operation boundaries.

It applies to:

- selection and deselection;
- column resize, reorder, show, hide;
- filter and sort changes;
- query edits;
- panel layout changes;
- add-to-queue and remove-from-queue;
- preference changes;
- destructive confirmations;
- export generation;
- multi-step workflows.

It does not make destructive filesystem cleanup undoable. It defines how UI
must represent whether undo exists, whether restore exists, and whether only a
receipt exists.

## Decision Options

Option A: No Headless operation history - 🎯 4   🛡️ 4   🧠 2, about
80-200 LOC.

- Simple.
- Forces each app to define undo semantics.
- Public UI kit users will create inconsistent shortcuts and announcements.

Option B: Generic undo stack of callbacks - 🎯 5   🛡️ 5   🧠 4, about
250-500 LOC.

- Easy for pure UI changes.
- Unsafe for async operations, external side effects, and stale data.
- Callback stacks are hard to serialize and inspect.

Option C: Typed command history with reversible, compensating, and receipt-only
classes - 🎯 9   🛡️ 9   🧠 7, about 900-1800 LOC.

- Accepted direction.
- Makes undo explicit and testable.
- Separates UI reversibility from product-side authority.

## Accepted Direction

Headless must define an operation history primitive that records semantic
commands and their reversal class.

Reversal classes:

- `reversible`: can be undone locally without external validation.
- `replayable`: can be reapplied through the same command contract.
- `compensating`: cannot undo original action, but can issue a separate
  compensating operation.
- `receiptOnly`: no undo is available, only evidence and follow-up actions.
- `blocked`: undo is intentionally disabled by policy.

## Command Record Shape

Each command record must include:

- stable command id;
- user-visible label key;
- affected primitive id;
- affected stable item ids;
- timestamp;
- initiating input modality;
- before state reference;
- after state reference;
- reversal class;
- expiration policy;
- privacy class;
- status announcement;
- diagnostic reason if not undoable.

The record must not store sensitive content unless the app explicitly opts in
and assigns a privacy class.

## Undo Stack Rules

The history stack must:

- only include commands that declare history policy;
- group continuous edits when appropriate;
- split commands when state authority changes;
- clear redo branch when a new command is applied after undo;
- expose canUndo and canRedo state;
- publish accessible status after undo and redo;
- never execute undo through stale callbacks;
- validate operation generation before replay.

## Reversible UI Commands

Usually reversible:

- table column resize;
- column order;
- sort choice;
- filter chip removal;
- selection change;
- expand or collapse all within current view;
- panel resize;
- queue item removal before validation;
- theme preference change.

These can often stay local to Headless or app presentation state.

## Non-Reversible Or Sensitive Commands

Not simple undo:

- move to Trash;
- permanent delete;
- official cleanup tool execution;
- daemon restart;
- scan cancellation after resources were freed;
- remote destructive action;
- export with sensitive data written to disk;
- file reveal operation.

These require product-layer receipts or explicit compensating actions.

## Clean Disk Delete Boundary

Clean Disk must model cleanup as:

1. UI selection;
2. queue edit;
3. current delete plan validation;
4. explicit confirmation;
5. daemon operation;
6. receipt;
7. restore or reveal receipt where platform supports it.

Undo can apply to steps 1 and 2.

Undo cannot be promised for steps 4 and beyond unless the platform adapter has
verified restore support and the receipt has enough evidence.

Label must distinguish:

- Undo selection;
- Remove from queue;
- Restore from Trash;
- Open receipt;
- No undo available.

## Keyboard Requirements

Headless should support:

- platform undo shortcut;
- platform redo shortcut;
- command discovery integration;
- disable when no command is available;
- announce command result through status region;
- avoid conflicting with text editing undo inside focused text fields.

Text inputs own their own edit stack. The app-level history must not intercept
text editing shortcuts while editing text.

## Multi-Client Rules

For daemon-backed apps:

- UI undo stack is window-local unless declared shared;
- daemon operations have operation ids;
- operation receipts are authoritative;
- multi-client changes may invalidate local undo;
- invalidation must publish a reason and disable stale undo.

Clean Disk multi-window rule:

- one window removing from queue must not silently undo another window's
  confirmed delete plan.

## Dirty State Rules

Dirty state means user-created local state not yet committed or persisted.

Headless must expose:

- dirty command count;
- pending operation count;
- unsaved local edits;
- unload warning policy;
- save or discard affordance.

It must not use dirty state to block safe navigation without a reason.

## API Shape Sketch

```text
OperationHistory
  record(command)
  undo()
  redo()
  clear(scope)
  canUndo
  canRedo
  pendingRecords

CommandRecord
  id
  scope
  labelKey
  reversalClass
  beforeRef
  afterRef
  privacyClass
  status
```

## Conformance Scenarios

- undo column resize restores prior width and announces result;
- redo after undo reapplies the command;
- typing in search input uses text field undo, not app undo;
- remove-from-queue can be undone before delete plan validation;
- confirmed cleanup does not show generic Undo unless restore is supported;
- stale undo is disabled after snapshot changes;
- multi-window command invalidation is visible;
- dirty state installs unload warning only while needed.

## Failure Catalog

- generic callback undo that runs after data changed;
- promising undo for destructive cleanup;
- redo branch preserved after new command;
- app undo intercepting text editing;
- hidden history state containing sensitive paths;
- stale undo button remaining enabled;
- no accessible status after undo;
- local UI history conflicting with daemon operation receipt;
- unload warning shown forever;
- restore and undo labels used interchangeably.

