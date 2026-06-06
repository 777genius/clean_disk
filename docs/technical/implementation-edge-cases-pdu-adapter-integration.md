# Implementation Edge Cases - pdu Adapter Integration

Last updated: 2026-05-13.

This file records edge cases for integrating `parallel-disk-usage` (`pdu`) as the Rust scanner adapter.

Related documents:

- [Architecture decisions](architecture-decisions.md)
- [Rust architecture](rust-architecture.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases concurrency state machines](implementation-edge-cases-concurrency-state-machines.md)
- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)

This document is not a decision to expose pdu directly to the app. The accepted decision remains: pdu is an adapter. The reusable `fs_usage_*` library owns the scanner port, scan session model, scan tree identity, progress DTOs, query indexes, and reusable cleanup safety primitives. Clean Disk owns the host process, protocol mapping, transport, and UI workflows.

## Sources Reviewed

- `parallel-disk-usage`, [docs.rs crate docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/). Relevant points: version 0.23.0 exposes a library crate; the main public entry points are `fs_tree_builder::FsTreeBuilder`, `tree_builder::TreeBuilder`, `data_tree::DataTree`, and `visualizer::Visualizer`.
- `parallel-disk-usage`, [GitHub README](https://github.com/KSXGitHub/parallel-disk-usage). Relevant points: pdu is positioned as a fast CLI, extensible through library crate or JSON interface, has optional progress reporting, optional hardlink detection/deduplication, does not follow symlinks, is ignorant of reflinks, and release binaries from 0.23.0 have provenance attestations.
- `parallel-disk-usage`, [FsTreeBuilder docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/fs_tree_builder/struct.FsTreeBuilder.html). Relevant points: builder fields include root, size getter, hardlink recorder, reporter, device boundary, and max depth; max depth affects display depth while sizes beyond max depth still count toward total.
- `parallel-disk-usage`, [DataTree docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/data_tree/struct.DataTree.html). Relevant points: `DataTree` stores disk usage data, has private fields, exposes name/size/children methods, and does not implement `Serialize` directly, instead using reflection for JSON.
- `parallel-disk-usage`, [Reporter docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/trait.Reporter.html). Relevant points: reporter receives progress events through a synchronous `report` method.
- `parallel-disk-usage`, [Event docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/event/enum.Event.html). Relevant points: event enum is non-exhaustive and currently includes receive-data, encounter-error, and detect-hardlink events.
- `parallel-disk-usage`, [ProgressReport docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/progress_report/struct.ProgressReport.html). Relevant points: progress tracks item count, total size, error count, hardlink count, and shared hardlink size.
- `parallel-disk-usage`, [Quantity docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/args/quantity/enum.Quantity.html). Relevant points: quantity can be apparent size, block size, or block count.
- `parallel-disk-usage`, [DeviceBoundary docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/device/enum.DeviceBoundary.html). Relevant points: device boundary policy can cross or stay within filesystem boundary.
- `parallel-disk-usage`, [feature flags](https://docs.rs/crate/parallel-disk-usage/latest/features). Relevant points: default features include CLI-related dependencies and JSON.
- Rust standard library, [Unix MetadataExt](https://doc.rust-lang.org/std/os/unix/fs/trait.MetadataExt.html). Relevant points: Unix metadata exposes `dev`, `ino`, `nlink`, `size`, `blocks`, and related values used for filesystem identity and block-size semantics.
- Rayon, [GitHub README](https://github.com/rayon-rs/rayon). Relevant point: Rayon gives easy data parallelism but side effects in parallel iterators can happen in different order, so adapter event ordering must not assume traversal order.

## Severity Scale

- `P0` - can cause wrong size/reclaim claims, wrong cleanup identity, stale or partial scan safety bugs, production dependency breakage, or unresponsive daemon under scan load.
- `P1` - can cause misleading UI, performance regressions, excessive memory, broken cancellation, inconsistent progress, or adapter upgrade surprises.
- `P2` - important polish, maintainability, distribution, benchmark, or future extensibility risk.

## Top 3 Integration Strategies

1. Thin pdu adapter behind a strict `fs_usage_engine` scanner port - 🎯 9 🛡️ 9 🧠 5, roughly 600-1500 LOC across adapter mapping, contract tests, version pinning, progress throttling, and fixture tests.
2. pdu adapter plus small maintained fork only if cancellation/progress/tree identity needs cannot be met upstream - 🎯 8 🛡️ 8 🧠 7, roughly 1500-4000 LOC including fork sync policy, patch tests, and upstream contribution workflow.
3. Replace pdu with a custom scanner now - 🎯 4 🛡️ 6 🧠 9, roughly 4000-12000 LOC before matching mature edge cases; too much risk before product contracts are proven.

Recommendation: start with a thin pdu library adapter, not CLI wrapping and not a custom scanner. Build a scanner contract test suite before depending on pdu behavior in the app. Fork only after we know the exact missing capability and can keep the fork small.

## Core Principle

pdu is a traversal and aggregation dependency, not the reusable scanner domain.

Required shape:

```text
fs_usage_engine scanner port
  -> pdu adapter config mapper
  -> pdu FsTreeBuilder/DataTree/Reporter
  -> fs_usage snapshot/read-model builder
  -> Rust-owned query indexes
  -> Clean Disk protocol DTO pages/events
```

Never expose pdu types through:

- domain entities;
- application ports;
- protocol DTOs;
- Flutter models;
- cleanup DeletePlan;
- persisted scan history.

## Adapter Boundary Edge Cases

### pdu Public API Is Useful But Not Our Contract - `P0`

pdu exposes library APIs, but those APIs are not designed around `fs_usage_*` library invariants or Clean Disk product invariants.

Required:

- define our own `ScannerBackend` or equivalent application port in `fs_usage_engine`;
- map pdu `DataTree` into the `fs_usage` snapshot/read-model and indexed node store;
- keep pdu type names out of domain/application public APIs;
- keep pdu option mapping in one adapter module;
- add compile/import boundary tests that prevent `parallel_disk_usage` imports outside scanner infrastructure.

Avoid:

- `type FsUsageNode = pdu::DataTree`;
- passing pdu `Event` to Flutter;
- storing pdu reflection JSON as our durable scan format;
- allowing cleanup to reference pdu paths or pdu node positions.

### Dependency Features Must Be Audited - `P1`

pdu's default features include CLI and JSON-related dependencies. A daemon library integration may not need CLI features.

Required:

- before adding the dependency, check the latest stable crate version;
- start by evaluating `default-features = false` if the library APIs compile with the needed modules;
- enable only needed features explicitly;
- document selected pdu version, features, and option mapping;
- run `cargo tree` and license/security checks after adding it.

Avoid:

- pulling CLI/man-page/completion features into the daemon without need;
- relying on pdu's CLI argument structs in our app config;
- treating `Cargo.lock` upgrade as harmless when scan semantics may change.

### Version Upgrades Need Semantic Snapshot Tests - `P0`

pdu can improve hardlink, device, size, or traversal behavior between releases. That is good upstream evolution, but a product regression if our UI semantics silently change.

Required:

- pin pdu version until adapter contract tests pass against upgrade;
- fixture snapshots for size modes, hardlinks, symlinks, permission errors, device boundary, and max depth;
- benchmark pdu raw scan separately from Clean Disk indexing/protocol/UI;
- record pdu version and adapter config in scan metadata;
- changelog review before every pdu upgrade.

Avoid:

- broad semver range without semantic tests;
- assuming "faster" release is behaviorally identical;
- comparing old scan history with new pdu semantics without showing scanner version/config.

## Size Semantics Edge Cases

### Apparent Size, Block Size, Block Count, And Reclaim Are Different - `P0`

pdu supports apparent size, block size, and block count. Clean Disk also needs reclaim estimates, which are not the same thing.

Required:

- expose explicit size mode in scan config and result metadata;
- label UI metrics as `apparent size`, `size on disk`, `blocks`, or `estimated reclaim`;
- do not use apparent size as cleanup reclaim estimate;
- keep `SizeOnDisk` and `ReclaimEstimate` separate domain value objects;
- if block size is unavailable on a platform or target, mark capability as partial/unknown.

Avoid:

- one field called `size` everywhere;
- mixing pdu block count with bytes in charts;
- calculating delete queue total from a different size mode than the tree view;
- claiming exact freed space after Trash based only on scan-time pdu totals.

### Directory Inode Size Can Confuse Small Trees - `P2`

`DataTree::dir` has a directory inode size concept. Users usually care about child totals, but filesystems may allocate directory metadata.

Required:

- decide whether directory self-size is shown separately, included in total only, or hidden;
- keep tree row total and self-size distinct in internal model;
- test tiny directories where directory metadata dominates apparent files;
- avoid UI labels that imply every directory byte is inside child files.

Avoid:

- losing directory self-size during pdu-to-domain mapping;
- double-counting directory self-size in parent totals;
- inconsistent totals between details pane and tree row.

### Sparse Files And Compression Can Break Intuition - `P1`

Apparent size can be huge while allocated disk usage is small. Compression can make allocated usage smaller than apparent size. COW filesystems can share data.

pdu's README explicitly says it is ignorant of reflinks from COW filesystems.

Required:

- mark COW/reflink awareness as unsupported/unknown in scanner capabilities;
- do not claim exact reclaim for APFS clones, BTRFS reflinks, ZFS clones, or compressed files until we add platform-specific support;
- show "estimated" reclaim when clone/compression awareness is absent;
- keep apparent and allocated modes available for diagnostics.

Avoid:

- using pdu totals as exact free-space prediction on APFS/BTRFS/ZFS;
- recommending deletion solely based on apparent size in clone-heavy directories;
- hiding capability limitations from receipts.

## Hardlink Edge Cases

### Hardlink Policy Must Be A Product Choice - `P0`

pdu supports hardlink awareness/deduplication and says all hardlinks are treated as equally real. That is a better default than arbitrary first-path ownership, but cleanup safety needs explicit policy.

Required:

- scan option exposes hardlink mode: ignorant, record, deduplicate, or equivalent Clean Disk values;
- result metadata includes hardlink policy and detected hardlink counters;
- hardlink groups become first-class warning/detail data when available;
- delete candidate for a hardlinked file explains that deleting one link may not reclaim file content while other links remain;
- cleanup revalidates link count and identity before action.

Avoid:

- letting pdu hardlink policy silently decide UI copy;
- displaying deduplicated totals as if every selected path frees that amount;
- treating one path to a hardlinked inode as "the real one".

### Hardlink Deduplication Has Performance Cost - `P1`

pdu documents optional hardlink detection/deduplication and says it can make pdu slower.

Required:

- benchmark with and without hardlink detection on macOS, Linux, and Windows targets;
- expose hardlink mode in benchmark reports;
- default policy should prioritize honest cleanup estimates, not only fastest scan;
- allow scanner capability to say hardlink details unavailable if mode is off.

Avoid:

- enabling expensive hardlink detection everywhere without measuring;
- comparing pdu benchmarks against tools with different hardlink policies;
- showing "cleanup candidates" that depend on hardlink info when the scan did not collect it.

### Device And Inode Identity Are Platform-Specific - `P0`

Unix identity commonly uses device and inode. Windows uses different file identity concepts. pdu exposes inode and device modules, but `fs_usage_*` must own cross-platform identity.

Required:

- map pdu identity facts into `fs_usage` `NodeIdentitySnapshot`;
- do not assume Unix `dev + ino` works on Windows;
- keep platform filesystem identity adapter separate from pdu adapter if pdu data is insufficient;
- cleanup identity revalidation uses platform adapter, not pdu tree position;
- test hardlinks on each supported platform.

Avoid:

- storing only path plus pdu node index;
- assuming inode is stable on network/virtual filesystems;
- using pdu hardlink detection as cleanup authorization.

## Device Boundary And Mount Edge Cases

### DeviceBoundary Is Not Enough Product Policy - `P0`

pdu can cross or stay within device boundary. `fs_usage_*` and Clean Disk need richer language: internal volume, external drive, network mount, cloud provider root, container bind mount, and user-selected custom folder.

Required:

- map `fs_usage` `MountBoundaryPolicy` to pdu `DeviceBoundary` intentionally;
- record resulting boundary policy in scan metadata;
- detect and label skipped cross-device roots;
- expose whether totals include mounted volumes;
- keep cloud/network/virtual filesystem warnings outside pdu.

Avoid:

- defaulting to cross-device because it is convenient;
- scanning mounted backups or network shares without clear UI state;
- comparing two scans with different boundary policy as if equivalent.

### Multi-Root Scans Need Synthetic Root Handling - `P1`

pdu README notes that multiple CLI roots produce a synthetic `(total)` root in JSON. Library integration may also need a synthetic root in our model.

Required:

- `fs_usage_*` owns synthetic root identity;
- synthetic root is never a filesystem path;
- cleanup cannot queue synthetic root;
- UI clearly displays multiple scan targets as separate children;
- paths under synthetic root preserve original target context.

Avoid:

- using `(total)` as a path;
- generating DeletePlan from synthetic root;
- losing which selected target a child came from.

## Symlink, Reparse, And Reflink Edge Cases

### pdu Does Not Follow Symbolic Links - `P1`

pdu's README says it does not follow symlinks. That is a safe traversal default, but UI needs to show it honestly.

Required:

- scanner capabilities state symlink-follow policy;
- symlink nodes are classified if pdu exposes enough data, otherwise platform adapter enriches;
- UI distinguishes symlink file/dir placeholder from scanned directory;
- cleanup treats symlink deletion as deleting link, not target, with revalidation.

Avoid:

- silently omitting symlink entries if users expect to see them;
- presenting symlink target size as scanned size unless policy says so;
- following Windows junctions/reparse points by accident in a separate adapter path.

### Reflinks Are Not Hardlinks - `P1`

pdu is ignorant of reflinks. Reflinks/COW clones can share extents without sharing inode identity.

Required:

- do not reuse hardlink UI for reflink/COW cases;
- mark clone/shared-extent awareness as unsupported until platform-specific implementation exists;
- if future adapter adds reflink detection, put it behind `fs_usage` filesystem capability, not pdu hardlink API.

Avoid:

- saying hardlink deduplication solves APFS clones;
- using pdu hardlink shared size as total shared storage on COW filesystems.

## Progress And Event Edge Cases

### pdu Reporter Is Synchronous And Non-Exhaustive - `P1`

pdu's `Reporter` receives events through a synchronous method, and event enum is non-exhaustive.

Required:

- custom reporter must never block pdu traversal on slow UI/WebSocket;
- reporter sends bounded/coalesced progress into our event pipeline;
- match pdu `Event` with wildcard arm;
- unknown pdu event maps to diagnostic counter or ignored safe behavior;
- progress events are treated as approximate notifications, not durable state.

Avoid:

- doing JSON serialization or WebSocket writes inside pdu reporter;
- assuming only current event variants exist forever;
- using reporter progress to build authoritative scan tree.

### pdu Progress Is Not User Percentage By Default - `P1`

Progress report has scanned items and total scanned size, but total future work is unknown during traversal.

Required:

- UI can show scanned files, scanned bytes, throughput, current path, and indeterminate progress;
- percentage is only shown if denominator is meaningful;
- terminal scan state comes from session completion, not progress reaching a number;
- progress throttling targets UI frame budget.

Avoid:

- fake 0-100 percent based on current discovered total;
- resetting progress when a huge subtree is discovered;
- sending one progress event per filesystem entry to Flutter.

### Error Reporting Must Preserve Per-Path Detail Safely - `P0`

pdu can report errors. `fs_usage_*` and Clean Disk need skipped path details, categories, privacy redaction, and cleanup implications.

Required:

- map pdu errors into typed `SkippedPath` or scan warning records;
- keep raw OS error only in redacted debug/support data;
- count errors and expose detail pages;
- permission denied does not fail entire scan unless root target is unusable;
- cleanup candidates under uncertain skipped subtrees are marked unsafe/unavailable.

Avoid:

- printing pdu errors to stderr as the product behavior;
- collapsing all errors into "unknown";
- treating a completed pdu tree as complete if errors occurred under it.

## Cancellation And Session Lifecycle Edge Cases

### pdu Tree Build May Be Blocking From Our Perspective - `P0`

`FsTreeBuilder` builds a `DataTree` from filesystem traversal. If cancellation is not natively cooperative enough for our needs, we need an adapter boundary that can mark the session cancel-requested and discard late output safely.

Required:

- run pdu scan inside a scanner-owned worker boundary;
- expose `CancelRequested` separately from `Cancelled`;
- never block HTTP/WebSocket control plane waiting for pdu to stop;
- if pdu cannot stop quickly, surface "cancelling" and finish/discard worker output according to session epoch;
- benchmark worst-case cancellation latency on huge directories and slow network mounts.

Avoid:

- assuming dropping a Rust future cancels pdu traversal;
- tying pdu worker lifetime to WebSocket connection;
- reusing a pdu result after user cancelled and started a new scan.

### Late Results Need Epoch Checks - `P0`

A pdu worker can finish after the user cancelled, rescanned, or changed target.

Required:

- every scanner worker has `scan_session_id` and `scan_epoch`;
- completed pdu output is accepted only if session epoch is still current and state allows completion;
- late output from old epoch is dropped and counted;
- logs include operation/session/epoch for debugging.

Avoid:

- updating tree store from whichever worker finishes last;
- changing UI from cancelled back to completed;
- allowing old result to power DeletePlan creation.

## Tree Mapping And Memory Edge Cases

### pdu DataTree Is A Final Tree, Not Our Query Store - `P0`

`fs_usage_*` and Clean Disk need paginated children, search, top lists, details, delete planning, and stale identity. A final `DataTree` alone is not enough as app state.

Required:

- convert pdu tree into our node arena/indexes once;
- assign stable node IDs within scan snapshot;
- keep parent/child relationships and path context;
- release raw pdu tree after indexing if not needed;
- query pages from `fs_usage` indexes, not pdu tree traversal.

Avoid:

- keeping two full trees in memory after scan;
- sending full pdu tree to Flutter;
- deriving node identity from `Vec` index alone;
- relying on pdu sort/cull methods for product query semantics.

### max_depth Does Not Mean Shallow Scan - `P1`

pdu `FsTreeBuilder` documents that sizes beyond max depth still count toward total. That is display-depth behavior, not necessarily a performance scan limit.

Required:

- do not use pdu `max_depth` as a user "scan only this deep" feature unless verified;
- if UI collapses depth, use our query layer;
- if performance needs shallow scan, design a separate scan scope option and test semantics;
- keep total calculation honest when hidden descendants contribute size.

Avoid:

- telling user "only scanned 3 levels" when deeper files were counted;
- using display max depth to reduce delete safety data;
- hiding large child details while allowing parent delete without context.

### Sorting/Culling In pdu Is Visualization-Oriented - `P1`

pdu has DataTree methods for sorting and culling insignificant data. `fs_usage_*` and Clean Disk have stronger requirements: deterministic pagination, stable sort, filters, stale cursors, and selected node details.

Required:

- perform product sorting/filtering in `fs_usage` query indexes;
- if using pdu sorting for raw benchmark comparison, keep it out of domain;
- do not cull nodes before building cleanup-capable indexes;
- top-K views come from our read model with explicit size mode.

Avoid:

- `min-ratio` style culling in production scan tree;
- using visualizer-oriented order as API order;
- hiding nodes that can be searched or queued later.

## Performance And Threading Edge Cases

### pdu Parallelism Must Fit The Whole Daemon Budget - `P1`

pdu depends on Rayon. Clean Disk also has Tokio, WebSocket, indexing, search, and maybe other CPU work.

Required:

- benchmark pdu under the daemon, not only as CLI;
- record active thread counts and CPU saturation;
- avoid stacking unbounded Tokio blocking work, pdu/Rayon work, and indexing work;
- keep control-plane endpoints responsive during scan;
- consider scanner-specific worker process/thread pool if global Rayon behavior becomes a limitation.

Avoid:

- running multiple full-disk pdu scans with default parallelism and no budget;
- comparing pdu CLI benchmark to app scan without indexing overhead;
- tracing every file in normal builds.

### Side Effects In Parallel Traversal Are Not Ordered - `P1`

Rayon parallel work can report side effects in non-deterministic order. pdu reporter events should not define tree order or UI order.

Required:

- treat progress order as approximate;
- apply deterministic order in Clean Disk query layer;
- fixture tests should not assert exact progress sequence;
- warnings/errors should be sorted by stable keys for UI pages.

Avoid:

- using event order as child order;
- using progress event path as current authoritative selected path;
- making tests flaky by asserting reporter event ordering.

## CLI And JSON Edge Cases

### CLI Wrapping Is Throwaway Only - `P0`

The project decision says production should not wrap the pdu CLI.

Allowed:

- quick benchmark scripts;
- one-off behavior investigation;
- comparing raw pdu CLI output against adapter behavior.

Forbidden for production:

- parsing ASCII chart output;
- relying on stderr for structured errors;
- spawning `pdu` process as the scanner backend without revisiting architecture;
- treating pdu JSON output as our protocol.

### JSON Reflection Is Not Our Stable Storage Format - `P1`

pdu supports JSON via reflection, but docs say `DataTree` itself does not implement `Serialize` directly.

Required:

- if using pdu reflection for diagnostics, store it as adapter debug artifact only;
- persisted Clean Disk scan history uses Clean Disk schema version, not pdu JSON shape;
- support bundle redacts paths before including any pdu-derived JSON;
- do not promise compatibility with pdu JSON shape.

Avoid:

- using pdu JSON as Flutter API;
- storing pdu JSON as the only scan cache;
- exposing pdu reflection type names in public protocol.

## Fork And Upstream Strategy Edge Cases

### Fork Only For Specific Missing Capability - `P1`

Forking pdu gives control but creates maintenance cost.

Fork is justified only if:

- cancellation cannot meet product requirements;
- progress/reporting cannot be made non-blocking through adapter;
- required identity/error details are unavailable;
- thread budget cannot be controlled enough;
- upstream cannot accept a small generic patch in useful time.

Required if forked:

- patch list is small and documented;
- upstream sync schedule exists;
- fork has the same contract tests as upstream pdu adapter;
- release artifacts identify fork commit;
- security/advisory tracking includes forked code.

Avoid:

- forking to rename APIs;
- broad rewrite hidden inside adapter;
- diverging without benchmark and behavior snapshots.

### Prefer Upstreamable Hooks Over Product-Specific Patches - `P2`

If we need changes, generic hooks are healthier than Clean Disk-specific behavior.

Good upstream candidates:

- cancellation token/check callback;
- reporter backpressure guidance;
- richer structured error info;
- thread budget or pool configuration;
- documented stable library examples;
- feature flags that make library-only integration lighter.

Avoid:

- adding Clean Disk or `fs_usage` DTOs to pdu;
- adding Flutter-specific behavior upstream;
- changing default CLI behavior to satisfy our UI.

## Testing Matrix

### Contract Tests For The Adapter - `P0`

Before using pdu in the app, test:

- apparent size mode;
- block size mode on Unix where available;
- block count mode on Unix where available;
- symlink not followed;
- hardlink ignored/recorded/deduplicated policy;
- permission denied directory;
- file removed during scan;
- file replaced during scan;
- device boundary stay/cross;
- max depth semantics;
- multiple roots and synthetic root mapping;
- invalid/non-UTF path display mapping;
- reporter error mapping;
- late result after cancel/rescan.

### Benchmark Tests - `P1`

Benchmarks must record:

- OS and filesystem;
- disk type and cache state;
- target path category;
- pdu version and feature flags;
- pdu size mode;
- hardlink mode;
- device boundary mode;
- thread budget;
- raw pdu duration;
- `fs_usage` indexing duration;
- first useful event latency;
- final query readiness latency;
- peak memory.

### Upgrade Tests - `P1`

Before pdu upgrade:

- run adapter contract fixtures;
- run raw performance baseline;
- compare scan metadata output;
- inspect upstream changelog and release notes;
- verify dependency/license/security report;
- check docs.rs build and supported target list;
- check whether default feature set changed.

## MVP Cut Line

Before scanner-only MVP:

- pdu dependency pinned and feature-audited;
- pdu types isolated to scanner infrastructure;
- `fs_usage_engine` scanner port defined;
- adapter maps `DataTree` into our snapshot/index model;
- pdu progress reporter is non-blocking and throttled;
- size mode and device boundary policy recorded in scan metadata;
- contract tests cover symlink, permission error, hardlink basics, max depth, and cancellation/late output behavior.

Before cleanup-capable beta:

- cleanup never depends on pdu path/tree identity alone;
- NodeIdentitySnapshot is enriched/revalidated by platform filesystem adapter;
- hardlink/reflink limitations are visible in risk/reclaim UI;
- pdu upgrade snapshot tests are required by CI;
- delete queue totals distinguish scanned size from estimated reclaim;
- support bundles redact pdu-derived paths.

Deferred:

- pdu fork;
- reflink/COW shared extent detection;
- exact free-space prediction;
- pdu JSON as diagnostic artifact;
- custom scanner replacement;
- live streaming full tree from pdu internals.

## Summary

Clean Disk's pdu invariant:

```text
pdu can scan and aggregate, but `fs_usage_*` owns reusable identity, safety, queryability, progress semantics, and cleanup meaning. Clean Disk owns protocol, host runtime, and user-facing product truth.
```

📌 pdu is a strong starting adapter because it is fast, current, cross-platform in docs.rs builds, and has useful library APIs. The risk is not "pdu is bad". The risk is letting pdu's CLI/library semantics become product semantics without a contract layer.
