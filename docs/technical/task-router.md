# Task Router

Last updated: 2026-05-16.

This file routes day-to-day work. Use it when you know what kind of task you
are doing, but do not know which documents to open or what order to follow.

This file answers:

```text
I am doing task type X.
Which docs do I open?
What do I do first?
What is the gate?
What should the output look like?
```

It complements:

- [README](README.md) - canonical full index;
- [Documentation sitemap](documentation-sitemap.md) - grouped structure of all
  technical docs;
- [Phase reading guide](phase-reading-guide.md) - phase-by-phase minimum
  reading and boundaries;
- [Reading order checklist](reading-order-checklist.md) - scenario checklists
  for reading order, output, gates, and stop conditions;
- [Execution board](execution-board.md) - row-by-row implementation board with
  deliverables, gates, workstreams, and excluded scope;
- [Start-to-finish guide](start-to-finish-guide.md) - one linear product path;
- [Capability implementation matrix](capability-implementation-matrix.md) -
  capability-level train, milestone, phase, lane, gate, and excluded scope;
- [Release train map](release-train-map.md) - product slice boundaries;
- [Implementation runbook](implementation-runbook.md) - milestone execution.

## Routing Algorithm

1. Pick the closest task type in the table below.
2. Open the listed docs in order.
3. Confirm train, milestone, phase, owner lane, and gate.
4. Write down excluded scope before editing.
5. Implement only the row and direct prerequisites.
6. Add tests, manual evidence, or documentation for the gate.
7. Update source-of-truth docs if the task changes an accepted rule.

If you cannot identify the task type, start with
[Start-to-finish guide](start-to-finish-guide.md) and
[Capability implementation matrix](capability-implementation-matrix.md).

## Task Type Router

