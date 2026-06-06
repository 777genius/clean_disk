# Documentation Operating Manual

Last updated: 2026-05-16.

This file explains how to operate the documentation set from a real task to a
verified output. It is not a source of architecture decisions. It tells you how
to move through the documents without reading everything or coding from stale
research.

## One Rule

```text
Request -> task type -> capability -> execution row -> packet -> phase docs
  -> critical gates -> evidence -> doc update
```

If any part of that chain is unknown, do not implement yet. Fill the missing
field from the navigation files.

## What Each Navigation File Does

| Need | Open | Result |
| --- | --- | --- |
| recover current project context | [START_HERE](../../START_HERE.md) | current scope and accepted baseline |
| see the whole technical index | [README](README.md) | full map, fast path, inventory, gates |
| see docs as a visual tree | [Documentation tree](documentation-tree.md) | docs grouped by layer, work area, read mode, and gate |
| understand how docs are maintained | [Documentation map](documentation-map.md) | source-of-truth rules and placement rules |
| see groups visually | [Documentation sitemap](documentation-sitemap.md) | conceptual map of document groups |
| classify a day-to-day task | [Task router](task-router.md) | task type, expected output, required docs |
| follow a checklist for a scenario | [Reading order checklist](reading-order-checklist.md) | step-by-step path and stop conditions |
| find the implementation row | [Execution board](execution-board.md) | row, deliverable, gate, excluded scope |
| find a concrete work packet | [README Implementation Packet Index](README.md#implementation-packet-index) | PK0-PK13 packet and stop condition |
| read by phase | [Phase reading guide](phase-reading-guide.md) | minimum docs and risk add-ons |
| follow one product path | [Start-to-finish guide](start-to-finish-guide.md) | master sequence and linear path from context to release gates |
| map product capability | [Capability implementation matrix](capability-implementation-matrix.md) | train, milestone, phase, lane, gate |
| decide release slice | [Release train map](release-train-map.md) | MVP, beta, release, remote, support boundary |
| execute milestone | [Implementation runbook](implementation-runbook.md) | build sequence and exit gate |
| check global blockers | [Critical zones index](critical-zones/README.md) | release blockers and stop criteria |

## Source Of Truth Order

When two documents appear to conflict, use this order:

1. [Architecture decisions](architecture-decisions.md) for accepted system
   direction.
2. [Critical zones](critical-zones/README.md) and matching critical-zone file
   for release blockers and safety gates.
3. [Rust architecture](rust-architecture.md),
   [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md),
   [Frontend boundaries decision](frontend-boundaries-decision.md),
   [Frontend i18n localization decision](frontend-i18n-localization-decision.md),
   and
   [Future-proofing architecture gates](future-proofing-architecture-gates.md)
   for boundary-specific contracts.
4. Phase-specific implementation docs for local risks and mitigations.
5. Research and benchmark docs for evidence and alternatives.
6. Sitemap, checklists, board, matrix, and runbook for navigation only.

Navigation files can point to decisions, but they must not silently change
accepted architecture.

## From Request To Task Card

Every real work item should be reducible to this task card:

```text
Task type:
Capability:
Train:
Milestone:
Phase:
Execution board row:
Implementation packet:
Owner lane:
Required docs:
Critical gates:
Excluded scope:
Deliverable:
Evidence:
Docs to update:
```

If the task card is not fillable, the next action is documentation routing, not
implementation.

## Output Types

| Task type | Minimum output | Evidence |
| --- | --- | --- |
| research | decision options, tradeoffs, recommendation, source docs updated | source links, notes, accepted or rejected facts |
| architecture | accepted rule, dependency direction, boundary, stop rule | updated decision doc and affected index links |
| spike | small proof, measured result, risk outcome | command output, fixture, benchmark, or manual proof |
| implementation | scoped code change matching one packet or row | tests, analysis, screenshots, benchmark, or manual verification |
| cleanup/destructive | DeletePlan-safe behavior only | identity revalidation, durable intent, receipt, rollback/restore proof |
| UI | screen behavior matching references and product flow | visual verification, responsive state, accessibility notes |
| release | enabled risky capabilities proven | release checklist, critical-zone evidence, dependency gate proof |
| documentation | index and source-of-truth updates | link check, inventory check, no stale duplicate source |

## Read Depth Ladder

Use the smallest useful ladder level.

```text
0 - START_HERE only
1 - README Front Door and Request To Evidence Loop
2 - documentation tree plus sitemap
3 - task router plus capability matrix
4 - execution board plus packet index
5 - start-to-finish master sequence
6 - phase reading guide plus required phase docs
7 - matching critical zones
8 - full release/readiness docs
```

Do not jump from level 1 to implementation. At minimum, know the execution row,
packet, and gate.

## Work Packet Flow

Work packets are the practical planning unit. They sit between a broad phase and
a PR-sized implementation.

```text
Phase P1 scanner engine
  -> rows 2, 3, 4, 5
  -> packets PK1, PK2, PK3, PK4
  -> phase docs plus critical-zone docs
  -> tests or spike evidence
```

Packet discipline:

- one task should normally target one packet;
- a packet may produce several PRs, but the gate is shared;
- do not mix scan UI, cleanup, recommendations, and release work in one packet;
- if a packet touches a critical zone, the critical-zone stop rule wins.

## Document Ownership Matrix

| Information | Owner | Mirrors allowed | Do not store in |
| --- | --- | --- | --- |
| accepted architecture | architecture decisions, Rust/Flutter/frontend decisions | README summaries, START_HERE summaries | research-only docs |
| implementation order | execution board, implementation runbook | README, START_HERE, sitemap | edge-case docs |
| product slice boundaries | release train map | README, execution board | architecture research |
| phase reading bundles | phase reading guide | README, checklist | individual feature docs |
| task routing | task router, checklist | README quick router | architecture decisions |
| global blockers | critical zones | README stop rules, phase gates | ordinary UX docs |
| pdu adapter truth | pdu guide, pdu audit, pdu validation, pdu risk verification | Rust architecture summary | Flutter UI docs |
| protocol contracts | protocol DTOs, transport streaming, web runtime docs | frontend boundaries summary | UI benchmark docs |
| UI behavior | feature UX, frontend architecture, large-tree UI, design references | README task lookup | scanner docs |
| localization/i18n | frontend i18n localization decision | UI accessibility/i18n, README task lookup | domain, application, data, protocol docs |
| cleanup safety | cleanup safety, identity revalidation, reclaim research, receipt/restore critical zones | README stop rules | recommendation docs |
| release evidence | testing gates, update rollback, dependency governance | release train map summaries | exploratory research |

## Update Rules

When work changes a rule:

1. Update the source-of-truth document first.
2. Update [README](README.md) if discoverability changes.
3. Update [START_HERE](../../START_HERE.md) if the recovery context changes.
4. Update [Documentation sitemap](documentation-sitemap.md) if a group or layer
   changes.
5. Update [Execution board](execution-board.md) or
   [Capability implementation matrix](capability-implementation-matrix.md) if
   build order, ownership, or gates change.
6. Update [Critical zones](critical-zones/README.md) if a global blocker is
   added or changed.

Do not add a new document for a paragraph that belongs in an existing source of
truth.

## New Document Gate

Create a new technical document only if it has at least one of these:

- a separate failure model;
- a separate accepted decision set;
- a separate phase gate;
- a separate benchmark/spike record;
- a separate product workflow contract;
- a separate critical-zone release blocker.

After creating a new document, add it to:

1. [README Full Document Inventory](README.md#full-document-inventory).
2. The relevant [README Document Groups](README.md#document-groups).
3. [Documentation sitemap](documentation-sitemap.md).
4. [START_HERE](../../START_HERE.md) only if it changes recovery context.
5. [Critical zones](critical-zones/README.md) only if it is a global blocker.

## Conflict Resolution

Use this process when docs disagree:

1. Identify the highest source-of-truth document involved.
2. Treat lower-level docs as stale until reconciled.
3. Update the lower-level docs or replace their statement with a link to the
   source of truth.
4. If both documents are same-level decisions, stop and make the conflict
   explicit in [Architecture decisions](architecture-decisions.md) or the
   relevant decision file.
5. Do not implement based on the more convenient statement.

## Evidence Rules

Evidence must match the risk:

| Risk | Evidence |
| --- | --- |
| dependency boundary | boundary test, import check, or static analysis |
| pdu adapter behavior | fixture, benchmark, and cancellation/hardlink test |
| read-model scale | memory profile and paginated query test |
| protocol correctness | sequence, reconnect, gap, cursor, and auth tests |
| Flutter large tree | responsive render proof and no full-tree ownership |
| destructive cleanup | dry-run, revalidation, durable journal, receipt proof |
| release/update | signed identity, migration, rollback, dependency gate |
| support/privacy | redaction proof and bounded export manifest |

If evidence is not available yet, mark the feature as spike-only, preview-only,
or disabled.

## Maintenance Checklist

Run this checklist after documentation changes:

```text
1. New or changed source of truth is clear.
2. README links to any new technical file.
3. Documentation tree contains the file.
4. Sitemap group contains the file.
5. START_HERE mentions only recovery-critical changes.
6. Execution board or capability matrix is updated only if order/gate changed.
7. Critical-zone index is updated only for global blockers.
8. Local markdown links resolve.
9. No broad research is copied as an accepted decision without approval.
```

## Practical Examples

### Build pdu adapter

```text
Task router -> scanner task
Capability matrix -> scanner adapter
Execution board -> row 3
Packet index -> PK2
Phase docs -> pdu guide, pdu risk verification, pdu audit
Critical gates -> Rust runtime if execution/cancellation is touched
Evidence -> fixtures, adapter isolation, cancellation behavior
```

### Build scan tree UI

```text
Task router -> Flutter UI task
Capability matrix -> scan tree/table
Execution board -> row 9
Packet index -> PK6
Phase docs -> feature UX, frontend architecture, large-tree UI
Critical gates -> none unless cleanup action is wired
Evidence -> responsive UI, paginated queries, stable node IDs
```

### Add cleanup execution

```text
Task router -> cleanup task
Capability matrix -> cleanup execution
Execution board -> row 12
Packet index -> PK9
Phase docs -> cleanup safety, local persistence, storage accounting
Critical gates -> receipt durability, restore safety
Evidence -> durable intent before side effects and per-item receipts
```

### Prepare release

```text
Task router -> release task
Capability matrix -> release readiness
Execution board -> rows 14 and 17
Packet index -> PK11
Phase docs -> testing gates, dependency governance, packaging
Critical gates -> update rollback and every enabled risky feature
Evidence -> release checklist and gate proof
```
