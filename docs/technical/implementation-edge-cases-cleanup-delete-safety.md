# Implementation Edge Cases - Cleanup And Delete Safety

Last updated: 2026-05-13.

This file records edge cases for the cleanup workflow: delete candidates, DeletePlan validation, move-to-trash adapters, partial outcomes, receipts, restore expectations, reclaim estimates, and platform-specific safety behavior.

The cleanup workflow is the highest-risk part of Clean Disk. A scan can be wrong and still be recoverable. A bad delete action can destroy user trust immediately.

Related documents:

- [Implementation edge cases](implementation-edge-cases.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md)
- [Implementation edge cases cloud network virtual filesystems](implementation-edge-cases-cloud-network-virtual-filesystems.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)

## Sources Reviewed

- Apple Developer Documentation, [FileManager.trashItem(at:resultingItemURL:)](https://developer.apple.com/documentation/foundation/filemanager/trashitem%28at%3Aresultingitemurl%3A%29). Relevant point: macOS can move an item to Trash and return the actual resulting Trash URL because the name may change.
- Microsoft Learn, [IFileOperation::SetOperationFlags](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-setoperationflags). Relevant point: `FOFX_RECYCLEONDELETE` sends deleted files to the Recycle Bin; flags must be set before `PerformOperations`.
- Microsoft Learn, [IFileOperationProgressSink::PostDeleteItem](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperationprogresssink-postdeleteitem). Relevant point: per-item delete result is reported after actual deletion; `psiNewlyCreated` points to the item now in the Recycle Bin or is null if it was fully deleted.
- Microsoft Learn, [SHFileOperation](https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-shfileoperationa). Relevant points: delete permanently removes unless `FOF_ALLOWUNDO` is set; fully qualified paths are required; recursive deletion is default unless disabled.
- Microsoft Learn, [DeleteFile](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-deletefile). Relevant points: `DeleteFile` is permanent, read-only files fail, open handles can defer/fail deletion, and symlink deletion deletes the link rather than the target.
- FreeDesktop.org, [Trash Specification](https://specifications.freedesktop.org/trash/latest/). Relevant points: trashed files live under `files`, `.trashinfo` stores original path and deletion date, Trash file names are not authoritative, and the info file should be created atomically.
- MITRE CWE, [CWE-367 Time-of-check Time-of-use Race Condition](https://cwe.mitre.org/data/definitions/367). Relevant point: a resource can change between validation and use, causing unexpected access or modification.
- Rust Standard Library, [std::path::Path](https://doc.rust-lang.org/std/path/struct.Path.html). Relevant points: `exists`/`try_exists` can still introduce TOCTOU bugs, and `to_string_lossy` replaces invalid UTF-8.
- Linux man-pages, [unlink(2)](https://man7.org/linux/man-pages/man2/unlink.2.html). Relevant points: unlink removes a name; storage is reclaimed only when link count and open descriptors allow it; symlink unlink removes the link; immutable/append-only and read-only filesystems fail.
- Linux man-pages, [rename(2)](https://man7.org/linux/man-pages/man2/rename.2.html). Relevant points: rename is atomic in important ways, open descriptors and hard links are unaffected, and symlinks are renamed/overwritten as links.
- Rust crate docs, [trash](https://docs.rs/trash/latest/trash/). Relevant points: the crate moves files to the OS Trash/Recycle Bin; Linux behavior assumes FreeDesktop-compatible desktops; docs call out a Linux/FreeBSD mount-point query caveat managed by a mutex.

## Severity Scale

- `P0` - can delete the wrong file, claim bytes were reclaimed when they were not, lose delete receipts, bypass confirmation, or make cleanup possible without stable identity revalidation.
- `P1` - can confuse restore expectations, cause partial outcomes without clear receipt, produce support burden, or make cross-platform behavior inconsistent.
- `P2` - important polish, diagnostics, future restore capability, enterprise policy, or better user explanations.

## Top 3 Cleanup Decisions

1. Trash-only MVP with no permanent delete adapter - 🎯 10 🛡️ 10 🧠 4, roughly 300-900 LOC across capability checks, disabled actions, wording, and tests.
2. DeletePlan aggregate with identity revalidation and durable receipt before execution - 🎯 10 🛡️ 10 🧠 8, roughly 900-2200 LOC across Rust domain/application, operation journal, protocol, adapters, UI, and crash tests.
3. Platform-specific Trash adapters behind one port, not a generic path-delete helper - 🎯 9 🛡️ 9 🧠 7, roughly 800-2000 LOC across macOS, Windows, Linux capability detection, typed outcomes, and fixtures.

The important stance: cleanup is not "run rm on paths". Cleanup is a domain workflow with identity, risk, confirmation, execution, receipt, and recovery states.

## Domain Boundary

### Cleanup Is A Separate Bounded Context - `P0`

Scan results identify disk usage. Cleanup decides whether the user can safely request a destructive action.

Required behavior:

- `scan` domain produces nodes, identities, size models, skipped states, and risk hints;
- `cleanup` domain owns DeletePlan, DeleteCandidate, CleanupRisk, ConfirmationToken, TrashExecution, TrashReceipt;
- UI selection is not a DeletePlan;
- DeletePlan references scan snapshot id and tree index version;
- direct calls from Flutter UI to a Trash crate, shell command, or filesystem path are forbidden.

Avoid:

- passing raw display paths from UI to a delete adapter;
- making scan nodes mutable cleanup state;
- putting confirmation logic inside widgets;
- representing cleanup as `List<PathBuf>`.

### Ports Belong In Application Layer - `P0`

The cleanup domain should not know macOS, Windows, Linux, `trash`, COM, FileManager, HTTP, WebSocket, Flutter, or Drift.

Required ports:

```text
CleanupRepository
DeletePlanRepository
TrashAdapter
IdentityProbe
RiskClassifier
ReceiptWriter
Clock
OperationJournal
```

Adapter examples:

- `MacosFileManagerTrashAdapter`;
- `WindowsIFileOperationTrashAdapter`;
- `FreedesktopTrashAdapter`;
- `TrashRsAdapter` only if audited and accepted;
- `ReadOnlyTrashAdapter` for web/remote/headless without cleanup capability.

## Candidate Selection

### Large Does Not Mean Safe - `P0`

The biggest directories are often the least safe: system folders, VM disks, app-managed databases, package-manager stores, sync roots, snapshots, and caches shared by multiple projects.

Required behavior:

- every candidate has a `risk_level`;
- every candidate has machine-readable `risk_reason_codes`;
- recommendations are grouped by confidence, not only size;
- system and app-owned directories are never silently presented as ordinary user files;
- UI can show "analyze only" candidates where direct cleanup is blocked.

Suggested risk levels:

```text
safe_known_cache
review_recommended
review_high_risk
blocked_system
blocked_snapshot
blocked_cloud_placeholder
blocked_remote_unsupported
blocked_identity_unstable
```

### Parent/Child Selection Must Be Normalized - `P0`

Users can queue a parent folder and a child file inside it. Executing both creates double counting, confusing receipts, and platform errors.

Required behavior:

- DeletePlan normalizes ancestry before confirmation;
- parent candidate covers children unless child has a different risk boundary;
- receipt records original user selections and normalized execution set;
- total size shows selected apparent bytes and normalized execution bytes separately when useful;
- UI explains covered child items without presenting them as separately executed.

### Trash Itself Is Not An Ordinary Folder - `P0`

Trash/Recycle Bin can appear as a folder and may be large. Emptying Trash is not the same operation as moving a normal folder to Trash.

Required behavior:

- Trash storage is detected and labeled separately;
- Trash contents are excluded from ordinary cleanup candidates by default;
- "Empty Trash" is a separate future platform action, not recursive delete of Trash directories;
- app never moves Trash into Trash;
- FreeDesktop "trashing of the trash" caveat is treated as a blocked case.

### Reclaim Estimate Must Distinguish Moved From Freed - `P0`

Moving an item to Trash often does not free disk space immediately. It changes location and restore state. Actual reclaim usually happens only after Trash is emptied.

Required behavior:

- UI label says "Move to Trash", not "Free space now";
- metric separates `selected_bytes`, `moved_to_trash_bytes`, and `immediately_freed_bytes`;
- after a successful move, receipt says moved, not freed;
- reclaim estimate notes "space is recoverable after Trash is emptied" where applicable;
- do not count same-volume Trash move as immediate disk reclaim.

Avoid:

- "Total to reclaim" for move-to-trash unless wording clearly means after emptying Trash;
- success toast claiming "38 GB freed" after a move-to-trash action;
- progress bars that imply disk free space changed before the OS reports it.

## Identity And Revalidation

### Path-Only Cleanup Is Forbidden - `P0`

Paths can be renamed, replaced, normalized, synced, mounted, or made to point to a different object between scan and cleanup.

Required behavior:

- scan snapshot stores an identity snapshot per node;
- DeletePlan stores identity snapshot, not only path;
- execution re-probes identity immediately before move-to-trash;
- identity mismatch moves item to `needs_review`;
- old scan cache never authorizes delete.

Identity snapshot should include, where available:

```text
path_raw
node_kind
device_or_volume_id
file_id_or_inode
parent_id
size_bytes
allocated_bytes
mtime
ctime_or_birthtime
link_count
symlink_marker
mount_id_or_boundary
provider_marker
```

### TOCTOU Cannot Be Fully Solved With Prechecks - `P0`

Rust docs warn that existence checks can still have TOCTOU issues. MITRE documents the class of bug. A file can change after validation and before operation.

Required behavior:

- perform validation immediately before adapter call;
- prefer APIs that operate on strong OS objects or shell items where available;
- compare identity before and after move where adapter can report it;
- never use `Path::exists` as safety proof;
- `exists == false` is not enough to infer "already safely deleted";
- if the final outcome cannot be proved, receipt item becomes `unknown_requires_review`.

Best practical stance:

```text
scan identity narrows the target;
DeletePlan binds user intent;
preflight validation catches stale state;
adapter outcome proves what happened;
receipt records uncertainty instead of inventing certainty.
```

### Symlink And Reparse Behavior Is A Policy, Not A Detail - `P0`

Windows `DeleteFile` deletes the symlink itself, not the target. Linux `unlink` removes the link name. macOS and shell Trash behavior can differ by API and item type.

Required behavior:

- scan marks symlink/reparse/junction nodes explicitly;
- cleanup policy says whether moving a link moves the link or target;
- UI labels linked items clearly;
- default cleanup should move the link object, not follow into outside target;
- reparse points and junctions are high-risk until platform adapter tests exist.

### Hardlinks Need Reclaim-Safe Accounting - `P0`

Deleting one link to a multi-link file may not free storage. Moving one link to Trash can preserve data while another link remains.

Required behavior:

- link count affects reclaim estimate;
- hardlinked files get risk reason `hardlink_low_reclaim` or equivalent;
- DeletePlan can show apparent size vs unique reclaimable size;
- receipt records link count observed at execution;
- do not recommend deleting package-manager stores as simple duplicates.

## Platform Trash Adapters

### macOS FileManager Adapter - `P0`

`FileManager.trashItem` returns the resulting Trash URL because the actual name may change.

Required behavior:

- adapter records resulting Trash URL when available;
- receipt stores original path and resulting Trash reference separately;
- if TCC/sandbox denies access, result is `permission_denied`, not generic failure;
- if item lives in iCloud/Dropbox/other provider storage, result includes provider warning;
- UI exposes "Reveal in Trash" only when resulting URL is available and still exists.

Avoid:

- assuming the Trash filename equals original filename;
- implementing Trash by manually moving to `~/.Trash`;
- claiming "Put Back" support unless restore is implemented and tested.

### Windows IFileOperation Adapter - `P0`

Windows cleanup should prefer Shell file operation APIs for Recycle Bin semantics. Low-level `DeleteFile` is permanent and has handle/read-only semantics that are not the same as Recycle Bin.

Required behavior:

- use `IFileOperation` for Recycle Bin capable adapter where feasible;
- set recycle flags deliberately before execution;
- use per-item progress sink to capture actual `hrDelete` and `psiNewlyCreated`;
- if `psiNewlyCreated` is null, receipt must not claim Recycle Bin restore exists;
- OS modal prompts should be disabled or avoided in daemon mode;
- read-only, locked, ACL-denied, path-too-long, and in-use states are typed outcomes.

Avoid:

- calling `DeleteFile` for move-to-trash;
- relying on relative paths;
- using legacy `SHFileOperation` unless we intentionally accept its quirks;
- automatically clearing read-only attribute or escalating privileges.

### Linux FreeDesktop Adapter - `P0`

Linux Trash support is real on desktop environments, but not guaranteed in server/headless/container environments.

Required behavior:

- detect FreeDesktop-compatible Trash capability;
- create `.trashinfo` before moving file into `files`;
- store original path and deletion date from reliable adapter result;
- handle external-volume Trash locations;
- refuse cleanup if Trash is unsupported instead of falling back to permanent delete;
- expose headless Linux as scan-only until delete semantics are explicitly designed.

Avoid:

- manually guessing Trash path from home directory only;
- treating `.trashinfo` filename as original file name;
- assuming all Linux desktops behave like Ubuntu GNOME;
- assuming a container has a user Trash.

### Rust `trash` Crate Is An Adapter Candidate, Not The Domain - `P1`

The `trash` crate is attractive because it is cross-platform and focused on moving to OS Trash/Recycle Bin. It still needs adapter-level auditing.

Required behavior if used:

- keep crate behind `TrashAdapter`;
- pin/review version before adding dependency;
- test each supported OS with our fixtures;
- audit Linux FreeDesktop assumptions;
- account for documented mount-point caveat and any global mutex behavior;
- map crate errors into our typed outcomes.

Top 3 adapter choices:

1. OS-native adapters first, optional `trash` crate only for Linux fallback - 🎯 8 🛡️ 9 🧠 8, roughly 1600-3500 LOC.
2. `trash` crate as first adapter behind our port, with fixture audit before cleanup beta - 🎯 8 🛡️ 7 🧠 5, roughly 700-1700 LOC.
3. Manual Trash implementations for all platforms - 🎯 4 🛡️ 5 🧠 9, roughly 2500-6000 LOC.

My current recommendation: start with adapter port and contract tests, then choose per-platform implementation. Do not let the first crate choice shape the domain model.

## Execution Semantics

### Batch Trash Is Not Atomic - `P0`

Moving 100 items to Trash can partially succeed. There is no universal cross-platform transaction.

Required behavior:

- receipt is created before execution starts;
- item outcome is written incrementally;
- final operation status can be `completed`, `partial`, `failed`, `cancelled`, or `interrupted_requires_review`;
- failures do not rollback successful Trash moves unless a verified restore adapter exists;
- UI reports item-level outcomes.

### Cancellation Is A Stop-Before-Next-Item Operation - `P0`

Cancel cannot guarantee undo for already moved items.

Required behavior:

- cancel requests stop scheduling the next item;
- current item may complete, fail, or become unknown;
- already moved items stay moved;
- receipt says cancelled by user and lists completed outcomes;
- UI wording avoids implying undo.

### Duplicate Commands Need Idempotency - `P0`

WebSocket reconnect, double-click, browser retry, or app restart can send the same command twice.

Required behavior:

- confirmation token is single-use;
- execution command carries idempotency key;
- same key with same payload returns same operation state;
- same key with different payload is rejected;
- stale retries after terminal status return terminal receipt.

### Active Cleanup Should Serialize By Target - `P0`

Two cleanup operations targeting overlapping paths can race.

Required behavior:

- daemon serializes delete executions or locks by normalized identity set;
- overlapping DeletePlans cannot execute concurrently;
- active execution blocks app update/shutdown or records interrupted state;
- operation event stream is derived from durable journal, not in-memory callbacks only.

## Restore Expectations

### Move To Trash Is Not Guaranteed Undo - `P1`

OS Trash usually allows user recovery, but our app should not promise undo unless it owns and verifies a restore flow.

Required behavior:

- MVP offers "Reveal in Trash" where supported, not "Undo";
- receipt stores enough adapter result to support future restore;
- restore feature, if added, is adapter-specific;
- restore must handle destination conflicts, replaced paths, missing parent, permissions, and cloud-provider state;
- restoring a parent folder and child file must be normalized like deletion.

### Resulting Trash Location Can Be Non-Obvious - `P1`

Provider-managed folders, external drives, network mounts, and desktop implementations may place trashed items in provider/volume-specific Trash.

Required behavior:

- receipt stores adapter-reported resulting location when available;
- UI does not assume one global Trash;
- "Reveal in Trash" is capability-gated;
- provider-specific Trash warning is shown for cloud/sync roots;
- remote/headless mode does not expose reveal actions.

## Permissions And Policy

### No Automatic Privilege Escalation - `P0`

A cleanup app should not become a silent privilege tool.

Required behavior:

- normal scan and move-to-trash run as the current user;
- admin/root elevation is not used in MVP;
- permission-denied is typed and visible;
- app does not chmod/chown/remove readonly/clear immutable flags automatically;
- system-protected paths are blocked or redirected to official OS cleanup tools.

### OS Prompts Are Product Bugs In Daemon Mode - `P1`

If a local daemon opens a hidden native prompt, the web UI and desktop UI can become inconsistent.

Required behavior:

- adapters run in noninteractive mode where possible;
- prompt-required outcome is typed;
- UI initiates explicit permission flow before cleanup;
- daemon never waits forever on a hidden OS dialog;
- headless mode rejects prompt-required operations.

### Enterprise Policies Can Disable Cleanup - `P1`

Managed machines may restrict Recycle Bin, shell operations, removable storage, cloud sync, or folder access.

Required behavior:

- capabilities endpoint reports cleanup disabled reasons;
- UI hides or disables cleanup actions;
- receipt records policy denial;
- recommendations remain read-only;
- app never bypasses policy with lower-level delete.

## Protocol And UX

### Mutating Cleanup Endpoints Must Not Be GET - `P0`

Browser prefetch, link previews, crawlers, history restore, or accidental navigation must not trigger cleanup.

Required behavior:

- create plan: `POST`;
- validate plan: `POST`;
- confirm plan: `POST`;
- execute plan: `POST`;
- receipt query: `GET`;
- no cleanup action uses query parameters like `?delete=true`.

### Confirmation Must Bind To The Exact Plan - `P0`

Confirmation text is not enough. The token must bind to the exact candidate set and risk state.

Required behavior:

- token binds to `delete_plan_id`, `plan_hash`, `session_id`, `tree_index_version`, user/client id, and expiry;
- any plan change invalidates token;
- risk escalation invalidates token;
- typed confirmation phrase can be required for high-risk plans;
- UI shows changed/stale items before re-confirmation.

### UI Copy Must Match Semantics - `P0`

Bad copy can make a safe implementation unsafe.

Required wording rules:

- "Move to Trash" for reversible platform action;
- "Empty Trash" only for a separate future action;
- "Potentially reclaimable" for estimates before emptying Trash;
- "Moved to Trash" for outcome, not "Deleted forever";
- "Could not verify outcome" for unknown state.

Avoid:

- "Delete" as the primary label in MVP;
- "Free now" after a Trash move;
- "Undo" without restore implementation;
- hiding partial failures behind one success toast.

## Observability And Receipts

### Receipts Need Item-Level Truth - `P0`

The receipt is the user's source of truth after cleanup.

Required fields:

```text
operation_id
delete_plan_id
started_at
finished_at
requested_by_client
source_scan_session_id
source_tree_index_version
adapter_kind
adapter_version
item_outcomes[]
total_selected_bytes
total_moved_to_trash_bytes
total_immediately_freed_bytes
warnings[]
```

Per-item outcome should include:

```text
candidate_id
original_path_redactable
identity_snapshot
execution_started_at
execution_finished_at
outcome_kind
adapter_error_code
resulting_trash_reference
bytes_claimed_moved
bytes_claimed_freed
requires_user_review
```

### Logs Must Not Leak Paths By Default - `P0`

Cleanup logs are useful for support but high privacy risk.

Required behavior:

- structured logs use operation id and candidate id;
- raw path logging is off by default;
- support bundle has redaction preview;
- receipt export can be redacted;
- tokens and confirmation phrases never enter logs.

## Test Matrix

### Cross-Platform Fixtures

Required:

- ordinary file;
- ordinary directory;
- parent and child both selected;
- symlink to file inside target;
- symlink to file outside target;
- broken symlink;
- hardlinked file with another link outside target;
- open/in-use file;
- read-only file;
- path with invalid/non-UTF-8 bytes where platform supports it;
- path with bidi/control characters;
- very long path;
- item replaced between scan and execution;
- item renamed between scan and execution;
- item deleted by another process before execution.

### macOS Fixtures

Required:

- `FileManager.trashItem` returns resulting URL;
- iCloud/CloudStorage path warning;
- TCC-denied folder;
- app sandbox denied path if sandbox package is tested;
- package/bundle directory selected;
- locked file outcome.

### Windows Fixtures

Required:

- `IFileOperation` Recycle Bin move;
- `PostDeleteItem` reports Recycle Bin item;
- null `psiNewlyCreated` becomes full-delete/unknown warning;
- read-only attribute denied or handled according to policy;
- ACL delete denied;
- open handle and memory-mapped file;
- junction/reparse point;
- long path;
- UNC path blocked or warned according to capability.

### Linux Fixtures

Required:

- FreeDesktop `.trashinfo` created;
- external-volume Trash;
- no desktop Trash available;
- read-only mount;
- immutable/append-only file;
- sticky directory;
- symlink and hardlink behavior;
- headless/container scan-only cleanup capability.

### Crash And Retry Fixtures

Required:

- crash before first item;
- crash after first item moved and receipt not finalized;
- crash after adapter returns success before event is delivered;
- duplicate execute request after reconnect;
- cancel while item is in progress;
- app update requested during execution;
- daemon restart with interrupted receipt.

## MVP Cut Line

Before first cleanup-capable beta:

- no permanent delete adapter;
- DeletePlan exists as server-side aggregate;
- confirmation token binds to exact plan hash;
- every item revalidates identity immediately before Trash;
- batch execution writes durable item-level receipt;
- UI wording says Move to Trash and does not claim immediate free space;
- reclaim estimate separates moved bytes from freed bytes;
- adapter capability endpoint blocks unsupported Trash;
- parent/child selection is normalized;
- symlink/reparse/hardlink policy is explicit;
- crash, duplicate command, and cancellation tests exist.

Do not ship cleanup until stale-path deletion, partial receipt, and platform Trash capability tests pass on each supported OS.

## Summary

The safe stance:

```text
Scan results are evidence, not authority.
DeletePlan is the authority boundary.
Trash adapters are platform ports.
Receipts are user-trust records.
Move to Trash is not immediate free space.
Undo is not promised until restore is implemented.
Permanent delete is outside MVP.
```

The invariant:

```text
Clean Disk must never turn a stale path, UI row, or size recommendation into a destructive filesystem action without current identity validation, explicit confirmation, typed adapter outcome, and durable receipt.
```
