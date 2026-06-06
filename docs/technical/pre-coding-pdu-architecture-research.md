# Pre-Coding pdu Architecture Research

Last updated: 2026-05-20.

This document is the pre-coding checklist for the Rust scanner side. It combines
source-level `parallel-disk-usage` research with Clean Architecture, DDD,
ports-and-adapters, and SOLID rules that must be respected before writing the
first production scanner code.

Read this before creating `fs_usage_core`, `fs_usage_engine`, `fs_usage_pdu`,
`clean-disk-server`, protocol DTOs, or Flutter scan clients.

## Executive Conclusion

pdu is a strong scanner backend, but it is not our architecture.

Accepted direction:

```text
pdu = private infrastructure adapter.
fs_usage_core = reusable domain language.
fs_usage_engine = application/use-case and read-model layer.
clean-disk-server = host/composition root and transport.
Flutter = view/application client over protocol adapters.
```

Top 3 implementation strategies:

1. Build our engine contracts first, then adapt pdu - 🎯 10 🛡️ 10 🧠 7,
   roughly 3000-7000 LOC for the first production scanner/read-model slice.
   Accepted. It keeps pdu replaceable and lets us add MFT, APFS, custom
   accounting, remote/headless, and safer cleanup later without protocol churn.
2. Wrap pdu models directly and refactor when needed - 🎯 5 🛡️ 5 🧠 4,
   roughly 1000-2500 LOC now, but high rewrite risk.
   Rejected. `DataTree`, `Reporter`, `BytesFormat`, and pdu JSON would leak into
   stable contracts.
3. Fork pdu now and make it our scanner engine - 🎯 5 🛡️ 6 🧠 9,
   roughly 5000-12000 LOC plus ongoing upstream maintenance.
   Deferred. Keep this as an escape hatch only after measured blockers prove the
   adapter path cannot meet cancellation, memory, progress, or streaming needs.

Core rule:

```text
Contracts are Pro. Implementation is MVP.

The MVP may perform one pdu final-tree scan.
The contracts must already support session ids, snapshots, paging, issues,
capabilities, policy, metadata enrichment, and backend replacement.
```

## Accepted Contract Boundary

This is the shape to implement first unless a new spike disproves pdu viability.

```text
Domain
  owns vocabulary and invariants:
  ScanTarget, SnapshotId, NodeId, NodeRef, SizeFact, DisplayPath,
  PathAuthorityRef, LinkPolicy, BoundaryPolicy, ScanIssueReason, ScanQuality,
  DeletePlan vocabulary.

Application
  owns use cases and ports:
  ScannerBackend, MetadataReader, FileIdentityReader, ReclaimAccounting,
  TrashAdapter, ScanEventSink, ReadModelQueryPort, DeletePlanValidator.

Data/infrastructure
  owns pdu integration and platform facts:
  PduScannerBackend, PduReporterRecorder, PduTreeConverter, side stores for
  path/kind/self-size/issue evidence, platform metadata probes, trash adapters.

Host/protocol
  owns runtime and transport:
  clean-disk-server process lifecycle, resource profile, HTTP commands,
  WebSocket events, auth/origin policy, DTO mapping, compatibility endpoint.

Flutter
  owns user interaction:
  commands, paginated queries, stale/degraded states, details, queue, and
  confirmation UI over product DTOs only.
```

Non-negotiable boundaries:

- pdu is allowed only behind the `fs_usage_pdu` adapter.
- `DataTree`, `OsStringDisplay`, pdu `Reporter`, pdu `Args`, pdu JSON, Rayon,
  `PathBuf` authority, `std::fs::Metadata`, and `io::Error` do not cross into
  domain, Flutter, or public protocol.
- the application receives a product-shaped `BackendScanOutput`, not pdu raw
  models.
- scan snapshots are evidence, not delete authority.
- delete authority is created only by current preflight validation under the
  same scanner/platform identity.
- every scan result carries capabilities and completion state.

## Latest Source-Audit Lock Before Coding

This section is the condensed decision record from the pdu 0.23.0 source audit.
Use it as the final checkpoint before creating Rust crates or DTOs.

Verified pdu shape:

- pdu's library scanner is a final-tree builder plus side-channel reporter
  events, not a streaming node engine;
- `FsTreeBuilder` converts into `DataTree` through `From`/`Into`, so filesystem
  errors are not the function result;
- `TreeBuilder` recursively builds child subtrees through Rayon and materializes
  `Vec` children;
- `TreeBuilder::Info` is only `{ size, children }`, so pdu cannot carry product
  metadata by itself;
- `DataTree::dir` stores aggregate size, so own size must be captured separately
  if the product needs it;
- pdu `Reporter::Event` is non-exhaustive and carries borrowed path/metadata
  references, so adapter code must copy evidence immediately;
- `HardlinkAware` reports detection before adding to its record, and
  `FsTreeBuilder` discards recorder errors with `.ok()`;
- Unix `GetBlockSize` is `metadata.blocks() * 512`, while block count and
  apparent bytes are separate pdu size modes. Product `MeasurementProfile` must
  choose semantics explicitly;
- `DataTree::par_sort_by` uses unstable sorting, and
  `par_cull_insignificant_data` is a float ratio projection. Neither is product
  query policy or stable ordering;
- pdu CLI `Sub` combines scan, fake roots, progress teardown, cull, sort,
  hardlink dedupe, JSON, terminal output, and visualizer policy. It is a host,
  not a reusable engine.

Architecture lock:

```text
fs_usage_core
  product language only: identity, size facts, issue taxonomy, policies.

fs_usage_engine
  application truth: session lifecycle, commands, queries, read model, ports.

fs_usage_pdu
  infrastructure adapter: pdu execution, reporter capture, pdu tree conversion,
  capability mapping, adapter diagnostics.

fs_usage_platform
  platform facts: metadata, identity, permissions, trash, capacity, accounting.

clean_disk_protocol
  wire contracts only: DTOs, compatibility, schema, redaction classes.

clean-disk-server
  composition root: daemon lifecycle, auth, HTTP/WebSocket, observability.
```

The first implementation should follow this order:

1. Product contracts plus fake backend - 🎯 10 🛡️ 10 🧠 6, roughly
   900-2000 LOC.
   This proves Clean Architecture before pdu imports exist.
2. pdu `FsTreeBuilder` scan-only adapter behind `ScannerBackend` - 🎯 8 🛡️ 8
   🧠 6, roughly 900-1800 LOC.
   Good MVP path if missing node kind, self-size, hardlink conflicts, and
   cancellation are honestly reported as capability gaps or lazy facts.
3. custom pdu `TreeBuilder` adapter with side stores - 🎯 8 🛡️ 9 🧠 8,
   roughly 1800-3600 LOC.
   Best production path once top files, exact kind indexes, self-size, better
   cancellation, or richer issue evidence become required.

What must not happen:

- no public domain/application/protocol type mirrors pdu types;
- no query endpoint mutates scanner/session/delete state;
- no projection becomes cleanup authority;
- no pdu CLI helper becomes product policy;
- no full recursive pdu tree crosses the daemon or Flutter boundary.

Highest-risk contracts to prove first:

1. Side-store correlation - 🎯 7 🛡️ 9 🧠 8, roughly 500-1200 LOC.
   If custom `TreeBuilder` is used, `PduTraversalKey` must attach metadata,
   issue, and path evidence back to the correct `DataTree` node without relying
   on display strings or child indexes alone.
2. Resource governance - 🎯 7 🛡️ 9 🧠 8, roughly 600-1600 LOC.
   pdu is fast because it is parallel; Clean Disk must own
   balanced/fast/background budgets, local Rayon execution, memory pressure
   behavior, and cancel latency.
3. Authority separation - 🎯 9 🛡️ 10 🧠 7, roughly 700-1800 LOC.
   Scan evidence, read-model projections, cached Flutter rows, and delete
   preflight authority must remain different types and different workflows.

## Deep pdu Source Pass Before Implementation

This pass classifies pdu by real source responsibility, not by convenient public
type names. Use it when creating the first `fs_usage_pdu` module skeleton.

| pdu source surface | What it actually is | Clean Disk contract consequence |
| --- | --- | --- |
| `fs_tree_builder::FsTreeBuilder` | real filesystem final-tree scanner | allowed only inside `PduScannerBackend` |
| `tree_builder::TreeBuilder` and `Info` | generic final-tree recursion over `{ size, children }` | not our scanner port, not a streaming API |
| `data_tree::DataTree` | aggregate size tree with private `name`, `size`, `Vec<children>` | raw evidence to convert, never read model |
| `data_tree::Reflection` | public-field inspection and JSON bridge helper | diagnostic/test draft only |
| `reporter::{Reporter, Event, ErrorReport}` | synchronous side-channel callbacks with borrowed evidence | adapter copies owned evidence immediately |
| `ProgressAndErrorReporter` | CLI-style sampler thread around relaxed counters | forbidden for production progress architecture |
| `get_size::{GetApparentSize, GetBlockSize, GetBlockCount}` | one selected measurement mode per scan | map into product `MeasurementProfile` |
| `size::{Bytes, Blocks}` | pdu arithmetic/display newtypes | convert into checked `SizeFact` |
| `hardlink::{HardlinkAware, HardlinkList}` | Unix-oriented hardlink evidence and projection helpers | evidence/projection only, not reclaim truth |
| `device::DeviceBoundary` | pdu traversal boundary policy | map from product `BoundaryPolicy` with capability evidence |
| `os_string_display::OsStringDisplay` | display wrapper for OS names | display evidence only, not path authority |
| `json_data::*` | pdu CLI JSON interchange | fixture/diagnostic only |
| `app::*`, `args::*`, `runtime_error::*` | pdu CLI host behavior | forbidden in production scanner path |
| `visualizer::*`, `bytes_format::*`, `status_board::*` | terminal/UI formatting concerns | forbidden outside diagnostics/tests |

The pdu source shape creates a firm boundary:

```text
pdu can discover and aggregate.
Clean Disk must identify, qualify, index, authorize, and explain.
```

Additional high-risk pdu mechanics from the deeper source pass:

- pdu `App::run` is not a library service. It parses CLI args, reads stdin JSON,
  writes terminal output, creates progress reporters, chooses thread count,
  configures global Rayon, maps quantity modes, handles unsupported CLI feature
  errors, and invokes `Sub`.
- pdu `Sub::run` treats an empty target list as `"."`. Clean Disk must reject or
  explicitly model empty target intent before the adapter.
- pdu multi-root mode creates a fake empty root and later renames it to
  `(total)`. Clean Disk must create its own synthetic root ids and labels.
- pdu overlapping-root removal runs only for Unix hardlink dedupe with more than
  one target. Clean Disk target normalization must be independent from hardlink
  mode.
- pdu auto thread behavior is CLI policy: it uses `sysinfo`, mount matching, and
  Linux virtual-device heuristics, then calls Rayon `build_global`. Clean Disk
  resource profiles must be daemon-owned and session-aware.
- pdu default quantity is platform-specific: Unix CLI defaults to block size,
  non-Unix CLI defaults to apparent size. Product scan requests must make size
  semantics explicit instead of inheriting CLI defaults.
- pdu `ProgressAndErrorReporter` samples every 100ms in the CLI path and reports
  through terminal helpers. Product progress is our sequenced event stream plus
  final query reconciliation.
- pdu `ErrorReport` contains only operation, borrowed path, and `io::Error`.
  Product issues need reason, severity, privacy class, capability impact, and
  remediation text outside the adapter.
- pdu `DataTree::par_cull_insignificant_data` is behind the `cli` feature and
  uses root-relative `f32` thresholds. Product pruning/top lists must use engine
  projections, not pdu CLI feature helpers.
- pdu hardlink dedupe mutates aggregate directory sizes by prefix-stripping paths
  under the current `DataTree` name. Product hardlink facts must stay separated
  as raw measured size, adjusted projection, and reclaim-confidence evidence.
- pdu hardlink summary can panic if detected paths exceed reported `nlink`. The
  daemon must catch panics at the adapter boundary and downgrade backend
  confidence rather than crash the product process.
- pdu `Reflection::par_try_into_tree` validates only one narrow invariant: a
  child cannot be larger than its parent. It does not validate path identity,
  scan completeness, permission quality, stale state, or cleanup safety.
- pdu JSON schema version is pdu interchange provenance, not Clean Disk protocol
  compatibility. Do not mirror `schema-version`, `unit`, `tree`, or `shared` as
  product DTO contracts.

Additional source-test implications:

- pdu `DataTree::par_retain` tests show that when children are removed, their
  size remains rolled into the parent aggregate. A node with no children can
  therefore mean a real file, empty directory, unreadable directory,
  cross-boundary directory, max-depth projection, or culled projection. Domain
  must model materialization/completeness separately from "has children".
- pdu overlapping-target tests intentionally do not remove symlink arguments as
  duplicates of their resolved targets. Clean Disk target normalization must own
  symlink policy explicitly instead of copying pdu CLI overlap removal.
- pdu hardlink tests show `(dev, ino)` is the identity key and that size or
  link-count conflicts are detectable in `HardlinkList`, but the normal
  `FsTreeBuilder` path discards recorder errors. Our adapter must capture or
  explicitly mark those conflicts as unknown.
- pdu HDD tests document Linux virtual-device correction and also a real
  LVM/device-mapper limitation where `/dev/dm-*` cannot be resolved to backing
  devices. Product `ResourceProfile` must treat storage medium as a weak hint,
  not a reliable scheduling truth.
- pdu `DeviceId` tests show `/dev` on macOS and `/proc` on Linux as separate
  filesystem examples, while non-Unix `DeviceId` collapses to `()`. Boundary
  support is therefore a capability fact, not a universal backend promise.

### Clean Architecture Mapping From pdu Facts

Domain layer `fs_usage_core`:

- owns names like `ScanTarget`, `NodeRef`, `SizeFact`, `MeasurementProfile`,
  `TraversalPolicy`, `BoundaryPolicy`, `ScanIssueReason`, `ScanQuality`, and
  cleanup vocabulary;
- does not own `DataTree`, `FsTreeBuilder`, `TreeBuilder`, `Info`, `Reporter`,
  `Event`, `ErrorReport`, `Bytes`, `Blocks`, `HardlinkList`, `Reflection`,
  `JsonData`, `PathBuf`, `std::fs::Metadata`, or `io::Error`;
- should model uncertainty as normal product state: degraded scan quality,
  unsupported capability, lazy metadata, projection, and stale authority.

Application layer `fs_usage_engine`:

- owns `ScannerBackend`, scan commands, query ports, session state machine,
  cancellation epoch, snapshot publication, arena/read-model creation, and event
  sequencing;
- receives `BackendScanOutput`, not pdu raw types;
- decides when a scan is usable, degraded, canceled, stale, incompatible, or
  queryable;
- must not call pdu directly. It depends on ports and product-shaped value
  objects only.

Data/infrastructure layer `fs_usage_pdu` and `fs_usage_platform`:

- `fs_usage_pdu` owns `PduScannerBackend`, `PduOptions`, `PduRawScanResult`,
  `PduReporterRecorder`, `PduTreeConverter`, hardlink evidence capture, and
  pdu capability mapping;
- `fs_usage_platform` owns native path identity, metadata enrichment,
  permissions, trash, filesystem/accounting facts, and delete preflight;
- both layers map outward facts inward. They do not export upstream types as
  stable product contracts.

Host/protocol layer `clean-disk-server` and `clean_disk_protocol`:

- owns HTTP commands, WebSocket events, auth/origin policy, compatibility, DTO
  versioning, redaction, and observability;
- maps application models to string-safe DTOs;
- never treats pdu JSON schema, pdu binary version, or pdu CLI exit errors as
  protocol compatibility.

Flutter:

- owns interaction state, view models, paged rows, stale/degraded indicators,
  cleanup queue UI, and confirmation UI;
- never owns complete scan truth or cleanup authority;
- queries Rust for sorted/filtered/paginated data instead of sorting full pdu
  trees locally.

### First Contract Tests To Write

These tests should exist before the pdu adapter is considered accepted:

1. import guard: `parallel_disk_usage` imports exist only in `fs_usage_pdu`.
2. fake backend test: engine scan/session/query works with no pdu dependency.
3. pdu normal tree fixture maps to engine `NodeArena` and root snapshot.
4. pdu error event maps to degraded `ScanQuality`, not failed process only.
5. missing root is preflight failure, not pdu zero-size success.
6. symlink fixture proves default policy does not follow links.
7. `max_depth` fixture proves hidden descendants are counted but not cleanup
   targets.
8. non-UTF-8 fixture proves display text is not path authority.
9. hardlink fixture proves raw measured size and hardlink-adjusted projection
   are separate facts.
10. hardlink conflict fixture lowers confidence instead of claiming exact truth.
11. cancellation fixture proves late pdu result is discarded by epoch.
12. read-model memory test proves `DataTree` is dropped after conversion.
13. protocol schema test proves no DTO mirrors pdu JSON or pdu type names.
14. Flutter repository test proves DTOs are mapped before store/widget usage.

Top 3 source-integration gates:

1. Contract-first fake backend, then pdu adapter - 🎯 10 🛡️ 10 🧠 7, roughly
   1200-2800 LOC.
   Accepted. This proves the product architecture before upstream SDK semantics
   enter the codebase.
2. pdu adapter first, then wrap with engine contracts - 🎯 6 🛡️ 6 🧠 5,
   roughly 900-2200 LOC.
   Rejected as default. It is tempting, but the first working shape would
   probably leak pdu terms into read models and DTOs.
3. CLI/JSON prototype first, then replace with SDK - 🎯 4 🛡️ 4 🧠 3, roughly
   300-1000 LOC.
   Rejected for architecture. It may help manual demos, but it teaches the wrong
   boundary and ignores macOS process identity concerns.

## Pre-Coding Implementation Blueprint

This is the concrete starting shape for code. It is still documentation, but it
should be treated as the default crate/module contract until a spike disproves
it.

### `fs_usage_core`

Purpose:

- product vocabulary and invariants that remain true with pdu, MFT, APFS, mock,
  or remote backends.

Initial public modules:

```text
domain/
  identity/
    scan_session_id
    backend_run_id
    snapshot_id
    node_id
    node_ref
  target/
    scan_target
    scan_target_set
    target_scope
    boundary_policy
    link_policy
  size/
    measurement_profile
    size_fact
    size_kind
    size_confidence
  evidence/
    evidence_class
    evidence_confidence
    path_authority_ref
    display_path
    node_kind_evidence
  issue/
    scan_issue_reason
    scan_issue_severity
    scan_issue
  policy/
    traversal_policy
    projection_policy
    privacy_profile
```

Rules:

- no pdu, serde DTOs, HTTP, Tokio, Flutter, `std::fs::Metadata`, or `PathBuf`
  authority in public domain models;
- prefer newtypes/private fields for ids and size facts;
- enums that cross crate boundaries are future-safe: unknown/unsupported states
  are valid product states.

### `fs_usage_engine`

Purpose:

- application orchestration, use cases, ports, session lifecycle, published
  snapshots, read-model queries, and destructive workflow gates.

Initial public modules:

```text
application/
  ports/
    scanner_backend
    metadata_reader
    file_identity_reader
    reclaim_accounting
    trash_adapter
    event_sink
    clock
  commands/
    create_scan_session
    start_scan
    cancel_scan
    dispose_scan_session
    build_delete_plan
  queries/
    get_scan_status
    get_children_page
    get_node_details
    search_nodes
    get_top_items
  session/
    scan_session
    scan_state
    session_registry
  read_model/
    node_arena
    node_record
    children_index
    query_cursor
    page
    projection_index
  backend/
    scan_request
    scan_output
    capability_snapshot
    adapter_decision_record
    backend_failure
```

Rules:

- commands mutate session/delete-plan state; queries are read-only over published
  snapshots and indexes;
- `ScannerBackend` returns product-shaped `BackendScanOutput`, never pdu
  `DataTree`;
- `NodeArena` is a read model, not a DDD aggregate;
- event streams can wake or invalidate the client, but queries remain source of
  truth for rows/details/search.

### `fs_usage_pdu`

Purpose:

- anti-corruption adapter from pdu source facts into engine contracts.

Initial private modules:

```text
adapter/
  pdu_scanner_backend
  pdu_scan_runner
  pdu_execution_lane
  pdu_output_requirements_selector
probe/
  pdu_entry_probe
  pdu_size_getter_mapper
  pdu_boundary_mapper
reporter/
  pdu_reporter_recorder
  pdu_event_mapper
  pdu_progress_coalescer
hardlink/
  pdu_hardlink_recorder
  pdu_hardlink_evidence_mapper
convert/
  pdu_tree_converter
  pdu_node_correlator
  pdu_side_store
diagnostics/
  pdu_backend_fingerprint
  pdu_capability_mapper
  pdu_adapter_decision_mapper
```

Rules:

- this is the only crate that imports `parallel_disk_usage`;
- public API exposes only `PduScannerBackend` as a `ScannerBackend`
  implementation plus diagnostic feature-gated helpers;
- pdu built-in `ProgressAndErrorReporter`, terminal reporters, visualizer,
  `app::Sub`, CLI args, JSON, and reflection are not production scan path;
- pdu reporter callbacks copy borrowed evidence and never call protocol/UI/log
  sinks directly;
- direct `FsTreeBuilder` path is allowed for scan-only MVP, but must report
  missing kind/self-size/conflict/cancel capabilities honestly;
- custom `TreeBuilder` path is the production upgrade path for richer side
  stores and cooperative pruning.

### `fs_usage_platform`

Purpose:

- platform truth that pdu does not own: metadata, file identity, permissions,
  Trash/recycle behavior, capacity, reclaim/accounting evidence.

Rules:

- scan-time evidence and delete-time authority stay separate;
- metadata enrichment can be lazy, but delete preflight is always current;
- platform adapters publish capability evidence instead of pretending every OS
  has the same identity, hardlink, boundary, or accounting model.

### `clean_disk_protocol`

Purpose:

- versioned wire DTOs and mapping between engine/application models and
  HTTP/WebSocket JSON.

Rules:

- no pdu-shaped DTOs;
- exact large values are web-safe;
- unknown enum/capability values fail closed for destructive workflows;
- DTOs are not domain models and not Flutter view state.

### Why This Is Clean Architecture, DDD, SOLID

Clean Architecture:

- domain policy is independent from pdu, platform APIs, transport, cache, and UI;
- dependencies point inward;
- pdu is a mechanism in the outer ring.

DDD:

- `ScanSession` and `DeletePlan` are consistency boundaries;
- the million-node tree is an immutable read model;
- value objects carry semantics such as measurement profile, evidence class,
  confidence, and path authority.

Ports/adapters:

- engine defines `ScannerBackend`, `MetadataReader`, `TrashAdapter`,
  `ReadModelQueryPort`;
- pdu/platform/protocol implement or map adapters;
- tests can replace pdu with fake backends.

SOLID:

- SRP: scanner execution, reporter capture, tree conversion, issue mapping,
  size mapping, capability mapping, and protocol mapping have different reasons
  to change;
- OCP: MFT/APFS/custom scanner adds a backend adapter, not pdu branches in
  domain;
- LSP: every backend satisfies the same lifecycle and capability honesty rules;
- ISP: scanner, metadata, identity, accounting, trash, event, and query ports are
  separate;
- DIP: engine owns ports; infrastructure depends inward.

Top 3 code-organization choices:

1. Layered reusable crates plus pdu/platform/protocol adapters - 🎯 10 🛡️ 10
   🧠 7, roughly 3000-7000 LOC for scan MVP.
   Accepted. Strong boundaries, reusable scanner library, backend replacement,
   and remote/headless readiness.
2. One Rust crate with `domain/application/infrastructure` modules - 🎯 7 🛡️ 7
   🧠 4, roughly 1800-4000 LOC.
   Acceptable for a prototype, but import boundaries and reusable library story
   are weaker.
3. pdu-centered library with product wrappers - 🎯 4 🛡️ 5 🧠 3, roughly
   1200-3000 LOC.
   Rejected. It starts fast but turns pdu final-tree semantics into product API
   debt.

## Minimum Contract Type Dictionary

Use this dictionary before writing the first Rust modules. These names may
change, but each responsibility must remain owned by the listed layer.

| Type | Owner | Meaning | Must not contain |
| --- | --- | --- | --- |
| `ScanTargetSet` | `fs_usage_core` / engine validation | explicit user intent for one scan | pdu empty-target fallback to `"."` |
| `OutputRequirements` | `fs_usage_engine` | requested product facts such as kind index, self-size, top files, cancellation mode | pdu mode names |
| `BackendScanRequest` | `fs_usage_engine` | policies, resource profile, privacy profile, target set, session epoch | pdu `Args`, `Depth`, `Fraction`, `Threads` |
| `PduOptions` | `fs_usage_pdu` private | mechanical mapping into pdu `root`, `size_getter`, `device_boundary`, `max_depth`, hardlink mode | domain/protocol DTO fields |
| `PduRawScanResult` | `fs_usage_pdu` private | pdu `DataTree` plus copied reporter evidence, timings, feature fingerprint | public API, Flutter DTOs, cache schema |
| `BackendScanOutput` | `fs_usage_engine` | product-shaped backend output: snapshot draft, issues, capabilities, diagnostics | pdu concrete types |
| `ScanSnapshotDraft` | `fs_usage_engine` | unpublished scan evidence before validation/index/publish gate | delete authority |
| `NodeArenaRecord` | `fs_usage_engine` read model | compact node fact row for paginated queries | pdu child order as stable identity |
| `SizeFact` | `fs_usage_core` | explicit size semantics and confidence | formatted strings, pdu terminal units |
| `ScanIssueDraft` | `fs_usage_engine` | owned product issue mapped from pdu/platform evidence | raw `io::Error` or pdu operation names as public reason ids |
| `ScanEvent` | `fs_usage_engine` | sequenced product event for progress/state invalidation | one event per filesystem entry as UI truth |
| `DeletePlan` | `fs_usage_engine` / cleanup domain | current destructive intent after preflight validation | stale scan rows or display paths as authority |
| `Protocol DTO` | `clean_disk_protocol` | versioned wire shape for HTTP/WebSocket | pdu schema/version as protocol version |

Layer handoff:

```text
BackendScanRequest
  -> PduOptions
  -> pdu FsTreeBuilder or custom TreeBuilder
  -> PduRawScanResult
  -> BackendScanOutput
  -> ScanSnapshotDraft
  -> NodeArena + ReadModelIndexes
  -> paginated protocol DTOs
  -> Flutter view models
```

Stop rule:

```text
If a type is useful both before and after PduRawScanResult conversion, it is
probably not a pdu type. Move it inward and map pdu into it.
```

### Contract Facts From pdu Internals

These pdu details are easy to miss and should be encoded in tests or type
boundaries:

- root name and child name semantics differ: pdu root can be a path-like name,
  while child names are directory entry names;
- `AccessEntry` errors point at the parent directory, not at a known child path;
- pdu progress `items` means metadata reads observed, not final nodes published;
- pdu progress `linked` increments by reported link count, not unique hardlink
  groups;
- pdu progress `shared` accumulates detection evidence, not reclaimable bytes;
- `ProgressAndErrorReporter` uses a helper thread and relaxed atomics. It is a
  CLI convenience, not product progress architecture;
- pdu `HardlinkList` can detect size and link-count conflicts, but default
  `FsTreeBuilder` hides recorder errors unless our adapter captures them;
- pdu hardlink dedupe mutates the recursive tree, so it must remain a named
  projection, never the measured snapshot;
- pdu cull/sort helpers mutate the tree and use unstable ordering/float ratios,
  so product sorting/filtering belongs in `ReadModelIndexes`;
- pdu `json` and `cli` features are additive Cargo features, so resolved feature
  graph must be checked in production builds.

Top 3 contract strictness options:

1. Strict type dictionary plus import/schema tests - 🎯 10 🛡️ 10 🧠 6, roughly
   500-1400 LOC.
   Accepted. It prevents pdu shape, UI rows, and delete authority from blending
   as the codebase grows.
2. Rely on folder naming and code review - 🎯 5 🛡️ 5 🧠 2, roughly 50-200 LOC.
   Rejected as sufficient. The risky mistakes compile cleanly unless tests catch
   them.
3. Make every contract generic enough to hide all semantics - 🎯 4 🛡️ 6 🧠 8,
   roughly 1000-2500 LOC.
   Rejected for MVP. Over-abstracting would make the first backend harder to
   verify.

## pdu Source Fact To Acceptance Gate Matrix

This matrix is the practical "do not start coding blind" checklist. Every row
connects a pdu source fact to a product boundary and an early test/guard.

| Source fact | Product boundary | Acceptance gate before integration |
| --- | --- | --- |
| `DeviceId` is `u64` on Unix and `()` outside Unix | `BoundaryPolicy` plus platform capability | non-Unix boundary support is reported as weakened/unknown, never universal |
| `DeviceBoundary::Stay` skips descent without a pdu skip event | `ScanIssueReason::BoundaryNotDescended` | boundary fixture creates explicit issue/capability evidence |
| `OsStringDisplay` falls back to Debug text for non-UTF-8 names | `DisplayPath` versus `PathAuthorityRef` | non-UTF-8 fixture proves display text cannot be delete authority |
| `Bytes` and `Blocks` are separate `u64` newtypes | `SizeFact` and `MeasurementProfile` | apparent bytes, allocated bytes, and block count map to distinct facts |
| pdu arithmetic is ordinary newtype arithmetic | checked product constructors | overflow/saturation test lowers confidence or fails the scan safely |
| `Threads::Auto/Max/Fixed` are CLI/Rayon settings | `ResourceProfile` and `ExecutionLane` | daemon never imports pdu `Threads` or calls CLI `build_global` |
| HDD detection uses `sysinfo`, mount matching, and Linux virtual-device heuristics | storage medium hint only | balanced mode never depends solely on pdu HDD auto |
| `Reflection` public fields validate only tree-size shape | diagnostic import only | pdu JSON/reflection import cannot create current scan or delete authority |
| `JsonData` uses `schema-version`, optional `pdu`, `unit`, `tree`, `shared` | diagnostic/export provenance only | no protocol/cache DTO mirrors pdu JSON schema |
| `ProgressAndErrorReporter` owns a helper thread and relaxed counters | product progress pipeline | production adapter uses its own reporter recorder and event throttling |
| `HardlinkList` conflicts exist but `FsTreeBuilder` drops recorder errors | hardlink evidence confidence | conflict fixture proves confidence degrades instead of claiming exact truth |
| `DataTree::par_sort_by`, cull, and dedupe mutate tree | read-model projections only | product sort/filter/top lists use engine indexes, not pdu tree mutations |
| CLI empty targets fallback to `"."` | explicit `ScanTargetSet` intent | empty-target command is rejected or explicitly confirmed before backend call |
| CLI multi-root creates fake root then `(total)` | product synthetic root policy | synthetic root ids/labels come from engine, never pdu names |
| CLI overlapping-root removal is tied to hardlink mode | target normalization policy | duplicate/overlap handling runs before pdu and independent from hardlink option |
| CLI auto threads can call global Rayon `build_global` | daemon execution profile | pdu scan runs in a daemon-owned execution lane, not pdu CLI thread policy |
| Unix CLI default is block size, non-Unix default is apparent size | explicit size semantics | scan request always carries `MeasurementProfile`, no inherited pdu defaults |
| hardlink summary can panic on impossible `nlink` evidence | adapter panic boundary | backend panics are contained and mapped to degraded/failed scan evidence |

Implementation rule:

```text
Every pdu source fact must become one of:
  product fact,
  projection,
  capability,
  diagnostic evidence,
  or explicit unsupported behavior.
It must never become implicit behavior.
```

Top 3 acceptance-gate strategies:

1. Matrix-driven tests before adapter merge - 🎯 10 🛡️ 10 🧠 7, roughly
   700-1800 LOC.
   Accepted. It converts source-audit knowledge into executable protection
   before UI/protocol code depends on it.
2. Add tests only after pdu adapter works manually - 🎯 6 🛡️ 5 🧠 3, roughly
   300-900 LOC.
   Rejected as default. The first adapter shape will already leak assumptions by
   then.
3. Trust pdu upstream tests for these behaviors - 🎯 4 🛡️ 5 🧠 1, roughly
   0-100 LOC.
   Rejected. pdu tests protect pdu's CLI/library goals, not Clean Disk authority,
   protocol, or UX semantics.

## Sources Used

Research note:

- Context7 was checked on 2026-05-20, but it did not expose an exact
  `parallel-disk-usage` library entry. Authoritative pdu facts in this document
  therefore come from docs.rs, crates.io/`cargo info`, and the locally audited
  crate source for `parallel-disk-usage` 0.23.0.

Current pdu facts:

- docs.rs says `parallel_disk_usage` 0.23.0 is the library crate for `pdu`, and
  highlights `FsTreeBuilder`, `TreeBuilder`, `DataTree`, and `Visualizer` as the
  main interesting APIs:
  [parallel_disk_usage](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/).
- docs.rs describes `DataTree` as disk usage data that can be built from
  `FsTreeBuilder`, `TreeBuilder`, or `Reflection`; visualization uses
  `Visualizer`; JSON goes through `Reflection`, not direct `DataTree` serde:
  [DataTree](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/data_tree/struct.DataTree.html).
- docs.rs lists `JsonData`, `JsonTree`, `JsonShared`, `Reflection`, `Args`,
  `GetApparentSize`, `GetBlockSize`, `GetBlockCount`, `DeviceBoundary`,
  reporter types, hardlink types, and visualizer types as crate items. This is
  useful for auditing, but not a reason to expose those types across Clean Disk
  boundaries:
  [All Items](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/all.html).
- docs.rs describes `FsTreeBuilder` fields: `root`, `size_getter`,
  `hardlinks_recorder`, `reporter`, `device_boundary`, and `max_depth`; its
  `max_depth` stores descendant sizes in totals even when children are not kept:
  [FsTreeBuilder](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/fs_tree_builder/struct.FsTreeBuilder.html).
