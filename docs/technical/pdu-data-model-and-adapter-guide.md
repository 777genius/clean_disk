# pdu Data Model And Adapter Guide

Last updated: 2026-05-19.

This document records what `parallel-disk-usage` 0.23.0 actually returns, how that differs from the Clean Disk product model, and how the first `fs_usage_pdu` adapter should be implemented.

Read together with [pdu Clean Architecture contract](pdu-clean-architecture-contract.md)
and [pdu raw API contract map](pdu-raw-api-contract-map.md) before writing
durable domain, application, data, infrastructure, or protocol contracts. The
contract file defines the anti-corruption boundary. The raw map records pdu
internals, CLI presentation steps, fixture observations, and layer-by-layer
rules for what belongs in `fs_usage_core`, `fs_usage_engine`, `fs_usage_pdu`,
platform/accounting adapters, server DTOs, and Flutter data models.

## Decision

Use `parallel-disk-usage` as a private scanner backend only.

The product must not expose pdu `DataTree`, pdu JSON, pdu `Event`, or pdu path semantics through reusable `fs_usage_*`, daemon protocol DTOs, Flutter repositories, or UI state.

Version policy:

- Latest checked crates.io version on 2026-05-19 is `0.23.0`.
- Use the latest verified stable version, but pin it exactly in the adapter crate.
- Upgrade only through a scanner dependency update checklist: source audit, fixture rerun, real-directory smoke scan, benchmark comparison, and semantic review of size/error/hardlink behavior.
- Do not use a floating semver range for production scanner behavior.
- pdu `src/lib.rs` sets `#![deny(warnings)]`. Treat new compiler warning
  failures as dependency release-gate failures, not scanner runtime failures.
- pdu exposes `parallel_disk_usage::main()` behind `cli`; Clean Disk must not
  call it from the daemon because it reads argv/env, writes stderr, and returns
  process exit codes.

Top 3 implementation choices:

1. pdu library scan, then immediate conversion to our arena/read model - 🎯 9 🛡️ 9 🧠 7, roughly 1200-3000 LOC.
   This is the accepted first implementation. It keeps pdu fast, keeps pdu private, and gives Rust ownership of pagination, search, sorting, top lists, and issue mapping.
2. pdu scan plus lazy metadata enrichment for visible/query nodes - 🎯 9 🛡️ 8 🧠 8, roughly 2000-4500 LOC.
   This is the likely product-grade shape after the first adapter. It avoids re-statting millions of nodes immediately while still giving details for selected rows, details panel, cleanup queue, and search results.
3. Fork/patch pdu for streaming node callbacks and cancellable traversal now - 🎯 5 🛡️ 6 🧠 9, roughly 4000-9000 LOC.
   Keep this as a fallback if memory, cancellation latency, or metadata duplication proves unacceptable. Do not start here unless a spike proves the adapter cannot meet product gates.

## Source-Audit Addendum: SDK Helpers Are Not Product Contracts

The deeper pdu source pass confirms that pdu is a strong traversal/aggregation
adapter, but its helper APIs are shaped for CLI visualization and JSON
interchange, not Clean Disk product state.

Important SDK facts:

- `DataTree::children()` returns `&Vec<Self>`. It is a full in-memory child
  vector, not a paging or cursor API.
- `DataTree::name_mut()` exists and pdu CLI uses mutation to rename the fake
  multi-root from `""` to `"(total)"`. Product identity must not depend on this.
- `DataTree::par_retain`, `into_par_retained`, `par_sort_by`, and
  `into_par_sorted` mutate the tree for visualization/query-like output. They
  are not stable product query semantics.
- `par_cull_insignificant_data` is CLI-gated and uses a root-relative `f32`
  threshold. It is not a precision-safe filter contract.
- pdu `Fraction` is an `f32` wrapper whose constructor checks `>= 1.0` and
  `< 0.0`; non-finite values such as `NaN` must not become product filter
  thresholds.
- `Reflection` exposes public tree fields and pdu comments explicitly describe
  potentially invalid `DataTree` conversion. Safe validation through
  `par_try_into_tree` checks child-size greater-than-parent only.
