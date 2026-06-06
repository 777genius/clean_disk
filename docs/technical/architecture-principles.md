# Architecture Principles Research

Last updated: 2026-05-12.

This document records the cross-source architecture consensus we use for Clean Disk. It is intentionally language-agnostic first, then mapped to Flutter and Rust.

## Sources Reviewed

Primary and high-signal sources:

- Robert C. Martin, [The Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html).
- Robert C. Martin, [The Clean Architecture Dependency Rule](https://www.informit.com/articles/article.aspx?p=2832399).
- Robert C. Martin, [The Single Responsibility Principle](https://blog.cleancoder.com/uncle-bob/2014/05/08/SingleReponsibilityPrinciple.html).
- Robert C. Martin, [The Open Closed Principle](https://blog.cleancoder.com/uncle-bob/2014/05/12/TheOpenClosedPrinciple.html).
- Robert C. Martin, [SOLID Relevance](https://blog.cleancoder.com/uncle-bob/2020/10/18/Solid-Relevance.html).
- Robert C. Martin, [Screaming Architecture](https://blog.cleancoder.com/uncle-bob/2011/09/30/Screaming-Architecture.html).
- Alistair Cockburn, [Hexagonal Architecture, the original 2005 article](https://alistair.cockburn.us/hexagonal-architecture).
- Mark Seemann, [Layers, Onions, Ports, Adapters: it's all the same](https://blog.ploeh.dk/2013/12/03/layers-onions-ports-adapters-its-all-the-same/).
- Robert C. Martin's package/component principles as summarized in [Sitecore Helix package principles](https://helix.sitecore.com/appendix/package-principles.html), [Acyclic Dependencies Principle](https://en.wikipedia.org/wiki/Acyclic_dependencies_principle), and component principle references.
- Eric Evans / Domain Language, [DDD Reference](https://www.domainlanguage.com/ddd/reference/).
- Martin Fowler, [Bounded Context](https://martinfowler.com/bliki/BoundedContext.html).
- Martin Fowler, [Anemic Domain Model](https://www.martinfowler.com/bliki/AnemicDomainModel.html).
- Vaughn Vernon, [Effective Aggregate Design](https://www.dddcommunity.org/library/vernon_2011/).
- Microsoft Learn, [Designing a DDD-oriented microservice](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/ddd-oriented-microservice).
- Microsoft Learn, [Common web application architectures](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures).
- Microsoft Learn, [Domain events: Design and implementation](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation).
- Microsoft Learn, [CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs).
- Flutter docs, [Guide to app architecture](https://docs.flutter.dev/app-architecture/guide) and [Common architecture concepts](https://docs.flutter.dev/app-architecture/concepts).
- Rust Book, [Packages and Crates](https://doc.rust-lang.org/book/ch07-01-packages-and-crates.html), [Modules](https://doc.rust-lang.org/book/ch07-02-defining-modules-to-control-scope-and-privacy.html), and [Cargo Workspaces](https://doc.rust-lang.org/book/ch14-03-cargo-workspaces.html).
- Cargo Book, [Workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html).
- Rust API Guidelines, [Type safety](https://rust-lang.github.io/api-guidelines/type-safety.html), [Dependability](https://rust-lang.github.io/api-guidelines/dependability.html), and [Public dependencies](https://rust-lang.github.io/api-guidelines/necessities.html).
- Spring Modulith docs, [Application Modules](https://docs.spring.io/spring-modulith/reference/fundamentals.html) and project overview.
- Spring Modulith docs, [Verifying Application Module Structure](https://docs.spring.io/spring-modulith/reference/verification.html).
- ArchUnit, [User Guide](https://www.archunit.org/userguide/html/000_Index.html).
- Three Dots Labs, [Clean Architecture in Go](https://threedots.tech/post/introducing-clean-architecture/).
- DDD Practitioner's Guide, [Anti-corruption Layer](https://ddd-practitioners.com/home/glossary/bounded-context/bounded-context-relationship/anticorruption-layer/).
- Context Mapper, [CML language reference](https://contextmapper.org/docs/language-reference/) and [Customer/Supplier](https://contextmapper.org/docs/customer-supplier/).
- DDD Crew, [DDD Starter Modelling Process](https://github.com/ddd-crew/ddd-starter-modelling-process).
- Neal Ford, Rebecca Parsons, and Patrick Kua, [Architecture fitness functions](https://www.oreilly.com/library/view/building-evolutionary-architectures/9781491986356/ch02.html).
- ABP, [Domain Logic and Application Logic](https://abp.io/docs/4.1/Domain-Driven-Design-Implementation-Guide#domain-logic-application-logic).
- arXiv systematic review, [Domain-Driven Design in Software Development](https://arxiv.org/abs/2310.01905).
- Alexis King, [Parse, don't validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/).
- Functional Software Architecture, [Make Illegal States Unrepresentable](https://functional-architecture.org/make_illegal_states_unrepresentable/) and [Functional Core, Imperative Shell](https://functional-architecture.org/functional_core_imperative_shell/).
- David L. Parnas, [On the Criteria To Be Used in Decomposing Systems into Modules](https://sunnyday.mit.edu/16.355/parnas-criteria.html).
- Cliff L. Biffle, [The Typestate Pattern in Rust](https://cliffle.com/blog/rust-typestate/).
- Chris Richardson / Microservices.io, [Domain event](https://microservices.io/patterns/data/domain-event.html) and [Transactional outbox](https://microservices.io/patterns/data/transactional-outbox.html).
- Michael Nygard, [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions).
- ADR GitHub organization, [Architectural Decision Records](https://adr.github.io/).
- Microsoft Azure Architecture Center, [CQRS](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs), [Pipes and Filters](https://learn.microsoft.com/en-us/azure/architecture/patterns/pipes-and-filters), [Publisher-Subscriber](https://learn.microsoft.com/en-us/azure/architecture/patterns/publisher-subscriber), [Asynchronous Request-Reply](https://learn.microsoft.com/en-us/azure/architecture/patterns/asynchronous-request-reply), [Queue-Based Load Leveling](https://learn.microsoft.com/en-us/azure/architecture/patterns/queue-based-load-leveling), [Materialized View](https://learn.microsoft.com/en-us/azure/architecture/patterns/materialized-view), and [Busy Front End antipattern](https://learn.microsoft.com/en-us/azure/architecture/antipatterns/busy-front-end/).
- Reactive Streams, [Reactive Streams specification overview](https://www.reactive-streams.org/).
- Erlang/OTP docs, [Supervision Trees](https://www.erlang.org/docs/27/system/design_principles.html).
- Eric Evans and Martin Fowler, [Specification pattern](https://martinfowler.com/apsupp/spec.pdf).
- AWS Prescriptive Guidance, [Hexagonal architecture pattern](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/hexagonal-architecture.html).

## Shared Consensus

The recurring idea across these sources is not a specific folder layout. It is controlled dependency direction around things that change at different speeds.

- Domain rules change for product/domain reasons.
- Application use cases change when workflows change.
- Infrastructure changes when technology changes: database, scanner crate, filesystem APIs, sockets, HTTP, WebSocket, OS Trash, framework details.
- Presentation changes when UX changes.

Clean Architecture, Hexagonal Architecture, Onion Architecture, and DDD-oriented layered architecture converge on the same rule: high-level policy must not depend on low-level detail. The outside may depend inward. The inside must not know the outside.

## Follow-up Insights

The second research pass added these stronger rules.

### Architecture Should Scream Use Cases

The top-level shape should communicate the product domain before it communicates frameworks. For Clean Disk, `scan`, `cleanup`, `delete plans`, `scan sessions`, and `tree queries` should be visible concepts. `axum`, `tokio`, `pdu`, `Flutter`, `Dio`, and `WebSocket` are implementation details and should live at the edges.

Practical rule: choose context-first and feature-first structure over framework-first structure.

### Use Anti-Corruption Layers Deliberately

An anti-corruption layer protects a bounded context from external language or data shape.

Clean Disk anti-corruption boundaries:

- `scan/infrastructure/pdu` protects scan language from `parallel-disk-usage`.
- `shared/protocol/mapping` protects application/domain from wire DTOs.
- `cleanup/application/port/node_identity_provider.rs` protects cleanup from depending on scan indexes directly.
- A future FRB adapter would be another interface adapter, not a domain dependency.

This has cost, so use it at real boundaries only. Do not create mapping layers between two types that are already in the same context and same layer for no reason.

### Aggregates Should Be Small Consistency Boundaries

Vaughn Vernon's aggregate guidance matters here. Aggregates are not object graphs for convenient navigation. They protect invariants inside a consistency boundary.

Clean Disk consequence:

- Do not model the entire scanned filesystem tree as one huge domain aggregate.
- `ScanSession` can be a domain concept, but the full tree/index should be an infrastructure read/index model.
- `DeletePlan` is a better aggregate candidate because it has safety invariants and a confirmation lifecycle.
- `ScanNode` and `NodeIdentity` can be domain models/value objects, but large tree traversal, sorting, searching, and pagination are query/index responsibilities.

This keeps domain logic understandable and avoids loading or mutating massive aggregates.

### Queries Are Not Always Domain Models

CQRS research reinforces a useful split: writes/commands protect invariants; reads/queries return views optimized for the UI.

Clean Disk consequence:

- `TreeRow`, `NodeDetails`, `TopItem`, and search result pages are query projections, not domain entities.
- The central folder table can be backed by Rust indexes and read DTOs without pretending that every row is a rich aggregate.
- Commands like `start_scan`, `cancel_scan`, `validate_delete_plan`, and `move_to_trash` should remain explicit use cases.
- This is logical CQRS. It does not require separate databases or event sourcing.

### Domain Logic Is Not "Important Logic"

Domain logic is core invariant logic. Important but use-case-specific work belongs to application.

Clean Disk examples:

- Domain: stale candidate policy, delete safety rules, hardlink policy, mount boundary policy, scan target validity.
- Application: start/cancel workflow, authorization/session token checks, confirmation workflow, transaction/work unit boundaries, event publication orchestration.
- Infrastructure/interface: OS metadata reads, pdu traversal, Trash API, HTTP auth middleware, WebSocket reconnect, logging, tracing.

If a rule changes depending on UI/client/deployment mode, it is probably application logic or adapter policy, not core domain.

### Verify Architecture, Do Not Rely On Memory

Spring Modulith and similar tooling emphasize automated module verification: no cycles, API-only access, explicit allowed dependencies.

Clean Disk consequence:

- Rust crate boundaries should enforce most dependency direction physically.
- Add CI checks using `cargo metadata` or a small `xtask` once Rust crates exist.
- Dart/Flutter features should get boundary tests that reject framework/infrastructure imports in domain/application.
- Make protocol and adapter dependencies explicit in workspace manifests.

Architecture docs are useful, but executable boundary checks prevent slow drift.

### Component Principles Matter For Crates

SOLID is not enough at crate/package scale. Robert Martin's component principles add useful pressure:

- Common Closure Principle: code that changes for the same reason belongs together.
- Common Reuse Principle: code that is not reused together should not be forced into the same dependency.
- Acyclic Dependencies Principle: package/crate dependency graphs must not contain cycles.
- Stable Dependencies Principle: unstable detail crates should depend on stable policy crates, not the reverse.
- Stable Abstractions Principle: stable crates should expose abstractions and stable domain language, not volatile implementation detail.

Clean Disk consequence:

- `shared/kernel` must remain tiny. A large shared package violates CRP by forcing every context to depend on things it does not use.
- `scan/domain` and `cleanup/domain` should be stable and small enough to depend on safely.
- `pdu`, `http_ws`, `trash`, and `jobs` are volatile detail crates. They must point inward.
- Do not create a generic `utils` crate. Create shared code only when reuse and closure are both real.

### Shared Kernel Is Not Published Language

DDD context mapping separates several relationship styles. Two are especially relevant:

- Shared Kernel: a small shared model owned jointly by multiple contexts.
- Published Language: a stable interchange language exposed at a boundary.

Clean Disk consequence:

- `shared/kernel` is Shared Kernel and must be small, stable, and boring.
- `shared/protocol` is closer to Published Language for clients and transports. It is not domain.
- `scan` and `cleanup` should not casually share models. If `cleanup` needs scan identity, use a port and mapping.

### No Adapter-To-Adapter Coupling

Ports/adapters and ArchUnit onion checks both reinforce a simple rule: adapters sit around the application core and should not call each other directly.

Clean Disk consequence:

- `http_ws` must not call `pdu` or `trash` directly.
- `pdu` must not know `http_ws`, `protocol`, or cleanup.
- `trash` must not know scan memory indexes.
- App composition wires adapters together through application ports.

### DDD Discovery Is Continuous

DDD Crew and EventStorming-oriented sources emphasize that discovery is not a one-time diagram. Bounded contexts evolve as domain understanding improves.

Clean Disk consequence:

- `scan` and `cleanup` are accepted starting contexts, not sacred forever.
- Future contexts may emerge, for example `history`, `rules`, `storage_targets`, or `automation`, but only when language and reasons-to-change justify them.
- Technical docs should record current decisions and open questions, not pretend that early modeling is final truth.

### Rust Should Encode Invariants In Types

Rust API Guidelines make this unusually practical.

Clean Disk consequence:

- Use newtypes for `ScanSessionId`, `NodeId`, `DeletePlanId`, `ByteSize`, `ItemCount`, `ConfirmationToken`, `SessionToken`, and validated paths.
- Prefer enums/custom types over boolean flags for options like hardlink handling, mount boundary behavior, delete mode, and scan scope.
- Parse at boundaries and then pass typed domain/application values inward.
- Do not leak unstable public dependencies. For example, public APIs in domain/application crates must not expose `pdu`, `axum`, WebSocket, or platform Trash types.

### Parse At Boundaries, Do Not Re-Validate Everywhere

Alexis King's "parse, don't validate" argument is especially relevant for a daemon that receives commands from HTTP, WebSocket, CLI, and possibly future bridges. A boolean validation step usually throws away what it learned. Parsing should convert untrusted input into a more precise type that carries the proof forward.

Clean Disk consequence:

- Transport adapters parse raw JSON, query params, headers, paths, and tokens into protocol DTOs or typed application commands.
- Protocol mapping parses DTOs into application/domain types such as `ScanTarget`, `PageRequest`, `NodeId`, `DeleteCandidate`, `SessionToken`, and `ConfirmationToken`.
- After parsing, inner code should not repeatedly ask "is this path valid?" or "is this token shaped correctly?" It should receive a type that could not have been constructed otherwise.
- Metadata freshness is different from input parsing. Cleanup must still revalidate current filesystem metadata before Trash because the world can change after scan.

This avoids shotgun validation and keeps checks close to system boundaries.

### Make Illegal States Unrepresentable

Functional DDD and Rust both push us toward precise state modeling instead of flag-heavy records. The goal is not type-theory ceremony. It is to prevent nonsense combinations from compiling or from being constructed in safe code.

Clean Disk consequence:

- `ScanStatus` should be an enum, not `is_running`, `is_cancelled`, `is_complete`, `has_error` booleans.
- `DeletePlanStatus` should represent lifecycle states such as draft, validated, confirmation-required, ready-to-trash, completed, failed, and cancelled without allowing impossible combinations.
- Use `NonEmpty<T>` or equivalent when a command requires at least one candidate.
- Use smart constructors/newtypes for non-negative byte sizes, bounded percentages, non-empty paths, and validated tokens.
- Use typestate selectively for local builder/session APIs where the state is known at compile time. Do not force typestate onto runtime session state that is naturally dynamic and persisted in registries.

### Functional Core, Imperative Shell

This is the functional-programming wording for the same boundary pressure Clean Architecture wants: pure policy inside, effects at the edge.

Clean Disk consequence:

- Domain policies should be mostly pure functions over typed values.
- Application use cases orchestrate ports, cancellation, authorization/session checks, event publication, and transactions/work units.
- Infrastructure and interface adapters own IO: filesystem, pdu, Trash, sockets, locks, async tasks, logs, and process state.
- Tests should mirror this split: many fast tests for pure domain/application behavior, fewer integration tests for adapters and process wiring.

### Domain Events Are Not Wire Events

DDD domain events, integration events, and WebSocket UI events are related but not the same object. Treating them as one DTO creates coupling between domain language, process reliability, and client protocol.

Clean Disk consequence:

- Domain events are internal facts inside a context, if we need them at all.
- Application events are use-case level notifications such as scan progress, skipped path, scan finished, delete plan validated, or Trash result.
- Protocol events are versioned wire messages in `shared/protocol`, batched and sequenced for clients.
- WebSocket `ScanEventBatch` is a delivery/protocol projection, not the domain event model.
- A local daemon with ephemeral sessions can start with an in-memory event log and replay window. If we later add persistent history, remote workers, or multi-process reliable delivery, then outbox-style persistence becomes relevant.

### Hide Volatile Design Decisions

Parnas's information hiding sharpens what "module" should mean. A module should hide a design decision likely to change behind a stable interface.

Clean Disk consequence:

- `scan/infrastructure/pdu` hides pdu's traversal shape, options, progress model, and errors.
- `scan/infrastructure/memory/tree` hides indexing and pagination strategy.
- `interfaces/http_ws` hides HTTP/WebSocket routing, heartbeat, reconnect, and auth details.
- `cleanup/infrastructure/trash` hides platform Trash behavior and unsupported server environments.
- Public module APIs should reveal the domain/use-case language, not internal data structures chosen for speed.

### Record Significant Decisions As ADRs

Nygard-style Architecture Decision Records are useful because this project has real tradeoffs: HTTP/WS vs FRB, pdu adapter vs custom scanner, local daemon vs embedded runtime, event replay strategy, delete safety model.

Clean Disk consequence:

- Keep accepted decisions in `docs/technical/architecture-decisions.md` while the project is young.
- Once decisions start changing or competing, add `docs/technical/adr/` and record one significant decision per ADR with context, decision, status, and consequences.
- ADRs should capture tradeoffs, not just the winning option.

## Additional Pattern Guidance For Clean Disk

These patterns are useful only when they solve a concrete pressure in the product. Do not add frameworks just because a pattern has a name.

### CQRS And Materialized Read Models

Clean Disk has a strong read/write asymmetry. Writes are rare and safety-sensitive: create session, start scan, cancel scan, validate delete plan, move to Trash. Reads are frequent and performance-sensitive: children pages, top items, search, selected node details, metrics, charts.

Use logical CQRS:

- Commands protect invariants and lifecycle.
- Queries return read models/projections optimized for UI.
- In-memory indexes such as children, top, search, sort, and details are materialized views over scan results.
- Do not introduce separate databases or event sourcing just to claim CQRS.

This supports the existing rule that Rust owns the full tree and clients query pages.

### Asynchronous Request-Reply For Long Work

Full disk scan and move-to-trash operations are long-running. A request should start or schedule work and return a handle quickly. Progress and completion arrive through query endpoints and event streams.

Clean Disk consequence:

- `start_scan` should not block until traversal completes.
- Client receives/keeps a `session_id`.
- The UI observes status through `get_summary`, paginated queries, and WebSocket event batches.
- If WebSocket is unavailable in a future environment, polling can be a fallback without changing use cases.

### Backpressure, Batching, And Queue-Based Load Leveling

The scanner can discover filesystem entries much faster than the UI can render or the network can transmit. Reactive Streams research frames the core rule: asynchronous streams need bounded queues and backpressure, otherwise buffers grow until the process becomes unstable.

Clean Disk consequence:

- Never emit one event per file to the UI.
- Use bounded channels between scanner jobs, index updates, and event publication.
- Coalesce progress into timed batches.
- Prefer dropping/replacing stale progress snapshots over buffering every progress tick.
- Preserve important terminal and error events even when progress events are throttled.
- Treat queue length and lag as observability metrics.

### Pipes And Filters For Scan Processing

Scanning naturally decomposes into a processing pipeline, but this should be an internal implementation pattern, not a distributed architecture by default.

Potential filters:

- filesystem traversal;
- metadata normalization;
- hardlink accounting;
- skip/error classification;
- node identity creation;
- tree/index update;
- progress aggregation;
- cleanup candidate classification.

Rules:

- Keep filters small and testable.
- Keep enough context in each pipeline message to process independently.
- Avoid distributed filters unless there is a real deployment need.
- Make retryable filters idempotent where they can update shared indexes.

### Pub/Sub Inside The Daemon, Not A Broker First

Event broadcast is useful because scan progress, UI sessions, logs, metrics, and future history can all observe the same work. But a full broker/outbox architecture is unnecessary for the first local daemon.

Clean Disk consequence:

- Use in-process pub/sub or an event bus abstraction for session events.
- Subscribers should be isolated: a slow WebSocket client must not block scanner/indexing work.
- Protocol event schemas must be versioned and backward compatible.
- Add durable outbox only when there is persistent history, remote workers, multi-process delivery, or external integrations.

### Supervision-Like Session Workers

Erlang/OTP supervision trees are a good mental model for scan sessions, but we do not need an actor framework by default.

Clean Disk consequence:

- Treat each scan session as an owned worker/job with explicit lifecycle.
- A supervisor/service owns start, cancel, cleanup, failure reporting, and resource disposal.
- Worker failure should mark only that session failed, not poison the whole daemon.
- Panics should be contained at task boundaries and converted to structured internal errors where possible.

### Specification Pattern For Safety Rules

Delete safety and candidate classification are rule-heavy enough for a light Specification pattern, especially when rules need to be composed and explained to the user.

Clean Disk consequence:

- Rules such as stale metadata, system protected path, mount boundary, symlink behavior, locked file, hardlink policy, and minimum reclaim threshold can be explicit specifications.
- The same rule object can answer "is this candidate allowed?" and "why not?".
- Do not create a generic rules engine. Start with typed policy/specification structs in the cleanup domain.

### Busy Front End Antipattern

The UI must not do heavy filesystem scanning or large-tree sorting itself. The browser cannot scan the disk, and even desktop Flutter should stay responsive.

Clean Disk consequence:

- UI renders pages and status.
- Rust daemon owns traversal, indexing, sorting, filtering, and deletion execution.
- Flutter owns interaction state, selected rows, layout, theme, and presentation logic.

### Pattern Cautions

- Event sourcing: not needed for scan sessions. It adds storage and replay complexity without clear product value right now.
- Full broker/pub-sub: useful for distributed/server deployments later, too heavy for first local daemon.
- Actor framework: maybe useful if session concurrency becomes complex, but Rust tasks plus explicit supervisors are enough to start.
- Generic repository everywhere: use repositories only for meaningful aggregate/session/read-model persistence. Do not wrap every data structure in a repository.
- Microservices: not useful for the local app. Keep a modular monolith/daemon with strong module boundaries.

## SOLID As Architecture Rules

Use SOLID as module and boundary guidance, not as class ceremony.

- SRP: group code that changes for the same reason. Split code that changes for different actors or reasons. For Clean Disk, scan rules, pdu integration, HTTP transport, delete safety, and UI state are separate reasons to change.
- OCP: add behavior by adding implementations, handlers, adapters, or policies where practical. Do not edit stable domain code just because the transport, scanner, or OS adapter changed.
- LSP: every adapter implementing a port must preserve the semantic contract of that port. A `ScannerPort` implementation cannot silently skip errors or change hardlink semantics unless the port contract allows it.
- ISP: keep ports small and role-specific. Prefer `ScannerPort`, `ScanTreeRepository`, `TrashPort`, and `NodeIdentityProvider` over one broad system facade.
- DIP: inner layers define abstractions, outer layers implement them. In Rust this usually means traits in `application` crates and concrete structs in `infrastructure` or `interfaces` crates.

## DDD Rules

DDD is most useful where the domain language matters. Clean Disk has enough domain behavior to justify light DDD: scan sessions, scan targets, node identity, stale candidate validation, delete plans, cleanup safety, skipped paths, hardlink policy, mount boundary policy.

Rules:

- Bounded contexts come before technical layers. Use `scan` and `cleanup` as separate contexts because they have different language and rules.
- A bounded context owns its vocabulary. `ScanNode`, `NodeIdentity`, `ScanSession`, `DeletePlan`, and `TrashResult` should not become generic cross-app data bags.
- Domain contains entities, value objects, aggregates, policies, and domain errors.
- Application contains use cases, commands, queries, app-level DTOs, ports, and orchestration.
- Infrastructure contains technical implementations of ports.
- Interface adapters contain transport/UI/CLI/protocol mapping.
- Shared kernel must stay tiny. Move a type into shared code only when it is genuinely stable across contexts.
- Avoid an anemic domain when there are real invariants. Put rules such as stale candidate checks, delete safety policy, scan scope policy, and hardlink counting policy near the domain model.
- Do not force tactical DDD everywhere. Simple DTO mapping and read-only query projections can stay simple.

## Clean Architecture Rules

The dependency rule is the hard rule:

```text
domain <- application <- adapters/infrastructure/interfaces <- apps/composition
```

Layer meaning:

- `domain` - highest-level domain policy and invariants. No framework, IO, serialization, async runtime, database, pdu, Flutter, HTTP, WebSocket, or generated bridge code.
- `application` - use cases and ports. It coordinates domain objects and declares what it needs from the outside world. It can define app DTOs for queries and commands.
- `infrastructure` - implementations of outbound ports: pdu scanner, OS Trash, filesystem metadata, in-memory registries, indexes, event logs, job runners, persistence.
- `interfaces` - inbound adapters and wire adapters: HTTP routes, WebSocket handlers, CLI commands, protocol mapping, possible future Flutter bridge adapter.
- `apps` - composition roots. They load config, create concrete adapters, wire dependencies, start processes, and own shutdown.

`runtime` is not a DDD or Clean Architecture layer. In Clean Disk, runtime-like pieces are process/infrastructure details unless they are pure use-case orchestration. Session registries, cancellation tokens, event logs, batching, tree indexes, and scan jobs belong under infrastructure modules because they deal with process state, concurrency, and delivery mechanics.

## Ports And Adapters Rules

Ports and adapters define how the application core talks to the outside world without knowing technologies.

- Inbound adapters translate an external trigger into an application use case call: HTTP route, WebSocket command, CLI command, future FRB call.
- Outbound ports express needs of the application: scan filesystem, publish scan events, store active session, validate metadata, move item to Trash.
- Outbound adapters implement those ports: pdu, platform Trash, in-memory session store, filesystem metadata reader.
- Adapters map external data immediately. `parallel-disk-usage`, socket frames, platform errors, and transport DTOs must not leak into domain.
- Multiple adapters may implement the same port. This is the main reason we can start with HTTP/WebSocket and later add Unix socket, named pipe, or FRB.

## Cross-Language Patterns

The same architecture appears differently per language:

- .NET commonly uses separate projects or class libraries: Domain, Application, Infrastructure, Web/API. Microsoft's docs put business logic/application model at the center and make infrastructure depend inward.
- Java/Spring often uses package/module boundaries. Spring Modulith emphasizes domain-driven application modules, provided/required interfaces, module verification, and integration tests.
- Go often keeps interfaces near the consumer package and uses `internal` packages. The key idea is still the same: application defines what it needs, adapters implement it, `main` wires dependencies.
- Flutter officially recommends separation of concerns, UI/data layers, optional domain/use-case layer for complex logic, repositories as sources of truth, unidirectional data flow, and lean widgets.
- Rust should use crates and modules as boundaries. Library crates model stable inner layers; binary crates are composition roots. Traits are ports, structs/enums/value types are domain/application types, modules enforce privacy, and Cargo workspaces keep related crates version-compatible.

The implementation style changes by language, but the invariant does not: domain/application code must not import framework or infrastructure detail.

## Clean Disk Rust Mapping

Accepted mapping:

```text
rust/
  apps/
    clean_disk_server/       # Clean Disk host, process config, auth, shutdown
    clean_disk_cli/          # CLI adapter/client
  crates/
    fs_usage_core/           # reusable domain language and value objects
    fs_usage_engine/         # reusable sessions, ports, indexes, queries
    fs_usage_pdu/            # parallel-disk-usage adapter
    fs_usage_platform/       # metadata, identity, volumes, permissions
    fs_usage_accounting/     # reclaim estimates and accounting confidence
    fs_usage_cleanup/        # reusable delete plans, preflight, Trash, receipts
    clean_disk_protocol/     # Clean Disk wire DTOs and versioned mapping
    clean_disk_http_ws/      # Clean Disk HTTP + WebSocket adapter
```

Rules for Clean Disk:

- `fs_usage_*` is the reusable library layer. It must not know Clean Disk, Flutter, HTTP, WebSocket, or app-specific protocol details.
- `clean-disk-server` is the host/composition root. It wires reusable library crates, adapters, protocol, auth, transport, config, and shutdown.
- Flutter is a client of the Clean Disk API. It does not own disk traversal or large scan indexes.
- `pdu` is an adapter, never a domain dependency. Only the dedicated pdu adapter crate may import `parallel_disk_usage`.
- HTTP/WebSocket is a Clean Disk transport adapter, never a reusable library assumption.
- Flutter DTOs and protocol DTOs are not domain models.
- Rust owns full scan trees and large indexes. Clients query pages.
- Progress/events are throttled and resumable by sequence number.
- Delete uses explicit plans, revalidation, and Trash/quarantine adapters.
- The server binary wires everything. Reusable library crates do not instantiate app-specific concrete adapters directly.

## Practical Boundary Tests

Add boundary checks when code exists:

- `fs_usage_core` must not import `tokio`, `serde` for wire compatibility, `axum`, pdu, platform APIs, Clean Disk protocol DTOs, or Flutter bridge code.
- `fs_usage_engine` must not import HTTP/WebSocket, pdu, Trash implementations, Flutter bridge code, Clean Disk protocol DTOs, or OS-specific modules.
- `parallel_disk_usage` imports are allowed only in the dedicated pdu adapter crate.
- Infrastructure crates may import application/domain and external libraries.
- Interface crates may import protocol/application and call use cases, but should not contain domain rules.
- App crates may depend on all concrete pieces because they are composition roots.

## Heuristics

Use these when choosing where code belongs:

- If it names a business concept or invariant, put it in `domain`.
- If it coordinates a user/system workflow, put it in `application`.
- If it talks to pdu, OS, filesystem, sockets, database, async tasks, locks, channels, or process state, put it in `infrastructure` or `interfaces`.
- If it maps wire/client data, put it in `protocol` or an interface adapter.
- If it decides concrete implementations, put it in an app composition root.
- If a type exists only to make one adapter easier, keep it inside that adapter.
- If multiple contexts need a type, first ask whether they really mean the same concept. If not, map between contexts instead of sharing.
