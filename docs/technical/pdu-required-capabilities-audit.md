# pdu Required Capabilities Audit

Last updated: 2026-05-16.

This document audits `parallel-disk-usage` 0.23.0 against the capabilities Clean Disk needs.

This is stricter than the performance validation. The question here is:

```text
Which product functions can pdu provide directly,
which ones need an adapter layer,
and which ones require a different backend or future pdu patch?
```

## Verdict

pdu covers the fast aggregate scan part very well.

pdu does not cover product semantics.

Top 3 conclusions:

1. pdu is good as `fs_usage_pdu` traversal/aggregation backend - 🎯 9 🛡️ 8 🧠 6, roughly 900-2200 LOC for adapter, mapping, reporter, and fixtures.
2. pdu must be wrapped by our read model, metadata enrichment, and operation semantics - 🎯 10 🛡️ 10 🧠 8, roughly 2500-7000 LOC across scanner engine, indexes, protocol, and tests.
3. pdu alone cannot satisfy cancellation, lazy expansion, platform identity, cloud semantics, reclaim estimates, or delete safety - 🎯 10 🛡️ 10 🧠 7, roughly 3000-9000 LOC handled outside pdu.

## Sources And Local Checks

- `cargo info parallel-disk-usage` confirmed latest checked crate version `0.23.0`, Apache-2.0, default feature `cli`, optional `json`.
- Local source audit of `parallel-disk-usage-0.23.0` in Cargo registry.
- Local CLI checks with `pdu 0.23.0`.
- Local throwaway library spike using `parallel-disk-usage = { version = "=0.23.0", default-features = false }`.
- Extra fixture checks for file target, symlink target, multi-root, missing path, hardlink dedupe, and overlapping roots.

## Capability Matrix