- `JsonData` uses pdu `schema-version`, optional `pdu` binary version, `unit`,
  tree reflection, and optional hardlink shared details. It has no scan quality,
  capabilities, stable ids, cursors, permission state, or cleanup authority.
- pdu JSON output is created after CLI cull/sort/dedupe/fake-root behavior and
  writes to stdout. Its shared-hardlink conversion error is chained through
  `.or(deduplication_result)`, so it is not a product export receipt or daemon
  operation result.
- `ProgressAndErrorReporter` owns a reporting thread, uses relaxed atomic
  counters, calls error callback before incrementing error count, and can stop
  without creating a final product event.
- pdu `StatusBoard` is process-global terminal repaint state over stderr. It
  stores only a relaxed atomic line width and must not become a daemon progress
  sink, logger, metric source, event bus, or multi-client notification contract.
- pdu `BytesFormat` is both formatting logic and CLI value vocabulary when the
  `cli` feature is enabled. Its names and aliases such as `plain`, `metric`,
  `binary`, `1`, `1000`, and `1024` are adapter/diagnostic compatibility only,
  never product protocol, persistence, domain, or Flutter preference values.
- `DeviceBoundary::Stay` uses Unix `metadata.dev()`. On non-Unix pdu internal
  device id is `()`, so pdu cannot honestly prove same-device enforcement by
  itself.
- `OsStringDisplay` is useful adapter evidence, but it is not a product path
  model. Its `Display` output, native ordering, and convenience deref/mutation
  helpers must be consumed only by the pdu mapper. Root and child names carry
  different semantics and must be tagged before entering the engine read model.
- `FsTreeBuilder` can inspect the root more than once: one probe for
  `DeviceBoundary::Stay` root device, then normal traversal probes through
  `TreeBuilder::get_info`. This means the adapter must wrap pdu with our own
  target identity envelope instead of treating the returned root tree as proof
  that the preflight target stayed unchanged.
- `DataTree::dir` accepts an own/inode size but stores aggregate size. The pdu
  adapter must convert stored `DataTree.size()` into our aggregate evidence and
  must not reuse pdu constructors or derive own size from visible children.
- pdu hardlink `SharedLinkSummary` is scan evidence. `exclusive_shared_size`
  means pdu detected all links for a group inside the measured tree, not that
  cleanup can reclaim those bytes without current accounting and link-count
  revalidation.
- pdu hardlink dedupe is a prefix/suffix aggregate projection. It mutates pdu
  `DataTree.size` by subtracting duplicate observed links under each scope.
  Product hardlink-adjusted views must be recomputed from our
  `HardlinkGroupEvidence` with checked arithmetic, not copied from a mutated pdu
  tree.
- pdu `LinkPathListReflection` converts paths into a `HashSet`, so it is useful
  for diagnostics but not authoritative evidence when duplicate observations
  matter.

Conversion rule:

- production `fs_usage_pdu` reads pdu `DataTree` through immutable getters only:
  `name()`, `size()`, and `children()`;
- production conversion never calls `name_mut`, `par_retain`,
  `into_par_retained`, `par_sort_by`, `into_par_sorted`,
  `par_cull_insignificant_data`, or `fixed_size_dir_constructor`;
- pdu `children()` is a full child vector, not an API page. `fs_usage_engine`
  builds indexed pages/cursors after conversion;
- all product sort, filter, search, top lists, projection, and completeness
  semantics are engine read-model responsibilities;
- any pdu helper-mutated output is fixture/diagnostic-only and must be marked
  reduced-authority with projection evidence.

Layer mapping:

```text
fs_usage_core
  owns product truth:
    NodeRef
    SizeFacts
    ScanIssue
    ScanQuality
    HardlinkEvidence
    TraversalEvidence
    BoundaryPolicy
  never owns:
    DataTree helper semantics
    pdu JSON schema
    pdu progress counters
    pdu fake-root names

fs_usage_engine
  owns application truth:
    BackendScanRequest
    BackendScanOutput
    ScanSnapshotDraft
    NodeArena
    ReadModelIndexes
    query pagination
    scan phases
    capability decisions
  treats pdu as:
    final-tree evidence plus bounded reporter evidence

fs_usage_pdu
  owns SDK translation:
    PduScanRunner
    PduTreeConverter
    PduReporter
    PduIssueMapper
    PduSizeFactsMapper
    PduBoundaryCapabilityMapper
    PduDiagnosticJsonCodec
  must not expose:
    DataTree
    Reflection
    JsonData
    Reporter/Event
    GetSize
    HardlinkList
```

Top 3 handling options:

1. Treat every pdu helper as an adapter-private implementation detail - 🎯 10
   🛡️ 10 🧠 6, roughly 700-1800 LOC in guards, mappers, and fixtures.
   Accepted. We use helpers only behind explicit adapter modules and record the
   semantics they imply.
2. Reuse pdu helper output as the engine read model - 🎯 4 🛡️ 4 🧠 3, roughly
   300-900 LOC.
   Rejected. It leaks mutable CLI/display semantics into domain and breaks
   pagination, permissions, cleanup safety, and protocol evolution.
3. Disable all pdu helpers and only read raw tree getters - 🎯 8 🛡️ 8 🧠 5,
   roughly 500-1400 LOC.
   Good default for production scan conversion. Diagnostics may still use
   Reflection/JSON behind reduced-authority gates.

Implementation stop rule:

```text
If a pdu helper method shapes product behavior, stop.
Either move that behavior into fs_usage_engine, or mark it diagnostic-only.
```

## What pdu Returns

### Library entrypoint

pdu's docs point library users toward `FsTreeBuilder`, `TreeBuilder`, `DataTree`, and reporter modules. `FsTreeBuilder` is the real filesystem builder and accepts:

- `root: PathBuf`
- `size_getter`
- `hardlinks_recorder`
- `reporter`
- `device_boundary`
- `max_depth`

`FsTreeBuilder` converts into `DataTree<OsStringDisplay, Size>`.

The builder uses `std::fs::symlink_metadata`, not `metadata`, so symlinks are measured as symlink entries and are not followed. It uses `read_dir` only when the current path is a directory and device policy allows traversal.

Wide-directory memory note:

- pdu collects all successful child `file_name()` values for a directory into a
  `Vec` before recursive parallel work starts;
- pdu does not expose exact temporary child-vector peak memory;
- final `DataTree` child counts are not enough to reconstruct hidden temporary
  allocation, especially when `max_depth` hides returned descendants but pdu
  still traverses deeper for aggregate size;
- `fs_usage_pdu` reports memory evidence with confidence: observed, calibrated,
  inferred, or unknown.

Important traversal contract:

- pdu returns a `DataTree` through `From<FsTreeBuilder>`, not a
  `Result<DataTree, Error>`;
- filesystem errors are side-channel evidence from `Reporter::report`;
- a returned pdu tree is not proof of scan success or subtree completeness;
- `fs_usage_pdu` must build `PduRawScanResult` from tree shape plus reporter,
  metadata tap, hardlink, target preflight, and timing evidence;
- `PduEvidenceJoiner` maps that adapter-only evidence into stable product
  `ScanIssue`, `ChildCompleteness`, `TargetScanOutcome`, `ScanQuality`, and
  `BackendMetrics` before crossing into `fs_usage_engine`;
- Flutter and protocol never see pdu callback events or pdu operation names.

### DataTree

`DataTree<Name, Size>` is a final aggregate tree with private fields:

```rust
name: Name
size: Size
children: Vec<DataTree<Name, Size>>
```

Public access is only:

- `name()`
- `name_mut()`
- `size()`
- `children()`
- parallel retain/sort helpers
- conversion into reflection for JSON feature use

Important semantics:

- Root `name` is the root path passed to pdu.
- Child `name` values are basename-like filesystem names, not full paths.
- Full paths are not stored per node. We must reconstruct them while converting.
- A directory size is its own metadata size plus descendant sizes.
- If `max_depth` cuts children, sizes below the cut still count, but child nodes are discarded.
- `DataTree` is not a product read model. It has no stable node id, no parent id, no item counts, no modification time, no permissions, no file kind beyond "has children", no issue links, no cloud state, no delete state, and no search indexes.

