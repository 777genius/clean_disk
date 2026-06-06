# pdu Domain Infrastructure Contract Blueprint

Status: accepted pre-coding blueprint.

Last source audit: 2026-05-21.

This document is the practical bridge between pdu internals and the first Rust
implementation. It does not replace the larger pdu research files. It answers
one narrower question:

```text
Where does each pdu fact go in Clean Architecture, DDD, ports/adapters, and SOLID?
```

Core rule:

```text
Contracts are designed like Pro. Implementation starts as MVP.
```

## Executive Decision

Top 3 architecture choices:

1. Engine-owned scan contract with pdu as a private anti-corruption adapter -
   🎯 10 🛡️ 10 🧠 7, roughly 900-1400 LOC for first Rust skeleton.
   Accepted.

   `fs_usage_engine` owns `ScannerBackend`, `BackendScanRequest`,
   `BackendScanOutput`, snapshot publication, read-model indexes, query
   contracts, and session state. `fs_usage_pdu` imports `parallel_disk_usage`
   and translates pdu facts into engine-owned models.

2. pdu-shaped engine contract - 🎯 4 🛡️ 5 🧠 4, roughly 400-800 LOC.
   Rejected.

   This is faster to start, but it leaks `DataTree`, pdu errors, pdu size
   semantics, and pdu lifecycle into the application. It makes MFT/APFS/custom
   scanners harder later and violates dependency inversion.

3. Custom scanner immediately - 🎯 5 🛡️ 6 🧠 9, roughly 2500-5000 LOC before
   UI integration.
   Rejected for MVP.

   It gives maximum control, but wastes the strongest value of pdu: fast,
   battle-tested parallel traversal. Keep contracts ready for this path, but do
   not build it until pdu blocks us with evidence.

Accepted shape:

```text
fs_usage_core
  pure domain vocabulary and invariants

fs_usage_engine
  application use cases, ports, session state, snapshot/read-model

fs_usage_pdu
  pdu SDK adapter and anti-corruption translation

fs_usage_platform
  metadata, identity, permissions, capacity, trash, accounting

clean-disk-server
  process host, config, HTTP, WebSocket, auth, observability

clean_disk_protocol
  versioned external DTOs and schema
```

## Source Facts That Drive The Boundary

pdu SDK facts:

- `parallel_disk_usage` 0.23.0 is both CLI and library crate.
- docs.rs says the likely useful SDK pieces are `FsTreeBuilder`,
  `TreeBuilder`, `DataTree`, and `Visualizer`.
- `DataTree` fields are private. Public access is `name()`, `size()`, and
  `children()`.
- `DataTree::dir(name, inode_size, children)` stores
  `inode_size + sum(child.size())`, so `size()` is aggregate measured size.
- `DataTree` does not implement serde directly. JSON uses `Reflection` behind
  the `json` feature.
- `FsTreeBuilder` uses `symlink_metadata`, so symlink targets are not followed.
- `FsTreeBuilder` returns a `DataTree` through `From/Into`, not `Result`.
  Filesystem problems are reported through `Reporter::Event`.
- `Reporter::Event` is non-exhaustive and borrows path/metadata. The adapter
  must copy anything it keeps immediately.
- pdu reports only three operation kinds today: `symlink_metadata`, `read_dir`,
  and `access entry`.
- `TreeBuilder` uses Rayon `into_par_iter` internally and materializes child
  vectors before recursion.
- `TreeBuilder` callbacks must be `Copy + Send + Sync`, so rich metadata
  cannot be kept in mutable callback-local state. It needs thread-safe side
  stores or a post-pass.
- pdu can measure apparent size and, on Unix, block size or block count.
- pdu hardlink detection is Unix-oriented and records `(dev, ino)` style
  identity. It is a size projection, not delete reclaim truth.
- pdu README states it is ignorant of reflinks and does not follow symlinks.
- pdu CLI can configure a global Rayon pool. The daemon adapter must not use
  CLI `App` or global thread-pool side effects.
- `cargo info parallel-disk-usage` reports default feature `cli`. Production
  library integration should start from `default-features = false` and enable
  only the features we actually need.

