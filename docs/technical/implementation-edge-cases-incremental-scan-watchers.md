# Implementation Edge Cases - Incremental Scan And Watchers

Last updated: 2026-05-13.

This file records edge cases for incremental rescans, filesystem watchers, event journals, stale scan snapshots, cache invalidation, subtree refresh, and watcher-driven UX.

Incremental scanning is tempting because full disk scans can be expensive. The hard part is not receiving filesystem events. The hard part is knowing when those events are incomplete, delayed, coalesced, denied, stale, or too ambiguous to update a cleanup-capable tree safely.

Related documents:

- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md)
- [Rust best practices research](rust-best-practices.md)

## Sources Reviewed

- Apple Developer Documentation, [File System Events](https://developer.apple.com/documentation/coreservices/file_system_events?changes=latest__2&language=objc). Relevant point: FSEvents reports changes in directory hierarchies and can be consumed by event ID/time, but it is still an event system, not a scan result.
- Apple Developer Documentation, [`kFSEventStreamEventFlagMustScanSubDirs`](https://developer.apple.com/documentation/coreservices/1455361-fseventstreameventflags/kfseventstreameventflagmustscansubdirs/). Relevant point: when this flag appears, the application must recursively rescan the affected directory subtree.
- Apple Developer Archive, [File System Event Security](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/FileSystemEventSecurity/FileSystemEventSecurity.html). Relevant points: event paths can leak private names, permissions affect event visibility, event IDs may be non-consecutive for non-root users, and deleted names can linger in event storage.
- Microsoft Learn, [ReadDirectoryChangesW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-readdirectorychangesw). Relevant points: subtree watches are supported, buffers can overflow and require subtree enumeration, network buffer size has a 64 KB limit, and some changes are detected only after cache flush.
- Microsoft Learn, [Change Journal Records](https://learn.microsoft.com/en-us/windows/win32/fileio/change-journal-records). Relevant points: NTFS USN records are volume-level change records, old records can be deleted, records describe change facts/reasons but not enough to reverse changes, and multiple changes can be summarized.
- Linux man-pages, [inotify(7)](https://man7.org/linux/man-pages/man7/inotify.7.html). Relevant points: inotify has queue limits and emits `IN_Q_OVERFLOW` when events are dropped; recursive watching requires watches for directories.
- Watchexec, [Linux inotify limits](https://watchexec.github.io/docs/inotify-limits.html). Relevant points: Linux inotify limits are per-user, recursive directory watching consumes one watch per directory, and queue overflow can make watcher state unusable until recovered.
- Rust `notify`, [crate documentation](https://docs.rs/notify/latest/notify/). Relevant points: network filesystems may not emit events, polling may be needed, macOS FSEvents can miss unowned-file cases, editor save behavior differs, parent folder deletion needs parent watch, pseudo filesystems can be unsuitable, Linux watch limits can fail large watches, and very large directories may miss events.
- Watchman, [Troubleshooting](https://facebook.github.io/watchman/docs/troubleshooting). Relevant points: mature watcher systems recover from lost sync through recrawl, frequent recrawls are expensive/noisy, and resource limit failures can poison watcher correctness.

## Severity Scale

- `P0` - stale or incomplete watcher state can drive wrong cleanup, hide changed/deleted files, corrupt tree sizes, present false reclaim estimates, or let an old confirmation act on a changed target.
- `P1` - watcher state can cause UI jank, high CPU, battery drain, repeated full rescans, noisy stale warnings, memory leaks, or missed refresh after sleep/mount changes.
- `P2` - improves perceived freshness, diagnostics, resource usage, and future incremental UX.

## Top 3 Incremental Scan Decisions

1. MVP: immutable scan snapshots, manual/full rescan, watcher-free correctness - 🎯 10 🛡️ 10 🧠 3, roughly 150-450 LOC across snapshot IDs, stale labels, and rescan commands.
2. Watchers as invalidation hints plus explicit subtree refresh - 🎯 9 🛡️ 9 🧠 7, roughly 1200-3500 LOC across watcher adapters, stale subtree model, refresh jobs, protocol events, and tests.
3. Fully incremental live tree maintained from native journals/watchers - 🎯 5 🛡️ 6 🧠 10, roughly 5000-15000 LOC across platform journals, conflict handling, persistent indexes, compaction, and recovery. Powerful later, too risky for first cleanup release.

My recommendation: ship v1 correctness with immutable snapshots and explicit rescans. Add watcher-driven stale hints only after delete safety, cache invalidation, and UI resync contracts are solid. A live incremental tree is a later product tier, not the foundation.

## Core Principle

Watchers are hints, scans are facts.

Minimum model:

```text
ScanSnapshot
  scan_id
  target_id
  root_identity
  index_version
  started_at
  completed_at
  freshness
  invalidated_subtrees[]
  watcher_status

InvalidationHint
  hint_id
  source
  target_id
  path_ref
  subtree_scope
  event_kind_hint
  confidence
  requires_full_rescan
  received_at
```

Rules:

- watcher events never mutate a cleanup-capable tree directly;
- watcher events mark snapshots, nodes, or subtrees stale;
- delete plans are invalidated or revalidated when their snapshot/subtree becomes stale;
- stale state is a first-class user-visible state, not an internal log message;
- overflow, dropped events, permission loss, mount reconnect, or watcher crash requires subtree/full rescan.

## Bounded Context

### Incremental Scan Is Not Cleanup Authority - `P0`

A watcher may know "something changed". It does not know "this queued path is still safe to delete".

Required behavior:

- cleanup always performs current identity validation;
- watcher freshness can only increase required review, never reduce it;
- stale hints invalidate confirmation tokens when they intersect queued items;
- DeletePlan stores scan snapshot and identity snapshot;
- user sees changed/stale item count before moving anything to Trash.

Avoid:

- automatically executing old delete queues after watcher refresh;
- recomputing risk tier from an event alone;
- treating rename event path as proof of identity.

### Incremental Scan Is A Separate Application Capability - `P1`

The scanner adapter produces facts. Watcher adapters produce invalidation hints. The application layer decides freshness policy.

Required behavior:

- `ScanApplication` owns snapshot lifecycle;
- `WatcherPort` emits invalidation hints;
- `ScanRefreshUseCase` turns hints into scheduled subtree/full refresh jobs;
- recommendation/rule engine re-evaluates only against refreshed facts;
- UI consumes stale/refresh events through protocol DTOs.

Avoid:

- putting watcher logic inside pdu adapter traversal;
- letting platform watcher APIs leak into domain;
- mixing event processing with delete validation code.

## Platform Watcher Edge Cases

### macOS FSEvents Can Be Coalesced, Dropped, And Privacy-Filtered - `P0`

FSEvents is useful for directory hierarchy change tracking, but it can report coarse changes and special flags that require rescans.

Required behavior:

- `MustScanSubDirs` maps to recursive subtree stale state;
- user/kernel dropped style conditions map to `requires_full_rescan` for the watched root;
- event IDs are not assumed consecutive for ordinary users;
- events for unowned/denied paths reduce confidence or require polling/rescan;
- raw event paths are treated as private data and redacted in logs/support bundles.

Avoid:

- using FSEvents event IDs as a complete audit log;
- persisting raw event paths by default;
- assuming root-volume watch gives a normal app every relevant event;
- reading `.fseventsd` storage directly.

### Windows `ReadDirectoryChangesW` Requires Overflow Recovery - `P0`

Windows directory change notifications can lose detailed information when buffers overflow.

Required behavior:

- zero-byte result or `ERROR_NOTIFY_ENUM_DIR` maps to subtree enumeration required;
- network watches respect the 64 KB buffer limitation;
- short-name events are normalized through current filesystem enumeration before UI display;
- size/write-time change events are treated as eventually observed because caching can delay detection;
- unsupported filesystem or network redirector maps to watcher unsupported and poll/full-rescan fallback.

Avoid:

- assuming every write emits immediate size/write-time event;
- treating a successful API call as proof that all detailed events were delivered;
- using watcher events from network shares as exact change history.

### Windows USN Journal Is A Journal, Not A Reversible History - `P1`

The NTFS USN journal is attractive for incremental scanning because it is persistent and volume-level. It still has limits.

Required behavior:

- use USN only through a dedicated Windows watcher/journal adapter if adopted;
- detect journal deletion/truncation and fall back to full rescan;
- remember that records summarize change reasons and may not preserve operation order;
- treat USN as NTFS/ReFS capability, not universal Windows behavior;
- test with volume boundaries, external drives, network shares, and permission-limited folders.

Avoid:

- building cross-platform incremental semantics around USN-specific behavior;
- treating USN as undo/restore data;
- assuming old records remain available forever.

### Linux inotify Is Non-Recursive And Resource-Limited - `P0`

Recursive watch over a large home directory can consume many watches and kernel memory.

Required behavior:

- recursive watcher setup reports watch count and resource failure separately;
- `IN_Q_OVERFLOW` maps to root/subtree stale plus recrawl required;
- add watches for new directories only after confirming resource budget;
- expose Linux inotify limit guidance in diagnostics, not as a scary generic crash;
- polling fallback is available for unsupported paths when acceptable.

Avoid:

- silently ignoring unwatched subdirectories;
- trying to watch an entire 500 GB disk tree by default on Linux;
- suggesting unlimited sysctl increases without explaining memory cost;
- treating inotify events as recursively complete without per-directory watches.

### Network, Cloud, Docker, And Pseudo Filesystems May Not Emit Useful Events - `P1`

Some filesystems do not provide reliable watcher semantics to local APIs.

Required behavior:

- NFS/SMB/FUSE/rclone/cloud sync roots default to snapshot/rescan policy unless capability is proven;
- Docker-on-macOS and WSL paths can require polling;
- `/proc`, `/sys`, and similar pseudo filesystems are never watcher-backed truth;
- watch capability belongs to target metadata;
- UI shows "auto-refresh unavailable" or "needs rescan" instead of pretending live freshness.

Avoid:

- treating a mounted path like local APFS/NTFS/ext4;
- using watcher absence as a scan failure;
- polling huge network trees aggressively.

## Event Semantics Edge Cases

### Editor Save Patterns Are Not Stable - `P1`

Editors and tools save files differently: truncate, write temp file, rename, replace, preserve metadata, or write in chunks.

Required behavior:

- coalesce bursts into invalidation windows;
- do not derive user-facing "created/deleted/replaced" claims from one event when only size freshness matters;
- after refresh, compare current identity and metadata rather than replaying editor intent;
- test rename-over-existing and temp-file-save patterns.

Avoid:

- updating tree size from a single write event delta;
- assuming a rename pair is always delivered together;
- exposing low-level event kind as final explanation.

### Rename Is Identity-Sensitive - `P0`

Rename can be same-directory, cross-directory, cross-volume copy/delete, tool-managed replacement, or a cloud provider sync event.

Required behavior:

- invalidate both old and new parent subtrees where known;
- preserve selection only if file identity confirms same object;
- old queued path becomes `needs_revalidation`;
- search index entries for old path are stale until refreshed;
- details panel displays stale state rather than following a path guess.

Avoid:

- blindly moving a selected UI row to the new path;
- deleting by old path after rename hint;
- assuming path equality means identity equality.

### Open Files And Late Flushes Affect Size Freshness - `P1`

Large files, VM images, databases, downloads, and archives can grow while scanned.

Required behavior:

- size freshness can be `stable`, `changing`, `unknown`, or `stale`;
- details panel can show "changed since scan";
- recommendation confidence drops for actively changing targets;
- delete preflight checks size/type/identity again;
- refresh jobs debounce repeated growth.

Avoid:

- showing "will free X GB" for a file still being written;
- rescan-looping on every append to a large log/database;
- treating late watcher delivery as an error.

### Permission Changes Can Hide Or Reveal Data - `P0`

Watcher permission loss may look like silence.

Required behavior:

- permission-denied during watcher setup is a capability state;
- permission-denied during refresh marks affected subtree uncertain;
- newly granted access should allow explicit rescan;
- stale inaccessible nodes cannot be cleanup candidates;
- support bundle redacts denied path details unless user opts in.

Avoid:

- assuming no events means no changes;
- deleting a previously visible node after access was lost;
- retrying denied paths hot-loop style.

## Cache And Read Model Invalidation

### Scan Results Are Immutable Snapshots - `P0`

Immutable snapshots make pagination, selection, details, search, and delete plans coherent.

Required behavior:

- completed scans publish immutable `snapshot_id`/`index_version`;
- pages, details, search results, and queue items reference snapshot identity;
- watcher hints produce a new freshness layer, not mutation of the old snapshot;
- subtree refresh publishes a new index version or a new snapshot segment with compatibility rules;
- old cursors are rejected or resynced when index version changes.

Avoid:

- mutating tree nodes while the UI is paginating;
- appending page 2 from old index to page 1 from new index;
- storing only paths in UI selection.

### Stale Marking Should Be Spatial And Bounded - `P1`

If every event marks the entire disk stale, auto-refresh becomes useless. If stale scope is too narrow, correctness suffers.

Required behavior:

- event-to-scope policy is explicit: node, parent, subtree, root, or full target;
- overflow/dropped events widen scope;
- rename and delete widen to parent subtree;
- unknown mount/cloud/network events widen to root target;
- UI can show stale badges at folder ancestors without flooding every row.

Avoid:

- marking every visible row stale for one file event;
- hiding stale children under collapsed parents without ancestor indication;
- silently clearing stale state without refresh.

### Refresh Jobs Need Backpressure - `P1`

Heavy change streams can turn a performance feature into constant rescanning.

Required behavior:

- refresh scheduler has per-target debounce;
- max concurrent refresh jobs is bounded;
- low-priority refresh pauses during active full scan/delete;
- repeated overflow escalates to manual/full rescan prompt;
- metrics track dropped hints, coalesced hints, refresh queue length, and rescan cost.

Avoid:

- starting a subtree scan per watcher event;
- letting watcher events starve user-requested scans;
- buffering unbounded path events.

## Protocol And UI Edge Cases

### Freshness Is A Protocol Field, Not UI Guesswork - `P1`

The UI needs stable semantics for stale state.

Recommended DTO fields:

```text
TreeNodeDto
  node_id
  snapshot_id
  path_display
  size
  freshness
  stale_reason_codes[]
  refresh_available

WatcherStatusDto
  target_id
  mode
  health
  last_event_at
  last_refresh_at
  overflow_count
  unsupported_reasons[]
```

Required behavior:

- UI does not infer stale from timestamps alone;
- details panel shows snapshot time and freshness;
- delete queue shows which items need revalidation;
- scan progress and refresh progress are separate states;
- compact UI keeps stale/refresh status visible without crowding the tree.

Avoid:

- mixing scan progress bar with watcher refresh;
- using only color to indicate stale state;
- hiding stale warnings behind a hover-only tooltip.

### Watcher Events Are Not For User-Facing Audit - `P1`

Watcher logs can contain private names and noisy implementation details.

Required behavior:

- user-facing history records scan/refresh/delete operations, not raw watcher streams;
- diagnostic export aggregates watcher health and counts by target;
- raw event path logging is disabled by default;
- operation IDs link refresh jobs to affected snapshots;
- support bundle can include redacted watcher health.

Avoid:

- exporting raw event streams;
- displaying every event in UI;
- treating watcher log as delete receipt.

## Persistence Edge Cases

### Persisted Watcher State Can Become Invalid Across Restart - `P1`

After app restart, sleep, logout, OS update, volume remount, or permissions change, old watcher handles and event cursors may be meaningless.

Required behavior:

- persisted watcher state is capability cache, not authority;
- startup validates target identity and watcher capability;
- if event cursor is invalid or too old, mark snapshot stale;
- sleep/resume triggers target health check;
- app upgrade can invalidate watcher cache schema.

Avoid:

- resuming delete-capable freshness from old watcher handle state;
- assuming volume IDs remain stable across removable drives;
- hiding "needs rescan" after daemon restart.

### Retention Of Snapshots Must Be Limited - `P2`

Keeping every scan snapshot forever creates local storage and privacy issues.

Required behavior:

- retain recent completed snapshots by explicit policy;
- stale snapshots can be evicted sooner than receipts;
- delete receipts outlive scan cache where needed;
- clearing scan cache does not delete operation receipts;
- support bundle includes snapshot metadata only when redacted.

Avoid:

- storing full historical file trees indefinitely;
- keeping stale event path history after scan cache is cleared;
- coupling snapshot cache retention to UI preferences.

## Testing Edge Cases

### Watcher Correctness Needs Failure Simulation - `P0`

The important cases are not normal create/modify/delete. They are overflow, dropped events, permission loss, rename storms, and mount changes.

Required tests:

- watcher overflow maps to full/subtree stale;
- rename old/new parent invalidation;
- parent directory deleted while child selected;
- watched root moved or unmounted;
- permission denied after initial scan;
- event burst coalesced into one refresh job;
- stale cursor/page rejected after refresh;
- delete plan token invalidated when queued subtree goes stale;
- network target watcher unsupported falls back to rescan policy.

### Fixture Matrix

Recommended fixture groups:

- local APFS/ext4/NTFS normal directory;
- hardlink/symlink/reparse point under watched target;
- large growing file;
- temp-file-save pattern;
- directory rename with selected child;
- mount boundary;
- cloud placeholder folder;
- network share or simulated watcher-unsupported target;
- Linux low inotify watch limit;
- macOS FSEvents dropped/must-scan simulation;
- Windows ReadDirectoryChangesW overflow simulation.

## MVP Cut Line

Before first scanner UI:

- all scan query results include snapshot/index identity;
- UI can show snapshot time;
- user can manually rescan target;
- delete queue stores snapshot and identity.

Before first cleanup-capable beta:

- stale snapshots cannot execute old confirmation tokens;
- delete preflight revalidates identity regardless of watcher state;
- scan cache invalidation policy exists;
- UI has changed/stale item states;
- tests cover stale delete plan rejection.

Before watcher-backed auto-refresh:

- watcher is behind a port/adapter;
- watcher events only create invalidation hints;
- overflow/dropped/unsupported states are typed;
- subtree refresh scheduler has backpressure;
- protocol has watcher health and freshness DTOs;
- support bundle redacts watcher paths;
- platform-specific watcher tests exist.

Before fully incremental live tree:

- persistent index format exists;
- journal/watch cursors are validated;
- conflict/overflow recovery recrawls correctly;
- stable identity tracking is proven on every supported OS;
- memory and CPU budgets are benchmarked;
- cleanup safety does not depend on incremental correctness.

## Summary

The safe stance:

```text
Full scan creates facts.
Watcher creates suspicion.
Suspicion marks stale state.
Stale state requires refresh or revalidation.
Delete never trusts watcher freshness.
Overflow means recrawl.
Unsupported watcher means snapshot/rescan mode, not product failure.
```

The invariant:

```text
Clean Disk must never use filesystem watcher events as direct authority for size, identity, recommendation, or destructive cleanup decisions.
```
