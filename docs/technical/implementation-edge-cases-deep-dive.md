# Implementation Edge Cases Deep Dive

Last updated: 2026-05-12.

This document supplements [Implementation Edge Cases](implementation-edge-cases.md). The first file is the core checklist. This file captures deeper platform, security, UI, packaging, and future-mode edge cases that can shape the design before implementation starts.

The core principle stays the same: edge cases should become typed capabilities, typed outcomes, adapter policies, UI states, or tests.

For additional advanced scenarios around system-managed storage, virtual disks, package-manager caches, recommendations, installers, updates, and enterprise mode, see [Implementation Edge Cases Advanced Scenarios](implementation-edge-cases-advanced-scenarios.md).

## Additional Sources Reviewed

- Apple security-scoped bookmarks and macOS sandbox file access - <https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox>
- Apple dataless files and File Provider materialization - <https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files>
- Microsoft OneDrive Files On-Demand - <https://support.microsoft.com/en-us/office/save-disk-space-with-onedrive-files-on-demand-for-windows-0e6860d3-d9f3-4971-b321-7092438fb38e>
- Microsoft Cloud Files API sample and placeholder hydration behavior - <https://learn.microsoft.com/en-us/samples/microsoft/windows-classic-samples/cloudmirror-sample/>
- Microsoft NTFS reparse points and file streams - <https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-points> and <https://learn.microsoft.com/en-us/windows/win32/fileio/file-streams>
- Microsoft OneDrive synced delete behavior - <https://learn.microsoft.com/en-us/troubleshoot/sharepoint/sync/synced-file-moved-to-recycle-bin>
- Linux and Rust filesystem watcher caveats: `notify`, inotify limits, FSEvents limitations, ReadDirectoryChangesW limits - <https://docs.rs/notify/> and <https://watchexec.github.io/docs/inotify-limits.html>
- Chrome Private Network Access and WICG Local Network Access drafts - <https://developer.chrome.com/blog/private-network-access-preflight/> and <https://wicg.github.io/local-network-access/>
- Flutter focus, shortcuts, web accessibility, and large table APIs - <https://docs.flutter.dev/ui/interactivity/focus>, <https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts>, <https://docs.flutter.dev/ui/accessibility/web-accessibility>, <https://api.flutter.dev/flutter/material/PaginatedDataTable-class.html>
- Unicode security considerations for bidirectional spoofing - <https://unicode.org/reports/tr36/tr36-12.html>
- RustSec, cargo-audit, cargo-deny, and Rust supply-chain guidance - <https://rustsec.org/> and <https://rust-secure-code.github.io/rust-supply-chain-security/>
- Btrfs copy-on-write snapshots/subvolumes - <https://btrfs.readthedocs.io/en/latest/btrfs-subvolume.html>

## New Design Biases

### 1. Watchers Are Invalidation Hints, Not Truth

Filesystem watcher APIs are not reliable enough to be the source of truth for scan state:

- Linux inotify has per-user watch and queue limits.
- macOS FSEvents is volume-log based and can be coarse or lossy.
- Windows ReadDirectoryChangesW can lose data when buffers overflow and has network buffer restrictions.
- Rust `notify` documents that events differ across editors/platforms and network filesystems may not emit events.

Recommended choices:

1. Watchers only mark subtrees/session state as stale, then queries rescan or revalidate - 🎯 9 🛡️ 9 🧠 5, roughly 250-700 LOC.
2. Watchers directly mutate the indexed tree as exact operations - 🎯 4 🛡️ 4 🧠 9, roughly 800-2000 LOC.
3. No watcher support in v1, only manual rescan and stale checks - 🎯 8 🛡️ 7 🧠 3, roughly 80-250 LOC.

Decision bias: choose 3 for MVP, design so 1 can be added later.

### 2. Cloud Placeholder Files Are Not Normal Local Files

Modern cloud providers expose files that look present but may not have local contents:

- Apple calls these dataless files and accessing them can materialize/download content.
- OneDrive Files On-Demand shows online-only files that do not take local space until opened.
- Windows cloud placeholders are implemented through Cloud Files API and reparse/filter behavior.

Recommended choices:

1. Metadata-only scan by default, never hydrate/materialize cloud placeholders automatically - 🎯 10 🛡️ 10 🧠 5, roughly 250-700 LOC.
2. Optional "include cloud-only contents" mode with explicit warning and cancellation - 🎯 7 🛡️ 7 🧠 7, roughly 500-1400 LOC.
3. Automatically open/read files to measure exact content - 🎯 2 🛡️ 2 🧠 6, roughly 400-1000 LOC.

Decision bias: choose 1 for MVP. Option 2 can be a later advanced scan mode.

### 3. Localhost Daemon Is Exposed To The Browser Threat Model

The web UI needs HTTP/WebSocket to a local daemon, but browsers can be used as a bridge to local services. Chrome Private Network Access, WICG Local Network Access, OWASP CSRF guidance, and DNS rebinding risks all point to the same rule: localhost is not authentication.

Recommended choices:

1. Token + Origin allowlist + Host validation + custom auth header + no cookies + loopback binding - 🎯 10 🛡️ 10 🧠 6, roughly 300-900 LOC.
2. CORS allowlist only - 🎯 4 🛡️ 4 🧠 3, roughly 80-200 LOC.
3. Disable browser web UI for local daemon - 🎯 7 🛡️ 9 🧠 2, roughly 50-150 LOC, but misses product direction.

Decision bias: choose 1.

## Platform Access And Permission Edge Cases

### macOS TCC, Full Disk Access, And Security-Scoped Bookmarks - `P0`

Scanning common high-value locations can hit TCC and sandbox boundaries:

- `~/Library`, Mail, Messages, Photos, app containers, and system-protected locations can require extra permission.
- Sandboxed macOS apps need user-selected file access and security-scoped bookmarks for persistent access.
- A bookmark can become stale and must be resolved again.

Implementation rule:

- model `PermissionCapability` separately from `ScanCapability`;
- keep permission prompts and bookmark persistence in macOS platform adapter;
- store only bookmark data needed for user-approved targets;
- expose `needs_full_disk_access`, `needs_user_selected_folder`, `bookmark_stale`, and `access_denied_by_tcc` as typed outcomes;
- do not repeatedly rescan denied paths, because that can spam logs and annoy users.

UI rule:

- explain exactly which target needs access;
- never ask for Full Disk Access when a security-scoped folder grant is enough;
- provide "continue with skipped items" as a normal path.

### macOS File Provider And Dataless Files - `P0`

iCloud Drive and other File Provider locations can contain dataless files. Metadata can exist locally while content requires network download.

Implementation rule:

- detect cloud/file-provider capability where possible;
- never read file content just to determine size unless user opted into materialization;
- show logical size and local allocated size separately;
- model `cloud_placeholder`, `cloud_local`, `cloud_materializing`, and `cloud_unavailable` states.

Delete rule:

- moving a cloud placeholder to Trash/delete can affect cloud state, not just local disk;
- require a cloud-synced warning for candidates in known sync roots.

### macOS Packages, Bundles, And App Containers - `P1`

`.app`, `.photoslibrary`, `.xcodeproj`, `.xcworkspace`, `.framework`, `.bundle`, and other packages are directories that users perceive as files or documents.

Implementation rule:

- classify known package/bundle directories;
- UI can show them as expandable with a package badge, but delete queue must make scope explicit;
- "Reveal in Finder" should reveal the package root, not a random internal file;
- cleanup candidates inside app bundles should be conservative unless the user expanded and selected the exact path.

### Windows Cloud Files, Reparse Points, And Offline Recall - `P0`

Windows reparse points are broader than symlinks and junctions. They can represent cloud placeholders, mount points, deduplication, WOF/CompactOS, and other filter-managed objects.