Architecture consequence:

```text
pdu gives fast scan evidence.
pdu does not give product truth.
```

Product truth is built after anti-corruption mapping, capability tagging,
metadata enrichment, issue classification, and snapshot publication.

## Extra Source Audit Findings

These findings are easy to miss because pdu exposes a clean-looking high-level
API, but its internal mechanics are optimized for CLI output.

### Progress Is CLI-Oriented

pdu's built-in `ProgressAndErrorReporter`:

- spawns a progress thread;
- uses relaxed atomics for counters;
- reports totals, item count, error count, linked count, and shared size;
- calls the error callback before progress reporting when errors happen;
- requires `destroy()` to stop and join the progress thread.

Clean Disk implication:

```text
Do not reuse ProgressAndErrorReporter as the product event stream.
```

Use our own `PduReporterRecorder`:

- copy borrowed evidence immediately;
- increment bounded counters;
- send coarse progress to the engine coalescer;
- never block pdu traversal on WebSocket or UI backpressure;
- keep the built-in pdu reporter only as source inspiration and test reference.

### JSON And Reflection Are Not Our Protocol

pdu's `DataTree` does not serialize directly. It converts to `Reflection`.
pdu's `JsonData` wraps schema version, binary version, tree, unit, and optional
hardlink shared data.

Clean Disk implication:

```text
pdu JSON is useful for fixtures and diagnostics.
It is not the Clean Disk protocol.
```

Reasons:

- pdu JSON is tree-shaped, not query/page-shaped;
- pdu JSON does not carry our `NodeId`, `SnapshotId`, `ScanIssue`,
  `ScanQuality`, `CapabilitySnapshot`, cursors, privacy classes, or cleanup
  authority;
- pdu JSON has pdu unit semantics, not our full `SizeFact` taxonomy;
- pdu `Reflection` can represent invalid aggregate sizes until converted and
  validated.

Rule:

```text
Do not expose pdu Reflection or JsonData from clean-disk-server.
```

### Device Boundary Is Capability-Tagged

pdu's `DeviceBoundary::Stay` relies on device identity. In the local source,
Unix uses `MetadataExt::dev()`. On unsupported non-Unix platforms, device id
collapses to `()`, effectively disabling cross-device detection.

Clean Disk implication:

```text
Boundary policy must carry platform_support and backend_support.
```

The UI must not show "same filesystem only" as a guaranteed behavior on a
platform/backend combination that cannot prove it.

### Max Depth And Retain Preserve Aggregate Size

`TreeBuilder` decrements `max_depth`. When depth is exhausted, it collects child
sizes into the current directory and stores no children. `DataTree::par_retain`
can remove descendants while parent aggregate size remains.

Clean Disk implication:

```text
Missing children can still have measured size.
```

Therefore a node needs `ChildCompleteness`, for example:

- complete;
- collapsed by depth;
- collapsed by projection;
- skipped by boundary;
- incomplete due to error;
- unknown.

Do not infer empty folder, file kind, or cleanup safety from
`children().is_empty()`.

### Hardlink Deduplication Is A Projection

pdu hardlink deduplication mutates aggregate sizes by path-prefix matching. It
is useful for better visual ranking, but it is not a delete-time reclaim model.

Clean Disk implication:

```text
hardlink_adjusted_size != reclaim_estimate
```

Keep three separate facts:

- raw measured size;
- backend hardlink-adjusted projection;
- platform/accounting reclaim estimate.

### OsStringDisplay Is Display Evidence Only

pdu names are wrapped in `OsStringDisplay`. It displays UTF-8 when possible and
falls back to debug formatting for non-UTF-8 names.

Clean Disk implication:

```text
Display name is not path authority.
```

The adapter must keep path evidence in platform-safe representation and only
format for UI at the presentation/protocol edge.

### CLI App Must Stay Out Of Daemon Runtime

pdu's CLI path handles args, default `"."`, multi-root fake `(total)` root,
sorting, min-ratio culling, hardlink dedupe, JSON input/output, terminal status,
and may configure the global Rayon pool.

Clean Disk implication:

```text
Do not wrap pdu CLI App inside production daemon.
```

