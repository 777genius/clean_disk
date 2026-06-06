# pdu Data Flow Architecture Contract

This document fixes the accepted data flow for the pdu-backed scanner before
the first Rust implementation. It is a source-of-truth for data ownership,
command/query/event flow, and layer boundaries.

Core rule:

```text
pdu discovers and aggregates.
fs_usage_pdu translates.
fs_usage_engine owns session, snapshot, read models, and query truth.
clean-disk-server exposes protocol.
Flutter renders view models and sends user intent.
Cleanup authority comes only from current preflight, never from scan rows.
```

## Accepted Flow Shape

Top 3 architecture options:

1. Engine-owned read model with pdu as anti-corruption adapter - 🎯 10 🛡️ 10
   🧠 7, roughly 2500-5500 LOC for the first serious end-to-end slice.
   Accepted. It keeps pdu replaceable, keeps Flutter light, and gives one
   authoritative place for pagination, search, sort, details, and cleanup
   validation inputs.
2. pdu-shaped data flow where `DataTree` is converted directly to protocol DTOs
   - 🎯 3 🛡️ 3 🧠 3, roughly 800-2000 LOC.
   Rejected. It is quick but leaks pdu semantics, cannot represent partial
   scan quality well, and makes future MFT/custom scanner adapters painful.
3. Flutter-owned full tree and local indexing - 🎯 4 🛡️ 4 🧠 5, roughly
   1800-4200 LOC.
   Rejected for product data. It can work for demos, but it does not scale to
   million-node trees and makes cleanup authority unsafe.

## End-To-End Scan Flow

```text
Flutter ScanStore
  -> ScanRepository
  -> CleanDiskApiClient
  -> HTTP start-scan command
  -> clean-disk-server route
  -> ScanApplicationService
  -> ScanSession aggregate
  -> OutputRequirements
  -> ScannerBackend port
  -> fs_usage_pdu adapter
  -> pdu FsTreeBuilder or custom TreeBuilder
  -> PduRawScanResult
  -> PduTreeConverter
  -> BackendScanOutput
  -> SnapshotPublicationGate
  -> NodeArena + ReadModelIndexes
  -> ScanSession current_snapshot_id
  -> HTTP paged queries and WebSocket notifications
  -> Flutter view models
```

Rules:

- HTTP start command returns `session_id` quickly and does not return a full
  tree.
- pdu raw output is private to `fs_usage_pdu`.
- `BackendScanOutput` is product-shaped and contains no pdu concrete type.
- `SnapshotPublicationGate` is the only point where a scan result becomes
  queryable truth.
- Flutter never owns the full scan tree.
- WebSocket events notify and invalidate. HTTP queries return authoritative
  pages and status.

## Data Ownership Map

| Data | Owner | Not owner |
|---|---|---|
| user selection | Flutter presentation/application | Rust scanner, pdu |
| scan command DTO | clean-disk-server protocol | domain, pdu |
| scan session lifecycle | `fs_usage_engine` application + `ScanSession` | transport, Flutter widgets |
| backend capability | `fs_usage_engine` contract, adapter reports | UI guesses |
| pdu traversal output | `fs_usage_pdu` private | protocol, Flutter, domain |
| node arena | `fs_usage_engine` read model | pdu, Flutter |
| query indexes | `fs_usage_engine` read model | pdu sort/cull, Flutter sort |
| protocol DTOs | `clean_disk_protocol` / server adapter | reusable `fs_usage_*` core |
| visible rows | Flutter view model | cleanup authority |
| delete plan | application cleanup workflow | UI selection, pdu row |
| current file identity | `fs_usage_platform` adapter | stale scan row |
| reclaim estimate | accounting adapter + delete plan | pdu aggregate size |

## Command Flow

Commands change server-side state or start operations.

```text
HTTP command
  -> parse DTO
  -> authorize token/origin/scope
  -> map DTO to application command
  -> call use case
  -> persist/transition application state
  -> return command receipt/status
  -> emit bounded event notification
```

Command examples:

- `POST /scan-sessions`;
- `POST /scan-sessions/{id}/start`;
- `POST /scan-sessions/{id}/cancel`;
- `POST /delete-plans`;
- `POST /delete-plans/{id}/validate`;
- later `POST /cleanup-operations`.

Command rules:

- commands are idempotent where retry is possible;
- destructive commands require operation ids and confirmation evidence;
- command handlers do not call pdu directly;
- command handlers never return recursive full trees;
- command success does not require WebSocket delivery.

## Query Flow

Queries read authoritative server state.

```text
HTTP query
  -> parse query DTO
  -> authorize
  -> map to application query
  -> ReadModelQueryStore
  -> page/projection DTO
  -> Flutter repository maps DTO to app model
```

Query examples:

- `GET /capabilities`;
- `GET /scan-sessions/{id}`;
- `GET /snapshots/{id}/children?parent=...&cursor=...`;
- `GET /snapshots/{id}/node-details?node=...`;
- `GET /snapshots/{id}/search?...`;
- `GET /snapshots/{id}/top-items?...`;
- `GET /scan-sessions/{id}/issues?...`;
- `GET /delete-plans/{id}`.

