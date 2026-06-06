# Modal Focus Return Stack Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Dialog Modal Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Alert Dialog Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/alertdialog/
- MDN `<dialog>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dialog
- MDN `inert`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inert
- WCAG 2.1.2 No Keyboard Trap: https://www.w3.org/WAI/WCAG22/Understanding/no-keyboard-trap.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 3.3.4 Error Prevention: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html

## Scope

This standard covers modal focus traps, focus return, nested dialogs, alert
dialogs, confirmation flows, inert background behavior, modal stack ownership,
initial focus placement, and modal close semantics.

It extends dialog, overlay layer stack, destructive action safety, guided
repair, command palette, and focus system standards.

## Problem

Modal dialogs are central for destructive confirmation, permission repair,
advanced filters, and support export. A weak modal contract can make the app
dangerous:

- focus returns to a deleted/unmounted row;
- nested confirmation closes the wrong layer;
- background controls remain interactive;
- first focus lands on a destructive button;
- large confirmation content is skipped by screen readers;
- Escape cancels a critical operation without showing outcome.

## Decision Options

1. Modal stack manager with explicit focus return tokens -
   🎯 10   🛡️ 10   🧠 8, roughly 1000-2400 LOC.
   Best fit. It makes nested modals, command palettes, and destructive
   confirmations predictable.
2. Per-dialog focus trap implementation -
   🎯 6   🛡️ 6   🧠 5, roughly 400-1000 LOC.
   Works for simple dialogs, but breaks when overlays stack.
3. Rely on renderer framework modal defaults -
   🎯 5   🛡️ 5   🧠 2, roughly 100-300 LOC.
   Fast, but public Headless cannot guarantee behavior or conformance.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- modal stack;
- active modal id;
- focus return token;
- initial focus policy;
- close reason;
- inert/background policy;
- Escape/outside interaction policy;
- destructive default focus policy;
- nested modal ordering.

Renderer owns:

- backdrop visuals;
- platform dialog implementation;
- focus node wiring;
- animations;
- size and scroll layout.

Application owns:

- dialog content;
- confirmation policy;
- operation execution;
- dirty state;
- post-close destination;
- audit receipts.

## Focus Return Token

Focus return is not just "focus previous element".

Token fields:

- invoker semantic id;
- route id;
- pane id;
- row/node id if applicable;
- fallback focus target;
- restore scroll policy;
- validity check;
- privacy class.

Rules:

- if invoker is gone, focus moves to safe fallback;
- destructive completion should not return focus to deleted row;
- route changes invalidate old return target;
- stale token never crashes focus restoration;
- focus return is logged in debug diagnostics, not production telemetry.

## Initial Focus Rules

Rules:

- simple dialogs focus first meaningful control;
- large content dialogs may focus title/static intro with `tabindex="-1"` style
  behavior;
- destructive confirmations should not initially focus destructive action by
  default;
- alert dialogs focus safest acknowledgement or message depending on severity;
- validation dialogs focus first error summary or repair action;
- scroll position is set so initial focus is visible.

## Modal Stack Rules

Rules:

- only top modal accepts keyboard commands;
- lower modals are inert while covered;
- Escape closes only top closeable modal;
- outside click behavior is explicit per modal;
- nested modal close returns focus to parent modal, not background app;
- command palette cannot open over a destructive confirmation unless allowed by
  policy.

## Close Reasons

Close reasons:

- commit;
- cancel;
- escape;
- outsideInteraction;
- routeChange;
- operationCompleted;
- operationFailed;
- capabilityRevoked;
- parentClosed;
- appShutdown.

Close reason is part of the public event because products need to distinguish
user cancellation from operation completion.

## Clean Disk Usage

Modals:

- delete plan review;
- move to Trash confirmation;
- permission repair guide;
- custom folder picker;
- advanced filter picker;
- support bundle export;
- daemon compatibility warning.

Rules:

- destructive dialog uses validated current plan;
- destructive action disabled if plan becomes stale while modal is open;
- focus returns to cleanup queue or safe status region after operation;
- permission repair can open platform instructions without losing modal state;
- dialog content scrolls without hiding focused buttons behind footer.

## Community API Sketch

```dart
final class RModalFocusReturnToken {
  const RModalFocusReturnToken({
    required this.invokerId,
    required this.fallbackId,
    required this.restorePolicy,
    required this.validity,
  });

  final String invokerId;
  final String fallbackId;
  final RFocusRestorePolicy restorePolicy;
  final RReturnTargetValidity validity;
}
```

## Conformance Scenarios

- Tab and Shift+Tab remain inside active modal;
- Escape closes only top closeable modal;
- nested modal returns focus to parent modal;
- deleted invoker falls back to safe region;
- destructive action is not initial focus by default;
- background app is inert during modal;
- long dialog content starts at readable location.

## Anti-Patterns

- restoring focus by stale widget reference only;
- focusing destructive confirm button by default;
- closing all overlays on one Escape;
- letting background toolbar remain reachable;
- trapping focus in a modal that cannot be closed;
- losing user intent when modal is closed by route/update;
- using modal overlay to hide incompatible daemon state without explanation.

## Clean Architecture Note

Headless owns modal mechanics. Application owns confirmation policy and command
execution. Renderer adapters must not decide whether a destructive action is
safe to enable.

