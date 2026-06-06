# Preimplementation Critical Research Sequence

Last updated: 2026-05-16.

This document fixes the ordered preimplementation research plan for Clean Disk. It consolidates the critical unknowns that must be resolved before serious scanner, daemon, cleanup, and large-tree UI implementation.

The goal is not to block all coding forever. The goal is to avoid building on contracts that later break under millions of filesystem nodes, platform permissions, Trash behavior, browser security rules, or destructive cleanup workflows.

## Sources Reviewed

Primary and official sources already used across the deeper documents:

- `parallel-disk-usage` docs.rs and GitHub docs for scanner output, hardlinks, symlinks, progress, and library integration.
- Rust std docs for `metadata`, `symlink_metadata`, `canonicalize`, `read_dir`, `remove_dir_all`, `Vec::try_reserve`, `HashMap`, `BTreeMap`, and path behavior.
- Tokio docs for bounded `mpsc`, `broadcast` lag handling, semaphores, and `spawn_blocking` limits.
- Rayon docs for explicit thread pool configuration.
- RFC 9110 for HTTP command/query semantics.
- RFC 6455 for WebSocket transport semantics.
- RFC 9457 for structured HTTP problem details.
- OWASP WebSocket, REST, CSRF, Logging, Input Validation, and CSP cheat sheets.
- Chrome and Edge docs around Private Network Access / Local Network Access behavior.
- MDN WebSocket API and WebSocketStream docs, especially stable WebSocket lacking application backpressure.
- Flutter performance docs, DevTools performance docs, `ListView.builder`, `DataTable`, `FutureBuilder`, isolates, background JSON parsing, and long-list guidance.
- Flutter `two_dimensional_scrollables` package docs for `TableView`.
- WAI-ARIA treegrid pattern for accessible tree/table behavior.
- Apple APFS, URLResourceValues, FileManager trash item, security-scoped bookmarks, App Sandbox, notarization, hardened runtime, and Time Machine local snapshots docs.
- Microsoft FILE_ID_INFO, BY_HANDLE_FILE_INFORMATION, FILE_STANDARD_INFO, CreateFileW reparse behavior, DeleteFile, file access rights, IFileOperation, SmartScreen, MSIX, long paths, Controlled Folder Access, VSS, ReFS block clone, Data Deduplication, and Cloud Files docs.
- Linux man-pages for `statx`, `open`, `openat2`, `unlink`, `rename`, and `stat`.
- Linux FIEMAP kernel docs.
- FreeDesktop Trash specification.
- Btrfs reflink and qgroup docs.
- OpenZFS zfsprops docs.
- SQLite transaction/WAL/atomic commit docs and Drift/Flutter local persistence docs for operation journal direction.
- cargo-nextest, proptest, cargo-fuzz, Miri, loom, Criterion, RustSec, cargo-deny, Flutter testing, golden testing, Dart analyze, Melos docs for quality gates.

## Ordered Decision

Implementation should be sequenced like this:

```text
0. pdu adapter capability spike
1. platform identity + delete revalidation + Trash reality
2. reclaim accounting confidence model
3. Rust read model memory + pagination + indexes
4. metadata enrichment cost and lazy strategy
5. traversal policy
6. protocol streaming/backpressure/reconnect
7. daemon security model
8. resource governance and scan modes
9. installer/permissions/daemon identity
10. persistent operation journal
11. Flutter large-tree virtualization
12. testing fixture lab and release gates
```

Some work can run in parallel, but the dependency order matters:

- UI virtualization depends on paginated query contracts.
- Delete UI depends on identity, Trash, reclaim, and operation journal contracts.
- Protocol streaming depends on read-model snapshots and session lifecycle.
- Installer permission UX depends on which process actually scans and trashes.
- Testing fixtures should start early, then grow as each spike lands.

## 0. pdu Adapter Capability Spike

Status: accepted as the first scanner spike.

Reference docs:

- `docs/technical/pdu-adapter-capability-spike.md`
- `docs/technical/implementation-edge-cases-pdu-adapter-integration.md`

Decision:

Use `parallel-disk-usage` as the first Rust scanner backend, but only behind an adapter. Do not expose pdu types through `fs_usage_*` public contracts.

Score:

1. pdu library adapter first - 🎯 8 🛡️ 8 🧠 7, roughly 800-1800 LOC spike/tests.
2. fork pdu immediately - 🎯 5 🛡️ 6 🧠 8, roughly 1500-5000 LOC plus maintenance burden.
3. write our scanner from scratch now - 🎯 3 🛡️ 5 🧠 9, roughly 4000-12000 LOC before matching pdu performance.

Must prove before implementation:

- raw pdu scan time separate from indexing/protocol/UI;
- final tree output shape and memory cost;
- progress signal quality;
- cancellation behavior and late output behavior;
- hardlink policy and cost;
- symlink behavior;
- mount boundary behavior;
- skipped/error mapping;
- max-depth and traversal option mapping;
- whether pdu can be driven without CLI wrapping.

Accepted guardrail:

```text
pdu -> scanner adapter -> fs_usage snapshot/read model
```

Never:

```text
pdu DataTree -> Flutter
pdu CLI JSON -> production app protocol
```

## 1. Platform Identity, Delete Revalidation, And Trash Reality

Status: accepted as the most safety-critical destructive workflow spike.

Reference docs:

- `docs/technical/implementation-edge-cases-platform-identity-delete-revalidation.md`
- `docs/technical/implementation-edge-cases-cleanup-delete-safety.md`

Decision:

Cleanup authority is a short-lived `DeletePlan`, not a path string. The plan stores identity evidence, scan snapshot, accounting snapshot, confirmation token, and operation journal entry. Every selected item is re-probed immediately before Trash/delete.

Score:

1. Evidence bundle + preflight + native Trash port - 🎯 10 🛡️ 10 🧠 8, roughly 1400-3200 LOC spike/tests.
2. Use `trash` crate directly with our preflight wrapper - 🎯 7 🛡️ 7 🧠 6, roughly 700-1800 LOC, acceptable only after audit.
3. Manual move/delete by path - 🎯 1 🛡️ 1 🧠 4, roughly 300-900 LOC but unsafe.

Must prove before cleanup implementation:

- macOS `FileManager.trashItem` returns resulting Trash URL and maps errors cleanly;
- Windows `IFileOperation` with `FOFX_RECYCLEONDELETE` works in no-surprise daemon mode;
- Linux FreeDesktop Trash works for home, external volumes, network/mount edge cases, and unsupported cases;
- stale path replaced by symlink/junction/reparse point is blocked;
- delete permission is checked separately from read permission;
- partial Trash result creates item-level receipt;
- unsupported Trash never falls back to permanent delete without explicit user action.

Accepted guardrail:

```text
UI node selection
  -> server DeletePlan
  -> identity revalidation
  -> TrashAdapter
  -> durable receipt
```

Never:

```text
UI path string
  -> recursive delete
```

## 2. Reclaim Accounting Confidence Model

Status: researched and fixed.

Reference docs:

- `docs/technical/reclaim-accounting-deep-research.md`
- `docs/technical/implementation-edge-cases-storage-accounting-snapshots-shared-extents.md`

Decision:

Do not promise exact reclaim before action. Model `logical_bytes`, `allocated_local_bytes`, `exclusive_reclaim_estimate`, `quota_effect`, `confidence`, `basis`, `uncertainty`, and post-action `observed_free_space_delta`.

Score:

1. Conservative estimate + confidence + observed receipt - 🎯 10 🛡️ 10 🧠 7, roughly 1000-3000 LOC gradually.
2. Show only logical folder size and hide reclaim confidence - 🎯 4 🛡️ 5 🧠 3, roughly 300-900 LOC but misleading.
3. Try exact pre-delete reclaim on every platform - 🎯 2 🛡️ 4 🧠 10, roughly 5000-20000 LOC and still impossible for many cases.

