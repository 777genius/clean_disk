# Start Here

This is the short recovery file for Clean Disk. If you need the full technical
map, read [docs/technical/README.md](docs/technical/README.md). That file is the
canonical index for reading order, implementation order, and task-specific
documents. If you are not sure where to go, start with the Front Door section in
[docs/technical/README.md](docs/technical/README.md). For the shortest full
workflow, use the One Screen Map and Decision Funnel in
[docs/technical/README.md](docs/technical/README.md). For execution work, use
[docs/technical/implementation-runbook.md](docs/technical/implementation-runbook.md).
For the exact request-to-evidence documentation workflow, use
[docs/technical/documentation-operating-manual.md](docs/technical/documentation-operating-manual.md).
For the visual tree of all technical docs by layer and work area, use
[docs/technical/documentation-tree.md](docs/technical/documentation-tree.md).
For product slice boundaries, use
[docs/technical/release-train-map.md](docs/technical/release-train-map.md).
For one ordered path from context recovery to release gates, use the master
sequence in
[docs/technical/start-to-finish-guide.md](docs/technical/start-to-finish-guide.md).
For capability-level routing, use
[docs/technical/capability-implementation-matrix.md](docs/technical/capability-implementation-matrix.md).
For day-to-day task routing, use
[docs/technical/task-router.md](docs/technical/task-router.md).
For checkbox-style reading order by scenario, use
[docs/technical/reading-order-checklist.md](docs/technical/reading-order-checklist.md).
For the row-by-row build board from zero to release, use
[docs/technical/execution-board.md](docs/technical/execution-board.md).
For a grouped map of every technical doc, use
[docs/technical/documentation-sitemap.md](docs/technical/documentation-sitemap.md).
For phase-by-phase minimum reading, use
[docs/technical/phase-reading-guide.md](docs/technical/phase-reading-guide.md).

## Fastest Control Loop

Use this loop when you need to go from a new request to a concrete output:

```text
START_HERE
  -> docs/technical/README.md Request To Evidence Loop
  -> task type
  -> capability
  -> execution-board row
  -> implementation packet
  -> phase docs
  -> critical gates
  -> evidence
```

## Current Scope

- `apps/clean_disk` is the only Flutter app shell.
- `features/scan` is the first feature package.
- Rust scanner integration is not implemented yet.
- `flutter_rust_bridge` is not installed yet.
- Accepted runtime architecture is one Rust daemon process with an internal
  bounded worker pool, not local microservices.
- Accepted transport architecture is HTTP commands/queries plus plain WebSocket
  events.
- Accepted Rust architecture is three layers:
  reusable `fs_usage_*` library crates, Clean Disk Rust host
  `clean-disk-server`, and Flutter API client code.
- The reusable `fs_usage_*` library is not public-stable yet. It should evolve
  as internal reusable crates until Clean Disk validates the API through real
  product flows.
- Production scanning must use a signed Clean Disk app component or bundled
  helper, not an external `pdu` binary. Permission probes must run in the same
  scanner process that performs the scan.
- pdu risk verification is now P1 input: full `PathBuf` per node is forbidden
  in the read model, metadata enrichment must be lazy, pdu cancellation is
  `cancelling` plus late-result discard, and full-depth scans need resource
  profiles before UI testing.
- Future-proofing gates are recorded in
  `docs/technical/future-proofing-architecture-gates.md`: MVP can be single
  pdu scan, but contracts must preserve opaque `NodeRef`, multi-size
  `SizeFacts`, versioned protocol/snapshots, capability-first UI, operation
  journal, policy objects, remote read-only path, and replaceable scanner
  execution. The same document also fixes operational future gates: UI/daemon
  compatibility, snapshot lifecycle, multi-client sessions, local state
  migrations, installer/update identity, rule-pack safety, hard resource
  budgets, public API discipline, degraded mode, design-system primitives,
  typed scan targets, semantic classification, evidence/confidence, scheduler
  lanes, authority scopes, dependency governance, safe path display, data
  lifecycle, compatibility corpus, export profiles, kill switches, runtime
  modes, typed projections, AI/recommendation authority boundaries, and
  architecture entropy checks. Organizational and ecosystem gates cover incident
  response, trust channel and revocation, OS evolution, data quality tiers, user
  intent preservation, public library governance, benchmark honesty, and privacy
  posture. Automation and multi-environment gates cover read-only automation,
  multi-user machine visibility, syncable versus local-only state, developer and
  virtualized storage providers, reason/evidence taxonomy, self-test diagnostics,
  and trust UX. Assurance and fault-model gates cover explicit operation state
  machines, destructive-flow safety cases, storage topology, deterministic
  evidence capture, cost-aware runtime, retention/forgetting, and fault injection.
  External-boundary and abuse-resistance gates cover local daemon threat model,
  confused deputy protection, schema governance, extension sandbox, metadata-first
  content boundary, release rings, human-readable audit trail, and provider
  honesty contracts. Complexity and evolution gates cover complexity budget,
  progressive disclosure, deprecation/sunset policy, reproducible release trust,
  ethical cleanup UX, documentation decay control, and cross-product reuse
  boundaries.