Query rules:

- pages are bounded;
- sort/filter/search are typed server-side contracts;
- cursors include snapshot/query/sort/filter identity;
- exact sizes and large counters use web-safe representation;
- stale snapshot or incompatible protocol is a visible state, not silent data.

## Event Flow

WebSocket is for progress, lifecycle, invalidation, and small state changes.

```text
application event
  -> event coalescer
  -> per-session sequence
  -> per-client bounded queue
  -> WebSocket event DTO
  -> Flutter event client
  -> store reconciliation
  -> HTTP query if authoritative data is needed
```

Event classes:

- `scan_session_state_changed`;
- `scan_progress_hint`;
- `scan_issue_summary_changed`;
- `snapshot_published`;
- `snapshot_invalidated`;
- `query_result_invalidated`;
- `delete_plan_state_changed`;
- `daemon_capability_changed`;
- `client_resync_required`.

Event rules:

- no full tree pages over WebSocket;
- no large search results over WebSocket;
- no delete authority over WebSocket;
- events are sequenced per session;
- slow clients get `lag/resync_required` or disconnect;
- reconnect starts with HTTP state query, then event subscription from sequence
  if supported.

## Runtime State Ownership

Runtime state must have one writer per operation. This prevents HTTP handlers,
WebSocket tasks, scanner workers, and Flutter reconnect logic from inventing
different truths.

Top 3 runtime ownership options:

1. Engine-owned operation supervisor per scan/delete operation - 🎯 10 🛡️ 10
   🧠 7, roughly 1200-3000 LOC.
   Accepted. Each operation has one command owner, one state machine, bounded
   inputs, and queryable state.
2. Shared mutable registry with locks around session state - 🎯 5 🛡️ 5 🧠 4,
   roughly 700-1800 LOC.
   Rejected as default. It is easy to start, but transition rules spread across
   HTTP routes, worker callbacks, and event senders.
3. Transport-owned state where WebSocket connection drives scan status - 🎯 2
   🛡️ 2 🧠 3, roughly 500-1500 LOC.
   Rejected. A scan must outlive one UI tab, one desktop window, and one
   WebSocket connection.

Accepted state owners:

| State | Single writer | Readers |
|---|---|---|
| daemon lifecycle | `clean-disk-server` lifecycle supervisor | HTTP health, Flutter bootstrap |
| scan lifecycle | `ScanSessionSupervisor` / application service | HTTP status, event adapter |
| pdu worker state | `PduExecutionLane` | adapter diagnostics only |
| snapshot publication | `SnapshotPublicationGate` | read-model queries after publish |
| event sequence | engine event sequencer | WebSocket adapter |
| Flutter visible state | feature store | widgets |
| cleanup operation | cleanup operation supervisor | HTTP query, event adapter |

State machine rule:

```text
Only the operation owner can transition state.
Everything else sends commands or reads state.
```

## Scan State Machine Flow

MVP scan states:

```text
created
  -> starting
  -> scanning
  -> converting
  -> publishing
  -> completed

scanning
  -> cancel_requested
  -> discarded
  -> canceled

starting | scanning | converting | publishing
  -> failed
```

State rules:

- `cancel_requested` does not mean pdu stopped;
- `discarded` means a stale pdu result arrived after epoch/cancel and was not
  published;
- `completed` means a snapshot is queryable or a completed-with-warnings
  outcome is queryable;
- `failed` still has queryable failure/diagnostic state;
- terminal states remain queryable after reconnect.

Illegal transitions:

- `completed -> scanning`;
- `failed -> publishing`;
- `canceled -> publishing`;
- `discarded -> completed`;
- `created -> completed` without start evidence.

## Event Sequencing And Recovery

Event sequencing is product-owned, not pdu-owned. pdu callbacks may arrive from
Rayon workers and must not assign protocol sequence numbers.

Event envelope:

```text
EventEnvelope
  protocol_version
  stream_id
  sequence
  event_id
  event_type
  occurred_at
  session_id | operation_id
  snapshot_id?
  payload
  privacy_class
```

Sequence scopes:

- daemon stream for daemon health/capability changes;
- scan-session stream for scan progress and snapshot publication;
- delete-plan stream for plan state;
- cleanup-operation stream for execution and receipt state.

Rules:

- sequence is monotonic only within its stream scope;
- client never compares sequences across sessions;
- `event_id` is unique within source/stream;
- progress events are latest-state hints and can be coalesced;
- terminal and publication events require stronger delivery: they must be
  recoverable through HTTP state query even if event replay misses;
- event payloads are protocol read models, not domain objects.

Reconnect flow:

```text
WebSocket closed or app resumes
  -> HTTP GET /capabilities
  -> HTTP GET /scan-sessions/{id}
  -> if session has current_snapshot_id, query needed pages
  -> open WebSocket with stream_id and last_seen_sequence
  -> server replies replay | resume | resync_required
```

