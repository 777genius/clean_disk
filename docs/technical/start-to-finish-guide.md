# Start-To-Finish Guide

Last updated: 2026-05-16.

This is the practical path from an empty implementation to a releasable Clean
Disk product. It connects the documentation index, release trains, implementation
milestones, architecture lanes, and critical gates into one workflow.

Use this when you want to know:

- what to read first;
- what to build first;
- which document owns each decision;
- which work is intentionally not part of the current slice;
- when to stop and resolve risk before coding more.

## One-Line Navigation

```text
START_HERE
  -> Documentation operating manual
  -> Documentation tree
  -> Documentation map
  -> Documentation sitemap
  -> Task router
  -> Capability implementation matrix
  -> Execution board
  -> README Implementation Packet Index
  -> Phase reading guide
  -> Reading order checklist
  -> Release train map
  -> Implementation runbook
  -> Phase docs
  -> Critical zones
  -> Tests and release gates
```

The full index is [README](README.md). This file is the linear route through
that index.

If you do not know how to operate the docs yet, read
[Documentation operating manual](documentation-operating-manual.md) before this
file.
If you already know the task type, use [Task router](task-router.md) first.
If you need the grouped map of all docs, use
[Documentation sitemap](documentation-sitemap.md).
If you already know the current phase, use
[Phase reading guide](phase-reading-guide.md).
If you want checkbox-style order for a common scenario, use
[Reading order checklist](reading-order-checklist.md).
If you want the row-by-row build board with deliverables and gates, use
[Execution board](execution-board.md).

## Five Coordinates For Every Task

Every implementation task should have five coordinates:

| Coordinate | Meaning | Source |
| --- | --- | --- |
| Train | product slice, such as scan-only MVP or cleanup beta | [Release train map](release-train-map.md) |
| Milestone | implementation step, such as M2 scanner adapter or M4 scan UI | [Implementation runbook](implementation-runbook.md) |
| Phase | documentation bundle, such as P1 scanner or P4 cleanup | [README](README.md) |
| Lane | owner boundary, such as Rust engine, server/runtime, Flutter app | [README Work Lanes](README.md) |
| Gate | stop rule or release blocker | [Critical zones](critical-zones/README.md) |

If a task cannot name these five things, it is not ready for implementation.

For a quick lookup by capability, use
[Capability implementation matrix](capability-implementation-matrix.md).

## Master Sequence

Use this table as the top-to-bottom implementation index. It is the clean path
from no context to release-ready product. It does not replace the execution
board or runbook; it tells you which row, packet, and docs to open next.

