# Documentation Map

Last updated: 2026-06-07.

This file explains how Clean Disk documentation is structured and maintained.
Use it when you do not know which file to open, where to record a decision, or
how a new document should relate to the rest of the project.

## Canonical Entry Points

```text
START_HERE.md
  short context recovery

docs/technical/README.md
  full documentation index and task router

docs/technical/documentation-operating-manual.md
  request-to-evidence workflow, source-of-truth order, task card, update rules

docs/technical/documentation-tree.md
  visual tree of all technical docs by layer, work area, read mode, and gate

docs/technical/documentation-sitemap.md
  visual structure of all technical docs grouped by area

docs/technical/phase-reading-guide.md
  phase-by-phase minimum reading, risk add-ons, output, and boundaries

docs/technical/task-router.md
  day-to-day task routing by task type, required docs, gate, and expected output

docs/technical/reading-order-checklist.md
  scenario checklists for reading order, output, gates, and stop conditions

docs/technical/execution-board.md
  row-by-row implementation board with deliverables, docs, gates, workstreams, and excluded scope

docs/technical/start-to-finish-guide.md
  one linear route from context recovery to release gates

docs/technical/capability-implementation-matrix.md
  capability-to-train, milestone, phase, lane, gate, and excluded-scope routing

docs/technical/implementation-runbook.md
  operational execution order from M0 to M9

docs/technical/release-train-map.md
  product slice boundaries from scan-only MVP to cleanup, release, remote/headless, and support operations

docs/technical/critical-zones/README.md
  release gates and global risk ranking
```

Rules:

- use `START_HERE.md` when recovering context quickly;
- use `docs/technical/README.md` when deciding where to look;
- use `docs/technical/documentation-operating-manual.md` when you need the
  exact operating workflow from request to evidence, source-of-truth order, task
  card shape, update rules, and conflict resolution;
- use `docs/technical/documentation-tree.md` when you need a visual tree of all
  technical docs by layer, work area, read mode, and gate;
- use `docs/technical/documentation-sitemap.md` when you need to see the whole
  documentation set grouped by area;
- use `docs/technical/phase-reading-guide.md` when you know the phase and need
  the minimum docs, risk add-ons, output, and boundaries;
- use `docs/technical/task-router.md` when you know the task type and need the
  exact docs, gate, and expected output;
- use `docs/technical/reading-order-checklist.md` when you want
  checkbox-style order for a known scenario;
- use `docs/technical/execution-board.md` when you need the next build row,
  deliverable, gate, and excluded scope from zero to release;
- use `docs/technical/start-to-finish-guide.md` when you want one ordered path
  from zero context to release gates;
- use `docs/technical/capability-implementation-matrix.md` when you want to
  build a concrete capability and need its train, milestone, phase, lane, gate,
  and excluded scope;
- use `docs/technical/implementation-runbook.md` when deciding what to build
  next;
- use `docs/technical/release-train-map.md` when deciding what belongs to the
  active MVP, beta, release, remote/headless, or support slice;
- use `docs/technical/critical-zones/README.md` when a change can affect
  safety, release, remote/headless, cleanup, or user trust.

## Documentation Layers

```text
Layer 0 - recovery
  START_HERE.md

Layer 1 - navigation
  docs/technical/README.md
  docs/technical/documentation-operating-manual.md
  docs/technical/documentation-tree.md
  docs/technical/documentation-map.md
  docs/technical/documentation-sitemap.md
  docs/technical/phase-reading-guide.md
  docs/technical/task-router.md
  docs/technical/reading-order-checklist.md
  docs/technical/execution-board.md
  docs/technical/start-to-finish-guide.md
  docs/technical/capability-implementation-matrix.md
  docs/technical/implementation-runbook.md
  docs/technical/release-train-map.md

Layer 2 - accepted architecture
  architecture-decisions.md
  architecture-fit-validation.md
  architecture-future-risks.md
  rust-architecture.md

Layer 3 - implementation domains
  pdu and scanner docs
  protocol and daemon docs
  Flutter and UX docs
  cleanup and persistence docs
  platform and release docs
  remote and diagnostics docs

Layer 4 - critical gates
  critical-zones/*

Layer 5 - broad research and edge cases
  implementation-edge-cases*
  preimplementation-critical*
```

Layer rules:

- lower-numbered layers route readers to higher-detail layers;
- accepted decisions override exploratory research;
- critical gates override local implementation convenience;
- broad edge-case docs feed implementation plans, but do not replace accepted
  decisions or tests.

