# Row Action Menu And Action Cell Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Menu Button Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/
- WAI-ARIA APG Menu and Menubar Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/menubar/
- WAI-ARIA APG Toolbar Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/toolbar/
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 2.5.3 Label in Name: https://www.w3.org/WAI/WCAG22/Understanding/label-in-name.html

## Scope

This standard covers row action cells, inline row buttons, "more" menus,
contextual row action menus, swipe action equivalents, card action areas, and
repeated per-item command surfaces in virtualized collections.

It extends command bar, context menu, TreeGrid row/cell interaction, and command
routing standards. It focuses on row-scoped command semantics.

## Problem

Dense tables often render the same actions on every row: reveal, inspect, add,
remove, copy path, ignore, compare, or delete. If every repeated icon enters the
global tab order, keyboard use becomes exhausting. If row actions are only
visible on hover, keyboard and touch screen reader users lose access. If the
action only knows the visible row index, virtualization can execute it against
the wrong item.

## Decision Options

1. Row action registry with per-row command scope -
   🎯 9   🛡️ 9   🧠 8, roughly 900-1900 LOC.
   Best fit. It keeps repeated actions accessible without making every row a
   mini toolbar.
2. Render inline buttons in every row -
   🎯 5   🛡️ 5   🧠 3, roughly 200-600 LOC.
   Easy visually, but creates tab-order noise and inconsistent disabled reason
   handling.
3. Context menu only -
   🎯 6   🛡️ 7   🧠 4, roughly 300-800 LOC.
   Good as a secondary path, but weak discoverability if no visible action
   affordance exists.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- row action registry;
- row action trigger model;
- per-row command scope;
- disabled reason facts;
- destructive risk facts;
- primary versus secondary action classification;
- keyboard entry policy;
- visible action count limit;
- action menu open/close state;
- row id and snapshot/query version facts;
- announcement policy.

Renderer owns:

- inline icon layout;
- overflow menu visuals;
- hover/focus reveal visuals;
- compact card action placement;
- swipe affordance visuals where platform allows;
- disabled styling.

Application owns:

- command authorization;
- row capability;
- row identity and current validation;
- localized command labels;
- side effects;
- receipts and audit.

## Core Rule

Row action command target is a scoped item reference, not a visual row index.

```text
visible row index
  != item id
  != current node identity
  != delete target
```

Each action intent must carry:

- command id;
- row item id;
- collection id;
- query or snapshot version;
- scope kind;
- capability version;
- invocation source.

## Focus Model

Recommended model:

- TreeGrid row/cell remains the primary focus target.
- A row action menu is reachable from the row by keyboard.
- One primary action may be reachable directly when it is central to the row.
- Secondary actions live in an action menu.
- Repeated row actions do not all enter global tab order.

Keyboard entry examples:

- `Enter` activates row primary action by product policy;
- `Shift` + `F10` opens row context menu where available;
- `Menu` key opens row action menu where available;
- dedicated "More actions" button in action cell opens menu;
- `Escape` closes action menu and returns focus to row.

## Visible And Accessible Labels

Every action must have:

- stable command id;
- visible label when space allows;
- accessible label;
- row context description;
- disabled reason when disabled;
- destructive marker when destructive.

For repeated labels such as "Reveal" or "Remove", accessible description should
include row context. The visible label should remain part of the accessible
name when visible to support speech control.

## Action Menu Rules

Action menu must:

- open from a button or command route;
- expose expanded state where platform supports it;
- keep focus within menu while open;
- close on action, Escape, route change, stale row, or outside command policy;
- return focus to the row or trigger after close;
- separate destructive actions visually and semantically;
- show disabled actions when discoverability is important.

Do not put row action menu items in a menubar. They are contextual commands,
not top-level persistent application menus.

## Virtualization Rules

Row action state must survive:

- row unmount/remount;
- sort/filter changes;
- paging;
- viewport changes;
- row height changes;
- stale capability updates.

If the row disappears while an action menu is open:

- close menu;
- announce row no longer available if user initiated;
- disable command execution;
- preserve focus by moving to collection or nearest valid row.

## Clean Disk Usage

Clean Disk row actions:

- reveal in Finder or platform file manager;
- add to cleanup queue;
- remove from queue;
- inspect details;
- copy path;
- exclude from recommendation;
- compare with previous scan;
- open action menu.

Rules:

- Add to queue is not delete authority.
- Delete never runs from row action without current validated plan.
- Reveal action can degrade if platform cannot reveal a path.
- Copy path uses privacy policy and may require explicit user action.
- Stale row disables risky actions and explains why.

## Community API Sketch

```dart
final class RRowActionIntent {
  const RRowActionIntent({
    required this.commandId,
    required this.itemRef,
    required this.collectionRef,
    required this.invocation,
  });

  final String commandId;
  final RItemRef itemRef;
  final RCollectionRef collectionRef;
  final RInvocationSource invocation;
}

final class RRowActionDescriptor {
  const RRowActionDescriptor({
    required this.commandId,
    required this.kind,
    required this.enabled,
    required this.risk,
    required this.placement,
  });

  final String commandId;
  final RCommandKind kind;
  final RCommandAvailability enabled;
  final RCommandRisk risk;
  final RRowActionPlacement placement;
}
```

## Conformance Scenarios

- keyboard user can open row actions without pointer hover;
- row action target uses stable item id, not visible index;
- disabled row action exposes reason;
- menu close restores focus to row or safe fallback;
- virtualization unmount closes stale menu safely;
- destructive row action cannot bypass confirmation policy;
- repeated icon-only actions have row context in accessible description;
- speech control can activate visible command labels.

## Failure Catalog

- Hover-only row actions.
- Every row action button in global tab order.
- Action target is visible row index.
- Menu stays open after row becomes stale.
- Disabled destructive action has no reason.
- Hidden overflow actions are unreachable by keyboard.
- Row action executes delete directly.

