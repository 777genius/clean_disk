# Implementation Edge Cases - Tool-Managed Storage And Developer Caches

Last updated: 2026-05-13.

This file records edge cases for large folders owned by developer tools, package managers, SDKs, build systems, containers, emulators, and local runtimes.

Related documents:

- [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md)
- [Implementation edge cases recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases cloud network virtual filesystems](implementation-edge-cases-cloud-network-virtual-filesystems.md)
- [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md)
- [Rust best practices research](rust-best-practices.md)

This document focuses on targets like:

- Docker images, build cache, containers, volumes, Docker Desktop VM storage;
- Xcode DerivedData, build products, Archives, simulators, DeviceSupport;
- npm, pnpm, Yarn, node_modules, npx caches;
- Dart/Flutter pub cache;
- CocoaPods cache;
- Cargo target directories and Rust build artifacts;
- Gradle user home, project `.gradle`, Android build cache;
- Android SDK packages and Android Virtual Devices;
- pip cache and Python virtual environments;
- Homebrew cache and old formula versions.

## Sources Reviewed

- Docker Docs, [`docker system prune`](https://docs.docker.com/reference/cli/docker/system/prune/). Relevant points: `system prune` removes unused containers, networks, dangling images, and build cache; volumes are not removed by default to avoid deleting important data; `--volumes` changes risk.
- Docker Docs, [Volumes](https://docs.docker.com/engine/storage/volumes/). Relevant points: volumes persist outside container lifecycle and can obscure existing container paths when mounted.
- npm Docs, [`npm cache`](https://docs.npmjs.com/cli/v11/commands/npm-cache/). Relevant points: npm cache is mostly internal, `npm cache verify` verifies cache contents, and cache cleaning is usually unnecessary because the cache is self-healing.
- npm Docs, [`npm prune`](https://docs.npmjs.com/cli/v11/commands/npm-prune/). Relevant points: removes extraneous packages from `node_modules`, supports `--dry-run`, and normal installs already prune in ordinary cases.
- pnpm Docs, [`pnpm store`](https://pnpm.io/cli/store). Relevant points: `pnpm store prune` removes unreferenced packages, is described as not harmful to projects, but too-frequent pruning slows future installs.
- Yarn Docs, [`yarn cache clean`](https://yarnpkg.com/cli/cache/clean). Relevant points: removes shared cache files; Yarn has global and local cache/mirror options.
- Gradle Docs, [Gradle-managed directories](https://docs.gradle.org/current/userguide/directory_layout.html). Relevant points: Gradle user home contains caches and distributions; Gradle automatically cleans caches/distributions on a periodic policy.
- Gradle Docs, [Build Cache](https://docs.gradle.org/current/userguide/build_cache.html). Relevant points: local build cache stores task outputs and is periodically cleaned; retention can be configured.
- Cargo Book, [`cargo clean`](https://doc.rust-lang.org/cargo/commands/cargo-clean.html). Relevant points: removes Cargo-generated artifacts from `target`, supports package/workspace selection and `--dry-run`.
- Dart Docs, [`dart pub cache`](https://dart.dev/tools/pub/cmd/pub-cache). Relevant points: `dart pub cache clean` clears the system cache and `repair` reinstalls cached packages.
- Pub cache layout docs, [The Pub cache](https://dart.googlesource.com/pub.git/%2B/4287a77c/doc/cache_layout.md). Relevant point: direct manipulation of pub cache layout is discouraged because layout details can change.
- CocoaPods Guides, [Command-line reference](https://guides.cocoapods.org/terminal/commands.html). Relevant points: `pod cache list` and `pod cache clean` exist; cleaning all cache requires explicit `--all`.
- Homebrew Docs, [Manpage](https://docs.brew.sh/Manpage.html). Relevant points: Homebrew has `brew cleanup`, cleanup age settings, and manages its own cached downloads/old versions.
- Android Developers, [`avdmanager`](https://developer.android.com/tools/avdmanager). Relevant points: `avdmanager delete avd -n name` deletes an AVD, and AVDs default to `~/.android/avd/` unless a path is provided.
- Android Developers, [`sdkmanager`](https://developer.android.com/tools/sdkmanager). Relevant point: `sdkmanager --uninstall` is the command-line path for uninstalling SDK packages.
- Apple Xcode Help, [Build and run your app](https://help.apple.com/xcode/mac/current/en.lproj/devdc0193470.html). Relevant point: Product > Clean Build Folder rebuilds all files for a project.
- Apple Developer Documentation, [Distributing documentation to other developers](https://developer.apple.com/documentation/xcode/distributing-documentation-to-other-developers). Relevant point: `xcodebuild` can use `-derivedDataPath`, and derived data contains many files produced by build processes.
- pip Docs, [`pip cache`](https://pip.pypa.io/en/stable/cli/pip_cache.html) and [Caching](https://pip.pypa.io/en/stable/topics/caching.html). Relevant points: `pip cache` inspects/manages wheel cache, cache layout is an implementation detail, and `pip cache purge` clears wheel and HTTP caches.

## Severity Scale

- `P0` - can delete persistent user/project data, wipe container volumes, break active builds, corrupt SDK state, delete shared dependency stores, or execute untrusted tool scripts.
- `P1` - can cause slow rebuilds, broken developer environments, confusing reclaim estimates, stale recommendations, or support burden.
- `P2` - useful polish, extra adapters, better heuristics, or later workflow automation.

## Top 3 Product Decisions

1. Tool-managed storage is classified first and cleaned through tool adapters, not raw path deletion - 🎯 10 🛡️ 10 🧠 7, roughly 900-2600 LOC across classifiers, adapters, preview DTOs, receipts, and tests.
2. Recommendation engine shows official cleanup actions with risk tiers and evidence - 🎯 9 🛡️ 9 🧠 6, roughly 700-1800 LOC across rules, command previews, UI labels, and safety copy.
3. Raw folder delete for known tool stores stays advanced/manual-only - 🎯 8 🛡️ 8 🧠 3, roughly 200-700 LOC for warnings and blocking rules, but weak as a full product experience.

Rejected default:

- "Big folder under cache path means safe to delete."

That rule will eventually delete someone's Docker database volume, emulator image, shared package store, or expensive build state.

## Core Principle

Tool-managed storage has an owner.

The owner might be Docker, npm, pnpm, Yarn, Gradle, Xcode, Android Studio, Cargo, Homebrew, pip, Pub, CocoaPods, or another runtime. Clean Disk can scan and explain the folder, but cleanup should prefer the owner's supported operation.

Required model:

```text
scan tree node
  -> classifier evidence
  -> tool storage identity
  -> cleanup capability
  -> preview/reclaim estimate
  -> explicit action adapter
  -> receipt with tool output summary
```

The app should distinguish:

- ordinary user folder;
- rebuildable project build output;
- package-manager cache;
- shared content-addressed store;
- tool-managed persistent data;
- virtual disk or VM image;
- emulator/device state;
- dependency install tree;
- unknown large directory.

## Classification Model

### "Cache" Is Not One Risk Tier - `P0`

Examples:

```text
low risk:
  npm HTTP cache
  pip wheel cache
  pub system cache
  Yarn global cache

medium risk:
  Xcode DerivedData
  Cargo target
  Gradle build cache
  node_modules in a project with lockfile

high risk:
  Docker volumes
  Android AVD user data images
  Xcode Archives
  local databases inside app support folders
  package-manager stores shared by many projects
```

Required behavior:

- every cleanup candidate has `storage_owner`;
- every candidate has `risk_tier`;
- every candidate has evidence paths and matched rules;
- user can inspect why the item is recommended;
- unsafe/unknown candidates are analyze-only until a specific adapter exists.

### Use Evidence, Not Only Path Names - `P0`

Path name alone is too weak.

Evidence examples:

- marker files: `package.json`, `pnpm-lock.yaml`, `Cargo.toml`, `Podfile.lock`, `build.gradle`, `gradle-wrapper.properties`;
- tool config: `GRADLE_USER_HOME`, `PUB_CACHE`, npm `cache`, Yarn `cacheFolder`, pnpm store path;
- official command output: `docker system df`, `pnpm store path`, `npm cache verify`, `pip cache dir`;
- folder layout: `.gradle/caches`, `target/debug`, `.android/avd/*.avd`, `DerivedData/*/Build`;
- process state: Xcode running, Docker daemon running, emulator running, Gradle daemon running;
- lockfiles and active handles where detectable.

Rules:

- weak evidence produces warning-only recommendation;
- destructive action requires strong evidence;
- official command availability changes capability;
- tool version is recorded in preview/receipt when possible.

### Project Build Output And Shared Stores Are Different - `P0`

`target/`, `build/`, `.dart_tool/`, `.gradle/`, and `node_modules/` near a project are project-scoped. `~/.gradle`, pnpm store, npm cache, pub cache, CocoaPods cache, and Docker storage are shared stores.

Required behavior:

- project-scoped outputs can be cleaned per project with lower blast radius;
- shared stores require tool-owned cleanup or stronger confirmation;
- UI shows how many projects may be affected when known;
- reclaim estimate notes likely re-download/rebuild cost;
- receipts record whether action was project-scoped or global.

## Tool Adapter Policy

### Official Cleanup Commands Beat Manual Deletes - `P0`

Preferred sequence:

1. Detect tool and candidate.
2. Ask tool for path/status/usage where possible.
3. Generate preview/dry-run where supported.
4. Execute official cleanup command or API.
5. Capture structured output summary.
6. Rescan affected roots.
7. Store receipt.

Examples:

```text
npm:
  npm cache verify
  npm cache clean --force only as explicit action
  npm prune --dry-run for project node_modules

pnpm:
  pnpm store path
  pnpm store prune

Yarn:
  yarn cache clean
  yarn cache clean --mirror

Cargo:
  cargo clean --dry-run
  cargo clean

Dart/Pub:
  dart pub cache clean
  dart pub cache repair

CocoaPods:
  pod cache list
  pod cache clean NAME
  pod cache clean --all

pip:
  python -m pip cache info
  python -m pip cache purge

Android:
  avdmanager delete avd -n NAME
  sdkmanager --uninstall PACKAGE

Homebrew:
  brew cleanup

Docker:
  docker system df
  docker system prune
  docker builder prune
  docker volume prune only under high-friction flow
```

Manual folder deletion should be a fallback only for:

- project build output where official command is unavailable;
- user explicitly chose manual delete;
- adapter marks it as rebuildable and not persistent;
- tool is not installed but evidence is strong and risk is acceptable.

### Tool Adapters Must Be Ports, Not Hardcoded UI Buttons - `P0`

Clean Architecture fit:

```text
domain:
  ToolStorageCandidate
  StorageOwner
  CleanupRisk
  CleanupActionKind
  ReclaimEstimate

application:
  ToolStorageClassifierPort
  ToolCleanupPreviewPort
  ToolCleanupExecutorPort
  ToolCapabilityQueryPort

infrastructure:
  DockerAdapter
  NpmAdapter
  PnpmAdapter
  XcodeAdapter
  AndroidSdkAdapter
  CargoAdapter
  GradleAdapter
  HomebrewAdapter
  PipAdapter

presentation:
  candidate list
  details
  preview dialog
  receipt view
```

Rules:

- UI does not construct shell commands;
- domain does not know CLI syntax;
- adapter outputs are mapped into typed outcomes;
- command execution is allowlisted per adapter;
- no arbitrary user-entered shell command in MVP.

### Cleanup Commands Can Run User Code - `P0`

Some package manager commands can trigger scripts or build logic. Even seemingly innocent commands may inspect project files, run lifecycle hooks, or load plugins depending on tool and command.

Required behavior:

- adapter command allowlist is narrow;
- prefer commands documented as cache/prune/clean without project script execution;
- use dry-run where available;
- run from a safe working directory;
- set minimal environment;
- never run cleanup commands with elevated privileges by default;
- command preview shows exact command class, not necessarily raw shell if args contain private paths;
- receipts redact tokens/env.

For MVP, avoid tool actions that run arbitrary project scripts.

## Docker Edge Cases

### Docker Volumes Are Persistent Data - `P0`

Docker documents that volumes persist outside container lifecycle. A stopped container does not mean its data is disposable. A volume might contain a database, upload storage, local dev data, or production-like state.

Required behavior:

- Docker volumes are high risk by default;
- `docker system prune` without `--volumes` is separate from volume prune;
- `docker volume prune` requires high-friction confirmation;
- UI shows that volume deletion may remove persistent application data;
- receipt records volume IDs/names and Docker daemon context;
- remote Docker daemon context is visible before any action.

Forbidden default:

- direct delete of Docker Desktop VM files;
- direct delete of `/var/lib/docker/volumes`;
- treating anonymous volume as safe solely because it is anonymous;
- deleting volumes from remote Docker daemon without explicit remote context.

### Docker Build Cache And Images Are Rebuildable But Costly - `P1`

Images, layers, and build cache are usually rebuildable, but cleanup can cause large re-downloads and slow builds.

Required behavior:

- distinguish build cache, dangling images, unused images, containers, networks, volumes;
- show `docker system df` where available;
- separate safe-ish prune from aggressive prune;
- ask about `-a`/all unused images separately;
- do not combine image prune and volume prune in one casual button;
- warn if Docker daemon is actively building or containers are running.

### Docker Desktop VM Size Can Mislead Scan Results - `P1`

On macOS/Windows, Docker may store data in a VM disk image. Deleting files inside Docker may not immediately shrink the host sparse image.

Required behavior:

- show Docker Desktop storage as tool-managed VM storage;
- report that host free-space reclaim may differ from Docker internal reclaim;
- do not promise exact host bytes until after rescan/free-space sample;
- future adapter can surface Docker's own reclaimable metrics.

## Xcode And Apple Developer Tools

### DerivedData Is Usually Rebuildable, But Active Xcode Matters - `P1`

Xcode DerivedData contains build intermediates, indexes, logs, and generated products. Deleting stale project folders is common, but doing it while Xcode builds/indexes can cause broken or confusing state.

Required behavior:

- detect Xcode/SourceKit/simulator activity where feasible;
- recommend quitting Xcode or stopping builds before cleanup;
- classify per-project DerivedData folders separately;
- prefer per-project cleanup over full DerivedData cleanup;
- show rebuild/indexing cost;
- rescan after cleanup.

### Xcode Archives Are Not DerivedData - `P0`

Archives can contain app builds, dSYMs, and distribution artifacts. They may be needed for crash symbolication or releases.

Required behavior:

- archives are high risk;
- never classify archives as cache;
- show creation date, app/project name where available;
- delete only through explicit archive cleanup workflow;
- warn about symbolication/release history.

### Simulators And Device Support Are Tool State - `P1`

Simulator runtimes/devices and DeviceSupport can be large. Some are easy to recreate; some represent test devices, app data, or installed simulator apps.

Required behavior:

- distinguish simulator runtime, simulator device data, logs, caches, DeviceSupport;
- running simulators block delete;
- device data requires high-friction confirmation;
- future adapter should prefer `simctl` where possible;
- user-visible copy says what will be re-downloaded versus lost.

## Node Package Managers

### `node_modules` Is Rebuildable Only With Context - `P0`

`node_modules` can usually be recreated if the project has a lockfile and registry/network access. But it can include:

- local linked packages;
- patched packages;
- generated native modules;
- offline-only dependencies;
- private registry packages;
- checked-in vendored modules;
- workspace symlinks;
- package manager specific layout.

Required behavior:

- classify package manager from lockfiles;
- detect npm/yarn/pnpm/bun where possible;
- show lockfile presence;
- show private registry/offline warning when detectable;
- delete project `node_modules` only as project cleanup action;
- do not delete pnpm store when user selected one project's `node_modules`;
- explain rebuild command, for example `npm install`, `pnpm install`, or `yarn install`.

### npm Cache Is Self-Healing, But Force Clean Is Still A Real Action - `P1`

npm docs say cache cleaning is usually unnecessary and `verify` is the safer operation.

Required behavior:

- default action: inspect/verify;
- clean action is explicit;
- show that packages will be re-downloaded;
- separate npm cache from `node_modules`;
- use npm config to discover cache path when possible;
- never delete cache internals directly if npm CLI is available.

### pnpm Store Is Shared And Content-Addressed - `P1`

pnpm store may be shared across many projects. `pnpm store prune` removes unreferenced packages and is considered safe by docs, but doing it too often can slow branch switching or older project installs.

Required behavior:

- use `pnpm store path`;
- prefer `pnpm store prune`;
- show "shared store" label;
- warn about future re-downloads;
- do not delete store folder directly;
- handle global virtual store if enabled.

### Yarn Has Global And Local Cache Modes - `P1`

Yarn Classic and modern Yarn have different cache layouts. Modern Yarn can use project local `.yarn/cache`, global cache, or mirror behavior.

Required behavior:

- detect Yarn version/lockfile;
- distinguish `.yarn/cache` inside project from global cache;
- do not delete `.yarn/releases`, `.yarn/plugins`, `.yarn/sdks`, or `.pnp.*` as cache;
- use `yarn cache clean` actions when available;
- show when deleting local cache affects offline/zero-install workflows.

## Dart, Flutter, CocoaPods

### Pub Cache Layout Is Not A Contract - `P1`

Dart pub cache docs discourage direct manipulation because layout evolves.

Required behavior:

- use `dart pub cache clean` or `flutter pub cache clean` where appropriate;
- use `dart pub cache repair` for repair workflow, not cleanup;
- discover `PUB_CACHE`;
- distinguish global pub cache from project `.dart_tool` and `build`;
- do not delete Flutter SDK `bin/cache` as ordinary cache.

### Flutter Project Build Output Is Project-Scoped - `P1`

`build/`, `.dart_tool/`, platform build outputs, and generated files can be recreated but may be expensive.

Required behavior:

- show project root and detected Flutter/Dart markers;
- `flutter clean` is an adapter action when Flutter is available;
- direct folder delete is fallback only;
- warn if IDE/dev server/test is running;
- keep generated source directories separate from build caches.

### CocoaPods Cache Has Its Own CLI - `P1`

CocoaPods has `pod cache list` and `pod cache clean`, and full cleanup requires explicit `--all`.

Required behavior:

- prefer `pod cache` commands over deleting `~/Library/Caches/CocoaPods`;
- distinguish global CocoaPods cache from project `Pods/`;
- project `Pods/` deletion requires `Podfile.lock` context and rebuild command;
- warn about private pods and offline installs;
- do not delete CocoaPods specs/repos as generic cache without adapter support.

## Rust And Cargo

### Cargo `target` Is Safe-ish, But Not Always Local - `P1`

Cargo `target` is generated build output. However, `CARGO_TARGET_DIR` can point outside the project, and workspaces can share targets.

Required behavior:

- detect Cargo workspace root;
- detect `.cargo/config*` and `CARGO_TARGET_DIR` when possible;
- prefer `cargo clean --dry-run` for preview;
- use `cargo clean` with package/workspace options where possible;
- do not assume every folder named `target` is Cargo output;
- avoid deleting shared target directory as if it belonged to one project.

### Cargo Registry/Git Cache Is Different From Target - `P1`

Cargo has global registry/git cache under Cargo home. Deleting it causes re-downloads and can affect offline work.

Required behavior:

- classify Cargo home separately;
- do not recommend global Cargo cache deletion in MVP unless user specifically chooses advanced cleanup;
- prefer project target cleanup first;
- note offline/rebuild cost.

## Gradle And Android

### Gradle Already Has Cleanup Policy - `P1`

Gradle user home is managed and periodically cleaned. Direct deletion can slow builds and break offline work.

Required behavior:

- detect `GRADLE_USER_HOME`;
- classify Gradle user home as shared tool-managed storage;
- prefer Gradle's own cleanup behavior and settings;
- avoid raw delete of `~/.gradle/caches` in MVP;
- project `build/` directories are separate and lower risk;
- `.gradle` project cache can be cleaned with project context.

### Android SDK Packages Should Use SDK Manager - `P1`

Android SDK packages and system images can be large, but direct deletion can leave SDK Manager confused.

Required behavior:

- use `sdkmanager --list` and `--uninstall` in future adapter;
- classify SDK platforms, build-tools, emulator, system images separately;
- warn that removing system images affects emulators/projects;
- do not delete SDK package folders directly when sdkmanager is available;
- receipt records package IDs.

### Android AVDs Contain Device State - `P0`

AVDs can hold installed apps, test data, snapshots, and virtual disks. Deleting an AVD is not just deleting cache.

Required behavior:

- AVDs are medium/high risk depending on data state;
- running emulator blocks deletion;
- use `avdmanager delete avd -n NAME`;
- show AVD name, path, API/system image, size, last modified;
- direct delete of `.android/avd/*.avd` is fallback only after lock/running checks;
- receipt records AVD name and path.

## Python And pip

### pip Cache Is Managed By pip - `P1`

pip docs say cache layout is implementation detail.

Required behavior:

- use `python -m pip cache dir/info/list/remove/purge`;
- classify wheel cache and HTTP cache separately if available;
- do not delete cache internals directly when pip is available;
- warn that repeated builds/downloads may be slower;
- virtualenv/site-packages cleanup is a different workflow from pip cache cleanup.

### Python Virtual Environments Are Project State - `P1`

`.venv`, `venv`, and Conda environments can be recreated sometimes, but they may contain local editable installs, notebooks, kernels, generated files, or manually installed packages.

Required behavior:

- detect pyproject/requirements/lockfiles;
- distinguish project venv from global Python install;
- require high-friction confirmation for venv deletion;
- show likely recreate command only if known;
- never delete global site-packages as cleanup recommendation.

## Homebrew

### Homebrew Owns Its Cellar, Cache, And Cleanup Policy - `P1`

Homebrew tracks installed formulae, old versions, downloads, and cleanup age.

Required behavior:

- prefer `brew cleanup`;
- show Homebrew prefix and cache path;
- do not delete Cellar or Caskroom folders directly;
- use `brew cleanup --dry-run` if supported by installed brew version;
- warn that cleanup can remove old versions needed for rollback;
- do not run brew actions under sudo.

## Recommendation And UX

### Explain Rebuild Cost, Not Just Reclaim Bytes - `P1`

Developer caches trade disk for time.

UI should show:

- estimated local reclaim;
- risk tier;
- rebuild/re-download cost: low, medium, high, unknown;
- affected tool;
- official cleanup command/action;
- whether network will be needed later;
- whether active processes were detected.

Example labels:

```text
Docker build cache
  Reclaim: 18.4 GB
  Risk: medium
  Cost: future image builds may be slower
  Action: Docker builder prune

Docker volume
  Reclaim: unknown
  Risk: high
  Cost: may delete database/application data
  Action: advanced only
```

### Preview Must Show Action Semantics - `P0`

Before cleanup, show:

- owner tool;
- exact action kind;
- target scope: project, global cache, shared store, persistent volume;
- whether official command supports dry-run;
- what cannot be undone;
- what will be recreated automatically;
- what may require network/download;
- active process warnings;
- receipt policy.

For high-risk items, require typed acknowledgement or separate confirmation.

### Do Not Combine Unrelated Tool Actions In One Button - `P0`

"Clean developer caches" is too broad.

Forbidden MVP action:

```text
Clean all dev caches
```

Safer:

```text
Review Docker cleanup
Review Xcode DerivedData
Review Cargo target folders
Review package manager caches
```

Each category has its own preview and confirmation.

## Remote And Multi-User Mode

### Tool Storage Belongs To A User Or Daemon Context - `P0`

Remote/headless mode can scan a server where tools run under different users.

Required behavior:

- cleanup actions run as the daemon user only;
- UI shows effective user/host;
- Docker context/daemon host is visible;
- global caches for other users are not touched;
- no sudo/admin escalation in MVP;
- audit records tool owner, host, user, and action.

### Shared CI Runners And Build Servers Are Different - `P1`

Build servers intentionally keep caches warm.

Required behavior:

- remote/headless defaults to analyze-only for shared tool stores;
- cleanup requires explicit admin policy;
- CI caches have retention policy rather than ad hoc delete;
- recommendations include performance impact warning;
- audit required for destructive cleanup.

## Security

### Tool Command Injection Must Be Designed Out - `P0`

Adapters must not concatenate shell strings from paths.

Required behavior:

- execute commands with argv arrays;
- allowlisted binary and subcommand;
- path args validated and canonicalized where needed;
- no shell expansion;
- no user-supplied extra flags in MVP;
- environment allowlist;
- timeout and cancellation;
- output size limits;
- stderr/stdout redaction.

### Tool Output Is Untrusted Input - `P1`

Tool output can contain paths, terminal control sequences, malicious package names, or huge logs.

Required behavior:

- parse structured output where available;
- strip ANSI/control sequences before UI/logs;
- cap output stored in receipts;
- redact sensitive paths/tokens;
- keep raw logs only in opt-in support bundle;
- never render tool output as HTML/Markdown without escaping.

## Data Model

Recommended domain concepts:

```text
StorageOwner:
  docker
  xcode
  npm
  pnpm
  yarn
  pub
  cocoapods
  cargo
  gradle
  android_sdk
  android_avd
  pip
  homebrew
  unknown

StorageClass:
  project_build_output
  dependency_install_tree
  package_cache
  shared_content_store
  build_cache
  persistent_volume
  virtual_device
  sdk_package
  archive
  tool_log
  unknown

CleanupActionKind:
  official_tool_clean
  official_tool_prune
  official_tool_delete_device
  official_tool_uninstall_package
  direct_trash_project_output
  analyze_only
```

Required candidate fields:

```text
candidate_id
storage_owner
storage_class
risk_tier
confidence
path_display
path_identity_snapshot
tool_version?
tool_context?
scope: project | user_global | machine_global | remote_daemon | unknown
official_action_available
dry_run_available
rebuild_cost
network_needed_later
active_process_warning
estimated_reclaim
evidence[]
warnings[]
```

## Testing Matrix

### Classifier Fixtures

Required:

- folder named `cache` that is not a cache;
- folder named `target` that is not Cargo;
- Cargo workspace with shared target dir;
- npm project with package-lock;
- pnpm project with global store;
- Yarn modern project with `.yarn/cache`;
- Flutter project with `build/` and `.dart_tool`;
- CocoaPods project with `Pods/` and `Podfile.lock`;
- Gradle project and `~/.gradle`;
- Docker Desktop data root fixture;
- Android AVD folder with lock files;
- Xcode DerivedData and Archives-like folders;
- Python `.venv` and pip cache.

### Adapter Tests

Required:

- command preview without execution;
- dry-run parsing where supported;
- tool missing;
- old tool version;
- command timeout;
- command cancelled;
- command output too large;
- command output with ANSI/control characters;
- command returns partial success;
- command returns localized output;
- active process blocks cleanup;
- receipt redacts paths/tokens.

### Safety Tests

Required before delete-capable release:

- Docker volume never low-risk;
- Xcode Archive never cache;
- Android AVD running blocks delete;
- raw delete is blocked for shared stores;
- project build output can be queued only with project context;
- official adapter failure does not fall back to raw delete automatically;
- high-risk actions require stronger confirmation;
- unknown tool store is analyze-only.

## MVP Cut Line

MVP should support:

- classification for common developer storage;
- analyze-only for high-risk persistent tool data;
- official adapters for a small first set:
  - Cargo `target` via `cargo clean --dry-run` / `cargo clean`;
  - npm cache verify/clean and npm prune dry-run where safe;
  - pnpm store path/prune;
  - Dart pub cache clean;
  - Docker system df and safe-ish prune preview, no volume prune by default;
  - Xcode DerivedData classification, cleanup only with strong warning;
- no raw delete of Docker volumes, AVDs, SDK packages, Homebrew Cellar, or shared package stores;
- receipts for every tool cleanup;
- rescans after cleanup;
- rebuild cost labels.

MVP defers:

- full Docker volume cleanup;
- Android SDK uninstall adapter;
- AVD deletion adapter;
- Homebrew cleanup execution;
- Gradle user home cleanup control;
- pip/Conda/Poetry virtualenv deletion;
- Xcode Archives cleanup;
- CI/server cache retention policies;
- arbitrary custom cleanup scripts.

## Summary

The rule for developer storage:

```text
scan broadly
classify conservatively
prefer official tool cleanup
preview before execution
separate cache from persistent data
record receipt
rescan after action
never let path name alone authorize delete
```

📌 The highest-value cleanup targets are often developer tool folders, but they are also where "just delete the big folder" becomes dangerous. Clean Disk should act like a cautious operator of each tool, not like `rm -rf` with a nicer UI.
