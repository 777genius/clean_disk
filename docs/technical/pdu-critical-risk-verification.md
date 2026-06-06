# pdu Critical Risk Verification

Last updated: 2026-05-16.

This document records local verification of the highest-risk pdu integration assumptions before implementation.

The tests used a throwaway Rust spike in `/tmp/clean_disk_pdu_critical_spike` with:

```toml
parallel-disk-usage = { version = "=0.23.0", default-features = false }
```

The spike is not product code.

## Executive Result

pdu remains a good first traversal backend, but four constraints are now verified as implementation blockers if ignored:

1. Full `PathBuf` per node is not acceptable for large scans - 🎯 10 🛡️ 10 🧠 7, fix roughly 700-1800 LOC.
2. pdu cancellation is not cooperative in 0.23.0 - 🎯 10 🛡️ 9 🧠 7, fix roughly 500-1600 LOC for honest session cancellation, or 2000-5000 LOC for pdu fork/patch.
3. Eager metadata restat of all nodes can destroy the speed advantage - 🎯 9 🛡️ 9 🧠 8, fix roughly 800-2200 LOC for lazy/batched enrichment.
4. pdu/Rayon can cause visible system pressure on real user machines - 🎯 9 🛡️ 10 🧠 8, fix roughly 800-2500 LOC for resource profiles, scheduler, and scan budgets.

## Latest Version Check

`cargo search parallel-disk-usage --limit 1` and `cargo info parallel-disk-usage` confirmed:

- latest crates.io version: `0.23.0`;
- installed CLI: `pdu 0.23.0`;
- default feature: `cli`;
- optional `json` feature;
- license: Apache-2.0.

Decision remains: use latest verified stable, but exact-pin it in the adapter crate and upgrade only through fixture and benchmark gates.

## Memory Verification

Target: `~/Library`

### Raw pdu scan plus naive arena

Naive model stored full `PathBuf` on every node.

Observed:

```text
root_nodes=1229122
arena_nodes=1229122
scan_ms=17521
convert_ms=591
rss_after_scan=127057920
rss_after_convert=492404736
maximum resident set size=693796864
approx_arena_bytes=392417207
path_bytes=168343721
name_bytes=39524110
report_errors=126
```

Interpretation:

- raw pdu tree itself is acceptable for this machine class;
- duplicating the tree into a path-heavy read model is not acceptable;
- full native path per node was the largest avoidable cost;
- maximum RSS reached about 694 MB before real indexes, metadata, protocol buffers, cache, or Flutter are included.

### Raw pdu scan plus compact arena

Compact model stored parent id plus basename, not full path per node.

Observed:

```text
root_nodes=1229166
compact_arena_nodes=1229166
scan_ms=13788
compact_convert_ms=67
rss_after_scan=133365760
rss_after_compact_convert=263667712
maximum resident set size=264765440
approx_compact_arena_bytes=108357765
compact_name_bytes=39524469
report_errors=126
```

Interpretation:

- compact arena is viable as a first read model shape;
- conversion cost was small compared with scan time;
- memory is still large enough that indexes must be built carefully;
- exact product implementation should avoid `String`/`OsString` bloat where profiling proves it matters, for example with compact names or interning.

### Required rule

Product read model must store:

```text
NodeRecord
  node_id
  parent_id
  first_child
  child_count
  local_name_ref
  size facts
  flags
  metadata_state
  issue counters
```

Product read model must not store:

```text
full PathBuf per node
full display path per node
raw JSON tree
duplicated path strings in every index
```

Full paths should be reconstructed on demand for visible rows, details, selected cleanup candidates, receipts, and support exports.

## max_depth Verification

Target: `~/Library`, `max_depth=2`

Observed:

```text
root_nodes=109
compact_arena_nodes=109
scan_ms=7102
report_items=1229167
report_errors=123
maximum resident set size=17612800
```

Interpretation:

- pdu `max_depth` dramatically reduces returned tree size and memory;
- pdu still scans the full subtree to compute aggregate sizes;
- `max_depth` is an overview optimization, not lazy expansion;
- if the user expands a hidden subtree later, the product needs either full-depth scan, subtree rescan, or a different backend capability.

## Metadata Enrichment Verification

The spike measured `symlink_metadata` restat cost over paths from the arena.

Target: `~/Library`

Naive arena run:

```text
lazy_restat_limit=5000
lazy_restat_ms=242
eager_restat_limit=200000
eager_restat_ms=7566
```

Compact arena run:

```text
lazy_path_build_and_restat_limit=5000
lazy_restat_ms=238
```

Interpretation:

- 5000 visible/detail-style metadata refreshes are acceptable as a bounded operation;
- 200000 restats cost about 7.6s in this run;
- extrapolating to 1.2M nodes would be product-visible and likely erase pdu's speed advantage;
- metadata enrichment must be lazy, page-driven, batched, cached, and cancellable;
- delete preflight is separate and must always revalidate identity near execution time.

Required product rule:

```text
scan first -> show size tree -> enrich visible/query/detail nodes -> enrich cleanup candidates before action
```

Do not do:

```text
pdu scan -> restat every node -> only then show UI
```

## Cancellation Verification

Target: `~/Library`, full-depth pdu scan in a worker thread.

The spike set a cancellation flag after 100 ms. pdu did not observe it because pdu 0.23.0 has no traversal cancellation token in this integration path.

Observed:

```text
cancel_requested_ms=100
cancel_returned_ms=13455
cancel_extra_wait_ms=13354
cancel_nodes=1229144
cancel_items=1229144
cancel_errors=125
cancel_flag_observed_by_pdu=false
```

Interpretation:

- pdu finished the whole scan after cancel was requested;
- the product must not promise immediate stop for pdu scans;
- MVP cancellation must be honest session supervision;
- fast cancellation requires a fork/patch or a different scanner backend.

