# Documentation Sitemap

Last updated: 2026-06-07.

This file shows the shape of the technical documentation as a map. It is for
orientation, not for implementation details.

Use it when you want to see:

- what document groups exist;
- where a file lives conceptually;
- which files are navigation, decisions, research, edge cases, UX contracts,
  critical gates, or references;
- what to ignore until the active task needs it.

For action routing, use [Task router](task-router.md). For capability routing,
use [Capability implementation matrix](capability-implementation-matrix.md).
For operating the whole documentation set, use
[Documentation operating manual](documentation-operating-manual.md).
For a visual tree of all files by layer and read mode, use
[Documentation tree](documentation-tree.md).
For checkbox-style scenario order, use
[Reading order checklist](reading-order-checklist.md).
For the row-by-row build board, use [Execution board](execution-board.md).
For concrete implementation packets, use
[README Implementation Packet Index](README.md#implementation-packet-index).

## Top-Level Reading Path

```text
START_HERE.md
  -> docs/technical/README.md
  -> docs/technical/documentation-operating-manual.md
  -> docs/technical/documentation-tree.md
  -> docs/technical/task-router.md
  -> docs/technical/capability-implementation-matrix.md
  -> docs/technical/execution-board.md
  -> README Implementation Packet Index
  -> docs/technical/reading-order-checklist.md
  -> docs/technical/phase-reading-guide.md
  -> docs/technical/start-to-finish-guide.md
  -> docs/technical/release-train-map.md
  -> docs/technical/implementation-runbook.md
  -> phase documents
  -> critical-zone gates
```

If you need only one rule:

```text
Task type -> Capability -> Execution row -> Packet -> Phase docs -> Gates
```

## Documentation Layers

```text
L0 context
  START_HERE.md

L1 navigation
  README.md
  documentation-operating-manual.md
  documentation-tree.md
  documentation-map.md
  documentation-sitemap.md
  task-router.md
  reading-order-checklist.md

L2 planning
  execution-board.md
  phase-reading-guide.md
  capability-implementation-matrix.md
  start-to-finish-guide.md
  release-train-map.md
  implementation-runbook.md
  README Implementation Packet Index

L3 accepted architecture
  architecture-decisions.md
  architecture-fit-validation.md
  future-proofing-architecture-gates.md
  rust-architecture.md
  flutter-frontend-architecture-decision.md

L4 implementation domain docs
  scanner, protocol, UI, cleanup, packaging, remote, support, testing docs

L5 critical gates
  critical-zones/*.md

L6 references
  design references, product benchmarks, future adapter notes
```

## Navigation And Execution

These files tell you how to move through the docs.

```text
START_HERE.md
  short context recovery

docs/technical/README.md
  canonical full index

docs/technical/documentation-operating-manual.md
  request-to-evidence workflow, source-of-truth order, task card, update rules

docs/technical/documentation-tree.md
  visual tree of all technical docs by layer, work area, read mode, and gate

docs/technical/documentation-map.md
  source-of-truth and maintenance rules

docs/technical/documentation-sitemap.md
  visual structure of the documentation set

docs/technical/phase-reading-guide.md
  phase-by-phase minimum reading and boundaries

docs/technical/task-router.md
  day-to-day task routing

docs/technical/reading-order-checklist.md
  scenario checklists for reading order, output, gates, and stop conditions

docs/technical/execution-board.md
  row-by-row implementation board from zero to release

docs/technical/start-to-finish-guide.md
  master sequence and one linear path from zero to release

docs/technical/capability-implementation-matrix.md
  capability-to-train/milestone/phase/lane/gate mapping

docs/technical/release-train-map.md
  product slice boundaries

docs/technical/implementation-runbook.md
  milestone execution order
```

## Architecture And Decisions

These files define what is accepted or why the accepted architecture fits.

```text
architecture-principles.md
  SOLID, DDD, Clean Architecture, ports/adapters baseline

architecture-decisions.md
  accepted product and system decisions

architecture-fit-validation.md
  validation of daemon, worker pool, HTTP/WebSocket, protocol choice

architecture-future-risks.md
  future risks and boundaries

future-proofing-architecture-gates.md
  future-shaped contracts, invariants, stop rules, and extension points

flutter-frontend-architecture-decision.md
  Flutter responsibility zones, MobX stores, lifecycle, identity, reactions

frontend-boundaries-decision.md
  frontend DTO, command, authority, design-system, persistence, platform, route boundaries

frontend-i18n-localization-decision.md
  official Flutter gen-l10n, shared localization package, formatting boundary

rust-architecture.md
  Rust crate layout, Clean Architecture boundaries, server responsibilities

rust-best-practices.md
  Rust patterns relevant to this product
```

Open these before changing package/crate boundaries, dependency direction, or
runtime architecture.

## Scanner And Filesystem Engine

These files cover pdu, filesystem modeling, scanner performance, and read-model
truth.

```text
implementation-edge-cases-pdu-adapter-integration.md
  pdu adapter integration risks and option mapping

pdu-adapter-capability-spike.md
  pre-implementation pdu capability findings

pdu-library-deep-validation.md
  local pdu CLI/library validation

pdu-data-model-and-adapter-guide.md
  pdu DataTree/reporter mapping into our read model

pdu-critical-risk-verification.md
  verified pdu risks for memory, cancellation, metadata, hardlinks, identity

pdu-required-capabilities-audit.md
  strict pdu feature audit against Clean Disk needs

implementation-edge-cases-filesystem-model.md
  low-level size, identity, quota, delete, and DTO modeling risks

implementation-edge-cases-performance-scale.md
  scanner, protocol, UI throughput, and scale risks

windows-ntfs-mft-fast-path.md
  future Windows-only fast scanner backend idea
```

Open these before pdu adapter, read-model, indexing, filesystem metadata, or
large scan work.

## Protocol, Runtime, And State Machines

These files describe daemon/API behavior, events, DTOs, concurrency, and local
web runtime.

```text
implementation-edge-cases-protocol-data-contracts.md
  JSON precision, path encoding, timestamps, enum evolution, schema policy

implementation-edge-cases-transport-protocol-streaming.md
  HTTP/WebSocket envelopes, reconnect, ordering, backpressure

transport-client-generation-research.md
  HTTP client, WebSocket, Socket.IO, JSON-RPC, gRPC tradeoffs

implementation-edge-cases-concurrency-state-machines.md
  command idempotency, cancellation, operation state, multi-client behavior

implementation-edge-cases-operational-reliability.md
  daemon lifecycle, crash recovery, overload, persistence, releases

implementation-edge-cases-web-ui-daemon-runtime.md
  daemon-served web UI, loopback policy, CORS/PNA, service worker constraints
```

Open these before API endpoints, WebSocket streams, local daemon behavior,
event replay, reconnect, or web UI runtime work.

## Product UX And Design

These files define the user-facing product workflow and UI behavior.

```text
feature-ux-benchmark.md
  feature-level UX contracts

permission-ux-playbook.md
  permission ladder, scan-quality states, repair flows

cross-platform-user-experience-playbook.md
  install, first-run, scan, cleanup, cloud, diagnostics, remote UX

market-competitive-research.md
  market, competitor, AI assistant, benchmark, and differentiation research

real-product-ux-lessons.md
  lessons from launched storage and cleanup products

launched-product-ux-playbook.md
  product journeys and UX/DTO implications from launched tools

real-product-feature-adoption-playbook.md
  feature-by-feature adoption rules from real products

top-company-product-ux-patterns.md
  state-led UX, health, diagnostics, settings, accessibility

launched-product-cross-platform-workflows.md
  shared workflows and native platform action adapters

launched-product-operational-ux-deep-dive.md
  command registry, trust modes, operation ledger, support UX

flutter-frontend-architecture-decision.md
  Flutter responsibility zones, store taxonomy, Observer and reaction rules

frontend-boundaries-decision.md
  frontend DTO, command, state, platform action, responsive, and route boundaries

frontend-i18n-localization-decision.md
  localization package, supported locales, formatting boundary, stop rules

implementation-edge-cases-flutter-large-tree-ui.md
  virtualization, large-tree state, rendering performance

implementation-edge-cases-ui-accessibility-i18n.md
  accessibility, keyboard UX, localization, bidi-safe paths

implementation-edge-cases-product-workflows.md
  product workflow, protocol correctness, delete plan, export
```

Design references:

```text
docs/design/references/clean-disk-wide-reference.png
docs/design/references/clean-disk-compact-reference.png
```

Open these before user-facing UI, design-system primitives, target picker,
tree/table, details panel, cleanup queue UI, or accessibility work.

## Cleanup, Persistence, And Accounting

These files cover destructive safety, receipts, local persistence, identity, and
reclaim truth.

```text
implementation-edge-cases-cleanup-delete-safety.md
  DeletePlan, Trash adapters, partial outcomes, receipts, restore expectations

implementation-edge-cases-platform-identity-delete-revalidation.md
  file identity, stale candidate validation, delete preflight

implementation-edge-cases-local-state-persistence.md
  Drift/SQLite, journals, receipts, migrations, corruption recovery

implementation-edge-cases-storage-accounting-snapshots-shared-extents.md
  APFS snapshots/clones, VSS, Btrfs/ZFS, dedupe, sparse/compressed files

reclaim-accounting-deep-research.md
  reclaim confidence, evidence model, platform API feasibility
```

Open these before cleanup preview, Trash/delete, receipts, reclaim estimates,
journals, low-disk handling, or crash recovery.

## Recommendations And Tool Cleanup

These files cover cleanup intelligence and controlled command execution.

```text
implementation-edge-cases-recommendation-rule-engine.md
  recommendation rules, evidence, risk tiers, explainability

implementation-edge-cases-tool-managed-storage.md
  Docker, Xcode, package managers, developer cache cleanup

critical-zones/recommendation-policy-rule-pack-safety.md
  false-positive control and rule-pack gates

critical-zones/tool-command-execution-sandbox.md
  safe official command execution and side-effect control
```

Open these only after DeletePlan and receipts are safe enough. Recommendations
must feed preview and DeletePlan; they must not directly delete.

## Platform, Security, Release, And Governance

These files cover packaging, signing, updates, dependency trust, and security.

```text
implementation-edge-cases-platform-permissions-packaging.md
  macOS/Windows/Linux permissions, signing, installers, helpers, updates

implementation-edge-cases-dependency-supply-chain-governance.md
  dependency trust, licenses, SBOM, provenance, vulnerability gates

implementation-edge-cases-security-privacy.md
  threat model, daemon hardening, tokens, remote mode, supply chain

critical-zones/update-release-rollback-safety.md
  update trust, quiesce gates, compatibility, rollback
```

Open these before signed desktop builds, permission UX, installers, updater,
dependency changes, release artifacts, or security-sensitive transport changes.

## Remote, Headless, Diagnostics, And Support

These files cover non-local usage and support workflows.

```text
implementation-edge-cases-remote-headless-mode.md
  headless/server mode, auth/authZ, containers, quotas, audit

implementation-edge-cases-diagnostics-observability-support.md
  logs, metrics, crash reports, support bundles, redaction

critical-zones/remote-headless-destructive-cleanup-authorization.md
  remote destructive authority, target scopes, audit, quota, policy

critical-zones/support-bundle-diagnostics-export-privacy-evidence.md
  typed, redacted, bounded, consented support evidence
```

Remote/headless read-only and remote cleanup are different products. Do not
inherit local cleanup trust for remote cleanup.

## Querying, Watchers, Cloud, And Advanced Scenarios

These files are cross-cutting. Open them only when the active task touches the
area.

```text
implementation-edge-cases-search-query-indexing.md
  search, sort, filter, top lists, indexing, stale results

implementation-edge-cases-incremental-scan-watchers.md
  watchers, cache invalidation, stale snapshots, subtree refresh

implementation-edge-cases-cloud-network-virtual-filesystems.md
  cloud placeholders, network shares, NAS, FUSE, removable volumes

implementation-edge-cases-resource-governance.md
  scan modes, CPU/IO budgets, priority, battery, thermal behavior

implementation-edge-cases-advanced-scenarios.md
  advanced storage, recommendations, installer, enterprise cases

implementation-edge-cases.md
  first-pass implementation edge-case index

implementation-edge-cases-deep-dive.md
  deeper platform, cloud, daemon security, watcher, UI risks
```

Do not read all of these for ordinary scan-only work. Use them when the task
touches the specific subsystem.

## Testing And Critical Research

These files shape release gates, spikes, and broad risk analysis.

```text
implementation-edge-cases-testing-quality-gates.md
  testing strategy, CI gates, benchmarks, destructive safety

pre-implementation-critical-spikes.md
  ordered spike plan before scanner, protocol, cleanup, UI

preimplementation-critical-research-sequence.md
  broader ordered research before implementation

preimplementation-critical-zones-deep-dive.md
  broad hidden failure modes and release blockers

critical-zones/README.md
  focused global risk gates and ranking
```

Open these before release readiness, destructive safety proof, benchmark design,
or when a broad risk appears to cross multiple phases.

## Critical Zones

Critical zones are global gates. They can block any phase.

```text
critical-zones/README.md
  index and ranking

critical-zones/rust-runtime-execution.md
  Tokio/blocking boundary, worker lanes, cancellation, shutdown

critical-zones/update-release-rollback-safety.md
  update trust, app identity, rollback

critical-zones/persistent-operation-journal-receipt-durability-low-disk.md
  durable cleanup truth under low disk and crash recovery

critical-zones/restore-quarantine-undo-safety.md
  restore capabilities, receipts, platform Trash semantics

critical-zones/recommendation-policy-rule-pack-safety.md
  evidence-backed recommendations and rule-pack gates

critical-zones/tool-command-execution-sandbox.md
  safe official command execution

critical-zones/remote-headless-destructive-cleanup-authorization.md
  remote authority, target scopes, audit, quota, policy

critical-zones/support-bundle-diagnostics-export-privacy-evidence.md
  typed, redacted, bounded, consented support evidence
```

Use critical zones as release gates, not background reading.

## What Not To Read Yet

| Current work | Usually skip for now |
| --- | --- |
| scan-only MVP | cleanup execution, recommendations, remote cleanup, support export |
| pdu adapter | UX playbooks, recommendation docs, remote/headless docs |
| Flutter scan UI | storage accounting, command sandbox, update rollback |
| cleanup preview | recommendation rules, official command adapters, remote cleanup |
| local cleanup beta | remote cleanup, hosted web pairing, enterprise scenarios |
| signed scan-only build | recommendation docs, remote cleanup authority |
| remote read-only | local Trash execution details beyond read-only safety constraints |

If a skipped area becomes necessary, route it through
[Task router](task-router.md) or
[Capability implementation matrix](capability-implementation-matrix.md) first.
