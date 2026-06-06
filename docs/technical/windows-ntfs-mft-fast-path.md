# Windows NTFS MFT Fast Path

Last updated: 2026-05-16.

This document records the future idea of adding a Windows NTFS fast scanner backend based on the Master File Table.

The idea is not part of MVP. It is a future high-impact backend that can make Clean Disk world-class on Windows while keeping `parallel-disk-usage` as the general scanner backend.

## Decision Status

Accepted as a future adapter idea, not an implementation commitment for MVP.

Top 3 options:

1. NTFS fast path adapter plus fallback to pdu - 🎯 8 🛡️ 9 🧠 8, roughly 3000-7000 LOC.

   Best long-term option. Use a Windows-only `fs_usage_ntfs_mft` backend for local NTFS volumes when capability checks pass. Use pdu/general traversal everywhere else.

2. USN enumeration first, metadata enrichment second - 🎯 6 🛡️ 7 🧠 7, roughly 2000-5000 LOC.

   Microsoft exposes `FSCTL_ENUM_USN_DATA` through `DeviceIoControl` to enumerate MFT records on NTFS volumes. This may be a pragmatic first spike, but it may not provide every disk-usage field we need without extra metadata reads.

3. Raw NTFS parser backend - 🎯 7 🛡️ 8 🧠 9, roughly 5000-12000 LOC.

   Potentially fastest and closest to WizTree-style behavior, but it is much more complex. It requires volume access, NTFS record parsing, parent reconstruction, allocated-size correctness, reparse handling, and strong safety tests.

## Sources Reviewed

- Microsoft Learn, [FSCTL_ENUM_USN_DATA](https://learn.microsoft.com/pl-pl/windows/win32/api/winioctl/ni-winioctl-fsctl_enum_usn_data). It enumerates USN data between boundaries to obtain MFT records, and requires opening a volume such as `\\.\X:`. The volume must be NTFS.
- `ntfs` Rust crate, [docs.rs](https://docs.rs/ntfs/latest/ntfs/). It is a low-level NTFS filesystem library targeting NTFS 3.x through current Windows 11, exposing file records, directory indexes, attributes, allocated size, hardlink count, and file reference concepts.
- WizTree, [official site](https://diskanalyzer.com/) and [download page](https://wiztree.app/). WizTree states that it scans NTFS drives in seconds by reading the Master File Table directly and falls back to slower scanning when MFT access is unavailable.

## Why This Matters

pdu is fast for general filesystem traversal, but Windows NTFS has a special advantage: the filesystem already stores file records in the MFT.

A normal recursive scanner does:

```text
read directory
  -> stat child
  -> read child directory
  -> repeat
```

An MFT fast path can do:

```text
read volume file records
  -> reconstruct parent/child tree by file reference
  -> aggregate sizes
```

That is why tools like WizTree can scan large NTFS volumes in seconds.

## Architecture Shape

The adapter must fit the same scanner port:

```text
fs_usage_engine::ScannerBackend
  -> fs_usage_pdu for general scan
  -> fs_usage_ntfs_mft for Windows NTFS fast path
  -> same fs_usage read model
  -> same Clean Disk protocol
  -> same Flutter UI
```

The UI should not know which backend produced the result except through scan metadata and capability badges.

## Backend Selection

Backend selection should be capability-based:

```text
if platform == Windows
and volume filesystem == NTFS
and target is local volume or path on local NTFS volume
and required permissions are available
and user/resource profile allows fast path
then use fs_usage_ntfs_mft
else use fs_usage_pdu
```

Backend selection must be recorded in scan metadata:

```text
scanner_backend
backend_version
filesystem_type
volume_id
authority_mode
fallback_reason
```

## Required Product Semantics

The MFT backend must still produce our product concepts:

```text
NodeId
parent id
full path
logical size
allocated size
file reference / sequence number
file attributes
timestamps
hardlink count
reparse point state
cloud placeholder state where available
scan quality
issue groups
reclaim estimate
```

It must not expose raw MFT records to Flutter or domain models.

## Hard Parts

### Permissions And Elevation

Fast direct MFT access commonly requires opening the volume and may require Administrator rights. The app must not start elevated by default.

Required:

- capability probe explains whether MFT fast path is available;
- standard user fallback uses pdu/general traversal;
- admin/elevated mode is explicit and read-only first;
- scanner identity and elevation state are recorded.

### NTFS Only

MFT fast path is only for NTFS local volumes.

Fallback required for:

```text
exFAT
FAT32
ReFS unless explicitly supported later
network shares
SMB
WSL paths
cloud virtual roots
FUSE-like providers
```

### Path Reconstruction

MFT records give identity and parent references, not the same shape as recursive paths.

Required:

- reconstruct full paths from parent references;
- handle multiple names/hardlinks;
- handle deleted or stale records;
- handle parent missing or inaccessible;
- avoid cycles or corrupt records.

### Size Correctness

We need more than one size:

```text
logical size
allocated size
compressed size
sparse behavior
alternate data streams
dedupe/ReFS later if supported
exclusive reclaim estimate
```

MFT record size is not automatically a safe cleanup reclaim estimate.

### Reparse Points And Cloud Files

NTFS reparse points include junctions, symlinks, mount points, OneDrive placeholders, and other providers.

Required:

- classify reparse tags;
- do not recurse blindly through junctions;
- do not hydrate cloud placeholders;
- distinguish remove local download from delete from sync root;
- fallback to provider/platform metadata where MFT is insufficient.

### Live Changes

The filesystem can change while MFT records are being read.

Required:

- scan session records consistency assumptions;
- operation receipts record backend and timestamp;
- delete preflight revalidates by platform identity and path;
- stale scan data never authorizes cleanup.

## MVP Impact

MFT fast path is not needed for MVP.

MVP should still use:

```text
fs_usage_pdu
metadata enrichment
read model indexes
permission issues
DeletePlan preflight
Trash adapter
```

But MVP architecture should keep the scanner backend swappable.

## First Spike Later

Top 3 spike tasks:

1. Windows capability probe for NTFS fast path - 🎯 8 🛡️ 9 🧠 7, roughly 500-1200 LOC.

   Detect filesystem type, target volume, admin/elevation availability, and fallback reason without doing a full scan.

2. USN/MFT enumeration prototype - 🎯 7 🛡️ 8 🧠 8, roughly 1000-2500 LOC.

   Build a read-only tree of file reference, parent reference, name, attributes, and basic sizes for one NTFS volume.

3. pdu versus MFT benchmark harness on Windows - 🎯 8 🛡️ 9 🧠 6, roughly 700-1600 LOC.

   Measure pdu traversal, MFT fast path, memory, correctness differences, permission behavior, and fallback behavior on the same volumes.

## Summary

```text
pdu is the correct MVP scanner adapter.
NTFS MFT fast path is the future Windows acceleration adapter.
The product contract stays the same.
Only the backend changes.
```