| Order | Work | Coordinates | Open first | Done when |
| --- | --- | --- | --- | --- |
| 0 | documentation operating model | T0 / M0 / P0 / rows 0-1 / PK0 | [START_HERE](../../START_HERE.md), [Documentation operating manual](documentation-operating-manual.md), [README](README.md) | task card can be filled and docs are indexed |
| 1 | architecture baseline | T0 / M0 / P0 / row 1 / PK0 | [Architecture decisions](architecture-decisions.md), [Future-proofing gates](future-proofing-architecture-gates.md), [Rust architecture](rust-architecture.md) | accepted boundaries, dependencies, and MVP exclusions are clear |
| 2 | Rust reusable skeleton | T1 / M1 / P1 / row 2 / PK1 | [Rust architecture](rust-architecture.md), [Rust best practices](rust-best-practices.md), [Rust runtime critical zone](critical-zones/rust-runtime-execution.md) | crates compile and core has no adapter, transport, Flutter, or generated-code leaks |
| 3 | pdu adapter contract | T1 / M2 / P1 / row 3 / PK2 | [pdu data model guide](pdu-data-model-and-adapter-guide.md), [pdu risk verification](pdu-critical-risk-verification.md), [pdu audit](pdu-required-capabilities-audit.md) | only adapter imports `parallel_disk_usage` and fixture behavior is proven |
| 4 | arena read model and indexes | T1 / M2 / P1 / row 4 / PK3 | [Performance scale](implementation-edge-cases-performance-scale.md), [Filesystem model](implementation-edge-cases-filesystem-model.md), [Search indexing](implementation-edge-cases-search-query-indexing.md) | Rust owns tree/indexes and Flutter cannot receive full tree |
| 5 | scanner runtime lanes | T1 / M2-M3 / P1-P2 / row 5 / PK4 | [Rust runtime critical zone](critical-zones/rust-runtime-execution.md), [Resource governance](implementation-edge-cases-resource-governance.md), [Operational reliability](implementation-edge-cases-operational-reliability.md) | blocking work, cancellation, shutdown, panic containment, and budgets are explicit |
| 6 | daemon protocol and event stream | T1 / M3 / P2 / rows 6-7 / PK5 | [Protocol DTOs](implementation-edge-cases-protocol-data-contracts.md), [Transport streaming](implementation-edge-cases-transport-protocol-streaming.md), [Web runtime](implementation-edge-cases-web-ui-daemon-runtime.md) | sessions, DTOs, event ordering, reconnect, auth, cursors, and gaps are typed |
| 7 | Flutter scan UI | T1 / M4 / P3 / rows 8-9 / PK6 | [Feature UX benchmark](feature-ux-benchmark.md), [Frontend architecture](flutter-frontend-architecture-decision.md), [Large-tree UI](implementation-edge-cases-flutter-large-tree-ui.md), [Design references](../design/references/clean-disk-wide-reference.png) | scan shell, tree/table, details, search, progress, and compact layout use paginated Rust queries |
| 8 | scan-only packaging proof | T4 partial / M7 / P6 / row 10 / PK7 | [Platform packaging](implementation-edge-cases-platform-permissions-packaging.md), [Permission UX](permission-ux-playbook.md), [Update rollback](critical-zones/update-release-rollback-safety.md) | signed scanner identity and permission probe identity match |
| 9 | cleanup preview | T2 / M5 / P4 / row 11 / PK8 | [Cleanup safety](implementation-edge-cases-cleanup-delete-safety.md), [Identity revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md), [Reclaim research](reclaim-accounting-deep-research.md) | DeletePlan preview and reclaim confidence exist with no destructive adapter call |
| 10 | cleanup execution | T2 / M5 / P4 / row 12 / PK9 | [Receipt durability](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md), [Restore safety](critical-zones/restore-quarantine-undo-safety.md), [Local persistence](implementation-edge-cases-local-state-persistence.md) | durable intent is written before side effects and receipts model partial outcomes |
| 11 | recommendations and tool commands | T3 / M6 / P5 / row 13 / PK10 | [Recommendation rules](implementation-edge-cases-recommendation-rule-engine.md), [Tool-managed storage](implementation-edge-cases-tool-managed-storage.md), [Command sandbox](critical-zones/tool-command-execution-sandbox.md) | no recommendation or command bypasses DeletePlan, evidence, and receipts |
| 12 | signed desktop release hardening | T4 / M7-M9 / P6-P8 / rows 14, 17 / PK11 | [Dependency governance](implementation-edge-cases-dependency-supply-chain-governance.md), [Testing gates](implementation-edge-cases-testing-quality-gates.md), [Critical zones](critical-zones/README.md) | update, rollback, dependency, scale, permission, cleanup, and migration gates have evidence |
| 13 | remote/headless read-only | T5 / M8 / P7 / row 15 / PK12 | [Remote mode](implementation-edge-cases-remote-headless-mode.md), [Security/privacy](implementation-edge-cases-security-privacy.md), [Remote destructive auth boundary](critical-zones/remote-headless-destructive-cleanup-authorization.md) | remote mode is scoped, audited, quota-bound, and cleanup remains disabled |
| 14 | support operations | T7 / M8-M9 / P7-P8 / rows 16-17 / PK13 | [Diagnostics support](implementation-edge-cases-diagnostics-observability-support.md), [Support privacy](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md), [Local persistence](implementation-edge-cases-local-state-persistence.md) | support export is typed, redacted, bounded, consented, and useful |

