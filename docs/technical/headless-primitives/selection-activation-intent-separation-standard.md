# Selection Activation Intent Separation Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Treegrid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- WAI-ARIA APG Listbox Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/listbox/
- MDN `aria-selected`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-selected
- MDN `aria-current`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Attributes/aria-current
- WCAG 2.5.7 Dragging Movements: https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html
- WCAG 3.3.4 Error Prevention: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html

## Scope

This standard covers selection, focus, active item, current item, activation,
opening, queueing, previewing, bulk scope, and destructive intent separation in
collections, grids, trees, lists, cards, and command surfaces.

It extends collection selection, TreeGrid, command routing, bulk selection,
destructive action, and user intent provenance standards.

## Problem

In dense data apps, one row can support many actions:

- focus for keyboard navigation;
- selection for multi-row operations;
- current item for details pane;
- activation for open/reveal;
- checkbox for cleanup queue;
- context menu for actions;
- drag source;
- destructive candidate.

If these states are collapsed into one boolean like `selected`, UI becomes
unsafe. A stale selected row could become a delete target, a focused row could
be queued accidentally, or a details preview could be mistaken for user
approval.

## Decision Options

1. Separate intent channels with typed state and command provenance -
   🎯 10   🛡️ 10   🧠 9, roughly 1200-2600 LOC.
   Best fit. It prevents selection/focus/activation confusion and protects
   destructive flows.
2. One selected item drives all row behavior -
   🎯 3   🛡️ 3   🧠 2, roughly 150-400 LOC.
   Common, but unsafe for cleanup, preview, and multi-client state.
3. Keep all states app-specific outside Headless -
   🎯 5   🛡️ 5   🧠 4, roughly 300-900 LOC.
   Flexible, but public primitives will not be interoperable.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- focused item id;
- active descendant id;
- selected item set;
- current item id;
- interaction source;
- activation intent event;
- selection change event;
- range anchor;
- keyboard and pointer models;
- semantic state export.

Renderer owns:

- selected visuals;
- focused visuals;
- current item visuals;
- hover visuals;
- checkbox placement;
- action affordances.

Application owns:

- command execution;
- cleanup queue;
- DeletePlan;
- stale validation;
- authority checks;
- operation receipts.

## State Channels

Channels:

- focus: where keyboard input goes;
- hover: pointer affordance only;
- active: temporary option under navigation;
- selected: set membership for collection operations;
- current: item shown in details/current route;
- expanded: hierarchy disclosure;
- queued: product-specific operation candidate;
- confirmed: validated destructive plan;
- executing: operation in progress.

Rules:

- focus is not selection;
- selection is not current details item;
- queue is not delete authority;
- confirmation plan is not visible selection;
- expansion is not activation;
- hover is never authority.

## Activation Rules

Activation events include:

- source modality;
- item id;
- semantic action;
- click count or key;
- modifier keys;
- timestamp;
- context version;
- visible row version.

Rules:

- Enter/Space behavior depends on component role;
- double click open/reveal is separate from selection;
- checkbox toggles selection or queue only by explicit part id;
- row action menu opens command candidates, not immediate delete;
- drag alternatives exist for reorder or grouping actions.

## Destructive Safety Rules

Rules:

- destructive commands consume validated command intent, not raw selection;
- delete queue item records explicit add-to-queue intent;
- DeletePlan is built from current daemon validation;
- stale selection disables destructive execution;
- all selected items visible is not required for bulk selection, but scope must
  be previewed;
- hidden filtered items are included only if bulk scope says so.

## Clean Disk Usage

State mapping:

- focused row: keyboard navigation;
- selected row: details and keyboard range selection;
- current node: details pane;
- queued node: cleanup queue;
- validated DeletePlan item: safe-to-confirm candidate;
- executing cleanup item: operation journal row.

Rules:

- clicking a folder row selects/current-details only;
- row checkbox may add to queue only if product policy says so;
- `Move to Trash` uses DeletePlan, not TreeTable selection;
- filter changes do not silently keep hidden destructive scope without preview;
- reconnect events may invalidate selected/queued/plan states separately.

## Community API Sketch

```dart
final class RCollectionIntentState<T extends Object> {
  const RCollectionIntentState({
    required this.focusedId,
    required this.currentId,
    required this.selectedIds,
    required this.expandedIds,
  });

  final T? focusedId;
  final T? currentId;
  final Set<T> selectedIds;
  final Set<T> expandedIds;
}
```

## Conformance Scenarios

- arrow navigation changes focus without adding to queue;
- row checkbox toggles declared selection channel only;
- details pane can follow current item without destructive authority;
- filtered bulk selection shows explicit scope preview;
- stale selected item cannot execute destructive command;
- current route item and selected grid item can differ by policy;
- screen reader output distinguishes selected, current, expanded, and busy.

## Anti-Patterns

- using one `selected` flag for focus, current, and queued;
- making hover show destructive authority;
- executing delete from active descendant id;
- hiding selected filtered items without scope disclosure;
- treating details preview as confirmation;
- using visible row index as stable identity;
- letting drag action be the only way to reorder.

## Clean Architecture Note

Headless owns interaction channels. Application owns product intent and policy.
Domain owns destructive plan meaning. Renderer owns visual distinction but
cannot merge states for convenience.

