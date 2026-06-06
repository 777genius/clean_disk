# Architecture Fit Validation

Last updated: 2026-05-16.

This document validates the accepted Clean Disk architecture from multiple angles. It is not a brainstorm. It records why the current architecture is suitable and when it should be revisited.

## Accepted Architecture

```text
Flutter app
  -> Clean Disk protocol clients
  -> clean-disk-server
  -> fs_usage_engine
  -> pdu/platform/accounting/cleanup adapters
```

Accepted runtime:

```text
one Rust daemon process
  -> bounded worker pool
  -> scan scheduler
  -> per-volume/resource budgets
  -> HTTP commands/queries
  -> WebSocket events
```

Accepted transport:

```text
HTTP = authoritative commands and queries
WebSocket = session/progress event stream
HTTP resync = recovery after WebSocket reconnect or missed events
```

## Top 3 Architecture Options

### Option 1: One Rust Daemon + Bounded Worker Pool + HTTP/WS

Assessment: 🎯 10   🛡️ 9   🧠 6, roughly 6000-12000 LOC for a serious MVP across Rust core, daemon, protocol, Flutter client, UI, and tests.

This is the accepted architecture.

Why it fits:

- local disk scan does not need service discovery or deployment orchestration;
- bounded worker pool gives parallelism without microservice overhead;
- Rust owns large trees and indexes, so Flutter stays responsive;
- HTTP queries are a natural fit for paginated read models;
- WebSocket events are enough for progress and lifecycle updates;
- Clean Architecture boundaries keep `pdu`, HTTP, WebSocket, Flutter, and platform APIs out of domain logic.

Main risks:

- event reconnect/resync must be designed carefully;
- resource budgets must prevent scan workers from saturating the machine;
- `CleanDiskApiClient` and `ScanEventClient` must stay thin protocol adapters.

### Option 2: JSON-RPC Over WebSocket For Everything

Assessment: 🎯 7   🛡️ 8   🧠 7, roughly 7500-15000 LOC if done with subscriptions, replay, schema, client generation, and tests.

This is not accepted for Clean Disk MVP.

Why it is attractive:

- clean daemon-style method API;
- one bidirectional channel;
- good future fit for orchestrator, agents, local sockets, stdio, and plugin protocols;
- request id, result, and error are standardized.

Why it is not the current Clean Disk choice:

- most Clean Disk operations are authoritative queries over a read model;
- base JSON-RPC does not provide replay, subscriptions, backpressure, capability negotiation, or auth;
- if the WebSocket is down, both queries and events are unavailable until reconnect;
- OpenRPC ecosystem is weaker than OpenAPI for HTTP command/query docs;
- it adds protocol commitment before Clean Disk has proven its real data shape.

Revisit if:

- Clean Disk becomes a reusable daemon/RPC platform;
- desktop/local socket protocol becomes more important than browser HTTP;
- another project such as an agent orchestrator becomes the primary driver.

### Option 3: gRPC/gRPC-Web Or Socket.IO

Assessment: 🎯 5   🛡️ 7   🧠 8, roughly 9000-20000 LOC depending on gateway, generated clients, streaming, compatibility tests, and operational tooling.

This is not accepted for Clean Disk MVP.

gRPC strengths:

- strong typed contracts;
- mature multi-language codegen;
- good internal service-to-service protocol;
- native gRPC supports streaming and deadlines.

gRPC limitations for Clean Disk:

- browser cannot call native gRPC directly;
- gRPC-Web has browser streaming limits;
- local daemon/browser UI does not need internal microservice contracts;
- protobuf-first workflow is heavier than needed for a single local daemon.

Socket.IO strengths:

- event emitter API;
- reconnect and heartbeat;
- rooms and namespaces;
- fallback transports;
- good fit for chat/collaboration products.

Socket.IO limitations for Clean Disk:

- not plain WebSocket;
- missed event recovery still needs application-level offsets and persistence;
- rooms/namespaces do not add much for a scan-session model;
- adds protocol dependency and Rust/Dart compatibility surface.

Revisit if:

- Clean Disk becomes multi-user collaborative software;
- public clients require Socket.IO;
- Clean Disk becomes part of a microservice network where gRPC is already the standard.

## Validation By Concern

### Performance

Fit: strong.

The accepted architecture optimizes the real bottleneck: filesystem traversal, metadata IO, indexing, and UI memory pressure.

Rules:

- parallelism belongs in `fs_usage_engine` as bounded work;
- per-volume budgets avoid oversaturating one disk;
- Fast mode can raise concurrency, but Balanced mode is default;
- WebSocket never emits per-file events;
- Flutter receives pages, not full trees.

Why microservices do not help by default:

- multiple local services still contend for the same filesystem;
- cross-process IPC adds lifecycle and coordination cost;
- scan speed depends more on traversal policy and IO budget than on process count.

### Safety

Fit: strong.

The architecture keeps delete authority in Rust and does not let UI paths become destructive commands.

Rules:

- cleanup uses `DeletePlan`;
- delete candidates carry scan-time identity evidence;
- revalidation happens immediately before Trash/delete;
- receipts and partial outcomes are first-class;
- path display is never path authority.

### Web And Desktop

Fit: strong.

The same daemon protocol works for:

- desktop app launched local daemon;
- web UI connected to local daemon;
- remote/headless server mode later;
- CLI client later.

Rules:

- browser scanning does not use browser filesystem APIs;
- local daemon binds loopback with random token and origin allowlist;
- remote mode has separate auth and allowed roots;
- desktop can later use Unix sockets or named pipes behind the same contract.

### Clean Architecture And SOLID

Fit: strong if boundaries stay small.

SRP:

- `fs_usage_core` owns domain language;
- `fs_usage_engine` owns scan/session/query use cases;
- `fs_usage_pdu` owns pdu mapping;
- `clean_disk_http_ws` owns transport;
- Flutter presentation owns UI state.

OCP:

- new scanner backends implement `ScannerBackend`;
- new transports are host/client adapters;
- new accounting probes are provider adapters.

DIP:

- domain/application depend on ports and value objects;
- infrastructure adapters depend inward.

Risk:

- over-abstracting transport too early.

Guardrail:

- define only `CleanDiskApiClient` and `ScanEventClient` now;
- do not build a generic transport framework until another transport exists.

### Future Reuse

Fit: medium to strong.

Reusable parts:

- `fs_usage_*` library;
- event envelope concepts: session id, sequence, snapshot epoch, recovery query;
- bounded worker/resource-budget design;
- protocol DTO discipline;
- delete safety model.

Not reusable by force:

- Socket.IO;
- JSON-RPC;
- gRPC;
- microservice worker protocol.

Reason:

- reuse architecture principles and contracts first;
- add protocol adapters only when a real product needs them.

### Testability

Fit: strong.

Required test layers:

- pure domain/value object tests;
- fake scanner backend contract tests;
- pdu adapter golden fixtures;
- protocol DTO snapshot tests;
- fake `HttpClient` tests for `CleanDiskApiClient`;
- fake WebSocket/event stream tests for `ScanEventClient`;
- destructive cleanup tests only in disposable roots;
- platform fixture tests for symlinks, hardlinks, permissions, long paths, and stale identity.

## Accepted Guardrails

- Do not use microservices for local MVP.
- Do not wrap the `pdu` CLI in production.
- Do not let Flutter hold the full scan tree.
- Do not send one WebSocket event per filesystem entry.
- Do not use Socket.IO, JSON-RPC, gRPC, or FRB as the first Clean Disk protocol.
- Do not accept cleanup commands where raw path string is the only authority.
- Do not parse formatted UI text back into protocol command values.
- Do not expose pdu types outside `fs_usage_pdu`.
- Do not create all target crates before implementation pressure exists.

## Revisit Triggers

Revisit the architecture if any of these become true:

- one daemon cannot keep UI responsive under measured scan workloads;
- pdu adapter cannot provide enough progress/cancellation and a fork becomes necessary;
- remote/headless mode becomes primary before desktop local mode ships;
- multiple physical disks or remote roots require distributed scheduling;
- another product requires JSON-RPC or Socket.IO as public integration protocol;
- internal microservices become real, not speculative;
- browser gRPC-Web limitations no longer apply or protobuf-first contracts become mandatory.

## Final Recommendation

Keep the accepted architecture:

```text
One Rust daemon
  -> bounded worker pool
  -> reusable fs_usage_* core
  -> pdu/platform/accounting/cleanup adapters
  -> HTTP commands/queries
  -> plain WebSocket events
  -> Flutter client with paginated UI
```

This is the smallest architecture that still protects the product's hardest requirements: fast scanning, responsive UI, delete safety, web/desktop support, and future replaceability of scanner and transport adapters.
