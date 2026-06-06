# Implementation Edge Cases Advanced Scenarios

Last updated: 2026-05-12.

This document adds a third layer of implementation research for Clean Disk. It focuses on advanced scenarios that are easy to miss if we think only in terms of "folders and files": system-managed storage, package-manager caches, virtual disks, developer tools, permissions, recommendations, installers, and operational behavior.

Read this after:

- [Implementation Edge Cases](implementation-edge-cases.md)
- [Implementation Edge Cases Deep Dive](implementation-edge-cases-deep-dive.md)

## Additional Sources Reviewed

- Apple Time Machine local snapshots - <https://support.apple.com/en-us/102154>
- Apple APFS snapshots in Disk Utility - <https://support.apple.com/guide/disk-utility/view-apfs-snapshots-dskuf82354dc/mac>
- Microsoft Volume Shadow Copy Service - <https://learn.microsoft.com/en-us/windows-server/storage/file-server/volume-shadow-copy-service>
- Microsoft WinSxS component store cleanup - <https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder>
- Docker prune and Docker Desktop disk usage docs - <https://docs.docker.com/engine/manage-resources/pruning/>
- Microsoft WSL disk-space management - <https://learn.microsoft.com/en-us/windows/wsl/disk-space>
- pnpm symlinked `node_modules` and hardlink store docs - <https://pnpm.io/symlinked-node-modules-structure>
- npm cache docs - <https://docs.npmjs.com/cli/commands/npm-cache>
- Cargo build cache and `cargo clean` docs - <https://doc.rust-lang.org/cargo/reference/build-cache.html> and <https://doc.rust-lang.org/cargo/commands/cargo-clean.html>
- Windows path naming, reserved names, and case sensitivity docs - <https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file> and <https://learn.microsoft.com/en-us/windows/wsl/case-sensitivity>
- Apple APFS filename behavior and file/directory guidance - <https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/FAQ/FAQ.html> and <https://developer.apple.com/documentation/technologyoverviews/files-and-directories>
- Windows ACL and file security docs - <https://learn.microsoft.com/en-us/windows/win32/secauthz/access-control-lists> and <https://learn.microsoft.com/en-us/windows/win32/fileio/file-security-and-access-rights>
- Linux capabilities docs for `CAP_LINUX_IMMUTABLE` - <https://man7.org/linux/man-pages/man7/capabilities.7.html>
- OWASP Logging Cheat Sheet - <https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html>
- Apple macOS code signing/notarization docs - <https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution>
- Microsoft SmartScreen reputation docs - <https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation>

## Main Advanced Bias

Clean Disk should not treat every large item as the same kind of cleanup target.

Use this mental model:

- normal user files - user-owned, can be moved to Trash after confirmation;
- rebuildable caches - safe only if the owning tool confirms or the cache semantics are known;
- system-managed storage - inspect and explain, but delegate cleanup to OS tools;
- virtualized storage - deleting the host image is dangerous, reclaim often needs tool-specific prune/compact;
- synced/cloud storage - local bytes and cloud object deletion are different actions;
- protected storage - permission/identity rules decide whether cleanup is even allowed.

## System-Managed Storage

### Time Machine Local Snapshots And Purgeable Space - `P0`

macOS can keep local Time Machine snapshots on APFS. Apple documents that snapshot space is counted as available storage and snapshots are managed by the system.

Implementation rule:

- classify Time Machine local snapshots as system-managed, not normal folders;
- do not offer "Move to Trash" for snapshot storage;
- show it as reclaimable-by-system or OS-managed where detectable;
- if we later add an action, it must call/document an Apple-supported flow and require explicit user consent.

UI rule:

- do not display snapshot bytes as normal cleanup candidates;
- explain that deleting user files may not immediately increase free-space display if snapshots still reference blocks.

### Windows VSS Shadow Copies - `P0`

Windows Volume Shadow Copy Service creates point-in-time snapshots. Snapshot storage is not an ordinary folder cleanup target.

Implementation rule:

- classify VSS storage as system-managed;
- never delete VSS files directly;
- future cleanup action must use documented Windows tools/APIs and admin policy;
- remote/server mode should default to read-only reporting for VSS.

### Windows WinSxS Component Store - `P0`

The WinSxS component store can look huge, but Microsoft documents cleanup through DISM/component cleanup tasks. Direct deletion can break Windows servicing.

Implementation rule:

- classify `C:\Windows\WinSxS` as protected system-managed storage;
- never offer direct Trash/delete inside WinSxS;
- show "Use Windows component cleanup" rather than "delete folder";
- scanner should handle WinSxS hardlinks without claiming that the full apparent size is reclaimable.

### Recycle Bin And Trash Storage Itself - `P1`

Trash/Recycle Bin may occupy substantial space and may be per-volume/provider-specific.

Implementation rule:

- show Trash usage separately from normal folder usage;
- "Empty Trash" is a platform action, not a recursive delete of a folder;
- if provider-specific Trash exists, keep OS Trash and provider recovery separate;
- do not include Trash candidates in the same delete queue as normal files without clear labeling.

## Virtualized And Tool-Owned Storage

### Docker Desktop Disk Images And Volumes - `P0`

Docker Desktop and WSL can store containers/images/volumes inside virtual disks. Docker docs warn that volumes are not removed automatically because they can contain persistent data.

Implementation rule:

- detect Docker storage roots and Docker Desktop disk images where practical;
- do not recommend deleting Docker's virtual disk file directly;
- show Docker storage as tool-owned;
- future cleanup actions should use Docker APIs/CLI with preview: images, containers, build cache, networks, volumes;
- volumes are highest-risk and need separate confirmation.

Recommended product path:

1. Read-only Docker storage classification in MVP - 🎯 9 🛡️ 9 🧠 4, roughly 150-400 LOC.
2. Docker prune advisor with explicit per-object preview later - 🎯 8 🛡️ 8 🧠 7, roughly 700-1800 LOC.
3. Delete Docker disk image from file tree - 🎯 1 🛡️ 1 🧠 2, roughly 50-150 LOC.

Decision bias: choose 1 first, maybe 2 later. Never choose 3 as a normal cleanup action.

### WSL VHDX And Linux Distribution Storage - `P1`

WSL 2 uses VHD files. Deleting files inside a distro and shrinking the host-side VHD are different operations.

Implementation rule:

- classify WSL distro disks as virtualized storage;
- direct deletion of `.vhdx` is dangerous and should be blocked/warned;
- future reclaim action should explain distro shutdown, compaction, and Microsoft-supported steps;
- scan mode running inside WSL must say it sees the Linux filesystem view, not the host's full Windows disk.

### VM Images, Simulator Images, And Sparse Bundles - `P1`

Virtual machine disks, iOS simulator runtimes, Android emulator images, Parallels/VMware/VirtualBox images, and sparse bundles can be huge. Reclaiming inside them is different from deleting the image.

Implementation rule:

- classify common VM/simulator image formats as tool-owned;
- show logical file size vs allocated sparse size where possible;
- direct move-to-Trash is allowed only if user selected the whole VM/simulator image knowingly;
- do not inspect or mutate inside disk images in MVP.

### Database And Search Index Storage - `P1`

Postgres, SQLite, Lucene, browser profiles, mail stores, Spotlight indexes, Windows Search indexes, and app databases can hold large files with internal ownership.

Implementation rule:

- classify known database/index files as application-owned;
- avoid "delete largest file" recommendations for active databases;
- delete candidate should warn "owned by app/service";
- future app-specific cleanup should use app APIs or documented maintenance commands, not raw file delete.

## Developer Tool And Package Cache Edge Cases

### pnpm Hardlinks And Symlinked `node_modules` - `P0`

pnpm stores packages in a content-addressable store and hardlinks package files into project `node_modules`, with symlinks building dependency layout.

Implementation rule:

- `node_modules` size can double-count hardlinked/shared storage;
- cleanup estimate must respect hardlink policy;
- deleting a project `node_modules` is usually safe but may not reclaim all displayed bytes if content is shared;
- deleting the pnpm store can break many projects and must be treated as package-manager cache cleanup, not ordinary folder delete.

### npm/Yarn/pnpm Cache Semantics - `P1`

Package-manager caches are often rebuildable, but each tool has different commands and safety behavior. npm documents cache as a cache, but it still requires explicit `--force` for `npm cache clean` in some versions.

Implementation rule:

- classify package-manager caches separately from project dependencies;
- prefer "recommend tool command" or adapter action over raw deletion;
- show rebuild cost and network dependency;
- never delete lockfiles or source project directories as cache.

### Cargo `target` Vs Cargo Global Cache - `P1`

Cargo docs distinguish build output in `target/` and registry/git caches under Cargo home. `cargo clean` removes target build artifacts, not all global cache.

