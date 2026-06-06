# Critical Zone - Restore, Quarantine, Undo, And Cleanup Receipt Safety

Last updated: 2026-05-16.

This file records the next global critical zone after
`recommendation-policy-rule-pack-safety.md`.

The core risk: the product can be technically correct about "Move to Trash" and
still mislead the user about recovery. Trash, Recycle Bin, provider trash,
tool-owned cleanup, app-managed quarantine, and permanent delete do not share one
undo model.

## Sources Reviewed

- Apple `FileManager.trashItem(at:resultingItemURL:)`: moves an item to Trash and
  can return the actual item URL in Trash because the item name may change.
  Source:
  https://developer.apple.com/documentation/foundation/filemanager/trashitem%28at%3Aresultingitemurl%3A%29
- Microsoft `IFileOperation::SetOperationFlags`: `FOFX_RECYCLEONDELETE` sends
  deleted files to the Recycle Bin, and flags must be set before
  `PerformOperations`.
  Source:
  https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-setoperationflags
- Microsoft `IFileOperationProgressSink::PostDeleteItem`: reports the actual
  delete result per item, and `psiNewlyCreated` points to the Recycle Bin item or
  is null if the item was fully deleted.
  Source:
  https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperationprogresssink-postdeleteitem
- Microsoft `SHFileOperation`: delete is permanent unless `FOF_ALLOWUNDO` is set;
  fully qualified paths are required; recursive deletion is default unless
  disabled.
  Source:
  https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-shfileoperationa
- FreeDesktop Trash Specification: Trash uses `files` and `info`; `.trashinfo`
  stores original path and deletion date; Trash filenames must never be used to
  recover the original filename; info file creation should be atomic.
  Source: https://specifications.freedesktop.org/trash/latest/
- Rust `trash` crate docs: version `5.2.6` provides cross-platform move-to-Trash
  functions, implements FreeDesktop Trash on Linux, and documents Linux/FreeBSD
  mount-query caveats.
  Source: https://docs.rs/trash/latest/trash/
- Microsoft OneDrive restore docs: personal OneDrive recycle bin items are
  automatically deleted after 30 days, work/school after 93 days unless changed;
  online-only deleted files do not appear in local Recycle Bin or Trash.
  Source:
  https://support.microsoft.com/en-us/office/restore-deleted-files-or-folders-in-onedrive-949ada80-0026-4db3-a953-c99083e6a84f
- Apple iCloud recovery docs: iCloud.com can recover iCloud Drive and app files
  deleted within the last 30 days, but cannot recover permanently removed files.
  Source: https://support.apple.com/en-mt/guide/icloud/mmae56ea1ca5/icloud
- Google Drive delete docs: items stay in Drive trash for 30 days, still count
  against storage until permanently deleted, and ownership affects access.
  Source: https://support.google.com/drive/answer/14933051
- Dropbox delete docs: deleted files remain recoverable for a plan-dependent
  recovery window; permanent delete is not recoverable; shared folder ownership
  affects outcome.
  Source: https://help.dropbox.com/delete-restore/deleted-files
- NIST SP 800-88 Rev. 1: delete, clear, purge, and destroy are distinct
  sanitization concepts. Clean Disk must not call Trash, permanent delete, or
  tool cleanup secure erase.
  Source: https://csrc.nist.gov/pubs/sp/800/88/r1/final
- Microsoft Azure Compensating Transaction pattern and Saga guidance:
  compensation can semantically undo completed work, but it does not necessarily
  return the system to the exact original state.
  Sources:
  https://learn.microsoft.com/en-us/azure/architecture/patterns/compensating-transaction
  and https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga
- Apple Human Interface Guidelines undo/redo and GNOME Human Interface
  Guidelines dialogs: undo/redo can help users reverse actions, but destructive
  actions need clear result communication, confirmation, or a genuine undo offer.
  Sources:
  https://developer.apple.com/design/human-interface-guidelines/undo-and-redo
  and https://developer.gnome.org/hig/patterns/feedback/dialogs.html

## Why This Is The Next Global Critical Zone

Update safety protects delivery. Runtime isolation protects execution.
Recommendation policy protects classification. The next global trust boundary is
what happens after the user approves cleanup.

Why:

- "Move to Trash" does not always free disk space now;
- "Trash" does not always mean restorable by our app;
- Windows may fully delete an item and report `psiNewlyCreated = NULL`;
- FreeDesktop Trash restore depends on valid `.trashinfo`;
- cloud provider deletion may propagate to other devices and have a separate
  provider recycle bin;
