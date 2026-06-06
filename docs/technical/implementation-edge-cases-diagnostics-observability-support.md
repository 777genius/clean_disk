# Implementation Edge Cases - Diagnostics, Observability, And Support Bundles

Last updated: 2026-05-13.

This document records edge cases for logs, traces, metrics, crash reports, support bundles, telemetry, diagnostics UI, and support workflows.

Clean Disk scans private local filesystems. That means diagnostics are dangerous by default. File paths can reveal customer names, project names, medical/legal topics, repositories, browser profiles, cloud folders, usernames, build systems, and secrets accidentally embedded in names. A cleanup receipt can reveal what the user deleted. A crash dump can contain daemon tokens or scan tree memory. A metric label can accidentally become a database of every path ever scanned.

## Sources Reviewed

- OWASP, [Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html). Relevant points: session IDs, access tokens, secrets, sensitive personal data, and often file paths should not be logged directly; data may need masking, sanitization, hashing, encryption, or de-identification.
- OWASP MAS, [Insertion of Sensitive Data into Logs](https://mas.owasp.org/MASWE/MASVS-STORAGE/MASWE-0001/). Relevant points: application logs can expose sensitive user and system data, including tokens and PII.
- OpenTelemetry, [Logs Data Model](https://opentelemetry.io/docs/specs/otel/logs/data-model/). Relevant points: logs have normalized severity, timestamps, trace context, resource, scope, body, and attributes.
- OpenTelemetry, [Semantic Conventions](https://opentelemetry.io/docs/concepts/semantic-conventions/). Relevant points: common attribute names reduce ad hoc telemetry shape drift across traces, metrics, logs, and resources.
- Prometheus, [Instrumentation best practices](https://prometheus.io/docs/practices/instrumentation/). Relevant points: metrics with cardinality over 100 or potential to grow that large should trigger alternate designs; inner loops should limit metrics overhead.
- Prometheus, [Metric and label naming](https://prometheus.io/docs/practices/naming/). Relevant points: labels should not store high-cardinality unbounded values such as user IDs, email addresses, or similar unbounded sets.
- Rust `tracing`, [crate documentation](https://docs.rs/tracing). Relevant points: structured spans and events preserve causality across async tasks better than plain log lines.
- Google SRE Book, [Monitoring distributed systems](https://sre.google/sre-book/monitoring-distributed-systems/). Relevant points: latency, traffic, errors, and saturation are the four golden signals for user-facing systems.
- Microsoft Learn, [Collecting user-mode dumps](https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps). Relevant points: full user-mode dumps can be collected locally after crashes and require explicit configuration.
- Apple Developer, [Acquiring crash reports and diagnostic logs](https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs). Relevant points: crash reports and diagnostic logs are a normal debugging path, but they must be treated as diagnostic artifacts.
- Sentry docs, [Scrubbing Sensitive Data](https://docs.sentry.dev/platforms/javascript/guides/nextjs/data-management/sensitive-data/). Relevant points: sensitive data should be scrubbed before leaving the local environment when possible; server-side scrubbing is a fallback, not a substitute for SDK-side policy.
- Chromium, [Crash reports](https://www.chromium.org/developers/crash-reports/). Relevant points: Crashpad can gather exception state, call stacks, stack memory, and loaded modules.

## Severity Scale

- `P0` - can leak daemon auth tokens, raw file paths, full scan tree, delete receipts, crash memory, or user-private data outside the machine.
- `P1` - can create support burden, unbounded telemetry cardinality, unusable logs, missing audit data for destructive actions, or impossible debugging after failures.
- `P2` - can reduce performance, create noisy diagnostics, hide root cause, or make support bundles too large.
- `P3` - polish, support ergonomics, or future observability improvements.

## Core Principle

Redact before export. Classify before logging. Measure without naming private things.

Diagnostics must be useful, but not at the cost of trust. Clean Disk should assume:

- every path is potentially sensitive;
- every filename is potentially sensitive;
- every query string is potentially sensitive;
- every daemon token is secret;
- every delete receipt is private user data;
- every crash dump may contain memory that was never intended for diagnostics;
- every metric label can become a long-lived database key.

## Top 3 Decisions

1. Central diagnostic data classification for every DTO/log/metric field - 🎯 10 🛡️ 10 🧠 6, roughly 700-1800 LOC across typed field wrappers, schema docs, redaction tests, and log helpers.

   Best first move. It prevents every subsystem from inventing its own "safe enough" logging rule.

2. Explicit support bundle generator with redaction preview and manifest - 🎯 9 🛡️ 9 🧠 7, roughly 1000-2600 LOC across bundle schema, redactors, UI preview, size caps, tests, and export workflow.

   This makes support possible without asking users to send arbitrary logs or screenshots.

3. Optional crash/telemetry pipeline behind local scrubbers and user consent - 🎯 7 🛡️ 7 🧠 8, roughly 800-2200 LOC depending on provider, symbolication, consent UI, upload queue, DSN config, and privacy review.

   Useful later, but not required for MVP. Local diagnostics and support bundles should come first.

## Diagnostic Data Classification

### Problem - `P0`

Without field classification, logs and support bundles will leak private data through ordinary development habits:

- `debug!("{:?}", dto)`;
- automatic request/response logging;
- crash breadcrumbs;
- error chains containing paths;
- metrics labels using paths;
- traces with span fields like `path = /Users/...`;
- support bundle zip that includes raw session JSON.

### Required Classification

Every diagnostic field should map to one of:

```text
public_safe:
  app version, OS family, architecture, feature flags, schema version

operational_safe:
  counts, durations, queue depth, error category, capability booleans

user_sensitive:
  paths, filenames, usernames, search text, project names, cloud account hints

destructive_sensitive:
  delete plan items, cleanup receipts, restore hints, quarantine paths

secret:
  daemon token, pairing secret, auth headers, CSRF token, API keys, local session cookie

raw_debug_only:
  OS error payloads, stack traces, pdu raw output, crash breadcrumbs, unredacted adapter state
```

### Mitigation

- DTOs used in logs implement safe diagnostic rendering separately from `Debug`.
- Do not log `Debug` output of domain/application DTOs by default.
- Path-like types expose:
  - `display_for_ui`;
  - `redacted_for_support`;
  - `fingerprint_for_correlation`;
  - `raw_for_local_operation`.
- Support bundle redaction is schema-aware, not regex-only.
- Unknown fields in bundle export are redacted by default.
- Tests fail if secret fields appear in logs/support output.

## Path Redaction

### Problem - `P0`

Paths are the core data of Clean Disk and also the core privacy risk.

Examples:

```text
/Users/alex/Clients/Acme-Lawsuit/medical-records
/Users/alex/Projects/stealth-startup
/Users/alex/Downloads/passport_scan.pdf
C:\Users\Alex\OneDrive - Employer\Layoffs\planning.xlsx
```

Even if content is never read, path names can reveal enough.

### Redaction Levels

```text
none:
  raw local only, never exported automatically

home_relative:
  ~/Library/Caches
  good for user-facing UI

category_only:
  {home}/Library/Caches
  {downloads}/large-file.iso
  good for support bundles

fingerprint:
  path_hash = hmac(local_support_salt, normalized_path)
  good for correlating repeated errors without naming path

depth_shape:
  {home}/.../.../Caches
  useful when hierarchy depth matters
```

### Required Mitigation

- Default support bundle uses `category_only` plus local fingerprints.
- Raw export requires explicit separate confirmation.
- Raw export should say it can expose private path names.
- Path fingerprints use a per-bundle random salt unless cross-bundle correlation is explicitly needed.
- Do not use unsalted hashes for paths. Common path names are guessable.
- Redaction preserves enough structure for support:
  - root type;
  - volume/mount category;
  - path depth;
  - extension category only when safe;
  - error category;
  - stable local fingerprint within one bundle.

## Log Policy

### Problem - `P1`

Logs that are too sparse are useless. Logs that are too rich are privacy leaks and performance problems.

### Required Rules

Production logs:

- no daemon tokens;
- no auth headers;
- no raw paths;
- no raw search text;
- no full scan tree;
- no per-file scan log;
- no delete target raw path;
- no crash memory;
- no request bodies by default.

Allowed production fields:

- session ID if opaque and non-secret;
- operation ID;
- request ID;
- stable error code;
- redacted path category;
- counts;
- durations;
- queue depths;
- selected resource profile;
- adapter capability flags.

Local debug logs:

- can be more detailed only after explicit user action or development build config;
- stored locally;
- retention-limited;
- clearly marked as potentially sensitive if exportable.

### Log Level Semantics

```text
TRACE:
  disabled by default
  local development only
  no raw secrets even in dev

DEBUG:
  local development and explicit diagnostic sessions
  redacted paths unless raw mode is explicitly enabled

INFO:
  lifecycle events, scan start/finish, delete operation summary

WARN:
  recoverable problems, degraded capabilities, skipped important paths

ERROR:
  failed operation, daemon internal error, adapter failure

FATAL:
  process cannot continue safely
```

### Edge Cases

- Newlines, tabs, terminal escapes, and control characters in filenames can forge log lines.
- Windows paths can contain reserved names and alternate data stream syntax.
- Unicode bidi markers can make a path visually misleading.
- URL query strings can include local session tokens if we ever put them there. We should not.
- Browser console logs can be copied into bug reports, so web UI logs follow the same rules.

## Structured Tracing

### Problem - `P1`

Plain log lines lose context across async tasks, scan workers, WebSocket fanout, query handlers, and cleanup adapters.

### Required Mitigation

Use structured tracing in Rust for daemon/server internals:

```text
span scan_session
  fields:
    session_id
    target_kind
    resource_profile

span scanner_adapter
  fields:
    adapter = pdu
    thread_budget

span query_children
  fields:
    request_id
    session_id
    page_size
    sort_key

span cleanup_operation
  fields:
    operation_id
    plan_id
    item_count
    adapter
```

Forbidden span fields:

- raw path;
- raw filename;
- raw query text;
- auth token;
- full DTO debug dump;
- serialized receipt contents.

### Trace Sampling

- Always keep lifecycle/error spans.
- Sample high-volume query spans if needed.
- Never create one span per filesystem entry in production.
- Scan adapter can aggregate per-directory error categories rather than per-file trace events.

## Metrics Cardinality

### Problem - `P0`

Metrics labels can silently become a private database and can also destroy monitoring performance.

Bad metrics:

```text
clean_disk_scan_path_bytes{path="/Users/alex/Clients/Acme"} 123
clean_disk_error_total{file="/Users/alex/secret.pdf"} 1
clean_disk_query_latency{query="passport"} 34
```

Good metrics:

```text
clean_disk_scan_duration_seconds{profile="balanced", target_kind="home"} 42
clean_disk_scan_skipped_total{reason="permission_denied"} 17
clean_disk_query_latency_ms{query_kind="tree_children"} 12
clean_disk_event_queue_depth{queue="session_fanout"} 5
```

### Required Rules

- No path labels.
- No filename labels.
- No username labels.
- No search text labels.
- No session ID labels in exported metrics unless metrics are local-only and bounded.
- No operation ID labels in long-lived metrics.
- Use error categories, target kinds, platform, profile, adapter, and capability flags.
- Keep label value sets bounded and documented.

### Golden Signals For Clean Disk

Adapt Google SRE's four signals:

```text
latency:
  API request latency
  page query latency
  cancellation latency
  delete operation step latency

traffic:
  scan sessions started
  page queries
  WebSocket clients
  cleanup operations

errors:
  scan failures
  skipped paths by category
  stale delete plan failures
  transport errors

saturation:
  scanner worker utilization
  queue depth
  memory/RSS
  event lag
  max sessions reached
```

## Crash Reports And Minidumps

### Problem - `P0`

Crash reports are useful, but native dumps can include memory. Memory can contain:

- daemon tokens;
- paths;
- scan tree nodes;
- recently selected delete targets;
- search text;
- request payloads;
- environment variables;
- HTTP headers;
- stack-local strings;
- crash breadcrumbs.

### Required Mitigation

- No automatic third-party crash upload in MVP.
- Local crash records are opt-in for export.
- Crash report UI explains that native dumps may contain sensitive data.
- By default, support bundles include crash metadata, not raw minidumps.
- Raw minidump attachment requires explicit checkbox.
- If Sentry or another provider is later used, scrub before send.
- Do not attach full scan tree or support bundle automatically to crash events.
- Keep symbols/upload credentials out of shipped app config.

### Crash Record Tiers

```text
safe_crash_summary:
  app version
  OS
  architecture
  exception code
  redacted stack frames
  operation kind
  request/session IDs

local_debug_crash:
  full stack trace
  local logs
  redacted recent events

raw_native_dump:
  minidump/full dump
  explicit user export only
```

## Support Bundle Contract

### Problem - `P1`

When users report a bug, we need enough context to debug without asking for their entire filesystem story.

### Support Bundle Must Include

```text
manifest.json:
  schema_version
  app_version
  build_channel
  OS family/version
  architecture
  install mode
  generated_at
  redaction_mode

capabilities.json:
  scanner capabilities
  trash capabilities
  platform permission state
  resource governance capabilities
  transport mode

sessions.json:
  redacted scan summaries
  counts and durations
  skipped/error categories
  effective resource profile

operations.json:
  redacted cleanup operation summaries
  operation IDs
  result categories
  receipt IDs

logs.jsonl:
  structured redacted logs

metrics.json:
  local aggregate metrics
  no path labels

environment.json:
  dependency versions
  feature flags
  pdu adapter version
  Flutter/Rust app version
```

Optional, disabled by default:

```text
raw_paths_sample.json
native_minidump.dmp
pdu_raw_debug.json
verbose_debug_logs.jsonl
screenshots/
```

### Required UI

Support bundle flow:

1. Generate bundle.
2. Show what will be included.
3. Show redaction mode.
4. Let user exclude optional artifacts.
5. Export local file.

Do not auto-upload in MVP.

### Redaction Modes

```text
standard:
  default
  no raw paths
  no tokens
  no raw search text
  no raw receipt target paths

developer_local:
  available in dev builds
  can include raw paths
  never auto-upload

raw_explicit:
  user must confirm
  includes strong warning
  still never includes daemon token
```

Even `raw_explicit` must never include active daemon auth secrets.

## Telemetry Policy

### Problem - `P0`

Telemetry can be useful for product quality, but for Clean Disk it can become invasive quickly.

### MVP Decision

No external telemetry by default.

Local diagnostics are enough for early development. If telemetry is added later:

- explicit opt-in;
- no raw paths;
- no filenames;
- no query text;
- no delete target;
- no receipt contents;
- no daemon token;
- no full scan tree;
- no unique path fingerprints that can be correlated across users;
- no high-cardinality labels;
- clear settings to disable and delete local telemetry queue.

### Allowed Aggregate Telemetry Later

Potentially acceptable after consent:

```text
scan_completed:
  platform
  target_kind
  duration_bucket
  file_count_bucket
  byte_count_bucket
  skipped_count_bucket
  resource_profile
  adapter_version

scan_failed:
  platform
  target_kind
  error_code
  adapter_version

cleanup_completed:
  cleanup_kind
  item_count_bucket
  result_category
  adapter
```

No raw sizes if they can fingerprint a user. Use buckets.

## Audit Logs Vs Debug Logs Vs Receipts

### Problem - `P1`

These three things are easy to confuse:

- debug logs help developers;
- audit logs record important actions;
- receipts help users understand cleanup outcomes.

### Required Separation

```text
debug log:
  retention-limited
  redacted by default
  high volume possible

audit log:
  low volume
  records security/destructive events
  tamper-evident if remote/headless later
  no raw secrets

receipt:
  user-facing cleanup record
  durable according to cleanup policy
  private user data
  exportable with redaction
```

### Destructive Actions Must Record

- operation ID;
- user/client identity where applicable;
- timestamp;
- plan ID;
- confirmation state;
- adapter used;
- result category;
- item count;
- estimated reclaimed bytes;
- whether raw paths are stored locally;
- receipt ID.

The audit log should not be the only place that stores receipt data.

## Error Reporting To UI

### Problem - `P1`

Users need actionable errors. Developers need precise diagnostics. These are not the same payload.

### Required Error Shape

UI-safe error:

```text
code
severity
operation_id
retryability
safe_message
redacted_path_hint
help_action
```

Diagnostic-only error:

```text
code
platform_error_code
adapter
raw_os_error
stack_trace
redacted_context
```

### Rules

- UI never parses human `detail`.
- UI never shows raw stack traces by default.
- Support bundle can include diagnostic error data after redaction.
- Raw OS error text may contain paths, so redact before export.

## Web UI And Browser Console

### Problem - `P1`

Browser diagnostics are easy to leak:

- console logs copied into bug reports;
- source maps reveal internal code;
- query strings can leak tokens to history;
- service worker caches old diagnostic code;
- local daemon errors can include path data.

### Required Mitigation

- Never put daemon token in URL query string.
- Prefer local-only session token in header or secure local pairing mechanism.
- Browser console logs follow production redaction rules.
- Web UI request logging excludes bodies by default.
- Service worker should not cache support bundles.
- Source maps for release builds are controlled artifacts, not public by accident.
- Flutter web error reports use redacted DTOs.

## Remote And Headless Mode

### Problem - `P1`

Remote/headless mode changes diagnostics from "one user debugging local machine" to "admin operating a service".

### Required Mitigation

- Audit logs are first-class.
- Per-user action identity is recorded.
- Support bundles can be scoped to one session/target/user.
- Admin can disable raw support bundle export.
- Metrics are aggregate and low-cardinality.
- Logs are suitable for journald/systemd/container collectors.
- Container logs must not include raw paths by default.
- Request IDs propagate across HTTP/WebSocket operations.

### Extra Remote Rules

- Do not log auth headers.
- Do not log bearer tokens.
- Do not log remote client IP if privacy policy disallows it. If logged, classify it.
- Admin-configured retention policy applies to logs/audit/support exports.
- Failed auth and policy violations are logged as security events without leaking credentials.

## Performance Cost Of Diagnostics

### Problem - `P2`

Diagnostic code can ruin scan performance.

### Failure Modes

- trace event per file;
- metric increment with high-cardinality labels per node;
- formatting paths for logs in hot loop;
- redaction regex running per entry;
- synchronous log writes on scan worker;
- giant support bundle generation blocking UI/control plane.

### Required Mitigation

- No per-file production logs.
- No path redaction inside tight scan loop unless necessary for an emitted event.
- Aggregate counters in scanner and flush periodically.
- Structured logs are asynchronous or buffered safely.
- Support bundle generation runs as an operation with progress and cancellation.
- Support bundle has size caps and time caps.
- Benchmark with production diagnostics enabled.

## Support Bundle Size And Retention

### Problem - `P2`

Support bundles can become huge if they include scan snapshots, logs, metrics, and crash dumps.

### Required Mitigation

- Hard cap bundle size.
- Include summaries, not full scan tree.
- Include recent logs by time window and severity.
- Include last N sessions, not all history.
- Exclude raw minidumps by default.
- Compress bundle.
- Store generated bundles in user-chosen path or app cache with expiry.
- Do not keep support bundles forever in app data.

### Suggested Defaults

```text
logs:
  last 24 hours or last 10 MB, whichever is smaller

sessions:
  last 10 scan summaries

operations:
  last 20 cleanup operation summaries

metrics:
  aggregate last 7 days local counters

raw artifacts:
  disabled by default
```

## Security Events

### Problem - `P1`

Some events must be logged for safety, even if debug logging is off.

### Required Security Events

- daemon token generated/rotated, without token value;
- pairing attempt success/failure;
- invalid auth token attempt;
- origin allowlist rejection;
- CORS/PNA rejection;
- destructive operation requested;
- delete plan confirmed;
- delete revalidation failed;
- raw support bundle export requested;
- diagnostics raw mode enabled;
- remote/headless permission denied;
- config changed for resource/cleanup/security policy.

### Rules

- Security event logging cannot be fully disabled in production.
- Security logs do not include token values.
- Security logs use stable event IDs.
- Support bundle includes redacted security event summary.

## Symbolication And Debug Symbols

### Problem - `P2`

Native Rust crashes and Flutter crashes need symbols to be useful. But symbols and source maps can expose internal paths and implementation details.

### Required Mitigation

- Store release symbols/source maps in controlled build artifacts.
- Do not ship debug symbols publicly unless packaging policy allows it.
- Support bundle records build ID/version needed for symbolication.
- Crash summary includes module/build IDs but not source paths if avoidable.
- Release pipeline preserves symbol artifacts by version.

## Local Storage Of Logs

### Problem - `P1`

Local logs are still private data and can become disk usage themselves.

### Required Mitigation

- Logs stored under OS-appropriate app state/log directory.
- Log retention cap by size and age.
- Clearing app diagnostics does not delete cleanup receipts unless user asks.
- Uninstall policy explicitly says whether diagnostics are removed.
- Log files are created with user-only permissions where practical.
- Runtime tokens are never stored in log directory.

## Diagnostics UI

### Problem - `P3`

Powerful diagnostics can scare normal users or expose sensitive data on screen share.

### Required UX

Main UI:

- simple status;
- scan/deletion errors;
- "Create support bundle" action only when useful.

Advanced diagnostics:

- hidden behind settings or support action;
- shows redaction mode;
- uses copy buttons for safe IDs;
- warns before showing raw paths/logs.

### Useful Safe Diagnostics

- app version;
- scanner adapter version;
- transport mode;
- current resource profile;
- last scan status;
- skipped count by reason;
- queue pressure;
- permission capability state;
- "support ID" or operation ID.

## Clean Architecture Placement

### Domain

Allowed:

- no logging dependencies;
- pure domain event type names if needed;
- no telemetry provider;
- no redaction implementation.

Forbidden:

- `tracing`;
- OpenTelemetry SDK;
- Sentry SDK;
- file loggers;
- crash reporters;
- support bundle writer;
- platform crash APIs.

### Application

Allowed:

- diagnostic data classification policy;
- support bundle use case contract;
- diagnostic event ports;
- audit event intent;
- error code taxonomy.

Forbidden:

- provider-specific telemetry code;
- direct filesystem logging;
- direct crash dump collection;
- direct OpenTelemetry exporter calls.

### Infrastructure

Allowed:

- `tracing` subscriber;
- OpenTelemetry exporter if later added;
- local log writer;
- crash reporter adapter;
- support bundle archive writer;
- redaction engine implementation;
- audit log persistence.

### Interface

Allowed:

- diagnostics HTTP endpoints;
- support bundle download endpoint;
- health endpoint;
- local CLI diagnostic commands.

### Presentation

Allowed:

- diagnostics UI;
- support bundle preview;
- redaction mode selector;
- consent/settings UI.

## Testing Requirements

### Redaction Tests

- daemon token never appears in logs;
- auth header never appears in logs;
- raw path never appears in standard support bundle;
- search text never appears in telemetry/logs by default;
- delete target raw path never appears in audit log export;
- unknown DTO fields are redacted by default;
- control characters in filenames cannot forge log lines;
- bidi path markers are escaped or represented safely.

### Metrics Tests

- no metrics labels named `path`, `file`, `filename`, `username`, `query`, `token`;
- label values are bounded for exported metrics;
- scan of large fixture does not create per-node time series;
- metrics overhead benchmark is below threshold.

### Support Bundle Tests

- bundle includes manifest;
- bundle schema version is present;
- bundle size cap works;
- raw artifacts disabled by default;
- redaction preview matches actual bundle content;
- corrupted bundle generation fails without exposing raw paths in error message;
- support bundle generation can be cancelled.

### Crash Tests

- crash summary excludes active daemon token;
- crash summary excludes full scan tree;
- native minidump is not included in standard bundle;
- optional raw dump requires explicit flag;
- provider upload disabled without consent.

### Remote Tests

- invalid auth token logs security event without token;
- origin rejection logs origin category safely;
- raw support export event is audited;
- container stdout logs stay redacted.

## MVP Cut Line

Must have:

- structured logging in Rust daemon;
- stable request/session/operation IDs;
- no raw path logging in production;
- no daemon token logging ever;
- basic local log retention;
- redacted support bundle with manifest;
- redaction tests for tokens and paths;
- metrics with bounded labels;
- crash upload disabled by default.

Should have:

- diagnostics UI for support bundle generation;
- local aggregate metrics export;
- safe crash summaries;
- security event log;
- redaction preview.

Can wait:

- third-party crash reporting;
- external telemetry;
- OpenTelemetry collector integration;
- encrypted support bundle;
- remote admin diagnostics portal;
- tamper-evident audit log.

## Open Questions

- Do we want any external crash reporting in early beta, or only local support bundles?
- Should raw path export exist at all, or only developer builds?
- What is the exact support bundle schema versioning policy?
- Which local log directory is best for each OS/package mode?
- Do we need user-facing "delete all diagnostics" separate from "delete all app data"?
- Should support bundle include redacted screenshots, or is that too risky for MVP?

## Summary

📌 Diagnostics must be designed like a product feature, not sprinkled through the code. Clean Disk should use structured, low-cardinality, redacted observability by default; support bundles should be explicit, local, previewable, and schema-versioned; crash/telemetry upload should come later only behind consent and local scrubbing.
