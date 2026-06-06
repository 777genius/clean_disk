# Time Date Duration And Recency Standard

## Status

Accepted direction for Headless. Extends the locale unit and quantity formatting
standard. Not implemented yet.

## Source Standards

- MDN `time`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/time
- MDN `data`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/data
- MDN `Intl.DateTimeFormat`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat
- MDN `Intl.RelativeTimeFormat`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/RelativeTimeFormat
- MDN Internationalization guide: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Internationalization
- WCAG 2.2.1 Timing Adjustable: https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html

## Problem

Scan UIs and cleanup tools show many time facts: last modified, scan start,
elapsed time, estimated remaining time, stale snapshot age, receipt time,
daemon uptime, retry delay, cache retention, update age, and relative labels
such as `Today` or `Yesterday`. These values can become misleading across time
zones, sleep/wake, clock changes, stale snapshots, localization, and long-lived
web sessions.

Headless needs a time, duration, and recency contract.

## Decision Options

1. Pass formatted time strings - 🎯 4   🛡️ 4   🧠 1, about 20-80 LOC.
   Easy, but loses sorting, timezone, and stale-state semantics.
2. Add typed temporal display facts - 🎯 9   🛡️ 9   🧠 5, about
   350-900 LOC. Best fit.
3. Own full calendaring and scheduling logic - 🎯 3   🛡️ 5   🧠 10, about
   2500-7000 LOC. Outside Headless scope.

Accepted: option 2.

## Accepted Contract

Headless receives temporal facts:

```dart
final class RTemporalValue {
  final RTemporalKind kind;
  final String? instantIso8601;
  final int? monotonicMillis;
  final Duration? duration;
  final String? timezoneId;
  final RTemporalExactness exactness;
  final RRecencyPolicy recencyPolicy;
  final RPrivacyClass privacyClass;
}
```

The product decides source clock, freshness, retention, and authority.
Headless handles display, accessibility, sorting value, and stale-state UI.

## Temporal Kinds

```text
instant:
  absolute moment, such as modified time or receipt time

duration:
  elapsed or remaining time interval

relativeAge:
  now-relative label such as today or 3 minutes ago

monotonicElapsed:
  elapsed runtime based on monotonic clock

deadline:
  retry, timeout, token expiry, or operation cutoff

retentionWindow:
  cache, receipt, log, or support-bundle retention period
```

## Rules

- Sort by raw temporal value, not display text.
- Use monotonic clock for elapsed operation duration where available.
- Use wall clock for file timestamps, receipts, and user-visible dates.
- Relative labels must be refreshed or marked stale.
- Time zone should be explicit in details, exports, and support bundles.
- Unknown or unavailable timestamp is not `now`.
- Future timestamp needs warning when unexpected.
- Sleep/wake and system clock changes should not corrupt elapsed scan time.
- Short relative labels must have accessible absolute details when important.

## Web Mapping

For web adapters:

- `time` can expose machine-readable date or duration where valid.
- `data` can pair visible recency with raw sortable value.
- `Intl.DateTimeFormat` formats localized absolute dates.
- `Intl.RelativeTimeFormat` formats localized relative labels.

Flutter adapters should use platform localization and keep the raw facts in
view models for sorting, testing, and exports.

## Clean Disk Requirements

Clean Disk temporal values include:

- node last modified time;
- scan start and finish time;
- elapsed scan time;
- estimated remaining time;
- recent scan labels;
- cleanup receipt time;
- retry delay;
- daemon uptime;
- support bundle creation time;
- cache age and retention.

History and compare views operate on snapshot ids and scan timestamps. A
historical timestamp cannot imply current cleanup authority.

## Recency Policies

```text
static:
  display does not update automatically

ticking:
  periodically updates while visible

snapshotRelative:
  relative to scan snapshot time, not current now

staleMarked:
  display is marked stale after threshold

absoluteOnly:
  no relative label because precision matters
```

## Accessibility Rules

- Relative labels should have accessible absolute time when decision-critical.
- Elapsed time updates should be throttled.
- Countdown changes should not spam live regions.
- Date format follows locale, but machine-readable value remains stable.
- Ambiguous dates can show year and time zone in details.
- Timing-dependent destructive actions must not rely on a fast countdown only.

## Testing Requirements

- Locale change updates display without changing sort value.
- System clock jump does not break elapsed scan timer.
- Sleep and resume keep operation state coherent.
- Relative label marks stale or refreshes.
- Unknown modified time renders as unknown, not current date.
- Time zone appears in export and support bundle.
- Screen reader is not spammed by every second of elapsed time.

## Failure Catalog

- `Today` label persists after midnight in long-running web UI.
- Elapsed scan time goes backwards after clock correction.
- Deleted receipt timestamp loses timezone.
- Unknown modified time renders as current time.
- Relative time used as history identity.
- Countdown live region announces every second.

## Release Gates

- Temporal values are typed, not plain strings.
- Clean Disk distinguishes snapshot time from current time.
- Elapsed operation timers use monotonic time where possible.
- Relative labels have refresh or stale policy.
- Time fixtures cover timezone, DST, clock jump, unknown, and future values.

## Summary

Time facts need source, exactness, clock type, timezone, and recency policy.
Headless should render temporal values accessibly while product logic owns
freshness and authority.
