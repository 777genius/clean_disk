# Technical Documentation

This folder is the durable technical memory for Clean Disk.

Use this index as the canonical map for what to read, in what order, and which
documents gate implementation work. `START_HERE.md` is the short recovery file;
this file is the full technical navigation.

Do not record brainstormed options as accepted decisions until they are
explicitly accepted.

## One Screen Map

If you remember only one workflow, use this:

```text
User/task request
  -> START_HERE for current context
  -> Documentation operating manual for how to use the docs
  -> Documentation tree if you need visual structure
  -> Task router for task type
  -> Capability matrix for train, milestone, phase, lane, gate
  -> Execution board for exact build row and excluded scope
  -> Implementation Packet Index for concrete work packet
  -> Phase reading guide for minimum docs and risk add-ons
  -> Critical zones if the row touches risky safety areas
  -> Implementation runbook for milestone execution
  -> Tests/evidence before moving forward
```

Do not start implementation until these fields are known:

```text
task type
capability
train
milestone
phase
owner lane
execution-board row
gate
excluded scope
evidence
```

## Request To Evidence Loop

Use this loop for any implementation, research, review, or documentation task.
It is stricter than the reading order because it forces the output and proof to
be known before work starts.

| Step | Do | Open | Output |
| --- | --- | --- | --- |
| 1 | recover current context | [START_HERE](../../START_HERE.md) | known scope and accepted runtime direction |
| 2 | classify the task | [Task router](task-router.md) | task type and expected output |
| 3 | map product capability | [Capability implementation matrix](capability-implementation-matrix.md) | train, milestone, phase, lane, gate |
| 4 | choose implementation row | [Execution board](execution-board.md) | exact row, deliverable, excluded scope |
| 5 | choose work packet | [Implementation Packet Index](#implementation-packet-index) | packet PK0-PK13 and stop condition |
| 6 | read only the minimum docs | [Phase reading guide](phase-reading-guide.md) | required docs and risk add-ons |
| 7 | check blockers | [Critical zones index](critical-zones/README.md) | safety, privacy, release, or runtime gates |
| 8 | execute the slice | [Implementation runbook](implementation-runbook.md) | implementation steps and exit gate |
| 9 | produce evidence | phase docs and tests | tests, spike output, manual proof, or doc update |
| 10 | update durable memory | [Documentation map](documentation-map.md) | accepted changes are stored in the right doc |

Do not pick documents by filename alone. Pick task type, capability, row, and
packet first; then read the documents those choices require.

## Decision Funnel

Use this funnel to avoid reading too much or coding from the wrong document.

| Step | Question | Open | Result |
| --- | --- | --- | --- |
| 1 | What is the current project state? | [START_HERE](../../START_HERE.md) | current scope and accepted architecture |
| 2 | What kind of task is this? | [Task router](task-router.md) | task type, required docs, gate, expected output |
| 3 | Which product capability is affected? | [Capability implementation matrix](capability-implementation-matrix.md) | train, milestone, phase, lane, excluded scope |
| 4 | Which build row owns the next action? | [Execution board](execution-board.md) | deliverable, docs, gate, do-not-pull-in list |
| 5 | Which concrete work packet owns this slice? | [Implementation Packet Index](#implementation-packet-index) | packet, stop condition, and packet docs |
| 6 | What is the minimum reading bundle? | [Phase reading guide](phase-reading-guide.md) | minimum docs and risk add-ons |
| 7 | What product slice allows this? | [Release train map](release-train-map.md) | MVP/beta/release/remote boundary |
| 8 | How do we execute the milestone? | [Implementation runbook](implementation-runbook.md) | build sequence and exit gate |
| 9 | What can block release or safety? | [Critical zones index](critical-zones/README.md) | global gates and stop criteria |

## Index Structure

This README is organized from broad navigation to detailed inventory.

| Section | Use it for |
| --- | --- |
| Request To Evidence Loop | moving from request to output and proof |
| Front Door | fastest entry by situation |
| Document Layer Model | understanding the document stack from context to gates |
| Navigation Files At A Glance | deciding which navigation file owns the question |
| Reading Depth | choosing how much to read |
| Quick Router | jumping to the right first doc |
| Navigation Stack | canonical order of navigation files |
| Dependency Flow | high-level P0-P8 dependency order |
| Phase/Row/Capability Crosswalk | mapping from phase to execution rows, capabilities, docs, and gates |
| Implementation Packet Index | concrete work packets between roadmap phases and PR-sized tasks |
| End-To-End Build Roadmap | compact implementation roadmap |
| Work Lanes And Ownership | deciding which layer owns the work |
| Mandatory Reading Bundles | minimum docs by work item |
| Stop Rules | conditions that block implementation |
| Fast Path | full recovery path without chat history |
| Implementation Order | phase-by-phase docs and outputs |
| Phase Gate Matrix | start and exit gates per phase |
| Document Groups | docs grouped by technical area |
| Full Document Inventory | every technical doc, phase, type, purpose |
| Critical Zones | global release blockers |
| Where To Look By Task | task-specific lookup table |

## Document Layer Model

The documentation is intentionally layered. Higher layers route work; lower
layers prove details and block unsafe shortcuts.

```text
L0 context
  START_HERE.md

L1 navigation
  README.md
  documentation-map.md
  documentation-operating-manual.md
  documentation-tree.md
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

Layer rules:

- L0-L2 decide what to open and what to build.
- L3 decides dependency direction and accepted architecture.
- L4 explains implementation risks by area.
- L5 can block any lower-risk plan.
- L6 informs UI/product shape but does not override gates.

## Front Door

If you are not sure where to start, use this section only.

| Situation | Open | Outcome |
| --- | --- | --- |
| no chat history, need current context | [START_HERE](../../START_HERE.md) | understand current scope and accepted architecture |
| need to understand how all docs are operated | [Documentation operating manual](documentation-operating-manual.md) | request-to-evidence loop, source-of-truth order, task card, update rules |
| need visual tree of all docs | [Documentation tree](documentation-tree.md) | layered tree by navigation, architecture, scanner, protocol, UI, cleanup, release, and gates |
| need the build board from zero to release | [Execution board](execution-board.md) | exact row, docs, deliverable, gate, and excluded scope |
| need checkbox order for a scenario | [Reading order checklist](reading-order-checklist.md) | step-by-step docs, output, gates, and stop conditions |
| know task type, need exact docs | [Task router](task-router.md) | task steps, required docs, gate, expected output |
| know product capability, need owner and gate | [Capability implementation matrix](capability-implementation-matrix.md) | train, milestone, phase, lane, gate, excluded scope |
| know current phase, need reading list | [Phase reading guide](phase-reading-guide.md) | minimum docs, risk add-ons, output, do-not-pull-forward rules |
| need one path from zero to release | [Start-to-finish guide](start-to-finish-guide.md) | master sequence, linear product path, and first implementation packets |
| need implementation order | [Implementation runbook](implementation-runbook.md) | milestones, build output, exit gates |
| need strict Clean Architecture phase order | [Clean Architecture implementation phases](clean-architecture-implementation-phases.md) | phase-by-phase steps, gates, stop rules, and first implementation slice that protects domain/application boundaries |
| need product slice boundaries | [Release train map](release-train-map.md) | MVP, beta, release, remote/headless boundaries |
| before writing Rust scanner/pdu code | [Pre-coding pdu architecture research](pre-coding-pdu-architecture-research.md) | source-audited pdu facts, Clean Architecture crate shape, DDD boundaries, global stop rules |
| starting the first Rust scanner PR | [pdu implementation start gate](pdu-implementation-start-gate.md) | compact must-read gate for pdu source facts, layer contracts, SOLID mapping, stop gates, and first PR shape |
| reviewing pdu usage across layers | [pdu cross-layer contract matrix](pdu-cross-layer-contract-matrix.md) | pdu internals mapped to domain, application, infrastructure, protocol, Flutter, data flow, cleanup, and review gates |
| deciding pdu-backed scan data flow | [pdu data flow architecture contract](pdu-data-flow-architecture-contract.md) | end-to-end scan flow, ownership, command/query/event split, read-model publication, cleanup authority boundaries |
| designing the pdu domain/infrastructure boundary | [pdu domain infrastructure contract blueprint](pdu-domain-infrastructure-contract-blueprint.md) | practical Rust module blueprint for domain, application, pdu adapter, platform facts, data flow, and first scanner skeleton |
| deciding disk visual map renderer | [Disk usage map adapter decision](disk-usage-map-view-adapter.md) | `DiskUsageMapView`, bounded map projections, optional Syncfusion adapter |
| deciding what Headless/UI components Clean Disk must build first | [Headless Clean Disk priority index](headless-clean-disk-priority-index.md) | critical component order, MVP scope, future architecture gates, and time sink stop rules |
| designing Headless tree/table primitive | [Headless TreeGrid primitive design](headless-tree-grid-primitive-design.md) | reusable treegrid behavior, virtualization, accessibility, renderer contracts, and Clean Disk integration |
| designing Headless public primitives | [Headless primitive RFC index](headless-primitives/README.md) | collection/grid/tree foundations, TreeGrid, SplitPane, ContextMenu, Dialog, Tooltip, StatusRegion, button/menu/split button, form fields, checkbox/radio/switch, slider/spinbutton, select/listbox, breadcrumb navigation, links/navigation, alerts/toasts, icons/images, badges/chips, pagination/load-more, empty/skeleton states, skip/bypass navigation, side navigation/drawer/rail, popover/floating panels, drawer/sheet/side panels, wizard/stepper workflows, file picker/dropzone/path targets, query/filter/sort surfaces, data summary metrics, property/details inspectors, command discovery/shortcut help, destructive action safety affordances, native menubar/app commands, motion/reduced animation, contrast/color-scheme/theme adaptation, route/focus/history restoration, undo/redo operation history, export/print/report snapshots, multi-window/session scopes, live announcement broker, capability/permission progressive enhancement, locale/unit/quantity formatting, zoom/density/target size, degraded/offline/partial availability, instrumentation/telemetry privacy budget, user intent/command provenance, untrusted content sanitization, recoverable error assistance, versioned state migration, safe-area/orientation/viewport, automation/test driver boundaries, semantic identity/reference stability, command routing/scope arbitration, nested interactive composition, sticky/scroll anchoring geometry, screen-reader browse/focus mode, third-party renderer trust, semantic diff/change announcements, operation lifecycle/cancellation/retry, cognitive load/progressive disclosure, evidence/confidence/uncertainty, cross-adapter semantic parity, extension lifecycle/deprecation compatibility, accessibility-tree snapshot regression, ARIA role/attribute linting, personalization preference profiles, localization/bidi stress corpus, semantic API review/release gates, support feedback/defect triage, data-transfer payload governance, keyboard layout/dead-key shortcuts, virtualized collection metadata, policy/feature flag evaluation, cross-window transfer trust, visual/semantic diff alignment, accessibility exception waivers, executable documentation examples, deterministic time/scheduler tests, render failure containment, property-based fuzz conformance, privacy-safe evidence capture, WCAG2ICT native app profiles, accessibility-supported technology policy, ACT rule integration, ACR/VPAT evidence reporting, platform role/action mapping, assistive technology transcript correlation, native semantic preference/ARIA minimization, host boundary iframe/shadow/portal rules, accessibility event ordering/cache invalidation, assistive technology workaround governance, misuse diagnostics/dev warnings, public fixture pack interoperability, platform accessibility settings adapters, switch access/linear scanning, voice control/speech commands, magnifier visual viewport reflow, closed functionality/kiosk runtime, assistive API permission/privacy boundaries, braille display output, screen-reader rotor/quick navigation, touch screen-reader exploration, dictation text input/correction, captions/transcripts/status media, adaptive symbols/plain language, regulatory procurement standards profiles, native accessibility API family contracts, AOM experimental boundaries, accessibility inspector debug evidence, localized accessible name catalogs, assistive technology compatibility lifecycle, accessible authentication/pairing, credential autofill/passkey forms, browser permission prompt orchestration, web filesystem picker/origin storage, local daemon network access, PWA service worker install/offline boundaries, web notification permission/attention, spatial navigation/D-pad, gamepad/remote input, fullscreen lock/immersive modes, text selection/find-in-page, accessible export artifacts, native shell integration/status, haptic vibration feedback, speech synthesis audio output, dwell/eye-tracking activation, virtual keyboard input viewport, writing assistance/spellcheck/translation, sensor motion/orientation permissions, path/filename semantic display, technical identifiers/error codes, code/preformatted/log output, abbreviation/definition terms, quantity/byte/unit semantics, time/date/duration recency, data table caption/header association, meter/comparison value indicators, description/details/help associations, inline annotation/highlight/revision semantics, figure/media caption/fallback semantics, mathematical expression/formula semantics, list/feed/result-set semantics, document outline/section/heading semantics, receipt/report document semantics, machine-readable metadata/provenance, audit timeline/event feed semantics, search result count/navigation semantics, structured evidence/chain-of-custody semantics, faceted filter taxonomy semantics, grouping/aggregation summary semantics, comparison baseline/delta semantics, bulk selection scope/preview semantics, column view preset/layout personalization, responsive card-grid alternate view semantics, severity/risk/threshold/trend semantics, row action menu/action cell semantics, master-detail preview panel semantics, command palette execution safety, reorderable drag-drop keyboard semantics, status footer activity region semantics, resizable pane layout persistence, async collection cursor window contracts, operation center task queues, notification inbox attention management, guided repair onboarding coachmarks, scope context authority banners, overlay layer stack z-order contracts, design token semantic theme bridges, dense target focus visibility, segmented control toggle groups, date time range picker filters, overflow truncation tooltip disclosure, scroll container keyboard affordances, modal focus return stacks, selection activation intent separation, inline edit commit cancel flows, command bars, tabs/disclosure, progress/log/status, landmarks, visualization accessibility, label-in-name, reducer/effect internals, semantics adapters, names/descriptions, IME/editing, focus algorithms, selection, combobox/search, state semantics, validation, timing/data loss, pointer/drag alternatives, async loading, clipboard privacy, conformance, compliance playbooks, public extension rules, and web ARIA bridge |
| deciding Flutter state and MobX stores | [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md) | responsibility zones, stores, lifecycle, identity, Observer and reaction rules |
| deciding frontend DTO/command/design-system boundaries | [Frontend boundaries decision](frontend-boundaries-decision.md) | DTO mapping, command flow, authority, events, persistence, platform actions, responsive boundaries |
| deciding Flutter i18n and localization | [Frontend i18n localization decision](frontend-i18n-localization-decision.md) | official gen-l10n, shared localization package, and presentation-only boundary |
| need source-of-truth rules | [Documentation map](documentation-map.md) | where decisions, research, gates, and new docs belong |
| need to see all docs as a structure | [Documentation sitemap](documentation-sitemap.md) | grouped map of navigation, architecture, scanner, protocol, UI, cleanup, release, remote, and gates |
| touching risky safety area | [Critical zones index](critical-zones/README.md) | global release gates and stop criteria |

Do not read every document before coding. Pick the task, capability, train, and
gate first; then open only the required bundle.

## Navigation Files At A Glance

These files are intentionally separate:

| File | Owns | Does not own |
| --- | --- | --- |
| [START_HERE](../../START_HERE.md) | short recovery context | full inventory |
| [README](README.md) | complete technical index | detailed task execution |
| [Documentation operating manual](documentation-operating-manual.md) | how to move from request to evidence and maintain docs | product implementation details |
| [Documentation tree](documentation-tree.md) | visual tree of docs by layer and work area | source-of-truth decisions |
| [Documentation sitemap](documentation-sitemap.md) | visual map of the documentation set | task routing |
| [Task router](task-router.md) | day-to-day task routing | product release boundaries |
| [Reading order checklist](reading-order-checklist.md) | scenario checklists for reading and action order | source-of-truth decisions |
| [Execution board](execution-board.md) | row-by-row implementation board from zero to release | detailed edge cases |
| [Phase reading guide](phase-reading-guide.md) | phase-by-phase minimum reading and gates | product capability ownership |
| [Capability implementation matrix](capability-implementation-matrix.md) | capability-to-train/milestone/phase/lane/gate mapping | milestone details |
| [Start-to-finish guide](start-to-finish-guide.md) | master sequence and one linear route through the product | every edge case |
| [Implementation runbook](implementation-runbook.md) | milestone execution order | product scope decisions |
| [Release train map](release-train-map.md) | product train boundaries | code-level sequence |
| [Documentation map](documentation-map.md) | source-of-truth and doc maintenance rules | product implementation details |
| [Critical zones index](critical-zones/README.md) | global release blockers | ordinary feature behavior |

## Reading Depth

Use the smallest useful depth.

| Time budget | Read | Stop when |
| --- | --- | --- |
| 2 minutes | [START_HERE](../../START_HERE.md) and Front Door | you know the current scope |
| 10 minutes | [Documentation operating manual](documentation-operating-manual.md), [Documentation tree](documentation-tree.md), [Task router](task-router.md), [Reading order checklist](reading-order-checklist.md), [Execution board](execution-board.md), [Documentation sitemap](documentation-sitemap.md), [Start-to-finish guide](start-to-finish-guide.md) | you know task type, checklist path, execution row, doc structure, and product path |
| 20 minutes | [Phase reading guide](phase-reading-guide.md), [Capability matrix](capability-implementation-matrix.md), [Release train map](release-train-map.md), [Implementation runbook](implementation-runbook.md), [Execution board](execution-board.md) | you know train, milestone, phase, lane, gate, row, and deliverable |
| task depth | the phase docs and critical-zone docs referenced by the row | you know what to implement and what is excluded |
| release depth | [Testing quality gates](implementation-edge-cases-testing-quality-gates.md) and relevant critical zones | enabled risky features have evidence |

## How To Use This Index

Use this file in ten modes:

1. **Recover context** - read Fast Path, then the phase you are about to touch.
   If you do not understand the documentation structure itself, read
   [Documentation operating manual](documentation-operating-manual.md),
   [Documentation tree](documentation-tree.md),
   [Documentation map](documentation-map.md), and
   [Documentation sitemap](documentation-sitemap.md).
2. **Follow one path from zero to release** - read
   [Start-to-finish guide](start-to-finish-guide.md), then use this index for
   the detailed document bundle.
3. **Route a product capability** - read
   [Capability implementation matrix](capability-implementation-matrix.md) to
   map a capability to train, milestone, phase, lane, gate, and excluded scope.
4. **Route a day-to-day task** - read [Task router](task-router.md) when you
   know the task type, such as docs, pdu adapter, UI, cleanup, release, or PR
   review.
5. **Follow a scenario checklist** - read
   [Reading order checklist](reading-order-checklist.md) when you want
   checkbox-style order for zero context, scan-only MVP, cleanup beta,
   recommendations, release, remote/headless, support, or review.
6. **Pick the execution row** - read [Execution board](execution-board.md) when
   you need the next build row, deliverable, gate, and excluded scope from zero
   to release.
7. **Implement a feature** - find the phase, read its required docs, then check
   the phase gate before coding. For execution details, use
   [Implementation runbook](implementation-runbook.md).
8. **Pick a concrete work packet** - use Implementation Packet Index when the
   phase is known but the next implementation slice is still too broad.
9. **Plan a product slice** - choose the active train in
   [Release train map](release-train-map.md), then use the runbook for the
   implementation sequence.
10. **Review or release** - start from Critical Zones, then Testing And Critical
   Research, then the affected phase.

Document type legend:

- **Decision** - accepted direction and contracts.
- **Validation** - why the accepted direction fits the product.
- **Research** - source-backed investigation or comparison.
- **Spike** - focused unknown that must be proven before implementation.
- **Edge case** - failure modes, mitigations, and test cases.
- **Critical gate** - release blocker for risky work.
- **UX contract** - product workflow, behavior, and design constraints.
- **Reference** - saved visual or future adapter idea.

## Quick Router

Use this table before reading the full index.

| Question | Open first | Then open |
| --- | --- | --- |
| I have no context | [Start Here](../../START_HERE.md) | [Start-to-finish guide](start-to-finish-guide.md) |
| I do not understand how to use the docs | [Documentation operating manual](documentation-operating-manual.md) | README Front Door and sitemap |
| I need a visual tree of docs | [Documentation tree](documentation-tree.md) | sitemap and README Document Groups |
| I need the next build row | [Execution board](execution-board.md) | task router and capability matrix for the row |
| I need a concrete implementation packet | [Implementation Packet Index](#implementation-packet-index) | execution board row and phase docs for that packet |
| I want checklist-style order | [Reading order checklist](reading-order-checklist.md) | task router and capability matrix for the chosen scenario |
| I need one path from zero to release | [Start-to-finish guide](start-to-finish-guide.md) | master sequence, then [Implementation runbook](implementation-runbook.md) |
| I know the task type but not the docs | [Task router](task-router.md) | capability matrix and required docs from the row |
| I want to build a capability | [Capability implementation matrix](capability-implementation-matrix.md) | phase docs and critical gates from the row |
| I know the phase but not what to read | [Phase reading guide](phase-reading-guide.md) | minimum docs and risk add-ons for the phase |
| I need to structure Flutter stores | [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md) | [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md) |
| I need to keep widgets/stores/adapters cleanly separated | [Frontend boundaries decision](frontend-boundaries-decision.md) | [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md) |
| I need localization/i18n | [Frontend i18n localization decision](frontend-i18n-localization-decision.md) | [Implementation edge cases UI accessibility and i18n](implementation-edge-cases-ui-accessibility-i18n.md) |
| I need to choose MVP, beta, release, or remote scope | [Release train map](release-train-map.md) | [Implementation runbook](implementation-runbook.md) |
| I need to choose treemap/sunburst/chart renderer | [Disk usage map adapter decision](disk-usage-map-view-adapter.md) | [Feature UX benchmark](feature-ux-benchmark.md) |
| I need to know where a decision belongs | [Documentation map](documentation-map.md) | the source-of-truth document for the topic |
| I need a visual map of all docs | [Documentation sitemap](documentation-sitemap.md) | the specific group for your task |
| I need to implement the next technical step | [Implementation runbook](implementation-runbook.md) | [Capability implementation matrix](capability-implementation-matrix.md) |
| I touch cleanup, commands, remote, support, update, or release | [Critical zones index](critical-zones/README.md) | the matching critical-zone file |

## Navigation Stack

```text
START_HERE.md
  -> README.md
  -> documentation-operating-manual.md
  -> documentation-tree.md
  -> documentation-sitemap.md
  -> task-router.md
  -> capability-implementation-matrix.md
  -> execution-board.md
  -> README Implementation Packet Index
  -> reading-order-checklist.md
  -> phase-reading-guide.md
  -> start-to-finish-guide.md
  -> release-train-map.md
  -> implementation-runbook.md
  -> phase documents
  -> critical-zone gates
```

Use the stack top-down. Do not jump from broad research directly into
implementation unless the capability row and gate are clear.

## Dependency Flow

Read and implement in this dependency order:

```text
P0 baseline decisions
  -> P1 Rust scanner engine and read model
  -> P2 daemon protocol and runtime
  -> P3 Flutter UI and product workflows
  -> P4 cleanup safety, receipts, and reclaim truth
  -> P5 recommendations and tool cleanup adapters
  -> P6 packaging, permissions, signing, updates
  -> P7 remote/headless, diagnostics, support
  -> P8 testing, quality gates, release readiness
```

Cross-cutting rule:

```text
critical zones can block any phase
```

If a phase touches a critical zone, the critical-zone file overrides convenience,
speed, and implementation shortcuts.

## Phase/Row/Capability Crosswalk

Use this table before opening detailed phase docs. It shows how the main
navigation systems connect.

| Phase | Execution rows | Capability rows | Open first | Exit gate |
| --- | --- | --- | --- | --- |
| P0 baseline | 0, 1 | project recovery, architecture baseline | [START_HERE](../../START_HERE.md), [Documentation map](documentation-map.md), [Architecture decisions](architecture-decisions.md), [Future-proofing gates](future-proofing-architecture-gates.md), [Rust architecture](rust-architecture.md) | architecture, scope, docs, and dependency direction are discoverable |
| P1 scanner engine | 2, 3, 4, 5 | Rust crate skeleton, pdu adapter, scan read model, search/sort/filter | [Pre-coding pdu architecture research](pre-coding-pdu-architecture-research.md), [Rust architecture](rust-architecture.md), [pdu data model guide](pdu-data-model-and-adapter-guide.md), [pdu Clean Architecture contract](pdu-clean-architecture-contract.md), [pdu risk verification](pdu-critical-risk-verification.md), [Performance scale](implementation-edge-cases-performance-scale.md), [Rust runtime critical zone](critical-zones/rust-runtime-execution.md) | pdu is isolated, memory is bounded, scanner work has safe execution lanes |
| P2 protocol/runtime | 6, 7 | scan protocol, daemon-served local web UI, search/sort/filter protocol | [Protocol DTOs](implementation-edge-cases-protocol-data-contracts.md), [Transport streaming](implementation-edge-cases-transport-protocol-streaming.md), [Concurrency state machines](implementation-edge-cases-concurrency-state-machines.md), [Web UI daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md) | sessions, DTOs, cursors, reconnect, auth, and backpressure are explicit |
| P3 Flutter UI | 8, 9 | Flutter scan shell, design-system primitives, scan permissions UX | [Feature UX benchmark](feature-ux-benchmark.md), [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md), [Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md), [Design references](../design/references/clean-disk-wide-reference.png) | UI uses paginated Rust queries, stable node IDs, and saved design references |
| P4 cleanup safety | 11, 12 | cleanup preview, reclaim estimate, Trash execution, receipt and operation journal | [Cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md), [Platform identity revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md), [Reclaim accounting](reclaim-accounting-deep-research.md), [Receipt durability](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md), [Restore safety](critical-zones/restore-quarantine-undo-safety.md) | no side effect without DeletePlan, identity revalidation, durable intent, and receipt |
| P5 recommendations/tools | 13 | recommendation cards, official cleanup commands | [Recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md), [Tool-managed storage](implementation-edge-cases-tool-managed-storage.md), [Rule-pack safety](critical-zones/recommendation-policy-rule-pack-safety.md), [Command sandbox](critical-zones/tool-command-execution-sandbox.md) | recommendations and commands cannot bypass DeletePlan or receipts |
| P6 packaging/release identity | 10, 14 | scan permissions UX, scan-only packaging, signed desktop release, dependency governance | [Platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md), [Permission UX playbook](permission-ux-playbook.md), [Dependency governance](implementation-edge-cases-dependency-supply-chain-governance.md), [Update rollback safety](critical-zones/update-release-rollback-safety.md) | signed scanner identity, permission probe, updates, rollback, and dependency gates are proven |
| P7 remote/support | 15, 16 | remote/headless read-only, diagnostics and support bundle | [Remote headless mode](implementation-edge-cases-remote-headless-mode.md), [Security privacy](implementation-edge-cases-security-privacy.md), [Diagnostics support](implementation-edge-cases-diagnostics-observability-support.md), [Remote destructive authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md), [Support privacy](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md) | remote is read-only by default, scoped, audited, and support export is redacted |
| P8 release readiness | 17 | release readiness | [Testing quality gates](implementation-edge-cases-testing-quality-gates.md), [Critical zones index](critical-zones/README.md), [Implementation runbook](implementation-runbook.md) | every enabled risky capability has test or manual release evidence |

If a task crosses rows, use the earliest row for dependencies and the
highest-risk row for gates. Example: Flutter cleanup queue starts in P3, but
P4 cleanup gates decide whether it is allowed to trigger side effects.

## Implementation Packet Index

Use packets when a task needs a concrete next slice, not a broad phase. A
packet is smaller than a phase and larger than a single PR.

Packet rule:

- choose one packet per task;
- if a packet touches cleanup, remote, commands, support, update, or release,
  open the matching critical zone;
- do not mix packets unless the dependency is already gated;
- if the packet cannot name its execution-board rows, gate, excluded scope, and
  evidence, return to [Execution board](execution-board.md).

| Packet | Rows | Build | Read first | Stop when |
| --- | --- | --- | --- | --- |
| PK0 docs baseline | 0, 1 | recover docs, architecture, accepted decisions | [START_HERE](../../START_HERE.md), [Documentation map](documentation-map.md), [Execution board](execution-board.md), [Architecture decisions](architecture-decisions.md) | task coordinates are known and docs are indexed |
| PK1 Rust skeleton | 2 | `fs_usage_*` skeleton, ports, `clean-disk-server` shell | [Rust architecture](rust-architecture.md), [Rust best practices](rust-best-practices.md), [Rust runtime critical zone](critical-zones/rust-runtime-execution.md) | core has no pdu, HTTP, Flutter, SQLite, process API, or generated-code imports |
| PK2 pdu adapter | 3 | pdu adapter, option mapping, fixtures | [pdu data model guide](pdu-data-model-and-adapter-guide.md), [pdu Clean Architecture contract](pdu-clean-architecture-contract.md), [pdu risk verification](pdu-critical-risk-verification.md), [pdu audit](pdu-required-capabilities-audit.md) | only the adapter imports `parallel_disk_usage` |
| PK3 read model | 4 | compact arena, node IDs, indexes, pagination | [Performance scale](implementation-edge-cases-performance-scale.md), [Filesystem model](implementation-edge-cases-filesystem-model.md), [Search query indexing](implementation-edge-cases-search-query-indexing.md) | Flutter cannot receive the full tree |
| PK4 scanner runtime | 5 | worker lanes, cancellation, resource profiles | [Rust runtime critical zone](critical-zones/rust-runtime-execution.md), [Resource governance](implementation-edge-cases-resource-governance.md), [Operational reliability](implementation-edge-cases-operational-reliability.md) | blocking work and shutdown are tested |
| PK5 protocol | 6, 7 | DTOs, sessions, HTTP queries, WebSocket events | [Protocol DTOs](implementation-edge-cases-protocol-data-contracts.md), [Transport streaming](implementation-edge-cases-transport-protocol-streaming.md), [Web runtime](implementation-edge-cases-web-ui-daemon-runtime.md) | reconnect, backpressure, auth, cursors, and event gaps are explicit |
| PK6 scan UI | 8, 9 | shell, tree/table, details, search, progress, compact layout | [Feature UX benchmark](feature-ux-benchmark.md), [Flutter frontend architecture](flutter-frontend-architecture-decision.md), [Large-tree UI](implementation-edge-cases-flutter-large-tree-ui.md), [Design references](../design/references/clean-disk-wide-reference.png) | UI uses paginated Rust queries and stable node IDs |
| PK7 scan-only packaging | 10 | signed scanner identity, permission probe, packaging spike | [Platform packaging](implementation-edge-cases-platform-permissions-packaging.md), [Permission UX](permission-ux-playbook.md), [Update rollback](critical-zones/update-release-rollback-safety.md) | probe and scanner share identity |
| PK8 cleanup preview | 11 | DeletePlan preview, identity revalidation dry-run, reclaim confidence | [Cleanup safety](implementation-edge-cases-cleanup-delete-safety.md), [Identity revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md), [Reclaim research](reclaim-accounting-deep-research.md) | no destructive adapter is called |
| PK9 cleanup execution | 12 | journal, receipts, Trash adapter, crash recovery | [Receipt durability](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md), [Restore safety](critical-zones/restore-quarantine-undo-safety.md), [Local persistence](implementation-edge-cases-local-state-persistence.md) | durable intent exists before side effects |
| PK10 recommendations/tools | 13 | rule packs, evidence, official command adapters | [Recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md), [Tool-managed storage](implementation-edge-cases-tool-managed-storage.md), [Command sandbox](critical-zones/tool-command-execution-sandbox.md) | no recommendation bypasses DeletePlan |
| PK11 release hardening | 14, 17 | signing, updates, rollback, dependency gates, release tests | [Dependency governance](implementation-edge-cases-dependency-supply-chain-governance.md), [Testing gates](implementation-edge-cases-testing-quality-gates.md), [Critical zones](critical-zones/README.md) | risky features have evidence |
| PK12 remote read-only | 15 | scoped remote/headless read-only service | [Remote mode](implementation-edge-cases-remote-headless-mode.md), [Security/privacy](implementation-edge-cases-security-privacy.md), [Remote destructive auth boundary](critical-zones/remote-headless-destructive-cleanup-authorization.md) | remote cleanup remains disabled |
| PK13 support operations | 16, 17 | diagnostics, support bundle, privacy, release evidence | [Diagnostics support](implementation-edge-cases-diagnostics-observability-support.md), [Support privacy](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md), [Local persistence](implementation-edge-cases-local-state-persistence.md) | export is typed, redacted, bounded, and consented |

## End-To-End Build Roadmap

This is the practical order for building the product from zero to release. The
phase sections below explain the documents in more detail; this table tells you
what to do next.

For the detailed row-by-row implementation board, use
[Execution board](execution-board.md). This table is the compact roadmap; the
board is the operational checklist with deliverables, gates, and excluded
scope.

| Step | Build objective | Read first | Gate before moving on |
| --- | --- | --- | --- |
| 0.1 | confirm workspace, package boundaries, and accepted architecture | [Start Here](../../START_HERE.md), [Task router](task-router.md), [Reading order checklist](reading-order-checklist.md), [Start-to-finish guide](start-to-finish-guide.md), [Capability implementation matrix](capability-implementation-matrix.md), [Architecture decisions](architecture-decisions.md), [Rust architecture](rust-architecture.md) | architecture fits Clean Architecture and crate boundaries |
| 0.2 | decide what is MVP and what stays future-only | [Release train map](release-train-map.md), [Architecture fit validation](architecture-fit-validation.md), [Architecture future risks](architecture-future-risks.md), [Future-proofing architecture gates](future-proofing-architecture-gates.md) | no FRB, gRPC, Socket.IO, local microservices, or hosted remote cleanup sneaks into MVP |
| 1.1 | create Rust workspace/crates and runtime skeleton | [Rust architecture](rust-architecture.md), [Rust best practices research](rust-best-practices.md) | domain/application stay independent from pdu, HTTP, Flutter, SQLite |
| 1.2 | implement pdu adapter spike contract | [pdu data model and adapter guide](pdu-data-model-and-adapter-guide.md), [pdu Clean Architecture contract](pdu-clean-architecture-contract.md), [pdu critical risk verification](pdu-critical-risk-verification.md), [pdu required capabilities audit](pdu-required-capabilities-audit.md) | pdu is only imported by adapter crate |
| 1.3 | implement read-model arena, node ids, indexes, and pagination | [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md), [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md) | Flutter never receives or stores full tree |
| 1.4 | harden scanner runtime lanes | [Critical zone Rust runtime execution](critical-zones/rust-runtime-execution.md) | blocking work, cancellation, panic, shutdown, and bounded channels are proven |
| 2.1 | define protocol DTOs and versioning | [Implementation edge cases protocol data contracts](implementation-edge-cases-protocol-data-contracts.md) | large counters, IDs, cursors, paths, timestamps, and enums are web-safe |
| 2.2 | implement HTTP queries and WebSocket events | [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md), [Transport and client generation research](transport-client-generation-research.md) | reconnect, sequence, backpressure, and resync behavior are explicit |
| 2.3 | implement daemon-served local web/runtime shell | [Implementation edge cases web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md) | loopback token, origin policy, port discovery, and service worker policy are safe |
| 3.1 | build Flutter shell and design-system facade | [Feature UX benchmark](feature-ux-benchmark.md), [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md) | UI follows references and reports Headless gaps |
| 3.2 | build scan tree/table, details, search, filters, progress | [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md), [Cross-platform user experience playbook](cross-platform-user-experience-playbook.md), [Real product feature adoption playbook](real-product-feature-adoption-playbook.md) | UI uses paginated Rust queries and clear scan-quality states |
| 4.1 | implement DeletePlan and identity revalidation | [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md), [Implementation edge cases platform identity and delete revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md) | stale UI row or path cannot trigger side effects |
| 4.2 | implement receipts, journal, crash recovery, low-disk reserve | [Critical zone persistent operation journal receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md), [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md) | if cleanup truth cannot be written, cleanup cannot run |
| 4.3 | implement reclaim confidence model | [Reclaim accounting deep research](reclaim-accounting-deep-research.md), [Implementation edge cases storage accounting snapshots shared extents](implementation-edge-cases-storage-accounting-snapshots-shared-extents.md) | UI never promises exact freed bytes without proof |
| 4.4 | implement restore/quarantine semantics | [Critical zone restore quarantine undo safety](critical-zones/restore-quarantine-undo-safety.md) | restore capability is shown honestly by platform and adapter |
| 5.1 | implement recommendation/rule engine | [Implementation edge cases recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md), [Critical zone recommendation policy rule-pack safety](critical-zones/recommendation-policy-rule-pack-safety.md) | recommendations are evidence-backed and risk-tiered |
| 5.2 | implement official tool cleanup adapters | [Implementation edge cases tool-managed storage](implementation-edge-cases-tool-managed-storage.md), [Critical zone tool command execution sandbox](critical-zones/tool-command-execution-sandbox.md) | command identity, env, args, output, timeout, and receipt are governed |
| 6.1 | package app/helper/daemon and permissions | [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md), [Permission UX playbook](permission-ux-playbook.md) | signed identity and real scanner permission probe are stable |
| 6.2 | implement update, rollback, and dependency gates | [Critical zone update release rollback safety](critical-zones/update-release-rollback-safety.md), [Implementation edge cases dependency supply chain governance](implementation-edge-cases-dependency-supply-chain-governance.md) | update cannot corrupt protocol, receipts, DB, helper identity, or rollback |
| 7.1 | add remote/headless read-only mode | [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md), [Critical zone remote/headless destructive cleanup authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md) | remote destructive cleanup stays disabled until authority model is proven |
| 7.2 | implement diagnostics and support bundle export | [Implementation edge cases diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md), [Critical zone support bundle diagnostics export privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md) | export is typed, redacted, bounded, consented, and useful |
| 8.1 | run release readiness gates | [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md), [Critical zones index](critical-zones/README.md) | crash, low-disk, destructive, update, permission, scale, and migration gates pass |

## Work Lanes And Ownership

Use these lanes to decide which layer owns a decision. A lower lane must not
reach upward for convenience.

| Lane | Owns | Reads | Must not own |
| --- | --- | --- | --- |
| Reusable Rust engine | scan sessions, read model, filesystem ports, cleanup domain, metadata contracts | Rust architecture, pdu docs, filesystem model, cleanup safety | Clean Disk routes, Flutter DTOs, HTTP/WebSocket, UI policy |
| Scanner adapter | pdu integration, traversal options, progress mapping, DataTree conversion | pdu adapter guide, pdu audit, pdu validation | product delete safety, recommendation policy, UI pagination decisions |
| Server/runtime | daemon lifecycle, worker pools, HTTP/WebSocket, tokens, persistence adapters, observability | runtime critical zone, protocol docs, operational reliability | Flutter state, widget behavior, domain invariants |
| Flutter app | app shell, routing, feature composition, scan UI, cleanup queue UI, settings | UX docs, large-tree UI, protocol DTO docs | scanner truth, delete decisions, remote authZ |
| Design system | shared visual primitives, Headless facade, app theme, accessibility primitives | design references, feature UX, accessibility/i18n | feature business rules, protocol parsing |
| Cleanup safety | DeletePlan, identity revalidation, receipts, reclaim confidence, restore capability | cleanup safety docs, receipt durability, reclaim research | ad hoc path deletion, unjournaled command execution |
| Recommendations | rule packs, evidence, risk tiers, explainability, stale invalidation | recommendation docs, tool-managed storage, command sandbox | bypassing DeletePlan or receipts |
| Distribution/security | signing, permissions, installer, updater, dependency trust, remote policy | platform packaging, update rollback, security/privacy | runtime shortcuts that change app/helper identity |
| Support/release | support bundles, diagnostics, release gates, test matrix, incident evidence | diagnostics docs, support privacy, testing quality gates | raw path/token export by default |

## Mandatory Reading Bundles

When a task starts, use the smallest bundle that covers the blast radius. Then
add critical-zone files if the task touches a gate.

| Work item | Required bundle | Add if touched |
| --- | --- | --- |
| Rust crate scaffold | P0 baseline docs, Rust architecture, Rust best practices | Rust runtime critical zone |
| pdu adapter | pdu guide, pdu critical risk verification, pdu audit, pdu validation, pdu integration edge cases | filesystem model, performance scale |
| read model/indexes | performance scale, filesystem model, search query indexing | protocol DTOs, large-tree UI |
| daemon HTTP endpoint | protocol data contracts, transport streaming, operational reliability | remote auth if endpoint can affect cleanup or private data |
| WebSocket events | transport streaming, concurrency state machines | support privacy if events can be logged/exported |
| Flutter scan screen | feature UX, large-tree UI, design references | permission UX, product workflows |
| cleanup queue | cleanup delete safety, identity revalidation, local persistence | receipt durability, restore/undo, reclaim accounting |
| reclaim estimate | reclaim research, storage accounting, filesystem model | cleanup safety |
| recommendation card | recommendation rule engine, rule-pack safety | tool-managed storage, command sandbox |
| official cleanup command | tool-managed storage, command sandbox | receipt durability, restore/undo |
| installer/permissions | platform packaging, permission UX, security/privacy | update rollback |
| remote/headless endpoint | remote/headless mode, web daemon runtime, security/privacy | remote destructive auth |
| support bundle | diagnostics support, support bundle privacy, local persistence | remote auth if support export can include remote audit |
| release | testing quality gates, critical zones index, dependency governance | every touched phase gate |

## Stop Rules

Stop implementation and update docs/tests before continuing when any of these
conditions appear:

- a feature needs raw absolute paths in logs, metrics, crash reports, or support
  bundles;
- a cleanup path can execute without DeletePlan, identity revalidation, durable
  journal intent, and receipt;
- Flutter needs the full scan tree in memory;
- pdu data is treated as product truth without metadata enrichment and issue
  modeling;
- protocol DTOs expose large integers to Flutter web without precision policy;
- WebSocket reconnect can replay or subscribe to unauthorized sessions;
- a daemon process can scan/delete under a different identity than the
  permission probe;
- remote/headless cleanup becomes possible before target scope, authorization,
  quota, audit, and destructive policy are implemented;
- an update can run while cleanup is mid-operation without quiesce/recovery
  state;
- support export can include raw receipts, command output, tokens, headers, scan
  trees, or raw paths by default.

## Fast Path

If you have no chat history, read in this order:

1. [Start Here](../../START_HERE.md) - current scope, accepted architecture, and
   short recovery context.
2. [Documentation operating manual](documentation-operating-manual.md) - how to
   move from request to evidence, resolve doc conflicts, and update indexes.
3. [Documentation tree](documentation-tree.md) - visual tree of all technical
   docs by layer, work area, read mode, and gate.
4. [Documentation map](documentation-map.md) - how docs are structured, where
   new information goes, and what each document type means.
5. [Documentation sitemap](documentation-sitemap.md) - grouped visual map of
   the full technical documentation set.
6. [Task router](task-router.md) - day-to-day routing by task type and expected
   output.
7. [Reading order checklist](reading-order-checklist.md) - checkbox-style
   scenario paths, expected outputs, gates, and stop conditions.
8. [Execution board](execution-board.md) - row-by-row build board with
   deliverables, gates, and excluded scope.
9. [Implementation Packet Index](#implementation-packet-index) - concrete work
   packets from docs baseline to release, remote, and support operations.
10. [Phase reading guide](phase-reading-guide.md) - phase-by-phase minimum
   reading, risk add-ons, output, and boundaries.
11. [Start-to-finish guide](start-to-finish-guide.md) - master sequence and one
   linear route from context recovery to release gates.
12. [Capability implementation matrix](capability-implementation-matrix.md) -
   capability-to-train/milestone/phase/lane/gate routing.
13. [Implementation runbook](implementation-runbook.md) - operational build plan,
   milestone gates, slices, and PR checklist.
14. [Release train map](release-train-map.md) - product slice boundaries from
   scan-only MVP to remote/headless and future cleanup.
15. [Scan-only macOS release gate](scan-only-macos-release-gate.md) - concrete
   macOS release validation command and required signing/notarization evidence.
16. [Architecture decisions](architecture-decisions.md) - accepted product and
   system decisions.
17. [Rust architecture](rust-architecture.md) - three-layer Rust model and crate
   responsibilities.
18. [Architecture fit validation](architecture-fit-validation.md) - why the
   accepted architecture fits performance, safety, desktop/web, and reuse.
19. [Disk usage map view adapter decision](disk-usage-map-view-adapter.md) -
   visual map abstraction, renderer adapters, and optional Syncfusion policy.
20. [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md) -
   Flutter responsibility zones and MobX store architecture.
21. [Frontend boundaries decision](frontend-boundaries-decision.md) -
   DTO, command, authority, event, persistence, design-system, platform, and
   route boundaries.
21. [Critical zones index](critical-zones/README.md) - global risks that can
   invalidate multiple guarantees.
22. The phase-specific documents below for the area you are implementing.

## Implementation Order

This is the intended build order. Each phase lists the documents that should be
read before implementation starts.

### Phase 0 - Project Baseline And Constraints

Goal: understand the accepted product shape before writing code.

- [Start Here](../../START_HERE.md)
- [Documentation operating manual](documentation-operating-manual.md)
- [Documentation tree](documentation-tree.md)
- [Documentation map](documentation-map.md)
- [Documentation sitemap](documentation-sitemap.md)
- [Task router](task-router.md)
- [Reading order checklist](reading-order-checklist.md)
- [Execution board](execution-board.md)
- [Phase reading guide](phase-reading-guide.md)
- [Start-to-finish guide](start-to-finish-guide.md)
- [Capability implementation matrix](capability-implementation-matrix.md)
- [Implementation runbook](implementation-runbook.md)
- [Release train map](release-train-map.md)
- [Architecture principles research](architecture-principles.md)
- [Architecture decisions](architecture-decisions.md)
- [Architecture fit validation](architecture-fit-validation.md)
- [Architecture future risks](architecture-future-risks.md)
- [Future-proofing architecture gates](future-proofing-architecture-gates.md)
- [Disk usage map view adapter decision](disk-usage-map-view-adapter.md)
- [Rust best practices research](rust-best-practices.md)

Output expected:

- implementation follows Clean Architecture, ports/adapters, simple DDD, and
  package boundaries;
- no direct dependency from domain/application to Flutter, Dio, Drift, pdu,
  transport, or generated bridge code;
- risks are checked against the critical-zone index before coding.

### Phase 1 - Rust Runtime, Scanner Adapter, And Data Model

Goal: create the reusable scanner foundation without coupling it to Clean Disk UI
or protocol.

- [Rust architecture](rust-architecture.md)
- [Implementation edge cases pdu adapter integration](implementation-edge-cases-pdu-adapter-integration.md)
- [pdu adapter capability spike](pdu-adapter-capability-spike.md)
- [pdu library deep validation](pdu-library-deep-validation.md)
- [pdu data model and adapter guide](pdu-data-model-and-adapter-guide.md)
- [pdu Clean Architecture contract](pdu-clean-architecture-contract.md)
- [pdu critical risk verification](pdu-critical-risk-verification.md)
- [pdu required capabilities audit](pdu-required-capabilities-audit.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Windows NTFS MFT fast path](windows-ntfs-mft-fast-path.md) - future
  Windows-only idea, not MVP.
- [Critical zone Rust runtime execution](critical-zones/rust-runtime-execution.md)

Output expected:

- pdu is an adapter, not product truth;
- scanner output is converted into our arena/read-model;
- Rust owns tree, indexes, sorting, filtering, and pagination;
- blocking filesystem work never runs on async reactor threads.

### Phase 2 - Protocol, Daemon Runtime, Web UI Boundary

Goal: connect Flutter/web UI to the Rust daemon without leaking transport details
through features.

- [Implementation edge cases protocol data contracts](implementation-edge-cases-protocol-data-contracts.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Transport and client generation research](transport-client-generation-research.md)
- [Implementation edge cases web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md)
- [Implementation edge cases concurrency state machines](implementation-edge-cases-concurrency-state-machines.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Critical zone remote/headless destructive cleanup authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md) - required
  before remote destructive mode.

Output expected:

- accepted transport remains HTTP commands/queries plus plain WebSocket events;
- protocol DTOs stay separate from domain and Flutter view state;
- sessions, cursors, event ordering, reconnect, and backpressure are explicit;
- web is a UI surface, not a browser-side full disk scanner.

### Phase 3 - Flutter UI, Design System, And Product Workflows

Goal: build the product surface around large scan results and safe workflows.

- [Feature UX benchmark](feature-ux-benchmark.md)
- [Cross-platform user experience playbook](cross-platform-user-experience-playbook.md)
- [Permission UX playbook](permission-ux-playbook.md)
- [Real product UX lessons](real-product-ux-lessons.md)
- [Launched product UX playbook](launched-product-ux-playbook.md)
- [Real product feature adoption playbook](real-product-feature-adoption-playbook.md)
- [Top company product UX patterns](top-company-product-ux-patterns.md)
- [Launched product cross-platform workflows](launched-product-cross-platform-workflows.md)
- [Launched product operational UX deep dive](launched-product-operational-ux-deep-dive.md)
- [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md)
- [Frontend boundaries decision](frontend-boundaries-decision.md)
- [Frontend i18n localization decision](frontend-i18n-localization-decision.md)
- [Headless TreeGrid primitive design](headless-tree-grid-primitive-design.md)
- [Headless primitive RFC index](headless-primitives/README.md)
- [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md)
- Design references:
  [wide desktop](../design/references/clean-disk-wide-reference.png) and
  [compact narrow](../design/references/clean-disk-compact-reference.png).

Output expected:

- the folder tree/table is the central workflow;
- wide and compact layouts follow the saved references;
- UI requests pages, details, top lists, and search results from Rust indexes;
- Headless/design-system limitations are reported instead of worked around
  awkwardly.

### Phase 4 - Cleanup Safety, DeletePlan, Receipts, And Reclaim Truth

Goal: make cleanup a safe domain workflow, not path deletion from UI state.

- [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md)
- [Implementation edge cases platform identity and delete revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md)
- [Implementation edge cases storage accounting snapshots shared extents](implementation-edge-cases-storage-accounting-snapshots-shared-extents.md)
- [Reclaim accounting deep research](reclaim-accounting-deep-research.md)
- [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md)
- [Critical zone restore quarantine undo safety](critical-zones/restore-quarantine-undo-safety.md)
- [Critical zone persistent operation journal receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md)

Output expected:

- DeletePlan revalidates current identity before side effects;
- receipt skeleton and journal intent are durable before execution;
- unknown outcomes are represented honestly;
- reclaim estimates distinguish logical, allocated, exclusive, quota effect, and
  observed free-space delta.

### Phase 5 - Recommendations, Tool-Managed Storage, And Command Adapters

Goal: add helpful cleanup advice without causing false-positive data loss.

- [Implementation edge cases recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md)
- [Implementation edge cases tool-managed storage](implementation-edge-cases-tool-managed-storage.md)
- [Critical zone recommendation policy rule-pack safety](critical-zones/recommendation-policy-rule-pack-safety.md)
- [Critical zone tool command execution sandbox](critical-zones/tool-command-execution-sandbox.md)

Output expected:

- recommendations are evidence-backed and risk-tiered;
- developer/tool storage is conservative by default;
- official cleanup commands run only through controlled adapters;
- command output, environment, executable identity, timeout, and receipts are
  governed.

### Phase 6 - Platform Permissions, Packaging, Release, And Updates

Goal: ensure the shipped app, helper, daemon, and updater have stable identity
and safe lifecycle behavior.

- [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md)
- [Implementation edge cases dependency supply chain governance](implementation-edge-cases-dependency-supply-chain-governance.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Critical zone update release rollback safety](critical-zones/update-release-rollback-safety.md)

Output expected:

- macOS/Windows/Linux permissions and signing are part of architecture, not
  installer polish;
- updates quiesce runtime state before replacing binaries;
- rollback does not break protocol, DB migrations, receipts, or helper identity;
- dependency trust is governed before release.

### Phase 7 - Remote, Headless, Diagnostics, And Support

Goal: make non-local usage and support workflows explicit and privacy-safe.

- [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md)
- [Implementation edge cases diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md)
- [Critical zone remote/headless destructive cleanup authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md)
- [Critical zone support bundle diagnostics export privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md)

Output expected:

- remote/headless starts read-only unless authorization, target scope, policy,
  quota, audit, and UI disclosure are proven;
- support bundles are typed, bounded, redacted, consented, and useful;
- logs, metrics, traces, crash reports, receipts, and support bundles have
  separate data policies.

### Phase 8 - Testing, Quality Gates, And Release Readiness

Goal: prove the product under scale, crashes, low disk, permission failures, and
destructive boundaries.

- [Pre-implementation critical spikes](pre-implementation-critical-spikes.md)
- [Preimplementation critical research sequence](preimplementation-critical-research-sequence.md)
- [Preimplementation critical zones deep dive](preimplementation-critical-zones-deep-dive.md)
- [Critical zones index](critical-zones/README.md)
- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)
- [Implementation edge cases resource governance](implementation-edge-cases-resource-governance.md)
- [Implementation edge cases search query indexing](implementation-edge-cases-search-query-indexing.md)
- [Implementation edge cases incremental scan and watchers](implementation-edge-cases-incremental-scan-watchers.md)
- [Implementation edge cases cloud network virtual filesystems](implementation-edge-cases-cloud-network-virtual-filesystems.md)
- [Implementation edge cases advanced scenarios](implementation-edge-cases-advanced-scenarios.md)

Output expected:

- performance, crash, low-disk, permission, migration, and destructive tests
  exist before enabling risky features;
- critical zones become release gates, not comments;
- scan resource profiles preserve system responsiveness by default.

## Phase Gate Matrix

Use this matrix to decide whether a phase is ready to start or ready to exit.

| Phase | Start condition | Exit condition | Blocking gates |
| --- | --- | --- | --- |
| P0 baseline | repo shape and product scope are known | accepted decisions, package boundaries, and architecture risks are clear | architecture decisions, fit validation |
| P1 scanner | P0 complete | pdu adapter contract, Rust read-model, indexes, pagination, and runtime worker boundaries are proven | Rust runtime critical zone, pdu audits |
| P2 protocol | P1 contracts stable enough for DTOs | HTTP queries, WebSocket events, sessions, cursors, reconnect, and backpressure are specified | protocol DTOs, transport streaming, remote auth if destructive |
| P3 UI | P2 query/event shape stable enough for screens | wide and compact UI follow references and use Rust queries instead of full tree state | large-tree UI, design references, feature UX |
| P4 cleanup | P1 identity model and P2 protocol are ready | DeletePlan, identity revalidation, receipt durability, reclaim confidence, and restore expectations are safe | restore/undo, receipt durability, reclaim accounting |
| P5 recommendations | P4 cleanup contract exists | rule packs are evidence-backed, risk-tiered, and cannot execute unsafe cleanup paths | rule-pack safety, command sandbox |
| P6 packaging | P1-P4 process identity decisions are known | permissions, signing, helper identity, updater, rollback, and dependency gates are release-ready | update rollback, dependency governance, platform permissions |
| P7 remote/support | P2 protocol and P6 identity story are stable | remote/headless is scoped, read-only by default, audited, and support export is redacted and bounded | remote auth, support bundle privacy |
| P8 release | feature phase has implementation and tests | destructive, crash, scale, low-disk, permission, migration, and update tests pass | all relevant critical zones |

Do not treat this as waterfall. UI prototypes can exist early, but production
code should not bypass the gates for the phase it depends on.

## Document Groups

Use these groups when working on a specific area.

### Navigation And Execution

- [Start Here](../../START_HERE.md)
- [Documentation operating manual](documentation-operating-manual.md)
- [Documentation tree](documentation-tree.md)
- [Documentation map](documentation-map.md)
- [Documentation sitemap](documentation-sitemap.md)
- [Task router](task-router.md)
- [Reading order checklist](reading-order-checklist.md)
- [Execution board](execution-board.md)
- [Phase reading guide](phase-reading-guide.md)
- [Start-to-finish guide](start-to-finish-guide.md)
- [Capability implementation matrix](capability-implementation-matrix.md)
- [Implementation runbook](implementation-runbook.md)
- [Release train map](release-train-map.md)
- [Critical zones index](critical-zones/README.md)

### Architecture And Decisions

- [Architecture principles research](architecture-principles.md)
- [Architecture decisions](architecture-decisions.md)
- [Architecture fit validation](architecture-fit-validation.md)
- [Architecture future risks](architecture-future-risks.md)
- [Future-proofing architecture gates](future-proofing-architecture-gates.md)
- [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md)
- [Rust architecture](rust-architecture.md)
- [Rust best practices research](rust-best-practices.md)

### Scanner And Filesystem Engine

- [Implementation edge cases pdu adapter integration](implementation-edge-cases-pdu-adapter-integration.md)
- [pdu adapter capability spike](pdu-adapter-capability-spike.md)
- [pdu library deep validation](pdu-library-deep-validation.md)
- [pdu data model and adapter guide](pdu-data-model-and-adapter-guide.md)
- [pdu Clean Architecture contract](pdu-clean-architecture-contract.md)
- [pdu critical risk verification](pdu-critical-risk-verification.md)
- [pdu required capabilities audit](pdu-required-capabilities-audit.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Windows NTFS MFT fast path](windows-ntfs-mft-fast-path.md)

### Protocol, Runtime, And State Machines

- [Implementation edge cases protocol data contracts](implementation-edge-cases-protocol-data-contracts.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Transport and client generation research](transport-client-generation-research.md)
- [Implementation edge cases concurrency state machines](implementation-edge-cases-concurrency-state-machines.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Implementation edge cases web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md)

### Cleanup, Persistence, And Accounting

- [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md)
- [Implementation edge cases platform identity and delete revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md)
- [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md)
- [Implementation edge cases storage accounting snapshots shared extents](implementation-edge-cases-storage-accounting-snapshots-shared-extents.md)
- [Reclaim accounting deep research](reclaim-accounting-deep-research.md)

### Product UX And Design

- [Feature UX benchmark](feature-ux-benchmark.md)
- [Permission UX playbook](permission-ux-playbook.md)
- [Cross-platform user experience playbook](cross-platform-user-experience-playbook.md)
- [Market and competitive research](market-competitive-research.md)
- [Real product UX lessons](real-product-ux-lessons.md)
- [Launched product UX playbook](launched-product-ux-playbook.md)
- [Real product feature adoption playbook](real-product-feature-adoption-playbook.md)
- [Top company product UX patterns](top-company-product-ux-patterns.md)
- [Launched product cross-platform workflows](launched-product-cross-platform-workflows.md)
- [Launched product operational UX deep dive](launched-product-operational-ux-deep-dive.md)
- [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md)
- [Frontend boundaries decision](frontend-boundaries-decision.md)
- [Frontend i18n localization decision](frontend-i18n-localization-decision.md)
- [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md)
- [Wide desktop reference](../design/references/clean-disk-wide-reference.png)
- [Compact narrow reference](../design/references/clean-disk-compact-reference.png)

### Platform, Security, Governance, And Support

- [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md)
- [Implementation edge cases dependency supply chain governance](implementation-edge-cases-dependency-supply-chain-governance.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md)
- [Implementation edge cases diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md)
- [Implementation edge cases resource governance](implementation-edge-cases-resource-governance.md)

### Querying, Watchers, Cloud, And Advanced Scenarios

- [Implementation edge cases search query indexing](implementation-edge-cases-search-query-indexing.md)
- [Implementation edge cases incremental scan and watchers](implementation-edge-cases-incremental-scan-watchers.md)
- [Implementation edge cases cloud network virtual filesystems](implementation-edge-cases-cloud-network-virtual-filesystems.md)
- [Implementation edge cases recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md)
- [Implementation edge cases tool-managed storage](implementation-edge-cases-tool-managed-storage.md)
- [Implementation edge cases UI accessibility and i18n](implementation-edge-cases-ui-accessibility-i18n.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases advanced scenarios](implementation-edge-cases-advanced-scenarios.md)

### Testing And Critical Research

- [Implementation edge cases](implementation-edge-cases.md)
- [Implementation edge cases deep dive](implementation-edge-cases-deep-dive.md)
- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)
- [Pre-implementation critical spikes](pre-implementation-critical-spikes.md)
- [Preimplementation critical research sequence](preimplementation-critical-research-sequence.md)
- [Preimplementation critical zones deep dive](preimplementation-critical-zones-deep-dive.md)
- [Critical zones index](critical-zones/README.md)

## Full Document Inventory

Every technical document should fit one phase and one primary role. If a new
file does not fit this inventory, either add a new category deliberately or
merge it into an existing document.

| Document | Phase | Type | Purpose |
| --- | --- | --- | --- |
| [Start Here](../../START_HERE.md) | P0 | Decision | short recovery context and canonical entry point |
| [Documentation operating manual](documentation-operating-manual.md) | P0-P8 | Decision | request-to-evidence loop, source-of-truth order, task card, output types, update rules, and examples |
| [Documentation tree](documentation-tree.md) | P0-P8 | Decision | visual tree of all technical docs by layer, work area, read mode, and gate |
| [Documentation map](documentation-map.md) | P0-P8 | Decision | documentation structure, source-of-truth routing, lifecycle, and maintenance rules |
| [Documentation sitemap](documentation-sitemap.md) | P0-P8 | Decision | visual structure of all technical docs grouped by area |
| [Task router](task-router.md) | P0-P8 | Decision | day-to-day task routing by task type, required docs, gate, and expected output |
| [Reading order checklist](reading-order-checklist.md) | P0-P8 | Decision | scenario checklists for reading order, expected output, gates, and stop conditions |
| [Execution board](execution-board.md) | P0-P8 | Decision | row-by-row implementation board with deliverables, docs, gates, workstreams, and excluded scope |
| [Phase reading guide](phase-reading-guide.md) | P0-P8 | Decision | phase-by-phase minimum docs, risk add-ons, output, and do-not-pull-forward boundaries |
| [Start-to-finish guide](start-to-finish-guide.md) | P0-P8 | Decision | master sequence and one linear route from context recovery to scan MVP, cleanup beta, desktop release, remote/headless, and release gates |
| [Capability implementation matrix](capability-implementation-matrix.md) | P0-P8 | Decision | capability-to-train, milestone, phase, lane, gate, and excluded-scope routing |
| [Implementation runbook](implementation-runbook.md) | P0-P8 | Decision | operational build sequence, milestones, slices, and PR checklist |
| [Clean Architecture implementation phases](clean-architecture-implementation-phases.md) | P0-P8 | Decision | strict phase-by-phase implementation steps, gates, stop rules, and first slice that protects Clean Architecture, SOLID, simple DDD, and ports/adapters |
| [Release train map](release-train-map.md) | P0-P8 | Decision | product slice boundaries from scan-only MVP to cleanup, desktop release, remote/headless, and support operations |
| [Scan-only macOS release gate](scan-only-macos-release-gate.md) | P7 | Validation | concrete scan-only macOS release validation command and required signing/notarization evidence |
| [Architecture principles research](architecture-principles.md) | P0 | Research | SOLID, DDD, Clean Architecture, and ports/adapters baseline |
| [Architecture decisions](architecture-decisions.md) | P0 | Decision | accepted architecture choices and open questions |
| [Architecture fit validation](architecture-fit-validation.md) | P0 | Validation | validates daemon, worker pool, HTTP/WebSocket, and protocol fit |
| [Architecture future risks](architecture-future-risks.md) | P0 | Research | future risks around cleanup authority, daemon lifecycle, and reuse |
| [Future-proofing architecture gates](future-proofing-architecture-gates.md) | P0-P8 | Decision | future-shaped contracts, operational, strategic, product, safety, organizational, ecosystem, automation, multi-environment, assurance, fault-model, external-boundary, abuse-resistance, complexity, and evolution future gates, invariants, stop rules, and extension points that MVP must preserve |
| [Disk usage map view adapter decision](disk-usage-map-view-adapter.md) | P0-P4 | Decision | `DiskUsageMapView`, renderer adapter boundary, optional Syncfusion policy, and bounded map projection rules |
| [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md) | P3 | Decision | Flutter responsibility zones, feature-scoped MobX stores, lifecycle, identity, Observer, reaction, and testing rules |
| [Frontend boundaries decision](frontend-boundaries-decision.md) | P3 | Decision | frontend DTO, command, authoritative state, design-system, event stream, persistence, platform action, accessibility, responsive layout, and route boundaries |
| [Frontend i18n localization decision](frontend-i18n-localization-decision.md) | P3 | Decision | official Flutter gen-l10n, shared localization package, formatting boundary, supported locales, and stop rules |
| [Headless Clean Disk priority index](headless-clean-disk-priority-index.md) | P3 | Decision | Clean Disk-specific Headless/UI implementation priority, critical components, MVP scope, future architecture gates, and time sink stop rules |
| [Headless TreeGrid primitive design](headless-tree-grid-primitive-design.md) | P3 | Decision | reusable Headless treegrid behavior, virtualization, keyboard, semantics, renderer contracts, and Clean Disk wrapper boundaries |
| [Headless primitive RFC index](headless-primitives/README.md) | P3 | Decision | community-grade Headless primitive RFCs for collection/grid/tree foundations, TreeGrid, SplitPane, ContextMenu, Dialog, Tooltip, StatusRegion, button/menu/split button, form fields, checkbox/radio/switch, slider/spinbutton, select/listbox, breadcrumb navigation, links/navigation, alerts/toasts, icons/images, badges/chips, pagination/load-more, empty/skeleton states, skip/bypass navigation, side navigation/drawer/rail, popover/floating panels, drawer/sheet/side panels, wizard/stepper workflows, file picker/dropzone/path targets, query/filter/sort surfaces, data summary metrics, property/details inspectors, command discovery/shortcut help, destructive action safety affordances, native menubar/app commands, motion/reduced animation, contrast/color-scheme/theme adaptation, route/focus/history restoration, undo/redo operation history, export/print/report snapshots, multi-window/session scopes, live announcement broker, capability/permission progressive enhancement, locale/unit/quantity formatting, zoom/density/target size, degraded/offline/partial availability, instrumentation/telemetry privacy budget, user intent/command provenance, untrusted content sanitization, recoverable error assistance, versioned state migration, safe-area/orientation/viewport, automation/test driver boundaries, semantic identity/reference stability, command routing/scope arbitration, nested interactive composition, sticky/scroll anchoring geometry, screen-reader browse/focus mode, third-party renderer trust, semantic diff/change announcements, operation lifecycle/cancellation/retry, cognitive load/progressive disclosure, evidence/confidence/uncertainty, cross-adapter semantic parity, extension lifecycle/deprecation compatibility, accessibility-tree snapshot regression, ARIA role/attribute linting, personalization preference profiles, localization/bidi stress corpus, semantic API review/release gates, support feedback/defect triage, data-transfer payload governance, keyboard layout/dead-key shortcuts, virtualized collection metadata, policy/feature flag evaluation, cross-window transfer trust, visual/semantic diff alignment, accessibility exception waivers, executable documentation examples, deterministic time/scheduler tests, render failure containment, property-based fuzz conformance, privacy-safe evidence capture, WCAG2ICT native app profiles, accessibility-supported technology policy, ACT rule integration, ACR/VPAT evidence reporting, platform role/action mapping, assistive technology transcript correlation, native semantic preference/ARIA minimization, host boundary iframe/shadow/portal rules, accessibility event ordering/cache invalidation, assistive technology workaround governance, misuse diagnostics/dev warnings, public fixture pack interoperability, platform accessibility settings adapters, switch access/linear scanning, voice control/speech commands, magnifier visual viewport reflow, closed functionality/kiosk runtime, assistive API permission/privacy boundaries, braille display output, screen-reader rotor/quick navigation, touch screen-reader exploration, dictation text input/correction, captions/transcripts/status media, adaptive symbols/plain language, regulatory procurement standards profiles, native accessibility API family contracts, AOM experimental boundaries, accessibility inspector debug evidence, localized accessible name catalogs, assistive technology compatibility lifecycle, accessible authentication/pairing, credential autofill/passkey forms, browser permission prompt orchestration, web filesystem picker/origin storage, local daemon network access, PWA service worker install/offline boundaries, web notification permission/attention, spatial navigation/D-pad, gamepad/remote input, fullscreen lock/immersive modes, text selection/find-in-page, accessible export artifacts, native shell integration/status, haptic vibration feedback, speech synthesis audio output, dwell/eye-tracking activation, virtual keyboard input viewport, writing assistance/spellcheck/translation, sensor motion/orientation permissions, path/filename semantic display, technical identifiers/error codes, code/preformatted/log output, abbreviation/definition terms, quantity/byte/unit semantics, time/date/duration recency, data table caption/header association, meter/comparison value indicators, description/details/help associations, inline annotation/highlight/revision semantics, figure/media caption/fallback semantics, mathematical expression/formula semantics, list/feed/result-set semantics, document outline/section/heading semantics, receipt/report document semantics, machine-readable metadata/provenance, audit timeline/event feed semantics, search result count/navigation semantics, structured evidence/chain-of-custody semantics, faceted filter taxonomy semantics, grouping/aggregation summary semantics, comparison baseline/delta semantics, bulk selection scope/preview semantics, column view preset/layout personalization, responsive card-grid alternate view semantics, severity/risk/threshold/trend semantics, row action menu/action cell semantics, master-detail preview panel semantics, command palette execution safety, reorderable drag-drop keyboard semantics, status footer activity region semantics, resizable pane layout persistence, async collection cursor window contracts, operation center task queues, notification inbox attention management, guided repair onboarding coachmarks, scope context authority banners, overlay layer stack z-order contracts, design token semantic theme bridges, dense target focus visibility, segmented control toggle groups, date time range picker filters, overflow truncation tooltip disclosure, scroll container keyboard affordances, modal focus return stacks, selection activation intent separation, inline edit commit cancel flows, command bars, tabs/disclosure, progress/log/status, landmarks, visualization accessibility, label-in-name, reducer/effect internals, semantics adapters, names/descriptions, IME/editing, focus algorithms, selection, combobox/search, state semantics, validation, timing/data loss, pointer/drag alternatives, async loading, clipboard privacy, conformance, compliance playbooks, public extension rules, columns, and web ARIA bridge |
| [Rust architecture](rust-architecture.md) | P0-P1 | Decision | Rust crate layout, layers, and server responsibilities |
| [Rust best practices research](rust-best-practices.md) | P0-P1 | Research | Rust patterns relevant to this project |
| [Implementation edge cases pdu adapter integration](implementation-edge-cases-pdu-adapter-integration.md) | P1 | Edge case | pdu integration, options, progress, cancellation, fork strategy |
| [pdu adapter capability spike](pdu-adapter-capability-spike.md) | P1 | Spike | pdu capability findings before implementation |
| [pdu library deep validation](pdu-library-deep-validation.md) | P1 | Spike | local pdu CLI/library validation and adapter implications |
| [Pre-coding pdu architecture research](pre-coding-pdu-architecture-research.md) | P1 | Research/Decision | source-audited pdu facts, Clean Architecture/DDD/ports-and-adapters shape, global pre-coding stop rules |
| [pdu implementation start gate](pdu-implementation-start-gate.md) | P1 | Decision | compact pre-PR gate for pdu source facts, layer contracts, SOLID mapping, stop gates, first PR shape, and contract tests |
| [pdu cross-layer contract matrix](pdu-cross-layer-contract-matrix.md) | P1-P2 | Decision | pdu internals mapped to Clean Architecture layers, product contracts, size/path/issue/event/reclaim/runtime/protocol/read-model rules, and PR review gates |
| [pdu data flow architecture contract](pdu-data-flow-architecture-contract.md) | P1-P2 | Decision | accepted scan data flow, consistency model, identifiers, cursors, capability negotiation, issue propagation, DTO mapping, privacy, and first PR boundary |
| [pdu domain infrastructure contract blueprint](pdu-domain-infrastructure-contract-blueprint.md) | P1-P2 | Decision | practical module blueprint for `fs_usage_core`, `fs_usage_engine`, `fs_usage_pdu`, `fs_usage_platform`, product data flow, and contract tests |
| [pdu data model and adapter guide](pdu-data-model-and-adapter-guide.md) | P1 | Decision | pdu DataTree/reporter mapping into Clean Disk read-model |
| [pdu Clean Architecture contract](pdu-clean-architecture-contract.md) | P1 | Decision | Clean Architecture/SOLID/ports-and-adapters contract for keeping pdu private to infrastructure |
| [pdu raw API contract map](pdu-raw-api-contract-map.md) | P1 | Reference | raw pdu API, JSON, reporter events, fixture observations, and required mapping before product data contracts |
| [pdu critical risk verification](pdu-critical-risk-verification.md) | P1 | Spike | verified memory, cancellation, metadata, hardlink, resource pressure, and macOS identity risks |
| [pdu required capabilities audit](pdu-required-capabilities-audit.md) | P1 | Validation | strict pdu capability audit against Clean Disk needs |
| [Windows NTFS MFT fast path](windows-ntfs-mft-fast-path.md) | P1 | Reference | future Windows-only fast scanner backend idea |
| [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md) | P1-P4 | Edge case | low-level size, identity, quota, delete, and DTO model risks |
| [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md) | P1-P8 | Edge case | scale, benchmarking, scanner, protocol, and UI throughput risks |
| [Implementation edge cases protocol data contracts](implementation-edge-cases-protocol-data-contracts.md) | P2 | Edge case | DTOs, JSON precision, path encoding, schema/versioning |
| [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md) | P2 | Edge case | HTTP/WebSocket envelopes, reconnect, backpressure, event ordering |
| [Transport and client generation research](transport-client-generation-research.md) | P2 | Research | HTTP client, WebSocket, Socket.IO, JSON-RPC, gRPC tradeoffs |
| [Implementation edge cases web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md) | P2-P7 | Edge case | daemon-served web, CORS/PNA, pairing, service worker constraints |
| [Implementation edge cases concurrency state machines](implementation-edge-cases-concurrency-state-machines.md) | P2-P4 | Edge case | operation state machines, idempotency, cancellation, multi-client |
| [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md) | P2-P8 | Edge case | daemon lifecycle, crash recovery, persistence, overload, releases |
| [Feature UX benchmark](feature-ux-benchmark.md) | P3 | UX contract | feature-level UX contracts for the product surface |
| [Permission UX playbook](permission-ux-playbook.md) | P3-P6 | UX contract | permission ladder, scan-quality states, repair flows |
| [Cross-platform user experience playbook](cross-platform-user-experience-playbook.md) | P3-P7 | UX contract | install, first-run, scan, cleanup, cloud, diagnostics, remote UX |
| [Market and competitive research](market-competitive-research.md) | P0-P7 | Research | market and competitor map, AI and safe-delete assistant landscape, benchmark methodology, differentiation, and monetization implications |
| [Real product UX lessons](real-product-ux-lessons.md) | P3 | Research | lessons from launched storage and cleanup products |
| [Launched product UX playbook](launched-product-ux-playbook.md) | P3 | Research | product journeys and UX/DTO spikes from launched tools |
| [Real product feature adoption playbook](real-product-feature-adoption-playbook.md) | P3 | UX contract | feature-by-feature adoption rules from real products |
| [Top company product UX patterns](top-company-product-ux-patterns.md) | P3 | Research | state-led UX, health, diagnostics, settings, accessibility |
| [Launched product cross-platform workflows](launched-product-cross-platform-workflows.md) | P3-P7 | UX contract | shared workflows and native platform action adapters |
| [Launched product operational UX deep dive](launched-product-operational-ux-deep-dive.md) | P3-P7 | Research | command registry, trust modes, operation ledger, support UX |
| [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md) | P3 | Edge case | virtualization, frontend state ownership, rendering performance |
| [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md) | P4 | Edge case | DeletePlan, Trash adapters, partial outcomes, receipts |
| [Implementation edge cases platform identity and delete revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md) | P4 | Edge case | file identity, stale candidate validation, delete preflight |
| [Implementation edge cases storage accounting snapshots shared extents](implementation-edge-cases-storage-accounting-snapshots-shared-extents.md) | P4 | Edge case | APFS, VSS, Btrfs/ZFS, dedupe, sparse/compressed, quotas |
| [Reclaim accounting deep research](reclaim-accounting-deep-research.md) | P4 | Research | reclaim confidence/evidence model and accounting feasibility |
| [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md) | P4-P8 | Edge case | Drift/SQLite, receipts, journals, migrations, corruption recovery |
| [Implementation edge cases recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md) | P5 | Edge case | recommendation rules, evidence, risk tiers, explainability |
| [Implementation edge cases tool-managed storage](implementation-edge-cases-tool-managed-storage.md) | P5 | Edge case | Docker, Xcode, package managers, developer cache cleanup |
| [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md) | P6 | Edge case | macOS/Windows/Linux permissions, signing, installers, updates |
| [Implementation edge cases dependency supply chain governance](implementation-edge-cases-dependency-supply-chain-governance.md) | P6 | Edge case | dependency trust, licenses, SBOM, provenance, vulnerability gates |
| [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md) | P6-P7 | Edge case | threat model, daemon hardening, tokens, remote mode, supply chain |
| [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md) | P7 | Edge case | headless/server mode, auth/authZ, containers, quotas, audit |
| [Implementation edge cases diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md) | P7 | Edge case | logs, metrics, crash reports, support bundles, redaction |
| [Implementation edge cases resource governance](implementation-edge-cases-resource-governance.md) | P8 | Edge case | scan modes, CPU/IO budgets, priority, battery, thermal behavior |
| [Implementation edge cases search query indexing](implementation-edge-cases-search-query-indexing.md) | P8 | Edge case | search, sort, filter, top lists, indexing, stale results |
| [Implementation edge cases incremental scan and watchers](implementation-edge-cases-incremental-scan-watchers.md) | P8 | Edge case | watchers, cache invalidation, stale snapshots, subtree refresh |
| [Implementation edge cases cloud network virtual filesystems](implementation-edge-cases-cloud-network-virtual-filesystems.md) | P8 | Edge case | cloud placeholders, network shares, NAS, FUSE, removable volumes |
| [Implementation edge cases UI accessibility and i18n](implementation-edge-cases-ui-accessibility-i18n.md) | P3-P8 | Edge case | accessibility, keyboard UX, localization, bidi-safe paths |
| [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md) | P3-P8 | Edge case | product workflow, protocol correctness, delete plan, export |
| [Implementation edge cases advanced scenarios](implementation-edge-cases-advanced-scenarios.md) | P8 | Edge case | advanced storage, recommendations, installer, enterprise cases |
| [Implementation edge cases](implementation-edge-cases.md) | P8 | Edge case | first-pass implementation edge-case index |
| [Implementation edge cases deep dive](implementation-edge-cases-deep-dive.md) | P8 | Edge case | deeper platform, cloud, daemon security, watcher, UI risks |
| [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md) | P8 | Edge case | testing strategy, CI gates, benchmarks, destructive safety |
| [Pre-implementation critical spikes](pre-implementation-critical-spikes.md) | P8 | Spike | ordered spike plan before scanner, protocol, cleanup, UI |
| [Preimplementation critical research sequence](preimplementation-critical-research-sequence.md) | P8 | Research | broader ordered research decisions before implementation |
| [Preimplementation critical zones deep dive](preimplementation-critical-zones-deep-dive.md) | P8 | Critical gate | broad hidden failure modes and release blockers |
| [Critical zones index](critical-zones/README.md) | P0-P8 | Critical gate | focused global risk gates and ranking |
| [Update, release, rollback, and app identity safety](critical-zones/update-release-rollback-safety.md) | P6-P8 | Critical gate | update trust, quiesce gates, compatibility, rollback |
| [Rust runtime execution and worker-pool isolation](critical-zones/rust-runtime-execution.md) | P1-P2 | Critical gate | Tokio/blocking boundary, worker lanes, cancellation, shutdown |
| [Recommendation policy, rule-pack safety, and false-positive control](critical-zones/recommendation-policy-rule-pack-safety.md) | P5 | Critical gate | evidence-backed recommendations and rule-pack gates |
| [Restore, quarantine, undo, and cleanup receipt safety](critical-zones/restore-quarantine-undo-safety.md) | P4 | Critical gate | restore capabilities, receipts, platform Trash semantics |
| [Tool command execution sandbox and side-effect control](critical-zones/tool-command-execution-sandbox.md) | P5 | Critical gate | safe official command execution and side-effect control |
| [Remote/headless destructive cleanup authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md) | P7 | Critical gate | remote authority, target scopes, audit, quota, policy |
| [Persistent operation journal and receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md) | P4 | Critical gate | durable cleanup truth under low disk and crash recovery |
| [Support bundle, diagnostics export, and privacy-preserving evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md) | P7 | Critical gate | typed, redacted, bounded, consented support evidence |
| [Wide desktop reference](../design/references/clean-disk-wide-reference.png) | P3 | Reference | primary wide desktop visual target |
| [Compact narrow reference](../design/references/clean-disk-compact-reference.png) | P3 | Reference | compact/narrow visual target |

## Critical Zones

Focused global critical-zone files live in
[critical-zones/README.md](critical-zones/README.md). Read them as release
gates for risky work.

Current focused files:

- [Update, release, rollback, and app identity safety](critical-zones/update-release-rollback-safety.md)
- [Rust runtime execution and worker-pool isolation](critical-zones/rust-runtime-execution.md)
- [Recommendation policy, rule-pack safety, and false-positive control](critical-zones/recommendation-policy-rule-pack-safety.md)
- [Restore, quarantine, undo, and cleanup receipt safety](critical-zones/restore-quarantine-undo-safety.md)
- [Tool command execution sandbox and side-effect control](critical-zones/tool-command-execution-sandbox.md)
- [Remote/headless destructive cleanup authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md)
- [Persistent operation journal and receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md)
- [Support bundle, diagnostics export, and privacy-preserving evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md)

## Where To Look By Task

| Task | Start with | Then read |
| --- | --- | --- |
| Understand how to operate the docs | [Documentation operating manual](documentation-operating-manual.md) | README, documentation map, sitemap |
| See the technical docs as a tree | [Documentation tree](documentation-tree.md) | sitemap, README Document Groups |
| Route a day-to-day task | [Task router](task-router.md) | capability matrix, required docs from task row |
| Follow a scenario checklist | [Reading order checklist](reading-order-checklist.md) | task router and capability matrix for the chosen scenario |
| Find next implementation row | [Execution board](execution-board.md) | task router, capability matrix, phase docs, critical gates |
| See all docs by structure | [Documentation sitemap](documentation-sitemap.md) | the relevant group and linked phase docs |
| Read by current phase | [Phase reading guide](phase-reading-guide.md) | minimum docs, risk add-ons, and gates for the phase |
| Start from zero context | [Start-to-finish guide](start-to-finish-guide.md) | documentation map, release train map, implementation runbook |
| Build a concrete capability | [Capability implementation matrix](capability-implementation-matrix.md) | matching phase docs, critical gates, implementation runbook |
| Product slice or MVP scope | [Release train map](release-train-map.md) | implementation runbook, architecture decisions, affected critical zones |
| Rust scanner crate | [Rust architecture](rust-architecture.md) | pdu docs, filesystem model, performance, Rust runtime critical zone |
| pdu adapter | [pdu data model and adapter guide](pdu-data-model-and-adapter-guide.md) | pdu Clean Architecture contract, pdu raw API contract map, pdu critical risk verification, pdu capability, pdu validation, pdu audit |
| HTTP/WebSocket protocol | [Transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md) | protocol DTOs, transport research, web daemon runtime |
| Flutter tree UI | [Feature UX benchmark](feature-ux-benchmark.md) | large-tree UI, design references, product workflows |
| Localization/i18n | [Frontend i18n localization decision](frontend-i18n-localization-decision.md) | UI accessibility/i18n, frontend boundaries, Flutter frontend architecture |
| DeletePlan/cleanup | [Cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md) | identity revalidation, reclaim accounting, receipt durability critical zone |
| Recommendations | [Recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md) | rule-pack safety, tool-managed storage, command sandbox |
| Tool cleanup adapter | [Tool-managed storage](implementation-edge-cases-tool-managed-storage.md) | command sandbox, receipts, operational reliability |
| Installer/permissions | [Platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md) | permission UX, update rollback critical zone |
| Remote/headless | [Remote and headless mode](implementation-edge-cases-remote-headless-mode.md) | remote destructive auth critical zone, web runtime, security/privacy |
| Support bundle | [Diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md) | support bundle privacy critical zone, local persistence |
| Release readiness | [Testing quality gates](implementation-edge-cases-testing-quality-gates.md) | critical zones, update rollback, dependency governance |

## Rules For New Documents

- Add a new document only when it has its own failure model, decision set,
  invariants, or release gates.
- Add the new document to this index and, if it is a global risk, to
  [critical-zones/README.md](critical-zones/README.md).
- Keep broad brainstorming in research docs; move accepted facts to decisions or
  phase-specific docs.
- Do not let this folder become chronological chat history. It should remain a
  navigable engineering map.
