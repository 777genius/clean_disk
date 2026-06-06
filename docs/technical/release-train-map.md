# Release Train Map

Last updated: 2026-05-16.

This file defines product slices for Clean Disk. It answers a different
question than the implementation runbook:

- [Documentation sitemap](documentation-sitemap.md) shows the grouped structure
  of all technical docs.
- [Phase reading guide](phase-reading-guide.md) shows minimum reading and
  boundaries for each implementation phase.
- [Task router](task-router.md) routes day-to-day task types to docs, gates,
  and expected outputs.
- [Reading order checklist](reading-order-checklist.md) gives
  checkbox-style scenario order, outputs, gates, and stop conditions.
- [Execution board](execution-board.md) gives the row-by-row build board,
  deliverables, workstreams, gates, and excluded scope.
- [Start-to-finish guide](start-to-finish-guide.md) gives one linear path from
  context recovery to release gates.
- [Capability implementation matrix](capability-implementation-matrix.md) maps
  each concrete capability to train, milestone, phase, lane, gate, and excluded
  scope.
- [Implementation runbook](implementation-runbook.md) says what to build in
  technical order.
- This file says which capabilities belong to each product train, which
  documents are mandatory, and which capabilities are intentionally excluded.

Use this file before planning a milestone, beta, demo, or release. If a feature
does not fit the active train, do not sneak it in through implementation work.

## Train Dependency Graph

```text
T0 documentation and architecture recovery
  -> T1 scan-only MVP
  -> T2 local cleanup beta
  -> T3 recommendations and official tool adapters beta
  -> T4 signed desktop release
  -> T5 remote/headless read-only
  -> T6 future remote cleanup
  -> T7 support and release operations
```

Rule:

```text
T6 is not a natural extension of T5.
T6 is a separate destructive-authority product train.
```

Remote read-only mode can ship before remote cleanup. Remote cleanup must not
inherit trust from local loopback auth, desktop UI confirmation, or scan-only
remote access.

## Train Selection Rules

Use the smallest train that satisfies the product goal.

| Need | Choose |
| --- | --- |
| understand docs, recover context, onboard agent | T0 |
| show disk usage fast and safely | T1 |
| move selected local items to Trash with receipts | T2 |
| recommend cleanup and run official cleanup tools | T3 |
| ship to users with installer, permissions, updater | T4 |
| run scanner on server or remote machine as read-only service | T5 |
| allow destructive cleanup remotely | T6 |
| operate, debug, support, and release repeatedly | T7 |

If a task touches cleanup, receipts, command execution, remote authority,
installer identity, support exports, update/rollback, or low-disk behavior, read
the relevant critical-zone document even if the train is earlier.

## T0 - Documentation And Architecture Recovery

Goal:

- make the project understandable without chat history.

Required documents:

- [Start Here](../../START_HERE.md)
- [Technical documentation index](README.md)
- [Documentation map](documentation-map.md)
- [Documentation sitemap](documentation-sitemap.md)
- [Phase reading guide](phase-reading-guide.md)
- [Task router](task-router.md)
- [Reading order checklist](reading-order-checklist.md)
- [Execution board](execution-board.md)
- [Start-to-finish guide](start-to-finish-guide.md)
- [Capability implementation matrix](capability-implementation-matrix.md)
- [Implementation runbook](implementation-runbook.md)
- [Architecture decisions](architecture-decisions.md)
- [Rust architecture](rust-architecture.md)
- [Architecture fit validation](architecture-fit-validation.md)
- [Critical zones index](critical-zones/README.md)

Build output:

- every future agent can answer where to look first;
- accepted architecture is findable;
- risky implementation work has clear gates;
- broad research is separated from enforceable decisions.

Excluded from this train:

- feature implementation;
- new dependencies;
- protocol or Rust crate scaffolding;
- moving documents unless links are verified.

Exit gate:

- README, START_HERE, AGENTS, documentation map, start-to-finish guide, and
  runbook agree on the same architecture and navigation structure.

Stop if:

- a critical rule exists only in chat;
- a new document is not reachable from README;
- a document mixes accepted decisions, brainstorms, and release gates without
  labels.

## T1 - Scan-Only MVP

Goal:

- deliver a useful disk usage viewer with fast scan, progress, tree/table,
  details, search, sort, and responsive UI.

Required documents:

- [Rust architecture](rust-architecture.md)
- [Rust best practices research](rust-best-practices.md)
- [pdu data model and adapter guide](pdu-data-model-and-adapter-guide.md)
- [pdu critical risk verification](pdu-critical-risk-verification.md)
- [pdu required capabilities audit](pdu-required-capabilities-audit.md)
- [Implementation edge cases pdu adapter integration](implementation-edge-cases-pdu-adapter-integration.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Critical zone Rust runtime execution](critical-zones/rust-runtime-execution.md)
- [Implementation edge cases protocol data contracts](implementation-edge-cases-protocol-data-contracts.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md)
- [Feature UX benchmark](feature-ux-benchmark.md)
- [Wide desktop reference](../design/references/clean-disk-wide-reference.png)
- [Compact narrow reference](../design/references/clean-disk-compact-reference.png)

Build output:

- reusable Rust scanner/read-model crates;
- pdu adapter isolated behind scanner ports;
- daemon session lifecycle for scan-only;
- HTTP queries and WebSocket events for scan progress and result pages;
- Flutter scan UI with tree/table, selected row details, progress strip, and
  compact layout.

Excluded from this train:

- cleanup execution;
- recommendation actions that imply deletion;
- official cleanup command execution;
- remote/headless public access;
- update system;
- support bundle export with raw scan data.

Exit gate:

- Flutter never receives the full tree;
- pdu is never product truth without metadata issue modeling;
- memory stays bounded on large trees;
- event stream has sequence, reconnect, throttling, and resync behavior;
- UI can show skipped, permission, changing-file, mount, symlink, and hardlink
  states without generic failure text.

Stop if:

- node identity is only a path string;
- full `PathBuf` is stored per node in the main read model;
- WebSocket events emit one message per filesystem entry;
- scanner cancellation only changes UI state and does not discard late results.

## T2 - Local Cleanup Beta

Goal:

- allow local users to move selected files/folders to Trash with explicit
  confirmation, identity revalidation, durable receipts, crash recovery, and
  honest reclaim estimates.

Required documents:

- every T1 document that defines scanner, protocol, and UI contracts;
- [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md)
- [Implementation edge cases platform identity and delete revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md)
- [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md)
- [Implementation edge cases storage accounting snapshots shared extents](implementation-edge-cases-storage-accounting-snapshots-shared-extents.md)
- [Reclaim accounting deep research](reclaim-accounting-deep-research.md)
- [Critical zone persistent operation journal receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md)
- [Critical zone restore quarantine undo safety](critical-zones/restore-quarantine-undo-safety.md)

Build output:

- DeletePlan aggregate;
- delete preview and confirmation workflow;
- stale identity revalidation;
- platform Trash adapter for the first supported OS;
- durable journal intent and receipt skeleton before side effects;
- per-item dispatch markers and outcomes;
- crash recovery inbox;
- reclaim estimate model with confidence and observed free-space delta;
- receipt view in UI.

Excluded from this train:

- raw permanent delete as default;
- remote destructive cleanup;
- broad recommendation engine;
- command execution adapters;
- cleanup of unknown tool-managed persistent data.

Exit gate:

- cleanup cannot run without DeletePlan, identity revalidation, durable intent,
  and receipt skeleton;
- stale or invisible UI selection cannot delete a different item;
- unknown outcomes are persisted and shown;
- reclaim UI distinguishes logical size, allocated local size, exclusive
  estimate, quota effect, confidence, and observed delta.

Stop if:

- cleanup executes from visible row state or path strings;
- receipts are finalized only at batch end;
- crash recovery auto-retries destructive operations;
- low disk can prevent recording cleanup truth.

## T3 - Recommendations And Official Tool Adapters Beta

Goal:

- add helpful cleanup advice and controlled official cleanup commands without
  turning guesses into destructive actions.

Required documents:

- every T2 document that defines DeletePlan, receipts, and cleanup safety;
- [Implementation edge cases recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md)
- [Implementation edge cases tool-managed storage](implementation-edge-cases-tool-managed-storage.md)
- [Critical zone recommendation policy rule-pack safety](critical-zones/recommendation-policy-rule-pack-safety.md)
- [Critical zone tool command execution sandbox](critical-zones/tool-command-execution-sandbox.md)

