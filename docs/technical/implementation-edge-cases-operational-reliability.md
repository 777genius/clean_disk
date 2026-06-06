# Implementation Edge Cases - Operational Reliability

Last updated: 2026-05-12.

This file records operational edge cases for Clean Disk.

The other edge-case documents cover filesystem correctness, performance, product workflow, and security. This document focuses on how the product behaves as a long-running local/remote system: startup, shutdown, crashes, updates, compatibility, persistence, observability, overload, packaging, and release gates.

Related documents:

- [Implementation edge cases](implementation-edge-cases.md)
- [Implementation edge cases deep dive](implementation-edge-cases-deep-dive.md)
- [Implementation edge cases advanced scenarios](implementation-edge-cases-advanced-scenarios.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Rust architecture](rust-architecture.md)

## Sources Reviewed

- Tokio, [Graceful Shutdown](https://tokio.rs/tokio/topics/shutdown). Relevant point: graceful shutdown has three parts: decide when to shut down, notify tasks, and wait for them to finish. `CancellationToken` and task tracking are a good shape for this.
- Google SRE Book, [Addressing Cascading Failures](https://sre.google/sre-book/addressing-cascading-failures/). Relevant points: test overload paths, use load shedding, limit retries, and use randomized exponential backoff.
- SQLite, [Write-Ahead Logging](https://www.sqlite.org/wal.html) and [Atomic Commit](https://www.sqlite.org/atomiccommit.html). Relevant points: WAL changes durability/checkpoint behavior; WAL files are part of database state and should not be deleted casually.
- Flutter, [Deployment](https://docs.flutter.dev/deployment). Relevant point: Flutter desktop/web release paths are separate, so release and CI must be platform-aware.
- Microsoft Learn, [Restart Manager](https://learn.microsoft.com/en-us/windows/win32/rstmgr/about-restart-manager). Relevant point: installers/updaters may stop and restart apps/services, and apps should be prepared to save state for clean restart.
- Microsoft Learn, [MSIX overview](https://learn.microsoft.com/en-us/windows/msix/overview). Relevant points: Windows package identity, clean install/uninstall, signing, updates, and enterprise management affect lifecycle.
- Apple Developer, [Service Management](https://developer.apple.com/documentation/servicemanagement/) and archived [daemon lifecycle](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/Lifecycle.html). Relevant points: macOS helpers/agents/daemons have different lifecycles and launch behavior.
- IETF, [RFC 9110 HTTP Semantics](https://www.ietf.org/rfc/rfc9110.html). Relevant point: HTTP is stateless and extensible, but command/query semantics must be explicit.
- IETF, [RFC 9457 Problem Details for HTTP APIs](https://www.ietf.org/rfc/rfc9457.html). Relevant point: structured machine-readable API errors are better than ad hoc strings, but must avoid leaking internals.
- Microsoft Azure Architecture Center, [API design and versioning](https://learn.microsoft.com/en-us/azure/architecture/microservices/design/api-design). Relevant point: add fields compatibly, version breaking changes, and keep old clients in mind.
- OpenTelemetry, [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/). Relevant point: consistent telemetry naming improves correlation across logs, metrics, and traces.
- Rust `tracing`, [crate documentation](https://docs.rs/tracing/latest/tracing/). Relevant point: async Rust needs structured spans/events because tasks are multiplexed and ordinary logs are hard to follow.

## Severity Scale

- `P0` - must be handled before delete-capable releases.
- `P1` - should be handled before public beta or remote/headless mode.
- `P2` - useful polish or later hardening, but should not shape MVP too much.

## Top 3 Operational Decisions

1. Explicit daemon lifecycle controller - 🎯 9 🛡️ 9 🧠 6, roughly 250-700 LOC across process bootstrap, single-instance guard, startup discovery, shutdown phases, and tests.
2. Versioned protocol handshake with capability gates - 🎯 10 🛡️ 9 🧠 5, roughly 150-450 LOC across `/health`, client guard, feature flags, generated DTO compatibility, and tests.
3. Durable operation journal for destructive workflows only - 🎯 8 🛡️ 10 🧠 7, roughly 350-1000 LOC across receipt persistence, crash recovery, idempotency records, migrations, and filesystem crash tests.

## Core Operational Principle

Clean Disk should treat scanning as rebuildable and deletion as auditable.

Implications:

- scan sessions can be cancelled, lost, or rebuilt;
- live tree indexes are runtime state, not sacred data;
- delete plans, confirmations, operation status, and receipts are durable product state;
- crash recovery must never resume destructive work automatically;
- update/restart must preserve enough state to explain what happened;
- every long-running operation has an ID, lifecycle state, start/end timestamps, and a terminal outcome.

## Process Topology And Startup

### User-Owned Daemon, Not System-Wide Service By Default - `P0`

For MVP, the daemon should run as the current user. Running as root/admin makes scanning broader but makes cleanup and token compromise much more dangerous.

Implementation rule:

- default daemon runs with the same user identity as the UI;
- no admin/root elevation for normal scan or move-to-trash;
- platform helpers are added only for specific future use cases, not as the first architecture;
- if a system service is ever added, it becomes a separate product mode with separate authZ and audit.

Why:

- delete semantics depend on the current user's Trash and permissions;
- user-scoped app data, caches, and bookmarks are easier to reason about;
- remote/headless mode can still run as a dedicated service user without making desktop MVP privileged.

### Single Instance And Discovery File - `P0`

Desktop app, web UI, CLI, and updater can accidentally start multiple daemons.

Implementation rule:

- use a per-user runtime lock;
- discovery file includes pid, start time, protocol version, endpoint, token id, and expiry;
- stale discovery is verified by connecting and checking pid/start token, not by deleting blindly;
- second launcher should attach to the existing compatible daemon or fail with a clear recovery action;
- delete-capable commands are disabled if the UI cannot prove which daemon it is attached to.

Tests:

- double-click app twice;
- app starts while old daemon is shutting down;
- stale discovery file after crash;
- daemon pid reused by another process;
- web UI has old connection info in local storage.

### Port Allocation And Listener Binding - `P0`

Random loopback port is correct for local web UI, but it has operational traps.

Implementation rule:

- bind only `127.0.0.1` and `::1` for local mode;
- never fallback to `0.0.0.0`;
- port is selected at startup and written to discovery after listener is ready;
- if bind fails, start on another port and rotate token;
- web UI reconnect uses discovery, not hardcoded port;
- dev mode can use fixed port only behind an explicit config flag.

Failure cases:

- port occupied by stale daemon;
- port occupied by unrelated process;
- IPv4 works but IPv6 does not, or opposite;
- firewall/security product delays loopback listener;
- browser caches stale endpoint.

### Desktop Window Lifecycle Is Not Daemon Lifecycle - `P1`

On desktop OSes, closing the window, quitting the app, sleep, logout, and installer restart are different events.

Implementation rule:

- window close does not implicitly kill active scan/delete unless product policy says so;
- app quit asks the daemon for active operations and drains/cancels according to policy;
- delete operation blocks quit/update or requires explicit cancel;
- if UI disappears, daemon keeps enough status for reconnect;
- final UI state is recovered from daemon, not from Flutter memory.

### Web UI Bundle Must Match Daemon Capability - `P1`

If daemon serves the web UI, it can serve the matching bundle. If web UI is hosted separately, version skew becomes common.

Implementation rule:

- local daemon should serve a bundled web UI for the normal local flow;
- separately hosted web UI must perform protocol handshake before showing actions;
- delete-capable UI is hidden and server-rejected when `capabilities.cleanup.move_to_trash` is false;
- stale web UI shows "daemon incompatible" rather than trying best effort.

## Graceful Shutdown And Cancellation

### Cancellation Tree - `P0`

Tokio's shutdown model maps well to Clean Disk.

Implementation rule:

- daemon has a root cancellation token;
- each scan session has a child token;
- each delete operation has a stricter child token with non-retryable terminal state;
- WebSocket disconnect cancels only client event delivery, not the scan session by default;
- user cancel sends a domain command, not a raw task abort.

Forbidden:

- shared `AtomicBool` as the main cancellation mechanism;
- dropping `JoinHandle` and calling it cancelled;
- `std::process::exit` in normal shutdown;
- panic as cancellation.

### Shutdown Phases - `P0`

Shutdown should be explicit and observable.

Required phases:

1. Stop accepting new commands.
2. Emit daemon shutdown-started event to connected clients if possible.
3. Cancel or drain active scans according to policy.
4. Block or finish active delete operations according to policy.
5. Persist final operation statuses and receipts.
6. Close WebSocket streams with terminal status.
7. Remove discovery/lock files only after state is safe.
8. Exit with a meaningful code.

Timeout policy:

- scan drain timeout can be short;
- delete drain timeout must be conservative;
- forced shutdown records `interrupted` and never auto-retries delete.

### Abrupt Termination Cannot Be Made Safe By Graceful Code - `P0`

Power loss, `kill -9`, OS crash, forced reboot, battery drain, or process abort can happen.

Implementation rule:

- recovery assumes the previous process died at any instruction;
- startup scans runtime state for incomplete operations;
- incomplete scan sessions become `interrupted`;
- incomplete delete operations become `requires_review`;
- user must explicitly inspect and continue after destructive interruption;
- temporary files and runtime locks are cleaned only if they are app-owned.

### Sleep, Wake, And Time Accounting - `P1`

Elapsed time and throughput become misleading when the machine sleeps or throttles.

Implementation rule:

- use monotonic time for operation durations where possible;
- detect large inactivity gaps and mark status as `stalled_or_sleep_gap`;
- throughput is a recent estimate, not a contract;
- timers that enforce cancellation or token expiry must handle sleep/wake;
- UI should not animate fake progress during a stalled scanner.

## Update And Version Compatibility

### Protocol Handshake Is Mandatory - `P0`

Every client starts with a capability handshake.

Handshake should include:

- daemon version;
- protocol major/minor;
- minimum supported client protocol;
- feature flags;
- platform capabilities;
- cleanup capabilities;
- security mode: local, remote, read-only, delete-capable;
- event replay capability;
- current active operation summaries.

Implementation rule:

- breaking changes increment protocol major;
- additive response fields are allowed in minor versions;
- clients ignore unknown response fields;
- server rejects unknown destructive command fields;
- UI disables actions not explicitly advertised.

### Error Contracts Are Part Of Compatibility - `P1`

Plain text errors become technical debt quickly.

Implementation rule:

- HTTP errors use a stable problem-details-like shape;
- domain errors have stable `code`, `severity`, `retryable`, and `safe_to_retry`;
- internal exception names are not protocol strings;
- messages are user-facing but not parsed by clients;
- redacted diagnostics have a separate field.

Important error families:

- `protocol_incompatible`;
- `permission_denied`;
- `path_stale`;
- `identity_mismatch`;
- `operation_conflict`;
- `resource_exhausted`;
- `transport_backpressure`;
- `cleanup_requires_review`;
- `unsupported_platform_action`.

### Update During Active Work - `P0`

Installers and auto-updaters can interrupt the daemon while it has active sessions.

Implementation rule:

- active delete blocks update or makes update wait;
- active scan can be cancelled with clear user-facing state;
- updater asks daemon for a quiesce operation before replacing binaries;
- daemon writes `shutdown_reason = update` before exiting when possible;
- new daemon checks for interrupted prior version operations.

Tests:

- update requested during scan;
- update requested during delete plan validation;
- update requested during move-to-trash;
- old UI connects to new daemon;
- new UI connects to old daemon;
- downgrade after schema migration.

### Downgrade And Migration - `P1`

Users can install older builds during beta or roll back after issues.

Implementation rule:

- app data schema has explicit version;
- destructive receipts remain readable after downgrade if possible;
- cache can be invalidated, receipts cannot be silently deleted;
- downgrade that cannot read state must fail with recovery instructions;
- migrations are idempotent and tested from every supported prior version.

### Matching Web Bundle Strategy - `P1`

If web UI is hosted by daemon, deployment is simpler. If hosted separately, remote use is easier.

Top 3 options:

1. Daemon serves bundled web UI - 🎯 9 🛡️ 9 🧠 4, roughly 120-350 LOC. Best local UX and lowest skew risk.
2. Hosted web UI connects to daemon - 🎯 7 🛡️ 6 🧠 6, roughly 300-900 LOC. Better remote flexibility, but origin/token/PNA/version issues increase.
3. Both modes behind same transport contract - 🎯 8 🛡️ 8 🧠 7, roughly 500-1300 LOC. Best long-term product shape, but more testing and release discipline.

My current recommendation: implement option 1 first, keep protocol and UI code compatible with option 3.

## Persistence, Cache, And Recovery

### Live Scan Tree Is Rebuildable - `P0`

The scan tree can be huge. Persisting it too eagerly can create slow scans and fragile migrations.

Implementation rule:

- live tree stays in Rust memory for MVP;
- Flutter queries pages;
- optional scan history stores summaries, not full node graph;
- if full tree cache is added later, it is explicitly versioned and disposable;
- delete plans reference immutable scan snapshot identifiers and node identities.

### Delete Receipts Need Durable Boundaries - `P0`

The user needs a truthful record of what was attempted and what happened.

Implementation rule:

- receipt ID is created before executing a delete operation;
- operation journal records intent, plan hash, confirmation token id, and preflight status;
- each item outcome is appended or committed in small batches;
- final receipt is marked complete only after all item outcomes are known;
- interrupted receipts start in `requires_review` on next startup.

Do not:

- store receipts only in memory;
- write one giant JSON file at the end of a long delete;
- claim "moved to Trash" before the platform adapter confirms the item outcome;
- retry incomplete delete automatically after crash.

### SQLite WAL Is Useful But Needs Policy - `P1`

Drift/SQLite is a good fit for app cache and receipts, but WAL behavior matters.

Implementation rule:

- decide `synchronous` policy separately for rebuildable cache vs receipts;
- do not delete `-wal` or `-shm` files manually;
- checkpoint policy must avoid unbounded WAL growth;
- support bundle must include SQLite metadata only if redacted and explicitly selected;
- tests simulate crash with open WAL and verify recovery.

Suggested split:

- cache/history summaries: performance-oriented settings are acceptable;
- delete receipts/journal: durability-oriented settings are required;
- large live tree: avoid SQLite until proven necessary.

### App Data Directories Are Product State - `P1`

The app itself will create caches, receipts, logs, lock files, discovery files, and temp files.

Implementation rule:

- separate runtime state, cache, durable app data, logs, and exports;
- cleanup of app-owned temp files has a max age and exact prefix/owner checks;
- never scan/delete app state as ordinary cleanup candidate while daemon is active;
- "reset app data" is a separate settings action.

## Overload, Backpressure, And Resource Exhaustion

### Retrying Can Make Localhost Systems Worse - `P1`

Even local clients can overload the daemon if every UI tab retries aggressively.

Implementation rule:

- use bounded retries with randomized exponential backoff;
- retry budget is per client/session;
- destructive commands are never retried automatically by generic HTTP client middleware;
- UI reconnect resubscribes with last event id instead of restarting operations;
- failed query pages can retry, failed delete commands require explicit user action.

### Queue Length Is A Safety Signal - `P0`

If queues grow without bound, memory growth and UI stutter follow.

Implementation rule:

- event queues are bounded;
- progress events can be dropped/coalesced;
- terminal and error events cannot be silently dropped;
- slow clients are disconnected or forced to resync;
- daemon exposes queue lag metrics without path labels.

### Load Shedding Applies To Desktop Too - `P1`

Local daemon overload should degrade safely.

Implementation rule:

- reject new scans when active scan limit is reached;
- reject expensive query shapes with `resource_exhausted`;
- cap page size, search result size, and export size;
- health endpoint remains cheap under load;
- expensive debug endpoints require dev mode.

### Health Checks Must Not Become Work - `P1`

Health checks are for liveness/readiness, not detailed diagnostics.

Implementation rule:

- `/health` is cheap and never scans filesystem;
- `/capabilities` is cheap and mostly static;
- detailed diagnostics are explicit and rate-limited;
- update manager uses quiesce/status endpoint, not repeated heavy queries.

## Observability And Support

### Operation IDs Are The Backbone - `P0`

Every scan, delete plan, delete execution, export, support bundle, and update quiesce operation needs a stable ID.

Implementation rule:

- logs include operation id, session id, client id, and protocol version;
- UI displays operation id in support/debug views;
- receipts include operation id;
- WebSocket events include operation id;
- path data is redacted or represented by stable path refs.

### Structured Tracing, Not String Logs - `P1`

Async Rust logs without spans are hard to debug.

Implementation rule:

- use structured spans around command handlers, scanner adapter calls, index updates, query handlers, and cleanup adapter calls;
- do not create a span per filesystem entry in normal builds;
- sample or aggregate hot-loop diagnostics;
- all logs pass through redaction before export;
- library crates emit structured events but do not configure global subscribers.

### Metrics Must Be Low Cardinality - `P1`

Useful metrics:

- scan files per second;
- bytes observed per second;
- scanner worker count;
- open file permit pressure;
- event queue lag;
- dropped progress event count;
- page query latency;
- WebSocket reconnect count;
- delete item outcome counts;
- error code counts.

Forbidden metric labels:

- raw path;
- file name;
- extension if it can identify private content and telemetry is enabled;
- user name;
- token id;
- full error message.

### Support Bundle Is A Product Feature - `P1`

Support bundles can become accidental privacy leaks.

Implementation rule:

- support bundle has a manifest of included data classes;
- user can preview what will be included;
- default bundle includes config summary, version/capabilities, redacted recent logs, operation ids, and system capability summary;
- default bundle excludes raw paths, tokens, request headers, receipts, screenshots, and scan history;
- adding sensitive artifacts requires explicit opt-in.

## Packaging And Release Operations

### macOS Agent/Helper Choice Is A Product Decision - `P1`

macOS supports app-bundled helpers, login items, launch agents, daemons, XPC, and Service Management APIs.

Implementation rule:

- MVP starts daemon from the app in the user session;
- future auto-start helper must be user-scoped unless there is a clear system-service reason;
- helper binary is signed with the app;
- Full Disk Access and security-scoped bookmarks are tested on signed/notarized builds;
- daemon identity changes are treated as permission-affecting changes.

### Windows Packaging Affects Lifecycle - `P1`

Windows installer choice affects identity, update, services, SmartScreen, and clean uninstall.

Implementation rule:

- decide packaged vs unpackaged before public beta;
- installer/updater can quiesce daemon;
- daemon should not require firewall exception in local mode;
- uninstall removes app-owned runtime/cache files only according to user choice;
- receipts/history deletion on uninstall is explicit.

### Linux Has Multiple Product Modes - `P1`

Linux desktop packaging and headless server usage should not be forced into one assumption.

Implementation rule:

- desktop package declares whether it is sandboxed;
- headless tarball/container mode is scan-first and cleanup-limited;
- systemd user service can be considered later for background/headless usage;
- Trash support is capability-driven, not assumed;
- remote daemon defaults to read-only until authZ is designed.

### CI Must Match Release Targets - `P1`

Flutter desktop and native scanner behavior need platform-specific verification.

Implementation rule:

- macOS release artifacts are built/tested on macOS;
- Windows release artifacts are built/tested on Windows;
- Linux packages are tested per target package format when chosen;
- Rust scanner fixtures run on all three OSes;
- UI golden/screenshot checks cover wide and compact references.

## Adapter Failure Isolation

### `pdu` Adapter Failure Must Not Poison Domain State - `P0`

`pdu` is an adapter. It can fail, panic, change behavior, or expose an API mismatch.

Implementation rule:

- pdu results are converted into application DTOs at the adapter boundary;
- adapter errors are mapped to typed scanner failures;
- panic boundaries are considered around worker tasks where safe;
- partial pdu output is never treated as complete unless marked complete;
- pdu version is recorded in debug capabilities.

### Scanner Hot Path Is Not The Place For Policy - `P1`

Business decisions should not be embedded in traversal code.

Implementation rule:

- scanner reports facts and known filesystem states;
- recommendation engine interprets facts into risk tiers;
- cleanup workflow validates selected facts before action;
- UI never assumes "large" means "safe to delete".

### Adapter Replacement Must Be Testable - `P1`

We chose pdu first, but the architecture should survive replacement.

Implementation rule:

- create scanner contract tests independent of pdu;
- test fixture expected outputs are expressed in our domain/application language;
- pdu-specific quirks are documented in adapter tests;
- replacing pdu should not change Flutter DTOs or product workflow semantics.

## Remote And Headless Operations

### Remote Mode Needs Separate Operational Defaults - `P0`

Remote daemon can run on servers, CI, containers, or shared workstations.

Implementation rule:

- remote mode is explicit config;
- default remote mode is read-only scan/query;
- cleanup requires user identity, authZ, audit, retention, and platform policy;
- no browser-local token discovery in remote mode;
- rate limits and quotas are stricter than local mode.

### Multi-Client State Ownership - `P1`

Remote/headless mode can have multiple clients watching the same operation.

Implementation rule:

- operation owner is explicit;
- read observers are distinct from command issuers;
- cancelling a scan requires ownership or permission;
- delete plan confirmation is bound to user/session/plan hash;
- event replay and operation status are authoritative after reconnect.

### Containers And Ephemeral Filesystems - `P1`

Server mode might run in a container where filesystem view is not the host disk.

Implementation rule:

- report namespace/container context where detectable;
- avoid claiming "whole machine" unless daemon has that view;
- app data volume must be separate from scan targets;
- receipts should survive container restart if cleanup is enabled;
- scan of bind mounts needs mount boundary policy.

## Runbooks And Supportability

### Recovery Actions Should Be Predefined - `P1`

When things break, the UI should not invent vague advice.

Required recovery actions:

- restart daemon;
- reconnect to daemon;
- rescan target;
- discard interrupted scan;
- review interrupted cleanup;
- export redacted support bundle;
- reset app cache;
- keep receipts/history;
- open platform permission settings;
- reveal app data directory.

### Debug Mode Must Be Explicit - `P1`

Developer convenience can weaken security and privacy.

Implementation rule:

- debug endpoints are disabled in production;
- verbose logs require explicit runtime config;
- fixed port mode is dev-only;
- raw path logging is never enabled by default;
- debug UI labels the security mode clearly.

## Testing Matrix

### Lifecycle Tests

- start daemon, attach UI, close window, reopen UI;
- start two daemons concurrently;
- stale discovery file with dead pid;
- stale discovery file with pid reused by another process;
- quit during active scan;
- quit during active delete;
- forced kill during scan;
- forced kill during delete operation;
- sleep/wake during scan if platform automation allows;
- update quiesce during scan and delete.

### Protocol Compatibility Tests

- old UI connects to new daemon;
- new UI connects to old daemon;
- unsupported protocol major disables all commands;
- missing optional field works;
- unknown response field ignored;
- unknown destructive command field rejected;
- incompatible cleanup capability disables move-to-trash in UI and server.

### Persistence Tests

- crash with open receipt journal;
- crash after item moved to Trash but before receipt finalization;
- corrupt cache database can be rebuilt;
- corrupt receipt database requires recovery/export path;
- WAL files preserved across restart;
- migration from every supported prior schema version;
- downgrade behavior documented and tested.

### Overload Tests

- slow WebSocket client;
- reconnect storm;
- huge page size rejected;
- repeated search queries rate-limited;
- event queue overflow coalesces progress;
- terminal event survives backpressure;
- health endpoint remains cheap while scan is busy;
- scan rejected when active scan limit is reached.

### Packaging Tests

- macOS signed/notarized build permission flow;
- Windows install/update/uninstall with daemon running;
- Windows SmartScreen/Defender notes captured during beta distribution;
- Linux sandboxed package capability reporting;
- app data and receipts survive normal update;
- uninstall asks before deleting history/receipts.

## MVP Cut Line

Must be in MVP:

- user-owned daemon;
- single-instance guard;
- discovery file with endpoint/token/protocol metadata;
- explicit daemon lifecycle states;
- graceful shutdown phases;
- forced-crash recovery for scan sessions;
- no auto-resume for delete operations;
- protocol handshake and capability gates;
- bounded event queues;
- cheap `/health` and `/capabilities`;
- structured error codes;
- operation IDs;
- durable receipt/journal design before cleanup release;
- redacted support bundle basics before public beta.

Can wait:

- system service mode;
- auto-start helper;
- remote cleanup;
- full OpenTelemetry exporter;
- persistent full-tree cache;
- cross-device sync of history;
- permanent delete;
- systemd/launchd/MSIX service integration beyond release packaging needs.

## Summary

📌 Operational invariant: Clean Disk can lose scans, but it must not lose the truth about destructive work.

The strongest product shape is:

- scans are fast, cancellable, and rebuildable;
- delete workflows are explicit, journaled, and never auto-retried after crash;
- daemon startup/shutdown is owned by a lifecycle controller;
- UI and daemon negotiate protocol/capabilities before any action;
- overload degrades by dropping/coalescing progress, not by dropping terminal truth;
- support data is useful by default and private by default.
