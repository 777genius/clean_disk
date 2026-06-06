# Implementation Edge Cases - Cloud, Network, And Virtual Filesystems

Last updated: 2026-05-13.

This file records edge cases for cloud-synced folders, online-only placeholders, network shares, NAS, user-space filesystems, remote mounts, and removable volumes.

The deeper point: the directory tree is not always a tree of local bytes. A path can represent local content, remote content, placeholder metadata, a provider cache, a virtual mount, a network resource, a sync root, or a file that will download only when touched.

Related documents:

- [Implementation edge cases deep dive](implementation-edge-cases-deep-dive.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md)
- [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md)

## Sources Reviewed

- Apple Developer Documentation, [TN3150: Getting ready for dataless files](https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files). Relevant point: some operations can materialize dataless files, so scanning must avoid accidental content downloads.
- Apple Developer Documentation, [Synchronizing the File Provider Extension](https://developer.apple.com/documentation/FileProvider/synchronizing-the-file-provider-extension). Relevant point: File Provider can enumerate content and materialize items as needed; materialized items are part of sync state.
- Microsoft Support, [OneDrive Files On-Demand](https://support.microsoft.com/en-us/office/sync-files-with-onedrive-files-on-demand-62e8d748-7877-420f-b600-24b56562aa70). Relevant points: online-only files do not use local disk content space until opened; locally available and always-available files take local space.
- Microsoft Learn, [Cloud Filter API](https://learn.microsoft.com/pl-pl/windows/win32/api/_cloudapi/). Relevant point: Windows cloud placeholders support hydration and dehydration states through Cloud Files APIs.
- Microsoft Learn sample, [CloudMirror Cloud Files API sample](https://learn.microsoft.com/en-us/samples/microsoft/windows-classic-samples/cloudmirror-sample/). Relevant point: cloud placeholder behavior is filter/reparse driven and not equivalent to ordinary local files.
- Google Drive Help, [Stream and mirror files with Drive for desktop](https://support.google.com/drive/answer/13401938). Relevant points: streamed files are primarily stored in the cloud and made available offline when accessed; mirrored files are always stored locally and in the cloud.
- Dropbox Help, [Free up space with online-only files](https://help.dropbox.com/sync/make-files-online-only). Relevant points: online-only files are stored in the cloud, do not occupy full local hard-drive space, and placeholders still use a small amount of local space.
- Dropbox Help, [Admins online-only settings](https://help.dropbox.com/sync/admins-online-only-settings). Relevant point: team/admin defaults can change local versus online-only behavior, and Dropbox for macOS File Provider has specific limitations.
- Box Support, [Making Content Available Offline](https://support.box.com/hc/en-us/articles/360043697574-Making-Content-Available-Offline). Relevant points: offline marking downloads content, uses local storage, and can fail due to insufficient disk space.
- Box Support, [About Box Drive](https://support.box.com/hc/en-us/articles/360044196553-About-Box-Drive). Relevant point: marking content for offline use downloads it to the device hard drive.
- Proton, [How on-demand sync works in Proton Drive Windows app](https://proton.me/support/proton-drive-windows-on-demand-sync). Relevant point: on-demand sync exposes cloud files in Explorer without taking unnecessary local disk space.
- Microsoft Learn, [SMB features in Windows and Windows Server](https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-feature-descriptions). Relevant point: SMB clients can reconnect transparently in some clustered/server scenarios, but network shares are still different from local volumes.
- Microsoft Learn, [Sync Center slow syncing of Offline Files](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/sync-center-slow-syncing-of-offline-files). Relevant point: SMB directory enumeration ordering can strongly affect offline sync performance; SMB does not require sorted query results.
- Microsoft Learn, [Offline file synchronization issues](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/offline-file-synchronization-issue). Relevant point: client-side caching can serve files from local cache while remote operations fail or remain offline.
- Microsoft Learn, [Client-Side Caching states](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-srvs/f83924b5-0876-4f3c-89d6-abff7765013c). Relevant point: SMB shares can signal different client-side caching states.
- Linux manual page, [mount.cifs](https://man7.org/linux/man-pages/man8/mount.cifs.8.html). Relevant point: CIFS/SMB clients use caching and oplock behavior that affects consistency and performance.
- libfuse, [API documentation](https://libfuse.github.io/doxygen/). Relevant point: FUSE exposes user-space filesystems to the kernel, so normal filesystem calls can trigger arbitrary provider behavior.
- macFUSE, [Mount Options](https://github.com/macfuse/macfuse/wiki/Mount-Options). Relevant points: access can be limited to the mounter unless `allow_other` is used; cache and metadata options affect consistency.
- rclone, [rclone mount](https://rclone.dev/commands/rclone_mount/). Relevant points: VFS cache modes change local disk use and behavior; overlapping remotes with VFS cache are warned against.
- FreeDesktop.org, [Trash Specification](https://specifications.freedesktop.org/trash/latest). Relevant point: Trash behavior on mounted/external volumes is topology-dependent.

## Severity Scale

- `P0` - can download huge cloud data accidentally, claim false reclaimable bytes, delete cloud files across devices, freeze on network shares, or move the wrong provider-backed object.
- `P1` - can make scans slow, confusing, inconsistent, incomplete, or support-heavy.
- `P2` - important diagnostics, UI clarity, provider-specific polish, or future integration risk.

## Top 3 Storage-Provider Decisions

1. Metadata-only scan by default with no automatic cloud hydration/materialization - 🎯 10 🛡️ 10 🧠 6, roughly 400-1100 LOC across scanner options, platform adapters, provider flags, and tests.
2. First-class size model: logical bytes, local allocated bytes, provider placeholder bytes, and reclaim estimate - 🎯 10 🛡️ 9 🧠 7, roughly 700-1800 LOC across domain value objects, Rust adapters, protocol DTOs, and UI columns.
3. DeletePlan cloud/network/removable risk classification before confirmation - 🎯 10 🛡️ 10 🧠 6, roughly 500-1400 LOC across sync-root detection, warnings, receipts, and destructive workflow tests.

These are stronger priorities than provider-specific integrations. The MVP does not need perfect OneDrive/Dropbox/iCloud APIs. It needs to avoid lying about local disk usage and avoid syncing destructive surprises.

## Core Principle

Clean Disk analyzes local disk pressure first.

Therefore every node can have more than one size:

```text
logical_size
local_allocated_size
provider_placeholder_size
remote_logical_size
estimated_local_reclaim
estimated_remote_effect
```

Rules:

- `logical_size` is not the same as local disk pressure.
- `remote_logical_size` is not the same as reclaimable local space.
- online-only placeholder delete may remove a cloud item without freeing meaningful local space.
- provider cache delete may free local space but not delete the cloud item, if provider exposes a safe "free up local space" action.
- network shares often do not affect the local disk at all, except through client caches.

The product must label these facts separately.

## Provider And Residency Model

### Residency State Must Be Typed - `P0`

Booleans like `is_cloud` are not enough.

Recommended model:

```text
residency_state:
  local
  local_provider_cache
  online_only_placeholder
  partially_hydrated
  hydration_in_progress
  dehydration_in_progress
  remote_network
  offline_cached_network
  virtual_mount_cache
  unknown_provider_managed
  unknown
```

Required behavior:

- unknown provider-managed files receive conservative warnings;
- UI shows local reclaim confidence;
- DeletePlan uses residency state in risk classification;
- scan result includes counts by residency state;
- capability endpoint reports whether provider detection is available.

### Provider Kind Must Be Separate From Filesystem Kind - `P1`

An APFS volume can contain iCloud/File Provider items. An NTFS volume can contain OneDrive placeholders. A FUSE mount can expose Google Drive or S3-like remote content.

Recommended model:

```text
filesystem_kind:
  apfs, ntfs, ext4, exfat, smb, nfs, fuse, unknown

provider_kind:
  none, icloud, onedrive, dropbox, google_drive, box, proton_drive,
  file_provider_generic, windows_cloud_files, rclone, sshfs, unknown
```

Rules:

- filesystem kind informs metadata and allocation semantics;
- provider kind informs hydration, sync, delete propagation, and user copy;
- both can be present at once;
- neither should leak into domain as raw platform strings.

### Sync Root Detection Is Best-Effort - `P1`

Provider roots can move, be renamed, live on external volumes, be enterprise-managed, or use a generic File Provider layer.

Required behavior:

- classify known roots best-effort;
- never rely only on folder names like `Dropbox` or `OneDrive`;
- store provider classification confidence;
- UI copy says "appears to be in a synced folder" when confidence is not exact;
- destructive actions are conservative when provider confidence is uncertain.

## Cloud Placeholder Scanning

### Do Not Open File Content To Measure Disk Usage - `P0`

Opening or reading provider-backed files can download data.

Required behavior:

- scanner must use metadata APIs where possible;
- no hash, preview, MIME sniffing, thumbnail read, or content sampling in default scan;
- "deep inspect" mode is separate and explicit;
- pdu adapter integration must be checked for APIs that open files;
- any future content-based classification requires a hydration policy review.

### macOS Dataless Files Can Materialize Unexpectedly - `P0`

Apple documents dataless files and materialization behavior. A seemingly normal enumeration or path operation can trigger provider work depending on API and context.

Required behavior:

- macOS adapter uses provider-safe metadata calls where possible;
- track whether a scan may have materialized files;
- if materialization starts, surface it as a warning and allow cancellation;
- do not recurse into provider roots with aggressive parallelism by default;
- test with iCloud/File Provider fixture on a real macOS machine before claiming safe behavior.

### Windows Cloud Files Need Reparse-Aware Handling - `P0`

Windows cloud placeholders are not ordinary files. They are commonly represented through reparse/filter mechanisms and Cloud Files APIs.

Required behavior:

- expose reparse tag/provider classification;
- avoid following unknown reparse points by default;
- do not treat placeholder logical size as local allocated size;
- classify hydration/dehydration errors separately;
- test OneDrive online-only, locally available, and always-available states.

### Provider Status Icons Are Not The Contract - `P1`

Finder/File Explorer overlay icons are UI indicators, not reliable protocol for our Rust scanner.

Required behavior:

- do not scrape icons or Finder labels;
- prefer platform metadata/provider APIs;
- if provider state cannot be read, mark as unknown;
- user-facing details can explain "provider status could not be verified";
- tests should not depend on icon appearance.

## Size And Reclaim Semantics

### Logical Cloud Size Can Be Huge While Local Reclaim Is Tiny - `P0`

OneDrive, Dropbox, Google Drive streaming mode, Box Drive, Proton Drive, and similar providers can show large files that do not occupy local content space.

Required behavior:

- details panel shows logical size separately from local size on disk;
- cleanup candidates sort by local reclaim by default, not cloud logical size;
- top files view can offer a "logical cloud size" mode, but it must be labeled;
- DeletePlan total reclaim excludes remote-only logical bytes;
- online-only placeholder row should not be a high-confidence local cleanup candidate.

### Provider Cache Can Consume Real Local Space - `P1`

Cloud providers and virtual mounts can keep caches outside the visible sync root.

Examples:

- provider cache folders;
- File Provider storage;
- rclone VFS cache;
- Google Drive/Dropbox/Box local caches;
- Windows Offline Files cache.

Required behavior:

- visible sync root scan is not enough to explain provider disk use;
- cache locations need provider-specific classification before cleanup recommendation;
- cache cleanup must prefer provider-supported "free up space" actions where available;
- direct delete of provider cache internals is high risk unless documented by provider;
- UI should distinguish "sync folder contents" from "provider cache".

### "Free Up Space" Is Not Delete - `P0`

Many providers offer a way to remove local content while keeping cloud files. That is conceptually different from moving files to Trash.

Top 3 implementation choices:

1. Do not implement provider-specific dehydrate/free-up-space in MVP - 🎯 9 🛡️ 9 🧠 3, roughly 50-200 LOC of capability flags and UI copy. Safest until provider APIs are understood.
2. Implement provider-specific safe actions later per provider - 🎯 7 🛡️ 8 🧠 8, roughly 800-2500 LOC per mature provider family. Useful but requires careful testing.
3. Simulate free-up-space by deleting local placeholder/cache files directly - 🎯 2 🛡️ 2 🧠 6, roughly 400-1200 LOC. Not acceptable for MVP.

MVP decision bias: choose 1.

### Estimates Need Confidence Labels - `P1`

Recommended reclaim confidence:

```text
exact_local
high_local
estimated_local
placeholder_near_zero
remote_effect_only
unknown_provider
not_applicable_network
```

Required behavior:

- table percent bars use the chosen size mode;
- details panel explains confidence;
- delete queue totals separate high-confidence local reclaim from uncertain/reclaim-unknown items;
- export includes confidence fields;
- recommendation rules use confidence, not just byte count.

## Delete And Sync Propagation

### Synced Folder Delete Can Propagate Across Devices - `P0`

Deleting inside a sync root can remove the item from cloud storage and other devices. This is not "local cleanup" even if the operation starts from a local file manager path.

Required behavior:

- DeletePlan marks `delete_propagation_risk = cloud_sync`;
- confirmation copy states that cloud and other devices may be affected;
- online-only placeholders show "may remove cloud item" rather than "free local disk";
- provider recycle-bin recovery is not promised by Clean Disk;
- batch delete groups synced items separately in review.

### Provider Recycle Bins Are Not OS Trash - `P1`

OS Trash, OneDrive recycle bin, Dropbox deleted files, Google Drive Trash, Box Trash, and iCloud recovery are different systems.

Required behavior:

- receipt records only what our adapter actually did;
- if OS Trash succeeds inside sync root, receipt says moved to OS Trash, not provider Trash;
- if provider later syncs the deletion, that is not a second receipt outcome unless observed;
- future restore must be adapter-specific;
- UI avoids "Undo" language unless restoration is implemented and tested.

### Shared Cloud Folders Need Extra Warning - `P0`

Shared OneDrive/SharePoint/Dropbox/Google Drive/Box folders may affect other people.

Required behavior:

- detect shared status only if provider API exists and user consent/auth model exists;
- without reliable shared detection, sync-root delete warning remains conservative;
- remote/team storage cleanup is read-only first;
- delete plan copy avoids claiming "only your files";
- future provider integrations need explicit authorization scopes.

### Conflicts And Versions Are Provider-Specific - `P1`

Cloud sync systems can create conflict copies, version history, or unsynced local changes.

Required behavior:

- classify conflict files as normal files unless provider-specific metadata is available;
- do not delete conflict files automatically as "duplicates";
- provider version history does not count as Clean Disk backup;
- delete receipt does not promise remote version recovery;
- recommendation engine treats conflict names as user-document risk.

## Network Shares And NAS

### Network Shares Are Not Local Disk Pressure - `P0`

An SMB/NFS/NAS folder may show huge files, but deleting them might not free local disk. It may free server quota, affect shared users, or only change a client cache.

Required behavior:

- target capability includes `network_remote = true` when detected;
- top summary separates local disk and remote share targets;
- local reclaim estimate for network shares is normally not applicable;
- cleanup actions on network shares are disabled or high-friction in MVP;
- remote/headless mode treats network shares as shared storage with audit implications.

### Network Traversal Needs Conservative Parallelism - `P1`

Parallel metadata traversal can overload slow NAS, VPN shares, SMB servers, or home routers.

Required behavior:

- detect remote mount/share when possible;
- reduce default scanner parallelism on network targets;
- expose throughput and latency as target characteristics;
- allow user cancellation to be responsive;
- do not benchmark pdu only on local SSD and assume same behavior for NAS.

### Directory Order And Pagination Can Be Weird - `P1`

Microsoft documents that SMB does not require directory results to be sorted, and unsorted results can affect offline sync performance.

Required behavior:

- never rely on network enumeration order;
- server-side index applies deterministic sorting;
- pagination uses snapshot/index version;
- network scans can take longer in metadata-heavy directories;
- UI should not label network slowness as app freeze.

### Offline Files And Client-Side Cache Can Lie - `P1`

Windows Offline Files/Sync Center and SMB client caching can serve cached files while remote state differs.

Required behavior:

- classify offline-cached network paths when detectable;
- report network/offline-cache confidence;
- do not execute destructive actions from stale offline cache without revalidation;
- delete plan revalidates server reachability and identity;
- receipt records whether operation touched remote server or local cache only, if distinguishable.

### Stale Handles And Disconnects Are Normal - `P1`

Network mounts can vanish, reconnect, or return stale handles while scanning.

Required behavior:

- map stale handle, timeout, disconnected, and permission-denied separately;
- scan can finish with skipped network subtree warnings;
- cancellation should not block indefinitely on a hung network call;
- target status can become unavailable during scan;
- user can remove stale network target from recent scans.

### Server Snapshots, Quotas, And Access-Based Enumeration Change Meaning - `P1`

NAS/server filesystems can have snapshots, quota rules, and access-based enumeration. The user may not see all files, and deleting may not reclaim quota immediately.

Required behavior:

- network target summary uses "visible to this user";
- quota/reclaim claims are low confidence unless server-specific data exists;
- do not scan hidden snapshot directories by default;
- do not recommend deleting NAS snapshot folders directly;
- remote/admin integrations are future work, not MVP local cleanup.

## User-Space And Virtual Filesystems

### FUSE/macFUSE/rclone Mounts Can Execute Arbitrary Provider Logic - `P1`

FUSE-like systems let user-space processes implement filesystem behavior. Normal metadata calls can involve network, caches, API requests, or provider bugs.

Required behavior:

- classify FUSE/macFUSE/sshfs/rclone-like targets when detectable;
- reduce parallelism and apply timeouts;
- treat size/reclaim as lower confidence;
- do not follow recursive mount loops;
- expose virtual filesystem warning in target details.

### rclone VFS Cache Can Be The Real Disk User - `P1`

rclone mount modes can create local VFS cache that consumes disk separately from the mounted remote tree.

Required behavior:

- remote mount tree and rclone cache location are separate targets;
- do not delete mounted remote files to clean local rclone cache;
- classify known rclone cache paths only as advanced cleanup candidates;
- warn that multiple overlapping remotes/caches can behave unexpectedly;
- local cache cleanup should follow rclone-supported behavior where possible.

### macFUSE Access May Be User-Specific - `P1`

macFUSE can restrict volume access to the mounting user unless options such as `allow_other` are used.

Required behavior:

- daemon running under different identity may not see user-mounted FUSE volumes;
- capability probe runs in scanner process identity;
- scan target picker should not assume app UI visibility equals daemon visibility;
- errors mention scanner identity mismatch if likely;
- no system service MVP for user-mounted virtual filesystems.

### Read-Only Virtual Mounts Need Clear Delete State - `P1`

Many virtual mounts are read-only or effectively not safe for modification.

Required behavior:

- detect read-only mount when possible;
- disable delete/move-to-trash for read-only target;
- avoid offering "free up space" if local reclaim is not applicable;
- show target as analysis-only;
- export/report still works with warning.

## External And Removable Volumes

### Removable Disconnect Is A Normal State - `P1`

USB disks, SD cards, phones, network-attached removable media, and external SSDs can disappear mid-scan.

Required behavior:

- target unavailable is a typed terminal/partial state;
- open handles are released promptly on cancel/unmount;
- UI tells user scan is partial because volume disappeared;
- delete plan expires when volume identity changes;
- recent scans show disconnected target state.

### Volume Identity Can Be Weak - `P1`

exFAT/FAT-like filesystems and some removable media may have weaker metadata, coarser timestamps, or unstable identifiers.

Required behavior:

- identity snapshot includes confidence;
- destructive revalidation is stricter when identity is weak;
- UI labels low-confidence identity in details;
- tests include removable/exFAT-like target if possible;
- do not merge scan history only by volume name.

### External Volume Trash Is Not Always Same As Home Trash - `P1`

Trash behavior can depend on filesystem, mount permissions, and platform trash spec.

Required behavior:

- Trash capability is per target, not global;
- external-volume Trash failure is normal item outcome;
- fallback permanent delete is not automatic;
- receipt records per-item target volume and adapter outcome;
- UI explains when item cannot be moved to Trash.

## Scanner Adapter Implications

### pdu Adapter Must Not Hide Provider Semantics - `P0`

`parallel-disk-usage` is a scanner adapter. Clean Disk still owns product semantics.

Required adapter contract:

- returns provider/residency flags when available;
- exposes reparse/symlink/mount handling policy;
- exposes whether logical or allocated size was measured;
- reports skipped provider-managed paths separately;
- can run with conservative options for network/cloud/removable targets.

If pdu cannot provide these signals:

1. Add a pre/post classification layer around pdu - 🎯 8 🛡️ 8 🧠 6, roughly 500-1400 LOC. Good first option.
2. Fork/patch pdu behind the same port - 🎯 7 🛡️ 8 🧠 8, roughly 1000-3000 LOC. Useful if core traversal needs provider-aware changes.
3. Accept opaque pdu output and infer in UI - 🎯 3 🛡️ 3 🧠 4, roughly 200-700 LOC. Not acceptable for cleanup decisions.

### Scan Options Need Hydration Policy - `P0`

Recommended scan options:

```text
hydrate_cloud_placeholders: false
follow_unknown_reparse_points: false
cross_network_mounts: ask
cross_removable_mounts: ask
network_parallelism: conservative
virtual_mount_parallelism: conservative
report_provider_states: true
```

Rules:

- options live in application commands, not UI-only state;
- default policy is safe and metadata-only;
- advanced modes must be explicit and cancellable;
- scan results record effective policy;
- benchmark reports include policy.

## UI Requirements

### The Tree Needs Provider Badges - `P1`

Badges should be useful, not decorative.

Recommended badges:

- cloud online-only;
- cloud local;
- provider cache;
- synced folder;
- network share;
- virtual mount;
- removable drive;
- read-only;
- low reclaim confidence;
- delete propagation risk.

Required behavior:

- badges have tooltips and accessible labels;
- row details explain size semantics;
- cleanup queue repeats important risk badges;
- compact layout still shows highest-risk badge;
- exports include badge/risk data.

### Size Columns Need Mode Awareness - `P0`

One "Size" column is ambiguous for provider-backed files.

Recommended MVP:

- central table default: local size on disk or estimated local reclaim;
- details panel: logical size, local size, provider state, reclaim confidence;
- top files view toggle later: local size vs logical size;
- delete queue total: high-confidence local reclaim plus uncertain amount;
- summary metric: "Local reclaim candidates", not "Cloud size".

### Copy Must Distinguish Cleanup From Cloud Deletion - `P0`

Bad:

```text
Delete this 80 GB online-only folder to free 80 GB.
```

Better:

```text
This folder appears to be online-only. Removing it may delete the cloud item, but it is not expected to free 80 GB from this Mac.
```

Rules:

- mention local disk only when local allocated/reclaim estimate supports it;
- mention cloud/sync propagation when in sync root;
- mention network/shared storage when target is remote;
- do not promise provider recovery;
- require extra confirmation for cloud-synced delete candidates.

## Clean Architecture Fit

### Provider Semantics Belong Behind Ports - `P0`

Recommended boundaries:

```text
domain:
  StorageProviderKind
  ResidencyState
  ReclaimEstimate
  DeletePropagationRisk
  TargetCapability

application ports:
  StorageProviderClassifier
  VolumeCapabilityProbe
  HydrationPolicy
  DeleteRiskClassifier
  TargetPerformanceProfile

infrastructure adapters:
  macos_file_provider_probe
  windows_cloud_files_probe
  linux_mount_probe
  network_share_probe
  fuse_mount_probe
  pdu_scan_adapter
```

Rules:

- domain expresses states and risks, not OS APIs;
- application use cases decide safe defaults;
- infrastructure maps platform/provider details;
- presentation receives view models and warnings;
- provider-specific APIs never leak into Flutter widgets.

### Recommendation Engine Needs Provider Evidence - `P1`

Every cleanup recommendation in provider-managed storage needs evidence fields:

```text
rule_id
provider_kind
residency_state
local_reclaim_estimate
remote_effect
confidence
user_warning
safe_action_available
```

Rules:

- no "large cloud placeholder" cleanup recommendation by byte count alone;
- no automatic delete recommendation for shared/synced documents;
- provider cache cleanup needs provider-specific rule id;
- test fixtures must include cloud placeholder and provider cache cases.

## Testing Matrix

### Cloud Provider Fixtures

Required before claiming provider-safe scanning:

- macOS iCloud/File Provider dataless file;
- Windows OneDrive online-only file;
- Windows OneDrive locally available file;
- Windows OneDrive always-available file;
- Dropbox online-only and offline/local items;
- Google Drive streaming and mirroring mode where available;
- Box offline-marked content where available;
- generic File Provider unknown provider;
- provider root on external drive if supported.

### Size And Reclaim Tests

Required:

- online-only logical size larger than local allocation;
- provider local cache consuming disk outside sync root;
- synced folder with mixed local and online-only children;
- details panel shows separate size fields;
- delete queue excludes remote-only logical bytes from local reclaim;
- export includes confidence.

### Delete Risk Tests

Required:

- cloud placeholder added to delete plan;
- local cloud file added to delete plan;
- synced folder delete warning;
- shared/synced unknown confidence warning;
- network share delete disabled or high-friction;
- external volume Trash unavailable;
- delete plan expires after provider state changes.

### Network Share Tests

Required:

- SMB/NFS or fake network target with high latency;
- directory with many unsorted entries;
- timeout/disconnect mid-scan;
- stale/unavailable handle mapped to typed warning;
- conservative parallelism profile applied;
- local reclaim not claimed for remote target.

### Virtual Filesystem Tests

Required:

- FUSE/macFUSE/sshfs/rclone-like mount if available;
- read-only virtual mount;
- daemon identity cannot access user-mounted volume;
- rclone cache directory treated separately from mounted remote tree;
- recursion/mount-loop guard;
- cancellation during slow provider response.

### Removable Volume Tests

Required:

- external drive scan;
- volume unplug/unmount mid-scan;
- weak metadata identity target;
- external Trash unsupported path;
- same volume label with different device identity;
- delete plan invalidation after reconnect.

## MVP Cut Line

Before first cleanup-capable beta:

- scan defaults to metadata-only and non-hydrating;
- protocol DTO has logical size, local allocated size, reclaim estimate, provider kind, residency state, and confidence fields;
- cloud/sync/network/removable warnings are part of DeletePlan;
- online-only placeholders do not inflate local reclaim totals;
- network shares are not presented as local disk pressure;
- pdu adapter behavior around reparse/provider paths is measured and documented;
- UI shows provider badges and detail explanations;
- delete confirmation explicitly warns for sync-root items;
- tests include at least one real OneDrive Files On-Demand fixture on Windows and one File Provider/dataless-style fixture on macOS before provider-safe claims.

Do not ship provider-specific "free up space" actions until the provider API and recovery semantics are explicitly designed.

## Summary

The safe stance:

```text
Scan metadata, not content.
Measure local pressure, not cloud inventory.
Separate logical size from local allocated size.
Treat sync-root delete as cloud-affecting.
Treat network and virtual mounts as lower-confidence targets.
Treat provider-specific cleanup as future work.
```

The invariant:

```text
Clean Disk must never download, hydrate, delete, or claim reclaim for provider-managed content unless the local-versus-remote effect is explicit.
```