Do not use WebSocket reconnect as authority. HTTP state query comes first.

## Event Durability Classes

Not every event deserves the same storage.

| Event | Class | Policy |
|---|---|---|
| progress hint | ephemeral | coalesce/drop, query status for truth |
| issue summary changed | replayable bounded | keep short replay buffer |
| snapshot published | durable state | queryable through session/snapshot API |
| terminal scan state | durable state | queryable after reconnect |
| delete plan changed | durable until plan expires | queryable through plan API |
| cleanup item outcome | journaled | queryable receipt/operation state |
| daemon heartbeat | ephemeral | no replay needed |

Rule:

```text
Events may be lost.
State that matters must be queryable.
```

## Backpressure And Queue Flow

Scanner and read-model work must never be blocked by a slow Flutter tab or a
slow WebSocket client.

```text
pdu callback
  -> nonblocking bounded recorder
  -> engine event coalescer
  -> bounded per-session event stream
  -> bounded per-client queue
  -> WebSocket writer
```

Backpressure rules:

- pdu callbacks copy only bounded evidence;
- if reporter buffer overflows, increment overflow evidence and degrade
  diagnostics instead of blocking traversal;
- event coalescer collapses progress and issue-summary changes;
- per-client queue overflow emits `client_resync_required` or closes client;
- slow client never blocks scan worker;
- large query results are always HTTP pages;
- WebSocket compression is not an MVP dependency.

Top 3 queue policies:

1. Lossy progress plus durable/queryable terminal state - 🎯 10 🛡️ 10 🧠 6,
   roughly 700-1600 LOC.
   Accepted. It matches browser WebSocket limits and keeps UI recoverable.
2. Durable event log for every progress update - 🎯 4 🛡️ 6 🧠 8, roughly
   1500-4000 LOC.
   Rejected for MVP. It adds storage and replay complexity without product
   value because progress is not truth.
3. Unbounded queues to avoid drops - 🎯 2 🛡️ 2 🧠 2, roughly 200-800 LOC.
   Rejected. It hides memory pressure until the app freezes.

## pdu Adapter Internal Flow

```text
BackendScanRequest
  -> PduOptionsMapper
  -> PduExecutionLane
  -> PduScanRunner
  -> PduReporterRecorder
  -> pdu FsTreeBuilder or custom TreeBuilder
  -> raw DataTree + copied reporter evidence + side-store evidence
  -> PduRawScanResult
  -> PduTreeConverter
  -> PduIssueMapper
  -> PduHardlinkEvidenceMapper
  -> PduCapabilityMapper
  -> BackendScanOutput
```

Accepted pdu entrypoint policy:

- scan-only MVP may use `FsTreeBuilder`;
- product-grade rich scan uses custom pdu `TreeBuilder` with side stores;
- fork pdu only if adapter spike proves a hard blocker.

Important pdu constraints:

- `TreeBuilder` callbacks require `Copy + Send + Sync`;
- callback evidence must be copied immediately;
- `DataTree` stores name, aggregate size, children only;
- `DataTree::size()` is aggregate measured size;
- `FsTreeBuilder` errors are side-channel reporter events;
- `max_depth` is stored-depth/projection depth, not lazy loading;
- pdu README states it does not follow symbolic links and is ignorant of
  reflinks;
- pdu hardlink dedupe mutates aggregate projection and is not reclaim truth.

## Snapshot Publication Flow

```text
BackendScanOutput
  -> validate adapter fingerprint
  -> validate output requirements and capability gaps
  -> build ScanSnapshotDraft
  -> build compact NodeArena
  -> build ReadModelIndexes
  -> attach ScanQuality and issue summary
  -> publish snapshot id atomically
  -> drop pdu DataTree
  -> emit snapshot_published event
```

Publication rules:

- partially converted pdu output is not queryable;
- cancelled or stale epoch output is discarded;
- `ScanSession.current_snapshot_id` changes only after publication;
- snapshot id is part of every `NodeRef`;
- `NodeArena` is immutable per snapshot;
- query indexes can be rebuilt from snapshot data and index manifest.

## Read Model Flow

Read model objects:

- `NodeArena`;
- `ChildrenIndex`;
- `TopItemsIndex`;
- `SearchIndex`;
- `IssueIndex`;
- `DetailsProjectionStore`;
- `PathDisplayStore`;
- `MetadataEnrichmentStore`;
- cursor registry.

Rules:

- read models serve queries and UI only;
- read models do not execute cleanup;
- read models do not call pdu;
- indexes own deterministic ordering;
- Flutter receives pages and stores disposable UI caches;
- if a query requires unavailable facts, return capability/degraded state
  instead of inventing data.

## Metadata Enrichment Flow

Two enrichment modes exist:

```text
lazy enrichment:
  node details query
  -> MetadataEnricher / IdentityProvider
  -> update DetailsProjectionStore
  -> return details page

during-scan enrichment:
  custom TreeBuilder get_info
  -> side-store metadata drafts
  -> PduTreeConverter joins by traversal key
  -> NodeArenaRecord metadata_state
```