## Decision Tree

```text
Recover context?
  -> START_HERE.md

Know the whole document structure?
  -> documentation-operating-manual.md
  -> documentation-tree.md
  -> documentation-map.md
  -> documentation-sitemap.md

Know the phase?
  -> phase-reading-guide.md

Know the task type?
  -> task-router.md

Need checkbox order for a scenario?
  -> reading-order-checklist.md

Need the next implementation row?
  -> execution-board.md

Want one path from zero to release?
  -> start-to-finish-guide.md

Want to build a concrete capability?
  -> capability-implementation-matrix.md

Know what to build next?
  -> implementation-runbook.md

Know what belongs in this release slice?
  -> release-train-map.md

Change architecture or package boundaries?
  -> architecture-decisions.md
  -> rust-architecture.md
  -> architecture-fit-validation.md

Touch scanner or read model?
  -> pre-coding-pdu-architecture-research.md
  -> pdu-data-model-and-adapter-guide.md
  -> pdu-critical-risk-verification.md
  -> implementation-edge-cases-performance-scale.md
  -> critical-zones/rust-runtime-execution.md

Touch protocol or daemon transport?
  -> implementation-edge-cases-protocol-data-contracts.md
  -> implementation-edge-cases-transport-protocol-streaming.md
  -> implementation-edge-cases-web-ui-daemon-runtime.md

Touch Flutter UI?
  -> feature-ux-benchmark.md
  -> implementation-edge-cases-flutter-large-tree-ui.md
  -> design references

Touch cleanup?
  -> implementation-edge-cases-cleanup-delete-safety.md
  -> implementation-edge-cases-platform-identity-delete-revalidation.md
  -> critical-zones/persistent-operation-journal-receipt-durability-low-disk.md
  -> critical-zones/restore-quarantine-undo-safety.md

Touch recommendations or tool cleanup?
  -> implementation-edge-cases-recommendation-rule-engine.md
  -> implementation-edge-cases-tool-managed-storage.md
  -> critical-zones/recommendation-policy-rule-pack-safety.md
  -> critical-zones/tool-command-execution-sandbox.md

Touch packaging, permissions, updater, or release?
  -> implementation-edge-cases-platform-permissions-packaging.md
  -> critical-zones/update-release-rollback-safety.md

Touch remote/headless or support export?
  -> implementation-edge-cases-remote-headless-mode.md
  -> implementation-edge-cases-diagnostics-observability-support.md
  -> critical-zones/remote-headless-destructive-cleanup-authorization.md
  -> critical-zones/support-bundle-diagnostics-export-privacy-evidence.md

Prepare release?
  -> implementation-edge-cases-testing-quality-gates.md
  -> critical-zones/README.md
  -> implementation-runbook.md
```

## Document Lifecycle

Documentation should move from uncertain to enforceable:

```text
research
  -> accepted decision
  -> implementation contract
  -> test or release gate
  -> support/recovery evidence
```

Rules:

- do not leave accepted architecture only in chat history;
- do not bury release blockers in broad research docs;
- do not duplicate the same accepted rule in many places with different
  wording;
- if duplication is useful for navigation, link back to the canonical source.

## Source Of Truth By Topic