Build output:

- rule-pack model with versioning;
- evidence-backed recommendation cards;
- risk tiers;
- stale recommendation invalidation;
- official tool cleanup adapters for explicitly supported tools;
- command execution sandbox with argv/env/cwd policy, timeout, output limits,
  cancellation, dry-run parity, and receipts.

Excluded from this train:

- deleting Docker volumes, Xcode Archives, Android AVDs, SDK packages,
  Homebrew Cellar, or package stores as generic cache;
- command output deciding deletion without domain review;
- user-editable shell snippets as cleanup rules;
- remote command execution.

Exit gate:

- every recommendation has evidence, risk tier, and invalidation rule;
- recommendation cannot bypass DeletePlan;
- command receipts capture executable identity and outcome;
- command adapter tests cover timeout, cancellation, hostile output, and
  partial outcomes.

Stop if:

- a rule says "safe" without proof;
- PATH lookup can select an attacker-controlled executable;
- official tool cleanup is treated as reversible when it is not;
- command output is logged or exported without redaction policy.

## T4 - Signed Desktop Release

Goal:

- ship a trusted desktop app with stable app/helper/daemon identity,
  permissions, installer behavior, dependency governance, and update/rollback
  safety.

Required documents:

- every enabled feature train document;
- [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md)
- [Permission UX playbook](permission-ux-playbook.md)
- [Implementation edge cases dependency supply chain governance](implementation-edge-cases-dependency-supply-chain-governance.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Critical zone update release rollback safety](critical-zones/update-release-rollback-safety.md)
- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)

Build output:

- signed macOS app/helper plan and notarization flow;
- Windows installer/signing/SmartScreen plan;
- Linux package mode decisions;
- scanner permission preflight and repair UI;
- dependency/license/vulnerability gates;
- update quiesce and rollback flow;
- release checklist with evidence.

Excluded from this train:

- hosted web UI connecting to localhost without explicit pairing/CORS/PNA
  design;
- service worker offline-first behavior for daemon-served UI;
- replacing helper identity in updates without migration plan;
- production scans through external random `pdu` binary.

Exit gate:

- permission probe and scanner run under the same process identity;
- updater cannot replace binaries during active cleanup;
- rollback preserves protocol, DB, receipts, and helper identity;
- release artifacts have dependency and signing evidence.

Stop if:

- app and daemon ask for different permissions;
- helper identity changes silently across updates;
- installer uninstall removes receipts/history without explicit user choice;
- release cannot reproduce build inputs and dependency versions.

## T5 - Remote/Headless Read-Only

Goal:

- support server, remote, or headless environments for read-only scan and
  diagnostics without enabling destructive authority.

Required documents:

- T1 scanner, protocol, and runtime documents;
- [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md)
- [Implementation edge cases web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Critical zone remote/headless destructive cleanup authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md)
- [Implementation edge cases diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md)

Build output:

- read-only remote profile;
- explicit bind address policy;
- auth/authZ policy ports;
- target scope model;
- audit event model;
- resource quotas;
- container/systemd/Kubernetes startup guidance if supported;
- UI copy that clearly shows remote/headless limitations.

Excluded from this train:

- remote Trash/delete;
- remote official command execution;
- remote cleanup queue execution;
- local loopback token as remote credential;
- unrestricted `--listen 0.0.0.0` with private scan data.

Exit gate:

- remote APIs are read-only by default;
- every target, session, node, and query is authorized server-side;
- audit trail can explain who scanned what scope;
- remote mode has separate defaults from local daemon mode.

Stop if:

- WebSocket connection auth is treated as object/action authorization;
- scan target paths can escape configured scopes;
- local desktop permission assumptions leak into server mode;
- hosted UI can connect to arbitrary localhost daemons without pairing model.

## T6 - Future Remote Cleanup

Goal:

- define a separate destructive-authority model for remote/headless cleanup.

Required documents:

- every T2 cleanup safety document;
- every T5 remote/headless document;
- [Critical zone remote/headless destructive cleanup authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md)
- [Critical zone persistent operation journal receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md)
- [Critical zone support bundle diagnostics export privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md)
- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)

