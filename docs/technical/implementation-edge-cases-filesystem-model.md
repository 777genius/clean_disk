# Implementation Edge Cases Filesystem Model

Last updated: 2026-05-12.

This document focuses on low-level filesystem facts that affect Clean Disk's data model, Rust platform adapters, scan indexes, reclaim estimates, and delete validation.

Read this after:

- [Implementation Edge Cases](implementation-edge-cases.md)
- [Implementation Edge Cases Deep Dive](implementation-edge-cases-deep-dive.md)
- [Implementation Edge Cases Advanced Scenarios](implementation-edge-cases-advanced-scenarios.md)

## Additional Sources Reviewed

- POSIX `stat` and `statvfs` structures - <https://pubs.opengroup.org/onlinepubs/007904875/basedefs/sys/stat.h.html> and <https://pubs.opengroup.org/onlinepubs/007904975/basedefs/sys/statvfs.h.html>
- Linux `stat(2)` and `statvfs(3)` man pages - <https://man7.org/linux/man-pages/man2/stat.2.html> and <https://man7.org/linux/man-pages/man3/statvfs.3.html>
- GNU Gnulib `stat` size notes - <https://www.gnu.org/software/gnulib/manual/html_node/stat_002dsize.html>
- Apple `URLResourceValues` and file resource identifiers - <https://developer.apple.com/documentation/foundation/urlresourcevalues> and <https://developer.apple.com/documentation/foundation/nsurlfileresourceidentifierkey>
- Microsoft `GetCompressedFileSize`, `FILE_STANDARD_INFO`, and `GetDiskFreeSpaceEx` - <https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getcompressedfilesizea>, <https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_standard_info>, <https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getdiskfreespaceexa>
- POSIX `unlink` semantics - <https://pubs.opengroup.org/onlinepubs/000095399/functions/unlink.html>
- GNU C Library deletion notes - <https://www.gnu.org/software/libc/manual/html_node/Deleting-Files.html>
- FreeDesktop Trash specification - <https://specifications.freedesktop.org/trash/latest/>
- Microsoft exFAT specification - <https://learn.microsoft.com/en-us/windows/win32/fileio/exfat-specification>
- Apple file and directory guidance - <https://developer.apple.com/documentation/technologyoverviews/files-and-directories>
- Red Hat disk quota documentation - <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/storage_administration_guide/ch-disk-quotas>

## Main Bias

Do not build the core model around a single `size: u64`.

The Rust model needs separate facts:

- `logical_size` - bytes in the file stream, often `st_size`, `fileSize`, or `EndOfFile`;
- `allocated_size` - bytes allocated on the local filesystem where available;
- `display_size` - user-facing recursive total for tree rows;
- `exclusive_reclaim_estimate` - conservative bytes likely to become available after cleanup;
- `shared_reclaim_uncertainty` - hardlinks, clones, snapshots, compression, dedupe, and cloud placeholders;
- `available_to_user` - bytes this user can allocate;
- `volume_free` - total free bytes on the volume, possibly larger than user quota;
- `inode_or_entry_pressure` - file count/inode limits can be exhausted before bytes are exhausted.

## Size And Allocation Model

### Rust `Metadata::len()` Is Logical Size Only - `P0`

Rust standard metadata gives a portable file length, but that is not "size on disk". Sparse files, compression, clone-on-write, hardlinks, alternate streams, resource forks, and snapshots all break naive accounting.

Implementation rule:

- `Metadata::len()` maps to `logical_size`, not `allocated_size`;
- platform adapters own allocated-size lookup;
- domain values must allow `allocated_size: unknown`;
- UI must label unknown allocated size instead of substituting logical size silently.

### POSIX `st_blocks` Is Useful But Not Universal Truth - `P0`

POSIX exposes `st_blocks` as allocated blocks, but POSIX does not require a universal block unit. Linux commonly reports 512-byte units. Some network, virtual, or special filesystems may report misleading values.

