# Reclaim Accounting Deep Research

Last updated: 2026-05-16.

This document records the deeper research and implementation model for estimating how much disk space a cleanup action can actually reclaim.

The short version: there is no single cross-platform "bytes freed by deleting this folder" API. Clean Disk must model reclaim as an estimate with evidence, confidence, and after-the-fact observed free-space delta.

## Sources Reviewed

- Apple Developer, [About Apple File System](https://developer.apple.com/documentation/foundation/about-apple-file-system). APFS supports clones, snapshots, space sharing, fast directory sizing, and sparse files.
- Apple Developer archive, [APFS Guide introduction](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/Introduction/Introduction.html). APFS is copy-on-write and supports space sharing, cloning, snapshots, and sparse files.
- Apple Developer archive, [APFS volume format comparison](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/VolumeFormatComparison/VolumeFormatComparison.html). APFS feature list includes file and directory clones, snapshots, space sharing, sparse files, and fast directory sizing.
- Apple Developer archive, [APFS tools and APIs](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/ToolsandAPIs/ToolsandAPIs.html). Public APIs include FileManager copy/replace behavior, libcopyfile `COPYFILE_CLONE`, and clonefile APIs.
- Apple Developer, [URLResourceValues file values](https://developer.apple.com/documentation/foundation/urlresourcevalues/ispurgeable?changes=l__8). Relevant public values include file size, file allocated size, total allocated size, sparse status, purgeable status, resource identifier, and `mayShareFileContent`.
- Apple Developer archive, [`getattrlist(2)`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/getattrlist.2.html). Relevant attributes include logical total size, allocated size, data allocated size, resource fork allocated size, hardlink count, volume capabilities, and sparse-file capability.
- Apple Support, [About Time Machine local snapshots](https://support.apple.com/en-us/102154). Time Machine stores local snapshots, macOS counts snapshot space as available storage, and deletes snapshots as they age or as space is needed.
- Microsoft Learn, [GetCompressedFileSize](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getcompressedfilesizea). Reports actual bytes used for compressed or sparse files where supported, and follows symbolic links.
- Microsoft Learn, [FILE_STANDARD_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_standard_info). Includes allocation size, end of file, hardlink count, delete-pending flag, and directory flag.
- Microsoft Learn, [File attribute constants](https://learn.microsoft.com/en-us/windows/win32/fileio/file-attribute-constants). Includes sparse, compressed, offline, recall-on-open, and recall-on-data-access attributes.
- Microsoft Learn, [Sparse files](https://learn.microsoft.com/en-us/windows/win32/fileio/sparse-files). Sparse files allocate only meaningful ranges, not every logical byte.
- Microsoft Learn, [Block cloning on ReFS](https://learn.microsoft.com/en-us/windows-server/storage/refs/block-cloning). ReFS block cloning lets file regions share physical clusters with reference counts and allocate-on-write.
- Microsoft Learn, [Volume Shadow Copy Service](https://learn.microsoft.com/en-us/windows-server/storage/file-server/volume-shadow-copy-service). VSS can use complete copy, copy-on-write, or redirect-on-write, and stores changed blocks in a diff area.
- Microsoft Learn, [About Data Deduplication](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/dedup/about-data-deduplication). Optimized files become reparse points and deleted chunks are reclaimed later by garbage collection.
- Microsoft Learn, [Understanding Data Deduplication](https://learn.microsoft.com/en-us/windows-server/storage/data-deduplication/understand). Dedup uses background jobs, a chunk store, and a filesystem filter. Microsoft warns not to manually modify the chunk store.
- Microsoft Learn, [Cloud Files conversion flags](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/ne-cfapi-cf_convert_flags). Cloud placeholders can be dehydrated to free local content, but this is provider and state dependent.
- Apple Developer, [File Provider synchronization](https://developer.apple.com/documentation/FileProvider/synchronizing-the-file-provider-extension). File Provider items can be dataless or materialized; dataless items store metadata without local content.
- Apple Developer, [File Provider eviction](https://developer.apple.com/documentation/fileprovider/nsfileprovidermanager/3191974-evictitem?changes=__6). Eviction removes local content for synced items and can fail for unsynced, nonevictable, busy, or hardlinked items.
- Linux man-pages, [`stat(2)`](https://man7.org/linux/man-pages/man2/stat.2.html). `st_size` is file length; `st_blocks` and `st_blksize` are less portable and can differ across systems or NFS.
- Linux man-pages, [`unlink(2)`](https://man7.org/linux/man-pages/man2/unlink.2.html). If the last link is removed but a process still has the file open, storage remains until the final descriptor closes.
- Linux kernel docs, [FIEMAP ioctl](https://docs.kernel.org/filesystems/fiemap.html). FIEMAP exposes extent mappings and can mark extents as shared, but support and cost are filesystem dependent.
- Btrfs docs, [Reflink](https://btrfs.readthedocs.io/en/stable/Reflink.html). Reflinks share data blocks while files remain independent.
- Btrfs docs, [Qgroups](https://btrfs.readthedocs.io/en/latest/Qgroups.html). Qgroups track referenced and exclusive usage; exclusive is the amount freed when a subvolume is deleted, but snapshot accounting is complex.
- OpenZFS docs, [zfsprops](https://openzfs.github.io/openzfs-docs/man/master/7/zfsprops.7.html). ZFS distinguishes available, used, referenced, logicalused, usedbysnapshots, usedbydataset, clones, and reservations.
- docs.rs, [parallel-disk-usage 0.23.0](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/). pdu exposes a fast tree builder and hardlink module, but its public surface is not a full reclaim-accounting model.

## Research Conclusion

The hard part is not "folder size". The hard part is "exclusive local allocation that will become available after this exact cleanup action".

Top 3 implementation decisions:

1. Reclaim is a first-class domain value, not a renamed size field - 🎯 10 🛡️ 10 🧠 6, roughly 700-1800 LOC across Rust types, DTOs, tests, UI labels, and receipts.

   `size_bytes` is insufficient. The domain needs `logical_bytes`, `allocated_local_bytes`, `exclusive_reclaim_estimate`, `quota_effect`, `confidence`, `basis`, and `uncertainty`.

2. Default scan gives a fast estimate; deep accounting is opt-in per selected node or delete plan - 🎯 9 🛡️ 9 🧠 7, roughly 1200-3500 LOC across adapters, selected-node analysis, cache, and UI states.

   Running FIEMAP, Btrfs qgroup queries, ZFS commands, VSS discovery, cloud-provider checks, or APFS snapshot analysis for every file would damage scan speed. The table can be fast; the delete plan must be more careful.

3. Receipts report action outcome and observed delta separately - 🎯 10 🛡️ 10 🧠 5, roughly 400-1000 LOC across cleanup journal, protocol, and UI.

   A successful move-to-trash is not the same as freed space. A receipt must say "moved/deleted", "estimated reclaim", and "observed free-space change".

## Non-Negotiable Model

```text
logical_bytes:
  bytes visible to applications, usually file length or total displayable size

allocated_local_bytes:
  bytes currently allocated on the local volume, where the platform can report it

exclusive_reclaim_estimate:
  conservative bytes likely to become locally available after this cleanup action

quota_effect:
  possible impact on a quota, which can differ from local free-space reclaim

observed_free_space_delta:
  measured volume free-space change after an operation, scoped to a volume

confidence:
  exact | high | medium | low | unknown

basis:
  logical_only | allocated_size | allocated_with_hardlink_policy |
  platform_exclusive_accounting | observed_delta | unsupported

uncertainty:
  hardlink_external_reference_possible
  shared_extent_possible
  shared_extent_detected
  snapshot_retention_possible
  dedupe_store_possible
  sparse_file
  compressed_file
  cloud_placeholder
  file_provider_dataless
  open_file_possible
  trash_not_empty
  remote_quota_unknown
  network_filesystem_untrusted
```

Important: `exclusive_reclaim_estimate` is not always less than or equal to `logical_bytes`, and `allocated_local_bytes` is not always greater than or equal to `logical_bytes`. Small files can allocate more than their logical size. Sparse and compressed files can allocate less. Quotas can charge different numbers. Cloud storage can have remote logical bytes with near-zero local allocation.

## Confidence Semantics

### `exact`

Use only when the value is observed or when a platform gives an authoritative exclusive deletion simulation for that exact scope.

Good examples:

- observed free-space delta after cleanup;
- ZFS dry-run or dataset property for a dataset/snapshot operation, if sourced from trusted ZFS tooling;
- Btrfs qgroup exclusive value for a subvolume, if qgroups are already enabled and current.

Avoid `exact` for normal file/folder pre-delete estimates.

### `high`

Use when:

- local allocated size is known;
- no hardlink external references are known;
- filesystem capability model says no snapshots, reflinks/clones, or dedupe are active for that volume;
- operation is permanent delete or empty-trash equivalent, not just move-to-trash;
- no cloud/network placeholder state is involved.

This is still a prediction, not a receipt.

### `medium`

Use when allocated size is known but one uncertainty is possible and not proven:

- APFS volume with no detected sharing, but clone/snapshot feature exists;
- Windows NTFS compressed or sparse file where allocated size is known, but VSS or dedupe may retain blocks;
- Linux filesystem where `st_blocks` looks reasonable but reflink/snapshot capability is possible;
- move-to-trash where later empty-trash reclaim is likely but not immediate.

### `low`

Use when:

- shared extents are possible or detected but exclusive bytes are unknown;
- snapshots exist or may exist;
- dedupe/chunk stores are present;
- cloud placeholder/local-vs-remote semantics affect the action;
- network/FUSE filesystem makes allocation reporting unreliable;
- hardlinks point outside the selected scope or scan boundary is incomplete.

### `unknown`

Use when:

- allocated local size is unavailable;
- filesystem type or provider is unknown;
- scan lacks permission to read metadata needed for accounting;
- the target is a special file, device, pseudo filesystem, or unsupported virtual filesystem.

## Platform Feasibility Matrix

| Platform/filesystem | Logical size | Allocated local size | Shared/exclusive reclaim | Snapshot/dedupe effect | MVP stance |
| --- | --- | --- | --- | --- | --- |
| macOS APFS | yes, Foundation/POSIX | yes, Foundation/getattrlist/stat | can detect "may share" signals, but exact shared extent bytes are not a normal public fast path | Time Machine/APFS snapshots can retain blocks, macOS treats local snapshot space as available | medium confidence by default, low if snapshots/sharing detected |
| macOS HFS+/exFAT/external | yes | usually yes, depending on FS | no APFS clones, fewer modern features | less snapshot complexity unless APFS-backed image or Time Machine target | high/medium if local and non-network |
| Windows NTFS | yes, `EndOfFile` | yes, `AllocationSize` or `GetCompressedFileSize` for sparse/compressed | hardlinks detectable; alternate streams need separate enumeration; no generic exact dedupe/share proof | VSS and Data Dedup can retain or delay reclaim | medium by default, low with VSS/dedupe/reparse/cloud |
| Windows ReFS | yes | yes | block clones can share clusters; exact per-file exclusive reclaim is not a cheap generic app contract | VSS may apply; backup workloads common | low/medium, treat VM/backup repos conservatively |
| Linux ext4 | yes, stat | yes-ish, `st_blocks`, but portability caveats | no reflink in common ext4 path, but hardlinks and open files matter | snapshots usually outside ext4 itself, e.g. LVM | high/medium for local ext4 with no snapshot layer |
| Linux XFS | yes | yes-ish, `st_blocks` | reflink may be enabled; FIEMAP can be deep-analysis signal | snapshots usually external/LVM/storage layer | medium, low if reflink possible and no deep analysis |
| Linux Btrfs | yes | yes-ish | qgroups can give exclusive at subvolume level if already enabled; FIEMAP can indicate shared extents per file | snapshots/subvolumes are central | low by default, exact/high only with trusted qgroup scope |
| ZFS/OpenZFS | yes | dataset properties are better than file-only stat | dataset-level properties are strong; file-level generic reclaim is weaker | snapshots, clones, reservations, compression are core concepts | use dataset adapter when available, otherwise low/medium |
| Network/SMB/NFS/FUSE/rclone | provider-dependent | provider-dependent and often misleading | usually not provable from client | server snapshots/dedupe/quotas may exist | low/unknown, separate local cache from remote quota |
| Cloud File Provider / Cloud Files | remote logical yes, local allocation varies | local allocation yes when materialized | "free local copy" differs from "delete remote item" | provider can hydrate/dehydrate asynchronously | separate `evict local copy` from delete everywhere |

## macOS/APFS Details

APFS has the exact features that break naive estimates:

- clones can make a copy without new storage allocation;
- snapshots can keep old blocks after live files are deleted;
- volumes share container free space;
- sparse files can have logical size much larger than allocated size;
- purgeable storage may be counted differently from user-visible "free".

Public data we can use:

```text
URLResourceValues.fileSize
URLResourceValues.totalFileSize
URLResourceValues.fileAllocatedSize
URLResourceValues.totalFileAllocatedSize
URLResourceValues.isSparse
URLResourceValues.isPurgeable
URLResourceValues.mayShareFileContent
URLResourceValues.fileResourceIdentifier
getattrlist ATTR_FILE_TOTALSIZE
getattrlist ATTR_FILE_ALLOCSIZE
getattrlist ATTR_FILE_DATAALLOCSIZE
getattrlist ATTR_FILE_RSRCALLOCSIZE
getattrlist ATTR_FILE_LINKCOUNT
```

What this gives us:

- good logical and allocated values;
- useful APFS clone/sparse/purgeable signals;
- stable enough identity for revalidation;
- hardlink count.

What it does not reliably give us:

- exact exclusive bytes for one APFS clone;
- exact bytes retained by current local snapshots for a specific file;
- exact future reclaim after Time Machine retention decisions.

MVP rule:

```text
APFS normal file:
  estimate = allocated_local_bytes
  confidence = medium/high depending on sharing/snapshot signals

APFS mayShareFileContent:
  estimate = allocated_local_bytes as upper bound
  confidence = low
  uncertainty += shared_extent_possible

APFS snapshots detected or unknown:
  confidence = medium/low
  uncertainty += snapshot_retention_possible

APFS move to Trash:
  immediate_reclaim = 0
  eventual_reclaim_estimate = allocated_local_bytes with confidence lowered
```

## Windows Details

Windows has several independent mechanisms:

- NTFS compression;
- sparse files;
- hardlinks;
- alternate data streams;
- reparse points;
- Cloud Files placeholders;
- Data Deduplication;
- VSS shadow copies;
- ReFS block cloning.

Public data we can use:

```text
GetFileInformationByHandleEx(FileStandardInfo)
  AllocationSize
  EndOfFile
  NumberOfLinks
  DeletePending

GetCompressedFileSizeW
  actual bytes used for compressed/sparse files when supported

GetFileAttributesW / FileAttributeTagInfo
  sparse
  compressed
  offline
  reparse point
  recall-on-open
  recall-on-data-access
  pinned/unpinned cloud state where exposed

FindFirstStreamW / stream enumeration
  alternate data stream discovery when implemented

CfGetPlaceholderState / Cloud Files APIs
  placeholder hydration/dehydration state where applicable
```

Critical implications:

- `GetCompressedFileSizeW` follows symlinks, so identity/symlink policy must be explicit.
- `AllocationSize` and `GetCompressedFileSizeW` are not the same as exclusive reclaim on VSS/dedupe/ReFS block clone volumes.
- Dedup optimized files can be deleted while chunks remain until garbage collection.
- VSS diff areas are system-managed and not safe cleanup targets.
- ReFS block clones are similar in risk to APFS clones/reflinks: large logical files can share physical clusters.

MVP rule:

```text
NTFS regular local file:
  estimate = allocated_local_bytes
  confidence = high/medium

NTFS sparse/compressed:
  estimate = allocated_local_bytes
  confidence = medium
  uncertainty += sparse_file or compressed_file

Data Dedup volume or optimized reparse point:
  estimate = allocated_local_bytes as upper bound
  confidence = low
  uncertainty += dedupe_store_possible

VSS present:
  confidence lowered
  uncertainty += snapshot_retention_possible

Cloud Files placeholder:
  local reclaim = local allocated bytes only
  remote quota effect = separate
```

## Linux Details

On Linux, `stat` is a useful baseline but not enough for all filesystems.

Useful baseline:

```text
st_size:
  logical size

st_blocks * 512:
  allocated-ish size on many local filesystems

st_nlink:
  hardlink count

st_dev + st_ino:
  identity for hardlink grouping and revalidation
```

Limits:

- man-pages explicitly warn that `st_blocks`/`st_blksize` are less portable and can differ on NFS;
- `st_blocks` does not prove extents are exclusive;
- `unlink` does not free storage until the last file descriptor closes;
- reflinks can make multiple files share physical extents;
- snapshots may exist below or beside the filesystem layer.

Deep-analysis tools:

```text
FIEMAP:
  can expose extent mappings and FIEMAP_EXTENT_SHARED where supported

SEEK_DATA / SEEK_HOLE:
  can help inspect sparse regions, but does not prove exclusivity

Btrfs qgroups:
  can expose referenced and exclusive usage for subvolume scopes

ZFS properties:
  can expose dataset/snapshot/accounting facts better than file-only stat
```

MVP rule:

```text
local ext4-like volume:
  estimate = st_blocks * 512
  confidence = high/medium if no snapshot/reflink layer known

XFS/Btrfs/reflink-capable:
  estimate = allocated_local_bytes upper bound
  confidence = medium/low unless deep analysis proves exclusivity

Btrfs subvolume with qgroups already enabled:
  use qgroup exclusive for subvolume-level operations
  confidence = high/exact depending on freshness and scope

ZFS dataset:
  prefer zfs dataset adapter over recursive file stat
```

## Hardlink Accounting

Hardlinks are the one sharing mechanism we can handle well if we scan enough of the volume.

Rule for one inode:

```text
if link_count == 1:
  hardlink factor does not reduce estimate

if link_count > 1 and all links are selected and scan_scope_covers_volume:
  count allocated bytes once
  confidence can remain high/medium

if link_count > 1 and some links are outside selection:
  reclaim for that inode is 0 until the last external link is also removed
  confidence = high for "will not reclaim this inode now" if link_count evidence is trusted

if link_count > 1 and scan boundary is incomplete:
  estimate is low confidence
  uncertainty += hardlink_external_reference_possible
```

Do not split bytes by link count as a reclaim estimate. Deleting one of two hardlinks does not free half the bytes; it frees zero bytes until the final link is gone.

## Shared Extents, Reflinks, And Clones

Hardlinks and shared extents need separate accounting.

```text
hardlink:
  same inode / same file identity

APFS clone / Btrfs reflink / ReFS block clone:
  different file identities can share data extents

dedupe:
  chunks may be shared through filesystem or filter metadata

snapshot:
  old versions may retain blocks after live file deletion
```

Default scan must not pretend these are the same.

Deep shared-extent analysis should be optional:

1. User selects a suspicious large node.
2. Server runs a bounded deep accounting job.
3. Job samples or enumerates extents where supported.
4. Result updates details panel and delete-plan confidence.
5. Main tree stays responsive and does not block on this.

## Trash And Deletion Semantics

Move-to-trash is a safety action, not a free-space action.

```text
same-volume move to Trash:
  immediate local reclaim = 0
  eventual reclaim = possible after Trash is emptied

cross-volume move to Trash:
  can copy then delete, behavior is platform-specific and riskier

permanent delete:
  can free bytes, but snapshots/open handles/dedupe may delay actual free space

open POSIX file:
  unlink succeeds but storage remains until final descriptor closes
```

UI wording:

Good:

```text
Selected size
Potentially reclaimable after Trash is emptied
Observed free-space change
May be retained by snapshots/shared storage
```

Bad:

```text
Freed 38.7 GB
```

unless the number is observed and scoped.

## DeletePlan Accounting Algorithm

For MVP, the delete plan should calculate three numbers:

```text
selected_logical_bytes:
  sum of logical bytes for user comprehension

selected_allocated_local_bytes:
  sum of local allocation after hardlink policy where possible

eventual_reclaim_estimate:
  conservative estimate after the planned action fully completes
```

Pseudo-flow:

```text
for each selected node:
  revalidate identity
  detect volume and filesystem capabilities
  collect logical and allocated size
  apply hardlink accounting
  classify storage flags
  lower confidence for snapshots/shared/dedupe/cloud/network/open-file risk
  block system-managed storage
  produce node-level AccountingEvidence

aggregate:
  avoid double-counting nested selections
  avoid hardlink double-counting
  keep per-volume buckets
  compute immediate_effect and eventual_effect separately
  issue confirmation token bound to plan hash and accounting snapshot
```

Important aggregation rules:

- If a parent and child are both selected, count the child only once.
- If two selected paths reference the same hardlinked inode, count it once only if all external links are selected or proven absent.
- If two selected paths are APFS/Btrfs/ReFS clones, do not dedupe them unless shared extents are actually proven.
- If the target is moved to Trash, do not show immediate free-space reclaim.
- If a cloud placeholder is selected, local reclaim and remote delete impact are separate values.

## Domain Types

```text
StorageUsage
  logical_bytes: ByteCount?
  allocated_local_bytes: ByteCount?
  exclusive_reclaim_estimate: ReclaimEstimate
  quota_effect: QuotaEffect
  purgeable_bytes: ByteCount?
  observed_delta: ObservedFreeSpaceDelta?
  evidence: Vec<AccountingEvidence>
  uncertainty: Vec<StorageUncertainty>

ReclaimEstimate
  bytes: ByteCount?
  confidence: Confidence
  basis: EstimateBasis
  scope: ReclaimScope

EstimateBasis
  logical_only
  allocated_size
  allocated_with_hardlink_policy
  platform_exclusive_accounting
  observed_delta
  unsupported

ReclaimScope
  immediate_after_move_to_trash
  eventual_after_empty_trash
  immediate_after_permanent_delete
  remote_quota_effect
  unknown

AccountingEvidence
  source: native_api | filesystem_tool | scanner | observed_measurement | heuristic
  capability: string
  collected_at: timestamp
  confidence: Confidence
```

## Rust Crate Placement

```text
fs_usage_core
  domain/storage_usage.rs
  domain/reclaim_estimate.rs
  domain/accounting_evidence.rs
  domain/storage_uncertainty.rs

fs_usage_engine
  application/ports/accounting_port.rs
  application/use_cases/build_delete_plan.rs
  application/use_cases/estimate_reclaim.rs

fs_usage_accounting
  infrastructure/accounting_service.rs
  infrastructure/hardlink/hardlink_accounting.rs
  infrastructure/aggregation/delete_plan_accounting.rs
  infrastructure/confidence/confidence_rules.rs

fs_usage_platform
  infrastructure/macos/apfs_accounting.rs
  infrastructure/macos/foundation_metadata.rs
  infrastructure/windows/ntfs_accounting.rs
  infrastructure/windows/cloud_files_state.rs
  infrastructure/linux/stat_accounting.rs
  infrastructure/linux/fiemap_accounting.rs
  infrastructure/linux/btrfs_accounting.rs
  infrastructure/linux/zfs_accounting.rs
```

`pdu` remains scanner input. It can provide fast tree size and hardlink-aware options, but reclaim confidence belongs in our accounting layer.

## What pdu Can Give Directly

Useful:

- fast recursive tree;
- size quantity modes;
- hardlink-related module and options;
- JSON/library data tree;
- good baseline for top folders and quick UI.

Not enough:

- exact APFS clone shared extent accounting;
- Time Machine snapshot retention;
- VSS retention;
- Windows Data Dedup chunk-store lifecycle;
- ReFS block clone exclusivity;
- cloud placeholder local-vs-remote intent;
- open deleted file diagnosis;
- delete-plan receipts.

Therefore:

```text
pdu result -> fast read model
platform metadata -> allocated and identity enrichment
accounting adapter -> reclaim estimate and confidence
cleanup journal -> observed delta and receipt
```

## MVP Cut Line

Must implement before real cleanup:

- separate logical, allocated, reclaim estimate, quota effect, observed delta;
- confidence and uncertainty in domain and DTOs;
- hardlink-safe accounting for selected delete plans;
- no "freed X GB" wording before observed delta;
- move-to-trash shows immediate reclaim as zero;
- system-managed snapshot/dedupe/chunk stores blocked from generic cleanup;
- low-confidence labels for APFS clone/snapshot, ReFS/Btrfs reflink, VSS, dedupe, sparse/compressed, cloud placeholder, network share;
- per-volume before/after free-space measurement in receipts.

Should implement early:

- macOS allocated size via Foundation/getattrlist;
- macOS APFS `mayShareFileContent`, `isSparse`, `isPurgeable`;
- Windows `FILE_STANDARD_INFO`, `GetCompressedFileSizeW`, sparse/compressed/reparse attributes;
- Linux `st_blocks * 512` with filesystem/provider caveats;
- volume capability model;
- manual/integration fixture lab for sparse, hardlink, compressed, APFS clone, and open deleted files.

Can wait:

- exact APFS clone extent accounting;
- FIEMAP deep analysis for every file;
- Btrfs qgroup UI;
- ZFS admin dataset mode;
- VSS management;
- dedupe garbage-collection integration;
- ReFS exact clone accounting.

## First Spike Before Implementation

Build a tiny Rust proof of concept separate from product code:

```text
inputs:
  one root path
  one selected path for deep accounting

outputs:
  logical_bytes
  allocated_local_bytes
  hardlink facts
  storage flags
  estimate
  confidence
  uncertainty
  source/evidence list
```

Test matrix:

```text
macOS:
  normal file
  sparse file
  APFS clone
  hardlink
  file in Trash
  Time Machine snapshot present if safe

Windows:
  normal file
  sparse file
  compressed file
  hardlink
  reparse/cloud placeholder if available

Linux:
  normal file
  sparse file
  hardlink
  open deleted file
  Btrfs reflink if available
  FIEMAP shared flag if supported
```

Acceptance criteria:

- API never collapses logical and allocated into one ambiguous field.
- APFS clone does not report exact reclaim unless proven.
- Hardlink delete plan does not divide size by link count.
- Trash action does not claim immediate free-space.
- Open deleted POSIX file produces observed delta smaller than selected allocation.
- All byte counts cross protocol as strings.

## Final Decision

Clean Disk should not try to be "exact" during the fast scan. It should be honest and layered:

```text
fast scan:
  show structure, logical/allocated where cheap, and broad confidence

selected node:
  enrich with platform metadata and warnings

delete plan:
  revalidate identity and run conservative accounting

cleanup receipt:
  record action result and observed free-space delta
```

This keeps performance high while avoiding the dangerous promise that deleting a folder always frees its displayed size.