Accepted guardrail:

Fast scan can show size. Delete plan must show estimated reclaim with confidence. Receipt must show observed free-space delta.

## 3. Rust Read Model Memory, Pagination, And Indexes

Status: must be researched and spiked before large UI or full protocol implementation.

Reference docs:

- `docs/technical/implementation-edge-cases-performance-scale.md`
- `docs/technical/implementation-edge-cases-search-query-indexing.md`
- `docs/technical/architecture-future-risks.md`
- `docs/technical/rust-best-practices.md`

Decision:

Use a Rust-owned, append-oriented, compact node arena plus explicit query indexes. Flutter receives pages only. Do not store full paths per node by default. Do not build all possible indexes upfront.

Score:

1. In-memory compact arena + lazy/targeted indexes - 🎯 8 🛡️ 9 🧠 8, roughly 1200-3000 LOC spike/tests.
2. SQLite/Drift-like persisted read model for active tree - 🎯 5 🛡️ 8 🧠 9, roughly 2500-7000 LOC, useful later for history but slower for MVP live tree.
3. Full tree JSON in Flutter - 🎯 1 🛡️ 1 🧠 3, roughly 500-1500 LOC but fails at scale.

Recommended structure:

```text
NodeArena
  nodes: Vec<NodeRecord>
  names: StringInterner or Arc<str> after profiling
  parent: NodeId
  first_child/child_count or child index ranges
  sizes/counters/flags as compact numeric fields

Indexes
  children_by_parent
  top_folders_by_size
  top_files_by_size
  search_name_index, MVP substring/simple token
  warnings/skipped index
  cleanup_candidate index

Queries
  children(parent, cursor, sort, filter, limit)
  top(scope, kind, cursor, limit)
  search(query, cursor, limit)
  details(node_id)
```

Must prove in spike:

- memory per node for 100k, 1M, and 5M synthetic nodes;
- peak memory when converting from pdu tree into our read model;
- ability to drop raw pdu tree after conversion;
- deterministic sorting and pagination with stable tie-breakers;
- cursor includes session, snapshot, parent/scope, sort, filter hash, and boundary key;
- one folder with 500k direct children does not require global resort on every page;
- search/top lists do not scan millions of nodes per keystroke;
- allocation failures return typed `resource_exhausted`, not process death where avoidable.

Accepted guardrails:

- Node ID is opaque and scoped to scan snapshot/index version.
- Store name segment and parent ID, not full path per row.
- Reconstruct full path lazily for details, reveal, receipt, and delete plan.
- Build only indexes needed for shipped UI.
- Use `try_reserve` or equivalent at large growth points.
- Never derive UI order from `HashMap` iteration.

Open technical question:

Should the first arena use simple `Vec<NodeRecord>` with generational IDs later, or start with a `slotmap`/generational arena style? Current recommendation: simple typed `NodeId(u32/u64)` over append-only `Vec` for scan snapshots. Deletion from the arena is not needed for an immutable scan snapshot, so generational complexity can wait.

## 4. Metadata Enrichment Cost And Lazy Strategy

Status: critical to avoid making pdu fast but product slow.

Reference docs:

- `docs/technical/reclaim-accounting-deep-research.md`
- `docs/technical/implementation-edge-cases-filesystem-model.md`
- `docs/technical/implementation-edge-cases-performance-scale.md`

Decision:

Split metadata into scan-time minimum, index-time cheap enrichment, selected-node enrichment, and delete-plan mandatory revalidation. Do not collect expensive metadata for every filesystem entry during the fast scan.

Score:

1. Tiered metadata enrichment - 🎯 9 🛡️ 9 🧠 7, roughly 900-2400 LOC.
2. Collect all metadata during scan - 🎯 3 🛡️ 5 🧠 5, roughly 600-1800 LOC but likely destroys performance.
3. Collect no metadata until delete - 🎯 5 🛡️ 7 🧠 4, roughly 400-1200 LOC but weak details/search/warnings.

