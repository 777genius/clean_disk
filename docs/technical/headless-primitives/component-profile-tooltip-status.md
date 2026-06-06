# Component Profile - Tooltip And StatusRegion

## Status

Implementation profile for `RTooltip` and `RStatusRegion`.

## Standards

- WAI-ARIA APG Tooltip:
  https://www.w3.org/WAI/ARIA/apg/patterns/tooltip/
- MDN `tooltip` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/tooltip_role
- MDN `status` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN ARIA live regions:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions

## Purpose

Tooltip describes a focused/hovered trigger. StatusRegion announces dynamic
state without moving focus.

Clean Disk use: icon button descriptions, scan progress summaries, daemon
status, skipped/error summaries.

## Tooltip Anatomy

- trigger;
- tooltip surface;
- text;
- optional arrow.

Forbidden:

- buttons;
- links;
- form fields;
- independent focus target.

## StatusRegion Anatomy

- visible status surface;
- message;
- optional progress indicator;
- announcement channel.

## Required State

Tooltip:

```text
closed
openingDelay
open
closingDelay
```

Status:

```text
idle
pendingAnnouncement
announcing
coalescing
```

## Keyboard Profile

Tooltip:

- Escape closes;
- focus stays on trigger.

StatusRegion:

- no keyboard focus;
- no focus movement.

## Semantic Profile

Tooltip:

- description relationship where platform supports it;
- role tooltip where web bridge supports it.

StatusRegion:

- polite by default;
- assertive only for urgent updates;
- no focus movement.

## Conformance Gates

- tooltip opens on focus/hover delay;
- Escape closes tooltip;
- no focusable tooltip descendants;
- status update does not move focus;
- progress announcements coalesced;
- alert policy only for urgent messages.

## Stop Rules

- Do not use Tooltip for interactive content.
- Do not use StatusRegion for destructive confirmation.
- Do not announce every progress tick.