The daemon should use `FsTreeBuilder` or a future scanner backend directly.
`clean-disk-server` owns target normalization, resource budgets, output shape,
event delivery, and runtime lifecycle.

## Source-Audited Invariant Register

This register converts pdu source details into rules the first implementation
must preserve. It is intentionally more concrete than the high-level
architecture decision.

| pdu source detail | Architectural invariant |
|---|---|
| `lib.rs` gates CLI modules behind `feature = "cli"` but `Cargo.toml` default feature is `cli` | production dependency starts with `default-features = false`; CLI types stay out of daemon and library contracts |
| `json_data` exists even as a module, while serde derives are feature-gated | do not use pdu JSON as product protocol; enable `json` only for fixture/debug use if needed |
| `Quantity::DEFAULT` is `BlockSize` on Unix and `ApparentSize` elsewhere | product requests must choose measurement explicitly; no hidden backend default |
| `Bytes` and `Blocks` are separate newtypes over `u64` | protocol must carry unit/quantity, not just a number |
| `GetBlockSize` uses `metadata.blocks() * 512` on Unix | call this allocated-block evidence, not exact reclaim truth |
| `TreeBuilder` callbacks are `Copy + Send + Sync` | pdu enrichment must use side stores or post-pass, not mutable callback state |
| `TreeBuilder` materializes child name vectors and recurses through Rayon | resource budget must account for allocation pressure and parallel traversal |
| `FsTreeBuilder` uses `symlink_metadata` | symlink targets are not followed by default; symlink policy must be explicit |
| `FsTreeBuilder` returns `DataTree` rather than `Result` | success with issues is a normal outcome; errors are side-channel evidence |
| root metadata failure returns zero-size file-shaped tree | root failure must be detected from issues and mapped to degraded or failed scan |
| `Reporter::Event` is non-exhaustive and borrowed | adapter copies bounded evidence immediately and handles unknown future events conservatively |
| pdu error operations are `SymlinkMetadata`, `ReadDirectory`, `AccessEntry` | domain issue codes are ours; pdu operation names are evidence, not stable API |
| `AccessEntry` reports the parent directory path | issue evidence must preserve ambiguity; do not invent missing child path |
| `ProgressAndErrorReporter` spawns its own thread | product event stream uses our coalescer, not pdu progress reporter |
| progress counters use relaxed atomics | progress is approximate UI evidence, never final truth |
| hardlink list uses `DashMap<(dev, ino), value>` | hardlink evidence is backend/platform-specific and must be capability-tagged |
| hardlink `AddError` can detect size or link-count conflict | conflicts must become adapter diagnostics if we depend on hardlink evidence |
| `FsTreeBuilder` currently ignores hardlink recorder errors with `.ok()` | our adapter needs independent diagnostic accounting for hardlink conflicts |
| hardlink summary panics when detected paths exceed link count | do not call summary in a way that can take down daemon without containment |
| hardlink dedupe mutates aggregate sizes by path-prefix logic | hardlink-adjusted projection must be labeled and separated from raw measured size |
| `DeviceId` is meaningful on Unix and `()` on unsupported platforms | boundary policy must expose backend support and platform support |
| `OsStringDisplay` falls back to debug formatting for non-UTF8 | display label is not path authority; raw path evidence stays separate |
| `DataTree::Reflection` can be invalid until checked | fixtures/imports must run validation before becoming snapshot drafts |
| `par_retain` removes children while parent size remains | completeness state is mandatory for nodes with missing children |
| CLI culling uses `f32` ratio | culling/projection must not be part of authoritative scan tree for MVP |
| CLI sorting uses `par_sort_by` on whole tree | product sorting should happen in read-model indexes and paginated queries |
| CLI multi-root creates fake root | Clean Disk target grouping is engine-owned, not pdu CLI-owned |

Layer placement:

| Concern | Domain | Application | Data/Infrastructure |
|---|---|---|---|
| measurement kind | `MeasuredQuantity`, `SizeFact` | request validation, display contract | pdu size getter mapping |
| path authority | `PathEvidence`, `PathAuthority` language | delete preflight policy | platform identity reader, pdu path evidence copy |
| progress | no direct dependency | session state and coalesced events | pdu reporter recorder |
| hardlink facts | evidence and confidence language | quality/capability decisions | pdu hardlink mapper, platform accounting |
| errors | issue codes and severity | scan quality aggregation | pdu operation/error mapper |
| JSON/schema | no dependency | snapshot/import validation only | optional fixture/debug adapter |
| thread/runtime | no dependency | resource budget and cancellation policy | pdu execution lane |

Rule:

```text
Source details can inform domain language.
Source types cannot become domain language.
```

## Layer Responsibilities

### `fs_usage_core`

Purpose:

```text
Define the language of disk usage without knowing how scanning happens.
```

Allowed:

- value objects;
- pure enums;
- pure invariants;
- simple domain services that need no IO;
- quantity and identity language;
- safety vocabulary.

Forbidden:

- `parallel_disk_usage`;
- filesystem IO;
- async runtime;
- HTTP, WebSocket, Flutter, protocol DTOs;
- platform-specific APIs;
- pdu error names as domain identity.

Recommended modules:

```text
fs_usage_core/src/
  lib.rs
  ids/
    mod.rs
    scan_session_id.rs
    snapshot_id.rs
    node_id.rs
    node_ref.rs
    operation_id.rs
  size/
    mod.rs
    measured_quantity.rs
    size_bytes.rs
    size_fact.rs
    reclaim_estimate.rs
  target/
    mod.rs
    scan_target.rs
    target_scope.rs
    boundary_policy.rs
  node/
    mod.rs
    node_kind.rs
    node_flags.rs
    child_completeness.rs
  path/
    mod.rs
    path_display.rs
    path_authority.rs
    path_evidence.rs
  issue/
    mod.rs
    scan_issue.rs
    issue_code.rs
    issue_severity.rs
    issue_evidence.rs
  quality/
    mod.rs
    scan_quality.rs
    evidence_confidence.rs
  capability/
    mod.rs
    scanner_capability.rs
    platform_capability.rs
  cleanup/
    mod.rs
    cleanup_risk.rs
    delete_policy.rs
```

DDD notes:

- This is not a place for repositories. Ports belong to application.
- Keep aggregates small. A million-file scan is not a mutable domain aggregate.
- `NodeId` is snapshot-local identity, not filesystem identity.
- `PathDisplay` is not cleanup authority.
- `SizeFact` must distinguish aggregate measured size, own measured size,
  allocated size, logical size, hardlink-adjusted projection, and reclaim
  estimate.

### `fs_usage_engine`

Purpose:

```text
Own use cases, ports, scan lifecycle, read models, and publication gates.
```

Allowed:

- ports;
- use cases;
- state machines;
- bounded queues;
- snapshot draft/build/publish flow;
- read-model indexes;
- query pagination;
- fake scanner backend for tests.

Forbidden:

- direct pdu imports;
- direct platform IO implementation details;
- HTTP/WebSocket DTOs;
- Flutter DTOs;
- CLI args;
- UI-specific filtering or localized labels.

Recommended modules:

```text
fs_usage_engine/src/
  lib.rs
  application/
    mod.rs
    use_cases/
      start_scan.rs
      cancel_scan.rs
      get_scan_status.rs
      get_children_page.rs
      search_nodes.rs
      get_node_details.rs
      build_delete_plan.rs
    ports/
      scanner_backend.rs
      metadata_reader.rs
      file_identity_reader.rs
      capacity_reader.rs
      reclaim_accounting.rs
      trash_adapter.rs
      clock.rs
      event_sink.rs
    sessions/
      scan_session.rs
      scan_state.rs
      cancellation_token.rs
      resource_budget.rs
    snapshots/
      scan_snapshot.rs
      scan_snapshot_draft.rs
      snapshot_publication_gate.rs
      snapshot_metrics.rs
    read_model/
      node_arena.rs
      node_record.rs
      node_indexes.rs
      children_query.rs
      search_query.rs
      cursor.rs
      page.rs
    events/
      scan_event.rs
      event_coalescer.rs
      event_sequence.rs
    errors/
      scan_failure.rs
      query_failure.rs
```