Implementation rule:

- Windows adapter must expose reparse tag category, not only "is symlink";
- default traversal should not follow unknown reparse points;
- cloud placeholders must not be hydrated by scan unless explicitly requested;
- opening files for metadata must avoid recall/materialization when possible;
- unknown reparse tag is a first-class warning, not a fatal scan error.

Delete rule:

- deleting or moving a cloud placeholder can sync deletion to remote storage;
- use provider/sync-root warnings for OneDrive, Dropbox, iCloud Drive for Windows, SharePoint, and similar folders.

### Windows Alternate Streams, Oplocks, And Locked Handles - `P1`

NTFS files can have named streams. Delete access can fail if another process holds a stream without delete sharing.

Implementation rule:

- expose `has_alternate_streams` when detected;
- do not promise exact allocated size unless stream accounting is included;
- classify delete failures as locked, sharing violation, access denied, readonly, or provider denied where possible.

UI rule:

- "file is in use" should be a normal candidate result with retry and remove-from-queue.

### Linux CoW Filesystems, Snapshots, And Subvolumes - `P1`

Btrfs, ZFS, and other CoW filesystems can share extents through reflinks and snapshots. Deleting one path may not reclaim the apparent bytes.

Implementation rule:

- detect filesystem family where practical;
- treat CoW/snapshot filesystems like APFS for reclaim confidence;
- show `exclusive`, `shared`, or `unknown` reclaim confidence if platform APIs can provide it;
- do not block MVP on exact CoW accounting.

### Linux Mount Namespaces, Bind Mounts, OverlayFS, And Containers - `P1`

When Clean Disk runs inside Docker, devcontainers, WSL, Flatpak, Snap, or another sandbox, visible paths may not match the host's real disk layout.

Implementation rule:

- expose runtime environment capability flags: host, container, sandbox, WSL, flatpak/snap when detectable;
- do not advertise "full disk scan" from a restricted mount namespace;
- mount boundary policy must handle bind mounts and overlay layers;
- cleanup should be disabled or strongly warned in container/sandbox contexts unless explicitly trusted.

## Delete And Cloud Sync Edge Cases

### Synced Folder Delete Propagation - `P0`

Deleting from OneDrive/SharePoint/Dropbox/iCloud-synced folders can propagate to cloud and other devices. Microsoft documents cases where a synced local delete is synchronized to cloud and then to other devices.

Implementation rule:

- classify known sync roots;
- add `cloud_synced_delete` warning to DeletePlan;
- default action remains platform Trash, but UI must not describe it as "local only";
- if provider-specific recycle bin exists, mention recovery may be provider-specific and not guaranteed by our app.

### Online-Only Cleanup Is Usually Not Reclaim - `P0`

Deleting an online-only placeholder might not reclaim meaningful local bytes because it was already not consuming local content space.

Implementation rule:

- cleanup estimate for cloud placeholders is local allocated bytes, not logical cloud size;
- UI must avoid saying "free 40 GB" when the local allocated size is near zero;
- show "removes cloud item" vs "frees local disk" distinction.

### Trash Of A Sync Root Is Not Universal Undo - `P1`

OS Trash, OneDrive recycle bin, Dropbox deleted files, and iCloud recovery are different systems.

Implementation rule:

- delete receipt should record adapter outcome and provider hint;
- never promise universal restore;
- future restore feature must be adapter-specific, not a generic "undo delete" button.

## Daemon Security Deep Cuts

### DNS Rebinding And Host Header Checks - `P0`

Origin allowlist is not enough if a malicious domain can resolve to loopback or if Host handling is lax.

Implementation rule:

- reject requests whose `Host` is not an allowed loopback host/port for local mode;
- reject unknown `Origin` and `Sec-Fetch-Site` patterns for browser-facing endpoints;
- require bearer/local token in a header, not URL query;
- do not rely on cookies for local daemon auth;
- WebSocket handshake must apply the same checks as HTTP commands.

