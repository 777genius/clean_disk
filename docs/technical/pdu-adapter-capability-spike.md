# pdu Adapter Capability Spike

Last updated: 2026-05-16.

This document records the pre-implementation research for using `parallel-disk-usage` (`pdu`) as the first scanner backend behind the reusable `fs_usage_*` scanner ports.

Status: `pdu` is viable as the first adapter, but not as the product model. The risky areas are cancellation, full-tree memory, Windows boundary semantics, and metadata completeness for our UI.

## Sources Reviewed

- `parallel-disk-usage` 0.23.0, [crates.io](https://crates.io/crates/parallel-disk-usage/0.23.0). Latest checked version: 0.23.0.
- `parallel-disk-usage`, [docs.rs crate docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/). Main library APIs: `FsTreeBuilder`, `TreeBuilder`, `DataTree`, `Reporter`, `ProgressReport`, `DeviceBoundary`, `GetSize`.
- `parallel-disk-usage`, [GitHub repository](https://github.com/KSXGitHub/parallel-disk-usage). Repository checked through `gh repo view`: latest release 0.23.0, published 2026-04-08; pushed 2026-05-14; Apache-2.0.
- `parallel-disk-usage`, [USAGE.md](https://github.com/KSXGitHub/parallel-disk-usage/blob/master/USAGE.md). Relevant CLI options: `--json-output`, `--quantity`, `--deduplicate-hardlinks`, `--one-file-system`, `--max-depth`, `--min-ratio`, `--no-sort`, `--progress`, `--threads`.
- GitHub issue [#225](https://github.com/KSXGitHub/parallel-disk-usage/issues/225), cloud-backed files can report misleading local disk usage.
- GitHub issue [#243](https://github.com/KSXGitHub/parallel-disk-usage/issues/243), stack overflow on unusual large/deep filesystem, suspected circular mounts.
- GitHub issue [#277](https://github.com/KSXGitHub/parallel-disk-usage/issues/277), random kill/OOM on very large volume with tens or hundreds of millions of entries.
- GitHub PR [#291](https://github.com/KSXGitHub/parallel-disk-usage/pull/291), hardlink deduplication.
- GitHub PR [#363](https://github.com/KSXGitHub/parallel-disk-usage/pull/363), one-file-system/device-boundary support.
- GitHub PR [#383](https://github.com/KSXGitHub/parallel-disk-usage/pull/383), hardlink key uses device plus inode.
- Local source audit of Cargo registry source for `parallel-disk-usage-0.23.0`.
- Local compile check: `cargo check --lib --no-default-features` succeeded for `parallel-disk-usage` 0.23.0.
- Local fixture probe with files, directories, symlinks, hardlinks, permission-denied directory, JSON output, and hardlink deduplication.

## Executive Verdict

Top 3 paths:

1. Thin pdu adapter plus our read-model and custom reporter - 🎯 8 🛡️ 8 🧠 6, roughly 900-1800 LOC for spike, fixtures, mapping, progress channel, and benchmark harness.

   Best first move. It proves the real integration without owning scanner traversal too early. It also keeps `pdu` replaceable.

2. Thin adapter plus upstreamable pdu patches for cancellation and direct arena callbacks - 🎯 7 🛡️ 8 🧠 7, roughly 1800-4500 LOC including fork/patch tests and upstream sync policy.

   Strong if the spike shows cancellation latency or memory duplication is unacceptable.

3. Fork or copy pdu traversal into `fs_usage_pdu` immediately - 🎯 5 🛡️ 6 🧠 9, roughly 3500-9000 LOC before product value.

   Too early. Keep as fallback if full-tree memory, cancellation, or Windows semantics fail hard.

Recommendation: start with option 1. Do not fork before measuring cancellation latency, peak memory, and read-model conversion cost.

## Capability Matrix

| Requirement | pdu 0.23.0 capability | Fit | Required Clean Disk work |
| --- | --- | --- | --- |
| Final tree | Yes. `FsTreeBuilder` builds `DataTree<Name, Size>`. | Good | Convert into our arena/read-model immediately. Do not expose `DataTree`. |
| Full expandable tree | Yes only if `max_depth` keeps the needed depth. Low `max_depth` collapses children and cannot be expanded later without rescan. | Medium | Use full depth for normal scans, then measure memory. Consider lazy subtree rescan later. |
| Progress stream | Partial. `Reporter` receives `ReceiveData`, `EncounterError`, and `DetectHardlink`; `ProgressReport` has counts and total size. | Medium | Implement custom reporter with bounded channel and throttling. |
| Per-node streaming | No public node-complete callback. | Weak | Not needed for MVP if final tree arrives fast enough. Fork/patch only if needed. |
| Cancellation | No cooperative scan cancellation found in API/source. `stop_progress_reporter` stops only the progress reporting thread. | Weak | Own scan worker state. Expose `cancel_requested` until pdu returns. Fork/patch if latency is bad. |
| Skipped/errors | Partial. `EncounterError` includes operation, path, and `io::Error`. Failed paths become empty/default nodes or skipped children. | Medium | Map errors into first-class skipped/error events and final scan summary. |
| Hardlink policy | Unix support. `HardlinkAware` records files with `nlink > 1` by `(dev, ino)`, emits hardlink events, and can deduplicate directory totals. | Medium | Expose hardlink policy and confidence. Windows needs separate capability state. |
| Symlinks | Uses `symlink_metadata`, so symlinks are not followed and are counted as link entries. | Good for safety | Explicitly show link type via metadata enrichment because `DataTree` alone does not tell file type. |
| Mount boundaries | `DeviceBoundary::Stay` uses device id on Unix. On non-Unix, device id is `()`, effectively disabling meaningful cross-device detection. | Medium on Unix, weak on Windows | Add platform capability flags and Windows reparse/mount fixtures. |
| Size modes | Apparent size works everywhere. Block size and block count are POSIX-only in `get_size`. | Medium | Keep size mode explicit and separate from reclaim estimate. |
| Metadata for UI | No. `DataTree` stores only `name`, `size`, and `children`. | Weak | Our metadata/index layer must add full path, node id, file type, item count, modified time, permissions, warnings, and skip reasons. |
| JSON output | Available behind `json` feature through reflection types. | Useful for diagnostics only | Do not use pdu JSON as product protocol or persisted format. |
| Library dependency weight | `--no-default-features` lib check works. Default features include CLI and JSON. | Good | Use `default-features = false`, then enable only needed features. |

## Findings By Spike Question

### Can We Get A Final Tree?

Yes. `FsTreeBuilder` returns a `DataTree<OsStringDisplay, Size>`.

Important details:

- `DataTree` contains private `name`, `size`, and `children`.
- Public getters expose `name()`, `size()`, and `children()`.
- `DataTree` does not store full path, metadata, node id, depth, parent id, modified time, permissions, file type, or skip reason.
- Directory total includes directory self-size plus child totals.
- `max_depth` affects stored children. Sizes beyond max depth still count, but child nodes are not kept.

Impact:

- For our tree/table UI, pdu is enough to produce the aggregate size tree.
- For our product model, pdu is not enough. We need an arena/index read-model.
- If we want expandable rows without rescan, we cannot use low `max_depth`.

### Is The Progress Stream Usable?

Usable for coarse progress, not for detailed UI state.

pdu emits:

- `ReceiveData(size)` for each metadata read;
- `EncounterError(ErrorReport)` for filesystem errors;
- `DetectHardlink(HardlinkDetection)` when hardlink detection is enabled and a linked file is found.

`ProgressReport` aggregates:

- scanned item count;
- total scanned size;
- error count;
- hardlink count;
- shared hardlink size.

Limitations:

- no path in `ReceiveData`;
- no total expected item count;
- no explicit current directory path in progress;
- event order is parallel and must not be treated as traversal order;
- CLI docs say `--progress` costs performance, so our reporter must be cheap and throttled.

Required:

- custom `Reporter` implementation, not pdu CLI reporter;
- bounded channel from reporter to scan session;
- coalescing to about 5-10 UI updates/sec;
- terminal event emitted by our session supervisor, not by pdu;
- progress is informational, not authoritative tree state.

### Is There Cooperative Cancellation?

No convincing cooperative cancellation exists in pdu 0.23.0.

What exists:

- `ProgressAndErrorReporter::stop_progress_reporter` stops only the progress reporting thread.
- `ParallelReporter::destroy` joins the reporter thread.
- scan traversal itself does not check a cancellation token.

Impact:

- The UI can request cancel, but pdu may continue until traversal returns.
- For MVP this is acceptable only if cancellation latency is small on normal 500 GB local disk targets.
- For huge folders, slow network mounts, cloud placeholders, or permission stalls, this can feel broken.

Required:

- scan session state must distinguish `running`, `cancel_requested`, `finishing`, `canceled`, and `completed`;
- cancel command should be idempotent;
- scan worker must be owned by a supervisor so daemon control endpoints stay responsive;
- if pdu cannot stop quickly, the adapter reports `supports_cooperative_cancel = false`.

Fork trigger:

- If cancel-to-terminal latency is consistently above 2-5 seconds on large local SSD scans or above an agreed threshold on slow mounts, patch/fork pdu to check a cancellation token at `get_info`, before `read_dir`, after `read_dir`, and before spawning child recursion.

### How Does pdu Return Skipped And Errors?

pdu reports filesystem errors through `EncounterError(ErrorReport)`.

`ErrorReport` includes:

- operation: `symlink_metadata`, `read_dir`, or `access entry`;
- path;
- `std::io::Error`.

Observed local fixture:

- A permission-denied directory produced a `read_dir` error.
- JSON output still completed.
- The denied directory appeared as a node with its own size and empty children.

Important:

- pdu does not have a separate "skipped path" domain model.
- Device-boundary skip is not an error. It becomes a directory node with no scanned children.
- If `symlink_metadata` fails, pdu reports error and returns a default-size file node.

Required:

- convert pdu errors into our `ScanIssue` and `SkippedPath` projections;
- record operation, path, OS error code/kind, and severity;
- distinguish permission denied, disappeared during scan, unsupported file type, boundary skipped, and cloud/network placeholders where platform metadata allows it;
- never hide skipped paths in final scan summary.

### Hardlink Policy

pdu hardlink support is useful but must stay behind our policy.

Current behavior:

- Unix-only hardlink awareness.
- Detects non-directory entries where `nlink > 1`.
- Keys hardlink groups by `(device, inode)`.
- Records size, total link count, and detected paths.
- Can subtract duplicate hardlink sizes from ancestor totals.
- Emits `DetectHardlink` events.

Limitations:

- no Windows hardlink support in the audited path;
- no reflink/COW/snapshot awareness;
- hardlink detection and deduplication can cost performance;
- `pdu` hardlink semantics are not the same as cleanup reclaim semantics.

Required:

- expose scan config as our enum: `ignore`, `detect`, `deduplicate`;
- record hardlink policy in scan metadata;
- use hardlink groups only as evidence;
- before delete, re-read link count and identity;
- do not claim deleting one hardlinked path frees the shared content while other links exist.

### Symlink, Reparse Point, And Mount Boundary Behavior

Symlinks:

- pdu uses `std::fs::symlink_metadata`, not `metadata`.
- On Unix this means symlinks are not followed.
- Local fixture showed symlink-to-file and symlink-to-directory as leaf entries with symlink metadata size.

Mount boundaries:

- `DeviceBoundary::Cross` scans across boundaries.
- `DeviceBoundary::Stay` compares root device id to child device id.
- Device id implementation is meaningful only on Unix.
- On unsupported platforms, all entries share the same device id, so boundary detection is effectively unavailable.

Windows/reparse:

- Needs real fixture testing. Rust `symlink_metadata` behavior plus Windows reparse-point varieties is not enough to infer product semantics.
- Junctions, volume mount points, cloud placeholders, OneDrive files, WSL paths, and deduplicated NTFS/ReFS data need explicit tests.

Required:

- capability flags per platform and volume;
- explicit UI warnings for unsupported boundary/hardlink/accounting capabilities;
- fixture tests for symlink loops, junctions, mount points, and boundary behavior.

### Raw Scan Time Versus Post-Index Time

pdu CLI does more than raw traversal:

- builds tree;
- optionally destroys progress reporter;
- optionally culls by `min_ratio`;
- optionally sorts tree;
- optionally deduplicates hardlinks;
- optionally converts tree to JSON/reflection.

For Clean Disk, we should measure separately:

1. raw pdu tree build;
2. hardlink detection/deduplication;
3. conversion from `DataTree` to our arena;
4. metadata enrichment;
5. index building for children, top files, top folders, search, details;
6. protocol serialization and page query cost.

Required:

- do not use pdu `min_ratio` culling for product data;
- avoid pdu sort if our indexes sort pages by query;
- drop `DataTree` immediately after conversion;
- report benchmark output as `scan_ms`, `adapter_convert_ms`, `index_ms`, `metadata_enrich_ms`, `peak_rss`, `node_count`.

### Can We Build Paginated Read Model Without Huge Memory?

Probably yes for normal local disks, but this is the main spike risk.

pdu memory properties:

- `DataTree` stores one node per stored filesystem entry.
- Each node stores a name, size, and `Vec` of children.
- Full expandable UI implies high or infinite `max_depth`.
- GitHub issue #277 shows pdu can be killed on extremely large volumes even after max-depth optimizations.

Our read-model must avoid duplicating the tree naively.

Required arena shape:

```text
NodeId -> {
  parent_id,
  name_atom_or_os_string,
  size,
  kind_hint,
  child_range_or_children_vec,
  issue_range,
  metadata_ref
}

Indexes:
  children_by_parent
  top_folders
  top_files
  search_terms
  path_lookup
  hardlink_groups
  issue_list
```

Rules:

- Do not store full path string in every node.
- Reconstruct path from parent chain or keep interned path segments.
- Keep path materialization cached only for selected/details/search results.
- Use integer `NodeId`, not pdu child positions as durable identity.
- Use pagination cursors based on `(sort_key, node_id)` or stable page tokens.
- Consider `smallvec`, compact enums, and string interning only after measuring.
- Drop pdu tree after arena conversion.

Spike acceptance target:

- 500 GB local user folder should scan and index without UI-visible daemon instability.
- Memory per indexed node must be measured before committing to full-tree strategy.
- If peak memory equals `pdu full tree + our full arena` for too long, consider consuming conversion, upstream patch, or fork to build our arena directly.

## Known External Risks

### Cloud Placeholder Sizes

Issue #225 reports misleading local disk usage for cloud-backed files on macOS. This matches our own storage-accounting risk model: pdu size is not enough for local reclaim.

Required:

- cloud placeholder detection outside pdu;
- separate logical size, allocated local size, and estimated reclaim.

## Local Validation Runs - 2026-05-16

Environment:

- macOS local machine.
- `parallel-disk-usage` 0.23.0 built from crates.io source.
- CLI binary used only for spike measurement. Production integration remains library adapter, not CLI wrapping.
- Main command shape: `pdu --json-output --min-ratio=0 --max-depth=inf --quantity=block-size --no-sort`.

Real target results:

| Target | Result | Time | Peak memory footprint | Nodes | Notes |
| --- | --- | --- | --- | --- | --- |
| `~/Downloads` | exit 0 | 0.16s | ~7.3 MB | 22,070 | JSON ~1.18 MB. No errors observed. |
| `~/Library` | exit 0 | 9.65s | ~176 MB | 1,226,080 | JSON ~86 MB. 123 permission errors, all reported as `read_dir` operation errors. |
| `/Volumes/Disk Inventory X 1.3` | exit 0 | 0.07s | ~4.0 MB | 633 | Mounted read-only volume scanned successfully. No network/FUSE mounts were present to test. |

Synthetic results:

| Fixture | Result | Time | Peak memory footprint | Nodes | Notes |
| --- | --- | --- | --- | --- | --- |
| Wide directory, 50,000 files | exit 0 | very fast after fixture creation | ~12.6 MB | 50,001 | Confirms pdu handles wide directories cleanly. Creating the files was slower than scanning them. |
| Deep directory | exit 0 | very fast | ~4.3 MB | 218 | macOS path length stopped fixture creation around 218 nested levels. pdu did not crash. `jq` hit its own depth limit parsing the resulting JSON. |
| Sparse 10 GB file | exit 0 | very fast | ~3.5 MB | 2 | Apparent size reported ~10 GB, block-size reported 0. Good evidence that POSIX block mode distinguishes sparse files. |
| Non-UTF8 filename attempt | fixture creation failed | n/a | n/a | n/a | macOS/APFS returned `Illegal byte sequence`. This case still needs Linux fixture coverage. |
| File deleted/growing during scan | exit 0 | 0.28s | ~8.7 MB | 29,506 | 88 `symlink_metadata` not-found errors were reported. Scan still completed. |
| APFS clone via `cp -c` | exit 0 | very fast | ~3.6 MB | 3 | pdu apparent and block-size both counted base and clone as ~64 MB each, total ~128 MB. This confirms pdu cannot provide exact exclusive reclaim for APFS clones. |

Snapshot check:

- `tmutil listlocalsnapshots /` showed existing OS update snapshots.
- No destructive snapshot experiment was run.
- Snapshot/reclaim behavior remains an accounting-adapter concern, not a pdu capability.

Validation conclusions:

- pdu is strong enough for fast aggregate scan tree on normal local targets.
- pdu reports permission and mutation errors instead of aborting, which fits our first-class skipped/error model.
- pdu full JSON for `~/Library` is large but tractable. Our production path should not send this JSON to Flutter.
- For 1M+ nodes, Rust-owned arena/read-model and paginated queries are mandatory.
- APFS clones prove again that pdu size is not reclaim size.
- The biggest unresolved local capability remains cooperative cancellation.
- macOS Full Disk Access and scanner process identity are now confirmed as production architecture risks. The production scanner must be a signed Clean Disk app component, not an external `pdu` binary.

### macOS Permission Follow-Up From Local Runs

The `~/Library` scan was fast and completed successfully, but it produced 123 `read_dir` `Operation not permitted` errors against protected user-data folders. This is expected on macOS without the right TCC authority and must be treated as a partial scan, not a scanner crash.

Architectural consequences:

- `pdu` remains a Rust library adapter compiled into our scanner component;
- production must not use a Homebrew, system, temporary, or random external `pdu` CLI process;
- the signed scanner component must be packaged with Clean Disk and tested as part of the signed/notarized release artifact;
- the permission doctor must probe protected paths from inside the scanner process;
- scan results must keep privacy/TCC denials as first-class `ScanIssue` and `SkippedPath` records;
- parent directory totals affected by denied subtrees must be marked partial/lower-confidence.

### Extreme Volume Memory

Issue #277 reports kills on a very large volume after tens or hundreds of millions of entries. This is outside the normal MVP target, but relevant for reusable library/server mode.

Required:

- document practical limits;
- resource profiles;
- optional subtree scan;
- possible future direct arena builder or streaming scanner backend.

### Deep Or Circular Trees

Issue #243 reports stack overflow, suspected circular mounts. pdu has `--one-file-system`, but product-grade safety still needs platform boundary handling and recursion guards.

Required:

- depth limits and loop detection policy;
- mount boundary fixtures;
- symlink/reparse behavior tests;
- terminal error state if traversal panics or aborts.

## Spike Test Matrix

Minimum local fixtures:

- normal nested directories;
- wide directory with many children;
- deep directory chain;
- symlink to file;
- symlink to directory;
- broken symlink;
- hardlinked files in same directory;
- hardlinked files across sibling directories;
- permission-denied directory;
- file deleted during scan;
- file growing during scan;
- non-UTF-8 file name on Unix;
- sparse file;
- APFS clone on macOS if available;
- external/removable volume if available;
- one-file-system boundary on Unix;
- Windows symlink, junction, and volume mount point;
- OneDrive placeholder on Windows;
- network share or FUSE/rclone mount.

Benchmark dimensions:

- apparent size vs block size;
- hardlink mode off vs detect/dedup;
- full depth vs limited depth;
- thread count auto/max/fixed;
- local SSD vs external drive vs network/cloud target;
- raw pdu scan vs adapter conversion vs index build.

## Decision Gates Before Main Implementation

Proceed with thin pdu adapter if:

- final tree mapping works without pdu types leaking;
- custom reporter can emit stable progress at low overhead;
- cancellation limitation is represented honestly in session state;
- memory is acceptable for realistic 500 GB local targets;
- read-model page queries are fast without moving tree state to Flutter.

Patch or fork pdu if:

- cooperative cancellation is required and cannot be approximated;
- `DataTree` duplication makes memory unacceptable;
- we need node-complete callbacks to build our arena directly;
- Windows boundary/reparse behavior cannot be represented safely through adapter capabilities.

Replace pdu only if:

- multiple core requirements fail at once;
- upstream API churn makes adapter maintenance unstable;
- a different library gives final tree, progress, cancellation, hardlink policy, and memory behavior with lower integration risk.

## Current Conclusion

`parallel-disk-usage` should remain the first scanner backend. It gives us the hard part - fast parallel traversal and aggregate size tree. It does not give us the product engine. Clean Disk still needs its own scanner session model, capability model, event throttling, arena read-model, metadata enrichment, query indexes, storage accounting, and delete safety.

The first implementation step should be a measured `fs_usage_pdu` spike, not app UI work and not a fork.
