# pdu Library Deep Validation

Last updated: 2026-05-16.

This document records a deeper validation pass for `parallel-disk-usage` (`pdu`) as the first Rust scanner backend behind our `fs_usage_*` scanner ports.

The goal was to answer:

```text
Is pdu actually good enough to use as the first scanner adapter,
what does it return,
how fast is it on real folders,
and where do we still need our own layer?
```

## Executive Verdict

`parallel-disk-usage` 0.23.0 is a good first scanner adapter. It is fast, has a real library API, supports final aggregate trees, has reporter events, supports hardlink detection/deduplication on Unix, and works on real large macOS folders.

It is not enough as the product model.

Top 3 integration paths:

1. Thin pdu library adapter plus our read model - 🎯 9 🛡️ 8 🧠 6, roughly 900-2200 LOC.

   Best current path. Use pdu for traversal/aggregation, immediately map to our arena/indexes, metadata model, capability state, scan issues, and query API.

2. Thin adapter plus upstreamable patches for cancellation/current-path/progress hooks - 🎯 7 🛡️ 8 🧠 8, roughly 1800-4500 LOC.

   Good fallback if real daemon tests prove cancellation latency, memory overlap, or progress semantics are not acceptable.

3. Fork or custom scanner now - 🎯 4 🛡️ 6 🧠 9, roughly 5000-14000 LOC.

   Too early. We do not yet have enough evidence that pdu fails core scanning. Keep fork as a measured fallback.

Decision: keep pdu as the initial scanner adapter, but keep strict anti-corruption boundaries.

## Sources Reviewed

