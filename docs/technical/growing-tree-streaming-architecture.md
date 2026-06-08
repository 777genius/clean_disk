# Growing Tree Streaming Architecture

Last updated: 2026-06-08.

This document records the accepted architecture direction for showing folders
and files while a scan is still running.

## Decision

Clean Disk will support a growing tree as a backend capability, not as a pdu
contract.

The UI may render discovered folders and files while scanning, with aggregate
sizes that grow over time, but this view is partial evidence only. Cleanup,
receipts, restore, search authority, and final pagination remain tied to the
published scan snapshot and validated cleanup plans.

Accepted shape:

```text
scanner backend
  -> adapter-private traversal events
  -> fs_usage_engine GrowingTreeEvent batches
  -> clean-disk-server protocol events
  -> Flutter scan application models
  -> TreeTable partial row view models

final scanner result
  -> ScanSnapshotDraft
  -> ScanSnapshot
  -> Rust read-model queries
  -> Flutter authoritative rows
```

The two flows are related but not the same. Growing tree events are a live
projection. `ScanSnapshotPublished` is the authority boundary.

## Options

1. Growing tree as engine-owned partial read model - confidence 8,
   reliability 8, complexity 8, roughly 2500-6000 LOC.
   This is the selected direction. It keeps Clean Architecture intact and lets
   pdu, a pdu fork, an upstream pdu streaming API, or a custom scanner feed the
   same engine contract.
2. Fork pdu and expose pdu traversal callbacks directly to protocol/UI -
   confidence 5, reliability 5, complexity 8, roughly 2500-7000 LOC.
   Rejected as the product contract. A fork may be one adapter, but pdu callback
   names, paths, and traversal ordering must not cross the adapter boundary.
3. Fake growing tree from progress counters - confidence 4, reliability 7,
   complexity 3, roughly 500-1500 LOC.
   Rejected. It looks alive but cannot honestly show folders, child state, or
   growing aggregate sizes.

## Domain Language

- Final node: a `NodeId` inside a published `ScanSnapshot`.
- Partial node: a `PartialNodeId` inside one running scan session.
- Growing event: a `GrowingTreeEvent` describing discovered, updated, completed,
  skipped, stale, or issue-bearing partial nodes.
- Growing batch: a bounded, session-scoped group of growing events emitted to
  avoid one event per filesystem item.
- Authority boundary: the moment `ScanSnapshotPublished` appears.

`PartialNodeId` is intentionally separate from `NodeId`. It must never be used
for cleanup commands, persisted delete queues, receipts, history, or restore.

## Layer Responsibilities

### fs_usage_core

Owns stable value objects:

- `PartialNodeId`;
- final `NodeId`;
- size facts;
- node kind;
- child completeness;
- scan issues.

It does not know pdu, protocol DTOs, HTTP, WebSocket, Flutter, or UI state.

### fs_usage_engine

Owns application contracts:

- `GrowingTreeEvent`;
- `GrowingTreeBatch`;
- batch validation;
- future partial read-model state machine;
- capability-aware scan session behavior.

Engine events are backend-neutral. A backend may produce growing events through
a pdu patch, a custom scanner, platform scanner, or future pdu API.

### fs_usage_pdu

Owns pdu translation only.

Current `parallel-disk-usage 0.24.0` does not expose path-bearing node streaming
callbacks as a named public product API. However our adapter already owns the
`TreeBuilder::get_info` closure used for pdu traversal. That closure sees each
visited path, node kind, and local metadata size. `fs_usage_pdu` converts that
adapter-private traversal evidence into `GrowingTreeEvent` batches through a
bounded channel and reports:

```text
growing_tree_streaming = supported
```

Current pdu-backed growing tree semantics:

- partial nodes are discovered as pdu visits paths;
- directory aggregate sizes grow by adding each visited descendant size to its
  materialized ancestors;
- max-depth is respected for partial node materialization, while skipped deeper
  descendants still contribute to visible ancestor sizes;
- file-like nodes may complete as soon as their metadata size is known;
- the root may receive a final completion update immediately before snapshot
  publication, but the adapter must not replay completion for every final node
  in a huge tree because the final snapshot replaces the partial view;
- cancellation is still not fully cooperative because pdu traversal may continue
  until the current worker finishes.

If pdu later adds stronger streaming callbacks, only `fs_usage_pdu` should change
to map that API into the same `GrowingTreeEvent` batches.

### clean-disk-server

