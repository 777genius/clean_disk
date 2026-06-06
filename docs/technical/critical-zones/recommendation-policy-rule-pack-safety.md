# Critical Zone - Recommendation Policy, Rule-Pack Safety, And False-Positive Control

Last updated: 2026-05-16.

This file records the next global critical zone after
`rust-runtime-execution.md`.

The core risk is simple: an accurate scanner can still produce unsafe cleanup if
the recommendation layer interprets facts incorrectly. A disk analyzer may say
"this folder is large". A cleanup product must not silently turn that into "this
folder is safe to remove".

## Sources Reviewed

- Apple File System Programming Guide: `Library/Caches` is for re-creatable
  cache data, while `Application Support` stores app-managed data files and
  resources.
  Source:
  https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html
- Microsoft Storage Sense docs: Windows cleanup policy distinguishes temporary
  files, Recycle Bin retention, Downloads cleanup, and cloud-backed content
  dehydration.
  Sources:
  https://learn.microsoft.com/en-us/windows/configuration/storage/storage-sense
  and
  https://support.microsoft.com/en-us/windows/manage-drive-space-with-storage-sense-654f6ada-7bfc-45e5-966b-e24aded96ad5
- XDG Base Directory Specification: data, config, state, cache, and runtime
  directories have different semantics.
  Source: https://specifications.freedesktop.org/basedir-spec/latest/
- Docker Docs: prune commands are explicit, volumes are not removed
  automatically because deleting them can destroy data, and volumes persist
  outside a container lifecycle.
  Sources:
  https://docs.docker.com/engine/manage-resources/pruning/
  and https://docs.docker.com/engine/storage/volumes/
- npm Docs: npm cache is opaque and self-healing; cache clean requires
  `--force`; `npm prune --dry-run --json` can preview extraneous package
  removal.
  Sources:
  https://docs.npmjs.com/cli/v11/commands/npm-cache/
  and https://docs.npmjs.com/cli/v11/commands/npm-prune/
- pnpm Docs: `pnpm store prune` removes unreferenced store packages, is not
  harmful to projects, but may slow future installs and should not be run too
  frequently.
  Source: https://pnpm.io/cli/store
- Yarn Docs: `yarn cache clean` removes shared cache files and has separate local
  and global cache options.
  Source: https://yarnpkg.com/cli/cache/clean
- Gradle Docs: Gradle User Home has global caches, downloaded JDKs,
  distributions, daemon logs, and automatic cleanup policies with different
  retention categories.
  Sources:
  https://docs.gradle.org/current/userguide/directory_layout.html
  and https://docs.gradle.org/current/userguide/build_cache.html
- Cargo Book: `cargo clean` removes generated target artifacts and supports
  `--dry-run`.
  Source: https://doc.rust-lang.org/cargo/commands/cargo-clean.html
- Dart Pub docs: `dart pub cache repair` and `dart pub cache clean` are supported
  cache-management commands.
  Source: https://dart.dev/tools/pub/cmd/pub-cache
- pip docs: pip cache layout is an implementation detail; `pip cache` commands
  are the supported management surface.
  Sources:
  https://pip.pypa.io/en/stable/topics/caching/
  and https://pip.pypa.io/en/stable/cli/pip_cache/
- Homebrew docs: `brew cleanup` removes outdated downloads and old versions,
  supports `--dry-run`, and has age-based pruning.
  Source: https://docs.brew.sh/Manpage.html
- Android docs: `sdkmanager --uninstall` and `avdmanager delete avd -n name`
  are supported tool paths for SDK packages and AVDs.
  Sources:
  https://developer.android.com/tools/sdkmanager
  and https://developer.android.com/tools/avdmanager
- CocoaPods command reference: `pod cache clean` requires explicit `--all` when
  no pod name is provided to avoid clearing all cache by mistake.
  Source: https://guides.cocoapods.org/terminal/commands.html

## Why This Is The Next Global Critical Zone

