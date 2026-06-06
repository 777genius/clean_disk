# Reading Order Checklist

Last updated: 2026-05-16.

This file is the executable checklist for reading and action order. It is not a
new source of truth. It turns the existing documentation map into step-by-step
paths for common scenarios.

Use it when you want to move from "where do I start?" to "what do I open, what
do I produce, and where do I stop?"

## How To Use

1. Pick the closest scenario.
2. Complete the checklist in order.
3. Write down the expected output before coding.
4. Stop if any gate is not satisfied.
5. If the task changes accepted architecture, update the source-of-truth doc
   before continuing.

Do not use this file to bypass:

- [Task router](task-router.md) for task-specific gates;
- [Execution board](execution-board.md) for the row-by-row build order and
  deliverable gates;
- [Capability implementation matrix](capability-implementation-matrix.md) for
  train, milestone, phase, lane, and excluded scope;
- [Critical zones](critical-zones/README.md) for release blockers.

## Scenario 1 - Zero Context Or New Agent

Use when the thread history is gone or an agent starts cold.

- [ ] Read [START_HERE](../../START_HERE.md).
- [ ] Read the Front Door section in [README](README.md).
- [ ] Read [Documentation map](documentation-map.md).
- [ ] Read [Documentation sitemap](documentation-sitemap.md).
- [ ] Read [Task router](task-router.md).
- [ ] Read [Execution board](execution-board.md).
- [ ] Read [Phase reading guide](phase-reading-guide.md).
- [ ] Read [Start-to-finish guide](start-to-finish-guide.md).
- [ ] Read [Capability implementation matrix](capability-implementation-matrix.md).
- [ ] Read [Release train map](release-train-map.md).
- [ ] Read [Implementation runbook](implementation-runbook.md).
- [ ] Identify active train, milestone, phase, owner lane, gate, and excluded
  scope.

Expected output:

- current architecture can be summarized without chat memory;
- next task has five coordinates: train, milestone, phase, lane, gate;
- excluded scope is explicit.

Stop if:

- an accepted decision exists only in chat;
- the task cannot name the owner lane;
- the task touches cleanup, command execution, remote, support, update, or
  release without a critical-zone file.

## Scenario 2 - Documentation Reorganization

Use when adding, splitting, renaming, or indexing docs.

- [ ] Read [Documentation map](documentation-map.md).
- [ ] Read [Documentation sitemap](documentation-sitemap.md).
- [ ] Read [README](README.md), especially Document Groups and Full Document
  Inventory.
- [ ] Read [Task router](task-router.md), Documentation Work section.
- [ ] Decide whether the new information is decision, validation, research,
  spike, edge case, critical gate, UX contract, or reference.
- [ ] Put the information in the source-of-truth document.
- [ ] Add the document to [README](README.md).
- [ ] Add it to [START_HERE](../../START_HERE.md) only if it is needed for
  recovery.
- [ ] Add it to [AGENTS](../../AGENTS.md) only if future agents must always
  know it.
- [ ] Add it to [Critical zones](critical-zones/README.md) only if it is a
  global release gate.
- [ ] Run local link and formatting checks.

Expected output:

- every new document is reachable from README;
- no critical rule lives only in a broad research file;
- navigation docs agree on the same structure.

Stop if:

- the same accepted rule appears in multiple docs with different wording;
- a new file is useful but has no owner, phase, type, or gate;
- links were not verified.

## Scenario 3 - Scan-Only MVP

Use when building the safe read-only disk visualization product.

- [ ] Confirm the active train is T1 in [Release train map](release-train-map.md).
- [ ] Confirm capability rows in
  [Capability implementation matrix](capability-implementation-matrix.md).
- [ ] Complete P0 baseline reading from [Phase reading guide](phase-reading-guide.md).
- [ ] Complete P1 scanner reading from [Phase reading guide](phase-reading-guide.md).
- [ ] Complete P2 protocol reading from [Phase reading guide](phase-reading-guide.md).
- [ ] Complete P3 UI reading from [Phase reading guide](phase-reading-guide.md).
- [ ] Follow M1-M4 in [Implementation runbook](implementation-runbook.md).
- [ ] Keep cleanup execution, recommendations, command adapters, and remote
  cleanup out of scope.
- [ ] Verify that Flutter never receives or stores the full scan tree.
- [ ] Verify that pdu is isolated behind the scanner adapter.
- [ ] Verify that HTTP queries and WebSocket events have reconnect, sequence,
  throttling, and resync behavior.

Expected output:

- reusable Rust scanner/read-model foundation;
- pdu adapter behind ports;
- read-only daemon protocol;
- Flutter scan UI with progress, tree/table, search, sort, filters, details,
  and scan-quality states.

Stop if:

- node identity is just a path string;
- WebSocket emits one event per filesystem entry;
- full `PathBuf` is stored per node in the main read model;
- UI computes cleanup truth from visible rows.

## Scenario 4 - Local Cleanup Beta

Use when adding local Trash/delete capability after scan-only works.

- [ ] Confirm scan-only MVP is usable and measured.
- [ ] Confirm the active train is T2 in [Release train map](release-train-map.md).
- [ ] Read P4 in [Phase reading guide](phase-reading-guide.md).
- [ ] Read [Cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md).
- [ ] Read [Platform identity delete revalidation](implementation-edge-cases-platform-identity-delete-revalidation.md).
- [ ] Read [Reclaim accounting deep research](reclaim-accounting-deep-research.md).
- [ ] Read [Local state persistence](implementation-edge-cases-local-state-persistence.md).
- [ ] Read [Receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md).
- [ ] Read [Restore quarantine undo safety](critical-zones/restore-quarantine-undo-safety.md).
- [ ] Build DeletePlan preview before any destructive adapter.
- [ ] Add identity revalidation dry-run.
- [ ] Add durable journal intent and receipt skeleton before side effects.
- [ ] Add platform Trash adapter for one OS.
- [ ] Add per-item outcome states and crash recovery inbox.

Expected output:

- cleanup cannot execute from stale UI state;
- receipts explain item outcomes;
- reclaim estimates show confidence and uncertainty;
- unknown outcomes are persisted and visible.

Stop if:

- cleanup executes from path strings;
- low disk can prevent recording cleanup truth;
- crash recovery auto-retries destructive operations;
- UI promises exact freed bytes without proof.

## Scenario 5 - Recommendations And Official Tool Adapters

Use when adding cleanup intelligence or official cleanup commands.

- [ ] Confirm local cleanup safety exists first.
- [ ] Confirm the active train is T3 in [Release train map](release-train-map.md).
- [ ] Read P5 in [Phase reading guide](phase-reading-guide.md).
- [ ] Read [Recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md).
- [ ] Read [Tool-managed storage](implementation-edge-cases-tool-managed-storage.md).
- [ ] Read [Recommendation policy rule-pack safety](critical-zones/recommendation-policy-rule-pack-safety.md).
- [ ] Read [Tool command execution sandbox](critical-zones/tool-command-execution-sandbox.md).
- [ ] Model evidence, risk tier, rule version, and invalidation for every
  recommendation.
- [ ] Route recommendations through DeletePlan, not direct deletion.
- [ ] Execute official commands only through controlled adapters.
- [ ] Record command identity, argv, env, cwd, timeout, output limits,
  cancellation, dry-run parity, and receipts.

Expected output:

- recommendation cards are explainable and conservative;
- official cleanup commands are bounded and auditable;
- false-positive risk is controlled before release.

Stop if:

- a rule says "safe" without evidence;
- command output decides deletion without domain review;
- PATH lookup can choose an attacker-controlled executable;
- persistent tool data is treated as ordinary cache.

## Scenario 6 - Signed Desktop Release

Use when preparing installable desktop builds.

- [ ] Confirm enabled trains and capabilities.
- [ ] Read P6 in [Phase reading guide](phase-reading-guide.md).
- [ ] Read [Platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md).
- [ ] Read [Permission UX playbook](permission-ux-playbook.md).
- [ ] Read [Dependency supply-chain governance](implementation-edge-cases-dependency-supply-chain-governance.md).
- [ ] Read [Security privacy](implementation-edge-cases-security-privacy.md).
- [ ] Read [Update release rollback safety](critical-zones/update-release-rollback-safety.md).
- [ ] Verify scanner permission probe and scanner execution use the same
  process identity.
- [ ] Verify production does not launch an external random `pdu` binary.
- [ ] Verify update quiesce and rollback compatibility.
- [ ] Verify dependency freshness, license, vulnerability, and trust gates.
- [ ] Run release readiness checks from
  [Testing quality gates](implementation-edge-cases-testing-quality-gates.md).

Expected output:

- signed identity and permission flow are stable;
- installer/update behavior is documented and tested;
- dependency and release artifacts have evidence.

Stop if:

- app and scanner/helper have different permission expectations;
- updater can replace binaries during cleanup;
- helper identity changes silently across updates;
- release cannot reproduce dependency inputs.

## Scenario 7 - Remote Or Headless Read-Only

Use when exposing scan-only behavior outside the local desktop shell.

- [ ] Confirm the active train is T5 in [Release train map](release-train-map.md).
- [ ] Read P7 in [Phase reading guide](phase-reading-guide.md).
- [ ] Read [Remote and headless mode](implementation-edge-cases-remote-headless-mode.md).
- [ ] Read [Web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md).
- [ ] Read [Security privacy](implementation-edge-cases-security-privacy.md).
- [ ] Read [Remote destructive authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md)
  as a warning boundary, not as permission to implement cleanup.
