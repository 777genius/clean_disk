# Implementation Edge Cases - Concurrency, State Machines, And Operation Ownership

Last updated: 2026-05-13.

This file records edge cases for concurrent UI clients, daemon commands, scan jobs, cleanup jobs, operation state machines, retries, cancellation, event ordering, and Rust async coordination.

Related documents:

- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md)
- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)

This document exists because concurrency mistakes in Clean Disk can look like harmless UI bugs, but the product eventually moves files to Trash. A duplicate command, stale confirmation, out-of-order event, or cancelled future in the wrong place can become a data-loss bug.

## Sources Reviewed

- RFC 9110, [HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110). Relevant points: safe methods are read-only by intent, idempotent methods can be repeated with the same intended effect, and method semantics must not hide unsafe actions.
- Google AIP-151, [Long-running operations](https://google.aip.dev/151). Relevant points: long-running work should return an operation handle, be pollable, expose terminal success/error, and define parallel operation behavior.
- Google AIP-155, [Request identification](https://google.aip.dev/155). Relevant points: client-provided request IDs are used to guarantee idempotency and make retry/audit behavior deterministic.
- Stripe API docs, [Idempotent requests](https://docs.stripe.com/api/idempotent_requests). Relevant points: persist the first status/body for an idempotency key, reject reused keys with mismatched parameters, and do not store a result if execution never began.
- Microsoft Azure Architecture Center, [Compensating Transaction pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/compensating-transaction). Relevant points: compensation is application-specific, may not restore original state, and compensation steps should be idempotent.
- Tokio, [Graceful Shutdown](https://tokio.rs/tokio/topics/shutdown). Relevant points: shutdown needs detection, notification, and waiting; `CancellationToken` and task tracking are a good shape.
- Tokio, [Channels](https://tokio.rs/tokio/tutorial/channels). Relevant points: concurrency and queuing must be explicit and bounded; unbounded queues can consume memory and fail unpredictably.
- Tokio docs, [Mutex](https://docs.rs/tokio/latest/tokio/sync/struct.Mutex.html). Relevant points: async mutexes can be held across `.await`, are FIFO, and are more expensive than blocking mutexes where a blocking mutex would be safe.
- Tokio, [Shared state](https://tokio.rs/tokio/tutorial/shared-state). Relevant points: do not hold a blocking mutex across `.await`; wrap shared data behind non-async methods where practical.
- `tracing`, [crate documentation](https://docs.rs/tracing/latest/tracing/). Relevant points: async Rust needs structured spans/events because tasks are multiplexed and ordinary logs lose causality.
- CloudEvents, [Specification](https://github.com/cloudevents/spec/blob/main/cloudevents/spec.md). Relevant points: event identity should include source plus id; stable event envelopes reduce ambiguity across systems.
- Loom, [crate documentation](https://docs.rs/loom/latest/loom/). Relevant points: model checking explores possible thread interleavings for concurrent code, which is valuable for operation coordination.
- Proptest, [State machine testing](https://proptest-rs.github.io/proptest/proptest/state-machine.html). Relevant points: state machine testing compares a system under test against an abstract reference machine.

## Severity Scale

- `P0` - can trigger wrong deletion, duplicate destructive execution, stale confirmation, authorization bypass, unrecoverable corruption, or daemon deadlock during cleanup.
- `P1` - can cause stuck operations, inconsistent UI, lost terminal events, broken reconnect, false progress, or hard-to-debug reliability issues.
- `P2` - important supportability, observability, polish, or future extensibility risk.

## Top 3 Decisions

1. Single authoritative operation state machine in Rust application layer - 🎯 10 🛡️ 10 🧠 6, roughly 700-1800 LOC across operation aggregate/state types, command handlers, protocol DTOs, Flutter stores, and tests.
2. Actor-like command ownership per scan/delete operation, with bounded queues - 🎯 9 🛡️ 9 🧠 7, roughly 900-2400 LOC across session supervisors, channels, cancellation, backpressure, and state snapshots.
3. Shared mutable maps with ad hoc locks around sessions/plans - 🎯 4 🛡️ 5 🧠 5, roughly 300-900 LOC initially, but expensive later because races and stale state become product bugs.

My recommendation: use a Rust-owned operation supervisor and explicit state machines. Internally, prefer single-writer command loops for scan sessions and cleanup jobs. Use locks only around small registries and never make a lock the place where domain transitions are invented.

## Core Principle

Clean Disk should treat long-running work as durable-enough operations, not async function calls.

A user action like "Scan", "Cancel", "Validate Delete Plan", or "Move to Trash" should become:

```text
UI intent
  -> command DTO with request_id
  -> application use case
  -> domain state transition
  -> operation/job record
  -> adapter work
  -> item outcomes
  -> authoritative operation state
  -> queryable read model
  -> events as notifications
```

Events tell clients that something changed. Queries tell clients what is true.

## Bounded Context

This concern cuts across multiple bounded contexts, but the ownership should stay clear:

- `scan` owns scan session state and scan cancellation policy;
- `cleanup` owns delete plan state, cleanup execution, confirmation, and item outcomes;
- `transport` owns request IDs, connection IDs, event delivery, and protocol envelopes;
- `operations` or application-level orchestration owns common operation lifecycle patterns if duplicated state machines appear;
- infrastructure adapters own Tokio tasks, channels, locks, timers, and persistence details.

Do not put Tokio channel types, HTTP request IDs, WebSocket sequence numbers, or Flutter store flags in domain entities.

## Operation State Machine Edge Cases

### Boolean Flags Cannot Model Operation Truth - `P0`

`isLoading`, `isDeleting`, `isCancelled`, `hasError`, and `done` can represent impossible combinations.

Required:

- every long-running operation has one explicit state enum;
- terminal states are exclusive;
- legal transitions are enforced in application/domain code;
- illegal transitions return typed errors;
- state includes reason codes and timestamps;
- UI derives flags from state, not the other way around.

Avoid:

- `isRunning = false` plus `error = null` meaning both cancelled and completed;
- setting UI state before server command result is known;
- letting WebSocket events mutate operation lifecycle without querying authoritative state after reconnect.

Recommended state shape:

```text
Draft
Queued
Validating
Running
CancelRequested
Cancelled
Completed
CompletedWithFailures
Failed
Expired
Superseded
```

For cleanup, `CompletedWithFailures` is not a cosmetic state. It is normal for batch Trash operations.

### Legal Transitions Need Tests - `P0`

State machines should reject illegal transitions such as:

- `Completed -> Running`;
- `Cancelled -> MoveToTrash`;
- `Failed -> Completed`;
- `Expired confirmation token -> ReadyToExecute`;
- `Superseded scan snapshot -> CleanupConfirmed`;
- `CancelRequested -> Completed` without a policy decision.

Required:

- transition table in Rust tests;
- property/state-machine tests for operation lifecycle;
- protocol snapshot tests for all public states;
- Flutter tests that unknown states fail safe, especially for cleanup.

Avoid:

- adding enum values without UI fallback;
- using stringly typed states in Dart or Rust;
- deriving state from progress percentage.

### Operation State Must Be Queryable - `P0`

A client can close, reconnect, reload web UI, sleep, or miss event replay.

Required:

- every operation has `GET /operations/{operation_id}` or equivalent;
- domain-specific resources expose state too, for example scan session and delete plan status;
- events include `operation_id` but do not replace status queries;
- terminal state remains queryable for a retention window;
- missing/expired operations return a typed problem, not generic 404 if the user needs recovery guidance.

Avoid:

- WebSocket-only status;
- progress UI that cannot recover after reload;
- deleting operation state before receipts or errors are available.

### Parallel Operation Policy Must Be Explicit - `P1`

The user may open two windows, a web UI, and a desktop UI. Remote mode can add more clients later.

Required policy per resource:

- can this scan target have multiple active scans?
- can a delete plan be edited while validation runs?
- can a delete plan be executed while another cleanup touches the same ancestor?
- can one user observe another user's operation?
- can a scan continue after all clients disconnect?

Recommended MVP:

- allow multiple read-only clients;
- one writer per delete plan;
- one cleanup execution per delete plan;
- reject overlapping cleanup execution when targets overlap by identity or ancestor relation;
- allow scan sessions to continue after client disconnect;
- expose operation ownership and connected observers in diagnostics, not in normal UI unless needed.

Avoid:

- silently merging two active scans;
- allowing a browser tab to cancel a cleanup created by a different user/session without explicit authority;
- assuming "same path" means same operation target.

## Command Idempotency And Retry Edge Cases

### Exactly-Once Execution Is The Wrong Mental Model - `P0`

Network calls, browser retries, desktop retries, double-clicks, and daemon restarts make exactly-once execution unrealistic.

Required:

- destructive commands accept a `request_id` or idempotency key;
- the key is scoped by user/session, command name, and canonical payload hash;
- repeated same key and same payload returns the first compatible result;
- repeated same key and different payload returns `idempotency_payload_mismatch`;
- idempotency entries for destructive commands survive at least through operation completion and receipt retention policy.

Avoid:

- generic HTTP retry middleware for `move_to_trash`;
- using timestamps as idempotency keys;
- storing path names inside idempotency keys;
- treating HTTP `DELETE` method idempotency as enough for a cleanup operation.

### Idempotency Store Needs Execution Boundary - `P0`

If validation fails before execution begins, storing a failed idempotency result can make a corrected retry impossible. If execution begins and crashes, not storing anything can allow duplicate cleanup.

Required:

- distinguish `RejectedBeforeExecution`, `Accepted`, `Started`, `Terminal`;
- store accepted destructive command before adapter side effects begin;
- persist operation/job ID as idempotency result once side effects may occur;
- on retry, return operation status, not re-run adapter work;
- if payload mismatch happens after execution started, return conflict and point to original operation.

Avoid:

- writing receipt after moving files but before writing operation start;
- allowing "unknown if started" to retry destructive work automatically;
- pruning idempotency records before receipts.

### Automatic Retries Need Per-Command Policy - `P1`

Retries are useful for queries and dangerous for destructive commands.

Recommended:

- safe queries can retry with budget and jitter;
- scan start can retry only with request ID;
- cancel can retry because it is a request to transition toward cancellation;
- delete validation can retry with plan version;
- move-to-trash never retries automatically unless it is idempotency-protected and returns operation status;
- adapter-level filesystem operations retry only for explicitly transient cases.

Avoid:

- HTTP client retrying all `POST` commands;
- retrying after `identity_mismatch`;
- retrying after permission denied without user action;
- retrying after stale confirmation.

## Ownership And Locking Edge Cases

### One Writer Per Aggregate Is The Default - `P0`

Scan sessions and delete plans are aggregates. Concurrent writes to the same aggregate should be serialized.

Required:

- each scan session has one owner task or command loop;
- each delete plan has one write authority;
- read models can be copied/snapshotted for queries;
- command handlers send commands to the owner instead of mutating shared state from many tasks;
- ownership is explicit in code names, not hidden in a global map.

Avoid:

- `Arc<Mutex<HashMap<SessionId, MutableSession>>>` where every handler mutates internals directly;
- holding a global registry lock while running pdu/trash/file IO;
- holding any lock while calling a user filesystem adapter.

### Registry Locks Should Be Small And Boring - `P1`

Some shared maps are fine: session registry, connection registry, operation registry. They should not contain business transitions.

Required:

- registry lock protects lookup/insert/remove only;
- operation work runs outside registry lock;
- registry values are handles/senders/arcs, not huge mutable trees;
- lock acquisition order is documented if multiple locks exist;
- lock contention metrics exist for P1 diagnostics.

Avoid:

- nested locks across scan, cleanup, and transport;
- async `.await` while holding a blocking mutex guard;
- using an async mutex everywhere by default;
- relying on lock fairness for product semantics.

### Async Cancellation Can Drop Futures Mid-Step - `P0`

Rust futures can stop when dropped. If a future owns half-finished cleanup state, cancellation can leave operation state inconsistent.

Required:

- destructive work runs inside owned tasks with explicit cancellation tokens;
- cancellation requests update operation state first;
- filesystem side effects are divided into small steps with durable item outcomes;
- once an item Trash step begins, complete that item outcome before honoring cancellation where possible;
- cleanup never depends on `Drop` to finish async cleanup.

Avoid:

- `select!` around `move_to_trash_item()` where the losing branch drops mid-side-effect without recording outcome;
- treating task abort as user cancel;
- assuming process shutdown runs async destructors.

### Blocking Work Must Not Starve Async Runtime - `P1`

pdu scanning and filesystem metadata reads can be CPU or blocking-IO heavy.

Required:

- isolate scan adapter work from HTTP/WebSocket runtime responsiveness;
- use bounded blocking pools or dedicated worker threads where appropriate;
- do not let query handlers wait behind scan traversal locks;
- cancellation and health endpoints remain responsive under scan load;
- metrics track command queue latency separately from scan throughput.

Avoid:

- running full traversal inside an async request handler;
- unbounded `spawn_blocking` for every file or directory;
- making WebSocket event encoding compete with scan hot path without bounds.

## Event Ordering And Replay Edge Cases

### Sequence Numbers Need Scope - `P1`

One global sequence across all sessions is simple but can create contention and privacy issues. Per-operation sequence numbers are easier to reason about.

Required:

- event envelope includes `event_id`, `operation_id`, `source`, `seq`, `schema_version`, and event class;
- sequence scope is explicit: per operation, per session, or global;
- reconnect request includes last seen sequence for the same scope;
- if replay is outside retention, server returns `resync_required`;
- clients sort/merge only within documented scope.

Avoid:

- comparing sequence numbers from different scan sessions;
- using wall-clock timestamps for ordering;
- making progress events durable just to preserve every percentage change.

### Durable And Ephemeral Events Must Be Separate - `P0`

Progress ticks are ephemeral. Cleanup item outcomes and terminal operation state are durable enough to recover.

Required:

- progress events can be coalesced or dropped;
- warning/error/terminal events have stronger delivery or queryable detail;
- cleanup item outcomes are persisted in operation receipt/journal;
- dropped progress never changes correctness;
- lost terminal event is recoverable via status query.

Avoid:

- deriving receipt from event stream;
- requiring UI to receive every item event to know cleanup result;
- buffering unlimited events for a sleeping browser tab.

### Event Payloads Must Be Read Models, Not Domain Objects - `P1`

Events cross clients, versions, and potentially remote boundaries.

Required:

- event DTOs are versioned and additive where possible;
- private paths are redacted or scoped according to mode;
- events carry IDs and summaries, not huge tree nodes;
- query endpoints provide detail pages;
- unknown event types are ignored safely or trigger resync.

Avoid:

- serializing Rust domain structs directly as protocol events;
- exposing internal error/debug strings in event details;
- including raw adapter-specific pdu payloads.

## Cleanup Job Concurrency Edge Cases

### Delete Execution Needs Exclusive Target Claims - `P0`

Two cleanup jobs can race over the same node, parent/child, symlink target, or path that changed identity.

Required:

- validate all plan items against current identity before execution;
- normalize parent/child conflicts before execution;
- create target claims before side effects begin;
- reject or wait when another cleanup holds an overlapping claim;
- release claims after terminal operation state is recorded.

Avoid:

- queue A moves parent while queue B moves child;
- remote user executes a plan while local user executes overlapping plan;
- claim by path string only;
- keeping claims forever after crash without recovery policy.

### Partial Success Is The Normal Case - `P0`

Trash/move operations are not atomic across filesystems, platforms, permissions, and cloud roots.

Required:

- item-level outcome is persisted;
- aggregate state can be `CompletedWithFailures`;
- failed items can be revalidated into a new plan;
- receipt explains moved, skipped, failed, already gone, identity mismatch, unsupported, and permission denied;
- compensation is explicit and best-effort, not promised undo.

Avoid:

- rolling back successful Trash moves automatically after one failure;
- claiming "cleanup failed" when 900 of 1000 items moved;
- claiming "cleanup succeeded" when any item failed.

### Confirmation Tokens Need Version And Lease Semantics - `P0`

The time between validation and execution can be long. Files can change and other clients can edit the plan.

Required:

- confirmation token binds to user/session, plan ID, plan version, plan hash, scan snapshot, risk tier, and expiry;
- executing with stale token returns typed stale/expired error;
- any plan edit invalidates token;
- any intersecting stale subtree invalidates or requires revalidation;
- token is not sent over WebSocket event payloads.

Avoid:

- reusing confirmation token after reconnect without status query;
- confirmation by UI checkbox only;
- token that authorizes "whatever is currently in the queue".

## Client Coordination Edge Cases

### Desktop Window, Web Tab, And Remote Client Are Different Actors - `P1`

They may share transport but should not have identical authority.

Required:

- every connection has `client_id`, client type, protocol version, and auth/session scope;
- commands include actor context;
- events are filtered by actor authorization;
- UI copy distinguishes local machine from remote host;
- local-only actions such as Reveal in Finder are hidden outside local desktop context.

Avoid:

- treating all clients connected to localhost as trusted forever;
- letting a remote browser issue local file-manager commands;
- mixing local desktop scan targets with remote server scan targets in one queue.

### Multi-Tab Web Needs A Policy - `P1`

Web UI can be opened in multiple tabs. Background tabs can sleep and reconnect later.

MVP options:

1. Multi-tab read-only observers plus one active writer tab - 🎯 8 🛡️ 9 🧠 6, roughly 400-1000 LOC.
2. Full collaborative editing for delete plans - 🎯 4 🛡️ 6 🧠 9, roughly 1800-5000 LOC.
3. Every tab independently mutates server state - 🎯 2 🛡️ 3 🧠 4, roughly 200-700 LOC but unsafe.

Recommendation: one active writer per plan/session, observers can query and follow state. If another tab wants to edit, require explicit takeover or duplicate draft.

### UI Store Must Separate Local Draft From Server Authority - `P1`

Flutter stores need optimistic UI for responsiveness, but cleanup safety needs authoritative server state.

Required:

- local draft selection is separate from server delete plan;
- queued item UI shows pending/synced/stale/conflict;
- command completion reconciles with authoritative plan version;
- rejected commands roll back local draft with visible reason;
- terminal cleanup results come from receipt/status query, not local assumptions.

Avoid:

- modifying server plan on every row focus change;
- hiding version conflicts by silently overwriting server state;
- using one store list as selected rows, expanded rows, and delete queue.

## Rust Async Implementation Edge Cases

### Use Channels To Express Ownership - `P1`

For long-running sessions, a command channel often communicates architecture better than a shared mutex.

Recommended shape:

```text
SessionRegistry
  -> ScanSessionHandle
      -> command_sender
      -> status_snapshot
      -> event_subscription

ScanSessionTask
  owns mutable session state
  receives commands
  updates snapshots
  emits bounded events
```

Required:

- command channel is bounded;
- send failure maps to `operation_not_available` or `daemon_shutting_down`;
- slow commands do not block registry lookup;
- event fanout is isolated from session command handling.

Avoid:

- unbounded command/event channels;
- one broadcast channel carrying all detailed events for all sessions;
- backpressure from a slow WebSocket client blocking scanner traversal.

### Cancellation Token Tree Needs Ownership Rules - `P1`

Cancellation should be structured:

```text
daemon_token
  -> scan_session_token
  -> scanner_adapter_token
  -> indexing_token

daemon_token
  -> cleanup_operation_token
  -> item_worker_token
```

Required:

- cancelling daemon requests all child operations to wind down;
- cancelling scan session cancels scanner/indexing/event producers;
- cancelling a UI connection cancels only that client's event stream;
- cancelling cleanup means "stop after safe boundary", not "undo completed items";
- forced shutdown records interrupted state where possible.

Avoid:

- tying scan lifetime to WebSocket lifetime;
- letting one tab disconnect cancel another user's scan;
- sharing one global cancellation token for unrelated operations.

### Tracing Must Preserve Operation Causality - `P1`

Async logs interleave. Without structured spans, support cannot debug race bugs.

Required:

- span fields include `operation_id`, `scan_session_id`, `delete_plan_id`, `client_id`, `request_id`, `protocol_version`;
- command handler, state transition, adapter call, event emission, and persistence write are in related spans;
- errors include typed codes and operation IDs;
- logs never include full private paths unless debug export explicitly allows redacted/consented detail.

Avoid:

- relying on plain string logs with no operation ID;
- logging huge path lists during scan;
- entering a tracing span guard across `.await` incorrectly when instrumentation helpers should be used.

## Query And Snapshot Concurrency Edge Cases

### Read Models Need Snapshot Boundaries - `P1`

Paginated tree queries, search, charts, and details must agree on which scan snapshot they represent.

Required:

- each read model has `snapshot_id` and `index_version`;
- cursor includes snapshot, parent/result scope, sort/filter, and page boundary;
- if snapshot changes, query either returns explicit stale cursor or a compatible refreshed page flag;
- details panel shows stale state rather than quietly switching identity.

Avoid:

- row index as identity;
- page 2 from old sort combined with page 1 from new sort;
- details panel updating from latest scan while delete queue still references old scan.

### Background Index Jobs Can Race With Scan Completion - `P1`

Search/top-lists/recommendations may index after scan traversal.

Required:

- scan completed does not imply all secondary indexes are ready;
- index jobs have operation state or capability state;
- query endpoint can return `index_building`, `partial`, or `unavailable`;
- cancellation cancels secondary index work too;
- stale index cannot authorize cleanup.

Avoid:

- blocking scan completion on all expensive indexes in MVP;
- showing search results without index freshness state;
- letting recommendation engine update delete candidates after user confirmation.

## Persistence And Recovery Edge Cases

### Crash Recovery Needs Operation Facts, Not Task Handles - `P0`

Tokio task handles disappear after crash. User-visible operations need recoverable facts.

Required for cleanup-capable release:

- operation journal records accepted destructive command before side effect;
- item outcome is recorded after each side-effect boundary;
- receipt is written before operation state is considered terminal;
- crash recovery marks unknown in-flight item states for revalidation;
- idempotency retry after crash returns recovered operation status.

Avoid:

- treating lost task as failed without inspecting journal;
- deleting temporary journal before receipt is durable;
- resuming filesystem side effects blindly after crash.

### Operation Expiration Must Be Designed - `P1`

Old scan sessions, delete plans, idempotency records, events, and receipts cannot live forever.

Required:

- retention windows by data class;
- cleanup disabled for expired scan/delete plan;
- receipts survive longer than transient events;
- idempotency records survive long enough to cover retries and support;
- UI explains expired operations and offers rescan/rebuild plan.

Avoid:

- keeping every event forever;
- deleting receipts before support window;
- allowing old web tab to execute an expired plan.

## Security And Authorization Edge Cases

### Authorization Must Apply To Operations, Not Only Endpoints - `P0`

An authenticated client should not automatically access every operation.

Required:

- operation has owner/actor/session scope;
- command checks ownership and capability;
- event subscription checks operation access;
- query endpoints filter by authorized target scope;
- cleanup command checks both plan ownership and target authority.

Avoid:

- "connected to daemon" equals "can command all operations";
- leaking operation IDs through global event stream;
- assuming local-only mode will never become remote.

### Request IDs Are Not Secrets - `P1`

Idempotency keys/request IDs are identifiers, not auth tokens.

Required:

- request ID cannot grant access;
- request ID value is random enough to avoid collisions;
- idempotency store is scoped by authenticated actor;
- keys do not embed path names, emails, hostnames, or private metadata;
- logs can include hashed/truncated request IDs if needed.

Avoid:

- treating request ID as bearer credential;
- putting user paths into `request_id`;
- accepting client-provided operation owner.

## Testing Edge Cases

### State Machine Tests Are Required Before Cleanup Beta - `P0`

Required:

- valid transition table tests;
- invalid transition tests;
- duplicate command tests;
- concurrent command conflict tests;
- cancel during scan tests;
- cancel during cleanup item tests;
- reconnect after missed terminal event tests;
- crash recovery after item outcome but before receipt tests.

### Model Concurrency Where It Matters - `P1`

Use focused concurrency testing for small coordination components.

Recommended:

- Loom tests for small lock/channel coordination primitives;
- property/state-machine tests for delete plan lifecycle;
- deterministic fake scheduler/time for operation expiry;
- stress tests for slow WebSocket client and bounded queues;
- fixture tests for overlapping cleanup claims.

Avoid:

- trying to model-check the whole daemon;
- relying only on flaky stress tests;
- ignoring rare interleavings because Rust prevents data races. Rust prevents memory unsafety, not product races.

### Manual Race Scenarios For QA - `P1`

Before cleanup-capable beta, manually test:

- two desktop windows open same scan;
- web UI reloads during scan;
- web tab sleeps and resumes after terminal event;
- duplicate Move to Trash click;
- cancel while validation runs;
- cancel while item move is in progress;
- app quit during cleanup;
- daemon crash after some items moved;
- scan target rescanned while delete plan exists;
- remote observer tries local-only action.

## MVP Cut Line

Before scanner-only MVP:

- operation state enum for scan;
- scan status query authoritative;
- scan event stream uses scoped sequence numbers;
- bounded event queues;
- scan cancellation token;
- multiple clients can observe without corrupting scan state.

Before cleanup-capable beta:

- delete plan aggregate has legal transition tests;
- destructive commands require idempotency key/request ID;
- idempotency store survives operation completion;
- cleanup operation journal exists;
- item outcomes and receipt are durable;
- confirmation tokens bind to plan hash/version/session and expire;
- overlapping cleanup claims are rejected or serialized;
- reconnect/status query recovers terminal cleanup result;
- illegal transitions fail closed.

Deferred:

- full collaborative multi-user edit of delete plans;
- exactly-once event delivery;
- durable event outbox for every progress event;
- distributed lock manager for multi-node server mode;
- automatic compensation beyond explicit Trash/receipt behavior.

## Summary

Clean Disk's concurrency invariant:

```text
One operation has one authoritative state machine, one write owner at a time, bounded event delivery, idempotent mutating commands, and queryable recovery after missed events or crashes.
```

📌 The UI can be optimistic, but the daemon must be authoritative. The event stream can be fast, but status queries must be correct. Cleanup can be cancellable, but every side-effect boundary needs an outcome.