Main port shape:

```text
ScannerBackend
  capabilities() -> ScannerBackendCapabilities
  scan(request, event_sink, cancel) -> Result<BackendScanOutput, ScanFailure>
```

`BackendScanRequest` should contain product language:

```text
BackendScanRequest
  targets
  measurement_profile
  boundary_policy
  hardlink_policy
  max_depth_policy
  resource_budget
  metadata_enrichment_policy
  privacy_policy
  scan_epoch
```

`BackendScanOutput` should contain product evidence:

```text
BackendScanOutput
  backend_run_id
  root_records
  snapshot_draft
  issue_store
  backend_capabilities_used
  backend_decision_record
  progress_summary
  raw_metrics
```

`BackendScanOutput` must not contain:

- `DataTree`;
- `FsTreeBuilder`;
- pdu `Event`;
- pdu `ErrorReport`;
- pdu hardlink record types;
- protocol DTOs;
- Flutter DTOs;
- delete authority.

SOLID reading:

- SRP: session orchestration, pdu execution, metadata enrichment, indexing,
  and protocol mapping are separate reasons to change.
- OCP: new scanners implement `ScannerBackend`, they do not modify domain
  contracts.
- LSP: every backend must return the same semantic output: final snapshot
  draft, issues, capabilities, metrics, and terminal state.
- ISP: `ScannerBackend` scans. Metadata, identity, capacity, trash, and reclaim
  accounting are separate ports.
- DIP: use cases depend on ports and value objects, not pdu or platform APIs.

### `fs_usage_pdu`

Purpose:

```text
Adapt pdu SDK facts into fs_usage_engine contracts.
```

Allowed:

- import `parallel_disk_usage`;
- call `FsTreeBuilder`;
- create pdu reporter and hardlink recorder;
- map pdu options from `BackendScanRequest`;
- copy pdu reporter evidence into adapter-owned records;
- convert `DataTree` into engine snapshot draft records;
- report pdu limitations as capabilities and issues.

Forbidden:

- expose pdu types publicly;
- expose pdu paths as cleanup authority;
- emit protocol DTOs;
- start HTTP/WebSocket;
- call pdu CLI `App`;
- configure global Rayon from production daemon path;
- make pdu size equal to reclaim estimate.

Recommended modules:

```text
fs_usage_pdu/src/
  lib.rs
  adapter/
    mod.rs
    pdu_scanner_backend.rs
    pdu_options_mapper.rs
    pdu_execution_lane.rs
    pdu_raw_scan_result.rs
  reporter/
    mod.rs
    pdu_reporter_recorder.rs
    copied_pdu_event.rs
    pdu_progress_sampler.rs
    pdu_issue_mapper.rs
  convert/
    mod.rs
    pdu_tree_converter.rs
    pdu_node_builder.rs
    pdu_size_mapper.rs
    pdu_path_mapper.rs
  hardlinks/
    mod.rs
    pdu_hardlink_policy_mapper.rs
    pdu_hardlink_summary_mapper.rs
  capabilities/
    mod.rs
    pdu_capability_mapper.rs
    pdu_version_info.rs
  diagnostics/
    mod.rs
    pdu_metrics.rs
    pdu_decision_record.rs
  tests/
    fixtures.rs
```

Public surface should be small:

```text
pub struct PduScannerBackend;
```

Everything else should be private or crate-private until a real reuse case
appears.

Internal pdu flow:

```text
BackendScanRequest
  -> PduOptionsMapper
  -> PduScannerBackend
  -> PduReporterRecorder
  -> FsTreeBuilder
  -> DataTree
  -> PduTreeConverter
  -> ScanSnapshotDraft
  -> BackendScanOutput
```

Adapter translation rules:

| pdu fact | Product mapping |
|---|---|
| `DataTree::name()` | display name evidence only |
| `DataTree::size()` | aggregate measured size fact |
| `DataTree::children()` | child shape evidence, not node kind truth |
| `DataTree::children().is_empty()` | ambiguous leaf-like record |
| `Event::ReceiveData` | progress byte/item evidence only |
| `Event::EncounterError` | `ScanIssue` with copied path evidence and operation |
| `Event::DetectHardlink` | hardlink evidence and capability fact |
| `GetApparentSize` | measurement profile: apparent bytes |
| Unix `GetBlockSize` | measurement profile: allocated-ish block bytes |
| hardlink dedupe | ranking projection only |
| `max_depth` collapsed children | `ChildCompleteness::CollapsedByDepth` |
| device boundary skip | completeness or boundary issue, capability-tagged |

Important adapter warnings:

- `AccessEntry` error path is the parent directory, not the inaccessible child.
- root `symlink_metadata` failure returns a zero-size file-shaped `DataTree`.
- hardlink recorder errors are ignored by pdu internals in the scan path, so
  our adapter must keep its own diagnostics if hardlink accuracy matters.
- pdu `Event` is borrowed. Never store references from the callback.
- pdu `DataTree` is final-tree oriented. Do not promise node streaming until
  we fork or add a visitor backend.
- pdu progress is evidence, not final session state.

### `fs_usage_platform`

Purpose:

```text
Provide platform facts that pdu either cannot know or should not own.
```

Allowed:

- filesystem identity;
- metadata restat;
- permissions and access probes;
- volume/topology facts;
- capacity/free space;
- trash/recycle bin operations;
- reclaim accounting;
- platform capabilities.

Forbidden:

- pdu imports;
- UI/protocol DTOs;
- cleanup decisions without application policy;
- trusting stale scan rows.

Recommended modules:

```text
fs_usage_platform/src/
  lib.rs
  metadata/
    mod.rs
    metadata_reader.rs
    metadata_snapshot.rs
  identity/
    mod.rs
    file_identity.rs
    identity_reader.rs
  permissions/
    mod.rs
    access_probe.rs
    permission_status.rs
  topology/
    mod.rs
    volume_id.rs
    mount_info.rs
    boundary_detector.rs
  capacity/
    mod.rs
    capacity_reader.rs
  accounting/
    mod.rs
    reclaim_accounting.rs
    shared_extent_evidence.rs
    sparse_file_evidence.rs
  trash/
    mod.rs
    trash_adapter.rs
    trash_receipt.rs
  platform/
    macos/
    windows/
    linux/
```

Why this is separate:

- pdu is optimized traversal, not delete safety.
- cleanup needs revalidation under the same signed scanner identity.
- reclaim estimate must handle hardlinks, reflinks, snapshots, sparse files,
  compression, cloud placeholders, quotas, and platform-specific recycle/trash
  behavior.
- platform facts evolve independently from pdu.

## Product Data Flow

Accepted scan flow:

```text
Flutter command
  -> CleanDiskApiClient
  -> clean-disk-server HTTP command
  -> StartScanUseCase
  -> ScanSession
  -> ScannerBackend port
  -> PduScannerBackend adapter
  -> BackendScanOutput
  -> SnapshotPublicationGate
  -> immutable ScanSnapshot
  -> NodeArena + ReadModelIndexes
  -> HTTP paginated queries
  -> Flutter stores and widgets
```

Accepted event flow:

```text
pdu reporter callback
  -> PduReporterRecorder copies bounded evidence
  -> engine event coalescer
  -> scan-session event stream
  -> clean-disk-server WebSocket envelope
  -> Flutter ScanEventClient
  -> invalidate/query UI state
```

Rules:

- WebSocket events are hints and lifecycle notifications.
- HTTP queries return authoritative current state.
- Slow clients must not block scanner callbacks.
- Progress can be dropped/coalesced.
- terminal state and snapshot publication must be queryable after reconnect.
- Flutter must never build or own the full tree.

## Query Model

Rust owns the full snapshot and indexes.

Query operations:

```text
get_children(snapshot_id, node_id, cursor, limit, sort, filter)
search(snapshot_id, query, cursor, limit, filter)
top(snapshot_id, category, cursor, limit)
details(snapshot_id, node_id)
map_projection(snapshot_id, node_id, projection, budget)
```

Cursor rules:

- opaque;
- snapshot-bound;
- query-shape-bound;
- expires safely;
- never encodes raw path or delete authority.

