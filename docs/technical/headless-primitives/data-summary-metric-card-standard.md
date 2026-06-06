# Data Summary Metric Card Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `<output>` element: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/output
- MDN `status` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN `meter` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/meter_role
- MDN `progressbar` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/progressbar_role
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers metric cards, KPI summaries, counters, totals, status
summaries, mini meters, scan totals, cleanup candidate totals, skipped counts,
throughput values, elapsed time, and compact dashboard facts.

It does not cover charts. Visualization has a separate standard.

## Decision Options

1. `MetricSummary` primitive with value facts, freshness, trend, and severity -
   🎯 9   🛡️ 9   🧠 7, roughly 700-1500 LOC.
   Best fit. It gives one contract for numbers that users may rely on for
   cleanup and scan decisions.
2. Render metrics as ordinary text/cards -
   🎯 5   🛡️ 5   🧠 3, roughly 200-600 LOC.
   Quick visually, but weak for freshness, approximation, status semantics, and
   accessibility.
3. Treat every metric as live status -
   🎯 3   🛡️ 4   🧠 4, roughly 300-700 LOC.
   Over-announces changes and makes scanning noisy.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- metric id;
- label;
- value;
- unit;
- precision;
- value kind: exact, estimated, approximate, unknown, stale;
- freshness timestamp or version;
- severity;
- trend/change fact;
- privacy class;
- announcement policy;
- related details target.

Renderer owns:

- card layout;
- typography;
- icon;
- meter/progress visuals;
- compact/wide arrangement;
- color tokens.

Application owns:

- metric calculation;
- data source;
- refresh cadence;
- business meaning;
- user-facing copy;
- drilldown route.

## Value Kinds

Exact:

- backed by current authoritative source;
- safe to use in precise text.

Estimated:

- derived from incomplete or approximate data;
- label must expose estimate state.

Approximate:

- rounded for display;
- exact value may exist in details.

Unknown:

- value not available;
- do not render as zero.

Stale:

- previously known but no longer current;
- risky actions derived from it are disabled.

## Unit And Quantity Rules

Metric must distinguish:

- logical size;
- allocated size;
- reclaim estimate;
- exclusive reclaim estimate;
- item count;
- folder count;
- elapsed time;
- throughput;
- percentage.

Clean Disk must not present a reclaim estimate as exact freed space when storage
accounting confidence is low.

## Announcement Rules

Announce when:

- metric is user-triggered result;
- metric crosses an important state boundary;
- cleanup candidate total becomes stale;
- skipped/error count changes from zero to non-zero.

Do not announce:

- every throughput tick;
- every scanned byte;
- every elapsed second;
- visual-only pulse animations.

## Visual Rules

Metric cards must not rely on:

- color alone for severity;
- size alone for priority;
- icon alone for meaning;
- glow/gradient for status.

They should include:

- stable label;
- visible value;
- unit;
- estimate/stale marker;
- details affordance when value needs explanation.

## Clean Disk Usage

Top summary row:

- total scanned;
- largest folder;
- cleanup candidates;
- skipped/protected;
- errors if present.

Bottom status:

- files scanned;
- elapsed time;
- throughput;
- errors;
- skipped.

Details pane:

- selected node size;
- item count;
- category breakdown.

## Privacy Rules

Metric labels and values usually have low privacy risk, but related details may
contain paths, query text, app names, or provider names. Headless metrics must
classify:

- value;
- label;
- details target;
- diagnostic payload.

## Conformance Scenarios

- exact and approximate size are distinguishable;
- unknown value is not displayed as zero;
- stale metric disables dependent destructive command;
- skipped count uses warning semantics beyond color;
- changing throughput is not announced every tick;
- metric card has accessible label and value;
- details target opens through link/action standard;
- high contrast preserves severity cues.

## Failure Catalog

- Approximate reclaim estimate displayed as exact.
- Error count hidden in red-only badge.
- Metric card has no accessible name.
- Throughput live region spams screen reader.
- Unknown metric rendered as `0 GB`.
- Cleanup candidate metric enables delete without current plan.