- docs.rs describes `TreeBuilder::Info` as only `size` plus `children`, which
  confirms that pdu's generic builder is shape-oriented and not a full metadata
  read model:
  [Info](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/tree_builder/info/struct.Info.html).
- docs.rs describes `RecordHardlinks` as a fallible trait for detecting and
  recording hardlinks. pdu `FsTreeBuilder` still discards this fallible result
  in its default path, so conflict preservation is adapter-owned:
  [RecordHardlinks](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/hardlink/record/trait.RecordHardlinks.html).
- Rust std documentation says `read_dir` order is platform and filesystem
  dependent, so pdu traversal order must not become product ordering or stable
  identity:
  [std::fs::read_dir](https://doc.rust-lang.org/std/fs/fn.read_dir.html).
- Rust std documentation says `symlink_metadata` queries metadata without
  following symlinks and may fail for permission or missing-path reasons. pdu
  uses this operation in `FsTreeBuilder`, so symlink behavior and missing-file
  races must be explicit product policy:
  [std::fs::symlink_metadata](https://doc.rust-lang.org/std/fs/fn.symlink_metadata.html).
- Rust std documentation says `Metadata::len` returns size in bytes, while Unix
  `MetadataExt::blocks` returns allocated blocks in 512-byte units and may be
  smaller than `st_size / 512` for sparse files. Clean Disk must model logical
  size, allocated size, block count, and reclaim estimate separately:
  [std::fs::Metadata](https://doc.rust-lang.org/std/fs/struct.Metadata.html),
  [std::os::unix::fs::MetadataExt](https://doc.rust-lang.org/std/os/unix/fs/trait.MetadataExt.html).
- Rust std documentation says `f32::is_finite` returns true only when a number
  is neither infinite nor NaN. Product ratio value objects must use this kind of
  finite check before mapping to pdu thresholds:
  [f32::is_finite](https://doc.rust-lang.org/std/primitive.f32.html#method.is_finite).
- The Rust Book documents integer overflow behavior: debug builds check and
  panic, release builds wrap, and relying on overflow wrapping is considered an
  error. Product size arithmetic must therefore be checked, saturating, or
  explicitly classified at boundaries:
  [Integer Overflow](https://doc.rust-lang.org/book/ch03-02-data-types.html#integer-overflow).
- Rust std documentation says `OsStr::to_str` succeeds only for valid Unicode,
  `to_string_lossy` may replace invalid sequences, and encoded bytes are
  platform-specific and not safe as portable stored/network identity. Product
  path authority therefore cannot be a plain UTF-8 string:
  [std::ffi::OsStr](https://doc.rust-lang.org/stable/std/ffi/os_str/struct.OsStr.html).
- docs.rs describes `OsStringDisplay` as displaying UTF-8 when possible and
  falling back to Debug formatting when not. This is display evidence only, not
  identity or protocol authority:
  [OsStringDisplay](https://docs.rs/parallel-disk-usage/0.23.0/parallel_disk_usage/os_string_display/struct.OsStringDisplay.html).
- pdu README describes the project as very fast and extensible through the
  library crate or JSON interface, but also states important limitations:
  ignorant of reflinks, does not follow symbolic links, and progress/hardlink
  modes add cost. These are backend capability facts, not product promises:
  [pdu README](https://github.com/KSXGitHub/parallel-disk-usage/blob/master/README.md).
- pdu README states that the project is both a binary crate and a library crate,
  and that `--json-output`/`--json-input` are CLI integration mechanisms. Clean
  Disk should use the library adapter path for production, not CLI JSON as the
  stable daemon protocol:
  [pdu README](https://github.com/KSXGitHub/parallel-disk-usage/blob/master/README.md).
- pdu README warns that JSON tree shape differs by the number of CLI arguments:
  zero/one target uses a real root name, while multiple targets use a virtual
  `(total)` root. Product protocol must own multi-root semantics:
  [pdu README](https://github.com/KSXGitHub/parallel-disk-usage/blob/master/README.md).
- docs.rs exposes pdu `JsonData`, `RuntimeError`, and `StatusBoard` as crate
  items. Source audit shows these are CLI/diagnostic/terminal concerns, not
  domain or daemon protocol contracts:
  [All Items](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/all.html).
- sysinfo documents `DiskKind` as `HDD`, `SSD`, or `Unknown`, returned by
  `Disk::kind`. pdu uses this only as a CLI heuristic for thread selection, not
  as a reliable storage topology model:
  [sysinfo DiskKind](https://docs.rs/sysinfo/latest/sysinfo/enum.DiskKind.html).
- terminal_size returns terminal width/height when available. pdu uses this for
  ASCII chart width, which is unrelated to protocol or Flutter layout:
  [terminal_size](https://docs.rs/terminal_size/).
- docs.rs describes `Reporter::report(Event)` and `ParallelReporter::destroy`;
  these are reporter mechanics, not product session lifecycle:
  [Reporter](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/trait.Reporter.html),
  [ParallelReporter](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/trait.ParallelReporter.html).
- docs.rs exposes `ProgressAndErrorReporter` as pdu's progress/error reporter;
  source audit shows it samples counters on a thread and uses relaxed atomics:
  [ProgressAndErrorReporter](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/progress_and_error_reporter/struct.ProgressAndErrorReporter.html).
- docs.rs marks `Event` as non-exhaustive with `ReceiveData`, `EncounterError`,
  and `DetectHardlink`, so adapter mapping must have a future fallback:
  [Event](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/event/enum.Event.html).
- docs.rs shows `ErrorReport` contains `operation`, borrowed `path`, and
  `io::Error`, and has `TEXT` that prints to stderr:
  [ErrorReport](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/error_report/struct.ErrorReport.html).
- docs.rs shows `ProgressReport` contains only `items`, `total`, `errors`,
  `linked`, and `shared`, and `TEXT` prints to stderr:
  [ProgressReport](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/reporter/progress_report/struct.ProgressReport.html).
- docs.rs shows pdu `Size` is a trait with associated display types; `Bytes`
  displays through `BytesFormat`, while `Blocks` displays as a `u64` block count:
  [Size](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/size/trait.Size.html).
- docs.rs exposes pdu CLI/runtime argument types such as `Depth`, `Fraction`,
  `Quantity`, `Threads`, and `RuntimeError`. Treat these as adapter inputs and
  CLI-host errors, not as product contracts:
  [Depth](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/args/depth/enum.Depth.html),
  [Fraction](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/args/fraction/struct.Fraction.html),
  [Quantity](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/args/quantity/enum.Quantity.html),
  [Threads](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/args/threads/enum.Threads.html),
  [RuntimeError](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/runtime_error/enum.RuntimeError.html).
- docs.rs shows `RecordHardlinks` has a fallible `record_hardlinks` method, and
  `Aware` is the Unix hardlink-aware implementation:
  [RecordHardlinks](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/hardlink/record/trait.RecordHardlinks.html),
  [HardlinkAware](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/hardlink/aware/struct.Aware.html).
- docs.rs exposes `HardlinkList` and shared-link summary types; source audit
  shows these are evidence/classification structures, not cleanup authority:
  [HardlinkList](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/hardlink/hardlink_list/struct.HardlinkList.html),
  [SharedLinkSummary](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/hardlink/hardlink_list/summary/struct.Summary.html).
- Rust std documentation says `panic::catch_unwind` is not a general try/catch
  replacement and does not catch all panics, but can be used when more graceful
  containment is needed around unwinding panics. Long-running daemon workers need
  explicit panic containment at adapter/runtime boundaries:
  [std::panic::catch_unwind](https://doc.rust-lang.org/std/panic/fn.catch_unwind.html).
- MDN documents `Number.MAX_SAFE_INTEGER` as `2^53 - 1` and notes that larger
  JavaScript numbers can lose integer-level precision. Flutter web protocol DTOs
  must therefore avoid lossy JSON numbers for exact `u64` facts:
  [Number.MAX_SAFE_INTEGER](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MAX_SAFE_INTEGER).
- `cargo info parallel-disk-usage` on 2026-05-20 reported latest version
  `0.23.0`, Apache-2.0, repository
  `https://github.com/KSXGitHub/parallel-disk-usage.git`, and default feature
  `cli = [clap/derive, clap_complete, clap-utilities, json]`.
- local `Cargo.toml.orig` audit shows pdu 0.23.0 uses Rust edition 2024 and
  does not declare an explicit `rust-version`; toolchain compatibility is our
  dependency governance check, not something pdu guarantees through metadata.
- Cargo documentation says default dependency features are enabled unless
  `default-features = false` is specified, and warns that feature unification
  can still enable defaults through another dependency path. This makes pdu
  feature graph inspection a release gate, not a nice-to-have:
  [Cargo features](https://doc.rust-lang.org/cargo/reference/features.html).
- Cargo documentation says `rust-version` records the supported Rust toolchain
  and gives clearer diagnostics when the selected compiler is too old. Since pdu
  does not declare one, Clean Disk must prove pdu compatibility with the pinned
  release toolchain:
  [Cargo rust-version](https://doc.rust-lang.org/cargo/reference/rust-version.html).

Architecture facts:

- Alistair Cockburn's original Hexagonal Architecture article says the
  application should work without UI or database, and technology-specific
  adapters convert outside events into application calls. This directly supports
  keeping pdu behind an adapter and testing `fs_usage_engine` with fake
  backends:
  [Hexagonal architecture](https://alistair.cockburn.us/hexagonal-architecture).
- Cockburn's ports-and-adapters material frames the app core as surrounded by
  different ports/adapters, including tests and external systems:
  [Hexagonal Budapest 2023](https://alistaircockburn.com/Hexagonal%20Budapest%2023-05-18.pdf).
- Microsoft DDD guidance emphasizes bounded contexts, entities/value
  objects/aggregates, domain isolation from infrastructure, and translation from
  domain entities to UI/API models:
  [Designing a DDD-oriented microservice](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/ddd-oriented-microservice).
- Microsoft Azure Architecture guidance describes CQRS as separating write
  operations/commands from read operations/queries, with read models designed
  for retrieving data. Clean Disk should borrow the command/query separation
  without forcing separate databases in MVP:
  [CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs).
- Rust API Guidelines recommend future-proofing with private fields/newtypes and
  strong input validation through types:
  [Future proofing](https://rust-lang.github.io/api-guidelines/future-proofing.html),
  [Dependability](https://rust-lang.github.io/api-guidelines/dependability.html).
- The Rust Reference documents `#[non_exhaustive]` as a way to preserve future
  compatibility by allowing more fields or variants later:
  [non_exhaustive](https://doc.rust-lang.org/reference/attributes/type_system.html).
- Rust error design guidance recommends converting implementation errors to API
  errors at boundaries and treating errors as part of public API stability:
  [Error type design](https://nrc.github.io/error-docs/error-design/error-type-design.html).
- Rayon documents that `build_global` initializes the global thread pool once,
  and that after it starts the configuration cannot be changed:
  [ThreadPoolBuilder::build_global](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html#method.build_global).
- Rayon documents that `ThreadPool::install` runs a closure in a chosen local
  pool and that Rayon operations called inside use that pool. This makes local
  pdu execution-lane control a concrete spike target:
  [ThreadPool::install](https://docs.rs/rayon/latest/rayon/struct.ThreadPool.html#method.install).
- Rust `thread::Builder` can configure spawned thread stack size, which matters
  for any recursive scan/conversion risk that cannot be removed in the first
  adapter:
  [thread::Builder::stack_size](https://doc.rust-lang.org/std/thread/struct.Builder.html#method.stack_size).
- Rust `panic::catch_unwind` catches only unwinding panics, not aborting panics,
  so panic containment must not be treated as a complete shield for every deep
  recursion or process-abort failure mode:
  [panic::catch_unwind](https://doc.rust-lang.org/std/panic/fn.catch_unwind.html).

Local source audited:

```text
~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/parallel-disk-usage-0.23.0
```

Especially:

```text
src/tree_builder.rs
src/tree_builder/info.rs
src/app/sub.rs
src/app/overlapping_arguments.rs
src/args/quantity.rs
src/fs_tree_builder.rs
src/data_tree.rs
src/data_tree/constructors.rs
src/data_tree/getters.rs
src/data_tree/hardlink.rs
src/data_tree/retain.rs
src/data_tree/sort.rs
src/data_tree/reflection/convert.rs
src/data_tree/reflection/par_methods.rs
src/reporter.rs
src/reporter/event.rs
src/reporter/progress_and_error_reporter.rs
src/reporter/progress_and_error_reporter/progress_report_state.rs
src/size.rs
src/args/depth.rs
Cargo.toml
README.md
```

## Clean Architecture Interpretation

The dependency rule for this project:

```text
domain -> depends on nothing product-external
application -> depends on domain and ports
infrastructure/adapters -> depend inward and implement ports
host/runtime -> wires concrete adapters and transports
Flutter -> depends on app-facing contracts, not Rust internals
```

Important translation:

- `runtime` is not a DDD layer. It is a composition/execution concern in the
  outer ring.
- `clean-disk-server` is not the domain. It is the host that chooses concrete
  adapters and exposes HTTP/WebSocket.
- `fs_usage_pdu` is not application logic. It is an infrastructure adapter.
- pdu `Reporter` is not our event bus. It is adapter evidence capture.
- pdu `DataTree` is not our aggregate. It is raw backend output.

## Recommended Rust Workspace Shape

Keep the crates separated by stability and dependency direction:

```text
rust/
  Cargo.toml
  crates/
    fs_usage_core/
      src/
        lib.rs
        domain/
          identity/
            node_id.rs
            node_ref.rs
            snapshot_id.rs
            scan_session_id.rs
          target/
            scan_target.rs
            target_scope.rs
            boundary_policy.rs
          size/
            size_fact.rs
            size_unit_semantics.rs
            measurement_profile.rs
            reclaim_estimate.rs
          path/
            display_path.rs
            path_authority.rs
            path_privacy_class.rs
          issue/
            scan_issue.rs
            issue_reason.rs
            issue_severity.rs
          quality/
            scan_quality.rs
            evidence_confidence.rs
          policy/
            traversal_policy.rs
            link_policy.rs
            display_policy.rs
          cleanup/
            delete_candidate.rs
            delete_plan.rs
            delete_receipt.rs
        result/
          app_error.rs
          app_result.rs

    fs_usage_engine/
      src/
        lib.rs
        application/
          ports/
            scanner_backend.rs
            platform_metadata_reader.rs
            trash_adapter.rs
            clock.rs
            event_sink.rs
          use_cases/
            create_scan_session.rs
            start_scan.rs
            cancel_scan.rs
            get_children_page.rs
            get_node_details.rs
            search_nodes.rs
            build_delete_plan.rs
          session/
            scan_session.rs
            scan_state.rs
            session_registry.rs
          read_model/
            node_arena.rs
            node_record.rs
            indexes.rs
            query_cursor.rs
            page.rs
          events/
            scan_event.rs
            event_sequence.rs
            progress_snapshot.rs
          mapping/
            backend_output_mapper.rs
          testing/
            fake_scanner_backend.rs

    fs_usage_pdu/
      src/
        lib.rs
        adapter/
          pdu_scanner_backend.rs
          pdu_scan_runner.rs
          pdu_execution_lane.rs
          pdu_reporter.rs
        mapper/
          pdu_tree_converter.rs
          pdu_size_mapper.rs
          pdu_issue_mapper.rs
          pdu_hardlink_mapper.rs
        evidence/
          pdu_raw_scan_result.rs
          pdu_raw_event.rs
          pdu_backend_capabilities.rs
        diagnostics/
          pdu_json_fixture.rs
          pdu_cli_compat.rs
        guards/
          feature_guard.rs
          import_guard.rs

    fs_usage_platform/
      src/
        lib.rs
        macos/
        windows/
        linux/
        metadata/
        identity/
        permissions/
        trash/

    clean_disk_protocol/
      src/
        lib.rs
        dto/
          scan.rs
          node.rs
          size.rs
          issue.rs
          capability.rs
          cleanup.rs
        mapper/
          engine_to_dto.rs
          dto_to_command.rs
        schema/

  apps/
    clean_disk_server/
      src/
        main.rs
        bootstrap/
          config.rs
          dependency_graph.rs
          graceful_shutdown.rs
        transport/
          http_routes.rs
          websocket_events.rs
          auth.rs
          cors.rs
        observability/
          logging.rs
          metrics.rs
          support_redaction.rs
```

Top 3 crate-organization options:

1. `fs_usage_core` + `fs_usage_engine` + adapter crates + server host -
   🎯 10 🛡️ 10 🧠 7, roughly 3000-7000 LOC for MVP scan.
   Accepted. Clear Clean Architecture boundary, reusable library, pdu
   replaceability, and remote/headless readiness.
2. One `clean_disk_rust` crate with modules - 🎯 6 🛡️ 6 🧠 4, roughly
   1800-4000 LOC.
   Fast initially, but import boundaries are easier to break and reusable
   library extraction becomes more expensive.
3. Many tiny crates per subdomain from day one - 🎯 5 🛡️ 7 🧠 9, roughly
   5000-10000 LOC.
   Architecturally pure, but heavy for MVP and likely to slow iteration.

## DDD Model Boundaries

Use simple DDD. Do not turn every struct into an aggregate.

Recommended modeling:

```text
Bounded context:
  filesystem usage analysis and cleanup planning.

Entities:
  ScanSession
  ScanSnapshot
  NodeRecord
  DeletePlan
  DeleteOperationReceipt

Value objects:
  ScanSessionId
  SnapshotId
  NodeId
  NodeRef
  SizeFact
  MeasurementProfile
  ScanTarget
  DisplayPath
  PathAuthority
  ScanIssue
  ScanQuality
  EvidenceConfidence

Aggregates:
  ScanSession controls lifecycle and current snapshot reference.
  DeletePlan controls destructive intent validation before execution.

Read models:
  NodeArena
  QueryIndexes
  ChildrenPage
  SearchPage
  TopItemsPage
  DetailsProjection
```

Important DDD decision:

```text
The full file tree is not one giant aggregate.
It is a read model built from scan evidence.
```

Why:

- a 500 GB disk can produce hundreds of thousands or millions of nodes;
- aggregate invariants over the whole tree would be too expensive;
- UI queries need pagination and indexes;
- delete authority needs fresh revalidation, not old tree ownership;
- snapshots/history/compare need immutable read-model semantics.

### Aggregate And Consistency Boundaries

DDD should protect invariants, not make every data structure "rich". For this
project the consistency boundaries are small and explicit.

Aggregate boundaries:

```text
ScanSession
  owns lifecycle, current operation epoch, current snapshot pointer, cancel
  state, and publication rules.

ScanSnapshot
  immutable evidence set after publication, referenced by id.

DeletePlan
  owns destructive intent, validation evidence, selected node refs, policy, and
  confirmation requirements.

DeleteOperationReceipt
  immutable outcome journal after an operation starts.
```

Not aggregates:

```text
DataTree
NodeArena
QueryIndexes
ChildrenPage
SearchResult
TopItemsPage
PduRawScanResult
Protocol DTOs
Flutter view models
```

Rules:

- `ScanSession` references snapshots by `SnapshotId`; it does not own a mutable
  million-node object graph;
- `ScanSnapshot` is immutable scan evidence, not current filesystem authority;
- `NodeArena` and indexes are read models optimized for queries, not aggregate
  roots;
- `DeletePlan` references snapshot/node ids but must revalidate current
  filesystem identity before becoming executable;
- repositories/storage ports store snapshots, journals, and cached read models
  by id; they do not expose pdu trees or Flutter DTOs;
- cross-aggregate workflows live in application use cases, not domain entities.

Top 3 DDD boundary strategies:

1. Small aggregates plus large immutable read models - 🎯 10 🛡️ 10 🧠 6,
   roughly 900-2200 LOC.
   Accepted. This matches DDD consistency boundaries and keeps million-node
   data out of aggregate mutation logic.
2. One giant `ScanSnapshot` aggregate containing every node as mutable children
   - 🎯 3 🛡️ 3 🧠 4, roughly 800-2000 LOC.
   Rejected. It would make pagination, memory, history, and cleanup validation
   painful.
3. No aggregates, only flat DTOs and services - 🎯 5 🛡️ 4 🧠 3, roughly
   400-1200 LOC.
   Too weak. It would make session lifecycle, publish gates, and destructive
   intent easy to bypass.

## pdu Source Facts That Shape Contracts

### Actual pdu Scan Pipeline

Source-level execution flow in pdu 0.23.0:

```text
FsTreeBuilder
  root
  size_getter
  hardlinks_recorder
  reporter
  device_boundary
  max_depth
    -> optional root symlink_metadata for DeviceBoundary::Stay
    -> TreeBuilder
         get_info(path)
         join_path(parent_path, child_name)
         max_depth
    -> DataTree
```

Important behavior:

- for `DeviceBoundary::Stay`, if root `symlink_metadata` fails, pdu reports an
  `EncounterError` event and returns a zero-size file-shaped `DataTree`;
- every path is inspected with `symlink_metadata`, not by following symlinks as
  directories;
- after metadata succeeds, pdu reports `ReceiveData(size)`;
- pdu calls `record_hardlinks(...).ok()`, so the default builder path discards
  hardlink recorder failures;
- children are listed only when the item is a directory and, when requested,
  remains on the same device;
- `read_dir` failure reports `ReadDirectory` and keeps the node with no stored
  children;
- individual directory entry errors report `AccessEntry` and skip that entry;
- child names stored in `DataTree` are only file names, while child paths are
  reconstructed internally by joining parent path and child name;
- `TreeBuilder` maps children through Rayon, so child traversal order and
  resource pressure are backend details;
- when `max_depth` is exhausted, children are still scanned and summed into the
  parent size, but not stored in the returned children vector.

Adapter consequence:

```text
PduRawScanResult = DataTree + reporter evidence + adapter diagnostics.
DataTree alone is never enough to determine scan quality or cleanup authority.
```

Top 3 pipeline integration choices:

1. Treat pdu as final-tree evidence plus side-channel evidence - 🎯 10 🛡️ 9
   🧠 7, roughly 1200-2500 LOC.
   Accepted. This matches how pdu actually works and keeps partial/error states
   explicit.
2. Treat pdu scan as `Result<DataTree, Error>` - 🎯 3 🛡️ 3 🧠 2, roughly
   300-800 LOC.
   Rejected. pdu often reports issues while still returning a `DataTree`, so
   this would erase scan quality.
3. Modify/fork pdu to return our exact pipeline events - 🎯 5 🛡️ 6 🧠 9,
   roughly 3000-9000 LOC plus fork maintenance.
   Deferred until adapter tests prove an actual blocker.

### pdu Module Map And Product Contract Consequences

This map is the practical anti-corruption guide for the first Rust code.

| pdu module/type | What it really does | Product contract consequence |
| --- | --- | --- |
| `fs_tree_builder::FsTreeBuilder` | Filesystem scanner convenience wrapper around `TreeBuilder` | Infrastructure adapter only; never a domain/service type |
| `tree_builder::TreeBuilder` | Parallel shape builder from `get_info(path)` and `join_path` | Useful production entry point if the adapter needs side stores |
| `tree_builder::Info` | `size` plus `children` only | Missing path, kind, self-size, identity, issues, permissions |
| `data_tree::DataTree` | Recursive aggregate projection | Not query store, not snapshot authority, not cleanup authority |
| `reporter::Event` | Synchronous backend evidence callback | Must be copied into owned product evidence immediately |
| `hardlink::RecordHardlinks` | Fallible hardlink recorder | Default `FsTreeBuilder` discards recorder errors, so conflicts are ours |
| `device::DeviceBoundary` | Unix-capable same-device input | Not complete mount/reparse/cloud/network policy |
| `args::*`, `app::Sub`, `visualizer::*` | CLI host and terminal policy | Forbidden in production integration except diagnostics/tests |

Contract:

```text
pdu modules are mapped by responsibility, not mirrored by folder name.
The adapter may depend on pdu's shape, but domain/application depend only on
product ports and value objects.
```

Top 3 source mapping strategies:

1. Adapter-owned source map with import tests - 🎯 10 🛡️ 10 🧠 5, roughly
   250-700 LOC.
   Accepted. It gives future contributors a mechanical rule for where pdu may
   appear.
2. Mirror pdu modules inside `fs_usage_engine` - 🎯 4 🛡️ 4 🧠 4, roughly
   400-1200 LOC.
   Rejected. It spreads upstream concepts into the application layer.
3. Hide all pdu facts behind one giant `scan()` function - 🎯 5 🛡️ 5 🧠 3,
   roughly 200-600 LOC.
   Rejected. It hides capability and evidence differences that the UI and delete
   flow must know.

### FsTreeBuilder Error Semantics Are Side-Channel Only

Source fact:

- `FsTreeBuilder` implements conversion into `DataTree`, not
  `TryFrom<FsTreeBuilder>`.
- root metadata failure under `DeviceBoundary::Stay` returns a zero-size
  file-shaped `DataTree`.
- per-node metadata failures return `Info { size: default, children: [] }`.
- `read_dir` failure preserves the directory's own size and returns no children.
- `DirEntry` access errors are reported against the parent directory path and
  the entry is skipped.
- different-device directories under `DeviceBoundary::Stay` are counted as the
  boundary node's own size but are not descended into.
- pdu does not emit a separate "boundary skipped" issue for same-device policy.

Contract:

```text
The pdu adapter returns BackendScanOutput, never Result<DataTree> as the whole
truth.
```

Required product facts:

- `completion_state`: complete, partial, degraded, cancelled, failed;
- `issues`: metadata failure, read directory failure, access entry failure,
  boundary not descended, unsupported policy;
- `scan_quality`: what was scanned, skipped, guessed, or unproved;
- `capabilities`: whether boundary, hardlink, node kind, identity, and self-size
  are authoritative for this scan.

Top 3 error modeling strategies:

1. `BackendScanOutput { tree, issues, quality, capabilities }` - 🎯 10 🛡️ 10
   🧠 6, roughly 700-1600 LOC.
   Accepted. It matches pdu behavior and keeps cleanup honest.
2. `Result<DataTree, ScanError>` only - 🎯 3 🛡️ 3 🧠 2, roughly 150-400 LOC.
   Rejected. pdu can return a tree with many errors.
3. Put errors only in logs/support bundle - 🎯 3 🛡️ 4 🧠 2, roughly
   100-300 LOC.
   Rejected. UI and delete policy need structured degraded-state facts.

### pdu App Is CLI Composition, Not Our Integration API

Source fact:

- `app::App` parses `Args`, chooses terminal visualization options, handles
  `--json-input` and `--json-output`, sets pdu CLI errors, builds or attempts to
  build a global Rayon thread pool, applies HDD thread heuristics, chooses
  progress or error-only reporter, chooses hardlink handler, runs `Sub`, sorts
  and culls the tree, writes terminal output, and serializes pdu JSON.
- `Sub::run` scans multiple roots, creates a fake root for multiple arguments,
  destroys the progress reporter, optionally culls by `min_ratio`, optionally
  sorts by size, runs hardlink deduplication, and then either serializes JSON or
  prints a visualizer.
- `Args` is `#[non_exhaustive]`, which is a good upstream API warning: its CLI
  field set may grow.

Contract:

```text
Do not call pdu App/Sub from production Clean Disk integration.
The adapter should call the lower-level scanner pipeline directly.
```

Why:

- CLI output, JSON format, UI visualization, and daemon protocol are different
  conversations;
- `App/Sub` makes resource policy, sorting, culling, dedupe, JSON, and terminal
  decisions before our architecture can validate them;
- using `App/Sub` would make the pdu CLI composition root compete with
  `clean-disk-server`, which should be our only host/composition root.

Top 3 pdu entry points:

1. Use pdu `TreeBuilder` with adapter-owned `get_info` and side stores -
   🎯 8 🛡️ 9 🧠 8, roughly 1500-3200 LOC.
   Best production path. It keeps pdu's parallel tree builder, but lets the
   adapter preserve node kind, target policy, cancellation checks, issue
   evidence, and metadata sidecars without a second full stat pass.
2. Use `FsTreeBuilder` directly inside `PduScannerBackend` - 🎯 8 🛡️ 7 🧠 5,
   roughly 700-1700 LOC.
   Good scan-only MVP path. It is lower effort, but loses node kind and forces
   lazy metadata or feature gates for top files and file/folder counts.
3. Use pdu `Sub` or wrap `pdu` CLI - 🎯 3 🛡️ 3 🧠 4, roughly 400-1400 LOC.
   Rejected for production. These paths bundle CLI decisions, terminal/JSON
   behavior, process identity problems, weak structured events, cancellation
   gaps, and unstable protocol semantics.

Adapter contract after deeper source audit:

```text
PduScannerBackend
  -> PduScanRunner
  -> PduEntryProbe
  -> PduReporterRecorder
  -> PduTreeConverter
  -> PduCapabilityMapper
  -> BackendScanOutput
```

Rules:

- `PduScanRunner` decides `FsTreeBuilder` versus custom `TreeBuilder` for one
  scan, but the rest of the engine sees only `BackendScanOutput`;
- `PduEntryProbe` owns `symlink_metadata`, size getter selection, node-kind
  evidence, self-size side store, device boundary evidence, and path evidence;
- `PduReporterRecorder` copies borrowed pdu event data immediately and maps it
  to product issue/evidence records;
- `PduTreeConverter` converts pdu `DataTree` shape to our arena and attaches
  side-store evidence;
- `PduCapabilityMapper` publishes what this concrete scan can prove, including
  non-UTF-8, hardlink, link-policy, boundary, cancellation, and self-size
  limitations;
- no class in this chain owns HTTP, WebSocket, Flutter DTOs, cleanup
  confirmation, or durable cache schema.

### FsTreeBuilder Is Infallible From The Outside

Source fact:

- `FsTreeBuilder` converts into `DataTree` via `From`/`Into`.
- It reports scan errors through `Reporter::report(Event::EncounterError)`.
- If root `symlink_metadata` fails under `DeviceBoundary::Stay`, it returns a
  zero-size file-shaped `DataTree`.

Contract:

```text
PduScanRunner cannot expose only Result<DataTree>.
It must return tree plus side-channel issues, quality, and adapter evidence.
```

### TreeBuilder Is Parallel And Shape-Oriented

Source fact:

- `TreeBuilder` calls `get_info(&path)`, then maps children through Rayon
  `into_par_iter`.
- `max_depth` uses `saturating_sub(1)`.
- When max depth is exhausted, children are not stored, but their sizes are
  still summed into the parent.
- pdu `FsTreeBuilder` obtains child names from `read_dir`, whose order is
  platform and filesystem dependent.
- pdu CLI later sorts by size using `sort_unstable_by`, which does not preserve
  stable tie ordering.

Contract:

```text
Stored child absence is not proof that the directory has no descendants.
Hidden-descendant evidence must be explicit in our read model.
```

### TreeBuilder Materializes Child Lists

Source fact:

- `TreeBuilder::Info` contains `children: Vec<Name>`, not a streaming iterator.
- pdu `FsTreeBuilder` collects directory entries into a `Vec` before recursive
  child construction.
- pdu `TreeBuilder` consumes that list with Rayon `into_par_iter`.
- pdu `DataTree::dir` stores a `Vec<Self>` of all retained children.
- when `max_depth` is exhausted, pdu still recursively computes child sizes, but
  stores `Vec::new()` for that node.

Contract:

```text
pdu is final-tree aggregation, not streaming node delivery.
Read-model ingestion is product-owned and budgeted.
```

Implications:

- do not promise one UI event per filesystem node;
- do not design Flutter as the owner of full tree construction;
- wide directories can allocate both a child-name vector and a child-tree
  vector before our read model sees the data;
- conversion should ingest pdu `DataTree` into a compact arena, then drop the
  pdu tree when memory policy requires it;
- memory budget must account for pdu tree, side stores, arena records, string
  storage, issue storage, indexes, and pending protocol pages;
- streaming progress is allowed, but streaming authoritative node records from
  pdu is not an MVP capability unless we fork or replace traversal.

Top 3 node-delivery strategies:

1. pdu final tree to compact arena, then paginated queries - 🎯 9 🛡️ 9 🧠 7,
   roughly 900-2200 LOC.
   Accepted. It matches pdu's real API and keeps the UI responsive by querying
   pages instead of receiving the whole tree.
2. Stream every pdu node to Flutter during traversal - 🎯 3 🛡️ 3 🧠 7,
   roughly 1200-3000 LOC.
   Rejected. pdu does not expose that shape, and the UI would become a memory
   and ordering bottleneck.
3. Fork pdu to expose a streaming traversal backend - 🎯 5 🛡️ 8 🧠 9,
   roughly 3500-9000 LOC plus fork maintenance.
   Deferred. Valuable only if final-tree ingestion cannot meet memory and
   responsiveness budgets after real benchmarks.

### Custom TreeBuilder Is The Main Extension Point

Source fact:

- `TreeBuilder` lets the caller provide `get_info(path)` and
  `join_path(parent, child_name)`.
- `Info` carries only `size` and child names, but `get_info` is where metadata,
  boundary, hardlink, issue, and cancellation side effects can be captured.
- `FsTreeBuilder` is itself just a concrete `TreeBuilder` wrapper.
- the returned `DataTree` still loses side-store facts, so side stores must be
  keyed by adapter-owned path/scan evidence during traversal.
- pdu `TreeBuilder` is generic over `Name`, so the adapter can choose an
  internal name type instead of using plain `OsStringDisplay`.

Contract:

```text
Production adapter may use pdu TreeBuilder, but owns the filesystem probe and
side stores around it.
```

This is the key reason we do not need to fork pdu immediately:

- keep pdu's parallel recursive size aggregation;
- replace the thin `FsTreeBuilder` probe with our `PduEntryProbe`;
- capture node kind, self size, native path evidence, skipped reason, and
  policy decisions before `DataTree` compresses them away;
- check cancellation/resource budget at the probe boundary;
- publish capability gaps when a fact cannot be captured.

Top 3 extension strategies:

1. Custom `TreeBuilder` probe with side stores - 🎯 8 🛡️ 9 🧠 8, roughly
   1500-3200 LOC.
   Accepted target for production-quality scanner adapter.
2. `FsTreeBuilder` first, lazy metadata after conversion - 🎯 8 🛡️ 7 🧠 5,
   roughly 700-1700 LOC.
   Acceptable scan-only MVP if we clearly mark missing node-kind/self-size
   capabilities.
3. Fork pdu to change `Info` and `DataTree` - 🎯 5 🛡️ 7 🧠 9, roughly
   3500-9000 LOC.
   Deferred. Useful only if side-store integration proves too fragile.

### Side-Store Correlation Is The Hardest Adapter Detail

Source fact:

- pdu `DataTree` stores only `name`, aggregate `size`, and `children`.
- pdu `FsTreeBuilder` uses `OsStringDisplay` as node names, so after conversion
  the adapter has no stable node id inside `DataTree`.
- pdu custom `TreeBuilder` allows a custom `Name` type, and `join_path` receives
  that `Name`.
- the `get_info(path)` callback sees the full traversal path before pdu
  compresses metadata into `Info { size, children }`.

Contract:

```text
Correlation between pdu DataTree nodes and product evidence is adapter-owned.
It must not depend on DataTree Vec index, pdu child order, or display path.
```

Recommended rich-scan shape:

```text
PduTraversalKey
  adapter-local opaque key, never public protocol.

PduTreeName
  traversal_key
  native_segment
  display_segment_hint

PduSideStore
  traversal_key -> path evidence
  traversal_key -> metadata evidence
  traversal_key -> node-kind evidence
  traversal_key -> self-size evidence
  traversal_key -> issue refs
```

Why this matters:

- path-keyed side stores can break when files are renamed, replaced, or when
  multiple requested roots have the same display name;
- Vec index identity breaks because traversal order is not stable and sort/cull
  projection can mutate the tree;
- display strings are lossy for non-UTF-8 paths and must not be authority;
- `PduTreeName` lets `DataTree` carry a private adapter key without exposing pdu
  types outside `fs_usage_pdu`.

Top 3 side-store correlation strategies:

1. Custom `PduTreeName` with `PduTraversalKey` - 🎯 9 🛡️ 9 🧠 7, roughly
   500-1400 LOC.
   Accepted target for rich scan. It is the cleanest way to attach side-store
   facts to final `DataTree` nodes without trusting order or display paths.
2. Side stores keyed by reconstructed absolute/native path - 🎯 6 🛡️ 6 🧠 4,
   roughly 300-900 LOC.
   Acceptable for throwaway spike or scan-only MVP, but weaker under races,
   duplicate roots, path normalization, and non-UTF-8 display.
3. Derive node identity from traversal order or child index - 🎯 2 🛡️ 2 🧠 2,
   roughly 100-300 LOC.
   Rejected. It will break pagination, compare, tests, and stale-delete
   validation.

### TreeBuilder Closures Force Shared, Thread-Safe State

Source fact:

- `TreeBuilder` requires `GetInfo: Fn(&Path) -> Info<Name, Size> + Copy + Send
  + Sync`.
- `TreeBuilder` requires `JoinPath: Fn(&Path, &Name) -> Path + Copy + Send +
  Sync`.
- pdu child construction uses Rayon `into_par_iter`, so callback side effects
  can run concurrently and out of order.
- `get_info` is not async and not `FnMut`, so mutable probe state cannot be a
  normal borrowed mutable struct.

Contract:

```text
PduEntryProbe is an immutable handle over explicit concurrent state.
All side effects are bounded, thread-safe, and classified as evidence.
```

Implementation implication:

- use an adapter-owned `Arc<PduProbeState>` or equivalent inside copyable
  closures;
- store evidence in sharded maps, bounded channels, or lock-minimized stores;
- keep path/metadata evidence owned, because pdu reporter events can borrow
  data only for the duration of the callback;
- never call slow UI/protocol/logging code inside pdu `get_info` or reporter
  callback;
- emit coalesced product events from a separate bridge, not directly from Rayon
  callbacks.

Top 3 probe-state strategies:

1. `Arc<PduProbeState>` plus sharded stores and bounded event bridge - 🎯 9
   🛡️ 9 🧠 8, roughly 900-2200 LOC.
   Accepted for production-quality rich scan.
2. One global `Mutex<HashMap<...>>` side store - 🎯 6 🛡️ 6 🧠 3, roughly
   250-700 LOC.
   Useful for spike tests, but likely to bottleneck on wide directories and
   many reporter events.
3. Thread-local side stores merged after traversal - 🎯 6 🛡️ 7 🧠 8, roughly
   900-2400 LOC.
   Possible later, but harder to correlate and merge correctly with pdu's
   recursive result shape.

### Custom Name Type And pdu Hardlink Dedupe Can Conflict

Source fact:

- pdu `TreeBuilder` can use a custom `Name`.
- pdu `DataTree::par_deduplicate_hardlinks` is implemented only when
  `Name: AsRef<OsStr>`.
- pdu hardlink dedupe strips recorded link paths by the current node name and
  recursively passes suffixes to children.
- this assumes pdu's name/path convention, where the root name is path-like and
  children are path segments after suffix stripping.

Contract:

```text
PduTraversalKey is not path text.
Hardlink dedupe path-prefix semantics must not depend on traversal-key display.
```

Implications:

- if `PduTreeName` is used, it may implement `AsRef<OsStr>` only for the native
  path segment needed by pdu mechanics, never for the traversal key;
- pdu built-in dedupe should remain a projection adapter, not the primary
  measured snapshot;
- rich scan can initially capture hardlink evidence and skip pdu dedupe
  projection until the custom name/path-prefix behavior is tested;
- multi-root, fake-root, overlapping target, non-UTF-8, and relative path cases
  need explicit hardlink projection tests before exposing deduped views.

Top 3 custom-name hardlink strategies:

1. Capture hardlink evidence, delay pdu dedupe projection for rich scan - 🎯 8
   🛡️ 9 🧠 4, roughly 300-900 LOC.
   Accepted MVP-safe choice. It avoids coupling traversal identity to pdu
   prefix semantics.
2. Implement `PduTreeName: AsRef<OsStr>` and keep pdu dedupe projection behind
   tests - 🎯 7 🛡️ 7 🧠 7, roughly 700-1800 LOC.
   Good later if deduped display becomes important early.
3. Put traversal key into the pdu name string and let dedupe operate on it - 🎯
   2 🛡️ 2 🧠 2, roughly 100-300 LOC.
   Rejected. It corrupts path-prefix behavior and display/path authority.

### Traversal Order Is Not Identity Or Query Order

Source fact:

- `std::fs::read_dir` does not guarantee stable ordering.
- pdu `TreeBuilder` parallelizes child construction with Rayon.
- pdu `DataTree::par_sort_by` uses `sort_unstable_by`.
- pdu CLI sorts by descending size only, with no product tie-breakers.

Contract:

```text
NodeId is snapshot-local opaque identity.
Query order is product-owned and explicitly sorted by read-model indexes.
```

Implications:

- do not allocate cross-snapshot identity from traversal index;
- do not use pdu child order as UI order unless query explicitly requests
  backend traversal order and marks it unstable;
- sort/filter/page APIs need stable tie-breakers such as normalized display
  name, node kind rank, size fact, and snapshot-local node id;
- history/compare must use path/identity evidence, not arena index equality;
- tests must not expect exact pdu child order unless the fixture sorts first.

Top 3 ordering strategies:

1. Product read-model sorting with explicit tie-breakers - 🎯 10 🛡️ 10 🧠 6,
   roughly 500-1400 LOC.
   Accepted. It makes UI, tests, pagination, and compare deterministic.
2. Keep pdu order and only sort in Flutter - 🎯 4 🛡️ 4 🧠 3, roughly
   200-700 LOC.
   Rejected. Flutter must not own full-tree truth or sort million-node trees.
3. Stable sort pdu `DataTree` in adapter for every query - 🎯 5 🛡️ 6 🧠 5,
   roughly 400-1200 LOC.
   Rejected as default. It mutates scan shape and does not scale to arbitrary
   query/filter/sort combinations.

### DataTree Is Aggregate Size, Name, Children

Source fact:

- `DataTree` has private `name`, `size`, and `Vec<Self> children`.
- `DataTree::size()` returns total disk usage.
- `DataTree::children()` returns a full `&Vec<Self>`.
- `DataTree::dir(name, inode_size, children)` stores `inode_size + sum(children)`
  as the node size.
- `DataTree::file(name, size)` stores the same shape as a leaf node with empty
  children.
- after `DataTree::dir`, the original directory self size is not separately
  accessible from the `DataTree`.
- Empty directories, files, max-depth leaves, unreadable directories, and
  same-device-boundary leaves can all become "node with empty children" after
  conversion.
- JSON requires `Reflection`, not direct `DataTree` serde.

Contract:

```text
DataTree traversal is a conversion input only.
Pagination, stable ids, full paths, item counts, and details are engine-owned.
```

### DataTree Is Recursive Projection, Not Query Store

Source fact:

- `DataTree<Name, Size>` stores `name`, `size`, and `Vec<Self> children`.
- `children()` returns a full `&Vec<Self>`, not a cursor, page, or query handle.
- conversion to `Reflection` recursively consumes and maps children.
- `Reflection` is another recursive `Vec<Self>` tree.
- `par_retain`, `par_sort_by`, and hardlink dedupe mutate the recursive tree in
  place.

Contract:

```text
Product read model is arena/index based.
pdu recursive tree is one conversion input, not the query store exposed to
application use cases.
```

Implications:

- `NodeArena` should be compact, snapshot-local, and indexed by `NodeId`;
- parent/child edges should be represented explicitly enough for pagination,
  details, search, top lists, and selection validation;
- protocol pages must use `NodeRef` plus cursor/query state, not `Vec` index
  authority;
- conversion should be an ingestion step: `DataTree -> NodeArenaWriter`, then
  pdu tree can be dropped if memory budget requires it;
- stack/recursion behavior must be tested with deep synthetic trees before
  trusting arbitrary user disks;
- read-model indexes must be owned by `fs_usage_engine`, not by pdu sort/retain
  mutations.

Top 3 read-model storage strategies:

1. Compact arena plus separate query indexes - 🎯 9 🛡️ 10 🧠 8, roughly
   1200-3000 LOC.
   Accepted. This supports pagination, stable snapshot ids, search, top lists,
   stale detection, and future backend replacement.
2. Keep pdu `DataTree` as in-memory authority and walk it for every query -
   🎯 5 🛡️ 5 🧠 4, roughly 400-1200 LOC.
   Rejected as product architecture. It is easy at first, but weak for paging,
   sorting, search, memory control, and metadata side stores.
3. Send the recursive tree to Flutter and let UI query it - 🎯 2 🛡️ 2 🧠 3,
   roughly 300-900 LOC.
   Rejected. It violates the "Rust owns full tree" rule and will not scale.

### Self Size And Total Size Must Be Separate Facts

Source fact:

- pdu stores only total size on `DataTree` nodes.
- pdu `DataTree::dir` computes `inode_size + sum(children)`.
- pdu `TreeBuilder` can still see the node's own size in `Info::size` before it
  is folded into total size.

Contract:

```text
SizeFact must distinguish self size, descendant total, displayed total, and
future reclaim estimate.
```

Implications:

- if the UI needs "folder itself" versus "folder contents", capture self size
  in the adapter side-store before `DataTree` construction;
- if only total size is captured from `DataTree`, `self_size` must be marked
  unknown or lazily enriched;
- directory self size can matter on some filesystems and should not be silently
  invented as zero;
- reclaim estimate must never be derived from total size alone.

Top 3 size-shape strategies:

1. Capture self size in custom `TreeBuilder` side-store - 🎯 8 🛡️ 9 🧠 7,
   roughly 600-1500 LOC.
   Accepted when using the production `TreeBuilder` path.
2. Store only total size for scan-only MVP - 🎯 7 🛡️ 7 🧠 3, roughly
   200-600 LOC.
   Acceptable only if `self_size` and reclaim fields are explicit unknowns.
3. Recompute self size from total minus child totals - 🎯 5 🛡️ 5 🧠 4,
   roughly 300-900 LOC.
   Risky around hidden descendants, errors, max depth, hardlink adjustments, and
   future filtered snapshots.

### DataTree Does Not Preserve Node Kind

Source fact:

- pdu `FsTreeBuilder` checks `stats.is_dir()` internally to decide whether to
  call `read_dir`.
- pdu `TreeBuilder::Info` returns only `size` and `children`.
- pdu `DataTree` stores only `name`, `size`, and `children`.
- after `FsTreeBuilder -> DataTree`, the adapter cannot distinguish a file from
  an empty directory by structure alone.

Contract:

```text
NodeKindEvidence is product-owned evidence.
pdu DataTree child shape is not node-kind authority.
```

Implications:

- UI folder/file icons must not rely only on `children.is_empty()`;
- top-files and folder/file counts require metadata evidence, not only pdu
  `DataTree`;
- eager re-stat of every pdu node would likely duplicate expensive filesystem
  work on million-node scans;
- lazy metadata is acceptable for visible rows/details, but full top-files
  indexes need a richer scan path or a separate indexing pass;
- `child_count_state` must distinguish `known_stored_children`,
  `hidden_due_to_depth`, `unknown_due_to_error`, and `unknown_kind_leaf`.

Top 3 node-kind strategies:

1. Use pdu `TreeBuilder` with adapter-owned `get_info` side-store - 🎯 8 🛡️ 9
   🧠 8, roughly 1200-2800 LOC.
   Best production path if MVP requires accurate top files, folder/file counts,
   and node-kind indexes without a second full metadata pass.
2. Use pdu `FsTreeBuilder` and lazy metadata enrichment - 🎯 8 🛡️ 7 🧠 5,
   roughly 700-1700 LOC.
   Good scan-only MVP path. It keeps integration small, but top-files and exact
   kind/count features must be capability-gated or delayed.
3. Use `FsTreeBuilder` then eager re-stat every node - 🎯 4 🛡️ 5 🧠 4,
   roughly 800-1800 LOC.
   Rejected as default. It risks doubling metadata I/O and hurting the speed
   reason we chose pdu.

### Depth Policy Must Preserve Hidden Descendants

Source fact:

- pdu `TreeBuilder` subtracts one from `max_depth` with `saturating_sub(1)` at
  every node.
- when the resulting depth is zero, it still builds children to sum their sizes,
  then stores an empty children vector.
- pdu CLI `Depth` disallows zero finite depth, but direct `TreeBuilder` accepts
  raw `u64`.

Contract:

```text
DepthLimit is product-owned.
Depth-limited leaves are not cleanup targets unless revalidated by current
subtree scan or platform metadata.
```

Implications:

- `child_count_state` needs `hidden_due_to_depth` and not just `0`;
- query APIs must be able to say "children not stored by scan policy";
- delete plan must not treat a max-depth leaf as a complete subtree selection
  without current preflight;
- direct pdu `TreeBuilder` path must validate depth before calling pdu and avoid
  accidental `0` semantics unless the product policy explicitly wants "summary
  root only".

Top 3 depth strategies:

1. Product `DepthLimit` plus hidden-descendant markers - 🎯 9 🛡️ 10 🧠 6,
   roughly 500-1300 LOC.
   Accepted. It keeps UI and cleanup honest about partial tree storage.
2. Always scan/store unlimited tree - 🎯 5 🛡️ 6 🧠 4, roughly 100-400 LOC.
   Rejected as default because very large disks need bounded memory and
   responsive UI.
3. Trust pdu empty children as no children - 🎯 2 🛡️ 2 🧠 1, roughly
   50-100 LOC.
   Rejected. It is factually wrong under max-depth, read errors, boundary
   policy, and node-kind ambiguity.

### Recursive Depth Is A Resource Boundary

Source fact:

- pdu `TreeBuilder::from` is recursive.
- `TreeBuilder::from` reduces `max_depth` with `saturating_sub(1)`, but still
  maps every child through `Self::from` to compute descendant sizes.
- `DataTree -> Reflection` conversion recursively maps every child.
- `Reflection::par_try_into_tree`, `Reflection::par_try_map`,
  `Reflection::par_convert_names_to_utf8`, `DataTree::par_retain`,
  `DataTree::par_sort_by`, and hardlink dedupe are recursive tree operations.
- Rust `thread::Builder::stack_size` can configure spawned thread stack size,
  but this is a runtime containment tool, not a domain rule.
- Rust `panic::catch_unwind` can contain unwinding panics, but does not catch
  aborting failures, so it is not a complete shield against every stack or
  process failure mode.

Contract:

```text
Traversal depth, retained tree depth, and UI display depth are three different
policies.

pdu max_depth is retained-tree depth, not traversal-depth authority.
Deep-tree safety is a backend capability and fixture result, not an assumption.
```

Implications:

- a product `TraversalDepthLimit` must be enforced in our adapter-owned probe if
  we need to stop descending, because pdu `max_depth` still traverses below the
  retained child arrays;
- a product `RetainedDepthLimit` controls how much of the tree is stored for
  immediate queries;
- a frontend `DisplayDepth` controls disclosure/initial expansion only and must
  never influence scan truth;
- a depth-collapsed node must carry `children_state = hidden_due_to_depth` or a
  similar product state;
- deep tree scans need explicit stack/resource tests before cleanup authority is
  enabled for that backend profile;
- panic containment at the adapter boundary is useful, but a signed helper
  process remains the stronger future boundary if deep recursion or native
  stack behavior becomes unacceptably risky.

Top 3 deep-tree strategies:

1. Product traversal guard plus retained-depth policy - 🎯 8 🛡️ 9 🧠 7,
   roughly 700-1800 LOC.
   Accepted. Use custom `TreeBuilder` probe when traversal cutoff is required;
   keep pdu `max_depth` only as retained-tree shaping.
2. Treat pdu `max_depth` as "do not scan deeper" - 🎯 3 🛡️ 3 🧠 2,
   roughly 100-300 LOC.
   Rejected. Source code shows hidden descendants are still scanned and summed.
3. Move every production scan into a helper process with tuned stack and kill
   boundary - 🎯 6 🛡️ 8 🧠 9, roughly 1800-4500 LOC.
   Deferred. Strong containment later, but too heavy for scan-only MVP unless
   fixture results prove in-process containment is not enough.

### Reflection And pdu JSON Are Not Product Protocol

Source fact:

- `DataTree` does not implement JSON serialization directly.
- `Reflection<Name, Size>` is the public intermediate format with `name`,
  `size`, and `children`.
- pdu docs/source describe `Reflection` as a format for construction and
  inspection of `DataTree` internals; its fields are public to allow test
  construction.
- `Reflection::par_try_into_tree` validates only a narrow invariant: a node's
  size must not be less than any one child size. It does not validate Clean Disk
  concepts such as path authority, metadata quality, permission state, node
  identity, or cleanup safety.
- `Reflection::par_convert_names_to_utf8` can fail on non-UTF-8 names.
- pdu CLI JSON output calls `par_convert_names_to_utf8()` and then
  `expect("convert all names from raw string to UTF-8")`, with a TODO to allow
  non-UTF-8 somehow.
- `JsonData` has `schema-version`, optional `pdu` binary version, and a flattened
  body tagged by `unit` as bytes or blocks.
- `JsonShared` hardlink details/summary are optional and can be omitted.
- pdu README warns JSON root semantics differ depending on target count.
- hardlink path-list reflection converts a vector into a `HashSet<PathBuf>`, so
  reflected hardlink path order is not stable evidence.

Contract:

```text
pdu JSON/Reflection is a diagnostic or fixture format only.
Clean Disk protocol/cache/export schemas are product-owned DTOs.
```

Implications:

- never use pdu JSON as daemon HTTP response, WebSocket event, Drift cache, or
  public export format;
- pdu JSON can be useful in adapter regression fixtures, but only behind
  `fs_usage_pdu/diagnostics`;
- non-UTF-8 file names must be handled by our path/display abstraction, not by
  forcing all names through pdu JSON;
- pdu `schema-version` is not our protocol version;
- pdu `unit` is not enough for our size model because we need logical,
  allocated, blocks, exclusive reclaim, confidence, and platform evidence;
- optional `JsonShared` cannot be cleanup authority.
- pdu JSON multi-root shape must not define Clean Disk `VirtualRootPolicy`;
- reflected hardlink path ordering cannot be used for deterministic UI order,
  selection, or receipts.

Top 3 JSON/fixture strategies:

1. Keep pdu JSON only as adapter fixture/debug input - 🎯 9 🛡️ 9 🧠 5,
   roughly 300-900 LOC.
   Accepted. It gives repeatable adapter tests without leaking upstream schema.
2. Transform pdu JSON directly to Flutter DTOs - 🎯 4 🛡️ 4 🧠 3, roughly
   300-800 LOC.
   Rejected. It loses non-UTF-8, issues, identity, and product version control.
3. Disable pdu JSON feature everywhere - 🎯 7 🛡️ 8 🧠 3, roughly 50-200 LOC.
   Acceptable for production builds, but keep a dev/test-only fixture path if it
   materially helps adapter regression tests.

### pdu JsonData Is A CLI Exchange Schema

Source fact:

- pdu `JsonData` has `schema_version`, optional `pdu` binary version, and a
  flattened body tagged by `unit`.
- `JsonDataBody` is either `bytes` or `blocks`, with `JsonTree<Bytes>` or
  `JsonTree<Blocks>`.
- `JsonShared` contains optional hardlink `details` and optional `summary`; both
  can be omitted.
- pdu `SchemaVersion` is currently a date string in pdu source, not a Clean Disk
  compatibility version.
- pdu JSON names are `String`, so pdu CLI has to convert native names to UTF-8
  before writing JSON.

Contract:

```text
pdu JsonData is a diagnostic/import fixture format only.
Clean Disk snapshot, cache, export, and daemon DTO schemas are product-owned.
```

Implications:

- product snapshot schema version is not pdu `schema-version`;
- pdu `unit` cannot represent our full `MeasurementProfile` and `SizeFact`
  model;
- optional `shared` means hardlink absence in JSON is ambiguous without
  capability evidence;
- pdu binary version is backend provenance, not protocol compatibility;
- pdu JSON input can be used for adapter fixtures, but imports must become
  `ScanSnapshotDraft` and pass product validation.

Top 3 JSON schema strategies:

1. Product-owned snapshot/protocol schema plus optional pdu fixture importer -
   🎯 10 🛡️ 10 🧠 6, roughly 700-1800 LOC.
   Accepted. It keeps public contracts stable and still lets us reuse pdu JSON
   for regression fixtures.
2. Expose pdu `JsonData` through daemon HTTP - 🎯 3 🛡️ 3 🧠 2, roughly
   100-400 LOC.
   Rejected. It loses product semantics and inherits upstream schema churn.
3. Delete all JSON-related paths forever - 🎯 5 🛡️ 7 🧠 2, roughly 50-200 LOC.
   Rejected as too rigid. Fixture import/export is useful for adapter tests.

### Reflection Safety Is Not Product Validation

Source fact:

- pdu `Reflection` fields are public for construction and inspection.
- pdu source says `DataTree` can be transmuted to a valid `Reflection`, while a
  `Reflection` can be transmuted to a potentially invalid `DataTree`.
- the safe `Reflection::par_try_into_tree` path validates only one structural
  invariant: a node must not be smaller than one of its direct children.
- `par_try_into_tree` does not validate path authority, node kind, permission
  state, scan issue state, identity, boundary policy, or cleanup authority.
- `par_convert_names_to_utf8` is only a UTF-8 conversion helper and can fail on
  native names that are valid on the filesystem.

Contract:

```text
pdu Reflection validation is fixture/tree-shape validation only.
Product snapshot validation is owned by fs_usage_core and fs_usage_engine.
```

Implications:

- never treat a pdu `Reflection` import as a valid Clean Disk snapshot;
- convert any fixture/import into a `ScanSnapshotDraft` and run product
  invariants separately;
- do not use unsafe transmute in our adapter unless a measured benchmark and a
  written safety case prove it is necessary;
- JSON fixture validation must not bypass domain value objects;
- cleanup, selection, receipts, and cache migrations must never rely on pdu
  reflection invariants.

Top 3 reflection strategies:

1. Safe conversion plus product snapshot validation - 🎯 10 🛡️ 10 🧠 6,
   roughly 500-1400 LOC.
   Accepted. It preserves pdu test utility without confusing it with product
   correctness.
2. Use pdu `Reflection::par_try_into_tree` as the main validator - 🎯 3 🛡️ 3
   🧠 2, roughly 100-300 LOC.
   Rejected. It validates too little.
3. Use unsafe transmute for speed from day one - 🎯 3 🛡️ 5 🧠 7, roughly
   200-800 LOC plus safety proof.
   Rejected until profiling proves safe conversion is a real bottleneck.

### Reporter Events Are Backend Evidence

Source fact:

- `Event` is non-exhaustive.
- Current variants are `ReceiveData(Size)`, `EncounterError(ErrorReport)`, and
  `DetectHardlink(HardlinkDetection)`.
- `ErrorReport` contains borrowed path and raw `io::Error`.
- `ProgressReport` has only counters and stderr text output.
- `Reporter::report(&self, event)` is synchronous and returns `()`.
- `Operation` currently has only `SymlinkMetadata`, `ReadDirectory`, and
  `AccessEntry`.
- `HardlinkDetection` carries borrowed path, borrowed metadata, size, and link
  count. It is not an owned event record.

Contract:

```text
Reporter events map into owned ScanIssue, ProgressEvidence, and HardlinkEvidence.
They never become protocol events directly.
```

### Reporter Port Design Before Coding

Because pdu reporter events are synchronous and borrowed, the adapter needs a
small local anti-corruption layer.

Recommended adapter pieces:

```text
PduReporter
  -> PduEventRecorder
       owned error evidence side-store
       owned hardlink evidence side-store
       atomic/coalesced progress counters
  -> PduIssueMapper
  -> PduProgressMapper
  -> ScanEventPublisher
```

Rules:

- copy or classify borrowed `ErrorReport` data immediately;
- never store borrowed pdu paths, metadata, or `io::Error` beyond the callback;
- map pdu `Operation` to product `ScanIssueReason`, not UI text;
- preserve unknown/future pdu events as `BackendEventUnsupported` or
  `BackendEventUnknown` evidence if upstream adds variants;
- bounded event publishing must not block pdu filesystem traversal;
- if the event queue is overloaded, coalesce progress and retain loss evidence;
- final scan state must come from `BackendScanOutput`, not from the last reporter
  callback.

Top 3 reporter integration strategies:

1. Owned `PduEventRecorder` plus bounded/coalesced publisher - 🎯 9 🛡️ 9
   🧠 7, roughly 600-1500 LOC.
   Accepted. It protects pdu traversal from UI/network backpressure and gives
   the application layer stable evidence.
2. Send pdu events directly to WebSocket - 🎯 3 🛡️ 3 🧠 2, roughly
   100-400 LOC.
   Rejected. Borrowed data, weak taxonomy, unknown events, and transport
   backpressure would leak into scan correctness.
3. Ignore reporter events and only inspect final tree - 🎯 4 🛡️ 5 🧠 2,
   roughly 50-200 LOC.
   Rejected for product UX and permissions. We would lose skipped/error quality
   and progress evidence.

### pdu ErrorReport Is Too Small For Product Issues

Source fact:

- pdu `ErrorReport` contains only `operation`, borrowed `path`, and raw
  `io::Error`.
- pdu `Operation` currently has `SymlinkMetadata`, `ReadDirectory`, and
  `AccessEntry`.
- pdu `ErrorReport::TEXT` formats the path with Debug and writes through
  `GLOBAL_STATUS_BOARD`.
- pdu does not classify permission denied, disappeared path, not-a-directory,
  network error, cloud placeholder, boundary skip, or policy skip as product
  reasons.

Contract:

```text
pdu ErrorReport is raw backend evidence.
Product ScanIssue is a richer, redacted, platform-aware issue record.
```

Recommended mapping shape:

```text
PduErrorEvidence
  operation
  native_path_evidence
  io_error_kind
  raw_os_code
  backend_phase

ScanIssueDraft
  reason
  severity
  recoverability
  privacy_class
  path_ref
  platform_code
  evidence_confidence
```

Implications:

- product issue mapping must look at `io::ErrorKind`, raw OS code when
  available, operation, target policy, and platform context;
- `AccessEntry` path precision is parent-directory precision in pdu's default
  builder, so UI wording must not imply exact child path if the child name was
  unavailable;
- permission guidance must be platform-owned, not pdu-owned;
- raw paths and OS messages require redaction before logs, metrics, support
  bundles, or telemetry;
- unknown future pdu operations must map to non-exhaustive backend issue
  evidence and fail closed for cleanup.

Top 3 issue-mapping strategies:

1. Product `ScanIssueDraft` with pdu evidence mapper - 🎯 10 🛡️ 10 🧠 6,
   roughly 500-1300 LOC.
   Accepted. It preserves raw evidence without leaking pdu or terminal text.
2. Expose pdu operation and `io::ErrorKind` directly to UI - 🎯 4 🛡️ 4 🧠 2,
   roughly 100-300 LOC.
   Rejected. It is not localized, not redacted, and too weak for permissions
   and cleanup safety.
3. Count errors only, no issue details - 🎯 5 🛡️ 5 🧠 1, roughly 50-150 LOC.
   Rejected for product UX. Users need to know why scan quality is degraded.

### Size Is Not One Number

Source fact:

- pdu `GetApparentSize` uses `metadata.len()`.
- Unix pdu `GetBlockSize` uses `metadata.blocks() * 512`.
- Unix pdu `GetBlockCount` uses `metadata.blocks()`.
- `Bytes` and `Blocks` are different pdu size types.
- byte display uses `BytesFormat`, while block count display ignores it.

Contract:

```text
Every size fact carries kind, unit semantics, source backend, confidence, and
exactness. UI display text is a projection, not a fact.
```

### Measurement Defaults Are CLI Policy

Source fact:

- pdu CLI `Quantity::DEFAULT` is `BlockSize` on Unix and `ApparentSize` on
  non-Unix.
- `GetApparentSize` maps to `Metadata::len()`.
- `GetBlockSize` is Unix-only and maps to `metadata.blocks() * 512`.
- `GetBlockCount` is Unix-only and returns pdu `Blocks`, not bytes.
- pdu size newtypes are `u64` wrappers with display helpers; display format is
  not measurement semantics.

Contract:

```text
MeasurementProfile is product-owned.
pdu Quantity and BytesFormat are adapter/CLI concerns.
```

Implications:

- every scan request must specify a measurement profile or use a Clean Disk
  default chosen by product policy;
- protocol should expose exact size facts as typed/string-safe values and a
  measurement profile id;
- UI labels must say what the number means: logical size, allocated size,
  block count, estimated reclaim, or unknown;
- read-model indexes must know which size fact they sort by;
- future Windows MFT or platform accounting adapters can add allocated size
  without changing `SizeFact`.

Top 3 measurement strategies:

1. Product `MeasurementProfile` plus typed `SizeFact` set - 🎯 10 🛡️ 10 🧠 7,
   roughly 900-2200 LOC.
   Accepted. It lets pdu, MFT, APFS, Linux, and remote backends coexist.
2. Use pdu CLI quantity defaults everywhere - 🎯 4 🛡️ 4 🧠 2, roughly
   100-300 LOC.
   Rejected. It creates platform-dependent UI truth and confusing comparisons.
3. Store only one `size_bytes` value - 🎯 5 🛡️ 4 🧠 2, roughly 150-500 LOC.
   Rejected. It cannot represent sparse files, block counts, APFS clones, or
   honest reclaim estimates.

### Numeric Precision And Overflow Are Boundary Concerns

Source fact:

- pdu `Bytes` and `Blocks` are `u64` newtypes.
- pdu `Size` requires arithmetic traits such as add, subtract, multiply, and
  sum.
- pdu culling converts size values into `u64`, then into `f32` for ratio
  comparison.
- Flutter web runs on JavaScript semantics, where large JSON numbers can lose
  integer precision.

Contract:

```text
Exact size and counter values are product value objects.
Protocol DTOs must be string-safe or otherwise explicitly web-safe for large
integers.
```

Implications:

- exact byte counts, item counts, node ids, cursors, event sequence numbers,
  and timestamps must not rely on JavaScript numeric precision;
- Rust domain/application code should use checked or saturating arithmetic
  where overflow would change product truth;
- UI can use approximate display values, but commands and delete plans must
  carry exact values or opaque ids;
- benchmarks need synthetic huge totals near numeric boundaries, not only normal
  laptop folders;
- ratio/cull operations must never mutate authoritative snapshot truth.

Top 3 numeric strategies:

1. Exact backend values plus web-safe DTO encoding - 🎯 9 🛡️ 10 🧠 6,
   roughly 500-1300 LOC.
   Accepted. It keeps desktop, web UI, and remote/headless contracts aligned.
2. Send all numbers as JSON numbers - 🎯 4 🛡️ 4 🧠 2, roughly 100-300 LOC.
   Rejected for Flutter web and future remote clients.
3. Convert everything to formatted strings early - 🎯 4 🛡️ 5 🧠 3, roughly
   200-500 LOC.
   Rejected. Display text cannot be used for sorting, commands, or receipts.

### DataTree Arithmetic Needs Product Guards

Source fact:

- pdu `DataTree::dir` computes total size as `inode_size + sum(children)`.
- pdu max-depth collapse computes parent size from child totals while dropping
  the child list.
- pdu hardlink dedupe subtracts shared-link size from aggregate containers.
- pdu `Bytes` and `Blocks` are `u64` wrappers and implement ordinary add,
  subtract, multiply, and sum traits.
- Rust integer overflow behavior differs by build profile unless explicitly
  handled.

Contract:

```text
pdu arithmetic output is backend evidence.
Product size value objects validate arithmetic before publishing authority.
```

Implications:

- `SizeFact` construction should use checked arithmetic when an overflow would
  change product truth;
- adapter conversion must map impossible arithmetic to degraded scan state or
  backend failure, not silently publish false values;
- hardlink-adjusted, depth-collapsed, cull-filtered, and display-rounded sizes
  need explicit projection metadata;
- tests must include synthetic near-limit totals, many children, and hardlink
  subtraction cases;
- product delete/reclaim estimates must not trust an aggregate number without
  knowing which arithmetic policy produced it.

Top 3 arithmetic strategies:

1. Checked `SizeFact` constructors and projection metadata - 🎯 9 🛡️ 10 🧠 6,
   roughly 500-1300 LOC.
   Accepted. Exact facts remain exact, while projections can be marked with
   policy and confidence.
2. Saturating arithmetic everywhere - 🎯 6 🛡️ 7 🧠 4, roughly 300-900 LOC.
   Useful only for defensive counters. It hides overflow unless paired with an
   explicit issue flag.
3. Trust pdu `u64` arithmetic as product truth - 🎯 3 🛡️ 3 🧠 1, roughly
   50-150 LOC.
   Rejected. It is too easy to publish wrapped or over-subtracted values as
   cleanup authority.

### Device Boundary Is Capability-Dependent

Source fact:

- `DeviceBoundary::Stay` compares root device id with current metadata device
  id where pdu can obtain one.
- pdu source is Unix-heavy for device/block/hardlink behavior.
- on non-Unix, pdu's internal `DeviceId` fallback makes all entries share the
  same device id, effectively disabling real cross-device detection.

Contract:

```text
Boundary enforcement is a capability result, not a universal promise.
The platform adapter must report when same-device behavior is unsupported,
weakened, or not proved.
```

Additional contract detail:

```text
BoundaryPolicy is product-owned.
pdu DeviceBoundary is one Unix-capable adapter input, not the full boundary
model.
```

Implications:

- `same_filesystem` must be a capability, not a universal boolean;
- Windows junctions/reparse points, WSL boundaries, network shares, removable
  volumes, cloud sync roots, and container mounts need platform adapters;
- UI should render "boundary not proved" differently from "boundary crossed" or
  "boundary skipped";
- cleanup policy must fail closed when boundary evidence is unknown for a risky
  target.

### Hardlinks Are Evidence, Not Reclaim Truth

Source fact:

- `HardlinkAware` ignores directories.
- It checks Unix `nlink()`, and ignores files with one or fewer links.
- It emits `Event::DetectHardlink` before adding the entry to `HardlinkList`.
- `HardlinkList` keys by `(inode, device)`.
- `HardlinkList::add` can return `SizeConflict` or `NumberOfLinksConflict`.
- `FsTreeBuilder` calls `record_hardlinks(...).ok()`, so recorder errors are
  discarded by the default pdu builder path.
- `DeduplicateSharedSize` mutates the pdu `DataTree` after scan by subtracting
  shared hardlink sizes from affected containers.
- pdu hardlink support is Unix-only.

Contract:

```text
pdu hardlink data is scan evidence.
Clean Disk reclaim/accounting truth belongs to accounting and delete-plan ports.
```

Implications:

- `HardlinkEvidence` must record capability, backend, conflicts, and confidence.
- `DetectHardlink` must not be treated as a stable hardlink group receipt.
- If pdu hardlink conflict evidence is needed, the adapter needs its own side
  store or a custom recorder strategy, because the default builder discards
  recorder errors.
- Primary product tree should avoid pdu destructive dedupe mutation unless the
  selected measurement profile explicitly says the tree is hardlink-adjusted.
- Delete preview must compute reclaim estimate through a separate accounting
  port and must label uncertainty.
- when there are multiple scan targets, overlap handling must be product-owned.
  pdu removes overlapping paths only for Unix hardlink dedupe mode, not as a
  general scan-target invariant.

Top 3 hardlink strategies:

1. Keep pdu primary tree non-deduped, store hardlink evidence separately -
   🎯 9 🛡️ 9 🧠 7, roughly 700-1800 LOC.
   Accepted for MVP. It keeps measured totals explainable and avoids mixing
   scanner evidence with reclaim authority.
2. Use pdu deduplicated tree as the only product tree - 🎯 5 🛡️ 5 🧠 4,
   roughly 300-900 LOC.
   Rejected as default. It mutates aggregate sizes and hides the difference
   between observed scan size and hardlink-adjusted accounting.
3. Disable hardlink detection entirely until cleanup beta - 🎯 6 🛡️ 7 🧠 2,
   roughly 100-300 LOC.
   Acceptable as a feature flag fallback, but weak for developer disks and Unix
   correctness.

### Hardlink Deduplication Mutates Aggregate Size

Source fact:

- pdu `DataTree::par_deduplicate_hardlinks` mutates a `DataTree` in place.
- it filters recorded hardlink groups by stripping the current node prefix from
  recorded paths.
- for each matching group with more than one path under a container, it
  subtracts `size * (number_of_links - 1)` from that container's aggregate size.
- this relies on pdu path-name conventions: the root name is a path-like value,
  children are relative names, and multi-target/fake-root shape changes path
  interpretation.
- this operation produces a hardlink-adjusted projection, not a measured
  filesystem fact and not a delete reclaim estimate.

Contract:

```text
Measured size and hardlink-adjusted size are separate SizeFact projections.
Hardlink dedupe mutation never replaces the authoritative measured snapshot.
```

Implications:

- store original measured aggregate facts before any dedupe/cull/sort
  projection;
- if a hardlink-adjusted view is exposed, attach `projection_policy =
  hardlink_deduped` and the evidence source;
- do not derive delete reclaim from pdu dedupe, because reclaim depends on
  links outside the scan scope, snapshots, clones, provider state, and current
  identity at delete time;
- path-prefix behavior needs contract tests with multi-root scans, overlapping
  targets, relative names, non-UTF-8 names, and symlinks;
- if pdu dedupe ever panics or underflows, the worker boundary must fail the
  projection without promoting it to current product truth.

Top 3 hardlink projection strategies:

1. Keep measured tree plus separate hardlink-adjusted projection - 🎯 9 🛡️ 10
   🧠 8, roughly 800-2200 LOC.
   Accepted long-term shape. It keeps disk usage, display projection, and
   reclaim estimate honest.
2. Disable pdu dedupe initially, capture hardlink events only - 🎯 8 🛡️ 8 🧠 3,
   roughly 200-700 LOC.
   Good MVP fallback. It avoids mutation while preserving enough evidence to
   show limitations.
3. Mutate the product snapshot with pdu dedupe - 🎯 4 🛡️ 4 🧠 3, roughly
   150-500 LOC.
   Rejected. It mixes backend projection with authoritative snapshot truth.

### Hardlink Recorder Errors Need A Custom Capture Path

Source fact:

- `RecordHardlinks::record_hardlinks` is fallible.
- `HardlinkAware` can return size conflicts or link-count conflicts for the same
  `(inode, device)` group.
- `FsTreeBuilder` calls `.ok()` on `record_hardlinks`, discarding these recorder
  errors.
- `DetectHardlink` is emitted before adding the hardlink to `HardlinkList`, so a
  progress/hardlink event can exist even if recording the group later conflicts.

Contract:

```text
Hardlink conflict evidence must be preserved by the adapter or explicitly
reported as unobservable.
```

Implications:

- if conflict evidence matters, use a custom `RecordHardlinks` implementation or
  custom `TreeBuilder` probe instead of relying on `FsTreeBuilder` defaults;
- `HardlinkEvidence` needs states such as detected, grouped, conflict,
  grouping_unavailable, and not_supported;
- UI can show a warning from evidence, but reclaim estimate still belongs to the
  accounting port;
- contract tests must prove hardlink record errors are not silently treated as
  successful grouping.

Top 3 hardlink conflict strategies:

1. Custom recorder that stores conflicts in adapter evidence - 🎯 8 🛡️ 9 🧠 7,
   roughly 500-1300 LOC.
   Accepted when hardlink details are enabled.
2. Use `FsTreeBuilder` and mark conflict evidence unobservable - 🎯 7 🛡️ 7
   🧠 3, roughly 150-400 LOC.
   Acceptable for scan-only MVP if the capability snapshot says so.
3. Ignore conflict semantics completely - 🎯 3 🛡️ 3 🧠 1, roughly 0-100 LOC.
   Rejected. It would make "hardlink-aware" look more authoritative than it is.

### Hardlink Summary Is Classification Evidence

Source fact:

- pdu `HardlinkList` stores a `DashMap` keyed by `(inode, device)`.
- pdu `Value` stores size, total link count, and detected paths.
- `SharedLinkSummary` is `#[non_exhaustive]` and includes inodes,
  exclusive_inodes, all_links, detected_links, exclusive_links, shared_size,
  and exclusive_shared_size.
- pdu considers a hardlink group "exclusive" when detected paths equal the
  filesystem `nlink` count.
- pdu dedupe mutates `DataTree` by subtracting `size * (detected_paths - 1)`
  from containers where multiple detected link paths are under the same prefix.

Contract:

```text
Hardlink summary is classification evidence.
It is not delete reclaim truth and not cross-filesystem shared-extent truth.
```

Implications:

- `exclusive_shared_size` can inform recommendations, but delete preview still
  needs `FilesystemAccountingAdapter`;
- pdu hardlink evidence covers Unix hardlinks, not APFS clones, Btrfs/ZFS
  shared extents, sparse holes, compression, snapshots, cloud placeholders, or
  dedupe engines;
- pdu detected path counts are scan-scope dependent, so changing target set can
  change exclusivity evidence;
- the read model should expose hardlink warnings/details lazily, not as required
  fields on every node.

### pdu Hardlink Summary Can Panic On Impossible Evidence

Source fact:

- `SummarizeHardlinks::summarize_hardlinks` compares total `nlink` with detected
  path count.
- if detected paths exceed total links, pdu panics with an "Impossible!" message.
- normal filesystem evidence should not produce this state, but stale,
  synthetic, corrupted, racy, or incorrectly reflected evidence can.
- pdu summary display text is terminal-facing explanation, not product error
  taxonomy.

Contract:

```text
Hardlink summary is fallible adapter evidence.
No pdu panic should crash the long-running Clean Disk daemon.
```

Implications:

- hardlink summary generation must map impossible evidence to a typed
  `HardlinkEvidenceError` or degraded capability state;
- adapter worker boundaries should contain unwinding panics and report a backend
  failure without publishing partial cleanup authority;
- `catch_unwind` is containment, not normal error handling, so ordinary
  filesystem errors still use typed `Result` flows;
- test fixtures must include impossible hardlink evidence to prove daemon
  survival and issue mapping;
- if we use pdu hardlink summary directly, it must sit inside the pdu adapter,
  never in domain/application code.

Top 3 panic strategies:

1. Validate/safely summarize hardlink evidence in the adapter - 🎯 8 🛡️ 9 🧠 7,
   roughly 600-1600 LOC.
   Accepted for cleanup-quality hardlink details.
2. Add worker panic containment around pdu scan/summarize execution - 🎯 8 🛡️ 8
   🧠 5, roughly 300-900 LOC.
   Accepted as a runtime safety net, not as the primary error model.
3. Treat the pdu panic as unreachable and ignore it - 🎯 3 🛡️ 3 🧠 1, roughly
   0-50 LOC.
   Rejected. Daemon stability cannot depend on upstream "impossible" states.

### Progress Reporter Is Eventually Sampled

Source fact:

- `ProgressAndErrorReporter` spawns a thread that sleeps for a configured
  interval.
- Counters use relaxed atomics.
- `EncounterError` calls the error callback before incrementing `errors`.
- `DetectHardlink` increments `linked` by `info.links`, not by one event.
- `destroy(self)` stops the thread and joins it.
- `ProgressReport::TEXT` writes to stderr.

Contract:

```text
pdu progress is a sampled backend counter stream.
Clean Disk progress is a session-scoped event contract with final reconciliation.
```

Implications:

- UI progress cannot rely on every pdu filesystem event.
- `linked` is not "number of hardlink files detected"; it is accumulated link
  count according to pdu event semantics.
- final scan state must be computed from `BackendScanOutput`, not from the last
  progress sample.
- event order must be added by our `ScanEventPublisher`, not inferred from pdu
  relaxed counters.
- `destroy` is reporter teardown, not scan cancellation.

### Built-In pdu Reporter Is Not Our Runtime Event Bus

Source fact:

- pdu `ProgressAndErrorReporter::new` spawns a thread that sleeps for a fixed
  interval and samples atomic counters.
- `destroy` stops and joins the reporter thread; it does not stop traversal.
- `destroy` can return the progress thread's panic payload; pdu CLI prints only
  a warning when reporter teardown fails.
- `ErrorReport::TEXT` and `ProgressReport::TEXT` write through pdu's global
  status board for terminal output.
- `Event` is marked non-exhaustive and currently carries borrowed paths and
  metadata through error and hardlink events.
- `EncounterError` calls the error reporter before incrementing the error
  counter.

Contract:

```text
PduReporterRecorder is an anti-corruption adapter.
Clean Disk events are emitted by the application session, not by pdu directly.
```

Implications:

- production should use a custom pdu reporter that copies evidence immediately,
  redacts paths, and writes into bounded adapter-owned state;
- pdu terminal reporters should not be used in daemon/server mode;
- pdu `Event` must be mapped through a non-exhaustive fallback;
- progress event emission to WebSocket should be throttled/coalesced by our
  session event sink, not by pdu's terminal reporter;
- final session state must be produced by our application lifecycle, not by the
  last pdu progress sample;
- reporter teardown failure must become a structured `BackendRuntimeIssue`, not
  terminal warning text;
- final scan output must not be promoted until reporter/evidence finalization is
  reconciled.

### Scan Phase Is Not The Whole Operation

Source fact:

- pdu `Sub::run` builds one or more `FsTreeBuilder` trees first.
- pdu then calls `reporter.destroy()`.
- only after reporter teardown does the CLI apply `min_ratio` culling, sorting,
  hardlink dedupe mutation, fake-root rename, JSON conversion, visualization,
  and hardlink summary printing.
- therefore pdu progress reports filesystem traversal counters, not complete
  product operation progress.

Contract:

```text
Clean Disk scan lifecycle has explicit phases.
Traversal, conversion, indexing, enrichment, and publication are separate
operation steps.
```

Implications:

- WebSocket event model should include phase/state, not only percentage;
- UI "scan complete" should mean the product snapshot is queryable, not merely
  that pdu traversal returned;
- heavy post-processing such as arena conversion, hardlink projection, search
  index build, top-list index build, metadata enrichment, and cache writes need
  their own resource budget and cancellation behavior;
- performance benchmarks must report raw pdu traversal time separately from
  product-ready snapshot time;
- late cancellation after traversal but before publication must still prevent
  the snapshot from becoming current.

Top 3 phase models:

1. Explicit operation phases with final publish gate - 🎯 10 🛡️ 10 🧠 6,
   roughly 600-1600 LOC.
   Accepted. It gives honest progress, cancellation, and benchmarking.
2. Treat pdu traversal return as "scan complete" - 🎯 4 🛡️ 4 🧠 2, roughly
   100-300 LOC.
   Rejected. It hides conversion/indexing latency and creates stale publish
   races.
3. Emit only coarse busy/idle without phases - 🎯 5 🛡️ 6 🧠 2, roughly
   100-300 LOC.
   Acceptable only for throwaway prototypes, weak for production UX/support.

### Rayon Execution Is A Runtime Boundary

Source fact:

- `TreeBuilder` and `DataTree` parallel operations use Rayon.
- pdu CLI `Threads::Auto` can try to set the global Rayon pool to one thread
  when any target appears to be on an HDD.
- pdu CLI `Threads::Max` leaves Rayon automatic behavior enabled.
- pdu CLI `Threads::Fixed` calls `rayon::ThreadPoolBuilder::build_global`.
- Rayon documents that the global pool is initialized once and cannot be
  reconfigured after it starts.
- Rayon `ThreadPool::install` runs a closure in a chosen local pool, and Rayon
  parallel iterators inside that closure use that pool.
- pdu uses `sysinfo` HDD detection as a CLI heuristic, including Linux virtual
  disk corrections and known limitations for device-mapper/LVM-like cases.

Contract:

```text
Clean Disk resource policy must not be pdu CLI thread policy.
Scanner execution belongs to the host/runtime adapter boundary.
```

Implications:

- do not use pdu `App` thread setup in the daemon;
- do not let one scan permanently configure the process-global Rayon pool;
- MVP should run pdu inside an explicit scanner execution lane and verify
  whether a local Rayon `ThreadPool::install` cleanly bounds pdu's parallel
  iterators;
- if local pool control is insufficient, the next isolation boundary is a
  signed helper process, not leaking pdu global settings into the daemon;
- HDD/resource detection should become `ResourceProfileDecision` evidence, not
  stderr warnings or hidden behavior.

Top 3 execution strategies:

1. Local scanner execution lane with explicit Rayon pool policy - 🎯 8 🛡️ 9
   🧠 7, roughly 600-1600 LOC.
   Accepted for MVP spike. It keeps resource control in our host and avoids pdu
   CLI global-pool behavior.
2. Use pdu CLI `Threads`/global Rayon behavior - 🎯 3 🛡️ 4 🧠 2, roughly
   100-300 LOC.
   Rejected. One global pool setting is too blunt for daemon sessions, tests,
   resource profiles, and future concurrent work.
3. Isolate each scan in a signed helper process - 🎯 7 🛡️ 9 🧠 9, roughly
   2500-7000 LOC.
   Deferred. Strong isolation and cancellation story, but too heavy before the
   adapter spike proves it is needed.

### Local Rayon Pool Is A Required Spike

Source fact:

- pdu library scan/build operations call Rayon parallel iterators internally.
- pdu CLI can configure the global pool, but production daemon integration must
  avoid process-global one-time configuration.
- Rayon `ThreadPool::install` is designed so nested Rayon operations use the
  selected pool while the closure runs.

Contract:

```text
ResourceProfile maps to a scanner execution lane, not to pdu CLI Threads.
The pdu adapter must prove whether local Rayon pools bound traversal,
conversion, sort, retain, and dedupe work.
```

Spike checklist:

```text
run pdu DataTree build inside local ThreadPool::install
verify thread count stays within ResourceProfile budget
verify nested DataTree sort/retain/dedupe uses the same pool
verify progress reporter and side-store event bridge do not spawn unbounded work
verify cancellation discard still works if the worker pool is saturated
verify no pdu app/build_global code is linked into production adapter path
```

Top 3 resource-boundary strategies:

1. Per-resource-profile local Rayon pool reused by scanner lane - 🎯 8 🛡️ 9
   🧠 7, roughly 700-1700 LOC.
   Accepted spike target. It should prevent global-pool pollution while keeping
   pdu performance.
2. One daemon-wide Rayon global pool with conservative thread count - 🎯 6 🛡️ 6
   🧠 3, roughly 200-600 LOC.
   Possible fallback, but weak for fast/background modes, tests, and future
   concurrent jobs.
3. Signed helper process per scan from day one - 🎯 7 🛡️ 9 🧠 9, roughly
   2500-7000 LOC.
   Strongest isolation, but too expensive before local-pool evidence exists.

### pdu HDD Auto Is A CLI Heuristic

Source fact:

- pdu `Threads::Auto` asks `sysinfo::Disks` for disk metadata.
- it canonicalizes user-provided paths and finds the longest matching mount
  point.
- on Linux, it tries to avoid false HDD classification for known virtual block
  drivers such as VirtIO, Xen, VMware paravirtual SCSI, and Hyper-V storage.
- pdu's own comments document a known LVM/device-mapper limitation where backing
  devices are not walked through `/sys/block/dm-*/slaves/`.
- on non-Linux platforms, pdu's virtual-HDD correction is a no-op.
- when no CLI paths are supplied, `Threads::Auto` checks an empty path list
  before `Sub` later defaults the scan target to `"."`, so the heuristic cannot
  throttle the implicit current-directory scan.
- failed canonicalization silently removes a path from HDD detection.

Contract:

```text
StorageMediumEvidence and ResourceProfileDecision are product-owned.
pdu HDD auto is diagnostic input at most, not resource governance.
```

Implications:

- do not inherit pdu `Threads::Auto` as Clean Disk balanced mode;
- host/runtime should choose worker budgets from explicit product
  `ResourceProfile`, battery/thermal state, target type, and user mode;
- storage medium detection must report confidence and unknown states;
- resource policy must handle empty target sets after product target resolution,
  not before;
- if we use pdu's HDD helper at all, keep it behind `fs_usage_pdu` or
  `fs_usage_platform` evidence, not domain.

Top 3 storage/resource strategies:

1. Product `ResourceProfileDecision` with optional pdu/sysinfo evidence -
   🎯 9 🛡️ 9 🧠 7, roughly 900-2200 LOC.
   Accepted. It lets balanced/fast/background modes evolve independently from
   pdu CLI heuristics.
2. Directly use pdu `Threads::Auto` in daemon - 🎯 4 🛡️ 4 🧠 2, roughly
   100-300 LOC.
   Rejected. It is a CLI heuristic with platform gaps and implicit-target
   mismatch.
3. Always run max threads for fastest benchmark - 🎯 5 🛡️ 3 🧠 2, roughly
   50-200 LOC.
   Rejected for default UX. User already saw machine freezes; fastest is not
   always best.

### pdu Feature Flags And Dependency Surface

Source fact:

- `parallel-disk-usage` default feature is `cli`.
- `cli` enables `clap/derive`, `clap_complete`, `clap-utilities`, and `json`.
- `json` enables serde derives and `serde_json`.
- pdu binary targets require CLI-related features, but the library can be used
  without default features.
- pdu crate root uses `#![deny(warnings)]`.
- pdu 0.23.0 uses Rust edition 2024 and does not declare an explicit
  `rust-version`.
- Cargo features are additive at the dependency graph level; another dependency
  path can enable default features unless the resolved feature graph is checked.
- the crate still has normal library dependencies used by internals, including
  Rayon and DashMap.
- several useful pdu surfaces are platform/feature shaped: JSON needs the
  `json` feature, hardlink dedupe is Unix-oriented, block size/count are
  Unix-oriented, and CLI binaries require CLI features.

Contract:

```text
Production adapter dependency policy is explicit.
No accidental CLI, terminal, or JSON surface is pulled into stable contracts.
Compile-time feature choices are part of the backend capability snapshot.
```

Implications:

- `fs_usage_pdu` should depend on pdu with `default-features = false` unless a
  specific feature is justified;
- if pdu JSON is used in tests or fixtures, gate it as test/dev tooling, not as
  the product protocol;
- dependency review must watch pdu feature changes on every upgrade;
- dependency review must watch pdu toolchain compatibility because pdu has
  edition 2024, `#![deny(warnings)]`, and no explicit `rust-version`;
- `app`, `visualizer`, `status_board`, pdu `Args`, and pdu `RuntimeError` are
  CLI-host concerns and should not appear in server/domain code.
- capability reports should say which optional pdu features and platform
  behaviors are available in this build, not only which backend name is active;
- CI should include a production feature build and a diagnostic/test feature
  build, so accidental JSON/CLI dependency drift is caught early.

Top 3 dependency strategies:

1. `parallel-disk-usage` with `default-features = false` in `fs_usage_pdu` -
   🎯 9 🛡️ 9 🧠 5, roughly 100-400 LOC.
   Accepted for production adapter dependency hygiene.
2. Use pdu default features because it is convenient - 🎯 5 🛡️ 5 🧠 2,
   roughly 50-150 LOC.
   Rejected for production. It invites CLI/JSON/terminal coupling.
3. Vendor/fork pdu immediately - 🎯 5 🛡️ 7 🧠 9, roughly 3000-10000 LOC.
   Deferred. Keep as an escape hatch if adapter spikes prove upstream API
   limits.

### pdu Backend Fingerprint And Upgrade Gate

pdu is a strategic scanner dependency, so each release build should know exactly
which pdu behavior it was built around.

Recommended fingerprint:

```text
PduBackendFingerprint
  crate_name = parallel-disk-usage
  crate_version
  crate_repository
  crate_license
  rust_edition
  declared_rust_version
  selected_features[]
  default_features_enabled
  production_import_allowlist_hash
  source_audit_revision
  fixture_corpus_version
  adapter_contract_version
```

Current audited fingerprint baseline, captured on 2026-05-20:

```text
crate_name = parallel-disk-usage
crate_version = 0.23.0
crate_repository = https://github.com/KSXGitHub/parallel-disk-usage.git
crate_license = Apache-2.0
rust_edition = 2024
declared_rust_version = unknown
local_verified_rustc = rustc 1.90.0 (1159e78c4 2025-09-14)
default_feature = cli
cli_feature = clap/derive, clap_complete, clap-utilities, json
json_feature = serde/derive, serde_json
production_default_features = false
production_json_feature = false unless used by diagnostic fixture tooling
production_cli_feature = false
core_runtime_dependencies_seen = rayon, dashmap
source_audit_focus = FsTreeBuilder, TreeBuilder, DataTree, Reporter, hardlink,
  get_size, device, json_data, app/Sub, args, status_board
```

This baseline is evidence, not a lockfile. The lockfile and CI still decide the
effective dependency graph, but every pdu upgrade must explain what changed
against this baseline.

Upgrade gate:

```text
Before bumping pdu:
  inspect Cargo.toml and lib.rs feature surface
  inspect FsTreeBuilder, TreeBuilder, DataTree, Reporter, hardlink modules
  run fixture corpus
  run production feature build with default-features=false
  run diagnostic fixture build when json is enabled
  diff AdapterDecisionRecord outputs
  diff capability snapshots
  update source-audit notes
```

Contract:

```text
pdu upgrades are adapter compatibility events.
They are not routine patch bumps until fixture diffs and capability diffs pass.
```

Top 3 pdu upgrade strategies:

1. Pin pdu plus require fingerprint/fixture/capability diff on upgrades -
   🎯 9 🛡️ 10 🧠 6, roughly 500-1300 LOC/config.
   Accepted. This preserves speed while making upstream drift visible.
2. Floating semver-compatible pdu updates with normal tests - 🎯 5 🛡️ 5 🧠 2,
   roughly 100-300 LOC.
   Rejected for scanner truth. pdu behavior, features, and toolchain surface are
   too central.
3. Vendor pdu source immediately - 🎯 5 🛡️ 8 🧠 9, roughly 2000-7000 LOC plus
   maintenance.
   Deferred. Useful if supply-chain or upstream drift becomes unacceptable, but
   too heavy before adapter evidence proves the need.

### Cancellation And Partial Output Boundary

Source fact:

- `FsTreeBuilder` has no cancellation token parameter.
- `Reporter::report` returns `()`, so a reporter cannot ask pdu to stop.
- `TreeBuilder` recursively builds a final `DataTree`; it does not expose a
  stable partial tree stream.
- `ParallelReporter::destroy` stops reporter threads, not filesystem traversal.

Contract:

```text
Cancellation is an application/session state first.
pdu cancellation is best-effort until we add a stronger backend boundary.
```

MVP policy:

- `CancelScanUseCase` sets session state to `cancellation_requested`;
- event delivery emits `CancelRequested`;
- the pdu worker may continue until natural completion;
- if the worker returns after cancellation, the application discards or archives
  the output according to `CancelledOutputPolicy`;
- UI must show cancellation as requested/finishing, not as instant abort;
- destructive actions stay disabled for cancelled or partial snapshots.

Future policy:

- fork/custom scanner path can add cooperative cancellation checks inside the
  tree traversal;
- signed helper process can provide hard abort when the OS permits it;
- remote/headless mode should expose cancellation semantics explicitly in
  capabilities.

Top 3 cancellation strategies:

1. MVP best-effort cancel with stale-output discard policy - 🎯 8 🛡️ 7 🧠 5,
   roughly 500-1200 LOC.
   Accepted for the first slice if clearly represented in UX and capabilities.
2. Fork pdu immediately for cooperative cancellation - 🎯 5 🛡️ 8 🧠 9,
   roughly 2500-7000 LOC.
   Deferred. Good final shape, but premature until pdu adapter proves other
   blockers.
3. Helper-process hard abort from day one - 🎯 6 🛡️ 8 🧠 9, roughly
   3000-8000 LOC.
   Deferred. Strong isolation, but packaging, TCC/process identity, logs, and
   crash recovery become first-milestone problems.

### Custom TreeBuilder Can Improve Cancellation Without Forking pdu

Source fact:

- `FsTreeBuilder` has no cancellation token.
- custom pdu `TreeBuilder` lets our adapter own `get_info(path)`.
- `get_info` returns `Info { size, children }`; returning an empty child list
  stops descent below that node.
- pdu still builds a final `DataTree`, so this is cooperative subtree pruning,
  not an immediate hard abort.

Contract:

```text
Cancellation is product session state.
Custom pdu TreeBuilder may implement cooperative scan pruning as a backend
capability, but partial output is not cleanup authority.
```

Implications:

- `PduEntryProbe` can check `CancellationToken` before metadata/read_dir and
  before returning children;
- when cancellation is observed, the adapter records `CancellationObserved`
  evidence and returns no descendants for that branch;
- output after cancellation must be marked cancelled/partial and must not be
  promoted to current query-ready snapshot unless an explicit policy allows a
  read-only partial view;
- `FsTreeBuilder` path remains best-effort stale-output discard only;
- helper process hard abort remains the stronger future boundary for scans that
  must stop immediately.

Top 3 cancellation implementation strategies:

1. Custom `TreeBuilder` cooperative pruning plus publish-gate discard - 🎯 8
   🛡️ 8 🧠 7, roughly 700-1800 LOC.
   Accepted target after the scan-only MVP fake backend exists. It improves UX
   without forking pdu.
2. `FsTreeBuilder` stale-output discard only - 🎯 8 🛡️ 7 🧠 4, roughly
   300-900 LOC.
   Acceptable MVP fallback, but cancel latency can be poor on huge trees.
3. Fork pdu for a native cancellation token now - 🎯 5 🛡️ 8 🧠 9, roughly
   2500-7000 LOC.
   Deferred until pdu adapter tests prove cooperative pruning is insufficient.

### DataTree Sort And Retain Are Presentation Helpers

Source fact:

- `DataTree::par_sort_by` recursively sorts children and uses
  `sort_unstable_by`.
- `DataTree::par_retain` removes children in place.
- `par_cull_insignificant_data` is behind pdu `cli` and removes descendants
  below a root-relative ratio.

Contract:

```text
pdu sort/cull/retain are adapter diagnostics or one-off conversion helpers.
Product query order, filters, top lists, and visible tree state are read-model
index concerns.
```

Implications:

- do not mutate the authoritative scan arena to answer one UI sort/filter;
- query sort order must include stable tie breakers;
- filtered-out nodes are not absent from snapshot truth unless the scan policy
  explicitly says the snapshot is partial;
- top-K views should use bounded indexes, not full tree resort for every query.
- pdu `min_ratio`/cull may be useful for CLI display, but product "hidden
  because too small" is a display projection and must not delete snapshot truth.

Top 3 cull/sort strategies:

1. Store full accepted snapshot, expose cull/sort as read-model projection -
   🎯 9 🛡️ 10 🧠 7, roughly 700-1800 LOC.
   Accepted. It preserves truth while keeping UI queries fast.
2. Apply pdu cull/sort before storing product snapshot - 🎯 4 🛡️ 4 🧠 3,
   roughly 200-700 LOC.
   Rejected. It makes omitted nodes disappear from product truth.
3. Never support cull/prune/top projection - 🎯 5 🛡️ 6 🧠 2, roughly
   100-300 LOC.
   Rejected for UX. Large disks need projections, but projections must be
   explicit.

### pdu Projection Pipeline Order Is CLI Policy

Source fact:

- pdu `Sub::run` scans all roots first.
- for multiple roots, it creates a fake empty-name root, then later renames it
  to `(total)` for display/JSON.
- after reporter teardown, pdu optionally culls by `min_ratio`.
- after culling, pdu optionally sorts with descending size.
- after sorting, pdu runs hardlink dedupe mutation.
- JSON export happens after these projection mutations.

Contract:

```text
Clean Disk snapshot truth is captured before pdu CLI projection pipeline.
Any cull, sort, fake-root rename, or dedupe result is a named projection.
```

Implications:

- do not benchmark pdu CLI output as if it were raw scan output;
- do not import pdu JSON as current product snapshot truth;
- multi-root virtual root is product-owned and should not be inherited from the
  CLI `(total)` behavior;
- deduped and culled views need `ProjectionPolicy` ids and explicit
  completeness state;
- top files/folders are read-model queries, not mutations of the scan tree.

Top 3 projection-pipeline strategies:

1. Product projection pipeline after validated snapshot ingestion - 🎯 9 🛡️ 10
   🧠 7, roughly 800-2000 LOC.
   Accepted. It preserves measured truth and lets UI projections evolve.
2. Reuse pdu CLI projection order as product behavior - 🎯 4 🛡️ 4 🧠 2,
   roughly 150-500 LOC.
   Rejected. It mixes display pruning, sorting, fake-root naming, hardlink
   accounting, and JSON export.
3. No projections until after MVP - 🎯 7 🛡️ 8 🧠 2, roughly 50-200 LOC.
   Acceptable for strict scan-only MVP, but the contracts must already reserve
   projection policy fields.

### Ratio Threshold Must Reject NaN

Source fact:

- pdu `Fraction(f32)` is documented as a value greater than or equal to 0 and
  less than 1.
- `Fraction::new(value)` rejects `value >= 1.0` and `value < 0.0`.
- `NaN` satisfies neither comparison, so `Fraction::new(f32::NAN)` can pass.
- Rust `f32::is_finite` is the explicit check for neither infinite nor NaN.
- pdu `par_cull_insignificant_data(min_ratio: f32)` multiplies root size by
  the raw ratio and prunes by floating-point comparison.

Contract:

```text
RatioThreshold is product-owned.
No raw float threshold crosses protocol or reaches pdu without finite/range
validation.
```

Implications:

- define product `RatioThreshold` or `DisplayPruneThreshold` as a value object;
- accept only finite values inside the product-approved range;
- prefer stable external representation such as basis points, decimal string,
  or integer percent units over unvalidated floating JSON numbers;
- never let pdu `Fraction` be the first validation layer;
- pruning/culling thresholds are display/query policy, not snapshot truth.

Top 3 ratio strategies:

1. Product ratio newtype with finite/range validation - 🎯 9 🛡️ 10 🧠 5,
   roughly 300-900 LOC.
   Accepted. It avoids NaN, protocol ambiguity, and backend-specific validation
   leakage.
2. Reuse pdu `Fraction` as application input - 🎯 4 🛡️ 5 🧠 2, roughly
   50-200 LOC.
   Rejected. It is a pdu adapter detail and can accept `NaN`.
3. Let Flutter send raw `double` and rely on backend behavior - 🎯 3 🛡️ 3 🧠 1,
   roughly 20-100 LOC.
   Rejected. It makes UI/runtime quirks part of scan semantics.

### pdu Builder Names Are Not Path Authority

Source fact:

- `FsTreeBuilder` root name is built from the root `PathBuf`.
- child nodes carry `OsStringDisplay` names returned by `DirEntry::file_name`.
- child paths are reconstructed internally by `prefix.join(&name.0)`.
- `DataTree` does not retain full paths.

Contract:

```text
pdu names are path components and display evidence.
Clean Disk path authority belongs to platform path and identity ports.
```

Implications:

- `NodeArenaWriter` must reconstruct path context during conversion if needed,
  but cleanup authority still requires later platform revalidation.
- display path can be lossy/redacted; native path authority must stay in Rust
  platform adapters.
- root node and child node names must be tagged differently because pdu root
  name can represent a full input path while child names are components.

### Path Display Is Not Path Authority

Source fact:

- `OsStringDisplay` displays the inner OS string as UTF-8 only when
  `OsStr::to_str` succeeds; otherwise it writes Debug formatting.
- `ErrorReport::TEXT` formats `path` with Debug and writes terminal text through
  pdu's global status board.
- pdu JSON output converts tree names with `par_convert_names_to_utf8()` and the
  CLI source still carries a `TODO: allow non-UTF8 somehow`.
- Rust `OsStr` encoding is platform-specific; non-UTF-8 encoded bytes are
  opaque and not safe as durable/network identity.

Contract:

```text
DisplayPath, PathAuthority, and LogRedaction are separate product concepts.
pdu Display, Debug path text, terminal text, and pdu JSON strings are never
cleanup authority.
```

Implications:

- UI receives display projections, not native path authority.
- the reusable Rust library may keep opaque native path handles/evidence, but
  protocol DTOs must not rely on pdu `Display` or `Debug` path text;
- logs, metrics, support bundles, and WebSocket events must never forward pdu
  terminal text as-is;
- path equality, selection, queue membership, and delete preflight use
  `PathAuthorityRef` plus platform identity revalidation;
- non-UTF-8 names need a valid UI display fallback and a redaction/privacy class,
  not a crash or forced UTF-8 conversion.

Top 3 path strategies:

1. Native path authority plus redacted display projection - 🎯 10 🛡️ 10 🧠 7,
   roughly 800-1800 LOC.
   Accepted. This keeps deletion safe, protocol portable, and UI usable with
   non-UTF-8 names.
2. Store UTF-8 strings as path authority - 🎯 4 🛡️ 4 🧠 3, roughly
   300-900 LOC.
   Rejected. It breaks on non-UTF-8 paths and creates false equality/security
   assumptions.
3. Use pdu `OsStringDisplay`/Debug output in protocol - 🎯 2 🛡️ 2 🧠 2,
   roughly 100-300 LOC.
   Rejected. It is formatting, not a stable contract.

### Symlink And Link Policy Must Be Product-Owned

Source fact:

- `FsTreeBuilder` imports and uses `std::fs::symlink_metadata`, not
  `metadata`, for the root and for every visited path.
- directory traversal is guarded by `stats.is_dir()` from that symlink metadata,
  so a symlink to a directory is not treated as a normal traversable directory
  by the default pdu path.
- pdu hardlink handling is separate from symlink handling; hardlink evidence
  does not describe symlink/reparse safety.
- pdu's overlapping-path cleanup in the Unix hardlink-aware CLI path explicitly
  avoids treating symlinks as normal directories.

Contract:

```text
TraversalPolicy and LinkPolicy are product-owned.
pdu's default symlink behavior is backend evidence, not universal product
policy.
```

Implications:

- default scan policy should be `DoNotFollowLinks` unless a future mode makes
  link following explicit and visible;
- Windows reparse points, junctions, WSL paths, cloud placeholders, and FUSE
  mounts need platform evidence outside pdu's generic tree model;
- cleanup preflight must never follow a link unexpectedly when validating a
  queued item;
- UI warnings should distinguish symlink/reparse/mount/cloud-placeholder
  situations instead of collapsing them into "file" or "folder";
- `DataTree` leaves are not enough to infer whether a thing is a file, empty
  directory, unreadable directory, symlink, reparse point, max-depth collapsed
  subtree, or boundary leaf.

Top 3 link-policy strategies:

1. Explicit `LinkPolicy::DoNotFollowByDefault` plus platform issue evidence -
   🎯 9 🛡️ 9 🧠 6, roughly 700-1600 LOC.
   Accepted. It matches pdu's current scan behavior and keeps destructive flows
   conservative.
2. Follow symlinked directories during scan when possible - 🎯 4 🛡️ 4 🧠 7,
   roughly 1200-3500 LOC.
   Deferred. Useful for an expert mode, but easy to double-count, cross trust
   boundaries, or delete the wrong target.
3. Ignore link type in the product model - 🎯 2 🛡️ 2 🧠 1, roughly
   100-300 LOC.
   Rejected. It makes cleanup safety and size accounting dishonest.

### TOCTOU And Moving Files During Scan

Source fact:

- pdu stats a path, later may read the directory, and later maps child names to
  child paths. The filesystem can change between all of those steps.
- if `symlink_metadata`, `read_dir`, or entry access fails, pdu reports an error
  through the reporter and still returns a tree with default/partial evidence.
- hardlink code can observe conflicts when the same inode appears with
  inconsistent size/link-count evidence.
- a final pdu tree is therefore evidence observed during scan, not current
  filesystem authority.

Contract:

```text
ScanSnapshot is evidence at scan time.
DeletePlan requires current platform identity revalidation.
```

Implications:

- every destructive command must validate current path, node identity, type,
  metadata, policy, and authority immediately before Trash/delete;
- scan issues need reasons such as `missing_during_scan`,
  `changed_during_scan`, `permission_changed`, `metadata_race`, and
  `hardlink_conflict`;
- search/top-files/details can be stale by design, so the UI must mark stale or
  degraded snapshots instead of silently treating them as live truth;
- retry/refresh should be a first-class command, not an accidental side effect
  of clicking delete;
- remote/headless mode must preserve the same rule. A cached snapshot from a
  server is not delete authority either.

Top 3 TOCTOU strategies:

1. Treat scan as evidence and require delete preflight revalidation - 🎯 10
   🛡️ 10 🧠 6, roughly 900-2200 LOC.
   Accepted. This is the correct safety boundary for desktop, web UI, and
   remote/headless.
2. Try to lock/freeze filesystem state during scan - 🎯 2 🛡️ 5 🧠 10,
   roughly 5000-15000 LOC.
   Rejected for MVP. It is not generally available cross-platform and would
   create permission/UX problems.
3. Ignore races until delete fails - 🎯 3 🛡️ 3 🧠 2, roughly 100-400 LOC.
   Rejected. It produces confusing partial failures and unsafe stale authority.

### Multi-Target Scans Need Product Semantics

Source fact:

- pdu CLI scans `"."` when no files are provided.
- when more than one target is provided, pdu creates a fake root with an empty
  internal name, later renamed to `(total)` for display.
- pdu uses `into_par_retained` around the fake root to fit CLI max-depth
  behavior.
- pdu removes overlapping paths only in the Unix hardlink-deduplication path,
  preferring the containing tree and the first duplicate.

Contract:

```text
ScanTargetSet, VirtualRootPolicy, and OverlapPolicy are product concepts.
pdu fake roots and CLI defaults must not leak into domain or protocol.
```

Implications:

- the app must not implicitly scan `"."` unless the user explicitly chose the
  current directory;
- multi-root sessions need a stable virtual root with product-owned id,
  display label, policy, and target membership;
- overlapping targets should be detected before scan start and represented as a
  validation/capability decision;
- overlap resolution must be independent of hardlink mode;
- UI should explain skipped/merged/duplicated targets through product issues,
  not pdu's `(total)` convention.

### Empty Target Default Is A CLI Convenience

Source fact:

- pdu `Sub::run` recursively re-runs itself with `files: vec![".".into()]` when
  no target is provided.
- pdu README says zero or one CLI argument uses a real root name, either `.`
  or the provided name.

Contract:

```text
The product must never scan an implicit target without user intent evidence.
```

Implications:

- desktop first-run can offer suggested targets, but the scan request must carry
  an explicit `ScanTargetSet`;
- remote/headless API must reject empty target sets unless a named server-side
  profile intentionally expands them;
- receipts and history must record which target was selected, not "default";
- tests must prove no empty request can accidentally scan the daemon's working
  directory.

### pdu Overlap Removal Is A Hardlink CLI Policy

Source fact:

- pdu removes overlapping paths only when Unix hardlink deduplication is enabled
  and more than one target was provided.
- it canonicalizes only paths that are real directories and not symlinks.
- canonicalization errors are ignored by turning that target into no real path
  for overlap comparison.
- the algorithm prefers the containing tree and removes later duplicates.

Contract:

```text
OverlapPolicy is product-owned and independent of hardlink mode.
```

Implications:

- target normalization must run before backend selection;
- overlapping target decisions must become explicit validation output:
  accepted, merged, rejected, duplicated, inaccessible, or unresolved;
- symlink, junction, mount, network, and cloud roots need platform evidence, not
  only `canonicalize`;
- pdu overlap removal can inform tests, but must not silently mutate the user's
  target set.

Top 3 target overlap strategies:

1. Product target normalization and explicit overlap policy - 🎯 9 🛡️ 10 🧠 7,
   roughly 800-2200 LOC.
   Accepted. It is required for safe history, compare, cleanup, and remote mode.
2. Reuse pdu overlap removal only when hardlinks are enabled - 🎯 4 🛡️ 4 🧠 2,
   roughly 100-300 LOC.
   Rejected. It changes behavior based on unrelated hardlink mode.
3. Allow duplicates/overlap silently - 🎯 3 🛡️ 3 🧠 1, roughly 50-150 LOC.
   Rejected. It produces confusing totals and unsafe cleanup intent.

## Layer Ownership Table

Use this table when deciding where a type or function belongs.

| Concept | Domain `fs_usage_core` | Application `fs_usage_engine` | Data/infrastructure adapters | Host/protocol/UI |
| --- | --- | --- | --- | --- |
| scan target | `ScanTarget`, `TargetScope` | validates use-case input | platform probes existence/access | DTO and picker model |
| scan lifecycle | state vocabulary only | `ScanSession`, state machine | backend start/stop evidence | HTTP commands, UI controls |
| pdu execution | never | `ScannerBackend` port only | `PduScannerBackend` | server wires concrete backend |
| tree node identity | `NodeId`, `NodeRef` | arena allocates/stores refs | maps pdu traversal into records | DTO renders refs, not pdu ids |
| path display | `DisplayPath`, privacy class | projection policy | native path conversion/redaction | localized UI text |
| native path authority | opaque evidence value | command/preflight flow | platform identity adapter | never in UI authority |
| link policy | `LinkPolicy`, `TraversalPolicy` | validates target policy | symlink/reparse/mount evidence | warnings and disabled actions |
| size truth | `SizeFact`, unit semantics | measurement policy | pdu/platform/accounting adapters | string-safe DTOs, formatted view |
| ordering | stable sort vocabulary only | read-model indexes and tie-breakers | optional backend order evidence | UI sort controls and cursors |
| depth policy | `DepthLimit`, completeness state | hidden-descendant markers | pdu max-depth mapping | visible disclosure state |
| progress | event vocabulary | sequence, throttling, finality | pdu counter capture | WebSocket DTO, UI status |
| errors/issues | `ScanIssueReason` | issue aggregation | pdu/platform error mapping | localized display |
| search/filter/sort | query vocabulary | indexes and pages | optional backend indexes later | UI query controls |
| cleanup | `DeletePlan` concepts | build/validate plan | trash/accounting adapters | confirmation UI |
| diagnostics | privacy classes | support bundle policy | raw evidence behind redaction | explicit export action |

Rule:

```text
If a type mentions pdu, std::fs::Metadata, io::Error, PathBuf authority,
Rayon, Tokio, HTTP, WebSocket, Flutter, serde DTOs, or terminal display, it is
not a domain type.
```

## pdu API Surface Classification Before Coding

docs.rs and local source show that pdu exposes library, CLI, JSON, terminal,
hardlink, reporter, size, and visualizer surfaces from the same crate. Treat
this as a broad upstream toolbox, not as a clean product boundary.

Production imports allowed only inside `fs_usage_pdu`:

```text
parallel_disk_usage::fs_tree_builder::FsTreeBuilder
parallel_disk_usage::tree_builder::{TreeBuilder, info::Info}
parallel_disk_usage::data_tree::DataTree
parallel_disk_usage::reporter::{Reporter, Event, ErrorReport}
parallel_disk_usage::get_size::{GetApparentSize, GetBlockSize, GetBlockCount}
parallel_disk_usage::device::DeviceBoundary
parallel_disk_usage::hardlink::{RecordHardlinks, HardlinkIgnorant, HardlinkAware}
parallel_disk_usage::size::{Bytes, Blocks}
parallel_disk_usage::os_string_display::OsStringDisplay
```

Diagnostics or fixture imports only:

```text
parallel_disk_usage::json_data::*
parallel_disk_usage::data_tree::reflection::Reflection
parallel_disk_usage::hardlink::*Reflection
parallel_disk_usage::visualizer::*
parallel_disk_usage::bytes_format::*
```

Forbidden in production daemon scan path:

```text
parallel_disk_usage::app::*
parallel_disk_usage::args::*
parallel_disk_usage::runtime_error::RuntimeError
parallel_disk_usage::status_board::*
parallel_disk_usage::main
```

Important source facts:

- pdu `lib.rs` gates `app`, `args`, `runtime_error`, and CLI re-exports behind
  the `cli` feature, but modules such as `visualizer`, `status_board`,
  `bytes_format`, and `json_data` are still part of the library surface;
- `JsonData` is explicitly the output of `--json-output` and input of
  `--json-input`, with `schema_version`, optional binary version, unit-tagged
  body, tree, and shared hardlink data;
- `Reflection` has public fields for tests/inspection and validates only a
  narrow tree invariant when converting back into `DataTree`;
- `app::sub::Sub` mixes scan execution, empty-target `"."` default, multi-root
  fake root, progress reporter destruction, cull, sort, hardlink dedupe, JSON
  serialization, terminal clearing, visualization, and hardlink report printing.

Contract:

```text
fs_usage_pdu is an anti-corruption adapter.
No pdu type is part of public domain, application, protocol, Flutter, or cache
contracts.
```

Top 3 API-surface policies:

1. Strict pdu import allowlist plus CI import check - 🎯 10 🛡️ 10 🧠 5,
   roughly 200-700 LOC.
   Accepted. It turns architecture into a mechanical rule and prevents quiet
   leakage of CLI/JSON/terminal concepts.
2. Developer convention only - 🎯 5 🛡️ 5 🧠 1, roughly 0-100 LOC.
   Too weak. The crate exposes many tempting helpers that look useful but carry
   wrong responsibilities.
3. Wrap pdu behind one facade but allow any pdu import under `rust/` - 🎯 6
   🛡️ 5 🧠 3, roughly 200-500 LOC.
   Not enough. A facade helps, but imports still leak upstream concepts into
   engine and host code.

### Where Ports Live In This Rust Architecture

Decision:

```text
Domain owns vocabulary and invariants.
Application owns ports and use cases.
Infrastructure implements ports.
Host wires concrete adapters.
```

Why ports are in application, not domain:

- `ScannerBackend`, `MetadataReader`, `TrashAdapter`, and
  `ReclaimAccountingAdapter` are conversations needed by use cases;
- pure domain value objects should be reusable without a scanner, database,
  daemon, or platform service;
- keeping ports in application prevents "repository-shaped" dependencies from
  looking like domain concepts;
- tests can drive use cases with fake adapters without importing pdu or OS APIs.

Top 3 port placement strategies:

1. Ports in `fs_usage_engine/application/ports` - 🎯 10 🛡️ 10 🧠 5, roughly
   300-900 LOC.
   Accepted. It matches our Flutter feature package rule and keeps domain pure.
2. Ports in `fs_usage_core/domain` - 🎯 5 🛡️ 6 🧠 4, roughly 250-800 LOC.
   Rejected for this project. It makes external conversations look like domain
   model.
3. Ports only in host/server crate - 🎯 4 🛡️ 4 🧠 3, roughly 150-500 LOC.
   Rejected. It would make the reusable engine hard to test and reuse.

Folder implication:

```text
rust/crates/fs_usage_core/src/
  domain/
    scan/
    tree/
    size/
    path/
    issue/
    policy/

rust/crates/fs_usage_engine/src/
  application/
    ports/
    use_cases/
    sessions/
    read_model/
    queries/

rust/crates/fs_usage_pdu/src/
  adapter/
    scanner/
    reporter/
    conversion/
    hardlinks/
    capabilities/
    diagnostics/
```

## Backend Output Contract Shape

The pdu adapter should not return `DataTree` directly to the engine. It should
return a product-shaped backend output that carries evidence and limitations.

Recommended internal shape:

```text
ScannerBackend::scan(request, sink, cancel) -> BackendScanOutput

BackendScanOutput
  backend_id
  backend_version
  target_evidence
  measurement_profile
  tree_draft
  issues
  hardlink_evidence
  boundary_evidence
  resource_evidence
  completion_state
  capability_snapshot

ScanSnapshotDraft
  snapshot_id
  root_node_ref
  node_arena_records
  hidden_descendant_markers
  aggregate_size_facts
  scan_quality

NodeArenaRecord
  node_id
  parent_node_id
  display_name
  display_path_ref
  path_authority_ref
  node_kind_evidence
  size_facts
  child_count_state
  issue_refs
  metadata_state
```

Top 3 backend output shapes:

1. Product-shaped `BackendScanOutput` with pdu evidence private - 🎯 10 🛡️ 10
   🧠 7, roughly 900-2200 LOC.
   Accepted. Clean, testable, replaceable, and compatible with future scanners.
2. Return `DataTree` plus separate vectors from `fs_usage_pdu` - 🎯 6 🛡️ 6
   🧠 4, roughly 400-1000 LOC.
   Too leaky. The engine would start depending on pdu traversal and semantics.
3. Return protocol DTOs directly from `fs_usage_pdu` - 🎯 2 🛡️ 2 🧠 3,
   roughly 300-800 LOC.
   Rejected. It collapses adapter, application, protocol, and UI boundaries.

Mapping rule:

```text
PduRawScanResult -> PduTreeConverter -> ScanSnapshotDraft -> ReadModelIndexes
```

No layer after `PduTreeConverter` should need to know that pdu produced the
initial tree.

## Evidence, Fact, Projection, Authority Taxonomy

pdu gives us useful observations. The product needs stricter language before
those observations become UI rows, protocol DTOs, indexes, or cleanup input.

Taxonomy:

| Class | Meaning | Examples | Can authorize cleanup? |
| --- | --- | --- | --- |
| Raw adapter evidence | Direct observation from pdu/platform at scan time | `DataTree.size`, pdu reporter error, hardlink event, metadata read | No |
| Product fact | Validated product value object with source, semantics, exactness, confidence | `SizeFact`, `NodeKindEvidence`, `ScanIssueDraft`, `PathAuthorityRef` | No by itself |
| Projection | Derived view for display/query/analysis | sorted page, top files, hardlink-adjusted view, cull-filtered view, donut chart | No |
| Capability | What the backend/run can prove | `ScannerCapabilitySnapshot`, `AdapterDecisionRecord` | No |
| Current authority | Fresh validation under current filesystem identity and policy | delete preflight identity match, current permission check, user confirmation | Yes, through use case only |

Contract:

```text
No field is "just size", "just path", or "just node state".
Every outward value is evidence, fact, projection, capability, or authority.
```

Rules:

- pdu `DataTree` is raw adapter evidence;
- pdu reporter events are raw adapter evidence;
- `SizeFact` is a product fact only after mapping kind, unit semantics, source,
  exactness, and confidence;
- sorted/cull/deduped/hardlink-adjusted outputs are projections and must carry
  `ProjectionPolicy`;
- protocol DTOs expose product facts and projections, never raw pdu evidence
  unless the DTO is explicitly diagnostic;
- cleanup commands accept only current authority from delete preflight, not
  scan facts or projections.

Top 3 semantic-taxonomy strategies:

1. First-class evidence/fact/projection/authority taxonomy - 🎯 10 🛡️ 10 🧠 6,
   roughly 700-1800 LOC.
   Accepted. It prevents pdu scan truth, UI display truth, and cleanup authority
   from collapsing into one unsafe model.
2. Use naming conventions only - 🎯 5 🛡️ 5 🧠 2, roughly 100-300 LOC.
   Rejected as sufficient. Names drift quickly once DTOs, cache, and UI stores
   appear.
3. Treat every scan output as fact until delete preflight - 🎯 4 🛡️ 4 🧠 3,
   roughly 200-600 LOC.
   Rejected. It would let stale/projection values influence UX and tests too
   early.

## Domain Contract Shape From pdu Facts

Domain must model product truth, not pdu mechanics.

Domain value objects required before the pdu adapter:

```text
ScanTarget
ScanTargetSet
TargetScope
TraversalPolicy
BoundaryPolicy
LinkPolicy
DepthPolicy
MeasurementProfile
SizeFact
SizeKind
NodeId
NodeRef
SnapshotId
DisplayPath
PathAuthorityRef
NodeKindEvidence
ScanIssueReason
ScanIssueSeverity
ScanQuality
EvidenceConfidence
BackendCapabilityCode
ProjectionPolicy
```

Domain invariants:

- a display path is never path authority;
- a scan snapshot is never current delete authority;
- `SizeFact` must carry kind, unit semantics, source, exactness, and confidence;
- hardlink-adjusted, cull-filtered, sorted, depth-collapsed, and display-rounded
  values are projections, not measured truth;
- unknown capability fails closed for destructive workflows;
- exact ids, counters, and sizes are not localized strings and not lossy JSON
  numbers;
- node identity is snapshot-local unless a platform identity adapter proves a
  stronger identity;
- domain does not depend on pdu, `std::fs::Metadata`, `PathBuf`, `io::Error`,
  Rayon, Tokio, serde DTOs, HTTP, WebSocket, Flutter, or cache schema.

What domain should not contain:

```text
PduScanSession
DataTreeNode
ReporterEvent
JsonData
FsTreeBuilderConfig
RayonThreadPolicy
PathBuf authority
io::Error
BytesFormat
RuntimeError
```

Top 3 domain-model strategies:

1. Product vocabulary with anti-corruption mapping from pdu - 🎯 10 🛡️ 10
   🧠 7, roughly 900-2200 LOC.
   Accepted. It keeps pdu replaceable and makes cleanup safety explicit.
2. Rebrand pdu `DataTree` as our domain tree - 🎯 3 🛡️ 3 🧠 2, roughly
   200-600 LOC.
   Rejected. It loses kind, self-size, path authority, issues, capabilities,
   query identity, and cleanup semantics.
3. Minimal domain with only `NodeId` and `size_bytes` - 🎯 5 🛡️ 4 🧠 2,
   roughly 300-800 LOC.
   Too weak. It would force later breaking changes for hardlinks, sparse files,
   APFS/NTFS accounting, permissions, and remote/headless support.

## Application Port Contract From pdu Facts

The application layer should talk to a scanner backend through a product-shaped
port. pdu details stay behind the adapter.

Recommended port shape:

```text
ScannerBackend::start_scan(
  request: ScanRequest,
  events: ScanEventSink,
  cancel: CancellationToken,
) -> BackendScanOutput

ScanRequest
  scan_session_id
  target_set
  traversal_policy
  boundary_policy
  link_policy
  depth_policy
  measurement_profile
  resource_profile
  output_requirements
  privacy_profile

BackendScanOutput
  backend_run_id
  backend_identity
  capability_snapshot
  completion_state
  phase_timings
  snapshot_draft
  issue_store
  evidence_store
  adapter_diagnostics
```

Application events should be product events, not pdu reporter events:

```text
ScanStarted
PhaseChanged
TraversalProgressSampled
IssueObserved
ResourcePressureObserved
CancellationRequested
FinalizingSnapshot
SnapshotReady
ScanFailed
ScanDiscarded
```

pdu event mapping:

- `ReceiveData(size)` becomes sampled traversal evidence, not final progress
  truth;
- `EncounterError(ErrorReport)` becomes a copied, owned `ScanIssueDraft`;
- `DetectHardlink(HardlinkDetection)` becomes `HardlinkEvidenceDraft`;
- unknown future pdu events must map to adapter diagnostic and weakened
  capability, not panic by default;
- pdu reporter callbacks must copy borrowed path/metadata before returning.

Top 3 port-contract strategies:

1. Product scanner port with owned events and final output - 🎯 10 🛡️ 10 🧠 7,
   roughly 1000-2400 LOC.
   Accepted. It supports fake backends, pdu, future MFT, remote scanner, and
   test fixtures through the same use cases.
2. Port returns pdu `DataTree` and pdu errors - 🎯 4 🛡️ 4 🧠 3, roughly
   300-800 LOC.
   Rejected. It leaks upstream semantics into application and makes replacement
   expensive.
3. Port returns protocol DTOs directly - 🎯 3 🛡️ 3 🧠 4, roughly 500-1100 LOC.
   Rejected. It binds reusable engine code to transport and Flutter/web
   concerns.

### Command And Query Boundaries

The scanner domain is read-heavy, but the lifecycle is command-driven. Keep
commands and queries separate in the application layer even if MVP stores both
state and read models in one process.

Source fact:

- CQRS guidance separates write operations/commands from read operations/queries
  and lets read models be optimized for retrieving data. Clean Disk borrows this
  separation without requiring separate databases, event sourcing, or
  microservices in MVP.

Application commands:

```text
CreateScanSession
StartScan
CancelScan
DisposeScanSession
RefreshTargetCapabilities
BuildDeletePlan
ConfirmDeletePlan
ExecuteDeletePlan
```

Application queries:

```text
GetScanStatus
GetChildrenPage
GetNodeDetails
SearchNodes
GetTopItems
GetCapabilitySnapshot
GetAdapterDecisionRecord
GetScanIssues
```

Rules:

- queries never start scans, refresh metadata, mutate sessions, mutate queues,
  or create delete authority;
- commands return ids, acknowledgements, state summaries, or operation receipts,
  not full recursive trees;
- WebSocket events invalidate or reconcile client state, but they are not the
  full query truth;
- read-model query ports require `SnapshotId`, `IndexVersion`, and cursor/query
  shape where pagination is involved;
- `DeletePlan` is a command workflow, not a selected-row query result;
- Flutter stores may cache query pages, but cached pages never become cleanup
  authority.

Top 3 command/query strategies:

1. Command/query split in `fs_usage_engine` with shared in-process read model -
   🎯 9 🛡️ 10 🧠 6, roughly 600-1500 LOC.
   Accepted. It keeps MVP practical while protecting lifecycle and delete
   authority from read-model shortcuts.
2. One scanner service with commands and queries mixed - 🎯 5 🛡️ 5 🧠 3,
   roughly 300-900 LOC.
   Rejected as a contract. It is easy to accidentally make a query refresh
   metadata, publish stale output, or create implicit delete authority.
3. Full CQRS with separate persistence/event-sourcing from day one - 🎯 5 🛡️ 8
   🧠 9, roughly 2500-7000 LOC.
   Deferred. Useful if remote/headless history becomes central, but too much
   infrastructure before the scanner contract is proven.

### Scan Phases Are Product-Owned

pdu gives us traversal and final tree construction. The product operation is
larger than that.

Product phase model:

```text
TargetValidation
CapabilityProbe
Traversal
PduTreeIngestion
SnapshotValidation
IndexBuild
MetadataEnrichment
PublicationGate
QueryReady
```

Contract:

```text
pdu traversal completion is not scan-session completion.
A snapshot becomes visible only after product validation, indexing, and publish
gate succeed for the same session epoch.
```

Implications:

- progress UI must show traversal separately from finalizing/indexing;
- cancellation after traversal but before publish must still prevent current
  snapshot promotion;
- benchmarks must report pdu traversal time and product query-ready time;
- cleanup and delete-plan actions require `QueryReady` plus current capability
  and current preflight validation;
- failures during ingestion/indexing are product failures even if pdu traversal
  succeeded.

Top 3 phase-boundary strategies:

1. Explicit operation state machine with publish gate - 🎯 10 🛡️ 10 🧠 7,
   roughly 900-2200 LOC.
   Accepted. It protects UI truth, cancellation, and cleanup authority.
2. Mark scan complete when pdu returns `DataTree` - 🎯 4 🛡️ 4 🧠 2, roughly
   200-500 LOC.
   Rejected. It hides conversion/index failures and makes late cancellation
   unsafe.
3. Stream partial UI rows before snapshot validation - 🎯 5 🛡️ 5 🧠 7, roughly
   1200-3000 LOC.
   Deferred. Useful later, but risky before read-model and authority semantics
   are proven.

### pdu-backed Protocol DTO Semantics

Clean Disk protocol DTOs are product contracts. pdu's JSON/reflection schema,
type names, operation names, and display strings are backend provenance only.

Protocol rule:

```text
ProtocolVersion != PduSchemaVersion != BackendVersion.
```

DTO rules:

- no public DTO field or type is named after pdu internals such as `DataTree`,
  `FsTreeBuilder`, `PduEvent`, `RuntimeError`, `Reflection`, or `JsonData`;
- pdu version, features, selected scan path, and source audit facts may appear
  only in capability/diagnostic DTOs as backend provenance;
- exact byte sizes, block counts, node ids, cursors, event sequence numbers, and
  large counters use web-safe encoding where Flutter web could lose integer
  precision;
- protocol reason codes are product codes such as
  `scan_issue.permission_denied`, not raw pdu operation names;
- unknown protocol enum values decode into unknown/degraded states and fail
  closed for destructive actions;
- `snapshotId`, `indexVersion`, `queryCursor`, `protocolVersion`, and
  `capabilitySnapshotId` are product ids, not pdu traversal indexes.

Top 3 DTO boundary strategies:

1. Product DTOs with pdu provenance only in diagnostics/capabilities - 🎯 10
   🛡️ 10 🧠 6, roughly 700-1800 LOC.
   Accepted. It keeps daemon/web/Flutter compatibility independent from pdu
   upgrades and lets future backends fit the same API.
2. pdu-shaped DTOs in daemon responses - 🎯 3 🛡️ 3 🧠 2, roughly 200-700 LOC.
   Rejected. It turns upstream implementation details into public compatibility
   debt.
3. Generated OpenAPI DTOs reused as Rust domain/application models - 🎯 4 🛡️ 5
   🧠 4, roughly 400-1200 LOC.
   Rejected. Codegen is useful at protocol boundaries, but domain invariants
   need owned Rust types.

## Data Infrastructure Adapter Contract From pdu Facts

`fs_usage_pdu` should be a small set of single-responsibility adapters, not one
large scanner object.

Recommended internal components:

```text
PduScannerBackend
  orchestrates one backend run and implements ScannerBackend.

PduScanRunner
  chooses FsTreeBuilder versus custom TreeBuilder path and owns worker boundary.

PduEntryProbe
  owns symlink_metadata/read_dir/size/kind/self-size/device/link side effects
  when custom TreeBuilder is used.

PduReporterRecorder
  implements pdu Reporter, copies borrowed data, stores issues/evidence, and
  emits coalesced product events.

PduHardlinkRecorder
  preserves hardlink add conflicts instead of letting FsTreeBuilder drop them.

PduTreeConverter
  converts DataTree into ScanSnapshotDraft/NodeArenaWriter and attaches side
  store evidence.

PduCapabilityMapper
  produces ScannerCapabilitySnapshot for exact build, OS, feature flags, target
  policy, and selected scan path.

PduDiagnosticsMapper
  maps upstream errors, panics, impossible evidence, and timings into redacted
  adapter diagnostics.
```

Adapter design rules:

- `PduScannerBackend` is the only public adapter type the engine needs;
- pdu `DataTree` is consumed during conversion and then can be dropped;
- side stores are keyed by adapter-owned traversal evidence, then converted
  into product ids during arena ingestion;
- `FsTreeBuilder` path is allowed only when required capabilities can be marked
  unknown or lazy;
- custom `TreeBuilder` path is required when scan-time node kind, self-size,
  boundary issue precision, or hardlink conflict capture is required;
- pdu CLI `Sub` is not a reusable service object and must not be called in
  production.

Top 3 adapter organization strategies:

1. Several small pdu adapter components behind one backend - 🎯 9 🛡️ 10 🧠 7,
   roughly 1400-3200 LOC.
   Accepted. This follows SRP and keeps each upstream coupling testable.
2. One `PduScannerBackend` with all logic inline - 🎯 6 🛡️ 6 🧠 4, roughly
   700-1800 LOC.
   Faster at first, but harder to test, profile, and replace piece by piece.
3. Reuse pdu `app::Sub` as the adapter - 🎯 2 🛡️ 2 🧠 2, roughly
   150-500 LOC.
   Rejected. It mixes CLI defaults, terminal output, JSON, cull, sort, dedupe,
   and scan execution in one host-level flow.

### Output Requirements Choose The pdu Path

The application should request product capabilities, not a concrete pdu mode.
The adapter then chooses the cheapest safe pdu path that satisfies the request
or returns a capability gap.

Source fact:

- pdu `FsTreeBuilder` is a convenient filesystem wrapper, but it loses node
  kind, self-size, precise child metadata, and hardlink recorder errors in its
  default path;
- pdu generic `TreeBuilder` lets our adapter own `get_info` and `join_path`,
  so it can capture side-store evidence while still using pdu's parallel
  `DataTree` construction;
- pdu `app::Sub::run` mixes scan, fake root handling, reporter teardown, cull,
  sort, hardlink dedupe, JSON conversion, terminal clearing, and visualization;
- pdu `app::overlapping_arguments` is hardlink-deduplication support code, not
  product target-normalization policy.

Recommended request model:

```text
BackendScanRequest
  target_set
  traversal_policy
  measurement_profile
  resource_profile
  privacy_profile
  output_requirements

OutputRequirements
  needs_node_kind_index
  needs_top_files_index
  needs_self_size
  needs_hardlink_conflict_evidence
  needs_boundary_issue_precision
  needs_traversal_depth_cutoff
  needs_allocated_size
  needs_delete_plan_eligibility
```

Adapter selection matrix:

| Requirement | `FsTreeBuilder` path | custom `TreeBuilder` path | Future backend |
| --- | --- | --- | --- |
| scan-only aggregate tree | good | good | good |
| visible-row lazy details | acceptable | good | good |
| accurate node-kind index | weak/lazy | good | good |
| top files without second metadata pass | weak | good | good |
| self-size evidence | weak/lazy | good | good |
| hardlink conflict preservation | weak | good with custom recorder | platform-specific |
| true traversal depth cutoff | weak | good through probe guard | good |
| allocated size on Unix | good | good | good |
| allocated size on Windows | weak | weak | MFT/platform adapter |
| cleanup eligibility | no | partial evidence only | still needs preflight |

Contract:

```text
Backend selection is an application/adapter negotiation.
The UI asks for product capabilities; it never asks for FsTreeBuilder,
TreeBuilder, pdu JSON, or pdu CLI behavior.
```

Rules:

- if `output_requirements` cannot be satisfied, return
  `BackendCapabilityGap`, not a silently weaker scan;
- scan-only MVP may choose `FsTreeBuilder`, but must mark missing kind/self-size
  facts as unknown or lazy;
- any feature that needs accurate tree-wide node kind, top files, self size,
  hardlink conflicts, or traversal cutoff pushes us toward custom
  `TreeBuilder`;
- cleanup beta must not infer delete safety from either pdu path; it still uses
  platform identity and delete preflight ports;
- `PduScanRunner` owns the choice; domain and Flutter never branch on pdu
  internals.

Top 3 output-negotiation strategies:

1. Typed `OutputRequirements` plus adapter capability negotiation - 🎯 10 🛡️ 10
   🧠 7, roughly 700-1800 LOC.
   Accepted. It keeps MVP simple while preventing accidental overpromises.
2. Hard-code one pdu path for every scan - 🎯 6 🛡️ 5 🧠 2, roughly
   100-300 LOC.
   Rejected as a long-term contract. It hides why some UI features are weak or
   expensive.
3. Expose pdu modes to Flutter/API clients - 🎯 3 🛡️ 3 🧠 3, roughly
   200-600 LOC.
   Rejected. It leaks infrastructure choices into product and external
   protocol.

### Adapter Decision Record Must Travel With The Scan

Choosing a pdu path is not only an implementation detail. It changes what facts
the scan can prove. The final scan output therefore needs a structured decision
record, not only a capability snapshot.

Recommended internal shape:

```text
AdapterDecisionRecord
  backend_id
  backend_version
  backend_fingerprint_id
  requested_output_requirements
  selected_scan_path
    pdu_fs_tree_builder
    pdu_custom_tree_builder
    future_backend
    rejected
  selection_reason_codes[]
  satisfied_requirements[]
  degraded_requirements[]
  rejected_requirements[]
  required_followup_phases[]
  feature_flags_observed[]
  platform_cfg_observed[]
  resource_profile_applied
  measurement_profile_applied
```

Contract:

```text
CapabilitySnapshot says what this backend can do.
AdapterDecisionRecord says what this run actually chose and why.
```

Rules:

- `BackendScanOutput` includes a decision record or a failure explaining why no
  decision could be made;
- UI can show degraded states from product capability/result DTOs, but it never
  learns pdu path names;
- tests assert that `OutputRequirements` drive selection deterministically;
- support bundles may include redacted decision records, but not raw paths or
  user search text;
- decision records are adapter/application evidence, not domain entities.

Top 3 decision-record strategies:

1. Store adapter decision record in every backend output - 🎯 9 🛡️ 10 🧠 6,
   roughly 400-1000 LOC.
   Accepted. It makes capability downgrades, support cases, and pdu upgrades
   explainable.
2. Only log the chosen pdu path - 🎯 5 🛡️ 4 🧠 2, roughly 50-150 LOC.
   Rejected. Logs are not protocol-safe truth and may be redacted or disabled.
3. Decide implicitly from which fields are present - 🎯 3 🛡️ 3 🧠 1, roughly
   50-100 LOC.
   Rejected. Absence is ambiguous: unsupported, skipped, lazy, failed,
   degraded, or not requested.

## Minimum Type Slice Before Writing pdu Adapter

Do not start `fs_usage_pdu` from pdu imports. Start from product contracts that
pdu will implement.

Minimum domain/application types:

```text
ScanSessionId
BackendRunId
SnapshotId
NodeId
NodeRef
ScanTarget
ScanTargetSet
OutputRequirements
TraversalPolicy
BoundaryPolicy
LinkPolicy
DepthPolicy
MeasurementProfile
ResourceProfile
PrivacyProfile
SizeFact
NodeKindEvidence
ScanIssueDraft
ScanQuality
ScannerCapabilitySnapshot
BackendScanOutput
BackendCapabilityGap
AdapterDecisionRecord
BackendFingerprint
ScanEvent
ScanEventSink
ScannerBackend
```

Minimum adapter-private pdu types:

```text
PduTraversalKey
PduTreeName
PduRawScanResult
PduProbeState
PduReporterRecorder
PduSideStore
PduTreeConverter
PduCapabilityMapper
PduRunDiagnostics
```

Minimum read-model types:

```text
NodeArenaWriter
NodeArenaRecord
NodeChildrenIndex
NodeSortKey
IssueStore
EvidenceStore
SnapshotPublicationGate
```

Top 3 first-code entry points:

1. Product contracts plus fake backend before pdu - 🎯 10 🛡️ 10 🧠 6, roughly
   900-2000 LOC.
   Accepted. It proves Clean Architecture, UI/client contracts, and tests
   before upstream coupling.
2. pdu adapter first, then extract contracts - 🎯 5 🛡️ 5 🧠 4, roughly
   700-1800 LOC.
   Tempting, but likely to leak `DataTree`, pdu errors, path strings, and
   reporter semantics into the engine.
3. Flutter UI first with mocked JSON - 🎯 4 🛡️ 4 🧠 5, roughly 800-2000 LOC.
   Rejected as the next backend step. UI can progress separately, but scanner
   contracts must be owned by Rust/application first.

## Minimal Domain/Data Contract To Write First

This is the practical pre-coding contract. If these boundaries are not present,
do not start the production pdu adapter.

Top 3 first-module strategies:

1. Domain/application contract plus fake backend first - 🎯 10 🛡️ 10 🧠 6,
   roughly 900-2200 LOC.
   Accepted. It proves use cases, read-model pagination, capability gaps,
   scan-quality states, and import boundaries before `parallel_disk_usage`
   appears in the dependency graph.
2. pdu adapter first, then move types inward - 🎯 5 🛡️ 5 🧠 4, roughly
   700-1800 LOC.
   Rejected as default. It is the fastest way to accidentally make `DataTree`,
   pdu operation names, pdu size modes, and pdu progress semantics part of the
   product language.
3. Full future engine before pdu - 🎯 6 🛡️ 8 🧠 9, roughly 4000-9000 LOC.
   Too much for MVP. Keep contracts future-shaped, but implement only the
   minimum scan/read-model slice.

### Domain Value Objects

The domain layer should define vocabulary and invariants only. It should not
define scanner execution, pdu options, HTTP DTOs, caches, platform probes, or
Flutter state.

Create these first:

```text
ScanTarget
ScanTargetSet
TargetAuthority
TargetScope
BoundaryPolicy
LinkPolicy
DepthPolicy
MeasurementProfile
MeasurementKind
SizeFact
SizeConfidence
NodeId
NodeRef
SnapshotId
ScanIssueReason
ScanIssueSeverity
ScanQuality
CapabilityCode
PrivacyClass
```

Important domain invariants:

- `ScanTargetSet` is explicit user intent. It cannot default to `"."` just
  because pdu CLI does.
- `MeasurementProfile` chooses apparent bytes, allocated bytes, or block count
  explicitly. It cannot inherit pdu's platform-dependent CLI default.
- `SizeFact` carries kind, exact value, source, confidence, and projection
  status. It is not a formatted string and not a pdu `Bytes`/`Blocks` wrapper.
- `NodeRef` references a snapshot plus node id. It is not a path and not a pdu
  child index.
- `ScanQuality` is a product state built from issues and capabilities. It is
  not the same thing as pdu returning a `DataTree`.
- `ScanIssueReason` is stable product taxonomy. It must not expose raw pdu
  operation enum names as public reason ids.

Forbidden in domain:

```text
DataTree
FsTreeBuilder
TreeBuilder
Info
Reporter
Event
ErrorReport
ProgressReport
HardlinkList
HardlinkAware
GetSize
Bytes
Blocks
JsonData
Reflection
PathBuf as authority
std::fs::Metadata
std::io::Error
rayon
tokio
HTTP/WebSocket DTOs
Flutter/MobX types
```

### Application Ports And Use Cases

Application owns orchestration, not infrastructure. Ports live here because the
application defines what it needs from the outside.

Create these ports before pdu:

```text
ScannerBackend
MetadataReader
FileIdentityReader
FilesystemCapabilityReader
ReclaimAccountingReader
ReadModelQueryPort
ScanEventSink
Clock
OperationJournal
```

First use cases:

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
```

Application responsibilities:

- convert a `BackendScanOutput` into a publishable `ScanSnapshot`;
- reject late output from an old session epoch;
- build `NodeArena` and indexes;
- define stable sort/search/page semantics;
- aggregate pdu/platform issues into `ScanQuality`;
- protect delete workflows from stale snapshots;
- throttle progress events and publish query invalidations;
- expose capability gaps instead of silently weakening results.

Application must not:

- import `parallel_disk_usage`;
- call pdu sort/cull/dedupe helpers;
- treat pdu child order as stable protocol order;
- create delete authority from pdu paths or pdu sizes;
- return the full recursive tree to Flutter.

### Data/Infrastructure Adapter Shape

`fs_usage_pdu` is an anti-corruption adapter. It translates pdu evidence into
application contracts and contains all upstream coupling.

Adapter-private components:

```text
PduScannerBackend
PduOptionsMapper
PduExecutionLane
PduScanRunner
PduReporterRecorder
CleanDiskHardlinkRecorder
PduRawScanResult
PduTreeConverter
PduCapabilityMapper
PduBackendFingerprint
PduRunDiagnostics
PduAdapterDecisionRecord
```

Adapter flow:

```text
BackendScanRequest
  -> PduOptionsMapper
  -> PduExecutionLane
  -> FsTreeBuilder or custom TreeBuilder
  -> PduReporterRecorder copies borrowed event evidence
  -> PduRawScanResult
  -> PduTreeConverter writes NodeArena records
  -> PduCapabilityMapper explains missing/degraded facts
  -> BackendScanOutput
```

Rules:

- `PduRawScanResult` is private and may contain pdu `DataTree`.
- `BackendScanOutput` is product-shaped and contains no pdu concrete type.
- `PduReporterRecorder` must copy borrowed paths and metadata-derived facts
  immediately because pdu event lifetimes are callback-local.
- `PduTreeConverter` must mark child completeness and materialization state.
  Empty children can mean file, empty dir, unreadable dir, boundary skip,
  depth projection, cull projection, or unknown.
- `PduTreeConverter` must not infer file/directory kind from
  `children().is_empty()`.
- `PduTreeConverter` should use an explicit stack or bounded recursion policy,
  because very deep trees should not turn adapter conversion into a stack-risk
  surprise.
- `CleanDiskHardlinkRecorder` should preserve hardlink conflict evidence before
  pdu can hide recorder errors through `.ok()`.
- pdu dedupe, sort, cull, visualizer, status board, CLI app, and JSON schema
  are not part of production scan truth.

### Minimum Contract Tests

These tests should exist before or with the first pdu adapter PR:

```text
contract_domain_has_no_parallel_disk_usage_imports
contract_application_has_no_parallel_disk_usage_imports
contract_protocol_has_no_pdu_schema_terms
contract_pdu_adapter_is_the_only_parallel_disk_usage_importer
contract_scan_target_set_never_defaults_to_dot
contract_measurement_profile_is_explicit
contract_pdu_default_features_are_disabled
contract_backend_output_contains_capabilities_and_decision_record
contract_empty_children_do_not_imply_empty_directory
contract_pdu_error_report_maps_to_scan_issue_draft
contract_access_entry_issue_has_parent_path_precision
contract_progress_item_is_metadata_read_not_node_published
contract_pdu_datatree_never_crosses_adapter_boundary
contract_node_ref_is_snapshot_plus_node_id_not_path
contract_scan_snapshot_cannot_authorize_delete
contract_query_page_does_not_mutate_snapshot
contract_late_cancelled_backend_output_is_discarded
contract_non_utf8_name_preserves_native_authority
contract_hardlink_projection_not_reclaim_truth
contract_custom_backend_can_replace_pdu_without_domain_change
```

### pdu To Product Mapping

| pdu evidence | Product mapping | Confidence |
| --- | --- | --- |
| `DataTree::size()` | aggregate `SizeFact` for selected `MeasurementProfile` | high for pdu-selected measurement, low for reclaim |
| `DataTree::name()` | display/name evidence only | low as authority |
| `DataTree::children()` | adapter traversal input | high for visible pdu projection, not pagination |
| `Reporter::ReceiveData` | progress evidence | medium, not node completion |
| `Reporter::EncounterError` | `ScanIssueDraft` | medium, depends on operation path precision |
| `Reporter::DetectHardlink` | hardlink observation evidence | medium, not exact reclaim |
| `DeviceBoundary::Stay` | traversal policy evidence | medium on Unix, weak outside Unix |
| `GetBlockSize` | allocated-byte measurement source on Unix | medium, not exclusive reclaim |
| pdu hardlink dedupe | named projection | low for cleanup authority |
| pdu JSON/Reflection | diagnostic fixture/import evidence | low for product trust |

### Rust-Specific Architecture Notes

Clean Architecture in Rust should be enforced by crates and imports, not only
by folder names.

Recommended crate dependency direction:

```text
fs_usage_core
  no dependency on fs_usage_engine, fs_usage_pdu, platform, server, protocol

fs_usage_engine
  -> fs_usage_core

fs_usage_platform
  -> fs_usage_core
  -> fs_usage_engine ports only when implementing adapters

fs_usage_pdu
  -> fs_usage_core
  -> fs_usage_engine
  -> parallel-disk-usage

clean_disk_protocol
  -> fs_usage_core or protocol-specific shared value DTOs only

clean-disk-server
  -> all adapters as composition root
```

Rust SOLID interpretation:

- SRP: split pdu scan execution, reporter capture, tree conversion,
  hardlink evidence, capability mapping, and decision records.
- OCP: add MFT/APFS/custom scanners by implementing `ScannerBackend`, not by
  changing domain types or Flutter DTOs.
- LSP: fake backend, pdu backend, and future platform backend must satisfy the
  same capability/result contract. Unsupported facts are capability gaps, not
  fake values.
- ISP: keep ports small. `ScannerBackend` should scan; metadata, identity,
  reclaim accounting, trash, and support-bundle export are separate ports.
- DIP: engine depends on scanner ports; pdu adapter depends on engine contracts.
  The inner crates never depend on pdu.

### Coding Start Gate

Before starting production code, answer these with "yes":

```text
Can the fake backend produce a scan snapshot without pdu?
Can Flutter query children by page without seeing the full tree?
Can pdu be replaced by a fake backend in application tests?
Can every missing pdu fact be represented as unknown, lazy, unsupported, or degraded?
Can a scan snapshot be displayed while still being unable to authorize delete?
Can an adapter decision record explain why the scan used FsTreeBuilder or custom TreeBuilder?
Can the production build prove pdu cli/json features are disabled?
```

If any answer is "no", the issue is architectural, not implementation detail.

## Fixture And Benchmark Gates Before pdu Adapter

The pdu adapter should not be judged only by scanning `Downloads` or
`~/Library`. Real folders are useful smoke tests, but they do not prove the
contract edges that matter for a reusable scanner library.

Required fixture families before production pdu integration:

- deep tree with thousands of nested directories to prove recursion, stack, and
  depth policy behavior;
- wide tree with tens or hundreds of thousands of entries in one directory to
  prove child-vector allocation, side-store contention, and arena ingestion;
- depth-limited scan where hidden descendants still contribute size, proving
  `RetainedDepthLimit` is not mistaken for `TraversalDepthLimit`;
- non-UTF-8/native-name fixture proving display text is not path authority;
- hardlink fixture with repeated links and, where possible, conflict/impossible
  evidence proving hardlink data is not reclaim authority;
- symlinked directory, symlinked file, broken symlink, and link-loop fixtures
  proving link policy is explicit and fails closed for destructive actions;
- permission-denied/read-dir-error/access-entry-error fixtures proving pdu
  `ErrorReport` is mapped into product `ScanIssueDraft`;
- race fixtures where a file disappears, appears, or grows during scan, proving
  scan snapshots are stale evidence;
- sparse file and large-counter fixtures proving measurement and JSON/web-safe
  encoding are correct;
- multi-root and overlapping-target fixtures proving pdu fake-root/overlap
  behavior does not become product target semantics;
- cancellation during traversal and cancellation during publication gate,
  proving no partial output becomes cleanup authority;
- local Rayon pool fixture proving pdu work runs inside the selected execution
  lane or reports a weakened capability.

Benchmark dimensions to record separately:

```text
raw pdu traversal time
reporter/event overhead
side-store capture overhead
DataTree -> arena ingestion time
index build time
metadata enrichment time
query-ready time
peak RSS
max event backlog
cancel latency
UI page query latency
```

Contract:

```text
No pdu adapter capability is accepted from intuition alone.
Every risky upstream behavior needs either a fixture, a measured benchmark, or
an explicit capability gap.
```

Top 3 verification strategies:

1. Contract fixture lab before production pdu adapter - 🎯 9 🛡️ 10 🧠 7,
   roughly 800-2000 LOC.
   Accepted. It lets fake backend, pdu adapter, future MFT adapter, and protocol
   tests share the same behavior expectations.
2. Real-machine smoke tests only - 🎯 5 🛡️ 5 🧠 2, roughly 100-400 LOC.
   Rejected as sufficient proof. Real folders catch performance regressions,
   but miss edge-case contracts and are hard to reproduce.
3. Delay fixtures until cleanup beta - 🎯 3 🛡️ 3 🧠 1, roughly 0-100 LOC now.
   Rejected. Cleanup safety and protocol shape depend on these facts from day
   one, even if deletion ships later.

## Scanner Capability Snapshot Contract

Every backend must publish what it can and cannot prove. This avoids encoding
pdu limitations as hidden product behavior.

Recommended capability snapshot shape:

```text
ScannerCapabilitySnapshot
  backend_id
  backend_version
  scan_output_mode
    final_tree
    incremental_tree
    streaming_nodes
  operation_phase_capabilities
    traversal
    conversion
    indexing
    enrichment
    publication_gate
  progress_mode
    none
    sampled_counters
    per_node_events
  cancellation_mode
    none
    best_effort_session_discard
    cooperative
    hard_abort
  size_capabilities
    apparent_size
    allocated_size
    block_count
    self_size_side_store
    exclusive_reclaim_estimate
  identity_capabilities
    inode_device
    platform_file_id
    generation_or_change_token
  node_kind_capabilities
    none
    lazy_metadata
    scan_side_store
    authoritative_scan_kind
  path_capabilities
    native_path_authority
    lossy_display_projection
    redaction_required
  boundary_capabilities
    same_filesystem
    symlink_policy
    mount_policy
  race_capabilities
    scan_time_evidence
    current_identity_preflight
    stale_snapshot_detection
  encoding_capabilities
    native_names
    lossy_display_names
    non_utf8_safe_protocol
  numeric_capabilities
    u64_backend_values
    web_safe_protocol_encoding
    finite_ratio_validation
  hardlink_capabilities
    detection
    grouping
    conflict_evidence
    deduped_projection
    summary_panic_containment
  query_capabilities
    recursive_tree_only
    arena_read_model
    paginated_children
    indexed_search
    indexed_top_lists
  resource_capabilities
    local_thread_pool
    global_thread_pool
    helper_process
  validation_capabilities
    reflection_shape_validation
    product_snapshot_validation
    adapter_panic_boundary
```

pdu 0.23.0 initial capability interpretation:

| Capability area | pdu adapter truth |
| --- | --- |
| scan output | final tree, not stable per-node stream |
| operation phases | pdu progress covers traversal only; product conversion/index/publish phases are ours |
| progress | sampled counters plus synchronous error/hardlink events |
| cancellation | no built-in cooperative cancellation through `FsTreeBuilder` |
| size | apparent size everywhere, allocated/block count on Unix only |
| self size | lost after ordinary `DataTree`; available through custom `TreeBuilder` side-store or lazy metadata |
| node kind | lost by `DataTree`; available only through lazy metadata or custom `TreeBuilder` side-store |
| traversal depth | pdu `max_depth` limits retained children, not descendant traversal |
| recursive safety | pdu tree build/conversion/projection paths are recursive and require fixture validation |
| ordering | traversal order unstable; product read-model must own sort/tie-breakers |
| path identity | names, display strings, and traversal paths only, no product cleanup authority |
| path display | `OsStringDisplay`/Debug formatting is display evidence only |
| link policy | `symlink_metadata` path does not follow symlinked directories by default |
| skipped boundary evidence | pdu can avoid descent on different device, but default path does not emit a structured boundary issue |
| race/TOCTOU | final tree is scan-time evidence, not current delete authority |
| same-filesystem boundary | meaningful on Unix, weakened/unsupported elsewhere |
| hardlinks | Unix hardlink evidence, conflict possible, not reclaim truth |
| hardlink conflicts | fallible recorder can detect conflicts, but `FsTreeBuilder` discards recorder errors |
| hardlink summary | classification evidence; impossible evidence can panic unless contained |
| non-UTF-8 | native names in `DataTree`, pdu JSON path is not safe |
| ratio thresholds | pdu `Fraction` can accept `NaN`; product must validate finite/range first |
| numeric precision | backend sizes/counters are `u64`; protocol must be web-safe |
| reflection validation | checks only narrow tree-size shape, not product snapshot validity |
| query model | pdu recursive `DataTree` only; product arena/pages/indexes are ours |
| resource control | Rayon-based, global-pool pitfalls if using CLI path |

Top 3 capability contract strategies:

1. Capability snapshot required for every scan session - 🎯 10 🛡️ 10 🧠 6,
   roughly 500-1300 LOC.
   Accepted. It lets UI, daemon, tests, and future scanners fail closed.
2. Hard-code pdu assumptions in UI and docs - 🎯 3 🛡️ 3 🧠 2, roughly
   100-300 LOC.
   Rejected. It creates hidden coupling and makes backend replacement painful.
3. Put capabilities only in server config - 🎯 5 🛡️ 5 🧠 3, roughly
   200-500 LOC.
   Rejected as insufficient. Capabilities can vary by platform, target,
   permissions, feature flags, and backend version.

## Public API Stability Rules For The Reusable Library

The reusable `fs_usage_*` library should be conservative because other projects
may use it later.

Rules:

- public structs use private fields plus constructors/getters when invariants
  matter;
- ids, cursors, tokens, and policies are newtypes;
- public enums that may grow are `#[non_exhaustive]`;
- public traits are sealed unless downstream implementation is intentional;
- library errors are typed and stable enough for recovery;
- implementation errors such as pdu hardlink conflicts map to product errors at
  the adapter boundary;
- `anyhow`/opaque errors are acceptable in binaries and diagnostics, not as
  stable reusable crate APIs;
- large integer facts must expose exact values without relying on JavaScript
  numeric precision.

Top 3 public API styles:

1. Stable typed API with newtypes, private fields, and non-exhaustive enums -
   🎯 9 🛡️ 10 🧠 7, roughly 700-1800 LOC.
   Accepted for public `fs_usage_*` surfaces.
2. Mostly public fields and simple enums - 🎯 6 🛡️ 5 🧠 3, roughly
   300-900 LOC.
   Too easy to start, too hard to evolve.
3. Opaque everything behind trait objects - 🎯 5 🛡️ 7 🧠 8, roughly
   1000-2500 LOC.
   Flexible, but less ergonomic and harder to test/debug for our first version.

## Data And Infrastructure Responsibilities

Data/infrastructure does not mean "put all messy code here." It has precise
responsibilities.

`fs_usage_pdu` responsibilities:

- choose pdu `GetSize` based on `MeasurementProfile`;
- choose pdu `DeviceBoundary` based on `BoundaryPolicy` and platform capability;
- run pdu in a bounded execution lane;
- decide between `FsTreeBuilder` scan-only path and custom pdu `TreeBuilder`
  path based on required node-kind/index capabilities;
- capture pdu reporter events without blocking the scan excessively;
- preserve node-kind evidence in side stores when using custom `TreeBuilder`;
- preserve self-size evidence in side stores when using custom `TreeBuilder`;
- never expose pdu traversal order as stable product order;
- convert `DataTree` into `ScanSnapshotDraft`;
- drop or quarantine recursive pdu trees after arena ingestion when memory
  budget requires it;
- treat pdu sort/cull/retain/dedupe as projection steps, not snapshot truth;
- map pdu `ErrorReport` and hardlink evidence into product issue/evidence;
- publish `ScannerCapabilitySnapshot` for the concrete backend, platform,
  feature flags, and target;
- enforce `CancelledOutputPolicy` when a pdu worker finishes after cancellation;
- hide pdu terminal, JSON, CLI, visualizer, and feature details.
- never expose pdu `BytesFormat`, `ColumnWidthDistribution`, `Direction`, or
  `BarAlignment` as domain/protocol scan semantics.
- never call pdu `app::Sub` in production, because it owns CLI defaults,
  terminal behavior, JSON behavior, sort/cull/dedupe, and empty-target fallback.

`fs_usage_platform` responsibilities:

- native metadata enrichment;
- file identity evidence;
- path authority and display/redaction support;
- Trash/recycle adapters;
- capacity/free-space semantics;
- permission/capability probes;
- platform-specific accounting evidence.

`clean_disk_protocol` responsibilities:

- versioned DTOs;
- string-safe exact integers;
- unknown enum handling;
- path privacy classes;
- compatibility/capability DTOs;
- mapping between engine models and transport.

`apps/clean_disk_server` responsibilities:

- dependency graph and config;
- auth/local token/origin policy;
- HTTP routes and WebSocket event delivery;
- graceful shutdown;
- observability and redaction;
- daemon lifecycle, not domain rules.

Flutter responsibilities:

- invoke app commands through clients/stores;
- render pages, progress, details, and confirmation states;
- keep cached rows disposable;
- never become cleanup authority;
- never sort/filter the full scan tree locally for product truth.

## CLI Configuration And Runtime Error Boundary

pdu contains useful argument types, but these types encode the CLI program's
interface and defaults. They must not become the Clean Disk domain language.

Source facts from pdu 0.23.0:

- `Depth` has `Infinite` and `Finite(NonZeroU64)`. The string `inf` maps to
  `Infinite`, and internal comparison maps infinite to `u64::MAX`.
- `Depth::try_from(0_u64)` fails because finite depth is a `NonZeroU64`.
- pdu `Depth::FromStrError` is `#[non_exhaustive]`, so adapter parsing code
  must keep a fallback branch.
- `Fraction` wraps `f32` and documents the range as `0 <= value < 1`.
- `Fraction::new` rejects values `>= 1.0` and `< 0.0`, but it does not reject
  non-finite values explicitly. Product thresholds must reject `NaN`,
  `Infinity`, and `-Infinity` before mapping to pdu.
- `Threads` supports `Auto`, `Max`, and `Fixed(NonZeroUsize)`. This is a Rayon
  thread setting, not the product's resource governance model.
- `Quantity` supports `ApparentSize`, and on Unix also `BlockSize` and
  `BlockCount`.
- pdu's CLI quantity default is platform-dependent: `BlockSize` on Unix and
  `ApparentSize` outside Unix. Our product default must be explicit.
- pdu `RuntimeError` is a CLI-host error enum for JSON serialization,
  deserialization, CLI argument conflict, invalid reflection, and unsupported
  platform features. It maps to process exit codes, not daemon protocol errors.

Contract rule:

```text
pdu CLI args/errors -> fs_usage_pdu adapter details
Clean Disk config/errors -> fs_usage_core/fs_usage_engine owned types
Daemon protocol errors -> clean_disk_protocol owned DTOs
```

Top 3 config boundary strategies:

1. Product value objects mapped to pdu in the adapter - 🎯 10 🛡️ 10 🧠 5,
   roughly 500-1400 LOC.
   Accepted. `ScanDepthPolicy`, `ResourceProfile`, `MeasurementProfile`,
   `RatioThreshold`, and `BackendFailure` stay product-owned and testable.
2. Reuse pdu `args::*` types in engine/application - 🎯 3 🛡️ 4 🧠 2,
   roughly 100-300 LOC.
   Rejected. It makes pdu CLI semantics part of our stable API and weakens the
   future scanner replacement story.
3. Pass strings through to pdu parsers from protocol/UI - 🎯 2 🛡️ 2 🧠 1,
   roughly 50-200 LOC.
   Rejected. It turns validation into runtime parsing, makes errors less typed,
   and risks exposing CLI wording in UI/API.

Mapping table:

| pdu concept | Product concept | Adapter responsibility |
| --- | --- | --- |
| `Depth::Infinite` internally comparable as `u64::MAX` | `ScanDepthPolicy::Unlimited` | Never encode unlimited as raw `u64::MAX` in protocol or domain |
| `Depth::Finite(NonZeroU64)` | `ScanDepthPolicy::Limited(DepthLimit)` | Validate range and UX limits before adapter mapping |
| `Fraction(f32)` | `RatioThreshold` or `DisplayPruneThreshold` | Reject non-finite values and preserve product rounding semantics |
| `Threads::Auto/Max/Fixed` | `ResourceProfile` plus `ThreadBudget` | Map balanced/fast/background policy to concrete pdu/Rayon settings |
| `Quantity` | `MeasurementProfile` and `SizeFactKind` | Choose explicit size semantics per target/platform, never inherit pdu default silently |
| `RuntimeError` exit codes | `BackendFailure` and daemon protocol error DTOs | Convert at boundary with typed reason, severity, and redaction |

### pdu RuntimeError Is A CLI Exit Contract

Source fact:

- pdu `RuntimeError` is explicitly documented in source as an error caused by
  the CLI program.
- variants cover JSON serialization, JSON deserialization, JSON input argument
  conflict, invalid input reflection, and unsupported platform features.
- `RuntimeError::code()` maps variants to process exit codes.
- `UnsupportedFeature` variants are cfg-gated by platform.

Contract:

```text
pdu RuntimeError is never a Clean Disk public error type.
The adapter maps it, when encountered in diagnostics/tests, into product-owned
BackendFailure or DiagnosticFailure.
```

Implications:

- daemon protocol errors must include product reason codes, severity,
  retryability, privacy class, and compatibility impact;
- unsupported platform features are capability facts, not process exit codes;
- public reusable library errors should be typed and `#[non_exhaustive]` where
  extension is expected;
- pdu CLI error messages and exit codes must not appear in Flutter UX.

Top 3 error contract strategies:

1. Product `BackendFailure` hierarchy with pdu mapping adapter - 🎯 10 🛡️ 10
   🧠 6, roughly 600-1600 LOC.
   Accepted. It keeps errors stable and testable across pdu, MFT, APFS, and
   remote backends.
2. Reuse pdu `RuntimeError` in daemon protocol - 🎯 3 🛡️ 3 🧠 2, roughly
   100-300 LOC.
   Rejected. It is a CLI exit contract and mostly JSON/terminal focused.
3. Collapse every backend problem into string messages - 🎯 2 🛡️ 2 🧠 1,
   roughly 50-150 LOC.
   Rejected. UI policy, retry behavior, support bundles, and tests need typed
   failures.

### Visualizer And Formatting Are Terminal Presentation

Source fact:

- pdu `BytesFormat` supports plain, metric, and binary display.
- pdu byte formatting uses `f32` internally for human-readable unit display.
- pdu `ColumnWidthDistribution` models ASCII chart width, and `Args` falls back
  to terminal width or `150` when terminal size is unavailable.
- pdu `Visualizer` implements terminal chart rendering over `DataTree`.
- pdu CLI options `top_down`, `align_right`, `total_width`, `column_width`, and
  `bytes_format` are display choices, not scan semantics.

Contract:

```text
FormattingPolicy and ViewProjection are presentation concepts.
Protocol and domain carry exact facts, not terminal chart formatting.
```

Implications:

- exact bytes/blocks/reclaim values stay in domain/protocol as exact numbers or
  string-safe integer DTOs;
- Flutter chooses localized formatting through product UI/localization rules;
- pdu `Visualizer`, `BytesFormat`, `ColumnWidthDistribution`, `Direction`, and
  `BarAlignment` must not appear in daemon responses or domain models;
- terminal width fallback `150` has no meaning for desktop/web layout;
- pdu visualizer output can be useful only for CLI diagnostics or regression
  snapshots, not as user-facing app UI.

Top 3 formatting strategies:

1. Exact protocol facts plus Flutter/product formatting policy - 🎯 10 🛡️ 10
   🧠 5, roughly 400-1000 LOC.
   Accepted. It keeps UI localization and exact accounting separate.
2. Reuse pdu `BytesFormat` in API and Flutter - 🎯 4 🛡️ 5 🧠 2, roughly
   100-300 LOC.
   Rejected. It leaks terminal display policy into product contracts.
3. Send preformatted strings from Rust only - 🎯 3 🛡️ 3 🧠 2, roughly
   100-300 LOC.
   Rejected. It breaks localization, sorting, filtering, accessibility, and
   exact comparisons.

Clean Architecture implication:

- domain owns the meaning of scan depth, measurement, resource profile, and
  error reason;
- application owns when a config is valid for a use case;
- `fs_usage_pdu` owns the mechanical mapping into pdu types;
- host/protocol owns transport formatting and compatibility behavior;
- Flutter owns only user input and display state.

This follows the Dependency Rule: pdu names and pdu data formats are outer
mechanism details, so inner policy types must not mention them.

### pdu StatusBoard Is Global Terminal State

Source fact:

- pdu has a static `GLOBAL_STATUS_BOARD`.
- it stores line width in an atomic and writes directly to stderr through
  `eprint!` and `eprintln!`.
- progress and error text reporters use terminal-oriented text paths.

Contract:

```text
Daemon/server mode must not use pdu terminal status output.
All observable state leaves through product logging, metrics, and event ports.
```

Implications:

- no production scan path should call `ErrorReport::TEXT`,
  `ProgressReport::TEXT`, `Visualizer`, or `GLOBAL_STATUS_BOARD`;
- terminal output is diagnostics-only and must be behind an explicit adapter;
- logs and events need privacy/redaction policy before leaving the scanner;
- tests should fail if daemon crates import `status_board` or terminal
  visualizer modules.

Top 3 terminal-output strategies:

1. Custom reporter plus product observability ports - 🎯 10 🛡️ 10 🧠 5,
   roughly 400-1200 LOC.
   Accepted. It keeps daemon behavior deterministic and private.
2. Reuse pdu terminal text in local desktop only - 🎯 4 🛡️ 4 🧠 2, roughly
   100-300 LOC.
   Rejected. Desktop app still needs structured state and redaction.
3. Let pdu write stderr and scrape it - 🎯 1 🛡️ 1 🧠 3, roughly 200-500 LOC.
   Rejected. It is brittle, noisy, and unsafe for privacy.

## SOLID Rules For The First Code

SRP:

- `PduScanRunner` runs pdu.
- `PduRichTreeBuilder` wraps pdu `TreeBuilder` when node-kind side stores are
  required.
- `PduReporter` captures pdu events.
- `PduEventRecorder` owns copied reporter evidence.
- `PduIssueMapper` maps pdu operations/errors to product issue taxonomy.
- `PduTreeConverter` converts tree to arena records.
- `PduNodeKindMapper` maps scan-time metadata to product `NodeKindEvidence`.
- `PduSizeFactMapper` maps pdu size totals and optional self-size evidence into
  product `SizeFact`.
- `PduCapabilityMapper` reports backend capabilities and known limitations.
- `PduCancellationPolicy` handles late pdu output after cancellation.
- `ReadModelIndexes` builds query indexes.
- `ScanSessionService` owns lifecycle.
- No module should both scan the filesystem and expose HTTP DTOs.

OCP:

- Adding an MFT scanner, APFS scanner, or fixture scanner must add a new
  `ScannerBackend` adapter, not modify domain or Flutter contracts.
- Adding a treemap/sunburst renderer must add a projection/renderer adapter,
  not mutate scan truth.

LSP:

- Every `ScannerBackend` implementation must honor the same lifecycle:
  start, progress, final/partial output, cancel, dispose.
- A fake backend must replace pdu in tests without changing use cases.

ISP:

- Split ports by need:
  `ScannerBackend`, `MetadataEnricher`, `TrashAdapter`, `CapacityReader`,
  `EventSink`, `Clock`, `OperationJournal`.
- Do not create one huge `FilesystemService`.

DIP:

- `fs_usage_engine` defines ports.
- `fs_usage_pdu` and `fs_usage_platform` implement ports.
- `clean-disk-server` wires concrete implementations.
- Domain never imports pdu, Tokio, HTTP, Flutter, filesystem APIs, or serde DTOs
  unless the type is explicitly domain-owned.

## Ports And Adapters Shape

Driving ports:

```text
CreateScanSessionUseCase
StartScanUseCase
CancelScanUseCase
GetChildrenPageUseCase
SearchNodesUseCase
GetNodeDetailsUseCase
BuildDeletePlanUseCase
```

Driven ports:

```text
ScannerBackend
PlatformMetadataReader
PlatformIdentityReader
TrashAdapter
CapacityReader
OperationJournal
ScanEventPublisher
Clock
```

Adapters:

```text
PduScannerBackend -> ScannerBackend
MacosMetadataReader -> PlatformMetadataReader
WindowsMetadataReader -> PlatformMetadataReader
LocalTrashAdapter -> TrashAdapter
HttpRouteAdapter -> driving adapter into use cases
WebSocketEventAdapter -> event delivery adapter
FlutterCleanDiskApiClient -> client-side transport adapter
```

Boundary rule:

```text
Ports are product-shaped.
Adapters are technology-shaped.
Mapping is explicit and tested.
```

## Global Attention Areas Before Coding

### 1. Anti-Corruption Boundary

Risk:

- pdu types leak into domain, protocol, Flutter, or cache.

Required guard:

- only `fs_usage_pdu` imports `parallel_disk_usage`;
- import checks fail if domain/application/protocol import pdu modules;
- mappers convert pdu facts into product-owned values immediately.

### 2. Session Lifecycle

Risk:

- pdu scan is a final-tree operation, while product needs create/start/cancel,
  progress, query, dispose, stale state, and multi-client behavior.

Required guard:

- `ScanSessionId`, `SnapshotId`, `event_seq`, state machine, cancellation token,
  and explicit finality state.

### 3. Read Model Memory

Risk:

- million-node scans can blow memory if every node stores full paths, strings,
  rich metadata, and UI details eagerly.

Required guard:

- arena-style records, string/path interning where useful, lazy metadata,
  compact issue refs, paginated queries, bounded top-K indexes.

### 4. Progress And Backpressure

Risk:

- pdu reporter events are synchronous and can become a bottleneck or UI spam.

Required guard:

- bounded channel, lossy/coalesced progress snapshots, full issue side-store,
  throttled WebSocket events, final reconciliation query.

### 5. Error Taxonomy

Risk:

- raw `io::Error`, pdu `Operation`, or terminal text becomes user-facing truth.

Required guard:

- `ScanIssueReason`, `IssueSeverity`, `PlatformErrorCode`, redacted path
  evidence, localized UI messages outside domain.

### 6. Size And Reclaim Accounting

Risk:

- apparent size, allocated size, hardlink-deduped size, block count, and reclaim
  estimate are mixed as one "size".

Required guard:

- `SizeFact` plus `MeasurementProfile`, `SizeUnitSemantics`,
  `EvidenceConfidence`, and explicit display policy.

### 7. Paths And Identity

Risk:

- display path or stale scan node is used for cleanup.

Required guard:

- `NodeRef` and scan-time identity evidence;
- delete preflight revalidates current path, metadata, identity, policy, and
  capability through platform adapters.

### 8. Links, Mounts, And Boundaries

Risk:

- symlinks, hardlinks, APFS clones, mount points, network shares, sparse files,
  cloud placeholders, and reparse points are treated as ordinary files.

Required guard:

- `TraversalPolicy`, `LinkPolicy`, `BoundaryPolicy`, platform capability report,
  and issue taxonomy for unsupported/uncertain cases.

### 9. Resource Governance

Risk:

- "fast scan" freezes the machine, burns battery, or starves UI/server work.
- pdu HDD auto-thread heuristic is mistaken for complete resource governance.

Required guard:

- `ResourceProfile` with balanced default, worker pool budget, bounded Rayon
  lane, cooperative cancellation wrapper, memory budget, storage-medium
  confidence, and overload policy.

### 10. Permission And Process Identity

Risk:

- scanner process has different permissions than UI/helper, especially macOS
  Full Disk Access and sandbox rules.

Required guard:

- capability probe and real scan run under the same signed process/helper
  identity; permission repair re-probes before declaring success.

### 11. Protocol Evolution

Risk:

- int64 values lose precision in Flutter web, enum evolution breaks clients, or
  raw paths leak into logs/support bundles.

Required guard:

- versioned DTOs, string-encoded large integers where needed, unknown enum
  fallback, path privacy classes, DTO redaction policy, compatibility endpoint.

### 12. Testing Evidence

Risk:

- scanner works on the developer machine but fails on edge filesystems.

Required guard:

- fixture lab: wide tree, deep tree, non-UTF-8 names, sparse files, hardlinks,
  symlinks, permission-denied dirs, deleted/growing files, mount boundaries,
  external/network volumes where available.

### 13. Reusable Library API

Risk:

- the library becomes Clean Disk-specific and cannot be reused by other apps.

Required guard:

- `fs_usage_*` crates know nothing about Clean Disk branding, Flutter, HTTP, or
  app routes. Clean Disk-specific policy lives in server/app composition.

### 14. Dependency And Feature Governance

Risk:

- pdu default features pull CLI/JSON/terminal behavior into production or
  upstream changes silently alter semantics.

Required guard:

- `default-features = false` for production pdu dependency;
- explicit feature policy;
- `cargo tree -e features` gate;
- local source audit on pdu upgrades.

### 15. Wrong Integration Entry Point

Risk:

- production code accidentally calls pdu `App`, `Sub`, CLI JSON, terminal
  visualizer, or `Args` because they look convenient.

Required guard:

- `fs_usage_pdu` exposes a small adapter-owned runner around `FsTreeBuilder`;
- import checks block pdu `app`, `args`, `visualizer`, and `json_data` outside
  diagnostics or tests unless explicitly approved.

### 15.1 Terminal Presentation Leakage

Risk:

- pdu `Visualizer`, byte formatting, terminal width, direction, or bar alignment
  leaks into daemon protocol or domain.

Required guard:

- exact facts cross backend/application/protocol boundaries;
- product formatting happens in UI/localization or explicit export adapters;
- terminal chart output is diagnostics-only.

### 16. Reflection And Encoding Leakage

Risk:

- pdu `Reflection` or pdu JSON becomes the product protocol/cache/export schema,
  which would lose non-UTF-8 paths and omit product evidence.

Required guard:

- protocol DTOs are generated from Clean Disk-owned schema;
- pdu JSON is fixture/debug only;
- path display and path authority are separate product types.

### 17. Parallel Runtime Side Effects

Risk:

- a scan session mutates the process-global Rayon pool or inherits pdu's CLI
  HDD heuristic, making future sessions/tests/resource profiles unpredictable.

Required guard:

- scanner runtime has an explicit execution lane;
- verify local Rayon pool control before implementation;
- helper-process isolation remains a documented escape hatch.

### 18. Capability Drift

Risk:

- UI or cleanup flow assumes every backend can do what pdu happened to do on the
  developer machine.

Required guard:

- every scan session carries a capability snapshot;
- risky actions require explicit current capability, not backend name checks;
- unknown capability values fail closed for cleanup and remote/headless modes.

### 19. Late Output After Cancel

Risk:

- pdu finishes after the user cancelled and the app accidentally promotes the
  result as current.

Required guard:

- session state machine validates output epoch before publishing;
- cancelled output is discarded or archived as non-authoritative according to
  `CancelledOutputPolicy`;
- UI can show "cancel requested" and "cleanup disabled" states separately.

### 20. Projection Versus Snapshot Truth

Risk:

- pdu cull/sort/dedupe/JSON projection is mistaken for authoritative scan
  truth.

Required guard:

- `ScanSnapshotDraft` stores measured facts and explicit projection metadata;
- UI projections are query/read-model outputs with policy ids;
- receipts, delete plans, and support bundles cite snapshot evidence, not pdu
  visualizer or JSON projection.

### 21. Product-Ready Time Versus Raw Scan Time

Risk:

- benchmarks report pdu traversal time while the user waits for conversion,
  indexing, event finalization, and cache writes.

Required guard:

- metrics split `traversal_time`, `conversion_time`, `index_time`,
  `publish_time`, and `query_ready_time`;
- release benchmarks state both raw backend time and product-ready snapshot
  time.

### 22. Invalid Numeric Configuration

Risk:

- `NaN`, infinity, negative values, oversized counters, or lossy JSON numbers
  silently change scan/query behavior.

Required guard:

- value objects validate finite/range/exactness at the boundary;
- protocol uses web-safe encoding for exact large values;
- adapter tests prove invalid pdu-facing values never reach pdu.

### 23. Upstream Panic Containment

Risk:

- a panic inside pdu summary/conversion or another upstream helper crashes the
  daemon and loses operation state.

Required guard:

- scanner work runs in a contained worker boundary;
- ordinary errors use typed `Result`;
- unexpected panics map to backend failure, close the session, and never publish
  cleanup authority.

### 24. Fixture Validation Versus Product Validation

Risk:

- pdu `Reflection` or JSON fixtures look validated but do not satisfy Clean Disk
  domain invariants.

Required guard:

- fixture imports enter as drafts;
- product snapshot validation checks identity, path authority, issue state,
  measurement profile, capabilities, and completion state separately.

### 25. Upgrade Drift In pdu Internals

Risk:

- a pdu upgrade changes private behavior around `Fraction`, `Reflection`,
  hardlinks, reporter events, features, or traversal semantics.

Required guard:

- each pdu upgrade has a local source audit checklist;
- contract tests pin the behaviors we rely on;
- adapter capabilities expose weakened behavior instead of silently promising
  old semantics.

### 26. CLI JSON Schema Leakage

Risk:

- pdu `JsonData` or `schema-version` becomes our daemon/cache/export schema.

Required guard:

- product DTOs own protocol versioning;
- pdu JSON is fixture/diagnostic only;
- imports pass through draft conversion and product validation.

### 27. Global Terminal State Leakage

Risk:

- pdu `GLOBAL_STATUS_BOARD`, visualizer, or text reporters write to stderr from
  daemon scans and bypass redaction/observability policy.

Required guard:

- daemon path uses custom reporter and product observability ports;
- import checks block pdu terminal modules outside diagnostics.

### 28. Implicit Target Or Silent Target Mutation

Risk:

- empty target requests scan `"."`, or overlapping target removal silently
  changes what the user asked to scan.

Required guard:

- `ScanTargetSet` requires explicit intent;
- `OverlapPolicy` returns structured validation decisions before scan start.

### 29. Error Contract Erosion

Risk:

- pdu `RuntimeError`, exit codes, CLI strings, or raw `io::Error` become public
  API behavior.

Required guard:

- product errors are typed, redacted, non-exhaustive where appropriate, and
  mapped at adapter/protocol boundaries.

### 30. pdu Final-Tree Memory Shape

Risk:

- pdu materializes child vectors and a recursive final `DataTree`, so a wide or
  huge scan can allocate heavily before our arena/indexes are ready.

Required guard:

- explicit memory budget, compact arena ingestion, side-store budget, pdu tree
  drop policy, degraded state on budget pressure, and benchmarks that split raw
  scan time from product-ready time.

### 31. Hardlink Mutation Projection Risk

Risk:

- pdu hardlink dedupe mutates aggregate size and can be mistaken for measured
  disk usage or reclaim truth.

Required guard:

- measured snapshot stays immutable; hardlink-adjusted output is a named
  projection with policy, capability, confidence, and failure handling.

### 32. Feature-Gated Backend Capability Drift

Risk:

- production builds accidentally depend on pdu default `cli`/`json` features,
  or UI assumes Unix-only hardlink/block semantics on every platform.

Required guard:

- `default-features = false`, explicit pdu feature matrix, `cargo tree -e
  features` gate, and capability DTOs that include compile-time and platform
  support.

### 33. Arithmetic Invariant Drift

Risk:

- total sizes, hardlink-adjusted projections, large counters, and ratio
  thresholds overflow, underflow, wrap, or accept non-finite values.

Required guard:

- checked product constructors, explicit projection metadata, finite/range
  validation, web-safe DTO encoding, and synthetic numeric boundary tests.

### 34. pdu API Surface Leakage

Risk:

- broad pdu crate surfaces such as CLI args, JSON, visualizer, status board, or
  `app::Sub` leak into domain, engine, server, protocol, or Flutter code.

Required guard:

- explicit pdu import allowlist, CI import checks, diagnostics-only feature
  gates, and adapter-owned mapping from pdu facts to product contracts.

### 35. Side-Store Correlation Failure

Risk:

- custom scan-time metadata is captured, but cannot be reliably attached back
  to the final pdu `DataTree` nodes.

Required guard:

- adapter-private `PduTraversalKey`, custom `PduTreeName`, correlation tests for
  duplicate root names, non-UTF-8 names, races, cull/sort/dedupe projections,
  and multi-target fake roots.

### 36. Concurrent Probe Bottleneck Or Data Race

Risk:

- pdu `TreeBuilder` callbacks run through Rayon, but adapter side stores use a
  blocking/global lock or non-thread-safe mutable state.

Required guard:

- `Arc<PduProbeState>`, bounded event bridge, sharded or lock-minimized stores,
  owned evidence copies, and tests that compare wide-tree throughput with and
  without side-store capture.

### 37. Traversal Completion Mistaken For Product Completion

Risk:

- pdu returns `DataTree`, UI says "done", but ingestion, indexing, validation,
  or publish gate still failed or was cancelled.

Required guard:

- explicit operation phases, final publication gate, session epoch check, and
  separate metrics for traversal, ingestion, indexing, and query-ready time.

### 38. Custom Name Breaks Hardlink Projection

Risk:

- rich scan uses `PduTreeName` for side-store correlation, but pdu hardlink
  dedupe expects `Name: AsRef<OsStr>` and path-prefix semantics.

Required guard:

- keep traversal key separate from path segment, delay dedupe projection until
  prefix behavior is tested, and never treat pdu dedupe as reclaim authority.

### 39. Raw pdu ErrorReport Under-Specifies Product Issues

Risk:

- permission, access, missing path, network, policy, and platform issues become
  a raw pdu operation plus `io::Error` text.

Required guard:

- product `ScanIssueDraft` mapper with reason, severity, recoverability,
  privacy class, platform code, evidence confidence, and redaction rules.

### 40. CLI Projection Pipeline Imported As Truth

Risk:

- pdu CLI order of fake-root creation, cull, sort, dedupe, JSON export becomes
  product snapshot semantics.

Required guard:

- product snapshot ingestion happens before projections; every projection has a
  `ProjectionPolicy`, completeness state, and query/read-model owner.

### 41. Local Rayon Pool Assumption Fails

Risk:

- pdu Rayon operations do not stay within the intended local scanner pool, or
  another code path initializes the process-global pool first.

Required guard:

- pre-implementation spike around `ThreadPool::install`, import checks that
  block pdu `app`/`build_global`, thread-budget tests, and fallback path to
  conservative daemon-wide pool or signed helper process.

### 42. Cooperative Cancellation Misrepresented As Hard Abort

Risk:

- custom `TreeBuilder` cancellation pruning is presented as immediate stop,
  while already scheduled branches still finish and final output is partial.

Required guard:

- capability reports distinguish best-effort discard, cooperative pruning, and
  hard abort; partial output never creates cleanup authority.

### 43. Recursive Depth/Stack Failure

Risk:

- pdu recursive tree build/conversion/projection paths hit pathological deep
  trees, stack pressure, or abort-like failures that cannot be fully contained
  by ordinary result handling.

Required guard:

- deep-tree fixture gate, runtime/worker containment policy, panic boundary for
  unwinding failures, and future helper-process option if in-process stack
  containment is not reliable enough.

### 44. pdu max_depth Misread As Traversal Limit

Risk:

- product code treats pdu `max_depth` as "do not scan deeper", while pdu still
  traverses hidden descendants to compute aggregate sizes.

Required guard:

- separate product policies for traversal depth, retained tree depth, and UI
  display depth; hidden-descendant state in the read model; adapter-owned
  traversal cutoff when true traversal limiting is required.

### 45. Fixture Lab Gap

Risk:

- pdu behavior is inferred from normal folders, so non-UTF-8 names, wide trees,
  hardlink conflicts, races, permission errors, sparse files, and cancellation
  are discovered only after UI/protocol contracts have already hardened.

Required guard:

- shared fixture lab and benchmark gates before `fs_usage_pdu` becomes the
  production backend; unproven behavior must appear as capability gap or
  degraded scan quality.

### 46. Output Requirement Drift

Risk:

- UI/product features ask for top files, kind indexes, self-size, hardlink
  conflicts, or traversal cutoff, but the adapter silently uses a weaker pdu
  path and fills missing facts with guesses.

Required guard:

- typed `OutputRequirements`, adapter selection matrix, and `BackendCapabilityGap`
  when the chosen backend cannot prove requested facts.

### 47. Giant Aggregate Accident

Risk:

- the scan tree is modeled as one mutable DDD aggregate, making million-node
  scans, pagination, history, and cleanup validation expensive or unsafe.

Required guard:

- `ScanSession` and `DeletePlan` are aggregates; `NodeArena` and query indexes
  are immutable/read-model data.

### 48. pdu CLI Helper Leakage

Risk:

- pdu `app::Sub`, `overlapping_arguments`, CLI defaults, fake root, cull, sort,
  dedupe, JSON, or terminal behavior is reused because it is convenient.

Required guard:

- production import allowlist, adapter-owned target policy, product-owned
  projections, and diagnostics-only access to pdu CLI/JSON helpers.

### 49. Adapter Decision Becomes Invisible

Risk:

- scan output says "degraded" or lacks fields, but we cannot prove whether the
  cause was user request, backend limitation, feature flag, platform cfg,
  resource profile, or adapter path choice.

Required guard:

- every backend output carries an `AdapterDecisionRecord` or typed
  `BackendCapabilityGap`.

### 50. pdu Upgrade Drift

Risk:

- a pdu version/toolchain/feature change alters traversal, error, hardlink,
  JSON, or Rayon behavior while product contracts and tests still assume old
  semantics.

Required guard:

- `PduBackendFingerprint`, fixture corpus diff, capability diff, import
  allowlist check, and source-audit update before accepting a pdu bump.

### 51. Cargo Feature Unification Surprise

Risk:

- production intends `default-features = false`, but another dependency path or
  test/diagnostic feature enables pdu `cli`/`json` and expands the runtime or
  public import surface.

Required guard:

- `cargo tree -e features` or equivalent resolved-feature check for production
  and diagnostic builds; pdu selected features appear in capability/fingerprint
  diagnostics.

### 52. Evidence, Projection, And Authority Collapse

Risk:

- a value that started as pdu evidence or UI projection is later reused as
  cleanup authority because it has the same path, size, or node id shape.

Required guard:

- every outward value is classified as raw evidence, product fact, projection,
  capability, or current authority;
- delete workflows accept only current authority produced by delete preflight;
- projections carry `ProjectionPolicy` and cannot be converted into
  `DeletePlan` input without revalidation.

### 53. Query Side Effects

Risk:

- a query endpoint or Flutter cache refresh starts a scan, re-reads metadata,
  mutates the cleanup queue, or silently upgrades a stale snapshot.

Required guard:

- application command and query ports are separate;
- query implementations are read-only over published snapshots/indexes;
- metadata refresh, delete-plan creation, scan restart, and queue mutation are
  explicit commands with state transitions and receipts.

### 54. pdu-shaped Public Protocol Drift

Risk:

- pdu type names, schema versions, operation names, or JSON shapes leak into
  daemon DTOs, Dart DTOs, cache rows, or support bundle contracts.

Required guard:

- product protocol owns DTO names, versions, reason codes, and compatibility
  behavior;
- pdu provenance appears only in capability/diagnostic DTOs;
- import/schema checks reject public DTO names that mirror pdu integration
  types.

### 55. pdu Import Surface Too Broad

Risk:

- `parallel_disk_usage` exposes convenient modules for CLI, args, visualizer,
  JSON, status board, and runtime errors, and a developer imports them because
  they solve an immediate problem.

Required guard:

- production import allowlist in `fs_usage_pdu`;
- diagnostics-only allowlist for `Reflection`/`JsonData`;
- hard deny for `app`, `args`, `visualizer`, `status_board`, `bytes_format`,
  `main`, and CLI helpers in production scanner/server/application paths;
- contract tests listed in `pdu-clean-architecture-contract.md`.

### 56. Source Mechanic Not Converted Into Product Meaning

Risk:

- a raw pdu fact is passed through unchanged because it appears harmless:
  aggregate size, `OsStringDisplay`, `Fraction`, `Depth`, `Quantity`,
  `RuntimeError`, `ErrorReport`, `HardlinkList`, or pdu JSON schema.

Required guard:

- every pdu source mechanic becomes exactly one of:
  product fact, projection, capability, diagnostic evidence, unsupported
  behavior, or adapter-private implementation detail;
- the category is stored in `AdapterDecisionRecord`, `ScanIssueDraft`,
  `CapabilitySnapshot`, `ProjectionPolicy`, or tests;
- no "unknown but useful" pdu value crosses the adapter boundary.

## Pre-Coding Stop Rules

Do not start implementation if any answer is missing:

```text
Which crate owns the type?
Is this domain, application, adapter, protocol, or host?
Does this type mention pdu, HTTP, Flutter, Tokio, serde DTOs, or OS APIs?
Can this be tested with a fake adapter?
Is this exact fact, display projection, or evidence with confidence?
Is this current authority or stale snapshot data?
Can this field be logged/exported safely?
What happens on unknown enum, unsupported platform, partial scan, or cancel?
Can this value be NaN, infinite, overflowed, truncated, or lossy in Flutter web?
Can an upstream panic cross this boundary and crash the daemon?
Is this validation pdu fixture validation or product domain validation?
Is this target explicit user intent or a CLI default?
Is this target set being silently changed by a backend helper?
Is this error a product failure, adapter diagnostic, or CLI exit code?
Is this output going through redaction/observability ports or direct terminal IO?
Does this path allocate a complete pdu child vector or recursive tree?
Is this measured size, adjusted projection, display value, or reclaim estimate?
Which compile-time pdu features and platform cfgs make this capability true?
Can this arithmetic overflow, underflow, wrap, saturate, or silently lose facts?
Is this pdu type allowed in production, diagnostics only, or forbidden here?
Does this public type force downstream users to depend on pdu or CLI semantics?
How does this side-store fact attach to a final DataTree node?
Can this callback run concurrently or out of traversal order?
Which operation phase owns this state, and has it passed the publication gate?
Is this pdu hardlink behavior compatible with our custom node name type?
Is this issue user-facing, raw backend evidence, or redacted diagnostic data?
Is this pdu CLI projection order accidentally becoming product truth?
Does this Rayon work run in our local scanner pool or the global pool?
Is this cancellation mode best-effort discard, cooperative pruning, or hard abort?
Is this traversal depth, retained tree depth, or UI display depth?
Does this pdu max_depth setting actually stop traversal, or only hide children?
Can this recursive pdu path blow stack or require helper-process containment?
Which fixture proves this pdu behavior before it becomes a contract?
Which `OutputRequirements` are requested, and which backend path can prove them?
Is this a real aggregate invariant or a read-model/query concern?
Is any pdu CLI helper being reused as product policy?
Where is the `AdapterDecisionRecord` for this scan output?
Which pdu fingerprint and resolved feature graph produced this behavior?
Would a pdu version/toolchain bump change this assumption?
Is this value raw evidence, product fact, projection, capability, or authority?
Can this query mutate scan/session/queue/delete state in any way?
Does this DTO expose pdu names, pdu schema versions, or pdu operation names?
Does this command return a full tree instead of id/page/state/receipt summary?
Can this event replace query truth, or only invalidate/reconcile it?
```

Hard stop:

- no pdu import outside `fs_usage_pdu`;
- no pdu JSON as product protocol/cache/export;
- no pdu terminal text as UI/log/protocol;
- no full tree sent to Flutter;
- no cleanup action from scan data without current revalidation;
- no raw path/token/search text in production logs;
- no scanner loop without resource budget and cancellation story;
- no public library API with pdu concrete types.
- no raw floating ratio reaches pdu without product validation;
- no exact large integer crosses protocol as a lossy JSON number;
- no pdu panic can publish a current snapshot or cleanup authority;
- no pdu `Reflection` validation replaces product snapshot validation.
- no pdu `JsonData` as daemon/cache/export schema;
- no empty target set maps to `"."` without explicit product intent;
- no pdu overlap removal silently mutates a product target set;
- no pdu `RuntimeError` or exit code crosses into public protocol;
- no pdu `GLOBAL_STATUS_BOARD` or terminal text reporter in daemon scan path.
- no pdu streaming-node promise unless a fork/replacement proves it;
- no pdu hardlink dedupe mutation replaces measured snapshot truth;
- no production pdu dependency uses default features without a written
  exception;
- no platform-specific pdu behavior is hidden behind a generic backend name;
- no unchecked aggregate arithmetic publishes cleanup authority.
- no pdu `app::Sub`, `Args`, `RuntimeError`, `StatusBoard`, `Visualizer`, or
  JSON data type reaches production scanner contracts;
- no reusable `fs_usage_*` public API exposes pdu concrete types.
- no side-store evidence is attached by child index or display string alone;
- no pdu callback writes to UI/protocol/logging directly;
- no `DataTree` return marks a scan session query-ready without ingestion,
  validation, indexing, and publication gate.
- no traversal key appears in pdu path-prefix hardlink semantics;
- no pdu `ErrorReport` or terminal text becomes a user-facing issue directly;
- no pdu cull/sort/dedupe/fake-root/JSON pipeline mutates measured snapshot
  truth.
- no production adapter calls pdu CLI thread setup or `build_global`;
- no cancellation UI claims hard abort when backend can only prune/discard.
- no pdu `max_depth` is documented or modeled as a traversal cutoff;
- no deep-tree capability is accepted without a fixture or explicit degraded
  capability;
- no scan-only smoke test replaces the required fixture lab for pdu contracts.
- no adapter silently downgrades requested output requirements;
- no million-node tree is modeled as one mutable aggregate;
- no pdu CLI helper or fake-root policy becomes product behavior.
- no scan output lacks an adapter decision record or capability-gap reason;
- no pdu upgrade is accepted without fixture and capability diffs;
- no production build assumes pdu defaults are disabled without resolved-feature
  evidence.
- no projection becomes delete authority;
- no query starts scans, refreshes metadata, mutates cleanup queues, or publishes
  snapshots;
- no public protocol DTO uses pdu-shaped field names, type names, schema
  versions, or operation names;
- no command returns a full recursive tree as its normal response;
- no WebSocket event stream replaces paginated query truth.

## First Coding Sequence

Recommended order:

1. `fs_usage_core` value objects and typed errors - 🎯 9 🛡️ 10 🧠 5,
   roughly 600-1200 LOC.
2. `fs_usage_engine` `ScannerBackend` port, session state machine, and fake
   backend - 🎯 9 🛡️ 9 🧠 6, roughly 900-1800 LOC.
3. Compact `NodeArena` and query page contracts - 🎯 8 🛡️ 9 🧠 7,
   roughly 900-2000 LOC.
4. Fixture lab and benchmark harness for pdu contract edges - 🎯 9 🛡️ 10 🧠 7,
   roughly 800-2000 LOC.
5. `fs_usage_pdu` adapter with pdu reporter capture and DataTree conversion -
   🎯 8 🛡️ 8 🧠 7, roughly 1200-2500 LOC.
6. Server protocol DTOs and HTTP/WebSocket adapters - 🎯 8 🛡️ 8 🧠 6,
   roughly 1000-2200 LOC.
7. Flutter scan client and TreeTable facade integration - 🎯 8 🛡️ 8 🧠 7,
   roughly 1200-2600 LOC.

Do not start with Flutter UI polishing before fake backend plus page contracts
exist. The data contract should make the UI boring to wire.

## Contract Tests To Add Early

```text
contract_no_pdu_imports_outside_fs_usage_pdu
contract_domain_has_no_serde_http_flutter_tokio
contract_scanner_backend_fake_replaces_pdu
contract_event_sequence_monotonic_per_session
contract_progress_backpressure_coalesces_without_losing_final_state
contract_reporter_borrowed_data_copied_before_callback_returns
contract_reporter_backpressure_does_not_block_filesystem_traversal
contract_pdu_operation_maps_to_product_issue_reason
contract_pdu_errors_map_to_scan_issue_taxonomy
contract_pdu_fs_tree_builder_errors_are_side_channel_not_result
contract_direntry_access_error_parent_path_precision_is_marked
contract_datatree_max_depth_hidden_descendants_are_not_cleanup_targets
contract_depth_limited_leaf_not_complete_subtree_authority
contract_pdu_max_depth_does_not_stop_deep_traversal
contract_depth_policy_splits_traversal_retention_and_display
contract_deep_tree_scan_has_depth_budget_or_degraded_state
contract_recursive_projection_failure_never_cleanup_authority
contract_fixture_lab_includes_deep_tree_and_depth_limited_scan
contract_boundary_not_descended_is_explicit_issue_or_capability_gap
contract_size_fact_distinguishes_apparent_allocated_blocks_reclaim
contract_self_size_unknown_unless_side_store_or_metadata_proves_it
contract_pdu_app_sub_not_used_as_production_integration_api
contract_custom_tree_builder_probe_preserves_side_store_evidence
contract_pdu_json_reflection_not_protocol_or_cache_schema
contract_pdu_json_non_utf8_names_do_not_crash_product_path_model
contract_pdu_jsondata_not_daemon_protocol_or_cache_schema
contract_pdu_schema_version_not_product_protocol_version
contract_pdu_json_shared_absence_is_capability_unknown_not_no_hardlinks
contract_pdu_reflection_validation_not_product_snapshot_validation
contract_no_unsafe_transmute_in_pdu_adapter_without_safety_case
contract_datatree_leaf_is_not_node_kind_authority
contract_top_files_requires_node_kind_evidence
contract_node_kind_capability_matches_scan_path
contract_hardlink_evidence_not_reclaim_authority
contract_hardlink_summary_not_reclaim_truth
contract_pdu_hardlink_summary_panic_maps_to_backend_failure
contract_backend_worker_panic_does_not_crash_daemon
contract_hardlink_exclusivity_depends_on_scan_scope
contract_pdu_hardlink_conflicts_are_preserved_or_marked_unobservable
contract_pdu_hardlink_record_errors_not_lost_by_adapter
contract_pdu_deduplicated_tree_not_default_product_tree
contract_deduped_projection_never_replaces_measured_snapshot_truth
contract_measurement_profile_not_inherited_from_pdu_cli_defaults
contract_size_fact_profile_explicit_in_every_query
contract_datatree_not_used_as_application_query_store
contract_recursive_tree_conversion_does_not_define_node_identity
contract_pdu_cull_sort_retain_are_projection_only
contract_product_snapshot_keeps_truth_before_projection
contract_pdu_progress_sample_not_final_state
contract_pdu_linked_counter_not_hardlink_file_count
contract_pdu_terminal_reporters_not_used_in_daemon_mode
contract_reporter_teardown_failure_maps_to_backend_runtime_issue
contract_pdu_reporter_event_non_exhaustive_fallback
contract_operation_phase_publish_gate_prevents_half_indexed_snapshot
contract_raw_backend_time_reported_separately_from_query_ready_time
contract_pdu_global_rayon_pool_not_mutated_by_scan_session
contract_resource_profile_maps_to_explicit_execution_lane
contract_pdu_hdd_auto_not_product_resource_policy
contract_empty_target_resource_policy_runs_after_product_target_resolution
contract_cancel_requested_does_not_publish_late_pdu_output_as_current
contract_cancelled_or_partial_snapshot_cannot_build_delete_plan
contract_datatree_sort_retain_not_query_authority
contract_read_model_sort_uses_stable_tie_breakers
contract_node_id_not_derived_from_cross_snapshot_traversal_index
contract_pdu_root_name_and_child_name_have_different_path_semantics
contract_pdu_json_multi_root_shape_not_product_virtual_root_policy
contract_hardlink_reflection_path_order_not_authority
contract_pdu_display_string_not_path_authority
contract_non_utf8_path_has_native_authority_and_redacted_display
contract_pdu_terminal_text_not_logged_or_protocol
contract_symlink_dir_not_traversed_without_explicit_policy
contract_link_policy_fails_closed_for_destructive_actions
contract_scan_snapshot_is_not_current_delete_authority
contract_delete_preflight_revalidates_after_scan_race
contract_multi_target_virtual_root_is_product_owned
contract_scan_targets_never_default_to_dot_without_user_intent
contract_overlap_policy_independent_of_hardlink_mode
contract_empty_target_set_rejected_or_explicitly_expanded_by_product_policy
contract_pdu_overlap_removal_not_used_as_product_target_normalization
contract_target_overlap_decisions_are_reported_before_scan_start
contract_backend_output_contains_capability_and_completion_state
contract_capability_snapshot_required_for_every_scan_session
contract_unknown_capability_fails_closed_for_destructive_actions
contract_ports_live_in_application_not_domain
contract_pdu_args_do_not_cross_adapter_boundary
contract_depth_unlimited_not_encoded_as_u64_max_in_protocol
contract_fraction_threshold_rejects_nan_and_infinite
contract_pdu_quantity_default_not_product_default
contract_pdu_runtime_error_not_daemon_error_contract
contract_pdu_runtime_error_exit_codes_not_protocol_error_codes
contract_backend_failure_has_reason_severity_retryability_and_privacy_class
contract_threads_auto_max_not_resource_profile
contract_pdu_fraction_nan_never_reaches_adapter
contract_product_ratio_threshold_rejects_nan_and_infinite_before_pdu_mapping
contract_pdu_visualizer_not_used_in_daemon_protocol
contract_pdu_status_board_not_imported_by_daemon_scan_path
contract_pdu_terminal_text_reporters_not_used_in_daemon_scan_path
contract_pdu_bytes_format_not_size_semantics
contract_terminal_width_not_protocol_layout
contract_children_page_uses_node_ref_and_cursor_not_vec_index_authority
contract_protocol_int64_values_are_web_safe
contract_exact_size_values_not_sorted_as_js_number
contract_unknown_protocol_enum_fails_closed_for_destructive_actions
contract_delete_plan_requires_current_identity_revalidation
contract_pdu_default_features_disabled_in_production
contract_pdu_json_feature_not_required_for_product_protocol
contract_support_bundle_redacts_paths_tokens_queries
contract_pdu_treebuilder_materializes_children_not_streaming_nodes
contract_wide_directory_scan_has_memory_budget_and_degraded_state
contract_pdu_tree_dropped_after_arena_ingestion_when_budget_requires
contract_hardlink_dedup_projection_never_replaces_measured_size_fact
contract_hardlink_dedupe_path_prefix_convention_not_product_authority
contract_size_arithmetic_overflow_maps_to_adapter_failure_or_degraded_state
contract_pdu_compile_features_are_explicit_in_capability_snapshot
contract_unix_only_pdu_capability_not_assumed_on_windows
contract_pdu_import_allowlist_enforced
contract_pdu_cli_app_sub_forbidden_in_production_scan_path
contract_reusable_public_api_has_no_pdu_concrete_types
contract_pdu_json_and_reflection_allowed_only_for_diagnostics_or_fixtures
contract_pdu_tree_name_carries_adapter_traversal_key_in_rich_scan
contract_side_store_not_keyed_by_display_path_only
contract_side_store_evidence_survives_sort_cull_and_dedupe_projection
contract_pdu_callbacks_are_thread_safe_and_nonblocking
contract_pdu_traversal_done_is_not_query_ready_until_publish_gate
contract_scan_late_cancel_before_publish_discards_snapshot
contract_custom_pdu_tree_name_does_not_break_hardlink_projection
contract_traversal_key_not_used_as_path_prefix
contract_pdu_error_report_maps_to_rich_scan_issue_draft
contract_access_entry_issue_marks_parent_path_precision
contract_pdu_cli_projection_pipeline_not_snapshot_truth
contract_output_requirements_select_pdu_path_or_capability_gap
contract_fs_tree_builder_scan_marks_kind_self_size_and_conflicts_unknown
contract_custom_tree_builder_required_for_top_files_without_second_metadata_pass
contract_backend_output_contains_adapter_decision_record
contract_adapter_decision_record_explains_degraded_requirements
contract_pdu_backend_fingerprint_records_version_features_and_toolchain_surface
contract_pdu_upgrade_requires_fixture_and_capability_diff
contract_pdu_production_feature_graph_has_cli_and_json_disabled
contract_scan_tree_not_modeled_as_single_mutable_aggregate
contract_pdu_app_sub_and_overlapping_arguments_not_product_policy
contract_multi_root_virtual_root_owned_by_product_not_pdu_total
contract_pdu_runs_inside_local_rayon_pool_or_reports_fallback
contract_pdu_app_build_global_not_linked_in_production_adapter
contract_resource_profile_thread_budget_enforced_for_pdu_scan
contract_custom_tree_builder_cancellation_prunes_subtrees_only
contract_cooperative_cancellation_snapshot_never_cleanup_authority
contract_every_outward_value_has_evidence_fact_projection_capability_or_authority_class
contract_projection_never_builds_delete_plan
contract_queries_have_no_scanner_session_queue_or_cleanup_side_effects
contract_commands_do_not_return_full_recursive_tree_payloads
contract_protocol_dto_has_no_pdu_type_schema_or_operation_names
contract_event_stream_invalidates_but_does_not_replace_query_truth
```

## Tactical DDD Risk Addendum

### 58. DDD Role Confusion - `P0`

Risk: scan session, snapshot, node, pdu tree, protocol row, and cleanup
candidate are all called "entities", and the code slowly turns into one large
mutable model.

Why this is dangerous:

- pdu `DataTree` is a recursive aggregate-size projection, not product domain;
- a real scan can produce hundreds of thousands or millions of nodes;
- sorting, filtering, pagination, search, metadata enrichment, and UI selection
  are query/read-model concerns;
- cleanup authority needs current validation, not old scan tree ownership;
- large mutable aggregates make cancellation, publication, and persistence
  harder to reason about.

Mitigation:

- `ScanSession` and `DeletePlan` are the only MVP mutable aggregate roots;
- `ScanSnapshot` is immutable evidence referenced by id;
- `NodeArena` and indexes are read models, not DDD aggregates;
- `NodeArenaRecord` is an identity-bearing read-model record, not a domain
  entity that owns business behavior;
- domain services are pure policy evaluators over already parsed evidence;
- application services coordinate use cases and ports;
- pdu/platform/protocol/persistence details remain adapters.

Architecture gate:

```text
If a type is selected, sorted, paged, filtered, rendered, or cached for query
speed, it starts in the read-model/data side.

If a type enforces a transactional invariant, it may be an aggregate.

If a type comes from pdu, it is adapter evidence until mapped.
```

### 59. pdu Source Mechanic Becomes Domain Language - `P0`

Risk: pdu internals leak into our ubiquitous language and make future adapters
harder.

Examples:

- `DataTree::size()` becomes `node.size` without saying it is aggregate
  measured size;
- `ReceiveData` becomes a domain event;
- pdu `Operation::AccessEntry` becomes a public protocol enum;
- pdu `OsStringDisplay` becomes display path authority;
- pdu `HardlinkAware` result becomes reclaim truth;
- pdu JSON becomes product snapshot format.

Mitigation:

- every pdu type crosses only through `fs_usage_pdu`;
- adapter maps pdu mechanics to `SizeFact`, `ScanIssue`, `HardlinkEvidence`,
  `BackendCapability`, or `DiagnosticEvidence`;
- public API uses product terms and versioned product DTOs;
- cleanup code never reads pdu structs.

Contract tests:

```text
contract_pdu_source_terms_do_not_escape_adapter
contract_receive_data_is_adapter_progress_not_domain_event
contract_access_entry_maps_to_product_issue_code
contract_os_string_display_not_public_path_authority
contract_pdu_hardlink_projection_not_reclaim_truth
contract_pdu_json_not_product_snapshot_format
```

## First Rust Slice Decision Board

This board decides what to implement first when coding starts. It is intentionally
more concrete than the architecture notes.

### Adapter Entry Point Decision

Top 3 options:

1. pdu `FsTreeBuilder` scan-only adapter plus lazy metadata enrichment -
   🎯 8 🛡️ 7 🧠 5, roughly 1200-2500 LOC.
   Use only when the first slice is scan tree, aggregate size, progress, basic
   issues, and paged children. This is the fastest useful slice, but it cannot
   honestly provide all rich UI metadata during traversal.
2. custom pdu `TreeBuilder` adapter with side stores - 🎯 8 🛡️ 9 🧠 8,
   roughly 2500-5000 LOC.
   Use when the first product slice needs stable traversal keys, own size,
   kind, permissions, modified time, richer issue evidence, cancellation
   checkpoints, or top-file indexes without a second full metadata pass.
3. fork pdu before MVP - 🎯 5 🛡️ 7 🧠 9, roughly 4000-9000 LOC plus ongoing
   maintenance.
   Avoid before the adapter proves a hard blocker. Fork only for a narrow,
   upstreamable extension such as consuming visitor, cancellation hook, or richer
   `Info` payload.

Decision rule:

```text
If first coding goal is scan-only MVP, start with FsTreeBuilder.
If first coding goal is the saved UI reference with rich details from day one,
start with custom TreeBuilder side stores.
Do not fork pdu until an adapter spike proves the public API blocks us.
```

### Output Requirement Gate

Before coding `fs_usage_pdu`, write an `OutputRequirements` object in engine
language. It must decide the adapter mode.

```text
OutputRequirements
  aggregate_size_tree: required
  stable_node_refs: required
  paged_children: required
  progress_hint: required
  scan_issues: required
  full_path_reconstruction: required
  node_kind: lazy | during_scan
  own_size: lazy | during_scan
  modified_time: lazy | during_scan
  permissions: lazy | during_scan
  top_files: lazy_index | during_scan_index
  cooperative_cancellation: unsupported | checkpoints
  hardlink_evidence: none | bounded_samples | full_evidence
```

Mapping:

- `lazy` facts allow `FsTreeBuilder` first;
- `during_scan` facts push toward custom `TreeBuilder`;
- `cooperative_cancellation = checkpoints` requires custom `TreeBuilder` or a
  fork/upstream hook;
- `full_evidence` hardlinks cannot rely on pdu's default `FsTreeBuilder`
  because recorder errors are discarded.

### Domain Layer Coding Gate

First domain code should be boring and small.

Start with:

- ids and refs: `ScanSessionId`, `SnapshotId`, `NodeId`, `NodeRef`;
- value objects: `ScanTarget`, `MeasurementProfile`, `SizeFact`,
  `ScanIssue`, `ScanQuality`, `BackendCapability`;
- aggregates: `ScanSession`, `DeletePlan`;
- pure policies: `ScanQualityClassifier`, `MeasurementPolicy`,
  `CleanupEligibilityPolicy`.

Do not start domain with:

- `NodeArena`;
- pdu `DataTree`;
- protocol DTOs;
- repository traits;
- platform metadata structs;
- UI row models.

Reason:

```text
Domain starts with language and invariants.
Read models start with query performance.
Adapters start with translation.
```

### Application Layer Coding Gate

First application code should define ports and use-case flow before the adapter.

Required ports:

- `ScannerBackend`;
- `ReadModelWriter`;
- `ReadModelQueryStore`;
- `SnapshotRepository`;
- `EventSink`;
- `Clock`;
- `IdGenerator`;
- later `MetadataEnricher`, `IdentityProvider`, `TrashProvider`.

First use cases:

1. `CreateScanSession`;
2. `StartScan`;
3. `CancelScan`;
4. `GetChildrenPage`;
5. `GetNodeDetails`;
6. `GetCapabilities`.

Rules:

- application service owns session state and publish gate;
- adapter never publishes directly to protocol;
- backend output is not visible until `SnapshotPublicationGate` accepts it;
- cancelled/stale backend output is discarded by session epoch;
- query use cases read from `ReadModelQueryStore`, not from pdu `DataTree`.

### Data/Infrastructure Coding Gate

First infrastructure implementation can be incomplete, but must be honest.

`fs_usage_pdu` must implement:

- explicit pdu version/feature fingerprint;
- pdu options mapper;
- bounded execution lane;
- reporter snapshot with owned copied evidence;
- raw pdu scan result private type;
- converter from pdu tree to engine snapshot draft/read model;
- capability mapper that says what is unsupported.

`fs_usage_pdu` must not implement:

- product protocol DTOs;
- cleanup decisions;
- Trash/delete;
- UI sort/filter policy;
- app settings;
- daemon auth;
- persistence schema.

### High-Risk Coding Order

Recommended order:

1. Domain value objects and aggregate state machines - 🎯 9 🛡️ 9 🧠 5,
   roughly 700-1400 LOC.
2. Application ports and in-memory read model contracts - 🎯 9 🛡️ 9 🧠 6,
   roughly 1200-2400 LOC.
3. pdu adapter spike behind `ScannerBackend` - 🎯 8 🛡️ 8 🧠 7,
   roughly 1500-3500 LOC.
4. protocol DTO mapping and daemon routes - 🎯 8 🛡️ 8 🧠 6,
   roughly 1000-2200 LOC.
5. Flutter data adapter and paged queries - 🎯 8 🛡️ 8 🧠 6,
   roughly 1000-2500 LOC.

Avoid starting with UI data integration before step 3 proves real pdu output,
memory, progress, and issue semantics.

### Must-Know pdu Facts Before Coding

These are the facts that should be visible in code comments/tests, not just in
architecture prose:

1. pdu 0.23.0 latest crate metadata on 2026-05-20: Apache-2.0, default feature
   is `cli`, `json` is optional, `rust-version` is unknown.
2. production dependency should pin `=0.23.0` initially and disable default
   features.
3. pdu `FsTreeBuilder` returns `DataTree` through `From`, so errors are
   side-channel reporter events.
4. pdu `TreeBuilder` returns shape from `Info { size, children }`, so it cannot
   carry our domain facts unless we use side stores or custom `Name`.
5. pdu `DataTree` carries only name, aggregate size, children.
6. pdu `max_depth` is stored-depth/projection depth, not true traversal cutoff.
7. pdu progress counters are approximate hints, not product truth.
8. pdu hardlink dedupe mutates aggregate sizes and is not reclaim truth.
9. pdu CLI uses global Rayon pool configuration; daemon adapter must use a
   bounded execution lane instead.
10. pdu JSON/reflection is diagnostic/fixture format, not product protocol.

## pdu API Constraint Addendum

This section records API constraints that should shape the first adapter code.

### No-Default-Features Verification

Local verification on 2026-05-20:

```text
cargo check --lib --no-default-features
```

Result:

```text
parallel-disk-usage 0.23.0 compiled successfully as a library without default
features.
```

Important dependency finding:

```text
Even with --no-default-features, pdu still brings normal dependencies such as
rayon, dashmap, sysinfo, terminal_size, zero-copy-pads, derive_more,
derive_setters, smart-default, and several proc-macro/transitive crates.
```

Implication:

- `default-features = false` removes CLI/json behavior but not all terminal or
  system-information dependency surface;
- supply-chain review must evaluate pdu's no-default dependency tree, not only
  Cargo features;
- production adapter still needs import allowlists because modules like
  `status_board`, `visualizer`, `args`, and `app` are present in the crate even
  if we do not use them.

Contract:

```text
Production dependency can use pdu core without default features, but cannot
assume that no CLI-adjacent dependencies exist in the compiled graph.
```

### TreeBuilder Callback Copy Constraint

pdu `TreeBuilder` requires:

```text
GetInfo: Fn(&Path) -> Info<Name, Size> + Copy + Send + Sync
JoinPath: Fn(&Path, &Name) -> Path + Copy + Send + Sync
```

This is a real design constraint. A closure that captures owned `Arc<State>` by
move is not automatically `Copy`. The custom adapter must be designed around
copyable handles.

Top 3 approaches:

1. `CopyProbeHandle<'scan>` containing references to shared probe state -
   🎯 9 🛡️ 9 🧠 7, roughly 500-1200 LOC.
   Accepted for custom `TreeBuilder`. The handle is `Copy`; the referenced state
   owns atomics, sharded maps, bounded buffers, cancellation flag, and id
   allocator.
2. Global/thread-local scan registry keyed by scan id - 🎯 4 🛡️ 5 🧠 6,
   roughly 400-1000 LOC.
   Avoid. It makes tests and daemon lifecycle harder, and risks stale scan state
   after cancellation or panic.
3. Fork/upstream `TreeBuilder` to accept `Clone` instead of `Copy` - 🎯 5 🛡️ 7
   🧠 8, roughly 1000-2500 LOC plus upstream/fork maintenance.
   Consider only if the copyable handle pattern blocks real implementation.

Accepted sketch:

```text
PduProbeState
  cancellation_token
  node_id_allocator
  issue_store
  hardlink_store
  boundary_decision_store
  metadata_draft_store
  progress_counters

CopyProbeHandle<'scan>
  state: &'scan PduProbeState

get_info = CopyProbeHandle::get_info
join_path = CopyProbeHandle::join_path
```

Rules:

- `PduProbeState` is infrastructure, not application or domain;
- `CopyProbeHandle` must not write protocol events directly;
- callback work must stay bounded and low latency;
- callback must copy owned evidence immediately and never retain borrowed pdu
  paths/metadata beyond callback scope.

### Custom Name As Correlation Carrier

pdu `TreeBuilder` is generic over `Name`, and `DataTree<Name, Size>` preserves
that name. This is our main clean way to attach adapter correlation data without
forking pdu.

Accepted custom name shape:

```text
PduTreeName
  traversal_node_id
  file_name
  display_name_evidence
```

`join_path` uses only `file_name` to construct child paths. `DataTree` later
returns `PduTreeName`, so `PduTreeConverter` can join final tree nodes with
side-store evidence by `traversal_node_id`.

Do not use:

- pdu child `Vec` index as identity;
- display path as identity;
- sorted order as identity;
- pdu `OsStringDisplay` as public path authority.

Contract:

```text
PduTreeName is private adapter correlation data.
NodeId is product snapshot identity.
NodeRef is product protocol/query identity.
```

### Hardlink Evidence Strategy

`FsTreeBuilder` calls `record_hardlinks(...).ok()`, so recorder errors are
discarded by pdu. However, a custom recorder can still capture side effects
before returning.

Top 3 approaches:

1. Custom recorder stores evidence and returns `Ok(())` for expected conflicts -
   🎯 8 🛡️ 8 🧠 6, roughly 600-1400 LOC.
   Good for MVP plus diagnostics. Product confidence can degrade based on stored
   conflict evidence instead of trusting pdu's ignored error channel.
2. Use pdu `HardlinkAware` and summaries only - 🎯 5 🛡️ 5 🧠 3, roughly
   200-700 LOC.
   Too weak for product truth because it mutates aggregate projection and hides
   conflict details from the main path.
3. Full platform hardlink/reflink/accounting provider independent of pdu -
   🎯 7 🛡️ 9 🧠 9, roughly 2500-7000 LOC.
   Future path for accurate reclaim/accounting, not first scanner adapter.

Rule:

```text
Hardlink evidence can inform scan quality and display.
Hardlink evidence cannot become reclaim truth without platform accounting.
```

### FsTreeBuilder Versus Custom TreeBuilder Contract

`FsTreeBuilder` is acceptable only when these facts are enough:

- aggregate measured size;
- recursive final tree shape;
- approximate progress;
- side-channel filesystem errors;
- basic hardlink samples through custom reporter/recorder;
- lazy metadata enrichment after scan.

Custom `TreeBuilder` is required when product requirements include:

- stable traversal id attached to final `DataTree` nodes during traversal;
- own size without second metadata pass;
- file kind, symlink/reparse/cloud placeholder classification during traversal;
- boundary skip evidence;
- richer permission issue classification;
- cancellation checkpoints;
- full hardlink conflict evidence;
- top-file index without rewalking metadata after pdu scan.

Decision:

```text
FsTreeBuilder is the fastest adapter path.
Custom TreeBuilder is the product-grade adapter path.
The engine port must support both without changing domain/application code.
```

### Memory Duplication Gate

Both adapter paths initially build pdu `DataTree`. The engine then builds
`NodeArena` and indexes. That creates a temporary double-memory window.

Required mitigation:

- build `DataTree`;
- convert into compact arena/index drafts;
- publish only after conversion;
- drop `DataTree` immediately after conversion;
- record memory high-water marks for pdu tree, arena, indexes, and side stores;
- fail degraded or stop if resource budget is exceeded before publication.

Escalation if memory budget fails:

1. consuming converter or upstream `DataTree::into_parts` - 🎯 7 🛡️ 8 🧠 8,
   roughly 1000-3000 LOC;
2. custom scanner/read-model writer that bypasses pdu `DataTree` - 🎯 6 🛡️ 8
   🧠 9, roughly 4000-10000 LOC;
3. segmented snapshots/read-model persistence - 🎯 7 🛡️ 9 🧠 9, roughly
   5000-12000 LOC.

MVP rule:

```text
Accept temporary double memory only with measured budget, visible degraded
state, and DataTree drop-after-conversion test.
```

### Layer Placement For These Constraints

Domain layer:

- does not know `TreeBuilder`, `FsTreeBuilder`, `DataTree`, or `Copy` callback
  constraints;
- owns terms like `ScanQuality`, `SizeFact`, `NodeRef`, and `EvidenceConfidence`.

Application layer:

- owns `OutputRequirements`;
- chooses required capability level through ports;
- rejects unsupported backend capabilities before pretending a feature works;
- owns scan session lifecycle and publication gate.

Data/infrastructure layer:

- owns pdu callback handles;
- owns side stores;
- owns pdu dependency feature policy;
- owns conversion and evidence mapping;
- exposes only engine contracts outward.

Protocol/data-client layer:

- sees product DTOs only;
- never sees pdu names, callback phases, or dependency feature details.

### Pre-Coding Stop Rules

Stop and revisit architecture if any of these happen:

- a public type contains `Pdu`, `DataTree`, `FsTreeBuilder`, `TreeBuilder`,
  `Reporter`, or pdu `Operation`;
- a cleanup command accepts only a raw path string;
- a domain object imports `std::fs`, pdu, HTTP, SQLite, or platform Trash code;
- a query endpoint returns a recursive full tree;
- a WebSocket event is treated as complete query truth;
- pdu progress counters are displayed as exact node/file counts;
- pdu hardlink adjusted size is used as reclaim estimate;
- a custom `TreeBuilder` side store is keyed only by display path;
- cancellation claims immediate stop while pdu is still running;
- adapter cannot prove `DataTree` is dropped after arena ingestion.

## Architecture Acceptance Gates Derived From pdu Internals

This section turns pdu research into concrete gates for the first implementation
PRs. A gate is stronger than a note: if it fails, the implementation should not
ship.

### Gate 1: pdu Is Discoverer, Not Product Model

pdu can discover paths and aggregate sizes quickly. It cannot define our product
truth.

Acceptance:

- no public Rust type outside `fs_usage_pdu` contains `DataTree`,
  `FsTreeBuilder`, `TreeBuilder`, `Info`, `Reporter`, pdu `Event`,
  pdu `Operation`, `OsStringDisplay`, pdu `Bytes`, or pdu `Blocks`;
- `fs_usage_engine` accepts `BackendScanOutput`, not pdu raw output;
- `NodeArenaRecord` contains `SizeFacts`, `NodeKindState`, `IssueRefs`, and
  `EvidenceRefs`, not pdu structs;
- protocol DTO names are product names, not pdu names.

Tests:

```text
contract_pdu_types_do_not_cross_adapter_boundary
contract_backend_scan_output_contains_no_pdu_public_types
contract_protocol_schema_contains_no_pdu_terms
```

### Gate 2: pdu Error Side Channel Is Joined With Tree Output

`FsTreeBuilder` returns a `DataTree` even when traversal errors occur. Errors
arrive via `Reporter::Event::EncounterError`.

Acceptance:

- adapter result includes tree evidence and issue evidence together;
- a non-empty `DataTree` with permission errors maps to degraded scan quality;
- missing root does not become a silent successful zero-size result;
- pdu operation names are mapped to product issue codes.

Tests:

```text
contract_pdu_tree_with_errors_maps_to_partial_scan
contract_missing_root_not_silent_zero_success
contract_pdu_operation_names_mapped_to_product_issue_codes
```

### Gate 3: pdu Reflection And JSON Are Not Trusted Snapshot Formats

pdu `DataTree` does not implement serde directly. It converts through
`Reflection`. `Reflection::par_try_into_tree` validates only the simple child
size invariant and pdu CLI UTF-8 conversion can reject non-UTF-8 names.

Acceptance:

- product cache schema is not pdu JSON;
- product snapshot load validates product manifest, backend fingerprint,
  protocol version, node refs, issue refs, measurement profile, and projection
  policy;
- pdu JSON may be used only for fixtures or diagnostics with explicit labels;
- non-UTF-8 paths remain representable in Rust product read models.

Tests:

```text
contract_pdu_json_not_product_snapshot_cache
contract_reflection_validation_not_product_validation
contract_non_utf8_node_name_survives_product_read_model
```

### Gate 4: Size Semantics Are Explicit

pdu `DataTree::size()` is aggregate measured size for the selected pdu size
getter. pdu README also states it is ignorant of reflinks, and pdu does not
solve APFS/Btrfs/ZFS shared extents or snapshot reclaim semantics.

Acceptance:

- `SizeFacts.aggregate_measured` is separate from `own_measured`;
- `logical_bytes`, `allocated_bytes`, `hardlink_adjusted_bytes`,
  `exclusive_reclaim_estimate`, and `observed_free_space_delta` are separate
  facts;
- pdu aggregate size never becomes reclaim estimate;
- reflink/shared-extent support is a filesystem accounting adapter capability,
  not a pdu scanner capability.

Tests:

```text
contract_pdu_size_maps_only_to_aggregate_measurement
contract_reclaim_estimate_never_uses_pdu_aggregate_directly
contract_reflink_limitation_visible_in_backend_capabilities
```

### Gate 5: Traversal Depth Is Not Lazy Loading

pdu `max_depth` controls stored child arrays, but deeper descendants can still
be traversed and included in aggregate size.

Acceptance:

- product API distinguishes traversal completeness from visible child
  completeness;
- hidden-by-depth descendants are not cleanup targets;
- expand-child query cannot pretend to load missing descendants from pdu
  `DataTree`;
- lazy expansion requires a new scan/query strategy, not a UI-only action.

Tests:

```text
contract_max_depth_hidden_descendants_not_cleanup_targets
contract_child_completeness_distinguishes_visible_and_traversed
contract_expand_hidden_depth_requires_rescan_or_indexed_snapshot
```

### Gate 6: Ordering Is Engine-Owned

pdu traversal uses filesystem order and Rayon parallel recursion. pdu sorting is
helper mutation and uses unstable sorting.

Acceptance:

- UI/protocol ordering comes from engine indexes;
- equal-size rows have deterministic tie-breakers in product query code;
- pdu `DataTree` child order is never cursor authority;
- pagination cursors reference snapshot, parent, query, sort, filter, and
  stable position token.

Tests:

```text
contract_pdu_child_order_not_protocol_order
contract_equal_size_sort_has_product_tie_breaker
contract_children_cursor_not_pdu_vec_index_authority
```

### Gate 7: Resource And Cancellation Semantics Are Honest

pdu has no true cooperative cancellation in `FsTreeBuilder`. Custom
`TreeBuilder` can add checkpoints only inside adapter-owned `get_info`.

Acceptance:

- API distinguishes `cancel_requested`, `backend_still_running`, `discarded`,
  and terminal `canceled`;
- stale pdu result is discarded by session epoch;
- Fast/Balanced/Background resource profiles map to bounded execution lanes;
- progress is approximate and never exact file/node count.

Tests:

```text
contract_cancel_requested_not_terminal_canceled_until_backend_outcome
contract_stale_pdu_result_discarded_by_epoch
contract_progress_hint_not_exact_count
contract_resource_profile_maps_to_bounded_execution_lane
```

### Gate 8: Domain, Application, Data Responsibilities Stay Separated

Domain layer acceptance:

- contains value objects, aggregate states, and pure policies only;
- no pdu, filesystem IO, HTTP, WebSocket, SQLite, Tokio, Rayon, or platform
  Trash imports;
- does not contain read-model indexes.

Application layer acceptance:

- owns use cases, ports, session lifecycle, publication gate, and capability
  checks;
- does not import pdu or protocol DTOs;
- does not publish full recursive trees.

Data/infrastructure layer acceptance:

- owns pdu import, callback handles, bounded side stores, conversion, and
  backend fingerprint;
- maps all pdu data to engine/domain terms before returning.

Tests:

```text
contract_domain_has_no_infrastructure_imports
contract_application_has_no_pdu_or_protocol_dto_imports
contract_infrastructure_returns_engine_contracts_only
```

### Gate 9: Cleanup Authority Is Never Derived From Scan Rows

pdu scan data is stale by definition after the scan finishes. UI selection is
not delete authority.

Acceptance:

- `DeletePlan` requires `NodeRef`, snapshot id, user intent, and current
  revalidation evidence;
- delete preflight re-reads path identity and metadata through platform ports;
- stale/missing/moved/permission-conflict states fail closed;
- path string alone cannot execute cleanup.

Tests:

```text
contract_delete_plan_requires_current_identity_evidence
contract_raw_path_string_cannot_execute_cleanup
contract_stale_snapshot_node_blocks_destructive_action
```

### Gate 10: Adapter Evolution Is Planned

The engine port must support pdu `FsTreeBuilder`, custom pdu `TreeBuilder`,
future Windows MFT fast path, and a non-pdu scanner without changing domain.

Acceptance:

- `ScannerBackendCapabilities` reports unsupported facts explicitly;
- `OutputRequirements` selects acceptable backend mode;
- unsupported requirements fail before scan or produce degraded state, not fake
  data;
- backend fingerprint is stored with snapshot evidence.

Tests:

```text
contract_backend_capabilities_drive_output_requirements
contract_unsupported_requirement_fails_or_degrades_explicitly
contract_backend_fingerprint_stored_with_snapshot_manifest
```

### First PR Minimum Bar

First Rust scanner PR should not be considered complete until it passes at least
these gates:

```text
Gate 1 pdu boundary
Gate 2 error side channel
Gate 4 size semantics
Gate 7 cancellation honesty
Gate 8 layer separation
Gate 10 backend capability reporting
```

Do not include cleanup execution in the first scanner PR.

## What To Remember

The risky part is not scanning. pdu can scan.

The risky part is preserving product truth:

```text
size truth
path identity truth
session truth
progress truth
permission truth
cleanup authority truth
protocol compatibility truth
privacy truth
```

pdu gives evidence for some of these. Our architecture must create and protect
the rest.