- tool-owned cleanup commands may be correct but not undoable;
- custom quarantine can duplicate data, lose metadata, cross filesystems, or
  fail under low disk pressure;
- partial cleanup can leave the user with a mixed state unless receipts are
  durable and precise.

This is P0 because recovery expectations are part of user consent. If the UI says
or implies "undo", the system needs a receipt-backed restore path or it must say
that restore is unavailable or uncertain.

## Current Global Ranking

1. Restore, quarantine, undo, and cleanup receipt safety - 🎯 8  🛡️ 10  🧠 9, roughly 1800-5200 LOC/tests/docs.
   Selected now. This decides what recovery guarantees the product may claim
   after cleanup and how partial outcomes are reconciled.
2. Tool command execution sandbox and side-effect control - 🎯 6  🛡️ 9  🧠 8, roughly 1400-4000 LOC/tests/docs.
   Official cleanup adapters are safer than raw deletion, but command execution
   brings PATH spoofing, scripts, environment, locks, credentials, output
   parsing, timeout, and cancellation risks.
3. Multi-user, enterprise, and remote cleanup authorization - 🎯 6  🛡️ 9  🧠 8, roughly 1500-4500 LOC/tests/docs.
   Remote/headless cleanup needs operator policy, audit, target scopes, and user
   ownership rules before destructive workflows are credible outside local
   desktop mode.

## Core Rule

Never promise undo. Promise only the restore capability proven by the adapter
receipt.

```text
approved DeletePlan
  -> preflight identity revalidation
  -> cleanup adapter execution
  -> per-item receipt
  -> restore capability classification
  -> post-action rescan
  -> optional restore workflow
```

Rules:

- UI says "Move to Trash", "Run cleanup", or "Permanently delete" based on the
  actual action, not one generic "Clean" verb;
- same-volume Trash move is not counted as immediate free space;
- cloud provider trash is not treated as local OS Trash;
- tool cleanup commands are not treated as undoable unless the tool exposes
  restore semantics;
- restore capability is per item, not per operation;
- every cleanup operation produces a durable receipt before and after execution;
- unknown outcome blocks further destructive automation until reconciled.

## Undo, Restore, Compensation, And Sanitization Are Different

Clean Disk needs four separate concepts.

```text
Undo
  product-controlled reversal of the last action, with clear result feedback

Restore
  adapter-supported attempt to return an item from Trash, Recycle Bin, provider
  recovery, or quarantine

Compensation
  follow-up action that reduces harm or rebuilds state, but may not restore the
  exact previous filesystem state

Sanitization
  clear, purge, or destroy semantics outside MVP scope
```

Rules:

- only use "Undo" when the app owns a tested reversal workflow for that exact
  action kind;
- use "Restore" only when receipt evidence and adapter capability exist;
- use "Rebuild", "Redownload", "Reinstall", or "Run tool repair" for
  compensation flows;
- never use "secure erase", "sanitize", "purge", or "destroy" unless a future
  platform-specific sanitization feature proves NIST-style semantics;
- compensation receipts are separate from cleanup receipts.

Kill criteria:

- `docker prune` or `cargo clean` gets an Undo button;
- "restore" means "rerun install" in UI text;
- permanent delete is called secure erase;
- compensation overwrites current user data to approximate rollback;
- support bundle cannot distinguish restore attempt from compensation attempt.

## Restore Capability Model

Use explicit levels instead of a boolean `canRestore`.

```text
RestoreCapability
  os_put_back_proven
    adapter returned a platform trash location and OS restore semantics are known

  os_trash_location_known
    adapter moved the item to Trash/Recycle Bin, but app-level restore still
    needs a preflight and may require user/manual action

  provider_recoverable
    cloud provider indicates a recycle bin/recovery window, but local app restore
    is not the authority

  manual_restore_possible
    receipt has enough metadata to guide user/manual restore, but no automatic
    safe restore is available

  tool_rebuild_or_redownload
    tool cleanup can be recovered only by rebuilding, reinstalling, redownloading,
    or recreating state

  not_restorable
    action was permanent or provider/tool declares no recovery

  unknown
    adapter outcome, platform support, provider state, or receipt evidence is
    insufficient
```

Kill criteria:

- cleanup receipt says only `success`;
- UI shows "undo" for a tool command with no restore adapter;
- cloud trash is represented as OS Trash;
- restore capability is inferred from path name;
- missing Trash location is treated as restorable.

## Cleanup Receipt Model

Receipts are the only honest bridge between cleanup and restore.