Implementation rule:

- classify `target/` as project build output when a nearby `Cargo.toml` exists;
- classify Cargo registry/git cache as global package-manager cache;
- do not delete shared Cargo cache without explaining it may trigger downloads/rebuilds;
- if future action exists, prefer Cargo-supported commands or documented cache behavior.

### Xcode DerivedData, Simulators, And DeviceSupport - `P1`

Xcode caches can be huge, but some are active, version-specific, or expensive to recreate.

Implementation rule:

- classify DerivedData as rebuildable development cache;
- classify simulators/runtimes separately because they may contain user app data;
- do not treat all `~/Library/Developer` as safe cache;
- future cleanup adapters should preview target class: build products, indexes, archives, simulators, device support.

### Browser Profiles And App Support Folders - `P0`

Browser profiles, chat apps, mail clients, photo libraries, password managers, and app support directories can be large but user-critical.

Implementation rule:

- never auto-label all `Application Support` as cleanup candidate;
- cache subfolders can be candidates only when known safe or app-specific;
- profile/database folders require warning and app ownership classification;
- cleanup UI should separate "large data" from "safe cleanup".

## Recommendation Engine Safety

### Cleanup Recommendations Need Risk Tiers - `P0`

A disk analyzer can show everything, but a cleanup tool must not imply that everything large is safe to remove.

Recommended tiers:

1. Rebuildable cache - 🎯 9 🛡️ 8 🧠 5, roughly 300-900 LOC for classification rules and UI.
2. Review manually - 🎯 10 🛡️ 9 🧠 4, roughly 150-500 LOC.
3. System/tool-managed - 🎯 9 🛡️ 10 🧠 6, roughly 400-1200 LOC with adapters.
4. Dangerous/protected - 🎯 10 🛡️ 10 🧠 5, roughly 250-700 LOC.

Implementation rule:

- every cleanup candidate has `risk_tier`, `owner_kind`, `reclaim_confidence`, and `action_kind`;
- `risk_tier` is not derived only from path or extension;
- unclassified large directories default to "Review manually", not "Cleanup candidate".

### "One Click Clean" Is A Product Risk - `P0`

One-click cleanup is attractive but dangerous with cloud sync, tool-owned storage, hardlinks, snapshots, and user documents.

Implementation rule:

- no one-click cleanup across mixed risk tiers;
- batch cleanup is allowed only after plan validation and explicit review;
- system-managed/tool-managed actions require separate adapter-specific confirmation;
- summary must show "estimated local reclaim" and "items affected".

### Recommendation Explanations Must Be Auditable - `P1`

Users need to know why an item was recommended.

Implementation rule:

- every recommendation carries `reason_codes`;
- examples: `known_cache_path`, `older_than_threshold`, `app_owner_detected`, `hardlink_low_reclaim`, `cloud_synced_warning`, `system_protected`;
- UI shows concise reason, details panel shows full explanation;
- tests snapshot reason codes so future rule changes are visible.

## Path And Name Advanced Cases

### Windows Reserved Names And Device Paths - `P0`

Windows reserves names like `CON`, `PRN`, `AUX`, `NUL`, `COM1`, `LPT1`, and has special device/namespace path behavior.

Implementation rule:

- avoid constructing Windows paths from display strings;
- use OS APIs and `PathBuf` boundaries;
- protocol actions use node ids, not user-edited paths;
- Windows adapter must preserve raw path identity and avoid normalizing into device names.

### Case Sensitivity Is Not Global - `P1`

APFS can be case-sensitive or case-insensitive. Windows NTFS can have per-directory case sensitivity for WSL scenarios.

Implementation rule:

- path comparison policy is per-volume/per-directory where detectable;
- do not lower-case paths for identity;
- search can be case-insensitive for UX, but identity and delete matching cannot;
- tests need same-name-different-case fixtures where platform supports them.

### Unicode Normalization And Visual Equivalence - `P1`

Apple documents APFS normalization behavior, and Unicode-equivalent names can behave differently across filesystems.

Implementation rule:

- display normalization is separate from identity;
- receipts and logs must encode raw path safely;
- cross-platform export/import of scan history must not assume normalized strings are stable identities.

### Control Characters In Filenames - `P1`

Unix filenames can contain newlines, tabs, escape sequences, and many control characters except path separator and NUL.

Implementation rule:

- UI renders control characters visibly or escaped;
- logs use structured fields and escaping to prevent log injection;
- CSV/text exports must quote/escape paths;
- tests include newline, tab, carriage return, ANSI escape-like names, and bidi controls.

## Permission And Protection Edge Cases

### Windows ACLs And Ownership - `P0`

Windows file access depends on security descriptors, DACLs, inherited ACEs, ownership, privileges, and sometimes SYSTEM/TrustedInstaller-owned resources.

Implementation rule:

- do not infer delete ability from readonly flag;
- classify access denied with reason where possible: DACL denied, owner mismatch, elevated/admin needed, SYSTEM protected, sharing violation;
- do not attempt ownership changes or ACL edits in MVP;
- protected system locations are inspect-only.

### Linux Immutable, Append-Only, SELinux/AppArmor - `P1`

Linux deletion can fail even as root due to immutable/append-only attributes, capabilities, MAC policies, read-only mounts, or namespace restrictions.

Implementation rule:

- classify immutable/append-only where detectable;
- do not clear immutable flags automatically;
- expose read-only mount and sandbox restrictions separately from Unix mode-bit denial;
- in server mode, surface SELinux/AppArmor-style denial as policy denial if detectable.

### macOS SIP, Quarantine, Tags, And Extended Attributes - `P1`

macOS system protection and extended metadata affect how files should be treated.

Implementation rule:

- do not strip xattrs, quarantine, tags, or resource-fork-like metadata as "cleanup";
- SIP-protected paths are inspect-only unless a future OS-supported action exists;
- if xattr size is displayed, keep it as platform metadata and not a default cleanup target.

## Performance And Measurement Traps

### Disk Size Is Less Important Than Entry Count - `P0`

A 500 GB disk with millions of tiny files can be slower than a 2 TB disk with large media files.

Implementation rule:

- scan progress reports bytes, entries, directories, skipped, current path, and throughput separately;
- ETA is confidence-based and can be absent;
- benchmark by entry count and directory depth, not only GB scanned.

### Cold Cache, Warm Cache, And Antivirus Variance - `P1`

Repeated scans may look much faster because OS metadata is cached. Antivirus, Spotlight, Windows Search, cloud sync, and backup tools can change scan speed.

Implementation rule:

- benchmarks record cold/warm state when known;
- UI throughput is "current estimate", not promised performance;
- performance tests should include high-entry-count fixtures and real-world folders.

### Sorting And Search Can Dominate Scan Time - `P1`

After traversal, building top lists, search indexes, and sorted child pages can dominate latency.

Implementation rule:

- use bounded top-K indexes where possible;
- do not globally sort millions of nodes for every query;
- search index can be incremental or built lazily;
- report index-building as a separate session phase if noticeable.

### Memory Footprint Must Be A Budget - `P0`

Rust owns tree/indexes. A naive per-node model can use too much memory on large disks.

Implementation rule:

- define memory budget per million nodes before implementation;
- store interned strings/path segments where useful;
- use compact node records and external detail fetches;
- fail a session with `resource_exhausted` rather than crash;
- expose approximate memory use in debug metrics.

## Daemon, Update, And Installer Edge Cases

### Daemon And UI Version Mismatch - `P0`

Desktop app, web UI bundle, CLI, and daemon can be updated independently.

Implementation rule:

- handshake includes daemon version, protocol version, capabilities, and minimum client version;
- UI refuses delete-capable actions on incompatible daemon;
- daemon serves the matching web UI bundle in local mode where possible;
- update process must not leave old daemon running with new UI silently.

### Auto-Update During Active Scan Or Delete - `P0`

Updates can interrupt scanning or cleanup.

Implementation rule:

- block auto-update during active delete;
- active scan can be cancelled or drained according to policy;
- update manager must stop/restart daemon explicitly;
- crash/update recovery must not retry delete actions without user confirmation.

### macOS Signing, Notarization, And Full Disk Access Identity - `P1`

macOS privacy permissions are tied to app identity/signing. Direct distribution requires Developer ID signing and notarization for normal Gatekeeper behavior.

Implementation rule:

- signing identity changes can affect saved permissions/bookmarks;
- release builds must be signed/notarized before permission UX is trusted;
- helper/daemon binary signing must be part of packaging plan;
- do not test Full Disk Access UX only with unsigned debug builds.

### Windows SmartScreen, Firewall, And Defender - `P1`

