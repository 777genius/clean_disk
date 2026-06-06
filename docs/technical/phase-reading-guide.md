# Phase Reading Guide

Last updated: 2026-05-16.

This file is the phase-by-phase reading guide for Clean Disk. It gives the
minimum reading set, optional risk add-ons, expected output, and "do not pull
forward" boundaries for each phase.

Use it when you know the project phase but do not want to read the full
[README](README.md), the full [Documentation sitemap](documentation-sitemap.md),
or every edge-case document.

For task type routing, use [Task router](task-router.md). For capability
routing, use [Capability implementation matrix](capability-implementation-matrix.md).
For checkbox-style scenario order, use
[Reading order checklist](reading-order-checklist.md).
For the row-by-row build board, use [Execution board](execution-board.md).

## Phase Flow

```text
P0 baseline
  -> P1 scanner engine and read model
  -> P2 daemon protocol and runtime
  -> P3 Flutter UI and product workflows
  -> P4 cleanup safety and reclaim truth
  -> P5 recommendations and tool adapters
  -> P6 packaging, permissions, updates
  -> P7 remote/headless, diagnostics, support
  -> P8 testing, quality gates, release readiness
```

Critical zones can block any phase.

## How To Use This Guide

1. Find the current phase.
2. Read the minimum set.
3. Add risk documents only if the task touches that risk.
4. Confirm expected output.
5. Respect "do not pull forward".
6. Move to the next phase only when the exit gate is true.

## P0 - Baseline And Constraints

Goal:

- understand product scope, accepted architecture, documentation structure, and
  dependency direction before coding.

Minimum read:

- [START_HERE](../../START_HERE.md)
- [Documentation map](documentation-map.md)
- [Documentation sitemap](documentation-sitemap.md)
- [Task router](task-router.md)
- [Reading order checklist](reading-order-checklist.md)
- [Execution board](execution-board.md)
- [Start-to-finish guide](start-to-finish-guide.md)
- [Release train map](release-train-map.md)
- [Architecture decisions](architecture-decisions.md)
- [Rust architecture](rust-architecture.md)

Risk add-ons:

- [Architecture fit validation](architecture-fit-validation.md) if changing
  daemon, worker pool, transport, or layering.
- [Architecture future risks](architecture-future-risks.md) if expanding scope.
- [Architecture principles](architecture-principles.md) if changing Clean
  Architecture, DDD, SOLID, or ports/adapters rules.

Expected output:

- task has train, milestone, phase, lane, gate, and excluded scope;
- no implementation starts from chat memory only;
- feature packages and Rust crates follow accepted boundaries.

Do not pull forward:

- FRB, gRPC, Socket.IO, microservices, hosted localhost pairing, or remote
  cleanup unless the architecture decision is reopened.

Exit gate:

- documentation entry points agree on current scope and architecture.

## P1 - Rust Scanner Engine And Read Model

Goal:

- build reusable scanner/read-model foundation without coupling to Clean Disk UI
  or protocol.

Minimum read:

- [Rust architecture](rust-architecture.md)
- [Rust best practices](rust-best-practices.md)
- [Future-proofing architecture gates](future-proofing-architecture-gates.md)
- [pdu data model and adapter guide](pdu-data-model-and-adapter-guide.md)
- [pdu critical risk verification](pdu-critical-risk-verification.md)
- [pdu required capabilities audit](pdu-required-capabilities-audit.md)
- [Implementation edge cases pdu adapter integration](implementation-edge-cases-pdu-adapter-integration.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Critical zone Rust runtime execution](critical-zones/rust-runtime-execution.md)

Risk add-ons:

- [Windows NTFS MFT fast path](windows-ntfs-mft-fast-path.md) only for future
  Windows scanner optimization.
- [Implementation edge cases resource governance](implementation-edge-cases-resource-governance.md)
  if touching CPU/IO/battery profiles.
- [Implementation edge cases cloud network virtual filesystems](implementation-edge-cases-cloud-network-virtual-filesystems.md)
  if scanning cloud, network, FUSE, or removable targets.

Expected output:

- pdu adapter is isolated;
- Rust owns tree, indexes, sorting, filtering, pagination;
- full `PathBuf` is not stored per node in the main read model;
- skipped, permission, hardlink, symlink, mount, and changing-file states are
  first-class issues.

Do not pull forward:

- Flutter DTOs, HTTP routes, cleanup policy, recommendation policy, or UI state
  into reusable scanner crates.

Exit gate:

- scan result can be queried by pages without cloning or sending the full tree.

## P2 - Daemon Protocol And Runtime

Goal:

- expose scan sessions and read-model queries safely through HTTP commands,
  HTTP queries, and plain WebSocket events.

