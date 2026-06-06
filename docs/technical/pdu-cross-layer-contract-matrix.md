# pdu Cross-Layer Contract Matrix

This document maps `parallel-disk-usage` internals into Clean Disk layers. Use it
when designing or reviewing the first scanner code. It answers one question:

```text
Given a pdu fact, where is it allowed, what product contract does it become,
and what must never leak across the boundary?
```

This is a review matrix, not an implementation plan.

## Executive Rule

```text
pdu can traverse and aggregate quickly.
Clean Disk owns meaning, identity, query truth, safety, protocol, and UI.
```

Top 3 integration shapes:

1. pdu as private anti-corruption adapter - 🎯 10 🛡️ 10 🧠 7, roughly
   3000-7000 LOC for the first production scanner/read-model slice.
   Accepted. This keeps `parallel-disk-usage` replaceable and prevents pdu
   semantics from becoming product language.
2. pdu as reusable product engine - 🎯 5 🛡️ 5 🧠 5, roughly 1500-3500 LOC now.
   Rejected. It would make `DataTree`, pdu JSON, pdu reporter events, and pdu
   size semantics stable app contracts.
3. pdu fork as our core - 🎯 5 🛡️ 7 🧠 9, roughly 5000-12000 LOC plus upstream
   maintenance.
   Deferred. Only revisit if adapter spikes prove impossible memory,
   cancellation, or metadata blockers.

## Layer Vocabulary

Use these names consistently:

| Layer | Owns | Does not own |
|---|---|---|
| `fs_usage_core` | domain language and pure invariants | pdu, IO, async runtime, protocol DTOs |
| `fs_usage_engine` | use cases, ports, state machines, read-model publication | pdu concrete types, HTTP, Flutter |
| `fs_usage_pdu` | pdu execution and anti-corruption mapping | public protocol, domain aggregates |
| `fs_usage_platform` | current platform identity, metadata, accounting, trash | pdu traversal policy |
| `clean-disk-server` | process lifecycle, transport, auth, observability | domain rules, pdu internals |
| `clean_disk_protocol` | versioned DTOs and schema | pdu JSON, domain aggregates |
| Flutter feature packages | presentation state and user intent | full scan tree, cleanup authority |

## pdu Source Surface Matrix

| pdu source surface | Real responsibility | Allowed layer | Product contract | Must not leak |
|---|---|---|---|---|
| `FsTreeBuilder` | real filesystem final-tree builder | `fs_usage_pdu` | `ScannerBackend` implementation detail | domain/app/protocol/Flutter |
| `TreeBuilder` | generic parallel final-tree recursion | `fs_usage_pdu` | optional custom adapter path | product streaming API claims |
| `TreeBuilder::Info` | `size` plus child names | `fs_usage_pdu` | adapter probe output | metadata contract |
| `DataTree` | recursive aggregate size tree | `fs_usage_pdu` | raw scan evidence | read model, protocol, cache |
| `DataTree::size()` | aggregate measured size | converter only | `AggregateSizeFact` | own size, reclaim estimate |
| `DataTree::children()` | retained children vector | converter only | arena ingestion input | pagination identity |
| `Reporter::Event` | synchronous side-channel callback | `fs_usage_pdu` | adapter event draft | domain event, WebSocket event |
| `ErrorReport` | operation, borrowed path, `io::Error` | `fs_usage_pdu` | `ScanIssueDraft` | protocol error, UI text |
| `ProgressAndErrorReporter` | CLI reporter thread and relaxed counters | diagnostics only | none for production | event pipeline |
| `GetSize` modes | apparent/block/block-count measurement | `fs_usage_pdu` | `MeasurementProfile` mapping | implicit defaults |
| `HardlinkAware` | Unix hardlink observation and projection | `fs_usage_pdu` | `LinkEvidence` | reclaim truth |
| `HardlinkList` | `(dev, ino)` keyed hardlink record | `fs_usage_pdu` | confidence evidence | cleanup accounting authority |
| `DeviceBoundary` | pdu traversal option | `fs_usage_pdu` | mapped from `BoundaryPolicy` | universal platform promise |
| `OsStringDisplay` | display wrapper for OS strings | `fs_usage_pdu` | display evidence | path authority |
| `Reflection` | public-field tree bridge | fixtures/diagnostics | test fixture draft | product persistence |
| `JsonData` | pdu CLI JSON interchange | diagnostics only | fixture import/export optional | protocol schema |
| `app`, `args`, `runtime_error` | CLI host and exit behavior | not production path | none | daemon host behavior |
| `visualizer`, `status_board`, `bytes_format` | terminal UI formatting | diagnostics only | none | Flutter/UI contract |