Microsoft documents that SmartScreen uses publisher/file reputation. A local TCP daemon may also trigger firewall/security product attention.

Implementation rule:

- signed installer and binary are part of usability, not polish;
- loopback-only daemon should avoid unnecessary firewall prompts;
- Windows Defender/SmartScreen warnings should be expected for early distribution;
- installer must clearly identify publisher and purpose.

### Linux Packaging Permissions - `P1`

Flatpak, Snap, AppImage, distro packages, and direct tarballs have different filesystem visibility and sandbox rules.

Implementation rule:

- packaged mode must expose `sandboxed` capability;
- do not promise full disk scan in sandboxed Flatpak/Snap without portal/access grants;
- Trash support may differ by desktop environment and package format;
- server/headless Linux should be scan-first, cleanup-limited by default.

## Privacy, Logging, And Telemetry

### File Paths Are Sensitive Data - `P0`

Paths can reveal names, projects, customers, medical/legal topics, repos, secrets, and account structure. OWASP logging guidance warns against logging sensitive data and session identifiers directly.

Implementation rule:

- production logs redact home prefix and daemon tokens;
- telemetry defaults off unless explicitly accepted later;
- crash reports must not include full scan tree;
- debug export requires explicit user action and redaction preview.

### Delete Receipts Need Balance - `P1`

Receipts help accountability but can leak private paths.

Implementation rule:

- local receipt stores enough for user review and support;
- exportable receipt has redaction options;
- remote/server mode needs retention policy before delete-capable release;
- receipt integrity matters more for delete actions than scan actions.

### Screenshots And Support Bundles - `P1`

The UI itself displays private file paths and sizes.

Implementation rule:

- support bundle generator should redact paths by default;
- screenshot mode could optionally blur home/user names later;
- logs and support bundles must never include local daemon auth token.

## Enterprise And Remote Mode

### Multi-User Servers Are Not Desktop Scanners - `P0`

Remote mode on a server has users, permissions, audit requirements, and potentially shared filesystems.

Implementation rule:

- remote mode starts read-only unless cleanup auth model is designed;
- scan target allowlist is admin-configured;
- user identity and audit trail are required before delete;
- do not run daemon as root/admin just to scan more paths.

### Network Shares And NAS - `P1`

SMB/NFS/NAS paths may have server-side snapshots, quotas, ACLs, stale handles, offline files, and latency spikes.

Implementation rule:

- classify network filesystem capability;
- show lower reclaim confidence;
- avoid aggressive parallelism on network shares by default;
- delete operations require extra warning because server-side Trash/snapshots differ.

### Organization Policy And MDM - `P1`

Enterprise macOS/Windows environments may block Full Disk Access, local daemons, unsigned apps, or network listeners.

Implementation rule:

- capability endpoint and UI must show policy-denied states;
- installer should support managed configuration later;
- local daemon port/origin policy should be configurable by admins without weakening defaults.

## Additional Test Matrix

Add these fixtures or mocked adapter tests later:

- Time Machine snapshot present while deleting a referenced file;
- Windows WinSxS path classified as protected and not deletable;
- VSS/shadow storage detected or mocked as system-managed;
- Docker Desktop disk image detected and direct delete blocked;
- Docker volume cleanup preview with data-loss warning;
- WSL `.vhdx` direct delete blocked;
- pnpm project with hardlinked `node_modules`;
- Cargo project `target/` vs global Cargo registry cache;
- npm cache classification;
- Xcode DerivedData vs simulator data classification;
- Windows reserved name/path fixture through mocked adapter;
- APFS case-sensitive and case-insensitive duplicate name fixture;
- NTFS per-directory case-sensitive fixture where available;
- newline/tab/control-character filename export and log escaping;
- Windows ACL denied delete vs readonly attribute;
- Linux immutable file delete failure;
- daemon/UI protocol mismatch;
- update attempted during active delete;
- redacted support bundle export;
- remote mode refuses delete without auth model.

## Guardrail Summary

📌 Advanced rule: the app can be an excellent disk analyzer before it becomes an aggressive cleaner. Showing truth is safer than pretending every large item has a safe delete button.

Keep these product boundaries:

- system-managed storage is explainable, not directly deletable;
- tool-owned storage needs tool-specific adapters;
- package caches are not all equal;
- protected paths default to inspect-only;
- recommendations need risk tiers and reason codes;
- delete receipts and logs are private data;
- update/installer behavior is part of correctness for a daemon app.