Sorting and filtering rules:

- Rust sorts and filters large result sets.
- Flutter may sort only already visible small pages for display convenience.
- query semantics are typed contracts, not localized labels.

## Domain Terms That Must Stay Separate

Do not collapse these:

| Term | Meaning |
|---|---|
| scan target | user-requested starting point |
| pdu root | adapter execution root |
| displayed path | UI evidence |
| authoritative path | platform-validated current path |
| node id | snapshot-local id |
| file identity | platform identity, when available |
| measured size | scan measurement |
| reclaim estimate | delete-time accounting estimate |
| cleanup candidate | recommendation/queue item |
| delete plan | validated destructive plan |
| selection | UI intent only |
| queue | user review list |
| snapshot | immutable scan result |
| current filesystem | mutable external world |

Critical rule:

```text
Snapshot rows can suggest cleanup.
Only a current DeletePlan can authorize cleanup.
```

## First Rust Skeleton Order

Recommended first implementation order:

1. `fs_usage_core` value objects and enums - 🎯 9 🛡️ 9 🧠 5,
   roughly 500-900 LOC.

   Build stable language first: ids, size facts, node kind/completeness, issue
   codes, capabilities, scan target, boundary policy.

2. `fs_usage_engine` fake backend and read-model gate - 🎯 9 🛡️ 9 🧠 7,
   roughly 900-1500 LOC.

   Implement `ScannerBackend`, session state machine, fake output,
   `ScanSnapshotDraft`, publication gate, and paginated children query before
   pdu. This tests the architecture without adapter noise.

3. `fs_usage_pdu` adapter behind `ScannerBackend` - 🎯 8 🛡️ 8 🧠 7,
   roughly 900-1600 LOC.

   Add pdu mapping with fixtures, progress recorder, issue mapper, size
   mapper, capability mapper, and cancellation boundary.

4. `clean-disk-server` HTTP/WebSocket protocol adapter - 🎯 8 🛡️ 8 🧠 6,
   roughly 800-1400 LOC.

   Expose commands, queries, event stream, protocol version, capability state,
   and local token/origin policy.

Reason:

```text
Build the port before the adapter.
Build query truth before UI polish.
Build cleanup authority after scan truth.
```

## Contract Tests Before Real UI Integration

Required tests:

- fake backend can publish a snapshot and answer paginated children queries;
- pdu adapter public API exposes no pdu concrete types;
- pdu root metadata failure maps to failed/degraded scan, not silent empty
  success;
- read directory permission error maps to `ScanIssue`;
- `AccessEntry` parent-path ambiguity is preserved in issue evidence;
- leaf-like `DataTree` record does not automatically become `NodeKind::File`;
- max-depth collapsed subtree sets child completeness;
- measured size is not reclaim estimate;
- hardlink detection changes capability/evidence, not delete authority;
- cancellation discards late pdu output through scan epoch/session state;
- query cursors are invalidated by snapshot mismatch;
- WebSocket progress loss does not break authoritative HTTP query state.

## Global Attention Zones Before Coding

These are the highest-risk places for the first implementation.

| Zone | Risk | Accepted contract |
|---|---|---|
| pdu final tree | pdu returns complete `DataTree`, not our query model | convert once into `ScanSnapshotDraft` and publish immutable snapshot |
| pdu progress | callback events are not full truth | use events as hints, final state comes from `BackendScanOutput` and session state |
| pdu errors | scan can finish with partial tree and side-channel errors | every error maps to `ScanIssue` and affects `ScanQuality` |
| child shape | empty children can mean file, empty dir, skipped, collapsed, or failed | model `NodeKind` and `ChildCompleteness` separately |
| size semantics | aggregate measured size can be mistaken for reclaimable bytes | every displayed number has a `SizeFact` kind and confidence |
| hardlinks | dedupe improves ranking but is not delete truth | hardlink facts stay evidence until accounting/preflight |
| reflinks/snapshots | pdu explicitly does not account for them | reclaim estimate is separate platform/accounting work |
| path identity | pdu names are not durable authority | cleanup uses current platform identity revalidation |
| non-UTF8 paths | display conversion can lose authority | keep raw platform path evidence behind platform/protocol-safe types |
| device boundaries | non-Unix support can be weak | report capability and degrade UX language honestly |
| threading | pdu uses Rayon internally | isolate scanner work from async reactor and UI event delivery |
| backpressure | UI/WebSocket can be slow | bounded queues, coalesced progress, no blocking callback path |
| memory | full `DataTree` plus our read model can double memory | first PR measures peak and keeps compact arena contract |
| cancellation | pdu is not strongly cooperative | session epoch discards late results, future backend can improve cancellation |
| protocol | JSON numeric/path precision can break web | versioned DTOs, string/u64-safe large values, opaque cursors |
| security | daemon scans local filesystem | local-only token/origin policy, no raw paths in logs, explicit authority scopes |
| cleanup | stale scan may delete wrong thing | DeletePlan revalidates current identity and metadata before Trash |