Decision:

1. Lazy enrichment first - 🎯 8 🛡️ 8 🧠 5, roughly 800-1800 LOC.
   Good MVP default. It keeps pdu integration simple and avoids slowing every
   scan for details the user may never open.
2. During-scan side-store enrichment - 🎯 8 🛡️ 9 🧠 8, roughly 1800-4500 LOC.
   Use when top files, file kind, modified, permissions, and details must be
   immediately available at scale.
3. Full second metadata pass after scan - 🎯 6 🛡️ 7 🧠 6, roughly 1000-3000 LOC.
   Useful as fallback, but can make large scans feel slow after pdu already
   finished.

Rules:

- details can be stale and must say so;
- delete preflight always revalidates, even if details are fresh;
- metadata cache is projection data, not authority;
- side-store evidence is keyed by adapter traversal id or platform identity,
  not display path alone.

## Cleanup Data Flow

Cleanup is a separate command flow.

```text
Flutter selection
  -> Add to cleanup queue view state
  -> BuildDeletePlan command with NodeRefs
  -> application validates snapshot/session compatibility
  -> platform identity revalidation
  -> accounting/reclaim confidence
  -> DeletePlan aggregate
  -> confirmation UI renders current plan
  -> ExecuteDeletePlan command
  -> TrashProvider / cleanup adapter
  -> OperationJournal + Receipt
  -> queryable operation outcome
```

Rules:

- selection is not queue;
- queue is not delete authority;
- stale scan node is not cleanup authority;
- raw path is never sufficient authority;
- pdu aggregate size is not reclaim estimate;
- confirmation renders the latest validated plan;
- partial cleanup produces item-level outcomes and receipt.

## Cross-Process And Web Flow

Desktop local mode:

```text
Flutter desktop
  -> launches signed clean-disk-server helper/app component
  -> loopback port + random session token
  -> HTTP commands/queries
  -> WebSocket event stream
```

Web UI mode:

```text
Flutter web
  -> connects to local or remote clean-disk-server
  -> origin allowlist + token/auth
  -> same HTTP/WebSocket protocol
  -> no browser filesystem full scan
```

Rules:

- scanner process identity matters for permissions;
- capability probe, scan, metadata enrichment, and delete preflight must run
  under the same trusted process identity where platform policy requires it;
- hosted web-to-localhost pairing is a separate security project;
- remote/headless destructive cleanup is disabled until explicit authority
  model exists.

## Thin DTO Boundary

Mapping chain:

```text
domain/application model
  -> protocol DTO
  -> HTTP/WebSocket JSON
  -> Flutter data DTO
  -> Flutter application model
  -> presentation view model
```

Rules:

- DTOs are versioned wire contracts;
- DTOs are not domain entities;
- unknown enum values fail closed for destructive actions;
- path, token, auth, and raw search text are redacted in logs/support bundles;
- DTO compatibility is checked at daemon connection time.

## Thin Points To Not Forget

1. `DataTree.children().is_empty()` does not mean file.
2. `DataTree.size()` does not mean reclaimable bytes.
3. pdu `max_depth` does not mean lazy load is possible.
4. pdu progress is a hint, not exact truth.
5. WebSocket event stream is not complete truth.
6. Flutter cache is not authority.
7. `NodeRef` must include snapshot identity.
8. Sort/filter/search belong to Rust read-model queries.
9. Cleanup needs current platform identity evidence.
10. pdu hardlink evidence is not reflink/shared-extent accounting.
11. pdu JSON/reflection is not product persistence.
12. exact sizes must survive Flutter web numeric limits.
13. slow clients must not block scanner traversal.
14. cancellation is a state machine, not just a boolean.
15. low-memory mode must stop before publishing corrupt/partial truth.

## Memory Stage Flow

pdu final-tree scanning creates a temporary memory peak. Treat that peak as a
first-class state, not an implementation detail.

```text
scan request accepted
  -> pdu DataTree building
  -> reporter/side-store buffers
  -> conversion to NodeArena draft
  -> index construction
  -> snapshot publication
  -> pdu DataTree drop
  -> query service reads compact model
```

Memory rules:

- record peak estimates for pdu tree, side stores, arena, and indexes;
- do not publish if conversion failed or memory budget was exceeded;
- low-memory cancellation maps to degraded/failed scan outcome with evidence;
- if double-memory peak is too high, next evolution is consuming conversion or
  upstream/fork `DataTree::into_parts`;
- Flutter never receives the full tree to "save Rust memory".

## Multi-Client Flow

Multiple clients can connect to the same daemon: desktop window, web tab, remote
client, or later automation.

Rules:

- one scan session can have many read clients;
- only authorized commands can mutate session state;
- each command has an idempotency key where retry is expected;
- each client has its own event queue and cursor state;
- query cursors are not shared across clients unless explicitly designed;
- cleanup confirmation is bound to the current validated plan and requester
  authority;
- a background tab cannot keep destructive authority alive without revalidation.

Multi-client invariant:

```text
Many clients may observe.
Only application use cases mutate.
Destructive authority is object-scoped and time-bound.
```

## Crash And Restart Flow

Scan-only MVP can keep scan snapshots in memory, but operation state still needs
honest recovery semantics.

MVP scan crash policy:

- daemon restart loses active in-memory scans;
- persisted preferences/capabilities remain;
- UI queries daemon status and sees no active scan or recovered failed scan,
  depending on persistence level;
- stale Flutter caches become read-only/stale and cannot create delete plans.

Cleanup beta crash policy:

- cleanup operations must have `OperationJournal`;
- item-level outcomes and receipts are durable;
- unknown in-flight item states require revalidation before retry;
- idempotency keys return recovered operation status after restart.

Decision:

1. Scan snapshots in memory for MVP, cleanup journal durable - 🎯 9 🛡️ 8 🧠 6,
   roughly 1500-3500 LOC.
   Accepted. Good balance before history/compare exists.
2. Persist every scan snapshot from day one - 🎯 6 🛡️ 8 🧠 8, roughly
   3000-7000 LOC.
   Useful later for history/compare, too much for scan-only MVP.
3. No durable operation journal for cleanup - 🎯 2 🛡️ 2 🧠 2, roughly
   400-1000 LOC.
   Rejected. Crash during cleanup without receipts is not acceptable.

## Exact Sequence Diagrams

Scan start:

```text
Flutter
  -> POST /scan-sessions
  <- session_id
  -> POST /scan-sessions/{id}/start
  <- accepted state=starting
  -> WS subscribe scan-session:{id}
  -> GET /scan-sessions/{id}
```

Snapshot publish:

```text
pdu worker finishes
  -> PduRawScanResult
  -> BackendScanOutput
  -> SnapshotPublicationGate
  -> current_snapshot_id set
  -> snapshot_published event
  -> Flutter GET children/details pages
```

Reconnect:

```text
Flutter detects disconnect
  -> GET /capabilities
  -> GET /scan-sessions/{id}
  -> GET visible pages if snapshot changed
  -> WS subscribe after last_seen_sequence
  <- replay | resume | resync_required
```

Cleanup preview:

```text
Flutter selected rows
  -> POST /delete-plans with NodeRefs
  -> app validates snapshot compatibility
  -> platform identity/accounting preflight
  <- DeletePlan current validation result
  -> UI renders confirmation from plan, not from selected rows
```

## Layer-Specific Do Not Forget

Domain:

- no pdu, Tokio, HTTP, WebSocket, JSON DTOs, filesystem IO, or UI;
- only value objects, aggregate state, and pure policies;
- no read-model indexes.

Application:

- owns use cases, ports, state machines, publication, and capability decisions;
- accepts `OutputRequirements`;
- rejects unsupported output requirements before fake data exists.

Data/infrastructure:

- owns pdu API constraints, callback copy, side stores, conversion, and
  fingerprint;
- owns platform metadata, identity, accounting, and Trash adapters;
- never invents domain state transitions.

Protocol:

- owns versioned DTOs, problem errors, event envelopes, and auth surface;
- no pdu raw types;
- no recursive full tree responses.

Flutter:

- owns presentation state, selection, layout, view models, and user workflow;
- never derives cleanup authority;
- never sorts/searches the entire scan tree locally;
- rebuilds from HTTP queries after reconnect.

## Consistency And Authority Model

The scanner pipeline has several truth levels. Do not collapse them into one
model.

```text
pdu callbacks and DataTree
  -> RawPduEvidence
  -> AdapterDraft
  -> BackendScanOutput
  -> ScanSnapshotDraft
  -> PublishedSnapshot
  -> QueryProjection
  -> Flutter ViewModel
```

Authority by stage:

| Stage | Purpose | Authority |
|---|---|---|
| pdu callbacks and `DataTree` | raw traversal and aggregate evidence | none outside `fs_usage_pdu` |
| `RawPduEvidence` | copied errors, progress hints, hardlink hints, adapter notes | adapter diagnostics only |
| `AdapterDraft` | adapter-local conversion state | not queryable |
| `BackendScanOutput` | product-shaped scan output | candidate input to publication |
| `ScanSnapshotDraft` | validated immutable arena and indexes under construction | not queryable |
| `PublishedSnapshot` | immutable server-side scan truth | authoritative for scan queries |
| `QueryProjection` | bounded page, details, top list, search result | UI read truth for this query only |
| Flutter view model | display and user intent | never destructive authority |

Rules:

- only `PublishedSnapshot` can answer scan tree queries;
- only delete preflight can answer destructive cleanup authority;
- no UI state, event payload, cursor, or pdu node can become cleanup authority;
- if publication fails, the previous published snapshot remains current or the
  session has no queryable snapshot;
- if a new snapshot is published, old `NodeRef`s remain historical and cannot
  create a current delete plan without explicit revalidation;
- every query response must say which `snapshot_id` and projection contract it
  belongs to.

Consistency choice:

1. Snapshot-at-a-time consistency - 🎯 10 🛡️ 10 🧠 6, roughly 900-2200 LOC.
   Accepted. Each completed scan publishes one immutable snapshot. Queries are
   strongly consistent within that snapshot, and progress before publication is
   explicitly non-authoritative.
2. Live mutable tree while scanning - 🎯 4 🛡️ 4 🧠 8, roughly 1800-4500 LOC.
   Rejected for MVP. It looks responsive, but introduces partial-node truth,
   racey selection, and much harder cancellation.
3. Flutter-side eventual consistency - 🎯 3 🛡️ 3 🧠 5, roughly 1000-2500 LOC.
   Rejected. It makes reconnect, multi-client, and cleanup safety fragile.

## Identifier Flow

Identifiers are product contracts, not pdu indexes. pdu `DataTree` does not
provide stable ids, full paths, metadata ids, or protocol refs.

Required identifier types:

| Identifier | Owner | Stable across | Notes |
|---|---|---|---|
| `ScanSessionId` | engine | daemon process or persisted session policy | public API handle |
| `ScanEpoch` | engine | one scan attempt in a session | rejects stale late results |
| `BackendRunId` | adapter | one backend invocation | diagnostics and benchmark split |
| `PduTraversalNodeId` | `fs_usage_pdu` | one adapter run only | private, never in protocol |
| `SnapshotId` | engine | immutable published snapshot | part of every `NodeRef` |
| `NodeId` | engine | one snapshot only | stable inside snapshot |
| `NodeRef` | protocol | one snapshot plus node | public query/delete-plan input |
| `TargetId` | engine/protocol | configured target policy | not just a path string |
| `QueryId` | query layer | one logical query shape | optional, for diagnostics/cache |
| `Cursor` | query layer | one snapshot/query shape | opaque to Flutter |
| `EventStreamId` | event layer | one event stream scope | daemon/session/operation scoped |
| `EventSequence` | event layer | one stream only | not globally comparable |
| `DeletePlanId` | cleanup application | plan lifetime | current validated plan |
| `OperationId` | cleanup application | operation lifetime | idempotency and journal |
| `ReceiptId` | cleanup application | receipt retention policy | support and audit |

Identifier rules:

- `NodeId` is never derived from vector index alone unless the arena is immutable
  and the id is scoped by `SnapshotId`;
- `NodeRef` must include `snapshot_id`, `node_id`, and protocol version or
  enough type information to reject incompatible refs;
- path strings are display/evidence, not identity;
- platform identity facts live behind `fs_usage_platform` and are reloaded
  before destructive operations;
- pdu traversal ids can help join side stores, but they must be discarded before
  protocol mapping;
- never compare `NodeId`s from different snapshots;
- event sequences are per stream. A client must not compare scan-session
  sequence with daemon sequence or cleanup-operation sequence.

## Cursor And Pagination Flow

Cursor is a server contract. Flutter treats it as opaque.

Cursor payload concept:

```text
Cursor
  snapshot_id
  projection_kind
  parent_node_ref | query_hash
  sort_spec_hash
  filter_spec_hash
  page_size
  position_token
  projection_epoch
  optional expiry
```

Rules:

- cursor is not a pdu child index exposed to clients;
- cursor is invalid if snapshot, query, sort, filter, capability, or projection
  epoch changes;
- page size has server max limits even if Flutter requests more;
- sort/filter/search are typed contracts, not strings interpreted by widgets;
- ties must be deterministic: size desc, type rank, normalized display name,
  then stable `NodeId` is a reasonable first policy;
- if a cursor is stale, return a typed stale-cursor response and let Flutter
  re-query from the first page or restored visible anchor;
- cursor data must not contain raw paths, auth data, or sensitive search text in
  logs.

Pagination choice:

1. Opaque cursor with query shape binding - 🎯 9 🛡️ 10 🧠 6, roughly
   700-1800 LOC.
   Accepted. It protects server internals and lets us change index layout.
2. Offset pagination over children vectors - 🎯 6 🛡️ 6 🧠 3, roughly
   300-900 LOC.
   Acceptable only inside the server implementation. Do not make it the public
   protocol because future filtered/search projections may not be offset-stable.
3. Stream all children and let Flutter page locally - 🎯 3 🛡️ 3 🧠 3, roughly
   400-1200 LOC.
   Rejected for large folders and web memory.

## Capability Negotiation Flow

Capabilities are not just "platform supports X". They combine daemon version,
protocol version, backend facts, platform permission, target topology, resource
profile, and current scan quality.

```text
daemon bootstrap
  -> static protocol capabilities
  -> platform capability probe
  -> backend capability probe
  -> target preflight
  -> scan output capability report
  -> Flutter feature gates
```

Capability layers:

| Layer | Examples |
|---|---|
| daemon static | protocol version, supported endpoints, event schema |
| backend static | pdu version, hardlink mode, size modes, max-depth behavior |
| platform static | Trash support, identity API, permission repair path |
| target dynamic | accessible, protected, network, removable, cloud root |
| scan dynamic | skipped paths, degraded metadata, overflowed diagnostics |
| cleanup dynamic | current revalidation, reclaim confidence, policy gates |

