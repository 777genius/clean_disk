# Fixture Corpus And Benchmark Plan

## Status

Spec-level fixture and benchmark plan.

## Primary References

- Flutter performance profiling:
  https://docs.flutter.dev/perf/ui-performance
- Flutter integration performance tests:
  https://docs.flutter.dev/cookbook/testing/integration/profiling
- Flutter accessibility testing:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Purpose

Community-grade primitives need shared fixtures. Otherwise each package tests a
different reality.

## Fixture Categories

Small:

- 5 row table;
- 5 item menu;
- simple dialog;
- simple tooltip;
- 2 pane split.

State:

- disabled focusable item;
- disabled skipped item;
- selected plus focused row;
- loading row;
- error row;
- stale data state.

Scale:

- 10k rows;
- 50k rows;
- 100k rows;
- 100 columns;
- nested tree depth 12;
- wide path labels.

International:

- RTL locale;
- mixed LTR/RTL path;
- long German labels;
- CJK labels;
- emoji in display labels;
- high text scale.

Accessibility:

- keyboard-only fixture;
- screen reader label fixture;
- reduced motion fixture;
- high contrast fixture;
- target size fixture.

Clean Disk:

- synthetic scan tree;
- synthetic large Library node;
- synthetic skipped nodes;
- synthetic cleanup queue.

No real user paths.

## Benchmarks

TreeGrid:

- scroll 50k rows;
- hover 100 rows;
- toggle selection 100 times;
- expand/collapse nested tree;
- update progress footer while table is visible.

Menu:

- open/close 100 times;
- submenu hover and keyboard;
- typeahead.

Dialog:

- open/close with focus restore;
- validation state changes.

SplitPane:

- drag resize;
- keyboard resize.

## Metrics

```text
frameTiming
builtRows
builtCells
semanticNodes
rebuildCount
memoryDelta
announcementCount
eventCount
```

## Stop Rules

- Do not use real filesystem data in public fixtures.
- Do not call a primitive stable without at least small, state, accessibility,
  and relevant scale fixtures.
- Do not accept benchmark numbers without environment metadata.