| Topic | Source of truth | Supporting docs |
| --- | --- | --- |
| Current project scope | [START_HERE](../../START_HERE.md) | [README](README.md) |
| Documentation routing | [README](README.md) | this file |
| Documentation structure view | [Documentation sitemap](documentation-sitemap.md) | README, task router |
| Phase reading | [Phase reading guide](phase-reading-guide.md) | README, implementation runbook |
| Day-to-day task routing | [Task router](task-router.md) | capability matrix, implementation runbook |
| Scenario checklist order | [Reading order checklist](reading-order-checklist.md) | task router, capability matrix, phase reading guide |
| Row-by-row implementation board | [Execution board](execution-board.md) | task router, capability matrix, implementation runbook |
| Start-to-finish path | [Start-to-finish guide](start-to-finish-guide.md) | README, release train map, implementation runbook |
| Capability routing | [Capability implementation matrix](capability-implementation-matrix.md) | release train map, implementation runbook |
| Execution order | [Implementation runbook](implementation-runbook.md) | [README](README.md) |
| Product slice boundaries | [Release train map](release-train-map.md) | [Implementation runbook](implementation-runbook.md) |
| Product market positioning | [Market and competitive research](market-competitive-research.md) | release train map, UX playbooks |
| Architecture decisions | [Architecture decisions](architecture-decisions.md) | architecture fit/future risks |
| Rust crate structure | [Rust architecture](rust-architecture.md) | Rust best practices |
| pdu adapter contract | [Pre-coding pdu architecture research](pre-coding-pdu-architecture-research.md) | pdu data model guide, pdu Clean Architecture contract, pdu raw API contract map, pdu audit, validation, risk verification |
| Runtime safety | [Rust runtime critical zone](critical-zones/rust-runtime-execution.md) | operational reliability |
| Protocol contracts | [Protocol data contracts](implementation-edge-cases-protocol-data-contracts.md) | transport streaming |
| UX behavior | [Feature UX benchmark](feature-ux-benchmark.md) | UX playbooks and design references |
| Flutter frontend state architecture | [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md) | large-tree UI, feature UX benchmark |
| Frontend boundaries | [Frontend boundaries decision](frontend-boundaries-decision.md) | Flutter frontend architecture, protocol contracts, transport streaming |
| Cleanup safety | [Cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md) | identity revalidation, receipt durability |
| Reclaim truth | [Reclaim accounting research](reclaim-accounting-deep-research.md) | storage accounting |
| Recommendations | [Recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md) | rule-pack critical zone |
| Tool cleanup | [Tool-managed storage](implementation-edge-cases-tool-managed-storage.md) | command sandbox critical zone |
| Packaging/update | [Platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md) | update rollback critical zone |
| Remote/headless | [Remote and headless mode](implementation-edge-cases-remote-headless-mode.md) | remote auth critical zone |
| Diagnostics/support | [Diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md) | support bundle critical zone |
| Release quality | [Testing quality gates](implementation-edge-cases-testing-quality-gates.md) | critical zones index |

## Where New Information Goes

| New information | Put it in |
| --- | --- |
| newly accepted architecture choice | `architecture-decisions.md` |
| changed Rust crate or layer rule | `rust-architecture.md` |
| changed visual grouping or documentation area map | `documentation-sitemap.md` |
| changed phase minimum reading, risk add-ons, output, or boundaries | `phase-reading-guide.md` |
| changed day-to-day task routing or expected task output | `task-router.md` |
| changed scenario checklist sequence, output, gate, or stop condition | `reading-order-checklist.md` |
| changed row-by-row implementation board, deliverable, workstream, gate, or excluded scope | `execution-board.md` |
| changed default start-to-release path | `start-to-finish-guide.md` |
| changed capability-to-train or capability-to-gate mapping | `capability-implementation-matrix.md` |
| changed implementation sequence | `implementation-runbook.md` |
| changed MVP, beta, release, remote/headless, or support slice | `release-train-map.md` |
| new market, competitor, monetization, or benchmark positioning research | `market-competitive-research.md` |
| new global risk or release blocker | `critical-zones/<topic>.md` and critical-zones index |
| new pdu limitation or adapter rule | pdu adapter guide, pdu audit, or pdu risk verification |
| new platform filesystem edge case | relevant `implementation-edge-cases-*.md` |
| new user-facing workflow rule | UX benchmark or relevant UX playbook |
| new release/test requirement | testing quality gates and relevant critical-zone file |
| new visual design target | `docs/design/references/` and `START_HERE.md` |

## Maintenance Checklist

When adding or changing a document:

- add it to [README](README.md);
- add it to [START_HERE](../../START_HERE.md) only if it is needed for recovery;
- add it to [AGENTS.md](../../AGENTS.md) only if future agents must always know
  about it;
- add it to [critical zones](critical-zones/README.md) only if it is a global
  risk gate;
- ensure it has a clear owner layer and lifecycle role;
- check that no local links broke;
- avoid copying accepted rules into multiple docs unless the duplicate points
  back to the canonical source.

## Preferred Document Shapes

Decision document:

```text
context
accepted decision
rejected alternatives
consequences
open questions
```

Edge-case document:

```text
scope
failure modes
mitigations
kill criteria
tests
links to gates
```

Critical-zone document:

```text
why this can invalidate guarantees
source research
core rule
state model
acceptance gates
kill criteria
required spikes
decision
```

Runbook section:

```text
goal
read
build
exit gate
stop if
```

## Anti-Patterns

Avoid:

- one more long unordered list in README;
- accepted decisions hidden only in research notes;
- critical safety rules duplicated with different wording;
- physical file moves without updating every link;
- new docs that do not appear in the inventory;
- docs that explain what to do but not when to stop;
- docs that list risks but do not name gates or tests.