| Task type | Open first | Then open | Gate | Expected output |
| --- | --- | --- | --- | --- |
| recover context | [START_HERE](../../START_HERE.md) | [Start-to-finish guide](start-to-finish-guide.md), [README](README.md) | accepted decisions are discoverable | know current architecture and next phase |
| follow scenario checklist | [Reading order checklist](reading-order-checklist.md) | task router row and capability matrix for the chosen scenario | output, gate, and stop conditions are known | ordered docs and task card |
| find next implementation row | [Execution board](execution-board.md) | [Capability matrix](capability-implementation-matrix.md), [Implementation runbook](implementation-runbook.md) | row deliverable, gate, and excluded scope are known | executable task slice |
| change documentation structure | [Documentation map](documentation-map.md) | [README](README.md), [Task router](task-router.md) | every new doc is indexed and linked | updated source-of-truth routing |
| plan product scope | [Release train map](release-train-map.md) | [Capability matrix](capability-implementation-matrix.md), [Architecture decisions](architecture-decisions.md) | excluded scope is explicit | chosen train and blocked future work |
| start implementation from zero | [Start-to-finish guide](start-to-finish-guide.md) | [Implementation runbook](implementation-runbook.md), [Capability matrix](capability-implementation-matrix.md) | five task coordinates are known | task plan with train, milestone, phase, lane, gate |
| Rust workspace skeleton | [Rust architecture](rust-architecture.md) | [Rust best practices](rust-best-practices.md), [Rust runtime critical zone](critical-zones/rust-runtime-execution.md) | core is framework-free | crates, ports, and composition boundary |
| pdu adapter | [pdu data model guide](pdu-data-model-and-adapter-guide.md) | [pdu risk verification](pdu-critical-risk-verification.md), [pdu audit](pdu-required-capabilities-audit.md) | only adapter imports pdu | adapter contract and fixtures |
| read model and pagination | [Performance scale](implementation-edge-cases-performance-scale.md) | [Filesystem model](implementation-edge-cases-filesystem-model.md), [Search indexing](implementation-edge-cases-search-query-indexing.md) | Flutter never stores full tree | arena, indexes, cursors, page queries |
| daemon protocol | [Transport streaming](implementation-edge-cases-transport-protocol-streaming.md) | [Protocol DTOs](implementation-edge-cases-protocol-data-contracts.md), [Concurrency state machines](implementation-edge-cases-concurrency-state-machines.md) | sequence, reconnect, auth, backpressure are explicit | HTTP queries and WebSocket events |
| local web runtime | [Web UI daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md) | [Transport research](transport-client-generation-research.md), [Security privacy](implementation-edge-cases-security-privacy.md) | loopback token and origin policy are safe | daemon-served UI runtime plan |
| Flutter scan UI | [Feature UX benchmark](feature-ux-benchmark.md) | [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md), [Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md), design references | UI uses paginated Rust queries | scan screen, details, search, progress |
| Flutter stores/state | [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md) | [Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md), [Protocol DTOs](implementation-edge-cases-protocol-data-contracts.md) | stores do not own scanner truth or full tree | feature-scoped MobX stores and tests |
| frontend boundaries | [Frontend boundaries decision](frontend-boundaries-decision.md) | [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md), [Protocol DTOs](implementation-edge-cases-protocol-data-contracts.md), [Transport streaming](implementation-edge-cases-transport-protocol-streaming.md) | DTOs, commands, events, persistence, platform actions, and design-system primitives stay separated | boundary tests and stop rules |
| design-system primitive | [Feature UX benchmark](feature-ux-benchmark.md) | [UI accessibility and i18n](implementation-edge-cases-ui-accessibility-i18n.md), design references | Headless gaps are reported | reusable primitive without feature logic |
| permission UX | [Permission UX playbook](permission-ux-playbook.md) | [Platform packaging](implementation-edge-cases-platform-permissions-packaging.md) | permission probe equals scanner identity | preflight and repair flow |
| cleanup preview | [Cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md) | [Platform identity revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md), [Reclaim research](reclaim-accounting-deep-research.md) | no side effect before DeletePlan | preview, queue, dry-run validation |
| Trash execution | [Receipt durability critical zone](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md) | [Restore undo critical zone](critical-zones/restore-quarantine-undo-safety.md), [Local persistence](implementation-edge-cases-local-state-persistence.md) | durable intent before side effect | Trash adapter, receipt, recovery |
| reclaim estimate | [Reclaim research](reclaim-accounting-deep-research.md) | [Storage accounting](implementation-edge-cases-storage-accounting-snapshots-shared-extents.md), [Filesystem model](implementation-edge-cases-filesystem-model.md) | no exact freed-byte claim without proof | confidence/evidence model |
| recommendation rule | [Recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md) | [Rule-pack safety](critical-zones/recommendation-policy-rule-pack-safety.md) | evidence and risk tier required | recommendation that feeds DeletePlan |
| official cleanup command | [Tool-managed storage](implementation-edge-cases-tool-managed-storage.md) | [Command sandbox](critical-zones/tool-command-execution-sandbox.md), [Receipt durability](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md) | argv/env/cwd/output/timeout governed | controlled command adapter |
| signed desktop packaging | [Platform packaging](implementation-edge-cases-platform-permissions-packaging.md) | [Update rollback safety](critical-zones/update-release-rollback-safety.md), [Dependency governance](implementation-edge-cases-dependency-supply-chain-governance.md) | identity, update, rollback, dependencies are governed | installer and release gate plan |
| dependency update | [Dependency governance](implementation-edge-cases-dependency-supply-chain-governance.md) | relevant package docs and release notes | freshness, license, vulnerability, trust checked | pinned dependency change with evidence |
| remote/headless read-only | [Remote headless mode](implementation-edge-cases-remote-headless-mode.md) | [Security privacy](implementation-edge-cases-security-privacy.md), [Remote destructive auth](critical-zones/remote-headless-destructive-cleanup-authorization.md) | destructive remote stays disabled | scoped read-only service |
| remote cleanup | [Remote destructive auth](critical-zones/remote-headless-destructive-cleanup-authorization.md) | local cleanup docs, receipt durability, support privacy | separate authority model exists | explicit remote destructive design |
| diagnostics/support bundle | [Diagnostics support](implementation-edge-cases-diagnostics-observability-support.md) | [Support privacy critical zone](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md), [Local persistence](implementation-edge-cases-local-state-persistence.md) | typed, redacted, bounded, consented export | useful support bundle without raw private data |
| release readiness | [Testing quality gates](implementation-edge-cases-testing-quality-gates.md) | [Critical zones index](critical-zones/README.md), [Update rollback safety](critical-zones/update-release-rollback-safety.md) | risky enabled features have evidence | release checklist and gates |
| PR review | [Capability matrix](capability-implementation-matrix.md) | [Implementation runbook](implementation-runbook.md), touched critical zones | owner lane and gate are respected | findings or approval with evidence |

