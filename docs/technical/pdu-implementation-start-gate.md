# pdu Implementation Start Gate

This document is the compact gate to read immediately before writing Rust
scanner code. It does not replace the deeper pdu research documents. It turns
their findings into concrete implementation constraints for Clean Architecture,
DDD, SOLID, and ports/adapters.

Core decision:

```text
pdu is a fast filesystem traversal and aggregation backend.
It is not the domain model, not the application service, not the protocol,
not the read model, and not cleanup authority.
```

## Gate Status

Accepted architecture:

1. Product contracts first, pdu adapter second - 🎯 10 🛡️ 10 🧠 7, roughly
   3000-7000 LOC for the first serious Rust scanner slice.
   This is the default. It protects us from pdu API drift and allows a future
   NTFS MFT/APFS/custom scanner adapter without rewriting Flutter or protocol.
2. Direct pdu-shaped read model - 🎯 4 🛡️ 4 🧠 4, roughly 1000-2500 LOC.
   Rejected. It would make `DataTree`, pdu aggregate size, pdu JSON, and pdu
   reporter semantics part of product behavior.
3. Fork pdu into our engine now - 🎯 5 🛡️ 6 🧠 9, roughly 5000-12000 LOC.
   Deferred. Keep as an escape hatch only if measured memory, cancellation, or
   metadata blockers cannot be solved through an adapter.

Implementation rule:

```text
Contracts are Pro. Implementation is MVP.

MVP may scan one target through pdu final tree.
Contracts must already support snapshots, ids, capabilities, issues, paging,
events, lazy metadata, resource budgets, and backend replacement.
```

## Current pdu Baseline

Source-audited baseline:

- crate: `parallel-disk-usage`;
- audited version: `0.23.0`;
- license: Apache-2.0;
- repository: `https://github.com/KSXGitHub/parallel-disk-usage.git`;
- default feature: `cli`;
- useful production dependency shape: `default-features = false`;
- Context7 status: checked, but no usable exact library docs were available in
  the current session because the quota was exceeded. Authoritative facts here
  come from docs.rs, `cargo info`, GitHub README, and local crate source.

Important pdu public surfaces:

| pdu surface | What it is | Product meaning |
|---|---|---|
| `FsTreeBuilder` | real filesystem final-tree builder | scanner backend internals only |
| `TreeBuilder` | generic parallel recursive final-tree builder | optional richer adapter base |
| `DataTree` | private-field tree: name, aggregate size, children | raw adapter evidence |
| `Reporter` / `Event` | synchronous side channel | copied adapter event evidence |
| `ErrorReport` | operation, borrowed path, `io::Error` | raw issue draft only |
| `GetSize` modes | apparent/block/block-count quantity | explicit product measurement profile |
| `HardlinkAware` | Unix hardlink observation/projection helper | evidence, not reclaim truth |
| `DeviceBoundary` | pdu traversal boundary option | mapped from product boundary policy |
| `Reflection` / `JsonData` | pdu inspection and CLI JSON bridge | fixture/diagnostic only |
| `app`, `args`, `visualizer`, `status_board` | CLI host and terminal UI | forbidden in production scanner path |

## Source Facts That Must Shape Code

These are facts verified from `parallel-disk-usage` 0.23.0 source and docs.

1. `DataTree` stores only `name`, aggregate `size`, and `children`.
2. `DataTree::dir(name, inode_size, children)` stores aggregate size as own
   inode size plus child sizes.
3. `DataTree::size()` is not own size and not reclaimable bytes.
4. `DataTree::children().is_empty()` does not mean "file".
5. `TreeBuilder::Info` contains only `size` and `children`.
6. `TreeBuilder` recurses with Rayon `into_par_iter`.
7. `TreeBuilder` callbacks are `Copy + Send + Sync`, so richer side evidence
   needs thread-safe side stores.
8. `FsTreeBuilder` uses `symlink_metadata`, so symlink targets are not followed.
9. `FsTreeBuilder` uses `read_dir` and reports access failures through
   `Reporter`.
10. `FsTreeBuilder` returns a `DataTree` through `From/Into`, not
    `Result<DataTree, Error>`.
11. `Reporter::Event` is non-exhaustive and can carry borrowed path/metadata.
12. Reporter evidence must be copied before callback returns.
13. pdu hardlink detection is Unix-oriented in the crate.
14. `FsTreeBuilder` ignores hardlink recorder errors with `.ok()`.
15. `max_depth` counts deeper sizes but does not store deeper child arrays.
16. pdu README states symlinks are not followed and reflinks are not accounted
    for.
17. pdu CLI can configure global Rayon through `build_global`; daemon code must
    not depend on CLI global setup.
18. pdu JSON/reflection is not product protocol or persistent snapshot format.

## Clean Architecture Layer Contract

