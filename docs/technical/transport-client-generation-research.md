# Transport And Client Generation Research

Last updated: 2026-05-13.

This document is research, not an accepted decision. Accepted decisions remain in `architecture-decisions.md`.

The question: should Clean Disk use generated Retrofit/OpenAPI clients and Socket.IO, or should it keep the current plan of typed HTTP commands/queries plus plain WebSocket events?

## Local Project Context

The Flutter workspace already has a reusable HTTP layer:

- `packages/abstract_http_client` defines `HttpClient`, request/response/error models, cancellation, retry, auth token storage, and observability primitives.
- `packages/dio_http_client` implements that abstraction with Dio.
- `packages/network` owns `AppHttpClientFactory` and chooses `DioHttpClient`.

Therefore, a "manual thin HTTP client" does not mean writing HTTP from scratch. It means:

```text
features/scan/data
  -> CleanDiskApiClient
  -> abstract_http_client.HttpClient
  -> DioHttpClient adapter from packages/network
```

The thin client should map:

- protocol request DTOs;
- protocol response DTOs;
- problem/error DTOs;
- exact integer strings;
- token/origin headers;
- cancellation tokens;
- retry policy where safe.

It should not bypass the existing HTTP abstraction.

## Direct `HttpClient` Use Vs `CleanDiskApiClient`

The project already has enough HTTP infrastructure. Do not add another generic HTTP wrapper.

The practical question is whether feature repositories should call `abstract_http_client.HttpClient` directly or through a small product-specific client.

### Option 1: Use `HttpClient` Directly In Feature Data Repositories

Assessment: 🎯 6   🛡️ 6   🧠 3, roughly 80-250 LOC.

Example shape:

```dart
final response = await httpClient.post<Map<String, Object?>>(
  '/api/v1/sessions',
  body: HttpBody.json(dto.toJson()),
  decoder: (data) => data as Map<String, Object?>,
);
```

Pros:

- least code;
- uses the existing abstraction directly;
- no extra class until endpoints grow.

Cons:

- route strings, headers, auth flags, problem-detail parsing, exact integer parsing, and endpoint conventions spread across repositories;
- harder to test protocol behavior in one place;
- harder to swap REST endpoints for JSON-RPC/SSE later;
- feature repositories become transport-shaped instead of use-case-shaped.

Use only for a tiny prototype.

### Option 2: Product-Specific Thin `CleanDiskApiClient` Over Existing `HttpClient`

Assessment: 🎯 9   🛡️ 9   🧠 4, roughly 200-700 LOC for MVP.

Example shape:

```dart
final session = await cleanDiskApi.createScanSession(request);
final page = await cleanDiskApi.getChildren(sessionId, query);
final plan = await cleanDiskApi.createDeletePlan(request);
```

This is not a wrapper over Dio. It is a protocol adapter over the existing `abstract_http_client`.

Pros:

- centralizes paths, auth headers, token/origin conventions, exact integer decoding, problem details, and compatibility handling;
- feature repositories depend on product protocol methods, not raw HTTP paths;
- easier to test all daemon HTTP behavior with a fake `HttpClient`;
- easier to later replace HTTP commands with JSON-RPC or generated clients behind the same feature port.

Cons:

- small amount of extra code;
- can become a god client if not split by resource/session area.

Recommended shape:

```text
features/scan/data/
  protocol/
    clean_disk_api_client.dart
    clean_disk_event_stream_client.dart
    dto/
    mappers/
```

Guardrail:

```text
CleanDiskApiClient is not a generic network layer.
It is the Clean Disk protocol adapter for HTTP commands/queries.
```

## Sources Reviewed

