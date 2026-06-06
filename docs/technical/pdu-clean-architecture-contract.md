# pdu Clean Architecture Contract

Last updated: 2026-05-20.

This document freezes how `parallel-disk-usage` 0.23.0 fits into the Clean Disk
Rust architecture. It is the anti-corruption contract between pdu internals and
our reusable `fs_usage_*` crates.

Read this before implementing `fs_usage_core`, `fs_usage_engine`,
`fs_usage_pdu`, server protocol DTOs, or Flutter scan repositories.

## Accepted Decision

Use pdu as a private infrastructure adapter, not as domain language.

Top 3 options:

1. Engine contract first, pdu anti-corruption adapter second - 🎯 10 🛡️ 10 🧠 7,
   roughly 2500-6000 LOC across contracts, adapter, fixtures, and read model.
   This is accepted. Domain/application stay stable, pdu can be replaced by MFT,
   custom scanner, or future pdu fork without changing Flutter/protocol.
2. pdu-first internal model, then wrap it later - 🎯 5 🛡️ 6 🧠 5, roughly
   1200-3000 LOC first, but higher rewrite risk later.
   Fast to start, but pdu terms leak into queries, events, and delete safety.
3. Fork pdu now and make it our scanner engine - 🎯 4 🛡️ 6 🧠 9, roughly
   5000-12000 LOC and ongoing maintenance.
   Only justified after measured blockers such as cancellation, metadata reuse,
   or streaming nodes cannot be solved by an adapter/upstream PR.

Rule:

```text
pdu is evidence.
fs_usage_engine is product truth.
fs_usage_core is domain language.
clean_disk_protocol is transport language.
Flutter stores are view state only.
```

## Source-Level pdu Facts We Rely On

From pdu 0.23.0 source and docs:

- `FsTreeBuilder` is the real library filesystem entrypoint.
- `FsTreeBuilder` converts into `DataTree<OsStringDisplay, Size>` through
  `From`/`Into`, not through `Result`.
- filesystem errors are reported through `Reporter::report(Event::EncounterError)`
  while a tree can still be returned.
- `TreeBuilder` recurses through Rayon `into_par_iter`.
- `max_depth` limits stored children, but deeper descendants still roll their
  sizes into ancestors.
- `DataTree` stores only `name`, aggregate `size`, and `children`.
- `DataTree::dir` computes `size = inode_size + sum(children.size)`, so the
  node size is already aggregated and should not be re-summed blindly.
- `DataTree::children()` returns a concrete `&Vec<Self>`, which is a convenient
  traversal API, not a pagination/query abstraction.
- `Reflection` exists to inspect/serialize/deserialize `DataTree`, but it is an
  intermediate pdu representation. It is not our persistence or protocol model.
- `Reflection::par_try_into_tree` validates child size does not exceed parent
  size, which is useful for pdu JSON input, not for product scan trust.
- `Reflection` fields are public and serializable behind pdu's `json` feature,
  but a deserialized `Reflection` is not product-trusted state.
- `DataTree` has no stable id, full path per node, metadata, permissions,
  modified time, item count, issue list, or delete authority.
- pdu size is selected by one `GetSize`: apparent bytes, Unix block bytes, or
  Unix block count.
- `DeviceBoundary::Stay` is meaningful on Unix device ids. On unsupported
  platforms pdu's internal device id is `()`, which effectively weakens
  boundary detection.
- hardlink awareness is Unix-only in pdu.
- `HardlinkAware::record_hardlinks` can return conflicts, but
  `FsTreeBuilder` currently calls `.ok()` and ignores those recorder errors.
- pdu CLI applies extra behavior outside the library: HDD thread auto-limit,
  global Rayon pool config, overlapping root removal for hardlink dedupe,
  fake `(total)` root, culling, sorting, JSON conversion, and visualization.
- pdu JSON converts names to UTF-8 and is not path-fidelity-safe for product
  protocol.
- pdu CLI calls `par_convert_names_to_utf8().expect(...)` for JSON output, so
  non-UTF-8 names can become a CLI panic path. Our adapter must bypass pdu JSON
  for product scans.
- pdu JSON has its own `schema-version`, optional pdu binary version, `unit`,
  `tree`, and optional hardlink `shared` fields. This is pdu interchange format,
  not our protocol compatibility contract.
- pdu's default Cargo feature enables `cli`, which also enables `json`.
  Production adapter should use `default-features = false` and enable `json`
  only for fixtures or diagnostics.
- current audited pdu baseline is 0.23.0, Apache-2.0, Rust edition 2024, no
  declared `rust-version`, default feature `cli`, `cli` includes `json`, and
  production must build with `default-features = false`.
- pdu CLI `App`/`Sub` is host policy, not scanner SDK policy: it owns argv/stdin,
  terminal output, empty-target fallback to `"."`, fake multi-root naming,
  global Rayon configuration, progress reporter creation, sorting/culling,
  hardlink dedupe, JSON conversion, and visualizer output.
- pdu CLI target normalization is partial and mode-dependent. Overlapping roots
  are removed only for Unix hardlink dedupe with multiple targets. Clean Disk
  must normalize duplicate/overlapping targets independently before pdu.
- pdu CLI size defaults are platform-dependent: Unix defaults to block size,
  non-Unix defaults to apparent size. Clean Disk scan requests must carry an
  explicit `MeasurementProfile`.
- pdu hardlink projection mutates directory aggregate sizes by path-prefix
  matching. Clean Disk must preserve raw measured size, hardlink-adjusted
  projection, and reclaim-confidence evidence as separate facts.
- pdu hardlink summary can panic on impossible `nlink` evidence. The adapter
  boundary must contain panics and publish degraded/failed backend evidence.
- pdu tests confirm several product-relevant semantics: culling/retain keeps
  hidden child sizes rolled into parents, overlapping-target removal does not
  remove symlink arguments, hardlink identity is `(dev, ino)`, Linux HDD
  heuristics have LVM/device-mapper limits, and non-Unix device boundary support
  is weakened by `DeviceId(())`.

Implication:

```text
The pdu adapter can be fast and useful, but it cannot be our domain,
application read model, protocol schema, or cleanup authority.
```

## pdu Internal Flow Contract

The pdu library path we will use is small, but it has several non-obvious
semantics that must shape our adapter contract.

Actual pdu library flow:

```text
FsTreeBuilder
  -> pre-read root metadata when DeviceBoundary::Stay
  -> TreeBuilder
  -> get_info(path)
       -> symlink_metadata(path)
       -> size_getter.get_size(metadata)
       -> reporter.report(ReceiveData(size))
       -> hardlinks_recorder.record_hardlinks(...).ok()
       -> read_dir(path) only when metadata.is_dir() and same_device
       -> collect child names
  -> children.into_par_iter()
  -> DataTree::dir(name, inode_size, children)
```

Important consequences:

- pdu does not follow symlinks because it uses `symlink_metadata`.
- `DataTree::dir` stores aggregate size, not only own inode size.
- pdu `max_depth` is storage truncation: deeper sizes still roll into parent,
  but children disappear from the returned tree.
- child ordering is OS/filesystem/Rayon dependent and cannot be protocol order.
- pdu records a progress item after successful metadata read, not after full node
  conversion.
- pdu hardlink recorder errors are currently ignored by `FsTreeBuilder`.
- pdu cross-device skip produces an empty child list, not an explicit skipped
  node event.
- pdu library path has no cooperative cancellation hook.
- pdu library path has no stable node id, full path per child, metadata details,
  or persistent cursor model.

Adapter consequence:

```text
PduRawScanResult is adapter evidence.
ScanSnapshotDraft is application truth.
Protocol DTOs are transport truth.
Flutter models are view/application truth.
```

The adapter must therefore create missing product meaning explicitly:

| Missing from pdu | Owner that creates it | Why |
| --- | --- | --- |
| stable `NodeId` | `fs_usage_engine` | ids must survive backend replacement |
| full path/display path | engine plus platform path policy | pdu children are names only |
| item counts | `NodeArenaWriter` during conversion | DataTree does not count descendants |
| modified/permissions/type | `fs_usage_platform` | metadata enrichment is separate from scan aggregation |
| search/sort/filter pages | `ReadModelIndexes` | pdu sort/cull mutates tree and is CLI-oriented |
| scan quality | engine issue aggregation | pdu completion does not mean complete scan |
| cleanup authority | cleanup preflight | pdu paths and sizes are not delete proof |

### pdu SDK Source-Audit To Layer Contract Matrix

This is the implementation-facing map from real pdu SDK behavior to our Clean
Architecture layers. It exists to stop pdu convenience APIs from becoming our
domain language during the first implementation.

Top 3 ways to shape the contract:

1. Source-audited pdu adapter with explicit layer matrix - 🎯 10 🛡️ 10 🧠 6,
   roughly 900-2200 LOC across mappers, guards, and contract tests.
   Accepted. Each pdu SDK fact maps into exactly one adapter responsibility and
   one engine/domain concept.
2. Thin wrapper that returns "almost pdu" DTOs to the engine - 🎯 4 🛡️ 5 🧠 3,
   roughly 300-900 LOC.
   Rejected. It is faster at first, but leaks pdu's final-tree, callback, and
   CLI vocabulary into application and Flutter.
3. Fork pdu and reshape its public API as our engine contract - 🎯 5 🛡️ 6 🧠 9,
   roughly 5000-12000 LOC plus ongoing upstream sync.
   Rejected for MVP. Keep this only as a later escape hatch if adapter evidence
   proves cancellation, streaming, or memory limits cannot be solved cleanly.

Layer matrix:

| pdu SDK fact | Allowed owner | Product contract |
| --- | --- | --- |
| `FsTreeBuilder` builds `DataTree` through `From`/`Into` | `fs_usage_pdu::adapter` | `PduScanRunner` returns private `PduRawScanResult`, never public engine data |
| `TreeBuilder` callback is infallible and side-effect based | `fs_usage_pdu::adapter` | product errors/cancel/quality stay in `ScannerBackend` output and session state |
| `DataTree` has `name`, aggregate `size`, `Vec<children>` only | `fs_usage_pdu::mapper` | `PduTreeConverter` writes engine `NodeArenaRecord` with stable ids and evidence |
| `DataTree::children()` is a full `Vec` | `fs_usage_engine` indexes | pagination is query/index behavior, not pdu traversal behavior |
| `max_depth` hides stored descendants but keeps aggregate sizes | `fs_usage_engine` projection policy | hidden descendants become projection evidence and never cleanup targets |
| `Reporter::report` is synchronous and non-exhaustive | `fs_usage_pdu::reporter` | bounded evidence capture, throttled engine events, external sequencing |
| `EncounterError` carries borrowed path and OS error | `fs_usage_pdu::evidence` | owned/redacted `ScanIssue` evidence, not raw pdu operation names |
| `DetectHardlink` fires before `HardlinkList::add` | `fs_usage_pdu::hardlink` | observation evidence, not durable group count |
| `RecordHardlinks::Err` is discarded by `FsTreeBuilder` with `.ok()` | `fs_usage_pdu::hardlink` | conflict side-store captures size/link conflicts before pdu can hide them |
| `GetSize` returns apparent bytes, Unix block bytes, or Unix block count | `fs_usage_pdu::mapper` | mapped into `MeasurementProfile` and `SizeFacts` with confidence |
| `DeviceBoundary::Stay` depends on pdu device id support | `fs_usage_pdu` plus `fs_usage_platform` | boundary result is capability/evidence tagged, not universal volume truth |
| pdu JSON/Reflection is an interchange/diagnostic format | `fs_usage_pdu::diagnostics` only | no protocol, cache, export, or Flutter DTO may be pdu-shaped |
| pdu CLI modules add sorting, culling, fake roots, visualizer, status board | diagnostics/test only | product query, display, progress, and multi-root behavior are engine/UI contracts |

Domain layer impact:

```text
fs_usage_core owns:
  ScanTarget, NodeRef, SizeFacts, ScanIssue, ScanQuality,
  HardlinkEvidence, TraversalEvidence, BoundaryPolicy, SizePolicy.

fs_usage_core never owns:
  DataTree, FsTreeBuilder, TreeBuilder, Info, Reporter, Event,
  ErrorReport, HardlinkList, GetSize, Bytes, Blocks, Reflection.
```

Application layer impact:

```text
fs_usage_engine owns:
  ScannerBackend
  BackendScanRequest
  BackendScanOutput
  ScanSnapshotDraft
  NodeArenaWriter
  ReadModelIndexes
  ScanPhaseEvent
  ScannerBackendCapabilities

fs_usage_engine decides:
  scan quality
  partial target outcomes
  session state and epoch rejection
  query pagination
  sort/search/top-list semantics
  cleanup eligibility gating
```

Data/infrastructure layer impact:

```text
fs_usage_pdu owns:
  PduScannerBackend
  PduOptionsMapper
  PduExecutionLane
  PduScanRunner
  PduReporter
  CleanDiskHardlinkRecorder
  PduRawScanResult
  PduTreeConverter
  PduIssueMapper
  PduSizeFactsMapper
  PduBoundaryCapabilityMapper
```

SOLID rules for this boundary:

- SRP: pdu adapter changes when pdu changes; domain changes only when product
  filesystem language changes.
- OCP: new backends implement `ScannerBackend`; they do not require
  pdu-specific branches in domain/application.
- LSP: a backend may be less capable than pdu, but must satisfy capability
  reporting honestly.
- ISP: scanner, metadata, hardlink, accounting, query, cleanup, and transport
  interfaces stay separate.
- DIP: engine depends on ports and value objects; pdu depends inward on the
  engine port contract, never the reverse.

Implementation rule:

```text
Every pdu SDK type is either:
  private adapter dependency,
  diagnostics/test fixture type,
  or explicitly rejected by an import guard.

There is no fourth category.
```

### Generic TreeBuilder Boundary Contract

pdu also exposes `TreeBuilder`, which can look like a reusable scanner
abstraction. It is not our Clean Architecture scanner port.

Source-level facts from pdu 0.23.0:

- `TreeBuilder` builds a final `DataTree`, not a stream of product nodes;
- `get_info(&Path) -> Info<Name, Size>` is infallible at the type level. Errors
  must be encoded through side channels or sentinel `Info` values;
- `get_info` returns all child names as a `Vec<Name>` before parallel child work
  begins;
- `join_path(&Path, &Name) -> Path` is a path reconstruction callback, not a
  platform identity model;
- `get_info` and `join_path` must be `Copy + Send + Sync`, which strongly
  discourages rich stateful orchestration inside the callback;
- recursion uses `children.into_par_iter()` internally, so callback order is not
  product order;
- `max_depth` is applied after `get_info` and still builds child subtrees for
  aggregate size when stored children are dropped;
- there is no typed cancellation token, backpressure, per-node completion event,
  bounded memory signal, current-depth argument, or cleanup-safe metadata model.

Top 3 `TreeBuilder` integration strategies:

1. Keep `TreeBuilder` private behind `PduScannerBackend` only - 🎯 9 🛡️ 9
   🧠 5, roughly 300-900 LOC in guards/tests.
   Accepted. We use pdu's public filesystem path through `FsTreeBuilder` and
   treat `TreeBuilder` as pdu implementation detail.
2. Build our own filesystem scanner on top of pdu `TreeBuilder` - 🎯 4 🛡️ 5
   🧠 7, roughly 1800-4500 LOC.
   Rejected for MVP. It means we own traversal semantics anyway, but remain
   constrained by pdu's final-tree, infallible, no-stream callback model.
3. Upstream/fork a visitor/arena builder API - 🎯 6 🛡️ 8 🧠 9, roughly
   3000-8000 LOC.
   Future option only if measured memory/cancellation/metadata duplication shows
   the final-tree adapter is not good enough.

Layer rules:

- `ScannerBackend` is the application port. pdu `TreeBuilder` is never that
  port.
- domain must not mention `Info<Name, Size>`, `TreeBuilder`, `get_info`, or
  `join_path`;
- `fs_usage_pdu` may use `TreeBuilder` only as part of pdu internals or
  diagnostics, not as product extension API;
- if we need true streaming, true traversal cutoff, cooperative cancellation, or
  direct arena writes, introduce a new backend capability or upstream/fork pdu;
- tests must fail if `TreeBuilder` or `Info` appears outside the pdu adapter
  crate.

Accepted boundary:

```text
Application ScannerBackend trait
  -> PduScannerBackend adapter
  -> pdu FsTreeBuilder / internal TreeBuilder
  -> PduRawScanResult
  -> engine-owned BackendScanOutput
```

### Node Kind And Target Preflight Semantics

pdu `DataTree` is not a filesystem metadata model. It is a size tree.

Source-level facts:

- `TreeBuilder` receives `Info { size, children }`;
- `TreeBuilder` always constructs returned nodes with `DataTree::dir(name, size,
  children)` unless `FsTreeBuilder` exits early in the root
  `DeviceBoundary::Stay` error path;
- a real file, symlink, unreadable directory, empty directory, cross-device
  boundary, and max-depth-truncated directory can all appear as "node with no
  children";
- pdu only uses `stats.is_dir()` internally to decide whether to call `read_dir`;
- pdu does not store `is_file`, `is_dir`, `is_symlink`, file type, permissions,
  owner, modified time, or identity in `DataTree`;
- when root metadata fails, pdu can still return a zero-size tree plus reporter
  error unless platform preflight rejects the target first.

Product mapping:

```text
NodeKind comes from fs_usage_platform / metadata enrichment.
DataTree.children.is_empty() never proves file kind.
Root target validity comes from preflight, not pdu scan output.
```

Top 3 node-kind strategies:

1. Lazy platform metadata enrichment with node-kind state - 🎯 10 🛡️ 10 🧠 7,
   roughly 900-2400 LOC.
   Accepted. Initial conversion creates `NodeKindState::Unknown/NeedsEnrichment`;
   visible/details/delete flows enrich through `MetadataProvider`.
2. Infer file/folder from pdu children - 🎯 2 🛡️ 2 🧠 1, roughly 50-200 LOC.
   Rejected. Empty children can mean many different things and would break delete
   safety, details, and UI icons.
3. Restat every pdu node during conversion - 🎯 6 🛡️ 8 🧠 8, roughly
   1800-5000 LOC plus major IO cost.
   Too heavy for MVP by default. Keep as optional enrichment profile or details
   query path.

Rules:

- `PduTreeConverter` may write `NodeKindState::NeedsEnrichment`, not final kind;
- target preflight must classify missing, inaccessible, unsupported, file,
  directory, and symlink targets before pdu runs;
- symlink scan policy is explicit: pdu default is "measure link itself, do not
  follow target";
- details and cleanup flows must refresh metadata through platform adapters under
  the same scanner process identity;
- UI folder/file icons are display hints until metadata state is current.

### Link Object And Reparse Semantics

pdu gives us fast traversal evidence, not full link/reparse semantics.

Source-level facts:

- `FsTreeBuilder` calls Rust `symlink_metadata(path)`, which queries the link
  object itself instead of following the link target;
- pdu uses only `stats.is_dir()` to decide whether to call `read_dir`;
- pdu does not store `metadata.file_type()`, `is_symlink()`, target path,
  Windows reparse tag, cloud provider placeholder state, or mount/junction
  semantics in `DataTree`;
- `DataTree.children.is_empty()` cannot distinguish ordinary file, symlink,
  broken symlink, empty directory, unreadable directory, cross-device boundary,
  Windows junction/reparse point, cloud placeholder, or max-depth projection;
- pdu hardlink evidence is inode/link-count evidence on Unix, not symlink target
  evidence;
- Windows reparse points and cloud/provider objects require platform-specific
  classification outside pdu.

Product contract:

```text
pdu link behavior = traversal evidence.
platform link behavior = product metadata evidence.
delete/link authority = current platform revalidation.
```

Top 3 link/reparse strategies:

1. Platform-owned link/reparse classification plus pdu evidence - 🎯 10 🛡️ 10
   🧠 7, roughly 900-2400 LOC.
   Accepted. pdu stays fast and private. `fs_usage_platform` classifies links,
   reparse points, provider placeholders, mount points, and broken links through
   metadata/identity ports.
2. Infer link semantics from pdu `children` and size - 🎯 2 🛡️ 2 🧠 2,
   roughly 100-300 LOC.
   Rejected. It would be wrong for symlinks, empty folders, unreadable folders,
   boundary skips, cloud placeholders, and max-depth projections.
3. Follow symlink/reparse targets during the pdu scan - 🎯 4 🛡️ 4 🧠 8,
   roughly 2000-6000 LOC.
   Rejected for MVP. It changes traversal safety, can create loops, crosses
   authority boundaries, and needs a separate backend/fork with explicit cycle
   and permission policy.

Accepted domain vocabulary:

```text
LinkKind
  none
  symlink_file
  symlink_directory
  junction
  mount_point
  provider_placeholder
  other_reparse
  broken_link
  unknown

LinkTraversalPolicy
  measure_link_object
  follow_target_when_explicitly_allowed
  block_high_risk_links

LinkEvidence
  link_kind
  target_known
  target_display
  reparse_tag
  provider_hint
  confidence
  source = platform_metadata
```

Layer rules:

- `fs_usage_core` owns pure value objects such as `LinkKind`,
  `LinkTraversalPolicy`, and `LinkEvidence`;
- `fs_usage_platform` owns link/reparse/provider classification and current
  metadata evidence;
- `fs_usage_pdu` records only pdu traversal evidence and may mark
  `NodeKindState::NeedsEnrichment`;
- `fs_usage_engine` combines pdu scan evidence with platform link evidence when
  building details, warnings, and capability states;
- delete preflight blocks or requires explicit review when current identity says
  the item is a link, reparse point, mount point, provider placeholder, or a
  stale replacement;
- UI icons and warnings for links are provisional until platform metadata
  enrichment is current;
- follow-link behavior is unsupported by the pdu backend unless a separate
  backend, fork, or upstream hook implements explicit cycle, authority, and
  boundary policy.

### Metadata Reuse And `GetSize` Limits

pdu already calls `symlink_metadata`, but the public library path does not expose
that metadata as a reusable product artifact.

Source-level facts:

- `GetSize::get_size(&self, metadata: &Metadata)` receives only metadata, not
  path, target id, mount context, cloud provider state, or scan session state;
- `FsTreeBuilder` computes `is_dir`, `same_device`, and `size`, reports
  `ReceiveData(size)`, passes borrowed metadata to hardlink recording, then lets
  metadata drop;
- `DataTree` stores only name, aggregate size, and children;
- reporter hardlink events can borrow metadata, but reporter callbacks must not
  retain borrowed references.

Implications:

```text
pdu metadata is traversal-local.
Clean Disk metadata is product evidence.
These are not the same boundary.
```

Top 3 metadata strategies:

1. Lazy metadata/identity enrichment through platform ports - 🎯 10 🛡️ 10 🧠 7,
   roughly 1200-3000 LOC.
   Accepted. It avoids restating every node during the first scan and keeps
   details/delete authority current.
2. Restat every pdu node during tree conversion - 🎯 6 🛡️ 8 🧠 8, roughly
   2000-6000 LOC plus IO cost.
   Useful only behind a measured "full details index" profile. Not default MVP.
3. Fork/upstream pdu to emit metadata snapshots per node - 🎯 6 🛡️ 7 🧠 9,
   roughly 3000-9000 LOC including maintenance.
   Consider only if lazy enrichment/restat cost becomes a measured product
   blocker.

Rules:

- `GetSize` is a size measurement hook, not metadata enrichment;
- `MetadataProvider` and `IdentityProvider` own current metadata and identity;
- `AccountingProvider` owns allocated/exclusive/quota/reclaim facts beyond pdu's
  selected measurement;
- metadata enrichment must be budgeted and observable separately from pdu scan,
  tree conversion, and index build;
- delete preflight always revalidates current metadata/identity even if metadata
  was enriched earlier.

### `RecordHardlinks` Metadata Tap Contract

pdu has one useful internal hook that is not obvious from the name:
`RecordHardlinks::record_hardlinks` is called for every successful metadata read,
not only for hardlink candidates.

Source-level facts:

- `FsTreeBuilder` calls `hardlinks_recorder.record_hardlinks(...)` after
  `ReceiveData(size)` and before deciding whether to call `read_dir`;
- the hook receives borrowed `path`, borrowed `Metadata`, measured `size`, and
  the reporter;
- the hook is available through the public `RecordHardlinks` trait even when the
  built-in `HardlinkAware` implementation is Unix-only;
- pdu ignores the recorder result with `.ok()`, so recorder failure does not
  stop or degrade pdu by itself;
- the hook observes metadata for cross-device directories before pdu skips their
  children;
- the hook can copy owned scan-time evidence, but it still cannot change pdu
  traversal, emit children, provide cancellation, or make metadata current after
  the scan.

Product contract:

```text
RecordHardlinks hook = pdu-private metadata tap.
Metadata tap output = scan-time evidence.
Platform provider output = current product metadata.
```

Top 3 metadata-tap strategies:

1. Custom `PduMetadataTapRecorder` inside `fs_usage_pdu` - 🎯 8 🛡️ 8 🧠 7,
   roughly 800-2200 LOC.
   Accepted as an adapter optimization. It can capture bounded boundary,
   file-type, hardlink, and scan-time identity hints without restating every
   visible node immediately.
2. Ignore the hook and restat everything through platform providers - 🎯 6 🛡️ 8
   🧠 8, roughly 1800-5000 LOC plus IO cost.
   Reliable but potentially slower. Keep as fallback for details/delete and for
   platforms where the tap cannot provide enough evidence.
3. Treat tap metadata as final domain metadata - 🎯 3 🛡️ 4 🧠 4, roughly
   600-1600 LOC.
   Rejected. It is scan-time evidence, can be stale, can be truncated by budget,
   and its errors are ignored by pdu.

Layer rules:

- `PduMetadataTapRecorder` is private to `fs_usage_pdu`;
- the tap may copy only bounded, redaction-aware evidence needed for conversion,
  capability reporting, hardlink hints, and boundary diagnostics;
- the tap must not allocate unbounded per-path metadata for large scans unless
  an explicit resource profile enables it;
- if tap buffers fill, it records `metadata_tap_truncated` evidence. It must not
  rely on returning `Err`, because pdu ignores recorder errors;
- tap evidence can improve `NodeKindState`, `BoundaryEvidence`, and hardlink
  evidence confidence, but delete preflight still revalidates through
  `fs_usage_platform`;
- tap evidence is matched to engine nodes through native path evidence or a
  bounded path/identity index, not through pdu display strings;
- if the tap is disabled or truncated, product correctness remains intact and
  only confidence/detail freshness decreases.

Accepted adapter-only records:

```text
PduMetadataTapRecord
  native_path_evidence
  measured_size
  file_type_hint
  unix_dev_ino_hint
  nlink_hint
  same_device_hint
  boundary_hint
  evidence_confidence

PduMetadataTapSummary
  observed_count
  stored_count
  dropped_count
  boundary_candidate_count
  hardlink_candidate_count
  truncated
```

### Callback State And Extension Hook Boundary

pdu extension hooks are useful, but they are not product ports. They are
synchronous adapter callbacks executed inside pdu traversal workers.

Source-level facts:

- `TreeBuilder.get_info` and `TreeBuilder.join_path` must be `Copy + Send + Sync`,
  so rich mutable orchestration cannot be modeled there directly;
- `Reporter::report(&self, Event<Size>)` is synchronous and receives borrowed
  event payloads;
- `RecordHardlinks::record_hardlinks` is synchronous and receives borrowed path
  and metadata;
- `RecordHardlinks::record_hardlinks` can return `Err`, but `FsTreeBuilder`
  discards that result with `.ok()`;
- pdu has no product callback for "node finished", "directory skipped by
  boundary", "children materialized", "subtree ready", "budget exceeded", or
  "cancel now";
- pdu callbacks execute in the same parallel traversal path that should remain
  CPU and IO efficient.

Product implication:

```text
pdu callback hook
  -> copy tiny owned adapter evidence
  -> push to bounded adapter-side store
  -> return quickly

engine event/protocol/update
  -> produced later by fs_usage_engine
  -> sequenced, throttled, redacted, and typed by product contracts
```

Top 3 callback-state strategies:

1. Adapter-owned side stores plus bounded callback guards - 🎯 10 🛡️ 10 🧠 7,
   roughly 900-2400 LOC.
   Accepted. It preserves SOLID: pdu hooks have one reason to change, engine
   ports stay stable, and domain does not learn callback mechanics.
2. Put product event emission directly inside pdu callbacks - 🎯 3 🛡️ 3 🧠 4,
   roughly 300-900 LOC.
   Rejected. It couples traversal workers to protocol/UI timing, redaction,
   reconnect behavior, and DB/socket failures.
3. Ignore callbacks and only use final `DataTree` - 🎯 5 🛡️ 7 🧠 2, roughly
   100-300 LOC.
   Safe for a minimal benchmark, but too weak for scan quality, progress,
   skipped/error evidence, hardlink hints, and boundary diagnostics.

Accepted contract:

```text
PduCallbackEvidenceSink
  record_progress_counter(...)
  record_issue_sample(...)
  record_metadata_tap(...)
  record_hardlink_observation(...)
  record_overflow_or_truncation(...)

PduCallbackPolicy
  max_issue_samples
  max_metadata_tap_records
  max_hardlink_observations
  drop_policy = drop_low_value | mark_truncated | fail_backend
  callback_time_budget
```

Layer rules:

- `fs_usage_pdu` owns callback guards, side stores, overflow counters, and
  truncation evidence;
- `fs_usage_engine` consumes a completed `PduRawScanResult` plus callback
  evidence and then emits product `ScanEvent` batches;
- `fs_usage_core` owns only stable evidence vocabulary, confidence, and scan
  quality states;
- protocol DTOs expose product events and summaries, not pdu callback events;
- callbacks must not write Drift/SQLite, send WebSocket messages, call async
  runtimes, log raw paths, localize messages, or run platform delete/preflight
  logic;
- returning `Err` from a recorder is never a backpressure or cancellation
  mechanism because pdu ignores it;
- callback store overflow lowers confidence through explicit evidence instead
  of blocking traversal or silently dropping product-significant facts.

Contract tests:

- pdu callbacks can receive high-volume events without blocking scanner workers;
- callback evidence stores record dropped/truncated counts;
- pdu recorder `Err` does not become product cancellation or failure;
- raw borrowed paths and metadata cannot escape callback scope;
- product event sequence numbers are assigned after callback ingestion;
- no protocol, Flutter, database, localization, or platform-delete code is
  imported by callback modules.

### DataTree Mutation And Projection Helper Semantics

pdu `DataTree` is a compact tree container plus helper methods. Those helpers
are useful for pdu CLI presentation, but they are not our product read model.

Source-level facts:

- `DataTree::dir(name, inode_size, children)` stores aggregate size as
  `inode_size + sum(children.size())`;
- after a `DataTree` is constructed, pdu helper methods can remove or reorder
  children without recomputing the original aggregate size semantics;
- `par_retain` removes descendants by predicate and leaves ancestor aggregate
  sizes as they were;
- `par_cull_insignificant_data` is behind pdu's `cli` feature, computes a
  root-relative `f32` threshold, and uses `par_retain`;
- `par_sort_by` recursively sorts children and uses `sort_unstable_by`, so equal
  items require our own deterministic tie-breaker if order matters;
- Unix hardlink dedupe mutates `DataTree.size` by subtracting shared sizes from
  directories based on path prefix matching;
- hardlink dedupe relies on pdu's `OsStringDisplay`/path-prefix assumptions and
  is a projection, not exact reclaim truth;
- pdu `Size` values are `u64` newtypes with ordinary Rust arithmetic, not our
  checked product numeric model.

Product contract:

```text
Raw pdu DataTree -> PduTreeConverter -> NodeArenaRecord
pdu helper projection -> diagnostics only unless explicitly mapped
engine indexes -> product sort/filter/page/search truth
```

Top 3 projection strategies:

1. Convert raw pdu tree once, then build engine-owned indexes - 🎯 10 🛡️ 10
   🧠 7, roughly 1200-3000 LOC.
   Accepted. pdu stays a scanner adapter. Sorting, filtering, culling, paging,
   and top lists are product query semantics in `fs_usage_engine`.
2. Use pdu `par_sort_by`, `par_retain`, culling, and hardlink dedupe as product
   tree operations - 🎯 3 🛡️ 3 🧠 3, roughly 300-900 LOC.
   Rejected. It mutates evidence, loses child materialization meaning, creates
   unstable ordering risk, and can confuse cleanup authority.
3. Fork pdu to expose first-class immutable projections - 🎯 5 🛡️ 7 🧠 9,
   roughly 3000-9000 LOC.
   Possible later only if engine indexes cannot meet memory/performance goals.
   Not justified for MVP.

Layer rules:

- `fs_usage_pdu` production scan conversion should not call pdu `par_retain`,
  `par_cull_insignificant_data`, `par_sort_by`, or hardlink dedupe on the
  primary product tree;
- if a pdu helper is used in diagnostics/fixtures, the resulting tree is marked
  projected and has no cleanup/delete authority;
- `NodeArenaRecord.size_facts.aggregate_measured` comes from raw pdu aggregate
  evidence, not from a sorted/culled/deduped presentation tree;
- product `child_visible_sum`, `child_completeness`, and projection evidence are
  computed by the engine, not inferred from pdu helper mutations;
- hardlink-adjusted size is stored as a separate projection/evidence field, not
  by mutating the primary node aggregate;
- UI row order, top lists, and search results come from engine indexes with
  deterministic tie-breakers;
- numeric conversion from pdu `u64` size newtypes goes through domain checked or
  saturating helpers and records overflow/saturation evidence.

### DataTree Helper Guard Contract

pdu helper methods are public and tempting, but they are presentation/projection
helpers, not product query APIs.

Deeper source-level facts:

- `par_retain` calls `children.retain` on each node and then recurses into kept
  children;
- the retain predicate sees child nodes and a depth counter for the current
  parent level, not a stable product `NodeRef`;
- `par_retain` removes entire child subtrees but does not add projection
  evidence or child completeness markers;
- `into_par_retained` consumes and returns the same tree shape after mutation;
- `par_cull_insignificant_data` is behind pdu `cli`, uses a root-relative `f32`
  threshold, and delegates to `par_retain`;
- `par_sort_by` sorts recursively and uses `sort_unstable_by`, so equal elements
  can reorder without a stable tie-breaker;
- `Reflection::par_try_into_tree` only rejects an immediate child whose size is
  greater than its parent. It does not validate child sum, path identity, file
  metadata, issue evidence, reclaim truth, or cleanup authority;
- `Reflection::par_convert_names_to_utf8` is a diagnostic/JSON helper and fails
  on non-UTF-8 names by returning the offending name.

Accepted helper policy:

```text
Product read model = raw pdu tree converted once.
Product projections = engine indexes and query policies.
pdu helper projections = diagnostics only.
pdu Reflection validation = structural pdu sanity only.
```

Top 3 helper strategies:

1. Ban pdu helper mutations from production scan conversion - 🎯 10 🛡️ 10 🧠 4,
   roughly 200-600 LOC for guards/tests.
   Accepted. It keeps product query semantics in `fs_usage_engine`.
2. Allow pdu sort only for stable UI order - 🎯 4 🛡️ 4 🧠 2, roughly
   100-300 LOC.
   Rejected. `sort_unstable_by` has no product tie-breaker and pdu order should
   never become protocol/UI truth.
3. Use pdu retain/cull as backend pagination - 🎯 3 🛡️ 3 🧠 3, roughly
   200-700 LOC.
   Rejected. It destroys child materialization evidence and cannot support
   future lazy expansion without rescan confusion.

Layer rules:

- `PduTreeConverter` reads `DataTree` through getters and does not call pdu
  helper mutation APIs;
- diagnostics may call pdu helpers only when the resulting snapshot authority is
  read-only and marked `diagnostic_backend_projection`;
- engine query APIs must express sort/filter/page/top semantics through
  `ReadModelIndexes`, not through pdu helper output;
- any pdu helper output used for fixture comparison carries
  `TreeProjectionKind::diagnostic_backend_projection`;
- `par_try_into_tree` success does not raise `ScanQuality`, `SizeConfidence`, or
  cleanup eligibility;
- non-UTF-8 product path tests must bypass pdu JSON/UTF-8 conversion helpers.

### pdu Fraction And Min-Ratio Boundary

pdu's `Fraction` and `par_cull_insignificant_data` are CLI visualization
helpers, not product query/filter contracts.

Source-level facts:

- `Fraction` stores an `f32`;
- `Fraction::new(value)` rejects values `>= 1.0` and values `< 0.0`;
- `NaN` is not rejected by those two comparisons because both comparisons are
  false for `NaN`;
- `Fraction::from_str` parses a string into `f32` before applying
  `Fraction::new`;
- pdu CLI default `min_ratio` is `"0.01"`;
- `DataTree::par_cull_insignificant_data(min_ratio)` computes
  `minimal = root_size_as_f32 * min_ratio`;
- culling keeps descendants only when `descendant_size_as_f32 >= minimal`;
- if `min_ratio` is `NaN`, the comparison is false and descendants can be
  removed as presentation output;
- converting large `u64` sizes to `f32` is approximate, so threshold boundaries
  are not exact for large trees;
- culling mutates child vectors and keeps parent aggregate sizes from the
  original tree.

Top 3 min-ratio/filter strategies:

1. Reject pdu `Fraction`/`min_ratio` from product query contracts - 🎯 10
   🛡️ 10 🧠 4, roughly 200-700 LOC.
   Accepted. Product filters use typed exact query descriptors in
   `fs_usage_engine`; pdu min-ratio remains diagnostic/CLI-only.
2. Sanitize pdu `Fraction` and reuse it as UI threshold filter - 🎯 5 🛡️ 5
   🧠 4, roughly 300-900 LOC.
   Rejected for MVP. Even sanitized, it is `f32`, root-relative, destructive,
   and tied to pdu helper mutation semantics.
3. Allow pdu min-ratio only in diagnostic fixture generation - 🎯 8 🛡️ 8 🧠 3,
   roughly 150-500 LOC.
   Acceptable only behind reduced-authority diagnostics. The resulting snapshot
   is not a product read model and cannot create cleanup targets.

Accepted product query contract:

```text
ProductSizeFilter
  fact_kind = logical_bytes | allocated_bytes | display_primary | hardlink_adjusted
  comparison = ge | le | between
  exact_value = decimal_string | u128_internal
  fallback_policy
  confidence_policy

Never:
  pdu Fraction
  pdu min_ratio
  pdu par_cull_insignificant_data output
```

Layer rules:

- `fs_usage_core` owns exact filter descriptors and validation;
- `fs_usage_engine` executes search/sort/filter/top queries over indexes;
- `fs_usage_pdu` does not call `par_cull_insignificant_data` in production;
- diagnostics that use pdu culling must reject non-finite ratios before running
  and must mark output as reduced-authority projection;
- protocol and Flutter never receive pdu `Fraction`, `min_ratio`, or pdu
  helper-mutated row visibility as query truth.

Contract tests:

- NaN and non-finite product filter thresholds are rejected before query
  execution;
- product size filters use exact value semantics and explicit size fact kind;
- pdu `min_ratio` does not appear in protocol DTOs, Flutter stores, cache
  schemas, or domain value objects;
- pdu culling output never grants cleanup/delete authority;
- equal-boundary filter behavior is deterministic and tested without `f32`
  rounding as authority.

Accepted domain vocabulary:

```text
TreeProjectionKind
  raw_backend_tree
  engine_query_projection
  diagnostic_backend_projection

ChildMaterializationState
  complete
  depth_truncated
  boundary_skipped
  read_failed
  projected
  unknown

ProjectionEvidence
  projection_kind
  source
  affected_node_ref
  reason
  confidence
```

Top 3 adapter shapes:

1. Evidence adapter plus engine-owned read model - 🎯 10 🛡️ 10 🧠 7, roughly
   2500-6000 LOC.
   Accepted. This matches Clean Architecture and lets us replace pdu without
   changing protocol or Flutter.
2. Thin pdu wrapper that exposes `DataTree`-like DTOs - 🎯 4 🛡️ 5 🧠 3, roughly
   800-1800 LOC.
   Rejected. It is quick, but leaks pdu semantics into data, protocol, and UI.
3. Fork pdu and make its internals our engine model - 🎯 5 🛡️ 6 🧠 9, roughly
   5000-12000 LOC.
   Not accepted for MVP. Only revisit after measured blockers in memory,
   cancellation, or streaming.

### DataTree Read-Only View Boundary

The sharper boundary is: production code may treat pdu `DataTree` as a
read-only adapter input, not as a mutable tree API. This follows SRP and DIP:
pdu scans and aggregates; `fs_usage_engine` owns product ordering, projection,
pagination, search, completeness, and cleanup authority.

Source-level facts from pdu 0.23.0:

- `DataTree` fields are private, but public methods expose `name()`, `size()`,
  `children()`, and `name_mut()`;
- `children()` returns `&Vec<Self>`, which is a complete child collection, not a
  cursor, page, or lazy iterator contract;
- `name_mut()` gives mutable access to the stored name and must not participate
  in product identity or path evidence;
- `par_sort_by` recursively mutates descendant order and uses
  `sort_unstable_by`, so equal items do not have product-stable ordering;
- `par_retain` mutates `children` in place and recurses only into retained
  subtrees, but it does not create projection evidence or recompute product
  child-completeness facts;
- `par_cull_insignificant_data` is `cli`-feature behavior, uses root-relative
  `f32` thresholding, and is not a precision-safe query/filter policy;
- `fixed_size_dir_constructor` and `DataTree::dir` are useful for pdu and
  synthetic fixtures, but their aggregate-size construction is not domain
  behavior.

Accepted production contract:

```text
PduDataTreeReadOnlyView
  reads DataTree::name()
  reads DataTree::size()
  reads DataTree::children()
  never calls DataTree::name_mut()
  never calls DataTree::par_retain()
  never calls DataTree::into_par_retained()
  never calls DataTree::par_sort_by()
  never calls DataTree::into_par_sorted()
  never calls DataTree::par_cull_insignificant_data()
  never calls DataTree::fixed_size_dir_constructor()
```

Top 3 adapter conversion strategies:

1. Read pdu `DataTree` through an immutable view, convert into `NodeArena`, then
   drop the pdu tree - 🎯 10 🛡️ 10 🧠 5, roughly 500-1400 LOC.
   Accepted. This is the cleanest anti-corruption layer and keeps pdu
   replaceable.
2. Use pdu helper mutations for product sorting, filtering, and projections -
   🎯 3 🛡️ 3 🧠 2, roughly 200-600 LOC.
   Rejected. It makes pdu presentation helpers part of product truth.
3. Convert pdu into a mutable engine tree that mirrors `DataTree` shape - 🎯 5
   🛡️ 5 🧠 5, roughly 800-2200 LOC.
   Rejected for MVP. It preserves pdu's shape instead of the product query
   shape we need for stable ids, pagination, indexes, and safety evidence.

Layer rules:

- `fs_usage_pdu` owns `PduDataTreeReadOnlyView` and the only code path that
  touches pdu `DataTree`;
- `fs_usage_engine` owns `NodeArena`, `NodeRef`, child materialization,
  deterministic order, query indexes, search indexes, and page cursors;
- diagnostic or fixture code may use pdu helpers only behind explicit gates and
  must mark the output as `diagnostic_backend_projection`;
- no domain, application, protocol, cache, or Flutter view model may contain pdu
  helper vocabulary such as `name_mut`, `par_retain`, `par_sort_by`,
  `min_ratio`, or `fixed_size_dir_constructor`;
- pdu child order is treated as traversal evidence only. Product row order must
  be rebuilt by engine indexes with stable tie-breakers;
- full pdu child vectors must never become API pages. Pages are produced by
  engine query ports from indexed node ids.

Contract tests:

- production `PduTreeConverter` imports only the read-only pdu tree view;
- pdu helper mutation methods are forbidden in production conversion modules;
- pdu child order does not define product row order when sizes/names tie;
- diagnostic helper output carries reduced authority and projection evidence;
- no public product DTO, cache schema, or Flutter model exposes pdu `children()`
  as a cursor/page shape.

## Source Audit Addendum: Hidden Semantics To Encode

These are implementation-level pdu facts that are easy to miss during coding.
Each one must become an adapter test or an explicit capability field.

### Feature Flags And Dependency Shape

pdu 0.23.0 declares:

```text
default = ["cli"]
ai-instructions = ["clap/derive"]
cli = ["clap/derive", "clap_complete", "clap-utilities", "json"]
cli-completions = ["cli"]
json = ["serde/derive", "serde_json"]
man-page = ["cli"]
usage-md = ["cli"]
```

Implications:

- product dependency must use `default-features = false`;
- enabling `cli` also enables `json` and pulls CLI/presentation behavior into the
  dependency graph;
- enabling `ai-instructions` pulls `clap/derive` even without the full `cli`
  feature. It is auxiliary CLI/documentation tooling, not scanner behavior;
- enabling `cli-completions`, `man-page`, or `usage-md` enables `cli`, which
  also enables `json`;
- `json_data` and `visualizer` are public modules, but they are not product
  protocol or UI models;
- Cargo feature unification means one accidental pdu dependency with default
  features, `ai-instructions`, `cli-completions`, `man-page`, or `usage-md` can
  expand the feature surface for the whole final binary.

Required guard:

```text
cargo tree -e features must prove clean-disk-server enables no pdu auxiliary
features: cli, json, ai-instructions, cli-completions, man-page, usage-md.
Only fs_usage_pdu may depend on parallel-disk-usage.
```

Effective dependency graph facts from local pdu 0.23.0 audit:

- `default-features = false` removes `clap`, `clap_complete`,
  `clap-utilities`, `serde`, and `serde_json` from normal production edges, but
  still keeps pdu's non-optional library dependencies;
- the no-default normal graph still includes scanner-adjacent crates such as
  `rayon`, `dashmap`, `itertools`, and `pipe-trait`;
- the no-default normal graph also still includes presentation/support crates
  such as `rounded-div`, `terminal_size`, `text-block-macros`,
  `zero-copy-pads`, and `sysinfo` because they are normal non-optional
  dependencies of the crate;
- enabling pdu `json` adds `serde` and `serde_json`, and should remain
  diagnostic/test-only unless explicitly revisited;
- enabling pdu `cli` adds `clap`, `clap_complete`, `clap-utilities`, and also
  enables `json`, so it is forbidden in the daemon dependency graph.
- enabling pdu `ai-instructions` adds `clap/derive` and is also forbidden in
  the daemon dependency graph because it is not a scanner capability;
- enabling pdu `cli-completions`, `man-page`, or `usage-md` enables pdu `cli`,
  so those features are forbidden anywhere outside explicit diagnostic/tooling
  build targets.

Top 3 effective feature graph strategies:

1. Snapshot and gate pdu's effective normal dependency graph - 🎯 10 🛡️ 9 🧠 5,
   roughly 250-900 LOC/config once the Rust workspace exists.
   Accepted. We treat pdu's extra normal dependencies as adapter supply-chain
   cost and make drift visible in CI.
2. Trust `default-features = false` as enough - 🎯 5 🛡️ 5 🧠 1, roughly
   0-100 LOC.
   Rejected. It prevents CLI/JSON feature leakage, but it does not prove scanner
   import discipline or detect non-optional dependency drift.
3. Fork pdu now to trim non-scanner dependencies - 🎯 4 🛡️ 6 🧠 9, roughly
   4000-10000 LOC plus maintenance.
   Not justified for MVP. Revisit only if binary size, review policy, or security
   governance blocks the adapter dependency surface.

Accepted guard shape:

```text
PduEffectiveDependencyGraph
  pdu_version
  requested_features
  effective_features
  forbidden_auxiliary_features
  normal_dependencies
  forbidden_features_present
  forbidden_imports_present
  diagnostic_features_present
  graph_fingerprint
```

Layer rules:

- `fs_usage_pdu` owns this evidence because it owns the pdu dependency;
- `clean-disk-server` release checks fail if pdu `cli` is enabled or if pdu
  auxiliary features are enabled in production, or if pdu imports escape the
  adapter crate;
- `fs_usage_core` and `fs_usage_engine` do not mention pdu feature names,
  dependency names, or Cargo feature unification;
- dependency governance decides whether pdu's non-optional presentation/support
  crates are acceptable supply-chain cost;
- feature graph evidence belongs in diagnostics/build reports, not normal
  protocol or Flutter view state.

Acceptance:

```text
Forbidden pdu production features:
  cli
  json
  ai-instructions
  cli-completions
  man-page
  usage-md

Diagnostic-only pdu feature:
  json, only when a diagnostic fixture/export build explicitly opts in
```

### Toolchain And Build Surface Boundary

pdu is not only an API dependency. It also brings a build/toolchain contract that
must remain outside domain and application layers.

Source-level facts from pdu 0.23.0 package metadata and source:

- the crate is published with `edition = "2024"`;
- `cargo info parallel-disk-usage` reports no explicit `rust-version`;
- `src/lib.rs` has `#![deny(warnings)]`, so new compiler warnings in pdu code
  can become dependency build failures when the Rust toolchain changes;
- the crate license is `Apache-2.0`;
- the package has no `build.rs` build script in the published crate metadata;
- pdu exposes a library-level `main()` behind the `cli` feature. That function
  calls `app::App::from_env().run()`, prints `[error] ...` to stderr, and maps
  `RuntimeError` to process exit codes;
- the scanner path depends on ordinary Rust code plus Rayon and pdu's data
  structures, while terminal/presentation modules remain public in the library;
- `unsafe` appears in visualizer code, which is outside the accepted production
  import allowlist;
- helper/diagnostic paths contain panics or `expect` paths such as hardlink
  summary inconsistency and CLI JSON UTF-8 conversion.

Product consequence:

```text
Rust toolchain compatibility is release/build policy.
pdu scanner API is adapter policy.
Neither one belongs in fs_usage_core domain vocabulary.
```

Top 3 toolchain strategies:

1. Pin pdu and Rust toolchain, guard the effective feature/build surface - 🎯 10
   🛡️ 9 🧠 5, roughly 250-800 LOC/config once Rust workspace exists.
   Accepted. It keeps pdu usable while making toolchain and feature drift
   visible in CI.
2. Let pdu decide the workspace Rust toolchain implicitly - 🎯 4 🛡️ 4 🧠 1,
   roughly 0-100 LOC.
   Rejected. A dependency upgrade could silently raise compiler requirements or
   feature surface.
3. Fork pdu immediately to define our own MSRV/build surface - 🎯 5 🛡️ 7 🧠 9,
   roughly 4000-10000 LOC plus maintenance.
   Keep only as a fallback if product release policy cannot accept pdu's
   toolchain/dependency surface.

Layer rules:

- `fs_usage_core` has no dependency on pdu, Rayon, terminal crates, or toolchain
  assumptions from pdu;
- `fs_usage_engine` records backend compatibility and capability evidence, but
  does not expose pdu compiler/version facts as product domain terms;
- `fs_usage_pdu` records `pdu_version`, `pdu_feature_set`,
  `pdu_toolchain_evidence`, and `pdu_contract_fingerprint`;
- `clean-disk-server` release checks prove the selected Rust toolchain can build
  pdu and that pdu `cli` remains disabled;
- if pdu later declares or changes `rust-version`, the adapter upgrade checklist
  must treat it as a compatibility change;
- diagnostics may record pdu package metadata, but protocol/Flutter must not
  expose it as user-facing scan truth.

Required guards:

```text
PduToolchainCompatibilityGuard
  -> verifies workspace Rust toolchain supports pdu edition/features
  -> records pdu rust-version as unknown | declared(version)
  -> fails release gate on unexpected feature expansion

PduBuildSurfaceGuard
  -> verifies no build script appears unexpectedly
  -> verifies production imports stay inside scanner allowlist
  -> verifies visualizer/status/CLI modules stay out of production path
```

### Crate Root Warning-Deny And CLI Entrypoint Boundary

pdu looks like a normal library crate, but the crate root includes two
release-relevant details that must not leak into Clean Disk architecture.

Source-level facts from pdu 0.23.0:

- `src/lib.rs` sets `#![deny(warnings)]` for the whole crate;
- the pdu binary `cli/main.rs` is only a thin wrapper around
  `parallel_disk_usage::main()`;
- library `main()` exists only with pdu feature `cli`;
- library `main()` reads process arguments and environment through
  `App::from_env()`;
- library `main()` writes errors to stderr and returns an `ExitCode`;
- the actual scanner library entrypoints remain `FsTreeBuilder`,
  `TreeBuilder`, `DataTree`, `Reporter`, `GetSize`, and hardlink adapters.

Product consequence:

```text
pdu warning policy = release/build evidence.
pdu library main() = CLI host entrypoint.
Neither is a scanner backend port, daemon operation, or domain use case.
```

Top 3 crate-root policies:

1. Treat `deny(warnings)` and pdu `main()` as release-governance concerns -
   🎯 10 🛡️ 10 🧠 4, roughly 150-500 LOC/config once Rust workspace exists.
   Accepted. CI pins the Rust toolchain, proves pdu builds, and blocks pdu CLI
   entrypoints from production daemon code.
2. Call `parallel_disk_usage::main()` from `clean-disk-server` for quick reuse -
   🎯 2 🛡️ 2 🧠 1, roughly 50-150 LOC.
   Rejected. It reads argv/env, writes terminal errors, uses exit codes, and
   bypasses Clean Architecture ports/adapters.
3. Patch/fork pdu to remove `deny(warnings)` now - 🎯 4 🛡️ 6 🧠 7, roughly
   500-2000 LOC plus maintenance.
   Not MVP. Only revisit if toolchain release policy cannot tolerate pdu's
   warning-as-error stance.

Layer rules:

- domain and application crates never import pdu crate-root functions or build
  metadata;
- `clean-disk-server` never calls `parallel_disk_usage::main()`;
- `fs_usage_pdu` may reference pdu crate metadata only in build diagnostics and
  dependency evidence;
- release checks include pdu build with the pinned Rust toolchain and feature
  graph;
- pdu warning failures are handled as dependency compatibility failures, not as
  scan failures or user-facing daemon capability states;
- CLI stderr/exit-code behavior is not reused for HTTP/WebSocket errors,
  operation receipts, or Flutter error messages.

Required guards:

```text
PduCrateRootGuard
  -> rejects parallel_disk_usage::main imports in production code
  -> records pdu crate attributes relevant to release compatibility

PduWarningPolicyGuard
  -> builds pdu under pinned Rust toolchain and selected features
  -> fails release gate on new dependency warning failures
  -> keeps warning failure outside scan/domain error taxonomy
```

### Target-Specific API Surface Boundary

pdu's public-looking API is not identical on every target. Some items exist only
when Rust `cfg` enables them.

Source-level facts from pdu 0.23.0:

- pdu `hardlink::aware` and `HardlinkAware` are compiled only with
  `#[cfg(unix)]`;
- pdu `GetBlockSize` and `GetBlockCount` are compiled only with `#[cfg(unix)]`;
- pdu `DeviceNumber::get` and `InodeNumber::get` are compiled only with
  `#[cfg(unix)]`;
- pdu Linux virtual-HDD reclassification code exists only on Linux;
- pdu docs.rs shows platform build links, but documentation pages are not a
  product capability probe;
- docs.rs builds use their own hosted rustdoc environment and are useful source
  references, not release-target evidence for our signed binaries.

Top 3 target-surface strategies:

1. Build/test target-specific pdu capability probes - 🎯 10 🛡️ 10 🧠 6,
   roughly 400-1200 LOC/config once Rust workspace exists.
   Accepted. Each release target proves which pdu APIs compile and maps that to
   our backend capability DTO.
2. Trust docs.rs visible items as cross-platform truth - 🎯 3 🛡️ 3 🧠 1,
   roughly 0-100 LOC.
   Rejected. Docs can show items that are unavailable on a different target or
   hide behavior that matters only after target compilation.
3. Use only the smallest common pdu API across all targets - 🎯 7 🛡️ 8 🧠 3,
   roughly 200-600 LOC.
   Safe fallback, but it wastes useful Unix capabilities and makes Windows fast
   paths harder to add cleanly.

Accepted target capability evidence:

```text
PduTargetApiSurface
  target_triple
  pdu_version
  hardlink_aware_available
  unix_allocated_size_available
  block_count_available
  device_inode_identity_available
  linux_hdd_heuristic_available
  json_feature_enabled
  cli_feature_enabled
  evidence_source = build_cfg_probe | compile_test | fixture
```

Layer rules:

- `fs_usage_pdu` owns target-specific pdu API probes and maps them to product
  backend capabilities;
- `fs_usage_core` owns target-agnostic vocabulary such as `HardlinkCapability`,
  `MeasurementCapability`, and `StorageMediumHintConfidence`;
- `fs_usage_engine` consumes capability DTOs and never imports pdu `cfg` names;
- `clean-disk-server` release gates run target-specific compile checks for every
  supported artifact target;
- docs.rs pages and crate metadata are references only. They do not replace local
  target build evidence;
- Flutter and protocol receive capability values, never pdu target/cfg terms.

Required contract tests:

- macOS/Linux Unix targets can compile pdu Unix hardlink and block-size probes
  when the adapter enables those code paths;
- Windows targets compile the pdu adapter with hardlink-aware and Unix block-size
  paths disabled;
- docs.rs metadata changes do not change product capabilities without target
  compile evidence;
- each backend capability response records the target triple and pdu version
  through diagnostic evidence, not domain enum names.

### Non-Exhaustive pdu API Evolution Boundary

pdu explicitly marks several public API shapes as open for future extension.
This is useful upstream design, but dangerous if Clean Disk mirrors those types
as domain/application contracts.

Source-level facts from pdu 0.23.0:

- `reporter::Event<'_, Size>` is `#[non_exhaustive]`;
- `data_tree::reflection::ConversionError` is `#[non_exhaustive]`;
- `hardlink::hardlink_list::AddError` is `#[non_exhaustive]`;
- `hardlink::aware::ReportHardlinksError` is `#[non_exhaustive]`;
- `hardlink::hardlink_list::reflection::ConversionError` is
  `#[non_exhaustive]`;
- `hardlink::hardlink_list::summary::Summary` is a `#[non_exhaustive]` struct;
- CLI/runtime types such as `Args`, `RuntimeError`, `UnsupportedFeature`, and
  CLI parse errors also use non-exhaustive markers, but those stay outside
  production scanner imports entirely.

Product consequence:

```text
pdu API evolution = adapter concern.
Product protocol evolution = clean_disk_protocol concern.
Domain evolution = fs_usage_core concern.

These are separate axes.
```

Top 3 handling strategies:

1. Map pdu non-exhaustive types through explicit adapter fallbacks - 🎯 10 🛡️ 10
   🧠 5, roughly 300-900 LOC.
   Accepted. Every pdu event/error/reflection conversion maps to known product
   evidence or `BackendUnknown`/degraded evidence.
2. Mirror pdu variants one-to-one in domain/application enums - 🎯 3 🛡️ 4 🧠 2,
   roughly 100-400 LOC.
   Rejected. It makes upstream pdu evolution look like product domain evolution.
3. Freeze on pdu 0.23.0 forever and ignore non-exhaustive markers - 🎯 4 🛡️ 5
   🧠 1, roughly 0-100 LOC.
   Rejected. Pinning is necessary, but future upgrade review still needs a safe
   mapping strategy.

Layer rules:

- `fs_usage_core` does not contain pdu variant names such as `ReceiveData`,
  `EncounterError`, `DetectHardlink`, `SizeConflict`, or `ExcessiveChildren`;
- `fs_usage_engine` owns stable product enums with unknown/fallback variants:
  `BackendUnknownEvent`, `BackendUnknownIssue`, `BackendProjectionInvalid`, or
  equivalent;
- `fs_usage_pdu` matches every pdu non-exhaustive enum with a wildcard fallback;
- `fs_usage_pdu` maps pdu non-exhaustive structs through named known fields plus
  upgrade tests, not through product assumptions that "this is the whole shape";
- `clean_disk_protocol` and Flutter DTOs expose our stable reason codes, not pdu
  variant names;
- unknown pdu event/error/reflection failures lower confidence or mark a
  diagnostic issue. They do not panic, become cleanup authority, or silently
  disappear.

Required adapter guards:

```text
PduNonExhaustiveApiGuard
  -> compile/checks mapper match sites include fallback arms
  -> rejects public pdu variant names outside fs_usage_pdu
  -> records unknown pdu evidence as degraded adapter evidence

PduApiEvolutionMapper
  -> maps known pdu variants to stable product reasons
  -> maps unknown variants to BackendUnknown* reasons
  -> records pdu version and contract fingerprint
```

### Public API And Dependency Surface Semantics

pdu is a library crate, but its public API includes more than scanner primitives.
With `default-features = false`, `lib.rs` still exposes modules such as:

```text
bytes_format
data_tree
device
fs_tree_builder
get_size
hardlink
inode
json_data
os_string_display
reporter
size
status_board
tree_builder
visualizer
```

The dependency list also includes non-optional crates that are not part of the
scanner domain we want to expose, including formatting/terminal/presentation
helpers such as `rounded-div`, `terminal_size`, `text-block-macros`, and
`zero-copy-pads`, plus `sysinfo`.

This is acceptable for an adapter dependency, but it is not acceptable as our
public architecture surface.

Top 3 dependency-surface strategies:

1. Keep pdu isolated in `fs_usage_pdu` and audit feature/dependency graph - 🎯 10
   🛡️ 9 🧠 5, roughly 300-900 LOC for guards and docs.
   Accepted. We pay pdu's dependency surface inside one adapter crate while
   preventing it from shaping product/domain/protocol.
2. Re-export convenient pdu types from our engine - 🎯 3 🛡️ 3 🧠 2, roughly
   100-400 LOC.
   Rejected. It would leak scanner-vendor API and presentation helpers into our
   stable contracts.
3. Fork pdu immediately to trim public modules/dependencies - 🎯 4 🛡️ 6 🧠 9,
   roughly 4000-10000 LOC plus maintenance.
   Not justified unless build size, supply-chain policy, or security review proves
   this dependency surface unacceptable.

Rules:

- `fs_usage_pdu` may import pdu scanner-related modules only;
- product code must not import pdu `visualizer`, `bytes_format`, `status_board`,
  `json_data`, or CLI modules;
- pdu presentation dependencies are treated as adapter supply-chain cost, not as
  app design-system dependencies;
- if dependency governance rejects pdu's non-optional presentation surface, first
  try upstream issue/PR, then small fork, then replacement backend.

### pdu Import Allowlist Contract

Feature flags alone are not enough. pdu's `lib.rs` exposes several modules even
when production uses `default-features = false`.

Source-level facts:

- `app`, `args`, `man_page`, `runtime_error`, `usage_md`, `clap`,
  `clap_complete`, and `clap_utilities` are gated behind pdu `cli`;
- pdu `default = ["cli"]`, so any accidental default-feature dependency enables
  CLI modules and also `json`;
- pdu re-exports `serde` and `serde_json` only when `json` is enabled;
- `json_data` is public even without `json`, but serialization derives are gated;
- `visualizer`, `bytes_format`, and `status_board` are public library modules
  even without `cli`;
- `status_board` writes to stderr through `eprint!`/`eprintln!`;
- `visualizer` renders terminal charts through `Display`, not product UI models.

Accepted production import allowlist for `fs_usage_pdu`:

```text
parallel_disk_usage::data_tree
parallel_disk_usage::device
parallel_disk_usage::fs_tree_builder
parallel_disk_usage::get_size
parallel_disk_usage::hardlink
parallel_disk_usage::inode
parallel_disk_usage::os_string_display
parallel_disk_usage::reporter
parallel_disk_usage::size
```

Diagnostics/test-only import allowlist:

```text
parallel_disk_usage::json_data
parallel_disk_usage::data_tree::DataTreeReflection
parallel_disk_usage::hardlink::HardlinkListReflection
parallel_disk_usage::hardlink::LinkPathListReflection
parallel_disk_usage::hardlink::SharedLinkSummary
```

Forbidden production imports:

```text
parallel_disk_usage::app
parallel_disk_usage::args
parallel_disk_usage::runtime_error
parallel_disk_usage::man_page
parallel_disk_usage::usage_md
parallel_disk_usage::visualizer
parallel_disk_usage::bytes_format
parallel_disk_usage::status_board
parallel_disk_usage::json_data
parallel_disk_usage::serde
parallel_disk_usage::serde_json
```

Top 3 guard strategies:

1. `fs_usage_pdu` import allowlist plus `cargo tree -e features` gate - 🎯 10
   🛡️ 9 🧠 5, roughly 300-900 LOC.
   Accepted. This protects both Rust module imports and Cargo feature
   unification.
2. Rely on developer discipline and code review - 🎯 4 🛡️ 4 🧠 1, roughly
   0-100 LOC.
   Rejected. pdu's public module surface makes accidental imports too easy.
3. Fork pdu to hide presentation modules - 🎯 5 🛡️ 7 🧠 9, roughly
   3000-8000 LOC.
   Not justified unless feature/import guards fail supply-chain or build review.

Layer rules:

- `fs_usage_core` and `fs_usage_engine` must not import any pdu module;
- `fs_usage_pdu` production code imports only the production allowlist;
- diagnostics may import pdu JSON/Reflection types only behind explicit
  diagnostics/test features;
- `status_board` and `visualizer` never run in the daemon process path;
- `bytes_format` never becomes product size display policy;
- `json_data` never becomes Clean Disk protocol, cache, export, or Flutter DTO;
- CI must fail if clean-disk-server enables pdu `cli`.

### Terminal Status And Display Side Effect Boundary

pdu contains terminal-oriented helpers that are convenient for the CLI, but they
are the wrong abstraction for a daemon, Flutter protocol, support bundles, logs,
or product UI. This is a separate boundary from scan traversal: the scanner
adapter may use pdu's tree/reporting facts, but not pdu's terminal side effects.

Source-level facts from pdu 0.23.0:

- `status_board::GLOBAL_STATUS_BOARD` is a global static with mutable line-width
  state and writes directly to stderr through `eprint!`/`eprintln!`;
- `StatusBoard` stores only one process-global `line_width: AtomicUsize` and
  uses relaxed atomic loads/stores. It has no scan session id, client id, target
  id, ordering token, lock around stderr writes, or backpressure signal;
- `StatusBoard::temporary_message` clears the previous global line, computes
  display width through `zero_copy_pads::Width`, then writes the new message to
  stderr. It is terminal repaint state, not durable progress state;
- `ProgressReport::TEXT` creates a carriage-return progress string and passes it
  to `GLOBAL_STATUS_BOARD.temporary_message`;
- `ProgressReport::TEXT` builds a human text line from `items`, `total`,
  `linked`, `shared`, and `errors`. It does not carry snapshot id, event
  sequence, resource profile, scan quality, or finality;
- `ErrorReport::TEXT` formats `[error] {operation} {path:?}: {error}` and passes
  it to `GLOBAL_STATUS_BOARD.permanent_message`;
- `Visualizer` is a `Display` implementation for an ASCII chart over
  `DataTree`, using terminal column widths, bar alignment, direction, and
  pdu size formatting;
- pdu `app::Sub::run` clears the status line, may print progress teardown
  warnings with `eprintln!`, then prints either JSON or the terminal visualizer;
- pdu `ParsedValue::Big` stores a `f32` display coefficient and is intentionally
  rounded for terminal display;
- pdu visualizer rows calculate percent text and formatted size strings while
  rendering, so those strings are already presentation output, not scan facts.

Accepted product contract:

```text
pdu traversal facts -> adapter evidence.
pdu terminal output -> forbidden in production daemon path.
pdu StatusBoard -> process-global terminal repaint state only.
product progress -> typed ScanProgressSnapshot.
product display size -> SizeDisplayPolicy and localization boundary.
```

Top 3 terminal/display strategies:

1. Ban pdu terminal helpers in production and create product-owned progress,
   size, and issue projections - 🎯 10 🛡️ 10 🧠 5, roughly 400-1200 LOC.
   Accepted. This keeps SRP clean: pdu scans, our application owns UX,
   localization, redaction, telemetry, and protocol.
2. Reuse pdu `ProgressReport::TEXT`, `ErrorReport::TEXT`, `Visualizer`, and
   `BytesFormat` for quick daemon/UI output - 🎯 2 🛡️ 2 🧠 1, roughly
   50-200 LOC.
   Rejected. It leaks raw paths/errors, mixes terminal state with daemon state,
   loses exact size semantics, and breaks web/Flutter accessibility.
3. Allow pdu terminal helpers only in a diagnostic CLI command behind an
   explicit feature - 🎯 7 🛡️ 7 🧠 4, roughly 300-800 LOC.
   Future-only. Useful for internal debugging, but it must never become the
   normal scanner, protocol, export, telemetry, or support-bundle path.

Clean Architecture rules:

- `domain` never contains pdu terminal strings, pdu `BytesFormat`, pdu
  `ParsedValue`, pdu visualizer rows, or pdu status-board state;
- `application` ports expose `ScanProgressSnapshot`, `ScanIssueReason`,
  `SizeFacts`, `SizeDisplayPolicy`, and paginated projections, not terminal
  lines;
- `fs_usage_pdu` production code cannot call `ProgressReport::TEXT`,
  `ErrorReport::TEXT`, `GLOBAL_STATUS_BOARD`, or `Visualizer`;
- `StatusBoard` is never used as a scan-session event bus, progress sink,
  logger, metric emitter, support-bundle source, or multi-client notification
  primitive;
- `clean-disk-server` logs/metrics/traces do not call pdu terminal helpers and
  do not store raw path/error display strings from pdu;
- Flutter receives typed exact facts plus optional display projections and
  formats for locale/accessibility through product presentation code;
- diagnostics that render pdu terminal output must be feature-gated, redacted by
  default, and labeled as diagnostic output with no cleanup authority.

Data/infrastructure guard shape:

```text
PduTerminalDisplayGuard
  forbidden_modules = visualizer | bytes_format | status_board
  forbidden_functions = ProgressReport::TEXT | ErrorReport::TEXT
  allowed_scope = tests | fixture_diagnostics | internal_cli_diagnostics

PduStatusBoardIsolationGuard
  rejects GLOBAL_STATUS_BOARD in production code
  rejects StatusBoard as progress/event/log sink
  requires session-scoped product event stream instead

PduProgressMapper
  receives ProgressReport<Size>
  emits ScanProgressSnapshot
  never emits pdu text

PduIssueMapper
  receives ErrorReport<'_>
  copies owned evidence
  emits ScanIssueReason
  never emits TextReport or Operation::name()
```

Contract tests:

- production `fs_usage_pdu` does not import pdu `status_board`, `visualizer`, or
  `bytes_format`;
- production adapter code does not reference `ProgressReport::TEXT`,
  `ErrorReport::TEXT`, or `GLOBAL_STATUS_BOARD`;
- production code does not reference pdu `StatusBoard` as a session-scoped or
  daemon-wide synchronization primitive;
- protocol DTO fixtures contain exact size fields and optional product display
  fields, but no pdu formatted size strings;
- daemon log/support-bundle redaction tests prove raw pdu error display text is
  not exported by default;
- diagnostic feature tests can render pdu terminal output only in read-only,
  no-cleanup-authority mode.

### CLI Host Semantics Are Not Product Semantics

pdu has a real library API, but the CLI adds a large host layer around it. Clean
Disk must not accidentally copy this host behavior into domain, protocol, or UI
contracts.

Source-level CLI facts:

- no CLI file arguments recursively calls `Sub::run` with `files = ["."]`;
- multiple CLI roots are wrapped under a fake root named `""`, then renamed to
  `"(total)"` after hardlink dedupe;
- `Sub::run` applies `into_par_retained` to multi-root fake trees using
  `depth + 1 < max_depth`;
- pdu `par_retain` removes child nodes from `children`, but does not recompute
  parent aggregate size. Removed descendants remain represented in ancestor
  sizes;
- CLI default `max_depth` is `10`, and `Depth::Infinite` maps to `u64::MAX`;
- CLI default `min_ratio` is `0.01`, which culls small nodes for visualization;
- CLI sorts by descending size through pdu `par_sort_by` unless `--no-sort` is
  passed;
- CLI hardlink overlap removal runs only on Unix and only when hardlink
  deduplication is enabled;
- overlap removal canonicalizes only real directories, prefers keeping the
  containing tree, and keeps the first duplicate path;
- CLI default size quantity is Unix block size on Unix and apparent size on
  non-Unix;
- CLI progress uses `ProgressAndErrorReporter` with 100 ms text output;
- CLI thread policy can detect HDD and call Rayon `build_global`;
- CLI JSON output consumes `DataTree` into `Reflection` and requires UTF-8 names.

Top 3 policies:

1. Treat pdu CLI as reference behavior only, never as product contract - 🎯 10
   🛡️ 10 🧠 5, roughly 300-900 LOC for guards and tests.
   Accepted. We can learn from pdu CLI choices, but product state, protocol,
   and UI use engine-owned policies and explicit capabilities.
2. Wrap pdu CLI behavior in Rust and map its output - 🎯 3 🛡️ 3 🧠 3, roughly
   300-1000 LOC first.
   Rejected for production. It inherits presentation culling, fake roots,
   global thread policy, UTF-8 JSON limitations, and weak permission identity.
3. Reimplement pdu CLI host behavior inside `fs_usage_pdu` - 🎯 5 🛡️ 5 🧠 6,
   roughly 1000-3000 LOC.
   Rejected by default. If a CLI behavior is useful, promote it into an engine
   policy with tests rather than copying pdu host names.

Accepted contract:

```text
pdu library facts
  -> fs_usage_pdu adapter evidence

pdu CLI facts
  -> research input only
  -> optional fixture comparison
  -> never domain/protocol identity
```

Domain/application replacements:

| pdu CLI behavior | Clean Disk owner |
| --- | --- |
| default target `"."` | product default target policy |
| fake root `""` / `"(total)"` | engine `SyntheticRootKind` |
| `max_depth` display depth | `ProjectionDepthPolicy` plus traversal capability |
| `min_ratio` culling | query/display filter contract |
| `par_sort_by` descending size | engine `ReadModelIndexes` |
| overlap root removal | `ScanTargetSet.overlap_policy` |
| CLI default quantity | explicit `SizePolicy` per scan |
| progress text thread | throttled engine/server event batches |
| CLI JSON | diagnostics/fixtures only |
| HDD thread auto-limit | `ResourceProfile` and platform/storage hints |

Guardrails:

- `fs_usage_pdu` production modules must not import pdu `app`, `args`, or
  `runtime_error`;
- pdu CLI fake root names must never appear in protocol, persistence, or
  Flutter state;
- target overlap handling is recorded as product diagnostics, not silently
  dropped like CLI convenience behavior;
- CLI culling/sorting/min-ratio cannot affect durable node identity or cleanup
  authority;
- any tree produced after pdu retain/cull must be marked as projected/truncated
  evidence, not complete child truth;
- CLI default `"."` is not our default for app UX. App composition decides
  initial targets explicitly.

### CLI Args Anti-Corruption Boundary

pdu `Args` is a CLI composition object. It mixes target selection, measurement,
hardlink policy, boundary policy, rendering, JSON import/export, terminal layout,
progress, error output, sorting, culling, and thread policy in one struct. That
is fine for a CLI, but it is the wrong shape for Clean Disk domain and
application ports.

Source-level facts from pdu 0.23.0:

- `Args.files` is raw `Vec<PathBuf>`, not a validated target set with user
  intent, target identity, overlap diagnostics, or authority scope;
- `json_input`, `json_output`, `omit_json_shared_details`, and
  `omit_json_shared_summary` are CLI/diagnostic concerns, not scan policy;
- `bytes_format`, `top_down`, `align_right`, `total_width`, and `column_width`
  are terminal rendering concerns;
- `quantity`, `deduplicate_hardlinks`, `one_file_system`, `max_depth`,
  `min_ratio`, `no_sort`, `silent_errors`, `progress`, and `threads` mix real
  scan behavior with CLI presentation defaults;
- `Depth::from_str` accepts exact `"inf"` or a positive non-zero integer.
  `Depth::try_from(0)` fails because it uses `NonZeroU64`;
- `Depth::Infinite` maps to `u64::MAX` before pdu traversal;
- `Fraction` stores `f32`, accepts values `>= 0` and `< 1`, and pdu CLI default
  `min_ratio` is `"0.01"`;
- `Threads` accepts exact `"auto"`, exact `"max"`, or positive non-zero thread
  counts. These are CLI tokens, not product protocol vocabulary;
- `Args` derives Clap parser and setters, so importing it pulls CLI-oriented
  concepts into the adapter boundary.

Accepted contract:

```text
BackendScanRequest = product policies and validated targets.
pdu Args = forbidden production boundary type.
pdu raw CLI flags = mapper inputs only in diagnostics/tests.
```

Top 3 request-shape strategies:

1. Product-owned `BackendScanRequest` plus pdu option mapper - 🎯 10 🛡️ 10 🧠 5,
   roughly 500-1400 LOC.
   Accepted. Application ports stay stable while pdu remains replaceable.
2. Reuse pdu `Args` as `PduScannerBackend.scan(...)` request - 🎯 2 🛡️ 2 🧠 1,
   roughly 50-200 LOC.
   Rejected. It leaks CLI rendering, JSON, terminal width, pdu defaults, and raw
   thread tokens into domain/application code.
3. Mirror pdu `Args` into our own DTO one-to-one - 🎯 4 🛡️ 4 🧠 3, roughly
   300-900 LOC.
   Rejected as public API. Acceptable only as an internal diagnostic fixture
   parser if clearly labeled and no cleanup authority is attached.

Layer rules:

- `domain` does not contain pdu option names, pdu CLI default values, pdu raw
  thread strings, pdu display direction, or pdu JSON flags;
- `application` owns product policies: target set, traversal, projection,
  measurement, boundary, hardlink, event, resource, diagnostics, and privacy;
- `fs_usage_pdu` owns `PduOptionsMapper`, which translates product policies to
  concrete `FsTreeBuilder` fields and adapter helpers;
- protocol/Flutter expose product modes like `balanced`, `fast`, `stored_depth`,
  `apparent_bytes`, and `allocated_bytes`, not pdu tokens like `"inf"`,
  `"auto"`, `"max"`, `top_down`, `min_ratio`, or `bytes_format`;
- diagnostic CLI compatibility may parse pdu-like flags only behind explicit
  diagnostic/test features;
- adding another scanner backend must not require changing product request
  shape just because pdu has a different CLI flag.

Mapper shape:

```text
BackendScanRequest
  target_set
  traversal_policy
  projection_policy
  size_policy
  boundary_policy
  hardlink_policy
  resource_profile
  event_policy
  diagnostics_policy

PduOptionsMapper
  maps product policies to FsTreeBuilder fields
  maps resource profile to PduExecutionLane
  rejects unsupported combinations with capability evidence
  never exposes pdu Args
```

Contract tests:

- `BackendScanRequest` and protocol DTOs do not import or serialize pdu `Args`,
  `Depth`, `Fraction`, `Threads`, `Quantity`, or `BytesFormat`;
- pdu raw tokens `"inf"`, `"auto"`, and `"max"` never appear in product
  protocol fixtures;
- pdu `min_ratio` is not used as product filtering/search/query policy;
- diagnostic pdu-args parsing creates read-only diagnostic runs only;
- replacing pdu backend with a non-pdu backend does not change application port
  request fields.

### CLI RuntimeError And JSON Host Boundary

pdu `RuntimeError` is a CLI host error model, not a scanner backend failure
model.

Source-level facts from pdu 0.23.0:

- `RuntimeError` variants are CLI concerns: JSON serialization failure, JSON
  deserialization failure, JSON input argument conflict, invalid input
  reflection, and unsupported CLI feature;
- `RuntimeError::code()` maps those variants to process exit codes `2..6`;
- `UnsupportedFeature` is conditionally compiled for non-Unix CLI flags such as
  hardlink dedupe and one-file-system;
- pdu `App::run` uses `--json-input` as stdin visualization input. It rejects
  simultaneous path arguments and does not scan the filesystem in that mode;
- pdu JSON input deserializes `JsonData`, ignores `binary_version` after serde,
  validates only pdu `schema-version`, converts reflection back into `DataTree`,
  and renders a terminal visualizer string;
- pdu JSON output serializes the post-CLI tree after cull/sort/dedupe/fake-root
  behavior and can panic on non-UTF-8 names through `expect`;
- pdu JSON output builds optional hardlink `shared` data before writing to
  stdout. If hardlink report conversion fails, pdu substitutes empty shared
  data and keeps the conversion error in a side result;
- pdu then returns `serde_json::to_writer(stdout(), &json_data)
  .map_err(RuntimeError::SerializationFailure).or(deduplication_result)`, which
  is CLI stdout/error precedence, not a scanner session outcome model;
- pdu `SchemaVersion` is the string `"2026-04-02"`, while `BinaryVersion` is the
  pdu crate version string;
- neither pdu schema version nor pdu binary version describes Clean Disk
  protocol compatibility, scan quality, delete authority, daemon capability, or
  platform permissions.

### pdu JSON Output Error Precedence Boundary

pdu JSON output is not just a data format. It is embedded in CLI control flow:
scan, optional progress reporter teardown, cull, sort, hardlink dedupe, fake
root rename, UTF-8 reflection conversion, shared-hardlink report conversion,
then stdout serialization.

Source-level facts from pdu 0.23.0:

- JSON output is created after pdu has already applied CLI culling, sorting,
  hardlink dedupe mutation, and multi-root fake-root rename;
- `JsonOutputParam` decides whether shared hardlink details and/or summary are
  included. If both are omitted, pdu never converts the dedupe record into JSON
  shared data;
- if shared hardlink report conversion fails, pdu emits empty `JsonShared` and
  stores the error as `deduplication_result`;
- pdu writes JSON to `stdout` through `serde_json::to_writer`;
- pdu chains the stdout serialization result with
  `.or(deduplication_result)`, so this is not a multi-error report and not a
  product-grade operation receipt;
- the CLI behavior is reasonable for terminal output, but it cannot represent
  per-target scan status, partial export status, recoverable hardlink evidence
  loss, stdout failure, protocol delivery failure, or cache write failure.

Top 3 product policies:

1. Treat pdu JSON output as diagnostic fixture/export only - 🎯 10 🛡️ 10 🧠 4,
   roughly 250-800 LOC for guards, mapper, and tests.
   Accepted. Product scan/export outcomes use our own typed receipt and issue
   model. pdu JSON error precedence is recorded only as pdu provenance when we
   run diagnostic comparisons.
2. Reuse pdu JSON output code for daemon export endpoints - 🎯 3 🛡️ 4 🧠 3,
   roughly 200-600 LOC initially.
   Rejected. It inherits stdout-oriented error composition, UTF-8-only names,
   tree-shaped payloads, and CLI-mutated data.
3. Copy pdu JSON output shape but rewrite error handling - 🎯 5 🛡️ 5 🧠 5,
   roughly 800-1800 LOC.
   Rejected for MVP. If we need a JSON export, define a Clean Disk export
   profile over our read model and receipts instead of pdu-shaped data.

Accepted contract:

```text
PduJsonDiagnosticExport
  source = pdu_json_output | pdu_json_import | fixture
  stdout_write = diagnostic_only
  hardlink_shared_conversion = optional_evidence
  authority = read_only
  cleanup_allowed = false

CleanDiskExportReceipt
  export_id
  snapshot_id
  schema_version
  status = complete | partial | failed
  issues[]
  written_bytes
  redaction_profile
```

Layer rules:

- `fs_usage_pdu::diagnostics` may call pdu JSON helpers only behind explicit
  diagnostic/test gates;
- product export endpoints must not call pdu `Sub::run`, pdu JSON stdout code,
  or pdu `RuntimeError`;
- pdu JSON serialization failures map to `DiagnosticExportFailure`, not
  daemon `ScanFailure`, protocol errors, or cleanup receipts;
- hardlink shared JSON conversion failures lower diagnostic evidence quality but
  do not erase live scan hardlink evidence captured by our adapter side store;
- Clean Disk export and daemon delivery use our own operation receipt, with
  separate issue entries for scan conversion, hardlink evidence, serialization,
  transport, cache, and user-visible export status.

Contract tests:

- production export/server code imports no pdu `json_data`, `RuntimeError`,
  `App`, or `Sub`;
- pdu diagnostic export is read-only and cannot create cleanup candidates;
- a simulated pdu shared-hardlink JSON conversion failure records diagnostic
  evidence loss without changing live scan authority;
- a simulated serialization/export failure is represented as a Clean Disk export
  issue, not as pdu `RuntimeError::SerializationFailure`;
- daemon protocol tests fail if pdu `JsonData` becomes the transport payload.

Accepted contract:

```text
PduCliHostEvidence
  pdu_schema_version
  pdu_binary_version
  source = fixture | diagnostic_import | cli_comparison
  authority = diagnostic_read_only
  cleanup_capability = none
```

Top 3 runtime/JSON boundary strategies:

1. Keep pdu CLI/runtime/json host types diagnostics-only - 🎯 10 🛡️ 10 🧠 4,
   roughly 300-900 LOC in guards/tests.
   Accepted. Production scanner uses library adapter evidence and our own
   `ScanFailure`, `BackendCapability`, and protocol compatibility models.
2. Map pdu `RuntimeError` directly into daemon API errors - 🎯 3 🛡️ 4 🧠 2,
   roughly 100-300 LOC.
   Rejected. It leaks CLI exit-code semantics and JSON visualization errors into
   application/domain contracts.
3. Support pdu JSON as user-facing import/export format - 🎯 4 🛡️ 5 🧠 6,
   roughly 1200-3000 LOC.
   Future diagnostic option only. It is UTF-8-only, lacks scan issues and
   authority evidence, and must remain reduced-authority.

Layer rules:

- `fs_usage_pdu/adapter` must not import pdu `RuntimeError`, `App`, `Args`, or
  CLI `Sub`;
- `fs_usage_pdu/diagnostics` may import pdu `json_data` and `RuntimeError` only
  behind explicit diagnostic/test features;
- application errors use our `ScanFailure`, `CapabilityFailure`, and
  `ProtocolCompatibilityState`, not pdu exit codes;
- pdu JSON import, if enabled, creates `DiagnosticSnapshotAuthority::ReadOnly`;
- pdu JSON import cannot create delete candidates, cleanup queue items,
  recommendation authority, scan history authority, or cache truth;
- pdu `SchemaVersion` and `BinaryVersion` are provenance fields only;
- daemon-to-Flutter protocol must never be pdu JSON, even if the shape looks
  convenient for fixtures.

Data/infrastructure mapping:

```text
PduDiagnosticJsonCodec
  -> reads/writes pdu JsonData for fixtures only
  -> records SchemaVersion and BinaryVersion as provenance
  -> maps tree into DiagnosticSnapshotAuthority::ReadOnly
  -> blocks cleanup/recommendation authority

PduRuntimeErrorGuard
  -> prevents pdu RuntimeError from adapter public API
  -> maps diagnostic failures into DiagnosticImportFailure only
```

Contract tests:

- production `fs_usage_pdu` imports fail if `runtime_error`, `app`, `args`, or
  CLI `Sub` appears outside diagnostics;
- pdu JSON input fixture creates read-only diagnostic snapshot;
- pdu `RuntimeError::code()` is not used by daemon HTTP, WebSocket, protocol,
  or Flutter error models;
- pdu `SchemaVersion`/`BinaryVersion` do not become Clean Disk protocol version;
- pdu JSON import cannot create cleanup authority.

### Reporter And Progress Semantics

pdu reporter events are low-level traversal events:

- `ReceiveData(size)` means one successful metadata read, not a finished node;
- `Event` is `#[non_exhaustive]`, so unknown future events must map to degraded
  evidence rather than panic;
- `Reporter::report` is synchronous and can run on pdu traversal worker threads;
- `EncounterError` carries borrowed path evidence and `std::io::Error`;
- `ErrorReport.operation` is pdu's low-level operation enum:
  `SymlinkMetadata`, `ReadDirectory`, or `AccessEntry`;
- `AccessEntry` errors point at the parent directory, not a child path;
- `DetectHardlink` carries borrowed path and borrowed `Metadata`; the callback
  must copy the evidence it needs immediately;
- built-in `ProgressReport` counts `items`, `total`, `errors`, `linked`, and
  `shared` with relaxed atomics;
- built-in hardlink progress increments `linked` by `nlink`, not by one unique
  inode;
- built-in progress reporter owns a reporting thread and text-oriented output;
- built-in `ProgressAndErrorReporter` calls the error callback before bumping
  the error counter;
- built-in progress snapshots load each counter independently, so the snapshot
  is useful telemetry but not a transactional scan state;
- built-in progress stop can end the thread without emitting a final product
  progress event;
- CLI `Sub::run` treats progress reporter destroy failure as a warning, not a
  domain failure;
- pdu callback order follows parallel traversal, not path order, size order, or
  deterministic protocol order.

Product mapping:

```text
PduReporter
  -> capture minimal owned evidence
  -> publish throttled snapshots outside pdu callbacks
  -> never emit one WebSocket event per pdu report
```

`ProgressReport` is not a UI progress contract. It is backend evidence for
estimated scan progress, diagnostics, and throughput metrics.

Reporter adapter rules:

- callback work must be bounded and non-blocking;
- no WebSocket, database write, log formatting, expensive path normalization, or
  UI throttling may happen inside `Reporter::report`;
- borrowed pdu references are converted into owned adapter evidence immediately;
- pdu operation names map into our `ScanIssueReason` taxonomy in
  `PduIssueMapper`;
- unknown pdu event or future error shape maps to `ScanIssueReason::BackendOther`
  or equivalent degraded evidence;
- progress snapshots are best-effort. They never grant scan completeness or
  cleanup authority.
- product code must prefer a custom `PduReporter` over pdu's built-in
  `ProgressAndErrorReporter`;
- engine event sequence numbers are assigned outside pdu callbacks;
- dropped reporter evidence creates explicit degraded evidence such as
  `ReporterEvidenceTruncated`;
- final scan state comes from `BackendScanOutput` plus collected issues, not the
  last progress snapshot.
- the detailed reporter design is frozen in the later
  "Reporter Callback Contract" section.

### Progress Finalization Boundary

pdu progress counters are live traversal telemetry. They are not a complete scan
phase model and not the final source of summary numbers.

Source-level facts from pdu 0.23.0:

- `ProgressReport` fields are `items`, `total`, `errors`, `linked`, and
  `shared`;
- `ReceiveData(size)` increments `items` and `total` after a successful
  `symlink_metadata` and size measurement;
- `ReceiveData(size)` is emitted before hardlink recording and before directory
  children are read;
- `EncounterError(error)` calls the error callback before incrementing the
  built-in `errors` counter;
- `DetectHardlink(info)` increments `linked` by `info.links`, not by one
  hardlink group, and increments `shared` by the observed file size;
- built-in progress state uses independent relaxed atomics, so one progress
  snapshot is not a transactional state;
- built-in progress reporting stops by setting `stopped`; it can stop without a
  final product progress snapshot;
- pdu progress does not cover target preflight, pdu tree conversion, index
  building, scan-quality aggregation, persistence, protocol readiness, or
  cleanup preflight.

Accepted product interpretation:

```text
pdu progress items = successful metadata measurements observed so far.
pdu progress total = approximate measured-size counter observed so far.
pdu linked/shared = hardlink telemetry, not group count or reclaim estimate.
last pdu progress snapshot != final scan summary.
```

Top 3 progress strategies:

1. Engine-owned `ScanPhaseProgress` with pdu counters as one evidence source -
   🎯 10 🛡️ 10 🧠 6, roughly 600-1600 LOC.
   Accepted. UI gets stable scan phases, approximate traversal counters, and
   final summary from authoritative read-model output.
2. Use pdu `ProgressReport` directly as protocol progress DTO - 🎯 4 🛡️ 4
   🧠 2, roughly 100-300 LOC.
   Rejected. It leaks pdu vocabulary and makes final totals, hardlink counts,
   and phase readiness ambiguous.
3. Hide live pdu progress until scan completes - 🎯 6 🛡️ 8 🧠 1, roughly
   50-150 LOC.
   Safe but poor UX. Acceptable only as a temporary fallback if reporter
   evidence is disabled or truncated.

Accepted contract:

```text
ScanPhaseProgress
  phase = target_preflight | pdu_traversal | converting_tree | building_indexes |
          aggregating_quality | ready | failed | cancelled
  approximate = true | false
  pdu_items_seen
  pdu_total_measured
  pdu_error_count
  pdu_hardlink_event_evidence
  finalized_summary_available

FinalScanSummary
  source = BackendScanOutput + NodeArena + ReadModelIndexes + ScanIssueStore
  not last ProgressReport
```

Layer rules:

- `fs_usage_pdu` maps pdu progress counters into `PduProgressEvidence`;
- `fs_usage_engine` owns phase transitions, finalization, throttling, and
  snapshot readiness;
- `fs_usage_core` owns phase/progress/confidence vocabulary;
- `clean_disk_protocol` exposes product progress DTOs, not pdu `ProgressReport`;
- Flutter renders pdu-derived progress as approximate until final summary is
  published;
- final dashboard totals, cleanup candidates, top lists, and item counts come
  from the completed read model, not from the last progress event.

Contract tests:

- last pdu progress snapshot is not used to build `ScanSummary`;
- hardlink `linked` progress is not interpreted as unique group count;
- a scan can finish pdu traversal but remain not-ready during conversion/index
  phases;
- progress stream can miss final pdu tick without losing final summary;
- pdu `EncounterError` callback-before-counter ordering does not hide scan
  issues;
- progress evidence truncation lowers confidence but does not fail the scan by
  itself.

### Built-In Progress Reporter Lifecycle Boundary

pdu's built-in `ProgressAndErrorReporter` is a CLI convenience. It is not a safe
product lifecycle primitive for the daemon.

Source-level facts from pdu 0.23.0:

- `ProgressAndErrorReporter::new` spawns an OS thread that sleeps for the
  configured interval and calls the supplied progress callback;
- the spawned thread owns a cloned `Arc<ProgressReportState>`;
- `stop_progress_reporter()` only sets `progress.stopped = true`;
- `ParallelReporter::destroy(self)` calls `stop_progress_reporter()` and then
  `join()`s the thread;
- source comments say stop would be automatically invoked when dropped, but a
  source audit of 0.23.0 shows no `Drop` implementation for
  `ProgressAndErrorReporter`;
- dropping a `JoinHandle` does not join the thread, so production code must not
  rely on implicit cleanup of the built-in reporter;
- `destroy()` can return a boxed panic payload from the progress thread.

Top 3 lifecycle strategies:

1. Do not use pdu `ProgressAndErrorReporter` in production - 🎯 10 🛡️ 10 🧠 5,
   roughly 300-900 LOC.
   Accepted. Implement our own bounded `PduReporter` with engine-owned lifecycle,
   no extra reporter thread, and explicit session shutdown.
2. Use pdu `ProgressAndErrorReporter` only in diagnostics with mandatory
   `destroy()` guard - 🎯 7 🛡️ 7 🧠 4, roughly 300-800 LOC.
   Acceptable for fixture parity or CLI comparison, but only behind diagnostic
   gates and with panic/timeout containment.
3. Use pdu `ProgressAndErrorReporter` directly in daemon sessions - 🎯 2 🛡️ 2
   🧠 2, roughly 100-300 LOC.
   Rejected. It risks detached progress threads, callback lifecycle ambiguity,
   and daemon shutdown coupling to a CLI helper.

Accepted contract:

```text
Production scan:
  PduReporter
    no owned progress thread
    bounded counters/evidence only
    lifecycle owned by ScanSession

Diagnostic pdu reporter:
  ProgressAndErrorReporter allowed only behind diagnostics
  destroy() required
  join/panic result mapped to DiagnosticFailure
  never used as product progress source
```

Layer rules:

- `fs_usage_pdu::reporter` owns production reporter lifecycle;
- `fs_usage_engine` owns scan-session state transitions and shutdown;
- `clean_disk_server` shutdown cancels sessions and waits on supervised
  execution lanes, not pdu reporter threads;
- `ProgressAndErrorReporter` imports are forbidden in production adapter paths;
- if diagnostics use it, they must call `destroy()` and map panic payloads to
  diagnostic failure, not product scan failure;
- no product code relies on pdu comments about automatic reporter cleanup.

Contract tests:

- production imports do not reference `ProgressAndErrorReporter`;
- diagnostic usage proves `destroy()` is called on success and failure paths;
- progress-thread panic maps to diagnostic failure;
- session cancellation does not leave a pdu built-in progress reporter running;
- custom `PduReporter` has no detached OS thread and no socket/database/log
  side effects.

### Product Scan Phase Contract

pdu CLI has one convenient `Sub::run` pipeline, but product state must be more
explicit.

Source-level facts:

- pdu CLI builds one `FsTreeBuilder` per root;
- when there are no CLI roots, pdu recurses into a new `Sub` with `"."`;
- multi-root CLI output creates a fake root with empty name, then later renames
  it to `(total)`;
- pdu CLI destroys the progress reporter after raw tree construction and before
  culling, sorting, hardlink deduplication, JSON conversion, or terminal
  visualization;
- pdu CLI culling, sort, hardlink deduplication, JSON, and visualization are
  post-walk presentation/diagnostic steps;
- pdu built-in progress covers traversal evidence, not our conversion, index
  build, scan-quality aggregation, persistence, or protocol readiness.

Product phase model:

```text
ScanPhase
  target_preflight
  resource_planning
  backend_walk
  backend_result_received
  converting_tree
  building_indexes
  aggregating_quality
  snapshot_ready
  failed
  cancelled
```

Accepted phase strategy:

1. Engine-owned phase model with pdu walk as one backend phase - 🎯 10 🛡️ 10
   🧠 6, roughly 500-1400 LOC.
   Accepted. UI can show honest progress while Rust converts the pdu tree,
   builds indexes, and finalizes scan quality.
2. Treat pdu walk completion as product scan completion - 🎯 3 🛡️ 4 🧠 2,
   roughly 100-300 LOC.
   Rejected. It hides conversion/index latency and causes stale or missing query
   data after a scan appears done.
3. Reuse pdu CLI `Sub::run` status behavior - 🎯 2 🛡️ 3 🧠 2, roughly
   200-500 LOC.
   Rejected. It couples product state to CLI presentation and reporter teardown.

Layer rules:

- `fs_usage_engine` owns `ScanPhase`, not `fs_usage_pdu`;
- `fs_usage_pdu` reports `backend_walk` evidence and raw timings only;
- `PduTreeConverter` and index builders publish phase events through engine
  orchestration, not through pdu `Reporter`;
- Flutter progress UI must distinguish "scanning files" from "preparing
  results";
- WebSocket events expose product phases, not pdu callback names;
- `snapshot_ready` means paginated query APIs are ready, not merely that pdu
  returned a `DataTree`;
- cleanup/recommendation actions remain disabled until snapshot readiness and
  capability/quality checks pass.

### Execution, Cancellation, And Panic Boundary

pdu is a synchronous Rust library that uses Rayon internally. It is not an async
daemon runtime and it does not provide cooperative cancellation.

Source-level facts:

- pdu library recursion uses Rayon `into_par_iter` inside `TreeBuilder`;
- pdu library path does not expose a cancellation token, visitor stop condition,
  or traversal checkpoint;
- pdu CLI may call `rayon::ThreadPoolBuilder::build_global()` to set thread
  count, but product code must not use CLI host behavior;
- pdu CLI has HDD auto-thread behavior through `sysinfo`, but that is CLI
  policy, not product resource policy;
- pdu `FsTreeBuilder` returns `DataTree` through `From`, so adapter execution
  must capture side-channel reporter evidence and combine it with final tree;
- pdu helper paths can panic in diagnostic/helper code, for example hardlink
  summary inconsistency or UTF-8 JSON conversion via CLI `expect`.

Accepted execution contract:

```text
ScanSessionUseCase
  -> ScannerBackend.scan(request, event_sink)
  -> PduScannerBackend
  -> PduExecutionLane
  -> local bounded Rayon ThreadPool::install
  -> PduScanRunner
  -> PduRawScanResult
  -> BackendScanOutput
```

Top 3 execution strategies:

1. Dedicated pdu execution lane with bounded Rayon pool - 🎯 10 🛡️ 9 🧠 7,
   roughly 900-2200 LOC.
   Accepted. Keeps UI/server async runtime responsive, makes resource profiles
   explicit, and prevents pdu from silently using product-global thread policy.
2. Use Rayon global pool directly from server command handlers - 🎯 4 🛡️ 4
   🧠 3, roughly 200-600 LOC.
   Rejected. It creates hidden global coupling and makes resource budgets,
   tests, and future scanner coexistence weak.
3. Run pdu in a separate helper process from day one - 🎯 6 🛡️ 8 🧠 9, roughly
   2500-7000 LOC.
   Strong isolation, but too heavy for MVP. Keep contracts compatible with a
   future helper process if panic/resource containment becomes a blocker.

### Rayon Pool Containment Boundary

pdu's speed comes from Rayon, but Rayon must not become a hidden product-global
runtime policy.

Source-level facts from pdu 0.23.0:

- `TreeBuilder` uses `children.into_par_iter()` for recursive child traversal;
- `DataTree::par_sort_by`, `par_retain`, hardlink dedupe, and `Reflection`
  conversion helpers also use Rayon;
- pdu's CLI may call `rayon::ThreadPoolBuilder::build_global()` when the CLI
  thread policy resolves to a fixed count;
- pdu CLI `Threads::Auto` uses `sysinfo` to reduce threads for HDD-like disks,
  but this lives in the CLI host path, not the library scanner contract;
- the library `FsTreeBuilder` itself accepts no thread-pool parameter and has no
  IO scheduler, per-volume queue, or async runtime integration;
- if product code calls pdu without a local `ThreadPool::install`, pdu work runs
  on the process-global Rayon pool.

Top 3 Rayon containment strategies:

1. Local `PduExecutionLane` with a bounded Rayon `ThreadPool::install` - 🎯 10
   🛡️ 9 🧠 7, roughly 900-2200 LOC.
   Accepted. It keeps pdu parallelism behind the adapter, lets product
   `ResourceProfile` choose thread budgets, and avoids global Rayon coupling.
2. Use pdu CLI `Threads` and `build_global()` from the daemon - 🎯 3 🛡️ 3 🧠 3,
   roughly 200-600 LOC.
   Rejected. Global thread pools are process-wide, hard to test, and make other
   future scanner/index workers compete through hidden policy.
3. Force single-thread pdu for all scans - 🎯 5 🛡️ 8 🧠 2, roughly 100-300 LOC.
   Safe for background mode or fragile systems, but too slow as the default for a
   product that needs fast large-disk scans.

Accepted execution contract:

```text
ResourceProfile
  balanced | fast | background | custom
  -> PduLanePolicy
       max_rayon_threads
       max_parallel_roots
       callback_budget
       memory_budget
       io_pressure_hint
  -> PduExecutionLane::install(...)
       runs FsTreeBuilder and pdu helper diagnostics inside local pool
```

Layer rules:

- `fs_usage_core` owns resource-profile vocabulary, not Rayon concepts;
- `fs_usage_engine` owns resource planning and session scheduling;
- `fs_usage_pdu` owns the local Rayon pool, lane metrics, and pdu helper
  containment;
- `clean-disk-server` starts blocking pdu work outside async request handlers and
  observes it through session state;
- product code must never call pdu CLI `app`, `args::Threads`, or
  `rayon::ThreadPoolBuilder::build_global`;
- pdu helper operations used for diagnostics must also run inside the pdu lane or
  a separate bounded diagnostic lane;
- engine conversion/index work uses its own budget and must not assume pdu's
  Rayon pool is available after `PduRawScanResult` is produced.

Contract tests:

- dependency/static guard blocks `build_global()` in product crates;
- pdu scan can be run with a fixed local thread count in tests;
- product `ResourceProfile` maps to `PduLanePolicy`, not to pdu CLI `Threads`;
- pdu helper diagnostics do not escape the lane;
- scan cancellation drops late results without killing the local Rayon pool;
- metrics record pdu walk time separately from conversion and index time.

Cancellation contract:

```text
pdu capability.cooperative_cancellation = false
pdu capability.discard_late_result = true
session cancel -> state = cancelling
late scan result -> dropped if epoch/request id no longer active
terminal state -> cancelled | completed_before_cancel | failed_backend
```

Rules:

- cancellation UI must not promise immediate stop for pdu-backed scans;
- cancel endpoint must return quickly even if pdu is still walking;
- scan session state owns epoch/request ids, not the pdu adapter;
- all progress/events include session and epoch so stale events can be ignored;
- cancellation latency is measured as a backend metric;
- future fork/upstream cancellation hook must implement the same
  `ScannerBackend` capability, not change domain contracts.

### Resource Profile And Storage QoS Semantics

pdu CLI contains resource behavior that is useful research input but wrong as a
daemon contract.

Source-level facts:

- pdu CLI parses `Threads::Auto`, `Threads::Max`, or fixed non-zero thread
  count;
- `Threads::from_str` trims text, accepts exact `auto`, exact `max`, or a
  positive non-zero usize;
- `--threads=0` is rejected by `NonZeroUsize` parsing;
- `Threads::Auto` refreshes `sysinfo::Disks`, canonicalizes target paths, checks
  whether any target sits on a disk reported as HDD, and then sets thread limit
  to `1`;
- when pdu CLI has no filesystem arguments, HDD auto-detection sees an empty
  path list and returns false, even though `Sub::run` later falls back to
  scanning `"."`;
- canonicalization failures during HDD detection are ignored, so those paths do
  not contribute to the auto-thread decision;
- pdu picks the matching disk by longest mount-point prefix using
  `Path::starts_with` and max mount-point `OsStr` length, then checks the disk
  kind for that mount;
- if a disk name is not valid UTF-8, pdu keeps the original `sysinfo` disk kind
  because Linux virtual-driver correction cannot parse the name;
- pdu CLI applies the thread limit by calling
  `rayon::ThreadPoolBuilder::new().num_threads(...).build_global()`;
- if `build_global()` fails, pdu CLI prints a warning and continues;
- `build_global()` is process-global Rayon state. A failure can mean some other
  code already initialized the global pool;
- `Threads::Max` does not set a thread limit;
- fixed thread count also uses global Rayon pool setup;
- on Linux, pdu CLI has extra virtual-disk correction for known virtual block
  drivers because sysfs rotational flags can misclassify virtual disks as HDD;
- the pdu source itself documents LVM/device-mapper limitations in the CLI HDD
  heuristic;
- the Linux correction recognizes direct block devices and some `/dev/mapper`
  symlink cases, but real `/dev/dm-*` device-mapper setups can remain
  misclassified;
- on non-Linux platforms, pdu CLI HDD reclassification is effectively a no-op
  when `sysinfo` reports unknown disk kind;
- none of this exists in the pdu library scan contract. It is host policy.

Mount-point heuristic boundary:

```text
pdu find_mount_point = resource heuristic helper.
VolumeIdentity = platform authority.
BoundaryPolicy = application scan-scope policy.
Delete authority = current platform identity revalidation.
```

pdu's mount-point matching is useful as a weak storage-medium hint, but it is
not enough to decide target scope, same-volume claims, cleanup safety, or
enterprise/headless policy. It uses the disk list visible through `sysinfo`,
canonicalized input paths, and longest matching mount point. That leaves gaps for
bind mounts, FUSE/rclone, network shares, container mounts, removable drives,
cloud-provider placeholders, stale disk lists, and platform-specific volume
groups.

Product contract:

```text
ResourceProfile = application policy.
StorageMediumHint = platform evidence.
PduExecutionLane = infrastructure mechanism.
pdu CLI thread auto-limit = research input only.
pdu mount-point heuristic = storage hint only, never volume authority.
```

Top 3 resource strategies:

1. Engine-owned `ResourceProfile` plus bounded `PduExecutionLane` - 🎯 10 🛡️ 9
   🧠 7, roughly 1000-2600 LOC.
   Accepted. It keeps scan speed tunable while protecting UI responsiveness,
   daemon health, tests, and future scanner backends.
2. Copy pdu CLI `Threads::Auto` and `build_global` behavior - 🎯 3 🛡️ 3 🧠 3,
   roughly 300-900 LOC.
   Rejected. It uses global process state, weak platform heuristics, and cannot
   express product modes such as balanced, fast, background, battery, or remote.
3. Always run pdu at maximum parallelism - 🎯 5 🛡️ 4 🧠 2, roughly 100-300 LOC.
   Rejected as default. It may benchmark well, but it risks UI stalls, thermal
   pressure, IO saturation, bad laptop behavior, and poor multi-client daemon
   behavior.

Accepted policy vocabulary:

```text
ResourceProfile
  background
  balanced
  fast
  benchmark

StorageMediumHint
  ssd
  hdd
  network
  virtual
  removable
  unknown

ExecutionBudget
  rayon_threads
  concurrent_targets
  metadata_enrichment_parallelism
  event_batch_interval
  memory_soft_limit
  io_pressure_mode

ResourceDecisionEvidence
  requested_profile
  selected_budget
  storage_medium_hint
  storage_hint_confidence
  mount_hint_source
  downgrade_reasons
  source = user | platform | daemon_policy | thermal | battery | benchmark
```

Layer rules:

- `fs_usage_engine` owns `ResourceProfile`, `ExecutionBudget`, scheduling, and
  fairness between sessions;
- `fs_usage_platform` owns storage medium, mount, removable/network, battery,
  and OS capability hints;
- `fs_usage_pdu` maps `ResourceProfile` into a local Rayon pool and never calls
  `build_global`;
- Flutter may request product modes such as background/balanced/fast, but never
  raw pdu thread flags;
- default local desktop mode is balanced, not max;
- fast/benchmark mode is explicit and visible to the user;
- low battery, thermal pressure, network/removable storage, or active UI
  interaction can downgrade execution budget without changing scan contracts;
- product default target resolution happens before resource-budget selection, so
  default scans can still receive correct storage hints;
- storage-medium hints are evidence, not truth. Unknown or contradictory hints
  choose the safer balanced/background budget;
- pdu mount-point heuristics can only influence `StorageMediumHint` confidence
  and resource budget. They must not create `VolumeIdentity`, `BoundarySkipped`,
  or cleanup authority;
- resource decisions are per session/job. They must not mutate process-global
  Rayon state;
- a failed resource hint lookup is not a scan failure. It lowers confidence and
  uses conservative defaults;
- all resource decisions are metrics: selected profile, actual thread count,
  queue delay, scan wall time, cancellation latency, dropped events, and memory
  pressure;
- resource throttling changes speed, not product truth. A slower scan should not
  silently change traversal policy, size policy, or delete authority.

Accepted adapter-only records:

```text
PduLaneMetrics
  selected_resource_profile
  requested_threads
  actual_threads
  storage_medium_hint
  mount_heuristic_confidence
  queue_wait_ms
  scan_wall_time_ms
  conversion_wall_time_ms
  cancellation_latency_ms
  memory_pressure_events
  downgraded_budget_reason
```

Contract tests:

- pdu mount-point heuristic output can downgrade/adjust resource budget but
  cannot create volume identity or same-volume authority;
- canonicalization failure during storage-medium lookup yields
  `StorageMediumHint::unknown`, not scan failure and not target exclusion;
- nested mount points choose a deterministic resource hint while scan boundary
  still comes from `BoundaryPolicy` plus platform evidence;
- bind/network/FUSE/container/removable fixtures keep resource hints separate
  from traversal and cleanup authority;
- pdu `find_mount_point` or `any_path_is_in_hdd` never appears outside pdu
  diagnostics/resource-hint adapter code.

Panic containment contract:

```text
PduScanRunner
  -> contains recoverable unwind at adapter boundary where platform/profile allows
  -> maps panic to BackendScanFailure::BackendPanicked
  -> marks session failed_backend
  -> keeps daemon alive
```

Rules:

- `catch_unwind` is an adapter containment guard, not normal domain error
  handling;
- if release/profile/platform uses aborting panic semantics, helper-process
  isolation becomes the stronger future boundary;
- pdu diagnostic helpers that can panic run behind diagnostics/tests or inside
  panic containment;
- no pdu panic crosses into `fs_usage_engine`, `clean_disk_server`, protocol, or
  Flutter.

### Hardlink Recorder Semantics

pdu hardlink behavior is useful but not product-safe as-is:

- `HardlinkAware` records by `(dev, ino)` in a `DashMap`;
- `HardlinkAware` skips directories and records only files where Unix
  `MetadataExt::nlink() > 1`;
- `DetectHardlink` fires for every observed hardlink candidate, including the
  first observed path of an inode. It does not mean "duplicate already found";
- pdu hardlink identity is Unix-only `DeviceNumber + InodeNumber`;
- `HardlinkList::add` can detect size conflict and link-count conflict;
- `FsTreeBuilder` calls `record_hardlinks(...).ok()`, so recorder errors are
  ignored by the traversal;
- pdu `deduplicate` mutates `DataTree` sizes by path-prefix logic;
- pdu dedupe subtracts `size * (detected_paths_in_this_subtree - 1)` from
  directories where more than one detected hardlink path falls under that
  directory;
- pdu `Summary.exclusive_*` is based on `detected_paths == nlink`. If detected
  paths are fewer than `nlink`, there are links outside the measured tree;
- pdu hardlink summary panics if detected paths exceed `nlink`;
- pdu README says hardlinks are treated as equally real by default;
- pdu README also says reflinks from COW filesystems such as Btrfs and ZFS are
  not handled.

Top 3 hardlink adapter strategies:

1. Custom `CleanDiskHardlinkRecorder` inside `fs_usage_pdu` - 🎯 9 🛡️ 9 🧠 7,
   roughly 900-2200 LOC.
   Accepted for the first serious adapter. It implements pdu `RecordHardlinks`,
   stores conflict/evidence internally, and does not rely on the ignored `Result`
   path for correctness.
2. Use pdu `HardlinkAware` directly and map `DetectHardlink` reporter events -
   🎯 6 🛡️ 6 🧠 4, roughly 300-900 LOC.
   Usable for a quick spike, but conflict details can be lost because
   `FsTreeBuilder` ignores recorder errors.
3. Call pdu `deduplicate` and use adjusted sizes as primary tree - 🎯 4 🛡️ 5
   🧠 4, roughly 300-900 LOC.
   Rejected for product truth. It mutates measured size and makes reclaim
   confidence look stronger than it is.

Accepted hardlink rule:

```text
Hardlink detection is evidence.
Hardlink adjustment is a confidence-tagged projection.
Exclusive reclaim estimate belongs to fs_usage_accounting, not pdu.
```

Hardlink domain mapping:

```text
HardlinkEvidence
  identity_kind = unix_dev_inode
  observed_path_count
  reported_link_count
  measured_size
  scope = inside_scan | partly_outside_scan | uncertain
  conflict = none | size_conflict | link_count_conflict | summary_inconsistent
  confidence
```

Hardlink data/infrastructure mapping:

```text
CleanDiskHardlinkRecorder
  -> stores observed `(dev, ino)` evidence
  -> stores conflicts even when pdu ignores recorder Result
  -> never mutates primary NodeArena size
  -> optionally computes hardlink-adjusted projection after scan
```

### Hardlink Platform Capability Boundary

pdu hardlink support is not a universal backend capability.

Source-level facts from `parallel-disk-usage` 0.23.0:

- the `hardlink::aware` module and `HardlinkAware` re-export are behind
  `#[cfg(unix)]`;
- pdu source comments say `RecordHardlink` is POSIX-exclusive because Windows
  `MetadataExt::number_of_links` requires Nightly;
- `HardlinkAware` depends on Unix `MetadataExt::nlink()`, `DeviceNumber::get`,
  and `InodeNumber::get`;
- `DeviceNumber::get` and `InodeNumber::get` are also behind `#[cfg(unix)]`;
- `HardlinkIgnorant` is cross-platform and intentionally does nothing;
- `RecordHardlinks` is a generic trait, so a custom adapter recorder can still
  be used as a private metadata tap, but that does not mean pdu has hardlink
  group support on the current platform.

Top 3 platform hardlink strategies:

1. Domain `HardlinkCapability` plus platform/backend-specific evidence - 🎯 10
   🛡️ 10 🧠 7, roughly 800-2200 LOC.
   Accepted. Unix pdu can report built-in pdu hardlink evidence. Non-Unix pdu
   reports unsupported or degraded. Future Windows NTFS/MFT support plugs into
   the same domain contract through a separate adapter.
2. Treat pdu hardlink support as universal - 🎯 2 🛡️ 2 🧠 2, roughly
   100-300 LOC.
   Rejected. It would make Windows and non-Unix reclaim confidence look stronger
   than the backend can prove.
3. Disable all hardlink evidence everywhere - 🎯 6 🛡️ 8 🧠 1, roughly
   50-150 LOC.
   Safe fallback, but it throws away useful Unix evidence and makes the product
   less honest on systems where pdu can detect hardlinks.

Accepted capability contract:

```text
HardlinkCapability
  detection = supported | unsupported | degraded
  identity_kind = unix_dev_inode | ntfs_file_reference | unknown
  built_in_pdu_hardlink_aware_available
  metadata_tap_available
  reclaim_estimate_authority = never_from_pdu
```

Layer rules:

- domain owns `HardlinkCapability`, `HardlinkIdentityKind`, and confidence
  vocabulary. Domain never contains pdu `cfg(unix)`, `HardlinkAware`,
  `HardlinkIgnorant`, or `RecordHardlinks` names;
- `fs_usage_engine` chooses scan and projection behavior from backend
  capability, not from crate names or platform guesses;
- `fs_usage_pdu` reports pdu built-in hardlink detection as Unix-only adapter
  evidence;
- non-Unix pdu reports hardlink detection as `unsupported` or `degraded`
  explicitly. It must not silently look like "no hardlinks found";
- future Windows NTFS/MFT hardlink evidence belongs to a separate platform or
  scanner adapter implementing the same domain contract;
- `RecordHardlinks` metadata tap availability is separate from hardlink group
  support. It may collect path/metadata evidence while
  `built_in_pdu_hardlink_aware_available = false`;
- pdu hardlink evidence never becomes reclaim authority. Reclaim estimates
  remain in `fs_usage_accounting` with confidence and platform revalidation.

Required contract tests:

- Unix pdu adapter reports `HardlinkCapability::supported` when pdu
  `HardlinkAware` is compiled and enabled;
- non-Unix pdu adapter reports `unsupported` or `degraded` instead of pretending
  hardlink scan support exists;
- metadata tap can be enabled while hardlink group support remains unsupported;
- future NTFS/MFT backend can implement `HardlinkIdentityKind::ntfs_file_reference`
  without changing domain, protocol, or Flutter contracts;
- no domain/protocol/cache type exposes pdu hardlink type names or pdu
  conditional compilation flags.

### Hardlink Recorder Side-Channel Contract

The pdu hardlink hook is powerful, but its error path is not usable as product
truth.

Source-level facts:

- `HardlinkAware::record_hardlinks` skips directories and files with
  `nlink <= 1`;
- for candidates, pdu emits `Event::DetectHardlink` before inserting into
  `HardlinkList`;
- `HardlinkList::add` can detect size conflict or link-count conflict for the
  same `(dev, ino)`;
- on conflict, pdu does not add the new path to the stored `LinkPathList`;
- `FsTreeBuilder` discards the `record_hardlinks` `Result` with `.ok()`;
- `LinkPathList::add` pushes paths into a `Vec<PathBuf>` and does not dedupe;
- `LinkPathListReflection` later converts paths into a `HashSet`, which can hide
  duplicate path observations;
- pdu dedupe only subtracts size for paths whose suffixes are under the current
  tree prefix and where at least two detected paths remain in that subtree.

Product consequence:

```text
DetectHardlink event != durable hardlink group evidence.
RecordHardlinks::Err != reliable product error channel.
CleanDiskHardlinkRecorder side store = source of hardlink evidence.
```

Accepted recorder strategy:

1. Side-store observations and conflicts, return `Ok` for recoverable conflicts -
   🎯 10 🛡️ 9 🧠 7, roughly 700-1800 LOC.
   Accepted. The adapter captures evidence before pdu can discard the error path
   and avoids using `RecordHardlinks::Err` as product control flow.
2. Rely on pdu `HardlinkAware` plus reporter counters - 🎯 5 🛡️ 5 🧠 3,
   roughly 200-700 LOC.
   Rejected for product truth. Reporter counters can observe a candidate even
   when the hardlink list did not store the conflicting path.
3. Disable hardlink evidence in MVP - 🎯 7 🛡️ 8 🧠 1, roughly 50-150 LOC.
   Acceptable only as a temporary capability downgrade. It keeps safety high but
   leaves size/reclaim explanations weaker on Unix developer machines.

Adapter contract:

```text
CleanDiskHardlinkRecorder
  -> copies path, dev, ino, size, nlink into owned evidence
  -> classifies observation, duplicate path, size conflict, link-count conflict
  -> stores conflict records in PduHardlinkConflictStore
  -> optionally emits telemetry after owned evidence is captured
  -> returns Ok for recoverable observation conflicts
  -> returns Err only for catastrophic adapter failure
```

Domain/application mapping:

```text
HardlinkObservationState
  observed
  duplicate_path
  size_conflict
  link_count_conflict
  outside_scan_possible
  summary_inconsistent
  recorder_truncated

HardlinkGroupEvidence.confidence
  high only when identity, size, link-count, and scope evidence agree
  medium when outside-scan links are possible
  low when conflicts, truncation, or pdu summary inconsistency exist
```

Rules:

- `PduReporterSnapshot.hardlink_event_count` is telemetry, not group count;
- product hardlink groups come from `CleanDiskHardlinkRecorder`, not from pdu
  progress counters;
- conflict paths are kept as evidence even if pdu would not add them to
  `HardlinkList`;
- duplicate path observations are explicit evidence, not silently collapsed by
  pdu Reflection;
- hardlink side-store truncation maps to degraded hardlink confidence and a scan
  issue or backend metric;
- hardlink evidence never upgrades a node to delete authority.

Hardlink UI/protocol mapping:

- show hardlink evidence as explanation/confidence, not as exact reclaimable
  bytes;
- never say hardlink-adjusted size is exact on APFS/Btrfs/ZFS/ReFS/dedupe/COW
  storage without a stronger accounting adapter;
- hardlink evidence can influence warnings and size facts, but delete preflight
  still validates current file identity.

### `HardlinkList` And Reflection Adapter Boundary

The deeper pdu source audit shows that hardlink data needs an explicit
anti-corruption layer:

- `HardlinkList<Size>` is a `DashMap<(DeviceNumber, InodeNumber), Value<Size>>`;
- each value stores measured size, total Unix `nlink`, and a `LinkPathList`;
- `LinkPathList` is internally a `Vec<PathBuf>`, so iteration is detection-order
  evidence, not a stable product order;
- `LinkPathListReflection` converts that vector into a `HashSet<PathBuf>`, which
  removes duplicate path entries and does not preserve product order;
- `HardlinkListReflection` sorts entries by inode number and device number only
  for inspection/equality/JSON support. That order is not a UI, protocol, or
  persistence order;
- `HardlinkList::add` can report size conflicts and link-count conflicts, but
  pdu traversal discards recorder errors through `.ok()`;
- pdu summary treats `detected_paths < nlink` as links outside the measured tree
  and panics if detected paths exceed `nlink`.

Product contract:

```text
pdu HardlinkList/Reflection
  -> fs_usage_pdu mapper
  -> owned HardlinkGroupEvidence records
  -> engine/accounting policy decides confidence and reclaim meaning
```

Do not expose these pdu types outside `fs_usage_pdu`:

```text
HardlinkList
HardlinkListReflection
LinkPathList
LinkPathListReflection
SharedLinkSummary
```

Domain concepts we own:

```text
HardlinkGroupEvidence
  identity = platform file identity observed during scan
  observed_paths = owned path refs or node refs
  observed_path_count
  reported_link_count
  outside_scan_links = known | possible | unknown
  conflict = none | size_conflict | link_count_conflict | duplicate_path | summary_inconsistent
  confidence = high | medium | low

HardlinkReclaimPolicy
  can_inform_warning = true
  can_inform_adjusted_projection = true
  can_be_delete_authority = false
```

Rules:

- order hardlink paths through our indexes when order matters;
- treat duplicate path collapse in reflection as diagnostic behavior only;
- treat `detected_paths < nlink` as "may have links outside scan scope";
- contain pdu summary panics and downgrade hardlink confidence;
- never let hardlink evidence alone claim exact reclaimable bytes;
- delete preflight must re-read current identity and link count.

### Hardlink Summary Completeness Boundary

pdu hardlink summary is useful scan evidence, but it is not an accounting or
cleanup contract. Its fields describe what pdu detected during this traversal,
not what the filesystem will actually reclaim after deletion.

Source-level facts from pdu 0.23.0:

- `Summary.inodes` counts hardlink groups where `nlink > 1`;
- `Summary.all_links` is the sum of reported Unix `nlink` values;
- `Summary.detected_links` is the number of paths pdu saw inside the measured
  tree;
- `Summary.exclusive_*` fields are incremented only when
  `detected_paths == nlink`;
- when `detected_paths < nlink`, pdu treats outside links as possible and does
  not mark the group exclusive;
- when `detected_paths > nlink`, pdu panics because that violates its invariant;
- pdu summary uses the scan-time hardlink list, so races, path duplication,
  conflict truncation, permission skips, target boundaries, and pdu `max_depth`
  can all lower confidence;
- pdu summary does not know APFS clones, reflinks, snapshots, compression,
  cloud placeholders, dedupe engines, or platform Trash behavior.

Accepted product interpretation:

```text
pdu Summary.shared_size = observed shared-link evidence.
pdu Summary.exclusive_shared_size = candidate evidence, not reclaim authority.
pdu Summary.detected_links < all_links = outside-scan links possible.
pdu Summary panic/inconsistency = degraded hardlink evidence.
```

Top 3 hardlink summary policies:

1. Map pdu summary into `HardlinkSummaryEvidence` with confidence - 🎯 10
   🛡️ 10 🧠 5, roughly 500-1200 LOC.
   Accepted. The evidence can explain hardlink-adjusted views while keeping
   reclaim estimates in `fs_usage_accounting`.
2. Show pdu `exclusive_shared_size` as exact reclaimable space - 🎯 3 🛡️ 3
   🧠 2, roughly 100-300 LOC.
   Rejected. It ignores delete-time link count, clones/reflinks/snapshots,
   stale paths, Trash behavior, and cleanup scope.
3. Hide all hardlink summary information from product surfaces - 🎯 6 🛡️ 8
   🧠 1, roughly 50-150 LOC.
   Acceptable only as a temporary downgrade. It is safe, but weakens scan
   explainability and benchmark honesty on Unix-heavy developer machines.

Accepted contract:

```text
HardlinkSummaryEvidence
  observed_group_count
  reported_link_count
  detected_link_count
  outside_scan_links
  shared_size
  exclusive_candidate_size
  consistency = consistent | summary_inconsistent | truncated | unknown
  confidence

HardlinkReclaimEstimate
  produced_by = fs_usage_accounting
  requires current link-count revalidation
  not produced directly by pdu Summary
```

Layer rules:

- `fs_usage_pdu` maps pdu `SharedLinkSummary` into owned
  `HardlinkSummaryEvidence`;
- `fs_usage_core` owns the summary evidence vocabulary and confidence states;
- `fs_usage_engine` can attach summary evidence to snapshot quality and
  projection metadata;
- `fs_usage_accounting` owns any reclaim estimate that uses hardlink data;
- protocol/UI can say "hardlink evidence" or "candidate adjusted view", but not
  "guaranteed reclaim" from pdu summary alone;
- summary generation runs behind panic containment when it consumes pdu
  `HardlinkList` or reflection data.

Contract tests:

- `detected_links < all_links` maps to outside-scan possible and lower reclaim
  confidence;
- `exclusive_shared_size` is not serialized as reclaimable bytes;
- summary panic or invariant failure maps to degraded hardlink evidence;
- hardlink summary from diagnostic pdu JSON remains reduced-authority evidence;
- delete preflight revalidates current link count before any hardlink-informed
  cleanup estimate is shown as current.

### Hardlink Dedupe Projection Contract

pdu's hardlink dedupe algorithm is a tree-size projection, not an accounting
model.

Source-level facts from pdu 0.23.0:

- `HardlinkAware::deduplicate(&mut DataTree)` delegates to
  `DataTree::par_deduplicate_hardlinks`;
- `par_deduplicate_hardlinks` mutates `DataTree.size` in place;
- the algorithm starts with full hardlink paths, then recursively converts them
  into path suffixes with `strip_prefix(self.name().as_ref())`;
- for each current `DataTree` node, it keeps only link suffixes that still fall
  under the current node name/prefix;
- if more than one detected link suffix remains in the current subtree, it
  subtracts `size * (number_of_links_in_this_subtree - 1)` from the current
  node's aggregate size;
- the same hardlink group can adjust an ancestor but not a child when the links
  are split across different child directories;
- dedupe depends on pdu's root-name/full-path and child-name/segment shape;
- `LinkPathList` stores a `Vec<PathBuf>` and does not dedupe on insert;
- `LinkPathListReflection` converts paths to a `HashSet<PathBuf>`, which can
  erase duplicate-observation evidence;
- pdu does not know APFS clones, Btrfs/ZFS/ReFS reflinks, dedupe engines,
  snapshots, compression, cloud placeholders, or delete-time link count.

Accepted contract:

```text
PduHardlinkDedupeProjection
  projection_id
  source = pdu_path_suffix_algorithm
  applies_to = display_size_projection | diagnostic
  mutates_primary_tree = false
  confidence
  excluded_from_reclaim_authority = true
```

Top 3 dedupe projection strategies:

1. Reimplement pdu dedupe as our own projection over `HardlinkGroupEvidence` -
   🎯 8 🛡️ 9 🧠 7, roughly 900-2200 LOC.
   Accepted when/if the UI needs a hardlink-adjusted view. It keeps raw measured
   sizes immutable and makes confidence/exclusions explicit.
2. Call pdu `deduplicate` on a cloned diagnostic tree only - 🎯 6 🛡️ 7 🧠 5,
   roughly 500-1400 LOC plus memory cost.
   Acceptable for diagnostics/spikes. It avoids mutating primary truth, but
   still inherits pdu path-prefix assumptions and can double memory.
3. Call pdu `deduplicate` before `PduTreeConverter` and use those sizes as
   primary - 🎯 3 🛡️ 3 🧠 3, roughly 200-700 LOC.
   Rejected. It destroys raw measurement semantics and makes cleanup/reclaim
   appear more certain than it is.

Layer rules:

- `SizeFacts.measured` is never hardlink-deduped;
- `SizeFacts.hardlink_adjusted_bytes` is an optional projection with evidence
  and confidence;
- `HardlinkReclaimPolicy` decides whether a projection can be displayed,
  exported, or used for recommendation ranking;
- `fs_usage_accounting` owns exclusive reclaim estimates and delete-time link
  count interpretation;
- `fs_usage_pdu` may compute pdu-shaped dedupe only as private diagnostic or
  projection evidence;
- `PduTreeConverter` must not call pdu `deduplicate` on the primary tree;
- UI copy must distinguish "measured size", "hardlink-adjusted view", and
  "estimated reclaim".

Data/infrastructure mapping:

```text
CleanDiskHardlinkRecorder
  -> HardlinkGroupEvidence
  -> PduHardlinkDedupeProjectionMapper
  -> SizeFacts.hardlink_adjusted_bytes optional projection

PduHardlinkDedupeGuard
  -> blocks DataTree mutation on primary conversion path
  -> allows cloned diagnostic projection only behind explicit capability
```

Contract tests:

- primary `NodeArenaRecord.size_facts.measured` equals raw pdu measurement even
  when hardlink evidence exists;
- pdu `deduplicate` is not called on the primary scan tree;
- duplicated hardlink path observations remain observable before any reflection
  conversion collapses paths;
- hardlinks split across sibling directories adjust only a projection, not
  primary aggregate truth;
- hardlink-adjusted projection never becomes exact reclaim estimate.

### Hardlink Dedupe Arithmetic And Prefix Scope Boundary

pdu hardlink dedupe is not only a hardlink detector. It is a recursive aggregate
mutation algorithm. That means the adapter must treat it like a lossy projection
with arithmetic and scope assumptions, not like filesystem accounting.

Source-level facts from pdu 0.23.0:

- `DataTree::par_deduplicate_hardlinks` takes a slice of `(Size, Vec<&Path>)`
  hardlink groups and mutates `self.size`;
- at each tree node, it uses `self.name().as_ref()` as the current prefix and
  calls `link_path.strip_prefix(prefix)`;
- after prefix stripping, the recursive child receives suffix paths, so the
  algorithm depends on pdu's heterogeneous name shape: root is path-like,
  descendants are file-name segments;
- groups with `link_paths.len() <= 1` are ignored at each scope;
- if more than one link remains under the current scope, pdu subtracts
  `size * (number_of_links_in_scope - 1)` from that node aggregate;
- subtraction uses pdu `Size` ordinary arithmetic, not checked product
  accounting arithmetic;
- `LinkPathList` stores a `Vec<PathBuf>` and can preserve repeated observations,
  while `LinkPathListReflection` converts to `HashSet<PathBuf>` and can erase
  duplicate-observation evidence;
- pdu hardlink scope says "multiple observed paths under this prefix", not
  "these bytes are exclusively reclaimable by deleting selected nodes".

Top 3 hardlink arithmetic policies:

1. Recompute hardlink projections from our own `HardlinkGroupEvidence` with
   checked arithmetic and scope evidence - 🎯 9 🛡️ 10 🧠 7, roughly 900-2400 LOC.
   Accepted for product hardlink-adjusted views. It keeps pdu's observed evidence
   but not pdu's mutable aggregate as authority.
2. Use pdu `par_deduplicate_hardlinks` only on cloned diagnostic/projection trees
   and label the output with `pdu_prefix_projection` - 🎯 6 🛡️ 7 🧠 5, roughly
   500-1400 LOC.
   Acceptable for comparison and benchmark diagnostics, not for product truth.
3. Trust pdu's mutated aggregate as the primary measured size - 🎯 2 🛡️ 2 🧠 2,
   roughly 100-300 LOC.
   Rejected. It mixes display projection, prefix assumptions, unchecked
   arithmetic, and reclaim ambiguity into the main scan model.

Accepted contract:

```text
HardlinkGroupEvidence
  observed_paths
  observed_link_count
  pdu_scope_evidence
  duplicate_observation_state
  arithmetic_confidence

HardlinkAdjustedProjection
  measured_size_ref
  adjusted_size
  projection_algorithm
  checked_arithmetic_state
  scope_confidence
  reclaim_authority = false
```

Layer rules:

- `fs_usage_pdu` may read pdu hardlink observations and pdu summaries, but it
  does not let pdu mutate the primary tree;
- `fs_usage_engine` may build hardlink-adjusted query projections only from
  `HardlinkGroupEvidence` plus checked arithmetic;
- `fs_usage_accounting` owns reclaim/exclusive-byte estimates and must revalidate
  current link count before cleanup;
- protocol/Flutter labels hardlink-adjusted values as projections, never as
  exact reclaim;
- diagnostic pdu dedupe output records `pdu_prefix_projection`,
  `duplicate_observation_state`, and `checked_arithmetic_state` before display.

Contract tests:

- pdu dedupe is forbidden on the primary `PduTreeConverter` path;
- hardlink links split across sibling directories affect only ancestor
  projection scope;
- duplicate path observations are preserved before any pdu reflection `HashSet`
  conversion;
- projection arithmetic uses checked/saturating product helpers and records
  degradation on overflow, underflow, or ambiguous scope;
- no cleanup estimate uses hardlink-adjusted projection without current platform
  accounting validation.

### Path Fidelity Semantics

pdu stores root as an `OsStringDisplay` built from the full root path and children
as `file_name()` segments. `OsStringDisplay` displays non-UTF-8 names using debug
format when `Display` is used.

Source-level path facts:

- `FsTreeBuilder.name` for the root is `OsStringDisplay::os_string_from(&root)`,
  so the root node name is a full path-like value;
- child nodes are collected from `DirEntry::file_name()`, so descendants are
  basename-like path segments, not full paths;
- `TreeBuilder.join_path` reconstructs traversal paths with
  `prefix.join(&name.0)`;
- `OsStringDisplay::Display` uses UTF-8 text when possible, otherwise it writes
  the inner `OsStr` debug form;
- pdu `Reflection`/JSON conversion requires UTF-8 names and is therefore not a
  path-fidelity-safe product transport;
- Rust `Path::to_str()` returns `None` for non-Unicode paths, and
  `to_string_lossy()` replaces invalid sequences. Those are display tools, not
  authority tools.

Product mapping:

- keep raw path segments in Rust as platform path evidence;
- reconstruct full display paths in the engine/read-model layer;
- never use pdu `Display` output as path identity;
- web protocol uses display-safe strings plus opaque `NodeRef`, not raw OS path
  authority;
- non-UTF-8 paths require a fixture and a lossy-display evidence flag.

Top 3 path contract policies:

1. Split raw path evidence, display path, and command authority - 🎯 10 🛡️ 10
   🧠 7, roughly 900-2200 LOC.
   Accepted. It preserves non-UTF-8 correctness, avoids UI-as-authority bugs,
   and keeps delete safety behind identity revalidation.
2. Store only UTF-8 display strings in the read model - 🎯 3 🛡️ 3 🧠 2, roughly
   200-600 LOC.
   Rejected. It is easy, but loses path identity and breaks non-UTF-8,
   bidi/control-character, and platform-native path cases.
3. Send raw platform path bytes to Flutter and let UI command by path - 🎯 4
   🛡️ 4 🧠 6, roughly 500-1400 LOC.
   Rejected for MVP. It leaks authority to UI, complicates Flutter web, and
   increases privacy/export risk. Raw/native path evidence stays server-side
   unless an explicit diagnostic export is requested.

Accepted path model:

```text
PathSegmentEvidence
  segment_id
  native_segment_ref
  display_name
  display_encoding = exact_utf8 | lossy | debug_escaped | redacted
  contains_control_or_bidi

NodePathEvidence
  target_id
  parent_ref
  segment_ref
  pdu_name_kind = root_full_path | child_file_name
  reconstructed_path_ref
  path_confidence

DisplayPath
  text
  redaction_class
  lossy
  safe_for_clipboard

Command authority
  NodeRef + current identity preflight
  not DisplayPath
  not pdu OsStringDisplay text
```

Layer rules:

- domain owns value objects such as `DisplayPath`, `PathEncodingState`, and
  `PathAuthorityKind`;
- application/read model owns reconstructed path refs and path indexes;
- `fs_usage_pdu` converts pdu root/full-path names and child file names into
  engine path evidence immediately;
- protocol exposes display-safe strings and opaque refs only;
- cleanup receives `NodeRef`/`DeletePlan` and revalidates current identity
  through platform ports.

Test fixtures:

- root node pdu name is full root path while child node names are segments;
- non-UTF-8 filename is representable in Rust read model without pdu JSON;
- pdu `Display` debug fallback never becomes path identity;
- two different native paths with same lossy display do not collide;
- bidi/control characters are display-escaped or marked for UI rendering;
- copied/exported paths follow explicit redaction and authority policy.

### Display Sanitization And Export Boundary

pdu display behavior is terminal-oriented. Clean Disk needs product-safe display,
copy, export, logging, and support-bundle behavior.

Source-level facts:

- `OsStringDisplay::Display` returns raw UTF-8 text when `OsStr::to_str()`
  succeeds;
- valid UTF-8 names can still contain newline, tab, control characters,
  bidirectional override characters, zero-width characters, and path separators
  that are confusing in UI/export contexts;
- when UTF-8 conversion fails, pdu writes the `OsStr` debug representation. That
  is a presentation fallback, not stable identity;
- pdu `Visualizer` converts names with `initial_row.name.to_string()` and then
  renders terminal tree rows;
- pdu CLI JSON requires UTF-8 names and calls `expect(...)` after
  `par_convert_names_to_utf8`;
- pdu does not classify display safety, clipboard safety, redaction class, or
  export policy.

Product contract:

```text
native path evidence = server-side authority evidence.
display path = UI text with safety annotations.
copy/export path = explicit user action through policy.
logs/support bundles = redacted evidence by default.
```

Top 3 display/export strategies:

1. Engine-owned display policy with protocol-safe annotations - 🎯 10 🛡️ 10
   🧠 7, roughly 900-2200 LOC.
   Accepted. UI receives already-classified text, safety flags, and redaction
   class. Commands still use `NodeRef`, not displayed path text.
2. Let Flutter sanitize every path string locally - 🎯 5 🛡️ 6 🧠 5, roughly
   500-1400 LOC.
   Rejected as the main contract. Flutter can apply visual rendering rules, but
   privacy, export, collision, and authority policy must be shared and tested in
   Rust/server contracts.
3. Trust pdu `Display`/visualizer output for UI and exports - 🎯 2 🛡️ 2 🧠 2,
   roughly 100-300 LOC.
   Rejected. It is terminal output, not a safe product display boundary.

Accepted vocabulary:

```text
DisplaySafety
  plain
  contains_control
  contains_bidi
  contains_zero_width
  lossy_encoding
  debug_escaped
  redacted

PathRedactionClass
  public_name
  user_home_relative
  sensitive_absolute
  secret_like
  diagnostic_only

PathExportPolicy
  disabled
  display_only
  clipboard_allowed_after_user_action
  support_bundle_redacted
  diagnostic_full_path_with_consent
```

Layer rules:

- `fs_usage_core` owns display safety, redaction, and export policy value
  objects;
- `fs_usage_engine` computes display-safe path projections and collision
  evidence for query/detail responses;
- `fs_usage_pdu` never exposes `OsStringDisplay::Display` text as identity,
  cache key, authority, or safe export;
- `clean_disk_protocol` exposes display text plus safety/redaction flags, not
  raw native path authority;
- Flutter renders display text defensively and must preserve warning/escape
  indicators for unsafe names;
- copy-to-clipboard and export are explicit commands with policy checks. They
  are not passive side effects of showing a row;
- production logs and telemetry do not contain raw paths. Support bundles use
  redacted path evidence unless the user explicitly chooses a diagnostic export.

### OsStringDisplay Sort And Name Boundary

pdu's `OsStringDisplay` is a native-name helper, not a product path model. It is
especially risky because it looks convenient: it derives ordering traits, exposes
`Deref`/`DerefMut`, implements `Display`, and can be serialized when the `json`
feature is enabled.

Source-level facts:

- `OsStringDisplay` derives `PartialOrd` and `Ord`, but that ordering is native
  wrapper ordering, not Clean Disk sort/search semantics;
- `OsStringDisplay` exposes mutation/conversion helpers such as `Deref`,
  `DerefMut`, `AsRef`, `AsMut`, and `From`, so adapter code can accidentally
  treat it as stable product identity;
- `Display` is conditional: valid UTF-8 is written directly, while non-UTF-8
  values are rendered with `OsStr` debug formatting;
- root names and child names are not the same kind of thing: pdu root name is a
  full path-like value, while descendants are basename segments;
- pdu text error reporting formats paths with debug output and sends them to the
  terminal/status path. That is diagnostic behavior, not a privacy, protocol, or
  UI display contract.

Top 3 name/sort policies:

1. Split native name evidence, display path, and product sort key - 🎯 10
   🛡️ 10 🧠 6, roughly 500-1300 LOC.
   Accepted. The adapter captures what pdu observed, the engine creates stable
   query/index keys, and protocol/UI receive display-safe projections.
2. Use `OsStringDisplay` text directly in the read model - 🎯 3 🛡️ 3 🧠 2,
   roughly 100-300 LOC.
   Rejected. It leaks pdu display behavior into identity, search, sorting,
   export, and cleanup flows.
3. Convert every pdu name to UTF-8 string during scan conversion - 🎯 4 🛡️ 4
   🧠 3, roughly 200-700 LOC.
   Rejected. It loses non-UTF-8 fidelity and creates collisions for names that
   have identical lossy display text.

Accepted contract:

```text
PduObservedName
  pdu_name_kind = root_full_path | child_file_name
  native_name_ref
  observed_display_hint

PathSegmentEvidence
  native_segment_ref
  encoding_state
  display_safety

DisplayPath
  safe_text
  redaction_class
  clipboard_policy

PathSortKey
  locale_policy
  case_policy
  natural_sort_policy
  deterministic_tie_breaker
```

Layer rules:

- `fs_usage_pdu` is the only layer allowed to unwrap `OsStringDisplay`;
- `fs_usage_pdu` maps root and child names through an explicit
  `PduNameKindMapper`;
- `fs_usage_core` owns `DisplayPath`, `DisplaySafety`, `PathRedactionClass`,
  and `PathSortKey` value objects, not pdu names;
- `fs_usage_engine` computes query/search/sort keys after path evidence is
  normalized and indexed;
- pdu `Ord`/`PartialOrd` never defines product row ordering, search ranking,
  export ordering, or cache key order;
- pdu `Display` and text error reports are diagnostic hints only;
- any valid UTF-8 pdu name still goes through control-character, bidi,
  zero-width, redaction, clipboard, and export policy checks.

Contract tests:

- root pdu name maps to `root_full_path` and children map to `child_file_name`;
- pdu `Ord` output is ignored when engine sort policy is active;
- two different native names with the same display string keep distinct
  `NodeRef` and path evidence;
- valid UTF-8 names with newline, control, bidi, or zero-width characters are
  flagged as unsafe display/export text;
- `OsStringDisplay::Display` and pdu text error output never appear in command
  authority, cache keys, protocol ids, or cleanup receipts;
- adapter code cannot expose `OsStringDisplay` outside the pdu import boundary.

### Traversal Boundary Semantics

pdu `DeviceBoundary::Stay` compares device ids when the platform supports them.
On unsupported platforms, pdu's internal device id is `()`, effectively weakening
the boundary.

pdu cross-device skip does not emit a skipped event. It simply returns no
children for the boundary-crossing directory.

Product mapping:

```text
BoundaryPolicy::StayOnDevice requires platform capability evidence.
If capability is weak, backend capabilities must say so.
Empty children from pdu are not enough to claim complete traversal.
```

The platform adapter may need a preflight or enrichment pass to mark boundary
skips explicitly.

### Directory Race And Ordering Semantics

pdu reads a directory in two steps:

```text
read_dir(parent)
  -> collect child file_name values
  -> later join parent + child name
  -> later symlink_metadata(child)
```

Implications:

- a child can be deleted or changed between `read_dir` and `symlink_metadata`;
- pdu maps that later failure to `SymlinkMetadata` on the child path;
- `AccessEntry` errors from `read_dir` are reported against the parent path;
- pdu child order is the collected filesystem order plus Rayon traversal timing;
- pdu gives no stable traversal sequence number.

Product mapping:

```text
ReadModelIndexes own ordering.
Event sequence belongs to fs_usage_engine / clean_disk_server.
Vanished files are scan issues, not backend failure.
```

UI and protocol must never rely on pdu child order or pdu callback order.

### Stable Ordering And Cursor Boundary

pdu child order is traversal evidence, not product order. This matters because
Clean Disk UI is page/cursor driven: row selection, keyboard focus, details,
search, top lists, compare views, and cleanup queue references must remain
stable within a snapshot.

Source-level facts:

- `FsTreeBuilder` collects child `file_name()` values from `read_dir(path)` into
  a `Vec`;
- Rust `read_dir` order is filesystem/platform dependent and should not be
  treated as stable product order;
- `TreeBuilder` then processes child names through Rayon `into_par_iter`;
- pdu `DataTree::children()` returns the stored `Vec`, not an index or cursor;
- pdu `DataTree::par_sort_by` recursively calls `sort_unstable_by`, so equal
  elements have no stable product tie-breaker;
- pdu `par_retain` and CLI culling mutate the tree and can remove rows while
  parent aggregate sizes still include hidden data;
- pdu has no stable node id, query fingerprint, cursor version, or page anchor.

Accepted product rule:

```text
pdu order = adapter observation only.
engine order = stable snapshot index order.
protocol cursor = opaque query + snapshot + index version.
Flutter row order = server page order only.
```

Top 3 ordering strategies:

1. Engine-owned deterministic indexes and opaque cursors - 🎯 10 🛡️ 10 🧠 7,
   roughly 900-2400 LOC.
   Accepted. It makes pagination stable, keeps pdu replaceable, and lets future
   backends use different raw traversal order without changing UI contracts.
2. Sort pdu `DataTree` once with `par_sort_by` and page the resulting children -
   🎯 5 🛡️ 5 🧠 3, roughly 300-900 LOC.
   Rejected. It is unstable for equal keys, mutates adapter data, and does not
   solve search/top/filter cursor semantics.
3. Preserve pdu filesystem order as "natural order" - 🎯 3 🛡️ 3 🧠 1, roughly
   100-300 LOC.
   Rejected. It changes across filesystems, OS versions, mounts, scans, and
   races, and makes support/debugging painful.

Accepted contract:

```text
SnapshotOrderIndex
  snapshot_id
  index_version
  query_fingerprint
  sort_policy
  tie_breaker_policy

SortPolicy
  by_size_desc
  by_name
  by_modified
  by_kind
  by_issue_severity

TieBreakerPolicy
  node_ref
  normalized_display_name
  stable_parent_order
  path_sort_key

PageCursor
  opaque_token
  snapshot_id
  index_version
  query_fingerprint
  position_anchor
  expires_or_invalidates_on_rescan
```

Layer rules:

- `fs_usage_core` owns sort, tie-breaker, cursor, and query identity vocabulary;
- `fs_usage_engine` owns index construction, cursor validation, stale cursor
  errors, and deterministic tie-breakers;
- `fs_usage_pdu` may preserve raw child position as diagnostic evidence, but it
  must not expose pdu child order as product order;
- protocol DTOs expose opaque cursors and sort/filter descriptors, not pdu
  vector offsets;
- Flutter never computes page order by sorting cached full-tree rows;
- destructive flows use `NodeRef` and current validation, not page position.

Contract tests:

- two pdu trees with identical nodes but different child order produce the same
  engine page order for the same sort policy;
- equal-size siblings have deterministic tie-breakers;
- cursor from an old `index_version` returns stale cursor or resync required;
- pdu `par_sort_by` is not called by production `PduTreeConverter`;
- filter/search/top queries never page by pdu vector offsets;
- selected row and cleanup queue survive page refresh through `NodeRef`, not row
  index.

### Wide Directory And Memory Shape Semantics

pdu is fast partly because it uses simple in-memory tree building. That is good
for raw scan speed, but it means Clean Disk must own memory budgets and page
large results through its read model.

Source-level facts:

- `FsTreeBuilder` calls `read_dir(path)` and collects all successful child
  `file_name()` values into a `Vec`;
- only after that collection does `TreeBuilder` turn child names into parallel
  recursive work with Rayon `into_par_iter`;
- every returned pdu node stores a `Vec<DataTree<...>>` of its returned children;
- pdu does not stream nodes out of traversal;
- pdu `max_depth` reduces returned tree shape, but it still traverses deeper
  descendants to aggregate size;
- pdu library does not expose backpressure, page size, memory budget, or a
  "stop after N nodes" hook.

Implication:

```text
wide directory -> temporary Vec of all child names
returned tree -> Vec children at every returned node
adapter conversion -> pdu DataTree and NodeArena can overlap in memory
Flutter must never receive the whole tree
```

Top 3 policies:

1. Accept final pdu tree for MVP, but bound and measure conversion/index memory
   - 🎯 9 🛡️ 8 🧠 7, roughly 900-2200 LOC.
   Accepted. Works with current pdu and keeps MVP fast. Requires scan budgets,
   memory metrics, compact arena, and paginated queries.
2. Fork/upstream pdu visitor/streaming node API before MVP - 🎯 6 🛡️ 8 🧠 9,
   roughly 3000-9000 LOC.
   Better long-term memory profile, but too expensive before proving real
   budget failure. Keep contracts ready for `streaming_nodes` capability.
3. Use pdu `max_depth` to avoid memory pressure for normal scans - 🎯 4 🛡️ 5
   🧠 4, roughly 300-900 LOC.
   Rejected as a product default. It reduces returned children, but does not
   provide true lazy expansion and can hide cleanup candidates from the read
   model.

Accepted memory contract:

```text
PduRawScanMetrics
  child_name_vec_peak_estimate
  pdu_tree_node_count
  returned_tree_max_depth
  deepest_reported_issue_depth
  path_join_count_estimate
  path_length_issue_count
  pdu_scan_peak_rss
  conversion_peak_rss
  arena_node_count
  index_build_peak_rss
  dropped_pdu_tree_at

ScannerBackendCapabilities
  final_tree = true
  streaming_nodes = false
  bounded_memory = no_strong_guarantee
  true_traversal_cutoff = false
  stack_depth_guard = false
```

Layer rules:

- `fs_usage_pdu` must record scan/conversion memory and node counts where
  practical;
- `fs_usage_engine` owns compact `NodeArena` and indexes, not pdu's nested Vec
  tree;
- protocol exposes pages, top lists, summaries, search results, and details, not
  a full tree dump;
- resource profiles may limit pdu threads, target count, concurrent sessions,
  and metadata enrichment lanes, but cannot force pdu to stream nodes;
- if wide-tree fixtures exceed the accepted memory budget, revisit upstream
  visitor/streaming API or helper-process isolation before adding more indexes.

### Wide Directory Budget And Degrade Contract

The wide-directory risk is not only "large final tree". pdu creates temporary
child-name vectors before recursive work and then returns a nested tree. Product
code needs a budget response that is explicit and testable.

Source-level memory phases:

```text
read_dir collection
  -> temporary Vec<OsStringDisplay> child names for one directory
rayon recursion
  -> many subtrees can exist before parent DataTree is built
DataTree final result
  -> nested Vec children for returned nodes
conversion
  -> pdu DataTree plus NodeArena can overlap
index build
  -> top/search/path/issue indexes allocate additional structures
```

Accepted budget vocabulary:

```text
MemoryBudgetClass
  normal
  high
  critical
  exceeded

WideDirectoryEvidence
  directory_ref
  child_name_count_estimate
  child_name_bytes_estimate
  collection_phase = observed | estimated | unknown
  mitigation = none | throttled_threads | deferred_indexes | failed_budget

PduMemoryPressurePolicy
  allow_scan
  pause_new_sessions
  defer_secondary_indexes
  fail_before_conversion
  fail_after_backend_walk
```

Top 3 budget strategies:

1. Measure and gate phases, then degrade optional indexes first - 🎯 9 🛡️ 9
   🧠 7, roughly 1000-2600 LOC.
   Accepted. Keep pdu fast for normal scans, but make memory pressure visible
   and stop before the UI or daemon becomes unhealthy.
2. Trust OS memory and let pdu run without budget gates - 🎯 4 🛡️ 3 🧠 1,
   roughly 100-300 LOC.
   Rejected. It can reproduce UI stalls or daemon OOM on wide trees.
3. Force low `max_depth` as memory protection - 🎯 4 🛡️ 5 🧠 3, roughly
   200-700 LOC.
   Rejected as product default. It reduces returned shape but does not give true
   lazy expansion and makes the read model incomplete by policy.

Layer rules:

- `fs_usage_pdu` owns observed/estimated pdu memory metrics and reports them as
  adapter evidence;
- `fs_usage_engine` owns budget decisions such as deferring secondary indexes or
  failing a scan with `BudgetExceeded`;
- `fs_usage_core` owns stable budget/quality vocabulary only, not RSS collection
  or pdu implementation details;
- `clean_disk_server` owns process health policy and can pause new scans when
  memory pressure is high;
- Flutter receives scan phase and degraded-quality events, never raw pdu memory
  internals;
- if budget is exceeded after pdu returned a tree but before indexes are ready,
  query APIs remain unavailable or degraded. They must not expose a half-built
  read model as complete.

Contract rule:

```text
Memory pressure changes availability and confidence.
It never silently changes scan truth.
```

### Wide Directory Observability Gap Boundary

pdu's wide-directory memory risk is partly observable and partly hidden. The
adapter can count final nodes and sample process memory, but pdu does not expose
a callback before/after each `read_dir` child-name collection. That makes exact
per-directory temporary allocation evidence impossible without an upstream hook
or fork.

Source-level facts from pdu 0.23.0:

- `FsTreeBuilder` collects successful `DirEntry::file_name()` values into one
  `Vec<OsStringDisplay>` for the current directory before parallel child work
  starts;
- `Info.children` is a `Vec<Name>`, not a lazy iterator or bounded producer;
- `TreeBuilder` consumes that `Vec` with `into_par_iter`;
- pdu `max_depth` is applied after `get_info(&path)`, so even hidden-by-depth
  descendants can create temporary child-name vectors during aggregation;
- if stored depth is exhausted, pdu still maps child builders, sums child sizes,
  and discards returned child nodes;
- final `DataTree.children()` cannot prove how large temporary child-name vectors
  were in truncated descendants;
- pdu exposes no memory watermark, child vector capacity, per-directory
  collection timing, or backpressure signal.

Top 3 observability strategies:

1. Use honest phase evidence: process RSS samples, final arena counts, reporter
   counts, synthetic fixture calibration, and estimated wide-directory evidence -
   🎯 9 🛡️ 9 🧠 7, roughly 900-2200 LOC.
   Accepted for MVP. It is not perfect, but it avoids lying and works without
   forking pdu.
2. Fork/upstream a visitor/collection hook that reports child vector size before
   recursion - 🎯 7 🛡️ 9 🧠 9, roughly 2500-7000 LOC.
   Future option if memory gates fail on real fixtures.
3. Treat final `DataTree` node counts as exact peak memory evidence - 🎯 3 🛡️ 3
   🧠 2, roughly 200-500 LOC.
   Rejected. It misses temporary wide-directory vectors and hidden-by-depth
   traversal work.

Accepted evidence contract:

```text
PduMemoryEvidence
  rss_samples
  pdu_tree_node_count
  arena_node_count
  final_child_count_by_returned_parent
  estimated_child_name_vec_peak
  estimate_confidence = observed | calibrated | inferred | unknown
  hidden_depth_allocation_risk
  budget_decision
```

Layer rules:

- `fs_usage_pdu` records what pdu exposes plus external process/resource samples;
- `fs_usage_engine` owns budget decisions and may defer secondary indexes,
  degrade query capabilities, or fail snapshot publication;
- `fs_usage_core` owns `MemoryEvidenceConfidence` and `BudgetDecision` value
  vocabulary, not pdu allocation details;
- protocol exposes user-facing quality/resource state, not raw RSS or pdu
  allocation internals;
- Flutter must show degraded/unavailable query states rather than rendering a
  partial arena as complete.

Contract tests:

- `max_depth=1` on a deep or wide tree records hidden allocation risk, not safe
  lazy loading;
- final pdu node count is not used as exact peak memory evidence;
- budget-exceeded after pdu traversal blocks `snapshot_ready` until indexes are
  complete or a degraded read model is explicitly published;
- memory evidence has confidence class and source;
- future streaming/visitor backend can satisfy the same `ScannerBackend` output
  without changing domain contracts.

### Deep Tree And Path Join Semantics

pdu recursion is simple and fast, but deep directory chains have different risks
from wide directories. A narrow tree with thousands of nested directories may
not allocate many sibling nodes, but it can stress recursion depth, path length,
and repeated `PathBuf` construction.

Source-level facts:

- `TreeBuilder::from` recursively maps every child into another `TreeBuilder`
  and calls `Self::from`;
- recursive work uses Rayon, but a single-child chain still behaves like a deep
  recursive traversal;
- `FsTreeBuilder.join_path` creates each child traversal path with
  `prefix.join(&name.0)`;
- pdu `max_depth` uses `saturating_sub(1)` to decide returned tree shape, but
  even at stored depth zero it still maps children and sums their sizes;
- pdu has no preflight for maximum path depth or maximum platform path length;
- path-length and too-deep traversal failures surface as filesystem errors such
  as `SymlinkMetadata`, not as a pdu-specific depth-risk event;
- pdu library has no stack-depth guard, depth budget, or iterative traversal
  mode.

Implication:

```text
deep chain -> recursive TreeBuilder calls
each child -> new PathBuf through prefix.join(name)
max_depth -> returned-shape control, not traversal-depth safety
path length failure -> ordinary scan issue evidence
```

Top 3 policies:

1. Treat deep-tree safety as adapter risk evidence and fixture-gated capability
   - 🎯 9 🛡️ 9 🧠 7, roughly 700-1800 LOC.
   Accepted. The pdu backend can be used, but deep-tree behavior must be tested,
   measured, and reported through capability/quality evidence.
2. Add engine-level hard max traversal depth for pdu by mapping to `max_depth`
   - 🎯 3 🛡️ 4 🧠 3, roughly 300-800 LOC.
   Rejected. pdu `max_depth` does not stop traversal, so it is not a real safety
   cutoff.
3. Fork/upstream an iterative traversal or cooperative depth cutoff before MVP
   - 🎯 5 🛡️ 8 🧠 9, roughly 3000-9000 LOC.
   Future option if synthetic or real deep trees prove stack/path risk is not
   acceptable. Not an MVP blocker without evidence.

Accepted deep-tree contract:

```text
PduRawScanMetrics
  returned_tree_max_depth
  deepest_reported_issue_depth
  path_join_count_estimate
  path_length_issue_count
  traversal_depth_cutoff_supported = false

ScannerBackendCapabilities
  true_traversal_cutoff = false
  stack_depth_guard = false
  path_length_preflight = platform_adapter_dependent
```

Layer rules:

- `fs_usage_pdu` must not claim deep traversal cutoff support;
- deep-tree fixtures are mandatory before broad release claims;
- platform preflight/enrichment may classify path-length and path-resolution
  errors, but pdu itself does not;
- if a deep-tree panic/stack failure is observed, it maps to backend failure and
  triggers fork/upstream/helper-process review;
- UI must show partial/degraded scan state for path-depth/path-length issues,
  not a clean empty subtree.

### Depth Policy Semantics

pdu `max_depth` is easy to misread. It does not stop traversal at that depth.
`TreeBuilder` still builds child subtrees to compute aggregate size, then drops
children from the returned `DataTree` when the stored-depth limit is reached.

This means pdu `max_depth` is:

```text
returned-tree-shape limit
not traversal cutoff
not faster shallow scan guarantee
not UI lazy expansion
not permission/error boundary
```

Clean Disk must split these product concepts:

```text
TraversalDepthPolicy
  how far the backend is allowed to walk

ProjectionDepthPolicy
  how much hierarchy is stored or returned in a specific view/projection

QueryExpansionPolicy
  how UI asks for more children from an existing snapshot/read model
```

Top 3 depth strategies:

1. Separate traversal, projection, and query expansion policies - 🎯 10 🛡️ 10
   🧠 7, roughly 700-1800 LOC.
   Accepted. It prevents pdu `max_depth` from becoming our lazy tree model and
   keeps future scanner backends free to support true traversal cutoffs.
2. Use pdu `max_depth` as UI lazy expansion - 🎯 3 🛡️ 3 🧠 3, roughly 200-600 LOC.
   Rejected. It throws away children while still scanning them, so the UI cannot
   expand without rescanning and cannot explain hidden errors clearly.
3. Always scan/store full tree and ignore projection depth - 🎯 7 🛡️ 7 🧠 5,
   roughly 400-1200 LOC.
   Acceptable for early local MVP if memory allows, but contract still needs
   projection/query separation for large scans.

Rules:

- pdu adapter maps `ProjectionDepthPolicy::StoredDepth` to pdu `max_depth`;
- if product needs true traversal cutoff, it must be a separate capability and
  pdu backend reports unsupported until we implement/fork/upstream it;
- `DepthTruncated` means "children not stored in this projection", not
  "children were not scanned";
- cleanup authority cannot target hidden-by-depth descendants without a current
  query/read-model entry and delete preflight.

### Stored Depth Boundary Contract

The exact pdu `max_depth` boundary is subtle and must be mapped deliberately.

Source-level facts:

- `TreeBuilder::from` calls `get_info(&path)` before applying the depth branch;
- it then computes `let max_depth = max_depth.saturating_sub(1)`;
- child builders receive this already-decremented `max_depth`;
- if the decremented value is greater than zero, pdu stores collected child
  `DataTree` nodes;
- if the decremented value is zero, pdu still recursively builds every child
  subtree, sums child sizes, and returns the current node with `children = []`;
- therefore pdu `max_depth = 0` and `max_depth = 1` both produce a root-only
  returned tree with full aggregate size;
- pdu `max_depth = 2` stores immediate children only. Those children can include
  aggregate size from deeper descendants that are not present in their
  `children` arrays.

Mapping rule:

```text
pdu max_depth N
  N <= 1 -> store root only, aggregate full traversed subtree
  N = 2  -> store root + direct children
  N = k  -> store descendants through depth k - 1 from root
```

Accepted domain/application vocabulary:

```text
StoredDepthRequest
  full
  root_only
  through_depth(depth_from_root)

StoredDepthEvidence
  requested_depth
  pdu_max_depth
  returned_max_depth
  hidden_descendants_possible
  aggregate_includes_hidden_descendants
```

Top 3 mapping strategies:

1. Product `StoredDepthRequest` mapped explicitly to pdu `max_depth` - 🎯 10
   🛡️ 10 🧠 5, roughly 300-900 LOC.
   Accepted. It hides pdu off-by-one behavior behind application vocabulary.
2. Expose pdu `max_depth` directly in protocol/UI - 🎯 3 🛡️ 3 🧠 1, roughly
   50-150 LOC.
   Rejected. It leaks backend semantics and invites lazy-expansion confusion.
3. Never use pdu `max_depth` - 🎯 7 🛡️ 8 🧠 2, roughly 100-300 LOC.
   Acceptable for early MVP if memory allows, but contracts still need the
   mapping for diagnostics, tests, and future resource modes.

Layer rules:

- `fs_usage_core` defines product depth vocabulary, not pdu numeric behavior;
- `fs_usage_engine` maps query/projection intent to `StoredDepthRequest`;
- `fs_usage_pdu` maps `StoredDepthRequest` to pdu `max_depth` and records
  `StoredDepthEvidence`;
- hidden descendants caused by stored-depth projection are not queryable current
  nodes and cannot be cleanup targets;
- parent aggregate size can include hidden descendants, so UI must not imply
  visible child rows sum to the parent total unless completeness evidence says
  so;
- tests must cover pdu `max_depth` values `0`, `1`, and `2`.

### Numeric Counter And Overflow Semantics

pdu `Bytes` and `Blocks` are `u64` newtypes. `DataTree::dir` aggregates child
sizes with ordinary `Size` addition. The built-in progress reporter stores
`items`, `total`, `errors`, `linked`, and `shared` in `AtomicU64` and uses
`fetch_add`.

For normal local disks this is fine, but Clean Disk should not expose backend
arithmetic as product truth.

Source-level numeric facts:

- pdu `Size` requires ordinary `Add`, `AddAssign`, `Sub`, `SubAssign`, `Sum`,
  and multiplication traits. It does not require checked arithmetic;
- pdu `Bytes` and `Blocks` wrap `u64`;
- `DataTree::dir` computes `inode_size + children.iter().map(size).sum()`;
- pdu hardlink dedupe subtracts `size * (number_of_links - 1)` from matching
  aggregate directories;
- built-in `ProgressAndErrorReporter` uses `AtomicU64::fetch_add` with relaxed
  ordering for item, total, error, linked, and shared counters;
- built-in `linked` progress adds `nlink`, not "one unique inode";
- pdu JSON, when enabled, serializes these numeric values as JSON numbers;
- pdu byte formatting is display-only and can lose exactness through unit
  formatting.

Top 3 numeric strategies:

1. Engine-owned checked/saturating counters with overflow evidence - 🎯 9 🛡️ 10
   🧠 6, roughly 500-1400 LOC.
   Accepted. Convert pdu values into `SizeFacts`/metrics through checked helpers.
   If any counter saturates or overflows, lower confidence and emit diagnostic
   evidence.
2. Reuse pdu `u64` values directly everywhere - 🎯 5 🛡️ 5 🧠 2, roughly
   100-300 LOC.
   Rejected. Easy, but it leaks backend arithmetic and makes web/protocol numeric
   precision unsafe.
3. Use arbitrary precision for all counters from day one - 🎯 6 🛡️ 9 🧠 8,
   roughly 1200-3200 LOC.
   Too heavy for MVP. Keep exact string DTOs and checked Rust conversion first.

Rules:

- pdu `Bytes::inner()` and `Blocks::inner()` are adapter input only;
- `fs_usage_pdu` converts pdu numeric values into engine numeric value objects
  at the adapter boundary;
- conversions use checked or saturating helpers and record saturation evidence;
- pdu progress counters are telemetry evidence, not authoritative final counts;
- pdu hardlink arithmetic is projection evidence, not reclaim accounting;
- web-facing exact byte sizes, counters, ids, cursors, and event sequences stay
  string-encoded;
- backend metrics may include saturation/overflow flags;
- UI must show unknown/degraded confidence rather than silently wrapping values.

Accepted numeric domain sketch:

```text
MeasuredQuantity
  value
  unit = bytes | blocks | count
  exactness = exact | saturated | overflowed | estimated
  source = pdu | platform | accounting | observed
  confidence

NumericEvidence
  raw_backend_value
  conversion_status
  saturation_limit
  evidence_ref
```

Adapter guardrails:

- no raw pdu `Bytes`, `Blocks`, `u64` counters, or formatted size strings cross
  the `fs_usage_pdu` public boundary;
- no pdu JSON numeric values become Clean Disk protocol DTO values;
- progress `total` can be lower or stale relative to final aggregate result and
  must be reconciled at scan completion;
- arithmetic failure in conversion lowers confidence or fails the backend
  cleanly. It must not wrap silently into smaller sizes.

### pdu Size Trait Anti-Corruption Boundary

pdu's `Size` trait is intentionally small and arithmetic-oriented. It is a good
fit for fast traversal, but a bad fit for product domain size facts. Clean Disk
must not try to make domain `SizeFacts`, accounting estimates, confidence-rich
values, or reclaim facts implement pdu `Size`.

Source-level facts:

- pdu `Size` requires `Debug`, `Default`, `Clone`, `Copy`, ordering, ordinary
  `Add`, `AddAssign`, `Sub`, `SubAssign`, `Sum`, and multiplication helpers for
  integer RHS values;
- pdu `Size` has an associated `Inner` type and a `display(...)` method, which
  mixes arithmetic and CLI display capability at the trait level;
- pdu built-in `Bytes` and `Blocks` are `u64` newtypes and derive ordinary
  arithmetic through `derive_more`;
- `Bytes` can mean apparent bytes or Unix allocated bytes depending on the
  selected `GetSize` implementation, so the pdu type alone is not enough
  semantic evidence;
- `Blocks` is a count and displays as a plain `u64`, not bytes;
- pdu `Size` values are copied freely through traversal, progress counters,
  `DataTree`, hardlink code, reflection, and JSON diagnostics;
- pdu does not encode confidence, platform source API, sparse-file sensitivity,
  shared-extent caveats, overflow status, redaction class, or reclaim authority
  in the size type itself.

Top 3 size-type strategies:

1. Use pdu `Bytes`/`Blocks` only inside `fs_usage_pdu`, then convert to
   engine-owned `SizeFacts` - 🎯 10 🛡️ 10 🧠 5, roughly 400-1100 LOC.
   Accepted. It keeps pdu traversal fast and keeps product semantics in our
   domain value objects.
2. Implement pdu `Size` for Clean Disk `SizeFacts` - 🎯 3 🛡️ 3 🧠 7, roughly
   900-2500 LOC.
   Rejected. It would force product facts into `Copy` arithmetic/display
   semantics and would make pdu callbacks carry too much domain meaning.
3. Wrap pdu `Bytes` in a product newtype and pass that through pdu traversal -
   🎯 5 🛡️ 5 🧠 6, roughly 600-1800 LOC.
   Rejected for MVP. It adds complexity while still inheriting pdu's unchecked
   arithmetic requirements and does not solve reclaim/accounting semantics.

Accepted boundary:

```text
pdu Bytes | pdu Blocks
  -> PduSizeValueMapper
  -> MeasuredQuantity
  -> SizeFacts

Never:
  SizeFacts implements pdu Size
  ReclaimEstimate implements pdu Size
  AccountingEvidence implements pdu Size
```

Layer rules:

- `fs_usage_pdu` is the only layer that mentions pdu `Size`, `Bytes`, `Blocks`,
  or pdu `DisplayFormat`;
- `fs_usage_core` owns `SizeFacts`, `MeasuredQuantity`, `MeasurementUnitEvidence`,
  `SizeConfidence`, and reclaim/accounting value objects;
- `fs_usage_engine` performs checked conversion and confidence assignment before
  writing arena records or indexes;
- `clean_disk_protocol` serializes exact numeric facts with explicit units,
  measurement kind, confidence, and source evidence. It never serializes pdu
  newtype names;
- Flutter receives product DTOs, never pdu `Bytes`, pdu `Blocks`, pdu display
  strings, or pdu `Quantity`.

Contract tests:

- no domain or protocol type implements pdu `Size`;
- pdu `Bytes` in apparent mode and pdu `Bytes` in Unix allocated mode produce
  different `measurement_kind` values;
- pdu `Blocks` cannot map into byte fields without explicit conversion
  evidence;
- `SizeFacts` has no dependency on `parallel_disk_usage`;
- pdu display output is never used as a machine-readable size value.

### CLI Helper Mutation And Panic Semantics

pdu exposes useful helper methods on `DataTree`, but several of them are
CLI/reporting helpers, not product data model operations.

Source-level facts:

- `DataTree::par_retain` removes child nodes but does not recompute parent
  aggregate sizes;
- CLI `par_cull_insignificant_data` uses `f32` ratio against root size and then
  retains/removes nodes for visualization;
- `DataTree::par_sort_by` uses `sort_unstable_by`, so equal-size ordering is not
  deterministic;
- `HardlinkAware::deduplicate` mutates `DataTree` by subtracting duplicated sizes
  using path-prefix matching;
- hardlink summary panics if detected paths exceed recorded `nlink`, which can
  happen only if assumptions are broken, but product code must still contain
  the blast radius.

Top 3 helper-use policies:

1. Do not call pdu CLI helper mutations in product path - 🎯 10 🛡️ 10 🧠 5,
   roughly 300-900 LOC for adapter guards and tests.
   Accepted. Product query behavior lives in `ReadModelIndexes`, and hardlink
   adjustment lives in confidence-tagged projections.
2. Use pdu sort/cull/deduplicate before converting to `NodeArena` - 🎯 4 🛡️ 4
   🧠 3, roughly 200-800 LOC.
   Rejected. It mixes visualization decisions, path-prefix hardlink logic, and
   mutable aggregate sizes into durable product state.
3. Call pdu helper methods only behind diagnostic feature gates - 🎯 7 🛡️ 7 🧠 6,
   roughly 600-1600 LOC.
   Acceptable later for fixture comparison, but never for product truth.

Rules:

- sorting, culling, pagination, filtering, and top lists are engine indexes;
- pdu `par_sort_by`, `par_retain`, and CLI culling are not product query logic;
- pdu hardlink deduplication is not the primary tree;
- pdu hardlink summary is diagnostic/evidence and must run behind panic
  containment if used;
- any pdu panic in scan/conversion maps to `ScanQuality::FailedBackend` and does
  not kill the daemon.

## Layer Responsibilities

### pdu Module Ownership Matrix

| pdu module/type | What it really is | Our layer allowed to know it | Product rule |
| --- | --- | --- | --- |
| `fs_tree_builder::FsTreeBuilder` | filesystem traversal entrypoint | `fs_usage_pdu` only | maps from `BackendScanRequest` |
| `tree_builder::TreeBuilder` | generic recursive tree builder | `fs_usage_pdu` only | do not model in domain |
| `data_tree::DataTree` | private pdu tree container | `fs_usage_pdu` only | convert and drop |
| `data_tree::Reflection` | inspection/JSON intermediate | fixture/diagnostic adapter only | not protocol or persistence |
| `reporter::Reporter` | synchronous event callback | `fs_usage_pdu` only | custom reporter batches events |
| `reporter::Event` | pdu raw event enum | `fs_usage_pdu` only | map to `ScanEvent`/`ScanIssue` |
| `get_size::*` | metadata-to-size strategies | `fs_usage_pdu` only | map from `SizePolicy` |
| `device::DeviceBoundary` | pdu traversal option | `fs_usage_pdu` only | map from `BoundaryPolicy` with platform capability |
| `hardlink::*` | Unix hardlink evidence/dedupe helpers | `fs_usage_pdu` only | map to evidence, not reclaim truth |
| `json_data::*` | pdu CLI JSON shape | fixtures/diagnostics only | never public product DTO |
| `visualizer::*` | CLI rendering | never | not app UI model |
| `app::*`, `args::*`, `runtime_error::*` | CLI host behavior | never in daemon adapter | do not enable `cli` feature |

The dependency direction is therefore:

```text
fs_usage_core
  <- fs_usage_engine
    <- fs_usage_pdu
    <- fs_usage_platform
    <- fs_usage_accounting
    <- fs_usage_cleanup
      <- clean_disk_server
        <- Flutter client adapters
```

`fs_usage_pdu` may depend inward on `fs_usage_engine` and `fs_usage_core`.
Neither `fs_usage_core` nor `fs_usage_engine` may depend outward on pdu.

## Target And Root Normalization Contract

pdu library scans one `FsTreeBuilder.root` at a time. The pdu CLI adds extra
host behavior around that:

- no args means scan `"."`;
- multiple args become children under a fake root;
- the fake root is initially an empty string because pdu hardlink dedupe relies
  on prefix matching, then CLI renames it to `(total)`;
- overlapping roots are removed only when CLI hardlink dedupe is enabled;
- missing roots can still produce a zero-size pdu tree if not preflighted.

Source-level overlap facts:

- pdu CLI calls overlap removal only when Unix hardlink dedupe is enabled and
  there is more than one CLI path;
- overlap removal mutates the argument vector before `Sub::run`;
- overlap detection first checks `symlink_metadata(path)` and accepts only real
  directories where metadata is directory and not symlink;
- only those real directories are canonicalized and compared;
- canonicalization failure, files, symlink directories, missing paths, and
  unreadable paths are silently excluded from overlap removal;
- duplicate canonical paths keep the first argument and remove later arguments;
- parent/subtree canonical paths prefer the containing tree and remove the
  subtree argument;
- comparison is pairwise over canonicalized arguments and returns indices to
  remove;
- this behavior exists to protect pdu hardlink dedupe assumptions, not to model
  product target intent.

Source-level multi-root pipeline facts:

- `Sub::run` scans every CLI root by creating one `FsTreeBuilder` per path;
- if no CLI path is provided, `Sub::run` recursively calls itself with `"."`;
- when there is one root, pdu keeps that root tree directly;
- when there are multiple roots, pdu creates a fake parent with name `""` and
  default size, then inserts each root tree as a child;
- the fake root exists so pdu hardlink dedupe can use empty-string prefix
  matching across all paths;
- multi-root fake trees are passed through `into_par_retained(|_, depth| depth +
  1 < max_depth)`, so the CLI depth budget is shifted by the synthetic parent;
- after scanning, pdu destroys the progress reporter before culling, sorting,
  hardlink dedupe, JSON conversion, or visualizer output;
- pdu then applies CLI `min_ratio` culling, unstable size sorting unless
  `--no-sort`, hardlink dedupe mutation, and finally renames the fake root to
  `"(total)"`;
- JSON output converts the final CLI-shaped tree to UTF-8 reflection and may
  include pdu hardlink detail/summary records.

Clean Disk must not inherit these CLI semantics.

Target normalization belongs to `fs_usage_engine` and platform preflight, not to
`fs_usage_pdu`.

Top 3 target strategies:

1. Engine-owned normalized targets and explicit synthetic root - 🎯 10 🛡️ 10
   🧠 7, roughly 900-2200 LOC.
   Accepted. `ScanTargetSet` owns input order, duplicate policy, subtree policy,
   synthetic root identity, and target diagnostics before pdu runs.
2. Let pdu CLI-style multi-root behavior shape our model - 🎯 3 🛡️ 4 🧠 3,
   roughly 200-600 LOC.
   Rejected. It leaks `(total)` and hardlink-prefix behavior into product
   identity.
3. One scan session per selected root with no synthetic root - 🎯 7 🛡️ 8 🧠 5,
   roughly 600-1600 LOC.
   Useful for some workflows, but worse for one combined UI tree and aggregate
   progress. Keep as a query/view option over normalized roots.

Domain/application contract:

```text
ScanTargetSet
  requested_targets
  normalized_targets
  rejected_targets
  overlap_policy
  synthetic_root_kind
  target_preflight_issues

NormalizedScanTarget
  target_id
  original_input
  canonical_identity
  display_path
  scan_path
  target_kind
  boundary_policy
  authority_scope
```

Rules:

- no target selected follows product default target policy, not pdu `"."`;
- missing target is rejected before pdu, not shown as a clean zero-size tree;
- duplicate target handling is explicit and recorded;
- subtree overlap handling is explicit and recorded;
- symlink target handling is explicit and recorded, not inherited from pdu CLI
  `is_real_dir`;
- canonicalization failure creates preflight evidence instead of silently
  excluding the target from overlap checks;
- parent/subtree decisions preserve user intent through diagnostics and visible
  target status;
- synthetic roots have `SyntheticRootKind`, never pdu string names;
- scan rows generated from synthetic roots are not cleanup targets;
- pdu root names are raw adapter evidence, not product identity;
- multi-root aggregation is engine-owned, not pdu CLI-owned.
- pdu CLI depth shifting for fake roots is not reused. Product depth/query
  semantics are defined by `ReadModelIndexes` and `TreeProjectionPolicy`;
- pdu CLI cull/sort/dedupe pipeline is not reused for target aggregation.

Accepted target policy vocabulary:

```text
TargetOverlapPolicy
  keep_all_with_diagnostics
  keep_containing_root
  reject_overlapping_targets
  split_as_independent_targets

TargetPreflightIssue
  missing
  inaccessible
  duplicate
  overlaps_parent
  overlaps_child
  canonicalization_failed
  symlink_policy_required
  unsupported_target_kind

SyntheticRootKind
  none
  multiple_targets
  comparison_snapshot
  filtered_view
```

Layer rules:

- `fs_usage_core` owns target policy/value vocabulary only;
- `fs_usage_engine` owns target normalization, ordering, overlap diagnostics,
  synthetic root identity, and target preflight state;
- `fs_usage_platform` owns canonicalization, symlink/root kind checks, and
  authority evidence;
- `fs_usage_pdu` receives already-normalized `NormalizedScanTarget` values and
  never mutates the target set;
- cleanup authority always points to a concrete current target/node identity,
  never a synthetic root or pdu fake root;
- target normalization is deterministic and tested independently from pdu.

Adapter implication:

```text
for each NormalizedScanTarget:
  run one FsTreeBuilder
  map root DataTree into target root NodeArenaRecord

if more than one target:
  engine creates synthetic root record
  pdu never creates product synthetic identity
```

Target execution plan:

```text
ScanTargetSet
  -> TargetPreflight
  -> TargetOverlapDetector
  -> TargetExecutionPlan
  -> one PduTargetRunner per normalized target
  -> EngineSyntheticRootBuilder when the product view needs aggregation
```

`TargetExecutionPlan` records whether targets are scanned as one combined
session, independent root sessions, or a comparison/snapshot view. It is product
state, not pdu CLI host state.

Target fixture requirements:

- no target selected uses product default target policy, not pdu `"."`;
- missing target becomes `InvalidTarget`;
- duplicate path preserves one target plus diagnostic;
- parent plus child path follows explicit overlap policy;
- multi-root output has product synthetic root id and non-deletable flag;
- pdu `(total)` never appears in protocol, persistence, or UI state.
- multi-root depth/query behavior does not change when a synthetic root is
  present;
- target order is the normalized product order, not pdu post-sort order;
- pdu CLI `min_ratio`, `top_down`, visualizer direction, and byte format never
  affect target identity or read-model shape.

### Target Canonicalization Authority Contract

pdu CLI overlap removal uses canonical paths as a hardlink-dedupe safety
shortcut. It is not a product target authority model.

Source-level facts from pdu 0.23.0:

- `remove_overlapping_paths` is in pdu `app`, so it is CLI host behavior;
- it is called only when Unix hardlink dedupe is enabled and there is more than
  one CLI file argument;
- `is_real_dir` uses `symlink_metadata` and accepts only directories that are
  not symlinks;
- accepted real directories are canonicalized with `std::fs::canonicalize`;
- files, symlink directories, missing targets, inaccessible targets, and
  canonicalization failures are represented as `None` and skipped by the overlap
  algorithm;
- duplicate canonical paths remove the later argument;
- parent/subtree overlaps remove the subtree argument, regardless of whether the
  user intentionally selected both;
- the function mutates the CLI argument vector by index and does not emit a
  product diagnostic;
- pairwise comparison is O(n^2), which is fine for CLI args but not a generic
  scalable target model.

Accepted authority contract:

```text
TargetCanonicalizationEvidence
  requested_target_id
  original_input_ref
  canonical_path_ref
  canonicalization_state = resolved | failed | not_applicable | policy_blocked
  root_kind = directory | file | symlink | missing | inaccessible | unsupported
  overlap_state = none | duplicate | parent | child | unknown
  user_intent_preserved = true
  source = platform_preflight
```

Top 3 canonicalization strategies:

1. Platform preflight plus engine overlap policy - 🎯 10 🛡️ 10 🧠 7, roughly
   900-2200 LOC.
   Accepted. Canonicalization is evidence. Engine policy decides whether to keep,
   reject, merge, or display overlapping targets.
2. Reuse pdu `remove_overlapping_paths` behavior - 🎯 3 🛡️ 4 🧠 2, roughly
   100-300 LOC.
   Rejected. It silently drops targets, ignores non-real-dir cases, and is tied
   to CLI hardlink dedupe.
3. Do no canonicalization before scan - 🎯 5 🛡️ 5 🧠 1, roughly 50-150 LOC.
   Too weak. It can double-count targets, create confusing synthetic roots, and
   make cleanup/recommendation intent ambiguous.

Layer rules:

- `fs_usage_platform` owns canonicalization and current target-kind evidence;
- `fs_usage_engine` owns overlap policy, target diagnostics, and execution plan;
- `fs_usage_pdu` receives normalized targets and never removes targets;
- canonical path is evidence, not a stable `NodeId` by itself;
- canonicalization failure is visible degraded preflight state, not silent
  exclusion;
- user intent survives normalization. If a target is merged, rejected, or
  shadowed by a parent target, the final `TargetScanOutcome` records why;
- cleanup authority never comes from canonicalization alone. Delete preflight
  must revalidate current path identity.

Data/infrastructure mapping:

```text
PlatformTargetPreflight
  -> TargetCanonicalizationEvidence
  -> TargetOverlapDetector
  -> TargetExecutionPlan

PduTargetRunner
  -> consumes one NormalizedScanTarget
  -> never calls pdu remove_overlapping_paths
```

Contract tests:

- duplicate canonical paths preserve the first target only through explicit
  product policy and diagnostic;
- parent plus child target follows `TargetOverlapPolicy`;
- symlink directory targets require explicit symlink policy instead of pdu
  `is_real_dir` behavior;
- canonicalization failure creates `TargetPreflightIssue`;
- `fs_usage_pdu` production imports fail if pdu `app::overlapping_arguments` is
  imported.

## Traversal And Boundary Semantics

pdu traversal is intentionally simple and fast. Our product contract must add
the missing semantics around it.

Source-level traversal facts:

- pdu calls `symlink_metadata`, so symlink entries are measured as links and are
  not followed;
- pdu calls `read_dir` only when `metadata.is_dir()` and the device boundary
  check allows traversal;
- when `DeviceBoundary::Stay` rejects a child because device id differs, pdu
  returns a leaf-like node with measured size and no children, without emitting
  `EncounterError`;
- on non-Unix, pdu's internal `DeviceId` is `()`, which effectively disables
  cross-device detection;
- `read_dir` entry order is filesystem/OS dependent, and pdu `TreeBuilder`
  processes child names through Rayon;
- pdu reports only three error operations: `SymlinkMetadata`, `ReadDirectory`,
  and `AccessEntry`;
- `ReadDirectory` error returns the directory's own measured size with empty
  children;
- `AccessEntry` error skips that child entirely;
- `max_depth` stores fewer children but still aggregates deeper sizes into the
  parent.

Accepted traversal contract:

```text
TraversalPolicy
  symlink_policy
  boundary_policy
  max_stored_depth
  inaccessible_policy
  ordering_policy

TraversalEvidence
  symlink_not_followed
  boundary_skipped
  children_unknown
  order_unstable
  depth_truncated
```

Top 3 traversal strategies:

1. pdu traversal plus explicit engine evidence flags - 🎯 9 🛡️ 9 🧠 7,
   roughly 1200-3000 LOC.
   Accepted. Keep pdu fast, but `PduIssueMapper` and platform preflight mark
   boundary skips, symlink policy, unreadable children, and depth truncation.
2. Treat pdu tree as complete if no `EncounterError` occurred - 🎯 3 🛡️ 3 🧠 2,
   roughly 100-300 LOC.
   Rejected. Cross-device skip and `max_depth` can hide children without an
   error event.
3. Fork pdu to emit every traversal decision - 🎯 6 🛡️ 8 🧠 9, roughly
   3000-8000 LOC.
   Useful later if evidence gaps become product blockers, but too expensive for
   MVP.

Rules:

- symlink nodes require platform metadata enrichment before details/delete UI
  claims file kind or target behavior;
- boundary-skipped nodes must be represented as `children_unknown` or
  `boundary_skipped`, not "empty folder";
- directory read failure must lower scan quality for that subtree;
- `AccessEntry` must be counted as skipped child evidence;
- UI sorting and stable order must come from engine indexes, not pdu/read_dir
  order;
- `max_depth` is a stored-depth limit, not lazy loading and not proof that
  omitted children do not exist;
- pdu `DeviceBoundary::Stay` is only enabled when platform capability proves the
  device id is meaningful.

Adapter mapping:

| pdu traversal behavior | Engine mapping | UI meaning |
| --- | --- | --- |
| symlink measured through `symlink_metadata` | `NodeKindState::NeedsEnrichment` plus symlink policy evidence | link itself, not target scan |
| `same_device == false` | `ScanIssue::BoundarySkipped` or node evidence when detectable | children intentionally not scanned |
| `ReadDirectory` error | `ScanIssue::DirectoryReadFailed` | subtree incomplete |
| `AccessEntry` error | `ScanIssue::DirectoryEntryAccessFailed` | at least one child skipped |
| `max_depth == 0` child aggregation | `TraversalEvidence::DepthTruncated` | size includes hidden descendants |
| read_dir/Rayon order | engine stable sort/index | UI order deterministic |

### Device Boundary And Mount Capability Contract

pdu's device boundary support is intentionally small:

- `DeviceBoundary::Cross` disables boundary checks by setting `root_dev = None`;
- `DeviceBoundary::Stay` stats the root once before traversal and stores its
  device id;
- during each node visit, pdu compares the current metadata device id with the
  root device id;
- when a directory is on a different device, pdu records the node's measured size
  but does not call `read_dir`;
- this cross-device skip emits no dedicated reporter event and no error;
- on Unix, pdu `DeviceId` is `metadata.dev()`;
- on non-Unix, pdu `DeviceId` is `()`, so every node appears to be on the same
  device;
- pdu CLI rejects `--one-file-system` on non-Unix as unsupported, but the library
  type still exists;
- pdu CLI HDD auto-thread detection has separate mount-point logic through
  `sysinfo`, but that is resource policy, not traversal boundary policy.

Product contract:

```text
BoundaryPolicy
  cross_all
  stay_on_target_volume
  stay_on_selected_volume_group
  platform_default

BoundaryCapability
  device_identity_supported
  mount_table_supported
  network_mount_detection_supported
  cloud_provider_boundary_supported
  confidence

BoundaryEvidence
  root_volume_identity
  node_volume_identity
  boundary_decision
  skipped_children_state
  source = pdu_dev | platform_mount_table | platform_metadata | unknown
```

Top 3 boundary strategies:

1. Platform-owned boundary model plus pdu `DeviceBoundary` adapter - 🎯 9 🛡️ 9
   🧠 7, roughly 1000-2600 LOC.
   Accepted. pdu can enforce a fast Unix same-device check, but product quality,
   capabilities, UI wording, and remote/headless policy come from our boundary
   model.
2. Expose pdu `DeviceBoundary` directly as product option - 🎯 4 🛡️ 5 🧠 2,
   roughly 100-300 LOC.
   Rejected. It leaks Unix/non-Unix behavior and hides skipped directories.
3. Always use `DeviceBoundary::Cross` and solve boundaries later - 🎯 6 🛡️ 6
   🧠 3, roughly 100-300 LOC.
   Acceptable only as an explicit MVP fallback. It can accidentally scan mounted
   network/removable/provider trees and surprise users.

Rules:

- boundary policy is selected by application/engine, not pdu CLI flags;
- pdu `DeviceBoundary::Stay` may be used only when `BoundaryCapability` says the
  backend can enforce it on the current platform;
- a cross-device directory with no children is `boundary_skipped`, not empty;
- pdu does not tell us which nodes were skipped unless adapter/platform evidence
  correlates metadata device ids with read-model paths;
- boundary evidence must be attached before cleanup/recommendation logic trusts
  subtree completeness;
- network, FUSE, cloud, container, and removable volumes are platform boundary
  concerns, not pdu concepts;
- resource decisions such as HDD thread limiting are separate from traversal
  boundary decisions.

Data/infrastructure mapping:

```text
PduTargetRunner
  -> chooses pdu DeviceBoundary from BoundaryPolicy + BoundaryCapability
  -> records root device evidence

PduMetadataTapRecorder
  -> records node device evidence when available
  -> lets PduBoundaryEvidenceStore correlate different-device nodes

PduTreeConverter
  -> maps correlated boundary skips to ChildCompleteness::BoundarySkipped
  -> never treats boundary-skipped empty children as complete empty directories
```

Domain/application mapping:

- `BoundaryPolicy` belongs to `fs_usage_core`;
- `BoundaryCapability` and `BoundaryEvidence` are scanner/platform evidence;
- `VolumeIdentity` is platform-specific and opaque;
- `ScanQuality` uses boundary evidence when deciding whether a subtree is
  complete, partial, or intentionally out of scope;
- UI can show "not scanned because outside selected volume" only when evidence
  supports it.

### Device Boundary Observability Contract

pdu can enforce a same-device rule on Unix, but it does not make the decision
observable enough for product semantics.

Source-level facts from pdu 0.23.0:

- `FsTreeBuilder` computes `same_device` from `root_dev` and the current node's
  metadata;
- if `same_device == false`, pdu still records the node size and returns
  `Info { size, children: Vec::new() }`;
- this path does not call `read_dir`;
- this path does not emit `EncounterError`;
- `DataTree` receives only name, aggregate size, and children, so the boundary
  decision is lost unless the adapter captured it earlier;
- `RecordHardlinksArgument` exposes borrowed `path`, `stats`, and measured size
  for every successfully statted node, so our custom metadata tap can copy
  bounded device evidence before pdu drops it;
- the pdu hardlink recorder `Result` is ignored by `FsTreeBuilder`, so the tap
  cannot use errors for control flow or backpressure;
- on non-Unix, pdu internal `DeviceId` is `()`, so the library cannot honestly
  prove same-device enforcement by itself.

Accepted contract:

```text
PduBoundaryDecisionEvidence
  target_ref
  path_evidence
  root_volume_evidence
  node_volume_evidence
  same_device_state = same | different | unknown | unsupported
  pdu_traversal_decision = traversed | skipped_by_boundary | unknown
  evidence_source = pdu_metadata_tap | platform_restat | capability_fallback
  confidence
```

Top 3 observability strategies:

1. Metadata tap plus platform restat fallback - 🎯 9 🛡️ 9 🧠 7, roughly
   900-2400 LOC.
   Accepted. The pdu adapter captures cheap scan-time device hints through a
   custom `RecordHardlinks` implementation, then platform providers revalidate
   visible/details/delete nodes when current truth matters.
2. Platform restat only after pdu returns - 🎯 6 🛡️ 8 🧠 7, roughly
   1200-3600 LOC plus extra IO.
   Reliable, but slower and weaker for explaining why a child set was not
   scanned during the original traversal.
3. Trust pdu empty children as the boundary signal - 🎯 2 🛡️ 2 🧠 2, roughly
   100-300 LOC.
   Rejected. Empty children can mean file, symlink, empty directory, read error,
   depth projection, boundary skip, or deleted/growing path race.

Layer rules:

- domain owns `BoundaryPolicy`, `BoundaryDecision`, `ChildCompleteness`, and
  `ScanQuality`;
- application owns use cases that choose the requested boundary policy and react
  to degraded evidence;
- `fs_usage_pdu` owns `PduBoundaryDecisionEvidence` and converts it into engine
  evidence;
- `fs_usage_platform` owns current volume/mount/provider classification and
  delete-time revalidation;
- protocol DTOs expose only opaque boundary state and user-facing capability
  facts, never raw pdu device ids;
- Flutter may show boundary/skipped wording only after the backend marks the
  state as evidence-backed;
- if evidence is missing, map the node to `ChildCompleteness::Unknown`, not
  `BoundarySkipped`;
- boundary-skipped or boundary-unknown nodes cannot become cleanup authority
  without current identity and policy revalidation.

Adapter mapping:

```text
PduTargetRunner
  -> reads root volume evidence before running pdu
  -> passes root evidence into PduMetadataTapRecorder

PduMetadataTapRecorder
  -> copies bounded node volume evidence from RecordHardlinksArgument.stats
  -> compares it with root evidence when supported
  -> records same/different/unknown without affecting pdu traversal

PduBoundaryEvidenceStore
  -> correlates tap records to engine path/node evidence
  -> marks truncated or missing observations explicitly

PduBoundarySkipMapper
  -> maps different-device observed directories to BoundarySkipped
  -> maps missing/unsupported evidence to ChildrenUnknown
```

MVP rule:

```text
Use pdu DeviceBoundary::Stay only when the platform capability says same-device
evidence is meaningful. Otherwise either use DeviceBoundary::Cross with explicit
scope warning, or return a degraded capability that disables one-volume claims.
```

### Domain: `fs_usage_core`

The domain layer owns product vocabulary that should remain true if we replace
pdu.

Allowed:

- `ScanSessionId`
- `ScanSnapshotId`
- `NodeId`
- `NodeRef`
- `ScanTarget`
- `TraversalPolicy`
- `BoundaryPolicy`
- `HardlinkPolicy`
- `SizePolicy`
- `SizeFacts`
- `SizeMeasurementMode`
- `SizeConfidence`
- `ScanIssue`
- `ScanIssueReason`
- `ScanQuality`
- `PermissionState`
- `PathIdentityEvidence`
- `NodeKind`
- `SyntheticRootKind`
- `TraversalEvidence`

Forbidden:

- `parallel_disk_usage` imports
- `DataTree`
- `FsTreeBuilder`
- `Reporter`
- `Event::ReceiveData`
- `Event::EncounterError`
- `HardlinkAware`
- `OsStringDisplay`
- Rayon
- filesystem traversal APIs
- protocol DTOs
- Flutter/Dart concepts

Domain invariants:

```text
NodeRef always includes snapshot identity.
NodeId is opaque and not derived from path string alone.
Synthetic roots are queryable but not cleanup targets.
SizeFacts never mean "safe to reclaim" by default.
Partial scans are successful-but-degraded, not complete truth.
Delete authority requires current identity revalidation, never a scan row.
```

SOLID reading:

- SRP: domain changes only when product filesystem language changes.
- OCP: new scanner backends add adapters/capabilities, not domain branches.
- LSP: a scanner backend can be weaker, but must honestly satisfy
  `ScannerBackend` capability reporting.
- ISP: scanner, metadata, accounting, cleanup, and event ports stay separate.
- DIP: domain/application depend on traits and value objects, not pdu structs.

### Application: `fs_usage_engine`

Application owns orchestration, ports, read model, and use cases.

Core ports:

```text
ScannerBackend
MetadataProvider
VolumeProvider
AccountingProvider
TrashProvider
Clock
EventSink
```

Core application models:

```text
BackendScanRequest
BackendScanOutput
ScannerBackendCapabilities
ScanSessionState
ScanPhase
ScanPhaseEvent
ScanSnapshotDraft
NodeArenaWriter
ReadModelIndexes
ResourceProfile
ExecutionLane
ScanEvent
```

Read-model shape should be engine-owned:

```text
ScanSnapshotDraft
  snapshot_id
  roots
  arena
  issues
  capability_observations
  backend_metrics

NodeArenaRecord
  node_id
  parent_id
  name
  display_path_ref
  depth
  child_range
  size_facts
  node_kind_state
  issue_refs
  hardlink_refs
  metadata_state
  traversal_evidence_refs

ReadModelIndexes
  children_by_parent
  top_by_size
  search_index
  issue_index
  path_lookup_index
```

Important: `NodeArenaRecord` is not a pdu `DataTree` clone. It is an engine read
model optimized for paginated queries, stable node refs, and later metadata
enrichment.

`ScannerBackend` contract shape:

```text
ScannerBackend
  capabilities() -> ScannerBackendCapabilities
  scan(request, event_sink) -> Result<BackendScanOutput, ScanFailure>
```

`BackendScanRequest` should include:

```text
session_id
snapshot_epoch
target_set
traversal_policy
boundary_policy
size_policy
hardlink_policy
resource_profile
event_policy
```

`BackendScanOutput` should include:

```text
snapshot_draft
scan_issues
backend_metrics
capability_observations
phase_metrics
```

Application rules:

- pdu errors become `ScanIssue`, not fatal process errors by default.
- pdu `ReceiveData(size)` becomes throttled progress evidence, not one UI event
  per entry.
- pdu `DetectHardlink` becomes hardlink evidence, not reclaim truth.
- pdu `max_depth` must not be used for UI lazy expansion.
- sorting/filtering/search/top lists happen through engine indexes, not pdu
  `DataTree::par_sort_by` or CLI culling.
- cancellation starts as request-only for pdu-backed scans. The session can move
  to `cancelling`, discard late results by epoch, and report measured latency.
- daemon health, cancel, and query endpoints must stay responsive during scan.
- product scan completion is `snapshot_ready`, not pdu walk completion.
- conversion and index-build phases are visible through `ScanPhaseEvent`.

Policy-to-pdu option mapping:

| Engine policy | pdu field/helper | Gap to handle outside pdu |
| --- | --- | --- |
| `NormalizedScanTarget.scan_path` | `FsTreeBuilder.root` | target normalization and preflight before pdu |
| `SizePolicy::Apparent` | `GetApparentSize` | not allocated/reclaim bytes |
| `SizePolicy::AllocatedUnix` | `GetBlockSize` | Unix-only, confidence tagged |
| `SizePolicy::BlockCountUnix` | `GetBlockCount` | diagnostic only for UI unless explicitly requested |
| `BoundaryPolicy::Cross` | `DeviceBoundary::Cross` | still classify mount/provider separately |
| `BoundaryPolicy::StayOnDevice` | `DeviceBoundary::Stay` | weak/no guarantee on non-Unix |
| `HardlinkPolicy::Ignore` | `HardlinkIgnorant` | no dedupe evidence |
| `HardlinkPolicy::DetectUnix` | `HardlinkAware` | Unix-only, conflicts can be hidden by pdu |
| `TraversalPolicy::MaxStoredDepth` | `max_depth` | not lazy expansion |
| `ResourceProfile` | none | handled by `PduExecutionLane` |
| `EventPolicy` | none | handled by custom reporter/throttler |

### Infrastructure/Data: `fs_usage_pdu`

`fs_usage_pdu` is the only crate that may import `parallel_disk_usage`.

Internal modules:

```text
fs_usage_pdu/
  src/
    adapter/
      pdu_scanner_backend.rs
      pdu_execution_lane.rs
      pdu_scan_runner.rs
      pdu_target_runner.rs
      pdu_options_mapper.rs
      pdu_backend_capabilities.rs
      pdu_contract_fingerprint.rs
      pdu_raw_result.rs
    evidence/
      pdu_metadata_tap_recorder.rs
      pdu_metadata_tap_record.rs
      pdu_boundary_evidence_store.rs
      pdu_boundary_decision_evidence.rs
      pdu_same_device_observation.rs
      pdu_boundary_observability_summary.rs
    reporter/
      pdu_reporter.rs
      pdu_reporter_snapshot.rs
    hardlink/
      clean_disk_hardlink_recorder.rs
      pdu_hardlink_evidence_store.rs
    mapper/
      pdu_tree_converter.rs
      pdu_issue_mapper.rs
      pdu_hardlink_mapper.rs
      pdu_size_facts_mapper.rs
      pdu_boundary_capability_mapper.rs
      pdu_boundary_skip_mapper.rs
      pdu_boundary_observability_guard.rs
      pdu_same_device_evidence_mapper.rs
      pdu_metrics_mapper.rs
```

Responsibilities:

- exact-pin pdu and keep its feature set small.
- map `BackendScanRequest` to `FsTreeBuilder` options.
- reject or downgrade unsupported policy combinations before scan.
- run pdu through `PduExecutionLane`.
- implement a custom pdu `Reporter`.
- implement a product-owned hardlink recorder when hardlink evidence is enabled.
- copy bounded scan-time metadata and same-device observations through the
  metadata tap when the platform supports it.
- collect pdu events into bounded internal counters/batches.
- build a private `PduRawScanResult`.
- convert `DataTree` into `ScanSnapshotDraft`/`NodeArenaWriter`.
- map pdu errors to `ScanIssue`.
- map pdu boundary observations to `ChildCompleteness`, `ScanIssue`, and
  degraded scan quality without exposing raw device ids.
- map hardlink detections to `HardlinkEvidence`.
- record pdu version, feature set, option fingerprint, timings, and raw counts.
- drop pdu `DataTree` after conversion.

Private raw result:

```text
PduRawScanResult
  data_tree
  reporter_summary
  issue_samples
  hardlink_observations
  pdu_version
  pdu_feature_set
  pdu_options_fingerprint
  timings
  resource_profile_used
```

Adapter pipeline:

```text
PduScannerBackend::scan
  -> validate BackendScanRequest against PduBackendCapabilities
  -> PduOptionsMapper creates concrete pdu knobs
  -> PduExecutionLane selects bounded Rayon pool
  -> PduScanRunner executes FsTreeBuilder
  -> PduReporter snapshots counters/issues/hardlinks
  -> CleanDiskHardlinkRecorder snapshots hardlink conflicts/evidence
  -> PduRawScanResult joins DataTree + reporter snapshot + metrics
  -> PduTreeConverter writes NodeArena records
  -> PduIssueMapper writes ScanIssue records
  -> PduHardlinkMapper writes HardlinkEvidence records
  -> BackendScanOutput returns engine-owned snapshot draft
```

Forbidden:

- exposing pdu public types from `fs_usage_pdu` public API.
- returning pdu JSON to server/Flutter.
- using pdu path strings as delete authority.
- using pdu size as reclaim estimate.
- letting Flutter choose pdu thread count or raw pdu flags.
- calling `rayon::ThreadPoolBuilder::build_global` in product daemon code.

Execution rule:

```text
PduScannerBackend
  -> PduScanRunner
  -> PduExecutionLane
  -> rayon::ThreadPool::install(...)
  -> FsTreeBuilder
  -> PduRawScanResult
  -> PduTreeConverter
  -> ScanSnapshotDraft
```

`PduExecutionLane` belongs to infrastructure because Rayon is an execution
mechanism. `ResourceProfile` belongs to application because it is product
policy.

### Server, Protocol, And Flutter Data Boundary

The pdu adapter boundary does not stop at Rust crate visibility. The same
anti-corruption rule must hold across `clean_disk_server`, `clean_disk_protocol`,
and Flutter feature packages.

Accepted flow:

```text
parallel_disk_usage
  -> fs_usage_pdu private raw types
  -> fs_usage_engine ScanSnapshotDraft / NodeArena / ScanIssue
  -> clean_disk_protocol DTOs
  -> features/scan/data DTO mappers
  -> features/scan/application models and ports
  -> presentation stores and widgets
```

Forbidden flow:

```text
parallel_disk_usage
  -> clean_disk_protocol
  -> Flutter DTO
  -> Flutter domain/store
```

Protocol DTOs are versioned transport contracts. They may resemble the engine
read model, but they must never be pdu-shaped.

Initial protocol DTO families:

```text
ScanSessionDto
ScanSnapshotDto
ScanNodePageDto
ScanNodeDto
ScanNodeDetailsDto
ScanIssueDto
SizeFactsDto
ScannerCapabilitiesDto
ScanEventDto
ScanQueryDto
ScanPageCursorDto
```

Flutter scan feature layer ownership:

```text
features/scan/domain
  entity/value object names that the product uses

features/scan/application
  scan use cases, ports, query objects, view-facing application models

features/scan/data
  protocol DTOs, HTTP/WebSocket data sources, repository adapters, cache mappers

features/scan/presentation
  MobX stores, pages, view models, UI state
```

Rules:

- Flutter `domain` must not import protocol DTOs, HTTP clients, WebSocket clients,
  server route strings, pdu terms, or Rust crate names.
- Flutter `data` may know protocol DTOs and transport adapters, but must map them
  into application/domain models before stores/widgets see them.
- `clean_disk_protocol` may expose `backend_capabilities`, but not raw pdu option
  names as product settings.
- `ScanEventDto` is notification/invalidation evidence. Paged HTTP queries remain
  the source of row/details truth after reconnect or missed events.
- cached node pages are read-only UI convenience. They are never delete authority.
- delete preflight and cleanup plan DTOs must be current server/application output,
  not reconstructed from Flutter cached rows.

Top 3 client contract strategies:

1. Protocol DTOs plus Flutter repository mapper - 🎯 10 🛡️ 10 🧠 6, roughly
   900-2200 LOC.
   Accepted. It keeps pdu private, keeps Flutter domain clean, and lets protocol
   evolve through schema/version rules.
2. Share Rust/pdu-shaped structs directly into Flutter DTOs - 🎯 3 🛡️ 4 🧠 4,
   roughly 400-1200 LOC.
   Rejected. Fast initially, but pdu internals leak into UI, cache, tests, and
   cleanup safety.
3. Let Flutter store raw server JSON maps and interpret fields in stores - 🎯 2
   🛡️ 3 🧠 2, roughly 200-800 LOC.
   Rejected. It hides contract drift, breaks typed refactors, and makes large-tree
   UI bugs hard to isolate.

DTO evolution rules:

- every DTO envelope carries protocol version and schema-compatible unknown
  fields policy.
- exact byte counts, IDs, cursors, and event sequences are encoded as strings for
  web safety.
- enums have unknown/fallback variants in Rust and Dart.
- path display values are presentation data, not authority.
- route/cache state stores `NodeRef` and query descriptors, not pdu paths.

Failure mapping:

| pdu/source condition | Adapter result | Engine/user-facing meaning |
| --- | --- | --- |
| root preflight missing | `ScanFailure::InvalidTarget` before pdu | user must choose existing target |
| pdu `symlink_metadata` error on root | degraded/failed target depending preflight result | do not silently show clean zero-byte root |
| pdu `symlink_metadata` error in child | `ScanIssue::MetadataReadFailed` | partial scan |
| pdu `read_dir` error | `ScanIssue::DirectoryReadFailed` | directory size may include inode only |
| pdu `AccessEntry` error | `ScanIssue::DirectoryEntryAccessFailed` | child skipped |
| hardlink conflict hidden by pdu | uncertain hardlink evidence if detected by custom wrapper/spike | lower confidence |
| reporter overflow/drop due to budget | `ScanIssue::TelemetryTruncated` or backend metric | UI shows degraded evidence |
| pdu panic | session failure through panic boundary | daemon stays alive |
| cancellation requested | session `cancelling`, late result discarded | no instant cancel promise |

If a pdu fact cannot be proven, map it to lower confidence. Do not invent exact
truth to make the UI look cleaner.

## Target Identity Drift And Root Probe Boundary

pdu is optimized for traversal speed, not for proving that a scan target kept the
same identity across preflight, traversal, query, and cleanup review. This is a
normal filesystem race, but it must be explicit in our contracts.

Source-level facts:

- `FsTreeBuilder` comments that the root is inspected multiple times;
- with `DeviceBoundary::Stay`, pdu first calls `symlink_metadata(&root)` only to
  capture `root_dev`;
- later, `TreeBuilder::get_info` calls `symlink_metadata(path)` again for the
  root and for every visited path;
- pdu does not keep the first root metadata, inode/file id, ctime/change time,
  generation, birth time, volume identity, or platform-specific file reference;
- if the root is replaced between probes, pdu can still produce a tree named by
  the original path;
- pdu reports IO errors as traversal evidence, but it does not classify
  `target_replaced`, `target_moved`, `bookmark_stale`, `volume_changed`, or
  `authority_scope_changed`.

Product consequence:

```text
target path accepted by preflight
  does not mean pdu walked the same target identity.

pdu root DataTree returned
  does not mean the target identity is still current.

displayed scan row selected later
  does not authorize cleanup without live identity revalidation.
```

Top 3 identity-drift policies:

1. Target identity envelope around pdu scan - 🎯 10 🛡️ 10 🧠 7, roughly
   900-2400 LOC.
   Accepted. `fs_usage_engine` records preflight identity, pdu traversal
   evidence, post-scan identity probe, and delete-time revalidation as separate
   facts.
2. Trust pdu root path plus scan issues - 🎯 4 🛡️ 4 🧠 2, roughly 150-400 LOC.
   Rejected. It misses root replacement, stale security-scoped bookmark,
   remounted volume, symlink/reparse replacement, and cloud/network transitions.
3. Hold open OS handles for every scanned directory during the full scan -
   🎯 5 🛡️ 7 🧠 9, roughly 3000-9000 LOC plus platform-specific risk.
   Rejected for MVP. It can improve identity assurance later for specific
   cleanup flows, but it is expensive, OS-specific, and may increase resource
   pressure.

Accepted contract:

```text
TargetIdentityEvidence
  target_id
  normalized_path_ref
  preflight_identity
  preflight_authority_scope
  pdu_root_name_evidence
  post_scan_identity
  drift_state
  confidence

TargetDriftState
  not_checked
  stable_enough_for_readonly
  changed_during_scan
  replaced
  moved_or_missing
  authority_scope_changed
  volume_changed
  unknown_degraded

Cleanup authority
  DeletePlan node refs
  current identity preflight
  current authority scope
  platform Trash capability
  not pdu scan-time root identity
```

Layer rules:

- `fs_usage_core` owns `TargetIdentityEvidence`, `TargetDriftState`, and
  authority-scope vocabulary as product concepts;
- `fs_usage_engine` owns the identity envelope: preflight, scan epoch,
  post-scan probe, outcome aggregation, and cleanup blocking policy;
- `fs_usage_platform` owns platform-specific identity reads and comparisons;
- `fs_usage_pdu` reports only pdu traversal evidence and the raw pdu root shape;
- `clean_disk_protocol` exposes identity/drift state as scan quality and
  cleanup eligibility, not raw inode/dev/file-reference values;
- Flutter can display degraded/stale target state, but cannot reinterpret it
  into cleanup permission.

Contract tests:

- root accepted by preflight but deleted before pdu starts maps to failed or
  degraded target, not clean zero-size success;
- root replaced by another directory between preflight and post-scan probe maps
  to `changed_during_scan` or `replaced`;
- root replaced by symlink/reparse point blocks cleanup even if pdu produced a
  tree;
- remounted/external volume changes target identity confidence;
- stale security-scoped bookmark or platform authority change is separate from
  path existence;
- cleanup plan validation always performs current identity revalidation and
  rejects stale scan-only identity.

## Error And Scan Quality Contract

pdu filesystem errors are raw evidence only.

Source-level facts:

- `ErrorReport` contains `operation`, `path: &Path`, and `std::io::Error`;
- pdu operation is only `SymlinkMetadata`, `ReadDirectory`, or `AccessEntry`;
- `FsTreeBuilder` emits errors through `Reporter::EncounterError`; the scan
  still returns a `DataTree` through `From`, not a `Result<DataTree, Error>`;
- when root `symlink_metadata` fails with `DeviceBoundary::Cross`, the normal
  `TreeBuilder` path can still construct a zero-size node with no children;
- when root `symlink_metadata` fails before `DeviceBoundary::Stay` setup, pdu
  reports the error and returns a zero-size root-shaped file tree;
- when `symlink_metadata` fails inside normal traversal, pdu reports the error
  and returns an `Info` with zero size and no children for that path;
- when `read_dir` fails, pdu keeps the current node measured size but returns no
  children for that directory;
- when `DirEntry` access fails, pdu reports the parent directory path and drops
  that child because no child `file_name()` is available;
- pdu does not classify permission repair actions, stale target, cloud
  placeholder, deleted-while-scanning, timeout, path encoding, or security
  policy reasons;
- pdu does not return a global "partial scan" result type;
- pdu `ProgressReport.errors` is just a count;
- root `symlink_metadata` failure under `DeviceBoundary::Stay` can return a
  zero-size pdu file tree unless target preflight prevents it.

This creates a strict product boundary:

```text
pdu DataTree returned
  does not mean target scan succeeded
  does not mean subtree is complete
  does not mean zero-size node is real
```

### Resultless Traversal Evidence Join Boundary

pdu's filesystem traversal is not result-shaped. The library path converts
`FsTreeBuilder` into `DataTree` through `From`, while errors, progress, and
hardlink observations are emitted through side channels. Our adapter must join
those channels before anything crosses into the engine.

Source-level facts from pdu 0.23.0:

- `FsTreeBuilder` implements `From<FsTreeBuilder> for DataTree`, not
  `Result<DataTree, ScanError>`;
- root and child `symlink_metadata` failures are reported through
  `Event::EncounterError`, then traversal still returns a tree-shaped value;
- a failed metadata read maps to `Info { size: Size::default(), children: [] }`
  in the generic `TreeBuilder` path;
- a `read_dir` failure keeps the current node's measured size and returns no
  child names;
- `AccessEntry` failure reports only the parent directory path and skips that
  child because no child name is available;
- `ReceiveData(size)`, `EncounterError(error)`, and `DetectHardlink(info)` are
  callback events, not ordered product events;
- `RecordHardlinks::Err` is discarded by pdu with `.ok()`, so adapter control
  flow cannot rely on returning errors from the recorder.

Accepted adapter contract:

```text
PduScanRunner
  -> pdu FsTreeBuilder produces DataTree
  -> PduReporter captures issue/progress/hardlink callback evidence
  -> PduMetadataTap captures bounded metadata and conflict evidence
  -> PduEvidenceJoiner correlates tree shape with side-channel evidence
  -> PduRawScanResult
  -> PduTreeConverter/PduIssueMapper
  -> BackendScanOutput
```

Top 3 evidence join strategies:

1. Add explicit `PduEvidenceJoiner` inside `fs_usage_pdu` - 🎯 10 🛡️ 10 🧠 6,
   roughly 500-1300 LOC.
   Accepted. It makes pdu's side-channel model visible at the adapter boundary
   without leaking pdu concepts into domain.
2. Let `PduTreeConverter` infer quality from `DataTree` shape only - 🎯 3 🛡️ 3
   🧠 2, roughly 100-300 LOC.
   Rejected. Empty children can mean real empty directory, read failure, boundary
   skip, depth projection, race, symlink, or metadata failure.
3. Store pdu callback events directly in `BackendScanOutput` and let the engine
   interpret them - 🎯 4 🛡️ 5 🧠 3, roughly 300-800 LOC.
   Rejected. It leaks pdu event vocabulary and lifetime/order assumptions across
   the port.

Layer responsibilities:

- `fs_usage_pdu` owns `PduEvidenceJoiner`, raw pdu operation names, callback
  snapshots, and correlation heuristics;
- `fs_usage_engine` receives only stable `ScanIssue`, `TargetScanOutcome`,
  `ChildCompleteness`, `ScanQuality`, and `BackendMetrics`;
- `fs_usage_core` owns scanner-agnostic issue/completeness vocabulary, not pdu
  event enums or `std::io::Error`;
- `clean_disk_protocol` exposes versioned product reason codes and quality
  states, not pdu operations;
- Flutter renders product quality/repair states and never decides from pdu tree
  shape whether a subtree is complete.

`PduRawScanResult` must therefore carry more than the tree:

```text
PduRawScanResult
  data_tree
  reporter_snapshot
  issue_evidence_store
  hardlink_evidence_store
  metadata_tap_summary
  target_probe_evidence
  tree_shape_anomaly_summary
  pdu_options_fingerprint
  timings
  resource_profile_used
```

Contract tests:

- root `symlink_metadata` failure can return a pdu tree but maps to failed or
  degraded target outcome;
- child metadata failure creates uncertain node evidence and never a cleanup
  candidate;
- `read_dir` failure marks children unknown, not complete empty;
- `AccessEntry` attaches to parent/evidence-only scope and does not fabricate a
  child path;
- pdu callback events never cross the `ScannerBackend` public boundary.

### Per-Target Outcome Contract

pdu can return a tree even when a target had root-level errors. Product code
must therefore classify each requested target separately before building the
final snapshot view.

Accepted target outcome model:

```text
TargetScanOutcome
  target_id
  requested_path_ref
  normalized_path_ref
  preflight_state
  backend_walk_state
  root_node_ref
  scan_quality
  issue_refs
  root_confidence
  pdu_root_shape
  query_visibility
  cleanup_eligibility
```

Outcome states:

```text
preflight_state
  accepted
  rejected_missing
  rejected_unsupported
  rejected_policy
  degraded_uncertain

backend_walk_state
  not_started
  walked_with_tree
  walked_with_root_error
  walked_partial
  failed_backend
  cancelled

query_visibility
  visible
  visible_with_warning
  hidden_failed_target

cleanup_eligibility
  never_for_failed_target
  requires_current_revalidation
  synthetic_root_blocked
```

Top 3 target outcome strategies:

1. Engine-owned `TargetScanOutcome` per normalized target - 🎯 10 🛡️ 10 🧠 6,
   roughly 700-1800 LOC.
   Accepted. It keeps multi-target sessions honest, prevents zero-size root
   lies, and works for pdu, MFT, remote, and future backends.
2. Single session-level `ScanQuality` only - 🎯 5 🛡️ 5 🧠 2, roughly
   200-600 LOC.
   Rejected. It cannot explain one failed target among several successful roots.
3. Trust pdu root node as target status - 🎯 2 🛡️ 2 🧠 1, roughly 50-200 LOC.
   Rejected. A returned pdu tree is not proof that the target was valid,
   complete, or cleanup-eligible.

Layer rules:

- target preflight belongs to `fs_usage_engine` plus `fs_usage_platform`;
- `fs_usage_pdu` may report `pdu_root_shape`, but it must not decide product
  cleanup eligibility;
- `TargetScanOutcome` is application/read-model state, not pdu DTO state;
- a failed target can have issue evidence without a usable `root_node_ref`;
- multi-target synthetic roots aggregate outcomes but never hide failed target
  evidence;
- UI may show a failed target row/card, but destructive actions remain disabled
  until current identity revalidation succeeds on a concrete node.

Accepted issue mapping:

```text
PduErrorReport
  operation
  owned_path_evidence
  io_error_kind
  raw_os_error
  target_id
  snapshot_epoch

ScanIssue
  issue_id
  issue_reason
  affected_ref
  severity
  confidence
  operation
  platform_error
  repair_hint
  evidence_ref
```

Issue path scope we own:

```text
IssuePathScope
  TargetRoot
  CurrentNode
  ParentDirectory
  UnknownChildOfParent
  SyntheticRoot

IssueAttachment
  NodeRef when the node exists in the read model
  TargetRef when the root failed before a trusted node exists
  ParentNodeRef plus child_unknown when pdu had only parent evidence
  EvidenceOnly when no safe node binding exists
```

Top 3 issue strategies:

1. Stable `ScanIssueReason` taxonomy owned by `fs_usage_core` - 🎯 10 🛡️ 10
   🧠 7, roughly 900-2400 LOC.
   Accepted. pdu errors map into stable product reasons, and future scanner
   backends reuse the same taxonomy.
2. Store pdu `Operation` + `io::ErrorKind` directly in domain - 🎯 4 🛡️ 5 🧠 3,
   roughly 200-600 LOC.
   Rejected. This leaks pdu and Rust std error shape into domain/protocol and
   gives weak UX repair states.
3. Treat every pdu error as generic skipped path - 🎯 5 🛡️ 5 🧠 2, roughly
   100-300 LOC.
   Too coarse. It hides permission, vanished-file, broken-link, and resource
   pressure differences that matter for trust and support.

Initial issue reason sketch:

```text
ScanIssueReason
  TargetMissing
  MetadataReadFailed
  DirectoryReadFailed
  DirectoryEntryAccessFailed
  PermissionDenied
  NotFoundDuringScan
  BoundarySkipped
  DepthTruncated
  PathEncodingLossy
  HardlinkEvidenceConflict
  ReporterEvidenceTruncated
  ProgressSnapshotApproximate
  EventOrderUnstable
  BackendPanic
  BackendCapabilityUnsupported
```

Scan quality aggregation:

```text
ScanQuality
  Complete
  CompleteWithWarnings
  Partial
  FailedTarget
  Cancelled
  FailedBackend
```

Rules:

- pdu scan completion does not imply `ScanQuality::Complete`;
- any unreadable directory or skipped entry makes the relevant subtree partial;
- root preflight failure maps to `FailedTarget`, not zero-size success;
- zero-size pdu nodes caused by metadata failures are marked as uncertain
  evidence and cannot become cleanup candidates;
- `ReadDirectory` failure marks children as unknown, not empty;
- `AccessEntry` failure attaches to the parent directory or evidence-only issue,
  never to a fabricated child path;
- permission-denied-like errors create repair-capable issues where platform
  adapters can provide guidance;
- vanished-file errors during scan are warnings/partial evidence, not hard
  backend failure;
- pdu operation names are not localized UI labels or protocol reason ids;
- raw paths and OS errors are evidence refs with redaction rules.

Issue mapping examples:

| pdu raw error | Product issue | Quality impact |
| --- | --- | --- |
| `SymlinkMetadata` + `NotFound` child | `NotFoundDuringScan` | warning or partial subtree |
| `SymlinkMetadata` + `PermissionDenied` | `PermissionDenied` | partial or failed target |
| `ReadDirectory` + `PermissionDenied` | `DirectoryReadFailed` plus permission facet | partial subtree |
| `AccessEntry` error | `DirectoryEntryAccessFailed` | skipped child evidence |
| root preflight missing | `TargetMissing` | failed target |
| reporter buffer overflow | `ReporterEvidenceTruncated` | degraded evidence |

`PduIssueMapper` is an anti-corruption adapter. Domain must not import pdu
`Operation` or depend on `std::io::Error`.

Data/infrastructure mapping:

```text
PduReporter
  -> copies ErrorReport into PduIssueEvidence
  -> records pdu operation as adapter evidence only
  -> maps io::ErrorKind/raw_os_error through PduIssueMapper

PduTreeConverter
  -> sees zero-size/no-child nodes
  -> consults issue evidence before assigning completeness
  -> writes ChildCompleteness/ScanQuality evidence
```

Domain/application contract:

- `ScanIssueReason` is stable and scanner-agnostic;
- `IssuePathScope` and `IssueAttachment` describe evidence location without
  inventing node identity;
- `ScanQuality` is computed from read-model completeness plus issue evidence;
- cleanup/search/recommendation code can exclude uncertain nodes by policy;
- UI repair hints are produced by platform/application policy, not by pdu
  operation strings.

### Owned Error Evidence And Redaction Contract

pdu error events must be copied and classified immediately. They are not durable
domain objects.

Source-level facts from pdu 0.23.0:

- `ErrorReport<'a>` contains `path: &'a Path`, so the path reference is valid
  only while the pdu callback is executing;
- `ErrorReport` owns `std::io::Error`, which is not a stable product protocol
  or domain type;
- `Operation::name()` returns terminal/debug wording, not a product reason id;
- `ErrorReport::TEXT` prints through pdu's global status-board path and includes
  debug path text plus the raw OS error display;
- `AccessEntry` reports the parent directory path, not the missing child path;
- `std::io::ErrorKind` and `raw_os_error()` alone are not enough to decide user
  repair UX across macOS, Windows, Linux, cloud providers, network mounts, and
  sandbox/permission systems;
- pdu does not aggregate issue samples, apply privacy classes, or cap path/error
  evidence by product budget.

Accepted adapter evidence:

```text
PduIssueEvidence
  evidence_id
  target_ref
  pdu_operation
  issue_path_scope
  owned_path_evidence
  io_error_kind
  raw_os_error
  error_message_class
  privacy_class
  sample_policy_state
  observed_at_phase
  snapshot_epoch

PlatformErrorFacet
  permission_like
  missing_like
  transient_like
  resource_like
  provider_like
  security_policy_like
  unknown
```

Top 3 issue-evidence strategies:

1. Owned redacted `PduIssueEvidence` plus stable domain taxonomy - 🎯 10 🛡️ 10
   🧠 6, roughly 700-1800 LOC.
   Accepted. pdu details stay private, domain gets stable `ScanIssueReason`,
   and support/telemetry can obey path/privacy budgets.
2. Store `std::io::Error` and pdu `Operation` in read model/domain - 🎯 3 🛡️ 4
   🧠 2, roughly 100-400 LOC.
   Rejected. It violates DIP, leaks Rust/pdu internals, and makes protocol/web
   compatibility brittle.
3. Store only aggregate error counts - 🎯 5 🛡️ 5 🧠 1, roughly 50-200 LOC.
   Too weak. It cannot explain partial subtrees, permission repair, target
   failure, or support diagnostics.

Layer rules:

- `PduReporter` copies `ErrorReport` into owned `PduIssueEvidence` before
  returning from `Reporter::report`;
- `PduIssueEvidence` stays inside `fs_usage_pdu` or adapter diagnostics;
- domain sees `ScanIssueReason`, `IssueAttachment`, `ScanQuality`, and optional
  platform-neutral facets only;
- platform repair UX is produced by `fs_usage_platform` and application policy,
  not by pdu operation names or raw error strings;
- raw path and raw OS-error display text are privacy-sensitive evidence and are
  never sent to Flutter, telemetry, logs, support bundles, or protocol by
  default;
- issue sampling is bounded. Dropped samples lower diagnostic confidence and
  emit `ReporterEvidenceTruncated`/`IssueEvidenceTruncated`;
- `ErrorReport::TEXT` and pdu global status-board output are forbidden in
  production adapter code.

Data/infrastructure mapping:

```text
PduReporter
  -> receives EncounterError(ErrorReport)
  -> copies path into NativePathEvidence under redaction policy
  -> copies io::ErrorKind and raw_os_error
  -> classifies message into error_message_class
  -> stores bounded PduIssueEvidence sample

PduIssueMapper
  -> maps pdu_operation + io_error_kind + path_scope into ScanIssueReason
  -> attaches to NodeRef, TargetRef, ParentNodeRef, or EvidenceOnly
  -> never exports pdu Operation or std::io::Error

PlatformRepairHintProvider
  -> maps ScanIssueReason + platform facets + permissions capability
  -> creates repair hint/action availability for UI
```

Contract tests:

- pdu borrowed path is copied before callback returns;
- raw `std::io::Error` never appears outside `fs_usage_pdu`;
- `AccessEntry` maps to parent-scope/evidence-only issue and does not fabricate
  a child `NodeId`;
- `ErrorReport::TEXT` and `Operation::name()` are not used in production
  protocol/UI/log messages;
- issue sample overflow records truncation evidence and does not block scanner
  worker threads.

### Platform And Accounting Adapters

pdu does not provide enough data for details, safety, or honest reclaim
accounting. These stay behind separate ports.

`fs_usage_platform` owns:

- file type and node kind.
- modified time.
- permissions and ownership.
- platform identity evidence.
- mount/volume information.
- cloud/provider placeholder hints.
- native reveal/open actions.

`fs_usage_accounting` owns:

- allocated bytes beyond pdu's selected size mode where available.
- exclusive reclaim estimate.
- quota effect.
- clone/reflink/snapshot confidence.
- observed free-space delta after cleanup.

`fs_usage_cleanup` or later cleanup package owns:

- delete preflight.
- Trash/Recycling Bin/quarantine adapters.
- operation journal.
- cleanup receipt.
- restore capability level.

## pdu Fact Mapping

| pdu fact | Product mapping | Contract caution |
| --- | --- | --- |
| `DataTree.name` | node display/raw segment evidence | root can be full path, children are names; not stable id |
| `DataTree.size` | one measured `SizeFacts` component | not reclaimable bytes |
| `DataTree.children` | hierarchy input to `NodeArenaWriter` | absent children may mean `max_depth`, not no children |
| `ReceiveData(size)` | progress counter evidence | not a complete node event |
| `EncounterError(operation,path,error)` | `ScanIssue` | scan can still succeed degraded |
| `DetectHardlink` | `HardlinkEvidence` | not full reclaim truth |
| `DeviceBoundary::Stay` | boundary policy adapter input | must be backed by platform capability report |
| `HardlinkAware` | Unix hardlink evidence adapter | recorder conflicts are not surfaced by `FsTreeBuilder` |
| pdu JSON | fixture/diagnostic only | not protocol |
| pdu CLI sort/cull | forbidden for product query | query semantics belong to engine indexes |

## Size Measurement Contract

pdu `size` is one measurement, not a universal storage truth.

Source-level behavior:

- `GetApparentSize` maps to `metadata.len()` and returns pdu `Bytes`;
- `GetBlockSize` is Unix-only and maps to `metadata.blocks() * 512`, returning
  pdu `Bytes`;
- `GetBlockCount` is Unix-only and maps to `metadata.blocks()`, returning pdu
  `Blocks`;
- pdu `Bytes` and `Blocks` are `u64` newtypes;
- pdu CLI default is `BlockSize` on Unix and `ApparentSize` on non-Unix;
- pdu CLI `Quantity` combines three concepts: which `GetSize` implementation
  runs, which pdu size newtype is used, and which formatter is available;
- pdu CLI `GetSizeUtils::formatter` returns `BytesFormat` for byte quantities
  and unit `()` for block-count quantities;
- pdu `JsonDataBody` tags serialized output as either `Bytes` or `Blocks`, but
  it does not distinguish apparent bytes from Unix allocated bytes;
- pdu byte formatting is presentation-only and may use floating display units;
- pdu JSON tags the body with `unit`, but JSON is not our product protocol.

### GetSize Adapter Boundary

pdu `GetSize` is a small measurement hook, not our storage-accounting port.
This is a classic Interface Segregation and Dependency Inversion point: the
domain should depend on our measurement vocabulary, while pdu-specific getters
stay in infrastructure.

Source-level facts from pdu 0.23.0:

- `GetSize::get_size(&self, metadata: &Metadata)` receives only
  `std::fs::Metadata`;
- `GetSize` does not receive the path, target id, volume identity, mount info,
  scan policy, privacy policy, cancellation token, or issue sink;
- `GetSize` returns a size value directly, not `Result`, so measurement fallback
  or degraded measurement quality must be modeled outside the trait;
- `GetApparentSize` and `GetBlockSize` both return pdu `Bytes`, even though one
  means apparent bytes and the other means POSIX allocated bytes;
- `GetBlockCount` returns pdu `Blocks`, which is a count and must not be mixed
  with byte facts;
- Unix block size support is compile-time gated. On non-Unix targets pdu exposes
  apparent size only;
- pdu CLI `Quantity::DEFAULT` is a CLI default, not an application default;
- the source comment for `GetBlockSize` references `Metadata::blksize`, but the
  implementation uses `metadata.blocks() * 512`.

Accepted measurement profile contract:

```text
MeasurementProfileRequest
  preferred_fact = apparent_bytes | allocated_bytes | block_count
  fallback_policy = fail_closed | fallback_to_apparent | platform_default
  require_mode_visibility = true

PduMeasurementEvidence
  pdu_getter = GetApparentSize | GetBlockSize | GetBlockCount
  pdu_size_type = Bytes | Blocks
  product_fact_kind
  platform_support
  fallback_used
  confidence

SizeFacts.measured
  value
  unit_semantics
  measurement_kind
  source = pdu
  confidence
  evidence_ref
```

Top 3 measurement integration strategies:

1. Map pdu getters into explicit product `MeasurementProfile` and `SizeFacts` -
   🎯 10 🛡️ 10 🧠 6, roughly 500-1400 LOC.
   Accepted. This preserves speed while keeping semantic truth in our domain.
2. Make pdu `GetSize` the application measurement port - 🎯 3 🛡️ 4 🧠 2,
   roughly 100-400 LOC.
   Rejected. The trait is too narrow and pdu-specific: no path, no Result, no
   platform evidence, no reclaim model, no capability reporting.
3. Implement custom pdu `GetSize` for all future accounting - 🎯 5 🛡️ 5 🧠 6,
   roughly 800-2500 LOC.
   Useful only for metadata-only facts. It cannot solve APFS clones, snapshots,
   cloud placeholders, Windows MFT/USN facts, provider state, or delete reclaim
   because the trait lacks path and volume context.

Layer rules:

- `domain` owns `MeasurementKind`, `UnitSemantics`, `SizeFactSource`,
  `MeasurementConfidence`, and reclaim/accounting vocabulary;
- `application` owns `MeasurementProfileRequest` and decides fail-closed versus
  fallback behavior;
- `fs_usage_pdu` maps product measurement requests to concrete pdu getters and
  emits `PduMeasurementEvidence`;
- `fs_usage_platform` and `fs_usage_accounting` own richer platform accounting,
  exclusive reclaim, quota effect, snapshots, clones, compression, sparse files,
  and observed free-space deltas;
- protocol and Flutter never infer semantics from a field named `bytes`;
- if a requested measurement mode is unsupported on the current platform, the
  adapter reports a capability/quality state instead of silently changing the
  meaning of returned sizes.

Contract tests:

- apparent and allocated pdu measurements both returning `Bytes` map to distinct
  product `measurement_kind` values;
- `Blocks` cannot be sorted, compared, exported, or displayed as bytes without
  explicit conversion/evidence;
- non-Unix allocated-byte requests fail closed unless an application fallback
  policy explicitly allows apparent bytes;
- pdu CLI default quantity is never used as the app's implicit scan policy;
- measurement fallback lowers confidence and is visible in details/export.

### GetSize Purity And Side-Effect Boundary

pdu `GetSize` is tempting as an extension hook because it runs for every
successfully statted path. Do not use it as a hidden metadata collector,
accounting adapter, logging hook, cancellation hook, or product event source.

Source-level facts:

- `FsTreeBuilder` calls `symlink_metadata(path)` first, then calls
  `size_getter.get_size(&stats)` only after metadata succeeds;
- the `GetSize` implementation receives `&Metadata`, but not `&Path`;
- `get_size` returns `Self::Size`, not `Result<Self::Size, Error>`;
- `GetSize` is constrained by `SizeGetter: GetSize<Size = Size> + Sync`;
- `FsTreeBuilder` reports `Event::ReceiveData(size)` immediately after
  `get_size`, before hardlink recording and before deciding whether to read
  child names;
- pdu can call `get_size` concurrently from Rayon workers through
  `TreeBuilder` recursion;
- the metadata borrowed into `get_size` is dropped quickly by pdu after the
  local block, so references cannot be retained safely;
- root preflight for `DeviceBoundary::Stay` calls `symlink_metadata(&root)` to
  get device id, but does not call `GetSize` during that preflight branch.

Product consequence:

```text
GetSize is a pure measurement adapter.
It is not MetadataProvider.
It is not AccountingProvider.
It is not ScanEventEmitter.
It is not CancellationToken.
```

Top 3 `GetSize` extension strategies:

1. Keep `GetSize` pure and side-effect free - 🎯 10 🛡️ 10 🧠 4, roughly
   200-700 LOC.
   Accepted. Use pdu built-in getters or tiny wrappers that only choose the
   measured numeric fact. Rich evidence comes from reporter, metadata tap, and
   platform providers.
2. Use custom `GetSize` as a metrics/event side channel - 🎯 4 🛡️ 4 🧠 5,
   roughly 500-1400 LOC.
   Rejected. It has no path, no `Result`, no lifecycle contract, no redaction
   policy, and it runs inside traversal workers.
3. Use custom `GetSize` for platform accounting and reclaim estimates -
   🎯 3 🛡️ 3 🧠 7, roughly 900-2600 LOC.
   Rejected. Reclaim needs path identity, filesystem topology, snapshots/clones,
   provider state, delete preflight, and confidence evidence that `GetSize`
   cannot express.

Accepted contract:

```text
PduGetSizeAdapter
  input = Metadata
  output = pdu Bytes | Blocks
  allowed = apparent size | Unix allocated bytes | Unix block count
  forbidden = path capture | logging | DB writes | network | cancellation |
              metadata enrichment | reclaim accounting | event emission

MetadataProvider
  input = NodeRef | NativePathEvidence | ScanTargetIdentity
  output = current metadata evidence
  owns = path-aware enrichment, delete preflight evidence
```

Layer rules:

- `fs_usage_pdu::measurement` owns pdu `GetSize` selection only;
- `fs_usage_platform::metadata` owns path-aware metadata enrichment;
- `fs_usage_accounting` owns reclaim/accounting estimates;
- `fs_usage_engine` correlates pdu measurement evidence with metadata tap,
  issue evidence, and later platform enrichment;
- pdu `GetSize` implementations must not emit product events, write logs,
  perform async work, capture raw paths, or mutate shared domain state.

Contract tests:

- custom production `GetSize` implementations have no protocol, DB, logging,
  async runtime, Flutter, or cleanup imports;
- `GetSize` is never the source of node identity, path, permissions, modified
  time, cloud state, or delete authority;
- `GetSize` failure cannot be represented as `Result`, so unsupported modes map
  before scanner start through capability/fallback policy;
- measurement events from pdu `ReceiveData(size)` are treated as progress
  evidence only, not node-complete events.

### Unix Blocks 512-Byte Unit Boundary

pdu's Unix allocated-size path is more specific than the name `GetBlockSize`
suggests. It does not read filesystem I/O block size. It reads Unix
`MetadataExt::blocks()` and converts that count using a fixed 512-byte unit.

Source-level facts:

- pdu `GetBlockSize` is compiled only on Unix;
- its implementation is `metadata.blocks() * 512`;
- Rust `MetadataExt::blocks()` is documented as allocated blocks in 512-byte
  units and can be smaller than file size for sparse files;
- pdu `GetBlockCount` returns raw `metadata.blocks()` as pdu `Blocks`;
- pdu `Bytes` does not encode whether bytes came from `metadata.len()` or
  `metadata.blocks() * 512`;
- pdu `GetBlockSize` source comment references block size, but the implementation
  uses allocated block count multiplied by 512.

Accepted product contract:

```text
MeasurementUnitEvidence
  product_fact_kind = unix_allocated_bytes
  source_api = std::os::unix::fs::MetadataExt::blocks
  source_unit = unix_512_byte_blocks
  conversion = blocks * 512
  sparse_file_sensitive = true
  exact_reclaim_authority = false
```

Top 3 unit-boundary strategies:

1. Store explicit `MeasurementUnitEvidence` for pdu Unix allocated bytes - 🎯 10
   🛡️ 10 🧠 5, roughly 300-900 LOC.
   Accepted. It preserves pdu performance while making source/API/unit truth
   visible to domain, protocol, export, and support diagnostics.
2. Treat pdu `GetBlockSize` as generic "allocated bytes" without source details -
   🎯 5 🛡️ 5 🧠 2, roughly 100-300 LOC.
   Rejected. It hides the 512-byte unit assumption and will confuse APFS, NTFS,
   sparse files, quotas, and reclaim explanations.
3. Treat pdu `GetBlockSize` as exact reclaimable physical bytes - 🎯 2 🛡️ 2 🧠 1,
   roughly 0-100 LOC.
   Rejected. It is a scan measurement, not clone/snapshot/dedupe/cloud-aware
   reclaim accounting.

Layer rules:

- `fs_usage_pdu` maps `GetBlockSize` to
  `MeasurementUnitEvidence::unix_512_byte_blocks`;
- `fs_usage_core` owns `MeasurementUnitEvidence`, `SourceApi`, and
  `UnitSemantics`;
- `fs_usage_accounting` may add stronger platform facts later, but it never
  overwrites the pdu source evidence;
- protocol/export include source API and unit semantics for exact values;
- Flutter labels this as measured allocated size with confidence, not exact
  cleanup savings.

Contract tests:

- `GetApparentSize` and `GetBlockSize` both returning pdu `Bytes` map to
  different `source_api` and `measurement_kind`;
- `GetBlockCount` maps to count semantics and cannot enter byte fields without
  explicit conversion evidence;
- sparse-file fixtures show apparent and Unix allocated measurements differ;
- non-Unix builds report pdu Unix allocated size as unsupported/degraded, not
  silently apparent bytes;
- export includes `source_unit = unix_512_byte_blocks` for pdu allocated bytes.

Domain rule:

```text
pdu size -> SizeFacts.measured
SizeFacts.measured.mode -> ApparentBytes | UnixAllocatedBytes | UnixBlockCount
SizeFacts.measured.source -> Pdu
SizeFacts.measured.confidence -> capability/platform dependent
```

Forbidden:

- treating pdu size as exact reclaimable bytes;
- using pdu formatted strings as DTO values;
- using pdu JSON numeric values in Flutter web DTOs;
- collapsing apparent, allocated, exclusive, quota, and observed-free-space into
  one `size` field;
- hiding size mode from UI/details/export.

Top 3 size contract options:

1. `SizeFacts` with explicit measured facts and confidence - 🎯 10 🛡️ 10 🧠 7,
   roughly 900-2200 LOC across value objects, mappers, DTOs, and tests.
   Accepted. It keeps pdu measurement honest and leaves room for platform
   accounting, hardlink projections, snapshots, clones, and cloud placeholders.
2. Single `bytes: u64` in domain - 🎯 4 🛡️ 4 🧠 2, roughly 100-400 LOC.
   Rejected. Fast, but it lies by omission and makes reclaim/delete unsafe.
3. Full accounting model before MVP scanner - 🎯 6 🛡️ 8 🧠 9, roughly
   4000-10000 LOC.
   Too much for scan-only MVP. Keep `SizeFacts` contract ready, but fill only
   measured pdu facts initially.

Accepted `SizeFacts` sketch:

```text
SizeFacts
  logical_bytes
  allocated_bytes
  unix_block_count
  hardlink_adjusted_bytes
  exclusive_reclaim_estimate
  quota_effect_bytes
  observed_free_space_delta
  primary_display_mode
  confidence
  evidence_refs
```

MVP fill rule:

```text
Apparent mode:
  logical_bytes = pdu Bytes
  allocated_bytes = unknown

Unix block-size mode:
  allocated_bytes = pdu Bytes
  logical_bytes = optional/lazy platform metadata

Unix block-count mode:
  unix_block_count = pdu Blocks
  display as diagnostic unless explicitly selected
```

Protocol rule:

```text
Exact byte counts, counters, IDs, cursors, and sequences are string-encoded in
web-facing JSON DTOs. Flutter web must not rely on JSON numeric precision for
u64-sized values.
```

Accounting boundary:

```text
pdu measures.
fs_usage_accounting estimates.
cleanup observes.
UI explains confidence.
```

### Measurement Mode Selection Boundary

pdu makes measurement selection compile-time/simple:

```text
Quantity::ApparentSize -> GetApparentSize -> Bytes
Quantity::BlockSize -> Unix GetBlockSize -> Bytes
Quantity::BlockCount -> Unix GetBlockCount -> Blocks
```

Clean Disk must not copy this as one `quantity` enum across the product. It
needs separate concepts:

```text
MeasurementPolicy
  ApparentBytes
  UnixAllocatedBytes
  UnixBlockCount

MeasuredFact
  exact_value
  unit_semantics
  source_backend
  source_api
  platform_scope
  confidence

DisplayPolicy
  metric
  binary
  plain
  localized_default
```

Top 3 measurement-boundary strategies:

1. Split measurement, fact, and display policies - 🎯 10 🛡️ 10 🧠 7, roughly
   900-2200 LOC.
   Accepted. It prevents pdu CLI semantics from shaping domain, keeps JSON/web
   exactness safe, and lets future MFT/APFS/accounting adapters add stronger
   facts without breaking UI contracts.
2. Reuse pdu `Quantity` as product enum - 🎯 4 🛡️ 5 🧠 2, roughly 100-300 LOC.
   Rejected. It leaks Unix-only variants, pdu naming, and byte/block ambiguity
   into protocol and Flutter.
3. Always scan apparent bytes and calculate everything later - 🎯 6 🛡️ 6 🧠 5,
   roughly 300-900 LOC.
   Too weak for desktop storage UX. It is acceptable as fallback on unsupported
   platforms, but not as the core contract.

Rules:

- product defaults are application policy, not pdu CLI defaults;
- `Bytes` from pdu can mean apparent bytes or Unix allocated bytes depending on
  selected getter, so the mode must be carried explicitly;
- pdu `Blocks` is a count, not bytes, and cannot be mixed with byte fields;
- pdu JSON `unit = bytes` is insufficient to distinguish logical and allocated
  bytes;
- sort/filter/compare must choose an explicit size fact and fallback policy;
- export must include exact value, unit semantics, source, and confidence.

### Size Formatting And Unit Display Boundary

pdu formatting is CLI presentation, not product number semantics.

Source-level formatting facts:

- pdu `BytesFormat` can be `PlainNumber`, `MetricUnits`, or `BinaryUnits`;
- pdu `BytesFormat` is also a `clap::ValueEnum` when the `cli` feature is
  enabled;
- pdu CLI accepts byte-format aliases `1`, `1000`, and `1024` for plain,
  metric, and binary display modes;
- pdu CLI default byte format is metric units;
- pdu `Quantity::DEFAULT` is Unix `BlockSize` on Unix and `ApparentSize` on
  non-Unix;
- pdu formatting chooses units with a fixed largest scale up to `P`;
- pdu `ParsedValue::Big` uses `f32`, so display text is intentionally rounded
  and approximate;
- pdu `ParsedValue::Big` stores a visible `coefficient: f32` and displays it
  with one decimal digit;
- pdu metric and binary units use single-letter suffixes such as `K`, `M`, `G`,
  `T`, and `P`;
- pdu `Blocks` display as a plain `u64` block count, not bytes;
- pdu visualizer formats sizes before terminal rendering, so formatted output
  has already lost exact machine semantics;
- pdu JSON stores raw numeric values plus a pdu `unit` tag, not localized display
  strings.

Product contract:

```text
exact quantity = typed numeric value object.
display size = localized view projection.
pdu formatted string = never protocol/persistence/domain.
```

Top 3 display-size strategies:

1. Store exact size facts and format at presentation boundaries - 🎯 10 🛡️ 10
   🧠 6, roughly 700-1800 LOC.
   Accepted. Exact values stay stable for sorting, filtering, export, compare,
   and cleanup. UI can localize and choose metric/binary without changing facts.
2. Reuse pdu formatted strings in DTOs - 🎯 2 🛡️ 2 🧠 1, roughly 50-200 LOC.
   Rejected. It loses exactness, locale control, unit semantics, and web-safe
   integer guarantees.
3. Store only one preformatted display size beside each node - 🎯 4 🛡️ 5 🧠 3,
   roughly 200-600 LOC.
   Rejected as product state. Acceptable only for preview fixtures, never
   authority, sorting, filtering, or export.

Accepted vocabulary:

```text
SizeDisplayPolicy
  metric
  binary
  plain_bytes
  block_count
  localized_default

SizeDisplayValue
  text
  source_fact_ref
  unit
  rounded
  locale
  exact_value_available

SizeUnitSemantics
  bytes
  unix_blocks_512
  count
  reclaim_estimate
  observed_delta
```

Layer rules:

- `fs_usage_core` owns exact quantity/unit/exactness vocabulary;
- `fs_usage_engine` returns exact facts and optional display projections for
  queries where useful;
- `clean_disk_protocol` encodes exact values as strings and display values as
  separate fields;
- Flutter may format sizes from exact facts for current locale, but must not use
  formatted text for sort/filter/compare/delete;
- exports include both exact values and display values when appropriate;
- pdu `BytesFormat`, `ParsedValue`, `Output`, and visualizer strings remain
  adapter/diagnostic-only and do not cross `fs_usage_pdu` public APIs;
- UI labels must expose size mode/confidence where it matters, especially when
  comparing apparent, allocated, hardlink-adjusted, and reclaim estimates.

### CLI Byte Format Alias Boundary

pdu byte-format CLI tokens are user-facing command-line compatibility, not Clean
Disk protocol or preference vocabulary.

Source-level alias facts:

- `Args.bytes_format` uses `#[clap(long, short, value_enum,
  default_value_t = BytesFormat::MetricUnits)]`;
- `BytesFormat::PlainNumber` has pdu CLI name `plain` and alias `1`;
- `BytesFormat::MetricUnits` has pdu CLI name `metric` and alias `1000`;
- `BytesFormat::BinaryUnits` has pdu CLI name `binary` and alias `1024`;
- `GetSizeUtils::formatter` forwards `BytesFormat` for byte-sized quantities;
- `GetBlockCount::formatter` ignores `BytesFormat` and returns `()`, because
  block count display is not byte display;
- pdu `ParsedValue::Big` uses `f32` and one decimal digit, so alias-selected
  display text is approximate by design.

Product contract:

```text
pdu CLI aliases -> compatibility input only.
Clean Disk display policy -> typed product preference.
Clean Disk size fact -> exact value plus explicit unit semantics.
```

Top 3 alias-boundary strategies:

1. Define our own `SizeDisplayPolicy` and map pdu aliases only inside the
   pdu/diagnostic adapter - 🎯 10 🛡️ 10 🧠 4, roughly 250-700 LOC.
   Accepted. It keeps CLI compatibility out of domain, protocol, persistence,
   and Flutter settings while still allowing pdu-compatible diagnostic tools.
2. Reuse pdu `BytesFormat` as protocol/preference enum - 🎯 3 🛡️ 3 🧠 1,
   roughly 50-150 LOC.
   Rejected. It imports pdu CLI naming, alias compatibility, feature-gated clap
   semantics, and approximate formatting into stable product contracts.
3. Accept raw strings like `1`, `1000`, and `1024` in app settings - 🎯 2 🛡️ 2
   🧠 1, roughly 50-200 LOC.
   Rejected. Numeric-looking tokens are ambiguous with quantity values,
   thresholds, bytes, locale formats, and future API clients.

Layer rules:

- `domain` contains `SizeDisplayPolicy`, `SizeUnitSemantics`, and exact size
  facts. It never imports pdu `BytesFormat`, `ParsedValue`, or `Output`.
- `application` accepts typed display preferences and query projection options,
  not pdu CLI tokens.
- `data/infrastructure` may parse pdu-compatible CLI aliases only in explicit
  diagnostic import/export adapters, then immediately maps them into product
  policy values.
- `clean_disk_protocol` serializes product values such as `metric_decimal`,
  `binary_iec`, `plain_bytes`, and `block_count`. It never serializes aliases
  `1`, `1000`, or `1024`.
- Flutter settings store product display preferences, not pdu enum variant
  names, clap names, or aliases.

Adapter mapping:

```text
fs_usage_pdu::diagnostics::parse_pdu_bytes_format_alias
  "plain" | "1"       -> SizeDisplayPolicy::PlainBytes
  "metric" | "1000"  -> SizeDisplayPolicy::MetricDecimal
  "binary" | "1024"  -> SizeDisplayPolicy::BinaryIec

fs_usage_pdu::scan_adapter
  never exposes BytesFormat in public return types
  may choose BytesFormat only for diagnostic terminal output
```

Acceptance checks:

```text
PduBytesFormatAliasBoundaryGuard
  rejects BytesFormat outside fs_usage_pdu
  rejects ParsedValue and Output outside diagnostic modules
  rejects protocol enum cases named plain | metric | binary when sourced from pdu
  rejects protocol/preference values equal to "1" | "1000" | "1024"

SizeDisplayPolicyContract
  exact facts remain sortable without formatted strings
  display text is derived at presentation/export boundaries
  block_count cannot use byte-format aliases
```

## Own Size And Aggregate Size Contract

pdu `DataTree` preserves aggregate node size, but does not preserve the node's
own measured size after tree construction.

Source-level facts:

- `FsTreeBuilder` computes `size_getter.get_size(&metadata)` for the current
  path before reading children;
- `TreeBuilder` passes that current-path size into `DataTree::dir(name, size,
  children)`;
- `DataTree::dir` stores `inode_size + sum(children.size())`;
- `DataTree::size()` returns only the stored aggregate size;
- `DataTree` has no getter for original `inode_size`;
- when `max_depth`, `par_retain`, or CLI culling removes children, the parent
  aggregate can still include hidden descendants;
- pdu hardlink dedupe can mutate aggregate sizes if used, which we reject for
  the primary product tree.

Implication:

```text
pdu DataTree.size = aggregate measured size
pdu DataTree does not expose own measured size
child sum may be less than parent aggregate size
visible children sum is not total parent size unless evidence says so
```

Top 3 policies:

1. Store aggregate pdu measurement now, enrich own size lazily - 🎯 10 🛡️ 9
   🧠 7, roughly 900-2200 LOC.
   Accepted. `NodeArenaRecord.size_facts.aggregate_measured` comes from pdu.
   `own_measured` starts unknown and can be filled by `MetadataProvider` or a
   future scanner backend.
2. Derive own size as `parent - sum(visible_children)` - 🎯 3 🛡️ 3 🧠 3,
   roughly 200-600 LOC.
   Rejected. It is wrong under projection depth, retained/cull helpers, skipped
   children, boundary skips, read errors, races, and hardlink projections.
3. Fork/upstream pdu to expose own size in `DataTree` - 🎯 6 🛡️ 8 🧠 9, roughly
   2500-7000 LOC including upgrade maintenance.
   Good future option if details/accounting need it at scan speed, but not MVP.
   Keep the contract ready through separate `own_measured` fields.

Accepted `SizeFacts` split:

```text
SizeFacts
  aggregate_measured
    value
    mode
    source = pdu
    confidence
  own_measured
    value = unknown | enriched
    source = metadata_provider | scanner_backend | accounting_provider
    confidence
  child_visible_sum
    value
    completeness = complete | projected | partial | unknown
```

Layer rules:

- `fs_usage_pdu` maps pdu `DataTree.size()` only to aggregate measured facts;
- `PduTreeConverter` must not infer own size from visible children;
- `fs_usage_engine` tracks child completeness separately from child count;
- `fs_usage_platform::MetadataProvider` may enrich current own size and
  identity, but this is a separate phase with its own metrics;
- details UI may show "own size unknown" or "visible children do not sum to
  total" instead of inventing exact values;
- cleanup/reclaim never uses own/aggregate arithmetic as authority without
  current accounting/preflight evidence.

### Aggregate Size Invariant And Constructor Boundary

pdu's `DataTree::dir` constructor is easy to misuse outside the pdu adapter. It
accepts an own/inode size and stores an aggregate size. That is correct inside
pdu's builder pipeline, but dangerous if any Clean Disk projection code treats
the stored aggregate as constructor input.

Source-level facts:

- `TreeBuilder::get_info` returns `Info { size, children }`, where `size` is the
  current path measurement from `GetSize`;
- when stored depth remains, `TreeBuilder` calls `DataTree::dir(name, size,
  children.collect())`;
- `DataTree::dir` stores `inode_size + children.iter().map(size).sum()`;
- when stored depth is exhausted, `TreeBuilder` first computes `size +
  children.map(|child| child.size()).sum()` and then calls `DataTree::dir` with
  no children, so the aggregate is preserved without double-adding descendants;
- pdu hardlink dedupe mutates stored aggregate sizes in place by subtracting
  shared sizes from matching ancestor paths;
- pdu does not store an invariant marker that says whether a `Size` value came
  from own measurement, aggregate construction, hardlink projection, culling, or
  depth truncation.

Product consequence:

```text
pdu constructor input size = own measured value in normal builder path.
pdu stored DataTree.size = aggregate measured or projection-mutated aggregate.
Clean Disk must never feed stored aggregate back into pdu dir constructor.
Clean Disk must never recompute parent aggregate from visible children unless
the child completeness evidence says this is allowed.
```

Top 3 aggregate invariant policies:

1. Convert once into typed engine size evidence and drop pdu tree - 🎯 10 🛡️ 10
   🧠 6, roughly 700-1800 LOC.
   Accepted. `PduAggregateSizeMapper` tags pdu `DataTree.size()` as stored
   aggregate evidence, and all later projections use engine value objects.
2. Reuse pdu `DataTree` constructors for engine projections - 🎯 4 🛡️ 4 🧠 3,
   roughly 200-600 LOC.
   Rejected. It invites double aggregation, hardlink projection leakage, and
   confusing own-vs-aggregate semantics.
3. Fork pdu to expose both own and aggregate size in `DataTree` now - 🎯 6
   🛡️ 8 🧠 9, roughly 2500-7000 LOC.
   Future option only. It may be worthwhile if scan-time own-size details become
   critical, but MVP should keep pdu as a fast aggregate backend.

Accepted contract:

```text
AggregateSizeEvidence
  aggregate_value
  measurement_mode
  source = pdu_datatree_size
  projection_state = raw | depth_projected | hardlink_projected | diagnostic
  child_completeness

OwnSizeEvidence
  value = unknown | current_metadata | backend_reported
  source
  confidence

VisibleChildSum
  value
  complete = true | false | unknown
  reason = full_children | depth_truncated | read_error | boundary_skip | filtered
```

Layer rules:

- `fs_usage_pdu` may read pdu `DataTree.size()` and `children()` but must not
  expose pdu constructors, pdu mutable size helpers, or pdu hardlink mutation
  outside the adapter;
- `fs_usage_engine` owns aggregate invariants in `NodeArenaWriter` and query
  projections;
- `fs_usage_core` owns typed size vocabulary such as `AggregateSizeEvidence`,
  `OwnSizeEvidence`, `VisibleChildSum`, and `ChildCompleteness`;
- protocol DTOs expose exact aggregate facts and visible-child completeness, not
  pdu constructor semantics;
- Flutter can render aggregate bars and visible child sums, but cannot derive
  cleanup/reclaim totals from `aggregate - visible_children`.

Contract tests:

- `PduTreeConverter` maps pdu stored size to aggregate evidence only;
- visible-child sum mismatch is allowed when children are hidden by depth,
  filters, read errors, boundary skips, or projections;
- engine projections never call pdu `DataTree::dir`;
- hardlink-adjusted pdu helper output cannot replace primary aggregate evidence;
- own size stays unknown until metadata/accounting enrichment provides it;
- details and export views label aggregate, own, visible child, and reclaim
  values separately.

## Reporter Callback Contract

pdu `Reporter::report` is called synchronously from traversal code. Since
`TreeBuilder` uses Rayon, calls can arrive from Rayon worker threads.

pdu event payloads are borrowed:

```text
EncounterError(ErrorReport { path: &Path, error })
DetectHardlink(HardlinkDetection { path: &Path, stats: &Metadata, size, links })
```

Source-level facts from pdu 0.23.0:

- `Reporter::report(&self, event)` returns `()`, not `Result`, so pdu traversal
  has no error/backpressure channel from reporter to scanner;
- `Reporter` has no async boundary, no explicit queue, no drop policy, and no
  cancellation token;
- `ProgressAndErrorReporter::new` spawns one OS thread and calls the supplied
  progress callback after `sleep(progress_report_interval)`;
- pdu CLI uses `ProgressAndErrorReporter` with 100 ms text output;
- built-in progress state uses `AtomicBool` and `AtomicU64` with `Relaxed`
  ordering, which is fine for approximate counters but not an event-ordering or
  audit contract;
- on `EncounterError`, pdu calls `report_error(error_report)` before incrementing
  the built-in error counter;
- `DetectHardlink` increments `linked` by link count and `shared` by size, but it
  is not a hardlink group stream or reclaim authority;
- `ParallelReporter::destroy(self)` consumes the reporter and may return a join
  panic payload for `ProgressAndErrorReporter`;
- `FsTreeBuilder` only requires `Reporter<Size> + Sync`, not `ParallelReporter`;
- pdu implements `Reporter` for `&Target`, so adapter code can pass shared
  reporter references without transferring reporter ownership to the scan;
- `ErrorOnlyReporter` ignores progress and hardlink events entirely.

### Reporter Lifecycle Trait Boundary

pdu `ParallelReporter` is not the product scan lifecycle port. It is a helper
trait for reporters that own reporting threads or teardown work.

Top 3 lifecycle strategies:

1. Production `PduReporter` implements only pdu `Reporter` - 🎯 10 🛡️ 10 🧠 5,
   roughly 300-900 LOC.
   Accepted. The engine owns session lifecycle, cancellation, snapshots, and
   event sequencing. The reporter only captures bounded evidence.
2. Production `PduReporter` implements pdu `ParallelReporter` and maps
   `destroy()` into session finish - 🎯 4 🛡️ 5 🧠 4, roughly 400-1200 LOC.
   Rejected. It lets pdu lifecycle vocabulary leak into engine/session code and
   makes reporter teardown look like scan finalization.
3. Use pdu `ProgressAndErrorReporter` and wrap its `destroy()` - 🎯 3 🛡️ 4 🧠 2,
   roughly 100-400 LOC.
   Rejected for production. It owns a detached progress thread and text-oriented
   progress model.

Accepted lifecycle contract:

```text
PduReporter
  implements pdu Reporter only
  no owned OS progress thread
  no pdu ParallelReporter lifecycle
  snapshot() returns bounded evidence
  dispose() is adapter-owned cleanup, not pdu destroy()

ScanSessionLifecycle
  owned by fs_usage_engine
  create/start/cancel/finish/dispose
  never calls pdu ParallelReporter::destroy
```

Layer rules:

- `fs_usage_engine` owns scan lifecycle and session state transitions;
- `fs_usage_pdu` owns pdu reporter implementation details;
- `clean-disk-server` owns WebSocket lifecycle and client subscription state;
- pdu `ParallelReporter::destroy` may appear only in diagnostics that explicitly
  use pdu `ProgressAndErrorReporter`;
- product code must not model `destroy()` as scan completion, cancellation, or
  final summary publication.

Contract rules:

- `PduReporter` must be non-blocking or bounded.
- `PduReporter` must copy only minimal owned evidence before returning.
- `PduReporter` must not call WebSocket, HTTP, SQLite, Flutter, logging sinks,
  or localization directly.
- `PduReporter` must not retain borrowed pdu paths or metadata references.
- raw paths copied by the reporter must stay in redaction-aware internal
  evidence stores, not production logs.
- reporter panic must not cross into uncontrolled daemon state.
- pdu built-in progress counters are evidence snapshots, not ordered events.
- pdu `Reporter::report` must never block scanner worker threads on UI, network,
  database, telemetry, or unbounded allocation.
- event sequence, audit sequence, and WebSocket sequence numbers are created by
  `fs_usage_engine`/`clean-disk-server`, not inherited from pdu.

Top 3 reporter designs:

1. Atomic counters plus bounded issue/hardlink sample buffers - 🎯 9 🛡️ 9 🧠 6,
   roughly 600-1600 LOC.
   Accepted MVP. Fast path increments counters; slow path copies limited issue
   samples and hardlink evidence. Event fanout reads throttled snapshots outside
   pdu callbacks.
2. Bounded channel from reporter to event task - 🎯 7 🛡️ 8 🧠 7, roughly
   900-2200 LOC.
   Useful later, but must define drop/backpressure policy. A full channel must
   not block Rayon scanner workers.
3. Use pdu `ProgressAndErrorReporter` directly - 🎯 3 🛡️ 4 🧠 2, roughly
   50-200 LOC.
   Rejected for product. It owns a progress thread and text-oriented semantics,
   and it does not match daemon privacy/backpressure/event contracts.

Accepted reporter flow:

```text
pdu Reporter::report
  -> PduReporter atomics and bounded evidence buffers
  -> PduReporterSnapshot
  -> fs_usage_engine throttles ScanEvent
  -> clean_disk_server maps to WebSocket event DTO
```

Accepted event/backpressure contract:

```text
PduReporter
  fast_path = atomics
  slow_path = bounded evidence samples
  overflow = set truncation/degraded flags
  forbidden = blocking IO | async runtime calls | DB writes | socket writes

PduReporterSnapshot
  counters
  bounded_issue_samples
  bounded_hardlink_samples
  truncation_flags
  observed_at_monotonic

ScanEventSequencer
  reads snapshots outside pdu callbacks
  assigns product sequence numbers
  throttles UI events
  records dropped/coalesced evidence
```

The reporter is raw evidence capture, not product event delivery. It is an
adapter-side anti-corruption layer between pdu's synchronous callbacks and our
daemon/application event model.

Contract tests:

- `PduReporter::report` performs no socket, HTTP, SQLite, localization, or
  blocking log sink calls;
- copied issue/hardlink samples are bounded and set truncation evidence on
  overflow;
- borrowed `&Path` and `&Metadata` never survive the callback;
- product WebSocket sequence numbers are monotonic even when pdu events arrive
  concurrently from Rayon workers;
- built-in pdu `ProgressAndErrorReporter` is not used in production adapter code;
- reporter panic is contained and mapped to backend failure evidence.

## Hardlink Accounting Strategy

pdu hardlink behavior has two separate phases:

```text
FsTreeBuilder traversal
  -> HardlinkAware::record_hardlinks records evidence and emits DetectHardlink
  -> DataTree still contains raw measured sizes

optional post-pass
  -> HardlinkAware::deduplicate(&mut DataTree)
  -> DataTree is mutated by subtracting duplicate sizes from matching prefixes
```

Important source behavior:

- `FsTreeBuilder` ignores `record_hardlinks` errors with `.ok()`;
- `HardlinkList` can detect size and link-count conflicts internally;
- pdu hardlink support is Unix-only;
- deduplication mutates aggregate directory sizes;
- pdu hardlink summary distinguishes total links, detected links, exclusive
  inodes, and exclusive shared size.
- `LinkPathListReflection` stores paths in a `HashSet`, so reflection can erase
  duplicate path observations and does not preserve detection order.
- `HardlinkListReflection` is sorted by inode/device for inspection, not by path,
  size, tree order, or product relevance.

Top 3 product strategies:

1. Keep primary tree raw, map hardlinks as separate evidence - 🎯 9 🛡️ 9 🧠 7,
   roughly 1200-2600 LOC.
   Accepted. `SizeFacts.measured` stays the direct pdu measurement. Hardlink
   evidence can add `hardlink_adjusted_size` or confidence tags later without
   hiding what was measured.
2. Call pdu deduplicate before converting to `NodeArena` - 🎯 5 🛡️ 6 🧠 4,
   roughly 400-1200 LOC.
   Simpler UI totals, but it loses raw measurement semantics and makes reclaim
   estimates look more certain than they are.
3. Build both raw and deduped trees - 🎯 6 🛡️ 7 🧠 8, roughly 1800-4200 LOC.
   Good evidence, poor memory profile for huge scans. Only consider if real
   product workflows need side-by-side hardlink views.

Accepted hardlink contract:

```text
NodeArenaRecord.size_facts.primary = pdu measured size
NodeArenaRecord.hardlink_refs = optional hardlink evidence
SizeFacts.hardlink_adjusted = optional, confidence-tagged projection
Reclaim estimate = accounting layer, never pdu hardlink summary alone
```

`HardlinkPolicy::DetectUnix` means "collect evidence". It does not mean "the UI
may show exact reclaimable bytes".

## DataTree Conversion Strategy

pdu `DataTree` has private fields. Public access is through `name()`, `size()`,
`children()`, mutation helpers, and `into_reflection(self)`.

This matters because converting a million-node result into our arena can
temporarily hold both the pdu tree and the engine read model.

Top 3 conversion options:

1. Borrowing converter over `DataTree` getters - 🎯 8 🛡️ 8 🧠 5, roughly
   600-1400 LOC.
   Walk `name()`, `size()`, and `children()` and write `NodeArenaRecord`s. This
   avoids building pdu `Reflection`, but keeps the whole pdu `DataTree` alive
   while the arena is built. It is the accepted MVP unless memory profiling
   proves otherwise.
2. Consuming converter through `into_reflection(self)` - 🎯 6 🛡️ 7 🧠 6,
   roughly 800-1800 LOC.
   This consumes `DataTree` and moves names/sizes into `Reflection`, then into
   our arena. It may reduce some ownership friction, but still creates another
   tree-shaped intermediate and makes pdu `Reflection` tempting to leak. Use
   only if it is measured to improve memory or simplify non-UTF-8 handling.
3. Upstream/fork `DataTree::into_parts` or consuming visitor - 🎯 7 🛡️ 8 🧠 9,
   roughly 2000-6000 LOC including upstream/fork maintenance.
   Best long-term memory profile because the adapter can consume pdu nodes
   directly into the arena. Not MVP unless memory spike shows the borrowed
   converter is unacceptable on real `~/Library`-scale scans.

Accepted MVP:

```text
pdu DataTree
  -> PduTreeConverter borrows and writes NodeArena
  -> build indexes
  -> drop DataTree immediately
```

Contract rule:

```text
PduTreeConverter may use pdu getters internally.
It must not expose DataTree, Reflection, or OsStringDisplay.
It must record conversion memory/time metrics.
```

### PduTreeConverter Stack Boundary

pdu's own traversal is recursive, and pdu helper operations such as sort, retain,
and hardlink dedupe are also recursive. Even after pdu successfully returns a
`DataTree`, Clean Disk can still introduce a second stack risk if
`PduTreeConverter` recursively walks the pdu tree into `NodeArena`.

Source-level facts:

- `TreeBuilder::from` recursively calls `Self::from` for each child builder;
- `DataTree::par_sort_by` recursively walks descendants before calling
  `sort_unstable_by`;
- `DataTree::par_retain_with_depth` recursively walks descendants;
- pdu hardlink dedupe recursively calls `par_deduplicate_hardlinks` on
  children;
- pdu `DataTree::children()` exposes nested `Vec<DataTree<...>>`, not an
  iterator with stack-depth control;
- pdu does not expose a consuming visitor, iterative traversal API, max stack
  budget, or per-node callback stream.

Product consequence:

```text
pdu scan success
  does not prove engine conversion is stack-safe.

pdu max_depth
  does not protect converter stack if returned tree is still deep enough.

PduTreeConverter
  must own an explicit traversal strategy and depth evidence.
```

Top 3 converter stack policies:

1. Iterative `PduTreeConverter` with explicit stack/depth metrics - 🎯 10
   🛡️ 10 🧠 7, roughly 700-1800 LOC.
   Accepted. It prevents a second stack risk after pdu scan and gives us
   measurable depth evidence for diagnostics and release gates.
2. Recursive converter with synthetic deep-tree tests only - 🎯 5 🛡️ 5 🧠 2,
   roughly 200-600 LOC.
   Rejected for product implementation. Tests can reveal a limit, but they do
   not remove the design risk.
3. Convert through pdu `Reflection` to avoid writing traversal code - 🎯 4
   🛡️ 5 🧠 5, roughly 500-1400 LOC.
   Rejected as the main path. It still creates a tree-shaped intermediate,
   weakens non-UTF-8 fidelity, and tempts pdu schema leakage.

Accepted contract:

```text
PduTreeConverter
  traversal = iterative_explicit_stack
  records max_returned_depth
  records max_converter_stack_len
  records path_depth_issues
  writes NodeArenaRecord once per pdu node
  drops pdu tree as soon as indexes allow

ConverterDepthEvidence
  max_seen_depth
  max_stack_len
  truncated = false | true
  backend_depth_guard = false for pdu
  converter_depth_guard = true
```

Layer rules:

- `fs_usage_pdu` owns pdu tree traversal and the converter implementation;
- `fs_usage_engine` receives `NodeArena` plus depth metrics, not pdu traversal
  details;
- `fs_usage_core` owns depth evidence vocabulary and degraded quality reasons;
- recursive helper paths from pdu are forbidden for product query/projection
  conversion;
- if pdu scan itself overflows or panics on deep trees, adapter containment maps
  it to backend failure and opens an upstream/fork/helper-process review;
- if converter stack/depth budget is exceeded, snapshot publication fails
  closed or returns degraded partial evidence, never a half-built read model.

Contract tests:

- synthetic deep chain converts without recursive Rust stack growth in
  `PduTreeConverter`;
- converter records max depth and explicit stack length;
- pdu `DataTree` and partially built `NodeArena` are not published until
  conversion and primary indexes complete;
- converter budget failure returns typed backend/conversion failure;
- recursive pdu helpers are not imported into product conversion modules.

Memory gate:

```text
Measure pdu_scan_peak, tree_convert_peak, index_build_peak.
If pdu DataTree + NodeArena double-memory exceeds budget, spike consuming
visitor/upstream patch before adding metadata enrichment.
```

## Reflection And JSON Boundary Semantics

pdu's `Reflection` and `JsonData` are attractive because they expose public
fields and serde support. For Clean Disk, that is precisely why they need an
explicit anti-corruption boundary.

Source-level facts:

- `DataTree` itself does not implement serde. pdu serializes by converting
  `DataTree` into `Reflection`;
- `Reflection<Name, Size>` has public `name`, `size`, and `children` fields;
- pdu source comments say a `Reflection` can be transmuted into a potentially
  invalid `DataTree`, which is why `par_try_into_tree` exists;
- docs state `Reflection` can be converted into a potentially invalid
  `DataTree`, and safe conversion requires `par_try_into_tree`;
- `par_try_into_tree` checks only that no child is larger than its parent. It
  does not validate path identity, permissions, node kind, scan completeness,
  target policy, or cleanup safety;
- `par_try_into_tree` accepts parent sizes that are greater than the sum of
  children, which is normal for pdu aggregate/own-size semantics but not a proof
  of completeness;
- `par_try_map` transforms children before the current node, so diagnostic
  transform failures can be reported from descendants before root context is
  fully mapped;
- `par_convert_names_to_utf8` returns an error when a name is not valid UTF-8;
- pdu CLI JSON output calls `par_convert_names_to_utf8().expect(...)`, with a
  source TODO about allowing non-UTF-8 names;
- pdu `JsonData` is tagged by size unit and contains pdu `schema-version`,
  optional pdu binary version, pdu tree reflection, and optional hardlink shared
  details/summary;
- pdu `SchemaVersion` currently accepts exactly `2026-04-02`;
- pdu `BinaryVersion` is an optional string and is not used as a compatibility
  decision in the CLI visualization path;
- pdu JSON input conflicts with filesystem path arguments, then deserializes
  `JsonData`, ignores `binary_version` after serde, converts the reflection back
  to `DataTree`, and renders a terminal visualizer;
- pdu JSON input can use `.shared.summary`, or derive a summary from
  `.shared.details` if summary is missing;
- pdu JSON contains no scan issues, skipped-path evidence, capabilities,
  permission repair state, node ids, target ids, query cursors, operation
  journal, or cleanup authority;
- pdu JSON input is CLI visualization input. The CLI turns JSON back into
  `DataTree`, then renders it through `Visualizer`.

Top 3 policies:

1. Product protocol/cache never uses pdu JSON or `Reflection` - 🎯 10 🛡️ 10
   🧠 5, roughly 300-900 LOC for adapters, guards, and tests.
   Accepted. We keep our own protocol DTOs, persistence schemas, and read-model
   records. pdu JSON is a fixture/diagnostic convenience only.
2. Use pdu JSON internally between Rust daemon and Flutter - 🎯 3 🛡️ 3 🧠 4,
   roughly 200-800 LOC first, but high rewrite risk.
   Rejected. It loses non-UTF-8 fidelity, leaks pdu version/schema semantics,
   has no node ids/cursors/metadata/issues, and cannot express partial scan
   authority.
3. Use pdu `Reflection` as the first engine read model, then enrich it - 🎯 4
   🛡️ 5 🧠 6, roughly 800-2200 LOC.
   Rejected for product state. It still has pdu-shaped names, aggregate sizes,
   and child vectors. It also encourages whole-tree transport and whole-tree
   persistence.

Accepted boundary:

```text
pdu DataTree
  -> PduTreeConverter
  -> NodeArena / ReadModelIndexes / ScanIssues

pdu Reflection / JsonData
  -> test fixture codec or diagnostic import/export only
  -> never protocol, persistence, Flutter DTO, or cleanup authority
```

Diagnostic snapshot contract:

```text
PduDiagnosticSnapshot
  provenance = pdu_json | pdu_reflection | fixture
  pdu_schema_version
  pdu_binary_version
  unit_tag
  utf8_only = true
  path_fidelity = reduced
  authority = diagnostic_read_only
  cleanup_allowed = false
```

If we enable pdu `json` for diagnostics, the feature must be explicit:

```text
fs_usage_pdu/diagnostics may import pdu json_data and Reflection.
fs_usage_pdu/adapter and fs_usage_pdu/mapper must not depend on pdu JSON or
Reflection codecs.
clean-disk-server production feature set must keep pdu json disabled unless
diagnostic endpoints are explicitly built and gated.
```

Protocol consequence:

- Clean Disk DTOs encode node ids, snapshot ids, cursor/page tokens, exact size
  strings, issue codes, capability state, and schema version independently from
  pdu;
- non-UTF-8 names stay representable in Rust read model through platform path
  components and display-safe rendering adapters;
- exports use Clean Disk export profiles, not pdu JSON, unless the user chooses
  a clearly labeled diagnostic pdu fixture export;
- importing pdu JSON, if ever supported, creates a diagnostic snapshot with
  reduced capability, no cleanup authority, and explicit provenance.
- pdu `schema-version` and `BinaryVersion` are recorded as pdu provenance, not
  Clean Disk protocol compatibility.
- pdu JSON `unit = bytes` maps to ambiguous byte evidence unless the diagnostic
  import also records the original pdu quantity/mode.
- pdu shared hardlink summary/detail import maps to diagnostic hardlink evidence
  only and must pass the same panic containment/confidence rules as live scans.

Memory consequence:

```text
Reflection is another tree-shaped allocation.
Diagnostic code that builds Reflection must report memory separately and must
not run in the normal scan-to-read-model path.
```

Top 3 diagnostic import/export strategies:

1. Keep pdu JSON as adapter-only fixture/diagnostic format - 🎯 10 🛡️ 10 🧠 5,
   roughly 500-1400 LOC.
   Accepted. It is useful for golden tests and pdu upgrade review without
   contaminating product protocol.
2. Convert pdu JSON into a reduced-authority diagnostic read model - 🎯 7 🛡️ 8
   🧠 7, roughly 1200-3000 LOC.
   Useful later for support bundles, but must stay read-only and visibly
   provenance-labeled.
3. Make pdu JSON a supported user export/import format - 🎯 4 🛡️ 5 🧠 6,
   roughly 1000-2600 LOC.
   Rejected for normal product flows. It cannot preserve enough authority,
   identity, issue, and non-UTF-8 path information.

## Capability Contract

The pdu backend must report capabilities honestly.

Initial pdu capability expectations:

```text
final_tree: yes
streaming_nodes: no
progress_counters: partial
cooperative_cancellation: no
request_cancel_discard_late_result: yes
stable_node_ids: engine-generated
metadata: no
full_path: engine-reconstructed
hardlinks_unix: partial
hardlinks_windows: no
device_boundary_unix: partial
device_boundary_non_unix: weak/no
search_indexes: engine-generated
delete_safety: no
reclaim_estimate: no
```

Unknown or weaker capability must disable risky operations by default.

## Upstream Change Guardrails

pdu is small and useful, but its API is not our product boundary. Treat every
pdu upgrade as an adapter compatibility event.

Version pin:

```toml
parallel-disk-usage = { version = "=0.23.0", default-features = false }
```

Adapter upgrade checklist:

- run pdu fixture corpus before changing the pin.
- diff `FsTreeBuilder` public fields.
- diff `DataTree` public methods and conversion APIs.
- diff `Reporter`, `Event`, `ErrorReport`, and `Operation`.
- diff `GetSize`, `DeviceBoundary`, and hardlink modules.
- verify `cli` is still disabled in product dependency graph.
- verify pdu still does not call `build_global()` from library path.
- verify non-UTF-8 fixture still bypasses pdu JSON.
- verify hardlink and `max_depth` semantics against golden fixtures.
- update `PduBackendCapabilities` if a pdu feature becomes stronger/weaker.

Non-exhaustive rule:

```text
Any match on pdu non_exhaustive enums must have an unknown/fallback branch.
Unknown pdu events or errors map to degraded adapter evidence, not panic.
```

Feature rule:

```text
default-features = false in production.
json feature may be enabled only for tests/diagnostics behind explicit feature.
cli feature is forbidden in clean-disk-server dependency graph.
```

Source ownership rule:

```text
docs.rs confirms the public API.
Cargo registry source confirms hidden behavior.
Local fixtures confirm what our adapter relies on.
All three are required before accepting a pdu upgrade.
```

## Layer Contract Checklist

Use this checklist when implementing the first Rust crates and Flutter scan
feature. It is intentionally strict because pdu leakage is easy to miss.

### Domain Checklist

Allowed in `fs_usage_core`:

- opaque ids and refs: `ScanSessionId`, `ScanSnapshotId`, `NodeId`, `NodeRef`;
- product policies: `TraversalPolicy`, `BoundaryPolicy`, `HardlinkPolicy`,
  `SizePolicy`;
- product facts: `SizeFacts`, `ScanIssue`, `ScanQuality`,
  `TraversalEvidence`;
- product safety language: `PermissionState`, `PathIdentityEvidence`,
  `NodeKind`;
- value objects that remain valid with pdu, MFT, or any future scanner.

Forbidden in `fs_usage_core`:

- `parallel_disk_usage`;
- `std::fs` traversal choices;
- pdu `DataTree`, `FsTreeBuilder`, `Reporter`, `Event`, `Operation`;
- pdu `Bytes`, `Blocks`, formatted size strings, JSON schema, or visualizer
  concepts;
- daemon HTTP/WebSocket DTOs;
- Flutter/Dart concepts.

### Application Checklist

Allowed in `fs_usage_engine`:

- `ScannerBackend` and other ports;
- `BackendScanRequest`, `BackendScanOutput`, `ScannerBackendCapabilities`;
- `ScanSessionState`, `ResourceProfile`, `ExecutionLane`;
- `ScanSnapshotDraft`, `NodeArenaWriter`, `ReadModelIndexes`;
- query, pagination, sort, search, and top-list contracts.

Forbidden in `fs_usage_engine`:

- importing pdu directly;
- depending on pdu child order;
- exposing pdu event names or pdu error operation names;
- making delete decisions from scan rows;
- letting backend-specific options become public product settings.

### Data/Infrastructure Checklist

Allowed in `fs_usage_pdu`:

- pdu imports;
- pdu option mapping;
- pdu reporter implementation;
- pdu raw result structs;
- pdu-to-engine mappers;
- pdu version and contract fingerprinting;
- adapter-only fixtures that use pdu JSON when explicitly enabled.

Forbidden in `fs_usage_pdu` public API:

- public pdu types;
- `DataTree` return values;
- pdu JSON product DTOs;
- pdu formatted strings;
- raw pdu operation names as product reason ids;
- blocking event fanout from pdu callback.

### Protocol And Flutter Data Checklist

Allowed in `clean_disk_protocol` and `features/scan/data`:

- versioned DTOs;
- query/page/event envelopes;
- DTO mappers into application models;
- capability DTOs that describe backend behavior honestly.

Forbidden:

- pdu-shaped DTOs;
- exposing pdu raw flags as UI controls;
- using cached Flutter rows as cleanup authority;
- relying on JSON numeric precision for large counters, ids, byte sizes, cursors,
  or event sequences.

Implementation stop rule:

```text
If a pdu type or pdu-specific term appears outside fs_usage_pdu tests, stop and
add a mapper, port, or domain value object instead.
```

## First Implementation Contract Skeleton

This is the contract shape to implement before any UI data integration. Names may
change during coding, but ownership and direction must not change without a new
architecture decision.

### Domain Contract Sketch: `fs_usage_core`

Domain types are product language. They must be serializable/testable if useful,
but they are not protocol DTOs and not pdu wrappers.

```text
ScanSessionId
ScanSnapshotId
NodeId
NodeRef
  snapshot_id
  node_id

ScanTarget
  target_id
  requested_path
  display_name
  target_kind

PathSegmentEvidence
  segment_id
  native_segment_ref
  display_name
  display_encoding
  contains_control_or_bidi

NodePathEvidence
  target_id
  parent_ref
  segment_ref
  pdu_name_kind
  reconstructed_path_ref
  path_confidence

TraversalPolicy
  symlink_policy
  boundary_policy
  hidden_file_policy

TraversalDepthPolicy
  full_walk
  cutoff_when_backend_supports_it

ProjectionDepthPolicy
  full_tree
  stored_depth

QueryExpansionPolicy
  from_snapshot_read_model
  requires_rescan_when_projection_hidden

SizePolicy
  primary_measurement
  collect_secondary_facts

HardlinkPolicy
  ignore
  detect_when_supported
  adjusted_projection_when_supported

HardlinkEvidence
  evidence_id
  identity_kind
  observed_path_count
  reported_link_count
  measured_size
  scope
  conflict
  confidence

SizeFacts
  aggregate_measured
  own_measured
  child_visible_sum
  logical_bytes
  allocated_bytes
  unix_block_count
  hardlink_adjusted_bytes
  exclusive_reclaim_estimate
  quota_effect_bytes
  observed_free_space_delta
  confidence
  evidence_refs

ScanIssue
  issue_id
  reason
  severity
  affected_ref
  confidence
  evidence_ref
  repair_hint

ScanQuality
  complete
  complete_with_warnings
  partial
  failed_target
  cancelled
  failed_backend
```

Domain rule:

```text
Domain tells the truth about what we know.
It never promises what pdu merely measured.
```

### Application Contract Sketch: `fs_usage_engine`

Application owns use cases, ports, orchestration, session lifecycle, and query
read models.

```text
ScannerBackend
  capabilities() -> ScannerBackendCapabilities
  scan(request, event_sink) -> Result<BackendScanOutput, ScanFailure>

BackendScanRequest
  session_id
  snapshot_epoch
  target_set
  traversal_policy
  boundary_policy
  size_policy
  hardlink_policy
  resource_profile
  event_policy

BackendScanOutput
  snapshot_draft
  issues
  target_outcomes
  backend_metrics
  capability_observations
  phase_metrics

TargetScanOutcome
  target_id
  preflight_state
  backend_walk_state
  root_node_ref
  scan_quality
  issue_refs
  query_visibility
  cleanup_eligibility

ScanPhaseEvent
  session_id
  snapshot_epoch
  phase
  progress_hint
  started_at
  finished_at
  evidence_ref

NodeArenaRecord
  node_id
  parent_id
  name
  display_path_ref
  depth
  child_range
  child_completeness
  size_facts
  node_kind_state
  issue_refs
  hardlink_refs
  metadata_state
  traversal_evidence_refs

ReadModelIndexes
  children_by_parent
  top_by_size
  search_index
  issue_index
  path_lookup_index
```

Application rule:

```text
The engine owns all durable scan query semantics.
Backends only provide evidence and capability-limited outputs.
Scan phases are product states, not backend callback names.
```

Top 3 `ScannerBackend` result shapes:

1. `BackendScanOutput` with `ScanSnapshotDraft` plus separate issues/metrics -
   🎯 10 🛡️ 10 🧠 7, roughly 800-1800 LOC.
   Accepted. It keeps scan data, quality evidence, and backend diagnostics
   separate enough for pdu, MFT, and future scanners.
2. `Result<NodeArena, ScanFailure>` only - 🎯 4 🛡️ 5 🧠 3, roughly 300-900 LOC.
   Rejected. It hides partial scans and makes permission/skipped path UX weak.
3. Stream every node through `ScannerBackend` as the primary model - 🎯 5 🛡️ 6
   🧠 8, roughly 1800-4500 LOC.
   Not for MVP because pdu does not stream nodes. Keep DTOs future-ready, but
   use final tree conversion first.

### Infrastructure Contract Sketch: `fs_usage_pdu`

`fs_usage_pdu` is an anti-corruption adapter. Its public API should speak
`fs_usage_engine`, while its private internals can speak pdu.

```text
PduScannerBackend
  -> PduBackendCapabilities
  -> PduOptionsMapper
  -> PduExecutionLane
  -> PduScanRunner
  -> PduReporter
  -> PduRawScanResult
  -> PduTreeConverter
  -> PduIssueMapper
  -> PduHardlinkMapper
  -> PduSizeFactsMapper
  -> BackendScanOutput
```

Private adapter-only records:

```text
PduOptions
  root_path
  size_getter_kind
  device_boundary_kind
  hardlink_mode
  max_depth
  resource_profile_fingerprint

PduReporterSnapshot
  receive_data_count
  receive_data_total
  error_count
  hardlink_event_count
  progress_snapshot_kind = approximate
  event_order_state = unstable
  dropped_evidence_count
  issue_samples
  hardlink_samples
  evidence_truncated

PduHardlinkEvidenceStore
  observed_inode_count
  observed_path_count
  outside_scan_candidate_count
  conflict_count
  evidence_truncated

PduCancelEpoch
  session_id
  request_epoch
  cancel_requested_at
  stale_result_policy

PduPanicBoundary
  panic_payload_class
  backend_failure_reason
  daemon_recovered

PduRawScanResult
  data_tree
  reporter_snapshot
  raw_scan_metrics
  pdu_version
  pdu_feature_set
  pdu_options_fingerprint
  timings
  resource_profile_used
```

Panic and mutation boundary:

```text
PduScanRunner catches/contains backend panics where Rust can recover.
PduTreeConverter does not call pdu sort/cull/deduplicate helpers.
PduHardlinkMapper treats pdu summaries as diagnostic evidence only.
```

Metadata boundary:

```text
PduScanRunner may observe metadata only through pdu traversal hooks.
PduTreeConverter does not claim current metadata facts.
MetadataProvider / IdentityProvider enrich current facts after conversion.
Delete preflight revalidates again.
```

Infrastructure rule:

```text
PduRawScanResult must die inside fs_usage_pdu.
Only BackendScanOutput crosses the adapter boundary.
```

### Flutter Data Contract Sketch: `features/scan/data`

Flutter data layer adapts Clean Disk protocol, not pdu.

```text
ScanRemoteDataSource
  start_scan(command_dto)
  cancel_scan(session_id)
  get_children(query_dto)
  get_node_details(node_ref_dto)
  search(query_dto)

ScanEventDataSource
  events(session_id) -> stream ScanEventDto

ScanRepositoryAdapter
  maps DTOs into application models
  reconciles event invalidations with paged queries
  never exposes raw route strings to stores
```

Flutter rule:

```text
data knows DTOs.
application knows ports and product models.
presentation knows stores and view models.
widgets know neither pdu nor daemon routes.
```

### Cross-Layer Contract Tests

Add these as soon as crate/package skeletons exist:

- Rust compile-fail or lint test: `parallel_disk_usage` import outside
  `fs_usage_pdu` fails CI.
- Rust unit test: `PduScannerBackend::scan` returns no public pdu type.
- Rust fixture test: pdu completed-with-errors maps to degraded `ScanQuality`.
- Rust fixture test: `max_depth` truncation creates traversal evidence.
- Rust fixture test: cross-device policy cannot silently become empty-complete
  directory.
- Rust fixture test: pdu hardlink recorder conflict lowers confidence.
- Protocol schema test: no DTO field names `data_tree`, `fs_tree_builder`,
  `pdu_operation`, or `pdu_error`.
- Dart test: scan repository maps DTOs into application models before stores.
- Dart test: cached row cannot create a delete plan without server preflight.

## Contract Tests Required Before Implementation

Implement these before the durable data/protocol contract is accepted:

1. normal nested tree maps to `NodeArena`.
2. pdu error event maps to degraded `ScanQuality`.
3. missing target is preflight failure, not silent zero-size success.
4. symlink-to-file and symlink-to-directory are not followed by default.
5. `max_depth` proves it is not lazy expansion.
6. hardlink detection on Unix maps to evidence only.
7. hardlink recorder conflict is represented as uncertain/degraded evidence.
8. non-UTF-8 name stays representable in Rust read model.
9. pdu JSON is excluded from product protocol tests.
10. `ResourceProfile` selects `PduExecutionLane`.
11. no pdu imports outside `fs_usage_pdu`.
12. `DataTree` is dropped after conversion in memory profile tests.
13. cancellation request discards late pdu result by epoch.
14. pdu upgrade fingerprint changes force semantic review.
15. borrowed `DataTree` converter does not leak pdu types.
16. conversion memory metrics are recorded for pdu tree, arena, and indexes.
17. unknown pdu event/error fallback maps to degraded evidence.
18. reporter callback stays non-blocking under synthetic high event volume.
19. reporter copies owned evidence and does not retain borrowed pdu references.
20. hardlink policy keeps raw measured size separate from hardlink-adjusted
    projection.
21. hardlink recorder conflict lowers confidence instead of silently claiming
    exact truth.
22. target normalization rejects missing roots before pdu.
23. duplicate and overlapping roots produce explicit diagnostics.
24. product synthetic root id does not use pdu `(total)` or empty-string root
    names.
25. pdu apparent, Unix allocated bytes, and Unix block count map to distinct
    `SizeFacts` fields.
26. web-facing DTOs encode exact large size values as strings, not JSON numbers.
27. pdu formatted units never become protocol or persistence values.
28. cross-device skips are not represented as empty directories.
29. read-dir ordering does not define UI/protocol ordering.
30. `max_depth` truncation is visible as traversal evidence, not lazy loading.
31. pdu `Operation` and `io::Error` do not leak into domain or protocol.
32. pdu scan completion with errors maps to degraded `ScanQuality`.
33. permission-like errors create repair-capable `ScanIssueReason` values.
34. production cargo feature graph proves pdu `cli` is disabled.
35. accidental pdu default-feature dependency fails the dependency boundary gate.
36. built-in pdu `ProgressReport` is not exposed as protocol progress DTO.
37. `AccessEntry` errors map to parent-directory issue evidence, not fabricated
    child paths.
38. custom hardlink recorder captures size and link-count conflict evidence even
    though `FsTreeBuilder` ignores recorder `Result`.
39. hardlink progress counters are not used as unique inode counts.
40. pdu `OsStringDisplay` formatted output is never used as path identity.
41. pdu cross-device empty-child result is not treated as complete traversal
    without platform boundary evidence.
42. pdu README limitations, especially reflink ignorance and symlink behavior,
    are represented in backend capability reporting.
43. pdu child order and reporter callback order do not define protocol or UI row
    order.
44. vanished child between `read_dir` and `symlink_metadata` maps to a scan issue,
    not backend failure.
45. pdu `AccessEntry` parent-path error does not fabricate an unknown child path.
46. size and progress counters convert through checked/saturating engine helpers.
47. overflow or saturation evidence lowers confidence and is visible in diagnostics.
48. pdu `par_retain`, `par_cull_insignificant_data`, and `par_sort_by` are not
    used for product query semantics.
49. equal-size row ordering is deterministic through engine indexes, not pdu
    `sort_unstable_by`.
50. pdu hardlink deduplication never mutates the primary product tree.
51. pdu hardlink summary panic is contained and maps to degraded backend evidence.
52. pdu helper-based diagnostics are behind explicit test/diagnostic feature gates.
53. `fs_usage_pdu` does not import pdu `visualizer`, `status_board`, `bytes_format`,
    `json_data`, `app`, `args`, or `runtime_error` in production code.
54. pdu presentation/terminal dependencies are tracked as adapter supply-chain
    surface, not product dependencies.
55. dependency governance has an escalation path: upstream issue/PR, controlled
    fork, or replacement backend.
56. pdu `max_depth` is mapped only to projection/storage depth, not true traversal
    cutoff.
57. true traversal cutoff is represented as unsupported pdu backend capability
    until implemented by another backend, fork, or upstream hook.
58. `DepthTruncated` never grants cleanup authority over descendants that are not
    current read-model nodes.
59. `DataTree.children.is_empty()` is never used to infer file/folder/symlink
    kind.
60. `PduTreeConverter` writes unknown or needs-enrichment node kind state until
    platform metadata proves current kind.
61. target preflight classifies file, directory, symlink, missing, inaccessible,
    unsupported, and policy-blocked roots before pdu runs.
62. root pdu zero-size output is not accepted without matching successful target
    preflight evidence.
63. pdu `GetSize` is treated only as a measurement hook, not metadata enrichment.
64. `PduTreeConverter` does not claim current permissions, owner, modified time,
    cloud state, or identity from pdu `DataTree`.
65. metadata enrichment metrics are recorded separately from pdu scan, tree
    conversion, and index build.
66. delete preflight revalidates current metadata and identity even when a node was
    enriched earlier.
67. pdu `Reflection` never appears in server protocol DTOs, Flutter DTOs,
    persistence schemas, or domain/application models.
68. non-UTF-8 fixture bypasses pdu JSON and stays representable in the Rust read
    model.
69. pdu JSON conversion failure maps to diagnostic/test failure, not product scan
    failure.
70. pdu `par_try_into_tree` validation is not used as product trust validation.
71. pdu `JsonData.schema_version` and `BinaryVersion` are not reused as Clean Disk
    protocol compatibility fields.
72. diagnostic code that builds pdu `Reflection` records memory separately and is
    excluded from the normal product scan path.
73. any pdu JSON import creates a reduced-authority diagnostic snapshot with no
    cleanup/delete capability.
74. pdu reporter callback does not perform WebSocket send, DB write, blocking log
    formatting, or expensive path normalization.
75. pdu `Event` matching includes a future/unknown fallback because the enum is
    non-exhaustive.
76. `DetectHardlink` borrowed path and metadata are copied into owned adapter
    evidence before returning from `Reporter::report`.
77. pdu `Operation` values map into our issue taxonomy and do not leak into
    domain, protocol, or Flutter models.
78. progress snapshots are treated as best-effort backend evidence and never as
    scan completion or cleanup authority.
79. first observed `nlink > 1` path is treated as hardlink candidate evidence,
    not as a duplicate already found.
80. `detected_paths < nlink` maps to hardlink evidence that can have links
    outside the scan scope.
81. hardlink size conflict and link-count conflict are captured by our recorder
    even though pdu traversal ignores recorder `Result`.
82. pdu hardlink dedupe does not mutate `NodeArenaRecord.size_facts.primary`.
83. pdu hardlink summary panic is contained and maps to
    `summary_inconsistent` degraded evidence.
84. hardlink-adjusted size is never exposed as exact reclaimable bytes.
85. non-Unix backend capabilities report pdu hardlink detection as unsupported.
86. delete preflight validates current file identity even when hardlink evidence
    exists for the scanned node.
87. pdu scan runs inside `PduExecutionLane`, not server request handler runtime.
88. pdu adapter never calls `rayon::ThreadPoolBuilder::build_global`.
89. resource profiles map to bounded pdu lane settings and are visible in backend
    metrics.
90. cancel command moves session to `cancelling` quickly even while pdu continues
    internally.
91. late pdu result is discarded when session epoch/request id is stale.
92. stale pdu progress/events are ignored after cancellation or restart.
93. recoverable pdu panic maps to backend failure and does not kill the daemon.
94. pdu helper panic in diagnostics does not cross into product scan flow.
95. if panic strategy is abort or containment is impossible, helper-process
    isolation is required before relying on panic recovery.
96. pdu root `DataTree.name()` full path semantics are mapped differently from
    child `file_name()` segment semantics.
97. `OsStringDisplay::Display` output is never used for path identity, cache
    keys, delete commands, or protocol authority.
98. non-UTF-8 path fixture produces display-safe text plus lossy/debug evidence,
    while retaining server-side native path evidence.
99. two distinct native paths that render to the same lossy display string remain
    distinct through `NodeRef` and path evidence.
100. pdu JSON/Reflection path conversion is not used in product path tests.
101. Flutter command DTOs cannot send `displayPath` as delete authority.
102. path export/clipboard behavior uses explicit redaction and safety policy,
     not raw pdu names.
103. bidi/control-character filename fixture is marked for safe UI rendering.
104. no pdu CLI modules `app`, `args`, or `runtime_error` are imported by
     production `fs_usage_pdu` modules.
105. no pdu CLI fake root names `""` or `"(total)"` appear in protocol,
     persistence, or Flutter state.
106. no-target product flow uses explicit app default target policy, not pdu
     CLI fallback to `"."`.
107. multi-root product flow creates engine `SyntheticRootKind`, not pdu CLI
     synthetic root.
108. target overlap handling emits product diagnostics and follows
     `ScanTargetSet.overlap_policy`.
109. pdu CLI `min_ratio` culling does not affect product read model,
     pagination, search, or cleanup authority.
110. pdu CLI `par_sort_by` does not define product row ordering.
111. pdu CLI default size quantity does not override explicit `SizePolicy`.
112. pdu CLI HDD thread auto-limit does not replace product `ResourceProfile`.
113. pdu CLI JSON output is used only for diagnostic/fixture comparison.
114. pdu `par_retain`/CLI culling hidden descendants do not become cleanup
     targets.
115. pdu node with empty `children` after retain/cull is not inferred as file or
     complete directory.
116. projected/truncated child state is explicit in read model evidence when any
     pdu retain/cull helper is used diagnostically.
117. parent aggregate size can include hidden descendants, and UI must not claim
     visible children sum equals full parent size without evidence.
118. pdu `DataTree.size()` maps to aggregate measured size only.
119. `PduTreeConverter` never derives own measured size as
     `aggregate - visible_children_sum`.
120. `own_measured` starts unknown unless filled by platform metadata,
     accounting, or a stronger scanner backend.
121. `child_visible_sum` carries completeness evidence: complete, projected,
     partial, or unknown.
122. node details UI can show aggregate size without claiming own size.
123. reclaim/delete estimates never depend on pdu aggregate-minus-children
     arithmetic.
124. wide-directory fixture records child-name collection and pdu tree memory
     pressure separately from arena/index memory.
125. pdu `streaming_nodes` capability remains false until a visitor/streaming
     backend exists.
126. protocol tests prove Flutter receives paginated rows, not a full pdu tree.
127. `max_depth` is not used as the default memory-control mechanism for product
     scans.
128. pdu tree is dropped immediately after successful conversion into the engine
     read model.
129. memory budget breach triggers degraded/failure state or backend strategy
     review, not silent UI partial truth.
130. deep-tree fixture proves pdu backend behavior on thousands of nested
     directories before release performance claims.
131. pdu `max_depth` is not documented or exposed as a traversal-depth safety
     cutoff.
132. deep path-length failures map to scan issues, not complete empty subtrees.
133. pdu backend capabilities report `stack_depth_guard = false` until a real
     guard exists.
134. pdu backend capabilities report `true_traversal_cutoff = false` until a
     real traversal cutoff exists.
135. deep-tree panic or stack failure is contained as backend failure where
     platform/profile allows recovery.
136. engine read model records returned tree max depth separately from requested
     projection depth.
137. path-depth/path-length degraded evidence is visible in diagnostics.
138. symlink-to-file, symlink-to-directory, and broken symlink fixtures map pdu
     tree nodes to `NeedsEnrichment`, not final node kind.
139. pdu `DataTree.children.is_empty()` is never used to classify file, link,
     empty directory, unreadable directory, boundary skip, or projected node.
140. link/reparse policy comes from platform metadata, not pdu `DataTree`.
141. Windows reparse, junction, mount-point, and cloud placeholder fixtures stay
     unknown or blocking until platform adapters classify them.
142. delete preflight blocks stale replacement by symlink, reparse point, mount
     point, or provider placeholder unless policy explicitly allows it.
143. follow-symlink mode remains unsupported by the pdu backend until a separate
     backend/fork/upstream hook provides cycle and authority controls.
144. link/reparse UI icons and warnings are provisional until metadata enrichment
     is current.
145. hardlink evidence is never treated as symlink target evidence.
146. pdu built-in `ProgressAndErrorReporter` is not used as product progress
     contract in production adapter code.
147. progress snapshots are marked approximate and never become final scan state.
148. pdu event order is never used as protocol event order, UI row order, or issue
     severity order.
149. pdu reporter evidence buffer overflow maps to `ReporterEvidenceTruncated`
     and lowers diagnostic completeness.
150. final scan completion state is computed from backend output plus issue
     aggregation, not from last progress counters.
151. engine sequence numbers are assigned outside pdu callbacks and remain stable
     after throttling/batching.
152. pdu `DataTree::dir` aggregate size is never treated as own node size.
153. pdu `par_retain` output is marked projected if used diagnostically and is
     never accepted as a complete product child set.
154. pdu `par_cull_insignificant_data` is unavailable in the production adapter
     feature graph and cannot affect product pagination/search/cleanup.
155. pdu `par_sort_by` and `sort_unstable_by` never define UI/protocol ordering.
156. engine indexes provide deterministic sort tie-breakers independent of pdu
     child order and helper sort order.
157. pdu hardlink dedupe mutation never mutates `aggregate_measured` in the
     product `NodeArenaRecord`.
158. hardlink-adjusted bytes stay a separate `SizeFacts` projection with
     confidence/evidence, not primary size truth.
159. any pdu helper projection used for fixture comparison is marked
     `diagnostic_backend_projection` and has no delete authority.
160. pdu `u64` size arithmetic converts through checked/saturating domain helpers
     and records overflow or saturation evidence.
161. custom `PduMetadataTapRecorder` receives successful metadata reads and copies
     only bounded owned evidence.
162. metadata tap overflow maps to `metadata_tap_truncated`; returning `Err` from
     the recorder is not relied on because pdu ignores recorder errors.
163. Unix cross-device directory fixture is captured as boundary candidate
     evidence by the tap when root device evidence is available.
164. non-Unix pdu backend capabilities do not claim reliable
     `DeviceBoundary::Stay` enforcement from pdu alone.
165. cross-device leaf-like pdu nodes are never treated as complete empty
     directories without boundary evidence.
166. metadata tap records are adapter-only and never appear in domain, protocol,
     persistence, or Flutter DTOs.
167. metadata tap path evidence stays redaction-aware and is not written to
     production logs.
168. disabling metadata tap through resource policy preserves scan correctness but
     lowers evidence confidence where applicable.
169. full per-node metadata indexing from the tap is opt-in and budgeted, not MVP
     default behavior.
170. pdu adapter production path never calls
     `rayon::ThreadPoolBuilder::build_global`.
171. `ResourceProfile::Balanced` maps to a bounded local `PduExecutionLane`, not
     to pdu CLI `Threads::Auto`.
172. Flutter/product protocol cannot pass raw pdu thread flags such as
     `auto`, `max`, or fixed pdu thread count.
173. storage medium hints come from platform providers and are treated as
     confidence-bearing hints, not hard scan truth.
174. HDD/network/removable/battery/thermal hints can downgrade execution budget
     without changing traversal, size, or delete policy.
175. pdu CLI HDD auto-limit behavior is covered only by diagnostics/research
     comparison tests, not product behavior tests.
176. `PduLaneMetrics` records selected profile, requested threads, actual
     threads, queue wait, wall time, cancellation latency, and downgrade reason.
177. benchmark/fast profile is explicit and visible; default desktop profile is
     balanced.
178. multiple concurrent scan sessions are scheduled by `fs_usage_engine`, not by
     independent pdu/Rayon global pools.
179. failed storage-medium detection maps to `StorageMediumHint::unknown` and
     still produces a valid resource budget.
180. pdu CLI overlap removal is not imported or called by production
     `fs_usage_pdu`.
181. duplicate targets keep product diagnostics and never disappear silently like
     pdu CLI duplicate removal.
182. parent/child target overlap follows `TargetOverlapPolicy` and is visible in
     target preflight output.
183. symlink-directory target overlap is handled by explicit symlink target
     policy, not by pdu CLI `is_real_dir` exclusion.
184. canonicalization failure produces `TargetPreflightIssue`, not silent
     exclusion from overlap checks.
185. multi-root synthetic root uses engine `SyntheticRootKind` and stable
     `NodeId`, never pdu fake root `""` or `(total)`.
186. `PduTargetRunner` receives normalized targets and cannot reorder, remove, or
     merge user-selected targets.
187. cleanup and delete plan creation rejects synthetic roots and requires a
     concrete current node/target identity.
188. overlap fixtures cover duplicate canonical paths, parent plus child, child
     before parent, symlink directory, missing target, and canonicalization
     failure.
189. pdu `OsStringDisplay::Display` output is never used as display-safety proof.
190. valid UTF-8 names containing control, bidi, zero-width, or newline characters
     are marked with `DisplaySafety` evidence.
191. pdu visualizer output is never used as app UI text, export text, protocol
     DTO, or support-bundle data.
192. copy-to-clipboard path command requires `PathExportPolicy`, explicit user
     action, and redaction checks.
193. support bundle export redacts paths by default and records redaction class.
194. diagnostic full-path export requires explicit user consent and provenance.
195. two paths with identical display-safe text remain distinct through `NodeRef`
     and server-side path evidence.
196. Flutter widgets receive display text plus safety flags and cannot create
     delete commands from displayed path strings.
197. pdu JSON UTF-8 conversion failure remains diagnostic/test behavior and never
     becomes normal product export failure.
198. pdu `BytesFormat`, `ParsedValue`, and visualizer size strings never appear in
     domain, protocol DTOs, persistence, or Flutter application models.
199. exact byte values are preserved separately from rounded display strings.
200. `SizeDisplayValue.rounded = true` when a display value uses pdu-like decimal
     unit formatting or any other lossy presentation.
201. pdu CLI default `Quantity::DEFAULT` does not choose product `SizePolicy`.
202. Unix block count is tagged as count/block semantics, not bytes.
203. formatted display text cannot be used for sort, filter, compare, export
     authority, or cleanup.
204. protocol tests prove exact values are string-encoded and display values are
     separate optional projections.
205. export tests include exact value, unit semantics, confidence, and display
     value where applicable.
206. locale-specific size formatting is presentation behavior and does not change
     scan facts or indexes.
207. apparent, allocated, hardlink-adjusted, reclaim estimate, and observed delta
     are never collapsed into one UI/backend `size` field.
208. `HardlinkListReflection` and `LinkPathListReflection` never appear in domain,
     server DTOs, Flutter DTOs, persistence schemas, or query cache schemas.
209. hardlink path order is stable only after engine sorting/indexing, not from
     pdu `DashMap`, `Vec`, or `HashSet` iteration.
210. duplicate hardlink path observations collapsed by pdu reflection are treated
     as diagnostic behavior, not product counting truth.
211. `detected_paths < nlink` maps to outside-scan hardlink evidence and lowers
     reclaim confidence.
212. `detected_paths > nlink` summary panic is contained and maps to degraded
     hardlink evidence.
213. pdu size conflict and link-count conflict map to explicit hardlink evidence
     states even when pdu traversal ignores recorder errors.
214. hardlink-adjusted projection never replaces primary measured aggregate size.
215. delete preflight treats hardlinks as current identity/accounting evidence,
     not scan-only delete authority.
216. non-Unix pdu backend reports built-in hardlink detection as unsupported even
     if metadata tap evidence exists.
217. public hardlink/reclaim DTOs are expressed in our `HardlinkGroupEvidence`
     and `HardlinkReclaimPolicy` terms, never in pdu summary terms.
218. pdu `EncounterError` side-channel evidence is required to interpret
     zero-size/no-child nodes safely.
219. root `symlink_metadata` failure cannot become a trusted zero-size scan
     result.
220. child `symlink_metadata` failure maps to uncertain current-node evidence,
     not a normal empty file/folder.
221. `ReadDirectory` failure marks child completeness as unknown, not empty.
222. `AccessEntry` failure attaches to parent-directory or evidence-only scope
     and never fabricates a child node id.
223. pdu `Operation` and `std::io::ErrorKind` are converted inside
     `PduIssueMapper` and never appear in domain/protocol models.
224. permission-like pdu errors can create platform repair hints, but repair
     policy is application/platform owned.
225. `ScanQuality` is computed from issue evidence plus read-model completeness,
     not from pdu scan return alone.
226. pdu `Quantity` is never exposed as product measurement policy.
227. pdu `Bytes` from apparent-size mode and pdu `Bytes` from Unix block-size
     mode map to different `SizeUnitSemantics`.
228. pdu `Blocks` maps to count semantics and cannot be assigned to byte fields.
229. product defaults for measurement mode are application policy and are tested
     separately from pdu CLI defaults.
230. pdu JSON `unit = bytes` is not sufficient to restore logical-vs-allocated
     semantics in product imports.
231. display formatting never changes exact measured facts or query ordering.
232. pdu rounded `f32` display coefficients never appear in protocol,
     persistence, sorting, filtering, compare, or cleanup decisions.
233. export contains exact value, unit semantics, source backend, source API, and
     confidence for every size fact.
234. no selected target uses product default target policy and never silently
     falls back to pdu `"."`.
235. multi-target product output uses engine `TargetExecutionPlan` and
     `SyntheticRootKind`, not pdu CLI fake root behavior.
236. pdu fake root names `""` and `"(total)"` cannot appear in product node ids,
     display paths, protocol DTOs, persistence, or query cache.
237. multi-root depth/query behavior is stable whether or not a synthetic root is
     visible in the UI.
238. pdu CLI `into_par_retained` depth shifting is not reused as product depth
     semantics.
239. pdu CLI `min_ratio`, visualizer direction, top-down mode, and unstable size
     sort do not affect product target order or read-model shape.
240. pdu CLI overlap removal is not imported by production adapter code.
241. pdu progress reporter destruction timing does not define product scan
     completion or post-processing state.
242. pdu JSON multi-root output remains diagnostic/fixture material only and
     never becomes product protocol.
243. pdu `DeviceBoundary::Stay` is used only when boundary capability says device
     identity is meaningful on the current platform.
244. non-Unix pdu backend reports same-device enforcement as unsupported unless
     another platform adapter proves it.
245. cross-device directories with empty children map to `boundary_skipped` or
     `children_unknown`, not complete empty directories.
246. boundary-skipped nodes do not become cleanup candidates without current
     platform revalidation and explicit user intent.
247. pdu device ids never appear as product protocol identifiers; they map to
     opaque `VolumeIdentity` evidence.
248. network, FUSE, cloud, container, and removable volume classification comes
     from platform adapters, not pdu.
249. HDD/resource auto-detection is tested separately from traversal boundary
     policy.
250. scan quality aggregation treats boundary skips as intentional partial scope,
     not success by absence of errors.
251. pdu `Reflection` and `JsonData` are allowed only in diagnostics/fixtures.
252. pdu `SchemaVersion` is recorded as pdu provenance and never reused as Clean
     Disk protocol version.
253. pdu `BinaryVersion` is recorded as optional provenance and never used as the
     only compatibility gate.
254. pdu JSON import creates `DiagnosticSnapshotAuthority::ReadOnly` with cleanup
     disabled.
255. pdu JSON import cannot create delete candidates, cleanup queues, operation
     journals, or authoritative scan history.
256. pdu `par_try_into_tree` validation is treated as structural sanity only, not
     product trust validation.
257. pdu JSON names are UTF-8-only and cannot be used to test product path
     fidelity for non-UTF-8 paths.
258. pdu hardlink shared details/summary imported from JSON remain diagnostic
     evidence and follow panic containment/confidence rules.
259. pdu JSON `unit = bytes` does not restore apparent-vs-allocated semantics
     without extra diagnostic provenance.
260. normal daemon-to-Flutter protocol tests fail if any pdu JSON or Reflection
     type appears in DTOs, cache schemas, repositories, or stores.
261. pdu `Threads::Auto`, `Threads::Max`, and fixed thread syntax never appear in
     product protocol or Flutter UI state.
262. product default target resolution runs before resource-budget selection.
263. pdu no-arg HDD auto-detection behavior is not copied; default target scans
     still receive storage-medium hints.
264. canonicalization failure during storage hint lookup lowers hint confidence
     and does not silently choose a faster budget.
265. `PduExecutionLane` never calls Rayon `build_global`.
266. resource budgets are session/job scoped and cannot mutate process-global
     Rayon state.
267. Linux virtual-disk correction and LVM/device-mapper limitations are platform
     evidence, not product truth.
268. non-UTF-8 disk names degrade storage hint confidence without blocking scan.
269. unknown storage medium defaults to conservative balanced/background budget,
     not max parallelism.
270. resource throttling changes speed only and never changes traversal, size,
     issue, cleanup, or authority semantics.
271. pdu backend walk completion does not publish product `snapshot_ready`.
272. `converting_tree`, `building_indexes`, and `aggregating_quality` are visible
     product phases after pdu returns a `DataTree`.
273. query APIs stay unavailable or explicitly pending until `snapshot_ready`.
274. cleanup/recommendation actions stay disabled until snapshot readiness,
     capability checks, and scan-quality aggregation pass.
275. pdu CLI reporter teardown, cull, sort, dedupe, JSON, and visualizer steps do
     not define product scan phases.
276. every normalized scan target produces a `TargetScanOutcome`.
277. a pdu zero-size root node is never accepted as target success without
     matching preflight and issue evidence.
278. a failed target can produce issue evidence without producing a cleanup-
     eligible `root_node_ref`.
279. multi-target synthetic roots aggregate target outcomes but cannot hide failed
     or degraded targets.
280. target cleanup eligibility is decided by application policy and current
     revalidation, not by pdu root tree shape.
281. pdu `DetectHardlink` events are never used as durable hardlink group count.
282. `CleanDiskHardlinkRecorder` preserves size-conflict and link-count-conflict
     evidence in a side store even when pdu would discard `RecordHardlinks::Err`.
283. hardlink conflict paths are preserved as evidence and are not lost because
     pdu `HardlinkList::add` skipped adding a conflicting path.
284. duplicate hardlink path observations are explicit evidence and are not
     silently collapsed through pdu `LinkPathListReflection`.
285. hardlink side-store truncation lowers confidence and emits degraded evidence.
286. wide-directory child-name collection is measured or estimated separately
     from pdu final tree memory.
287. memory pressure can defer secondary indexes or fail the scan, but cannot
     silently publish a partial read model as complete.
288. if budget is exceeded after pdu walk and before `snapshot_ready`, query APIs
     remain pending, degraded, or unavailable.
289. `MemoryBudgetClass`, `WideDirectoryEvidence`, and `PduMemoryPressurePolicy`
     stay in engine/adapter vocabulary and never expose pdu internals to Flutter.
290. `max_depth` is not used as the default memory safety mechanism for product
     scans.
291. production dependency graph uses pdu `default-features = false`.
292. clean-disk-server dependency graph never enables pdu `cli`.
293. `fs_usage_pdu` production imports stay inside the pdu scanner allowlist.
294. pdu `visualizer`, `bytes_format`, `status_board`, and `json_data` are
     forbidden in production adapter code.
295. pdu JSON/Reflection imports are diagnostics/test-only and cannot appear in
     protocol, cache, export, Flutter DTOs, or engine read model.
296. pdu `serde` and `serde_json` re-exports are never used as product protocol
     serialization dependencies.
297. production `PduTreeConverter` never calls pdu `par_retain`,
     `into_par_retained`, `par_cull_insignificant_data`, `par_sort_by`,
     `into_par_sorted`, or hardlink dedupe helper mutations.
298. pdu helper projections used in diagnostics are marked
     `diagnostic_backend_projection` and have no cleanup authority.
299. pdu `Reflection::par_try_into_tree` success is structural sanity only and
     never upgrades scan quality, size confidence, or cleanup eligibility.
300. pdu `par_sort_by` ordering never defines protocol, UI, persistence, or cache
     ordering.
301. pdu UTF-8 conversion helpers remain diagnostics/JSON-only and are not used
     for product path fidelity tests.
302. pdu `max_depth = 0` and `max_depth = 1` are both mapped as root-only stored
     projection with aggregate sizes from traversed descendants.
303. pdu `max_depth = 2` stores direct children only and marks deeper
     descendants as hidden-by-projection evidence.
304. product protocol/UI exposes `StoredDepthRequest`, not raw pdu `max_depth`.
305. parent aggregate size may include hidden-by-depth descendants, so visible
     child rows are not assumed to sum to parent size without completeness
     evidence.
306. hidden-by-depth descendants cannot become cleanup targets without a current
     read-model entry and delete preflight.
307. pdu `same_device == false` is represented only through adapter/platform
     evidence, because pdu emits no boundary event and `DataTree` loses the
     decision.
308. a node with empty pdu children and missing boundary evidence maps to
     `ChildCompleteness::Unknown`, not `BoundarySkipped` and not complete empty
     directory.
309. non-Unix pdu same-device enforcement is never claimed unless a separate
     platform adapter proves meaningful volume identity.
310. `PduBoundaryDecisionEvidence` stores bounded adapter evidence and never
     leaks raw pdu device ids into protocol, persistence, Flutter, telemetry, or
     support bundles.
311. `PduMetadataTapRecorder` copies same-device evidence without using
     `RecordHardlinks::Err` for control flow, because pdu ignores that error.
312. boundary-skipped and boundary-unknown nodes remain non-destructive until
     current platform identity, policy, and user intent are revalidated.
313. pdu `TreeBuilder` and `Info<Name, Size>` are not used as application
     `ScannerBackend` contracts.
314. pdu `TreeBuilder::get_info` infallibility is not allowed to shape product
     error handling, cancellation, or scan quality.
315. pdu `TreeBuilder` callback order and Rayon recursion never define protocol
     event order, UI row order, or issue order.
316. direct arena streaming remains a backend capability/fork decision, not a
     hidden dependency on pdu `TreeBuilder`.
317. import-boundary tests fail if `TreeBuilder`, `Info`, `get_info`, or
     `join_path` appear outside `fs_usage_pdu` diagnostics/adapter code.
318. `ErrorReport<'_>` borrowed paths are copied into owned adapter evidence
     before `Reporter::report` returns.
319. raw `std::io::Error`, pdu `Operation`, `Operation::name()`, and
     `ErrorReport::TEXT` never cross the `fs_usage_pdu` public boundary.
320. `AccessEntry` error evidence attaches to parent scope or evidence-only
     scope, never to a fabricated child node.
321. raw OS error messages and raw paths are privacy-sensitive evidence and are
     redacted or omitted from protocol, Flutter, logs, telemetry, and support
     bundles by default.
322. issue sample overflow emits truncation evidence and does not block pdu
     traversal worker threads.
323. pdu hardlink dedupe path-prefix mutation is never used to create primary
     `SizeFacts.measured` values.
324. `SizeFacts.hardlink_adjusted_bytes` is optional projection evidence with
     confidence, not exact reclaim authority.
325. pdu `LinkPathList` duplicate observations are preserved by our recorder
     before any pdu reflection conversion can collapse them into a `HashSet`.
326. hardlinks split across sibling directories can affect display projections,
     but do not mutate primary aggregate truth.
327. pdu hardlink dedupe can run only on cloned diagnostic/projection data behind
     an explicit capability gate.
328. pdu `RuntimeError` and `RuntimeError::code()` are CLI host details and never
     become daemon `ScanFailure`, protocol error, or Flutter error contracts.
329. pdu `--json-input` semantics are diagnostic visualization semantics, not
     filesystem scan or product import semantics.
330. pdu `SchemaVersion` and `BinaryVersion` are provenance only and never become
     Clean Disk protocol compatibility versions.
331. pdu JSON import always creates reduced-authority read-only diagnostic
     snapshots with no cleanup, recommendation, or cache authority.
332. production adapter code cannot import pdu `App`, `Args`, `Sub`, or
     `runtime_error`; diagnostics may do so only behind explicit gates.
333. pdu CLI overlap removal is hardlink-dedupe host behavior, not target
     authority or user intent policy.
334. canonicalization failure during target preflight creates
     `TargetPreflightIssue`, not silent exclusion from overlap detection.
335. symlink directory targets follow explicit symlink policy, not pdu
     `is_real_dir` filtering.
336. `fs_usage_pdu` never calls or imports pdu `app::overlapping_arguments` in
     production code.
337. target canonical path evidence never becomes cleanup authority without
     current delete preflight identity validation.
338. pdu `status_board`, `visualizer`, `bytes_format`, `ProgressReport::TEXT`,
     and `ErrorReport::TEXT` stay out of production daemon, protocol, Flutter,
     persistence, logs, telemetry, and support-bundle paths.
339. pdu terminal display output can run only in explicit read-only diagnostic
     paths with no cleanup authority.
340. progress crosses our boundaries as typed `ScanProgressSnapshot`, never as a
     carriage-return terminal line.
341. exact size and percent facts cross protocol as typed/string-encoded values;
     pdu formatted strings never become sort, filter, compare, export, or delete
     authority.
342. pdu raw path/error display text is treated as privacy-sensitive evidence and
     redacted or omitted by default.
343. pdu `GetSize` is not our application measurement port. It is an
     infrastructure hook mapped into product `MeasurementProfile` and
     `SizeFacts`.
344. pdu `GetApparentSize` and `GetBlockSize` both returning `Bytes` still map to
     different product measurement kinds.
345. pdu `Blocks` is a count, not bytes, and never crosses protocol/UI/export as
     a byte value without explicit conversion evidence.
346. pdu CLI `Quantity::DEFAULT` never becomes an implicit app default.
347. unsupported measurement requests fail closed or use an explicit fallback
     policy that lowers confidence and remains visible to UI/details/export.
348. pdu `Reporter::report` is adapter evidence capture, not product event
     delivery, audit ordering, WebSocket delivery, or persistence.
349. pdu reporter callbacks never block scanner workers on UI, network, database,
     telemetry, localization, or unbounded allocation.
350. pdu built-in `ProgressAndErrorReporter` and `ErrorOnlyReporter` are not
     production Clean Disk reporter implementations.
351. product event sequence numbers are assigned outside pdu callbacks by the
     engine/server event sequencer.
352. reporter buffer overflow records truncation/degraded evidence instead of
     blocking pdu traversal.
353. pdu mount-point matching and HDD detection are storage-medium/resource
     heuristics only, never volume identity, scan boundary, or cleanup authority.
354. pdu `find_mount_point`/`any_path_is_in_hdd` behavior may affect selected
     `ExecutionBudget`, but it cannot exclude targets or mark children as
     boundary-skipped.
355. canonicalization failure during resource-hint lookup produces unknown
     storage-medium evidence and conservative budget, not scan failure.
356. pdu `Args`, `Depth`, `Fraction`, `Threads`, `Quantity`, and `BytesFormat`
     never appear in domain, application ports, protocol DTOs, Flutter DTOs, or
     persistence schemas.
357. product `BackendScanRequest` is policy-shaped, not pdu-CLI-shaped.
358. pdu raw CLI tokens such as `"inf"`, `"auto"`, and `"max"` are diagnostics
     compatibility only and never product protocol vocabulary.
359. pdu `min_ratio` and terminal layout flags are rendering/query diagnostics,
     not product search, filter, sort, cleanup, or snapshot identity policy.
360. `PduOptionsMapper` is the only place where product scan policy is translated
     into pdu-specific options.
361. each pdu SDK type is classified as private adapter dependency,
     diagnostics/test fixture type, or rejected import. No pdu SDK type has a
     public engine/domain/protocol category.
362. `FsTreeBuilder`, `TreeBuilder`, `Info`, `DataTree`, `Reporter`, `Event`,
     `ErrorReport`, `HardlinkList`, `GetSize`, `Bytes`, `Blocks`, and
     `Reflection` are not allowed in `fs_usage_core`, `fs_usage_engine`,
     `clean_disk_protocol`, Flutter DTOs, or persistence schemas.
363. SDK source facts are mapped through `PduSdkBoundaryMatrix` or equivalent
     adapter guard before implementation code can depend on them.
364. source-audited pdu behavior may lower backend capability or scan
     confidence, but it may not silently change domain vocabulary.
365. pdu upgrade work must update the SDK layer matrix before bumping the
     production dependency.
366. pdu `edition = "2024"` and missing explicit `rust-version` are build/release
     compatibility facts, not domain or protocol facts.
367. `PduToolchainCompatibilityGuard` records pdu package metadata and fails the
     release gate if the effective Rust toolchain or feature surface drifts.
368. `PduBuildSurfaceGuard` verifies pdu production integration still has no
     unexpected build script and no production import of visualizer/status/CLI
     modules.
369. unsafe/panic-prone pdu helper or presentation paths remain outside the
     production scanner import allowlist or run only behind explicit diagnostic
     containment.
370. pdu package metadata may appear in diagnostics/support evidence, but never
     in domain entities, cleanup authority, Flutter state, or product protocol
     compatibility.
371. pdu `#[non_exhaustive]` enums and structs are API-evolution signals, not
     product domain contracts.
372. pdu non-exhaustive variants are mapped inside `fs_usage_pdu` with wildcard
     fallbacks to degraded/unknown backend evidence.
373. product enums and protocol reason codes use Clean Disk names and include
     their own unknown/fallback variants.
374. pdu variant names such as `ReceiveData`, `EncounterError`,
     `DetectHardlink`, `SizeConflict`, and `ExcessiveChildren` never appear in
     domain, application, protocol, Flutter DTO, persistence, or UI state.
375. pdu non-exhaustive struct fields such as hardlink `Summary` are evidence
     fields only and never define exact reclaim authority or protocol schema.
376. pdu `OsStringDisplay` ordering never defines product sort, search ranking,
     export ordering, or cache key order.
377. pdu root name and child names are heterogeneous and must map through
     explicit `pdu_name_kind` evidence.
378. `OsStringDisplay::Display` and pdu text error reports are diagnostic/display
     hints only, not identity, redaction, export, or cleanup authority.
379. valid UTF-8 pdu names still require display-safety checks for control,
     bidi, zero-width, newline, clipboard, and export behavior.
380. pdu `Deref`/`DerefMut` convenience cannot bypass `PduNameKindMapper` and
     `PduPathDisplayBoundaryMapper`.
381. pdu root path traversal is wrapped by a target identity envelope owned by
     `fs_usage_engine`, not trusted as direct target identity proof.
382. preflight identity, pdu traversal evidence, post-scan identity probe, and
     delete-time identity validation are separate facts.
383. root replacement between pdu's repeated `symlink_metadata` probes maps to
     degraded or changed target evidence, not clean success.
384. target drift state is exposed as scan quality and cleanup eligibility, not
     raw platform identity values in protocol or Flutter state.
385. cleanup plans cannot execute from pdu scan-time target identity without a
     current platform revalidation result.
386. pdu `DataTree::dir` constructor semantics never cross the adapter boundary;
     engine projections use typed size evidence instead.
387. pdu stored `DataTree.size()` maps to aggregate evidence only, never own
     measured size.
388. visible child sum mismatch is legal when depth, filter, error, boundary, or
     projection evidence says descendants are not fully represented.
389. engine code never feeds pdu stored aggregate size back into pdu
     `DataTree::dir`.
390. hardlink-adjusted or helper-mutated pdu aggregates remain projection
     evidence and cannot replace primary aggregate facts.
391. pdu `SharedLinkSummary` maps to `HardlinkSummaryEvidence`, not reclaim
     authority.
392. pdu `exclusive_shared_size` is a candidate evidence field and is never
     serialized as exact reclaimable bytes.
393. `detected_links < all_links` lowers confidence because outside-scan hardlinks
     are possible.
394. pdu hardlink summary panic or invariant failure maps to degraded hardlink
     evidence under adapter containment.
395. hardlink-informed cleanup estimates require current link-count revalidation
     through accounting/platform ports.
396. pdu child order and pdu `sort_unstable_by` output never define product page
     order, protocol order, persistence order, or cleanup queue order.
397. every paged query result is ordered by engine-owned `SnapshotOrderIndex`
     with deterministic tie-breakers.
398. protocol cursors are opaque and include snapshot/index/query identity; pdu
     vector offsets are not cursor authority.
399. stale cursor or stale index version returns an explicit resync/stale result,
     not silently mixed page data.
400. row selection and cleanup queue identity use `NodeRef`, not row index or pdu
     child position.
401. `PduTreeConverter` uses an iterative explicit stack or equivalent
     stack-depth guard, not unbounded recursive conversion.
402. converter depth evidence records max returned depth and max converter stack
     length for diagnostics and release gates.
403. partially converted `NodeArena` is not published until conversion and primary
     indexes complete.
404. converter depth/budget failure returns typed backend/conversion failure or
     degraded evidence, never a half-built read model.
405. recursive pdu helpers such as `par_sort_by`, `par_retain`, and
     `par_deduplicate_hardlinks` are not part of product conversion.
406. pdu progress counters map to `PduProgressEvidence` only and never directly
     to product `ScanSummary`, dashboard totals, cleanup candidate totals, or
     query counts.
407. `ScanPhaseProgress` remains approximate during pdu traversal and becomes
     final only after `BackendScanOutput`, `NodeArena`, read-model indexes, and
     issue aggregation are ready.
408. hardlink progress `linked` and `shared` are telemetry, not hardlink group
     count, exclusive shared size, or reclaim estimate.
409. a scan can finish pdu traversal but remain not-ready until tree conversion,
     index construction, and scan-quality aggregation finish.
410. missing final pdu progress tick does not affect final summary publication.
411. pdu callback hooks are adapter extension points, not product ports or event
     buses.
412. pdu callbacks copy bounded owned evidence and must not perform protocol,
     database, localization, logging of raw paths, or platform cleanup work.
413. callback overflow creates explicit truncation/degraded evidence instead of
     blocking traversal silently.
414. `RecordHardlinks::Err` is not used as cancellation, backpressure, or product
     failure because pdu ignores recorder errors.
415. product scan events are emitted by `fs_usage_engine` after callback evidence is
     mapped, sequenced, redacted, and throttled.
416. pdu Rayon work runs inside `PduExecutionLane` local pools, never through
     product-global Rayon configuration.
417. domain, application, protocol, and Flutter contracts expose resource profiles
     and scan states, not Rayon or pdu CLI thread types.
418. pdu CLI `Threads`, HDD auto-thread policy, and `build_global()` are host
     behavior and are not used by the daemon adapter.
419. pdu helper diagnostics that use Rayon stay inside bounded adapter lanes.
420. pdu walk time, callback pressure, conversion time, and index time are measured
     separately.
421. pdu `ProgressAndErrorReporter` is not used in production scan paths.
422. diagnostic use of pdu `ProgressAndErrorReporter` requires explicit
     `destroy()`/join handling on success and failure paths.
423. product session lifecycle is owned by `fs_usage_engine` and
     `PduExecutionLane`, not by pdu reporter helper threads.
424. pdu progress-thread panic maps to diagnostic failure, not product domain
     failure.
425. custom production `PduReporter` has no detached progress thread and no
     protocol/database/log side effects.
426. pdu built-in hardlink detection is a Unix-only capability, not universal
     backend truth.
427. non-Unix pdu backend reports hardlink detection as unsupported or degraded
     explicitly.
428. `RecordHardlinks` metadata tap availability does not imply hardlink group
     support.
429. future Windows NTFS/MFT hardlink evidence implements the same domain
     contract through a separate adapter.
430. no domain/protocol enum uses pdu `cfg(unix)` or `HardlinkAware` names as
     capability identity.
431. pdu `default-features = false` is necessary but not sufficient as dependency
     governance.
432. production dependency graph must prove pdu `cli` is disabled and `json` is
     absent unless explicitly diagnostic.
433. pdu non-optional presentation/support dependencies are adapter supply-chain
     cost, not product UI/design-system dependencies.
434. effective feature/dependency graph evidence is owned by `fs_usage_pdu` and
     release checks, not domain or protocol.
435. pdu feature names and dependency names never become domain capability names.
436. pdu target-specific API surface is proven by target compile evidence, not
     docs.rs page visibility.
437. pdu Unix-only hardlink, block-size, device, and inode APIs map to capability
     DTOs, not domain `cfg` assumptions.
438. Windows pdu adapter builds with Unix pdu code paths disabled and explicit
     unsupported/degraded capabilities.
439. docs.rs crate metadata is a source reference, not release artifact authority.
440. Flutter/protocol receive target capability values, never pdu target/cfg names.
441. production `PduReporter` implements pdu `Reporter` only, not
     `ParallelReporter`.
442. pdu `ParallelReporter::destroy` is diagnostic-only lifecycle for built-in
     reporters, not scan-session completion.
443. `FsTreeBuilder` requiring only `Reporter + Sync` keeps reporter lifecycle
     outside pdu traversal ownership.
444. shared reporter references are allowed as adapter implementation detail, but
     borrowed pdu event payloads still must be copied before callback return.
445. scan session lifecycle remains in `fs_usage_engine`, never in pdu reporter
     traits.
446. production `PduTreeConverter` reads pdu `DataTree` through immutable getters
     only.
447. pdu `name_mut`, `par_retain`, `into_par_retained`, `par_sort_by`,
     `into_par_sorted`, `par_cull_insignificant_data`, and
     `fixed_size_dir_constructor` are forbidden in production conversion.
448. pdu `children()` full `Vec` never becomes a pagination or cursor contract.
449. pdu helper-mutated trees are diagnostic/reduced-authority only and must carry
     projection evidence.
450. product sort, filter, projection, pagination, and completeness are engine
     read-model responsibilities, not pdu helper behavior.
451. pdu traversal completion is resultless evidence, not product success.
452. `PduEvidenceJoiner` correlates pdu `DataTree`, reporter evidence, metadata
     tap evidence, hardlink evidence, and target preflight before
     `BackendScanOutput` is created.
453. empty pdu children never imply complete empty directory without explicit
     completeness evidence.
454. pdu callback events remain adapter-private and map to stable product issues,
     metrics, and quality states.
455. `RecordHardlinks::Err` and pdu reporter callbacks are never used as
     cross-layer control flow.
456. pdu hardlink dedupe prefix/suffix arithmetic is projection evidence, not
     primary measured size and not reclaim authority.
457. hardlink-adjusted projections are recomputed from product
     `HardlinkGroupEvidence` with checked arithmetic before any product display.
458. pdu `LinkPathListReflection` `HashSet` conversion is diagnostic only because
     it can erase duplicate-observation evidence.
459. pdu hardlink scope means observed paths under a prefix, not delete-time
     exclusive reclaim.
460. hardlink projection arithmetic degradation is explicit evidence and fails
     closed for cleanup/reclaim use.
461. pdu wide-directory temporary child-name allocation is not exactly observable
     through final `DataTree` shape.
462. memory evidence carries confidence and source: observed, calibrated,
     inferred, or unknown.
463. pdu `max_depth` does not remove hidden child-name allocation risk because
     deeper traversal can still occur for aggregate size.
464. final pdu node count is not used as exact peak-memory evidence.
465. budget-exceeded states block or degrade snapshot publication instead of
     exposing half-built read models as complete.
466. pdu Unix allocated bytes from `GetBlockSize` are tagged as
     `MetadataExt::blocks() * 512`, not generic physical bytes.
467. pdu `Bytes` from apparent and Unix allocated modes never share the same
     product `measurement_kind` or `source_api`.
468. pdu `Blocks` remains count semantics until explicit conversion evidence is
     attached.
469. sparse-file measurement differences are expected evidence, not inconsistency.
470. measured allocated size is never promoted to reclaim authority without
     accounting validation.
471. no domain, protocol, persistence, or Flutter value type implements pdu
     `Size`.
472. pdu `Bytes`, pdu `Blocks`, pdu `Size::DisplayFormat`, and pdu display output
     remain inside `fs_usage_pdu`.
473. `SizeFacts` and reclaim/accounting value objects are engine/domain-owned and
     never pass through pdu traversal.
474. pdu `Size` arithmetic and pdu `display(...)` capability are adapter input,
     not product numeric semantics.
475. product DTOs serialize measurement kind, unit, exact value, source evidence,
     and confidence instead of pdu newtype names.
476. production pdu `GetSize` implementations are pure measurement adapters with
     no protocol, DB, logging, async runtime, Flutter, cleanup, or event imports.
477. pdu `GetSize` never acts as `MetadataProvider`, `AccountingProvider`,
     `ScanEventEmitter`, or cancellation source.
478. unsupported measurement modes are resolved before pdu traversal through
     capability and fallback policy because `GetSize` cannot return `Result`.
479. path-aware metadata, current identity, permissions, timestamps, cloud state,
     and delete authority come from platform providers, not pdu `GetSize`.
480. pdu `ReceiveData(size)` after `GetSize` is progress evidence only, not a
     node-complete event.
481. pdu `Fraction` and CLI `min_ratio` never appear in domain, protocol,
     persistence, Flutter stores, or product query DTOs.
482. product filter thresholds reject `NaN`, infinity, and other non-finite
     values before query execution.
483. product size filters use exact typed values plus explicit size fact kind, not
     pdu root-relative `f32` culling.
484. pdu `par_cull_insignificant_data` output is reduced-authority diagnostic
     projection only and cannot create cleanup/delete targets.
485. visible row filtering does not mutate primary `NodeArena` aggregate evidence
     or child-completeness state.
486. pdu JSON output error precedence is diagnostic-only and never becomes
     daemon scan, export, or cleanup operation semantics.
487. product export endpoints do not call pdu `Sub::run`, stdout JSON writer
     flow, pdu `JsonData`, or pdu `RuntimeError`.
488. pdu shared-hardlink JSON conversion failures lower diagnostic evidence
     quality but do not erase live adapter hardlink evidence.
489. Clean Disk export receipts separate scan conversion, hardlink evidence,
     serialization, transport, cache, and user-visible export status.
490. daemon protocol payloads are Clean Disk DTOs, never pdu JSON output.
491. `parallel_disk_usage::main()` is never called by production daemon,
     adapter, domain, application, protocol, or Flutter code.
492. pdu `#![deny(warnings)]` is treated as release/build compatibility
     evidence, not scan/runtime behavior.
493. pdu stderr and exit-code behavior never maps directly to HTTP/WebSocket
     errors, operation receipts, or Flutter user-facing failures.
494. pdu warning failures under a new Rust toolchain block release upgrade gates,
     not user scan sessions.
495. build diagnostics may record pdu crate-root warning policy, but protocol DTOs
     do not expose it as product capability.
496. production feature graph forbids pdu `cli`, `json`, `ai-instructions`,
     `cli-completions`, `man-page`, and `usage-md`.
497. pdu `json` may be enabled only in explicit diagnostic fixture/export builds
     and never in the normal daemon dependency graph.
498. pdu auxiliary features are build/tooling concerns and never become scanner
     capabilities, domain flags, protocol fields, or Flutter view-state terms.
499. `cargo tree -e features` or equivalent metadata checks are release gates for
     pdu feature unification drift.
500. any future pdu feature added upstream is denied by default until the adapter
     dependency review classifies it.
501. pdu `StatusBoard` is process-global terminal repaint state, not a
     session-scoped progress sink, event bus, logger, metric source, or
     support-bundle source.
502. pdu `StatusBoard` relaxed line-width state never defines product event
     ordering, scan finality, progress sequence, or multi-client behavior.
503. product progress uses session-scoped `ScanProgressSnapshot` and event
     sequence contracts, not pdu carriage-return text or global stderr state.
504. any diagnostic use of pdu terminal progress must be read-only, redacted,
     feature-gated, and explicitly excluded from daemon protocol semantics.
505. production import checks fail if pdu `StatusBoard` or
     `GLOBAL_STATUS_BOARD` appears outside diagnostic/test code.
506. pdu `BytesFormat` CLI names and aliases are compatibility input only, not
     domain, protocol, persistence, or Flutter preference vocabulary.
507. protocol and preference values never use pdu aliases `1`, `1000`, or
     `1024`.
508. `SizeDisplayPolicy` is product-owned and maps to pdu `BytesFormat` only
     inside diagnostic or terminal-formatting adapters.
509. block-count projections never accept byte-format aliases because pdu
     `GetBlockCount::formatter` ignores `BytesFormat`.
510. pdu `ParsedValue`, `Output`, and one-decimal `f32` formatting never define
     exact values, sorting keys, cleanup estimates, or export facts.

Acceptance:

```text
No Flutter DTO, server DTO, or persistence schema may be pdu-shaped.
No destructive operation may use pdu output without current platform validation.
```

## Pre-Coding Layer Contract Addendum

This addendum turns the pdu source audit into the exact layer contract to follow
when implementation starts.

Top 3 architecture choices for the first real scanner slice:

1. Clean core plus pdu adapter plus fake backend - 🎯 10 🛡️ 10 🧠 7, roughly
   2500-6000 LOC.
   Accepted. The fake backend proves the application contract. The pdu adapter
   proves real performance. Neither one defines domain vocabulary.
2. pdu-backed engine with later abstraction - 🎯 5 🛡️ 5 🧠 4, roughly
   1200-3000 LOC.
   Rejected. This creates a strong chance that pdu's aggregate tree, callback
   events, path display, and CLI options become product semantics.
3. Custom scanner instead of pdu from day one - 🎯 4 🛡️ 6 🧠 9, roughly
   6000-14000 LOC.
   Rejected for MVP. Keep this as a future backend only if pdu adapter evidence
   fails memory, cancellation, or output capability gates.

### Domain Responsibility

The domain layer owns product vocabulary, invariants, and safety language.

Domain may define:

```text
ScanTarget
ScanTargetSet
TargetAuthority
NodeId
NodeRef
SnapshotId
SizeFact
MeasurementProfile
BoundaryPolicy
LinkPolicy
ScanIssueReason
ScanQuality
CapabilityCode
PrivacyClass
DeleteIntent vocabulary
```

Domain must not know:

```text
parallel_disk_usage
DataTree
FsTreeBuilder
TreeBuilder
Info
Reporter
Event
ErrorReport
ProgressReport
HardlinkList
GetSize
Bytes
Blocks
JsonData
Reflection
PathBuf authority
std::fs::Metadata
std::io::Error
rayon
tokio
HTTP/WebSocket
Flutter
MobX
```

Domain rule:

```text
Domain names the truth we need.
Adapters provide evidence for that truth.
No adapter is allowed to rename product truth after itself.
```

### Application Responsibility

The application layer owns use cases, ports, session state, scan publication,
read-model construction, and cleanup gating.

Application ports:

```text
ScannerBackend
MetadataReader
FileIdentityReader
FilesystemCapabilityReader
ReclaimAccountingReader
TrashAdapter
ReadModelQueryPort
ScanEventSink
Clock
OperationJournal
```

Application use cases:

```text
CreateScanSession
StartScan
CancelScan
DisposeScanSession
GetScanCapabilities
GetScanStatus
GetChildrenPage
GetNodeDetails
SearchNodes
GetTopNodes
BuildDeletePlanPreview
ValidateDeletePlan
```

Application owns these state transitions:

```text
session created
scan requested
backend running
backend completed
conversion running
indexing running
snapshot publish gate
query ready
cancel requested
cancel acknowledged
failed
degraded
disposed
```

Application rules:

- `ScannerBackend` returns product-shaped `BackendScanOutput`, not pdu raw data.
- every backend output includes `ScannerCapabilitySnapshot` and
  `AdapterDecisionRecord`;
- progress events are invalidation/status evidence, not the read-model truth;
- query endpoints are side-effect-free and paginated;
- cleanup preview requires current platform validation, not scan evidence alone;
- late pdu output after cancellation or session epoch change is discarded before
  publication;
- missing pdu facts are represented as `unknown`, `lazy`, `unsupported`, or
  `degraded`, never guessed.

### Infrastructure Responsibility

`fs_usage_pdu` owns all coupling to pdu and converts it at the boundary.

Adapter-private modules:

```text
adapter/
  pdu_scanner_backend
  pdu_options_mapper
  pdu_execution_lane
  pdu_scan_runner
  pdu_reporter_recorder
  clean_disk_hardlink_recorder
  pdu_tree_converter
  pdu_capability_mapper
  pdu_backend_fingerprint
  pdu_adapter_decision_record
```

Adapter-private data:

```text
PduOptions
PduRawScanResult
PduTraversalKey
PduTreeName
PduCopiedEvent
PduCopiedError
PduHardlinkObservation
PduRunDiagnostics
PduFeatureGraphEvidence
```

Adapter rules:

- `PduOptionsMapper` is the only place that maps product policies to pdu
  `root`, `size_getter`, `device_boundary`, `max_depth`, and hardlink mode.
- `PduExecutionLane` owns Rayon/local blocking behavior. Production code must
  not use pdu CLI `Threads` or pdu CLI global Rayon setup.
- `PduReporterRecorder` must be bounded and non-blocking because pdu calls it
  synchronously from traversal work.
- `PduReporterRecorder` copies borrowed event evidence immediately.
- `CleanDiskHardlinkRecorder` captures conflict evidence before pdu hides
  recorder errors with `.ok()`.
- `PduTreeConverter` reads `DataTree` through immutable getters and writes
  product arena records.
- `PduTreeConverter` never derives node kind from `children().is_empty()`.
- `PduTreeConverter` never claims modified time, permission, owner, cloud
  state, file identity, or delete safety.
- `PduCapabilityMapper` explains why a fact is exact, estimated, lazy,
  unsupported, degraded, or not requested.
- pdu JSON, CLI, visualizer, status board, and bytes formatter are diagnostic
  or test-only surfaces.

### Mapping Contract

| pdu source | Product destination | Boundary note |
| --- | --- | --- |
| `FsTreeBuilder` | `PduScanRunner` internals | final-tree scanner, not app port |
| custom pdu `TreeBuilder` | richer adapter path | useful when we need side stores |
| `DataTree::size()` | aggregate `SizeFact` | selected measurement only |
| `DataTree::name()` | display/name evidence | never path authority |
| `DataTree::children()` | arena ingestion input | never pagination identity |
| `Reporter::ReceiveData` | progress evidence | metadata read, not node published |
| `Reporter::EncounterError` | `ScanIssueDraft` | stable product reason required |
| `Reporter::DetectHardlink` | hardlink evidence | observation, not reclaim truth |
| `GetSize` implementation | measurement source | not metadata provider |
| `DeviceBoundary` | traversal policy evidence | platform capability required |
| pdu hardlink dedupe | named projection | not primary size truth |
| pdu JSON/Reflection | diagnostics/fixtures | not protocol/cache/export schema |

### First Implementation Gate

Before writing `fs_usage_pdu`, the first implementation PR should be able to
pass these gates with a fake backend:

```text
fake backend starts and completes a scan session
fake backend publishes capability snapshot
fake backend returns BackendScanOutput without pdu types
engine builds NodeArena and query indexes
children query returns a page and cursor
details query returns a product view model
progress events do not carry full tree payloads
scan snapshot cannot create DeletePlan authority
protocol DTOs do not mirror pdu JSON
Flutter repository can swap fake daemon/client without scanner change
```

Then the pdu adapter PR adds:

```text
pdu import allowlist test
pdu default-features false feature-graph test
FsTreeBuilder scan-only path
reporter evidence copy path
DataTree to NodeArena converter
adapter decision record
capability-gap mapping
permission/error fixture mapping
non-UTF-8 fixture mapping
hardlink fixture evidence mapping
wide/deep resource fixture baseline
cancel-before-publish gate
```

### Research Conclusion

pdu is good for the expensive traversal and aggregation work. It is not good as
our public model because it intentionally does not carry the product facts that
Clean Disk needs: stable identity, full authority path, item counts, metadata,
issue taxonomy, capability state, query indexes, delete safety, or protocol
compatibility.

The correct shape is therefore:

```text
pdu discovers.
fs_usage_pdu translates.
fs_usage_engine publishes.
fs_usage_core names invariants.
clean-disk-server transports.
Flutter displays and commands.
platform adapters validate authority.
```

If an implementation step violates this chain, stop and move the type or logic
back to the layer that owns it.

## Concrete Module Ownership For First Rust Slice

Clean Architecture must be enforced by crates, imports, and tests. Folder names
alone are not enough.

Top 3 physical organization choices:

1. Crate-enforced boundaries with small modules inside each crate - 🎯 10 🛡️ 10
   🧠 7, roughly 2500-6500 LOC for first scanner/read-model slice.
   Accepted. It fits Rust well because compile-time dependencies enforce the
   direction better than comments.
2. One crate with `domain/application/infrastructure` folders - 🎯 6 🛡️ 6 🧠 4,
   roughly 1500-3500 LOC.
   Useful for tiny projects, but too easy to leak pdu, platform IO, and protocol
   DTOs into inner code as the scanner grows.
3. Many tiny crates per adapter/use case immediately - 🎯 5 🛡️ 7 🧠 9, roughly
   5000-12000 LOC before product value.
   Too much upfront. Split only where dependency direction or build/test speed
   needs it.

### `fs_usage_core` Ownership

Domain-only crate. It contains value objects, policies, issue taxonomy, and
pure invariants.

Recommended first module shape:

```text
fs_usage_core/src/
  lib.rs
  ids/
    scan_session_id.rs
    backend_run_id.rs
    snapshot_id.rs
    node_id.rs
    operation_id.rs
  target/
    scan_target.rs
    scan_target_set.rs
    target_scope.rs
    target_authority.rs
    target_overlap_policy.rs
  path/
    display_path.rs
    path_authority_ref.rs
    path_encoding_state.rs
    path_redaction_class.rs
    path_sort_key.rs
  size/
    measurement_profile.rs
    measurement_kind.rs
    size_fact.rs
    size_confidence.rs
    aggregate_size.rs
    own_size.rs
    reclaim_estimate.rs
  node/
    node_ref.rs
    node_kind_evidence.rs
    child_materialization_state.rs
    projection_kind.rs
  policy/
    boundary_policy.rs
    link_policy.rs
    depth_policy.rs
    resource_profile.rs
    privacy_profile.rs
  issue/
    scan_issue_reason.rs
    scan_issue_severity.rs
    scan_quality.rs
    issue_path_scope.rs
  capability/
    capability_code.rs
    capability_state.rs
    backend_capability.rs
  error/
    fs_usage_error.rs
```

Allowed dependencies:

```text
std
small pure utility crates only if justified
```

Forbidden dependencies:

```text
parallel_disk_usage
tokio
rayon
serde_json as domain truth
HTTP/WebSocket
database/cache crates
platform plugins
Flutter/Dart concepts
```

### `fs_usage_engine` Ownership

Application crate. It coordinates use cases, ports, sessions, events, arena
ingestion, indexing, and query pages.

Recommended first module shape:

```text
fs_usage_engine/src/
  lib.rs
  ports/
    scanner_backend.rs
    metadata_reader.rs
    file_identity_reader.rs
    filesystem_capability_reader.rs
    reclaim_accounting_reader.rs
    trash_adapter.rs
    scan_event_sink.rs
    clock.rs
  session/
    scan_session.rs
    scan_session_registry.rs
    scan_session_state.rs
    scan_epoch.rs
    cancellation.rs
  command/
    create_scan_session.rs
    start_scan.rs
    cancel_scan.rs
    dispose_scan_session.rs
  query/
    get_children_page.rs
    get_node_details.rs
    search_nodes.rs
    get_top_nodes.rs
    get_scan_status.rs
  backend/
    backend_scan_request.rs
    backend_scan_output.rs
    backend_capability_gap.rs
    adapter_decision_record.rs
    backend_fingerprint.rs
  read_model/
    node_arena.rs
    node_arena_writer.rs
    node_children_index.rs
    node_sort_index.rs
    search_index.rs
    issue_store.rs
    evidence_store.rs
    snapshot_publication_gate.rs
  event/
    scan_event.rs
    scan_event_batch.rs
    event_sequence.rs
  fake/
    fake_scanner_backend.rs
```

Application rule:

```text
Ports are defined by what the use cases need.
Adapters are implemented outside the engine.
```

This is the main DDD/Clean Architecture boundary: `fs_usage_engine` may know
that it needs a scanner, metadata reader, or identity reader. It must not know
that the scanner is pdu, MFT, APFS, mock, or remote.

### `fs_usage_pdu` Ownership

Infrastructure adapter crate. This is the only production crate that imports
`parallel_disk_usage`.

Recommended first module shape:

```text
fs_usage_pdu/src/
  lib.rs
  adapter/
    pdu_scanner_backend.rs
    pdu_options_mapper.rs
    pdu_scan_runner.rs
    pdu_execution_lane.rs
  reporter/
    pdu_reporter_recorder.rs
    copied_pdu_event.rs
    copied_pdu_error.rs
    progress_translator.rs
  hardlink/
    clean_disk_hardlink_recorder.rs
    hardlink_observation.rs
    hardlink_conflict_mapper.rs
  converter/
    pdu_tree_converter.rs
    pdu_traversal_key.rs
    pdu_tree_name.rs
    node_materialization_mapper.rs
    size_fact_mapper.rs
  capability/
    pdu_capability_mapper.rs
    pdu_backend_fingerprint.rs
    pdu_feature_graph.rs
  diagnostics/
    pdu_run_diagnostics.rs
    pdu_adapter_decision_record_builder.rs
```

Adapter rules:

- pdu import allowlist points only at this crate;
- `pdu_scan_runner` is the only module that calls `FsTreeBuilder` or custom pdu
  `TreeBuilder`;
- `pdu_reporter_recorder` is the only module that receives pdu callback events;
- `pdu_tree_converter` is the only module that walks pdu `DataTree`;
- `capability` explains every missing pdu fact as exact, lazy, unsupported,
  degraded, or not requested;
- `diagnostics` is redacted and never becomes protocol schema.

### `fs_usage_platform` Ownership

Platform facts crate. It owns current OS metadata, permissions, identity,
capacity, trash, and authority checks. This is separate from pdu because pdu is
optimized for traversal and size aggregation, not safety authority.

Recommended first module shape:

```text
fs_usage_platform/src/
  lib.rs
  metadata/
    platform_metadata_reader.rs
    node_kind_probe.rs
    permissions_probe.rs
    modified_time_probe.rs
  identity/
    file_identity_reader.rs
    stale_identity_detector.rs
    path_revalidation.rs
  capability/
    filesystem_capability_probe.rs
    permission_capability_probe.rs
    scan_quality_probe.rs
  accounting/
    allocated_size_probe.rs
    reclaim_confidence_probe.rs
  trash/
    trash_adapter.rs
    delete_preflight.rs
    delete_receipt.rs
```

Platform rules:

- platform metadata can enrich a scan snapshot, but does not mutate raw pdu
  evidence;
- delete preflight always revalidates current path and identity;
- platform capabilities must be measured under the same process identity as the
  real scanner;
- platform failures become product issue/capability evidence, not pdu errors.

### `clean-disk-server` Ownership

Host/composition root. It wires adapters, resource profiles, auth, HTTP,
WebSocket, protocol DTOs, observability, and process lifecycle.

Recommended first module shape:

```text
apps/clean_disk_server/src/
  main.rs
  bootstrap/
    config.rs
    composition.rs
    resource_profiles.rs
  transport/
    http_routes.rs
    websocket_events.rs
    auth.rs
    cors_origin_policy.rs
  protocol/
    dto/
    mapper/
    compatibility.rs
    schema_version.rs
  runtime/
    shutdown.rs
    worker_pool.rs
    panic_boundary.rs
    observability.rs
```

Server rules:

- server maps product/application output into protocol DTOs;
- server does not expose pdu raw JSON or pdu operation names;
- server owns local token/origin policy;
- server publishes protocol compatibility before risky commands are enabled.

### First Slice Build Order

The least risky order is:

```text
1. fs_usage_core value objects
2. fs_usage_engine ports/use cases/read-model interfaces
3. fake scanner backend in engine tests
4. clean-disk-server protocol skeleton over fake backend
5. fs_usage_pdu scan-only adapter
6. pdu reporter evidence and capability mapping
7. DataTree to NodeArena converter
8. pdu fixture tests and resource baselines
9. Flutter client integration over HTTP/WebSocket pages/events
```

Stop rules:

- if a pdu type is needed outside `fs_usage_pdu`, the boundary is wrong;
- if a Flutter row needs the whole tree, the read-model/query contract is wrong;
- if a delete workflow uses a scan path directly, the safety model is wrong;
- if progress events are needed to reconstruct truth, the event/query model is
  wrong;
- if a domain type needs to know a platform API or pdu feature flag, the domain
  model is wrong.

### Global Pre-Coding Facts To Keep In Mind

- pdu is a final-tree builder, not a node-streaming scanner.
- pdu callback progress is metadata-read evidence, not node publication.
- pdu `DataTree` stores aggregate size, not self size.
- pdu `children().is_empty()` is ambiguous.
- pdu `AccessEntry` error has parent-path precision, not child-path precision.
- pdu hardlink evidence is observation/projection, not reclaim truth.
- pdu CLI combines many host policies and must not be reused as SDK policy.
- pdu JSON exists, but it is not path-fidelity-safe enough for product protocol.
- pdu default features include CLI and JSON, so production feature graph must be
  audited.
- Clean Disk scan evidence, read-model rows, cached Flutter rows, delete queue,
  and delete authority are five different things.

## pdu Source Mechanics Allowlist

This is the practical import policy for the first production adapter. It should
be enforced by an import/lint test before the adapter is merged.

Top 3 enforcement options:

1. Allowlist test over Rust source imports - 🎯 10 🛡️ 9 🧠 5, roughly
   150-500 LOC.
   Accepted. Fast, cheap, and catches the most dangerous boundary mistakes.
2. Rely on code review and module docs - 🎯 5 🛡️ 5 🧠 1, roughly 0-100 LOC.
   Rejected as sufficient. pdu has many convenient modules that compile cleanly
   but are wrong architecturally.
3. Custom cargo-deny style plugin for symbol-level rules - 🎯 7 🛡️ 9 🧠 8,
   roughly 800-2000 LOC.
   Useful later, too heavy for the first slice.

### Production Allowed pdu Surface

Only `fs_usage_pdu` may import these in production scan code:

```text
parallel_disk_usage::fs_tree_builder::FsTreeBuilder
parallel_disk_usage::tree_builder::TreeBuilder
parallel_disk_usage::tree_builder::Info
parallel_disk_usage::data_tree::DataTree
parallel_disk_usage::device::DeviceBoundary
parallel_disk_usage::get_size::{GetApparentSize, GetBlockSize, GetBlockCount}
parallel_disk_usage::hardlink::{HardlinkAware, HardlinkIgnorant, RecordHardlinks}
parallel_disk_usage::reporter::{Reporter, Event, ErrorReport}
parallel_disk_usage::os_string_display::OsStringDisplay
parallel_disk_usage::size::{Bytes, Blocks}
```

Even these are adapter-private evidence types. They must not appear in public
`fs_usage_pdu` API, `fs_usage_engine`, `fs_usage_core`, protocol DTOs, Flutter,
cache schema, or cleanup contracts.

### Diagnostics-Only pdu Surface

These may be imported only behind explicit diagnostics, fixtures, or source-audit
tests:

```text
parallel_disk_usage::data_tree::Reflection
parallel_disk_usage::data_tree::DataTreeReflection
parallel_disk_usage::json_data::*
parallel_disk_usage::hardlink::HardlinkList
parallel_disk_usage::hardlink::HardlinkListReflection
parallel_disk_usage::hardlink::LinkPathListReflection
parallel_disk_usage::runtime_error::RuntimeError
```

Rules:

- diagnostics may not become protocol/cache/export truth;
- pdu JSON must be converted into product fixture drafts, then validated by
  product snapshot rules;
- non-UTF-8 path fixtures must bypass pdu JSON because JSON conversion requires
  UTF-8 names;
- diagnostics must record extra memory use when converting `DataTree` to
  `Reflection` because that creates another recursive tree-shaped structure.

### Production Forbidden pdu Surface

These are forbidden in production scanner/application/server path unless a new
architecture decision explicitly changes this:

```text
parallel_disk_usage::app::*
parallel_disk_usage::args::*
parallel_disk_usage::visualizer::*
parallel_disk_usage::status_board::*
parallel_disk_usage::bytes_format::*
parallel_disk_usage::man_page::*
parallel_disk_usage::usage_md::*
parallel_disk_usage::main
parallel_disk_usage::app::sub::Sub
parallel_disk_usage::app::overlapping_arguments
```

Why:

- `app::Sub` mixes scan execution, empty target fallback to `"."`, fake roots,
  progress reporter teardown, cull, sort, hardlink dedupe, JSON, terminal clear,
  visualization, and runtime error handling;
- `args::*` are CLI parsing types, not product policy;
- `visualizer`, `bytes_format`, and `status_board` are terminal/UI concerns;
- `overlapping_arguments` is helper policy for pdu hardlink dedupe assumptions,
  not product target authority;
- `RuntimeError`/exit semantics are CLI contract, not daemon/protocol contract.

### Source Mechanics That Must Become Tests

| pdu source mechanic | Contract test |
| --- | --- |
| `DataTree::dir` stores aggregate size | `contract_datatree_size_maps_to_aggregate_size_fact_only` |
| `DataTree::children()` returns full `Vec` | `contract_children_query_uses_node_arena_page_not_pdu_vec` |
| `par_retain` keeps removed child sizes in parent | `contract_projection_retains_hidden_size_but_not_delete_targets` |
| hardlink dedupe mutates `DataTree.size` through `strip_prefix` | `contract_hardlink_dedupe_projection_never_mutates_primary_size_fact` |
| `Reflection::par_try_into_tree` checks only child <= parent | `contract_reflection_validation_not_product_snapshot_validation` |
| `par_convert_names_to_utf8` fails for non-UTF-8 names | `contract_non_utf8_paths_bypass_pdu_json_protocol` |
| `Fraction::new` does not reject `NaN` | `contract_product_ratio_rejects_nan_before_pdu` |
| `Depth::Infinite` maps to `u64::MAX` | `contract_unlimited_depth_not_encoded_as_u64_max_in_domain_or_protocol` |
| `Quantity::DEFAULT` differs by platform | `contract_measurement_profile_never_uses_pdu_default_quantity` |
| `OsStringDisplay` Debug-fallbacks non-UTF-8 | `contract_osstringdisplay_not_path_authority` |
| `remove_overlapping_paths` ignores symlink arguments in tests | `contract_product_target_overlap_policy_independent_of_pdu_cli_helper` |
| `ProgressAndErrorReporter` uses helper thread and relaxed counters | `contract_product_progress_not_pdu_terminal_reporter` |
| `ErrorReport::AccessEntry` points at parent directory | `contract_access_entry_issue_has_parent_precision` |
| `GetBlockSize` is Unix `blocks * 512` | `contract_allocated_size_source_is_platform_tagged` |
| pdu `Size` newtypes use ordinary arithmetic | `contract_product_size_arithmetic_is_checked_before_publish` |

### Domain/Data/Infrastructure Boundary From These Mechanics

Domain:

```text
owns names for exact product facts:
MeasurementProfile, SizeFact, NodeRef, ScanIssueReason, ScanQuality,
BoundaryPolicy, LinkPolicy, ProjectionKind, ChildMaterializationState.
```

Application:

```text
owns lifecycle and interpretation:
BackendScanRequest, BackendScanOutput, AdapterDecisionRecord, NodeArena,
ReadModelIndexes, SnapshotPublicationGate, command/query separation.
```

Data/infrastructure:

```text
owns pdu contact:
PduOptionsMapper, PduScanRunner, PduReporterRecorder, PduTreeConverter,
CleanDiskHardlinkRecorder, PduCapabilityMapper, PduBackendFingerprint.
```

Rule:

```text
If a pdu mechanic needs explanation to be safe, it belongs in adapter mapping
and tests, not in domain naming.
```

## Tactical DDD Contract Addendum

This section is the coding gate before the first Rust implementation. It exists
to prevent a common architecture drift: treating pdu output, protocol DTOs,
read-model rows, and domain entities as the same thing.

Accepted direction:

```text
Small domain aggregates
Immutable scan evidence
Large query read models
Thin application orchestration
Anti-corruption adapters around pdu, platform APIs, persistence, and protocol
```

### Tactical DDD Strategy Choice

Top 3 options:

1. Small aggregates plus immutable read model plus pdu anti-corruption adapter -
   🎯 10 🛡️ 10 🧠 7, roughly 1500-3500 LOC for the first serious Rust slice.
   Accepted. This keeps million-node scan data query-optimized and keeps
   destructive invariants small enough to test.
2. Full scan tree as one mutable DDD aggregate - 🎯 3 🛡️ 3 🧠 5, roughly
   1000-2500 LOC. Rejected. It looks simple at first, but every sort, filter,
   page, progress update, metadata enrichment, and cleanup validation would
   become aggregate mutation pressure.
3. DTO-only services with no aggregates - 🎯 5 🛡️ 4 🧠 3, roughly
   700-1800 LOC. Rejected as default. It is fast to start, but cleanup safety,
   scan lifecycle, stale identity checks, and capability gates would become
   scattered procedural rules.

Rule:

```text
The scan tree is data evidence and read-model state, not the core aggregate.
```

### Bounded Contexts

MVP uses one reusable bounded context and one product host context:

```text
Reusable bounded context: Filesystem Usage Analysis
Product host context: Clean Disk Runtime and Cleanup UX
```

The reusable context owns:

- scan request semantics;
- measurement profiles;
- scan session lifecycle;
- snapshot publication;
- node identity inside a snapshot;
- query projections over scan results;
- issue, skip, permission, and degraded-quality vocabulary;
- delete-plan preflight contracts, but not product-specific UI workflow.

The product host owns:

- daemon process lifecycle;
- HTTP/WebSocket protocol;
- local auth/session/origin policy;
- Clean Disk app settings;
- product telemetry and diagnostics policy;
- UI DTO mapping;
- platform installer and permission UX.

### Aggregate Roots

MVP aggregate roots:

```text
ScanSession
DeletePlan
```

`ScanSession` owns:

- session id;
- target set;
- selected backend capability snapshot;
- resource profile;
- lifecycle state machine;
- current published snapshot id;
- cancellation state;
- terminal outcome;
- scan-quality summary.

`ScanSession` does not own:

- every `NodeArenaRecord`;
- full recursive `DataTree`;
- pdu reporter objects;
- WebSocket subscribers;
- Flutter row state;
- SQLite row handles.

`DeletePlan` owns:

- selected candidate refs;
- user intent snapshot;
- current preflight evidence;
- policy verdict;
- risk class;
- confirmation requirement;
- operation idempotency key.

`DeletePlan` does not own:

- raw pdu paths;
- stale UI selection;
- historical snapshot nodes as current authority;
- Trash implementation details.

Potential later aggregate roots, not MVP defaults:

- `CleanupOperation` when cleanup becomes long-running and resumable;
- `RulePack` when recommendations become versioned policy artifacts;
- `RemoteAuthorityGrant` when remote/headless destructive cleanup is allowed;
- `ScanHistoryEntry` when history/compare becomes durable product state.

### Entities, Records, And Value Objects

Use the word `entity` carefully.

Domain entities:

- `ScanSession`, because identity and lifecycle persist over time;
- `DeletePlan`, because identity, validation state, and confirmation state
  persist across commands;
- later `CleanupOperation`, if cleanup spans multiple process lifetimes.

Identity-bearing read-model records, not aggregates:

- `NodeArenaRecord`;
- `NodeDetailsProjection`;
- `SearchResultRow`;
- `TopItemRow`;
- `IssueSampleRecord`;
- `HardlinkEvidenceRecord`.

Value objects:

- `ScanSessionId`;
- `SnapshotId`;
- `NodeId`;
- `NodeRef`;
- `ScanTarget`;
- `TargetScope`;
- `PathAuthority`;
- `DisplayPath`;
- `MeasurementProfile`;
- `SizeFact`;
- `AggregateSizeEvidence`;
- `OwnSizeEvidence`;
- `VisibleChildrenCompleteness`;
- `ScanIssueCode`;
- `ScanQuality`;
- `BackendCapability`;
- `ResourceProfile`;
- `CancellationPolicy`;
- `ProjectionPolicy`;
- `ReclaimEstimate`;
- `EvidenceConfidence`;
- `ProtocolVersion`.

Rule:

```text
If the object is mostly selected, sorted, paged, filtered, searched, or rendered,
it is a read-model/projection object first.
```

### Domain Services

Domain services are pure and side-effect free. They encode product rules that do
not naturally fit inside a single aggregate or value object.

Allowed domain services:

- `TargetOverlapPolicy`;
- `MeasurementPolicy`;
- `ScanQualityClassifier`;
- `NodeVisibilityPolicy`;
- `CleanupEligibilityPolicy`;
- `DeleteRiskPolicy`;
- `ReclaimConfidencePolicy`;
- `CapabilityCompatibilityPolicy`;
- `PrivacyClassificationPolicy`.

Forbidden in domain services:

- `std::fs`;
- pdu imports;
- Tokio;
- Rayon;
- HTTP or WebSocket;
- SQLite/Drift;
- JSON DTOs;
- platform Trash APIs;
- logging raw paths.

Rule:

```text
Domain service input is already parsed evidence.
Domain service output is a typed decision.
```

### Application Services And Use Cases

Application services are thin orchestration. They coordinate ports, domain
services, transactions, snapshot publication, and event emission. They do not
hide business rules in procedural code.

Use cases:

- `CreateScanSession`;
- `StartScan`;
- `CancelScan`;
- `DisposeScanSession`;
- `PublishScanSnapshot`;
- `GetChildrenPage`;
- `GetNodeDetails`;
- `SearchNodes`;
- `GetTopItems`;
- `CreateDeletePlan`;
- `ValidateDeletePlan`;
- `ExecuteDeletePlan`;
- `GetCapabilities`;
- `ExportSnapshot`.

Application services may:

- call scanner ports;
- call platform metadata ports;
- call read-model writers;
- call repositories/journals;
- map adapter evidence into domain decisions;
- publish application events after state transitions.

Application services must not:

- import `parallel_disk_usage`;
- return pdu `DataTree`;
- accept only raw paths as cleanup authority;
- build Flutter DTOs;
- know daemon route names;
- push one event per filesystem entry to the protocol.

### Ports

Ports live in application or engine crates, not in domain.

Inbound ports:

- `ScanCommandPort`;
- `ScanQueryPort`;
- `CleanupCommandPort`;
- `CapabilityQueryPort`;

Outbound ports:

- `ScannerBackend`;
- `ReadModelWriter`;
- `ReadModelQueryStore`;
- `MetadataEnricher`;
- `FilesystemIdentityProvider`;
- `FilesystemAccountingProvider`;
- `TrashProvider`;
- `OperationJournal`;
- `SnapshotRepository`;
- `Clock`;
- `IdGenerator`;
- `EventSink`;
- `DiagnosticsSink`.

Port sizing rule:

```text
Create a port for a role, not for every function.
Split a port when two adapters would change for different reasons.
```

This is how SOLID maps here:

- SRP: pdu scan, metadata enrichment, read-model indexing, cleanup preflight,
  Trash execution, and protocol mapping have different reasons to change.
- OCP: adding `fs_usage_windows_mft` or `fs_usage_walkdir` adds a backend
  adapter without rewriting `ScanSession` or query use cases.
- LSP: every `ScannerBackend` must preserve contract semantics: terminal
  outcome, capability snapshot, error/skip evidence, and cancellation outcome.
- ISP: UI query code should not depend on delete execution methods; scanner
  adapter should not depend on protocol event subscribers.
- DIP: application services depend on `ScannerBackend`, `ReadModelQueryStore`,
  and `TrashProvider` abstractions, while pdu/platform/protocol implement them.

### Data And Infrastructure Layer

Data/infrastructure is where pdu, filesystem APIs, persistence, and transport
are allowed to exist.

`fs_usage_pdu` owns:

- `PduOptionsMapper`;
- `PduBackendFingerprint`;
- `PduScanRunner`;
- `PduReporterRecorder`;
- `PduTreeConverter`;
- `PduHardlinkEvidenceMapper`;
- `PduIssueMapper`;
- `PduCapabilityMapper`;
- pdu version/feature probes;
- pdu fixture compatibility tests.

`fs_usage_platform` owns:

- current metadata restat;
- path identity;
- mount/device topology;
- permissions probing;
- Trash/Recycling Bin adapter;
- platform accounting facts;
- OS-specific evidence confidence.

`fs_usage_engine` owns:

- `ScanSessionService`;
- `NodeArenaWriter`;
- `ReadModelIndexer`;
- `SnapshotPublicationGate`;
- `ChildrenPageQuery`;
- `SearchQuery`;
- `TopItemsQuery`;
- `DeletePlanService`;
- application port traits.

`fs_usage_core` owns:

- IDs;
- value objects;
- domain entities;
- pure policies;
- capability and issue vocabulary;
- result/error types without infrastructure details.

### pdu To Product Contract

Raw pdu surface:

| pdu surface | What it means | Product mapping |
|---|---|---|
| `FsTreeBuilder` | real filesystem traversal entrypoint | infrastructure adapter only |
| `TreeBuilder` | generic parallel recursive tree builder | optional custom adapter base |
| `DataTree` | aggregate size tree with private fields | raw scan evidence |
| `DataTree::size()` | total disk usage stored by pdu | `AggregateSizeEvidence` only |
| `DataTree::children()` | visible stored children | `NodeArenaWriter` input |
| `OsStringDisplay` | display-capable OS string wrapper | adapter traversal name, not UI authority |
| `Reporter::Event::ReceiveData` | one metadata read and size fact | throttled progress evidence |
| `Reporter::Event::EncounterError` | filesystem operation failed | `ScanIssueDraft` |
| `Reporter::Event::DetectHardlink` | pdu saw nlink > 1 file | `HardlinkEvidenceRecord` |
| `HardlinkAware` | Unix hardlink recorder and projection helper | diagnostics/evidence, not reclaim truth |
| pdu JSON | CLI/reflection format | diagnostics and fixtures only |
| `Visualizer` | ASCII terminal rendering | forbidden in daemon/product protocol |

Product rule:

```text
pdu data crosses the boundary once:
pdu raw type -> adapter draft -> engine read model/domain value object.
```

After that mapping, pdu types disappear.

### Important pdu Mechanics For Coding

Facts confirmed from pdu 0.23.0 source and docs:

1. `DataTree` has private `name`, `size`, and `children` fields.
2. `DataTree::dir(name, inode_size, children)` stores aggregate size:
   `inode_size + sum(children.size())`.
3. `DataTree::file(name, size)` stores a leaf with no children.
4. `DataTree::size()` returns total disk usage, not own inode size.
5. `TreeBuilder` uses Rayon `into_par_iter()` for child recursion.
6. `TreeBuilder` decrements `max_depth`, but when depth is exhausted it still
   traverses children to compute aggregate size and stores no child array.
7. `FsTreeBuilder` uses `symlink_metadata`, so symlink targets are not followed
   as ordinary directories.
8. `FsTreeBuilder` reports `symlink_metadata`, `read_dir`, and `AccessEntry`
   failures through `Reporter`, not through `Result<DataTree, Error>`.
9. `FsTreeBuilder` ignores hardlink recorder errors with `.ok()`.
10. `DeviceBoundary::Stay` can avoid descending into another device, but this
    is Unix-shaped and not a complete cross-platform mount policy.
11. `ProgressAndErrorReporter` uses relaxed atomics and a reporting thread.
12. pdu `items` progress is metadata-read count, not final node count and not
    UI row count.
13. pdu `total` progress is accumulated measured size, not final published
    snapshot size.
14. `par_retain` removes children but does not recompute parent aggregate size.
15. `par_cull_insignificant_data` is CLI-feature-gated and root-ratio based.
16. Hardlink dedupe mutates aggregate directory sizes by path-prefix logic.
17. pdu JSON conversion requires UTF-8 names and can fail or panic in CLI path.
18. pdu `Size` newtypes are `u64` arithmetic wrappers, not product-safe
    accounting types.
19. CLI `App` uses `rayon::ThreadPoolBuilder::build_global`, which is not an
    acceptable production daemon boundary because it mutates global Rayon state.
20. CLI HDD auto-thread detection, terminal width, sorting, culling, and
    visualization are product policy examples, not reusable domain rules.

### pdu Mechanics That Must Not Leak

The following pdu concepts must not appear in domain, public protocol, Flutter
DTOs, or cleanup authority:

- `DataTree`;
- `Reflection`;
- `OsStringDisplay`;
- `Bytes`/`Blocks` as direct DTO/domain types;
- `FsTreeBuilder`;
- `TreeBuilder`;
- `ErrorReport`;
- `Operation::{SymlinkMetadata, ReadDirectory, AccessEntry}` as raw public
  enum names;
- `ProgressReport`;
- `HardlinkAware`;
- `HardlinkList`;
- `Visualizer`;
- `StatusBoard`;
- CLI `Args`, `Sub`, `RuntimeError`;
- pdu JSON schema version as product protocol version.

### Anti-Corruption Mapping Pipeline

Accepted adapter pipeline:

```text
PduScanRunner
  -> PduReporterRecorder
  -> raw DataTree
  -> PduTreeConverter
  -> NodeArenaWriter
  -> ReadModelIndexer
  -> SnapshotPublicationGate
```

Parallel side-store pipeline for richer metadata:

```text
pdu traversal callback evidence
  -> AdapterNodeDraft / MetadataDraft / IssueDraft / HardlinkDraft
  -> NodeArenaRecord / ScanIssue / HardlinkEvidence
```

Do not key this side-store by display path only. Use a traversal key created by
the adapter, plus platform identity when available.

### Query Read Models

Query read models are optimized data structures, not domain aggregates.

Required read models:

- compact node arena;
- parent-to-children index;
- sorted child order indexes;
- top files/folders index;
- name/path search index;
- issue index;
- optional hardlink evidence index;
- optional metadata enrichment cache;
- query cursor registry.

Rules:

- Rust owns query read models.
- Flutter requests pages.
- Protocol responses include opaque refs and exact string/int fields.
- UI caches are disposable and never become delete authority.
- Query projections can be rebuilt from a snapshot.
- Query projections must be invalidated by snapshot id and projection policy.

### Event Types By Layer

Do not collapse these into one type:

```text
pdu callback event
adapter internal event
application event
protocol event
Flutter UI event
domain event
```

Mapping:

- pdu callback event -> adapter internal event;
- adapter internal event -> progress evidence or scan issue draft;
- application event -> session state/progress/snapshot lifecycle;
- protocol event -> client invalidation, progress batch, terminal outcome;
- Flutter UI event -> presentation state;
- domain event -> only domain-significant state transitions, not raw
  filesystem callbacks.

Examples:

- `ReceiveData` is not a domain event.
- `ScanSnapshotPublished` can be an application event.
- `DeletePlanConfirmed` can be a domain/application boundary event.
- `NodeExpandedInUi` is only a Flutter UI event.

### Persistence Boundaries

Persistence must store product records, not pdu structs.

Allowed persisted records:

- `ScanSessionRecord`;
- `SnapshotManifest`;
- `NodeArenaSegment`;
- `IssueRecord`;
- `QueryIndexManifest`;
- `DeletePlanRecord`;
- `OperationJournalRecord`;
- `ReceiptRecord`;
- `CapabilitySnapshotRecord`;
- `BackendFingerprintRecord`.

Forbidden persisted records:

- serialized pdu `DataTree` as primary cache;
- pdu CLI JSON as product snapshot;
- raw `ErrorReport`;
- raw terminal visualizer output;
- raw non-redacted paths in support bundle records.

Diagnostic fixtures may keep pdu JSON, but only under fixture/diagnostics rules
with explicit version and backend fingerprint.

### First Coding Gate

Before implementing scanner code, create these contracts or equivalent tests:

```text
contract_node_arena_is_read_model_not_aggregate
contract_scan_session_references_snapshot_by_id
contract_delete_plan_requires_current_revalidation
contract_domain_services_have_no_io_or_pdu_imports
contract_application_services_do_not_import_parallel_disk_usage
contract_repositories_return_product_models_not_pdu_or_protocol_dtos
contract_pdu_callbacks_are_adapter_events_not_domain_events
contract_datatree_size_maps_to_aggregate_size_fact_only
contract_treebuilder_max_depth_hidden_children_are_not_cleanup_targets
contract_pdu_error_report_is_copied_before_callback_returns
contract_pdu_global_thread_pool_not_used_in_daemon_adapter
contract_pdu_json_not_product_protocol
contract_node_ref_contains_snapshot_identity
contract_ui_selection_is_not_delete_authority
contract_read_model_projection_rebuilds_from_snapshot
```

### Architecture Fitness Questions

Use these questions in reviews:

1. Is this type part of business truth, adapter evidence, a read model, or a
   protocol DTO?
2. Does this object need identity over time, or is it a value object?
3. Is this invariant transactional and small enough for an aggregate?
4. Is this sorting/filtering/pagination concern actually a query projection?
5. Does this code import pdu outside `fs_usage_pdu`?
6. Does this code treat pdu aggregate size as own size or reclaim truth?
7. Does this cleanup command rely on a raw path without current identity
   revalidation?
8. Does this event represent domain meaning or just scanner/protocol/UI flow?
9. Can another scanner backend implement the same port without copying pdu
   terminology?
10. Can this feature be tested without UI, HTTP, pdu, and real filesystem
    access?

### Final Boundary Rule

```text
Domain describes disk-usage truth and cleanup safety.
Application coordinates use cases.
Read models serve large queries.
Adapters translate pdu/platform/protocol details.
pdu remains a fast scanner backend, not the architecture.
```

## Sources

- [parallel-disk-usage 0.23.0 crate docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/)
- [Args 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/args/struct.Args.html)
- [Depth 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/args/depth/enum.Depth.html)
- [Fraction 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/args/fraction/struct.Fraction.html)
- [Threads 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/args/threads/enum.Threads.html)
- [FsTreeBuilder 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/fs_tree_builder/struct.FsTreeBuilder.html)
- [TreeBuilder 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/tree_builder/struct.TreeBuilder.html)
- [DataTree 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/data_tree/struct.DataTree.html)
- [Reporter/Event 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/reporter/event/enum.Event.html)
- [Reporter trait 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/reporter/trait.Reporter.html)
- [ParallelReporter trait 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/reporter/trait.ParallelReporter.html)
- [ProgressAndErrorReporter 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/reporter/progress_and_error_reporter/struct.ProgressAndErrorReporter.html)
- [ErrorReport 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/reporter/error_report/struct.ErrorReport.html)
- [Reporter Operation 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/reporter/error_report/operation/enum.Operation.html)
- [ProgressReport 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/reporter/progress_report/struct.ProgressReport.html)
- [StatusBoard 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/status_board/struct.StatusBoard.html)
- [Visualizer 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/visualizer/struct.Visualizer.html)
- [BytesFormat 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/bytes_format/index.html)
- [GetSize 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/get_size/trait.GetSize.html)
- [GetApparentSize 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/get_size/struct.GetApparentSize.html)
- [GetBlockSize 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/get_size/struct.GetBlockSize.html)
- [Size trait 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/size/trait.Size.html)
- [Bytes 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/size/struct.Bytes.html)
- [Blocks 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/size/struct.Blocks.html)
- [GetBlockCount 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/get_size/struct.GetBlockCount.html)
- [Bytes size type 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/size/struct.Bytes.html)
- [Blocks size type 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/size/struct.Blocks.html)
- [Hardlink module 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/hardlink/index.html)
- [RecordHardlinks trait 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/hardlink/record/trait.RecordHardlinks.html)
- [HardlinkAware 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/hardlink/aware/struct.Aware.html)
- [HardlinkIgnorant 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/hardlink/ignorant/struct.Ignorant.html)
- [HardlinkList 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/hardlink/hardlink_list/struct.HardlinkList.html)
- [Hardlink AddError 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/hardlink/hardlink_list/enum.AddError.html)
- [parallel-disk-usage 0.23.0 feature flags](https://docs.rs/crate/parallel-disk-usage/0.23.0/features)
- [RuntimeError 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/runtime_error/enum.RuntimeError.html)
- [JsonData 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/json_data/struct.JsonData.html)
- [SchemaVersion 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/json_data/schema_version/struct.SchemaVersion.html)
- [BinaryVersion 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/json_data/binary_version/struct.BinaryVersion.html)
- [pdu app module 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/app/index.html)
- [DeviceBoundary 0.23.0 docs](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/device/enum.DeviceBoundary.html)
- [Rayon ThreadPool::install docs](https://docs.rs/rayon/latest/rayon/struct.ThreadPool.html#method.install)
- [Rayon ThreadPoolBuilder::build_global docs](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html#method.build_global)
- [sysinfo DiskKind docs](https://docs.rs/sysinfo/latest/sysinfo/enum.DiskKind.html)
- [Rust symlink_metadata docs](https://doc.rust-lang.org/std/fs/fn.symlink_metadata.html)
- [Rust Metadata file_type docs](https://doc.rust-lang.org/std/fs/struct.Metadata.html#method.file_type)
- [Rust OsStr docs](https://doc.rust-lang.org/std/ffi/struct.OsStr.html)
- [Rust Path docs](https://doc.rust-lang.org/std/path/struct.Path.html)
- [Cargo features](https://doc.rust-lang.org/cargo/reference/features.html)
- [Alistair Cockburn Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture)
- [Robert C. Martin Clean Architecture dependency rule](https://www.informit.com/articles/article.aspx?p=2832399)
- [Microsoft Azure Tactical DDD guidance](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/tactical-domain-driven-design)
- [Microsoft DDD-oriented microservice guidance](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/ddd-oriented-microservice)
- [Microsoft domain model, value object, and aggregate guidance](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- Local source audit:
  `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/parallel-disk-usage-0.23.0`
- Local dependency freshness check on 2026-05-20:
  `cargo info parallel-disk-usage` reported `0.23.0`, Apache-2.0, default
  feature `cli`, and optional `json`.
