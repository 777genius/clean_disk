# Documentation Tree

Last updated: 2026-05-16.

This is the visual tree of Clean Disk technical documentation. Use it when the
file list feels too flat and you need to see the structure from start to finish.

This file is navigation only. It does not create architecture decisions.

## Read Mode Legend

```text
ALWAYS - read during context recovery or planning
PACKET - read when the active implementation packet needs it
RISK - read when the task touches the listed risk area
REFERENCE - read for background, benchmark, or future adapter context
GATE - can block implementation or release
```

## Start Here

```text
START_HERE.md                                      ALWAYS
  short recovery context and current accepted baseline

docs/technical/README.md                          ALWAYS
  canonical full technical index

docs/technical/documentation-operating-manual.md  ALWAYS
  how to move from request to evidence

docs/technical/start-to-finish-guide.md           ALWAYS
  master sequence from zero context to release gates
```

## Navigation Layer

```text
docs/technical/
  documentation-map.md                            ALWAYS
    source-of-truth and maintenance rules

  documentation-tree.md                           ALWAYS
    this visual tree of all technical docs

  documentation-sitemap.md                        ALWAYS
    grouped conceptual map

  task-router.md                                  ALWAYS
    route by task type

  reading-order-checklist.md                      ALWAYS
    scenario checklists

  execution-board.md                              ALWAYS
    row-by-row build board

  phase-reading-guide.md                          ALWAYS
    phase reading bundles and boundaries

  capability-implementation-matrix.md             ALWAYS
    capability to train/milestone/phase/lane/gate

  release-train-map.md                            ALWAYS
    product slice boundaries

  implementation-runbook.md                       ALWAYS
    milestone execution order
```

## Architecture Layer

```text
docs/technical/
  architecture-decisions.md                       ALWAYS
    accepted product and system decisions

  architecture-fit-validation.md                  ALWAYS
    why accepted architecture fits the product

  architecture-future-risks.md                    PACKET
    future risks around cleanup authority, daemon lifecycle, reuse

  architecture-principles.md                      REFERENCE
    SOLID, DDD, Clean Architecture, ports/adapters baseline

  future-proofing-architecture-gates.md           GATE
    future-shaped contracts and stop rules MVP must preserve

  rust-architecture.md                            ALWAYS
    Rust crates, layers, server responsibilities

  rust-best-practices.md                          PACKET
    Rust patterns relevant to this project

  flutter-frontend-architecture-decision.md       PACKET
    Flutter responsibility zones and MobX store rules

  frontend-boundaries-decision.md                 PACKET
    DTO, command, event, design-system, route, platform boundaries

  frontend-i18n-localization-decision.md          PACKET
    Flutter gen-l10n, shared localization package, formatting boundary

  disk-usage-map-view-adapter.md                  PACKET
    DiskUsageMapView and renderer adapter boundary
```

## P1 Scanner And Filesystem Engine

```text
docs/technical/
  pdu-data-model-and-adapter-guide.md             PACKET PK2
    how pdu maps into our read model

  pdu-required-capabilities-audit.md              PACKET PK2
    strict pdu capability audit

  pdu-critical-risk-verification.md               PACKET PK2
    verified pdu risks and adapter consequences

  pdu-library-deep-validation.md                  PACKET PK2
    local CLI/library validation and implications

  pdu-adapter-capability-spike.md                 PACKET PK2
    pre-implementation pdu findings

  implementation-edge-cases-pdu-adapter-integration.md
                                                        PACKET PK2
    option mapping, cancellation, hardlinks, fork strategy

  implementation-edge-cases-filesystem-model.md   PACKET PK3 / RISK
    size, identity, quota, delete, DTO modeling risks

  implementation-edge-cases-performance-scale.md  PACKET PK3 / RISK
    scanner, protocol, UI throughput and scale

  windows-ntfs-mft-fast-path.md                   REFERENCE
    future Windows NTFS fast scanner backend
```

## P2 Protocol, Runtime, And State Machines

