# Live Announcement Broker Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN ARIA live regions: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions
- MDN `aria-live`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-live
- MDN `alert` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alert_role
- MDN `status` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN `log` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/log_role
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility

## Scope

This standard defines a shared Headless broker for user-facing announcements.

It applies to:

- status regions;
- alerts;
- toasts;
- logs;
- progress updates;
- validation errors;
- route changes;
- selection count changes;
- query result count changes;
- permission and degraded-state messages;
- destructive action state changes.

It does not replace visible UI. It coordinates what should be announced,
when, at what urgency, and with what privacy rules.

## Decision Options

Option A: Each primitive announces by itself - 🎯 3   🛡️ 3   🧠 3, about
80-200 LOC per primitive.

- Fast locally.
- Creates duplicate announcements and inconsistent priority.
- Hard to test across composed primitives.

Option B: App-level announcement callback only - 🎯 5   🛡️ 5   🧠 4,
about 250-500 LOC.

- Keeps Headless small.
- Too vague for public components.
- Every app invents throttle, politeness, and privacy policy.

Option C: Headless live announcement broker - 🎯 9   🛡️ 9   🧠 7, about
800-1500 LOC.

- Accepted direction.
- Primitives publish typed announcement intents.
- Adapter maps them to ARIA live regions, Flutter semantics, or platform APIs.
- Broker coalesces, suppresses, prioritizes, and redacts.

## Accepted Direction

Headless should define a `LiveAnnouncementBroker`.

Primitives do not call platform announcement APIs directly. They emit
`AnnouncementIntent` through an effect channel. The broker resolves:

- whether to announce;
- visible region target;
- politeness;
- interruption rules;
- coalescing;
- privacy redaction;
- duplicate suppression;
- testing trace.

## Announcement Kinds

Kinds:

- `status`: advisory update, polite by default.
- `alert`: urgent update, assertive by default.
- `logEntry`: ordered append-only information.
- `progressMilestone`: progress change worth announcing.
- `routeChange`: screen or route context changed.
- `selectionSummary`: count or selected target changed.
- `validationError`: user action needs correction.
- `capabilityChange`: permission or feature availability changed.
- `operationResult`: command completed, failed, cancelled, or skipped.
- `destructiveGuard`: safety block or confirmation requirement changed.

Each kind must declare:

- default politeness;
- interrupt policy;
- coalescing key;
- privacy class;
- minimum interval;
- replacement strategy.

## Politeness Policy

Politeness levels:

- `off`: visible only, no live announcement.
- `polite`: announce when assistive technology is idle.
- `assertive`: interrupt for urgent safety or blocking errors.
- `manual`: available through status region but not auto-announced.

Rules:

- ordinary scan progress is not assertive;
- validation error may be assertive only when it blocks current action;
- destructive safety block may be assertive if user attempted the action;
- route changes should be announced through title and focus movement first;
- repeated identical messages are suppressed.

## Coalescing Rules

The broker must coalesce:

- progress ticks;
- file count increments;
- rapidly changing filter result counts;
- repeated permission warnings;
- repeated connection retry notices;
- repeated validation errors for the same field.

A coalesced message should preserve the final meaningful state.

Clean Disk examples:

- "Scanning Library, 42%" can update visually every frame, but announce only
  milestone buckets.
- "17 skipped items" announces when count stabilizes or severity changes.
- search result count announces after debounce, not on every keystroke.

## Privacy Rules

Announcement text is user-facing data.

Broker must classify:

- raw path;
- file name;
- user name;
- daemon token;
- search query;
- operation id;
- error detail;
- count or size bucket.

Default rule:

- never announce daemon token;
- avoid raw paths unless the product explicitly permits it;
- prefer safe display names or redacted paths;
- support visible-only detail for sensitive information.

## Visible Region Rules

Announcements should map to visible or discoverable regions:

- status bar;
- alert banner;
- toast stack;
- log panel;
- details inspector;
- form error;
- route heading.

Invisible-only announcements are allowed only when the visual UI already
contains the state in a way that does not need an extra region.

## Adapter Requirements

Web DOM adapter:

- use persistent live region nodes created before updates;
- avoid duplicate `role=alert` plus `aria-live=assertive` where it causes
  double speaking;
- use `role=status` for polite status;
- use `role=log` for ordered appended logs;
- support atomic and relevant attributes through policy.

Flutter adapter:

- route announcements through a status effect or platform semantics adapter;
- use `Semantics` where persistent structure matters;
- avoid uncontrolled `SemanticsService.announce` from random widgets;
- support semantics test traces.

## Clean Disk Requirements

Broker must coordinate:

- scan started, paused, cancelled, completed;
- progress milestones;
- skipped and permission-degraded scan quality;
- selected node changed;
- cleanup queue count changed;
- delete plan validated or stale;
- move-to-trash completed or failed;
- daemon disconnected or incompatible;
- export completed.

Delete safety rule:

- announcement is never confirmation authority.
- a spoken or visible status cannot replace explicit confirmation UI.

## API Shape Sketch

```text
LiveAnnouncementBroker
  publish(intent)
  suppress(scope, reason)
  flush(scope)
  currentVisibleStatus(scope)

AnnouncementIntent
  kind
  scope
  messageKey
  arguments
  privacyClass
  politeness
  coalescingKey
  severity
```

## Conformance Scenarios

- progress updates do not announce every tick;
- alert interrupts only for urgent blocking state;
- same validation error is not repeated endlessly;
- route change updates title and focus before optional announcement;
- sensitive path is redacted according to policy;
- web live region exists before dynamic text update;
- Flutter semantics trace contains one announcement for one logical event;
- two primitives publishing same event produce one user announcement.

## Failure Catalog

- every component calling announcement APIs directly;
- assertive progress spam;
- duplicate alert speaking on iOS VoiceOver;
- raw paths or queries spoken by default;
- invisible-only announcement with no visible equivalent;
- relying on announcement as destructive confirmation;
- no debounce for search results;
- no test trace for announcements;
- route change announced but focus remains stale;
- status region overwritten before user can discover it.