Recommended tiers:

```text
Tier 0, scanner baseline:
  name
  kind if known
  logical/allocated size if scanner gives it cheaply
  child totals
  skipped/error basics

Tier 1, cheap index enrichment:
  parent/child relationship
  item counts
  extension/type bucket
  modified time if available from scanner/stat without extra expensive call
  warning flags already emitted by scanner

Tier 2, selected-node enrichment:
  permissions
  owner/group if needed
  cloud/reparse/provider flags
  APFS/NTFS allocated details
  top child category breakdown
  exact path reconstruction

Tier 3, delete-plan revalidation:
  live identity evidence
  delete permission evidence
  Trash support
  hardlink/reclaim policy
  stale path check
  operation risk tier
```

Must prove in spike:

- cost of `stat/lstat/statx` per node on APFS, NTFS, ext4, network share if available;
- cost of Apple URLResourceValues/getattrlist for selected folders;
- cost of Windows handle open and FILE_STANDARD_INFO;
- cost of detecting cloud/reparse/placeholder state;
- UI value of each metadata field versus scan slowdown.

Accepted guardrails:

- Details panel may load extra metadata asynchronously.
- Delete plan must never rely only on stale scan metadata.
- Metadata source and freshness are part of the read model.
- Expensive metadata jobs need bounded concurrency and cancellation.

## 5. Traversal Policy

Status: must be explicit before scanner integration.

Reference docs:

- `docs/technical/rust-best-practices.md`
- `docs/technical/implementation-edge-cases-pdu-adapter-integration.md`
- `docs/technical/architecture-future-risks.md`
- `docs/technical/implementation-edge-cases-cloud-network-virtual-filesystems.md`

Decision:

Default traversal is conservative: do not follow symlink/reparse-point directories, do not silently cross dangerous provider boundaries, expose mount boundary behavior, and record every skipped/unsupported state as first-class output.

Score:

1. Explicit conservative traversal policy - 🎯 10 🛡️ 10 🧠 7, roughly 800-2200 LOC.
2. Follow OS/tool defaults silently - 🎯 2 🛡️ 3 🧠 3, roughly 200-700 LOC but impossible to explain safely.
3. Aggressive "scan everything" mode by default - 🎯 3 🛡️ 2 🧠 6, roughly 900-2500 LOC and risky.

Policy fields:

```text
follow_symlinks: false
follow_windows_reparse_points: false
cross_mounts: ask or false for system-wide scan, true only when target is explicit
include_hidden: true for disk usage
respect_ignore_files: false by default for disk usage
max_depth: optional
scan_packages_as_dirs: true, but classify bundles/packages
network_shares: scan with low confidence and reduced parallelism
cloud_placeholders: classify; do not hydrate by default
pseudo_filesystems: skip
system_managed_storage: classify and block cleanup
```

Must prove in spike:

- pdu's actual symlink behavior and how it surfaces symlink nodes;
- root is symlink: scan link, scan target, or reject behavior;
- Windows junction/reparse behavior;
- APFS firmlinks/system paths if relevant;
- mount boundary detection on macOS, Windows, Linux;
- cloud placeholder behavior without hydration;
- skipped paths are queryable and visible in UI.

Accepted guardrails:

- Traversal policy is stored in scan metadata.
- UI can show "partial scan" with reasons.
- Search results and delete queue include traversal policy context.
- Cleanup never follows a link/reparse point just because scan displayed it.

## 6. Protocol Streaming, Backpressure, And Reconnect

Status: accepted architecture exists; needs concrete spike after read model contract.

Reference docs:

- `docs/technical/implementation-edge-cases-transport-protocol-streaming.md`
- `docs/technical/transport-client-generation-research.md`
- `docs/technical/implementation-edge-cases-concurrency-state-machines.md`

Decision:

HTTP commands/queries are authoritative. WebSocket emits bounded, loss-aware notifications and progress snapshots. Reconnect recovers by HTTP resync, not by assuming every event was delivered.