```text
CleanupReceipt
  operation_id
  delete_plan_id
  scan_snapshot_id
  rule_pack_version
  adapter_kind
  action_kind
  operation_started_at
  operation_finished_at
  preflight_summary
  items[]
  aggregate_space_effect
  warnings[]
  recovery_state
```

```text
CleanupReceiptItem
  original_selection_id
  normalized_execution_id
  original_path
  original_identity
  risk_tier
  action_attempted
  action_result
  adapter_result_code
  destination_evidence
  restore_capability
  bytes_selected
  bytes_moved
  bytes_observed_freed
  provider_effect
  tool_output_summary
  errors[]
  follow_up_required
```

Rules:

- receipt is durable before action begins and finalized after each item;
- every item has independent result;
- adapter raw errors are mapped to stable result codes;
- raw private paths are redacted in telemetry but kept locally where needed for
  restore;
- support bundles include redacted receipts by default;
- receipt version is migratable and readable after app updates.

Kill criteria:

- crash during cleanup loses what happened;
- partial success cannot be shown item-by-item;
- receipt cannot distinguish moved, deleted, skipped, failed, and unknown;
- receipt does not record the resulting Trash URL/path/item evidence;
- receipt says bytes were freed without observed free-space evidence.

## Action Kinds And Space Truth

Cleanup actions need different user promises.

```text
move_to_os_trash
  usually restorable, usually no immediate same-volume free space

run_tool_cleanup
  may free space, often no undo, recovery may mean rebuild/redownload

provider_trash_or_dehydrate
  provider-specific, may affect cloud and other devices

app_quarantine
  app-owned holding area, expensive and complex, not MVP default

permanent_delete
  not MVP default, high-friction future feature only

empty_trash
  separate destructive action, not equivalent to cleanup candidate deletion
```

Space labels:

```text
selected_bytes
  bytes represented by the selected candidates

moved_to_trash_bytes
  bytes moved into OS/provider trash

estimated_eventual_reclaim_bytes
  likely bytes after Trash/provider cleanup, with confidence

observed_free_space_delta
  actual filesystem free-space delta measured after operation

cloud_quota_effect
  provider-specific quota effect, not local disk space
```

Rules:

- do not call same-volume move-to-trash "freed";
- Google Drive Trash can still count against Drive storage until permanent
  deletion;
- OneDrive online-only deleted files may not appear in local Trash/Recycle Bin;
- tool cleanup can free local bytes but be non-restorable;
- cross-volume Trash behavior needs adapter-specific evidence;
- observed free-space delta can be noisy and should be labeled as observed, not
  promised.

Kill criteria:

- success toast says "38 GB freed" after moving files to Trash;
- cloud quota and local disk free space are added together;
- provider trash is represented as immediate local reclaim;
- "Total to reclaim" does not distinguish moved versus freed.

## Platform Restore Semantics

### macOS

Accepted rules:

- Use `FileManager.trashItem(at:resultingItemURL:)` or a native adapter that
  exposes equivalent resulting URL evidence.
- Store the resulting Trash URL in the receipt because the item name may change.
- Do not manually move files into `~/.Trash` for production semantics.
- Automatic restore is optional and must preflight original path conflicts.
- If original path now exists, do not overwrite. Require user decision.
- Cloud/File Provider locations need provider-sensitive restore messaging.

Kill criteria:

- assume original filename inside Trash;
- claim restore is guaranteed without resulting URL or receipt evidence;
- implement restore by moving arbitrary Trash path back without identity match;
- overwrite a new file at the original path.

### Windows

Accepted rules:

- Prefer `IFileOperation` with `FOFX_RECYCLEONDELETE`.
- Implement progress sink handling for per-item `hrDelete` and
  `psiNewlyCreated`.
- If `psiNewlyCreated` is null, receipt must not claim Recycle Bin restore.
- Use `FOFX_EARLYFAILURE` and no unexpected UI behavior deliberately.
- Old `SHFileOperation` is a fallback/reference only, not the primary design.
- Do not use `DeleteFile` for Trash semantics.

Kill criteria:

- treat queued `DeleteItem` as actual delete result;
- ignore per-item `hrDelete`;
- treat null `psiNewlyCreated` as restorable;
- pop Explorer/UAC dialogs from the daemon unexpectedly;
- use relative paths for shell operations.

### Linux And FreeDesktop

Accepted rules:

- Prefer FreeDesktop Trash where available.
- `.trashinfo` is authoritative for original path and deletion date.
- Trash filenames are not authoritative.
- Info file creation must be atomic where we implement the adapter directly.
- If FreeDesktop Trash is unavailable, return `trash_unsupported`, not permanent
  delete.