```text
docs/technical/
  implementation-edge-cases-protocol-data-contracts.md
                                                        PACKET PK5
    DTOs, JSON precision, path encoding, schema/versioning

  implementation-edge-cases-transport-protocol-streaming.md
                                                        PACKET PK5
    HTTP/WebSocket envelopes, ordering, reconnect, backpressure

  transport-client-generation-research.md         PACKET PK5 / REFERENCE
    HTTP client, WebSocket, Socket.IO, JSON-RPC, gRPC tradeoffs

  implementation-edge-cases-concurrency-state-machines.md
                                                        PACKET PK5 / RISK
    idempotency, cancellation, operation state, multi-client behavior

  implementation-edge-cases-web-ui-daemon-runtime.md
                                                        PACKET PK5 / RISK
    daemon-served web, loopback policy, CORS/PNA, service workers

  implementation-edge-cases-operational-reliability.md
                                                        RISK
    daemon lifecycle, crash recovery, overload, persistence, releases
```

## P3 Product UX, Flutter UI, And Frontend Boundaries

```text
docs/technical/
  feature-ux-benchmark.md                         PACKET PK6
    feature-level UX contracts

  flutter-frontend-architecture-decision.md       PACKET PK6
    presentation stores, lifecycle, identity, reactions

  frontend-boundaries-decision.md                 PACKET PK6
    frontend boundary rules and authority flow

  frontend-i18n-localization-decision.md          PACKET PK6
    localization package and display formatting boundary

  implementation-edge-cases-flutter-large-tree-ui.md
                                                        PACKET PK6
    virtualization, large-tree state, rendering performance

  implementation-edge-cases-ui-accessibility-i18n.md
                                                        RISK
    accessibility, keyboard UX, localization, bidi-safe paths

  implementation-edge-cases-product-workflows.md  RISK
    product workflow, protocol correctness, delete plan, export

  permission-ux-playbook.md                       PACKET PK6 / PK7
    permission ladder, scan-quality states, repair flows

  cross-platform-user-experience-playbook.md      PACKET PK6 / REFERENCE
    install, first-run, scan, cleanup, cloud, diagnostics, remote UX

  real-product-ux-lessons.md                      REFERENCE
    lessons from launched storage and cleanup products

  launched-product-ux-playbook.md                 REFERENCE
    product journeys and UX/DTO implications

  real-product-feature-adoption-playbook.md       REFERENCE
    feature-by-feature adoption rules

  top-company-product-ux-patterns.md              REFERENCE
    state-led UX, health, diagnostics, settings, accessibility

  launched-product-cross-platform-workflows.md    REFERENCE
    shared workflows and native platform actions

  launched-product-operational-ux-deep-dive.md    REFERENCE
    command registry, trust modes, operation ledger, support UX

docs/design/references/
  clean-disk-wide-reference.png                   REFERENCE
  clean-disk-compact-reference.png                REFERENCE
```

## P4 Cleanup, Persistence, And Accounting

```text
docs/technical/
  implementation-edge-cases-cleanup-delete-safety.md
                                                        PACKET PK8 / PK9
    DeletePlan, Trash adapters, partial outcomes, receipts

  implementation-edge-cases-platform-identity-delete-revalidation.md
                                                        PACKET PK8 / PK9
    file identity, stale candidate validation, delete preflight

  reclaim-accounting-deep-research.md             PACKET PK8
    reclaim confidence and evidence model

  implementation-edge-cases-storage-accounting-snapshots-shared-extents.md
                                                        RISK
    APFS, VSS, Btrfs/ZFS, dedupe, sparse/compressed, quotas

  implementation-edge-cases-local-state-persistence.md
                                                        PACKET PK9 / RISK
    Drift/SQLite, journals, receipts, migrations, corruption recovery
```

## P5 Recommendations And Tool-Managed Storage

```text
docs/technical/
  implementation-edge-cases-recommendation-rule-engine.md
                                                        PACKET PK10
    recommendation rules, evidence, risk tiers, explainability

  implementation-edge-cases-tool-managed-storage.md
                                                        PACKET PK10
    Docker, Xcode, package managers, developer cache cleanup
```

## P6-P8 Packaging, Release, Remote, Support, Quality