### Reporter events

`Reporter::report(&self, Event<Size>)` is called synchronously from traversal.

Current pdu 0.23.0 event variants:

- `ReceiveData(Size)` - one metadata result was measured.
- `EncounterError(ErrorReport)` - filesystem operation failed.
- `DetectHardlink(HardlinkDetection)` - hardlink-aware recorder detected a hardlink.

`Event` is `#[non_exhaustive]`, so adapter matching must include `_ => {}` or a typed unknown-event counter.

Reporter events are pdu callback evidence, not product events. The callback must
copy small owned facts into bounded adapter-side stores and return quickly.
Product `ScanEvent` batches are emitted later by `fs_usage_engine`, with product
sequence numbers, throttling, redaction, scan phase, and compatibility semantics.

Lifecycle note:

- `FsTreeBuilder` requires pdu `Reporter + Sync`, not `ParallelReporter`;
- production `PduReporter` should implement pdu `Reporter` only;
- pdu `ParallelReporter::destroy` is for reporters with their own reporting
  threads, such as pdu's built-in progress reporter, and stays diagnostic-only;
- scan session lifecycle remains in `fs_usage_engine`, not in pdu reporter traits.

`ErrorReport` includes:

- `operation`
- `path`
- `error`

Current operations:

- `SymlinkMetadata`
- `ReadDirectory`
- `AccessEntry`

This is enough to classify skipped or partial scan reasons, but not enough to say a whole scan failed. pdu can return a tree while also reporting many errors.

### Progress

pdu progress is reporter-derived counters, not a streaming node API.

The built-in `ProgressAndErrorReporter` tracks:

- items
- total size
- errors
- linked
- shared

It reports on a timer thread and can stop that progress thread, but this is not cooperative traversal cancellation.

Important adapter interpretation:

- `items` means successful metadata/size measurements observed so far;
- `total size` is an approximate measured-size counter during traversal;
- `linked` is incremented from reported link counts, so it is not a unique hardlink group count;
- `shared` is observed hardlink candidate size, not exclusive reclaimable space;
- the last pdu progress snapshot is not the final scan summary.

Map these counters into `PduProgressEvidence`. Product `ScanPhaseProgress`,
dashboard totals, cleanup candidate totals, and final `ScanSummary` come from
`BackendScanOutput`, `NodeArena`, read-model indexes, and issue aggregation.

Clean Disk should implement its own reporter:

- increment atomics or send tiny internal events only;
- never do JSON serialization, socket fanout, DB writes, logging of raw paths, or metadata enrichment inside the callback;
- throttle outward progress to UI, for example 100-250 ms;
- expose current phase and target from the session, not from pdu current path, because pdu does not provide a reliable current path stream.

Do not use pdu's built-in `ProgressAndErrorReporter` in production. It spawns a
progress thread and cleanup requires an explicit `destroy()` path; pdu 0.23.0
source does not show a `Drop` implementation for that cleanup. Diagnostic use is
allowed only with a mandatory destroy/join guard and panic mapping.

The same rule applies to the `RecordHardlinks` metadata tap. It can capture
scan-time evidence, but recorder errors are ignored by pdu and must not be used
as cancellation, backpressure, or product failure.

### JSON output

pdu JSON is useful for prototypes, diagnostics, and golden fixture comparison. It is not the Clean Disk protocol.

Observed pdu 0.23.0 JSON shape:

```json
{
  "schema-version": "2026-04-02",
  "pdu": "0.23.0",
  "unit": "bytes",
  "tree": {
    "name": "/path/to/root",
    "size": 270,
    "children": [
      { "name": "dir", "size": 142, "children": [] }
    ]
  },
  "shared": {
    "details": [
      {
        "ino": 505517136,
        "dev": 16777232,
        "size": 5,
        "links": 2,
        "paths": ["/path/a", "/path/b"]
      }
    ],
    "summary": {
      "inodes": 1,
      "exclusive_inodes": 1,
      "all_links": 2,
      "detected_links": 2,
      "exclusive_links": 2,
      "shared_size": 5,
      "exclusive_shared_size": 5
    }
  }
}
```