### Private Network Access And Browser Policy Changes - `P1`

Browser rules for local/private network access are changing. Chrome has PNA preflight behavior and WICG has a Local Network Access permission proposal.

Implementation rule:

- keep web transport isolated in `interfaces/http_ws`;
- document required CORS/PNA headers and test in Chrome, Edge, Safari, and Firefox;
- keep CLI/desktop fallback path independent of browser PNA behavior;
- expose a clear UI error when browser policy blocks local daemon connection.

### File URL And Null Origin - `P1`

Opening a Flutter web build as a local file can produce `Origin: null` or no normal origin.

Implementation rule:

- do not allow `Origin: null` for delete-capable local daemon;
- web UI should be served from the daemon or a trusted dev origin;
- development mode can have an explicit allowlist, never implicit wildcard.

### Remote Mode Is A Different Product Mode - `P0`

Remote server mode is useful, but it changes threat model and permissions.

Implementation rule:

- remote mode requires explicit config, auth, TLS/reverse proxy decision, and user identity model;
- remote mode should default to read-only scan until cleanup authorization is designed;
- capability endpoint must report delete/trash support per deployment;
- do not reuse the local ephemeral token model for remote users.

## Protocol And State Edge Cases

### Idempotency And Duplicate Commands - `P1`

HTTP retries, browser refreshes, and reconnects can duplicate commands.

Implementation rule:

- mutating commands should accept optional idempotency key when useful;
- `start_scan` on already-started session returns current state, not duplicate scan job;
- `move_to_trash` on completed DeletePlan returns prior result or a typed conflict;
- cancellation is idempotent.

### Snapshot Queries During Mutation - `P1`

Querying children while scan/indexing is still mutating can show inconsistent parent totals or duplicate/missing rows.

Implementation rule:

- query responses include `snapshot_id` or `index_version`;
- pages are stable within one query response;
- UI can show "updating" instead of pretending active scan data is final;
- cleanup from active/incomplete scans requires revalidation or waits for final state.

### Event Replay Window Boundaries - `P1`

Clients can reconnect with `after_seq` older than replay window.

Implementation rule:

- event stream returns `replay_missed` and forces query resync;
- terminal session state is always queryable after stream failure while session exists;
- replay window size is a runtime budget, not a correctness guarantee.

### Protocol Version Drift - `P1`

Desktop app, web bundle, and daemon binary can be updated independently.

Implementation rule:

- `/health` or `/capabilities` returns protocol version and feature flags;
- Flutter client refuses unsupported delete-capable protocol versions;
- event envelopes include version and unknown-field tolerant parsing;
- protocol snapshot tests are required before adding web release builds.

## UI, Accessibility, And Design System Edge Cases

### Keyboard-First Desktop Use - `P1`

A disk cleanup productivity tool should work well with keyboard and mouse:

- arrow navigation in tree;
- expand/collapse with keyboard;
- search focus;
- queue/remove/reveal shortcuts;
- focus recovery after file picker and dialogs.

Implementation rule:

- tree rows need focus model, selection model, and action intents;
- use Flutter `Actions`, `Shortcuts`, and focus traversal deliberately;
- Headless/design system should own reusable keyboard patterns, not page-specific hacks.

### Web Accessibility Semantics - `P1`

Flutter web uses a semantics layer for accessibility. Dense custom tree tables can become unreadable to screen readers if we only draw pixels.

Implementation rule:

- tree rows expose role, level, expanded/collapsed state, selected state, and size text;
- icon-only buttons require semantic labels/tooltips;
- color-only warnings are forbidden;
- if custom virtualization breaks semantics, report Headless/design-system gap before shipping.

### Path Spoofing And Bidi Controls - `P1`

Unicode bidirectional control characters and lookalike characters can make filenames render misleadingly.

Implementation rule:

- display path text should escape or visibly mark bidi controls and other suspicious controls;
- delete confirmation should include a copyable raw path and a safe-rendered path;
- logs and receipts should encode paths safely;
- tests should include filenames with RTL override, zero-width characters, newlines, and tabs.

### Huge Rows, Huge Counts, And Localized Formatting - `P2`

Large disks can produce large counts and long localized unit strings.

Implementation rule:

- use fixed-width numeric columns or measured constraints;
- support both binary and decimal unit policy later;
- avoid layout shifts when sizes change during scan;
- do not scale table font size with viewport width.

## Operational Edge Cases

### Sleep, Wake, Battery, And Thermal Pressure - `P1`

Scans can run while a laptop sleeps, wakes, switches power mode, or gets thermally constrained.

Implementation rule:

- session events should include pause/interrupted/resumed where detectable;
- elapsed time and throughput must handle sleep gaps;
- cancellation and shutdown must not depend on wall-clock timers only;
- UI should show "system slept or scan stalled" instead of fake progress.

### Antivirus, Indexers, And Backup Tools - `P1`

Security scanners, Spotlight, Windows Search, Time Machine, backup tools, and cloud sync engines can mutate or lock files during scan/delete.

Implementation rule:

- file-in-use and metadata-changed are expected outcomes;
- scan benchmarks should run with notes about indexing/antivirus state;
- delete retry must revalidate identity again.

### Crash Recovery And Session Garbage Collection - `P1`

Daemon crash can leave runtime files, lock files, incomplete receipts, and orphaned sessions.

Implementation rule:

- runtime lock/port files include pid and start time;
- stale locks are detected carefully;
- active sessions are ephemeral unless persistent history is explicitly implemented;
- delete receipts are written before or during move-to-trash according to durability policy;
- cleanup of old cache/session files must not delete user data.

## Dependency And Supply Chain Edge Cases

### Scanner And Trash Dependencies Are Privileged - `P0`

pdu and Trash adapters touch the filesystem heavily. Any dependency there has high trust.

Implementation rule:

- dependency additions require maintainer/activity/license/security check;
- run `cargo audit` or equivalent before Rust dependency acceptance;
- use `cargo-deny` when dependency graph stabilizes;
- consider `cargo auditable` for release binaries later;
- avoid build scripts/proc macros in privileged crates unless needed and reviewed.

### Forking pdu Is A Product Decision - `P1`

If pdu does not expose the progress/tree shape we need, forking is possible but creates maintenance cost.

Implementation rule:

- keep pdu anti-corruption adapter stable;
- document local patches if forked;
- upstream useful changes first when realistic;
- add adapter contract tests so switching back or replacing pdu remains possible.

## Additional Test Matrix

Add these to the future fixture plan where platform allows:

- macOS security-scoped bookmark stale resolution;
- macOS dataless iCloud/File Provider item;
- known macOS package directory selected and deleted as root;
- OneDrive online-only file with logical size larger than allocated size;
- delete candidate inside OneDrive/Dropbox/iCloud sync root;
- Windows unknown reparse tag fixture or mocked adapter;
- NTFS alternate stream fixture;
- Btrfs reflink or snapshot fixture on Linux CI where available;
- Linux bind mount or container mount namespace fixture;
- watcher overflow or replay-missed simulation;
- `Origin: null`, bad `Host`, bad `Origin`, missing token, and DNS-rebinding-style host tests;
- bidi-control filename display and delete confirmation;
- daemon crash during scan and during Trash operation;
- desktop focus traversal through tree, details, queue, and bottom progress.

## Guardrail Summary

📌 The deeper pattern is that Clean Disk must separate "what exists logically" from "what consumes local bytes" and "what deletion will actually reclaim".

Keep these distinctions stable:

- local bytes vs cloud logical bytes;
- path display vs selected identity;
- watcher notification vs current filesystem truth;
- OS Trash vs provider recycle bin vs permanent delete;
- local daemon convenience vs browser-origin attack surface;
- scan result tree vs cleanup authority.