Update/release safety and Rust runtime isolation protect the system from broad
infrastructure failures. The next most dangerous product boundary is
recommendation safety.

Why:

- delete damage usually starts before deletion, at classification time;
- user trust depends on whether "cleanup candidate" means evidence-backed,
  reversible, and scoped;
- external tools already encode cleanup semantics that raw folder deletion does
  not know;
- "cache" has different meanings across macOS, Windows, Linux, Docker, package
  managers, SDKs, and build systems;
- rule-pack updates can change product behavior without changing scanner code;
- the UI can accidentally create pressure to delete high-risk items if risk,
  confidence, and counter-evidence are not explicit.

This is P0 because a false-positive recommendation can delete persistent app
data, project state, Docker volumes, Android emulator userdata, SDK packages,
archives, shared package stores, or cloud-synced files even when scan size,
path, and metadata were technically correct.

## Current Global Ranking

1. Recommendation policy, rule-pack safety, and false-positive control - 🎯 8  🛡️ 10  🧠 8, roughly 1500-4200 LOC/tests/docs.
   Selected now. This controls which large things become cleanup candidates and
   how much friction each action needs.
2. Restore, quarantine, and undo semantics after cleanup - 🎯 6  🛡️ 9  🧠 9, roughly 1800-5000 LOC/tests/docs.
   Still next after this. Even good recommendations need honest undo/restore
   semantics across Trash, cloud, network shares, tool commands, and partial
   failures.
3. Tool command execution sandbox and side-effect control - 🎯 6  🛡️ 8  🧠 8, roughly 1200-3600 LOC/tests/docs.
   This may become its own file later. Official commands are safer than raw
   deletion, but command execution brings PATH spoofing, scripts, environment,
   locks, credentials, output parsing, and timeout risks.

## Core Rule

Analyzer facts are not cleanup authority.

```text
scan facts
  -> classification evidence
  -> recommendation claim
  -> delete/tool action plan
  -> execution preflight
  -> receipt
  -> rescan/reconcile
```

Rules:

- no recommendation without stable rule ID;
- no cleanup action without evidence;
- no one-click cleanup across mixed risk tiers;
- no path substring alone can authorize cleanup;
- no unknown large folder becomes a cleanup candidate by default;
- no rule-pack update can silently increase destructive authority;
- no recommendation survives identity, rule-pack, or scan-snapshot mismatch;
- DeletePlan still revalidates even if recommendation confidence is high.

## Recommendation Claim Model

Recommendations must be claims with evidence, counter-evidence, scope, and
expiry.

```text
RecommendationClaim
  recommendation_id
  candidate_node_id
  source_snapshot_id
  path_fingerprint
  identity_facts
  rule_pack_id
  rule_pack_version
  rule_ids[]
  evidence[]
  counter_evidence[]
  owner
  storage_semantics
  risk_tier
  confidence
  allowed_actions[]
  blocked_actions[]
  reclaim_estimate
  user_cost_estimate
  required_confirmation_level
  expires_at
```

Important separation:

- `risk_tier` says what can go wrong;
- `confidence` says how sure we are about the classification;
- `allowed_actions` says what the product can offer;
- `blocked_actions` says what the product must not offer even if the item is
  large;
- `user_cost_estimate` captures likely rebuild, re-download, re-login, emulator
  reset, package reinstall, or lost local state cost.

Kill criteria:

- recommendation DTO has only path and size;
- "cache" is a boolean;
- UI can call cleanup directly from a scan row;
- rule output has no counter-evidence field;
- receipts do not record rule IDs and rule-pack version.

## Risk Tiers

Use risk tiers that reflect ownership and recoverability, not folder names.

```text
inspect_only
  large but unknown, no cleanup action

known_rebuildable_cache
  likely recreatable, review required

tool_managed_cleanup
  cleanup should run through official adapter or documented command

project_build_output
  project-scoped generated artifacts, usually rebuildable

shared_dependency_store
  rebuildable or re-downloadable, but affects many projects

app_managed_data
  persistent app data, no generic cleanup

container_or_vm_state
  can include databases, volumes, images, snapshots, emulator state

cloud_or_remote_sensitive
  local deletion can propagate or trigger provider-specific behavior

system_managed_storage
  redirect to OS/tool, no raw delete

blocked_dangerous
  do not recommend cleanup
```