The source defines JSON fields as:

- `schema-version`
- `pdu`
- `unit`
- `tree`
- optional `shared`

Critical caveats:

- pdu JSON converts names to UTF-8 and has a source TODO to allow non-UTF8 names.
- JSON tree root differs for one target vs multiple CLI targets.
- pdu JSON is tree-shaped and can be huge. It should not be sent to Flutter as the scan result.
- JSON numeric byte values must not become Flutter web exact-decision numbers.
- pdu JSON stdout/error precedence is CLI behavior. Clean Disk exports need our
  own receipt with separate status for serialization, transport, cache, and
  evidence-quality issues.
- The `json` feature should be test/diagnostic only unless a future CLI-compatible export feature is explicitly designed.

## What pdu Does Not Return

pdu does not directly return:

- stable `NodeId`;
- parent ids;
- full path per node;
- item counts per subtree;
- modified time;
- permissions;
- owner/group;
- file kind beyond directory traversal outcome;
- symlink target;
- cloud placeholder/provider state;
- sparse/compressed/COW/reflink/sharing evidence;
- APFS snapshot or clone exclusivity;
- Windows reparse point identity;
- search index;
- top files/folders index;
- cleanup recommendation evidence;
- safe delete authority;
- reclaim estimate confidence;
- cooperative cancellation token;
- resumable scan state;
- product protocol DTOs.

These belong in our `fs_usage_*` read model, metadata/accounting adapters, daemon protocol, and cleanup preflight.

## Best Adapter Shape

The pdu integration should be one private adapter crate:

```text
fs_usage_engine
  application ports:
    ScannerBackend
    ScanSession
    ScanEventSink
    MetadataEnricher
    FilesystemAccounting

fs_usage_pdu
  imports parallel_disk_usage
  maps our ScanConfig to pdu FsTreeBuilder config
  runs pdu inside PduExecutionLane, a bounded Rayon pool selected by ResourceProfile
  owns PduReporter
  converts pdu DataTree to NodeArena/ScanSnapshot
  maps pdu errors and hardlink evidence to ScanIssue/HardlinkEvidence

clean-disk-server
  selects fs_usage_pdu as concrete ScannerBackend
  maps ScanSnapshot queries to HTTP responses
  maps ScanEvents to WebSocket events
```

`parallel-disk-usage` import rule:

```text
allowed:   crates/fs_usage_pdu/**
forbidden: crates/fs_usage_engine/**
forbidden: apps/clean_disk_server/**
forbidden: Flutter packages/features/apps
```

Cargo dependency:

```toml
parallel-disk-usage = { version = "=0.23.0", default-features = false }
```

Use pdu's `json` feature only for adapter tests or diagnostic exports if
needed. Do not enable the `cli` feature for the daemon adapter unless a measured
need appears.

Also do not enable pdu auxiliary tooling features in production:
`ai-instructions`, `cli-completions`, `man-page`, or `usage-md`.

Dependency graph implication:

- `default-features = false` removes pdu CLI/JSON feature edges, but pdu still
  has normal non-optional dependencies that are not scanner domain concepts;
- enabling `json` adds serialization dependencies and makes pdu JSON easier to
  misuse as protocol;
- enabling `ai-instructions` pulls `clap/derive` and is not scanner behavior;
- enabling `cli` also enables `json` and pulls CLI/presentation behavior into the
  binary;
- enabling `cli` also exposes pdu's library-level CLI `main()` entrypoint. This
  remains forbidden in production daemon code even if it is technically
  available;
- enabling `cli-completions`, `man-page`, or `usage-md` enables `cli`, so they
  are also forbidden in production daemon builds;
- `fs_usage_pdu` should record an effective dependency graph fingerprint in
  diagnostics/build evidence once the Rust workspace exists.

Target API implication:

- docs.rs and pdu crate metadata are references, not capability authority;
- Unix-only pdu APIs such as `HardlinkAware`, `GetBlockSize`, `GetBlockCount`,
  `DeviceNumber::get`, and `InodeNumber::get` must be proven by target compile
  checks;
- Windows builds must compile the pdu adapter with Unix pdu paths disabled and
  explicit unsupported/degraded capability values;
- protocol and Flutter read capability DTOs, not pdu target or `cfg` names.

### Rayon execution

pdu uses Rayon internally for tree traversal and several helper operations.
The product must not call pdu through Rayon global policy.

Accepted mapping:

- `ResourceProfile` is a product/application concept;
- `PduLanePolicy` maps that profile to a bounded local Rayon pool;
- `PduExecutionLane` calls `ThreadPool::install` around `FsTreeBuilder` and any
  pdu helper diagnostics;
- pdu CLI `Threads`, HDD auto-thread detection, and `build_global()` are not used
  by the daemon adapter;
- conversion and index building have separate metrics and budgets from pdu walk.

## Data Flow

Accepted MVP data flow:

```text
ScanConfig
  -> target preflight and normalization
  -> ResourceProfile selects PduExecutionLane
  -> pdu FsTreeBuilder per normalized root
  -> PduReporter internal counters/issues/hardlinks
  -> DataTree<OsStringDisplay, Size>
  -> NodeArenaBuilder
  -> ScanSnapshot / ReadModel / Indexes
  -> paginated daemon queries
  -> Flutter tree/details/search/top pages
```

Do not do this:

```text
pdu CLI JSON -> HTTP response -> Flutter builds full tree
pdu DataTree -> Flutter
pdu Event -> WebSocket per filesystem entry
pdu path string -> delete authority
```

## Conversion Rules

### Node ids

Generate stable IDs inside our snapshot, not from pdu:

- `NodeId` can be an arena index plus snapshot epoch, or an opaque generated id.
- Do not use raw path as the primary id.
- Keep file identity separately for delete preflight and stale result detection.

### Paths

Root path comes from normalized `ScanTarget`.

For each child:

```text
full_path = parent.full_path.join(pdu_child.name())
```

Store paths as native path objects or path refs on the Rust side. Protocol DTOs should expose:

- display path;
- encoded native path ref or opaque authority ref;
- never raw display text as delete authority.

### Counts

During conversion, calculate:

- direct child count;
- descendant file count;
- descendant folder count;
- total item count;
- skipped issue count under subtree;
- hardlink evidence count under subtree if enabled.

Use iterative conversion or explicit stack-depth guards. A deep filesystem tree
should not make our converter blow the Rust stack. Record converter depth
evidence separately from pdu scan success: pdu can return a tree, while a naive
recursive converter can still fail afterward.

### Sorting and pagination

pdu `DataTree::par_sort_by` is useful for CLI visualization, but product sorting belongs to our indexes.
pdu child order comes from filesystem `read_dir` collection plus adapter
conversion and must be treated as diagnostic observation only. Product pages use
engine-owned `SnapshotOrderIndex`, deterministic tie-breakers, and opaque cursors
that include snapshot, query, and index version identity.

Build read-model indexes:

- children by parent;
- top folders by size;
- top files by size;
- normalized name/path search;
- issues by node/path;
- hardlink groups by inode/device where available;
- optional modification-time index after metadata enrichment.

The daemon returns pages and cursors. Flutter never owns the full tree.

### Metadata enrichment

pdu already calls `symlink_metadata`, but `DataTree` does not keep metadata. Reusing pdu without a fork means metadata must be enriched separately.

Recommended path:

1. MVP: convert pdu tree into `NodeArena` with size and hierarchy first.
2. Lazily enrich metadata for visible rows, selected node details, cleanup queue, top files, and search result pages.
3. Add batched enrichment for frequently used fields if UI proves too sparse.
4. Only fork/patch pdu to expose metadata if duplicate stat cost becomes a measured bottleneck.

This avoids turning every scan into "pdu scan plus restat all nodes" for million-node trees.

### Issues and skipped paths

Map pdu `EncounterError` to typed scan issues:

```text
SymlinkMetadata -> CannotStatPath
ReadDirectory   -> CannotReadDirectory
AccessEntry     -> CannotAccessDirectoryEntry
```

Keep:

- native path ref;
- display path;
- operation;
- OS error kind/code;
- severity;
- whether aggregate size is partial;
- nearest known node if it can be attached safely.

Do not treat pdu exit/process success as full scan success. Scan quality is our own aggregate state:

- `complete`
- `partial_with_skips`
- `partial_permission_limited`
- `failed_preflight`
- `cancelled`
- `stale_discarded`

### Hardlinks

Use pdu hardlink-aware mode as evidence, not product truth.

What pdu gives:

- path;
- metadata reference during event;
- size;
- number of links;
- Unix inode/device evidence through hardlink recorders and JSON diagnostics.

Platform capability facts:

- pdu built-in `HardlinkAware` is Unix-only in 0.23.0;
- pdu `DeviceNumber::get`, `InodeNumber::get`, and `MetadataExt::nlink()` usage
  are Unix-only in the built-in aware path;
- non-Unix pdu uses `HardlinkIgnorant` unless we add a separate backend or
  platform provider;
- custom `RecordHardlinks` implementations can be useful as metadata taps, but
  metadata-tap support does not mean hardlink group support;
- Windows NTFS/MFT hardlink evidence must come from a future platform/scanner
  adapter that maps into the same domain contract.

Rules:

- hardlink dedupe affects scan totals only when enabled by policy;
- hardlink evidence must be recorded in the snapshot;
- hardlink capability must be reported as supported, unsupported, or degraded;
- deleting one hardlink path usually does not reclaim the full file size;
- reclaim confidence must be computed by our accounting layer, not pdu;
- Windows hardlink/reparse behavior needs separate platform handling.

### Size policy

Map our `SizePolicy` to pdu size getters:

- `apparent` -> `GetApparentSize`
- `allocated_bytes` on Unix -> `GetBlockSize`
- `allocated_blocks` on Unix diagnostics -> `GetBlockCount`
- non-Unix allocated size -> platform adapter or explicit unsupported/degraded capability

`GetBlockSize` means Unix `MetadataExt::blocks() * 512`, not filesystem I/O
block size and not exact reclaimable bytes. Store `source_api`,
`source_unit = unix_512_byte_blocks`, measurement kind, and confidence with the
value.

Keep pdu `GetSize` pure. It receives only `&Metadata`, returns a size directly,
and can run concurrently inside pdu traversal workers. Do not use custom
`GetSize` implementations as metadata enrichment, logging, event emission,
cancellation, or reclaim-accounting hooks. Path-aware metadata belongs to
`MetadataProvider`; reclaim math belongs to accounting adapters.

Do not implement pdu `Size` for product value objects. pdu `Size` is optimized
for traversal and requires copyable ordinary arithmetic plus display support.
`fs_usage_pdu` should use pdu `Bytes`/`Blocks` only as adapter input, then map
them into engine-owned `MeasuredQuantity`/`SizeFacts` with explicit unit,
measurement kind, source evidence, exactness, and confidence.

Do not call these "reclaimable bytes". pdu sizes are scan measurements, not safe cleanup estimates.

### Device and mount policy

pdu has `DeviceBoundary::Cross` and `DeviceBoundary::Stay`.

Clean Disk needs a richer policy:

- cross same-volume directories;
- stop at mount boundary;
- include/exclude external volumes;
- include/exclude network volumes;
- include/exclude cloud sync roots;
- include/exclude platform protected roots.

The pdu adapter maps only the simple part to pdu. The rest is target preflight, capability detection, and path classification around pdu.

### Multi-root scans

Do not depend on pdu CLI's `(total)` root behavior.

Clean Disk owns:

- target normalization;
- deduplication of overlapping parent/child targets;
- synthetic root naming;
- per-target scan quality;
- target-level cancellation state;
- per-root issue counts.

Recommended implementation:

```text
normalize targets
for each root under worker budget:
  run FsTreeBuilder
  convert to our root node
merge roots under our synthetic ScanRoot
```

