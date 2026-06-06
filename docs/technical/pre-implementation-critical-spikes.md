# Pre-Implementation Critical Spikes

Last updated: 2026-05-16.

This document records the ordered research topics that should be proven before implementing the Rust daemon, protocol, scan read-model, cleanup, and packaging surfaces.

It is intentionally practical. The goal is to reduce unknowns that can create rewrites, unsafe cleanup behavior, UI freezes, or platform-specific release blockers.

For the broader accepted order that also includes metadata enrichment, traversal policy, daemon security, operation journal, Flutter tree virtualization, and fixture gates, see `docs/technical/preimplementation-critical-research-sequence.md`.

For hidden failure modes, source-specific proof gates, and fallback decisions, see `docs/technical/preimplementation-critical-zones-deep-dive.md`.

## Sources Reviewed

- Flutter docs, [Performance best practices](https://docs.flutter.dev/perf/best-practices). Relevant for lazy lists, frame budget, and avoiding large eager widget trees.
- Flutter docs, [Work with long lists](https://docs.flutter.dev/cookbook/lists/long-lists). Relevant for keeping large tree/table rendering virtualized.
- MDN, [WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API). Relevant because stable browser `WebSocket` has broad support but no built-in backpressure.
- MDN, [WebSocketStream](https://developer.mozilla.org/en-US/docs/Web/API/WebSocketStream). Relevant because stream backpressure exists there, but it is not a baseline dependency for Flutter web.
- Tokio docs, [`mpsc`](https://docs.rs/tokio/latest/tokio/sync/mpsc/index.html). Relevant for bounded queues and explicit backpressure between runtime components.
- Tokio docs, [`broadcast`](https://docs.rs/tokio/latest/tokio/sync/broadcast/index.html). Relevant for lag detection when one event source fans out to multiple clients.
- Microsoft Learn, [`IFileOperation::SetOperationFlags`](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-setoperationflags). Relevant for `FOFX_RECYCLEONDELETE`, no-UI flags, early failure, and junction behavior.
- Microsoft Learn, [`SetPriorityClass`](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setpriorityclass). Relevant for background and priority process modes on Windows.
- Apple Developer Documentation, [`FileManager.trashItem`](https://developer.apple.com/documentation/foundation/filemanager/trashitem%28at%3Aresultingitemurl%3A%29). Relevant for macOS native Trash behavior.
- FreeDesktop.org, [Trash Specification v1.0](https://specifications.freedesktop.org/trash/latest/). Relevant for Linux desktop Trash semantics, per-volume Trash directories, `.trashinfo`, and remote filesystem limitations.
- docs.rs, [`trash` 5.2.6](https://docs.rs/trash/latest/trash/). Relevant as a candidate cross-platform Trash adapter, with documented Linux caveats.
- docs.rs, [`compact_str` 0.9.0](https://docs.rs/compact_str/latest/compact_str/). Relevant for reducing memory cost of many short names.
- docs.rs, [`lasso`](https://docs.rs/lasso/latest/lasso/). Relevant as a possible string interning crate if real fixtures show duplicated path segments.
- docs.rs, [`roaring`](https://docs.rs/roaring/latest/roaring/). Relevant as a possible bitmap index crate when query predicates need large set intersections.
- docs.rs, [`fst`](https://docs.rs/fst/latest/fst/). Relevant as a possible prefix or fuzzy name index if simple substring search is not enough.

## Current Ranking

The highest-uncertainty work is not the UI. It is the boundary between fast filesystem traversal, compact Rust-owned query state, platform-safe delete behavior, and reliable transport semantics.

Implementation should proceed in this order:

1. pdu adapter capability spike.
2. Rust read-model memory and pagination spike.
3. Protocol streaming, backpressure, and reconnect spike.
4. Platform identity and delete preflight spike.
5. Trash adapter fixture spike.
6. Installer, permissions, and daemon identity spike.
7. Resource governance and scan modes benchmark spike.

The pdu adapter and platform identity topics already have dedicated documents. This file connects the remaining critical topics into one pre-implementation sequence.

## 1. Rust Read-Model Memory, Pagination, and Indexes

Problem: `parallel-disk-usage` can produce the aggregate tree, but the product cannot expose that tree directly to Flutter. A 500 GB disk can still contain hundreds of thousands or millions of nodes. If we duplicate path strings, sort every query eagerly, or stream the full tree to Flutter, the UI and daemon will eventually hit memory and latency ceilings.

Decision: build a Rust-owned immutable scan snapshot read-model after scanner aggregation.

Recommended first implementation: `NodeStore` arena plus query indexes - 🎯 7 🛡️ 9 🧠 8, roughly 1000-2500 LOC for spike, fixtures, metrics, node mapping, query API, and tests.

Core rules:

- Node IDs are scoped to a `SnapshotId`. A `NodeId` from one scan is never valid in another scan.
- Store path as parent link plus local name segment, not full path per node.
- Store hot query fields in a compact `NodeRecord`: parent id, first child range, child count, size facts, type, flags, modified time, metadata enrichment state, and identity evidence handle.
- Build one global children array after scan: each node stores `child_start` and `child_len`.
- Keep row DTOs short. The UI receives only visible pages and selected-node details.
- Cache per-parent sorted child pages lazily. Do not globally sort every directory in every mode.
- Build top-K views during indexing or with bounded heaps. Do not scan the entire snapshot for every "largest files" query.
- Search MVP should use normalized name/path segment indexes. Full-text ranking can wait until product requirements prove it.

Library posture:

- `compact_str` is a good candidate for short node names because it stores short strings inline and has current docs for 0.9.0.
- `lasso` is a candidate only after profiling shows many repeated path segments. Interning adds lifetime and lookup complexity.
- `roaring` is useful once filters need fast set intersections, for example type + size bucket + risk tier + modified range.
- `fst` is useful for prefix/fuzzy name lookup later. It is not necessary for the MVP tree browser.
- Tantivy should not be the first search engine for this product. It is powerful, but likely too heavy for name/path-only disk usage search.

Spike acceptance criteria:

- 100k, 1M, and synthetic 5M node fixtures can be indexed without unbounded memory growth.
- Record peak memory for pdu tree only, read-model only, and pdu plus read-model overlap.
- Children page query p95 stays under the target UI budget on large directories.
- Top folders/files queries return deterministic pages with cursors.
- Search returns paginated, stable results without exposing full paths in logs.
- A completed scan can be disposed and all snapshot memory is actually released.

Red flags:

- Full path `String` stored in every node.
- Flutter receives the full tree.
- Search result DTOs contain every matched child instead of a page.
- Query sorting clones large vectors per request.
- Snapshot disposal waits on leaked UI subscriptions forever.

## 2. Protocol Streaming, Backpressure, and Reconnect

Problem: plain WebSocket is still the right MVP transport for events, but stable browser `WebSocket` has no built-in backpressure. If we send too much or treat every event as durable, slow clients can either force daemon memory growth or lose important terminal state.

Decision: HTTP is authoritative for commands and queries. WebSocket is for progress, invalidation, lifecycle hints, and terminal events.

Recommended first implementation: HTTP query plane plus bounded WebSocket event plane - 🎯 8 🛡️ 9 🧠 7, roughly 700-1800 LOC for envelopes, event router, reconnect, test clients, and slow-client tests.

Event classes:

- Durable: scan started, scan completed, scan failed, scan canceled, delete plan created, delete receipt created, snapshot invalidated, auth/session revoked.
- Coalescible: current path, file count progress, byte count progress, throughput, ETA, scanner phase, queue length.
- Diagnostic: warning, skipped path category, permission denied category, adapter degraded, resource throttled.

Envelope shape:

```text
EventEnvelope
  protocol_version
  session_id
  stream_id
  sequence
  event_id
  occurred_at
  event_type
  durability_class
  payload
```

Rules:

- `sequence` is encoded as a string in protocol DTOs to avoid JSON integer precision issues in Flutter web.
- The client reconnects with `last_seen_sequence`.
- The daemon replies with `resume_ok` if replay is possible, otherwise `resync_required`.
- Durable events have a bounded replay window per session.
- Coalescible progress can be dropped or replaced by the latest value under pressure.
- Large tree pages, search pages, and details are never sent over WebSocket. They are queried over HTTP by cursor.
- A slow client must not block scanning, indexing, or cleanup.

Backpressure design:

- Use bounded queues between scanner, indexer, operation supervisor, and event fanout.
- Use a per-client outbound queue.
- If the per-client queue fills, drop coalescible progress first.
- If durable events cannot be delivered within the policy, close that client and require HTTP resync.
- Expose overload state to Flutter so UI can switch to polling or reduce visible subscriptions.

Why not rely on `WebSocketStream` yet:

- It solves browser-side stream backpressure better, but MDN marks it non-baseline and non-standard.
- It is not a stable cross-browser assumption for Flutter web.
- We can still design our protocol so `WebSocketStream`, WebTransport, JSON-RPC, or gRPC can be adapters later.

Spike acceptance criteria:

- Slow client test cannot grow daemon memory without bound.
- Terminal events are never silently lost.
- Reconnect after network drop either resumes from sequence or forces HTTP resync.
- Event ordering is deterministic within one operation stream.
- Cancel/delete terminal states remain queryable over HTTP after WS disconnect.

Red flags:

- One unbounded channel from scanner to WebSocket.
- One event per filesystem entry.
- UI depends on progress events for authoritative state.
- Queries are blocked when WebSocket disconnects.
- Reconnect "works" only if no events were missed.

## 3. Trash Adapter Reality

Problem: safe cleanup is much harder than scanning. A Trash operation is not the same as `delete(path)`, and every OS has different semantics. We cannot trust a scan row from minutes ago to still point at the same object.

Decision: deletion is a `DeletePlan` plus revalidation plus a platform `TrashAdapter` result. The adapter must produce a receipt or a typed unsupported/error outcome.

Recommended first implementation: platform fixture spike before cleanup MVP - 🎯 6 🛡️ 10 🧠 8, roughly 800-2200 LOC for fixtures, adapter interface, typed outcomes, and OS-specific probes.

Adapter posture:

- `trash` crate is acceptable for an early disposable fixture adapter, but not as a domain dependency and not without platform tests.
- macOS should test native `FileManager.trashItem` behavior, resulting URL behavior, external volumes, iCloud paths, locked files, symlinks, and Full Disk Access/TCC interactions.
- Windows should test `IFileOperation` with `FOFX_RECYCLEONDELETE`, no-UI operation, early failure, Recycle Bin disabled, removable drives, OneDrive placeholders, locked files, read-only files, junctions, and long paths.
- Linux should test FreeDesktop Trash behavior on GNOME, KDE, headless sessions, external mounts, FUSE/rclone mounts, AppImage, Flatpak, and Snap constraints.

Typed outcomes:

- `MovedToTrash`
- `AlreadyGone`
- `IdentityMismatch`
- `PathChanged`
- `PermissionDenied`
- `TrashUnsupported`
- `TrashWouldPermanentDelete`
- `PartialFailure`
- `PlatformDialogRequired`
- `AdapterDegraded`
- `UnknownError`

Spike acceptance criteria:

- Trash fixtures prove no direct permanent delete occurs unless explicitly labeled and confirmed.
- Adapter can tell when Trash is unsupported for a target.
- Receipt includes enough evidence for UI audit and support without logging raw path in production telemetry.
- Partial success on multi-item operations is represented precisely.
- Cleanup beta is blocked until the fixture matrix passes.

Red flags:

- `trash::delete(path)` called directly from application code.
- UI can send a raw path delete command.
- No identity revalidation immediately before Trash.
- Adapter treats "Recycle Bin disabled" as success.
- Linux Trash assumes every mount supports the same home Trash path.

## 4. Installer, Permissions, and Daemon Identity

Problem: scanning authority belongs to the process that performs filesystem IO, not the visual Flutter shell. Debug builds do not prove release behavior. macOS TCC, Windows app identity, Linux sandbox package modes, signing, and updater behavior can change what the daemon can actually read and delete.

Decision: packaging and permission probes are architecture work, not release polish.

Recommended first implementation: packaged permission probe harness - 🎯 7 🛡️ 9 🧠 7, roughly 500-1500 LOC for packaged builds, capability probe endpoint, Permission Doctor UI contract, and manual matrix.

MVP packaging posture:

- macOS: Developer ID signed and notarized app, bundled signed daemon/helper, explicit permission probe from the same process identity that scans.
- macOS production scans must not launch a Homebrew/system/random external `pdu` binary. `parallel-disk-usage` is compiled into the signed scanner component as a library adapter.
- Windows: signed installer or MSIX only after behavior tests. Direct executable distribution will run into SmartScreen trust issues for early users.
- Linux: direct AppImage or distro package first. Flatpak/Snap are supported later as reduced-capability modes unless explicit permissions and portals are proven.
- Web UI: daemon-served loopback UI by default, with local token and origin allowlist.

Capability model:

- `CanReadHome`
- `CanReadDownloads`
- `CanReadLibraryOrAppData`
- `CanReadExternalVolume`
- `CanTrashTarget`
- `CanWatchTarget`
- `RequiresUserPermission`
- `RequiresElevatedHelper`
- `UnsupportedInPackageMode`

Permission Doctor rules:

- Probe before a full disk scan.
- Show capability gaps by target, not one generic permission error.
- Never ask for admin by default.
- Explain when a package mode cannot support full scanning.
- Cache probe results with short TTL because permissions can change outside the app.

Spike acceptance criteria:

- macOS packaged build proves whether app and daemon share or differ in TCC behavior.
- Windows packaged build proves long path, AppData, Program Files, OneDrive, removable drive, and Controlled Folder Access behavior.
- Linux package modes prove which targets are readable and which are blocked by sandbox.
- Daemon identity and version can be reported to Flutter and logs without exposing secrets.

Red flags:

- Validating macOS permissions from `cargo run` or `flutter run` only.
- Assuming Flutter app permissions automatically apply to a helper process.
- Requiring admin/elevation for normal scans.
- Shipping a Linux sandbox package as if it supports full disk scanning.
- Hosted website connecting to localhost daemon without a pairing and browser policy design.

## 5. Resource Governance and Scan Modes

Problem: a fast scanner can make the machine feel bad if it competes aggressively with the UI, indexing, browser, antivirus, cloud sync, and thermal limits. Performance must be controlled, not just maximized.

Decision: one local daemon with internal bounded worker pools and explicit resource profiles.

Recommended first implementation: scan resource profiles behind OS adapters - 🎯 8 🛡️ 8 🧠 6, roughly 500-1400 LOC for config, budgets, metrics, and platform adapters.

Profiles:

- Balanced: default. Preserves UI/system responsiveness, uses moderate parallelism, coalesces progress, and adapts under pressure.
- Fast: opt-in. Uses higher scanner parallelism and less delay, but still has hard queue and file-handle limits.
- Background: lower priority where the OS allows it, lower thread count, lower event frequency, and more aggressive pause on battery/thermal pressure.

Budget boundaries:

- Scanner traversal workers.
- Metadata enrichment workers.
- Index builder workers.
- HTTP request concurrency.
- WebSocket fanout queues.
- Delete/revalidate workers.
- File descriptor permits.
- Per-volume or per-target scan concurrency.

Rust implementation posture:

- Do not let Tokio blocking pool and Rayon/pdu both consume "all cores" independently.
- Use explicit semaphores for filesystem-heavy work.
- Keep scanner CPU pools and async transport runtime separate.
- Bounded queues are part of the public reliability model, not just implementation details.
- OS priority adapters live behind ports because QoS APIs differ significantly.

Platform posture:

- macOS: support QoS/background activity where practical and observe battery/thermal behavior.
- Windows: evaluate process/thread priority and background mode, including `SetPriorityClass`; keep EcoQoS as a later adapter if it fits the deployment target.
- Linux: evaluate `nice`, `ionice`, cgroup constraints, and package permission limits.

Metrics:

- scan elapsed time
- throughput
- files/sec
- bytes/sec
- queue depths
- dropped/coalesced event count
- open file permits used
- memory peak
- p95 page query latency
- UI frame timing from Flutter integration tests
- battery/thermal/power-source state when available

Spike acceptance criteria:

- Balanced mode keeps UI responsive while scanning a large fixture.
- Fast mode is measurably faster than Balanced on at least one target class.
- Background mode reduces visible system impact on laptop workloads.
- Slow network/removable volumes do not starve local SSD scans.
- Scanner does not exceed configured file descriptor or queue budgets.

Red flags:

- Fast mode as default.
- No queue depth metrics.
- No way to pause/resume without losing operation state.
- Resource profile stored only in UI state instead of daemon session config.
- OS priority calls scattered through scanner code instead of platform adapters.

## Cross-Cutting Architecture Consequences

These spikes reinforce the accepted architecture:

- `parallel-disk-usage` remains a scanner adapter, not the engine API.
- `fs_usage_*` owns reusable scan sessions, read-models, ports, indexes, metadata enrichment, and cleanup primitives.
- `clean-disk-server` owns host/runtime/protocol/transport composition, local auth, observability, and concrete adapter wiring.
- Flutter owns presentation and feature use cases, but not full scan trees, native filesystem authority, or cleanup execution.
- HTTP commands/queries plus plain WebSocket events remain the MVP transport.
- Future FRB, JSON-RPC, gRPC, WebTransport, or Socket.IO adapters should not change domain or read-model contracts.

## Top 3 Least Certain Areas

1. Read-model peak memory while pdu result and our indexed snapshot overlap - 🎯 5 🛡️ 8 🧠 8, roughly 1000-2500 LOC to prove.
   Reason: if pdu holds one full tree and we build another full read-model before releasing the first, peak memory can be the real bottleneck.

2. Native Trash behavior across packaged app modes - 🎯 5 🛡️ 10 🧠 8, roughly 800-2200 LOC to prove.
   Reason: this is safety-critical and platform behavior differs more than normal filesystem reads.

3. macOS/Windows permission identity for app plus daemon/helper packaging - 🎯 6 🛡️ 9 🧠 7, roughly 500-1500 LOC to prove.
   Reason: debug behavior can mislead us. The packaged, signed artifact is the only meaningful test.

## Implementation Gates

Before writing production scanner UI:

- pdu adapter spike must prove progress, cancellation, boundary behavior, and memory cost.
- Read-model spike must prove paginated queries on large fixtures.
- Flutter UI must render a virtualized tree/table from pages only.

Before writing production cleanup:

- Platform identity revalidation must exist.
- Trash adapter fixture matrix must pass.
- Delete receipts and partial outcomes must be modeled.
- Raw path delete commands must be impossible from UI/application layers.

Before shipping desktop beta:

- Packaged permission probes must pass on macOS and Windows.
- Resource profiles must be observable.
- Slow-client WebSocket tests must pass.
- Support bundle redaction must avoid raw paths and tokens by default.

## Short Decision Summary

- ✅ Keep one daemon with bounded internal worker pools.
- ✅ Keep HTTP for authoritative commands/queries.
- ✅ Keep plain WebSocket for events, with explicit backpressure and resync.
- ✅ Keep Rust as owner of full scan snapshots, read-models, indexes, and cleanup authority.
- ✅ Keep Flutter as paginated client and UI composition layer.
- ✅ Treat Trash and permissions as first-class product safety work.
- ⚠️ Do not start from full UI implementation before proving read-model memory, transport pressure, and packaged permissions.
