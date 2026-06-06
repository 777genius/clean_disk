# Deterministic Time Scheduler And Test Standard

## Status

Accepted as a Headless quality-operations standard. Not implemented yet.

## Source Standards

- MDN Page Visibility API: https://developer.mozilla.org/docs/Web/API/Page_Visibility_API
- MDN Performance API: https://developer.mozilla.org/en-US/docs/Web/API/Performance_API
- MDN `requestAnimationFrame`: https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame
- MDN `setTimeout`: https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout
- WCAG 2.2.1 Timing Adjustable: https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html
- WCAG 2.2.2 Pause, Stop, Hide: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html

## Scope

This standard defines deterministic handling of timers, debounces, throttles,
animations, announcements, timeouts, retries, and background tab behavior.

It applies to:

- search debounce;
- typeahead timeout;
- tooltip delay;
- toast duration;
- live announcement throttle;
- progress milestones;
- animation lifecycle;
- retry backoff;
- cleanup confirmation expiry;
- test harness time control.

It does not define product operation timing. It defines Headless scheduler
contracts.

## Decision Options

Option A: Use real timers everywhere - 🎯 3   🛡️ 3   🧠 2, about
100-250 LOC.

- Easy.
- Tests are flaky and background tabs behave differently.

Option B: Component-local fake clocks - 🎯 5   🛡️ 5   🧠 4, about
300-800 LOC.

- Better in tests.
- Each component drifts in timing behavior.

Option C: Shared deterministic scheduler abstraction - 🎯 9   🛡️ 9   🧠 7,
about 900-1700 LOC.

- Accepted direction.
- Timing behavior is testable, cancelable, and policy-aware.
- Background and reduced-motion behavior can be modeled.

## Accepted Direction

Headless should route time through a `HeadlessScheduler`.

Scheduler supports:

- monotonic time;
- wall-clock time only when needed;
- timers;
- debounces;
- throttles;
- animation frames;
- idle tasks;
- cancellation;
- deterministic test advancement;
- visibility state;
- reduced motion policy.

## Time Classes

Classes:

- `interactionDelay`;
- `typeaheadWindow`;
- `searchDebounce`;
- `announcementThrottle`;
- `toastDuration`;
- `tooltipDelay`;
- `operationTimeout`;
- `retryBackoff`;
- `animationDuration`;
- `confirmationExpiry`.

Each class declares default, min, max, and accessibility policy.

## Visibility Rules

Background or hidden states can change timer behavior.

Rules:

- do not assume animation frames keep firing while hidden;
- do not expire destructive confirmation solely because tab was hidden unless
  policy says so;
- pause decorative motion while hidden;
- keep durable operation state outside UI timers;
- on resume, reconcile time-sensitive UI state.

## Cancellation Rules

Every scheduled task must be cancelable by owner scope.

Cancel on:

- component dispose;
- route exit;
- overlay close;
- operation cancellation;
- policy change;
- test teardown.

No timer may dispatch command after owner scope is invalid.

## Clean Disk Requirements

Clean Disk timing:

- search debounce;
- scan progress milestone announcement;
- stale delete plan expiry;
- toast duration;
- reconnect retry display;
- cleanup confirmation state;
- progress animation under reduced motion.

Rules:

- stale cleanup validation is based on daemon facts, not UI timer only.
- progress announcements are throttled deterministically.
- hidden web tab does not fake scan completion.

## API Shape Sketch

```text
HeadlessScheduler
  now()
  schedule(delay, task)
  debounce(key, delay, task)
  throttle(key, interval, task)
  animationFrame(task)
  cancel(scope)
  setVisibility(state)

ScheduledTask
  id
  scope
  class
  dueAt
  cancelPolicy
```

## Conformance Scenarios

- search debounce fires once after deterministic advance;
- route exit cancels pending tooltip;
- hidden tab pauses decorative animation;
- progress announcement throttle does not spam;
- retry backoff can be tested without real sleep;
- stale confirmation cannot dispatch after dispose;
- reduced motion skips animation frame dependency;
- operation timeout emits status, not direct destructive command.

## Failure Catalog

- tests sleep real time;
- timer fires after widget disposed;
- background tab changes operation result assumption;
- animation completion required for state update;
- toast duration ignores pause or focus;
- retry backoff cannot be cancelled;
- confirmation expires while hidden with no policy;
- announcement throttle differs by component;
- wall clock skew breaks timeout;
- scheduler stores product secrets in task keys.

