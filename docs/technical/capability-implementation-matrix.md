# Capability Implementation Matrix

Last updated: 2026-05-16.

This file maps product capabilities to release trains, implementation
milestones, documentation phases, owner lanes, gates, and excluded scope.

Use it after choosing a product direction and before planning a concrete PR.

This file does not replace:

- [README](README.md) - full documentation index;
- [Documentation sitemap](documentation-sitemap.md) - grouped structure of all
  technical docs;
- [Phase reading guide](phase-reading-guide.md) - phase-by-phase minimum
  reading and boundaries;
- [Task router](task-router.md) - day-to-day task routing;
- [Reading order checklist](reading-order-checklist.md) - scenario checklists
  for reading order, output, gates, and stop conditions;
- [Execution board](execution-board.md) - row-by-row build order with
  deliverables, gates, workstreams, and excluded scope;
- [Start-to-finish guide](start-to-finish-guide.md) - one linear route;
- [Release train map](release-train-map.md) - product slice boundaries;
- [Implementation runbook](implementation-runbook.md) - milestone execution.

It is the shortest way to answer:

```text
I want to build capability X.
What do I read?
Which layer owns it?
What can block it?
What must stay out of scope?
```

## Capability Matrix

| Capability | Train | Milestone | Phase | Owner lane | Read first | Gate | Excluded scope |
| --- | --- | --- | --- | --- | --- | --- | --- |
| project recovery | T0 | M0 | P0 | documentation | [Start Here](../../START_HERE.md), [Documentation map](documentation-map.md), [Start-to-finish guide](start-to-finish-guide.md) | accepted decisions are indexed | product code |
| architecture baseline | T0 | M0 | P0 | architecture | [Architecture decisions](architecture-decisions.md), [Rust architecture](rust-architecture.md), [Architecture fit validation](architecture-fit-validation.md), [Future-proofing architecture gates](future-proofing-architecture-gates.md) | dependency direction is enforceable | adapters in domain/application |
| Rust crate skeleton | T1 | M1 | P1 | reusable Rust engine | [Rust architecture](rust-architecture.md), [Rust best practices research](rust-best-practices.md) | domain/application are framework-free | pdu, HTTP, Flutter, SQLite in core |
| pdu adapter | T1 | M2 | P1 | scanner adapter | [pdu data model and adapter guide](pdu-data-model-and-adapter-guide.md), [pdu critical risk verification](pdu-critical-risk-verification.md) | only adapter imports pdu | CLI wrapper as production path |
| scan read model | T1 | M2 | P1 | reusable Rust engine | [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md), [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md) | bounded arena and paginated queries | full tree in Flutter |
| search/sort/filter | T1 | M2-M3 | P1-P2 | reusable Rust engine | [Implementation edge cases search query indexing](implementation-edge-cases-search-query-indexing.md), [Protocol data contracts](implementation-edge-cases-protocol-data-contracts.md) | stable cursors and typed stale-result errors | UI-side full-tree filtering |
| scan protocol | T1 | M3 | P2 | server/runtime | [Transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md), [Protocol data contracts](implementation-edge-cases-protocol-data-contracts.md) | sequence, reconnect, backpressure | raw socket parsing in widgets |
| daemon-served local web UI | T1 | M3 | P2 | server/runtime | [Web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md) | loopback token, origin policy, service worker policy | hosted website connecting to localhost |
| Flutter scan shell | T1 | M4 | P3 | Flutter app | [Feature UX benchmark](feature-ux-benchmark.md), [Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md) | UI uses Rust pagination and stable IDs | cleanup truth from visible rows |
| design-system primitives | T1 | M4 | P3 | design system | [Feature UX benchmark](feature-ux-benchmark.md), [UI accessibility and i18n](implementation-edge-cases-ui-accessibility-i18n.md) | Headless gaps are reported | feature business logic in components |
| scan permissions UX | T1-T4 | M4-M7 | P3-P6 | Flutter app, distribution/security | [Permission UX playbook](permission-ux-playbook.md), [Platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md) | probe identity equals scanner identity | external scanner binary in production |
| scan-only packaging | T4 partial | M7 | P6 | distribution/security | [Platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md), [Update rollback safety](critical-zones/update-release-rollback-safety.md) | signed identity and update constraints | cleanup release without receipts |
| cleanup preview | T2 | M5 | P4 | cleanup safety | [Cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md), [Platform identity delete revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md) | stale identity blocks action | destructive adapter call |
| reclaim estimate | T2 | M5 | P4 | cleanup safety | [Reclaim accounting research](reclaim-accounting-deep-research.md), [Storage accounting snapshots shared extents](implementation-edge-cases-storage-accounting-snapshots-shared-extents.md) | confidence and evidence are shown | exact freed-byte promise without proof |
| Trash execution | T2 | M5 | P4 | cleanup safety | [Receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md), [Restore quarantine undo safety](critical-zones/restore-quarantine-undo-safety.md) | durable intent before side effect | path-string deletion |
| receipt and operation journal | T2 | M5 | P4 | cleanup safety, server/runtime | [Local state persistence](implementation-edge-cases-local-state-persistence.md), [Receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md) | crash states are recoverable | batch-only receipt finalization |
| recommendation cards | T3 | M6 | P5 | recommendations | [Recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md), [Rule-pack safety](critical-zones/recommendation-policy-rule-pack-safety.md) | evidence and risk tier required | bypassing DeletePlan |
| official cleanup commands | T3 | M6 | P5 | recommendations, cleanup safety | [Tool-managed storage](implementation-edge-cases-tool-managed-storage.md), [Tool command sandbox](critical-zones/tool-command-execution-sandbox.md) | argv/env/cwd/output/timeout governed | PATH lookup or shell snippets |
| signed desktop release | T4 | M7-M9 | P6-P8 | distribution/security | [Platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md), [Testing quality gates](implementation-edge-cases-testing-quality-gates.md) | signing, dependencies, rollback, tests | updater during active cleanup |
| dependency governance | T4-T7 | M7-M9 | P6-P8 | distribution/security | [Dependency supply-chain governance](implementation-edge-cases-dependency-supply-chain-governance.md) | license, vulnerability, provenance gates | unreviewed build scripts or macros |
| remote/headless read-only | T5 | M8 | P7 | server/runtime, distribution/security | [Remote and headless mode](implementation-edge-cases-remote-headless-mode.md), [Security privacy](implementation-edge-cases-security-privacy.md) | scoped read-only authZ | remote cleanup |
| remote cleanup | T6 | separate review | P4-P7 | cleanup safety, distribution/security | [Remote destructive authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md), [Cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md) | object auth, target scope, audit, quota | inheriting local cleanup auth |
| diagnostics and support bundle | T7 | M8-M9 | P7-P8 | support/release | [Diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md), [Support bundle privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md) | typed redacted bounded export | raw log/database zip |
| release readiness | T4-T7 | M9 | P8 | support/release | [Testing quality gates](implementation-edge-cases-testing-quality-gates.md), [Critical zones index](critical-zones/README.md) | risky features map to evidence | happy-path-only tests |

