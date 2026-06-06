# Implementation Edge Cases

Last updated: 2026-05-12.

This document records implementation risks we must design for before the scanner, daemon, UI, and cleanup flow are implemented.

The goal is practical: every item here should eventually become a typed state, adapter policy, UI warning, or test fixture. Do not handle these as generic `io::Error` logs.

For additional platform, cloud, watcher, daemon security, packaging, and UI accessibility cases, see [Implementation Edge Cases Deep Dive](implementation-edge-cases-deep-dive.md).

## Sources Reviewed

- `parallel-disk-usage` docs: library crate, JSON interface, optional progress, and hardlink policy notes - <https://docs.rs/crate/parallel-disk-usage/latest>
- `parallel_disk_usage` library entry points - <https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/>
- Rust filesystem docs: `read_dir`, `symlink_metadata`, `Metadata`, and `remove_dir_all` - <https://doc.rust-lang.org/std/fs/>
- Tokio docs: `tokio::fs`, `tokio::select!`, and `Semaphore` - <https://docs.rs/tokio/latest/tokio/>
- Microsoft docs: NTFS reparse points, hard links/junctions, file streams, sparse files, and free-space APIs - <https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-points>
- Apple docs: APFS space sharing, clones, snapshots, sparse files, and macOS sandbox file access - <https://support.apple.com/en-ie/guide/security/seca6147599e/web>
- FreeDesktop Trash specification and Rust `trash` crate docs - <https://specifications.freedesktop.org/trash/latest/> and <https://docs.rs/trash/latest/trash/>
- Flutter performance docs for lazy large lists - <https://docs.flutter.dev/perf/best-practices>
- OWASP CSRF and REST security cheat sheets for localhost daemon hardening - <https://cheatsheetseries.owasp.org/>

## Severity Labels

- `P0` - must be handled before delete-capable releases.
- `P1` - must be handled before broad beta.
- `P2` - can be iterated, but should be modeled early so the architecture does not fight us later.

## Global Rule

All filesystem and transport boundaries must return structured results:

- stable reason code;
- user-safe message;
- raw debug context only in internal logs;
- affected path identity when available;
- recoverability: retryable, needs permission, unsupported, stale, conflict, cancelled, or fatal.

Do not collapse permission denied, skipped path, stale identity, transport lag, and unsupported Trash into one failure type.

## Scan Target And Scope

### Missing Or Changed Target - `P0`

The selected path can disappear, become a file, become a symlink, be unmounted, or change permissions between selection and scan start.

Implementation rule:

- `ScanTarget` is parsed at the boundary, but scan start must still preflight current metadata.
- Store original display path separately from resolved/current metadata.
- Return typed states: `target_not_found`, `target_not_directory`, `target_unmounted`, `target_permission_denied`, `target_changed`.

Tests:

- target removed after selection;
- target replaced by file;
- target replaced by symlink;
- external volume unmounted before start.

### Mount And Volume Boundaries - `P0`

A folder scan can cross into mounted volumes, APFS volumes, network shares, bind mounts, package mounts, or Windows volume mount points.

Default policy:

- scan the selected target only;
- do not cross mount/volume boundaries unless the user enables it;
- expose skipped mount roots in scan warnings with size unknown.

Architecture placement:

- pure policy type in scan domain;
- platform detection in filesystem adapter;
- mapping in scanner adapter.

### Symlink, Junction, And Reparse Point Scope - `P0`

Rust `metadata()` follows links, while `symlink_metadata()` inspects the link itself. Windows junctions and other reparse points can point to separate directories or volumes.

Default policy:

- do not follow symlinks or Windows reparse points by accident;
- count the link object itself unless an explicit follow policy is enabled;
- delete the selected link/reparse object, not its target, unless the user explicitly selected the target.

Implementation rule:

- file identity must record whether the selected node is a link/reparse point;
- UI must show link/reparse status in details;
- cleanup validation must reject ambiguous link-target operations.

### Network, Cloud, And External Storage - `P1`

iCloud Drive, Dropbox, OneDrive, SMB/NFS, external SSDs, and removable media can be slow, offline, lazily hydrated, or permission-gated.

Implementation rule:

- expose target capability flags: local, removable, network, cloud, readonly, trash-supported, scan-speed-confidence;
- keep scan cancellable and resumable at session level;
- never assume a missing file during traversal is fatal for the whole scan.

UI rule:

- show a warning badge, not a blocking modal, for slow/unreliable targets.

## Traversal And Scanner Adapter

### `pdu` Adapter Contract - `P0`

`parallel-disk-usage` is both a CLI and a library crate. Docs describe optional progress reporting and optional hardlink deduplication, but our domain must not depend on pdu types or pdu vocabulary.

Implementation rule:

- `pdu` lives only in `scan/infrastructure/pdu`;
- map pdu options to our domain policies;
- map pdu output into our tree/index model;
- if pdu cannot expose an event we need, add it behind the adapter or fork pdu, but keep the application port stable.

Expected shape:

- pdu produces a final tree and progress snapshots;
- Rust runtime owns the full final tree and indexes;
- Flutter queries pages and receives throttled progress/events.

### Iterator Errors During Traversal - `P0`

`read_dir` can construct successfully and still yield per-entry errors later. Its order is platform/filesystem dependent.

Implementation rule:

- traversal must treat per-entry errors as skipped/error nodes, not abort the scan by default;
- deterministic ordering is needed in tests and stable UI pages;
- sorting must be done in Rust indexes, not by Flutter over all nodes.

Tests:

- unreadable child directory;
- permission changes while iterator is active;
- directory deleted during traversal;
- deterministic sort fixtures.

### File Handles And Thread Pressure - `P0`

Scans can touch millions of entries. OS file handles, directory iterators, blocking thread pools, WebSocket queues, and memory arenas are finite.

Implementation rule:

- use bounded channels or explicit lossy latest-state progress;
- use semaphores/resource budgets for file handles and concurrent filesystem work;
- keep scanner work off the HTTP/WebSocket async runtime when needed;
- report `resource_exhausted` as a session failure, not a process crash.

Recommended first approach:

1. Dedicated scan workers + bounded channels - 🎯 9 🛡️ 10 🧠 7, roughly 250-700 LOC.
2. Pure Tokio `spawn_blocking` for all scan work - 🎯 5 🛡️ 6 🧠 4, roughly 100-300 LOC.
3. One synchronous scan thread per session - 🎯 7 🛡️ 7 🧠 4, roughly 100-250 LOC.

Pick 1 for production direction. Pick 3 only for a throwaway prototype.

### Cancellation And Partial Results - `P0`

The user can cancel, the client can disconnect, or daemon shutdown can happen while pdu/traversal/indexing is active.

Implementation rule:

- cancellation token is owned by session runtime;
- cancelled session has a terminal state distinct from failed;
- no partial delete candidates from cancelled scans unless marked stale/incomplete;
- cleanup actions require completed scan or explicit validation against current FS state.

### Scanner Faster Than Indexer/UI - `P1`

On SSDs, traversal can produce updates faster than UI or WebSocket clients can consume.

Implementation rule:

- do not emit one event per filesystem entry;
- coalesce progress by time and count;
- preserve terminal events, warnings, and errors;
- if a client lags behind replay window, force resync through queries.

## Size Accounting And Reclaim Estimates

### Size Is Not One Number - `P0`

Users care about "what is big" and "what can I reclaim", but filesystems expose several meanings:

- logical/apparent bytes;
- allocated bytes or size on disk;
- deduplicated hardlink accounting;
- compressed/sparse allocated size;
- estimated reclaim after Trash/delete;
- volume free bytes after operation.

Implementation rule:

- model `logical_size`, `allocated_size`, `reclaim_estimate`, and `confidence` separately;
- UI labels must say which number is shown;
- delete result must show actual operation result, not promise exact freed bytes.

### Hardlinks - `P0`

pdu treats hardlinks as equally real by default and supports optional deduplication with a performance cost.

Product policy:

- default display can show each path as real, but totals must disclose hardlink accounting mode;
- cleanup estimate must be conservative if a file has multiple links;
- if hardlink metadata is unavailable, mark reclaim confidence as low.

Tests:

- two hardlinks inside one scanned folder;
- one hardlink inside target and one outside target;
- delete one link and verify reclaim estimate does not claim full bytes when not safe.

### APFS Clones, Snapshots, Sparse Files, And Space Sharing - `P0`

