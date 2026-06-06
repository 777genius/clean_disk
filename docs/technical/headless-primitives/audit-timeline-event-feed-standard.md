# Audit Timeline And Event Feed Standard

## Status

Accepted direction for Headless. Complements operation lifecycle, logs,
receipts, and live status standards. Not implemented yet.

## Source Standards

- WAI-ARIA APG Feed Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/feed/
- MDN ARIA `feed` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/feed_role
- MDN ARIA `article` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/article_role
- MDN ARIA `log` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/log_role
- MDN `time`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/time
- W3C PROV Overview: https://www.w3.org/TR/prov-overview/
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

## Problem

Operations produce event streams: scan started, permission denied, item skipped,
DeletePlan validated, item moved to trash, receipt persisted, daemon restarted,
support bundle exported. These are not just logs. Some are live status, some
are audit evidence, some are user-readable timelines, and some are low-level
diagnostics. Mixing them causes verbosity, privacy leaks, and weak receipts.

Headless needs an audit timeline and event-feed display contract.

## Decision Options

1. Render events as log lines - 🎯 4   🛡️ 4   🧠 2, about 80-200 LOC.
   Useful for debug, poor for audit and accessibility.
2. Add typed event feed and timeline semantics - 🎯 9   🛡️ 9   🧠 6,
   about 500-1200 LOC. Best fit.
3. Build an event sourcing system in Headless - 🎯 2   🛡️ 4   🧠 10,
   about 3000-9000 LOC. Wrong layer.

Accepted: option 2.

## Accepted Contract

Headless receives display-safe event entries:

```dart
final class REventFeedSemantics {
  final String feedId;
  final REventFeedKind kind;
  final String label;
  final bool live;
  final RFeedOrdering ordering;
  final int? totalCount;
}
```

```dart
final class REventEntrySemantics {
  final String eventId;
  final REventKind kind;
  final String title;
  final String? summary;
  final String? occurredAtIso8601;
  final REventSeverity severity;
  final RPrivacyClass privacyClass;
  final String? provenanceRef;
}
```

Headless never invents audit facts. It displays product-supplied facts.

## Feed Kinds

```text
liveOperation:
  current operation events

auditTimeline:
  durable evidence events

diagnosticLog:
  support/debug stream

receiptTimeline:
  operation receipt events

activityFeed:
  user-facing recent actions
```

## Event Kinds

```text
started:
  operation began

progress:
  meaningful milestone

decision:
  policy or validation decision

warning:
  non-fatal issue

error:
  failed step

sideEffect:
  mutation performed

persisted:
  receipt or artifact written

recovered:
  retry, resume, restore, or fallback completed
```

## Rules

- Live status is not the same as audit evidence.
- Low-level logs are not receipts.
- Audit events have stable ids and provenance refs.
- Live feeds throttle announcements.
- Timeline ordering is explicit.
- Event titles are localized; event kinds and ids are stable.
- Raw paths and tokens are redacted before Headless.
- Side-effect events need receipt linkage where product supports it.

## Clean Disk Requirements

Clean Disk uses event feeds for:

- scan progress event timeline;
- skipped item issue timeline;
- cleanup operation audit;
- receipt view;
- support bundle diagnostics;
- daemon lifecycle events;
- remote/headless activity view.

Delete events must come from product operation journal or daemon evidence, not
from UI row actions.

## Web Mapping

For web adapters:

- ARIA `feed` can represent dynamic article-like event streams;
- ARIA `log` can represent append-only diagnostic output where appropriate;
- `article` can represent standalone event entries;
- `time` exposes machine-readable timestamps;
- status messages announce high-level changes separately from full feed.

Flutter adapters should expose feed label, event count, item position,
severity, and current focus behavior.

## Accessibility Rules

- Live feed does not auto-read every event by default.
- Critical errors use appropriate status or alert channel.
- Users can navigate event entries by heading or item.
- Event severity is not color only.
- Timeline position and time are discoverable.
- Feed append does not steal focus.

## Testing Requirements

- Live scan feed throttles announcements.
- Audit timeline includes stable event ids.
- Receipt timeline links side effects to receipt evidence.
- Diagnostic log redacts private paths.
- Event ordering remains stable after reconnect.
- Feed append preserves focus and reading position.
- Severity has non-color cue.

## Failure Catalog

- Debug log line is treated as durable receipt evidence.
- Live feed announces thousands of events.
- Delete side effect has no event id or receipt link.
- Reconnect duplicates events without identity.
- Event title contains raw path.
- Warning is color only.
- Timeline order changes when locale changes.

## Release Gates

- Event feed primitives separate live, audit, diagnostic, receipt, and activity
  feeds.
- Clean Disk destructive events come from operation evidence.
- Live announcements are throttled.
- Event ids and provenance refs are stable.
- Privacy redaction is tested for event entries.

## Summary

Event feeds need meaning, ordering, severity, privacy, and provenance. Headless
should display live streams and audit timelines without pretending logs are
receipts or UI actions are evidence.