Implementation rule:

- POSIX adapter can use `st_blocks` for allocated estimate where platform semantics are known;
- record the accounting source: `posix_st_blocks`, `linux_st_blocks_512`, `unknown`;
- do not use `st_blksize` as the multiplier for `st_blocks`;
- if `st_blocks` looks unavailable or nonsensical, mark allocated size confidence low.

Tests:

- small file below filesystem block size;
- sparse file where logical size is huge but allocated size is small;
- compressed/CoW filesystem fixture where possible;
- network/mock filesystem returning unknown or unreliable allocated size.

### macOS Has Better Resource Keys, But Values Are Optional - `P0`

Apple `URLResourceValues` exposes `fileAllocatedSize`, `totalFileAllocatedSize`, `totalFileSize`, `isSparse`, `isPurgeable`, `mayShareFileContent`, `mayHaveExtendedAttributes`, and volume capacity fields. Documentation also states that not all values exist for all URLs.

Implementation rule:

- macOS adapter should prefer URL resource keys for details where practical;
- still handle nil/unavailable values;
- map `mayShareFileContent`, `isSparse`, and `isPurgeable` into reclaim confidence;
- keep xattr/resource-fork metadata as diagnostics, not default cleanup actions.

### Windows Has Multiple Size APIs With Different Semantics - `P0`

Microsoft `GetCompressedFileSize` returns actual disk storage for compressed/sparse files, but follows symbolic links to the target. `FILE_STANDARD_INFO` contains `AllocationSize`, `EndOfFile`, `NumberOfLinks`, and `DeletePending` for an opened handle.

Implementation rule:

- Windows adapter needs explicit "follow target" vs "inspect link object" behavior;
- prefer handle-based metadata where possible for identity-sensitive operations;
- map `EndOfFile` to logical size and `AllocationSize` or compressed size to allocated size according to adapter policy;
- expose `DeletePending` as a typed state;
- alternate data streams remain an explicit accounting caveat unless fully enumerated.

### Directory Sizes Are Aggregates, Not File Sizes - `P1`

Directory entries have their own metadata size, but users expect directory rows to show recursive child totals.

Implementation rule:

- `ScanNodeKind::Directory` has optional own metadata allocation and recursive totals separately;
- UI default displays recursive totals;
- details panel can show directory entry own size only as advanced metadata;
- sorting tree rows uses recursive display size unless user chooses another metric.

### Allocated Size Can Exceed Or Undercut Logical Size - `P1`

Small files allocate at least one block on many filesystems; sparse/compressed files can allocate less than logical size; dedupe/CoW files can share blocks; resident data may live in filesystem metadata.

Implementation rule:

- no invariant `allocated_size >= logical_size`;
- no invariant `allocated_size <= logical_size`;
- use `ByteSizeRelation` or confidence flags instead of brittle assertions;
- tests must include both directions.

## File Identity Model

### Identity Is Platform-Specific And Time-Bounded - `P0`

POSIX has `st_dev` + `st_ino`. Apple exposes file resource identifiers but notes resource identifiers are not persistent across restarts. Windows has volume serial/file IDs through handle APIs on supported filesystems. Network and removable filesystems can be weaker.

Implementation rule:

- `NodeIdentity` is a sum type by platform/source, not a single universal struct;
- identity includes `identity_confidence`;
- live cleanup validation can use stronger ephemeral IDs;
- persistent history cannot assume ephemeral IDs survive reboot/remount.

Suggested shape:

```text
NodeIdentity
  platform_kind
  identity_source
  volume_id?
  file_id?
  device_id?
  inode?
  link_kind
  case_policy?
  created_or_birth_time?
  modified_time?
  logical_size?
  allocated_size?
  confidence
```

### Paths Are UI Coordinates, Not Authority - `P0`

Paths are still needed for display, reveal, and current lookup, but cleanup authority comes from candidate id + session id + revalidated identity.

Implementation rule:

