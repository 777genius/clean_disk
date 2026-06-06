# Status Footer Activity Region Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- MDN `status` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN `progressbar` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/progressbar_role
- MDN `aria-busy`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-busy
- MDN `<progress>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/progress
- WAI-ARIA APG Landmarks Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/landmarks/
- WCAG 2.2.2 Pause, Stop, Hide: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html

## Scope

This standard covers status footers, bottom activity bars, task progress
regions, scan activity strips, sync status bars, compact task indicators,
activity summaries, and footer command surfaces.

It extends progress/log/status, live announcement broker, and sticky geometry
standards. It focuses on persistent workbench status regions.

## Problem

Clean Disk has a bottom scan status surface: current path, progress, throughput,
files scanned, errors, skipped count, and pause controls. If implemented as a
chatty live region, it will spam screen readers. If implemented as visual-only,
users miss failures and completion. If it overlaps focus, keyboard users lose
access to row actions.

## Decision Options

1. `ActivityRegion` primitive with task facts and announcement policy -
   🎯 9   🛡️ 9   🧠 7, roughly 800-1700 LOC.
   Best fit. It models long-running operations without turning every tick into
   a live announcement.
2. Ordinary footer widget with progress bar -
   🎯 6   🛡️ 5   🧠 3, roughly 200-600 LOC.
   Looks fine, but weak for task identity, busy state, throttling, and
   operation controls.
3. Toast notifications for all activity -
   🎯 4   🛡️ 4   🧠 4, roughly 300-800 LOC.
   Too noisy and loses persistent operation state.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- activity region id;
- task id;
- task kind;
- task state;
- progress facts;
- status message;
- metric facts;
- command descriptors;
- announcement throttle policy;
- busy relationship;
- reduced motion policy;
- privacy class.

Renderer owns:

- footer placement;
- progress visuals;
- compact/wide layout;
- icon treatment;
- command button visuals;
- sticky behavior;
- animation.

Application owns:

- task lifecycle;
- operation cancellation;
- task metrics;
- error categories;
- localized status text;
- audit and receipts.

## Activity State Model

States:

- idle;
- starting;
- running;
- paused;
- cancelling;
- completed;
- completedWithWarnings;
- failed;
- disconnected;
- stale;
- hidden;

Each state declares:

- whether progress is determinate;
- whether task controls are available;
- whether announcement is required;
- whether risky commands elsewhere are blocked;
- whether stale read-only data can remain visible.

## Progress Facts

Progress fact fields:

- current value;
- total value if known;
- percent if meaningful;
- value text;
- unit;
- phase;
- throughput;
- elapsed;
- remaining estimate if reliable;
- confidence;
- freshness.

Rules:

- unknown total means indeterminate, not `0 percent`;
- progress value text should be meaningful when percentage is misleading;
- throughput ticks are not announced individually;
- private path text is not put in telemetry or ordinary live announcements.

## Announcement Rules

Announce:

- task started when user initiated;
- task paused;
- task resumed;
- task cancelled;
- task completed;
- task failed;
- warning/error count crosses important boundary;
- progress reaches coarse milestones if product policy enables it.

Do not announce:

- every scanned file;
- every current path update;
- every byte counter update;
- repeated unchanged status.

Status updates should not move focus. If focus must move, use dialog or error
summary patterns instead of status role behavior.

## Busy Relationship

If activity updates a specific region:

- relate task to that region;
- expose busy intent while content is incomplete;
- clear busy when region is coherent;
- keep partial content navigable only by policy.

Clean Disk scan can mark result collection as refreshing or scanning without
making the entire app inaccessible.

## Footer Geometry Rules

Persistent footer must not:

- cover focused row actions;
- hide bottom rows without scroll padding;
- steal pointer events outside its bounds;
- obscure virtual keyboard input;
- overlap system safe area.

It should:

- reserve layout space or provide scroll inset;
- expose skip/focus shortcut if dense;
- collapse to compact summary when space is limited;
- preserve task controls at target size.

## Clean Disk Usage

Bottom status region:

- scanning path summary;
- progress bar;
- percent or phase;
- files scanned;
- elapsed;
- throughput;
- errors;
- skipped;
- pause/cancel command.

Rules:

- current path display follows path privacy rules;
- pause/cancel commands use command routing;
- status footer never authorizes cleanup;
- stale/disconnected daemon state disables risky actions.

## Community API Sketch

```dart
final class RActivityRegionModel {
  const RActivityRegionModel({
    required this.id,
    required this.task,
    required this.progress,
    required this.metrics,
    required this.commands,
  });

  final String id;
  final RTaskFact task;
  final RProgressFact progress;
  final List<RMetricFact> metrics;
  final List<RCommandDescriptor> commands;
}
```

## Conformance Scenarios

- progress has accessible name and value text;
- indeterminate progress is not announced as zero;
- status update does not move focus;
- scan completion is announced once;
- throughput updates do not spam;
- footer does not cover focused row action;
- pause/cancel are keyboard reachable;
- private current path is redacted by policy.

## Failure Catalog

- Live region announces every progress tick.
- Footer overlays the last rows.
- Progressbar has no accessible name.
- Unknown total displayed as `0 percent`.
- Pause button bypasses command routing.
- Current private path logged as status telemetry.
- Completion toast is the only place task result appears.

