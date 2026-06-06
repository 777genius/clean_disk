# pdu Raw API Contract Map

This document records the raw `parallel-disk-usage` (`pdu`) facts that must be
understood before writing Clean Disk data contracts.

Read together with [pdu Clean Architecture contract](pdu-clean-architecture-contract.md).
That file defines the layer boundary and anti-corruption rules; this file
records the pdu source facts behind those rules.

Scope:

- pinned library version: `parallel-disk-usage 0.23.0`;
- local CLI currently installed: `pdu 0.23.0`;
- source inspected from Cargo registry for the pinned crate;
- public docs checked on docs.rs and upstream GitHub;
- small controlled fixtures were run locally for JSON shape, hardlinks,
  symlinks, missing targets, multi-root behavior, and `max_depth`.

Primary sources:

- `parallel_disk_usage` crate docs: https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/
- `FsTreeBuilder` docs: https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/fs_tree_builder/struct.FsTreeBuilder.html
- `DataTree` docs: https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/data_tree/struct.DataTree.html
- upstream repository and README: https://github.com/KSXGitHub/parallel-disk-usage
- local source: `~/.cargo/registry/src/.../parallel-disk-usage-0.23.0`

## Accepted Contract Position

1. Clean Disk data contracts are built from our `fs_usage_engine` read model,
   not from pdu JSON or pdu `DataTree` - 🎯 10 🛡️ 10 🧠 6, roughly
   1200-3000 LOC across adapter mapping, read model records, fixture tests, and
   boundary tests.
2. pdu raw outputs are fixture evidence and adapter input only - 🎯 10 🛡️ 9
   🧠 5, roughly 500-1200 LOC for golden fixtures, semantic assertions, and
   source-version fingerprints.
3. Exposing pdu `DataTree` or pdu JSON as product data contract is rejected -
   🎯 10 🛡️ 3 🧠 4. It is easy initially but becomes brittle because pdu does
   not carry product identity, metadata, pagination, delete safety, or protocol
   evolution semantics.

Core rule:

```text
pdu raw scan facts
  -> private fs_usage_pdu adapter structs
  -> fs_usage_engine NodeArena / ScanSnapshot / indexes
  -> clean_disk_server product protocol DTOs
  -> Flutter application models and view models
```

Never:

```text
pdu JSON -> Flutter tree
pdu DataTree -> public fs_usage API
pdu Event -> WebSocket event
pdu path string -> delete authority
```

## Internal Execution Model

pdu is structured as a fast traversal and visualization crate, not as a product
storage engine.

Raw library path:

```text
FsTreeBuilder
  -> symlink_metadata(root)
  -> TreeBuilder
  -> symlink_metadata(each path)
  -> reporter.ReceiveData(size)
  -> hardlink recorder
  -> read_dir(directory)
  -> child file names
  -> recursive Rayon tree build
  -> DataTree<OsStringDisplay, Size>
```

CLI path adds presentation steps:

```text
Args
  -> quantity / thread / reporter selection
  -> Sub::run
  -> one FsTreeBuilder per input root
  -> optional fake "(total)" root for multi-root CLI input
  -> optional min-ratio culling
  -> optional size sort
  -> optional hardlink dedupe
  -> JSON or ASCII visualizer
```

Key internal consequences:

- traversal uses Rayon recursion through `TreeBuilder`, so pdu is good at fast
  full-tree aggregation but does not expose a streaming node callback contract;
- pdu gathers child names from `read_dir`, then joins them back to paths during
  recursion;
- `DataTree::dir` stores directory own/inode size plus child totals as one
  aggregate `size`;
- pdu CLI sorting and min-ratio culling are display behaviors, not product
  query semantics;
- pdu CLI fake `(total)` root is display behavior, not product multi-root
  identity;
- pdu JSON converts names to UTF-8, which makes JSON unsuitable as the product
  source for path-fidelity guarantees;
- pdu library traversal uses Rayon, but `FsTreeBuilder` does not accept a
  thread-count option. Thread/resource policy must be controlled by our adapter
  execution lane, not by pdu domain options;
- Rayon `ThreadPool::install` runs nested Rayon operations inside the chosen
  custom pool. That means the pdu adapter can run `FsTreeBuilder` inside our
  bounded pool even though pdu internally calls `par_iter`/`into_par_iter`;
- pdu CLI has extra runtime behavior, such as auto-limiting threads for HDD
  detection. That is CLI host behavior, not reusable library contract;
- pdu has no domain concept of scan session, snapshot, node identity, page
  cursor, cleanup candidate, or reclaim estimate.

Adapter rule:

```text
Use pdu's library traversal.
Do not use pdu's CLI presentation pipeline as product behavior.
```

## Raw pdu Library Shape

### `FsTreeBuilder`

`FsTreeBuilder` is the primary filesystem entrypoint. Its public fields are:

```text
root: PathBuf
size_getter
hardlinks_recorder
reporter
device_boundary
max_depth
```

Important behavior from source:

- it calls `symlink_metadata`, so symlinks are measured as symlink entries and
  are not followed;
- it calls `read_dir` only when the item is a directory and allowed by device
  boundary policy;
- it reports `ReceiveData(size)` after successful metadata read;
- it reports `EncounterError` for `symlink_metadata`, `read_dir`, and
  directory-entry access failures;