APFS supports clone-on-write, snapshots, sparse files, and space sharing between volumes. Deleting a cloned file or a file present in snapshots may not free the apparent bytes immediately.

Implementation rule:

- macOS adapter should expose APFS capability flags where detectable;
- show "estimated reclaim" rather than "will free" for APFS clone/snapshot-sensitive paths;
- never equate selected file size with guaranteed free-space increase.

UI rule:

- details panel can show confidence labels: high, medium, low, unknown.

### Windows Sparse, Compressed, And Alternate Data Streams - `P1`

NTFS sparse/compressed files and alternate data streams each have allocation semantics. A file's displayed main stream can be small while named streams occupy space.

Implementation rule:

- Windows filesystem adapter should distinguish logical size from allocated size where feasible;
- do not silently ignore alternate streams in delete safety if the selected object has them;
- if stream accounting is not implemented in MVP, mark Windows allocated-size confidence as unknown for affected files.

### Free Space Can Differ By User And Quota - `P1`

Windows free-space APIs distinguish available bytes to caller from total free bytes. APFS volumes share container free space. Network and quota-managed filesystems can lie from the user's perspective.

Implementation rule:

- volume metrics must include `available_to_user` and `volume_free` when the platform exposes both;
- UI should prefer "available to you" for actionability;
- do not use volume free-space deltas as the only proof of cleanup success.

## Path, Identity, And Metadata

### Path Strings Are Not Identity - `P0`

Paths can be renamed, replaced, normalized differently, or point to different objects by delete time.

Implementation rule:

- `NodeIdentity` stores platform file identity where available;
- use path + identity + metadata freshness for cleanup validation;
- path-only cleanup is forbidden for delete-capable releases.

Minimal identity fields:

- original path as OS path, not only UTF-8 string;
- display path;
- file kind;
- device/volume id where available;
- inode/file id where available;
- size and modified timestamp as weak signals only;
- symlink/reparse/link classification.

### Invalid Unicode And Case Sensitivity - `P0`

Unix paths may not be valid UTF-8. macOS and Windows path comparison can involve normalization and case behavior that differs by volume.

Implementation rule:

- Rust core uses `PathBuf`/`OsString` internally at OS boundaries;
- protocol uses display-safe strings plus opaque node ids, not raw path roundtrips for actions;
- UI actions should send node ids/delete candidate ids, not typed user path strings.

### Long Windows Paths - `P1`

Deep project trees can exceed legacy path length assumptions.

Implementation rule:

- Windows package/manifest must support long paths where possible;
- adapters should avoid string APIs that reintroduce path truncation;
- tests should include long nested paths near and above common legacy limits.

### Metadata Availability Is Partial - `P1`

Rust `Metadata::modified`, `created`, and `accessed` can be unavailable or disabled depending on platform/filesystem.

Implementation rule:

- timestamps are optional fields;
- sorting by unavailable metadata needs a stable fallback;
- cleanup validation must not depend only on mtime.

## Cleanup And Trash

### Trash Is A Platform Adapter - `P0`

Trash/Recycle Bin behavior differs by OS and environment. Linux desktop Trash follows FreeDesktop only in compliant desktop environments; headless/server mode may not support Trash.

Implementation rule:

- cleanup application requests `move_to_trash`, not direct recursive delete;
- `trash` crate, shell APIs, or platform FFI are adapters;
- adapter returns structured outcomes: moved, unsupported, permission denied, locked, already gone, partial, identity mismatch, path changed.

MVP rule:

- if Trash is unsupported, do not silently fall back to permanent delete.

### Delete Queue Conflicts - `P0`

User can queue both parent and child, duplicate paths, stale nodes, symlinks, or items from different scan sessions.

Implementation rule:

- `DeletePlan` canonicalizes candidate conflicts by identity, not display path only;
- parent-child duplicates collapse into one visible plan warning;
- queue items carry session id and node identity;
- mixing sessions requires revalidation or explicit rejection.

### Stale Scan Data - `P0`

Files can be modified, replaced, moved, or recreated between scan and cleanup.

Implementation rule:

- every candidate is revalidated immediately before Trash;
- identity mismatch fails safe;
- disappeared path is a non-fatal candidate result;
- changed size/status returns "needs rescan" or "review again".

