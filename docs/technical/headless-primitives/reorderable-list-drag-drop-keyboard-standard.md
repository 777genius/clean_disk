# Reorderable List Drag Drop Keyboard Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 2.5.2 Pointer Cancellation: https://www.w3.org/WAI/WCAG22/Understanding/pointer-cancellation.html
- WCAG 2.5.7 Dragging Movements: https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- MDN HTML Drag and Drop API: https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API
- MDN DataTransfer: https://developer.mozilla.org/en-US/docs/Web/API/DataTransfer
- MDN Pointer Events: https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events
- WAI-ARIA APG Listbox Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/listbox/
- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/

## Scope

This standard covers reorderable lists, reorderable chips, sortable columns,
drag-to-move cards, drag-to-queue interactions, file drop targets, internal
drag previews, keyboard reorder commands, and drop target semantics.

It extends pointer/touch/drag accessibility and data-transfer governance
standards. It focuses on reorder and drag operation contracts.

## Problem

Drag and drop is attractive for productivity tools, but it is often
inaccessible and unsafe. WCAG 2.5.7 requires non-drag alternatives for dragging
movements. Clean Disk also cannot let a drag preview become cleanup authority.
Dropping a folder into a queue must be validated like any other command.

## Decision Options

1. `ReorderMoveOperation` with keyboard and single-pointer alternatives -
   🎯 9   🛡️ 9   🧠 8, roughly 900-2000 LOC.
   Best fit. It supports community reorderable components and keeps drag
   previews separate from committed operations.
2. Pointer drag only -
   🎯 3   🛡️ 3   🧠 3, roughly 200-600 LOC.
   Fast visually, but fails accessibility and is fragile on touch, switch,
   voice, and remote input.
3. Disable drag/drop entirely -
   🎯 6   🛡️ 8   🧠 1, roughly 0-100 LOC.
   Safe for MVP, but public Headless needs a standard before adding drag
   affordances.

Accepted direction: option 1 as the public contract, option 3 for Clean Disk
MVP unless a drag workflow is explicitly approved.

## Primitive Boundary

Headless owns:

- draggable item ids;
- operation kind;
- source scope;
- target scope;
- preview state;
- allowed drop targets;
- keyboard move commands;
- single-pointer alternative commands;
- cancellation state;
- live announcement policy;
- data transfer policy.

Renderer owns:

- drag handle visuals;
- preview ghost visuals;
- drop target highlight;
- insertion indicator;
- pointer cursor feedback;
- animation.

Application owns:

- whether move is allowed;
- persistence of new order;
- validation of dropped payload;
- cleanup queue policy;
- external file handling;
- receipts and audit.

## Operation Types

Supported operation kinds:

- reorderWithinList;
- moveBetweenLists;
- copyBetweenLists;
- addToQueue;
- removeFromQueue;
- columnReorder;
- cardMove;
- externalFileDrop;
- appDefined.

Each operation declares:

- whether drag is optional or essential;
- keyboard alternative;
- single-pointer alternative;
- cancellation behavior;
- authority downgrade rules;
- committed result.

## Drag Lifecycle

```text
idle
  -> armed
  -> previewing
  -> overTarget
  -> cancelled | rejected | committed
```

Rules:

- pointer down does not commit;
- operation commits on up/drop or explicit keyboard command;
- Escape cancels when keyboard focus is in the operation;
- pointer cancellation reverts preview;
- rejected target explains reason;
- preview never mutates authoritative state;
- late validation can reject before commit.

## Keyboard Alternatives

Required alternatives:

- move up/down commands for list reorder;
- move to top/bottom where useful;
- menu command to move to another group or column;
- add/remove button for queue-style interactions;
- explicit choose-target dialog for complex moves.

Keyboard reorder pattern:

- focus item;
- enter reorder mode or open action menu;
- move by commands;
- announce new position;
- commit or cancel;
- restore focus to item.

## Single-Pointer Alternatives

For any pointer drag:

- provide tap/click controls or menu alternatives;
- do not require holding pointer down and moving;
- allow abort before commit;
- avoid activating on down-event;
- support undo when practical.

This applies to mouse, touch, stylus, and assistive pointer devices.

## Data Transfer Rules

Internal drag may carry:

- opaque item ref;
- collection ref;
- operation id;
- source window id;
- capability version.

It must not carry:

- raw private path by default;
- daemon token;
- delete authority;
- localized labels as ids;
- unbounded serialized row data.

External drop targets are untrusted until application validates payload.

## Clean Disk Usage

Allowed future uses:

- reorder visible columns;
- reorder queue items;
- drag result to queue as convenience;
- drop a folder as scan target;
- rearrange dashboard widgets if that ever exists.

Rules:

- drag to queue is an add-to-queue intent, not delete plan;
- external file drop requires scan target validation;
- drag from another window downgrades authority;
- keyboard/menu alternative is mandatory;
- Clean Disk MVP can avoid drag entirely.

## Community API Sketch

```dart
final class RMoveOperation {
  const RMoveOperation({
    required this.id,
    required this.kind,
    required this.source,
    required this.targetPolicy,
    required this.state,
  });

  final String id;
  final RMoveKind kind;
  final RMoveSource source;
  final RDropTargetPolicy targetPolicy;
  final RMoveState state;
}
```

## Conformance Scenarios

- reorder works without dragging;
- drag preview cancels on Escape;
- pointer down alone does not commit;
- invalid drop target announces rejection reason;
- external payload is validated before use;
- selected item keeps focus after reorder;
- dropped item does not carry destructive authority;
- keyboard move announces new position.

## Failure Catalog

- Drag is the only way to reorder.
- Drop target highlight commits before drop.
- Raw path is serialized in drag payload.
- Drag from another window preserves delete authority.
- Pointer cancellation leaves item half-moved.
- Keyboard user cannot reach drop target.
- Reorder uses visible index as stable identity.