Minimum read:

- [Implementation edge cases protocol data contracts](implementation-edge-cases-protocol-data-contracts.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Transport and client generation research](transport-client-generation-research.md)
- [Implementation edge cases concurrency state machines](implementation-edge-cases-concurrency-state-machines.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Implementation edge cases web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md)

Risk add-ons:

- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
  if routes expose private data, tokens, or remote access.
- [Critical zone remote/headless destructive cleanup authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md)
  if any endpoint can affect cleanup or remote authority.
- [Critical zone support bundle diagnostics export privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md)
  if events/logs can enter diagnostics or support export.

Expected output:

- protocol DTOs are separate from domain and Flutter view state;
- session lifecycle is explicit;
- event envelopes have sequence, kind, session, and version;
- reconnect, stale cursor, dropped event, and resync behavior are typed.

Do not pull forward:

- generated bridge code, raw route parsing in widgets, Socket.IO/gRPC/JSON-RPC
  without reopening transport decisions.

Exit gate:

- UI can recover from event gaps without stale or unauthorized state.

## P3 - Flutter UI And Product Workflows

Goal:

- build the scan product surface around paginated Rust data and saved design
  references.

Minimum read:

- [Feature UX benchmark](feature-ux-benchmark.md)
- [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md)
- [Permission UX playbook](permission-ux-playbook.md)
- [Cross-platform user experience playbook](cross-platform-user-experience-playbook.md)
- [Real product feature adoption playbook](real-product-feature-adoption-playbook.md)
- [Wide desktop reference](../design/references/clean-disk-wide-reference.png)
- [Compact narrow reference](../design/references/clean-disk-compact-reference.png)

Risk add-ons:

- [Implementation edge cases UI accessibility and i18n](implementation-edge-cases-ui-accessibility-i18n.md)
  for keyboard, screen reader, localization, bidi paths, or text scaling.
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
  for delete queue, export, multi-client, or cross-view workflow state.
- [Launched product operational UX deep dive](launched-product-operational-ux-deep-dive.md)
  for command registry, trust modes, operation ledger, or support UX.

Expected output:

- tree/table is central workflow;
- UI uses paginated Rust queries;
- selected row, details, and expanded state use stable node IDs;
- compact and wide layouts follow references;
- Headless gaps are reported instead of hidden with awkward workarounds.

Do not pull forward:

- cleanup execution, recommendation rules, command adapters, full scan tree in
  Flutter, or UI-derived cleanup truth.

Exit gate:

- scan-only UI can show progress, tree/table, search/filter/sort, details, and
  scan-quality states without owning scanner truth.

## P4 - Cleanup Safety, Receipts, And Reclaim Truth

Goal:

- make cleanup a safe domain workflow, not path deletion from UI state.

Minimum read:

- [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md)
- [Implementation edge cases platform identity and delete revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md)
- [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md)
- [Implementation edge cases storage accounting snapshots shared extents](implementation-edge-cases-storage-accounting-snapshots-shared-extents.md)
- [Reclaim accounting deep research](reclaim-accounting-deep-research.md)
- [Critical zone persistent operation journal receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md)
- [Critical zone restore quarantine undo safety](critical-zones/restore-quarantine-undo-safety.md)

Risk add-ons:

- [Implementation edge cases cloud network virtual filesystems](implementation-edge-cases-cloud-network-virtual-filesystems.md)
  if deleting cloud placeholders, network shares, removable volumes, or FUSE
  mounts.
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
  if cleanup receipts or logs can expose raw private paths.

Expected output:

- DeletePlan preview exists before destructive adapters;
- identity revalidation blocks stale candidates;
- durable intent and receipt skeleton exist before side effects;
- per-item outcomes are recorded;
- reclaim UI uses confidence and evidence.

Do not pull forward:

- recommendation rules, command execution, remote cleanup, or exact freed-byte
  promises without proof.

Exit gate:

- cleanup cannot execute without DeletePlan, identity revalidation, durable
  journal intent, and receipt skeleton.

## P5 - Recommendations And Tool Cleanup Adapters

Goal:

- add helpful cleanup intelligence and controlled official cleanup commands
  without false-positive data loss.

Minimum read:

- [Implementation edge cases recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md)
- [Implementation edge cases tool-managed storage](implementation-edge-cases-tool-managed-storage.md)
- [Critical zone recommendation policy rule-pack safety](critical-zones/recommendation-policy-rule-pack-safety.md)
- [Critical zone tool command execution sandbox](critical-zones/tool-command-execution-sandbox.md)

Risk add-ons:

- [Critical zone persistent operation journal receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md)
  if command adapters can mutate data.
