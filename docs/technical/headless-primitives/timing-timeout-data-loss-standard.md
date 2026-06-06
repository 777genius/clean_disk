# Timing Timeout And Data Loss Standard

## Status

Implementation standard for timing, timeout warnings, delayed actions,
debounce, auto-dismiss, background refresh, and unsaved data loss.

## Purpose

Headless primitives use timers for tooltip delays, typeahead buffers, search
debounce, live announcement throttling, animations, long-running operations,
and auto-dismiss status. Timers can cause data loss or inaccessible behavior if
they are not explicit and controllable.

## Standards And References

- WCAG 2.2:
  https://www.w3.org/TR/wcag-22/
- WCAG Timeouts Understanding:
  https://www.w3.org/WAI/WCAG22/Understanding/timeouts.html
- WAI-ARIA APG Tooltip:
  https://www.w3.org/WAI/ARIA/apg/patterns/tooltip/
- MDN ARIA live regions:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/ARIA_Live_Regions
- Flutter accessibility:
  https://docs.flutter.dev/ui/accessibility

## Core Rule

Time-based behavior must be explicit policy, not hidden renderer behavior.

```text
timer
  -> policy
  -> state transition
  -> cancellable effect
```

## Timer Categories

```text
tooltipDelay
typeaheadTimeout
searchDebounce
statusAutoDismiss
animationDuration
longPressDelay
operationTimeout
sessionTimeout
backgroundRefresh
validationDebounce
liveAnnouncementThrottle
```

Each timer declares:

- purpose;
- owner;
- default duration;
- cancellation condition;
- accessibility override;
- reduced motion behavior;
- data-loss risk;
- test hook.

## Data Loss Rule

Any timeout that can lose user input, selection, pending confirmation, or
operation intent requires warning or preservation.

Examples:

- unsaved filter draft;
- edit cell draft;
- command palette query;
- delete confirmation plan;
- remote session pairing;
- cleanup operation receipt.

If preserving data is feasible, preserve it. If not, warn before timeout.

## Auto-Dismiss Rules

Auto-dismiss is acceptable for:

- nonessential toast/status;
- tooltip after blur/hover exit;
- transient progress completion if information remains in history.

Auto-dismiss is risky for:

- errors;
- validation messages;
- destructive confirmation;
- permission repair instructions;
- security prompts;
- user-entered data.

Critical messages require user dismissal or persistent location.

## Debounce Rules

Debounce must not hide state:

- search field shows pending/loading state;
- late result ignored by request id;
- screen reader gets throttled result count;
- user can submit explicitly without waiting where appropriate.

## Reduced Motion And Accessible Navigation

When reduced motion or accessible navigation is requested:

- animation timers shorten or skip;
- tooltip/status timers remain readable;
- auto-advance patterns pause or become manual;
- scroll animation becomes instant or minimal.

## Testability

Timer behavior needs injected clock or test scheduler.

Required:

- no real-time sleeps in unit tests;
- deterministic debounce tests;
- cancellation tests;
- reduced motion tests;
- timeout warning tests.

## Clean Disk Examples

- scan progress update throttle;
- search query debounce;
- tooltip delay;
- delete confirmation stale-plan timeout;
- daemon reconnect/backoff;
- support bundle export timeout.

Destructive confirmation timeout must fail closed and require revalidation.

## Required Tests

Automated:

- tooltip delay cancel;
- search debounce late result ignored;
- status auto-dismiss skipped for error;
- reduced motion changes animation behavior;
- destructive plan timeout disables action;
- timer disposed with component.

Manual:

- screen reader has time to hear status;
- keyboard user can recover from timeout warning;
- slow user can complete confirmation without surprise data loss.

## Stop Rules

- Do not auto-dismiss errors by default.
- Do not let timeout execute destructive action.
- Do not make timers renderer-owned hidden behavior.
- Do not use real-time sleeps in conformance tests.
- Do not lose user draft without warning or preservation.