## Product Contract Matrix

| Product contract | Built from pdu? | Owner | Notes |
|---|---:|---|---|
| `ScanSessionId` | no | engine | created before pdu runs |
| `ScanEpoch` | no | engine | discards late canceled pdu output |
| `BackendRunId` | yes, adapter-local | `fs_usage_pdu` | diagnostic only |
| `SnapshotId` | no | engine | assigned at publish gate |
| `NodeId` | no | engine | stable only inside one snapshot |
| `NodeRef` | no | protocol/application | contains snapshot identity |
| `SizeFact.aggregate_measured` | yes | engine converter | from pdu aggregate size |
| `SizeFact.own_measured` | partially | platform/side store | pdu final `DataTree` does not expose it |
| `NodeKind` | partially | platform/side store | `children().is_empty()` is not enough |
| `ChildCompleteness` | partially | engine/converter | requires max-depth, errors, boundary, cull facts |
| `ScanIssue` | yes, mapped | engine issue taxonomy | pdu error is raw evidence |
| `ScanQuality` | yes, plus platform | engine | combines issues, gaps, overflow, permissions |
| `CapabilitySnapshot` | yes, plus platform | engine/server | includes pdu version and adapter decisions |
| `ReadModelIndex` | no | engine | built from published snapshot |
| `Cursor` | no | query layer | opaque, snapshot/query bound |
| `DeletePlan` | no | application/platform | never from pdu scan output alone |
| `ReclaimEstimate` | no direct | accounting adapter | pdu size is only evidence |

## Size Semantics Contract

pdu has fast size modes, but product size language must be explicit.

Source facts:

- `GetApparentSize` uses `metadata.len()`;
- Unix `GetBlockSize` uses `metadata.blocks() * 512`;
- Unix `GetBlockCount` uses `metadata.blocks()`;
- pdu CLI default quantity differs by platform;
- `DataTree::dir` rolls child sizes into parent size;
- pdu README says reflinks are not accounted for.

Product contract:

```text
MeasurementProfile
  requested_quantity
  platform_support
  backend_size_mode
  confidence
  limitations
```

Rules:

- no implicit platform default in product request;
- every size fact carries measurement type;
- aggregate size, own size, allocated size, logical size, adjusted hardlink
  projection, and reclaim estimate are separate concepts;
- pdu size can support scan ranking, but not delete-time reclaim truth;
- Flutter displays size label from product metadata, not pdu type names.

## Identity And Path Contract

pdu's path/name evidence is not enough for cleanup authority.

Source facts:

- `FsTreeBuilder` gives `OsStringDisplay` names in `DataTree`;
- `OsStringDisplay` uses UTF-8 display when possible, otherwise debug display;
- pdu `ErrorReport` carries a borrowed `&Path`;
- pdu hardlink identity uses Unix `(dev, ino)`;
- non-Unix device identity support is weaker.

Product contract:

```text
DisplayPath
  user-facing string

NativePathEvidence
  raw platform path bytes or platform representation
  privacy class

PathAuthorityRef
  platform identity facts
  freshness
  validation time
```

Rules:

- display path is never authority;
- raw path string is never delete authority;
- `NodeRef` is snapshot id plus node id, not path;
- platform identity is loaded or reloaded through `fs_usage_platform`;
- delete preflight revalidates path, metadata, and identity under current
  process permissions.

## Completeness And Materialization Contract

pdu can hide children without changing aggregate size.

Source facts:

- `max_depth` counts deeper sizes but stores no deeper child arrays;
- `par_retain` can remove children while parent aggregate stays;
- read errors return partial trees through reporter side channel;
- device boundary may stop descent;
- an empty `children` vector can mean many things.

Product contract:

```text
ChildCompleteness
  complete
  limited_by_depth
  unreadable
  boundary_stopped
  projection_culled
  lazy_unknown
```

Rules:

- file/folder kind is not inferred from `children().is_empty()`;
- hidden descendants are not selectable cleanup targets;
- UI disclosure state depends on materialization/completeness, not just
  children count;
- query API must report degraded or unknown child state honestly.

## Issue And Diagnostics Contract

pdu error events are evidence, not final product errors.

Source facts:

- `ErrorReport` has `operation`, `path`, and `io::Error`;
- operations are `symlink_metadata`, `read_dir`, and access entry;
- `AccessEntry` points at the parent directory;
- reporter event data may be borrowed;
- pdu still returns a `DataTree` after many errors.

Product contract:

```text
ScanIssue
  stable_reason
  severity
  operation
  privacy_class
  redacted_path_sample
  platform_code
  capability_impact
  remediation_hint_code
```

Rules:

- copy reporter evidence immediately;
- map pdu operation to stable issue reason;
- permission-denied issues degrade scan quality unless root target cannot be
  meaningfully scanned;
- error text is not a stable identifier;
- UI localizes from issue code, not pdu operation text;
- support bundles redact path samples by default.

## Progress And Event Contract

pdu reporter is not our event bus.

Source facts:

- `ReceiveData(size)` increments pdu progress counters per metadata read;
- pdu `ProgressAndErrorReporter` uses relaxed atomics and a helper thread;
- pdu progress is not exact node publication or final tree completeness.

Product event flow:

```text
pdu reporter callback
  -> PduReporterRecorder
  -> engine coalescer
  -> sequenced session event
  -> WebSocket hint
  -> Flutter reconciles by HTTP query
```

Rules:

- progress events are hints;
- terminal state and snapshot publication are queryable through HTTP;
- slow clients do not block scan workers;
- event queues are bounded;
- WebSocket payloads do not carry full tree pages.

## Hardlink, Reflink, And Reclaim Contract

pdu hardlink support is useful but narrow.

Source facts:

- pdu hardlink detection is Unix-oriented;
- `HardlinkList` records `(dev, ino)`, size, link count, and detected paths;
- hardlink add can detect size/link count conflicts;
- `FsTreeBuilder` currently discards hardlink recorder errors with `.ok()`;
- pdu hardlink dedupe mutates aggregate size projection;
- hardlink summary can panic if detected paths exceed link count;
- pdu is ignorant of reflinks.

Product contract:

```text
LinkEvidence
  observed_hardlinks
  conflict_state
  adjusted_projection
  confidence
  limitations

ReclaimEstimate
  current_preflight
  platform_accounting
  confidence
  shared_extent_unknowns
```

Rules:

- hardlink evidence can improve scan explanation;
- hardlink evidence does not authorize cleanup;
- adjusted projection is not primary measured size;
- reflink/shared-extent accounting is a separate platform/accounting adapter;
- panics or impossible hardlink evidence degrade backend confidence.

## Runtime And Resource Contract

pdu is parallel. The daemon must own resource policy.

Source facts:

- pdu `TreeBuilder` uses Rayon parallel iteration;
- pdu CLI can call `ThreadPoolBuilder::build_global`;
- global Rayon pool setup is process-wide and one-time;
- pdu CLI has HDD auto-thread heuristics.

Product contract:

```text
ResourceProfile
  balanced | fast | background
  max_threads
  io_pressure_policy
  cancellation_budget
  memory_budget
```

Rules:

- route handlers never call pdu directly;
- no production daemon path calls pdu CLI `App` or `build_global`;
- scanner runs in a daemon-owned execution lane;
- resource policy is per operation, not hidden process global state;
- memory peak from pdu tree plus conversion plus indexes is tracked;
- cancellation can discard late output even if pdu cannot stop instantly.

## Protocol And DTO Contract

pdu JSON is not Clean Disk protocol.

Source facts:

- `DataTree` does not serialize directly;
- pdu JSON goes through `Reflection` and `JsonData`;
- JSON includes pdu schema/binary provenance and unit-tagged body;
- pdu JSON shape changes around single root vs multi-root CLI behavior.

Product contract:

```text
domain/application model
  -> protocol DTO
  -> HTTP/WebSocket JSON
  -> Flutter data DTO
  -> Flutter application model
  -> view model
```

Rules:

- protocol schema is product-owned;
- no protocol DTO mirrors pdu JSON;
- exact bytes, counters, ids, and sequences are Flutter-web safe;
- unknown enum values fail closed for destructive actions;
- compatibility manifest is served before risky commands;
- generated clients are adapters, not domain model.

## Query And Read Model Contract

pdu final tree is an ingestion input, not a query engine.

Source facts:

- `DataTree` owns recursive `Vec` children;
- pdu sort/cull mutate the tree;
- pdu sort uses unstable sorting;
- pdu has no paginated child query, search index, top-files index, or details
  projection.