### Locked Or In-Use Files - `P0`

Windows streams and handles can block delete access. macOS and Linux can also fail due to permissions, SIP/TCC, open files, immutable flags, or active processes.

Implementation rule:

- locked/in-use is a typed result;
- do not chmod/chown or force-delete without a separate explicit feature decision;
- UI should offer retry, reveal, or remove from queue.

### Permanent Delete - `P0`, Deferred

Permanent recursive delete is a separate high-risk adapter, not a mode flag on Trash.

Implementation rule:

- keep permanent delete out of MVP unless explicitly accepted;
- if added, require a second confirmation policy and hostile filesystem tests;
- never use `remove_dir_all` directly from UI/application code.

## Local Daemon, Transport, And Remote Mode

### Browser To Local Daemon Security - `P0`

A website can try to talk to `localhost`. Our daemon can scan and move files to Trash, so local-only is not enough.

Implementation rule:

- bind local mode to loopback only;
- use a random per-session token;
- do not put tokens in URLs;
- require origin allowlist for HTTP and WebSocket;
- use explicit CORS origins, never wildcard CORS for delete-capable endpoints;
- require custom auth headers for browser commands;
- reject unknown origins before command parsing.

### Multiple Daemon Instances - `P1`

Desktop app, web UI, CLI, and auto-launch can start or find different daemon instances.

Implementation rule:

- define single-instance policy per mode;
- store connection info in runtime/state dir with restrictive permissions;
- lock startup where practical;
- handle stale lock/port files after crash.

### WebSocket Backpressure And Reconnect - `P0`

Background browser tabs, slow clients, or paused UIs can miss events.

Implementation rule:

- event envelopes include sequence numbers;
- keep bounded replay per session;
- preserve terminal events and warnings;
- if replay is unavailable, client resyncs via summary and paginated queries;
- disconnect clients whose per-client queue exceeds policy.

### Remote Server Mode - `P1`

The same daemon API might run on a remote server or CI agent later.

Implementation rule:

- remote mode is explicit config, never accidental `0.0.0.0`;
- remote mode requires real auth, TLS/reverse proxy decision, and user/permission model;
- cleanup capabilities differ by deployment and must be discoverable from `/health` or capabilities endpoint.

## Flutter UI And Design System

### Huge Tree Rendering - `P0`

Flutter should not receive or render the whole tree. Official Flutter performance guidance recommends lazy builders for large lists.

Implementation rule:

- UI requests visible children/top/search pages;
- Rust sorts and filters large sets;
- use lazy slivers/list builders with stable row heights;
- row expand/collapse state is UI state keyed by node id;
- scroll position and selection survive event updates.

### Event Spam Rebuilds - `P0`

Progress can update very frequently. Rebuilding the whole app or table on every event will feel broken.

Implementation rule:

- presentation store separates scan progress, tree pages, selection, and delete queue state;
- only affected widgets rebuild;
- progress updates are throttled/coalesced before UI;
- tree pages refresh on query invalidation, not per-entry events.

### Long Names And Paths - `P1`

Paths can be extremely long and can include characters that look odd in UI.

Implementation rule:

- display name, parent path, and full path are separate UI fields;
- use ellipsis and tooltip/copy affordances;
- no action uses copied display text as authority.

### Compact Layout - `P1`

The compact reference moves details and delete queue below the tree. Without discipline, this can become a scrolling mess.

Implementation rule:

- no permanent sidebar in compact layout;
- details panel and delete queue are collapsible sections below tree;
- bottom progress remains visible or easily reachable;
- dense table remains the primary workflow.

### Headless/Design-System Gaps - `P2`

If Headless lacks table virtualization, disclosure rows, split panes, accessible menu buttons, or keyboard navigation primitives, workarounds can damage app quality.

Implementation rule:

- report critical Headless API gaps before building awkward one-off widgets;
- build reusable design-system facade components for tree table, metric tiles, queue rows, and icon buttons.

## Cache, History, And Privacy

### Cache Is Rebuildable, Receipts Are Not - `P0`

Scan tree caches can be discarded. Delete receipts and user preferences need stronger durability.

Implementation rule:

- store cache, config, state/history, receipts, and runtime tokens in separate OS-appropriate locations;
- cache writes can be best-effort;
- delete receipts require stronger write discipline and privacy redaction.