Do not treat this as waterfall. UI sketches, spikes, and research may happen
earlier, but production work cannot pass the gate for its row until the required
evidence exists.

## Default Product Path

Follow this order unless the user explicitly changes the product goal.

| Order | Product objective | Train | Milestones | Result |
| --- | --- | --- | --- | --- |
| 1 | recover project context | T0 | M0 | docs, architecture, and boundaries are clear |
| 2 | build scan-only app | T1 | M1-M4 | fast disk visualization with no destructive actions |
| 3 | package scan-only desktop build | T4 partial | M7, M9 partial | signed identity and permissions are proven early |
| 4 | add local cleanup beta | T2 | M5 | Trash, DeletePlan, receipts, reclaim confidence |
| 5 | harden desktop cleanup release | T4 full | M7, M9 | installer, updater, dependency gates, safety tests |
| 6 | add support operations | T7 | M8-M9 | diagnostics, support bundles, release evidence |
| 7 | add remote/headless read-only | T5 | M8 | server/headless scan without destructive authority |
| 8 | add recommendations and tool adapters | T3 | M6 | evidence-backed cleanup guidance and official tools |
| 9 | consider remote cleanup | T6 | separate review | destructive remote authority, audit, quotas, policy |

Reasoning:

- scan-only creates value before data-loss risk;
- signed identity and permissions should be proven before cleanup reaches users;
- local cleanup is easier to make safe than remote cleanup;
- recommendations are useful only after DeletePlan and receipts are reliable;
- remote cleanup is a separate authority model, not a checkbox on remote mode.

## First Implementation Packets

These are the first concrete packets. Build them in order.

### Packet 0 - Documentation Baseline

Read:

- [START_HERE](../../START_HERE.md)
- [README](README.md)
- [Documentation map](documentation-map.md)
- [Documentation sitemap](documentation-sitemap.md)
- [Reading order checklist](reading-order-checklist.md)
- [Execution board](execution-board.md)
- [Phase reading guide](phase-reading-guide.md)
- [Task router](task-router.md)
- [Capability implementation matrix](capability-implementation-matrix.md)
- [Release train map](release-train-map.md)
- [Implementation runbook](implementation-runbook.md)

Build:

- no product code;
- keep docs indexed;
- make accepted decisions discoverable.

Gate:

- new docs are reachable from README;
- no accepted decision exists only in chat.

### Packet 1 - Rust Workspace Skeleton

Read:

- [Rust architecture](rust-architecture.md)
- [Rust best practices research](rust-best-practices.md)
- [Critical zone Rust runtime execution](critical-zones/rust-runtime-execution.md)

Build:

- reusable `fs_usage_*` crates;
- `clean-disk-server` binary shape;
- domain/application boundaries;
- ports for scanning, read model, metadata, cleanup, persistence, and runtime.

Gate:

- domain/application do not import pdu, HTTP, Flutter, SQLite, process APIs, or
  generated bridge code;
- server owns composition;
- blocking scanner work has an explicit execution lane.

### Packet 2 - pdu Adapter Contract

Read:

- [pdu data model and adapter guide](pdu-data-model-and-adapter-guide.md)
- [pdu critical risk verification](pdu-critical-risk-verification.md)
- [pdu required capabilities audit](pdu-required-capabilities-audit.md)
- [Implementation edge cases pdu adapter integration](implementation-edge-cases-pdu-adapter-integration.md)

Build:

- pdu adapter behind scanner port;
- option mapping;
- hardlink policy;
- progress mapping;
- cancellation state model;
- fixture tests for pdu behavior.

Gate:

- only the pdu adapter crate imports `parallel_disk_usage`;
- pdu types are not public domain models;
- late pdu results after cancellation are discarded.