Rules:

- capabilities are queryable through HTTP and can change during runtime;
- Flutter gates commands by capabilities, but the daemon still validates every
  command;
- unknown capability means disabled for destructive flows;
- "unsupported" and "not yet loaded" are different states;
- backend capability must include pdu adapter fingerprint: crate version,
  feature flags, size mode, hardlink mode, device boundary mode, max-depth
  policy, and whether custom `TreeBuilder` side stores are enabled;
- scan response should expose quality as a typed object, not as free-form
  warning text.

## Issue Propagation Flow

pdu emits errors through reporter events. Those are not domain errors until the
adapter maps them.

```text
pdu Event::EncounterError
  -> copied AdapterIssueDraft
  -> PduIssueMapper
  -> ScanIssue
  -> IssueIndex and ScanQuality
  -> query page or summary
  -> Flutter badge, repair card, or details row
```

Issue categories we need from day one:

- `metadata_read_failed`;
- `directory_read_failed`;
- `directory_entry_failed`;
- `device_boundary_skipped`;
- `permission_denied`;
- `path_disappeared`;
- `path_changed_during_scan`;
- `diagnostics_overflowed`;
- `backend_panic_or_abort`;
- `resource_budget_exceeded`;
- `unsupported_accounting`;
- `unknown_backend_issue`.

Rules:

- pdu `EncounterError` path is borrowed. Copy immediately inside reporter;
- do not log raw issue paths by default;
- issues must carry severity, count, optional redacted path sample, operation,
  platform error code when available, and privacy class;
- permission errors affect scan quality, not necessarily scan failure;
- issue summary is evented, detailed issue pages are queried;
- issue taxonomy is stable and not localized;
- UI text is localized in Flutter, using issue codes as stable identity.

## DTO Versioning And Mapping Flow

DTOs are adapters at process boundaries. Domain and application models must not
derive directly from protocol serialization needs.

Mapping chain:

```text
fs_usage_core domain
  -> fs_usage_engine application/read model
  -> clean-disk-server protocol DTO
  -> JSON HTTP/WebSocket
  -> Flutter data DTO
  -> Flutter application model
  -> presentation view model
```

DTO rules:

- protocol DTOs are versioned and additive by default;
- unknown enum values are preserved as unknown for read-only display and fail
  closed for destructive actions;
- large integers are represented in a Flutter-web-safe way, preferably strings
  or typed decimal wrappers for bytes/counters/sequences;
- timestamps use explicit UTC instants plus optional display timezone only in
  presentation;
- path bytes and display strings are separate concepts where platform requires
  it;
- protocol DTOs cannot import pdu, platform-specific structs, Flutter, MobX,
  Drift, or domain aggregates;
- generated OpenAPI/schema output is a contract artifact, not the source of
  domain design;
- event payload DTOs and query response DTOs can share primitives, but event
  payloads must stay small.

Compatibility gates:

- daemon exposes protocol version and capability manifest before risky actions;
- Flutter refuses destructive UI if daemon is older/newer in an incompatible
  range;
- server rejects commands with unknown destructive policy, stale ids, stale
  snapshots, or unsupported client contract;
- schema changes require fixture snapshots and backward/forward compatibility
  tests.

## Privacy And Observability Flow

Disk usage tools naturally touch sensitive names. Treat observability as a
separate adapter with explicit privacy classes.

Data classes:

| Class | Examples | Default handling |
|---|---|---|
| public technical | protocol version, backend name | logs allowed |
| operational aggregate | counts, durations, queue depth | metrics allowed |
| sensitive path metadata | folder/file names, raw paths, search text | redact by default |
| destructive authority | delete plan items, tokens, confirmation evidence | never ordinary logs |
| support evidence | redacted samples, issue codes, receipts | explicit export only |

Rules:

- spans and metrics use ids, counts, and coarse categories instead of raw paths;
- support bundle export is a user action with redaction profile;
- WebSocket events include `privacy_class` so clients know what can be cached or
  displayed;
- diagnostics overflow must be visible as scan quality evidence;
- error reports from pdu are copied into structured issues before logging or
  protocol conversion;
- raw paths must not appear in command ids, cursor tokens, route paths, metrics
  labels, daemon tokens, crash summaries, or telemetry.

## pdu Source Mechanics To Remember

These facts are verified against `parallel-disk-usage` 0.23.0 source and docs.

- docs.rs exposes `FsTreeBuilder`, `TreeBuilder`, `DataTree`, and `Reporter` as
  the main library API;
- `DataTree` fields are private and only expose `name`, `size`, and `children`;
- `DataTree::dir` stores aggregate size as own inode size plus child sizes;
- `DataTree::children().is_empty()` cannot reliably distinguish empty directory
  from file after max-depth collapse;
- `TreeBuilder::Info` contains only `size` and child names;
- `TreeBuilder` recursively uses Rayon `into_par_iter`;
- `TreeBuilder` `get_info` and `join_path` are `Copy + Send + Sync` closures,
  so rich mutable side effects need explicit thread-safe side stores;
