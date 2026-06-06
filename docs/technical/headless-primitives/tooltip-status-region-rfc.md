# Headless Tooltip And StatusRegion RFC

## Status

Accepted design direction. Not implemented yet.

## Problem

Clean Disk uses dense icon controls, table actions, scan progress, skipped
items, and background daemon state. Headless needs two separate primitives:

- `RTooltip` for supplemental descriptions on hover/focus;
- `RStatusRegion` for polite or assertive announcements and visible status
  surfaces.

These must not be conflated.

## Standards And References

- WAI-ARIA APG Tooltip:
  https://www.w3.org/WAI/ARIA/apg/patterns/tooltip/
- MDN `tooltip` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/tooltip_role
- MDN `status` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN `alert` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alert_role
- MDN live regions:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions
- Flutter Tooltip semantics note:
  https://docs.flutter.dev/release/breaking-changes/tooltip-semantics-order

## Accepted Direction

Build separate components:

```text
components/headless_tooltip
  RTooltip
  RTooltipController
  TooltipDelayPolicy
  TooltipDismissPolicy

components/headless_status_region
  RStatusRegion
  RLiveAnnouncementController
  StatusPoliteness
  AnnouncementQueuePolicy
```

## Top Options

1. Separate Tooltip and StatusRegion primitives - 🎯 9   🛡️ 9   🧠 7,
   roughly 700-1400 LOC.

   Best design. Tooltip describes a focused/hovered trigger. Status announces
   dynamic updates without moving focus.

2. One generic popup primitive - 🎯 5   🛡️ 5   🧠 6,
   roughly 500-1000 LOC.

   Too vague. Tooltips, popovers, dialogs, menus, and status regions have
   different accessibility contracts.

3. Use Flutter `Tooltip` and ad hoc SnackBars - 🎯 5   🛡️ 6   🧠 3,
   roughly 100-300 LOC.

   Fine for simple apps, not enough for Headless community contracts and
   consistent live region policy.

Accepted: option 1.

## Tooltip Rules

Tooltip:

- appears on hover or keyboard focus after delay;
- closes on Escape, blur, and pointer leave by policy;
- focus stays on the trigger;
- tooltip itself does not receive focus;
- tooltip must not contain interactive elements;
- trigger references tooltip as description where platform supports it.

If content is interactive, use non-modal dialog or popover, not tooltip.

## Tooltip Contracts

```text
TooltipTriggerId
TooltipState.closed | opening | open | closing
TooltipPlacement
TooltipDelayPolicy(openDelay, closeDelay)
TooltipTriggerMode.focus | hover | manual
```

Renderer owns surface visuals. Component owns open/close state, focus/hover
coordination, Escape handling, and semantics.

## StatusRegion Rules

StatusRegion:

- does not receive focus on update;
- announces dynamic advisory updates;
- uses polite by default;
- assertive only for urgent messages;
- urgent interactive acknowledgment should be Dialog/AlertDialog, not status;
- announcement queue must coalesce noisy progress updates.

Clean Disk examples:

- "Scanning Library, 42%" - visible status, mostly no announcement every tick;
- "Scan completed" - polite announcement;
- "Connection lost to daemon" - assertive or alert depending severity;
- "Move to Trash failed for 2 items" - likely dialog/receipt, not just status.

## Announcement Policies

```text
StatusPoliteness.off
StatusPoliteness.polite
StatusPoliteness.assertive

AnnouncementPriority.low
AnnouncementPriority.normal
AnnouncementPriority.urgent

AnnouncementCoalescing.none
AnnouncementCoalescing.byKey
AnnouncementCoalescing.trailingThrottle
```

Default for progress: trailing throttle by key.

## Accessibility Model

Tooltip semantic facts:

- tooltip role;
- described-by relationship;
- trigger label remains primary;
- dismissible by Escape.

Status semantic facts:

- status/live region;
- politeness;
- atomic update;
- label optional;
- no focus movement.

Flutter Semantics may not expose a direct live-region API equivalent to ARIA on
all platforms. Keep platform-neutral facts and test actual behavior.

## Conformance Tests

Tooltip:

- opens on focus/hover after delay;
- closes on Escape;
- focus remains on trigger;
- no focusable descendants allowed in debug;
- description semantics available where supported;
- controlled open state works.

StatusRegion:

- update does not move focus;
- polite/assertive policies are recorded;
- progress coalescing suppresses spam;
- repeated same message dedupes by policy;
- visible text and semantic announcement can differ safely.

## Stop Rules

- Do not put buttons, links, or forms inside tooltip.
- Do not use tooltip for essential-only information.
- Do not use assertive announcements for ordinary progress.
- Do not show status as a modal.
- Do not move focus to status updates.