## Dependency Chains

### Scan Visualization Chain

```text
Rust crate skeleton
  -> pdu adapter
  -> compact read model
  -> indexes and pagination
  -> protocol DTOs
  -> HTTP queries and WebSocket events
  -> Flutter scan UI
  -> scan-only packaging spike
```

Do not start cleanup execution until this chain is usable and measured.

### Cleanup Chain

```text
scan node identity
  -> DeletePlan preview
  -> identity revalidation dry-run
  -> reclaim confidence model
  -> durable journal intent
  -> receipt skeleton
  -> Trash adapter
  -> per-item outcome
  -> crash recovery
  -> receipt view
```

Do not add recommendations or command adapters before this chain is safe.

### Recommendation Chain

```text
DeletePlan and receipts
  -> evidence model
  -> risk tiers
  -> rule-pack versioning
  -> stale recommendation invalidation
  -> official tool adapters
  -> command sandbox
```

Recommendations must feed preview and DeletePlan. They must not directly delete.

### Remote Chain

```text
scan protocol
  -> read-only remote profile
  -> target scopes
  -> object-level authZ
  -> audit events
  -> quotas
  -> support diagnostics
  -> separate remote cleanup authority review
```

Remote cleanup is not part of remote read-only. Treat it as a separate product.

### Release Chain

```text
signed identity
  -> permission probe parity
  -> dependency governance
  -> update quiesce
  -> rollback compatibility
  -> low-disk and crash tests
  -> destructive safety tests
  -> support evidence
```

Release is blocked if any enabled risky capability lacks evidence.

## Layer Ownership By Capability

| Lane | Allowed to decide | Must delegate |
| --- | --- | --- |
| reusable Rust engine | scan sessions, read-model shape, node IDs, filesystem ports | transport routes, Flutter state, product copy |
| scanner adapter | pdu option mapping, DataTree conversion, progress mapping | cleanup policy, recommendation safety |
| server/runtime | daemon lifecycle, HTTP/WebSocket, auth token, event buffers, persistence adapters | domain invariants, widget behavior |
| Flutter app | routes, view state, target picker, scan tree UI, cleanup queue UI | scanner truth, delete execution truth |
| design system | shared visual primitives, theme, accessibility primitives | feature state machines, protocol parsing |
| cleanup safety | DeletePlan, identity revalidation, receipts, reclaim confidence | raw command execution without sandbox |
| recommendations | evidence, rules, risk tiers, explanations | bypassing DeletePlan or receipts |
| distribution/security | signing, installers, permissions, updates, dependency gates | runtime shortcuts that change safety semantics |
| support/release | diagnostics, support bundles, release evidence | raw private data export by default |

## How To Use This Matrix For A PR

1. Pick the capability row.
2. Confirm the active train includes it.
3. Open the listed docs.
4. Confirm the owner lane.
5. Write down the gate in the PR/task plan.
6. Write down the excluded scope.
7. Implement only the row and its direct prerequisites.
8. Add tests or manual evidence for the gate.

If one row depends on another row that is not built yet, build the dependency
first or create a narrow stub that cannot perform risky side effects.

## Quick Risk Class

| Capability type | Risk level | Required discipline |
| --- | --- | --- |
| read-only UI | medium | pagination, state correctness, privacy in logs |
| local scan | medium-high | permission identity, resource budgets, skipped states |
| local cleanup | high | DeletePlan, identity revalidation, journal, receipts |
| command execution | high | sandbox, dry-run parity, output limits, receipts |
| signed release | high | signing, updates, rollback, dependency governance |
| remote read-only | high | scopes, authZ, audit, privacy |
| remote cleanup | critical | separate authority model, quotas, audit, kill switch |
| support export | high | data classes, redaction, consent, bounded output |

## Common Wrong Turns

- building Flutter tree state before read-model pagination is defined;
- treating pdu output as final product truth;
- implementing cleanup before durable receipt semantics;
- adding recommendations before DeletePlan safety;
- using local loopback token as remote auth;
- shipping scan-only without thinking about scanner process identity;
- adding service worker offline behavior before daemon/UI version compatibility;
- adding support bundle as raw logs plus database dump.