Owns host concerns:

- capability DTO mapping;
- WebSocket event batching;
- backpressure;
- replay gap behavior;
- local auth and origin policy;
- protocol versioning.

It must not expose pdu event names, pdu `DataTree`, pdu JSON, or raw pdu paths.

### Flutter feature

Owns presentation and application state:

- capability-gated growing tree mode;
- partial rows marked as partial/scanning/complete;
- no cleanup authority from partial rows;
- replacement of partial rows by authoritative snapshot rows after
  `ScanSnapshotPublished`;
- virtualized rendering with throttled updates.

Flutter must not sort/filter the full scan tree locally. Partial sort is either
discovered order or a bounded backend projection marked incomplete.

## Event Semantics

Minimum internal event set:

```text
NodeDiscovered
  partial node exists, name/kind/parent are known

NodeSizeUpdated
  aggregate size evidence changed, usually monotonically grows

NodeCompleted
  subtree traversal for this partial node finished

NodeIssueRecorded
  permission, metadata, boundary, or adapter issue was observed
```

Future protocol may add:

```text
GrowingTreeBatchPublished
  sessionId
  scannedItems
  events[]
```

This event is optional and capability-gated. Clients that do not understand it
must keep using progress events and final snapshot queries.

## UI Semantics

Growing rows show evidence state:

```text
discovered
scanning
complete
skipped
stale
```

Size display rules:

- partial directory sizes may grow;
- partial directory sizes are visually distinct from final sizes;
- rows with incomplete descendants are not authoritative;
- final snapshot rows replace partial rows when available;
- partial rows cannot be added to cleanup queue unless revalidated through the
  final snapshot and cleanup plan flow.

## Backpressure Rules

Do not emit one WebSocket message per file.

Accepted default:

```text
scanner callback
  -> bounded adapter queue
  -> engine coalescer
  -> 100-250 ms batch
  -> max event count per batch
  -> lossy progress allowed, terminal/final events not lossy
```

If overload happens, the UI should show that live tree updates are degraded and
fall back to progress plus final snapshot.

## SOLID Mapping

- SRP: scanner traversal, partial read model, protocol mapping, and UI rendering
  each have one reason to change.
- OCP: adding a pdu streaming API or Windows-native scanner adds an adapter, not
  a new UI contract.
- LSP: any scanner backend that claims growing tree support must satisfy the
  same event ordering and authority rules.
- ISP: final snapshot queries stay separate from growing tree events.
- DIP: app and feature code depend on engine/protocol abstractions, not pdu.

## Stop Rules

Stop implementation if any of these happen:

- pdu `DataTree` or pdu `Event` appears in protocol, Flutter, or reusable
  engine APIs;
- partial node IDs are accepted by cleanup commands;
- UI treats partial sizes as final;
- WebSocket sends unbounded per-file events;
- reconnect replay stores every historical growing batch instead of the latest
  bounded progress hint per session;
- final snapshot publication depends on Flutter consuming partial events;
- a backend reports growing tree support without contract tests for batch
  ordering, cancellation, and authority separation.

## First Implementation Slices

1. Add backend capability and engine contract types.
2. Add protocol DTO for growing tree batches behind capability gates.
3. Add fake scanner support for deterministic tests.
4. Add Flutter domain/store handling for partial row batches.
5. Add TreeTable visual state for partial/scanning/complete rows.
6. Coalesce replay/runtime buffers so growing batches behave as bounded
   progress hints, not unbounded history.
7. Add pdu-backed growing events through adapter-private `TreeBuilder`
   traversal evidence.
8. Run large-tree UI and backpressure benchmarks.

Current repository state:

- `PartialNodeId`, `growing_tree_streaming`, `GrowingTreeEvent`, and
  `GrowingTreeBatch` exist in Rust core/engine contracts.
- The daemon protocol maps `growing_tree_batch` WebSocket events.
- Flutter maps growing batches into partial, non-authoritative rows.
- The scan table can render running partial rows but disables selection,
  context menu, and cleanup authority for them.
- Rust and Flutter fake adapters can publish deterministic growing batches.
- `parallel-disk-usage` remains private to `fs_usage_pdu`, but the pdu adapter
  now emits real growing batches before final snapshot publication using its
  adapter-owned traversal closure.
- Future pdu upstream callbacks, a pdu fork, or a custom scanner can replace the
  adapter internals without changing engine, server protocol, or Flutter
  contracts.
