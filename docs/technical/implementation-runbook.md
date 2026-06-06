# Implementation Runbook

Last updated: 2026-05-16.

This file is the operational build plan for Clean Disk. It converts the
technical documentation map into an execution sequence.

Use it when starting implementation work, planning milestones, reviewing a PR,
or deciding whether a feature can move to the next phase.

## How This Runbook Relates To The Index

- [README](README.md) is the canonical documentation map.
- [Documentation map](documentation-map.md) explains source-of-truth routing and
  maintenance rules.
- [Documentation sitemap](documentation-sitemap.md) shows the grouped structure
  of all technical docs.
- [Phase reading guide](phase-reading-guide.md) gives phase-by-phase minimum
  reading, risk add-ons, expected output, and boundaries.
- [Task router](task-router.md) maps day-to-day task types to required docs,
  gates, and expected outputs.
- [Reading order checklist](reading-order-checklist.md) gives
  checkbox-style order for common scenarios and stop conditions.
- [Execution board](execution-board.md) gives row-by-row build deliverables,
  gates, workstreams, and excluded scope from zero to release.
- [Start-to-finish guide](start-to-finish-guide.md) gives one linear path across
  trains, milestones, phases, lanes, and gates.
- [Capability implementation matrix](capability-implementation-matrix.md) maps
  concrete product capabilities to train, milestone, phase, owner lane, gate,
  and excluded scope.
- [Clean Architecture implementation phases](clean-architecture-implementation-phases.md)
  gives the strict phase-by-phase order, steps, gates, and stop rules for
  protecting domain/application boundaries before adapters, protocol, UI, and
  cleanup.
- This file is the canonical execution order.
- [Release train map](release-train-map.md) defines what belongs to scan-only
  MVP, cleanup beta, signed desktop release, remote/headless, future remote
  cleanup, and support operations.
- [START_HERE](../../START_HERE.md) is the short recovery file.
- [Critical zones](critical-zones/README.md) are release gates and can block any
  step in this runbook.

Rules:

- do not implement from a research doc alone;
- convert accepted decisions into contracts, tests, or gates;
- keep domain/application layers independent from frameworks and adapters;
- do not advance a milestone if its exit gate is not testable.

## Product Build Shape

Clean Disk is built as one product with three implementation layers:

```text
Flutter UI
  talks to
Clean Disk Rust server
  composes
Reusable fs_usage_* Rust crates
  adapt
pdu and platform filesystem APIs
```

Accepted MVP constraints:

- one Rust daemon process with internal bounded worker pools;
- HTTP commands/queries plus plain WebSocket events;
- pdu as Rust library adapter, not CLI wrapper;
- Flutter does not hold full scan tree;
- remote/headless destructive cleanup is disabled until explicit authority
  model is proven;
- cleanup is a domain workflow with DeletePlan, identity revalidation, journal,
  receipts, and recovery states.

## Milestone Overview

| Milestone | Name | Main deliverable | Primary risk |
| --- | --- | --- | --- |
| M0 | Baseline | repo boundaries and architecture contracts are clear | coding against wrong architecture |
| M1 | Rust engine skeleton | reusable crates compile with clean domain/application boundaries | pdu or transport leaks inward |
| M2 | Scanner adapter and read model | scan tree converts into internal arena and paginated queries | memory blowup or wrong tree truth |
| M3 | Daemon protocol | HTTP/WebSocket sessions, commands, events, and reconnect contract | stale or unordered UI state |
| M4 | Flutter scan UI | scan target, progress, tree/table, search, details, responsive layout | UI stores too much or drifts from design |
| M5 | Cleanup safety core | DeletePlan, identity revalidation, receipt journal, low-disk safety | destructive side effect without proof |
| M6 | Recommendations and tool cleanup | safe evidence-backed cleanup advice and official tool adapters | false-positive or command side effects |
| M7 | Packaging and permissions | signed app/helper/daemon, permission UX, update/rollback policy | platform identity mismatch |
| M8 | Remote and diagnostics | read-only remote/headless, support bundle, telemetry/redaction policy | private data leak or remote authority bug |
| M9 | Release readiness | test matrix, benchmarks, crash/low-disk/update/destructive gates | shipping unproven safety claims |

## M0 - Baseline

Goal:

- lock the project direction before implementation.

Read:

- [Architecture decisions](architecture-decisions.md)
- [Architecture fit validation](architecture-fit-validation.md)
- [Architecture future risks](architecture-future-risks.md)
- [Future-proofing architecture gates](future-proofing-architecture-gates.md)
- [Rust architecture](rust-architecture.md)
- [Architecture principles research](architecture-principles.md)