Score:

1. HTTP query truth + lossy/coalesced WS events - 🎯 10 🛡️ 10 🧠 6, roughly 700-1800 LOC spike/tests.
2. JSON-RPC over WebSocket for everything - 🎯 7 🛡️ 8 🧠 8, roughly 1500-3500 LOC and better for future orchestrator, not Clean Disk MVP.
3. Raw per-node event stream - 🎯 1 🛡️ 2 🧠 6, roughly 600-2000 LOC and will overload UI.

Event classes:

```text
lossless:
  terminal state
  delete item result
  plan invalidated
  fatal error

coalescable:
  scan progress
  current path
  throughput
  counters

invalidation:
  index ready
  query cache stale
  session snapshot changed
```

Required protocol:

```text
session_id
stream_id
sequence
snapshot_id
event_type
occurred_at
payload
```

Must prove in spike:

- slow client with full queue gets lag event and HTTP resync path;
- reconnect with `after_seq` works within retention window;
- reconnect outside retention window returns `resync_required`;
- terminal events are not lost silently;
- progress updates are throttled to UI frame needs;
- event queue memory is bounded;
- Flutter store can rebuild screen from HTTP only after socket drop.

Accepted guardrails:

- No tree pages over WebSocket.
- No large search results over WebSocket.
- No destructive commands over WebSocket in MVP.
- Browser stable WebSocket has no reliable app backpressure; server must own throttling.

## 7. Daemon Security Model

Status: must be implemented before any browser/web UI talks to local daemon.

Reference docs:

- `docs/technical/implementation-edge-cases-security-privacy.md`
- `docs/technical/implementation-edge-cases-web-ui-daemon-runtime.md`
- `docs/technical/implementation-edge-cases-remote-headless-mode.md`

Decision:

Localhost is not auth. Local daemon must bind loopback only, use random port, require per-session token, validate Host/Origin, use narrow CORS, avoid cookies, enforce rate/body limits, and never expose delete-capable remote mode by accident.

Score:

1. Hardened local daemon protocol from day one - 🎯 10 🛡️ 10 🧠 7, roughly 800-2200 LOC.
2. Desktop-only direct process bridge first, daemon security later - 🎯 4 🛡️ 5 🧠 5, roughly 500-1600 LOC but conflicts with web UI goal.
3. Open localhost API with no auth during MVP - 🎯 1 🛡️ 1 🧠 2, roughly 100-400 LOC but unacceptable.

Required behavior:

- bind only to `127.0.0.1` and `[::1]` in local mode;
- random local port unless explicitly configured;
- token required for every HTTP and WS connection;
- token never appears in URL;
- no cookie auth;
- custom auth header for HTTP;
- secure WS handshake token mechanism;
- explicit Origin and Host allowlist;
- no wildcard CORS;
- request body/message size limits;
- connection and rate limits;
- logs redact token, raw paths, raw search text, and raw delete targets;
- delete-capable remote listen requires separate explicit profile and authZ design.

Must prove in spike:

- hostile Origin rejected;
- hostile Host/DNS rebinding-style request rejected;
- missing token rejected for HTTP and WS;
- token in URL not supported;
- CORS wildcard absent;
- PNA/LNA browser behavior tested in Chrome/Edge/Safari/Firefox where practical;
- production web UI served by daemon has strict CSP.

Accepted guardrail:

Default local web path is daemon-served loopback UI, not a hosted website connecting to localhost, until hosted pairing/PNA/CORS semantics are explicitly implemented.

## 8. Resource Governance And Scan Modes

Status: needed before performance claims.

Reference docs:

- `docs/technical/implementation-edge-cases-resource-governance.md`
- `docs/technical/implementation-edge-cases-performance-scale.md`

Decision:

Ship with explicit resource profiles: `Balanced` default, `Fast` opt-in, `Background` low-impact. All scanner, metadata, indexing, and event delivery work runs under bounded budgets.