This is more predictable than emulating pdu CLI multi-root semantics.

### Cancellation

pdu 0.23.0 does not expose a confirmed traversal cancellation token.

Accepted MVP behavior:

- session stores `cancel_requested`;
- scan work runs inside `PduExecutionLane`, not Rayon global pool;
- worker is supervised by scan epoch;
- late pdu results are discarded;
- UI state becomes `cancelling` until the current adapter call returns;
- split multi-root scans at root boundaries where possible;
- keep future pdu fork/patch option for cooperative checks.

Do not promise instant cancellation until a spike proves worst-case latency.

## Contract Tests To Add First

Adapter tests should freeze behavior before real product code depends on it:

- file target returns a zero-child root;
- directory target returns aggregate size and children;
- symlink-to-file target is leaf;
- symlink-to-directory target is leaf unless our preflight resolves it;
- missing target creates preflight failure before pdu, not silent zero-size success;
- unreadable directory maps to `CannotReadDirectory`;
- file deleted during scan maps to `CannotStatPath` or degraded result;
- sparse file differs between apparent and allocated policies;
- hardlinks detected and deduped on Unix;
- multi-root parent/child overlap normalized by us;
- `max_depth=1` keeps aggregate size but discards children;
- JSON diagnostics schema remains `2026-04-02` for 0.23.0;
- unknown future pdu event does not panic;
- pdu version and option fingerprint are stored with scan snapshot test fixtures.

## Implementation Checklist

1. Create `fs_usage_engine` public scanner contracts without pdu types.
2. Create `fs_usage_pdu` with pinned pdu dependency and boundary tests that forbid imports elsewhere.
3. Implement `PduScanConfigMapper`.
4. Implement `PduReporter` with atomics plus bounded issue/hardlink channels.
5. Implement `PduRawScanResult` containing pdu tree plus copied reporter summary.
6. Convert `DataTree` to `NodeArena` and immediately drop the pdu tree.
7. Build item counts and child indexes in Rust.
8. Add lazy metadata enrichment port and first adapter.
9. Add query APIs for children/top/search/details using pages.
10. Add scan quality aggregation from pdu errors and preflight outcomes.
11. Add memory and time metrics split by `pdu_scan`, `tree_convert`, `index_build`, and `metadata_enrich`.
12. Add cancellation state and late-result discard.

## Red Flags

Stop and revisit if any of these appear:

- `parallel_disk_usage` imported outside `fs_usage_pdu`;
- Flutter receives full pdu JSON;
- WebSocket emits one event per `ReceiveData`;
- delete flow trusts pdu path or pdu size directly;
- progress reporter performs blocking IO;
- pdu `DataTree` remains in memory after our read model is built;
- metadata enrichment re-stats every node by default without a benchmark gate;
- UI depends on pdu `max_depth` for lazy expansion;
- scan success is inferred from process exit instead of issue aggregation;
- pdu upgrade changes fixture totals without a semantic review.

## Sources

- [parallel-disk-usage 0.23.0 crate page](https://docs.rs/crate/parallel-disk-usage/latest) - version, features, library and JSON extension notes, limitations, installation and release attestation notes.
- [parallel_disk_usage crate docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/) - library entrypoints and module map.
- [FsTreeBuilder docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/fs_tree_builder/struct.FsTreeBuilder.html) - root, reporter, hardlink recorder, device boundary, and `max_depth` semantics.
- [DataTree docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/data_tree/struct.DataTree.html) - private tree model, getters, reflection, sort/retain helpers.
- [Reporter docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/index.html) and [Event docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/event/enum.Event.html) - reporter/event contract and non-exhaustive event enum.
- [ErrorReport docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/error_report/struct.ErrorReport.html) and [Operation docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/error_report/operation/enum.Operation.html) - filesystem error shape.
- Local source audit of `~/.cargo/registry/src/.../parallel-disk-usage-0.23.0`.
- Local fixture runs with `pdu 0.23.0`, including JSON output, hardlink summary/details, `max_depth`, missing target, symlink target, and real `~/Downloads` and `~/Library` scans.
