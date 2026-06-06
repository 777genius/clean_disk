# Performance And Observability Contract

## Status

Implementation contract. Not implemented yet.

## Primary References

- Flutter performance profiling:
  https://docs.flutter.dev/perf/ui-performance
- Flutter DevTools performance:
  https://docs.flutter.dev/tools/devtools/performance
- WAI-ARIA Grid and Table Properties:
  https://www.w3.org/WAI/ARIA/apg/practices/grid-and-table-properties/

## Core Decision

Performance is part of the public component contract. Dense Headless primitives
must ship with measurable budgets and diagnostics hooks.

## Budget Categories

```text
buildBudget
layoutBudget
paintBudget
semanticsBudget
memoryBudget
eventBudget
announcementBudget
```

Each complex component should expose debug counters in test/dev mode.

## TreeGrid Budgets

Minimum target before stable:

- 50k synthetic rows scroll smoothly in profile;
- visible row widgets bounded by viewport plus overscan;
- hover rebuild affects one row;
- focus move rebuilds previous and next focus targets only;
- selection range does not allocate all backend rows;
- progress/status updates do not rebuild viewport;
- semantics nodes bounded by visible range.

## Event Coalescing

```text
CoalescingPolicy
  none
  perFrame
  trailingThrottle
  byKey
```

Use coalescing for:

- viewport range changes;
- progress announcements;
- hover updates;
- scroll-to-visible effects;
- resize drag updates if needed.

Do not coalesce:

- destructive command intents;
- focus restoration;
- keyboard activation;
- dialog close completion.

## Debug Counters

```text
HeadlessPerfSnapshot
  builtRows
  builtCells
  semanticNodes
  rebuildCountByPart
  visibleRangeEventCount
  commandDispatchCount
  droppedEvents
```

These are debug/test only and must not expose product data.

## Observability Privacy

Never log:

- raw paths;
- raw search text;
- daemon tokens;
- full row labels;
- delete target names.

Allowed:

- counts;
- durations;
- enum states;
- package versions;
- component ids without product identity;
- redacted failure categories.

## Test Gates

- synthetic large tree fixture;
- viewport adapter built count assertion;
- semantics node count assertion;
- hover rebuild assertion;
- progress update isolation;
- memory smoke test;
- reduced motion test;
- RTL layout performance smoke.

## Stop Rules

- Do not stabilize TreeGrid without performance gate.
- Do not log product labels in component diagnostics.
- Do not let status/progress events rebuild table rows.
- Do not expose performance counters in production by default.