Score:

1. Bounded worker pool + scan profiles - 🎯 9 🛡️ 9 🧠 7, roughly 900-2200 LOC.
2. Let pdu/Rayon/Tokio choose defaults - 🎯 4 🛡️ 5 🧠 4, roughly 300-900 LOC but risky and hard to debug.
3. Max-speed default - 🎯 5 🛡️ 4 🧠 5, roughly 500-1200 LOC but likely bad UX.

Profile defaults:

```text
Balanced:
  default
  moderate worker count
  bounded metadata concurrency
  throttled progress events
  responsive UI priority

Fast:
  opt-in
  higher worker count
  more aggressive IO
  warns about battery/fan/system load

Background:
  lower worker count
  slower progress
  reduced CPU/IO pressure
  preferred on battery/network/removable targets
```

Must prove in spike:

- scan does not starve HTTP status endpoint;
- pause/cancel works while scan is busy;
- worker count can be configured or bounded even when pdu uses Rayon;
- network/external/cloud targets automatically reduce parallelism;
- progress event rate remains bounded;
- memory ceiling is enforced per session;
- benchmark reports include CPU, memory, queue lengths, and target class.

Accepted guardrails:

- One daemon process with internal bounded pools, not microservices.
- No unbounded Tokio/Rayon/thread stacking.
- Fast mode is never silently enabled.

## 9. Installer, Permissions, And Daemon Identity

Status: must be validated before claiming desktop install is convenient.

Reference docs:

- `docs/technical/implementation-edge-cases-platform-permissions-packaging.md`
- `docs/technical/implementation-edge-cases-operational-reliability.md`

Decision:

Direct native desktop distribution is the MVP baseline. Store/sandboxed builds are separate capability profiles. The scanner process identity must be known and tested: whichever process scans needs the permissions.

Score:

1. Direct signed app + bundled daemon/helper + capability doctor - 🎯 9 🛡️ 9 🧠 7, roughly 1000-3000 LOC/config/tests.
2. Store/sandbox-first packaging - 🎯 4 🛡️ 6 🧠 8, roughly 1500-5000 LOC and likely reduced scan power.
3. Dev-only launcher assumptions - 🎯 2 🛡️ 2 🧠 3, roughly 300-900 LOC but not product-ready.

Must decide before implementation:

- does Flutter process spawn daemon child, or daemon is installed as helper/service?
- which process asks for/receives macOS Full Disk Access or security-scoped folder access?
- how direct app bundle signs daemon/helper;
- how update preserves permissions and helper path;
- Windows installer choice: signed installer vs MSIX first;
- Windows long-path manifest and Controlled Folder Access behavior;
- Linux package profiles: AppImage/native package first, Snap/Flatpak later with limitations.

Accepted guardrails:

- Capability endpoint exposes `package_mode`, `sandboxed`, `scan_authority`, `trash_authority`, `permission_grants`, and known limitations.
- Permission doctor runs before full-disk scan.
- Partial scan must be visibly labeled.
- Debug builds do not define final permission UX.

## 10. Persistent Operation Journal

Status: required before destructive workflows, optional for pure scan MVP.

Reference docs:

- `docs/technical/implementation-edge-cases-operational-reliability.md`
- `docs/technical/implementation-edge-cases-local-state-persistence.md`
- `docs/technical/implementation-edge-cases-cleanup-delete-safety.md`

Decision:

Use a durable operation journal for destructive and receipt-producing workflows. Scan progress can be ephemeral. Delete plans, confirmations, item outcomes, receipts, and idempotency records must survive app/daemon crash.

Score:

1. SQLite/Drift-backed operation journal for delete/receipts - 🎯 9 🛡️ 10 🧠 7, roughly 800-2200 LOC.
2. Append-only JSONL journal - 🎯 7 🛡️ 7 🧠 6, roughly 500-1500 LOC, easier but needs compaction/corruption handling.
3. In-memory operation state only - 🎯 2 🛡️ 2 🧠 2, roughly 200-600 LOC but unsafe.