Accepted MVP behavior:

```text
running -> cancel_requested -> cancelling -> cancelled | completed_late_discarded
```

Implementation requirements:

- scan epoch on each worker result;
- late results discarded when session no longer accepts them;
- UI shows `cancelling` until adapter returns;
- target-level split can reduce wait if scanning many roots;
- user can close app/window without waiting for pdu to finish only if daemon lifecycle handles orphaned work safely.

## Hardlink Mode Verification

Target: `~/Library`, pdu hardlink-aware/dedupe path in the spike.

Observed:

```text
scan_ms=28148
report_hardlink_events=25475
report_errors=127
rss_after_scan=146423808
```

Comparable non-hardlink full-depth run:

```text
scan_ms=17521
report_hardlink_events=0
report_errors=126
rss_after_scan=127057920
```

Interpretation:

- hardlink-aware mode found meaningful evidence;
- it also cost noticeably more time and memory;
- hardlink policy should be explicit in scan config and visible in scan facts;
- hardlink evidence helps size interpretation but is not reclaim truth.

Recommended default:

1. Balanced profile includes hardlink detection only where correctness needs it - 🎯 7 🛡️ 8 🧠 7, roughly 700-1800 LOC.
2. Fast profile may skip hardlink dedupe and mark totals as faster/lower-confidence - 🎯 8 🛡️ 7 🧠 6, roughly 500-1400 LOC.
3. Always-on hardlink dedupe - 🎯 5 🛡️ 8 🧠 5, roughly 300-900 LOC, but worse UX on large trees.

## Resource Pressure Verification

During a local Rayon pool experiment on `~/Library`, the machine had a visible UI freeze for about 4 seconds. The process was stopped immediately.

This is enough to treat resource governance as P0, not a later polish item.

Additional relevant observation:

```text
RAYON_NUM_THREADS=1, ~/Library, max_depth=2
scan_ms=145871
maximum resident set size=7225344
```

Default parallel scan for the same target/depth:

```text
scan_ms=7102
maximum resident set size=17612800
```

Interpretation:

- pdu speed depends heavily on parallel traversal;
- too little parallelism makes scans painfully slow;
- too much or badly scheduled parallelism can hurt the user's active desktop session;
- the product needs explicit scan modes and daemon resource budgets before full-disk UI testing.

Required scan profiles:

- `Background`: lower CPU/IO pressure, slower, safe while user works.
- `Balanced`: default, bounded parallelism, protects UI responsiveness.
- `Fast`: opt-in, warns that the machine may become less responsive.

Implementation requirements:

- never run heavy full-depth scans on the UI process;
- use a dedicated scanner lane separate from daemon control/HTTP/WS lanes;
- keep status/cancel/health endpoints responsive while pdu is hot;
- throttle progress events;
- avoid nested unbounded parallelism: pdu scan plus metadata enrichment plus indexing must not all saturate the machine at once;
- add a kill/stop switch for development benchmarks.

## macOS Permission And Process Identity Recheck

External sources confirm the existing architecture constraint:

- Apple Support says apps requiring full storage access must be explicitly added in System Settings or System Preferences.
- Apple's device-management docs list `SystemPolicyAllFiles` as the managed Full Disk Access service for protected files.
- Apple Developer Forum guidance around TCC and responsible code says the system must be able to identify the app as responsible for helper behavior; helpers can break this relationship if packaged or launched oddly.

Product implication:

- production must not shell out to a random external `pdu` binary;
- scanner, permission probe, metadata enrichment, and delete preflight should run under the same signed app/helper identity;
- if a helper is used, its bundle/signing/responsible-code relationship must be tested on clean macOS VMs;
- permission-denied results are product states, not generic scanner failures.

## Final Implementation Gates

Before scanner MVP implementation is accepted:

- `fs_usage_pdu` import boundary test exists.
- pdu version is exact-pinned.
- pdu upgrade fixture suite exists.
- compact arena uses parent/local-name storage.
- no full `PathBuf` per node in persistent read model.
- no full tree DTO sent to Flutter.
- metadata enrichment is lazy/batched and separately cancellable.
- cancellation state machine distinguishes `cancelling` from `cancelled`.
- daemon control plane remains responsive during scan.
- scan profiles exist before real full-disk UI tests.
- hardlink mode is a policy with visible confidence/evidence.
- pdu `max_depth` is not used as lazy expansion.
- macOS signed helper/app identity plan is tested before shipping scanner builds.

## Cleanup

The local spike was disposable. Heavy scan runs should not be repeated interactively without an explicit resource profile and stop switch.

The spike directory can be removed after recording results. Do not commit `/tmp` spike code into the product.

## Sources

- [parallel-disk-usage crate docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/) - library entrypoints and module map.
- [FsTreeBuilder docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/fs_tree_builder/struct.FsTreeBuilder.html) - traversal inputs and `max_depth` behavior.
- [DataTree docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/data_tree/struct.DataTree.html) - private tree model, getters, reflection, sort/retain helpers.
- [Reporter and Event docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/event/enum.Event.html) - reporter event contract and non-exhaustive event enum.
- [Apple Support: Controlling app access to files in macOS](https://support.apple.com/guide/security/controlling-app-access-to-files-secddd1d86a6/web) - user consent and Full Disk Access settings.
- [Apple Developer Documentation: PrivacyPreferencesPolicyControl Services](https://developer.apple.com/documentation/devicemanagement/privacypreferencespolicycontrol/services-data.dictionary) - `SystemPolicyAllFiles` and related protected file services.
- [Apple Developer Forums: On File System Permissions](https://developer.apple.com/forums/thread/678819) - TCC, responsible code, helper relationship, and testing guidance.
