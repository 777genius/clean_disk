# Execution Board

Last updated: 2026-05-16.

This file is the single implementation board from zero context to releasable
product. It connects:

- product trains from [Release train map](release-train-map.md);
- milestones from [Implementation runbook](implementation-runbook.md);
- phases from [Phase reading guide](phase-reading-guide.md);
- owner lanes from [README Work Lanes](README.md);
- gates from [Critical zones](critical-zones/README.md).

It is not a source of new architecture decisions. It tells you what to do next
and which document to open before doing it.

## How To Use

1. Find the first incomplete row.
2. Open the docs in the `Open` column.
3. Produce the `Deliverable`.
4. Check the `Gate`.
5. Keep the `Do not pull in` column out of the task.
6. Move to the next row only when the gate has evidence.

If the current task does not fit a row, route it through:

- [Task router](task-router.md);
- [Capability implementation matrix](capability-implementation-matrix.md);
- [Reading order checklist](reading-order-checklist.md).

If the row is too small or too isolated, use
[README Implementation Packet Index](README.md#implementation-packet-index) to
group the work into a packet. Packets are the preferred planning unit for real
implementation slices.

## Board At A Glance

| Row | Train | Milestone | Phase | Lane | Deliverable |
| --- | --- | --- | --- | --- | --- |
| 0 | T0 | M0 | P0 | documentation | recover context and doc structure |
| 1 | T0 | M0 | P0 | architecture | accepted architecture baseline |
| 2 | T1 | M1 | P1 | reusable Rust engine | Rust crate skeleton and ports |
| 3 | T1 | M2 | P1 | scanner adapter | pdu adapter contract and fixtures |
| 4 | T1 | M2 | P1 | reusable Rust engine | compact read model and indexes |
| 5 | T1 | M2-M3 | P1-P2 | server/runtime | scanner runtime lanes and resource budgets |
| 6 | T1 | M3 | P2 | server/runtime | protocol DTOs and session state |
| 7 | T1 | M3 | P2 | server/runtime | HTTP queries and WebSocket events |
| 8 | T1 | M4 | P3 | Flutter app, design system | app shell and scan UI foundation |
| 9 | T1 | M4 | P3 | Flutter app | scan tree/table, details, search, progress |
| 10 | T4 partial | M7 | P6 | distribution/security | scan-only packaging and permission identity |
| 11 | T2 | M5 | P4 | cleanup safety | DeletePlan preview and revalidation dry-run |
| 12 | T2 | M5 | P4 | cleanup safety | Trash adapter, journal, receipts, recovery |
| 13 | T3 | M6 | P5 | recommendations | rules, evidence, official command adapters |
| 14 | T4 | M7-M9 | P6-P8 | distribution/security | signed release, update, rollback, dependency gates |
| 15 | T5 | M8 | P7 | server/runtime, distribution/security | remote/headless read-only mode |
| 16 | T7 | M8-M9 | P7-P8 | support/release | diagnostics and support bundles |
| 17 | T4-T7 | M9 | P8 | support/release | release readiness evidence |

## Product Slice Paths

Use these paths when the task is product-slice oriented.

| Slice | Rows | Build before moving on | Keep out |
| --- | --- | --- | --- |
| documentation and architecture recovery | 0, 1 | docs are indexed, accepted architecture is discoverable | product code |
| scan-only MVP | 2, 3, 4, 5, 6, 7, 8, 9 | scanner, read model, protocol, and scan UI work end to end | cleanup, recommendations, remote cleanup |
| scan-only desktop proof | 10 | signed scanner identity and permission probe are proven | destructive cleanup |
| local cleanup beta | 11, 12 | DeletePlan, identity revalidation, journal, receipts, Trash, recovery | recommendations, command adapters, remote cleanup |
| recommendations and tools beta | 13 | evidence-backed rules and official command adapters are safe | generic deletion of tool stores |
| signed desktop release | 10, 14, 17 | installer, permissions, update, rollback, dependencies, test evidence | remote cleanup |
| remote/headless read-only | 15 | scoped read-only service with authZ, quotas, audit | destructive remote operations |
| support and operations | 16, 17 | diagnostics, support bundle, release evidence | raw logs, raw database export |

Default low-risk order:

```text
0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9
  -> 10
  -> 11 -> 12
  -> 14 -> 16 -> 17
  -> 15
  -> 13
```

Remote cleanup is intentionally not in the default path. It requires a separate
authority review before any implementation row is added.

## Detailed Execution Board

| Row | Do | Open | Gate | Do not pull in |
| --- | --- | --- | --- | --- |
| 0 | Recover context, doc ownership, and current scope. | [START_HERE](../../START_HERE.md), [README](README.md), [Documentation map](documentation-map.md), [Documentation sitemap](documentation-sitemap.md), [Reading order checklist](reading-order-checklist.md) | every accepted rule is reachable from README | product code, new dependencies |
| 1 | Confirm architecture baseline and future boundaries. | [Architecture decisions](architecture-decisions.md), [Architecture fit validation](architecture-fit-validation.md), [Architecture future risks](architecture-future-risks.md), [Future-proofing architecture gates](future-proofing-architecture-gates.md), [Rust architecture](rust-architecture.md) | Clean Architecture, DDD, ports/adapters, daemon, HTTP/WebSocket, and pdu adapter boundaries are explicit | FRB, gRPC, Socket.IO, microservices, hosted localhost pairing |
| 2 | Create reusable Rust crate skeleton and server composition shape. | [Rust architecture](rust-architecture.md), [Rust best practices](rust-best-practices.md), [Rust runtime critical zone](critical-zones/rust-runtime-execution.md) | domain/application do not import pdu, HTTP, Flutter, SQLite, process APIs, or generated code | pdu concrete types in core, route DTOs in domain |
| 3 | Build pdu adapter contract and fixture tests. | [pdu data model and adapter guide](pdu-data-model-and-adapter-guide.md), [pdu critical risk verification](pdu-critical-risk-verification.md), [pdu required capabilities audit](pdu-required-capabilities-audit.md), [pdu adapter integration](implementation-edge-cases-pdu-adapter-integration.md) | only the adapter imports `parallel_disk_usage`; late results after cancellation are discarded | CLI wrapper in production, pdu JSON as product DTO |
| 4 | Build compact arena/read model, node IDs, indexes, pagination, search/sort/filter. | [Performance scale](implementation-edge-cases-performance-scale.md), [Filesystem model](implementation-edge-cases-filesystem-model.md), [Search query indexing](implementation-edge-cases-search-query-indexing.md) | Flutter cannot receive full tree; memory profile is bounded | full `PathBuf` per node in main arena, UI-side filtering over full tree |
| 5 | Define scanner execution lanes, cancellation, shutdown, panic containment, and resource profiles. | [Rust runtime critical zone](critical-zones/rust-runtime-execution.md), [Resource governance](implementation-edge-cases-resource-governance.md), [Operational reliability](implementation-edge-cases-operational-reliability.md) | blocking filesystem work does not run on async reactor threads; cancellation and shutdown are tested | unlimited worker pools, scan modes without budgets |
| 6 | Define protocol DTOs, session lifecycle, errors, large integer policy, cursor policy. | [Protocol data contracts](implementation-edge-cases-protocol-data-contracts.md), [Concurrency state machines](implementation-edge-cases-concurrency-state-machines.md) | DTOs are separate from domain and Flutter view state; web-safe numeric policy exists | raw domain structs over the wire, unversioned enums |
| 7 | Implement HTTP commands/queries and plain WebSocket events. | [Transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md), [Transport client generation research](transport-client-generation-research.md), [Web UI daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md) | sequence, reconnect, backpressure, event gaps, resync, token, and origin policy are explicit | Socket.IO, JSON-RPC, gRPC, FRB in MVP without reopening decision |
| 8 | Build Flutter shell, routing, design-system facade, target picker, scan layout foundation. | [Feature UX benchmark](feature-ux-benchmark.md), [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md), [Frontend boundaries decision](frontend-boundaries-decision.md), [Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md), [Permission UX playbook](permission-ux-playbook.md), [Design references](../design/references/clean-disk-wide-reference.png) | UI follows saved references and reports Headless gaps | marketing landing page, feature logic inside design system |
| 9 | Build virtualized scan tree/table, details, progress, search/filter/sort, compact layout. | [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md), [Frontend boundaries decision](frontend-boundaries-decision.md), [Cross-platform UX playbook](cross-platform-user-experience-playbook.md), [Real product feature adoption playbook](real-product-feature-adoption-playbook.md), [Product workflows](implementation-edge-cases-product-workflows.md) | UI uses paginated Rust queries, stable node IDs, clean DTO/command boundaries | full tree state in Flutter, cleanup truth from visible rows |
| 10 | Prove scan-only packaging, signing identity, permission preflight, and updater constraints. | [Platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md), [Permission UX playbook](permission-ux-playbook.md), [Update release rollback safety](critical-zones/update-release-rollback-safety.md) | permission probe and scanner execution use the same signed identity | external random `pdu` binary, cleanup release without receipts |
| 11 | Build cleanup preview with DeletePlan and identity revalidation dry-run. | [Cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md), [Platform identity revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md), [Reclaim accounting research](reclaim-accounting-deep-research.md) | stale identity blocks action; no side effects before preview | destructive adapter call, exact reclaim promise |
| 12 | Add durable journal, receipt skeleton, Trash adapter, per-item outcomes, low-disk and crash recovery. | [Receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md), [Restore quarantine undo safety](critical-zones/restore-quarantine-undo-safety.md), [Local state persistence](implementation-edge-cases-local-state-persistence.md), [Storage accounting](implementation-edge-cases-storage-accounting-snapshots-shared-extents.md) | cleanup cannot run if durable intent cannot be written | path-string deletion, batch-only receipts, auto-retry after crash |
| 13 | Add recommendations and official cleanup command adapters. | [Recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md), [Tool-managed storage](implementation-edge-cases-tool-managed-storage.md), [Rule-pack safety](critical-zones/recommendation-policy-rule-pack-safety.md), [Command sandbox](critical-zones/tool-command-execution-sandbox.md) | every recommendation has evidence, risk tier, invalidation, and cannot bypass DeletePlan | generic deletion of tool stores, shell snippets, PATH lookup |
| 14 | Harden signed desktop release, dependency governance, update, rollback, migrations, release tests. | [Dependency governance](implementation-edge-cases-dependency-supply-chain-governance.md), [Security privacy](implementation-edge-cases-security-privacy.md), [Testing quality gates](implementation-edge-cases-testing-quality-gates.md), [Update release rollback safety](critical-zones/update-release-rollback-safety.md) | release artifacts have identity, dependency, update, rollback, and test evidence | updater during active cleanup, unreproducible dependency inputs |
| 15 | Add remote/headless read-only profile with scopes, auth/authZ, quotas, and audit. | [Remote headless mode](implementation-edge-cases-remote-headless-mode.md), [Web UI daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md), [Security privacy](implementation-edge-cases-security-privacy.md), [Remote destructive authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md) | remote APIs are read-only by default and authorized per object | remote cleanup, local loopback token as remote credential |
| 16 | Add diagnostics, crash summary policy, logs/metrics policy, support bundle manifest, redaction. | [Diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md), [Support bundle privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md), [Local state persistence](implementation-edge-cases-local-state-persistence.md) | export is typed, bounded, redacted, consented, and useful | raw log/database zip, raw paths/tokens/search text in metrics |
| 17 | Run release readiness gates for every enabled risky capability. | [Testing quality gates](implementation-edge-cases-testing-quality-gates.md), [Critical zones index](critical-zones/README.md), [Implementation runbook](implementation-runbook.md) | crash, low-disk, destructive, update, permission, scale, migration, and privacy gates pass | happy-path-only release claims |

## Workstream Map

Use this to see which rows belong together.

| Workstream | Rows | Primary docs | Main proof |
| --- | --- | --- | --- |
| documentation and recovery | 0 | documentation map, sitemap, checklist, README | docs are reachable and consistent |
| architecture baseline | 1 | architecture decisions, fit validation, Rust architecture | dependency direction is enforceable |
| scanner engine | 2, 4, 5 | Rust architecture, performance, filesystem model, runtime critical zone | bounded memory and execution lanes |
| pdu adapter | 3 | pdu guide, pdu audit, pdu risk verification | adapter isolation and fixtures |
| protocol/runtime | 6, 7 | protocol DTOs, transport streaming, web runtime | reconnect, cursor, auth, event guarantees |
| Flutter product UI | 8, 9 | feature UX, large-tree UI, design references | paginated UI with stable IDs |
| cleanup safety | 11, 12 | cleanup safety, identity, receipts, reclaim, restore | durable intent before side effects |
| recommendations/tools | 13 | recommendation rules, tool storage, command sandbox | evidence and command receipts |
| distribution/release | 10, 14, 17 | packaging, update rollback, dependency governance, testing | signed identity and release evidence |
| remote/support | 15, 16 | remote mode, diagnostics, support privacy | read-only remote and redacted support export |

## Daily Execution Loop

Use this loop for every task:

```text
Task request
  -> pick capability row
  -> pick execution-board row
  -> open required docs
  -> write excluded scope
  -> implement smallest slice
  -> prove gate
  -> update docs if a rule changed
```

Task card:

```text
Execution board row:
Capability:
Train:
Milestone:
Phase:
Owner lane:
Required docs:
Critical gates:
Excluded scope:
Deliverable:
Evidence:
```

If the task card cannot be filled, do not code yet.

## Board Maintenance Rules

- Add a row only if it changes implementation order or introduces a new gate.
- Do not move accepted architecture here; put it in
  [Architecture decisions](architecture-decisions.md).
- Do not move detailed edge cases here; link the relevant edge-case document.
- If a row changes train, milestone, phase, or lane, update
  [Capability implementation matrix](capability-implementation-matrix.md),
  [Release train map](release-train-map.md), and
  [Implementation runbook](implementation-runbook.md).
- If a row introduces a global release blocker, update
  [Critical zones](critical-zones/README.md).