- Headless/server Linux defaults to analyze-only or tool cleanup unless an
  explicit trash/quarantine policy is configured.

Kill criteria:

- recover original path from Trash filename;
- ignore missing `.trashinfo`;
- silently fall back from Trash to `rm`;
- assume every Linux environment has a desktop Trash;
- use a cross-platform crate without auditing its Linux assumptions.

## Cloud Provider Restore Semantics

Cloud sync roots are not ordinary local folders.

Rules:

- provider detection lowers confidence of local restore semantics;
- cloud trash/recycle bin is provider authority, not Clean Disk authority;
- local delete can propagate to other devices;
- online-only files may have no local Trash item;
- provider recovery windows must be shown as provider-specific and time-limited;
- shared folders need ownership and permission warnings;
- cloud quota effect is separate from local disk effect.

Provider examples:

- OneDrive: personal recycle bin items are deleted after 30 days; work/school
  after 93 days unless policy changes; online-only deleted files do not appear in
  local Trash/Recycle Bin.
- iCloud Drive: iCloud.com can recover files deleted within the last 30 days,
  but permanently removed files cannot be recovered.
- Google Drive: Trash keeps items for 30 days; items in Trash still count against
  storage until permanently deleted; ownership affects access.
- Dropbox: recovery window is plan-dependent; permanent deletion is not
  recoverable; shared folder behavior depends on ownership.

Kill criteria:

- local OS Trash receipt is required for cloud-only delete;
- provider delete is shown as local undo;
- shared cloud folder delete is offered without ownership context;
- provider retention is hard-coded without capability reporting.

## App Quarantine Policy

App-owned quarantine sounds attractive but is dangerous as a default.

Risks:

- moving large data into quarantine may require extra disk space at the worst
  possible time;
- cross-volume quarantine can copy/delete instead of rename;
- metadata, ACLs, xattrs, sparse files, clones, and hardlinks can be lost or
  changed;
- encrypted/provider-managed files may not survive the move as expected;
- quarantine retention becomes a storage problem owned by Clean Disk;
- quarantine can become a hidden second Trash with worse user expectations.

Accepted policy:

- MVP does not create a generic app quarantine for arbitrary folders.
- OS Trash is the default reversible target where supported.
- Tool cleanup uses tool semantics and receipts.
- App quarantine may be considered later only for small, app-owned generated
  state or controlled test fixtures.
- If implemented later, quarantine needs a manifest, identity checks, retention
  policy, integrity checks, and restore preflight.

Kill criteria:

- app moves arbitrary multi-GB folders into its own hidden quarantine by default;
- quarantine duplicates data under low disk pressure;
- quarantine has no retention/empty policy;
- quarantine restore overwrites current user data.

## Restore Workflow

Automatic restore is a separate workflow, not an assumption.

Restore preflight:

```text
load receipt
  -> verify receipt version
  -> verify item restore capability
  -> locate trash/provider/quarantine item
  -> revalidate trash item identity when possible
  -> check original parent exists
  -> check original path conflict
  -> check permissions and available space
  -> execute restore or present manual recovery instructions
  -> write restore receipt
```

Restore states:

```text
not_requested
available
manual_only
blocked_conflict
blocked_missing_trash_item
blocked_provider_authority
blocked_permission
partial_restored
restored
failed_unknown
```

Rules:

- restore never overwrites a current file automatically;
- restore can offer "restore to alternate location" later, but MVP can defer it;
- restored items need a post-restore identity/size check where possible;
- restore receipts are separate from cleanup receipts;
- restore UI must show partial outcomes.

Kill criteria:

- cleanup receipt doubles as proof of restore success;
- restore proceeds when original path is occupied;
- missing Trash item is treated as restored;
- partial directory restore is collapsed into one success state.

## Tool Cleanup Recovery

Tool-owned cleanup often has no undo.

Rules:

- tool cleanup actions must declare recovery model:
  `rebuild`, `redownload`, `reinstall`, `provider_restore`, `none`, or `unknown`;
- receipts store command, tool version, preview summary, output summary, and
  affected roots;
- UI labels tool cleanup as cleanup, not Trash;
- high-cost rebuild/redownload is shown before execution;
- official dry-run output does not equal restore capability.

Examples:

- `cargo clean` recovery is rebuild.
- package cache cleanup recovery is redownload.
- Docker image/build-cache cleanup recovery is pull/rebuild.
- Docker volume cleanup is data destructive and should not be grouped with cache.
- Android AVD deletion is not a simple cache clear.