Build:

- confirm app package boundaries;
- confirm Rust crate boundaries;
- confirm feature package shape;
- confirm dependency direction;
- confirm design references are visible from project docs.

Exit gate:

- no feature package imports another feature directly;
- domain/application do not import Flutter, Dio, Drift, pdu, transport, or
  generated bridge code;
- `docs/technical/README.md` and `START_HERE.md` remain in sync.

Stop if:

- a new dependency is added without checking freshness and stability;
- a convenience adapter starts living inside domain/application;
- MVP scope expands to FRB, gRPC, Socket.IO, local microservices, or hosted
  remote cleanup without reopening architecture decisions.

## M1 - Rust Engine Skeleton

Goal:

- create the reusable Rust core and server composition shape.

Read:

- [Rust architecture](rust-architecture.md)
- [Rust best practices research](rust-best-practices.md)
- [Critical zone Rust runtime execution](critical-zones/rust-runtime-execution.md)

Build:

- `fs_usage_engine` domain/application boundaries;
- scanner ports and metadata ports;
- read-model/query ports;
- cleanup domain types without platform side effects;
- `clean-disk-server` composition root skeleton;
- worker-pool abstraction and cancellation token shape.

Exit gate:

- reusable crates do not know Clean Disk HTTP routes, Flutter DTOs, or pdu
  concrete types;
- server owns runtime composition;
- blocking work has a dedicated execution lane;
- panic/cancel/shutdown behavior has a test plan.

Stop if:

- pdu types become public domain models;
- Tokio reactor threads are used for filesystem traversal;
- cancellation is represented as best-effort UI state only.

## M2 - Scanner Adapter And Read Model

Goal:

- prove fast scanning can feed a stable product read model.

Read:

- [pdu data model and adapter guide](pdu-data-model-and-adapter-guide.md)
- [pdu required capabilities audit](pdu-required-capabilities-audit.md)
- [pdu library deep validation](pdu-library-deep-validation.md)
- [Implementation edge cases pdu adapter integration](implementation-edge-cases-pdu-adapter-integration.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)

Build:

- pdu adapter crate;
- scan session aggregate;
- internal node arena;
- stable node IDs;
- parent/children indexes;
- top files/top folders indexes;
- search/sort/filter query path;
- pagination cursors;
- issue model for skipped paths, permissions, hardlinks, mount boundaries,
  symlinks, and changing files.

Exit gate:

- pdu imports are isolated to adapter crate;
- query response can page children without cloning full tree;
- memory profile is bounded for large trees;
- scan results include issue states instead of generic failure;
- Flutter can query tree pages without receiving the whole tree.

Stop if:

- pdu JSON or DataTree is sent directly to Flutter;
- node identity is just path string;
- skipped/permission errors disappear from the read model;
- hardlink and mount policies are implicit.

## M3 - Daemon Protocol

Goal:

- expose scanner/read-model safely through product protocol.

Read:

- [Implementation edge cases protocol data contracts](implementation-edge-cases-protocol-data-contracts.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Transport and client generation research](transport-client-generation-research.md)
- [Implementation edge cases concurrency state machines](implementation-edge-cases-concurrency-state-machines.md)
- [Implementation edge cases web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)

Build:

- HTTP commands and queries;
- WebSocket event stream;
- session lifecycle: create, start, cancel, query, dispose;
- event envelope with sequence, kind, session, and schema version;
- reconnect/resync path;
- bounded event buffering;
- error taxonomy;
- version/capability endpoint;
- local token/origin policy for daemon-served UI.

Exit gate:

- large integers are safe for Flutter web;
- protocol DTOs are not domain models;
- stale cursors and event gaps have typed errors;
- WebSocket reconnect cannot access unauthorized sessions;
- terminal events and safety errors are lossless or recoverable.

Stop if:

- raw route parsing leaks into repositories/widgets;
- WebSocket connection auth is treated as action auth;
- event stream can grow unbounded;
- old UI can send destructive commands that new daemon accepts blindly.

## M4 - Flutter Scan UI

Goal:

- make the core product surface usable and consistent with design references.

Read:

- [Feature UX benchmark](feature-ux-benchmark.md)
- [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md)
- [Frontend boundaries decision](frontend-boundaries-decision.md)
- [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md)
- [Cross-platform user experience playbook](cross-platform-user-experience-playbook.md)
- [Permission UX playbook](permission-ux-playbook.md)
- [Real product feature adoption playbook](real-product-feature-adoption-playbook.md)
- [Wide desktop reference](../design/references/clean-disk-wide-reference.png)
- [Compact narrow reference](../design/references/clean-disk-compact-reference.png)