- it records hardlinks through the configured hardlink recorder;
- `max_depth` controls stored/displayed children, while deeper sizes still roll
  into ancestors.

Contract implication:

- target preflight is our responsibility;
- symlink-follow policy is our responsibility;
- current-path progress is not available from pdu;
- device-boundary policy has only `Cross` or `Stay`, so richer mount/reparse
  rules belong outside pdu;
- `max_depth` cannot power lazy expansion in the UI.
- pdu can return a `DataTree` even when errors occurred; scan quality must be
  computed by our application layer.

Error detail:

- root `symlink_metadata` error returns a zero-size leaf named as the root path;
- child metadata errors return a zero-size no-child `Info` for that path;
- `read_dir` errors keep the directory's own measured size and discard children;
- `DirEntry` access errors skip that entry and report the parent path.

Contract implication:

- do not treat zero-size leaf as proof that a target is empty;
- preserve error operation and path evidence in `ScanIssue`;
- model partial/degraded scan result explicitly;
- run target preflight before pdu so missing roots are typed failures.

### `TreeBuilder`

`TreeBuilder` is pdu's generic recursive tree constructor. It receives:

```text
path
name
get_info(path) -> Info { size, children }
join_path(parent_path, child_name)
max_depth
```

It then builds children with Rayon:

```text
children.into_par_iter()
  -> child TreeBuilder
  -> DataTree child
```

`max_depth` behavior is subtle:

- it decrements the depth during recursion;
- when the depth limit is reached, it still scans/builds child totals;
- it returns a node with aggregated size but `children = []`.

Contract implication:

- pdu can compute a shallow displayed tree with correct totals;
- pdu cannot later expand a shallow node without rescanning or having retained
  its children;
- our read model should not use pdu `max_depth` for ordinary expandable UI;
- if we add partial/subtree scans later, that is an `fs_usage_engine` feature,
  not a pdu `max_depth` feature.

### `DataTree`

pdu `DataTree<Name, Size>` stores only:

```text
name
size
children
```

Fields are private. Public getters expose:

```text
name() -> &Name
size() -> Size
children() -> &Vec<Self>
```

Contract implication:

- no stable node id;
- no parent id;
- no full path except root and reconstructable child path context;
- no file type except "has children" after traversal;
- no item counts;
- no modified time;
- no permissions;
- no owner;
- no filesystem identity;
- no skipped/error links on the tree nodes;
- no cloud/provider state;
- no delete/reclaim safety state;
- no pagination, search, or top-list index.

Therefore `DataTree` must be consumed immediately into our own arena/read model
and dropped as soon as practical.

### Path and Name Representation

pdu uses `OsStringDisplay` around OS strings. Its `Display` behavior is:

```text
valid UTF-8 -> display as UTF-8
invalid UTF-8 -> display Debug representation
```

Contract implication:

- never use `Display` output as path identity;
- keep OS path/name bytes in Rust-side identity/display-safe structures;
- web/protocol DTOs must distinguish machine identity from display text;
- support bundles and logs must redact or encode paths intentionally;
- pdu JSON is not path-fidelity safe for non-UTF-8 names.

### `Reflection` and JSON

pdu JSON is built by converting `DataTree` to `Reflection`. The JSON tree shape
is:

```json
{
  "schema-version": "2026-04-02",
  "pdu": "0.23.0",
  "unit": "bytes",
  "tree": {
    "name": "...",
    "size": 123,
    "children": []
  },
  "shared": {
    "details": [],
    "summary": {}
  }
}
```

`unit` is tagged as either:

- `bytes` for apparent size or block size;
- `blocks` for block count.

Important JSON limitation:

- pdu converts names to UTF-8 for JSON and has a source TODO for non-UTF-8
  names. Product contracts must not depend on pdu JSON for path fidelity.

Contract implication:

- pdu JSON is useful for prototypes, diagnostics, and golden fixtures;
- pdu JSON is not our daemon protocol and not the Flutter tree contract;
- product DTOs need explicit versioning independent from pdu schema version.

### Reporter Events

pdu reporter events are synchronous calls through:

```text
Reporter::report(Event<Size>)
```

`Event` is `non_exhaustive` and currently includes:

```text
ReceiveData(Size)
EncounterError(ErrorReport)
DetectHardlink(HardlinkDetection)
```

`ErrorReport` contains:

```text
operation: SymlinkMetadata | ReadDirectory | AccessEntry
path: &Path
error: std::io::Error
```

`HardlinkDetection` contains:

```text
path: &Path
stats: &Metadata
size: Size
links: u64
```

`ProgressReport` counters are:

```text
items
total
errors
linked
shared
```

Contract implication:

- progress is counter-based, not percent-based;
- pdu does not know final total before the scan ends;
- UI progress must say "scanned X items / Y bytes so far", not exact percent
  unless we derive a separate estimate;
- events must be throttled by our adapter/session layer;
- unknown future pdu events must not crash the adapter.

pdu's built-in progress reporter uses atomics plus a sleeping thread. Clean Disk
should not use that reporter in production. The adapter should implement a
custom reporter that:

- updates bounded counters;
- sends throttled event batches to `fs_usage_engine`;
- never blocks pdu traversal on a slow UI/WebSocket client;
- keeps raw path data out of production logs;
- supports terminal drain and late-result discard by scan epoch.

### Size Modes

pdu size getters:

```text
GetApparentSize -> metadata.len()
GetBlockSize    -> metadata.blocks() * 512 on Unix
GetBlockCount   -> metadata.blocks() on Unix
```

CLI defaults:

- Unix: `block-size`;
- non-Unix: `apparent-size`.

Contract implication:

- our size facts must name the measurement mode explicitly;
- pdu sizes are scan measurements, not reclaim estimates;
- reclaim estimates must be computed by a separate filesystem accounting layer.
- `Bytes` alone is not enough. Apparent bytes and block-size bytes share the
  same numeric unit but have different semantics.

Recommended domain shape:

```text
SizeFacts
  apparent_bytes: Option<ByteSize>
  allocated_bytes: Option<ByteSize>
  block_count: Option<BlockCount>
  measured_mode: SizeMeasurementMode
  reclaim_estimate: Option<ReclaimEstimate>
  confidence: SizeConfidence
```

### Hardlinks

Hardlink support is Unix-only in pdu's current implementation.

Hardlink-aware mode:

- ignores directories;
- detects files with `nlink > 1`;
- keys records by inode plus device;
- emits `DetectHardlink`;
- can deduplicate shared size from directory totals;
- can output JSON `shared.details` and `shared.summary`.

Controlled fixture output showed:

```json
"shared": {
  "details": [
    {
      "ino": 506498854,
      "dev": 16777232,
      "size": 4096,
      "links": 2,
      "paths": [".../dir_a/a.txt", ".../dir_b/a-hardlink.txt"]
    }
  ],
  "summary": {
    "inodes": 1,
    "exclusive_inodes": 1,
    "all_links": 2,
    "detected_links": 2,
    "exclusive_links": 2,
    "shared_size": 4096,
    "exclusive_shared_size": 4096
  }
}
```

The same fixture had root block-size total:

```text
without hardlink dedupe: 12288
with hardlink dedupe:     8192
```

Contract implication:

- hardlink data is evidence, not delete truth;
- hardlink policy must be visible in scan options and scan result metadata;
- delete/reclaim still needs platform identity revalidation.
- hardlink dedupe changes aggregate folder totals, so UI and exports must show
  whether the snapshot used deduped or non-deduped totals.

Important pdu detail:

- pdu hardlink dedupe mutates `DataTree` after the scan by walking path prefixes;
- pdu CLI removes overlapping roots only for some hardlink-dedupe multi-root
  cases;
- Clean Disk must normalize targets and overlapping roots before backend scan,
  regardless of hardlink policy.

### Sorting and Culling

pdu `DataTree` supports:

```text
par_sort_by
par_retain
par_cull_insignificant_data
```

The CLI uses these for chart readability. Clean Disk must not use them as the
main product query model.

Contract implication:

- sorting belongs to our `ChildIndex`, `TopIndex`, and query services;
- filtering belongs to our query/index layer;
- pdu culling would destroy nodes we may need for search, details, cleanup, or
  accurate issue counts;
- pdu sorting mutates the tree and should not define stable UI order across
  different product queries.

### Dependency And Feature Policy

Cargo features in `parallel-disk-usage 0.23.0`:

```text
default = ["cli"]
cli     = ["clap/derive", "clap_complete", "clap-utilities", "json"]
json    = ["serde/derive", "serde_json"]
```

Adapter policy:

- production `fs_usage_pdu` uses `default-features = false`;
- enable pdu `json` only for adapter fixtures or diagnostic tooling if needed;
- never enable pdu `cli` in the daemon adapter unless a measured requirement is
  documented;
- record exact pdu version and feature set in scan backend diagnostics;
- every pdu upgrade reruns semantic fixtures before changing accepted behavior.

Reason:

- `cli` includes behavior that belongs to an executable, not our reusable
  scanner adapter;
- JSON is useful evidence but weak as product protocol;
- smaller feature surface reduces supply-chain and behavior drift.

## Hidden Source-Level Behaviors To Guard

These are implementation details found in pdu 0.23.0 source that must shape our
adapter contract.

### No Native Product Cancellation

pdu traversal has no public cancellation token in `FsTreeBuilder`. The built-in
progress reporter can stop its progress thread, but that does not stop the scan
recursion.

Contract rule:

- `ScannerBackendCapabilities` must expose cancellation level;
- pdu adapter capability starts as `CancelRequestOnly`;
- `fs_usage_engine` owns `cancel_requested`, `cancelling`, `cancelled`, and
  late-result discard by epoch;
- if cancel latency is unacceptable, we either upstream a cancellation hook,
  keep a small fork, or run pdu behind a killable execution boundary.

Do not promise immediate cancellation in UI or protocol for pdu-backed scans.

### Rayon Global Pool And Resource Budgets

pdu uses Rayon internally. The CLI can configure a global Rayon thread pool, but
the library `FsTreeBuilder` does not accept a per-scan thread count.

Source audit shows `build_global()` only in pdu's CLI app path, while traversal
and tree helpers use Rayon parallel iterators internally.

Contract rule:

- resource profiles belong to `fs_usage_engine` and host execution policy;
- `Fast`, `Balanced`, and `Background` are product policies, not pdu options;
- if per-scan isolation is required, `fs_usage_pdu` should run inside a
  dedicated scoped/custom Rayon pool or a controlled worker boundary;
- never let Flutter or protocol choose pdu thread settings directly.

Risk:

- one aggressive scan can starve the daemon control plane or UI if we rely on
  pdu defaults.

Required mitigation:

- daemon health, cancel, and query endpoints must stay responsive while pdu is
  scanning;
- pdu scan work must be treated as blocking/heavy work, not normal async work.

Accepted execution boundary:

1. Dedicated Rayon pool inside `fs_usage_pdu` runner - 🎯 8 🛡️ 9 🧠 7,
   roughly 400-1000 LOC.
   `PduScanRunner` owns or borrows a `PduExecutionLane` selected from the
   product `ResourceProfile`, then executes the pdu scan through
   `pool.install(|| run_fs_tree_builder(...))`. Rayon documents that `install`
   makes nested `join`, `scope`, and parallel iterators operate in that pool.
   This is the accepted MVP path.
2. Global Rayon pool - 🎯 4 🛡️ 5 🧠 3, roughly 50-150 LOC.
   Easy, but rejected for product runtime because one scan can consume process
   parallelism and make the daemon control plane less predictable.
3. External helper process per scan - 🎯 6 🛡️ 8 🧠 9, roughly 2500-6000 LOC.
   Strong isolation, but it complicates macOS TCC identity, signing, updates,
   crash recovery, and local web pairing. Keep this as a future execution
   adapter if measured isolation needs justify it.

Hard rule:

```text
PduScanRunner
  -> PduExecutionLane
  -> rayon::ThreadPool::install(...)
  -> FsTreeBuilder

Never call rayon::ThreadPoolBuilder::build_global from product daemon code.
```

The only acceptable exception is a standalone benchmark or fixture binary whose
name and Cargo feature make it impossible to ship in the normal app.

### Error Semantics Are Partial, Not Terminal

pdu reports filesystem errors through reporter events while still returning a
tree. It does not convert permission errors, missing children, or unreadable
directories into a single failed result.

Contract rule:

```text
BackendScanOutput
  snapshot
  scan_issues
  scan_quality
```

not:

```text
Result<DataTree, Error>
```

Scan quality must distinguish:

- complete;
- partial with skipped paths;
- degraded by permission errors;
- target preflight failed;
- cancelled;
- failed by adapter/runtime error.

### Hardlink Recorder Errors Are Not Product Errors

pdu's `FsTreeBuilder` calls hardlink recording and then discards the returned
error with `.ok()`. With pdu's built-in `HardlinkAware`, conflicts in size or
link count can fail inside the hardlink recorder without becoming a scanner
failure.

Contract rule:

- hardlink evidence must carry confidence;
- hardlink conflicts or incomplete hardlink data become `ScanIssue` or
  `HardlinkEvidenceQuality`, not hidden success;
- pdu hardlink summary is not enough for cleanup authority.

Top 3 adapter choices:

1. Custom hardlink recorder implementing pdu `RecordHardlinks` - 🎯 8 🛡️ 9
   🧠 8, roughly 600-1400 LOC.
   Best long-term evidence model. It can collect conflicts and emit our own
   adapter diagnostics before pdu discards return errors.
2. Use pdu `HardlinkAware`, then map summary/details as weak evidence - 🎯 8
   🛡️ 7 🧠 5, roughly 300-800 LOC.
   Good MVP if hardlink quality is labeled and not used for delete authority.
3. Disable hardlink dedupe in MVP and record only policy gap - 🎯 6 🛡️ 8 🧠 3,
   roughly 100-300 LOC.
   Safest for simplicity but weaker product value on hardlink-heavy trees.

Accepted starting position:

```text
MVP may use pdu HardlinkAware as weak evidence.
Contract must allow replacing it with a custom recorder.
Delete/reclaim safety cannot depend on pdu hardlink evidence alone.
```

### pdu JSON Can Panic On Non-UTF-8 Names In CLI Path

pdu CLI JSON conversion calls UTF-8 conversion and expects success. The source
contains a TODO to allow non-UTF-8 names. This is another reason the production
daemon must not use pdu JSON as the product data path.

Contract rule:

- library adapter converts `OsStringDisplay`/OS names into our path/name model;
- protocol display strings are lossy-safe and separate from identity;
- non-UTF-8 fixture is required before protocol DTOs are locked.

### pdu CLI Multi-Root Normalization Is Conditional

pdu CLI removes overlapping roots only for hardlink-dedupe multi-root cases and
creates a fake `(total)` root for multiple inputs.

Contract rule:

- `fs_usage_engine` normalizes targets before backend scan;
- synthetic root identity is ours;
- overlapping target behavior is ours;
- pdu CLI target behavior is not a product rule.

### pdu Sort And Culling Are Destructive

pdu `par_sort_by`, `par_retain`, and `par_cull_insignificant_data` mutate or
remove nodes in the tree.

Contract rule:

- adapter conversion should preserve raw node structure needed for product
  queries;
- sort/filter/culling belong to indexes and query projections;
- do not use pdu `min_ratio` for product scan results.

### Non-Exhaustive Public Types