Kill criteria:

- "Undo" appears after `docker system prune`;
- tool cleanup receipt lacks command and version;
- rebuild/redownload cost is hidden;
- volume deletion is described as cache cleanup.

## Empty Trash Policy

Empty Trash is a separate high-risk feature.

Rules:

- not part of MVP cleanup;
- never implemented as recursive delete of Trash directories;
- requires platform-specific adapter and warning;
- must distinguish OS Trash, provider Trash, and app quarantine;
- must show that restore will no longer be available after permanent removal;
- must have a receipt but restore capability becomes `not_restorable`.

Kill criteria:

- "free now" button empties all platform Trash without scope;
- app deletes FreeDesktop `$trash/files` directly without `.trashinfo` handling;
- emptying provider trash is mixed with local cleanup queue;
- Trash cleanup bypasses user confirmation.

## Testing And Release Gates

Required fixtures:

```text
macos_trash_resulting_url_name_changed
macos_restore_conflict_blocks_overwrite
windows_recycle_psi_newly_created_present
windows_delete_full_delete_null_recycle_item
windows_shell_no_relative_paths
freedesktop_trashinfo_original_path
freedesktop_missing_trashinfo_emergency
linux_no_desktop_trash_unsupported
same_volume_trash_no_immediate_free
cloud_onedrive_online_only_no_local_trash
cloud_google_trash_counts_storage
cloud_dropbox_shared_folder_owner_warning
tool_cargo_clean_rebuild_only
tool_docker_prune_no_undo
docker_volume_blocked_not_cache
app_quarantine_low_disk_blocked
cleanup_crash_mid_operation_receipt_recovery
restore_missing_trash_item_blocks
restore_partial_directory_outcome
empty_trash_not_mvp_blocked
```

Required gates:

- receipt crash-recovery tests;
- adapter per-item result tests;
- restore capability snapshot tests;
- same-volume versus observed free-space tests;
- cloud/provider messaging tests;
- conflict-safe restore tests;
- no-overwrite invariant tests;
- no permanent delete in MVP tests;
- no generic app quarantine for large folders tests;
- support bundle redaction tests.

## MVP Cut Line

Acceptable MVP:

- move-to-OS-Trash only where platform adapter can produce reliable per-item
  outcome;
- no permanent delete;
- no empty Trash;
- no generic app quarantine;
- tool cleanup actions allowed only when they have explicit recovery model and
  receipt;
- every cleanup item has restore capability classification;
- UI wording separates moved, freed, and eventual reclaim;
- restore automation can be deferred if receipts are precise and manual recovery
  instructions are honest.

Not acceptable MVP:

- promise "undo" generically;
- claim bytes were freed after same-volume Trash move;
- treat tool cleanup as restorable;
- cloud provider deletes shown as local Trash;
- missing per-item receipt;
- fallback from Trash failure to permanent delete;
- cleanup can finish with unknown item outcomes and still say success.

## Architecture Impact

Reusable Rust `fs_usage_*` crates:

- may expose cleanup-adjacent facts and receipt value objects if kept generic;
- must not depend on Clean Disk UI wording or product policy;
- should not claim restore capability without adapter evidence.

Clean Disk Rust host:

- owns cleanup adapter composition, receipt persistence, restore capability
  classification, crash recovery, and provider/tool policy;
- exposes cleanup receipt queries and optional restore preflight APIs;
- emits cleanup/restore events with stable item IDs and redacted details.

Flutter app:

- displays action-specific verbs;
- distinguishes selected bytes, moved bytes, eventual reclaim, and observed free
  delta;
- disables restore where capability is unknown or not restorable;
- shows receipt and partial outcomes before offering further cleanup.

Persistence:

- cleanup receipt storage is durable and schema-versioned;
- restore receipts are separate records;
- receipts include enough local evidence for restore and support without leaking
  private paths into telemetry;
- migrations must keep old receipts readable.

Protocol:

- `RestoreCapability`, `ActionKind`, `ActionResult`, and `SpaceEffect` are
  explicit enums;
- unknown enum values fail closed;
- cleanup event stream reports per-item outcomes and final reconciliation;
- clients cannot infer restore from action name alone.

## Decision

The next global critical zone is restore, quarantine, undo, and cleanup receipt
safety.

Implementation should treat "undo" as a receipt-backed capability, not as a
generic property of cleanup. MVP should prefer OS Trash with precise receipts,
avoid permanent delete and empty Trash, avoid generic app quarantine, and label
tool cleanup as rebuild/redownload/none instead of restorable unless proven.