- `FsTreeBuilder` uses `symlink_metadata`, then `read_dir`, and reports
  failures through reporter events;
- `FsTreeBuilder` returns a `DataTree` through `From/Into`, not a `Result`;
- `FsTreeBuilder` ignores hardlink recorder errors with `.ok()`;
- `max_depth` still counts deeper sizes but does not store deeper child arrays;
- pdu README says symlinks are not followed and reflinks are not accounted for;
- pdu CLI uses global Rayon pool setup. The daemon adapter must not depend on
  CLI global initialization;
- pdu JSON/reflection is useful for tests/diagnostics, but not product
  persistence or wire format.

## First PR Boundary Checklist

The first implementation PR should be boring and strict. It should prove the
architecture boundary before adding rich UI or cleanup.

Must include:

- `fs_usage_core` value objects for ids, bytes, scan quality, issue codes,
  capability flags, and snapshot refs;
- `fs_usage_engine` ports for scanner backend, query store, event sink, platform
  metadata/accounting placeholders;
- in-memory scan session state machine with epoch/cancel/discard rules;
- pdu adapter that returns `BackendScanOutput`, not protocol DTOs;
- converter that drops pdu `DataTree` after arena ingestion;
- bounded reporter recorder with overflow evidence;
- server routes for capabilities, create/start/cancel scan, session status,
  children page, issue summary;
- WebSocket events only for lifecycle/progress/snapshot invalidation;
- contract tests proving no pdu concrete type crosses the adapter boundary;
- test fixture for pdu errors, hardlink hints, max-depth collapse, and stale
  cancel result.

Must not include yet:

- production cleanup execution;
- Flutter full-tree cache;
- pdu CLI wrapping;
- raw path authority;
- unbounded WebSocket event queues;
- global Rayon pool changes from server route handlers;
- product protocol generated directly from pdu reflection JSON.

## First Implementation Order

Recommended order:

1. `fs_usage_core` value objects and aggregate states - 🎯 9 🛡️ 9 🧠 5,
   roughly 700-1500 LOC.
2. `fs_usage_engine` ports, session service, publication gate, in-memory
   read-model contracts - 🎯 9 🛡️ 9 🧠 7, roughly 1600-3200 LOC.
3. `fs_usage_pdu` scan-only adapter with `FsTreeBuilder` and bounded reporter -
   🎯 8 🛡️ 8 🧠 7, roughly 1500-3200 LOC.
4. HTTP command/query and WebSocket event adapter - 🎯 8 🛡️ 8 🧠 6,
   roughly 1200-2600 LOC.
5. Flutter data repository and stores over paged queries/events - 🎯 8 🛡️ 8
   🧠 6, roughly 1200-2800 LOC.
6. rich metadata/custom `TreeBuilder` upgrade if MVP gates show it is needed -
   🎯 8 🛡️ 9 🧠 8, roughly 2000-5000 LOC.

Do not implement cleanup execution before scan snapshot, read-model, protocol
compatibility, and delete-plan preflight are stable.

## Contract Tests

Minimum tests before scan-only MVP:

```text
contract_start_scan_returns_session_without_tree
contract_backend_scan_output_contains_no_pdu_types
contract_snapshot_not_queryable_before_publication
contract_pdu_errors_join_with_tree_output
contract_cancelled_epoch_discards_late_pdu_output
contract_node_ref_includes_snapshot_id
contract_children_query_is_paged_and_server_sorted
contract_websocket_event_invalidates_but_http_query_is_truth
contract_datatree_dropped_after_arena_ingestion
contract_progress_hint_not_exact_file_count
contract_max_depth_hidden_nodes_not_cleanup_targets
contract_delete_plan_requires_current_identity_revalidation
contract_reclaim_estimate_not_pdu_aggregate_size
contract_unknown_capability_fails_closed_for_cleanup
contract_flutter_store_never_receives_full_tree_payload
```

## Sources

- [parallel-disk-usage 0.23.0 crate docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/)
- [DataTree 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/data_tree/struct.DataTree.html)
- [FsTreeBuilder 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/fs_tree_builder/struct.FsTreeBuilder.html)
- [TreeBuilder 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/tree_builder/struct.TreeBuilder.html)
- [Reporter/Event 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/reporter/event/enum.Event.html)
- [pdu README limitations](https://github.com/KSXGitHub/parallel-disk-usage#limitations)
- [RFC 9110 HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110)
- [RFC 6455 WebSocket Protocol](https://www.rfc-editor.org/rfc/rfc6455)
- [MDN WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
- [Tokio channels tutorial](https://tokio.rs/tokio/tutorial/channels)
- [CloudEvents specification](https://github.com/cloudevents/spec/blob/main/cloudevents/spec.md)
- [Alistair Cockburn Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture)
- [Microsoft Azure Tactical DDD guidance](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/tactical-domain-driven-design)
- Local source audit:
  `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/parallel-disk-usage-0.23.0`
