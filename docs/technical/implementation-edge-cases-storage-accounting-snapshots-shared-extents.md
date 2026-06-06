# Implementation Edge Cases - Storage Accounting, Snapshots, And Shared Extents

Last updated: 2026-05-16.

This document records edge cases for storage accounting: snapshots, clones, reflinks, deduplication, sparse files, compression, alternate streams, purgeable space, quotas, and "why did deleting this not free as much as expected?"

See also: `docs/technical/reclaim-accounting-deep-research.md` for the deeper reclaim confidence/evidence model and platform API feasibility matrix.

Clean Disk must be honest about three different questions:

```text
How large does this file/folder look to applications?
How much local disk allocation is currently tied to it?
How much free space will actually return after cleanup?
```

Those are not the same question on modern filesystems.

## Sources Reviewed

- Apple Developer, [About Apple File System](https://developer.apple.com/documentation/foundation/file_system/about_apple_file_system?changes=_8_5). Relevant points from accessible summary: APFS includes cloning, snapshots, space sharing, fast directory sizing, atomic safe-save, and sparse files; a clone can occupy no additional disk space at creation.
- Apple Developer archive, [Apple File System Guide introduction](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/Introduction/Introduction.html). Relevant points: APFS is optimized for Flash/SSD and features copy-on-write metadata, space sharing, clones, snapshots, fast directory sizing, and sparse files.
- Apple Support, [About Time Machine local snapshots](https://support.apple.com/en-us/102154). Relevant points: Time Machine saves local snapshots, macOS counts snapshot space as available storage, and snapshots are deleted automatically as they age or as space is needed.
- Apple WWDC 2019, [What's New in Apple File Systems](https://developer.apple.com/videos/play/wwdc2019/710/). Relevant points: APFS snapshots capture point-in-time volume state; deleted files can still exist in snapshots; snapshot deltas can be used for efficient replication.
- Microsoft Learn, [Volume Shadow Copy Service](https://learn.microsoft.com/en-us/windows-server/storage/file-server/volume-shadow-copy-service). Relevant points: VSS creates consistent volume snapshots through requesters, writers, and providers; providers can use complete copy, copy-on-write, or redirect-on-write; VSS has diff areas and tools such as DiskShadow and VssAdmin.
- Microsoft Learn, [Block cloning on ReFS](https://learn.microsoft.com/en-us/windows-server/storage/refs/block-cloning). Relevant points: ReFS block cloning remaps metadata instead of copying file data and allows multiple files to share physical clusters with reference counts.
- Microsoft Learn, [GetCompressedFileSizeW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getcompressedfilesizew). Relevant points: the API retrieves actual bytes used for compressed or sparse files where supported.
- Microsoft Learn, [Sparse files](https://learn.microsoft.com/en-us/windows/win32/fileio/sparse-files). Relevant points: sparse files allocate disk only for nonzero regions, and quotas can be affected by nominal size rather than allocated size.
- Microsoft Learn, [File streams](https://learn.microsoft.com/en-us/windows/win32/fileio/file-streams). Relevant points: NTFS streams have their own allocation size, actual size, valid data length, and compression/encryption/sparse state.
- Microsoft Learn, [About Data Deduplication](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/dedup/about-data-deduplication). Relevant points: Windows Data Deduplication chunks files, stores one copy of duplicate chunks, replaces files with reparse points, and garbage collection later reclaims unreferenced chunks.
- Microsoft Learn, [Understanding Data Deduplication](https://learn.microsoft.com/en-us/windows-server/storage/data-deduplication/understand). Relevant points: dedupe operates transparently through a file system filter and the chunk store must not be manually modified.
- Btrfs docs, [Reflink](https://btrfs.readthedocs.io/en/stable/Reflink.html). Relevant points: reflink creates separate metadata pointing to shared blocks instead of deep-copying all blocks.
- Btrfs docs, [Quota groups](https://btrfs.readthedocs.io/en/latest/Qgroups.html). Relevant points: qgroups can account shared and exclusive usage, but that accuracy has cost and can create latency when snapshots scale.
- Linux kernel docs, [FIEMAP ioctl](https://docs.kernel.org/filesystems/fiemap.html). Relevant points: FIEMAP returns file extent mappings, and extent flags can indicate shared extents where supported.
- OpenZFS docs, [`zfs` man page](https://openzfs.github.io/openzfs-docs/man/v0.7/8/zfs.8.html). Relevant points: `referenced`, `logicalused`, `used`, `usedbysnapshots`, and clone/snapshot properties have different space-accounting semantics; snapshot used space is exclusive to that snapshot and can change when adjacent snapshots are destroyed.

## Severity Scale

- `P0` - can promise incorrect freed space, delete system-managed snapshot/dedup storage directly, corrupt storage, or hide that deletion did not reclaim space.
- `P1` - can confuse users, create wrong cleanup rankings, break quotas, mislabel cloud/local storage, or make receipts dishonest.
- `P2` - can reduce accuracy, make benchmarks misleading, or hide platform limitations.
- `P3` - polish, diagnostics, or future filesystem-specific improvements.

## Core Principle

Never promise exact reclaimed bytes unless the adapter can prove exclusive local allocation.

Clean Disk should show size with confidence:

```text
logical size:
  what apps see

allocated size:
  what the file appears to allocate locally

exclusive reclaim estimate:
  what we believe will become free if deleted

reclaim confidence:
  exact | high | medium | low | unknown

uncertainty factors:
  snapshots, clones, reflinks, dedupe, sparse, compression, cloud placeholder, open file, mount quota
```

## Top 3 Decisions

1. Separate logical, allocated, exclusive estimate, and confidence in the domain model - 🎯 10 🛡️ 10 🧠 6, roughly 700-1800 LOC across Rust structs, protocol DTOs, UI labels, tests, and pdu mapping.

   This is mandatory. A single `size_bytes` field is not enough for a modern disk analyzer.

2. Filesystem capability adapter per volume, not global assumptions - 🎯 9 🛡️ 9 🧠 7, roughly 1000-2600 LOC across macOS, Windows, Linux, mount detection, capability flags, and fixtures.

   Correctness depends on volume format and mount provider, not only OS.

3. Conservative reclaim UX with "estimated" and "may be retained by snapshots/shared storage" warnings - 🎯 9 🛡️ 9 🧠 5, roughly 300-900 LOC across UI, receipt text, rule engine, and explanations.

   This avoids false trust while still making the app useful.

## Size Vocabulary

### Required Terms

```text
logical_size:
  file length or application-visible bytes

allocated_size:
  local allocation reported by filesystem APIs

apparent_size:
  same family as logical_size, useful for du-like output

shared_size:
  bytes that may be referenced by multiple files/snapshots/datasets

exclusive_size:
  bytes uniquely owned by this node/scope where platform can prove it

reclaim_estimate:
  expected local free-space increase after cleanup

quota_effect:
  expected impact on a quota, which may differ from local allocation

purgeable_size:
  system-managed storage that OS may free when needed
```

### UI Rule

Never display a single unqualified "Size" as the only value once storage features are detected.

Main table can still have a simple `Size` column, but details must label:

- `Size on disk`;
- `App-visible size`;
- `Estimated reclaim`;
- `Confidence`;
- `Warnings`.

## APFS Clones

### Problem - `P0`

APFS clones can make a copied file appear large while occupying little or no additional disk space at creation. If two 20 GB files share extents, deleting one may not free 20 GB.

### Failure Modes

- UI ranks clone copies as huge cleanup candidates;
- delete receipt claims 20 GB reclaimed but free space barely changes;
- "duplicate files" feature recommends deleting a clone without understanding shared extents;
- pdu/hardlink logic gives false confidence because clone sharing is not inode hardlink sharing.

### Required Mitigation

- Treat APFS clone/reflink awareness as separate from hardlink dedupe.
- If shared extent detection is unavailable, mark reclaim estimate as low confidence.
- Details panel should show: `May share storage with APFS clones or snapshots`.
- Duplicate-file cleanup must not assume clone copies reclaim full logical size.
- Do not promise exact reclaim from APFS clone files until adapter can prove exclusive extents.

### Architecture

```text
FilesystemCapabilities
  supports_clone_files
  supports_shared_extents
  can_detect_shared_extents
  can_estimate_exclusive_bytes
```

Domain stores capability facts and confidence, not APFS API details.

## APFS Snapshots And Time Machine Local Snapshots

### Problem - `P0`

Deleting a file from the live filesystem does not necessarily free its blocks if snapshots still reference the old state. Apple documents that Time Machine local snapshot space is counted as available storage and managed by macOS.

### Failure Modes

- user deletes 40 GB and sees almost no immediate free-space increase;
- app blames itself or reports wrong receipt;
- app offers snapshots as normal folders;
- user deletes snapshot-related paths directly and damages backup/restore behavior;
- Storage Settings and our app disagree because macOS treats some snapshot space as available/purgeable.

### Required Mitigation

- Classify Time Machine/APFS snapshot storage as system-managed.
- Do not offer Move to Trash for APFS snapshots.
- Show snapshot retention as an uncertainty factor, not a normal cleanup candidate.
- After cleanup, compare volume free space before/after and show actual observed delta.
- Receipt says `moved/deleted`, not `freed`, unless free-space delta confirms it.
- Details explain: `Free space may update later if local snapshots still reference deleted data`.

### UI Copy

Good:

```text
Estimated reclaim: 38.7 GB
Confidence: Medium
Some blocks may be retained by APFS or Time Machine snapshots.
```

Bad:

```text
You will free 38.7 GB.
```

## APFS Space Sharing And Multiple Volumes

### Problem - `P1`

APFS volumes can share container free space. A volume's reported free/available bytes may include space shared with sibling volumes.

### Failure Modes

- app says "Macintosh HD has 100 GB free" but another APFS volume consumes the shared container;
- cleanup estimate ignores sibling volume pressure;
- app attributes container-level pressure to wrong root.

### Required Mitigation

- Volume model distinguishes:
  - volume path;
  - filesystem;
  - APFS container identity where available;
  - volume available;
  - user available;
  - container shared free.
- UI should not rank sibling APFS volumes as independent disks if they share a container.
- Disk summary can show `shared APFS container` when detected.

## Windows VSS Shadow Copies

### Problem - `P0`

Windows VSS snapshots are not ordinary folders. VSS coordinates applications, writers, providers, diff areas, and tools like DiskShadow/VssAdmin.

### Failure Modes

- app tries to delete `System Volume Information` contents directly;
- app treats VSS diff area as a cleanup candidate;
- app promises free space from deleting live files while shadow copies still retain old blocks;
- remote/server mode damages backup policy;
- user lacks privilege and gets confusing access denied errors.

### Required Mitigation

- Classify VSS storage as `system_managed_snapshot_storage`.
- Never delete VSS files directly.
- Any future VSS management must go through official OS/admin tools and require elevated/admin mode.
- Local desktop MVP should report VSS as a factor, not manage it.
- Remote/server mode defaults to read-only reporting for VSS.
- Receipts and scan summary mention VSS uncertainty when volume has shadow storage.

### Admin Mode Guardrail

If later we expose VSS controls:

- require explicit admin mode;
- show backup/restore risk;
- use supported commands/APIs;
- log audit event;
- never include in one-click cleanup;
- never hide behind "cache" wording.

## ReFS Block Cloning

### Problem - `P1`

ReFS block cloning allows multiple file regions to share physical clusters. It is common in virtualization and backup workloads.

### Failure Modes

- `.vhdx` checkpoint/backup folders look larger than physical allocation;
- deleting one cloned backup file frees less than logical size;
- app mislabels ReFS clones as duplicates that waste full size;
- VM backup repositories get dangerous cleanup suggestions.

### Required Mitigation

- ReFS volumes get clone/shared-extent uncertainty flags.
- VM backup repository folders get high-risk classification.
- `estimated reclaim` is conservative for ReFS block-cloned files.
- Do not perform file-level duplicate cleanup on ReFS backup repositories without explicit advanced mode.

## NTFS Compression, Sparse Files, And Alternate Streams

### Problem - `P1`

NTFS has compressed files, sparse files, alternate data streams, and per-stream allocation. A file's default stream size may not capture all storage.

### Failure Modes

- sparse VM disk appears huge but uses little physical space;
- compressed folder logical size is bigger than size on disk;
- alternate data streams consume storage but table shows file size as 0;
- deleting or copying loses streams or changes size;
- sparse file quotas differ from allocated local bytes.

### Required Mitigation

- Windows adapter distinguishes logical size from allocated size.
- Use platform APIs like `GetCompressedFileSizeW` where appropriate.
- Stream enumeration is a separate capability.
- Details panel should show `alternate streams present` only when detected.
- MVP can mark ADS accounting as unsupported if not implemented, but must not claim exact totals.
- Sparse/VM disk cleanup should use allocated size and risk labels.

### UI Labels

```text
App-visible size: 120 GB
Size on disk: 14 GB
Estimated reclaim: up to 14 GB
Warnings: sparse virtual disk
```

## Windows Data Deduplication

### Problem - `P0`

Windows Data Deduplication stores chunks in a volume chunk store and replaces optimized files with reparse points. Microsoft warns not to manually modify the chunk store unless instructed by support.

### Failure Modes

- app scans `System Volume Information\Dedup\ChunkStore` and offers it as large cleanup;
- app deletes an optimized file and expects immediate chunk-store free space;
- app labels deduplicated files as duplicates wasting full size;
- chunk garbage collection runs later, so actual free-space delta is delayed;
- remote server cleanup damages dedupe policy.

### Required Mitigation

- Classify dedupe chunk store as system-managed.
- Never delete dedupe chunk store directly.
- Detect dedupe reparse points where practical.
- Reclaim estimate is low/medium confidence unless dedupe state is known.
- Receipt says chunks may be reclaimed later by dedupe garbage collection.
- Server mode needs read-only report for dedupe unless explicit admin integration exists.

## Btrfs Reflinks And Snapshots

### Problem - `P1`

Btrfs reflinks and snapshots share extents. Qgroups can account shared and exclusive usage, but precise accounting can have performance cost.

### Failure Modes

- folder tree double-counts reflinked copies;
- deleting one reflink frees less than logical size;
- btrfs qgroup information is unavailable or disabled;
- enabling qgroups for accuracy affects performance;
- snapshot-heavy systems have confusing `referenced` vs `exclusive` usage.

### Required Mitigation

- Detect Btrfs filesystem where practical.
- Do not enable qgroups automatically just for Clean Disk.
- If qgroup data exists, use it carefully and record source.
- Otherwise mark shared extent accounting as unsupported/low confidence.
- Snapshot directories/subvolumes should be classified distinctly from normal directories.
- Do not recommend deleting snapshots without explicit snapshot-management mode.

## ZFS Snapshots, Clones, Compression, And Datasets

### Problem - `P1`

ZFS has dataset-level accounting properties. `used`, `referenced`, `logicalused`, and `usedbysnapshots` mean different things.

### Failure Modes

- app treats ZFS dataset mount as normal folder tree only;
- deleting files from live dataset does not free space because snapshots retain blocks;
- deleting one snapshot changes used space of adjacent snapshots;
- compression makes logical and used diverge;
- clones depend on origin snapshots.

### Required Mitigation

- Detect ZFS mounts/datasets where practical.
- Prefer dataset-level `zfs` accounting when available in admin/server mode.
- Local desktop mode can mark ZFS reclaim as low-confidence if no dataset data is accessible.
- Do not manage snapshots/clones through generic file delete.
- Report `usedbysnapshots` only if retrieved from trusted ZFS adapter.

## FIEMAP And Shared Extent Detection On Linux

### Problem - `P2`

Linux can expose extents through FIEMAP, including shared extent flags where supported. But using this per file can be expensive.

### Required Mitigation

- Do not call FIEMAP for every file in default scan.
- Consider optional deep analysis for selected folder or suspicious large files.
- Cache per-node capability and result source.
- Only show "shared extent detected" when explicitly detected.
- Absence of FIEMAP result is not proof that extents are exclusive.

## Hardlinks Are Not Reflinks

### Problem - `P1`

Hardlinks share inode identity. Reflinks/clones share extents while remaining separate files/inodes. Dedupe shares chunks through a store/filter. Snapshots retain old blocks. These are different mechanisms.

### Required Mitigation

- Keep separate flags:

```text
hardlink_dedup_applied
shared_extent_possible
shared_extent_detected
snapshot_retention_possible
dedupe_store_possible
compressed_or_sparse
```

- Do not use hardlink count as proof of exclusive storage.
- Do not say "deduplicated" unless mechanism is known.
- Recommendation rules should explain which uncertainty applies.

## Quotas Can Differ From Local Free Space

### Problem - `P1`

Quota impact may not match local free-space impact:

- sparse files can charge nominal size to quota;
- network shares can have server quotas;
- ZFS/Btrfs datasets have dataset quotas;
- APFS container free space is shared;
- dedupe can change volume used without changing file logical sizes;
- cloud providers can use remote quota independent of local allocation.

### Required Mitigation

- Model `quota_effect` separately from `reclaim_estimate`.
- Only show quota impact when known.
- For remote/NAS/server shares, say `may affect server quota` instead of local reclaim.
- Do not rank cleanup candidates solely by remote logical size if local goal is free local disk.

## Trash, Snapshots, And Free Space

### Problem - `P1`

Moving to Trash usually does not free space until Trash is emptied. Even after emptying Trash, snapshots or open file handles can retain blocks.

### Required Mitigation

- Move-to-Trash receipt says `moved to Trash`, not `freed`.
- Cleanup summary distinguishes:
  - selected size;
  - moved to Trash;
  - observed free-space delta;
  - possible delayed reclaim.
- Empty Trash integration, if ever added, is a separate destructive action.
- After cleanup, volume free-space delta is measured and shown as observed, not guaranteed.

## Open Deleted Files

### Problem - `P1`

On POSIX-style systems, unlinking an open file removes a name but storage remains until file handles close. Logs, databases, VM disks, downloads, and build outputs can behave this way.

### Required Mitigation

- Receipt should say file was moved/deleted, not necessarily freed.
- If platform can detect open deleted files, expose diagnostic hint.
- For active logs/databases/VM disks, prefer app-specific cleanup adapters.
- Do not retry deletion repeatedly because free-space did not change.

## Cloud And Provider Placeholders

### Problem - `P1`

Cloud files can have remote logical size and local allocated size. Evicting local content is different from deleting remote content.

### Required Mitigation

- Cloud placeholder docs remain the source of truth for sync-provider behavior.
- This accounting doc adds one rule: local reclaim is local allocation, not remote logical size.
- UI must distinguish:
  - `Remove local copy`;
  - `Delete everywhere`;
  - `Provider-managed cache`.

## Ranking Cleanup Candidates

### Problem - `P1`

Largest logical folders may not be the best cleanup candidates.

### Ranking Inputs

```text
allocated_size
reclaim_estimate
confidence
risk_tier
storage_feature_flags
tool_owner
snapshot_or_dedupe_uncertainty
last_modified
user_intent
```

### Required Behavior

- Default ranking uses reclaim estimate, not raw logical size, when available.
- If only logical size is known, rank but label confidence.
- System-managed snapshots/dedupe/chunk stores are excluded from cleanup candidates.
- VM disks and sparse bundles get special warnings.

## Receipts Must Be Honest

### Problem - `P0`

A cleanup receipt is a user trust artifact. It must not claim bytes freed unless measured.

### Required Receipt Fields

```text
selected_logical_bytes
selected_allocated_bytes
estimated_reclaim_bytes
estimate_confidence
observed_free_space_before
observed_free_space_after
observed_free_space_delta
uncertainty_factors
trash_or_delete_result
delayed_reclaim_hint
```

### Copy Rule

Use:

```text
Estimated reclaim
Observed free-space change
May be retained by snapshots/shared storage
```

Avoid:

```text
Freed
Saved
Recovered
```

unless the value is observed and scoped precisely.

## Rust Domain Model

### Suggested Types

```text
StorageUsage
  logical_bytes: ByteCount?
  allocated_bytes: ByteCount?
  exclusive_bytes: ByteCount?
  shared_bytes: ByteCount?
  reclaim_estimate: ReclaimEstimate
  accounting_policy: AccountingPolicy
  confidence: Confidence
  uncertainty: Vec<StorageUncertainty>

ReclaimEstimate
  bytes: ByteCount?
  confidence: Confidence
  basis: EstimateBasis

StorageUncertainty
  snapshot_retained
  shared_extent_possible
  hardlink_policy_applied
  dedupe_possible
  sparse_file
  compressed_file
  alternate_streams_unknown
  cloud_placeholder
  open_file_possible
  remote_quota_unknown
  system_managed_storage
```

### Rule

Do not encode this as loosely named nullable numbers. The type names must force callers to decide which number they are using.

## Adapter Capability Model

```text
VolumeAccountingCapabilities
  filesystem
  volume_kind
  can_report_logical_size
  can_report_allocated_size
  can_report_exclusive_size
  can_detect_hardlinks
  can_detect_shared_extents
  can_detect_snapshots
  can_report_snapshot_usage
  can_detect_dedupe
  can_detect_sparse
  can_detect_compression
  can_enumerate_alternate_streams
  can_report_quota
```

Capability source:

```text
native_api
filesystem_tool
heuristic
configured
unknown
```

UI should reflect capability limitations in details/support bundles, not as noisy alerts for every row.

## Protocol DTOs

Node DTO should not only include `sizeBytes`.

Suggested projection:

```json
{
  "logicalBytes": "41570752512",
  "allocatedBytes": "38700000000",
  "reclaimEstimateBytes": "28000000000",
  "reclaimConfidence": "medium",
  "accountingPolicy": "allocated_with_uncertainty",
  "uncertainty": ["snapshot_retained", "shared_extent_possible"]
}
```

All byte counts are strings for web precision.

## UI States

### Details Panel

Show:

```text
Size on Disk
App-visible Size
Estimated Reclaim
Confidence
Why estimate may differ
```

### Candidate Badges

```text
Snapshot retained
Shared storage
Sparse file
Compressed
Dedupe
System-managed
Cloud placeholder
Low confidence
```

### Post-Cleanup Summary

```text
Moved to Trash: 38.7 GB selected
Observed free-space change: 12.4 GB
Some space may remain referenced by snapshots, clones, or open files.
```

## Clean Architecture Placement

### Domain

Allowed:

- `StorageUsage`;
- `ReclaimEstimate`;
- `Confidence`;
- `StorageUncertainty`;
- risk labels.

Forbidden:

- APFS APIs;
- VSS APIs;
- FIEMAP calls;
- `zfs`/`btrfs` command execution;
- Windows API calls.

### Application

Allowed:

- ports for volume accounting;
- use cases that request usage estimates;
- cleanup planning rules based on confidence and uncertainty.

### Infrastructure

Allowed:

- platform filesystem adapters;
- pdu mapping;
- optional OS command adapters;
- capability detection;
- observed free-space delta measurement.

### Presentation

Allowed:

- labels, warnings, confidence badges;
- post-cleanup observed delta display;
- user education in details panel.

## Testing Requirements

### Fixtures

Need platform fixtures where possible:

- normal file;
- hardlinked file;
- sparse file;
- compressed file;
- APFS clone if macOS runner supports it;
- APFS snapshot scenario, manual/integration;
- Time Machine local snapshot, manual/integration;
- NTFS sparse and compressed file;
- NTFS alternate data stream;
- ReFS block clone, optional Windows Server fixture;
- Btrfs reflink;
- Btrfs snapshot;
- ZFS dataset/snapshot, optional;
- dedupe-enabled NTFS volume, optional Windows Server fixture;
- open deleted file on POSIX.

### Unit Tests

- logical vs allocated values do not get mixed.
- low-confidence estimate cannot be displayed as exact reclaim.
- system-managed snapshot storage is blocked from delete plan.
- dedupe chunk store is blocked from delete plan.
- hardlink dedupe flag does not suppress shared extent warning.
- receipt includes observed free-space delta separately.

### Integration Tests

- deleting file retained by snapshot reports delayed reclaim.
- sparse file details show logical larger than allocated.
- compressed file details show allocated less than logical.
- moving to Trash does not claim freed bytes.
- stale volume free-space measurement does not override receipt result.

## MVP Cut Line

Must have:

- model separates logical, allocated, reclaim estimate, and confidence;
- UI labels estimated reclaim;
- post-cleanup observed free-space delta;
- snapshots/VSS/dedupe chunk stores blocked as system-managed;
- sparse/compressed/hardlink uncertainty flags where available;
- tests that prevent "freed X GB" wording without observed evidence.

Should have:

- macOS APFS/Time Machine snapshot detection;
- Windows VSS/dedupe detection;
- NTFS sparse/compressed allocated-size support;
- support bundle includes volume accounting capabilities;
- details panel explains low-confidence estimates.

Can wait:

- FIEMAP deep shared extent analysis;
- Btrfs qgroup integration;
- ZFS dataset adapter;
- ReFS block clone exact accounting;
- dedupe GC integration;
- admin snapshot management UI.

## Open Questions

- How much APFS clone/shared extent detection is feasible from Rust without private APIs?
- Should Clean Disk ever manage Time Machine snapshots, or only explain/report?
- Should Windows VSS management exist only in server/admin builds?
- Do we want optional deep extent analysis for selected folders, with clear time cost?
- What is the default table sort when allocated size is unknown but logical size is known?
- How do we reconcile free-space deltas when multiple cleanup operations run concurrently?

## Summary

📌 Modern filesystems make "folder size" a projection, not a fact. Clean Disk must separate logical size, local allocation, exclusive reclaim, quota effect, and observed free-space delta. Snapshots, clones, reflinks, dedupe, sparse files, compression, open files, and cloud placeholders should lower confidence instead of creating fake precision.