- Disk usage visual maps use a `DiskUsageMapView` abstraction. Treemap,
  sunburst, icicle, bar, and donut renderers are replaceable adapters over
  bounded Rust map projections; Syncfusion is optional only, not a core
  dependency.
- Flutter frontend state uses feature-scoped MobX stores as presentation-layer
  controllers that orchestrate application use cases. Application may own
  workflow state and state machines as framework-free pure Dart; MobX belongs
  only to presentation. Stores own visible UI state, user intent, bounded query
  caches, and lifecycle subscriptions; widgets remain lean renderers and must
  not own selection, expansion, cleanup queue, scan session, or delete
  authority.
- Tree/table UI uses a design-system `TreeTable` facade. MVP implementation is
  `ListView.builder` with fixed-height visible rows and controlled columns;
  `two_dimensional_scrollables` `TableView`/`TreeView` or custom slivers are
  future adapters behind the same facade. Stop UI polishing after reference
  structure, no overflow, synthetic 50k-row profile smoothness, distinct states,
  and non-rebuilding progress footer are proven.
- Frontend boundaries are explicit: DTOs map inward before presentation,
  commands flow through use cases, WebSocket events invalidate/reconcile rather
  than become truth, design-system primitives do not know product stores, and
  platform actions go through ports/adapters.
- Additional frontend safety boundaries are accepted: target runtime separation,
  daemon session/auth isolation, versioned query cache invalidation,
  virtualized row identity, validated confirmation surfaces, frontend
  scheduling, receipt-backed undo, shell ownership, export/clipboard redaction,
  and privacy-safe design fixtures.
- Second-wave frontend boundaries are accepted: selection/queue/DeletePlan
  separation, bulk action scope, lazy details metadata enrichment, multi-window
  ownership, overlay/menu focus target identity, settings versus safety policy,
  drag/drop validation, notification/toast truth separation, protocol
  compatibility UX, and scroll restoration by stable anchor.
- Third-wave frontend boundaries are accepted: degraded/offline daemon states,
  startup hydration stages, permission repair re-probe, snapshot history and
  compare separation, table column versus query semantics, command registry,
  semantic classification evidence, distinct empty/loading/partial states,
  reduced-motion-safe animation, and monotonic/sequence-based time handling.
- Flutter localization uses official `gen-l10n` in `packages/localization`;
  localization is presentation-only, and domain/application/data/protocol code
  must not import generated localization APIs.

## Architecture Baseline

- Domain stays framework-free.
- Application owns ports and use cases.
- Data/infrastructure owns adapters.
- Presentation owns Flutter UI and view state.
- MobX belongs only to presentation stores and presentation-facing state.
- App shell owns composition, routing, runtime config, and concrete adapter
  choices.
- Rust reusable filesystem logic belongs in `fs_usage_*` crates.
- `clean-disk-server` owns host/runtime/protocol/transport composition.
- Flutter is a client and must not hold the full scan tree.
- `pdu` is an adapter, not product truth.

## Canonical Reading Order

Read the full ordered map in [docs/technical/README.md](docs/technical/README.md).
That index contains:

- Fast Path for recovering context;
- Documentation Operating Manual for request-to-evidence workflow,
  source-of-truth order, task card, update rules, and doc conflict resolution;
- Documentation Tree for visual structure by layer, work area, read mode, and
  gate;
- Documentation Map for source-of-truth routing;
- Documentation Sitemap for the grouped structure of all technical docs;
- Phase Reading Guide for minimum docs, risk add-ons, output, and boundaries by
  phase;
- Task Router for day-to-day task type routing;
- Reading Order Checklist for scenario checklists, gates, output, and stop
  conditions;
- Execution Board for row-by-row deliverables, gates, workstreams, and excluded
  scope from zero to release;
- Phase/Row/Capability Crosswalk for mapping each phase to execution rows,
  capability rows, required docs, and exit gates;
- Implementation Packet Index for concrete work packets from docs baseline to
  release, remote, and support operations;
- Start-To-Finish Guide for the master sequence and one linear route through
  the project;
- Capability Implementation Matrix for capability-to-train, milestone, phase,
  lane, gate, and excluded-scope routing;
- Release Train Map for MVP, beta, release, remote/headless, and support
  slices;