Build:

- app shell route for scan screen;
- feature-scoped MobX stores for scan session, progress, viewport, selection,
  details, search/filter/sort, map projection, and cleanup queue;
- DTO mappers, command/use case boundaries, event-stream reconciliation, and
  platform-action ports for all scan UI side effects;
- target picker;
- scan progress/status strip;
- virtualized tree/table;
- details panel;
- search/filter/sort controls;
- scan-quality/permission states;
- `DiskUsageMapView` abstraction for optional treemap/sunburst/bar projections;
- compact layout;
- design-system components over Headless/Material primitives.

Exit gate:

- UI requests paginated data from Rust;
- long names and paths do not break layout;
- compact and wide layouts match saved references;
- selected row, details panel, and tree state use stable IDs;
- MobX stores own UI state and widgets stay lean renderers with granular
  `Observer` boundaries;
- widgets never import protocol DTOs, repositories, platform plugins, daemon
  route paths, or renderer adapter types directly;
- disk usage map projections use bounded Rust query results and sync selection
  back to the tree/details state;
- Headless limitations are reported before awkward workarounds.

Stop if:

- Flutter stores entire tree;
- widget-local state owns selection, expansion, queue, scan session, or delete
  authority;
- raw DTOs, platform plugins, HTTP/WebSocket clients, or daemon route strings
  reach widgets;
- MobX reactions can trigger destructive commands;
- visual map renderer becomes the source of truth for selection, cleanup, or
  filesystem identity;
- UI derives cleanup candidates from visible rows only;
- controls use explanatory in-app text instead of proper state/actions;
- layout depends on viewport-scaled font sizes.

## M5 - Cleanup Safety Core

Goal:

- make cleanup safe enough for local beta.

Read:

- [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md)
- [Implementation edge cases platform identity and delete revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md)
- [Critical zone restore quarantine undo safety](critical-zones/restore-quarantine-undo-safety.md)
- [Critical zone persistent operation journal receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md)
- [Reclaim accounting deep research](reclaim-accounting-deep-research.md)
- [Implementation edge cases storage accounting snapshots shared extents](implementation-edge-cases-storage-accounting-snapshots-shared-extents.md)
- [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md)

Build:

- DeletePlan aggregate;
- stale identity revalidation;
- platform Trash adapter abstraction;
- durable operation journal;
- receipt skeleton before side effects;
- per-item dispatch and outcome states;
- crash recovery inbox;
- low-disk reserve;
- reclaim confidence model;
- cleanup queue UI wired to daemon contracts.

Exit gate:

- cleanup cannot run without durable intent and receipt skeleton;
- dispatch marker is written before adapter call;
- unknown outcomes are represented;
- stale identity blocks item execution;
- reclaim UI never promises exact bytes without observed/proven evidence;
- crash tests cover item-boundary states.

Stop if:

- cleanup executes from path strings;
- receipt is finalized only at batch end;
- crash recovery auto-retries destructive side effects;
- low disk can drop journal or receipt writes.

## M6 - Recommendations And Tool Cleanup

Goal:

- add helpful cleanup intelligence without unsafe advice or command execution.

Read:

- [Implementation edge cases recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md)
- [Implementation edge cases tool-managed storage](implementation-edge-cases-tool-managed-storage.md)
- [Critical zone recommendation policy rule-pack safety](critical-zones/recommendation-policy-rule-pack-safety.md)
- [Critical zone tool command execution sandbox](critical-zones/tool-command-execution-sandbox.md)

Build:

- recommendation rule model;
- evidence model;
- risk tiers;
- stale recommendation invalidation;
- official tool cleanup adapters;
- command execution sandbox;
- dry-run/preview parity model;
- recommendation UI cards that feed DeletePlan, not direct deletion.

Exit gate:

- every recommendation has evidence, risk tier, and invalidation rule;
- official command adapters have executable identity, argv/env/cwd policy,
  output limits, timeout, and receipts;
- recommendations cannot bypass DeletePlan;
- tool-managed persistent data is not treated as ordinary cache.

Stop if:

- recommendation says "safe" without evidence;
- command output parsing decides deletion without receipt;
- PATH lookup can pick attacker-controlled executable;
- Docker volumes, Xcode Archives, Android AVDs, SDKs, package stores, or
  Homebrew Cellar are treated as generic cache.

## M7 - Packaging, Permissions, Updates

Goal:

- ship a trusted app/helper/daemon identity across OSes.

Read:

- [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md)
- [Permission UX playbook](permission-ux-playbook.md)
- [Implementation edge cases dependency supply chain governance](implementation-edge-cases-dependency-supply-chain-governance.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Critical zone update release rollback safety](critical-zones/update-release-rollback-safety.md)

Build:

- macOS package/signing/notarization plan;
- Windows installer/signing/SmartScreen plan;
- Linux package modes;
- app/helper/daemon identity model;
- permission preflight and repair UI;
- dependency governance gates;
- update quiesce and rollback flow.

Exit gate:

- scanner permission probe runs in same identity as scanner process;
- updater cannot replace binaries during active destructive operation;
- rollback preserves protocol compatibility and safety DB readability;
- dependency/license/vulnerability gates exist before release.

Stop if:

- external pdu binary becomes production scanner;
- app and daemon have different permission expectations;
- update can strand operation journal or receipt migrations;
- installer removes receipts/history without explicit user choice.

## M8 - Remote, Headless, Diagnostics

Goal:

- make non-local and support workflows explicit, scoped, and private by default.

Read:

- [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md)
- [Implementation edge cases diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md)
- [Critical zone remote/headless destructive cleanup authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md)
- [Critical zone support bundle diagnostics export privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md)

Build:

- remote/headless read-only profile;
- remote target scope model;
- auth/authZ policy port shape;
- audit event model;
- support bundle manifest;
- redaction profiles;
- diagnostics data classes;
- crash summary and logs policy.

Exit gate:

- remote/headless starts read-only;
- destructive remote capability is separate and disabled;
- every remote object ID is authorized server-side;
- support bundle is typed, bounded, redacted, consented, and useful;
- raw paths/tokens/headers/search text/receipts are not exported by default.

Stop if:

- `--listen 0.0.0.0` enables cleanup;
- local loopback token becomes remote auth;
- support bundle is a zip of logs and databases;
- crash report includes scan tree, delete queue, or raw paths by default.

## M9 - Release Readiness

Goal:

- prove the product before users rely on it.

Read:

- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)
- [Implementation edge cases resource governance](implementation-edge-cases-resource-governance.md)
- [Implementation edge cases search query indexing](implementation-edge-cases-search-query-indexing.md)
- [Implementation edge cases incremental scan and watchers](implementation-edge-cases-incremental-scan-watchers.md)
- [Implementation edge cases cloud network virtual filesystems](implementation-edge-cases-cloud-network-virtual-filesystems.md)
- [Implementation edge cases advanced scenarios](implementation-edge-cases-advanced-scenarios.md)
- [Critical zones index](critical-zones/README.md)

Build:

- fixture lab;
- large-tree benchmarks;
- destructive safety tests;
- crash/kill tests;
- low-disk tests;
- permission degradation tests;
- update/rollback tests;
- support export tests;
- resource profile tests;
- release checklist.

Exit gate:

- every enabled risky feature maps to tests;
- critical-zone gates are represented in CI or release checklist;
- beta disables unfinished destructive/remote capabilities;
- support bundle can debug failures without private data by default.

Stop if:

- only happy-path scan tests exist;
- destructive tests are manual-only;
- low-disk and crash tests are postponed until after cleanup release;
- release checklist cannot point to evidence for each safety claim.

## Minimal First Implementation Slice

If we want the smallest useful product slice, build only this:

1. M0 baseline.
2. M1 Rust engine skeleton.
3. M2 pdu adapter and read model for scan-only.
4. M3 HTTP/WebSocket read-only scan protocol.
5. M4 Flutter scan UI with progress, tree, details, search.

Explicitly exclude:

- cleanup execution;
- recommendations that imply deletion;
- remote/headless destructive mode;
- support bundle with receipts;
- updater complexity beyond local development.

This slice gives useful disk visualization while keeping destructive safety work
out of MVP scope until M5 is proven.

## First Cleanup Slice

Cleanup starts only after scan-only works.

Build in this order:

1. DeletePlan draft/preview without side effects.
2. identity revalidation dry-run.
3. durable receipt skeleton and journal intent.
4. platform Trash adapter for one OS.
5. per-item dispatch/outcome journal.
6. crash recovery inbox.
7. low-disk reserve.
8. UI confirmation and receipt view.

Do not add recommendations or command adapters until this slice is safe.

## Review Checklist

For each PR, answer:

- Which milestone does this touch?
- Which work lane owns the change?
- Which reading bundle applies?
- Which critical zones can block this?
- Does any domain/application code import forbidden infrastructure?
- Does any UI code hold full tree or cleanup truth?
- Are protocol DTOs separate from domain and view state?
- Are new paths/logs/support fields privacy-classified?
- Are failure states typed and visible?
- Is there at least one test or fixture for the new boundary?