pdu uses `#[non_exhaustive]` on event/error-like types. Future versions may add
variants.

Contract rule:

- pdu upgrade gates must include source audit and fixture rerun;
- match statements in `fs_usage_pdu` must include fallback handling;
- unknown pdu event maps to backend diagnostic issue, not panic.

### Panic Containment

Normal pdu library paths should not panic for ordinary filesystem errors, but
source contains panics/assertions in helper/summary/test-like paths and CLI JSON
conversion has an `expect` for UTF-8 conversion.

Contract rule:

- production adapter avoids CLI JSON path;
- pdu work should run inside a panic boundary where practical;
- panic becomes adapter failure with crash-safe session terminal state;
- daemon process should preserve operation journal and not expose partial
  cleanup authority after panic.

## Controlled Fixture Observations

### Small tree with file, symlink, and hardlink

Block-size JSON produced:

```text
root.size = 8192 with dedupe
dir_a/a.txt = 4096
dir_b/a-hardlink.txt = 4096
root.txt = 4096
link-to-a = 0
shared.summary.shared_size = 4096
```

Interpretation:

- symlink entry exists as leaf;
- hardlink children still appear as nodes;
- dedupe changes aggregate totals;
- visible row size and aggregate ancestor size need a clear size policy.

### Apparent-size mode

Apparent-size JSON produced small byte values from `metadata.len()`, including
directory metadata and symlink target length on macOS.

Interpretation:

- apparent size is not equal to local allocated size;
- the UI must distinguish "apparent", "allocated/local", and future
  "exclusive reclaim estimate".

### Missing target

CLI behavior for missing target:

```text
exit = 0
stderr = [error] symlink_metadata "...": No such file or directory
tree.name = missing path
tree.size = 0
tree.children = []
```

Interpretation:

- CLI exit code is not enough to classify scan success;
- our adapter must preflight targets and aggregate scan quality from errors;
- missing target should become a typed preflight failure, not a valid empty
  folder.

### Multi-root CLI behavior

CLI creates a fake root:

```json
{
  "name": "(total)",
  "children": [
    {"name": "/absolute/root/a", "...": "..."},
    {"name": "/absolute/root/b", "...": "..."}
  ]
}
```

Interpretation:

- `(total)` is CLI presentation behavior;
- Clean Disk must create its own synthetic root with target metadata;
- cleanup cannot target synthetic roots.

### `max_depth`

Controlled fixture:

```text
max_depth=1 -> root has total size, children = []
max_depth=2 -> root has immediate child, child has total size, child.children = []
```

Interpretation:

- `max_depth` preserves aggregate size but discards deeper child nodes;
- it is not lazy expansion;
- expandable UI requires full-depth scan, subtree rescan, or future pdu patch.

## Clean Disk Data Contract Requirements

The data contract should be designed around these product facts, not raw pdu
fields.

Minimum internal read-model record:

```text
NodeRecord
  node_id
  parent_id
  first_child
  child_count
  local_name_ref
  depth
  size_facts
  node_flags
  metadata_state
  issue_counters
  hardlink_state
```

Minimum query DTO concepts:

```text
NodeRef
  scan_session_id
  snapshot_id
  node_id
  generation

TreePageQuery
  parent: NodeRef
  cursor
  limit
  sort
  filter

TreeRowDto
  node_ref
  parent_ref
  display_name
  depth
  has_children
  expansion_state
  size_facts
  percent_of_parent
  item_counts
  issue_badges
  metadata_state

NodeDetailsDto
  node_ref
  display_path
  size_facts
  metadata
  identity_evidence
  issues
  hardlink_evidence
  action_availability
```

Data that must be enriched outside pdu:

- stable id and snapshot identity;
- full path reconstruction;
- item counts;
- file kind;
- modified time;
- permissions and ownership;
- platform identity;
- scan quality and skipped reasons;
- cloud/provider placeholder state;
- search/sort/top indexes;
- delete preflight and stale identity checks;
- reclaim estimate confidence.

## Domain And Infrastructure Layer Contract

This is the layer mapping we should preserve when implementing the Rust side.

### Domain Layer: `fs_usage_core`

Allowed responsibilities:

- value objects and entities that are true regardless of scanner backend;
- `NodeId`, `ScanSessionId`, `ScanSnapshotId`, `NodeRef`;
- `SizeFacts`, `SizeMeasurementMode`, `SizeConfidence`;
- `ScanIssue`, `ScanQuality`, `PermissionState`;
- `HardlinkEvidence`, but not pdu hardlink structs;
- `PathDisplay`, `PathIdentityEvidence`, but not pdu path authority;
- immutable domain rules such as "synthetic roots cannot be cleanup targets".

Forbidden in domain:

- `parallel_disk_usage` imports;
- pdu `DataTree`, `Event`, JSON, hardlink list, or size getter types;
- filesystem traversal, `symlink_metadata`, `read_dir`, Rayon thread config;
- daemon protocol DTOs;
- Flutter, HTTP, WebSocket, persistence, or platform delete adapters.

Domain invariant examples:

```text
NodeRef always includes snapshot identity.
NodeId is not derived from path string alone.
Synthetic root is queryable but not deletable.
SizeFacts never mean "safe to reclaim" by default.
Partial scan with permission errors is successful-but-degraded, not full truth.
```

