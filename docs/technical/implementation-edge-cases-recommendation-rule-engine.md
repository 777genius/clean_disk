# Implementation Edge Cases - Recommendation And Rule Engine

Last updated: 2026-05-13.

This file records edge cases for cleanup recommendations, rule evaluation, evidence, reason codes, risk tiers, app/tool-specific cleanup actions, rule versioning, user overrides, and explainability.

Clean Disk can be an accurate analyzer before it becomes a safe cleaner. The recommendation system is the bridge between those two modes. It must not turn "large" into "safe".

Related documents:

- [Implementation edge cases advanced scenarios](implementation-edge-cases-advanced-scenarios.md)
- [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)
- [Architecture principles research](architecture-principles.md)

## Sources Reviewed

- Apple Developer Archive, [File System Basics](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html). Relevant points: `Application Support` is for app support files, `Caches` contains cache data the app can recreate, and the system may delete cache data to free space.
- Apple Developer Documentation, [Using the file system effectively](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively?changes=_4&language=objc). Relevant point from accessible summary/search result: use standard directories and avoid hard-coded paths because Finder may localize/present names differently.
- Microsoft Learn, [Configure Storage Sense](https://learn.microsoft.com/en-us/windows/configuration/storage/storage-sense). Relevant points: Windows Storage Sense has policy-controlled cleanup for temporary files, cloud-backed content, Downloads, Recycle Bin retention, and cadence.
- Docker Docs, [docker system prune](https://docs.docker.com/reference/cli/docker/system/prune/). Relevant points: Docker has an official prune command for unused containers/networks/images/build cache; volumes are excluded by default to avoid deleting important data.
- npm Docs, [npm cache](https://docs.npmjs.com/cli/v7/commands/npm-cache/). Relevant points: npm cache is self-healing, clearing is usually unnecessary except reclaiming space, `clean` requires `--force`, and npm does not expose direct per-file cache management.
- pnpm Docs, [pnpm store](https://pnpm.io/cli/store). Relevant points: `pnpm store prune` removes unreferenced packages, is described as having no side effects on projects, may require future re-downloads after branch switches or older dependency installs, displays the removed size after pruning, and can garbage-collect global virtual store links when that feature is enabled.
- Yarn Docs, [yarn cache clean](https://yarnpkg.com/cli/cache/clean). Relevant point: Yarn can remove shared cache files, with options for local/global cache.
- pip Documentation, [Caching](https://pip.pypa.io/en/stable/topics/caching/). Relevant points: cache layout is an implementation detail that may change; `pip cache` exposes supported management commands; disabling cache can significantly slow pip and increase network usage.
- Cargo Book, [cargo clean](https://doc.rust-lang.org/cargo/commands/cargo-clean.html). Relevant points: Cargo has official cleanup for generated artifacts and supports dry-run.
- XDG Base Directory Specification, [latest](https://specifications.freedesktop.org/basedir-spec/latest/). Relevant points: cache, data, config, state, and runtime directories have different semantics; runtime files must be user-owned and should not survive logout/reboot.

## Severity Scale

- `P0` - recommendation can imply unsafe deletion, classify user data as cache, call the wrong tool cleanup, bypass app ownership, or produce one-click cleanup across mixed risk classes.
- `P1` - recommendation can mislead about reclaim amount, generate noisy false positives, become stale across tool versions, or create support burden.
- `P2` - improves explainability, customization, catalog maintenance, developer ergonomics, or future ecosystem integrations.

## Top 3 Rule Engine Decisions

1. Typed Specification rules in Rust, versioned catalog, no generic scripting in MVP - 🎯 10 🛡️ 10 🧠 5, roughly 700-1800 LOC across rules, DTOs, tests, and UI reason mapping.
2. External signed JSON/YAML rule catalog later for non-destructive classification only - 🎯 7 🛡️ 7 🧠 7, roughly 1200-3000 LOC across schema, signatures, migrations, review UI, and compatibility tests.
3. Community/plugin rules that can create cleanup actions - 🎯 3 🛡️ 3 🧠 9, roughly 2500-7000 LOC plus security review. Too risky for MVP because the app can move user files.

My recommendation: start with typed rules as code, with rule IDs and evidence snapshots. Add external catalogs only after we have tests, rule review workflow, and a non-destructive sandbox.

## Core Principle

Recommendations are claims. Every claim needs evidence.

Minimum recommendation model:

```text
Recommendation
  candidate_id
  source_node_id
  rule_set_version
  rule_ids[]
  evidence[]
  risk_tier
  confidence
  action_kind
  reclaim_estimate
  warnings[]
  required_confirmation_level
```

Rules:

- no recommendation without rule ID;
- no cleanup action without evidence;
- no one-click cleanup for mixed risk tiers;
- unclassified large folders default to inspect/review, not cleanup;
- user-facing copy is derived from reason codes, not ad hoc strings.

## Bounded Context

### Recommendation Is Not Scan - `P0`

Scan tells what exists and how much it uses. Recommendation decides how to interpret it.

Required behavior:

- scan domain emits facts: path, kind, size facts, identity, skipped states, owner hints, mount/provider hints;
- recommendation domain/application evaluates rules against facts;
- cleanup domain consumes recommendations only through DeletePlan validation;
- UI never treats a scan row as a cleanup recommendation unless the recommendation service produced one.

Avoid:

- mixing rule flags into scanner traversal code;
- adding delete buttons based only on path substring;
- using UI filters like "largest" as cleanup policy.

### Recommendation Is Not Cleanup Authority - `P0`

A recommendation can suggest. DeletePlan still owns authority for destructive action.

Required behavior:

- recommendation has expiry or snapshot binding;
- DeletePlan revalidates identity and risk before execution;
- recommendation confidence can only reduce friction, never remove validation;
- changed rule versions invalidate old low-friction cleanup plans.

## Rule Model

### Use Specification Pattern, Not A Generic Rules Engine First - `P0`

Architecture research already points to a light Specification pattern for safety rules. This is enough for MVP.

Good shape:

```text
trait CandidateRule {
  id() -> RuleId
  version() -> RuleVersion
  evaluate(context, node_facts) -> RuleEvaluation
}

RuleEvaluation
  matched: bool
  risk_delta
  confidence_delta
  evidence[]
  warnings[]
  allowed_actions[]
```

Rules stay typed and testable. They can still produce structured metadata for UI and snapshots.

Avoid:

- embedding a DSL before the rules are stable;
- letting JSON/YAML rules execute commands;
- making "path regex matched" enough evidence for deletion;
- hiding rule code inside Flutter presentation.

### Rule IDs Must Be Stable - `P1`

Rules are product behavior, not implementation details.

Required behavior:

- each rule has stable ID like `macos.library_caches.app_cache`;
- rule version increments when semantics change;
- receipts and support bundles include rule IDs, not only text;
- rule snapshots are test fixtures;
- deprecating a rule keeps old receipts readable.

### Rule Output Needs Evidence - `P0`

Evidence is how the app explains and audits recommendations.

Evidence examples:

```text
path_under_known_cache_root
xdg_cache_home_match
apple_caches_directory_match
tool_manifest_detected
package_lock_detected
docker_context_detected
tool_dry_run_available
file_age_threshold_met
app_not_running_observed
hardlink_count_gt_1
cloud_provider_marker_detected
system_managed_path_detected
```

Rules:

- evidence is structured and machine-readable;
- UI maps evidence to short copy;
- details panel can show full evidence;
- tests snapshot rule IDs and evidence for canonical fixtures.

## Risk Tiers

### Use Conservative Defaults - `P0`

Default for unknown data must be review-only.

Recommended tiers:

```text
inspect_only:
  visible in analyzer, no cleanup action

known_rebuildable_cache:
  candidate for move-to-trash or tool-specific cleanup after review

tool_managed_cleanup:
  candidate only through tool adapter or documented command

app_managed_data:
  explain owner, no generic cleanup

system_managed_storage:
  redirect to OS/tool, no raw delete

cloud_or_remote_sensitive:
  warn, no automatic cleanup without provider semantics

blocked_dangerous:
  no cleanup action
```

Rules:

- unclassified large folder = `inspect_only`;
- `Application Support` root = not a cleanup candidate;
- system snapshots = `system_managed_storage`;
- package-manager stores = `tool_managed_cleanup` or `inspect_only`;
- cloud sync roots require warning even for cache-like paths.

### Confidence Is Separate From Risk - `P0`

Risk says what can go wrong. Confidence says how certain the app is about classification.

Examples:

- known exact cache path + app not running = low risk, high confidence;
- path named `Cache` inside unknown app data = medium risk, low confidence;
- Docker Desktop virtual disk = high risk for raw delete, high confidence system/tool-managed;
- `node_modules` in active project = low/medium risk for rebuildability, medium confidence on reclaim due hardlinks;
- cloud placeholder = high risk, high confidence that local reclaim semantics are provider-specific.

Required fields:

```text
risk_tier
risk_score
confidence_score
confidence_reasons[]
unknowns[]
```

## Action Kinds

### Action Kind Must Be Explicit - `P0`

The UI must not show one generic "Clean" action for everything.

Recommended actions:

```text
inspect
reveal_in_file_manager
add_to_delete_plan
move_to_trash
run_tool_dry_run
run_tool_cleanup
open_official_cleanup_settings
show_manual_command
blocked
```

Rules:

- `move_to_trash` only for normal filesystem candidates;
- Docker gets `run_tool_dry_run`/`show_manual_command` first, not raw virtual disk deletion;
- Windows Storage Sense gets `open_official_cleanup_settings` or read-only guidance;
- package-manager caches prefer tool commands over raw deletion;
- blocked candidates still explain why they are large.

### Tool Adapters Need Dry-Run Where Possible - `P1`

Tool-managed storage should use the tool's own semantics.

Examples:

- Docker prune: official command lists affected classes and asks for confirmation;
- Cargo clean: supports dry-run for generated artifacts;
- npm cache: supports verify/clean, but clean is all-cache and force-gated;
- pip cache: supports info/list/remove/purge;
- pnpm store prune: project-safe but can slow future installs and has global virtual store semantics when enabled;
- Yarn cache clean: can remove shared/local/global cache depending options.

Required behavior:

- tool adapter exposes capabilities;
- tool adapter exposes dry-run/preview when available;
- no tool command runs without explicit user review;
- command output is parsed only if stable enough; otherwise show as text with conservative status;
- failure maps to typed outcome.

Avoid:

- raw deleting Docker volumes;
- raw deleting npm `_cacache` internals;
- raw deleting pip cache internals instead of `pip cache`;
- treating pnpm store reclaim as equivalent to deleting project `node_modules`;
- assuming all package manager cache cleanup frees project `node_modules`.

## Known Directory Semantics

### macOS Library Is Not One Category - `P0`

Apple distinguishes `Application Support`, `Caches`, `tmp`, and user data. Deleting across `~/Library` blindly is unsafe.

Required behavior:

- `~/Library/Caches` can be candidate root only with app-aware warnings;
- `~/Library/Application Support` defaults to inspect-only/app-managed;
- `~/Library/Containers` and `Group Containers` require app ownership and sandbox semantics;
- `~/Library/Developer/Xcode/DerivedData` can be rebuildable developer cache with Xcode-running warning;
- system/user Library roots are never one-click cleanup candidates.

### Windows Storage Sense Is A System Policy Surface - `P1`

Windows already has policy-controlled cleanup concepts for temporary files, cloud-backed content, Downloads, Recycle Bin, and cadence.

Required behavior:

- do not duplicate Storage Sense policy blindly;
- show Windows cleanup categories separately from raw folders;
- managed policy can disable or configure cleanup;
- Downloads cleanup is never assumed safe;
- OneDrive dehydration/offline content is not deletion.

### Linux XDG Directories Are Semantics, Not Just Paths - `P1`

XDG separates cache, state, data, config, and runtime. Recommendation rules should respect those meanings.

Required behavior:

- `$XDG_CACHE_HOME` content is lower risk than `$XDG_DATA_HOME`;
- `$XDG_STATE_HOME` history/state is not generic cache;
- `$XDG_RUNTIME_DIR` is runtime communication/storage and should not contain large cleanup targets from our app;
- relative XDG env values are invalid according to the spec and should be ignored;
- Flatpak/Snap package dirs may have their own sandbox semantics.

## Tool And Developer Cache Cases

### `node_modules` Is Rebuildable But Not Always Low Reclaim - `P0`

`node_modules` can contain symlinks, hardlinks, native builds, manually patched files, or vendored dependencies.

Required behavior:

- project `node_modules` is review candidate, not automatic deletion;
- pnpm symlink/hardlink store affects reclaim estimate;
- Yarn PnP `.yarn/cache` can be committed as zero-install strategy, so deleting it can break repo workflow;
- native dependencies may require rebuild and toolchain/network;
- if package lock/manifest is missing, confidence drops.

### Package Manager Caches Prefer Official Commands - `P1`

Required behavior:

- npm: prefer `npm cache verify`/documented clean, not direct `_cacache` delete;
- pnpm: prefer `pnpm store prune`, explain possible future re-download cost, and account for global virtual store semantics when enabled;
- Yarn: prefer `yarn cache clean` with correct local/global option;
- pip: prefer `pip cache info/list/remove/purge`, do not rely on cache internals;
- Cargo: distinguish project `target` cleanup from global cargo cache cleanup.

### Docker Storage Is Tool-Managed - `P0`

Docker Desktop and Docker Engine storage can include images, containers, volumes, build cache, and virtual disks.

Required behavior:

- never recommend deleting Docker Desktop virtual disk directly;
- show Docker as tool-managed storage;
- official prune commands are separate adapter actions;
- volumes get higher risk because Docker excludes them by default in `system prune`;
- `--force`, `--all`, and `--volumes` require escalating confirmation.

### Build Artifacts Need Project Context - `P1`

Build directories are usually rebuildable, but cleanup can disrupt local workflow.

Examples:

- Rust `target`;
- Flutter/Dart `.dart_tool`, `build`;
- Xcode DerivedData;
- Gradle `.gradle`;
- CMake build dirs;
- Bazel output/cache;
- Python `.tox`, `.venv`, `__pycache__`;
- JS `.next`, `dist`, `coverage`.

Required behavior:

- known project markers increase confidence;
- active process/build lock reduces confidence;
- user-created folders named `build` are not automatically safe;
- virtualenvs can be large but may be intentionally offline/reproducible.

## Staleness And Runtime Context

### Last Access Time Is Weak Evidence - `P1`

Many systems disable or coarsen access time updates. Cloud/provider caches can also present misleading timestamps.

Required behavior:

- age-based rules are never sole evidence for deletion;
- timestamp source and confidence are tracked;
- last access is advisory text, not delete proof;
- user can sort by age, but recommendation needs stronger evidence.

### App Running State Is Useful But Not Perfect - `P1`

Deleting an app's cache while the app is running can cause corruption, rebuild storms, or immediate recreation.

Required behavior:

- app-specific rules can check running processes where feasible;
- running app lowers cleanup confidence or blocks action;
- process detection is best-effort and shown as such;
- tool adapters handle lock/in-use outcomes.

### Rule Evaluation Must Be Snapshot-Bound - `P0`

Recommendation can become stale if files change after scan.

Required behavior:

- recommendation references scan snapshot id;
- rule_set_version is persisted;
- DeletePlan validation re-runs safety-critical rules;
- stale recommendation cannot execute cleanup directly;
- UI marks candidates stale after relevant rescan changes.

## User Controls And Overrides

### User Overrides Are Data, Not Code - `P1`

Users may want to hide, pin, or custom-label paths.

Allowed overrides:

- hide recommendation for path/pattern;
- mark path as important;
- mark project root;
- add custom review note;
- preferred cleanup action disabled;
- rule severity increased locally.

Forbidden in MVP:

- user-defined rule that executes commands;
- user-defined auto-delete rule;
- unreviewed imported rules from internet;
- wildcard override that silently downgrades risk for system/app-managed paths.

### Overrides Must Be Explainable - `P1`

Required behavior:

- UI shows when an override affected classification;
- support bundle can include redacted override IDs;
- overrides are scoped to user/profile;
- import/export has explicit review;
- deleting/resetting overrides does not affect receipts.

## Rule Updates And Compatibility

### Rule Catalog Changes Can Be Breaking - `P1`

Changing rules changes product behavior.

Required behavior:

- rule_set_version in every recommendation;
- changelog for rule behavior changes;
- snapshot tests for canonical fixtures;
- migration for renamed/deprecated reason codes;
- release notes mention cleanup rule changes.

### Remote Rule Updates Are A Security Risk - `P0`

A remote rule update could cause the app to classify private files differently or enable actions.

Rules:

- no remote rule updates in MVP;
- future remote catalog must be signed and non-executable;
- destructive action rules require app release, not silent remote config;
- user can view rule source/version;
- enterprise can pin/disable rule catalog versions.

## UX And Explainability

### Recommendations Need Reason Copy And Evidence Detail - `P1`

UI should answer:

- what is this;
- why is it shown;
- who owns it;
- how confident are we;
- what can happen if removed;
- whether space is immediately freed;
- what action will actually run.

Required UI fields:

```text
Title: Xcode DerivedData
Risk: Rebuildable developer cache
Confidence: High
Action: Move to Trash after review
Reasons: known developer cache path, project build artifacts, Xcode not running
Warnings: will slow next build
Reclaim: local estimate, not guaranteed if snapshots/hardlinks apply
```

### Recommendation Badges Must Not Overpromise - `P0`

Avoid labels:

- "Safe" alone;
- "Junk";
- "Useless";
- "Free now";
- "One click clean";
- "Duplicate" without hardlink/content proof.

Prefer labels:

- "Rebuildable cache";
- "Review recommended";
- "Tool-managed";
- "System-managed";
- "Cloud/provider-managed";
- "Blocked";
- "Unknown, inspect only".

## Privacy

### Rule Matching Can Reveal Sensitive Habits - `P1`

Rule IDs can reveal installed tools, project types, cloud providers, and app usage.

Required behavior:

- analytics disabled by default unless explicitly designed later;
- support bundles redact paths and can redact rule IDs if needed;
- local rule history retention is limited;
- recommendation logs use candidate IDs, not raw paths;
- no remote rule lookup with local path/tool names.

## Testing

### Canonical Fixture Matrix - `P0`

Required recommendation fixtures:

- macOS Caches vs Application Support;
- Xcode DerivedData;
- Docker virtual disk vs Docker prune candidate;
- npm cache;
- pnpm store and pnpm project node_modules;
- Yarn PnP `.yarn/cache`;
- pip cache;
- Cargo `target`;
- user folder named `Cache` outside known cache root;
- cloud sync root with cache-like folder;
- system snapshot/storage;
- active app/process lock;
- old file with weak timestamp evidence;
- same path after rule version change.

### Snapshot Rule Output - `P0`

Tests must snapshot:

- rule IDs;
- rule_set_version;
- evidence;
- risk tier;
- confidence;
- action kind;
- warnings;
- user-facing reason keys.

### Negative Tests Matter Most - `P0`

Required negative tests:

- `Application Support` is not globally suggested as cache;
- Downloads folder is not auto-cleaned because old;
- Docker volume is not raw-delete candidate;
- cloud placeholder is not counted as simple reclaim;
- `node_modules` without lockfile is not high-confidence cleanup;
- user-created `build` folder with documents is inspect-only;
- old file alone is not cleanup candidate.

## MVP Cut Line

Before first recommendation UI:

- typed rule/specification model exists;
- every recommendation has rule IDs, evidence, risk, confidence, action kind;
- unknown large folders are inspect-only;
- rule snapshots exist for canonical fixtures;
- user-facing labels avoid "safe/junk/free now";
- app/tool-managed actions are separated from move-to-trash.

Before first cleanup-capable beta:

- DeletePlan re-runs safety-critical rules;
- mixed risk plans escalate confirmation;
- package-manager/tool cleanup actions use official adapters or are read-only guidance;
- no external/community rule catalog can enable destructive action;
- support bundle redaction covers rule/evidence privacy.

Before external/custom rules:

- signed catalog format;
- schema validation;
- non-executable rules only;
- rule review UI;
- enterprise pin/disable;
- downgrade/migration policy;
- no cleanup actions from unsigned/custom rules.

## Summary

The safe stance:

```text
Large is not safe.
Path is not proof.
Recommendation is not authority.
Every recommendation needs rule ID, evidence, risk, confidence, and action kind.
Unknown means inspect-only.
Tool-managed storage should use tool-managed cleanup.
Remote/custom rules cannot enable destructive behavior in MVP.
```

The invariant:

```text
Clean Disk must never recommend cleanup as safe unless it can explain the rule, evidence, risk, confidence, expected action, and reclaim semantics in a way that remains testable and auditable across rule versions.
```