- protocol commands should send node/delete candidate ids;
- user-edited path strings are never delete authority;
- path normalization is display-only unless a platform adapter explicitly says otherwise;
- reveal/open actions can use current path but must handle missing/replaced path.

### Stable Pagination Requires Versioned Indexes - `P1`

If a scan is active while the UI queries pages, child lists can change between page 1 and page 2.

Implementation rule:

- tree query responses include `index_version` or `snapshot_id`;
- cursor/page token includes sort/filter/index version;
- if index version changes, client should resync or accept "live page" semantics;
- cleanup candidates from live pages are revalidated, never trusted blindly.

## Free Space, Quotas, And Capacity

### "Free Space" Has Several Meanings - `P0`

Windows `GetDiskFreeSpaceEx` exposes bytes available to caller separately from total free bytes. POSIX `statvfs` has blocks available to unprivileged users. Apple exposes important/opportunistic capacity. Quotas and reserved blocks make these differ.

Implementation rule:

- model `available_to_current_user`, `free_on_volume`, `reserved_or_unavailable`, and `capacity_confidence`;
- UI should emphasize "available to you";
- debug/details can show total free and reserved where known;
- cleanup success should not be proven only by volume free-space delta.

### Inodes And File Counts Can Be The Real Limit - `P1`

Unix quotas can limit both bytes and inodes/file count. A filesystem can fail new files with no inode capacity even when bytes are available.

Implementation rule:

- volume capability should include inode/file-entry data where available;
- scan summary tracks file count and directory count as first-class metrics;
- UI can warn "many small files" separately from "many bytes";
- performance benchmarks must include high-entry-count trees.

### External Drives Can Have Weak Metadata - `P1`

exFAT and FAT-like filesystems are common on external drives and may lack Unix permissions, symlinks, hardlinks, stable high-resolution timestamps, and advanced metadata.

Implementation rule:

- expose volume feature flags: supports_symlinks, supports_hardlinks, supports_permissions, supports_birthtime, supports_sparse, supports_case_sensitive_names;
- do not run hardlink or symlink policies as if unsupported features exist;
- timestamp-based stale checks become lower confidence on weak filesystems.

## Delete And Reclaim Semantics

### Unix Unlink Can Succeed While Space Is Not Freed - `P0`

POSIX `unlink` removes a name. If a process still has the file open, storage is not freed until all references close. This affects logs, databases, temp files, and active downloads.

Implementation rule:

- delete result separates `path_removed` from `bytes_reclaimed`;
- if platform can detect open deleted files, expose diagnostic hint;
- UI says "moved/deleted" instead of "freed" until volume metrics or adapter result confirms;
- active app-owned logs/databases should be warned before cleanup.

### Windows DeletePending And Sharing Violations Are Normal States - `P0`

Windows can report delete-pending state and commonly fails delete/move when handles are opened without delete sharing.

Implementation rule:

- map delete-pending and sharing violation into typed candidate results;
- offer retry/remove/reveal, not force;
- never loop indefinitely on locked files;
- queue validation should mark "may be in use" when detectable.

### Sticky Directories Change Delete Permission - `P1`

On Unix-like systems, deleting a file depends on parent directory permissions. A sticky directory can prevent deleting files the user does not own even when the directory is writable.

Implementation rule:

- cleanup validation checks parent directory write/execute/sticky behavior where practical;
- classify sticky-bit denial separately from file readonly;
- `/tmp`-style shared directories should not be treated as normal user-owned cleanup space.

### FreeDesktop Trash Has Per-Topdir Rules - `P1`

The FreeDesktop spec uses top-directory trash locations and sticky-bit requirements. Cross-device trash can be tricky or unsupported.

Implementation rule:

- Trash adapter must know selected file topdir and target trash location;
- moving to `$HOME/.local/share/Trash` is not always correct for external volumes;
- if compliant trash is unavailable, return unsupported instead of deleting;
- UI should explain when a volume has no usable Trash.

## Special File Kinds

