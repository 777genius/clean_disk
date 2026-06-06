# Instrumentation Telemetry And Privacy Budget Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN Performance API: https://developer.mozilla.org/en-US/docs/Web/API/Performance_API
- MDN User Timing API: https://developer.mozilla.org/en-US/docs/Web/API/Performance_API/User_timing
- MDN `PerformanceObserver`: https://developer.mozilla.org/en-US/docs/Web/API/PerformanceObserver
- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

## Scope

This standard defines how Headless primitives emit diagnostics, performance
marks, accessibility evidence, conformance traces, and optional telemetry
without leaking product data.

It applies to:

- TreeGrid rendering performance;
- virtualization;
- focus movement;
- keyboard command handling;
- announcement broker;
- export preparation;
- dialog lifecycle;
- renderer capability gaps;
- conformance tests;
- Clean Disk support diagnostics.

It does not define product analytics. It defines safe instrumentation hooks and
privacy budgets for reusable primitives.

## Decision Options

Option A: No instrumentation in Headless - 🎯 4   🛡️ 4   🧠 2, about
50-150 LOC.

- Small API.
- Hard to debug performance and accessibility in real apps.

Option B: Free-form logs and callbacks - 🎯 4   🛡️ 3   🧠 3, about
150-400 LOC.

- Flexible.
- High privacy risk and inconsistent naming.

Option C: Typed instrumentation events with privacy budget - 🎯 9   🛡️ 9
🧠 7, about 800-1600 LOC.

- Accepted direction.
- Events are structured, bounded, redacted, and testable.
- Production telemetry is opt-in adapter behavior, not Headless default.

## Accepted Direction

Headless must expose typed instrumentation events:

- performance;
- accessibility;
- interaction;
- capability;
- error;
- conformance;
- layout pressure;
- announcement;
- lifecycle.

Each event must declare:

- name;
- category;
- severity;
- privacy class;
- allowed fields;
- sampling policy;
- retention hint;
- production eligibility;
- test expectation.

## Privacy Budget

Headless must maintain a conservative privacy budget.

Forbidden by default:

- raw paths;
- raw queries;
- raw labels;
- user names;
- daemon tokens;
- file names;
- full command arguments;
- full tree sizes by node id if it can fingerprint user data;
- clipboard contents;
- export contents.

Allowed by default:

- component type;
- event kind;
- duration bucket;
- count bucket;
- boolean capability flags;
- renderer package id;
- error code;
- conformance scenario id;
- density bucket;
- text scale bucket.

## Event Naming Rules

Event names must be stable and low-cardinality.

Good:

- `treegrid.frame_budget_exceeded`;
- `focus.restore_failed`;
- `announcement.coalesced`;
- `capability.missing_renderer`;
- `layout.target_size_exception`;

Bad:

- `scan_/Users/belief/Library_finished`;
- `button_Copy /secret/path clicked`;
- `error_${localizedMessage}`;

## Performance Marks

Headless should expose performance marks for:

- component mount;
- first meaningful row render;
- viewport page render;
- keyboard command handling;
- focus restoration;
- announcement publish to adapter;
- export projection preparation;
- layout pressure calculation.

Adapters may map them to platform APIs like browser Performance API or Flutter
timeline tools.

## Accessibility Evidence

Instrumentation should support:

- semantic role emitted;
- accessible name presence;
- focus target path;
- announcement intent trace;
- target size exception;
- contrast validation result;
- keyboard command result;
- screen reader lab scenario id.

Do not store actual user labels by default.

## Error And Diagnostic Events

Errors should include:

- stable code;
- component type;
- primitive state;
- capability id;
- adapter id;
- recovery hint key;
- severity;
- safe context.

Errors should not include localized message as identity.

## Production Versus Development

Development mode may include richer traces, but must still respect explicit
privacy restrictions.

Production default:

- no network telemetry from Headless core;
- no raw user content;
- bounded event rate;
- sampling controlled by app;
- support bundle export requires user action;
- sensitive data stays out of logs.

## Clean Disk Requirements

Clean Disk needs instrumentation for:

- table frame budget;
- visible row rebuild count;
- query latency buckets;
- daemon event backlog;
- announcement suppression;
- focus restore failures;
- capability degradation;
- delete safety gate blocks;
- export projection time;
- support bundle redaction.

Clean Disk rule:

- no raw path, raw query, daemon token, or delete target path in production
  logs or telemetry.

## API Shape Sketch

```text
HeadlessInstrumentationEvent
  name
  category
  severity
  fields
  privacyClass
  samplingHint
  productionEligible

InstrumentationSink
  record(event)
  mark(name, fields)
  measure(name, start, end, fields)
```

## Conformance Scenarios

- performance event uses buckets, not raw path labels;
- missing renderer capability creates safe diagnostic;
- focus restore failure records reason code only;
- announcement coalescing trace does not include sensitive text;
- production sink is opt-in;
- support export redacts forbidden fields;
- event rate is bounded during fast scrolling;
- localized error text is not event identity.

## Failure Catalog

- logging raw file paths in component events;
- high-cardinality event names;
- production telemetry enabled by default from core;
- unbounded scroll event spam;
- localized labels used as diagnostic ids;
- accessibility trace storing raw names;
- support bundle including clipboard contents;
- performance mark detail leaking DOM or widget labels;
- app cannot disable instrumentation sink;
- conformance tests depending on production telemetry.