Dependency direction:

```text
domain <- application <- infrastructure adapters
domain <- application <- clean-disk-server protocol mapping
Flutter -> protocol client -> application-facing product models
```

`fs_usage_core` domain:

- owns product vocabulary and invariants;
- contains entities/value objects only where they protect product meaning;
- must not import pdu, Tokio, HTTP, WebSocket, Flutter, Drift, GetIt, platform
  APIs, or filesystem IO.

Allowed domain concepts:

- `ScanTarget`;
- `ScanSessionId`;
- `SnapshotId`;
- `NodeId`;
- `NodeRef`;
- `SizeFact`;
- `MeasurementProfile`;
- `BoundaryPolicy`;
- `LinkPolicy`;
- `ScanIssueReason`;
- `ScanQuality`;
- `Capability`;
- cleanup vocabulary such as `DeletePlanId` and reclaim confidence.

`fs_usage_engine` application:

- owns use cases, ports, state machines, publication gate, read-model queries,
  and event sequencing;
- receives `BackendScanOutput`, never pdu raw types;
- decides scan state: created, scanning, converting, publishing, completed,
  degraded, failed, canceled, discarded;
- owns snapshot publication and query truth;
- must remain testable with a fake backend.

Required application ports:

- `ScannerBackend`;
- `MetadataReader`;
- `FileIdentityReader`;
- `ReclaimAccounting`;
- `TrashAdapter`;
- `ScanEventSink`;
- `ReadModelQueryPort`;
- `DeletePlanValidator`;
- `ResourceBudgetPort`.

`fs_usage_pdu` infrastructure:

- is the only crate allowed to import `parallel_disk_usage`;
- owns `PduScannerBackend`, `PduOptionsMapper`, `PduExecutionLane`,
  `PduReporterRecorder`, `PduTreeConverter`, `PduIssueMapper`,
  `PduCapabilityMapper`, and optional side stores;
- converts pdu evidence into product-shaped output;
- does not export pdu types.

`fs_usage_platform` infrastructure:

- owns platform metadata, identity, permission probing, trash/recycle bin,
  storage accounting, filesystem topology, and delete preflight;
- is separate from pdu because pdu scan evidence is not enough for cleanup.

`clean-disk-server` host:

- owns daemon lifecycle, config, local auth/origin policy, resource budgets,
  observability, HTTP routes, WebSocket event delivery, and adapter wiring;
- maps application errors into protocol problem responses;
- never calls pdu directly from route handlers.

`clean_disk_protocol`:

- owns versioned DTOs, event envelopes, problem details, compatibility manifest,
  and schema generation;
- must not import pdu, domain aggregates, Flutter, platform APIs, or storage
  cache types.

Flutter:

- owns presentation state, rows, layout, user selection, cleanup queue UI, and
  confirmation rendering;
- never receives the full tree;
- never derives cleanup authority from selected rows or cached pages.

## Tactical DDD Shape

Use simple DDD. The large scan tree is not a giant aggregate.

Accepted DDD model:

1. Small aggregates plus immutable read models - 🎯 10 🛡️ 10 🧠 7, roughly
   2000-5000 LOC.
   Accepted. `ScanSession` and `DeletePlan` protect lifecycle/safety
   invariants, while `NodeArena` and indexes serve query scale.
2. Full scan tree as one aggregate - 🎯 3 🛡️ 3 🧠 5, roughly 1500-4000 LOC.
   Rejected. A million-node tree should not be a transactional domain object.
3. Anemic everything with repositories only - 🎯 5 🛡️ 5 🧠 3, roughly
   1000-2500 LOC.
   Rejected as default. It hides safety invariants in routes/adapters.

Aggregates:

- `ScanSession`: owns lifecycle, current snapshot id, epoch, cancellation,
  terminal state, and scan quality summary.
- `DeletePlan`: owns current validation, item identities, policy gates,
  confirmation evidence, and reclaim confidence.
- `CleanupOperation`: owns execution state, item outcomes, receipt, retry and
  journal semantics.

Read models:

- `NodeArena`;
- `ChildrenIndex`;
- `SearchIndex`;
- `TopItemsIndex`;
- `IssueIndex`;
- `DetailsProjectionStore`;
- `PathDisplayStore`.

Value objects:

- ids and refs;
- size facts;
- display path;
- native path evidence;
- measurement profile;
- capability flags;
- issue reason;
- privacy class;
- resource profile.

## Port And Adapter Boundary

The scanner port should speak product language:

```text
ScannerBackend::scan(request, event_sink, cancellation)
  -> BackendScanOutput
```

`BackendScanRequest` must include:

- target set;
- measurement profile;
- boundary policy;
- link policy;
- output requirements;
- resource profile;
- privacy policy;
- scan epoch;
- cancellation token.

