# Clean Architecture Implementation Phases

Status: accepted execution plan.

Last updated: 2026-05-31.

This document is the strict phase plan for implementing Clean Disk without
breaking Clean Architecture, simple DDD, SOLID, ports/adapters, and the core
project rule:

```text
Contracts are designed like Pro. Implementation starts as MVP.
```

Use this when starting real implementation. It is intentionally stricter than a
fast MVP checklist. If a phase takes more code and time but preserves the
architecture boundary, choose the boundary.

## Strategy Choice

Top 3 implementation strategies:

1. Contract-first vertical foundation - 🎯 10 🛡️ 10 🧠 8, roughly
   9000-15000 LOC before polished UI.
   Accepted.

   Build domain/application contracts, fake backends, read-model gates,
   protocol DTOs, and adapter seams before pushing UI polish or cleanup. This
   is slower, but gives clean replacement points for pdu, future MFT/APFS
   scanners, daemon protocol changes, and remote/headless mode.

2. pdu-first scan MVP - 🎯 7 🛡️ 7 🧠 6, roughly 5000-9000 LOC before usable
   scan UI.
   Rejected as default.

   It gives visible scan results sooner, but pdu concepts can leak into domain,
   protocol, and Flutter. Use only for short spikes, not the main branch.

3. UI-first shell with mocked API - 🎯 6 🛡️ 6 🧠 5, roughly 4000-8000 LOC before
   real scanning.
   Rejected as default.

   It helps product iteration, but risks building stores/widgets around fake
   data that cannot survive large-tree pagination, scan quality, reconnect,
   permissions, and cleanup authority.

## Non-Negotiable Layer Order

Production work moves inward to outward, then back through adapters:

```text
domain language
  -> application ports and use cases
  -> fake adapters and contract tests
  -> real infrastructure adapters
  -> server protocol
  -> Flutter data adapters
  -> UI composition
  -> cleanup authority
  -> packaging/release hardening
```

Rules:

- no adapter type in domain;
- no protocol DTO in domain or application;
- no Flutter state in Rust contracts;
- no pdu type outside `fs_usage_pdu`;
- no path string as cleanup authority;
- no full tree in Flutter;
- no destructive action before DeletePlan, identity revalidation, journal, and
  receipt skeleton exist.

## Phase 0 - Architecture Baseline Freeze

Goal:

- make the repo ready for implementation without relying on chat memory.

Steps:

1. Verify the documented architecture direction is current.
2. Confirm monorepo package/crate names and dependency direction.
3. Confirm `apps/clean_disk` is the Flutter composition root.
4. Confirm `clean-disk-server` is the Rust host/composition root.
5. Confirm reusable Rust crates are product-independent.
6. Confirm pdu stays an adapter.
7. Confirm HTTP commands/queries plus plain WebSocket events are the MVP
   transport.
8. Confirm cleanup is out of scan-only MVP.

Outputs:

- updated documentation index if any file moved;
- task coordinates: train, milestone, phase, lane, gate, excluded scope;
- first implementation issue/PR plan.

Exit gate:

- implementation can start from docs alone;
- no open architectural question blocks the first Rust skeleton.

Stop if:

- the plan pulls in FRB, gRPC, Socket.IO, microservices, remote cleanup, or
  pdu CLI wrapper without reopening the architecture decision.

## Phase 1 - Workspace And Build Boundaries

Goal:

- create the physical crate/package structure before behavior.

Steps:

1. Add Rust workspace/crate skeletons only:
   - `fs_usage_core`;
   - `fs_usage_engine`;
   - `fs_usage_platform`;
   - `fs_usage_pdu`;
   - `clean_disk_protocol`;
   - `apps/clean_disk_server`.
2. Add minimal crate manifests with no unnecessary features.
3. Add dependency constraints so inner crates cannot depend on outer crates.
4. Add lint/test commands for Rust workspace.
5. Add a dependency freshness note when adding each crate.
6. Ensure `parallel-disk-usage` is not yet needed unless the pdu adapter phase
   starts.