Build output:

- remote destructive capability model separate from read-only auth;
- object-level authorization;
- target scopes and quotas;
- explicit approval workflow;
- durable audit and operation journal;
- remote cleanup receipts;
- admin-visible policy gates;
- emergency disable/kill switch.

Excluded from this train:

- enabling cleanup because local cleanup already works;
- enabling cleanup because remote read-only auth already works;
- deleting outside configured scopes;
- cleanup from stale scan sessions without revalidation.

Exit gate:

- destructive action requires object-level auth, policy approval, target-scope
  validation, identity revalidation, journal intent, and receipt skeleton;
- audit survives crash and supports incident review;
- quota/rate limits bound blast radius;
- UI and API make remote destructive mode visibly distinct from local cleanup.

Stop if:

- remote cleanup can be enabled by config flag alone;
- WebSocket events can authorize or replay destructive commands;
- cleanup receipt cannot distinguish actor, scope, policy, and item outcome;
- support export can leak remote delete targets by default.

## T7 - Support And Release Operations

Goal:

- make the product maintainable after release through diagnostics, support
  bundles, tests, migration policy, and operational gates.

Required documents:

- [Implementation edge cases diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md)
- [Critical zone support bundle diagnostics export privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md)
- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)
- [Implementation edge cases dependency supply chain governance](implementation-edge-cases-dependency-supply-chain-governance.md)
- [Critical zone update release rollback safety](critical-zones/update-release-rollback-safety.md)

Build output:

- typed diagnostics data classes;
- support bundle manifest;
- redaction profiles;
- crash summary policy;
- structured logs and metrics with privacy budgets;
- database migration gates;
- incident/debug workflow;
- release checklist and regression suite.

Excluded from this train:

- raw database/log zips as support bundles;
- metrics with high-cardinality raw paths or search text;
- crash reports that include scan tree, delete queue, headers, tokens, or raw
  receipts by default;
- release without rollback and migration evidence.

Exit gate:

- support export is typed, bounded, redacted, consented, and useful;
- release checklist maps every enabled risky feature to tests or manual gates;
- update and rollback gates are part of release process;
- diagnostics can debug failures without private data by default.

Stop if:

- support can only be done by asking users for raw logs;
- production logs include daemon tokens, auth headers, raw paths, or delete
  targets;
- migrations lack crash/rollback tests;
- release notes cannot identify changed protocol, schema, cleanup, or updater
  behavior.

## Mapping To Implementation Milestones

| Train | Primary milestones | Notes |
| --- | --- | --- |
| T0 | M0 | documentation and architecture recovery |
| T1 | M1, M2, M3, M4 | scan-only product slice |
| T2 | M5 plus M3/M4 updates | local destructive cleanup beta |
| T3 | M6 plus M5 gates | recommendations and official command adapters |
| T4 | M7, M9 | signed desktop release and release readiness |
| T5 | M8 plus M3 security hardening | remote/headless read-only |
| T6 | M5, M8, M9 with extra authority gates | future remote destructive cleanup |
| T7 | M7, M8, M9 | long-term support, diagnostics, release operations |

## Minimal Useful Release Path

The lowest-risk sequence is:

1. T0 - documentation and architecture recovery.
2. T1 - scan-only MVP.
3. T4 partial - signed desktop packaging for scan-only.
4. T2 - local cleanup beta.
5. T4 full - signed desktop cleanup release.
6. T7 - support and release operations.
7. T5 - remote/headless read-only.
8. T3 - recommendations and official tool adapters.
9. T6 - future remote cleanup only after a separate authority review.

Reasoning:

- scan-only creates value before destructive risk;
- signed identity and permission behavior should be proven before cleanup
  reaches users;
- remote/headless read-only can be useful without inheriting cleanup authority;
- recommendations are powerful, but they increase false-positive risk and
  should sit on top of proven DeletePlan and receipts.

## Product Slice Review Checklist

Before adding work to a train, answer:

- Which train owns this feature?
- Which train explicitly excludes it?
- Which implementation milestone builds it?
- Which critical zones can block it?
- Is the feature read-only, local destructive, command-executing, remote, or
  support/export related?
- Which document becomes the source of truth after the decision?
- Which tests or release gates prove the claim?
