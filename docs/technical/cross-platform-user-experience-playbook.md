# Cross-Platform User Experience Playbook

Last updated: 2026-05-16.

This document records how Clean Disk should feel for users across macOS, Windows, Linux, desktop UI, web UI, and future remote/headless mode. It complements [Permission UX playbook](permission-ux-playbook.md), but focuses on the whole product journey rather than only filesystem access.

The core decision: Clean Disk is a fast analyzer first, a conservative cleanup assistant second, and an advanced system utility only by explicit user choice.

## Sources Reviewed

- Apple Human Interface Guidelines, [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy/). Relevant points: request access only when needed, avoid launch-time prompts unless required, and explain why access is needed.
- Apple Developer Support, [Developer ID](https://developer.apple.com/support/developer-id/) and Apple Platform Security, [App code signing process in macOS](https://support.apple.com/en-ca/guide/security/sec3ad8e6e53/web). Relevant points: Developer ID signing and notarization are trust signals for direct macOS distribution.
- Google Material Design, [Permissions](https://m1.material.io/patterns/permissions.html), [Errors](https://m1.material.io/patterns/errors.html), and [Empty states](https://m1.material.io/patterns/empty-states.html). Relevant points: ask in context, provide immediate benefit, make errors recoverable, and treat empty/loading states as part of activation.
- Microsoft Learn, [Windows application development best practices](https://learn.microsoft.com/en-us/windows/apps/get-started/best-practices), [Guidelines for app settings](https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings), and [Progressive disclosure controls](https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-progressive-disclosure-controls). Relevant points: install/update/uninstall are part of UX, settings should be discoverable and searchable, and advanced details should be progressively disclosed.
- Microsoft Support, [Storage Sense](https://support.microsoft.com/en-us/windows/manage-drive-space-with-storage-sense-654f6ada-7bfc-45e5-966b-e24aded96ad5) and [Free up drive space in Windows](https://support.microsoft.com/en-us/windows/free-up-drive-space-in-windows-85529ccb-c365-490d-b548-831022bc9b32). Relevant points: automatic cleanup is conservative, Downloads/cloud content are not touched by default, and users review cleanup recommendations.
- Microsoft Support, [Storage settings in Windows](https://support.microsoft.com/en-us/windows/storage-settings-in-windows-5bc98443-0711-8038-4621-6a18ddc904f2). Relevant points: storage UX combines current usage, reserved storage, backup handoff, and cleanup automation in one settings area.
- Microsoft PC Manager, [official page](https://pcmanager.microsoft.com/en-us). Relevant point: Microsoft frames cleanup as storage management, large-file discovery, Storage Sense integration, and quiet maintenance.
- CCleaner, [Health Check](https://www.ccleaner.com/ccleaner/health-check), [Health Check support](https://support.ccleaner.com/articles/en_US/Master_Article/what-is-health-check), and [safety page](https://www.ccleaner.com/ccleaner/is-ccleaner-safe). Relevant points: simple health-check UX can coexist with advanced custom-clean controls, but defaults must avoid daily-life breakage such as removing passwords or personal context unexpectedly.
- Sparkle, [documentation](https://sparkle-project.github.io/documentation/) and [publishing updates](https://sparkle-project.github.io/documentation/publishing/). Relevant point: signed auto-updates are part of polished macOS direct distribution.
- Microsoft Learn, [MSIX auto-update and repair](https://learn.microsoft.com/en-us/windows/msix/app-installer/auto-update-and-repair--overview). Relevant point: packaged Windows apps can support managed update and repair flows.
- DaisyDisk, [Full Disk Access](https://daisydiskapp.com/guide/full-disk-access), [Hidden space](https://daisydiskapp.com/guide/4/en/HiddenSpace/), and [Scanning as administrator](https://daisydiskapp.com/guide/4/en/AdminScan/). Relevant points: partial scan is useful, hidden space is visible, and admin scan is an advanced targeted path.
- DaisyDisk, [Deleting files](https://daisydiskapp.com/guide/4/en/DeletingFiles). Relevant points: a collector/queue keeps files intact until explicit delete, blocks dangerous top-level targets, and lets users inspect/remove queued items before deletion.
- TreeSize, [scan options](https://manuals.jam-software.com/treesize/EN/scan_options.html), [scan tab](https://manuals.jam-software.com/treesize/EN/scan_tab.html), and [NTFS notes](https://manuals.jam-software.de/treesize/EN/notesonntfs.html). Relevant points: mature analyzers expose accuracy, follow-link, pause/resume, update, export, and filesystem-specific caveats.
- WinDirStat, [cleanups](https://documentation.help/WinDirStat/actions.htm) and [user-defined cleanups](https://documentation.help/WinDirStat/userdefinedcleanups.htm). Relevant points: analyzer actions include reveal, copy path, Recycle Bin delete, irreversible delete, refresh, and expert custom cleanup commands.
- GNOME Disk Usage Analyzer, [help index](https://help.gnome.org/baobab/), [scan folder](https://help.gnome.org/baobab/scan-folder.html), [error when scanning](https://help.gnome.org/baobab/problem-permissions.html), [delete folder](https://help.gnome.org/baobab/question-trash.html), and [slow scan](https://help.gnome.org/baobab/problem-slow-scan.html). Relevant points: selected-folder scans are faster, unreadable folders make results incomplete, Trash is the delete path, and speed depends on media/tree/file count.
- CleanMyMac, [safety and reliability](https://macpaw.com/support/cleanmymac/knowledgebase/cleanmymac-safety). Relevant points: cleanup tools earn trust with safety database, smart selection, personal-file exclusion, and ignore lists.
- BleachBit, [documentation](https://docs.bleachbit.org/), [general usage](https://docs.bleachbit.org/doc/general-usage.html), and [shred/wipe guidance](https://docs.bleachbit.org/doc/shred-files-and-wipe-disks.html). Relevant points: preview is explicitly safe, clean is separate, and secure erase/wipe features need strong warnings because they are slow and cannot cover backups/cloud/SSD behavior perfectly.
- Hazel, [App Sweep](https://www.noodlesoft.com/manual/hazel/hazel-basics/manage-your-trash/use-app-sweep/). Relevant points: app-support cleanup is offered after the user throws an app away, lets users uncheck leftovers, prefers vendor uninstallers when special cleanup steps may be needed, and supports restore from Trash.
- Backblaze, [macOS Full Disk Access install guide](https://help.backblaze.com/hc/en-us/articles/1260801754709-Installing-the-Backup-Client-on-Mac-for-OSX-10-14-and-Later) and [admin FDA status report](https://help.backblaze.com/hc/en-us/articles/360011389154-Which-Users-Have-Granted-Backblaze-Full-Disk-Access). Relevant points: mature agents expose permission status, prove whether the real process can read protected data, and treat external/removable volume access separately.
- Carbon Copy Cloner, [Full Disk Access for app and helper](https://bombich.com/en/kb/ccc/6/granting-full-disk-access-ccc-and-its-helper-tool). Relevant points: helper identity matters, users may need to grant access to both app and privileged helper, and privacy database confusion requires a repair/recheck workflow.
- Dropbox, [sync troubleshooting](https://help.dropbox.com/sync/files-not-syncing) and [macOS File Provider changes](https://help.dropbox.com/installs/macos-support-for-expected-changes). Relevant points: mature sync apps expose status, repair checklists, restart requirements, online-only behavior, and cloud-provider limitations.
- Apple Support, [Free up storage space on Mac](https://support.apple.com/en-us/102624), [Optimize storage space on your Mac](https://support.apple.com/en-gb/guide/mac-help/sysp4ee93ca4/mac), [iCloud Drive status](https://support.apple.com/en-euro/guide/mac-help/mchlc994344b/mac), and [Time Machine local snapshots](https://support.apple.com/en-us/ht204015). Relevant points: storage tools mix category review, large-file review, offload/remove-download, Trash, and system-managed purgeable/snapshot space that may not map to ordinary files.
- Google, [Files by Google](https://support.google.com/files/answer/9848742) and [Google Photos storage](https://support.google.com/photos/answer/10100180). Relevant points: cleanup recommendations are grouped as junk, duplicates, screenshots, large videos, and unused apps, and "free up space" can remove local backed-up content rather than delete account data.
- Dropbox, [sync icons](https://help.dropbox.com/sync/sync-icons), [online-only files](https://help.dropbox.com/sync/make-files-online-only), Google Drive, [Drive for desktop on macOS](https://support.google.com/drive/answer/12178485), Microsoft OneDrive, [Files On-Demand](https://support.microsoft.com/en-us/office/sync-files-with-onedrive-files-on-demand-62e8d748-7877-420f-b600-24b56562aa70), [OneDrive icons](https://support.microsoft.com/en-us/office/what-do-the-onedrive-icons-mean-11143026-8000-44f8-aaa9-67c985aa49b3), and Apple, [iCloud Drive Remove Download](https://support.apple.com/en-asia/guide/mac-help/mchl1a02d711/mac). Relevant points: local disk reclaim can mean dehydrate/remove-download rather than delete, placeholders may still consume small local metadata, status icons teach local/cloud/error states, and cloud delete/restore semantics differ from local Trash.
- OneDrive, [sync troubleshooting](https://support.microsoft.com/en-us/office/fix-onedrive-sync-problems-52a86836-1e7f-46fd-85c7-1e7a5e9b4273), Dropbox, [sync troubleshooting](https://help.dropbox.com/sync/files-not-syncing), and Google Drive, [fix Drive for desktop problems](https://support.google.com/drive/answer/2565956/fix-problems-with-syncing-to-your-computer-computer). Relevant points: mature desktop agents use status-specific troubleshooting, guided repair, restart/relink/cache-reset paths, and support escalation.
- Trend Micro, [Full Disk Access setup](https://helpcenter.trendmicro.com/en-us/article/TMKA-20794), Avast, [Full Disk Access](https://support.avast.com/en-ca/article/Mac-full-disk-access), Malwarebytes, [Real-Time Protection inactive](https://help.malwarebytes.com/hc/en-us/articles/31589209948059-Real-Time-Protection-inactive-on-macOS-device), and Norton, [repeated Full Disk Access prompt](https://support.norton.com/sp/en/us/home/current/solutions/v20221020120926278). Relevant points: permission state can regress after OS/app updates, multiple app/helper/extension components may need access, and repeated prompts are a known support problem.
- Flatpak, [sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html), Flathub, [modifying default permissions](https://docs.flathub.org/docs/for-users/permissions), and Snapcraft, [home](https://snapcraft.io/docs/home-interface) plus [removable media](https://snapcraft.io/docs/reference/interfaces/removable-media-interface/). Relevant points: Linux package mode changes filesystem visibility and users can inspect or override permissions.
- GNOME HIG, [Dialogs](https://developer.gnome.org/hig/patterns/feedback/dialogs.html). Relevant points: dialogs are disruptive, destructive actions need confirmation or undo, and simple non-critical errors should avoid modal interruption.
- Sentry, [scrubbing sensitive data](https://docs.sentry.dev/platforms/javascript/guides/nextjs/data-management/sensitive-data/), and Apple, [User Privacy and Data Use](https://developer.apple.com/app-store/user-privacy-and-data-use/). Relevant points: diagnostics must scrub sensitive data before it leaves the device and privacy declarations must match actual behavior.
- Electron, [code signing](https://www.electronjs.org/docs/latest/tutorial/code-signing), Tauri, [updater signing](https://tauri.app/plugin/updater/), Sparkle, [documentation](https://sparkle-project.github.io/documentation/), and Microsoft, [MSIX auto-update and repair](https://learn.microsoft.com/en-us/windows/msix/app-installer/auto-update-and-repair--overview). Relevant points: signed artifacts, signed updates, update repair, and stable identity are user-facing trust features, not only release engineering details.

## Accepted Product Direction

Top 3 product UX strategies:

1. Analyzer-first, cleanup-second, advanced-on-demand - 🎯 10 🛡️ 9 🧠 7, roughly 5000-12000 LOC across UI, Rust read model, protocol, cleanup rules, diagnostics, and packaging.

   Accepted. This is closest to DaisyDisk, TreeSize, GNOME Disk Usage Analyzer, Windows Storage, and CleanMyMac's safest patterns combined. Users see value quickly, trust grows from honest results, and dangerous operations are delayed until explicit intent.

2. Cleaner-suite-first with upfront setup and smart cleaning - 🎯 5 🛡️ 7 🧠 7, roughly 4000-10000 LOC.

   Good for maintenance suites, weaker for Clean Disk. It asks for trust before proving value and risks looking like an overreaching cleaner.

3. Minimal OS companion that delegates most cleanup to built-in tools - 🎯 6 🛡️ 8 🧠 5, roughly 2000-6000 LOC.

   Safe and easy to ship, but not enough. It would not solve the main user need: quickly see the real folder/file structure and reclaim candidates across large disks.

Accepted product contract:

```text
open app
  -> no permission wall
  -> show real analyzer surface
  -> quick target scan
  -> progressive tree/table result
  -> honest completeness
  -> conservative recommendations
  -> explicit delete plan
  -> receipt and observed result
```

## Cross-Platform User Journey

### 1. Install And Trust

Best user experience:

- macOS direct app: Developer ID signed, notarized, stable app/helper identity, app bundle name matches permission guidance.
- Windows: signed installer, visible uninstall entry, no hidden background services without explanation, optional portable read-only build later.
- Linux: native packages or AppImage for full scanner; Flatpak/Snap clearly marked as reduced-capability builds.
- Web UI: daemon-served local UI by default, with local token and local-only binding.

UX rules:

- never ask users to disable OS security;
- never ship production scanner as a random external `pdu` binary;
- update mechanism must keep app/helper identity stable;
- if an update changes daemon/protocol compatibility, show a repair/restart state instead of silent failure;
- uninstall should remove app components and offer to keep/delete scan cache and receipts.

### 2. First Launch

Best user experience:

```text
real app frame
  -> target selector
  -> recent scans or empty tree/table placeholder
  -> Scan button
  -> small capability status
  -> no modal setup
```

Rules:

- first-launch empty state is actionable: `Scan Downloads`, `Choose Folder`, `Scan Home`.
- do not show a "grant access" wizard first;
- do not explain architecture or daemon internals in the main surface;
- if daemon is not running, show a repair card with `Start service`, `Retry`, and logs redaction note.

### 3. Scan Start

Best user experience:

```text
user picks target
  -> fast preflight
  -> quality badge
  -> scan starts or user chooses scan quality
```

Scan quality labels:

```text
Complete
May be partial
Needs access
Advanced
Unavailable
Checking
```

Rules:

- `Downloads` and custom selected folder should usually start without broad prompts;
- Home/full disk can show `Scan anyway` plus `Improve access`;
- advanced authority is never the default button;
- network/removable/cloud targets show slower/limited labels before scan.

### 4. During Scan

Best user experience:

- progress visible but not noisy;
- current path is visible and ellipsized;
- pause/cancel works predictably;
- result tree can progressively appear when safe;
- errors become grouped scan issues, not modal spam.

Status model:

```text
scanning
indexing
partial_results_available
paused
canceling
completed
completed_partial
failed_recoverable
failed_blocked
```

Rules:

- progress events are throttled;
- "files scanned" is not the same as completion if post-indexing is still running;
- large scan must keep UI interactive;
- battery/thermal/background mode can reduce scan pressure.

### 5. Results

Best user experience:

```text
summary cards
  -> largest folders
  -> tree/table
  -> details panel
  -> skipped/protected banner
  -> cleanup candidates
```

Rules:

- big folders and files are visible before cleanup;
- selected row shows path, modified, permissions, item counts, warnings;
- every result has completeness metadata;
- hidden/protected/skipped must be visible, not hidden in `Other`;
- search/top files/sort/filter are query-backed, not full-tree in Flutter.

### 6. Cleanup

Best user experience:

```text
candidate found
  -> evidence and risk tier
  -> user adds to queue
  -> delete plan revalidates identity
  -> move to Trash
  -> receipt
  -> observed free-space delta later
```

Risk tiers:

```text
Safe
Review
Risky
Unsupported
```

Rules:

- only generated cache/log/temp data can be auto-selected;
- personal files, Downloads, cloud placeholders, projects, app data stores, Docker volumes, Xcode Archives, SDKs, and unknown tool folders are not auto-selected;
- Trash is default, permanent delete is not MVP default;
- delete plan must show stale-scan risk;
- receipt must record what happened, what failed, and what still needs manual action.

### 7. Cloud, File Provider, And Sync Roots

Best user experience:

- cloud roots are labeled before scan;
- local bytes and logical bytes are separate;
- online-only placeholders are not hydrated by scan;
- delete copy explains cloud propagation;
- sync pause/error states lower reclaim confidence.

UI labels:

```text
Local
Cloud-only
Available offline
Provider-managed
May download if opened
Delete may sync to cloud
```

Rules:

- never promise local reclaim from cloud placeholder deletion unless local allocated bytes are proven;
- never scan by opening file contents;
- treat provider root moves/deletes as higher-risk until provider behavior is known.

### 8. Repair And Diagnostics

Best user experience:

```text
problem detected
  -> clear user label
  -> exact affected capability
  -> exact component identity
  -> action
  -> re-check
  -> redacted diagnostic export
```

Rules:

- diagnostics never include raw full scan trees by default;
- raw paths are redacted unless user explicitly includes them;
- daemon token, auth headers, search text, delete target paths, and cloud account IDs are never exported;
- crash reports and metrics must scrub sensitive data before upload;
- support bundle has preview before export.

### 9. Updates And Compatibility

Best user experience:

- app updates are signed;
- daemon/helper update is coordinated with UI;
- old UI cannot silently talk to incompatible daemon;
- users see a simple "Restart to finish update" state when needed.

Rules:

- daemon API has version negotiation;
- event protocol compatibility is checked at startup;
- partial update state is recoverable;
- update must not reset permission guidance or cached scan history accidentally.

### 10. Enterprise And Remote

Best user experience:

- consumer app stays simple;
- admin/policy status is visible only when relevant;
- remote/headless defaults to read-only scan;
- destructive remote cleanup is later and requires stronger auth/audit.

Rules:

- MVP vocabulary includes `policyBlocked`, `packageLimited`, `remoteReadOnly`, `adminRequired`;
- fleet reporting is later;
- managed PPPC/Intune/GPO docs are later;
- remote mode shares protocol concepts but has separate threat model.

## Deeper Benchmark Findings

This round looked less at "what permission is technically required" and more at what makes users trust a cross-platform disk utility in practice.

### 1. Trust Comes From A Repeated Proof Loop

Accepted approach: scan/proof/repair/recheck loop - 🎯 10 🛡️ 9 🧠 7, roughly 1800-4200 LOC across capability probes, repair cards, status DTOs, and UI state.

Top products do not rely on "please trust us" copy alone:

- DaisyDisk proves partial scan value first, then explains hidden space and offers access improvement;
- Backblaze reports whether the real backup agent has Full Disk Access, not whether a settings page looks correct;
- Carbon Copy Cloner documents that helper identity can differ from app identity, so repair must verify the helper too;
- Dropbox/Google Drive/OneDrive expose sync/provider status and repair flows because cloud file state is not obvious from path alone.

Clean Disk implication:

```text
show result
  -> show scan quality
  -> show skipped/protected groups
  -> offer improve access only where useful
  -> re-probe from scanner process
  -> rescan or refresh affected areas
  -> show what changed
```

The app should never say `Access granted` purely because the user clicked an instruction. It should say `Verified`, `Still limited`, or `Unavailable` based on a real scanner-process probe.

### 2. Cleanup Needs A Two-Step Mental Model

Accepted approach: analyzer selection first, delete plan second - 🎯 10 🛡️ 10 🧠 8, roughly 2200-6000 LOC.

Common product pattern:

- DaisyDisk uses a Collector so files remain intact until final delete;
- BleachBit separates Preview from Clean and explicitly treats preview as safe;
- Hazel App Sweep appears only after the user throws an app away and lets them uncheck leftovers;
- CleanMyMac smart selection excludes personal files by default and uses safety/ignore data;
- Windows Storage and PC Manager frame cleanup as categories/recommendations, not raw recursive deletion.

Clean Disk implication:

- selecting a row in the tree never means "will be deleted";
- adding to queue means "candidate";
- DeletePlan is a separate generated artifact with reasons, risk, identity, and reclaim confidence;
- `Move to Trash` is the default destructive action;
- permanent delete, shredding, wipe-free-space, and system-tool cleanup are advanced adapters, not the first workflow.

### 3. Dehydrate Is Not Delete

Accepted approach: separate local reclaim actions from delete actions - 🎯 9 🛡️ 9 🧠 8, roughly 1600-4800 LOC.

Cloud products show that "free up space" often means removing a local download while preserving the cloud item. This is different from moving a file to Trash and different again from deleting it from the cloud account.

Clean Disk action taxonomy:

```text
Reveal
Move to Trash
Remove local download
Use provider cleanup action
Run official tool cleanup
Ignore
Export path/report
```

Rules:

- cloud roots show provider and locality before recommendations;
- online-only placeholders are not counted as reclaimable local bytes except for proven allocated metadata;
- deleting from a sync root must warn that it may propagate to cloud;
- provider-specific actions such as `Remove Download` are separate from `Move to Trash`;
- scan should not hydrate cloud placeholders just to compute size.

### 4. The Best UX Is Mode-Aware, Not Platform-Agnostic

Accepted approach: one product model with platform/package capability badges - 🎯 9 🛡️ 9 🧠 7, roughly 1600-4000 LOC.

Top-company pattern:

- Apple and Microsoft make privacy/security status visible in system settings;
- Flatpak/Snap intentionally change filesystem visibility;
- MSIX and Sparkle make update/repair part of the product lifecycle;
- Backblaze and CCC show that helper/daemon identity matters on macOS.

Clean Disk implication:

- same Flutter UI, but capability cards differ by `platform`, `packageMode`, `scannerIdentity`, and `scanTarget`;
- direct signed app is the primary full-power desktop path;
- Flatpak/Snap/Web/remote never promise the same authority as direct desktop builds;
- Permission Doctor must show the exact process/bundle/helper that needs access.

### 5. Advanced Power Must Be Discoverable But Contained

Accepted approach: progressive disclosure for power-user controls - 🎯 9 🛡️ 8 🧠 7, roughly 1200-3500 LOC.

TreeSize, WinDirStat, BleachBit, and CCleaner all show the same split: simple scan/clean path for normal users, advanced knobs for people who understand the consequences.

Clean Disk advanced controls:

- scan boundaries: same filesystem, mount points, symlinks/reparse points, hidden/protected folders;
- accounting mode: logical, allocated, exclusive estimate, observed delta;
- performance mode: background, balanced, fast;
- cleanup adapters: official tool action, provider dehydrate, Trash, permanent delete later;
- exports: safe summary by default, raw path export only explicit.

Default UI should be dense and professional, but advanced filesystem caveats should be expandable, not dumped on first-run users.

## Best Cross-Platform User Flow

The strongest product flow after this research:

1. User opens the app and sees scan targets, recent scans, and a real empty state, not a setup wizard.
2. The app suggests `Downloads`, `Home`, current disk, and `Custom Folder`.
3. Before scan, target badges show `Fast`, `May be partial`, `External`, `Cloud`, or `Advanced`.
4. Scan starts immediately for available paths and streams progress.
5. Results show tree/table first, with skipped/protected groups visible but not modal.
6. Details panel explains selected item, local bytes, item count, modified time, warnings, and suggested action.
7. Cleanup candidates are added to a queue, not deleted inline.
8. DeletePlan revalidates path identity, classifies risk, estimates reclaim confidence, and shows cloud/provider consequences.
9. Trash/provider action runs and returns a receipt with observed free-space delta when measurable.
10. Permission Doctor stays available for users who want more complete scans.

This is more user-friendly than a classic first-run permission wizard because it gives value before asking for broad authority.

## Top-Company Rules For Clean Disk

1. Ask for access only after visible user intent.
2. Prefer selected-folder access over global authority when it solves the user task.
3. Show partial results honestly instead of blocking work.
4. Verify permission from the same process that scans.
5. Treat helper/daemon identity as user-visible diagnostics.
6. Separate Preview, Queue, DeletePlan, and Execution.
7. Use Trash/provider actions by default.
8. Do not auto-select personal files, Downloads, cloud placeholders, project folders, app data stores, Docker volumes, SDKs, or unknown tool-managed folders.
9. Use official cleanup commands/adapters for tool-managed storage where available.
10. Separate delete from dehydrate/remove-download.
11. Never promise exact reclaimed bytes without observed or high-confidence evidence.
12. Keep advanced modes discoverable, but never make them the default route to value.
13. Support repair/recheck instead of only linking to settings.
14. Make install/update/uninstall part of UX, with stable signed identity.
15. Redact paths/tokens/searches before diagnostics leave the machine.

## User Convenience Patterns From Top Products

This pass focused on "what feels convenient" rather than only "what is safe".

### 1. Recommendation Cards Beat Raw Cleanup Lists

Accepted approach: category-backed recommendation cards plus tree drill-down - 🎯 10 🛡️ 9 🧠 7, roughly 2200-5200 LOC.

Apple Storage, Windows Cleanup recommendations, Files by Google, Google Photos, and Microsoft PC Manager all put users into recognizable categories before asking them to delete anything. Raw paths are still available, but the first decision is usually:

```text
Temporary files
Large files
Duplicates
Downloads
Screenshots
Unused apps
Synced cloud files
Trash / Recycle Bin
Developer caches
```

Clean Disk should keep the folder tree as the main power surface, but the right/summary areas should expose recommendation cards with:

- reason: why this is shown;
- risk: `Safe`, `Review`, `Risky`, `Unsupported`;
- action: `Review`, `Add to Queue`, `Remove Download`, `Reveal`;
- evidence: size, age, file count, provider/tool owner;
- confidence: reclaim estimate quality.

This gives normal users a shorter path while keeping expert tree navigation.

### 2. Status Icons Are A Better Language Than Long Explanations

Accepted approach: compact status badges with tooltip/details drawer - 🎯 9 🛡️ 9 🧠 6, roughly 900-2400 LOC.

Dropbox, OneDrive, iCloud Drive, and Google Drive train users with repeated status markers: synced, online-only, available offline, syncing, paused, error, ignored, provider-managed.

Clean Disk should use the same idea for disk scanning:

```text
Complete
Partial
Protected
Skipped
Cloud-only
Available offline
Provider-managed
External
Network
Changing
Stale
Queued
Trash-ready
```

Rules:

- badges are visible in tree rows and details panel;
- tooltips explain the short label;
- grouped issue drawer explains many repeated issues once;
- status labels are queryable/filterable;
- badges must never imply a file is safe to delete.

### 3. Repair UX Should Be A Checklist, Not A Paragraph

Accepted approach: guided repair cards with measurable checks - 🎯 9 🛡️ 9 🧠 7, roughly 1400-3600 LOC.

OneDrive, Dropbox, Google Drive, Backblaze, CCC, Trend Micro, Avast, Malwarebytes, and Norton all show the same pain: users can follow instructions and still be stuck because sync, permissions, helpers, extensions, and OS updates change state.

Clean Disk repair cards should be structured like this:

```text
Problem
Affected feature
Detected component
Why it matters
Action
Re-check
Last checked
Fallback
```

Examples:

```text
Full Disk Access missing
Component: Clean Disk Scanner Helper
Action: Open System Settings
Re-check: run protected-folder probe
Fallback: scan selected folders only
```

```text
Cloud provider busy
Component: OneDrive
Action: reveal provider status
Re-check: refresh local/cloud metadata
Fallback: avoid provider cleanup actions
```

### 4. Updates Must Preserve Trust And Capability

Accepted approach: signed update plus capability revalidation after update - 🎯 9 🛡️ 9 🧠 8, roughly 1600-4200 LOC.

Electron, Tauri, Sparkle, and MSIX documentation all point to the same product truth: unsigned or identity-changing updates break trust. Security/backup apps also show that macOS permission prompts can reappear after OS or app updates.

Clean Disk update UX:

- signed app and signed updater artifacts;
- daemon/helper version compatibility check;
- post-update scanner identity re-check;
- Permission Doctor shows `Changed after update` if capability regressed;
- protocol mismatch shows `Restart required` or `Update required`, not silent errors;
- release notes should mention scanner/helper permission changes when relevant.

### 5. Low-Space Mode Must Avoid Making The Problem Worse

Accepted approach: low-space operating mode - 🎯 9 🛡️ 9 🧠 8, roughly 1200-3200 LOC.

Storage tools exist because users are already low on disk. The app must not create a large cache, hydrate cloud files, generate massive logs, or download updates while trying to help.

Low-space mode rules:

- scanner cache has a strict size budget;
- logs rotate aggressively and avoid raw paths;
- update downloads are paused or require explicit confirmation when free space is critical;
- scan result persistence can be summary-only if disk is too low;
- provider placeholders are never opened to inspect contents;
- large support bundles need preview and size warning;
- cleanup receipt is kept even if scan cache is discarded.

### 6. Native Surface Matters More Than Perfect Uniformity

Accepted approach: shared product model, platform-native affordances - 🎯 9 🛡️ 8 🧠 8, roughly 2000-6000 LOC.

The same app should feel like Clean Disk everywhere, but not ignore platform habits:

- macOS: Finder reveal, Quick Look later, menu bar conventions, FDA repair, Trash language;
- Windows: Explorer reveal, Recycle Bin language, UAC/elevation as advanced, Storage Sense handoff, signed installer;
- Linux: file manager reveal, Trash where available, package-mode warning, Flatpak/Snap permission explanation;
- web UI: daemon status, target picker, local/remote connection state, no fake browser disk scan promise.

This means design tokens and workflow are shared, while platform labels, icon affordances, and repair steps are adapter-driven.

## Product UX Invariants

These are now hard product rules:

1. The first useful action is always a scan, not setup.
2. The first scan must work in at least one low-friction target.
3. Every incomplete result has a visible reason and repair path.
4. Every cleanup recommendation has evidence and risk.
5. Every destructive action has a DeletePlan and receipt.
6. Every cloud/provider action distinguishes local bytes from account data.
7. Every permission repair is verified by the real scanner/helper process.
8. Every package mode reports what it can and cannot promise.
9. Every update preserves or revalidates scanner identity and protocol compatibility.
10. Every diagnostic export is previewable and redacted by default.

## Platform Defaults

| Platform | Primary distribution | First scan | Full/advanced path | Cleanup default |
| --- | --- | --- | --- | --- |
| macOS | Developer ID signed, notarized direct app | Downloads or selected folder | FDA/rescan, later admin read-only profile | Trash, revalidate identity |
| Windows | Signed installer | User folders or selected folder | Advanced NTFS/MFT/admin read-only profile later | Recycle Bin, revalidate identity |
| Linux native | AppImage/deb/rpm | Home/Downloads/selected folder | root/system read-only profile later | Trash where supported |
| Linux Flatpak | Reduced-capability package | portal-selected folder | package permission help, no full-host promise | Trash where portal/package allows |
| Linux Snap strict | Reduced-capability package | visible home files or selected folder | interface guidance, no full-host promise | Trash where package allows |
| Web UI | daemon-served local UI | daemon target picker | daemon capability state | daemon delete plan |
| Remote/headless | server deployment | read-only scoped targets | admin policy later | disabled by default |

## UX Architecture Implications

Flutter needs:

- first-run actionable empty state;
- scan target cards with quality badges;
- progressive scan status strip;
- virtualized tree/table;
- details panel;
- skipped/protected drawer;
- risk-tier cleanup queue;
- delete-plan confirmation and receipt;
- Permission Doctor;
- diagnostics preview/export;
- package-mode and daemon-status surfaces.

Rust/server needs:

- capability preflight endpoint;
- scan profile model;
- session state machine;
- paginated read model;
- grouped issue model;
- cloud/provider metadata enrichment;
- delete-plan preflight;
- receipt persistence;
- daemon version negotiation;
- redacted diagnostics bundle.

Protocol needs:

- stable DTOs for package mode, scan quality, scan profile, issue groups, cloud locality, risk tier, delete plan, receipt, and diagnostics export;
- no raw filesystem internals leaking into UI state;
- no full-tree transfer to Flutter;
- clear operation IDs and idempotency keys for scan/delete/retry.

## MVP User Experience Scope

Ship in MVP:

1. First useful scan with no permission wall - 🎯 10 🛡️ 9 🧠 5, roughly 900-2200 LOC.
2. Progressive scan quality and partial-result UX - 🎯 10 🛡️ 9 🧠 6, roughly 1200-3200 LOC.
3. Virtualized tree/table with details and grouped skipped issues - 🎯 9 🛡️ 9 🧠 8, roughly 2500-6500 LOC.
4. Conservative cleanup queue with Trash-only delete plan - 🎯 10 🛡️ 10 🧠 8, roughly 2200-6000 LOC.
5. Permission Doctor and daemon repair cards - 🎯 9 🛡️ 9 🧠 7, roughly 1200-3600 LOC.
6. Package-mode capability detection - 🎯 9 🛡️ 9 🧠 7, roughly 1000-2800 LOC.

Do not ship as MVP default:

1. auto-cleanup schedules - 🎯 4 🛡️ 5 🧠 8.
2. permanent delete as primary action - 🎯 2 🛡️ 3 🧠 4.
3. Windows MFT/admin as default - 🎯 5 🛡️ 6 🧠 8.
4. macOS admin/root scan as default - 🎯 4 🛡️ 5 🧠 9.
5. Flatpak/Snap "full disk" promise - 🎯 2 🛡️ 3 🧠 7.
6. hosted web page connecting to localhost daemon by default - 🎯 4 🛡️ 5 🧠 8.
7. remote destructive cleanup - 🎯 3 🛡️ 4 🧠 9.

## Product Copy Rules

Use:

```text
Scan may be partial
Some protected folders were skipped
Scan anyway
Improve access
Re-check access
Move to Trash
Review before deleting
Local bytes
Observed free space change
```

Avoid:

```text
Grant full access to continue
Run as administrator for best results
Safe to delete everything
100% freed
Unknown error
Other
Cleaner magic
```

## Final Decision

Clean Disk should feel like:

```text
DaisyDisk/TreeSize-level analyzer clarity
+ Windows/Apple-style cleanup review
+ CleanMyMac-style safety tiers without aggressive trust asks
+ Dropbox/Google Drive-style repair/status cards
+ direct signed desktop-app trust model
+ Rust-daemon scale and web/desktop protocol reuse
```

The default product promise is not "we can delete stuff for you." The default product promise is "we show what uses your disk, how complete the result is, and what can be reclaimed safely."
