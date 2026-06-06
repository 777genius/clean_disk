# Operation Center Background Task Queue Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- WCAG 2.2.2 Pause, Stop, Hide: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html
- MDN `status` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN `log` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/log_role
- MDN `progressbar` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/progressbar_role
- MDN `aria-busy`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-busy
- WAI-ARIA APG Button Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/button/

## Scope

This standard covers operation centers, background task drawers, task queues,
job lists, scan operation lists, cleanup operation lists, support export tasks,
retry queues, and operation history surfaces.

It does not define product operations. Headless renders operation facts and
commands. Application owns execution, receipts, and authority.

## Problem

Clean Disk will have operations that continue outside the currently focused
view: scan, cancel scan, cleanup, restore, support bundle export, update check,
permission repair, and remote/headless tasks. A status footer is not enough
once several operations exist. A public Headless library needs a task queue
contract so every app does not reinvent progress, cancellation, retry, and
receipts.

## Decision Options

1. `OperationCenter` primitive with task facts and command routing -
   🎯 9   🛡️ 9   🧠 8, roughly 1000-2200 LOC.
   Best fit. It gives persistent operation visibility without making Headless
   own app operations.
2. Only show one current status footer -
   🎯 6   🛡️ 6   🧠 3, roughly 200-600 LOC.
   Acceptable for MVP, but weak once operations overlap or continue after
   navigation.
3. Use audit timeline as operation queue -
   🎯 5   🛡️ 6   🧠 4, roughly 300-900 LOC.
   Audit is history/evidence. Operation center is live control and recovery.

Accepted direction: option 1 as contract, option 2 for first scan-only slice.

## Primitive Boundary

Headless owns:

- operation list model;
- operation id;
- operation kind;
- operation state;
- progress facts;
- command descriptors;
- retry/cancel/pause capability facts;
- dependency and blocking facts;
- visibility and attention policy;
- status announcement policy;
- privacy class.

Renderer owns:

- drawer, panel, popover, or full page layout;
- operation row visuals;
- progress visuals;
- icons;
- grouping;
- compact badge visuals;
- animation.

Application owns:

- operation execution;
- cancellation implementation;
- retry behavior;
- receipts;
- logs;
- audit;
- policy gates;
- localization.

## Operation State Model

States:

- queued;
- starting;
- running;
- paused;
- waitingForUser;
- waitingForSystem;
- cancelling;
- cancelled;
- completed;
- completedWithWarnings;
- failed;
- blocked;
- stale;
- unknown.

Each operation declares:

- whether it is active;
- whether it is user-cancellable;
- whether retry is available;
- whether receipt exists;
- whether it blocks risky commands;
- whether it needs user attention.

## Queue Semantics

Task queue order is not always execution order.

Facts:

- display order;
- priority;
- dependency relation;
- concurrency group;
- retry count;
- last update time;
- result summary.

Rules:

- visible queue order is not authority;
- operation id is stable and nonlocalized;
- failed operation remains discoverable until dismissed or archived by policy;
- completed destructive operation must link to receipt if available;
- operation center does not hide active risky operation behind toast only.

## Announcement Rules

Announce:

- operation started by user;
- operation needs attention;
- operation failed;
- operation completed;
- operation completed with warnings;
- operation was cancelled.

Do not announce:

- every progress tick;
- every log line;
- every queue reorder;
- every background retry unless user attention is required.

Use `status` intent for advisory updates and `alert` intent only for urgent,
time-sensitive failures that require attention.

## Clean Disk Usage

Operations:

- scan target;
- refresh subtree;
- create delete plan;
- move to Trash;
- restore from receipt if available;
- support bundle export;
- permission repair check;
- daemon restart/reconnect.

Rules:

- delete operations require receipts;
- operation center can display cleanup progress but cannot authorize cleanup;
- stale operation cannot be retried without app validation;
- raw paths are redacted by privacy policy in operation rows.

## Community API Sketch

```dart
final class ROperationCenterModel {
  const ROperationCenterModel({
    required this.operations,
    required this.summary,
    required this.policy,
  });

  final List<ROperationItem> operations;
  final ROperationSummary summary;
  final ROperationVisibilityPolicy policy;
}

final class ROperationItem {
  const ROperationItem({
    required this.id,
    required this.kind,
    required this.state,
    required this.progress,
    required this.commands,
  });

  final String id;
  final String kind;
  final ROperationState state;
  final RProgressFact? progress;
  final List<RCommandDescriptor> commands;
}
```

## Conformance Scenarios

- multiple running operations are discoverable;
- failed operation exposes retry and disabled reason where applicable;
- completed cleanup links to receipt;
- cancellation command uses command router;
- progress updates are throttled for assistive technology;
- operation center works without pointer hover;
- raw private paths are not logged or announced by default;
- stale operation cannot execute retry blindly.

## Failure Catalog

- Operation disappears after navigation.
- Toast is the only record of failure.
- Delete operation has no receipt link.
- Retry reuses stale authority.
- Progress update spams live region.
- Operation id is localized label.
- Operation queue order is treated as execution authority.

