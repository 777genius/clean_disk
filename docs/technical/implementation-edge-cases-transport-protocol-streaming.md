# Implementation Edge Cases - Transport, Protocol, And Streaming

This file records edge cases for the Clean Disk HTTP and WebSocket layer.

The product decision is still:

- HTTP for commands and paginated queries.
- WebSocket for progress, status, and invalidation events.
- Rust owns the scan tree and indexes.
- Flutter receives pages, summaries, and selected details, not the full tree.
- Transport is an adapter. Domain and application layers do not depend on HTTP, WebSocket, Axum, Dio, Flutter, or generated client code.

This document focuses on risks that appear when the scanner is fast enough that the transport, event model, browser WebSocket behavior, Flutter rebuilds, or protocol versioning become the bottleneck.

Related documents:

- [Architecture decisions](architecture-decisions.md)
- [Rust architecture](rust-architecture.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md)

## Sources Reviewed

- RFC 9110, [HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110). Useful for safe, idempotent, and unsafe method semantics, status codes, content negotiation, cache semantics, and avoiding destructive actions behind `GET`.
- RFC 6455, [The WebSocket Protocol](https://www.rfc-editor.org/rfc/rfc6455). Useful for close, ping, pong, fragmentation, control frames, and the fact that WebSocket gives message transport, not application-level replay or authorization.
- RFC 9457, [Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457). Useful for structured HTTP errors without leaking implementation internals.
- OWASP Cheat Sheet Series, [WebSocket Security](https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html). Useful for origin allowlists, handshake authentication, message-level authorization, size limits, rate limiting, logging, and disabling compression unless needed.
- OWASP Cheat Sheet Series, [REST Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html). Useful for HTTP security basics, status code discipline, TLS, input validation, and avoiding generic `200` error responses.
- OWASP Cheat Sheet Series, [CSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html). Useful because browser requests can carry ambient credentials and CORS does not replace CSRF/authorization thinking.
- MDN, [WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API). Useful for browser behavior: stable `WebSocket` has broad support but no backpressure; `WebSocketStream` has stream backpressure but is experimental.
- MDN, [WebSocketStream](https://developer.mozilla.org/docs/Web/API/WebSocketStream). Useful for future options, but not safe as a production dependency while experimental.
- Flutter, [Communicate with WebSockets](https://docs.flutter.dev/cookbook/networking/web-sockets). Useful for Flutter client shape: WebSocket messages arrive through a `Stream`, and `StreamBuilder` rebuilds on events.
- Flutter, [Performance best practices](https://docs.flutter.dev/perf/best-practices). Useful for frame budget, lazy lists, avoiding expensive build work, and avoiding intrinsic layout for large views.
- Flutter, [Concurrency and isolates](https://docs.flutter.dev/perf/isolates). Useful because expensive JSON parsing can jank the main isolate; Flutter web does not support isolates the same way desktop/mobile do.
- Flutter, [Work with long lists](https://docs.flutter.dev/cookbook/lists/long-lists). Useful for lazy rendering of large lists.
- Tokio docs, [`mpsc`](https://docs.rs/tokio/latest/tokio/sync/mpsc/index.html). Useful because bounded channels provide backpressure and unbounded channels can hide memory growth.
- Tokio source docs, [`broadcast`](https://docs.rs/tokio/latest/src/tokio/sync/broadcast.rs.html). Useful because lagging receivers are an expected state and must be mapped into protocol behavior.
- JSON Schema, [Draft 2020-12](https://json-schema.org/draft/2020-12). Useful for validating protocol DTOs and keeping generated docs/tests honest.
- AsyncAPI, [Specification 3.1.0](https://www.asyncapi.com/docs/reference/specification/latest). Useful as a future documentation option for event streams, separate from OpenAPI REST documentation.
- OpenAPI Specification, [v3.1.0](https://spec.openapis.org/oas/v3.1.0). Useful for documenting HTTP command/query endpoints, but not sufficient for the whole WebSocket event stream.

## Severity Scale

- `P0` - can delete wrong data, corrupt user decisions, freeze UI, leak private paths, break remote authorization, or make reconnect produce a false state.
- `P1` - can cause jank, stale UI, missed progress, stuck sessions, confusing errors, or hard-to-debug compatibility issues.
- `P2` - important polish, diagnostics, tooling, SDK, documentation, or long-term maintainability risk.

## Top 3 Transport Decisions

1. Authoritative state via HTTP queries, WebSocket as notification stream - 🎯 10 🛡️ 10 🧠 5, roughly 350-900 LOC across Rust read models, WebSocket adapter, Flutter stores, and tests.
2. Loss-aware event classes with bounded queues and coalesced progress - 🎯 10 🛡️ 9 🧠 6, roughly 450-1200 LOC across event runtime, session state, protocol DTOs, and slow-client tests.
3. Versioned protocol envelopes plus schema/snapshot tests - 🎯 9 🛡️ 9 🧠 5, roughly 250-800 LOC across shared protocol crate, OpenAPI/AsyncAPI snapshots, Flutter client DTOs, and compatibility tests.

These matter because a disk scanner can produce more state than a UI can display. Correctness depends on explicit contracts for what is authoritative, what can be dropped, and when the client must resync.

## Core Principle

The event stream is not the database.

WebSocket events are hints, progress, invalidations, and small state changes. Every important screen must be recoverable from HTTP queries:

- current daemon status;
- current scan session state;
- scan summary;
- tree pages;
- selected node details;
- delete plan status;
- delete execution receipt;
- warnings and skipped path pages.

If the UI cannot close, reopen, reconnect, and rebuild from queries, the protocol is too fragile.

## Transport Surface

### HTTP Owns Commands And Queries - `P0`

HTTP endpoints should handle:

- start scan;
- cancel scan;
- get scan session status;
- query child pages;
- query top folders/files;
- query selected node details;
- query skipped/error pages;
- search;
- create delete plan;
- confirm delete plan;
- execute move-to-trash;
- get delete job status;
- get receipts/export jobs;
- get capabilities/version.

Required behavior:

- unsafe operations use unsafe HTTP methods, not `GET`;
- mutating commands accept idempotency keys where retry is possible;
- long operations return operation/session IDs;
- large result sets are paginated;
- all route handlers translate into application commands/queries;
- route handlers never call filesystem adapters directly.

### WebSocket Owns Events And Invalidations - `P0`

WebSocket should handle:

- scan progress snapshots;
- phase changes;
- skipped/error counters;
- index-ready notifications;
- warning notifications;
- session terminal state;
- delete-plan invalidation;
- delete execution progress;
- daemon capability/version change;
- server shutdown notice.

Required behavior:

- do not transfer tree pages over WebSocket;
- do not transfer large search results over WebSocket;
- do not require WebSocket delivery for correctness;
- event clients must tolerate missed events;
- subscriptions are explicit and scoped to session IDs;
- server can close slow or unauthorized connections safely.

### Do Not Build A Second Command Protocol Over WebSocket - `P1`

It is tempting to use WebSocket bidirectionally for every action. That creates a custom RPC protocol, duplicate error semantics, and harder browser/devtool debugging.

Recommended policy:

- HTTP commands/queries first;
- WebSocket client-to-server messages only for subscribe, unsubscribe, heartbeat/ack if needed, and optional debug capabilities;
- if a WebSocket command is added, it must map to the same application command as HTTP and use the same authorization/idempotency rules;
- never let "real" behavior exist only in WebSocket.

### Localhost Does Not Remove API Discipline - `P0`

Even if the daemon listens only on loopback, browser-origin attacks, malicious local pages, local malware, browser extensions, and old tabs are realistic enough for a cleanup tool.

Required behavior:

- token required for HTTP and WebSocket;
- Origin and Host allowlists;
- no wildcard CORS;
- size limits;
- rate limits;
- structured errors;
- no secrets in URLs;
- no tokens in logs;
- no unauthenticated discovery endpoint that reveals private paths.

## Protocol Envelope

### Every Message Needs A Stable Envelope - `P0`

An event without metadata is hard to replay, dedupe, debug, or authorize.

Recommended envelope:

```json
{
  "protocolVersion": 1,
  "messageId": "evt_...",
  "type": "scan.progress",
  "sessionId": "scan_...",
  "sequence": 1234,
  "occurredAt": "2026-05-12T10:15:30Z",
  "correlationId": "req_...",
  "payload": {}
}
```

Rules:

- `type` is explicitly tagged;
- `sequence` is monotonic within a stream scope;
- `messageId` is stable enough for client dedupe;
- `correlationId` links events to commands when available;
- `protocolVersion` is always visible;
- `payload` is schema-validated at tests and client boundaries;
- debug/internal spans do not become protocol fields unless they are stable.

### Do Not Use Ambiguous Untagged Enums - `P1`

Untagged JSON shapes are pleasant until two variants overlap. Then old clients can decode new messages as the wrong type.

Required behavior:

- use explicit `type` or `kind`;
- keep unknown variants survivable where practical;
- treat unknown event type as `unsupported_event`, not fatal protocol corruption;
- reserve extension objects for future metadata;
- snapshot every public event shape.

### IDs Are Product Contracts - `P0`

Protocol IDs must not leak internal vector indexes or memory addresses.

Required behavior:

- scan session ID is opaque;
- node ID is opaque and scoped to scan/index version;
- delete plan ID is opaque;
- receipt ID is opaque;
- IDs are never parsed by client logic;
- if an ID encodes scope internally, that remains server-private.

### Paths Are Not Command Authority - `P0`

Transport must not accept raw paths for destructive operations after a scan produced node identities.

Required behavior:

- tree queries can return display paths;
- destructive commands reference delete plan ID, node IDs, and confirmation token;
- server revalidates identity snapshot before Trash/delete;
- path strings from UI search/filter inputs never become direct filesystem calls;
- path traversal checks still apply to import/export/debug endpoints.

## Event Classes

### Separate Durable Events From Ephemeral Events - `P0`

Not every event deserves the same delivery semantics.

Recommended classes:

```text
Durable:
  scan.started
  scan.phase_changed
  scan.completed
  scan.failed
  scan.cancelled
  delete_plan.changed
  delete_job.completed
  delete_job.completed_with_failures
  delete_job.failed

Replayable short-window:
  scan.warning
  scan.skipped_path
  scan.index_ready
  delete_job.item_outcome

Ephemeral/coalesced:
  scan.progress
  scan.current_path
  scan.throughput
  daemon.resource_sample
```

Required behavior:

- durable events are never silently dropped;
- ephemeral events can be coalesced;
- if a client misses replayable events, server returns resync required;
- terminal state is always queryable over HTTP;
- delete outcomes are persisted enough to build receipts.

### Progress Is Latest State, Not A Ledger - `P1`

Progress events should represent latest known state, not every filesystem entry.

Required behavior:

- progress event carries summary counters;
- event runtime coalesces progress at a target frequency;
- UI uses progress as a rendering input, not as authoritative accounting;
- current path may be omitted or rate-limited to protect privacy and UI readability;
- if scan is too fast, send fewer events, not more.

### Warnings Need Queryable Detail Pages - `P1`

Skipped paths and errors can be numerous.

Required behavior:

- WebSocket event may say `skipped_count_changed`;
- full skipped/error list is queried through paginated HTTP endpoint;
- warning pages include stable warning ID, node/parent context if available, reason code, and redacted/display path policy;
- warnings are not stuffed into a giant final event.

### Terminal Events Need Strong Delivery Semantics - `P0`

The UI must not remain stuck in "scanning" because a terminal WebSocket event was missed.

Required behavior:

- terminal state is stored in session state;
- client polls or queries session state after reconnect;
- close with abnormal WebSocket code triggers a status query;
- terminal events can be replayed within a short window;
- UI treats "socket closed" as unknown, not as scan failure.

## Backpressure And Slow Clients

### Browser WebSocket Has No Backpressure - `P0`

MDN documents that stable browser `WebSocket` has broad support but does not support backpressure. If messages arrive faster than the app processes them, memory or CPU can grow until the tab becomes unresponsive.

Required behavior:

- server never sends one event per file entry;
- server uses bounded per-client queues;
- progress events are coalesced;
- event payloads are capped;
- slow clients receive `stream.lagged` or are disconnected with a resync path;
- UI can recover using HTTP state queries.

### Do Not Depend On WebSocketStream Yet - `P1`

`WebSocketStream` is promising because it uses Streams API backpressure, but MDN marks it experimental. It is not a baseline product dependency for Flutter web.

Required behavior:

- use normal WebSocket as the compatibility baseline;
- design server-side flow control as if clients have weak backpressure;
- optionally detect WebSocketStream later in custom web code, but keep protocol identical;
- do not make product correctness depend on browser-specific stream support.

### Bounded Queues Are Required - `P0`

Unbounded queues turn slow clients into memory leaks.

Required behavior:

- per-client outbound queue has a fixed capacity;
- per-session event fanout has a fixed capacity;
- overflow policy is explicit per event class;
- metrics expose queue length, dropped/coalesced counts, lagged clients, and disconnects;
- tests simulate a client that reads very slowly.

### Tokio Channel Choice Is Protocol Semantics - `P1`

Tokio `mpsc` bounded channels provide backpressure. Tokio `broadcast` can report lagged receivers. That behavior should be reflected in protocol policy, not hidden as an implementation detail.

Recommended mapping:

- `watch` or latest-state storage for scan progress summary;
- bounded `mpsc` for per-client write loop;
- `broadcast` only when lagged receiver semantics are handled explicitly;
- durable events persisted or stored in a small replay buffer;
- never use unbounded channels for hot progress paths unless a measured, bounded outer policy exists.

### Compression Can Hurt Security And Latency - `P1`

OWASP warns that WebSocket compression can introduce security concerns. For Clean Disk, most event payloads should be small. Compression can also increase CPU and complicate capacity planning.

Required behavior:

- disable WebSocket per-message compression in MVP;
- use smaller/coalesced messages first;
- only add compression after measuring real payload bottlenecks;
- never mix secrets and attacker-controlled content in compressible streams without a threat review.

## Reconnect And Replay

### Reconnect Starts With HTTP State Query - `P0`

The correct reconnect sequence:

1. WebSocket closes or client resumes from sleep.
2. Client queries daemon version/capabilities if needed.
3. Client queries current session state.
4. Client subscribes with `after_seq`.
5. Server either replays, resumes from next sequence, or returns resync required.

Required behavior:

- reconnect does not assume missed events are available;
- missing replay buffer is not a fatal product error;
- client clears stale optimistic state when resync is required;
- terminal sessions remain visible after reconnect;
- delete plan state is revalidated.

### Sequence Numbers Need Scope - `P1`

A single global sequence can become a scalability and privacy problem. A per-stream sequence is usually enough.

Recommended scopes:

- daemon event stream sequence for daemon lifecycle;
- scan session event sequence per scan;
- delete job sequence per job;
- maybe user/session sequence in future remote mode.

Rules:

- sequence is monotonic within scope;
- gaps are meaningful;
- sequence reset only with a new stream identity;
- cursor includes stream ID and protocol version;
- client never compares sequences across unrelated streams.

### Replay Buffer Is A Cache, Not A Database - `P1`

Replay buffers make reconnect smooth, but should not become durable storage for critical facts.

Required behavior:

- replay buffer has capacity and time bounds;
- terminal state and receipts live in authoritative state, not only replay buffer;
- if event is no longer in buffer, server returns `resync_required`;
- buffer contents are redacted according to same privacy policy as events;
- tests cover replay hit and replay miss.

### Sleep And Network Changes Are Normal - `P1`

Laptop sleep, network interface change, VPN change, and mobile browser tab freeze can all break or delay sockets.

Required behavior:

- Flutter store treats socket disconnect as degraded state;
- stale progress is visibly stale if scan is still unknown;
- reconnect uses exponential backoff with jitter;
- foreground/resume triggers state query;
- server expires dead connections through heartbeat/read timeout policy.

## Payload Size And UI Jank

### JSON Parsing Can Jank Flutter - `P0`

Flutter docs recommend isolates when large computations cause jank. They also note Flutter web does not support isolates the same way. Large JSON pages can therefore be more dangerous on web.

Required behavior:

- keep HTTP pages small enough for main-isolate decode;
- parse huge exports outside the UI path;
- avoid massive single WebSocket messages;
- desktop can use isolates for heavy transforms if needed;
- web must rely more on pagination, smaller DTOs, and server-side filtering/sorting.

### Page Size Is A Product Setting - `P1`

Too small pages produce many requests. Too large pages jank UI and waste memory.

Required behavior:

- default child page size starts conservative, for example 100-300 rows;
- UI can request larger pages only for measured virtualized views;
- server enforces max page size;
- query response includes `has_more`, `next_cursor`, `snapshot_id`, and `sort`;
- page size tuning is benchmarked on desktop and web.

### WebSocket Event Rate Must Match Frame Budget - `P1`

Flutter best practices emphasize frame budget and avoiding unnecessary rebuilds. A scan can produce updates faster than the UI can render.

Required behavior:

- progress event publish rate is capped, for example 4-10 Hz for normal UI;
- faster internal metrics remain internal;
- UI store batches updates into frame-friendly notifications;
- selected details and tree rows rebuild only when their state changed;
- `StreamBuilder` over raw high-frequency transport stream is not the final architecture for the whole app.

### Large Lists Need Virtualized Rendering - `P0`

Flutter docs recommend lazy builders for long lists. Clean Disk's central tree/table must behave like a virtualized product primitive.

Required behavior:

- no full tree in widget state;
- no full tree in Dart memory for normal operation;
- child pages fetched lazily;
- expansion state is small and client-owned;
- visible row model is derived from pages and expansion state;
- sorting/filtering happens server-side for large datasets.

### Avoid Rebuilding From Raw Transport DTOs - `P1`

Raw DTOs should not directly drive large widgets.

Required behavior:

- transport DTOs map into feature application state;
- stores expose compact view models;
- event handlers update specific session/read model slices;
- high-frequency counters are separated from stable tree rows;
- table rows use stable keys and localized rebuild boundaries.

## Pagination, Sorting, And Snapshots

### Cursor Must Bind To Snapshot And Sort - `P0`

If cursor does not include snapshot/sort/filter identity, a client can mix pages from different states.

Required behavior:

- cursor encodes or references `snapshot_id`;
- cursor encodes sort key/direction and filter hash;
- cursor expires when index version changes;
- expired cursor returns structured problem, not silent weird page;
- client resyncs page from first page or current selected node.

### Sorting Must Be Deterministic - `P1`

Filesystem iteration order is not stable. Hash map iteration is not stable. UI pagination must be stable.

Required behavior:

- every sort has deterministic tie-breaker;
- ties can use name segment, file identity, node ID, or full normalized display key according to policy;
- sorting by size must define folder/file mixed behavior;
- sorting by modified date handles unknown timestamps;
- snapshots tests include equal-size/equal-name cases.

### Filters Need Stable Semantics - `P1`

Filter changes must not mutate selection or delete plan silently.

Required behavior:

- filter query has explicit filter expression or known enum;
- text search and category filters have separate fields;
- hidden rows can remain selected only if UI shows a clear count and review path;
- delete plan creation uses explicit selected node IDs, not "all currently filtered rows" unless that is a separate confirmed command;
- filter semantics are tested with pagination.

### Node Details Must Match The Same Snapshot - `P0`

The right panel cannot show details for a different version than the selected row.

Required behavior:

- selected row stores node ID plus snapshot ID;
- details query includes snapshot ID;
- if details are stale, server returns resync/stale problem;
- delete queue item records snapshot and identity;
- UI shows stale state instead of pretending the old object is current.

## Errors And Problem Details

### HTTP Errors Should Use Problem Details - `P1`

RFC 9457 gives a standard shape for HTTP API errors. It is useful for clients and support, but it should not leak internal stack traces or private filesystem details.

Recommended fields:

```json
{
  "type": "https://clean-disk.local/problems/stale-cursor",
  "title": "Cursor is stale",
  "status": 409,
  "detail": "The tree index changed. Query the first page again.",
  "instance": "req_...",
  "code": "stale_cursor"
}
```

Required behavior:

- stable machine-readable `code`;
- safe human-readable title/detail;
- request/correlation ID;
- no stack trace;
- no token;
- no raw private paths unless endpoint and redaction policy allow it;
- domain failures map to stable problem codes.

### WebSocket Errors Need Their Own Envelope - `P1`

WebSocket cannot rely on HTTP status after upgrade.

Required behavior:

- protocol-level errors use `error` event envelope;
- fatal protocol errors close socket with a defined close code where possible;
- recoverable subscription errors keep socket open;
- authorization failures for a subscription do not leak whether another user's session exists;
- parse errors are rate-limited to avoid error floods.

### Do Not Collapse All Failures Into `unknown` - `P1`

Clean Disk needs specific failure codes for UI decisions.

Examples:

- `unauthorized`;
- `forbidden`;
- `origin_denied`;
- `stale_cursor`;
- `snapshot_expired`;
- `session_not_found`;
- `session_not_owned`;
- `scan_already_running`;
- `target_unavailable`;
- `queue_overflow`;
- `resync_required`;
- `payload_too_large`;
- `rate_limited`;
- `unsupported_protocol_version`;
- `daemon_shutting_down`.

Required behavior:

- UI maps codes to actions;
- tests assert error code stability;
- logs include internal detail with redaction, not protocol payload.

## Versioning And Compatibility

### Handshake Needs Capability Negotiation - `P0`

Desktop app, web UI, daemon, and future CLI can be different versions.

Required behavior:

- HTTP capability endpoint returns daemon version, protocol version, supported features, max page size, event rate policy, and remote/local mode;
- WebSocket handshake checks protocol version;
- unsupported client receives clear problem/error;
- feature flags are additive;
- UI hides actions not supported by daemon.

### Protocol Version Is Not App Version - `P1`

App versions can change without wire protocol changes, and protocol changes can happen inside one app release.

Required behavior:

- protocol version is explicit;
- DTO schema version can be tracked separately if needed;
- client code checks protocol compatibility at startup;
- generated clients are pinned to protocol version;
- docs list compatibility promises before external API release.

### Additive Changes Need Unknown Field Policy - `P1`

JSON can carry extra fields. Different clients handle them differently.

Required behavior:

- clients ignore unknown fields where safe;
- server never removes or changes meaning of fields within a protocol version;
- enum additions are treated carefully because clients often switch exhaustively;
- public enums include `unknown` fallback at client boundary;
- protocol snapshots test old-client examples.

### Breaking Changes Need Explicit Cutover - `P1`

Do not silently make old UI talk to new daemon if delete workflows changed.

Required behavior:

- minimum client protocol version in daemon capabilities;
- client blocks unsafe actions if daemon is too old/new;
- migration notes for protocol changes;
- dev mode can allow mismatch only behind explicit flag;
- compatibility matrix in release checklist.

## Security And Authorization At Transport Layer

### WebSocket Handshake Auth Is Necessary But Not Sufficient - `P0`

OWASP recommends authentication during handshake and authorization for each action/message.

Required behavior:

- authenticate connection;
- validate Origin;
- authorize every subscription to scan/delete/session objects;
- authorize every message, not just connection;
- re-check authorization when session ownership or remote user changes;
- close or deny subscriptions when token expires.

### Message Size Limits Are Security And Performance - `P0`

Oversized payloads can freeze UI or exhaust daemon memory.

Required behavior:

- HTTP body limits per route;
- WebSocket message size limit;
- JSON nesting/decode limits where feasible;
- route-specific max page size;
- error with `payload_too_large`;
- tests with oversized payloads.

### Rate Limits Also Matter On Localhost - `P1`

Local malicious pages/extensions or a buggy client can spam commands.

Required behavior:

- rate limit start/cancel/plan/delete commands;
- rate limit failed auth and malformed messages;
- rate limit per token/session/client;
- expose local dev override only in debug mode;
- logs record rate-limit triggers without token leakage.

### Event Payloads Can Leak Private Paths - `P0`

Current path/progress events can expose files the user never clicked.

Required behavior:

- event path redaction policy;
- current path can be disabled or truncated;
- remote mode defaults to less path detail;
- support bundle and logs redact paths unless user opts in;
- telemetry never includes paths by default.

## Operation Semantics

### Start Scan Is Not A Synchronous Request - `P1`

A scan can outlive the HTTP request, UI window, or WebSocket.

Required behavior:

- `start_scan` returns quickly with session ID;
- scanner runs under session runtime;
- client observes through status query/events;
- request timeout does not cancel scan unless command failed before start;
- idempotency key handles duplicate starts if UI retries.

### Cancel Is A Request, Not Instant Reality - `P1`

Scanner may be in blocking filesystem work.

Required behavior:

- `cancel_scan` returns `cancel_requested` or current terminal state;
- session status eventually becomes cancelled/completed/failed;
- UI does not assume immediate stop;
- WebSocket sends cancel requested and terminal state separately;
- cancellation is tested against slow directories and blocking adapter calls.

### Delete Execution Needs Stronger Semantics Than Scan - `P0`

Delete/move-to-trash is destructive. It needs stronger idempotency, revalidation, and receipt behavior than scan progress.

Required behavior:

- HTTP command with idempotency key;
- confirmation token bound to plan hash;
- per-item outcomes;
- durable-ish receipt policy;
- WebSocket only reports progress/outcomes, it does not authorize execution;
- retry semantics documented before shipping.

## Flutter Client Store

### Transport Stream Is Not UI State - `P0`

The Flutter app should not pipe WebSocket messages directly into widgets.

Required behavior:

- infrastructure adapter decodes messages;
- data/application store applies them to session state;
- presentation reads view models;
- reducers/handlers are unit-tested without a real socket;
- stale/resync/error states are explicit.

### StreamBuilder Is Too Raw For The Main App State - `P1`

Flutter cookbook examples use `StreamBuilder` to show messages. That is fine for simple demos, not for a multi-panel cleanup workflow.

Required behavior:

- use explicit store/state management for scan sessions;
- batch high-frequency event updates;
- keep WebSocket connection lifecycle outside table widgets;
- avoid rebuilding the full tree/table on every progress tick;
- table row view models are stable and keyed.

### Web Has Weaker Background Compute - `P1`

Flutter docs state web platforms do not support isolates the same way; `compute` runs on the main thread on web.

Required behavior:

- avoid large client-side JSON transforms in web;
- server handles sort/filter/search;
- keep DTO pages compact;
- avoid rich derived calculations on the web client;
- benchmark Chrome/Safari/Firefox web UI separately.

### Multi-Tab Behavior Needs Policy - `P1`

Flutter web can be opened in multiple browser tabs. Desktop can also have multiple windows later.

Required behavior:

- each client has separate subscription ID;
- closing a tab does not cancel scan;
- one tab cancelling scan updates others through events;
- delete plan ownership and confirmation token behavior are explicit;
- stale tabs cannot execute old delete confirmations.

## Documentation And Tooling

### OpenAPI Is For HTTP, Not The Full Protocol - `P1`

OpenAPI 3.1 is useful for command/query endpoints, request/response schemas, and problem details. It does not fully describe a live WebSocket event stream by itself.

Required behavior:

- generate or snapshot OpenAPI for HTTP endpoints when stable;
- keep DTOs sourced from shared protocol crate;
- do not let OpenAPI-generated types become domain models;
- document event stream separately.

### AsyncAPI Can Document Event Streams Later - `P2`

AsyncAPI supports event-driven APIs and WebSocket protocol bindings. It can be useful after event shapes stabilize.

Recommended behavior:

- first write snapshot tests and markdown contracts;
- add AsyncAPI only when event stream is stable enough;
- do not slow MVP by forcing full AsyncAPI generation;
- if remote/headless API becomes public, revisit AsyncAPI.

### JSON Schema Is A Test Tool, Not The Domain - `P1`

JSON Schema can validate DTOs and examples, but domain rules belong in Rust application/domain code.

Required behavior:

- schema snapshots for public protocol examples;
- property tests for important DTO decode paths;
- domain invariants tested without JSON;
- schema validation errors map to structured protocol errors;
- no generated schema type should pull transport concepts inward.

## Testing Matrix

### Protocol Compatibility Tests

Required:

- old client connects to new daemon within supported range;
- new client connects to old daemon within supported range;
- unsupported protocol version returns clear problem;
- unknown event type does not crash UI;
- missing optional field uses default/fallback only where allowed;
- removed/renamed field is caught by snapshot tests.

### Reconnect Tests

Required:

- reconnect with no missed events;
- reconnect with replay hit;
- reconnect with replay miss and resync;
- reconnect after terminal state;
- reconnect during delete plan review;
- reconnect during delete execution;
- laptop sleep simulation if tooling allows.

### Slow Client Tests

Required:

- client reads WebSocket very slowly;
- client stops reading but stays connected;
- many clients subscribe to same scan;
- one slow client does not slow scanner;
- queue overflow emits lag/resync or closes;
- memory remains bounded.

### Payload Limit Tests

Required:

- oversized HTTP command body;
- oversized WebSocket message;
- huge page request above max;
- malformed JSON;
- deeply nested JSON if parser allows limit testing;
- flood of invalid messages.

### UI Jank Tests

Required:

- high-frequency progress stream;
- large child page;
- rapid expand/collapse while scan progresses;
- search while events arrive;
- multi-tab or multi-window view;
- web build profile with frame timing.

### Security Tests

Required:

- unauthorized Origin;
- missing token;
- token in URL rejected or ignored according to policy;
- subscription to another session denied;
- malformed subscribe message;
- rate-limit trigger;
- no token/path leakage in logs.

## MVP Cut Line

Before implementing first usable HTTP/WebSocket daemon:

- HTTP has capability endpoint.
- HTTP starts scan and returns session ID.
- HTTP status query is authoritative.
- WebSocket only sends bounded/coalesced events.
- Tree pages stay HTTP-paginated.
- Event envelope includes type, session ID, sequence, protocol version, and timestamp.
- Per-client outbound queue is bounded.
- Slow client policy exists.
- Reconnect path queries state first.
- Structured problem errors exist for common failures.
- Protocol DTO snapshots exist.
- Flutter store does not rebuild whole UI from raw event stream.

Do not ship cleanup actions over this transport until:

- command idempotency exists;
- delete plan hash and confirmation token exist;
- object-level authorization is implemented;
- stale snapshot/cursor behavior is tested;
- receipts are queryable after reconnect.

## Summary

The safe shape is:

```text
HTTP = authoritative commands and paginated queries
WebSocket = bounded notifications and invalidations
Rust = scan tree, indexes, sorting, filtering, page generation
Flutter = visible state, view models, selection, and user workflow
```

The invariant:

```text
No UI decision, delete decision, or session truth may depend on receiving every WebSocket event.
```