Journal must record:

```text
operation_id
operation_type
state
created_at
updated_at
idempotency_key
scan_snapshot_id
delete_plan_id
plan_hash
confirmation_token_id
item_outcomes
native_adapter_result
observed_free_space_before
observed_free_space_after
receipt_id
recovery_action
```

Must prove in spike:

- crash before native Trash call recovers as not executed;
- crash after partial item results recovers exact item outcomes where known;
- retry with same idempotency key does not duplicate destructive work;
- idempotency key with different payload is rejected;
- receipt persists even if UI closed;
- corrupted journal has safe recovery mode;
- support bundle redacts paths/tokens.

Accepted guardrails:

- Operation journal is not the scan tree store.
- Delete button disabled if journal cannot persist required intent.
- Receipt says unknown when native state cannot be recovered, not "success".

## 11. Flutter Large-Tree Virtualization

Status: can start after read-model/protocol shape is stable.

Reference docs:

- `docs/technical/implementation-edge-cases-flutter-large-tree-ui.md`
- `docs/design/references/clean-disk-wide-reference.png`
- `docs/design/references/clean-disk-compact-reference.png`

Decision:

Build a design-system `TreeTable` facade backed first by a virtualized fixed-row list. Keep implementation swappable so we can move to `TableView`/two-dimensional virtualization later without rewriting feature state.

Score:

1. Virtualized fixed-row tree table behind design-system facade - 🎯 9 🛡️ 9 🧠 8, roughly 1600-4200 LOC.
2. `TableView` from `two_dimensional_scrollables` first - 🎯 7 🛡️ 8 🧠 8, roughly 1800-5000 LOC and needs package maturity/semantics validation.
3. Material `DataTable`/full list - 🎯 1 🛡️ 1 🧠 3, roughly 300-1000 LOC but fails at scale.

Must prove in spike:

- 50k-200k visible-row projection does not jank;
- rows have stable height;
- expansion/selection/focus/queue state is not row-local widget state;
- sort/filter/page events do not rebuild entire app shell;
- profile build keeps frame budget acceptable;
- compact layout remains usable;
- Headless/design_system has needed primitives or we report the gap.

Accepted guardrails:

- Flutter renders viewport only.
- Row identity is node ID + snapshot/projection version, not row index.
- Main tree does not use `DataTable`.
- Full scan tree never enters Flutter memory.
- State for focus, selection, expansion, details, and queued delete are separate.

## 12. Testing Fixture Lab And Quality Gates

Status: must be started early and expanded continuously.

Reference docs:

- `docs/technical/implementation-edge-cases-testing-quality-gates.md`
- `docs/technical/rust-best-practices.md`

Decision:

Create a disposable filesystem fixture lab with fake adapters plus real platform smoke tests. Quality gates are layered: local fast, PR, nightly platform, release candidate.

Score:

1. Fixture lab + layered gates - 🎯 10 🛡️ 10 🧠 7, roughly 1200-3200 LOC/config.
2. Unit tests only until late - 🎯 3 🛡️ 4 🧠 3, roughly 300-900 LOC but misses platform truth.
3. Manual QA only for filesystem edge cases - 🎯 1 🛡️ 2 🧠 2, roughly 100-400 LOC but not defensible.

Minimum fixture set:

```text
normal files and folders
deep tree
huge direct-child folder
hardlinks
symlink to file
symlink to directory
broken symlink
path replaced after scan
sparse file
compressed file where platform supports it
permission denied
locked/open file
open deleted POSIX file
unicode and invalid/non-UTF path cases where platform supports it
very long Windows path
external/removable volume smoke where available
Trash-supported and Trash-unsupported target
APFS clone if macOS runner supports it
Btrfs reflink if Linux runner supports it
cloud placeholder mock or real optional test
network share mock/profile
```

Required gates:

- architecture import-boundary tests;
- protocol schema/snapshot tests;
- pagination property tests;
- delete-plan stale identity tests;
- Trash adapter contract tests;
- operation journal crash/retry tests;
- redaction tests for logs/support bundles;
- performance macrobenchmarks by node count and target class;
- release gate blocks cleanup-capable builds if stale identity, receipt, or destructive idempotency tests fail.

Accepted guardrails:

- Tests never scan/delete real user folders.
- Destructive tests operate only in disposable temp roots or controlled CI targets.
- Platform-specific tests are explicit and tagged.
- Missing platform capability is recorded as skipped with reason, not silently passed.

## Cross-Cutting Architecture Decision

The final composition should look like this:

```text
Scanner backend, pdu first
  -> fs_usage scanner adapter
  -> compact Rust read model
  -> metadata/accounting enrichment ports
  -> application query services
  -> HTTP paginated queries
  -> Flutter viewport store
  -> design-system TreeTable

Delete workflow
  -> UI draft queue
  -> server DeletePlan
  -> identity revalidation
  -> reclaim accounting
  -> operation journal
  -> TrashAdapter
  -> receipt with observed delta
```

## Parallel Work Plan

Best practical order for engineering:

```text
Track A, scanner truth:
  pdu adapter spike
  read-model memory spike
  metadata/traversal spike

Track B, cleanup safety:
  identity/delete revalidation spike
  Trash adapter spike
  reclaim accounting proof
  operation journal spike

Track C, daemon/client:
  protocol streaming spike
  daemon security spike
  capability/permission doctor spike

Track D, UI:
  TreeTable facade spike after read-model query contract
  compact/wide layout validation against references

Track E, quality:
  fixture lab starts immediately and absorbs every new edge case
```

If only one thing is started next after current docs, start Track A with `pdu adapter capability + read-model memory` because it tells us whether the whole product can stay fast at 1-5M nodes.

If one safety thing is started next, start Track B with `identity/delete revalidation + Trash adapter reality` because it determines whether cleanup can be shipped at all.

## MVP Acceptance Checklist

Clean Disk MVP should not ship cleanup unless all of these are true:

- pdu adapter contract has fixture coverage;
- Rust read model handles at least 1M synthetic nodes within memory target;
- Flutter never receives full tree;
- metadata enrichment is tiered and bounded;
- traversal policy is explicit and visible;
- HTTP/WS reconnect can recover from dropped events;
- local daemon rejects hostile Origin/Host and missing token;
- scan resource profile defaults to Balanced;
- permission doctor labels partial scans;
- DeletePlan revalidates identity immediately before Trash;
- Trash adapter returns item-level outcomes;
- operation journal survives crash/retry;
- receipt separates moved/deleted from observed free-space delta;
- fixture lab covers hardlink, symlink, stale path, sparse file, permission denied, and Trash smoke tests.

## Current Open Questions

These are the remaining places where research becomes code proof:

1. Can pdu library expose enough skipped/error/progress data without fork?
2. What is the actual memory per node of our compact Rust read model at 1M and 5M nodes?
3. Which macOS metadata API is the best cost/value split for selected-node enrichment: Foundation URLResourceValues, `getattrlist`, POSIX `lstat`, or a hybrid?
4. Is Windows `IFileOperation` from Rust ergonomic enough, or should Trash use a small native helper layer?
5. Can Linux FreeDesktop Trash be made reliable enough through `trash` crate, or do we need our own adapter for strict receipts?
6. How much of daemon security can be shared between desktop-served web UI and future remote/headless mode without leaking local assumptions?
7. Does Headless/design_system already support the tree-table primitives we need, or should the library get a first-class virtualized tree/table primitive?

## Summary

The riskiest remaining implementation unknown is not "can Rust scan fast". It is whether we can preserve speed while adding the contracts that make the app safe: compact read model, lazy metadata, explicit traversal, recoverable protocol, hardened daemon, bounded resources, native Trash behavior, durable receipts, and a test lab that proves all of it.