- Dart `retrofit_generator`, [pub.dev](https://pub.dev/packages/retrofit_generator). Relevant points: Dio client generator using `source_gen`; popular package, current `10.2.5` at time of research.
- Dart `openapi_retrofit_generator`, [pub.dev](https://pub.dev/packages/openapi_retrofit_generator/versions/2.0.4). Relevant points: generates Retrofit + Dio clients and models from OpenAPI 2.0/3.0/3.1; supports `json_serializable`, `freezed`, `dart_mappable`, `unknown_enum_value`, and streaming endpoints; package is young and small.
- Dart `openapi_generator`, [pub.dev](https://pub.dev/packages/openapi_generator). Relevant points: wraps OpenAPI Generator for Dart projects; requires Java and initial jar download; documentation warns that generated code can be imperfect and may need spec fixes or `.openapi-generator-ignore`.
- Dart `web_socket_channel`, [pub.dev](https://pub.dev/packages/web_socket_channel). Relevant points: official `tools.dart.dev` package, cross-platform WebSocket API, current `3.0.3` at time of research.
- MDN, [WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API). Relevant points: standard browser API, stable support, but no built-in backpressure on `WebSocket`.
- Axum, [WebSocket extractor docs](https://docs.rs/axum/latest/axum/extract/ws/struct.WebSocket.html). Relevant points: Axum exposes a WebSocket stream behind the `ws` feature.
- Socket.IO, [Introduction](https://socket.io/docs/v4/). Relevant points: Socket.IO is not a WebSocket implementation; it uses WebSocket when possible but adds protocol metadata, so plain WebSocket clients cannot connect to Socket.IO servers and Socket.IO clients cannot connect to plain WebSocket servers.
- Socket.IO, [Delivery guarantees](https://socket.io/docs/v4/delivery-guarantees/). Relevant points: ordered delivery is guaranteed for arriving messages, default delivery is at-most-once, missed server events are not retransmitted unless the app persists events and sends offsets.
- Socket.IO, [Connection state recovery](https://socket.io/docs/v4/connection-state-recovery/). Relevant points: recovery was added in Socket.IO 4.6.0; it can restore state and missed packets after temporary disconnection, but it is not guaranteed and adapter support varies.
- Socket.IO, [Handling disconnections](https://socket.io/docs/v4/tutorial/handling-disconnections). Relevant points: clients are not always connected, server does not store events, and missed events are lost unless the application resynchronizes state.
- Socket.IO, [Rooms](https://socket.io/docs/v4/rooms/). Relevant points: rooms are server-only channels for broadcasting to subsets of clients.
- Dart `socket_io_client`, [pub.dev](https://pub.dev/packages/socket_io_client). Relevant points: Dart Socket.IO client current `3.1.4` at time of research, compatible with Socket.IO server version ranges, publisher is unverified.
- Rust `socketioxide`, [docs.rs](https://docs.rs/socketioxide). Relevant points: Rust Socket.IO server implementation that integrates with Tower/Axum ecosystem and supports Socket.IO protocol versions, but adds a non-standard protocol dependency.
- Dart `json_rpc_2`, [pub.dev](https://pub.dev/packages/json_rpc_2). Relevant points: official `tools.dart.dev` package implementing JSON-RPC 2.0 over `StreamChannel`; useful alternative if we want RPC over WebSocket.
- Rust `jsonrpsee`, [docs.rs](https://docs.rs/jsonrpsee). Relevant points: Rust JSON-RPC library with optional HTTP and WebSocket client/server features.

## Client Generation Options

### Option 1: Thin Client On Existing `abstract_http_client`

Assessment: 🎯 9   🛡️ 9   🧠 4, roughly 200-700 LOC for MVP client, DTO mappers, and tests.

Use our existing `abstract_http_client` and `DioHttpClient` for HTTP commands and queries. Generate or hand-write protocol DTOs separately.

Why it fits:

- preserves current workspace architecture;
- no direct Dio dependency in feature application/domain;
- exact integer strings and unknown enum behavior stay under our control;
- easier to keep protocol DTOs separate from domain and Flutter view state;
- easy to test with fake `HttpClient`;
- lower generator risk while protocol is still changing.

Risk:

- some repetitive endpoint code;
- OpenAPI client generation benefits are deferred;
- must maintain DTO/schema alignment through tests.

Required safeguards:

- schema snapshot tests;
- generated examples for protocol DTOs;
- explicit DTO mappers;
- no parsing formatted UI strings back into commands.

### Option 2: OpenAPI To Retrofit/Dio Generated Client

Assessment: 🎯 6   🛡️ 6   🧠 6, roughly 300-1100 LOC for generator config, wrappers, mappers, and regression tests.

Use `openapi_retrofit_generator` to generate Retrofit clients and models from OpenAPI.

Why it is attractive:

- generates Retrofit + Dio code from OpenAPI;
- supports OpenAPI 2.0/3.0/3.1;
- supports `json_serializable`, `freezed`, `dart_mappable`;
- has `unknown_enum_value` option;
- supports streaming endpoint generation for SSE/binary streams.

Concern:

- package is young and small compared to core Dart packages;
- generated code may shape the data layer too strongly;
- WebSocket events still need a separate client;
- exact integer strings, problem details, cursors, event schemas, and forward-compatible enums need a real spike before trust.

Use only if:

- it passes our protocol fixture suite;
- generated DTOs stay in data/protocol adapter layer;
- no generated class crosses into domain/application.

### Option 3: OpenAPI Generator Dart/Dio

Assessment: 🎯 7   🛡️ 7   🧠 7, roughly 500-1600 LOC for generator workflow, dependency management, ignored files, wrappers, and fixes.

Use `openapi_generator` or OpenAPI Generator `dart-dio`.

Why it is attractive:

- more established generator ecosystem;
- broad OpenAPI support;
- useful when API surface becomes large.

Concern:

- Java requirement;
- generated code can need manual fixes;
- dependency conflicts can occur inside generated packages;
- generated code may be harder to keep aligned with Clean Architecture boundaries.

My current preference:

```text
MVP: Option 1
Spike later: Option 2
Keep Option 3 as fallback if API surface grows and Option 2 fails.
```

## Socket Transport Options

Browser reality:

```text
Browser UI cannot open arbitrary TCP/Unix/named-pipe sockets.
It can use browser-supported transports such as HTTP, WebSocket, SSE, and WebTransport.
```

Desktop packaging may later use Unix sockets or named pipes, but that is a transport adapter behind the same protocol contract. It is not a replacement for browser-compatible transport.

### Option 1: HTTP Commands/Queries Plus Plain WebSocket Events

Assessment: 🎯 10   🛡️ 9   🧠 5, roughly 600-1500 LOC across Rust HTTP/WS adapter, Flutter client, reconnect/resync, and tests.

This is the current best fit.

Shape:

```text
HTTP:
  POST /api/v1/sessions
  POST /api/v1/sessions/{id}/cancel
  GET  /api/v1/sessions/{id}/children?cursor=...
  GET  /api/v1/sessions/{id}/details/{node_id}

WebSocket:
  scan.started
  scan.progress
  scan.skipped
  scan.completed
  scan.failed
  scan.cancel_requested
  scan.cancelled
```

Why it fits:

- standard browser-compatible transport;
- simple to debug with browser/devtools/Postman-like tools;
- OpenAPI documents commands and queries;
- WebSocket only handles notifications/events;
- missed events are recovered by HTTP resync using `after_seq`, snapshot epoch, and read-model queries;
- no dependency on Socket.IO protocol versions;
- works for desktop, web, CLI, and remote mode.

Required work that Socket.IO would not eliminate:

- event envelope;
- sequence numbers;
- replay window or resync endpoint;
- backpressure and slow-client policy;
- capability/version handshake;
- reconnect state in Flutter;
- query pagination.

Main concern:

- more custom protocol code than Socket.IO's event emitter style.

Mitigation:

- keep the WebSocket layer tiny;
- make all authoritative state queryable by HTTP;
- treat WebSocket as "notification and progress", not as authoritative storage.

### Option 2: JSON-RPC 2.0 Over Plain WebSocket

Assessment: 🎯 7   🛡️ 8   🧠 6, roughly 800-1900 LOC across RPC schema, subscriptions, Rust/Dart client wrappers, and tests.

Use JSON-RPC for bidirectional request/response and notifications. Candidate libraries: Dart `json_rpc_2`, Rust `jsonrpsee`.

Why it is attractive:

- one bidirectional channel can handle requests and events;
- request ids and errors are part of the protocol;
- Dart and Rust libraries exist;
- can work over WebSocket and other stream channels.

Concern:

- OpenAPI no longer naturally documents every command/query;
- request/response and subscription semantics need careful design;
- browser reconnection and missed event recovery still need our own state model;
- harder to use simple HTTP caching/debugging for paginated queries.

Use if:

- API becomes command-heavy and bidirectional;
- desktop/local socket transports become primary;
- we intentionally choose RPC over REST-style query endpoints.

Deeper fit analysis:

JSON-RPC gives a clean message contract:

```json
{"jsonrpc":"2.0","method":"scan.createSession","params":{...},"id":"req_1"}
{"jsonrpc":"2.0","result":{...},"id":"req_1"}
```

It also supports notifications:

```json
{"jsonrpc":"2.0","method":"scan.progress","params":{...}}
```

This is elegant for a daemon because every command/query can be method-shaped, independent of URL design.

Important limitations:

- base JSON-RPC 2.0 is stateless and does not define subscriptions, replay windows, backpressure, auth, capability negotiation, or stream resync;
- notifications have no response, so they are wrong for destructive commands;
- batch requests may return responses in any order, so client correlation must be strict;
- OpenAPI no longer describes the main API; OpenRPC can document it, but its ecosystem is smaller than OpenAPI;
- Flutter web still needs exact integer strings because JSON-RPC uses JSON too;
- missed progress events still need `seq`, `after_seq`, and resync.

Potential Clean Disk JSON-RPC shape:

```text
scan.handshake
scan.createSession
scan.start
scan.cancel
scan.dispose
scan.children
scan.search
scan.nodeDetails
cleanup.createPlan
cleanup.confirmPlan
cleanup.receipt
events.subscribe
events.unsubscribe
```

If using JSON-RPC, my preferred variant would be:

```text
HTTP remains for health/version/static web UI.
JSON-RPC over WebSocket owns commands, queries, and events.
OpenRPC documents the RPC API.
```

But that is a bigger architectural commitment than HTTP + WebSocket events.

### Option 3: Socket.IO

Assessment: 🎯 4   🛡️ 6   🧠 7, roughly 1000-2600 LOC across Socket.IO server/client adapters, protocol mapping, recovery, tests, and fallback handling.

Socket.IO is viable, but I do not recommend it for Clean Disk MVP.

What it gives:

- event emitter API;
- automatic reconnect;
- heartbeat;
- long-polling fallback;
- acknowledgements;
- rooms/namespaces;
- optional connection state recovery in Socket.IO 4.6+;
- ecosystem for chat-like realtime apps.

Why it does not map cleanly to Clean Disk:

- it is not plain WebSocket, so we couple to the Socket.IO protocol;
- official docs say missed server events are not replayed by default;
- connection state recovery is useful but not guaranteed and adapter support varies;
- our UI still needs authoritative HTTP queries for pages, details, search, delete plans, receipts;
- rooms/namespaces are mostly unnecessary because our natural subscription key is scan session id;
- long-polling fallback is not obviously useful for a localhost daemon where the browser can use WebSocket;
- Dart client is community-maintained and publisher is unverified;
- Rust server support means adding `socketioxide`, another abstraction over Axum/Tower;
- generated OpenAPI does not describe Socket.IO event contracts.

Where Socket.IO would make more sense:

- multi-user collaborative web app;
- many logical rooms;
- chat/notifications style traffic;
- Node.js backend where Socket.IO is already standard;
- product wants Socket.IO clients as public API.

For Clean Disk:

```text
Socket.IO replaces a small WebSocket adapter with a larger protocol adapter,
but does not remove our need for event sequence, resync, state queries, or delete safety.
```

## Final Research Conclusion

Use the existing HTTP client stack:

```text
Flutter feature data adapter
  -> CleanDiskApiClient
  -> packages/abstract_http_client
  -> packages/dio_http_client
```

Use plain WebSocket for event transport:

```text
Flutter ScanEventStreamClient
  -> web_socket_channel
  -> clean-disk-server / axum ws
```

Keep transport abstract:

```text
abstract class ScanTransport {
  Future<T> command<T>(CommandDto command);
  Future<PageDto> query(QueryDto query);
  Stream<ScanEventDto> events(SessionId sessionId, {EventSeq? afterSeq});
}
```

Do not choose Socket.IO unless at least one of these becomes true:

- rooms/namespaces become product-critical;
- long-polling fallback is required by measured browser/proxy failures;
- Socket.IO clients are a public integration requirement;
- we accept Socket.IO as a protocol dependency and write compatibility tests around it.

Recommended next validation spike before implementation:

1. Build a tiny Rust `axum` WebSocket server emitting `seq` events and accepting `after_seq`.
2. Build a Flutter/Dart `web_socket_channel` client that reconnects and resyncs through existing `abstract_http_client`.
3. Build the same spike with `socketioxide` + `socket_io_client`.
4. Compare LOC, reconnect correctness, missed-event recovery, debugging clarity, and package friction.

Expected result: plain WebSocket wins for Clean Disk because our real complexity is state recovery and query pagination, not socket syntax.

## Protocol Shape Comparison

### REST-ish HTTP + Plain WebSocket Events

Assessment: 🎯 10   🛡️ 9   🧠 5, roughly 600-1500 LOC.

Best for:

- browser web UI;
- OpenAPI documentation;
- paginated read models;
- simple CLI/debugging;
- keeping commands/queries separate from event notifications.

Why likely less code than Socket.IO for Clean Disk:

- HTTP commands/queries already use `abstract_http_client`;
- WebSocket event client is small if it only receives notifications;
- no Socket.IO protocol adapter, rooms, namespaces, Engine.IO fallback, or version-compat layer;
- resync logic is needed either way, so Socket.IO does not remove the hard part.

### HTTP + SSE Events

Assessment: 🎯 7   🛡️ 8   🧠 4, roughly 450-1100 LOC.

SSE is server-to-client only. For Clean Disk that is actually enough for progress/events if commands stay HTTP.

Pros:

- simpler than WebSocket;
- native browser `EventSource`;
- reconnect model is part of SSE;
- easy to debug as HTTP stream.

Cons:

- not bidirectional;
- custom headers/auth with `EventSource` can be awkward in browsers;
- Dart/Flutter cross-platform story is less direct than WebSocket;
- if later we need client-to-server streaming or unified local socket behavior, SSE is limiting.

Good fallback candidate if WebSocket creates browser/proxy friction.

### JSON-RPC 2.0 Over WebSocket

Assessment: 🎯 7   🛡️ 8   🧠 6, roughly 800-1900 LOC.

Best for:

- daemon-style method API;
- future CLI/local socket parity;
- one protocol over many bidirectional transports;
- teams that prefer RPC contracts over REST resources.

Concern:

- OpenRPC ecosystem is smaller;
- subscription/replay semantics are still ours;
- HTTP client stack becomes less central for app commands;
- generated Dart clients may be less mature than OpenAPI/Dio flows.

### Socket.IO

Assessment: 🎯 4   🛡️ 6   🧠 7, roughly 1000-2600 LOC.

Best for:

- chat/collaboration style apps;
- many rooms/namespaces;
- public Socket.IO integrations;
- environments where long-polling fallback is measured as necessary.

Concern:

- not plain WebSocket;
- server-to-client missed-event recovery remains our job;
- Socket.IO protocol must be tested across Rust server and Dart client versions;
- does not document command/query API like OpenAPI.

## Exchange-Grade Architecture Lens

If this were a large exchange, the architecture would not be "one nice socket library for everything".

It would likely split traffic by correctness and latency needs:

```text
Public/reference queries:
  HTTP/gRPC-style request-response

Order commands:
  FIX, binary protocol, or strongly typed RPC with idempotency and acknowledgements

Market/user feeds:
  sequenced WebSocket/binary feeds with heartbeats, snapshots, deltas, gap detection, and replay/resync

Internal pipeline:
  durable log/event bus, not browser sockets
```

Real examples point in this direction:

- Coinbase Advanced Trade documents REST for programmatic trading/order management and WebSocket for real-time data.
- Coinbase WebSocket docs expose separate market data and user order data endpoints, with JSON messages and typed message handling.
- Binance.US documentation describes REST APIs for exchange/account/order/wallet operations and WebSocket streams for market/user data streams.
- FIX Trading Community describes FIX as an industry standard for trading communication.

The important architectural lesson:

```text
High-reliability systems do not rely on "the socket library" for correctness.
They rely on protocol-level sequence numbers, snapshots, idempotent commands,
acknowledgements, replay, durable state, and explicit recovery.
```

Applied to Clean Disk:

```text
Commands and destructive actions need idempotency and explicit receipts.
Tree/detail/search queries need authoritative request-response reads.
Progress events need sequence numbers, reconnect, and resync.
```

That leans toward either:

- HTTP commands/queries + WebSocket events; or
- JSON-RPC over WebSocket with our own subscription/replay layer.

It does not strongly point toward Socket.IO unless the product specifically needs Socket.IO's rooms, fallbacks, and ecosystem.

## Socket.IO Community And Reuse Assessment

Socket.IO is mature and widely used in the JavaScript/web realtime community.

Community-positive reasons:

- easy event emitter model;
- automatic reconnect;
- fallback to HTTP long-polling when WebSocket is blocked;
- rooms and namespaces are well-known and useful for chats/collaboration;
- many tutorials and examples;
- multi-server adapters exist;
- great fit for Node.js realtime products.

Community-negative or caution reasons:

- it is a custom protocol on top of Engine.IO/WebSocket, not raw WebSocket;
- non-JS server ecosystems depend on third-party implementations and protocol-version compatibility;
- it can hide transport details until debugging production reconnect/fallback behavior;
- official docs still require application-level work for server-to-client delivery guarantees;
- connection state recovery helps intermittent disconnects, but docs say recovery is not always successful and the app must still resync state;
- some adapter combinations do not support recovery, such as Redis PUB/SUB according to the Socket.IO compatibility table.

For a future chat-heavy app, Socket.IO becomes much more attractive:

```text
rooms = conversation/channel membership
namespaces = product areas or tenant partitions
acks = message send confirmation
reconnect = better UX under mobile networks
fallback polling = useful behind restrictive proxies
adapters = horizontal scaling
```

But Clean Disk is not naturally room-centric. Its "rooms" would mostly be scan sessions and user tabs. That is simple enough to model ourselves.

Reuse strategy:

```text
Create our own RealtimeTransport abstraction.
Implement PlainWebSocketTransport first for Clean Disk.
Keep SocketIoTransport as a future adapter for chat/collaboration products.
Share event envelope, reconnection policy, auth token handling, and resync concepts.
Do not force Clean Disk to adopt Socket.IO only because another future product might need it.
```

This avoids the wrong kind of reuse. We reuse the architecture, not necessarily the protocol dependency.

### gRPC/gRPC-Web

Assessment: 🎯 4   🛡️ 7   🧠 8, roughly 1200-3500 LOC plus build/proxy complexity.

Not recommended for the Flutter web surface. Browser gRPC-Web has streaming limitations and often needs proxies or protocol compromises. It can be revisited only if we later build a non-browser internal service API.

### WebTransport

Assessment: 🎯 3   🛡️ 5   🧠 8, roughly 1500-4000 LOC.

Interesting long-term transport, but too early for Clean Disk MVP. It is powerful but would add browser support, security, and implementation complexity before the product protocol is stable.

## Updated Recommendation

For Clean Disk MVP:

```text
HTTP commands/queries:
  CleanDiskApiClient over existing abstract_http_client

Events:
  plain WebSocket through web_socket_channel

Protocol docs:
  OpenAPI/JSON Schema for HTTP DTOs
  AsyncAPI or schema snapshots for WebSocket events later if needed
```

Do not use `HttpClient` raw in every repository except for temporary spike code.

Do not choose Socket.IO unless we explicitly accept Socket.IO protocol coupling for a measured reason.

Do not choose JSON-RPC yet, but keep it as the strongest alternative if we decide that "daemon RPC API" matters more than OpenAPI-friendly HTTP queries.