Rule:

```text
If a fact is not stable, current, and authority-bearing, it cannot drive cleanup.
```

## Minimum First PR Acceptance Criteria

The first scanner PR should pass this checklist before any UI wiring:

- crate boundaries exist and compile;
- `fs_usage_core` has no IO, pdu, protocol, Flutter, or async dependencies;
- `fs_usage_engine` defines the `ScannerBackend` port and fake backend tests;
- fake backend publishes a snapshot and answers children page queries;
- `fs_usage_pdu` is the only crate importing `parallel_disk_usage`;
- pdu adapter maps at least size, name evidence, child shape, progress counters,
  and error issues;
- pdu adapter reports capabilities and limitations;
- `BackendScanOutput` contains no pdu concrete type;
- one fixture covers permission/read-dir error mapping;
- one fixture covers collapsed max-depth child completeness;
- one fixture covers hardlink evidence without delete authority;
- no daemon/protocol route returns a full tree.

Suggested LOC split for first PR:

1. core value objects only - 🎯 9 🛡️ 9 🧠 5, roughly 500-900 LOC.
2. engine fake backend/read-model only - 🎯 9 🛡️ 9 🧠 7, roughly 900-1500 LOC.
3. pdu adapter slice - 🎯 8 🛡️ 8 🧠 7, roughly 900-1600 LOC.

Do not merge all UI, daemon, pdu, cleanup, and protocol work in one PR. It will
hide the real architecture errors under volume.

## Stop Rules

Stop before coding or merging if:

- any non-`fs_usage_pdu` crate imports `parallel_disk_usage`;
- protocol DTOs include pdu types or pdu operation names as stable API;
- Flutter receives the full scan tree;
- a path string from scan output can directly become a delete command;
- pdu `DataTree::size()` is shown as guaranteed reclaimable bytes;
- scan completion depends only on the last progress event;
- pdu CLI `App` is used in production daemon integration;
- global Rayon configuration is introduced from the daemon scanner path;
- scanner callbacks can block on WebSocket clients;
- unknown pdu event variants are treated as success without capability
  degradation.

## What To Remember Before Coding

Most important facts:

- pdu is a very good traversal engine, not our product model.
- pdu returns a final aggregate tree plus side-channel events.
- pdu does not give stable node ids, full metadata, safe delete authority,
  reclaim truth, or query indexes.
- our reusable library should be useful without Clean Disk, Flutter, HTTP, or
  WebSocket.
- `fs_usage_engine` is the contract center.
- `fs_usage_pdu` is replaceable.
- `fs_usage_platform` is where safety facts live.
- `clean-disk-server` is the host, not the domain.

## Sources

- [parallel_disk_usage crate docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/)
- [DataTree docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/data_tree/struct.DataTree.html)
- [FsTreeBuilder docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/fs_tree_builder/struct.FsTreeBuilder.html)
- [TreeBuilder docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/tree_builder/struct.TreeBuilder.html)
- [Reporter Event docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/reporter/event/enum.Event.html)
- [parallel-disk-usage README limitations](https://github.com/KSXGitHub/parallel-disk-usage#limitations)
- Local audited source:
  `/Users/belief/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/parallel-disk-usage-0.23.0`