`BackendScanOutput` must include:

- backend fingerprint;
- adapter decision record;
- root draft nodes or compact arena input;
- aggregate size facts;
- copied issue drafts;
- capability report;
- hardlink/link evidence;
- scan quality facts;
- timing/resource evidence;
- completion state.

`BackendScanOutput` must not include:

- `DataTree`;
- `FsTreeBuilder`;
- `TreeBuilder`;
- pdu `Reporter`;
- pdu `ErrorReport`;
- pdu JSON/reflection;
- raw `std::fs::Metadata`;
- raw `io::Error`;
- cleanup authority.

## Data Flow Contract

Accepted flow:

```text
Flutter command
  -> HTTP command DTO
  -> clean-disk-server route
  -> application use case
  -> ScannerBackend port
  -> fs_usage_pdu adapter
  -> pdu final DataTree + copied reporter evidence
  -> BackendScanOutput
  -> SnapshotPublicationGate
  -> PublishedSnapshot + NodeArena + indexes
  -> HTTP paged queries
  -> Flutter view models
```

Rules:

- HTTP commands start/cancel operations and return ids/status, not full trees;
- HTTP queries return authoritative state and bounded pages;
- WebSocket events are progress/lifecycle/invalidation hints;
- slow WebSocket clients must not block scanner work;
- events may be lost, important state must be queryable;
- snapshot publication is atomic from the query layer point of view;
- canceled or stale pdu output is discarded by `ScanEpoch`;
- Flutter caches are disposable and never authority.

## pdu Adapter Internal Contract

Adapter flow:

```text
BackendScanRequest
  -> PduOptionsMapper
  -> PduExecutionLane
  -> PduReporterRecorder
  -> FsTreeBuilder or custom TreeBuilder
  -> PduRawScanResult
  -> PduTreeConverter
  -> issue/capability/hardlink mappers
  -> BackendScanOutput
```

Implementation choices:

1. `FsTreeBuilder` scan-only path - 🎯 8 🛡️ 8 🧠 6, roughly 900-1800 LOC.
   Good first pdu adapter. Missing rich metadata becomes lazy/degraded facts.
2. custom pdu `TreeBuilder` with side stores - 🎯 8 🛡️ 9 🧠 8, roughly
   1800-3600 LOC.
   Best upgrade when we need node kind, own size, full path, modified time, or
   richer issue correlation during scan.
3. fork pdu to expose streaming nodes - 🎯 6 🛡️ 8 🧠 9, roughly 3000-9000 LOC
   plus upstream maintenance.
   Keep only as a later escape hatch.

Adapter requirements:

- bounded reporter recorder;
- immediate owned copy of borrowed pdu evidence;
- no pdu terminal reporters;
- no pdu CLI args as product config;
- no pdu global thread pool mutation;
- backend fingerprint stored with scan;
- pdu `DataTree` dropped after conversion;
- panic boundary around adapter work;
- low-memory and cancellation outcomes become typed scan states.

## Domain To Infrastructure Mapping

| Product concept | pdu source fact | Mapping rule |
|---|---|---|
| `MeasurementProfile` | `GetApparentSize`, `GetBlockSize`, `GetBlockCount` | explicit request, no platform default |
| `AggregateSizeFact` | `DataTree::size()` | measured aggregate only |
| `OwnSizeFact` | `DataTree::dir` own size is not exposed | side store or lazy metadata |
| `NodeKind` | pdu only has children shape | side store or lazy metadata |
| `ChildCompleteness` | `max_depth` and errors can hide children | explicit completeness state |
| `ScanIssue` | `Event::EncounterError` | copied and mapped with severity/privacy |
| `ProgressHint` | `ReceiveData(Size)` | approximate metadata-read progress |
| `LinkEvidence` | `DetectHardlink` and hardlink list | evidence only, not reclaim truth |
| `BoundaryDecision` | `DeviceBoundary` and device id | capability-tagged traversal decision |
| `DisplayPath` | `OsStringDisplay` / names | display only |
| `PathAuthorityRef` | platform identity APIs | from `fs_usage_platform`, not pdu |
| `DeletePlan` | none | application/platform preflight only |

## SOLID Reading

SRP:

- scanner backend scans;
- platform adapter identifies and validates;
- read model indexes;
- server transports;
- Flutter renders and sends intent.

OCP:

- adding MFT/APFS/custom scanner means adding a `ScannerBackend` adapter, not
  editing domain/protocol concepts.

LSP:

- every scanner backend must preserve `BackendScanOutput` semantics: final
  completion, capability report, issue report, and no cleanup authority.

ISP:

- split ports by use case. Do not create one `FilesystemService` that scans,
  deletes, accounts, reads metadata, and opens Finder.

DIP:

- application depends on scanner/platform/cache/event abstractions;
- pdu, OS APIs, HTTP, WebSocket, and Flutter depend inward through adapters.

## Pre-Coding Stop Gates

Do not start real pdu integration until these are true:

```text
gate_domain_has_no_pdu_or_io_imports
gate_application_has_scanner_backend_port
gate_fake_backend_can_publish_snapshot
gate_node_ref_contains_snapshot_id
gate_node_arena_is_read_model_not_aggregate
gate_query_children_is_paged
gate_event_stream_is_not_authoritative_truth
gate_protocol_dtos_are_separate_from_domain
gate_backend_output_has_capability_report
gate_delete_plan_requires_current_identity_preflight
```

Do not start cleanup execution until these are true:

```text
gate_platform_identity_revalidation_exists
gate_reclaim_estimate_confidence_exists
gate_trash_adapter_contract_exists
gate_operation_journal_contract_exists
gate_stale_snapshot_blocks_delete_plan
gate_unknown_capability_fails_closed
```

Do not expose Flutter scan UI to real data until these are true:

```text
gate_flutter_never_receives_full_tree
gate_store_maps_protocol_dto_to_app_model
gate_visible_rows_are_disposable_cache
gate_reconnect_rehydrates_from_http_state
gate_progress_footer_uses_events_as_hints
gate_destructive_ui_uses_delete_plan_not_selection
```

## First PR Shape

Recommended first implementation PR:

1. `fs_usage_core` ids, size facts, issue/capability vocabulary - 🎯 9 🛡️ 9
   🧠 5, roughly 700-1500 LOC.
2. `fs_usage_engine` scan session, fake backend, publication gate, in-memory
   node arena, paged children query - 🎯 9 🛡️ 9 🧠 7, roughly 1600-3200 LOC.
3. Contract tests proving no pdu dependency outside `fs_usage_pdu` - 🎯 10
   🛡️ 10 🧠 4, roughly 300-900 LOC.

What to postpone:

- pdu real adapter, until fake backend gates pass;
- rich metadata, until lazy/details contract is stable;
- cleanup execution, until delete-plan preflight exists;
- UI polish, until data flow is stable;
- custom pdu `TreeBuilder`, until `FsTreeBuilder` adapter proves its gaps.

## Critical Tests From pdu Facts

Minimum tests:

```text
contract_datatree_size_is_aggregate_only
contract_empty_children_not_file_kind
contract_max_depth_hidden_nodes_not_cleanup_targets
contract_error_report_copied_before_callback_returns
contract_pdu_result_not_result_type
contract_hardlink_error_not_silent_success
contract_hardlink_projection_not_reclaim_truth
contract_non_utf8_display_not_path_authority
contract_pdu_json_not_product_protocol
contract_no_global_rayon_build_global_in_daemon_path
contract_late_cancelled_backend_output_discarded
contract_snapshot_publish_atomic_for_queries
contract_cursor_bound_to_snapshot_and_query_shape
contract_unknown_capability_disables_cleanup
```

## Architecture Review Questions

Use these questions in every scanner PR:

1. Is this type domain truth, application state, adapter evidence, protocol DTO,
   read model, or Flutter view model?
2. Does this code import `parallel_disk_usage` outside `fs_usage_pdu`?
3. Can the same port be implemented by an NTFS MFT or fake backend?
4. Is this size fact measured, logical, allocated, adjusted projection, or
   reclaim estimate?
5. Does this row/page/cursor depend on pdu child indexes?
6. Does this operation remain correct after reconnect?
7. Does a slow WebSocket client block scanner work?
8. Can a stale `NodeRef` create a delete plan?
9. Are raw paths redacted from logs, metrics, cursors, and support bundles?
10. Does this path/metadata fact come from scan evidence or current preflight?

## Final Rule

```text
pdu gives speed.
Clean Disk gives architecture, safety, protocol, UX, and cleanup correctness.
```

If code makes pdu concepts visible above `fs_usage_pdu`, stop and redesign the
boundary before continuing.

## Sources

- [parallel-disk-usage 0.23.0 crate docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/)
- [DataTree 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/data_tree/struct.DataTree.html)
- [FsTreeBuilder 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/fs_tree_builder/struct.FsTreeBuilder.html)
- [TreeBuilder 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/tree_builder/struct.TreeBuilder.html)
- [Reporter/Event 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/reporter/event/enum.Event.html)
- [pdu README limitations](https://github.com/KSXGitHub/parallel-disk-usage#limitations)
- [Rayon ThreadPoolBuilder::build_global docs](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html#method.build_global)
- [Alistair Cockburn Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture)
- [Microsoft Azure Tactical DDD guidance](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/tactical-domain-driven-design)
- Local source audit:
  `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/parallel-disk-usage-0.23.0`