Domain naming rule:

```text
Use product names:
  NodeRef
  SizeFacts
  ScanIssue
  TraversalPolicy
  BoundaryPolicy
  HardlinkPolicy

Do not use pdu names:
  DataTree
  Reflection
  FsTreeBuilder
  ReceiveData
  EncounterError
  DeduplicateSharedSize
```

SOLID implications:

- SRP: domain changes only when product filesystem language changes, not when
  pdu internals change;
- OCP: new scanners add adapters and capabilities, not new domain branches;
- LSP: every scanner backend must satisfy the same `ScannerBackend` contract,
  even if it reports weaker capabilities;
- ISP: scanner, metadata, accounting, cleanup, and event ports stay separate;
- DIP: domain/application depend on traits and value objects, not pdu structs.

### Application Layer: `fs_usage_engine`

Allowed responsibilities:

- scanner use cases and session lifecycle;
- ports such as `ScannerBackend`, `MetadataProvider`, `AccountingProvider`,
  `TrashProvider`, and `Clock`;
- `ScanConfig`, `TraversalPolicy`, `SizePolicy`, `HardlinkPolicy`,
  `BoundaryPolicy`, `ResourceProfile`;
- orchestration of scan jobs, cancellation state, epochs, and late-result
  discard;
- conversion target shape: `ScanSnapshotBuilder`, `NodeArena`, indexes,
  pagination, search, sort, top lists, and details queries;
- scan quality aggregation from pdu errors, preflight results, and metadata
  enrichment outcomes.

Forbidden in application:

- direct pdu imports;
- pdu-specific option names in public use cases;
- sending full trees to clients;
- assuming pdu CLI success means product scan success;
- tying cancellation semantics to pdu internals.

Application ports should speak product language:

```text
trait ScannerBackend {
  fn capabilities(&self) -> ScannerBackendCapabilities;
  fn scan(&self, request: BackendScanRequest, sink: ScanEventSink)
    -> Result<BackendScanOutput, ScanFailure>;
}

BackendScanRequest
  targets
  traversal_policy
  size_policy
  hardlink_policy
  boundary_policy
  resource_profile
  snapshot_epoch

BackendScanOutput
  raw_node_source converted into ScanSnapshotBuilder
  scan_issues
  backend_metrics
  capability_observations
```

The application layer owns the public contract. pdu is only one backend that
implements that contract.

Recommended port split:

```text
ScannerBackend
  raw traversal and aggregate measurement

MetadataProvider
  file type, modified time, permissions, owner, identity evidence

VolumeProvider
  mount/device/volume information and boundary facts

AccountingProvider
  allocated/exclusive/quota/reclaim estimates

CleanupPlanner
  delete candidate preflight and DeletePlan creation

EventSink
  throttled application events, not raw scanner callbacks
```

Avoid:

```text
trait FilesystemService {
  scan
  stat
  estimate_reclaim
  delete
  trash
  search
}
```

That would violate interface segregation and make pdu look like a full
filesystem product engine, which it is not.

### Infrastructure/Data Layer: `fs_usage_pdu`

Allowed responsibilities:

- import `parallel_disk_usage`;
- exact-pin and feature-gate the pdu dependency;
- map `BackendScanRequest` to `FsTreeBuilder` fields;
- create or receive a bounded `PduExecutionLane` for the requested
  `ResourceProfile`;
- create a custom `Reporter`;
- collect pdu `ReceiveData`, `EncounterError`, and `DetectHardlink`;
- run the scan inside the bounded execution lane chosen by the host/engine;
- convert `DataTree<OsStringDisplay, Size>` into `ScanSnapshotBuilder`;
- map pdu `ErrorReport` into product `ScanIssue`;
- map hardlink detections and optional dedupe report into product
  `HardlinkEvidence`;
- record pdu version, options fingerprint, scan timing, raw node count, and
  backend metrics.

Forbidden in `fs_usage_pdu`:

- delete policy;
- cleanup recommendations;
- UI pagination decisions;
- daemon protocol DTOs;
- Flutter DTOs;
- long-lived ownership of product read model;
- exposing pdu public types from its public API.

Recommended internal modules:

```text
fs_usage_pdu/
  src/
    lib.rs
    adapter/
      pdu_scanner_backend.rs
      pdu_execution_lane.rs
      pdu_scan_runner.rs
      pdu_options_mapper.rs
      pdu_reporter.rs
      pdu_raw_result.rs
      pdu_tree_converter.rs
      pdu_issue_mapper.rs
      pdu_hardlink_mapper.rs
      pdu_metrics.rs
    fixtures/
      fixture_builder.rs
      expected_raw.rs
      expected_snapshot.rs
    tests/
      contract_hardlinks.rs
      contract_symlinks.rs
      contract_missing_target.rs
      contract_max_depth.rs
      contract_non_utf8.rs
      contract_boundaries.rs
```

Adapter mapping table:

| pdu source | `fs_usage_pdu` maps to | Layer owning final meaning |
| --- | --- | --- |
| `FsTreeBuilder.root` | backend target after preflight | `fs_usage_engine` |
| `DeviceBoundary::Cross/Stay` | `BoundaryPolicy` subset | `fs_usage_engine` and platform adapter |
| `GetApparentSize` | `SizeMeasurementMode::Apparent` | `fs_usage_core` |
| `GetBlockSize` | `SizeMeasurementMode::AllocatedApprox` | `fs_usage_core` plus accounting |
| `DataTree.name` | local name segment or root target display source | read-model builder |
| `DataTree.size` | measured aggregate size fact | read-model builder |
| `DataTree.children` | child arena records and child index | read-model builder |
| `ReceiveData` | backend progress counter | session progress throttle |
| `EncounterError` | typed `ScanIssue` evidence | application scan quality |
| `DetectHardlink` | hardlink evidence | hardlink evidence index |
| pdu JSON | fixture/diagnostic only | adapter tests |

Adapter public API should expose:

```text
PduScannerBackend
  implements ScannerBackend

PduBackendConfig
  pdu version policy
  enabled features fingerprint
  default size policy mapping
  default hardlink policy mapping

PduBackendDiagnostics
  pdu_version
  pdu_feature_set
  raw_scan_duration
  conversion_duration
  reporter_counts
```

Adapter public API should not expose:

```text
parallel_disk_usage::DataTree
parallel_disk_usage::reporter::Event
parallel_disk_usage::json_data::JsonData
parallel_disk_usage::hardlink::HardlinkList
```

### Platform Infrastructure: `fs_usage_platform`

Responsibilities outside pdu:

- metadata enrichment for visible/query/detail nodes;
- platform identity collection for delete revalidation;
- permission/capability probing;
- volume and mount classification;
- cloud placeholder/provider state where possible;
- path display/redaction helpers.

Important rule:

```text
pdu can measure tree size.
fs_usage_platform decides what the filesystem item actually is.
```

Platform enrichment should be lazy and batched:

- visible rows first;
- selected details next;
- cleanup queue candidates before DeletePlan;
- search/top results only when needed;
- full-tree restat only after a measured requirement.

Reason:

- pdu already paid a metadata cost but does not keep metadata;
- restatting millions of nodes can erase pdu's speed benefit;
- visible/detail-first enrichment preserves responsiveness.

### Accounting Infrastructure: `fs_usage_accounting`

Responsibilities outside pdu:

- apparent versus allocated versus exclusive reclaim estimate;
- APFS clone/snapshot caveats;
- reflink/shared extent caveats on Btrfs/ZFS/ReFS;
- sparse/compressed/cloud-placeholder caveats;
- quota and observed free-space delta handling.

Important rule:

```text
pdu size is a measurement.
reclaim estimate is a separate claim with confidence and evidence.
```

pdu-specific caution:

- pdu documents itself as ignorant of reflinks and does not model snapshots;
- hardlink dedupe is not enough for APFS clones, Btrfs/ZFS/ReFS shared extents,
  Time Machine/APFS snapshots, sparse files, compression, or cloud placeholders;
- domain copy must never say "will free X bytes" based only on pdu `size`.

### Server/Data Protocol: `clean_disk_server`

Responsibilities:

- map `fs_usage_engine` query results to versioned protocol DTOs;
- expose HTTP commands/queries and WebSocket events;
- throttle and coalesce events;
- keep auth/origin/local token policy;
- hide pdu and reusable library internals from clients.

Forbidden:

- protocol field named after pdu internals;
- full `DataTree` JSON in a response;
- WebSocket event per filesystem item;
- path string as action authority.

### Flutter Data Layer

Responsibilities:

- `CleanDiskApiClient` and `ScanEventClient`;
- DTO mappers into feature application models;
- presentation view models built from application models;
- no pdu vocabulary.

Flutter should receive:

```text
TreePageDto
NodeDetailsDto
ScanProgressDto
ScanIssueSummaryDto
CleanupQueueDraftDto
DeletePlanDto
```

Flutter should never receive:

```text
DataTree
Reflection
pdu schema-version
pdu event names
pdu fake "(total)" root
raw pdu hardlink JSON
```

## Contract Type Sketch

These sketches are guidance for the implementation agent. Names can evolve, but
the dependency direction must not.

Domain value objects in `fs_usage_core`:

```text
ScanSessionId
ScanSnapshotId
NodeId
NodeRef
ScanTarget
SyntheticRootKind
TraversalPolicy
BoundaryPolicy
HardlinkPolicy
SizePolicy
SizeFacts
ScanIssue
ScanQuality
BackendCapabilityFlag
```

Application port types in `fs_usage_engine`:

```text
ScannerBackend
ScannerBackendCapabilities
BackendScanRequest
BackendScanOutput
ScanEventSink
ScanSnapshotBuilder
NodeArenaWriter
ReadModelIndexes
ResourceProfile
ExecutionLane
```

Infrastructure-only pdu types in `fs_usage_pdu`:

```text
PduScannerBackend
PduExecutionLane
PduRawScanResult
PduReporter
PduOptionsMapper
PduTreeConverter
PduIssueMapper
PduHardlinkMapper
PduBackendDiagnostics
```

Forbidden type dependency:

```text
fs_usage_core -> fs_usage_pdu
fs_usage_engine -> fs_usage_pdu
clean_disk_protocol -> fs_usage_pdu
Flutter -> pdu vocabulary
```

## Clean Architecture Placement Matrix

