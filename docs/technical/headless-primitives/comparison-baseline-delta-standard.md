# Comparison Baseline Delta Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `<ins>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/ins
- MDN `<del>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/del
- MDN `<time>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/time
- MDN `<data>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/data
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

## Scope

This standard covers compare views, before/after views, baseline snapshots,
delta badges, added/removed/changed markers, inline diffs, side-by-side diffs,
trend against a previous value, and compare result summaries.

It does not define domain diff algorithms. Application and backend compute
differences. Headless exposes them safely and accessibly.

## Problem

Comparison views are tempting for disk tools: "Library grew by 12 GB", "Caches
shrunk", "new large file appeared". But a delta is only meaningful relative to
a baseline. If the baseline is stale, from another target, or from a different
scanner capability, the UI can mislead the user into unsafe cleanup decisions.

## Decision Options

1. `ComparisonSurface` with explicit baseline/current/delta facts -
   🎯 9   🛡️ 9   🧠 8, roughly 800-1800 LOC.
   Best fit. It gives Headless a reusable compare primitive without owning
   product diff logic.
2. Inline visual badges only -
   🎯 5   🛡️ 5   🧠 3, roughly 200-500 LOC.
   Fast, but baseline, confidence, and stale semantics get lost.
3. Reuse audit/event feed for all compare views -
   🎯 5   🛡️ 6   🧠 4, roughly 300-700 LOC.
   Useful for chronological changes, but weak for row-by-row or metric
   comparison.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- comparison id;
- baseline label;
- current label;
- baseline timestamp;
- current timestamp;
- comparison scope;
- delta fact list;
- change kind;
- confidence;
- freshness;
- status announcement policy;
- focus and navigation model.

Renderer owns:

- inline badge visuals;
- side-by-side layout;
- added/removed/changed icons;
- color and trend tokens;
- compact compare layout;
- animation policy.

Application owns:

- baseline selection;
- snapshot compatibility;
- diff computation;
- user-facing explanations;
- safety policy for derived actions;
- persistence and history.

## Compare State Model

States:

- unavailable;
- baselineMissing;
- baselineLoading;
- currentLoading;
- compatible;
- incompatible;
- stale;
- partial;
- failed.

A compare surface must not show deltas without declaring:

- what is the baseline;
- what is current;
- whether units and accounting mode match;
- whether hidden or skipped data exists;
- whether the delta is exact, approximate, or unknown.

## Delta Kinds

Delta kinds:

- added;
- removed;
- changed;
- moved;
- renamed;
- increased;
- decreased;
- unchanged;
- unknown;
- conflict.

Disk usage-specific deltas:

- logical size change;
- allocated size change;
- exclusive reclaim estimate change;
- item count change;
- skipped count change;
- permission quality change;
- classification change.

## Accessibility Rules

Do not communicate deltas by color alone.

Each delta must include:

- change kind text;
- signed value when numeric;
- unit;
- baseline value if useful;
- current value if useful;
- confidence or estimate marker;
- source snapshot labels.

For web:

- use semantic insert/delete markup where the adapter renders document-like
  diffs;
- use grid/table semantics where comparison is tabular;
- announce compare completion as a status message, not by moving focus.

For Flutter:

- expose a combined semantic label for compact delta chips;
- keep visual arrows/icons redundant with text;
- do not animate changes when reduced motion is requested.

## Baseline Compatibility

Baseline and current must be marked incompatible when:

- scanner version changed in a breaking way;
- accounting mode changed;
- target changed;
- permissions changed enough to affect result quality;
- provider/cloud state changed;
- snapshot schema changed;
- baseline is older than product policy allows;
- current query excludes data included in baseline.

Incompatible compare can still be displayed read-only if it is clearly marked.
It cannot drive cleanup recommendations without fresh validation.

## Clean Disk Usage

Useful compare surfaces:

- scan history compare;
- folder growth compare;
- cleanup before/after receipt compare;
- recommendation impact compare;
- permission repair quality compare;
- skipped count compare.

Rules:

- historical nodes are not current cleanup targets;
- compare deltas never create a delete plan;
- stale baseline disables destructive derived commands;
- exact numbers remain available in details when compact display rounds values.

## Community API Sketch

```dart
final class RComparisonModel {
  const RComparisonModel({
    required this.id,
    required this.baseline,
    required this.current,
    required this.scope,
    required this.deltas,
    required this.state,
  });

  final String id;
  final RComparisonEndpoint baseline;
  final RComparisonEndpoint current;
  final RComparisonScope scope;
  final List<RDeltaFact> deltas;
  final RComparisonState state;
}

final class RDeltaFact {
  const RDeltaFact({
    required this.kind,
    required this.metric,
    required this.value,
    required this.confidence,
  });

  final RDeltaKind kind;
  final String metric;
  final Object? value;
  final RConfidence confidence;
}
```

## Conformance Scenarios

- baseline and current labels are discoverable;
- positive and negative deltas are not color-only;
- exact and approximate deltas are distinguishable;
- incompatible baseline blocks risky derived command;
- compare completion is announced once;
- compact delta chip has accessible name and value;
- deleted/added row semantics are preserved in exported artifact;
- historical node cannot be sent as current cleanup target.

## Failure Catalog

- Delta shown without baseline.
- Green/red color is the only change indicator.
- Historical snapshot item becomes delete authority.
- Different accounting modes are compared as if equal.
- Rounded compact delta hides exact value entirely.
- Incompatible compare still enables cleanup recommendation.
- Compare result is logged with private paths.

