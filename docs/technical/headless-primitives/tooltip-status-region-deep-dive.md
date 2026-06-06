# Tooltip And StatusRegion Deep Dive

## Status

Implementation-ready design constraints. Not implemented yet.

## Primary Standards

- WAI-ARIA APG Tooltip:
  https://www.w3.org/WAI/ARIA/apg/patterns/tooltip/
- MDN `tooltip` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/tooltip_role
- MDN `status` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN `alert` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alert_role
- MDN ARIA live regions:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions
- Flutter tooltip semantics order:
  https://docs.flutter.dev/release/breaking-changes/tooltip-semantics-order

## Core Decision

Tooltip and StatusRegion are separate primitives.

Tooltip describes a trigger. StatusRegion announces dynamic state. Neither is a
generic popover.

## Tooltip State

```text
TooltipState
  closed
  openingDelay
  open
  closingDelay
  closed
```

Triggers:

- hover;
- focus;
- manual;
- disabled if trigger disabled by policy.

Dismiss:

- Escape;
- blur;
- pointer leave after close delay;
- owner disposed.

## Tooltip Rules

- tooltip does not receive focus;
- focus remains on trigger;
- tooltip has no interactive descendants;
- trigger owns described-by relationship where platform supports it;
- tooltip is supplemental, not required-only information;
- interactive hovercard must be Dialog/Popover, not Tooltip.

## StatusRegion State

```text
StatusRegionState
  idle
  pendingAnnouncement
  announcing
  coalescing
```

Politeness:

```text
off
polite
assertive
```

Coalescing:

```text
none
byKey
trailingThrottle
leadingAndTrailing
```

## Clean Disk Announcement Policy

Progress:

- visible always;
- semantic announcement throttled;
- do not announce every file or percent.

Completion:

- polite announcement.

Daemon disconnect:

- assertive if user action is blocked.

Deletion failure:

- dialog/receipt if action needed;
- status only for advisory summary.

## Semantic Contract

Tooltip:

```text
TooltipSemantics
  role tooltip
  triggerRelationship describedBy
  text
  dismissibleByEscape
```

Status:

```text
StatusSemantics
  role status | alert
  live politeness
  atomic
  label optional
  message
```

MDN notes `status` is polite and atomic by default. Use alert only for urgent
interruptive content.

## Renderer Boundary

Renderer owns:

- tooltip surface;
- placement visuals;
- animation;
- status visual treatment.

Component owns:

- open delay;
- close delay;
- hover/focus coordination;
- Escape handling;
- announcement queue;
- semantic relationship.

## Conformance Tests

Tooltip:

- focus opens after delay;
- hover opens after delay;
- Escape closes;
- focus stays on trigger;
- interactive descendants rejected in debug;
- controlled open works.

StatusRegion:

- update does not move focus;
- polite/assertive facts recorded;
- repeated progress is coalesced;
- urgent status can use alert policy;
- visible text and announcement text can differ safely.

## Stop Rules

- Do not put buttons or links inside Tooltip.
- Do not use Tooltip for mandatory-only instructions.
- Do not use assertive live region for ordinary scan progress.
- Do not move focus for status updates.
- Do not show destructive confirmation as status.