Outputs:

- compiling empty crates;
- documented dependency graph;
- CI/local commands for `cargo check`, tests, and formatting.

Exit gate:

- each crate compiles;
- dependency direction is enforceable by code review and manifests.

Stop if:

- `fs_usage_core` depends on async runtime, pdu, protocol, server, or platform
  implementation crates.

## Phase 2 - Domain Kernel `fs_usage_core`

Goal:

- define the stable disk-usage language without IO.

Steps:

1. Implement ids:
   - `ScanSessionId`;
   - `SnapshotId`;
   - `NodeId`;
   - `NodeRef`;
   - `OperationId`.
2. Implement size language:
   - `MeasuredQuantity`;
   - `SizeBytes`;
   - `SizeFact`;
   - `ReclaimEstimate`;
   - confidence/evidence tags.
3. Implement target language:
   - `ScanTarget`;
   - `TargetScope`;
   - `BoundaryPolicy`;
   - `HardlinkPolicy`.
4. Implement node language:
   - `NodeKind`;
   - `NodeFlags`;
   - `ChildCompleteness`.
5. Implement issue language:
   - `ScanIssue`;
   - `IssueCode`;
   - `IssueSeverity`;
   - `IssueEvidence`.
6. Implement capability language:
   - scanner capabilities;
   - platform capabilities;
   - unsupported/unknown capability states.
7. Add pure unit/property tests for invariants.

Outputs:

- pure domain crate;
- no IO;
- no repositories;
- no adapters;
- no DTOs.

Exit gate:

- `fs_usage_core` can be used by fake tests without pdu, daemon, or Flutter.

Stop if:

- domain models expose pdu operation names as stable identity;
- domain models treat displayed path as authoritative path;
- size facts collapse measured size and reclaim estimate.

## Phase 3 - Application Engine Contracts `fs_usage_engine`

Goal:

- define use cases, ports, state machines, and read-model contracts before real
  infrastructure.

Steps:

1. Define ports:
   - `ScannerBackend`;
   - `MetadataReader`;
   - `FileIdentityReader`;
   - `CapacityReader`;
   - `ReclaimAccounting`;
   - `TrashAdapter`;
   - `Clock`;
   - `EventSink`.
2. Define scan contracts:
   - `BackendScanRequest`;
   - `BackendScanOutput`;
   - `ScannerBackendCapabilities`;
   - `ScanFailure`.
3. Define scan session lifecycle:
   - create;
   - start;
   - progress;
   - cancel;
   - terminal;
   - dispose.
4. Define immutable snapshot flow:
   - `ScanSnapshotDraft`;
   - `SnapshotPublicationGate`;
   - `ScanSnapshot`.
5. Define read-model contracts:
   - `NodeArena`;
   - `NodeRecord`;
   - children page query;
   - search query;
   - top files/folders query;
   - details query;
   - opaque cursor.
6. Define application events:
   - lifecycle events;
   - progress hints;
   - issue summaries;
   - snapshot published.
7. Add fake backend.
8. Add contract tests against fake backend.

Outputs:

- engine tests pass without pdu;
- fake scan produces a snapshot and paginated queries;
- cancellation and terminal state are modeled.

Exit gate:

- the application can run a fake scan end to end without infrastructure.

Stop if:

- `ScannerBackend` returns pdu `DataTree`;
- application events become protocol/WebSocket DTOs;
- query cursors encode raw path or delete authority.

## Phase 4 - Read Model And Index Design

Goal:

- prove large-tree data ownership before real pdu scans.

Steps:

1. Design compact arena storage.
2. Decide which fields are in the main node record and which are lazy details.
3. Add parent/children indexes.
4. Add sorted child views.
5. Add search index strategy.
6. Add top files/top folders indexes.
7. Add issue aggregation by subtree.
8. Add child completeness propagation.
9. Add memory budget tests with synthetic trees.
10. Add pagination/cursor invalidation tests.

Outputs:

- Rust-owned read model;
- page queries;
- no full-tree DTO export;
- memory profile baseline.

Exit gate:

- a synthetic large tree can be queried without cloning the full tree.

Stop if:

- full `PathBuf` is stored on every hot node record without budget proof;
- Flutter-facing shape drives Rust storage;
- filtering/sorting requires sending all rows to Flutter.

## Phase 5 - pdu Adapter `fs_usage_pdu`

Goal:

- integrate pdu as an infrastructure adapter without leaking source types.

Steps:

1. Add `parallel-disk-usage` with `default-features = false`.
2. Implement `PduScannerBackend`.
3. Implement `PduOptionsMapper`.
4. Implement `PduReporterRecorder`.
5. Copy pdu events immediately because they borrow paths/metadata.
6. Map `DataTree` into `ScanSnapshotDraft`.
7. Map pdu errors into `ScanIssue`.
8. Map size getter choice into `MeasuredQuantity`.
9. Map hardlink facts as evidence, not reclaim truth.
10. Map max-depth and missing children into `ChildCompleteness`.
11. Add pdu capability and limitation report.
12. Add cancellation epoch handling for late output.
13. Add fixtures for permission errors, hardlinks, non-UTF8 names, depth
    collapse, symlinks, and root failure.

Outputs:

- real scan backend behind `ScannerBackend`;
- no pdu public types outside adapter;
- source-level pdu limitations converted into product evidence.

Exit gate:

- pdu adapter passes the same scanner contract tests as fake backend.

Stop if:

- pdu JSON, `Reflection`, `DataTree`, or pdu errors appear in protocol,
  Flutter, domain, or server public contracts;
- pdu progress is treated as authoritative final state;
- hardlink-adjusted pdu size is labeled reclaim estimate.

## Phase 6 - Runtime Execution And Resource Governance

Goal:

- ensure scanning does not freeze the UI or daemon runtime.

Steps:

1. Define blocking scanner execution lane.
2. Define bounded worker pool policy.
3. Define scan modes:
   - background;
   - balanced;
   - fast.
4. Define bounded event queues.
5. Define progress coalescing interval.
6. Define cancellation and shutdown behavior.
7. Define panic containment.
8. Define overload behavior.
9. Add resource profile tests.
10. Add benchmark harness for synthetic and real fixture scans.

Outputs:

- runtime contract;
- no blocking filesystem work on async reactor;
- controlled backpressure.

Exit gate:

- slow WebSocket/UI clients cannot block scanner traversal.

Stop if:

- scanner callbacks can wait on network/UI;
- worker pools are unbounded;
- cancellation is only a UI flag.

## Phase 7 - Protocol DTOs And Schema

Goal:

- define external API without exposing domain structs directly.

Steps:

1. Define protocol version.
2. Define capability endpoint DTO.
3. Define scan command DTOs.
4. Define session status DTOs.
5. Define event envelope.
6. Define node page DTOs.
7. Define details DTO.
8. Define issue DTO.
9. Define cursor DTO.
10. Define large integer policy for Flutter web.
11. Define path/display redaction policy.
12. Add schema generation.
13. Add compatibility tests.

Outputs:

- `clean_disk_protocol`;
- versioned JSON DTOs;
- no domain struct exposed directly.

Exit gate:

- old/unknown enum values fail closed or degrade safely.

Stop if:

- DTOs derive directly from internal domain or pdu structs;
- raw paths, tokens, or search text enter logs or metrics;
- large counters rely on JavaScript number precision.

## Phase 8 - Daemon Host `clean-disk-server`

Goal:

- compose engine, adapters, protocol, auth, events, and lifecycle.

Steps:

1. Wire composition root.
2. Add local config.
3. Add local token/origin policy.
4. Add HTTP commands.
5. Add HTTP queries.
6. Add WebSocket events.
7. Add reconnect/resync contract.
8. Add session registry.
9. Add capability endpoint.
10. Add graceful shutdown.
11. Add observability with redaction.
12. Add daemon integration tests.

Outputs:

- local scan daemon;
- HTTP state is authoritative;
- WebSocket events are hints/lifecycle.

Exit gate:

- client can lose WebSocket and recover by HTTP state query.

Stop if:

- WebSocket reconnect is treated as command authorization;
- daemon route strings leak into Flutter widgets;
- event buffers can grow without bound.

## Phase 9 - Flutter Data Integration

Goal:

- connect Flutter to daemon through application/data boundaries before UI
  polish.

Steps:

1. Add `CleanDiskApiClient` over existing HTTP abstraction or a thin approved
   wrapper.
2. Add `ScanEventClient`.
3. Add DTO mappers into feature application models.
4. Add scan repository adapter.
5. Add application use cases in `features/scan`.
6. Add MobX stores for session, viewport, query state, selection, details, and
   progress.
7. Add stale/offline/incompatible daemon states.
8. Add tests for DTO mapping and event reconciliation.

Outputs:

- Flutter feature can run against fake/server fixtures;
- widgets still do not know protocol DTOs or route strings.

Exit gate:

- stores can query pages and reconcile events without full-tree state.

Stop if:

- widgets import HTTP/WebSocket clients;
- protocol DTOs reach widgets;
- Flutter sorts or filters full scan tree.

## Phase 10 - Flutter Scan UI

Goal:

- render the saved wide/compact product surface using real paginated data.

Steps:

1. Build scan target controls.
2. Build progress/status footer.
3. Build tree/table facade using fixed visible rows.
4. Build details panel.
5. Build search/filter/sort controls backed by Rust queries.
6. Build issue/permission/degraded states.
7. Build delete queue as UI intent only, not delete authority.
8. Build compact layout.
9. Add loading/empty/error states.
10. Add keyboard/focus/accessibility basics.
11. Add screenshot checks against saved references.
12. Add synthetic 50k-row UI performance profile.

Outputs:

- usable scan-only UI;
- no destructive cleanup.

Exit gate:

- wide and compact references are structurally matched;
- UI does not overflow;
- scan table remains smooth under synthetic large data.

Stop if:

- visual map or table becomes source of truth;
- cleanup candidates are created from visible rows only;
- UI polishing blocks data integration gates.

## Phase 11 - Scan-Only Packaging And Permission Proof

Goal:

- prove real app identity and platform permissions before cleanup.

Steps:

1. Package daemon/helper with app identity.
2. Add permission probe.
3. Add macOS Full Disk Access guidance flow.
4. Add Windows/Linux permission/access states.
5. Add scanner identity check.
6. Add permission repair flow.
7. Add update/rollback constraints for scan-only.
8. Add installer smoke tests where possible.

Outputs:

- scan-only desktop proof;
- permission state is honest;
- scanner process identity is predictable.

Exit gate:

- capability probing, scan, metadata enrichment, and future delete preflight
  can run under the same intended process identity.

Stop if:

- production scan launches an external random `pdu` binary;
- permission UI claims access before scanner identity re-probes.

## Phase 12 - Cleanup Preview Only

Goal:

- model cleanup intent without side effects.

Steps:

1. Add `DeletePlan` aggregate.
2. Add selected snapshot refs to cleanup queue as intent only.
3. Add current identity revalidation preflight.
4. Add stale item states.
5. Add reclaim estimate confidence model.
6. Add policy conflict states.
7. Add preview UI.
8. Add tests for stale path, changed metadata, missing permission, and unknown
   reclaim.

Outputs:

- cleanup preview;
- no Trash adapter execution.

Exit gate:

- stale scan data cannot authorize cleanup.

Stop if:

- path strings become delete commands;
- UI checkbox equals delete authority;
- reclaim estimate is shown as exact without evidence.

## Phase 13 - Cleanup Execution Safety

Goal:

- enable local Trash/recycle cleanup with durable evidence.

Steps:

1. Add durable operation journal.
2. Write intent before side effects.
3. Add receipt skeleton before dispatch.
4. Add platform Trash adapter.
5. Add per-item outcome states.
6. Add partial failure handling.
7. Add crash recovery inbox.
8. Add low-disk reserve policy.
9. Add restore expectation levels.
10. Add destructive operation tests.

Outputs:

- local cleanup beta;
- durable receipts;
- safe partial outcomes.

Exit gate:

- crash at any item boundary has a defined recovery state.

Stop if:

- cleanup auto-retries unknown destructive outcomes;
- receipt exists only after a whole batch completes.

## Phase 14 - Recommendations And Tool Adapters

Goal:

- add cleanup intelligence without bypassing safety.

Steps:

1. Add recommendation evidence model.
2. Add rule-pack versioning.
3. Add risk tiers.
4. Add invalidation rules.
5. Add official tool adapter ports.
6. Add command sandbox policy.
7. Add dry-run parity.
8. Add recommendation UI.

Outputs:

- explainable recommendations;
- tool cleanup cannot bypass DeletePlan and receipts.

Exit gate:

- every recommendation has evidence, risk tier, invalidation, and safe action
  path.

Stop if:

- app runs shell snippets from UI;
- PATH lookup decides cleanup executable identity;
- recommendation deletes persistent user data without explicit high-risk flow.

## Phase 15 - Release, Remote, Diagnostics

Goal:

- harden production surfaces after local scan/cleanup architecture is proven.

Steps:

1. Add dependency governance gates.
2. Add SBOM/provenance policy.
3. Add updater and rollback tests.
4. Add migration tests.
5. Add support bundle manifest.
6. Add log/metric redaction.
7. Add crash summary policy.
8. Add remote/headless read-only profile.
9. Add auth/authZ scopes for remote mode.
10. Add release readiness matrix.

Outputs:

- production release evidence;
- remote read-only mode;
- support operations.

Exit gate:

- release claims have tests, diagnostics, and rollback path.

Stop if:

- remote mode reuses local loopback token as remote credential;
- support bundle exports raw paths/tokens/search text by default;
- updater can interrupt active cleanup.

## Phase Dependency Graph

```text
0 baseline
  -> 1 workspace
  -> 2 domain core
  -> 3 application engine
  -> 4 read model
  -> 5 pdu adapter
  -> 6 runtime lanes
  -> 7 protocol
  -> 8 daemon
  -> 9 Flutter data
  -> 10 Flutter UI
  -> 11 scan-only packaging
  -> 12 cleanup preview
  -> 13 cleanup execution
  -> 14 recommendations
  -> 15 release/remote/diagnostics
```

Parallel work allowed:

- UI component previews can start during phases 7-9, but cannot define data
  truth.
- Packaging research can run during phases 5-10, but cannot ship cleanup.
- Recommendation research can run anytime, but cannot bypass cleanup phases.
- Remote/headless research can run anytime, but remote destructive cleanup stays
  blocked.

## First Implementation Slice

First production slice should be:

1. Phase 1 workspace skeleton - 🎯 9 🛡️ 9 🧠 5, roughly 300-700 LOC.
2. Phase 2 domain kernel - 🎯 9 🛡️ 10 🧠 6, roughly 700-1400 LOC.
3. Phase 3 engine contracts with fake backend - 🎯 10 🛡️ 10 🧠 8, roughly
   1200-2200 LOC.
4. Phase 4 read-model contract tests - 🎯 9 🛡️ 9 🧠 8, roughly 1000-2000 LOC.

Do not start Phase 5 pdu adapter until fake backend and read-model gates pass.
This is the main protection against pdu leaking into the architecture.

## Review Checklist For Every PR

Every implementation PR must answer:

1. Which phase is this?
2. Which layer owns the changed behavior?
3. Which port or adapter boundary changed?
4. What is the inward dependency direction?
5. What is the fake/test adapter proving?
6. What production adapter is intentionally not included?
7. Which stop rule was checked?
8. Which edge-case doc was read?
9. Which tests prove the gate?
10. What future feature is preserved but not implemented?

If a PR cannot answer these, it is not ready.