### Sensitive Paths And Tokens - `P0`

Logs, screenshots, crash reports, exported history, and protocol snapshots can leak private paths or daemon tokens.

Implementation rule:

- never log daemon tokens;
- redact home paths in user-shareable logs where practical;
- debug logs can keep raw paths only in local developer mode;
- delete receipts should support privacy-preserving export.

### Schema And Protocol Evolution - `P1`

Scan history, DTOs, and protocol events will evolve.

Implementation rule:

- version cache schemas and protocol envelopes;
- snapshot-test WebSocket event JSON;
- keep backward compatibility only for intentionally persisted history, not temporary session memory.

## Packaging And Permissions

### macOS Full Disk Access, TCC, And Sandbox - `P0`

Scanning `~/Library`, Mail, Messages, Photos, system locations, or app containers can require permissions. Sandboxed apps need explicit user-selected access and security-scoped bookmarks for persistent access.

Implementation rule:

- model permission needed as a capability, not a crash;
- UI should show "Grant access" or "Open system settings" when applicable;
- persist access only through platform-approved mechanisms;
- permission denial is a scan warning and skipped subtree, not process failure.

### Windows Installer And Manifest - `P1`

Windows support needs long paths, code signing policy, firewall prompts if daemon binds TCP, and correct install/update behavior.

Implementation rule:

- local daemon should bind random loopback port or explicitly configured port;
- installer should not require admin for normal user scanning;
- long-path support and firewall behavior must be tested on a clean Windows VM.

### Linux Desktop And Headless Modes - `P1`

Linux desktop Trash may exist, but headless/server environments often do not have the same desktop services.

Implementation rule:

- capabilities endpoint reports Trash support;
- unsupported Trash blocks cleanup fallback unless user explicitly chooses permanent delete in a future feature;
- remote/headless mode should still support scan and read-only analysis.

## Testing Strategy

### Filesystem Fixture Matrix - `P0`

Create a fixture suite before delete-capable implementation:

- unreadable directory;
- file changing during scan;
- symlink loop;
- symlink to outside target;
- hardlink inside target;
- hardlink outside target;
- parent and child queued together;
- target replaced before cleanup;
- long path;
- invalid Unicode path on Unix;
- sparse file where platform supports it;
- reparse point/junction on Windows;
- APFS clone/sparse/snapshot-sensitive case where practical.

### Contract And Boundary Tests - `P0`

Test boundaries rather than only happy-path UI:

- domain/application crates do not import pdu, HTTP, WebSocket, Flutter, or Trash crates;
- pdu adapter maps errors into typed reasons;
- protocol DTO snapshots are stable;
- WebSocket replay and lag behavior is deterministic;
- cleanup validation rejects stale identity.

### Performance Budgets - `P1`

Performance should be measured before polishing UI:

- scan duration for representative home/download/library folders;
- memory per million nodes;
- query latency for children/top/search pages;
- WebSocket event queue behavior under slow client;
- Flutter frame stability while progress updates.

Initial targets to validate, not promises:

- page query p95 under 50 ms for already-indexed data;
- UI does not rebuild whole tree for progress-only events;
- event stream remains bounded during full disk scan;
- cancellation visible within 1 second in normal cases.

## MVP Cut Line

Must be in MVP:

- pdu adapter behind scanner port;
- final tree + paginated queries;
- throttled progress stream;
- permission/skipped/stale states;
- hardlink accounting policy;
- mount/link policy;
- delete queue with revalidation;
- Trash-only cleanup where supported;
- local daemon token + origin checks;
- large-list UI paging/lazy rendering.

Can wait:

- permanent delete;
- remote multi-user auth;
- persistent scan history;
- local IPC transport beyond HTTP/WebSocket;
- APFS exact clone/snapshot accounting;
- full NTFS alternate stream accounting;
- reliable durable event outbox.

## Most Important Decisions To Keep Stable

1. Rust owns the scan tree and indexes. Flutter asks questions, it does not store the world.
2. pdu is an adapter. If pdu changes or we fork it, application contracts stay stable.
3. Cleanup acts on validated identities, not stale paths.
4. Transport is replaceable, but the command/query/event contract is stable.
5. Reclaim bytes are estimates with confidence, not guaranteed promises.