- `parallel-disk-usage` 0.23.0, [crates.io](https://crates.io/crates/parallel-disk-usage/0.23.0).
- `parallel-disk-usage`, [docs.rs crate docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/). Public library entry points include `FsTreeBuilder`, `TreeBuilder`, `DataTree`, `Reporter`, and `Visualizer`.
- `parallel-disk-usage`, [DataTree docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/data_tree/struct.DataTree.html). `DataTree` has private `name`, `size`, and `children`; JSON goes through reflection.
- `parallel-disk-usage`, [Reporter docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/index.html). Reporter events include data received, errors, and hardlink detection.
- `parallel-disk-usage`, [GitHub repository](https://github.com/KSXGitHub/parallel-disk-usage). Upstream describes pdu as a highly parallelized directory tree analyzer and CLI.
- Local Cargo metadata: `cargo info parallel-disk-usage` reported version `0.23.0`, Apache-2.0, repository `https://github.com/KSXGitHub/parallel-disk-usage.git`.
- Local Cargo source audit from `~/.cargo/registry/src/.../parallel-disk-usage-0.23.0`.

## Environment

Local environment used for validation:

```text
macOS user environment through Codex desktop
rustc 1.90.0
cargo 1.90.0
pdu 0.23.0 installed through cargo install
```

The CLI was installed with:

```text
cargo install parallel-disk-usage --version 0.23.0 --locked
```

The library spike used:

```toml
parallel-disk-usage = { version = "=0.23.0", default-features = false }
```

This compiled successfully. Important: even with default features disabled, the library still has non-trivial dependencies such as Rayon, DashMap, sysinfo, terminal size helpers, and proc-macro dependencies. We still need dependency review, but the CLI/json features can be kept out of the daemon integration.

## Public API Findings

### `FsTreeBuilder`

Observed source behavior:

- uses `std::fs::symlink_metadata`;
- reads directories through `read_dir`;
- can stay within device boundary or cross boundaries;
- reports errors through `Reporter`;
- reports each metadata read through `Event::ReceiveData(size)`;
- records hardlinks through a supplied hardlink recorder;
- builds a `DataTree<OsStringDisplay, Size>`;
- `max_depth` controls stored/displayed children, while deeper sizes still count.

Impact:

- Good fit for fast aggregate scan.
- Not enough for product-level metadata.
- `max_depth` cannot be used for expandable UI unless we accept missing child nodes or rescan.

### `DataTree`

`DataTree` gives:

```text
name()
size()
children()
```

It does not give:

```text
full path
stable node id
parent id
file type
modified time
permissions
owner/group
platform identity
skip reason
cloud state
reclaim estimate
current path
query cursor
```

Impact:

Clean Disk must build its own Rust read model:

```text
pdu DataTree
  -> fs_usage node arena
  -> metadata/index enrichment
  -> paginated query API
```

Flutter must never receive the full pdu tree.

### `Reporter`

Reporter event types observed in source:

```text
ReceiveData(Size)
EncounterError(ErrorReport)
DetectHardlink(HardlinkDetection)
```

Useful:

- scanned item count;
- total scanned size;
- error count;
- hardlink event count;
- error operation/path/io error;
- hardlink path/size/link count.

Limitations:

- `ReceiveData` has no path;
- no total expected item count;
- no current directory path;
- no completion event;
- no cancellation token;
- event order is parallel and must not be treated as traversal order;
- reporter callback is synchronous, so our reporter must be extremely cheap.

Required:

- custom reporter with bounded channel;
- coalesced UI events, roughly 5-10/sec;
- session supervisor emits terminal events;
- progress is informative, not authoritative.

### Cancellation

No cooperative cancellation hook was found in pdu 0.23.0.

Implication:

- cancel command in Clean Disk can mark a session as `cancel_requested`;
- the pdu worker may continue until traversal returns;
- late pdu output must be discarded if the session epoch changed;
- fork/upstream patch is needed if cancel latency is bad in real daemon tests.

## CLI Validation Results

### Synthetic Fixture

Fixture included:

```text
regular file 1 MiB
regular file 5 MiB
hardlink to 5 MiB file
sparse file 1 GiB
symlink to file
symlink to directory
wide directory with 2000 tiny files
permission-denied directory
attempted invalid UTF-8 filename
```

APFS/macOS rejected the invalid UTF-8 filename:

```text
Illegal byte sequence
```

This means non-UTF8 filename testing needs Linux or another filesystem/runtime. We should keep it in cross-platform fixtures but cannot prove it on this APFS setup.

Synthetic results:

| Mode | Root size | Runtime | Peak memory | Notes |
| --- | ---: | ---: | ---: | --- |
| apparent size, full JSON | 1,085,342,951 bytes | 0.12s | ~4.1 MB footprint | sparse file counted as 1 GiB |
| block size, full JSON | 8,196,096 bytes | 0.12s | ~4.0 MB footprint | sparse file counted as 0 bytes |
| apparent + hardlink dedupe | 1,080,100,071 bytes | 0.12s | ~3.9 MB footprint | 5 MiB duplicate hardlink subtracted |

Observed:

- permission-denied directory produced an error but exit code stayed 0;
- denied directory remained in tree as an empty node;
- symlinks were not followed and appeared as leaf entries;
- hardlink JSON included shared details with `ino`, `dev`, `size`, `links`, and paths;
- `max_depth=1` kept the root total but stored no children;
- `max_depth=2` stored immediate children but not deeper nodes.

Important conclusion:

`max_depth` is a display/storage-depth control, not a lazy expandable tree solution.

### Real `~/Downloads`

Command shape:

```text
pdu --json-output --max-depth=inf --min-ratio=0 --quantity=block-size --bytes-format=plain ~/Downloads
```

Result:

```text
exit=0
runtime=0.27s
peak memory footprint=7,144,768 bytes
json_size=1,186,225 bytes
root_size=3,426,570,240 bytes
node_count=22,070
top_level_children=455
errors=0
```

Thread comparison with `max_depth=2`:

| Threads | Runtime | Peak footprint | JSON size |
| --- | ---: | ---: | ---: |
| auto | 0.33s | ~4.3 MB | 30,065 bytes |
| 1 | 0.52s | ~2.5 MB | 30,065 bytes |

Conclusion:

For a normal user folder, pdu is comfortably fast.

### Real `~/Library`

Full-depth JSON command:

```text
pdu --json-output --max-depth=inf --min-ratio=0 --quantity=block-size --bytes-format=plain ~/Library
```

Result:

```text
exit=0
runtime=13.77s
maximum resident set size=192,987,136 bytes
peak memory footprint=174,720,704 bytes
json_size=86,257,479 bytes
root_size=117,509,455,872 bytes
node_count=1,227,191
top_level_children=108
errors=124
```

Largest top-level entries by block size:

```text
Application Support 42,204,930,048
Containers          32,400,375,808
Android             18,844,741,632
Caches               8,460,308,480
Developer            5,308,887,040
pnpm                 5,205,807,104
```

Permission errors were normal on macOS protected folders:

```text
Autosave Information
ContainerManager
HomeKit
Photos
Safari
Messages
Mail
Calendars
Group Containers/*
Containers/com.apple.*
```

One transient filesystem error appeared:

```text
Interrupted system call (os error 4)
```

Conclusion:

`~/Library` is a good stress target. pdu handles it, but the product must show partial/completeness state and grouped skipped reasons. A successful exit code does not mean a complete scan.

### `~/Library` Depth And Thread Comparison

`max_depth=2`, `--threads=auto`, silent errors:

```text
runtime=7.24s
maximum resident set size=23,543,808 bytes
peak memory footprint=18,449,920 bytes
json_size=5,526 bytes
```

`max_depth=2`, `--threads=1`, silent errors:

```text
runtime=45.21s
maximum resident set size=11,550,720 bytes
peak memory footprint=6,407,232 bytes
json_size=5,526 bytes
```

Conclusion:

- parallelism matters a lot on this machine;
- limiting threads greatly reduces memory but makes scan much slower;
- Clean Disk needs explicit scan resource profiles and daemon-wide worker budgets;
- raw pdu benchmarks must always record `threads`, `max_depth`, size mode, and hardlink mode.

### Progress Mode On `~/Library`

`pdu --progress --max-depth=2 --silent-errors ~/Library` completed in about `7.30s`.

Observed progress text contained:

```text
scanned 1,216,278
total 117,462,106,112
erred 123
```

Progress is useful but only coarse:

- item count grows;
- total grows;
- error count grows;
- no path;
- no percentage;
- no known total;
- no product completion semantics.

For Clean Disk we should not use pdu CLI progress. We should implement a custom library reporter and throttle events.

## Library Spike Results

A throwaway Rust project was created under `/tmp/clean_disk_pdu_library_spike` with:

```toml
parallel-disk-usage = { version = "=0.23.0", default-features = false }
```

The spike implemented:

- `CollectingReporter`;
- `Event::ReceiveData` counting;
- `Event::EncounterError` capture;
- `Event::DetectHardlink` capture;
- `FsTreeBuilder`;
- `HardlinkAware`;
- hardlink deduplication through `DeduplicateSharedSize`;
- recursive node counting through `DataTree::children()`.

Synthetic fixture output:

```text
tree_size_before_dedupe=1085342951
tree_size_after_dedupe=1080100071
tree_nodes=2013
reported_items=2013
reported_total_bytes=1085342951
reported_errors=1
reported_hardlink_events=2
hardlink_groups=1
scan_elapsed_ms=30
```

`~/Library` output:

```text
tree_size_before_dedupe=148766875262
tree_size_after_dedupe=147894910123
tree_nodes=1228411
reported_items=1228411
reported_total_bytes=148766875262
reported_errors=123
reported_hardlink_events=25221
hardlink_groups=12593
scan_elapsed_ms=7032
runtime=11.12s
peak memory footprint=175,802,048 bytes
```

Conclusion:

The library API works for our intended adapter shape. A custom reporter is straightforward. Hardlink detection/deduplication works on macOS/Unix. The main missing API is cooperative cancellation and richer node-complete/current-path metadata.

## What pdu Gives Us Directly

pdu gives:

```text
fast recursive traversal
aggregate size tree
name/size/children
apparent size
block size on Unix
block count on Unix
symlink-safe traversal through symlink_metadata
permission/error events
hardlink detection on Unix
hardlink deduplication on Unix
device boundary option
JSON for diagnostics/prototypes
thread limit option in CLI
```

## What We Must Add Around pdu

Clean Disk still needs:

```text
stable NodeId
full path storage
parent id
node type
modified time
permissions
owner/group where available
platform identity
cloud/sync state
mount/reparse classification
skip reason model
scan quality model
read model indexes
pagination
search/sort/top lists
selection sets
delete preflight identity revalidation
reclaim estimate model
operation state machine
cooperative cancellation or cancellation fallback
resource budget integration
support bundle redaction
```

## Architecture Consequences

Accepted adapter shape remains correct:

```text
fs_usage_engine scanner port
  -> fs_usage_pdu adapter
  -> pdu FsTreeBuilder + Reporter
  -> fs_usage read-model builder
  -> query indexes
  -> Clean Disk protocol pages/events
```

Rules:

- only `fs_usage_pdu` imports `parallel_disk_usage`;
- pdu types never cross into domain/application/protocol/Flutter;
- pdu JSON is diagnostic/prototype only;
- pdu CLI is prototype/benchmark only;
- production macOS scanner must compile pdu as a library into the signed scanner component/helper;
- scan metadata records pdu version, size mode, hardlink mode, device-boundary policy, thread/resource profile, and adapter version.

## Risks That Remain

### Cancellation

No cooperative cancellation hook was found. This is the weakest pdu fit.

Required before production:

- daemon cancellation spike;
- large local folder cancel latency;
- slow network/FUSE cancel latency;
- session epoch discard tests;
- decision whether upstream patch/fork is needed.

### Memory Overlap

Full-depth `~/Library` pdu tree plus JSON used about 175 MB peak footprint on this machine. Our real product will also build read-model indexes.

Required:

- measure pdu tree only;
- measure pdu tree plus read model;
- drop pdu tree as early as possible after conversion;
- avoid duplicating path strings naively;
- test 1-5M node fixtures.

### Metadata Completeness

pdu only gives name/size/children plus reporter events.

Required:

- metadata enrichment pass;
- platform identity adapter;
- cloud/provider adapter;
- mount/reparse adapter;
- skip/error merge model.

### macOS Permissions

`~/Library` produced 123-124 permission errors. This is expected without Full Disk Access in the scanner process.

Required:

- permission errors are first-class scan issues;
- successful exit code can still mean partial scan;
- production scanner identity must be signed/bundled;
- capability probe must run in the same process that scans.

### Cross-Platform Gaps

This validation was on macOS. Still required:

- Windows NTFS/ReFS hardlinks, junctions, symlinks, OneDrive placeholders, VSS/reparse points;
- Linux ext4/Btrfs/ZFS, bind mounts, FUSE/rclone, permission denied, non-UTF8 filenames;
- network mounts and removable volumes;
- cloud provider roots on each OS.

## Final Recommendation

Use pdu first, behind `fs_usage_pdu`, with strict adapter tests.

Do not fork now.

Do not expose pdu as product truth.

Top next validation tasks:

1. Read-model memory overlap spike - 🎯 9 🛡️ 9 🧠 8, roughly 1000-2500 LOC.

   Convert a full pdu tree into our arena/index model and measure peak memory on `~/Library` and synthetic 1M+ node fixtures.

2. Daemon cancellation spike - 🎯 8 🛡️ 9 🧠 8, roughly 800-1800 LOC.

   Prove user-visible cancel behavior when pdu cannot stop cooperatively.

3. Cross-platform fixture suite - 🎯 8 🛡️ 10 🧠 9, roughly 1500-4000 LOC plus OS runners.

   Windows/Linux/macOS fixtures for symlinks, hardlinks, mount boundaries, permissions, sparse/compressed files, cloud placeholders, and changing files.

## Summary

```text
pdu is strong at fast traversal and aggregate trees.
pdu is weak at product semantics.
The correct architecture is adapter plus our own read model, metadata, safety, and protocol.
```