| Clean Disk requirement | pdu status | Fit | What we do |
| --- | --- | --- | --- |
| Fast recursive scan | Direct: `FsTreeBuilder` + Rayon. | Strong | Use behind `fs_usage_pdu`. |
| Directory aggregate tree | Direct: `DataTree<Name, Size>`. | Strong | Convert immediately to our arena/read model. |
| File target scan | Direct. | Strong | Supported. |
| Directory target scan | Direct. | Strong | Supported. |
| Multi-root scan | CLI builds fake root `(total)`. Library caller can do same. | Medium | Prefer our own synthetic root and target metadata. |
| Overlapping root handling | CLI removes overlaps only for hardlink dedupe and only in specific path cases. | Weak | Detect overlapping targets ourselves before scan. |
| Full expandable tree | Possible only with full depth. | Medium | Use full-depth scans or add lazy subtree rescan later. |
| Lazy expansion without full scan | Not provided. | Weak | Future feature needs our own subtree scan strategy or pdu patch. |
| Stable node id | Not provided. | Weak | Our read model owns IDs. |
| Full path per node | Not stored in `DataTree`. | Weak | Reconstruct while converting, or enrich from traversal events if patched later. |
| Parent id | Not stored. | Weak | Our arena owns parent ids. |
| File type | Not stored. | Weak | Metadata enrichment pass. |
| Modified time | Not stored. | Weak | Metadata enrichment pass. |
| Permissions/owner/group | Not stored. | Weak | Platform metadata adapter. |
| Platform identity | Not stored as product concept. | Weak | Platform identity adapter. |
| Apparent size | Direct: `GetApparentSize`. | Strong | Use as one explicit size mode. |
| Allocated/block size | Direct on Unix: `GetBlockSize`. | Medium | Use where available; Windows needs separate adapter. |
| Block count | Direct on Unix: `GetBlockCount`. | Medium | Diagnostic mode only if useful. |
| Reclaim estimate | Not provided. | Weak | Separate accounting adapter. |
| Sparse files | Block size on Unix reflects sparse allocation. | Medium | Good evidence, not full reclaim semantics. |
| Compression/COW/reflinks | Not handled. pdu docs/source do not provide this. | Weak | Separate platform accounting. |
| Hardlink detection | Unix direct: `HardlinkAware`, `DetectHardlink`. | Medium | Use as evidence, not delete authority. |
| Hardlink dedupe | Unix direct through `DeduplicateSharedSize`. | Medium | Record policy and confidence. |
| Windows hardlinks | CLI rejects hardlink dedupe on non-Unix. | Weak | Future Windows identity/MFT adapter. |
| Symlink traversal safety | Uses `symlink_metadata`, so symlinks are not followed. | Strong | Good default. |
| Symlink target scan policy | Symlink-to-dir selected as root is treated as leaf, not followed. | Medium | Target picker must choose resolve-vs-link policy. |
| Device boundary | Unix `DeviceBoundary::Cross/Stay`. | Medium | Map from our mount policy. |
| Windows mount/reparse boundary | Not supported by pdu CLI path. | Weak | Future Windows/platform adapter. |
| Permission errors | Direct through `EncounterError`. | Medium | Map to `ScanIssue`; success exit can still be partial. |
| Missing target | Emits `symlink_metadata` error and zero-size node, exit 0. | Medium | Preflight targets ourselves before scan. |
| Error operations | `SymlinkMetadata`, `ReadDirectory`, `AccessEntry`. | Medium | Map to typed issue reasons. |
| Progress item count | Reporter can count `ReceiveData`. | Medium | Use custom reporter and throttle. |
| Progress current path | Not provided. | Weak | Do not promise current path unless we add our own traversal/pdu patch. |
| Progress percent | Not provided because total unknown. | Weak | UI shows scanned items/size, not real percent, until indexed total exists. |
| Cooperative cancellation | Not found. | Weak | Session-supervised cancel and possible future patch/fork. |
| Thread limit | CLI supports `--threads`; library uses Rayon global pool. | Medium | Run scan inside our controlled Rayon pool or worker budget. |
| HDD-aware auto threads | CLI has HDD detection and sets threads to 1 on auto. | Medium | Reimplement in our resource profile if needed. |
| Include/exclude filters | Not provided in `FsTreeBuilder`. | Weak | Pre/post filter, or future custom traversal/pdu patch. |
| Skip directories before traversal | Not provided in `FsTreeBuilder`. | Weak | Needed for product exclusions or dangerous roots. |
| Sorting | `DataTree::par_sort_by`. | Medium | Useful for diagnostics only; product sort belongs to indexes. |
| Culling/min ratio | CLI-only `par_cull_insignificant_data`. | Weak | Not for product pagination. |
| Search | Not provided. | Weak | Our indexes. |
| Top files/folders | Not provided as query API. | Weak | Our indexes. |
| Pagination/cursors | Not provided. | Weak | Our read model. |
| JSON output | Available with `json` feature through reflection. | Medium | Prototype/diagnostics only, not product protocol. |
| Non-UTF8 JSON names | CLI conversion expects UTF-8. | Weak | Our protocol needs path encoding strategy. |
| Delete safety | Not provided. | Weak | DeletePlan and platform preflight. |
| Cloud placeholders | Not modeled. | Weak | Cloud/provider adapter. |
| Network/FUSE semantics | Not modeled. | Weak | Platform capability and issue model. |
| Watch/incremental scan | Not provided. | Weak | Future watcher/incremental layer. |

## Extra Fixture Findings

### File Target

pdu scans a single file as a zero-child tree.

Implication:

- file targets are supported;
- our UI can allow scanning a file, but product value is mostly largest-file/details/search.

### Symlink Target

When target is a symlink to a directory, pdu treats the symlink itself as a leaf. It does not follow the target.

Implication:

- safe by default;
- target picker must decide whether a user-selected symlink should scan the link itself or resolve target;
- if resolving, that is our preflight policy, not pdu behavior.

### Missing Target

Missing path produced:

```text
symlink_metadata error
size 0
children 0
exit 0
```

Implication:

- Clean Disk must preflight target existence;
- pdu exit code is not enough to classify scan success.

### Multi-Root

pdu CLI creates fake root `(total)` with each target as a child.

Implication:

- useful behavior;
- our model should create its own synthetic root with stable target metadata and source labels;
- do not depend on pdu `(total)` naming.

### Overlapping Roots

pdu CLI has overlap removal logic only when hardlink dedupe is enabled and multiple roots are passed.

Implication:

- Clean Disk must detect target overlap itself;
- scanning parent plus child can double-count or confuse user intent if not normalized.

