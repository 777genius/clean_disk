# Security And Privacy Contract

## Status

Implementation contract. Not implemented yet.

## Primary Context

Headless is UI infrastructure, but Clean Disk displays sensitive local data:
paths, app names, account names, cloud sync folders, and cleanup targets.
Community users may also render secrets in tables, menus, dialogs, and logs.

## Core Decision

Headless primitives must treat labels and semantic text as potentially
sensitive. Debugging and conformance must not require raw product data.

## Data Classes

```text
PublicUiText
  generic labels such as "Scan", "Cancel"

UserContent
  file names, paths, search text, project names

SensitiveOperationalData
  daemon token, session id, delete target, full tree snapshot

DiagnosticMetadata
  counts, enum states, timings, package versions
```

Only diagnostic metadata is safe by default.

## Logging Rules

Headless diagnostics may log:

- component type;
- package version;
- missing renderer type;
- enum state;
- counts;
- timing buckets.

Headless diagnostics must not log:

- raw labels;
- raw paths;
- search strings;
- semantic text values;
- command contexts containing product ids;
- daemon/session/auth values.

## Semantics Privacy

Accessibility labels are intentionally exposed to assistive technologies. They
must still not leak into logs, performance counters, crash reports, or support
bundles by default.

## Command Context Privacy

Command context can contain logical keys. Keys may be product-sensitive.

Rules:

- command ids can be logged;
- command target keys are redacted by default;
- app can provide debug redaction labels in development;
- renderer never receives hidden sensitive context unless needed for display.

## Clipboard And Export

Headless must not perform clipboard/export actions directly. It emits command
intent. Application decides policy and confirmation.

Clean Disk example:

- `copyPath` command is app-owned;
- Headless context menu only emits command id and row target;
- app copies raw path if user invokes command.

## Test Fixtures

Use synthetic labels:

- "Item A";
- "Folder 001";
- "Row 42".

Do not use real local paths in conformance fixtures.

## Stop Rules

- Do not log semantic labels by default.
- Do not put raw paths in Headless error messages.
- Do not let renderer perform clipboard/delete/export directly.
- Do not expose daemon/session tokens through component state.