Rules:

- `Application Support` and XDG data/state roots default to `app_managed_data`
  unless a specific tool adapter proves safer semantics.
- Docker volumes default to `container_or_vm_state`, not cache.
- Android AVDs default to `container_or_vm_state` because they can hold emulator
  userdata.
- package-manager shared stores default to `shared_dependency_store` or
  `tool_managed_cleanup`, not raw delete.
- cloud roots default to `cloud_or_remote_sensitive`, even if path names contain
  `cache`.
- Downloads cleanup is a user-policy decision, not automatic cache cleanup.

Kill criteria:

- "under Caches" always means low risk;
- "not modified recently" is enough to recommend deletion;
- "unused by active process" is enough to delete shared stores;
- Docker volume cleanup is grouped with build cache cleanup;
- OneDrive/iCloud/Dropbox/Google Drive files are recommended without provider
  semantics.

## Evidence And Counter-Evidence

Evidence must be structured and testable.

Positive evidence examples:

```text
path_under_standard_cache_root
official_tool_reports_reclaimable
tool_dry_run_available
project_manifest_detected
lockfile_detected
generated_output_marker_detected
last_used_over_threshold
owner_tool_version_detected
package_store_reference_graph_available
snapshot_bound_to_current_identity
```

Counter-evidence examples:

```text
path_under_application_support
path_under_xdg_data_or_state
docker_volume_detected
android_avd_userdata_detected
cloud_sync_root_detected
network_or_fuse_mount_detected
active_process_uses_path
permission_probe_incomplete
tool_version_unknown
official_cleanup_unavailable
rule_pack_version_changed
identity_changed_since_scan
```

Rules:

- weak evidence can create an `inspect_only` card, not a cleanup action;
- destructive action requires strong evidence and no blocking counter-evidence;
- UI text is generated from reason codes, not ad hoc path guesses;
- details panel must show why an item is recommended and why some actions are
  blocked;
- support bundle must include redacted evidence IDs and rule IDs.

Kill criteria:

- recommendation says "safe to delete" without showing evidence;
- counter-evidence is logged but ignored;
- evidence cannot be snapshot-tested;
- localization changes semantics of warnings.

## Rule-Pack Trust And Versioning

Rule packs are product behavior and need release discipline.

MVP rule-pack shape:

```text
RulePack
  id
  version
  compatibility_range
  rules[]
  risk_policy
  evidence_schema_version
  fixture_set_version
  provenance
```

Rules:

- MVP rules should be typed Rust code, not arbitrary scripts.
- External JSON/YAML rule catalogs may classify only after signed catalog,
  schema validation, compatibility gates, fixture tests, and review tooling
  exist.
- Rule packs must not execute commands.
- Rule-pack update must not grant new destructive authority outside the app
  release/update trust model.
- Rule IDs and versions are stable. Receipts remain readable after rule removal.
- Rule-pack changes that affect classification invalidate recommendation caches.
- Rule-pack provenance belongs in release evidence.

Kill criteria:

- community rule can create a delete action in MVP;
- rule ID changes without migration;
- rule-pack update changes cleanup behavior without compatibility manifest;
- rule-pack can run shell commands;
- old recommendation remains actionable after rule-pack upgrade.

## Official Tool Adapter Policy

Official tool cleanup beats raw deletion when a tool owns the storage.

Adapter flow:

```text
detect tool ownership
  -> verify binary and version
  -> query official status/path if available
  -> create preview or dry run if supported
  -> show action scope and risk
  -> execute with bounded environment
  -> capture structured output summary
  -> rescan affected roots
  -> store receipt
```

Examples:

```text
Docker:
  docker system df
  docker image/container/network/buildx prune
  docker volume prune only with high friction and volume-specific warning

npm:
  npm cache verify
  npm cache clean --force only as explicit cache action
  npm prune --dry-run --json for project node_modules

pnpm:
  pnpm store path
  pnpm store prune

Yarn:
  yarn cache clean
  yarn cache clean --mirror
  yarn cache clean --all

Gradle:
  prefer Gradle-managed cleanup policy awareness
  avoid raw global cache deletion as default

Cargo:
  cargo clean --dry-run
  cargo clean

Dart/Pub:
  dart pub cache repair
  dart pub cache clean

pip:
  python -m pip cache info
  python -m pip cache remove
  python -m pip cache purge

Homebrew:
  brew cleanup --dry-run
  brew cleanup

CocoaPods:
  pod cache list
  pod cache clean NAME
  pod cache clean --all only with explicit high-friction confirmation

Android:
  sdkmanager --uninstall PACKAGE
  avdmanager delete avd -n NAME
```

Rules:

- official command path must be resolved safely, not blindly from user-writable
  PATH in privileged contexts;
- command adapter must declare whether it has dry-run, precise preview,
  approximate preview, or no preview;
- no command runs while a conflicting owner process is active unless the tool
  supports that operation;
- command output is parsed into stable result codes where possible;
- command execution has timeout, cancellation, and receipt;
- raw delete fallback is advanced/manual-only and never the default for
  tool-owned global stores.

Kill criteria:

- Clean Disk deletes `~/.gradle/caches` directly as a recommendation;
- Clean Disk deletes Docker volume directories directly;
- Clean Disk treats package manager stores as ordinary folders;
- command adapter uses shell string concatenation for paths;
- command adapter has no timeout or cancellation behavior.

## UI Safety Contract

The UI must reduce pressure to delete risky items.

Required UX:

- separate tabs or filters for "largest", "cleanup candidates", and "needs
  review";
- every recommendation shows owner, risk tier, confidence, expected reclaim, and
  likely cost;
- high-risk items cannot sit in the same one-click queue with low-risk cache;
- actions show verb-specific labels: "Run Docker prune", "Clean pub cache",
  "Move selected folder to Trash", "Inspect only";
- "Add to Queue" is disabled for blocked or inspect-only items;
- details panel shows evidence and counter-evidence;
- stale recommendations visually expire and require refresh;
- rule-pack or scanner upgrade invalidates visible low-friction recommendations.

Kill criteria:

- UI shows "cleanup candidates" based only on size;
- primary button says "Delete" for tool-owned cleanup;
- queue mixes Docker volumes, npm cache, Downloads, and app data under one
  confirmation checkbox;
- user cannot see why an action is recommended;
- warnings are hidden below the fold.

## Staleness And Snapshot Binding

Recommendations must be bound to scan snapshot, identity, rule-pack, and tool
state.

Invalidate recommendation when:

- path identity changes;
- node size or kind changes materially;
- rule-pack version changes;
- tool version changes;
- cloud/provider/mount state changes;
- owner process state changes from inactive to active;
- scan is older than the configured freshness window;
- package manager metadata changed;
- update/migration occurred;
- permission quality changed.

Rules:

- stale recommendations become inspect-only until refreshed;
- DeletePlan revalidates before execution;
- receipts record whether action used fresh or refreshed facts;
- UI should show "refresh required" instead of silently removing buttons.

Kill criteria:

- recommendation from last week can be executed after a tool update;
- stale path points to a different directory but action proceeds;
- rule-pack upgrade does not invalidate cached candidates.

## Remote And Headless Policy

Remote/headless mode increases false-positive cost because the operator may not
be the owner of the data.

Rules:

- default remote/headless mode is analyze-only for new rule categories;
- destructive recommendations require server-side policy allowlist;
- rule packs can be pinned by operator policy;
- targets can be limited by root allowlist;
- receipts and audit logs are mandatory for cleanup actions;
- multi-user hosts need ownership and authorization checks before presenting
  cleanup for another user's data;