### Device, FIFO, Socket, Procfs, Sysfs, And Pseudo-Files - `P0`

Special files can report strange sizes, block counts, or behavior. Reading them can block, trigger side effects, or return dynamic content.

Implementation rule:

- scanner must classify file type before size accounting;
- never read file contents for size;
- pseudo-filesystems are skipped or shown as virtual/system, not cleanup candidates;
- device/fifo/socket nodes are never Trash candidates in normal desktop mode.

### Archives Are Large But Not Trees Unless Explicitly Opened - `P1`

ZIP, tar, dmg, iso, sparsebundle, app bundles, photo libraries, and database containers can hide internal structure.

Implementation rule:

- MVP treats archive/container files as files unless a dedicated adapter exists;
- do not estimate internal cleanup without parsing and ownership rules;
- reveal details can show "container/archive" classification;
- future archive inspection must be read-only by default.

### Memory-Mapped And Preallocated Files - `P1`

Databases, VM disks, torrents, and download managers may preallocate or mmap files. Logical size and actual meaningful content diverge.

Implementation rule:

- classify common preallocated owners where possible;
- do not recommend deleting active preallocated files without owner/app warning;
- reclaim estimate should be based on allocated size, not logical promise;
- deletion may not free bytes immediately if open or snapshot-referenced.

## Protocol And DTO Consequences

### Avoid Boolean Size Flags - `P0`

Booleans like `is_sparse` and `is_shared` are not enough.

Recommended model:

1. Separate size facts + confidence enum + source enum - 🎯 10 🛡️ 10 🧠 6, roughly 300-900 LOC.
2. Simple `{ size, size_on_disk }` pair - 🎯 5 🛡️ 5 🧠 3, roughly 100-250 LOC.
3. Only one `size` field - 🎯 2 🛡️ 2 🧠 1, roughly 40-80 LOC.

Decision bias: choose 1.

### Error Codes Need Domain Meaning, Not OS Strings - `P0`

Raw OS errors differ by platform and language. UI and tests need stable reason codes.

Implementation rule:

- adapters preserve raw OS code in diagnostics;
- application exposes stable reason codes;
- protocol errors include stable code, severity, retryability, and optional redacted path;
- UI copy maps stable code to localized text.

### Details Can Be Lazy - `P1`

Rich metadata is expensive. Fetching full URL resource values, Windows handle info, xattrs, ACLs, and volume data for every node can slow scans.

Implementation rule:

- scan hot path collects minimal facts needed for tree and safety;
- details query can enrich selected node lazily;
- delete validation re-reads strong metadata just-in-time;
- cache expensive metadata with invalidation/versioning.

## Testing Additions

Add these platform-specific or mocked fixtures:

- POSIX sparse file with logical size much larger than allocated size;
- small file where allocated size is larger than logical size;
- macOS `URLResourceValues` returns nil for some keys;
- macOS `mayShareFileContent` or `isSparse` fixture/mocked adapter;
- Windows `GetCompressedFileSize` symlink behavior mocked;
- Windows `FILE_STANDARD_INFO` with `NumberOfLinks > 1`;
- Windows `DeletePending` state mocked;
- Unix open file unlinked before free-space check;
- sticky-bit directory delete denial;
- external exFAT-like volume with weak metadata;
- volume quota where available-to-user differs from volume-free;
- high inode/file-count pressure fixture;
- pseudo-filesystem entry with strange reported size;
- archive/container classification;
- live pagination with changed `index_version`;
- stable reason-code snapshot for every adapter error mapping.

## Guardrail Summary

📌 Filesystem model rule: Clean Disk should be precise about what it knows, how it knows it, and how confident it is.

Stable product distinctions:

- logical size is not allocated size;
- allocated size is not exclusive reclaim;
- path is not identity;
- current volume free is not user-available quota;
- unlink/delete success is not immediate byte reclaim;
- hot scan metadata is not full details metadata;
- OS error strings are not product contracts.