- [Critical zone restore quarantine undo safety](critical-zones/restore-quarantine-undo-safety.md)
  if user expectations imply restore.
- [Implementation edge cases diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md)
  if command output enters logs/support.

Expected output:

- every recommendation has evidence, risk tier, and invalidation rule;
- command adapters have executable identity, argv/env/cwd policy, output
  limits, timeout, cancellation, dry-run parity, and receipts;
- recommendations feed DeletePlan, not direct deletion.

Do not pull forward:

- generic deletion of Docker volumes, Xcode Archives, Android AVDs, SDKs,
  package stores, Homebrew Cellar, or unknown tool folders.

Exit gate:

- rule packs and command adapters cannot bypass DeletePlan or receipts.

## P6 - Platform Permissions, Packaging, Release, And Updates

Goal:

- make app, helper, daemon, installer, updater, and dependency trust safe enough
  for real users.

Minimum read:

- [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md)
- [Permission UX playbook](permission-ux-playbook.md)
- [Implementation edge cases dependency supply chain governance](implementation-edge-cases-dependency-supply-chain-governance.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Critical zone update release rollback safety](critical-zones/update-release-rollback-safety.md)

Risk add-ons:

- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)
  before release gates are claimed.
- [Critical zone support bundle diagnostics export privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md)
  if release includes diagnostics or support export.

Expected output:

- scanner permission probe and scanner execution use the same identity;
- production does not launch random external pdu binary;
- updater quiesces active operations;
- rollback preserves protocol, DB, receipts, helper identity, and migrations;
- dependency freshness, license, vulnerability, and trust are checked.

Do not pull forward:

- hosted localhost pairing, offline-first service worker, or remote cleanup
  without explicit design and gates.

Exit gate:

- signed/release artifacts have identity, dependency, update, rollback, and
  permission evidence.

## P7 - Remote, Headless, Diagnostics, And Support

Goal:

- support non-local and support workflows without leaking private data or
  enabling accidental remote destructive authority.

Minimum read:

- [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md)
- [Implementation edge cases diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Critical zone remote/headless destructive cleanup authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md)
- [Critical zone support bundle diagnostics export privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md)

Risk add-ons:

- [Implementation edge cases web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md)
  if hosted UI, browser pairing, CORS/PNA, or service workers are involved.
- [Critical zone persistent operation journal receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md)
  if remote cleanup is discussed.

Expected output:

- remote/headless read-only is scoped and audited;
- destructive remote capability is separate and disabled by default;
- support export is typed, redacted, bounded, consented, and useful.

Do not pull forward:

- local loopback token as remote auth;
- `--listen 0.0.0.0` with cleanup;
- raw log/database support bundle.

Exit gate:

- remote read-only and support export have separate auth, privacy, audit, and
  data-retention policies.

## P8 - Testing, Quality Gates, And Release Readiness

Goal:

- prove enabled capabilities under scale, crashes, low disk, permissions,
  updates, destructive boundaries, and privacy constraints.

Minimum read:

- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)
- [Critical zones index](critical-zones/README.md)
- [Pre-implementation critical spikes](pre-implementation-critical-spikes.md)
- [Preimplementation critical research sequence](preimplementation-critical-research-sequence.md)
- [Preimplementation critical zones deep dive](preimplementation-critical-zones-deep-dive.md)

Risk add-ons:

- [Implementation edge cases resource governance](implementation-edge-cases-resource-governance.md)
  for scan profiles, battery, CPU, IO, thermal behavior.
- [Implementation edge cases incremental scan watchers](implementation-edge-cases-incremental-scan-watchers.md)
  for watchers, cache invalidation, stale snapshots.
- [Implementation edge cases advanced scenarios](implementation-edge-cases-advanced-scenarios.md)
  for broad advanced storage, installer, and enterprise cases.

Expected output:

- release checklist maps every risky enabled feature to tests or manual
  evidence;
- destructive tests, crash tests, low-disk tests, permission degradation tests,
  update/rollback tests, and support export tests exist where relevant;
- unfinished risky features stay disabled.

Do not pull forward:

- release claims without evidence;
- manual-only destructive safety;
- support export without privacy tests.

Exit gate:

- all critical zones touched by enabled features pass or block release.

## Cross-Phase Rule

When a task crosses phases, use the earliest phase for dependency readiness and
the highest-risk phase for gates.

Examples:

- Flutter cleanup queue crosses P3 and P4. Use P3 for UI behavior, P4 for
  safety gates.
- Remote cleanup crosses P4 and P7. Use P4 for cleanup truth, P7 for remote
  authority, and critical zones for final gating.
- Recommendation command adapter crosses P5 and P4. Use P5 for rule/command
  policy, P4 for DeletePlan and receipts.