- [ ] Define target scopes, auth/authZ policy, audit events, and quotas.
- [ ] Keep remote cleanup disabled.
- [ ] Keep local loopback token out of remote auth.

Expected output:

- remote/headless read-only scan is scoped, audited, and private by default;
- every target, session, node, and query is authorized server-side;
- destructive mode is visibly absent.

Stop if:

- `--listen 0.0.0.0` enables cleanup;
- hosted UI can connect to arbitrary localhost daemons without pairing;
- WebSocket connection auth is treated as object/action authorization;
- scan target paths can escape configured scopes.

## Scenario 8 - Future Remote Cleanup

Use only after a separate destructive-authority review.

- [ ] Confirm T6 is explicitly selected in [Release train map](release-train-map.md).
- [ ] Re-read all T2 cleanup safety docs.
- [ ] Re-read all T5 remote/headless docs.
- [ ] Read [Remote destructive authorization](critical-zones/remote-headless-destructive-cleanup-authorization.md).
- [ ] Read [Receipt durability under low disk](critical-zones/persistent-operation-journal-receipt-durability-low-disk.md).
- [ ] Read [Support bundle privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md).
- [ ] Design object-level auth, target scope, quota, audit, policy approval,
  emergency disable, and remote receipt semantics.
- [ ] Prove remote destructive action cannot inherit local desktop trust.

Expected output:

- remote cleanup is a separate product mode;
- destructive actions have explicit policy and blast-radius controls;
- audit and receipts survive crash and support incident review.

Stop if:

- remote cleanup can be enabled by a config flag alone;
- WebSocket messages can authorize or replay destructive commands;
- remote cleanup uses local loopback token or desktop confirmation semantics;
- support export leaks remote delete targets by default.

## Scenario 9 - Diagnostics And Support

Use when adding logs, metrics, crash reports, support bundles, or support UI.

- [ ] Confirm the active train is T7 or a release/support slice.
- [ ] Read P7 and P8 in [Phase reading guide](phase-reading-guide.md).
- [ ] Read [Diagnostics observability support](implementation-edge-cases-diagnostics-observability-support.md).
- [ ] Read [Support bundle privacy evidence](critical-zones/support-bundle-diagnostics-export-privacy-evidence.md).
- [ ] Read [Local state persistence](implementation-edge-cases-local-state-persistence.md).
- [ ] Classify each data field before logging or exporting it.
- [ ] Define redaction profile, manifest, consent, retention, and size limits.
- [ ] Ensure raw paths, tokens, headers, search text, full scan trees, and raw
  delete targets are not exported by default.

Expected output:

- support bundle is useful without raw private data;
- diagnostics are typed and bounded;
- production observability avoids high-cardinality private labels.

Stop if:

- support requires raw log/database zips;
- crash reports include scan tree or delete queue by default;
- metrics include raw paths or search text;
- redaction cannot be tested.

## Scenario 10 - PR Or Local Change Review

Use when reviewing a PR, local branch, or generated patch.

- [ ] Identify changed capabilities in
  [Capability implementation matrix](capability-implementation-matrix.md).
- [ ] Confirm active train in [Release train map](release-train-map.md).
- [ ] Confirm milestone in [Implementation runbook](implementation-runbook.md).
- [ ] Confirm phase in [Phase reading guide](phase-reading-guide.md).
- [ ] Confirm owner lane in [README Work Lanes](README.md).
- [ ] Confirm excluded scope.
- [ ] Read touched critical zones.
- [ ] Check forbidden imports and dependency direction.
- [ ] Check tests or manual evidence for the gate.
- [ ] Report bugs, safety risks, missing gates, and missing tests first.

Expected output:

- review findings are tied to file/line and gate;
- safe changes are allowed without broad refactor demands;
- risky scope creep is blocked before merge.

Stop if:

- destructive capability appears in a read-only train;
- adapter code leaks into domain/application;
- raw private data enters logs or support output;
- critical-zone gate is bypassed.

## Stop Checklist

Stop and resolve docs/tests before continuing if any answer is "no":

- [ ] Can the task name train, milestone, phase, lane, and gate?
- [ ] Is excluded scope written down?
- [ ] Is the source-of-truth document identified?
- [ ] Are touched critical zones opened?
- [ ] Are side effects gated by domain workflow, not UI state?
- [ ] Are private data fields classified before logging/export?
- [ ] Are tests, fixtures, or manual evidence named for the gate?

## Task Card

Copy this into implementation plans:

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
Stop conditions:
```

If any field is unknown, do not code yet. Route the task through
[Task router](task-router.md) and
[Capability implementation matrix](capability-implementation-matrix.md), then
place it on [Execution board](execution-board.md).