| Concern | Domain `fs_usage_core` | Application `fs_usage_engine` | Infrastructure/Data | Interface/Server |
| --- | --- | --- | --- | --- |
| Node identity | Defines `NodeId`/`NodeRef` invariants | Allocates per snapshot | Uses during conversion | Serializes opaque ids |
| Tree traversal | Forbidden | Calls `ScannerBackend` | pdu/custom/MFT adapter | No direct traversal |
| Size meaning | Defines `SizeFacts` and confidence | Chooses policy | Measures/enriches | Presents DTO fields |
| Metadata | Defines value objects | Requests through port | OS/platform adapter | Details DTO |
| Hardlinks | Evidence model | Policy and issue aggregation | pdu/platform evidence | Badges/details DTO |
| Errors/skips | `ScanIssue` language | Quality aggregation | pdu/platform mappers | Issue summaries/events |
| Pagination | Page value objects | Owns indexes and query use cases | No UI decisions | HTTP query DTO |
| Delete safety | Candidate invariants | DeletePlan/preflight use cases | Trash/platform adapter | Commands/receipts |
| Resource budget | Policy value objects | Schedules jobs | Runs pdu in bounded lane | Shows state |

## Contract-First Implementation Order

1. Define `fs_usage_core` value objects and invariants - 🎯 10 🛡️ 10 🧠 6,
   roughly 800-1800 LOC.
2. Define `fs_usage_engine` ports and read-model builders - 🎯 10 🛡️ 10 🧠 7,
   roughly 1500-3500 LOC.
3. Implement `fs_usage_pdu` against the port with fixtures - 🎯 9 🛡️ 9 🧠 7,
   roughly 1800-4200 LOC.
4. Add platform metadata enrichment through a separate port - 🎯 9 🛡️ 9 🧠 7,
   roughly 1200-3000 LOC.
5. Add server protocol DTOs after the engine query DTOs stabilize - 🎯 9 🛡️
   10 🧠 6, roughly 1000-2500 LOC.

Do not start with protocol DTOs or Flutter DTOs, because that tends to freeze
pdu-shaped fields before the engine contract is correct.

## Adapter Implementation Rule

The first adapter should have an explicit private raw result:

```text
PduRawScanResult
  data_tree
  reporter_summary
  error_events
  hardlink_events
  hardlink_report
  tree_stats
  size_policy_used
  hardlink_policy_used
  boundary_policy_used
  pdu_version
  adapter_options_fingerprint
  started_at
  finished_at
```

Then convert immediately:

```text
PduRawScanResult
  -> ScanSnapshotBuilder
  -> NodeArena
  -> ChildIndex
  -> SizeIndex
  -> IssueIndex
  -> HardlinkEvidenceIndex
```

Stop conditions:

- pdu `DataTree` survives after read-model build;
- product DTO includes pdu field names;
- Flutter receives pdu JSON or full tree JSON;
- delete logic uses pdu path string as authority;
- scan status treats pdu CLI/process success as full product success;
- data contract cannot represent partial scan, skipped paths, or degraded
  confidence.

## Implementation Decision For First Contract

Top 3 choices for the first real contract:

1. `fs_usage_engine` read-model contract first, pdu adapter second - 🎯 10 🛡️
   10 🧠 7, roughly 2500-6000 LOC.
   Best path. It protects domain and clients from pdu and allows future
   backends such as Windows MFT or custom scanner.
2. pdu adapter first with a private raw result, then extract engine contract -
   🎯 7 🛡️ 7 🧠 6, roughly 1800-4500 LOC.
   Faster spike, but risks pdu vocabulary leaking into the engine contract.
3. pdu JSON contract first - 🎯 3 🛡️ 3 🧠 4, roughly 800-2000 LOC.
   Rejected. It is easy to demo but weak for non-UTF-8 names, pagination,
   metadata, partial scan states, cleanup safety, and future backends.

Accepted direction:

```text
Define fs_usage_engine contract first.
Implement fs_usage_pdu against it.
Use pdu raw fixtures to verify mapping.
```

## Next Contract Spike

Before writing the durable data package/contracts, implement a small contract
fixture suite:

1. normal nested tree;
2. hardlink tree with dedupe on and off;
3. symlink-to-file and symlink-to-directory;
4. missing target;
5. multi-root normalized by our code, not pdu `(total)`;
6. `max_depth` proof that it is not lazy expansion;
7. non-UTF-8 filename at library level, with JSON explicitly excluded as
   product source;
8. permission-denied fixture where platform allows safe reproduction.
9. hardlink conflict/incomplete evidence fixture or mocked recorder behavior;
10. pdu event unknown/fallback handling test;
11. cancellation request during scan with late-result discard;
12. resource-budget smoke test where daemon control plane remains responsive;
13. boundary test that no pdu types/imports leak outside `fs_usage_pdu`;
14. pdu upgrade fingerprint fixture with version, feature set, and option hash.

Each fixture should assert:

- pdu raw behavior;
- our adapter raw result;
- our read-model shape;
- public protocol DTO shape;
- no pdu types outside `fs_usage_pdu`.
- degraded confidence is represented when pdu cannot prove a fact.

Acceptance gate:

```text
No pdu-shaped public contract is accepted until these fixtures pass.
```