- Dependency Flow from P0 to P8;
- End-To-End Build Roadmap;
- Work Lanes And Ownership;
- Mandatory Reading Bundles;
- Stop Rules;
- Implementation Order by phase;
- Phase Gate Matrix;
- Document Groups by topic;
- Full Document Inventory;
- Where To Look By Task.

Minimum recovery path:

1. [Documentation operating manual](docs/technical/documentation-operating-manual.md)
2. [Documentation tree](docs/technical/documentation-tree.md)
3. [Documentation map](docs/technical/documentation-map.md)
4. [Documentation sitemap](docs/technical/documentation-sitemap.md)
5. [Task router](docs/technical/task-router.md)
6. [Reading order checklist](docs/technical/reading-order-checklist.md)
7. [Execution board](docs/technical/execution-board.md)
8. [Phase reading guide](docs/technical/phase-reading-guide.md)
9. [Start-to-finish guide](docs/technical/start-to-finish-guide.md)
10. [Capability implementation matrix](docs/technical/capability-implementation-matrix.md)
11. [Implementation runbook](docs/technical/implementation-runbook.md)
12. [Release train map](docs/technical/release-train-map.md)
13. [Architecture decisions](docs/technical/architecture-decisions.md)
14. [Future-proofing architecture gates](docs/technical/future-proofing-architecture-gates.md)
15. [Rust architecture](docs/technical/rust-architecture.md)
16. [Architecture fit validation](docs/technical/architecture-fit-validation.md)
17. [Critical zones index](docs/technical/critical-zones/README.md)
18. [Disk usage map view adapter decision](docs/technical/disk-usage-map-view-adapter.md)
19. [Flutter frontend architecture decision](docs/technical/flutter-frontend-architecture-decision.md)
20. [Frontend boundaries decision](docs/technical/frontend-boundaries-decision.md)
21. The phase-specific documents in [docs/technical/README.md](docs/technical/README.md)

## Implementation Order

Use this order unless the task explicitly targets a later phase:

1. Project baseline and constraints.
2. Rust runtime, scanner adapter, and data model.
3. Protocol, daemon runtime, and web UI boundary.
4. Flutter UI, design system, and product workflows.
5. Cleanup safety, DeletePlan, receipts, and reclaim truth.
6. Recommendations, tool-managed storage, and command adapters.
7. Platform permissions, packaging, release, and updates.
8. Remote/headless, diagnostics, and support.
9. Testing, quality gates, and release readiness.

The detailed document list for each phase is in
[docs/technical/README.md](docs/technical/README.md).

## Critical Zones

Global risks are tracked in
[docs/technical/critical-zones/README.md](docs/technical/critical-zones/README.md).

Current focused critical zones:

- [Update, release, rollback, and app identity safety](docs/technical/critical-zones/update-release-rollback-safety.md)
- [Rust runtime execution and worker-pool isolation](docs/technical/critical-zones/rust-runtime-execution.md)
- [Recommendation policy, rule-pack safety, and false-positive control](docs/technical/critical-zones/recommendation-policy-rule-pack-safety.md)
- [Restore, quarantine, undo, and cleanup receipt safety](docs/technical/critical-zones/restore-quarantine-undo-safety.md)
- [Tool command execution sandbox and side-effect control](docs/technical/critical-zones/tool-command-execution-sandbox.md)
- [Remote/headless destructive cleanup authorization](docs/technical/critical-zones/remote-headless-destructive-cleanup-authorization.md)
- [Persistent operation journal and receipt durability under low disk](docs/technical/critical-zones/persistent-operation-journal-receipt-durability-low-disk.md)
- [Support bundle, diagnostics export, and privacy-preserving evidence](docs/technical/critical-zones/support-bundle-diagnostics-export-privacy-evidence.md)

## Design References

Before changing user-facing UI, inspect:

- [Wide desktop reference](docs/design/references/clean-disk-wide-reference.png)
- [Compact narrow reference](docs/design/references/clean-disk-compact-reference.png)

Design target:

- dense productivity tool, not landing page;
- folder tree/table is the central workflow;
- wide layout uses left targets, central tree, right details/delete queue, bottom
  progress;
- compact layout uses top controls, central tree, below-tree details,
  collapsible queue, sticky bottom progress;
- build shared UI through `packages/design_system` over Headless/Material
  primitives.

## Before Coding

- Read the phase-specific docs from [docs/technical/README.md](docs/technical/README.md).
- Check the relevant critical-zone file if the work touches cleanup, runtime,
  transport, remote/headless, update, recommendations, command execution,
  receipts, or diagnostics.
- Keep feature/domain/application layers independent from Flutter, Dio, Drift,
  MobX, GetIt, Modularity, Headless, pdu, generated bridge code, and process
  APIs.
- Keep raw protocol routes, socket parsing, and daemon process details out of
  repositories and UI widgets. Use small product adapters.
