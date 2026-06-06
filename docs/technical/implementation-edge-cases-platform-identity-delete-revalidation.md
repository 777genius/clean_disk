# Implementation Edge Cases - Platform Identity And Delete Revalidation

Last updated: 2026-05-16.

This document records the platform identity and delete revalidation research for Clean Disk.

This is the most safety-critical spike after scanner capability. The goal is to prevent a stale scan row, replaced path, symlink, junction, reparse point, permission mismatch, or Trash adapter quirk from deleting the wrong target.

## Sources Reviewed

- Apple Developer Documentation, [fileResourceIdentifierKey](https://developer.apple.com/documentation/foundation/urlresourcekey/fileresourceidentifierkey). Relevant point: this resource key identifies a file resource, but the value is not persistent across system restarts.
- Apple Developer Documentation, [generationIdentifierKey](https://developer.apple.com/documentation/foundation/urlresourcekey/generationidentifierkey). Relevant point: generation identifiers can help detect content generation changes, but metadata changes may not change the identifier.
- Apple Developer Documentation, [FileManager.trashItem(at:resultingItemURL:)](https://developer.apple.com/documentation/foundation/filemanager/trashitem%28at%3Aresultingitemurl%3A%29). Relevant point: macOS returns the actual Trash URL because the item name can change while trashing.
- Apple Developer Documentation, [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox). Relevant points: sandboxed access can be extended by user selection and security-scoped bookmarks, but POSIX, ACL, and mandatory controls can still produce access errors.
- Apple Developer Archive, [lstat(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/lstat.2.html). Relevant points: `lstat` reports metadata about the symbolic link itself and exposes `st_ino`, `st_dev`, `st_nlink`, file type, size, blocks, and flags.
- Microsoft Learn, [FILE_ID_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_id_info). Relevant point: `FileId` plus `VolumeSerialNumber` identifies a file on one computer when available through `GetFileInformationByHandleEx(FileIdInfo)`.
- Microsoft Learn, [BY_HANDLE_FILE_INFORMATION](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/ns-fileapi-by_handle_file_information). Relevant points: volume serial plus file index can identify a file, but file IDs are filesystem-specific, may be reused, and can change on FAT-like filesystems.
- Microsoft Learn, [FILE_STANDARD_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_standard_info). Relevant points: handle metadata includes allocation size, end of file, number of links, delete pending, and directory flag.
- Microsoft Learn, [CreateFileW symbolic link behavior](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew). Relevant point: `FILE_FLAG_OPEN_REPARSE_POINT` opens the symbolic link/reparse object itself instead of the target.
- Microsoft Learn, [DeleteFile](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-deletefilea). Relevant points: `DeleteFile` is permanent, read-only files fail, delete requires file delete or parent delete-child permission, open handles can block or defer deletion, and symlink deletion deletes the link.
- Microsoft Learn, [File Access Rights Constants](https://learn.microsoft.com/en-us/windows/win32/fileio/file-access-rights-constants). Relevant point: Windows has distinct rights such as `DELETE` and `FILE_DELETE_CHILD`; read/list permission is not delete capability.
- Microsoft Learn, [Reparse Points](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-points). Relevant points: reparse points back links, mounted folders, remote storage, and filter-managed behaviors; operations can differ from ordinary directories.
- Microsoft Learn, [IFileOperation::SetOperationFlags](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-setoperationflags). Relevant point: `FOFX_RECYCLEONDELETE` sends delete operations to the Recycle Bin instead of permanent delete.
- Microsoft Learn, [IFileOperationProgressSink::PostDeleteItem](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperationprogresssink-postdeleteitem). Relevant point: per-item result is reported after the actual deletion, and `psiNewlyCreated` can point to the Recycle Bin item or be null when fully deleted.
- Linux man-pages, [statx(2)](https://man7.org/linux/man-pages/man2/statx.2.html). Relevant points: `statx` can return inode, device, mount ID, link count, blocks, timestamps, attributes, and mount-root hints.
- Linux man-pages, [open(2)](https://man7.org/linux/man-pages/man2/open.2.html). Relevant points: `O_PATH | O_NOFOLLOW` can obtain a descriptor for a symlink itself and file descriptors remain references even if the path is later removed or modified.
- Linux man-pages, [openat2(2)](https://man7.org/linux/man-pages/man2/openat2.2.html). Relevant points: `RESOLVE_BENEATH`, `RESOLVE_IN_ROOT`, `RESOLVE_NO_MAGICLINKS`, `RESOLVE_NO_SYMLINKS`, and `RESOLVE_NO_XDEV` can restrict path resolution for trusted root operations.
- Linux man-pages, [unlink(2)](https://man7.org/linux/man-pages/man2/unlink.2.html). Relevant points: unlink removes a name, symlink unlink removes the link, storage is freed only after last link and open descriptor are gone, and sticky bit, immutable, append-only, read-only filesystem, mount point, and NFS states affect deletion.
- Linux man-pages, [rename(2)](https://man7.org/linux/man-pages/man2/rename.2.html). Relevant points: rename is atomic in important ways, open file descriptors and hard links are unaffected, and renaming a symlink renames the link.
- FreeDesktop.org, [Trash Specification](https://specifications.freedesktop.org/trash/latest/). Relevant points: Trash implementations must not use Trash filenames as original filenames, `.trashinfo` stores original path and deletion date, and failure to trash must not silently erase without confirmation.
- Rust crate docs, [trash](https://docs.rs/trash/latest/trash/). Relevant points: version `5.2.6` moves files to OS Trash/Recycle Bin, but Linux behavior assumes FreeDesktop-compatible environments and documents a mount-point query caveat guarded by a mutex.
- Rust crate docs, [file-id](https://docs.rs/file-id/latest/file_id/). Relevant points: version `0.2.3` reads cross-platform file IDs, but IDs can be reused.
- Rust crate docs, [same-file](https://docs.rs/same-file/latest/same_file/). Relevant point: version `1.0.6` gives a cross-platform equality check for two paths or handles, useful for tests and fallback comparisons, not enough as a cleanup authority.

## Top 3 Decisions

1. Evidence bundle plus confidence, not one universal file ID - 🎯 10 🛡️ 10 🧠 7, roughly 500-1200 LOC across core value objects, probes, protocol DTOs, and tests.
2. DeletePlan preflight revalidation immediately before Trash/delete - 🎯 10 🛡️ 10 🧠 8, roughly 900-2200 LOC across cleanup use cases, operation journal, adapters, receipts, and fixtures.
3. Platform-native Trash adapters behind a `TrashAdapter` port, with `trash` crate only after audit - 🎯 8 🛡️ 8 🧠 7, roughly 800-2500 LOC depending on how many native adapters we implement first.

Important conclusion: there is no cross-platform ID that safely authorizes cleanup by itself. The safe model is a short-lived identity evidence bundle, current re-probe, strict policy, typed uncertainty, and durable receipt.

## Required Domain Model

### `NodeIdentityEvidence`

Store scan-time identity evidence for every cleanup-eligible node.

```text
NodeIdentityEvidence
  platform
  identity_source
  identity_confidence
  observed_at
  path_raw
  path_display
  node_kind
  link_kind
  volume_evidence
  object_evidence
  parent_evidence
  metadata_fingerprint
  provider_evidence
  traversal_policy
```

Suggested platform-specific fields:

```text
macos
  st_dev
  st_ino
  st_nlink
  st_mode
  st_flags
  birthtime
  mtime
  ctime
  file_resource_identifier_ephemeral
  generation_identifier_optional
  volume_url_or_uuid_optional
  security_scoped_bookmark_state_optional

windows
  volume_serial_number
  file_id_128_optional
  file_index_64_fallback_optional
  file_attributes
  reparse_tag_optional
  number_of_links
  allocation_size
  end_of_file
  delete_pending
  creation_time
  last_write_time
  final_path_optional

linux
  stx_dev_major
  stx_dev_minor
  stx_ino
  stx_mnt_id_optional
  stx_nlink
  stx_mode
  stx_attributes
  stx_size
  stx_blocks
  stx_btime_optional
  stx_mtime
  stx_ctime
  mount_root_flag_optional
```

### Confidence Levels

```text
strong_live
  A current handle or descriptor was opened using a no-follow policy where needed, and identity facts match scan evidence.

strong_snapshot
  Scan-time identity facts were strong for that platform, but no current live handle is held anymore.

medium
  Path plus device/volume plus inode/file-id-like value plus metadata fingerprint match, but platform docs allow reuse/change.

weak
  Only path plus size/timestamps/kind match, or filesystem is known to have weak identity.

unknown
  Provider, permission, network, sandbox, or virtual filesystem prevented reliable identity.
```

Cleanup requires at least `medium` for normal user files and `strong_live` for high-risk objects such as directories, symlinks/reparse points, app-managed data, external volumes, network shares, or anything selected from stale search results.

## Platform Matrix

### macOS

Available identity facts:

- POSIX `lstat` gives `st_dev`, `st_ino`, `st_nlink`, type bits, size, blocks, timestamps, flags, and symlink-object metadata.
- Foundation `fileResourceIdentifierKey` is useful for comparing resources during a live session, but must be treated as ephemeral because Apple documents it as not persistent across system restarts.
- `generationIdentifierKey` can add evidence for content generation, but it is not a complete identity because metadata-only changes may not update it.
- Security-scoped bookmarks are permission/intent evidence, not object identity. A stale bookmark means permission state must be refreshed before destructive action.

Delete and Trash facts:

- Prefer `FileManager.trashItem(at:resultingItemURL:)` for macOS Trash semantics.
- Store `resultingItemURL` as receipt evidence. Do not assume the Trash filename equals the original name.
- Do not manually move into `~/.Trash`.
- TCC, Full Disk Access, App Sandbox, POSIX permissions, ACLs, SIP/protected locations, file provider storage, and provider-translocated app state can all produce denial or partial behavior.

Symlink and replacement policy:

- Use `lstat` for scan identity of link objects.
- Default cleanup moves the link object, not the target.
- If a path was selected as a directory but now `lstat` says symlink or different inode/device, block and require review.

Open questions for spike:

- Whether we can reliably call `FileManager.trashItem` from Rust through Objective-C bindings with detailed `NSError` mapping, or whether a small Swift/Objective-C helper layer is cleaner.
- Whether `NSURL` resource keys add enough value beyond `lstat` for the MVP identity probe.
- How sandboxed vs direct distribution changes the daemon process identity and security-scoped access.

### Windows

Available identity facts:

- Prefer opening a handle and calling `GetFileInformationByHandleEx(FileIdInfo)` for `FILE_ID_INFO`, which gives 128-bit `FileId` plus `VolumeSerialNumber`.
- Fallback to `BY_HANDLE_FILE_INFORMATION` for file index plus volume serial, but mark lower confidence because Microsoft documents filesystem-specific behavior, reuse, ReFS 64-bit caveat, and FAT/exFAT instability.
- Use `FILE_STANDARD_INFO` for `AllocationSize`, `EndOfFile`, `NumberOfLinks`, `DeletePending`, and directory flag.
- Use `CreateFileW` with `FILE_FLAG_OPEN_REPARSE_POINT` when we need identity of the symlink/junction/reparse object itself. Without that flag, the handle can target what the link points to.
- Record `FILE_ATTRIBUTE_REPARSE_POINT` and reparse tag. A junction, symlink, cloud placeholder, mount point, and provider object are not ordinary directories.

Delete and Recycle Bin facts:

- Do not use `DeleteFile` for move-to-trash. It is permanent, can fail on read-only files, and has handle/share/delete-pending semantics that are not Recycle Bin semantics.
- Prefer Shell `IFileOperation` with `FOFX_RECYCLEONDELETE` for Recycle Bin behavior.
- Implement `IFileOperationProgressSink::PostDeleteItem` so each item receives actual `hrDelete` and optional `psiNewlyCreated`.
- If `psiNewlyCreated` is null, receipt must not claim Recycle Bin restore exists.
- Use no-UI or daemon-safe flags deliberately. Never let a background daemon pop unexpected Explorer dialogs.

Permission facts:

- Delete capability can come from `DELETE` on the file or `FILE_DELETE_CHILD` on the parent directory.
- Read/list permission is not delete permission.
- Controlled Folder Access, enterprise policy, ACLs, read-only attribute, locks, memory-mapped files, SMB leases/oplocks, Recycle Bin disabled per drive, and long path settings all affect outcomes.

Symlink and replacement policy:

- Reparse point handling must be explicit. Default cleanup operates on the selected reparse object, not blindly on the resolved target.
- Junctions and mounted folders are high-risk until fixtures prove adapter behavior.
- A directory that becomes a reparse point between scan and cleanup is `stale_replaced_by_link_or_reparse`.

Open questions for spike:

- Whether native `IFileOperation` from Rust through `windows` crate is ergonomic enough, or whether a small C++/COM helper crate reduces risk.
- Exact flag set for daemon mode: recycle, no UI, early failure, no junction traversal, no elevation prompt unless explicitly user initiated.
- How Recycle Bin disabled, removable drives, OneDrive/Cloud Files, and SMB shares report `psiNewlyCreated`.

### Linux

Available identity facts:

- Prefer `statx` where available: inode, containing device major/minor, optional mount ID, link count, size, allocated blocks, timestamps, attributes, and mount-root flag.
- Fallback to `lstat` if `statx` is unavailable or incomplete.
- For identity-sensitive probes, use `openat`/`openat2` style operations relative to an already opened root or parent directory.
- `O_PATH | O_NOFOLLOW` can obtain a descriptor for a symlink itself without needing read permission on the object.
- `openat2` can restrict resolution with `RESOLVE_BENEATH`, `RESOLVE_IN_ROOT`, `RESOLVE_NO_MAGICLINKS`, `RESOLVE_NO_SYMLINKS`, and `RESOLVE_NO_XDEV`; use this for root-scoped validation where kernel support exists.

Delete and Trash facts:

- POSIX `unlink` removes a name. Space is only reusable after link count reaches zero and no process holds the file open.
- `unlink` of a symlink removes the link, not the target.
- `unlinkat` can operate relative to a directory file descriptor and reduce path replacement risk.
- For user-facing cleanup, prefer FreeDesktop Trash where available. If compliant Trash is unavailable, return `trash_unsupported`, not permanent delete.
- FreeDesktop requires `.trashinfo` as the source of original path/deletion date. Trash filenames are not authoritative.

Permission facts:

- Delete requires write and search permission on the parent directory.
- Sticky directories restrict deletion based on file owner, directory owner, or privilege.
- Immutable and append-only flags, read-only filesystems, mount points, NFS silly rename, FUSE/provider behavior, and sandbox packaging can block or alter deletion.

Symlink and replacement policy:

- Default scan identity uses no-follow metadata for link objects.
- A trailing slash or resolver behavior can accidentally target a symlink destination, so cleanup should not operate on user-supplied path strings.
- If Linux kernel supports `openat2`, use resolution restrictions for the preflight path walk. Otherwise use best-effort parent fd, `fstatat` no-follow, and conservative blocking for risky cases.

Open questions for spike:

- Which Rust crate or internal FFI path gives the cleanest `statx`, `openat2`, `unlinkat`, and `O_PATH` support with good testability.
- Whether the `trash` crate is acceptable for Linux MVP despite its own documented caveat and FreeDesktop assumption.
- Behavior on GNOME, KDE, XFCE, headless Linux, Flatpak, Snap, WSL, NFS, SMB, FUSE/rclone, and removable volumes.

## Revalidation Algorithm

### 1. Build DeletePlan From Node IDs, Not Paths

Input from Flutter:

```text
scan_session_id
snapshot_id
selected_node_ids
client_visible_version
idempotency_key
```

Forbidden input:

```text
path_to_delete
formatted_size
row_index
search_result_path
```

The server resolves node IDs against the Rust-owned scan snapshot and creates candidates with scan-time identity evidence.

### 2. Normalize The Plan

Rules:

- collapse child selections under selected parent when risk boundaries allow it;
- keep high-risk children separate if they need independent confirmation;
- block system roots, Trash itself, snapshots, provider internals, and unknown special files by default;
- assign every candidate a `risk_level`, `evidence_level`, and `required_confirmation_level`;
- compute selected apparent bytes separately from estimated reclaim.

### 3. Preflight Immediately Before Execution

For each execution candidate:

```text
resolve under allowed root
probe current identity without following links unless policy allows
probe parent identity and delete capability
probe mount/volume identity
compare current evidence with scan evidence
classify stale/missing/replaced/moved/permission/unsupported
only then call TrashAdapter
```

Preflight must run as close as possible to the adapter call. It reduces risk but does not fully solve TOCTOU.

### 4. Prefer Handle/Descriptor Based Operations Where Possible

Best available pattern:

```text
open root or parent directory handle
resolve relative path with no escape policy
probe final object no-follow
compare identity evidence
execute platform Trash operation
record adapter-reported result
```

Reality:

- macOS `FileManager.trashItem` is URL/path-oriented, so we still need immediate preflight and post-result receipt.
- Windows `IFileOperation` is shell-item oriented; we need current handle evidence before queueing and per-item sink result after execution.
- Linux FreeDesktop Trash usually moves by path, so parent-fd scoped validation plus immediate rename/move semantics matter.

### 5. Receipt Is The Authority After Execution

Receipt item fields:

```text
operation_id
candidate_id
scan_identity_evidence
preflight_identity_evidence
trash_adapter
started_at
completed_at
outcome
platform_error_code_optional
resulting_trash_reference_optional
observed_path_removed
observed_free_space_delta_optional
reclaim_confidence_after
manual_review_reason_optional
```

Receipt outcomes:

```text
moved_to_trash
permanently_deleted_by_platform
skipped_by_policy
blocked_identity_mismatch
blocked_permission_denied
blocked_trash_unsupported
blocked_reparse_or_symlink_policy
blocked_volume_changed
blocked_parent_changed
blocked_mount_boundary_changed
missing_before_execution
failed_in_use
failed_read_only
failed_provider_state
unknown_requires_review
```

## Stale Candidate Detection

### Directory Replacement

Detect as stale when:

- current object kind changed;
- device/volume changed;
- inode/file ID changed;
- parent identity changed unexpectedly;
- mount ID or boundary changed;
- path now points to symlink/reparse point;
- candidate was directory at scan time but current object is file/link/provider placeholder;
- candidate was file at scan time but current object is directory.

Do not silently follow new targets.

### Move Or Rename

If the original path is missing:

- do not search whole disk and auto-delete "same" file elsewhere;
- mark as `missing_before_execution`;
- optional future: offer "locate moved item" as a review-only flow using identity search within same volume.

### Same ID, Different Metadata

If strong ID matches but size/time changed:

- normal file: downgrade confidence and require user review if selected as cleanup candidate;
- directory: require subtree refresh because child contents may differ;
- app-managed data: block or rerun recommendation rule.

### Same Path, Different ID

Always block. This is the classic stale path replacement case.

### Weak Filesystem

If identity source is weak:

- FAT/exFAT, some network filesystems, FUSE, provider mounts, WSL interop paths, containers, and sandboxes lower confidence;
- cleanup can remain available only with stronger confirmation and immediate preflight;
- high-risk recursive directory cleanup should be disabled if identity is weak.

## Rust Crate Candidates

### `file-id` 0.2.3

Use case:

- quick cross-platform file ID collection for initial spike;
- good reference for platform-specific identity extraction;
- possible adapter inside `fs_usage_platform`.

Risk:

- docs explicitly warn IDs can be reused;
- API may be too small for our needed confidence model, parent identity, no-follow semantics, and platform-specific fields;
- not enough for DeletePlan authority alone.

Score: 🎯 7 🛡️ 6 🧠 3, roughly 50-200 LOC to try, 300-800 LOC if wrapped with our evidence model.

### `same-file` 1.0.6

Use case:

- test helper and fallback equality comparison;
- useful for checking two paths/handles refer to the same object.

Risk:

- equality check is not a durable identity snapshot;
- not enough for stale candidate classification, reparse policy, permissions, Trash receipt, or reclaim evidence.

Score: 🎯 8 🛡️ 7 🧠 2, roughly 20-120 LOC as a test/helper dependency.

### `trash` 5.2.6

Use case:

- cross-platform first Trash adapter candidate behind our `TrashAdapter`;
- likely useful for a quick destructive-operation spike in disposable fixtures.

Risk:

- Linux behavior assumes FreeDesktop-compatible desktop environments;
- docs mention mount-point query caveat and mutex guard;
- may not expose enough platform result detail for receipts;
- may not classify Windows/macOS errors with the granularity we need.

Score: 🎯 7 🛡️ 6 🧠 4, roughly 150-500 LOC to wrap, 700-1700 LOC to audit and fixture-test across OSes.

### Direct Native Adapters

Use case:

- production-grade receipt and error classification;
- full control over `FileManager.trashItem`, `IFileOperation`, FreeDesktop Trash, and Linux fd-scoped validation.

Risk:

- more code and OS-specific tests;
- COM and Objective-C/Swift integration need care;
- Linux desktop/headless behavior still varies.

Score: 🎯 8 🛡️ 9 🧠 8, roughly 1600-3500 LOC for first stable version.

Recommendation: use crates for spike and tests, but keep `fs_usage_platform` evidence model and `TrashAdapter` independent. We can start with `file-id` and `trash` behind adapters, then replace specific platforms where receipt fidelity is too weak.

## Architecture Placement

```text
rust/crates/fs_usage_core/
  model/node_identity.rs
  model/node_kind.rs
  model/link_kind.rs
  model/volume_identity.rs
  accounting/reclaim_estimate.rs
  warning/warning_code.rs

rust/crates/fs_usage_engine/
  application/port/identity_provider.rs
  application/port/delete_capability_probe.rs
  application/port/trash_adapter.rs
  application/command/create_delete_plan.rs
  application/command/preflight_delete_plan.rs
  application/command/execute_delete_plan.rs
  application/event/cleanup_event.rs

rust/crates/fs_usage_platform/
  src/macos/identity_probe.rs
  src/macos/trash_adapter.rs
  src/windows/identity_probe.rs
  src/windows/reparse_probe.rs
  src/windows/trash_adapter.rs
  src/linux/identity_probe.rs
  src/linux/trash_adapter.rs
  src/common/error_mapper.rs

rust/crates/fs_usage_cleanup/
  src/domain/delete_plan.rs
  src/domain/delete_candidate.rs
  src/domain/cleanup_risk.rs
  src/domain/cleanup_receipt.rs
  src/application/delete_plan_service.rs
  src/application/cleanup_policy.rs
```

Layer rules:

- `fs_usage_core` defines evidence value objects only.
- `fs_usage_engine` defines ports and use cases.
- `fs_usage_platform` implements OS probes and Trash adapters.
- `fs_usage_cleanup` owns DeletePlan, policy, validation, and receipt workflow.
- Clean Disk server maps HTTP commands to cleanup use cases.
- Flutter never sends raw delete paths and never interprets platform identity itself.

## Spike Plan

### Spike A - Identity Probe Matrix

Goal: prove what evidence we can collect on macOS, Windows, and Linux.

Fixtures:

```text
regular file
directory
empty directory
non-empty directory
symlink to file
symlink to directory
broken symlink
hardlink pair
renamed file
path replaced by different file
path replaced by symlink
directory replaced by file
permission-denied parent
readonly file
external/removable volume if available
network/share/FUSE if available
```

Expected result:

- printed JSON evidence for every fixture;
- confidence level assigned;
- same path/different object detection works;
- same object/renamed path detection is represented but not auto-deleted;
- all platform fields map to optional structured values.

### Spike B - Delete Preflight Without Execution

Goal: build DeletePlan, mutate fixtures after scan, and ensure preflight blocks stale candidates.

Required mutations:

```text
rename selected item away
replace selected file with new file
replace selected directory with symlink
replace parent directory
change permissions
make file read-only
open/lock file where platform supports it
change symlink target
mount boundary if practical
```

Expected result:

- preflight produces typed block reason;
- no Trash/delete operation is called for blocked candidates;
- operation journal stores blocked result;
- UI-facing DTO can explain why review is needed.

### Spike C - Trash Adapter Fixture Test

Goal: move disposable fixture items to Trash/Recycle Bin and record receipt truthfully.

Required:

- use dedicated temp directory only;
- never test against user folders;
- require explicit `CLEAN_DISK_ALLOW_TRASH_FIXTURE_TESTS=1`;
- record result path/reference where platform reports it;
- verify original path removed;
- verify item appears in Trash only when adapter can prove it;
- classify unsupported/headless/disabled Recycle Bin separately.

### Spike D - Race Harness

Goal: simulate TOCTOU by mutating paths between preflight and adapter call.

Approach:

- inject a `BeforeTrashHook` in test-only adapter path;
- mutate target after validation;
- assert final adapter wrapper rechecks or classifies uncertainty;
- receipt must become `unknown_requires_review` or blocked, never success without evidence.

## MVP Rules

- No permanent delete in MVP.
- Move-to-Trash only when platform adapter reports support.
- No cleanup on unknown identity for directories.
- No cleanup on reparse/junction/mount point until specific adapter fixture passes.
- No cleanup on network/FUSE/removable volume unless Trash support and identity confidence are known.
- No cleanup from stale scan, stale search cursor, or old browser tab without server-side revalidation.
- No "freed space" claim after moving to Trash; report moved bytes and observed free-space delta separately.
- No raw path delete endpoint.

## Open Questions Before Implementation

1. Do we use `file-id` for the identity spike, or write minimal native probes immediately?
   - My recommendation: start with `file-id` only as a baseline comparison, but implement our own `IdentityProbe` shape from day one.
2. Do we use `trash` crate for the first Trash adapter spike?
   - My recommendation: yes for disposable fixture spike, no domain dependency, and be ready to replace per platform.
3. Do we build native macOS Trash through Objective-C bindings or a tiny Swift helper?
   - My recommendation: spike both if Objective-C error mapping gets awkward. Keep the public adapter contract identical.
4. Do we support Linux headless cleanup?
   - My recommendation: scan-only for headless MVP unless user explicitly configures a permanent-delete policy later.
5. Do we hold live handles from scan until delete?
   - My recommendation: no for large scans. It is too expensive and can interfere with user operations. Re-probe immediately before delete instead.

## Final Position

Platform identity and delete revalidation are feasible, but not "simple". The right abstraction is not `FileId` and not `delete(path)`. The right abstraction is:

```text
scan evidence
  -> DeletePlan
  -> current identity preflight
  -> platform Trash adapter
  -> typed receipt
  -> conservative UI wording
```

This keeps the reusable Rust library honest and lets Clean Disk remain safe on macOS, Windows, Linux desktop, Linux headless, remote mode, and weak filesystems.