```text
docs/technical/
  implementation-edge-cases-platform-permissions-packaging.md
                                                        PACKET PK7 / PK11
    platform permissions, signing, installers, updates

  implementation-edge-cases-dependency-supply-chain-governance.md
                                                        PACKET PK11 / GATE
    dependency trust, licenses, SBOM, provenance, vulnerability gates

  implementation-edge-cases-security-privacy.md   PACKET PK12 / RISK
    threat model, daemon hardening, tokens, remote mode, supply chain

  implementation-edge-cases-remote-headless-mode.md
                                                        PACKET PK12
    headless/server mode, auth/authZ, containers, quotas, audit

  implementation-edge-cases-diagnostics-observability-support.md
                                                        PACKET PK13
    logs, metrics, crash reports, support bundles, redaction

  implementation-edge-cases-resource-governance.md
                                                        RISK
    scan modes, CPU/IO budgets, priority, battery, thermal behavior

  implementation-edge-cases-search-query-indexing.md
                                                        PACKET PK3 / RISK
    search, sort, filter, top lists, indexing, stale results

  implementation-edge-cases-incremental-scan-watchers.md
                                                        REFERENCE / RISK
    watchers, cache invalidation, stale snapshots, subtree refresh

  implementation-edge-cases-cloud-network-virtual-filesystems.md
                                                        RISK
    cloud placeholders, network shares, NAS, FUSE, removable volumes

  implementation-edge-cases-advanced-scenarios.md REFERENCE / RISK
    advanced storage, recommendations, installer, enterprise cases

  implementation-edge-cases-testing-quality-gates.md
                                                        PACKET PK11 / GATE
    testing strategy, CI gates, benchmarks, destructive safety

  implementation-edge-cases.md                    REFERENCE
    first-pass implementation edge-case index

  implementation-edge-cases-deep-dive.md          REFERENCE / RISK
    deeper platform, cloud, daemon security, watcher, UI risks

  pre-implementation-critical-spikes.md           REFERENCE / GATE
    ordered spike plan before major implementation

  preimplementation-critical-research-sequence.md REFERENCE
    broader ordered research decisions before implementation

  preimplementation-critical-zones-deep-dive.md   GATE
    broad hidden failure modes and release blockers
```

## Critical Gates

```text
docs/technical/critical-zones/
  README.md                                       GATE
    focused global risk gates and ranking

  rust-runtime-execution.md                       GATE PK1 / PK4
    Tokio/blocking boundary, worker lanes, cancellation, shutdown

  persistent-operation-journal-receipt-durability-low-disk.md
                                                        GATE PK9
    durable cleanup truth under low disk and crash recovery

  restore-quarantine-undo-safety.md              GATE PK9
    restore capabilities, receipts, platform Trash semantics

  recommendation-policy-rule-pack-safety.md      GATE PK10
    evidence-backed recommendations and rule-pack gates

  tool-command-execution-sandbox.md              GATE PK10
    official command execution and side-effect control

  update-release-rollback-safety.md              GATE PK7 / PK11
    update trust, quiesce gates, compatibility, rollback

  remote-headless-destructive-cleanup-authorization.md
                                                        GATE PK12
    remote authority, target scopes, audit, quota, policy

  support-bundle-diagnostics-export-privacy-evidence.md
                                                        GATE PK13
    typed, redacted, bounded, consented support evidence
```

## Open Order By Need

| Need | Open |
| --- | --- |
| no context | [START_HERE](../../START_HERE.md), [README](README.md), [Documentation operating manual](documentation-operating-manual.md) |
| linear implementation | [Start-to-finish guide](start-to-finish-guide.md), then [Execution board](execution-board.md) |
| visual structure | this file, then [Documentation sitemap](documentation-sitemap.md) |
| exact task routing | [Task router](task-router.md), then [Capability implementation matrix](capability-implementation-matrix.md) |
| phase work | [Phase reading guide](phase-reading-guide.md), then phase docs |
| safety-sensitive work | [Critical zones index](critical-zones/README.md), then matching gate |
| new or changed docs | [Documentation operating manual](documentation-operating-manual.md), then [Documentation map](documentation-map.md) |