## Function-By-Function API Audit

### `FsTreeBuilder`

Use: yes.

Role:

```text
filesystem traversal
size collection
device boundary policy
reporter events
hardlink recorder integration
```

Do not expose outside `fs_usage_pdu`.

### `TreeBuilder`

Use: maybe later.

Role:

- generic tree builder from arbitrary path/name info;
- can be useful if we create a custom traversal source;
- still only builds `DataTree`.

Not MVP-critical.

### `DataTree`

Use: internally only.

Good:

```text
name
size
children
constructors
parallel sort
parallel retain
hardlink dedupe internal support
reflection conversion
```

Bad for product:

```text
no ids
no full paths
no metadata
no scan issues
no query API
```

### `Reporter`

Use: yes, custom implementation.

Do:

- collect counters;
- collect errors;
- collect hardlink events;
- send cheap bounded events;
- throttle product events outside reporter callback.

Do not:

- do heavy work inside `report`;
- emit one UI event per pdu event;
- assume event order means traversal order.

### `ProgressAndErrorReporter`

Use: no for product.

Good for CLI, but product should implement custom reporter because:

- progress output is text-oriented;
- interval/reporting is CLI-oriented;
- errors need structured mapping;
- stopping reporter thread is not scan cancellation.

### `HardlinkAware`

Use: yes on Unix, behind policy.

Do:

- record hardlink evidence;
- optionally dedupe aggregate totals;
- expose scan hardlink mode.

Do not:

- treat hardlink dedupe as cleanup reclaim truth;
- rely on it for Windows.

### `DeviceBoundary`

Use: yes, but only as adapter mapping.

Our product should expose richer policy:

```text
cross mounts
stay on selected filesystem
skip network mounts
skip external volumes
provider roots
```

pdu only gets `Cross` or `Stay`.

### `GetApparentSize`, `GetBlockSize`, `GetBlockCount`

Use:

- apparent size: yes;
- block size: yes where supported;
- block count: diagnostic only.

Windows allocated-size support needs another path.

### JSON Reflection

Use: diagnostics/prototype only.

Reasons:

- pdu schema is not our protocol;
- JSON output includes pdu schema version;
- non-UTF8 conversion is not product-safe;
- DTOs need stable Clean Disk schema.

### Visualizer

Use: no for product.

Good for CLI/manual debugging, but Flutter owns visualization.

## Capability Gaps That May Force Upstream Patch Or Fork

Patch/fork only if measured product needs demand it.

Top 3 possible pdu extensions:

1. Cooperative cancellation token - 🎯 8 🛡️ 9 🧠 7, roughly 500-1500 LOC upstream/fork plus tests.

   Most likely useful. Check token before/after metadata, read_dir, and child traversal.

2. Node-complete/current-path event - 🎯 6 🛡️ 7 🧠 7, roughly 700-1800 LOC.

   Useful for better progress and streaming partial tree, but can hurt performance and privacy if overused.

3. Traversal filter callback - 🎯 7 🛡️ 8 🧠 8, roughly 800-2000 LOC.

   Useful for exclusions, package-mode restrictions, dangerous roots, cloud provider roots, and performance.

## Required Contract Tests Before App Integration

Create fixture tests for:

```text
file target
empty directory
wide directory
deep directory
symlink to file
symlink to directory
hardlink pair
missing target
permission denied
parent + child overlapping targets
multi-root scan
max_depth behavior
min_ratio/culling not used for product
apparent vs block size
sparse file
changing file during scan
deleted file during scan
```

Later OS-specific fixtures:

```text
Windows junction
Windows symlink
Windows OneDrive placeholder
Windows NTFS hardlink
Windows ReFS/non-NTFS fallback
Linux non-UTF8 filename
Linux bind mount
Linux FUSE/rclone mount
Btrfs/ZFS reflink
macOS APFS clone
macOS Full Disk Access protected folder
```

## Final Rule

```text
pdu owns traversal and aggregate tree.
fs_usage owns product scan model.
Clean Disk owns protocol and user-facing semantics.
```

If a feature needs identity, safety, recovery, cloud semantics, queryability, cancellation, or reclaim truth, it belongs outside pdu.