### Packet 3 - Arena Read Model And Indexes

Read:

- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases search query indexing](implementation-edge-cases-search-query-indexing.md)

Build:

- compact node arena;
- stable node IDs;
- parent/child indexes;
- top folders/top files indexes;
- search, sort, filter;
- paginated query responses;
- issue model for skipped, permission, hardlink, mount, symlink, and changing
  file states.

Gate:

- Flutter cannot receive the full tree;
- full `PathBuf` is not stored per node in the main read model;
- memory profile is measured on large fixtures.

### Packet 4 - Daemon Protocol

Read:

- [Implementation edge cases protocol data contracts](implementation-edge-cases-protocol-data-contracts.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Transport and client generation research](transport-client-generation-research.md)
- [Implementation edge cases concurrency state machines](implementation-edge-cases-concurrency-state-machines.md)
- [Implementation edge cases web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md)

Build:

- HTTP commands and queries;
- WebSocket events;
- session lifecycle;
- protocol envelopes;
- sequence numbers;
- reconnect/resync;
- bounded event buffers;
- capability endpoint;
- local token/origin policy.

Gate:

- protocol DTOs are separate from domain;
- large counters and IDs are Flutter web safe;
- reconnect cannot subscribe to unauthorized sessions;
- stale cursors have typed errors.

### Packet 5 - Flutter Scan UI

Read:

- [Feature UX benchmark](feature-ux-benchmark.md)
- [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md)
- [Cross-platform user experience playbook](cross-platform-user-experience-playbook.md)
- [Permission UX playbook](permission-ux-playbook.md)
- [Wide desktop reference](../design/references/clean-disk-wide-reference.png)
- [Compact narrow reference](../design/references/clean-disk-compact-reference.png)

Build:

- scan shell;
- target picker;
- progress/status strip;
- virtualized tree/table;
- selected node details;
- search/filter/sort;
- compact layout;
- scan-quality states;
- design-system primitives over Headless/Material.

Gate:

- selected row and details use stable node IDs;
- long names and paths do not break layout;
- UI never computes cleanup truth from visible rows;
- Headless gaps are reported before awkward workarounds.

### Packet 6 - Scan-Only Packaging Spike

Read:

- [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md)
- [Permission UX playbook](permission-ux-playbook.md)
- [Critical zone update release rollback safety](critical-zones/update-release-rollback-safety.md)

Build:

- signed scanner process identity plan;
- permission probe under the real scanner identity;
- first-run permission UX;
- development installer notes;
- update constraints before cleanup exists.

Gate:

- production scan is not an external random pdu binary;
- permission probe and scanner process identity match;
- app/helper identity will survive update planning.

### Packet 7 - Cleanup Preview Without Side Effects

Read:

- [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md)
- [Implementation edge cases platform identity and delete revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md)
- [Reclaim accounting deep research](reclaim-accounting-deep-research.md)

Build:

- DeletePlan preview;
- identity revalidation dry-run;
- cleanup queue UI;
- reclaim estimate with confidence;
- no actual Trash/delete yet.

Gate:

- stale identity blocks preview;
- UI shows confidence and uncertainty;
- no destructive adapter is called.

### Packet 8 - Local Trash Adapter And Receipts

Read:

- [Critical zone persistent operation journal receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md)
- [Critical zone restore quarantine undo safety](critical-zones/restore-quarantine-undo-safety.md)
- [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md)

Build:

- durable operation journal;
- receipt skeleton before side effects;
- platform Trash adapter for one OS;
- per-item outcome states;
- crash recovery inbox;
- receipt view.

Gate:

- cleanup cannot run if durable intent cannot be written;
- unknown outcomes are represented;
- crash recovery does not auto-retry destructive side effects.

## What To Read By Stage

### Stage A - Before Any Code

Read:

- [START_HERE](../../START_HERE.md)
- [Documentation map](documentation-map.md)
- [Release train map](release-train-map.md)
- [Implementation runbook](implementation-runbook.md)
- [Architecture decisions](architecture-decisions.md)
- [Rust architecture](rust-architecture.md)

Do not read all edge-case docs yet. Use them when the task touches their area.

### Stage B - Scan-Only MVP

Read:

- Phase 1 scanner docs from [README](README.md);
- Phase 2 protocol docs from [README](README.md);
- Phase 3 UI docs from [README](README.md);
- [Critical zone Rust runtime execution](critical-zones/rust-runtime-execution.md).

Ignore for now:

- remote cleanup;
- recommendation rules;
- official command adapters;
- destructive cleanup execution.

### Stage C - Cleanup Beta

Read:

- Phase 4 cleanup docs from [README](README.md);
- receipt durability critical zone;
- restore/quarantine critical zone;
- reclaim accounting research.

Ignore for now:

- broad recommendations;
- remote cleanup;
- command execution adapters.

### Stage D - Desktop Release

Read:

- platform packaging;
- permission UX;
- update rollback critical zone;
- dependency governance;
- testing quality gates.

Do not postpone:

- signing identity;
- permission probes;
- update quiesce;
- rollback safety;
- dependency/license gates.

### Stage E - Remote/Headless Read-Only

Read:

- remote/headless mode;
- web daemon runtime;
- security/privacy;
- remote destructive authorization critical zone.

Keep disabled:

- remote Trash/delete;
- remote official cleanup commands;
- remote cleanup queue execution.

### Stage F - Future Remote Cleanup

Read:

- all local cleanup docs;
- all remote/headless docs;
- remote destructive authorization critical zone;
- receipt durability critical zone;
- support privacy critical zone.

Treat as new product:

- new authZ model;
- new audit model;
- new quota model;
- new release gate.

## Document Ownership Rules

| Question | Canonical owner | Do not put it in |
| --- | --- | --- |
| what is accepted architecture? | architecture-decisions.md | broad research docs |
| how Rust crates are shaped? | rust-architecture.md | pdu docs |
| what product slice are we building? | release-train-map.md | implementation-runbook.md |
| what exact order do we implement? | implementation-runbook.md | release-train-map.md |
| what docs exist and where to look? | README.md | START_HERE.md |
| how documentation is maintained? | documentation-map.md | every doc footer |
| what can block release globally? | critical-zones/* | broad edge-case lists |
| how UI should behave? | feature-ux-benchmark.md | scanner docs |
| how a protocol field is encoded? | protocol data contracts | Flutter UI docs |
| how cleanup is made safe? | cleanup safety docs and critical zones | recommendation docs |

## Stop And Resolve

Stop implementation and resolve docs/tests first when:

- a task needs a new dependency without freshness and stability check;
- an adapter leaks into domain/application;
- the UI needs the full scan tree;
- pdu output becomes product truth;
- cleanup can execute from path strings;
- a receipt can be missing after side effects;
- remote read-only starts growing destructive permissions;
- support export needs raw logs or raw databases;
- update can run while cleanup is active.

## PR Planning Template

Use this before opening a work item:

```text
Train:
Milestone:
Phase:
Lane:
Critical gates:
Required docs:
Excluded scope:
Implementation output:
Exit evidence:
```

If the template cannot be filled in, the task is under-specified.

## Minimal Definition Of Done

For implementation work:

- code follows the owning lane;
- forbidden imports are absent;
- required docs were checked;
- relevant gates have tests or explicit manual evidence;
- no raw paths/tokens/private scan data leak through logs, metrics, or support
  exports;
- risky future features stay disabled.

For documentation work:

- the file is linked from [README](README.md);
- recovery docs are updated only if the new doc is needed for onboarding;
- AGENTS is updated only if future agents must always know the rule;
- critical-zone index is updated only for global release gates;
- local links are valid;
- the document says whether it is a decision, research, edge case, critical
  gate, UX contract, or reference.