- CI/build agents can enable aggressive cleanup profiles only when workspace is
  disposable.

Kill criteria:

- remote UI can clean arbitrary user home directories by default;
- hosted UI can push a new cleanup rule into a local daemon without local policy;
- CI cleanup profile is reused on a developer laptop.

## Testing And Release Gates

Required fixtures:

```text
macos_application_support_not_cache
macos_library_caches_known_cache
windows_downloads_policy_required
windows_onedrive_cloud_sensitive
xdg_data_state_not_cache
docker_volume_blocked
docker_build_cache_tool_adapter
android_avd_blocked_without_avdmanager
android_sdk_package_tool_adapter
npm_cache_verify_only
npm_prune_dry_run_project
pnpm_store_prune_shared_store
yarn_cache_local_vs_global
gradle_user_home_no_raw_delete
cargo_target_dry_run
pub_cache_clean_tool_adapter
pip_cache_layout_not_parsed
homebrew_cleanup_dry_run
cocoapods_requires_all_confirmation
cloud_root_path_contains_cache_blocked
stale_rule_pack_invalidates_recommendation
identity_change_invalidates_recommendation
```

Required gates:

- rule fixture snapshots for every rule ID;
- false-positive regression tests for dangerous folders;
- counter-evidence precedence tests;
- rule-pack compatibility tests;
- generated UI reason-code coverage tests;
- DeletePlan refuses stale recommendation tests;
- tool adapter preview/dry-run tests where tools support preview;
- command execution injection tests;
- remote/headless policy tests;
- support receipt redaction tests.

## MVP Cut Line

Acceptable MVP:

- typed Rust rules only;
- no external community cleanup rules;
- recommendations can classify and explain;
- cleanup actions only for low-risk known cache and tool adapters with explicit
  review;
- Docker volumes, Android AVDs, app support folders, cloud roots, and unknown
  large folders are inspect-only;
- rule IDs, evidence, risk tier, confidence, and expiry exist from day one;
- stale recommendations require refresh.

Not acceptable MVP:

- deleting by path substring;
- one-click cleanup of mixed risk tiers;
- external rule pack can create destructive action;
- tool-owned stores are deleted as raw folders;
- recommendations survive rule-pack or identity changes;
- UI hides evidence and counter-evidence.

## Architecture Impact

Reusable Rust `fs_usage_*` crates:

- expose scan facts, identity, owner hints, mount/provider hints, and metadata;
- do not decide product cleanup policy unless a dedicated reusable
  recommendation crate owns typed policy;
- keep pdu adapter separate from recommendation semantics.

Clean Disk Rust host:

- owns rule-pack selection, compatibility gates, tool adapter wiring, command
  execution policy, and remote/headless policy;
- exposes paginated recommendation queries and action previews;
- emits recommendation invalidation events when snapshot, rule pack, tool state,
  or identity changes.

Flutter app:

- renders recommendations as claims, not as scan rows;
- shows evidence, risk, confidence, owner, and cost;
- never constructs cleanup actions directly from paths;
- disables stale or blocked actions.

Persistence:

- recommendation cache includes scan snapshot ID, rule-pack version, evidence
  schema version, tool version, and identity facts;
- receipts include rule IDs, action kind, adapter kind, preview summary, result,
  and post-action rescan status;
- cache migrations invalidate recommendations if semantics changed.

Protocol:

- recommendation DTOs must version risk tiers and action kinds explicitly;
- unknown risk tier or action kind fails closed;
- large counters and reclaim estimates follow existing protocol precision rules;
- tool adapter capability is exposed as data, not inferred in Flutter.

## Decision

The next global critical zone is recommendation policy, rule-pack safety, and
false-positive control.

Implementation should not start with a generic cleanup rule engine. It should
start with typed, evidence-backed rules, conservative risk tiers, official tool
adapters, snapshot-bound recommendations, and strict invalidation gates.