## Route Details

### Documentation Work

Use when adding, splitting, renaming, or reorganizing docs.

Steps:

1. Open [Documentation map](documentation-map.md).
2. Decide whether the information is decision, research, edge case, critical
   gate, UX contract, or reference.
3. Put the information in the source-of-truth document.
4. Link it from [README](README.md).
5. Add it to [START_HERE](../../START_HERE.md) only if needed for recovery.
6. Add it to [AGENTS](../../AGENTS.md) only if future agents must always know
   the rule.
7. Run link and formatting checks.

Stop if:

- a critical rule exists only in chat;
- a new file is not reachable from README;
- the same accepted rule is copied into multiple docs with different wording.

### Implementation Work

Use when adding product code.

Steps:

1. Pick the capability row in
   [Capability implementation matrix](capability-implementation-matrix.md).
2. Confirm the train in [Release train map](release-train-map.md).
3. Confirm the milestone in [Implementation runbook](implementation-runbook.md).
4. Open required phase docs from [README](README.md).
5. Open critical-zone docs if the capability touches cleanup, commands, remote,
   support, update, packaging, or release.
6. Implement the smallest dependency chain.
7. Add tests or manual evidence for the gate.

Stop if:

- the task cannot name train, milestone, phase, lane, and gate;
- domain/application would import framework or adapter code;
- the UI needs full-tree state;
- cleanup can run without DeletePlan, identity revalidation, journal, and
  receipt.

### Research Work

Use when a dependency, architecture choice, platform API, protocol, or safety
model is unclear.

Steps:

1. Check if an accepted decision already exists.
2. If not, create or update a research doc.
3. Record evaluated options and evidence.
4. Move only accepted outcomes into decision docs.
5. Update capability matrix or release train only if scope or gates change.

Stop if:

- research starts changing implementation scope without an accepted decision;
- a source-backed risk is not converted into a gate, test, or explicit
  non-goal.

### Review Work

Use when reviewing a PR or local change.

Steps:

1. Identify changed capability rows.
2. Check owner lane boundaries.
3. Check excluded scope.
4. Check critical gates.
5. Look for missing tests or evidence.
6. Report bugs, safety risks, and missing gates first.

Stop if:

- a destructive capability appears in a read-only train;
- a critical-zone rule is bypassed;
- an adapter leaks into domain/application;
- logs, metrics, or support output can expose raw private data.

## Task Card Template

Use this at the top of a task plan:

```text
Task type:
Capability:
Train:
Milestone:
Phase:
Owner lane:
Required docs:
Critical gates:
Excluded scope:
Expected output:
Evidence:
```

If a field is unknown, resolve documentation first.

## Fastest Safe Paths

### Scan-Only MVP

```text
Rust workspace skeleton
  -> pdu adapter
  -> read model and pagination
  -> daemon protocol
  -> Flutter scan UI
  -> scan-only packaging spike
```

### Local Cleanup Beta

```text
cleanup preview
  -> reclaim estimate
  -> Trash execution
  -> receipt and operation journal
  -> crash recovery
  -> receipt view
```

### Remote Read-Only

```text
daemon protocol
  -> local web runtime
  -> remote/headless read-only
  -> diagnostics/support bundle
```

### Desktop Release

```text
permission UX
  -> signed desktop packaging
  -> dependency governance
  -> update rollback safety
  -> release readiness
```

## Most Common Blockers

| Blocker | Resolve in |
| --- | --- |
| unclear product slice | [Release train map](release-train-map.md) |
| unclear capability owner | [Capability matrix](capability-implementation-matrix.md) |
| unclear implementation order | [Implementation runbook](implementation-runbook.md) |
| unclear document ownership | [Documentation map](documentation-map.md) |
| cleanup safety uncertainty | [Cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md) and cleanup critical zones |
| protocol/event uncertainty | [Transport streaming](implementation-edge-cases-transport-protocol-streaming.md) and protocol DTO docs |
| UI performance uncertainty | [Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md) and performance scale docs |
| packaging identity uncertainty | [Platform packaging](implementation-edge-cases-platform-permissions-packaging.md) and update rollback critical zone |
| remote authority uncertainty | [Remote destructive authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md) |
| support privacy uncertainty | [Support bundle privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md) |