Product contract:

```text
PublishedSnapshot
  -> NodeArena
  -> ChildrenIndex
  -> SearchIndex
  -> TopItemsIndex
  -> IssueIndex
  -> DetailsProjectionStore
```

Rules:

- snapshot is immutable after publication;
- query pages are bounded;
- sort/filter/search run in Rust read model;
- cursor is opaque and bound to snapshot plus query shape;
- Flutter never receives or sorts the full tree;
- details can be lazily enriched and must expose freshness.

## Destructive Workflow Contract

pdu does not participate in destructive authority.

Source facts:

- pdu output is scan evidence;
- pdu has no trash/recycle bin adapter;
- pdu has no current identity revalidation;
- pdu size cannot predict exact reclaim on snapshots, reflinks, cloud files, or
  shared extents.

Product cleanup flow:

```text
Flutter selected rows
  -> NodeRefs
  -> BuildDeletePlan command
  -> application validates snapshot compatibility
  -> platform identity revalidation
  -> accounting confidence
  -> confirmation from current DeletePlan
  -> TrashAdapter or cleanup adapter
  -> OperationJournal and Receipt
```

Rules:

- selection is not queue;
- queue is not delete authority;
- scan snapshot is not delete authority;
- current `DeletePlan` is the confirmation source;
- unknown capability or stale snapshot disables destructive action.

## What To Prove Before pdu Adapter Code

The first PR should prove architecture with fake data before pdu enters.

Required gates:

```text
gate_domain_has_no_pdu_or_io_imports
gate_application_can_scan_with_fake_backend
gate_snapshot_publish_is_atomic
gate_node_ref_is_snapshot_scoped
gate_children_query_is_paged
gate_cursor_is_opaque
gate_backend_output_has_capabilities
gate_issue_taxonomy_exists
gate_event_stream_is_hint_not_truth
gate_protocol_dtos_are_separate
```

Only after those gates:

```text
implement_fs_usage_pdu_adapter
copy_reporter_evidence
convert_datatree_to_arena
drop_datatree_after_ingestion
publish_degraded_scan_quality
run_pdu_contract_fixtures
```

## Highest-Risk Global Zones

1. Side-store correlation for custom `TreeBuilder` - 🎯 7 🛡️ 9 🧠 8, roughly
   600-1400 LOC.
   Needed if we want node kind, own size, metadata, and richer issue evidence
   during scan. Must not rely on display path or child vector index.
2. Memory peak during final-tree ingestion - 🎯 7 🛡️ 8 🧠 8, roughly
   700-1800 LOC.
   pdu `DataTree`, adapter evidence, arena, and indexes can overlap. Must be
   measured and bounded.
3. Delete safety separation - 🎯 10 🛡️ 10 🧠 7, roughly 1000-2500 LOC.
   Scan rows are useful for review but must never become destructive authority.
4. Resource governance - 🎯 8 🛡️ 9 🧠 8, roughly 800-2200 LOC.
   pdu is fast because it is parallel. Product default must protect UI and user
   machine responsiveness.
5. Size honesty - 🎯 9 🛡️ 9 🧠 8, roughly 900-2400 LOC.
   Users will trust reclaim numbers. pdu aggregate size must be clearly
   separated from reclaim estimate.

## First Scanner Code Review Checklist

Review every scanner PR with this list:

1. Does any non-`fs_usage_pdu` crate import `parallel_disk_usage`?
2. Does any public type include `DataTree`, `FsTreeBuilder`, `TreeBuilder`,
   `Reporter`, `ErrorReport`, `JsonData`, or pdu `Bytes`/`Blocks`?
3. Can a fake backend implement the same `ScannerBackend` contract?
4. Is `BackendScanOutput` product-shaped and capability-bearing?
5. Is every pdu reporter event copied before callback return?
6. Is scan completion queryable even if WebSocket events are lost?
7. Is `DataTree::size()` mapped only to aggregate measured size?
8. Is `children().is_empty()` never used as file kind?
9. Are pdu sort/cull/dedupe helpers kept out of product query semantics?
10. Does cancellation use epoch discard even if pdu returns late?
11. Is pdu JSON absent from product protocol and cache schema?
12. Are raw paths absent from logs, metrics, cursors, tokens, and ordinary
    support bundles?
13. Is cleanup still impossible without current platform preflight?
14. Are unknown capabilities fail-closed for destructive actions?

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
