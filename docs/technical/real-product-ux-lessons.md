# Real Product UX Lessons

Last updated: 2026-05-16.

This document records product lessons from launched storage, cleanup, sync, backup, and disk analyzer tools. The goal is to copy proven user-facing patterns without copying unsafe behavior.

## Sources Reviewed

- Apple Support, [Free up storage space on Mac](https://support.apple.com/en-us/ht206996), [Optimize storage space](https://support.apple.com/guide/mac-help/sysp4ee93ca4/mac), [iCloud Drive remove downloads](https://support.apple.com/guide/mac-help/mchl1a02d711/mac), [Time Machine local snapshots](https://support.apple.com/en-us/ht204015).
- Microsoft Support, [Storage Sense](https://support.microsoft.com/en-us/windows/manage-drive-space-with-storage-sense-654f6ada-7bfc-45e5-966b-e24aded96ad5), [OneDrive Files On-Demand](https://support.microsoft.com/en-us/office/sync-files-with-onedrive-files-on-demand-62e8d748-7877-420f-b600-24b56562aa70), and Microsoft PC Manager [service terms](https://pcmanager.microsoft.com/en-us/termsofservice).
- Google Support, [Files by Google](https://support.google.com/files/answer/9848742), [Drive for desktop stream/mirror](https://support.google.com/drive/answer/13401938).
- Dropbox Help, [online-only files](https://help.dropbox.com/sync/make-files-online-only), [sync icons](https://help.dropbox.com/sync/sync-icons), [macOS sync icons](https://help.dropbox.com/sync/macos-sync-icons).
- DaisyDisk Guide, [Deleting files](https://daisydiskapp.com/guide/4/en/DeletingFiles), [What is safe to delete](https://daisydiskapp.com/guide/4/en/WhatToDelete/), [Local APFS snapshots](https://daisydiskapp.com/guide/4/en/Snapshots/).
- WizTree, [official product page](https://diskanalyzer.com/), [FAQ](https://diskanalyzer.com/faq), [what's new](https://diskanalyzer.com/whats-new).
- TreeSize Manual, [filter types](https://manuals.jam-software.de/treesize/EN/availablefiltertypes.html), [process search results](https://manuals.jam-software.de/treesize/EN/process_search_results.html), [disk usage comparison](https://manuals.jam-software.de/treesize/EN/disk_usage_comparison.html), [command line options](https://manuals.jam-software.de/treesize/EN/command_line_opt.html).
- WinDirStat Documentation, [Directory List](https://documentation.help/WinDirStat/directorytree.htm), [Cleanups](https://documentation.help/WinDirStat/actions.htm), [User Defined Cleanups](https://documentation.help/WinDirStat/userdefinedcleanups.htm), [Configuration](https://documentation.help/WinDirStat/configuration.htm).
- CleanMyMac, [Smart Care](https://macpaw.com/support/cleanmymac/knowledgebase/smart-care), [safety and reliability](https://macpaw.com/support/cleanmymac/knowledgebase/cleanmymac-safety).
- CCleaner, [Health Check](https://www.ccleaner.com/ccleaner/health-check), [what Health Check does](https://support.ccleaner.com/articles/en_US/Master_Article/what-does-health-check-do), [is CCleaner safe](https://www.ccleaner.com/ccleaner/is-ccleaner-safe).
- BleachBit, [general usage](https://docs.bleachbit.org/doc/general-usage.html), [expert mode](https://docs.bleachbit.org/doc/expert-mode.html), [preferences](https://docs.bleachbit.org/doc/preferences.html), [command line interface](https://docs.bleachbit.org/doc/command-line-interface.html).
- Hazel, [App Sweep](https://www.noodlesoft.com/manual/hazel/hazel-basics/manage-your-trash/use-app-sweep/).
- Backblaze Help, [send logs to support](https://help.backblaze.com/hc/en-us/articles/14750819976731-How-to-send-logs-to-Backblaze-Mac), [restore options](https://www.backblaze.com/cloud-backup/features/restore).
- Malwarebytes Help, [Real-Time Protection inactive on macOS](https://help.malwarebytes.com/hc/en-us/articles/31589209948059-Real-Time-Protection-inactive-on-macOS-device).

## Product Archetypes

Real products split into six useful archetypes:

1. OS storage assistants: Apple Storage, Windows Storage Sense, Microsoft PC Manager, Files by Google.

   Strength: simple categories, conservative defaults, OS-native language, low-space awareness.

   Weakness: not enough deep tree navigation for power users.

2. Disk analyzers: DaisyDisk, TreeSize, WizTree, WinDirStat.

   Strength: fast discovery, tree/table/treemap, top files, manual control.

   Weakness: they can push responsibility to the user when cleanup gets risky.

3. Cleaning suites: CleanMyMac, CCleaner, BleachBit.

   Strength: recommendation categories, preview/analyze before cleaning, safety databases, expert modes.

   Weakness: trust can degrade if recommendations feel opaque, aggressive, or marketing-heavy.

4. Cloud sync clients: OneDrive, Dropbox, iCloud Drive, Google Drive for desktop.

   Strength: clear local-vs-cloud states, online-only actions, sync status, restore paths.

   Weakness: delete semantics are easy to misunderstand and can propagate across devices.

5. Backup/security utilities: Backblaze, Carbon Copy Cloner, Malwarebytes, Norton/Avast/Trend Micro.

   Strength: permission repair, process identity checks, support bundles, restore/diagnostic language.

   Weakness: first-run permission walls can feel heavy for analyzer-style apps.

6. Admin/reporting tools: TreeSize Professional, BleachBit CLI, Windows scheduled tasks, enterprise PC cleanup tools.

   Strength: scheduling, export, historical comparison, headless runs, reports.

   Weakness: advanced automation can be unsafe if exposed as ordinary consumer UX.

## Accepted Direction

Top 3 product direction options:

1. Hybrid analyzer plus conservative cleaner - 🎯 10 🛡️ 10 🧠 8, roughly 9000-22000 LOC.

   Accepted. Use DaisyDisk/TreeSize/WizTree style exploration for finding space, then CleanMyMac/BleachBit/Storage Sense style safety for cleanup. This means tree/table is the power surface, recommendations are evidence-backed shortcuts, and deletion goes through queue, preview, DeletePlan, execution, and receipt.

2. Cleaner-first assistant - 🎯 7 🛡️ 8 🧠 6, roughly 6000-15000 LOC.

   Easier for casual users, but weaker for the core product promise: quickly seeing exactly which folders/files occupy disk space. It risks feeling like another opaque cleaner.

3. Pure analyzer with manual cleanup - 🎯 7 🛡️ 7 🧠 5, roughly 4000-10000 LOC.

   Simpler and safer, but leaves too much work on the user. It would miss recommendation cards, cleanup queue, tool-managed storage, cloud actions, and recovery receipts.

## Adopted Product Lessons

### 1. Home Should Show Value Before Asking For Authority

What real products do:

- Apple and Windows start from storage categories and recommendations, not a permission lecture.
- DaisyDisk starts from disks/folders and still works partially when access is limited.
- Security/backup tools ask for broad permission only when the protected feature cannot work without it.

Clean Disk decision:

- default first action is `Scan Downloads` or `Choose Folder`;
- full disk scan is visible but marked with scan-quality/capability badges;
- Permission Doctor is available from warnings, not a first-launch wall;
- daemon/helper status appears only when it affects the current action.

### 2. Scan Results Must Combine Tree, Top Lists, And Visual Cues

What real products do:

- WinDirStat and TreeSize make the size-sorted tree central.
- WizTree uses speed and a linked tree/treemap/file view to locate large items quickly.
- DaisyDisk uses a visual map to make discovery feel immediate.

Clean Disk decision:

- central workflow is still the virtualized tree/table;
- top files, top folders, extension breakdown, and chart views are projections over the same Rust read model;
- selection in a visual view must sync back to the tree/details panel;
- charts never become a separate source of truth.

### 3. The Cleanup Model Must Be Preview-First

What real products do:

- DaisyDisk has a Collector: items remain intact until the final Delete action.
- BleachBit explicitly tells users to Preview, review files, adjust choices, and only then Delete.
- CCleaner uses Analyze/Health Check before cleaning.

Clean Disk decision:

- selection is not deletion;
- Add to Queue is not deletion;
- DeletePlan is generated after queue selection;
- final execution shows action type, counts, risk, confidence, restore capability, and stale-item checks;
- permanent delete is not a primary action.

### 4. Safety Is A Product Feature, Not Just A Warning Dialog

What real products do:

- CleanMyMac relies on a safety database, smart selection, and ignore lists.
- BleachBit separates normal mode from expert mode and filters protected options by default.
- DaisyDisk blocks system roots from its Collector and tells users to use official UIs for app libraries/backups.

Clean Disk decision:

- recommendations need evidence, category, risk tier, confidence, and why-shown text;
- only high-confidence generated cache/log/temp data can be auto-selected;
- unknown large folders, projects, cloud roots, app libraries, SDKs, Docker volumes, package stores, browser profiles, and user documents stay Review/Risky;
- ignore list and rule versioning are required before broad recommendation expansion.

### 5. Cloud Files Need Their Own Vocabulary

What real products do:

- OneDrive and Dropbox expose online-only, locally available, always available/offline, syncing, paused, and error states.
- OneDrive distinguishes `Free up space` from deletion and explains provider recycle bin behavior.
- Dropbox warns that online-only files may still need local space when opened.
- iCloud exposes `Remove Download` for local copies.

Clean Disk decision:

- local allocated bytes, logical cloud bytes, provider status, and delete propagation are separate UI facts;
- `Remove local download` is not `Move to Trash`;
- online-only files are not reclaim candidates unless they consume local bytes;
- scanning must not open/hydrate cloud placeholders;
- provider restore/recycle semantics are shown per provider.

### 6. Reclaim Estimates Must Be Honest

What real products do:

- DaisyDisk explains that free space may not increase immediately because local snapshots can retain deleted data.
- OneDrive/Dropbox distinguish local placeholder space from cloud object size.
- WizTree highlights allocated size and hardlink correctness as a core accuracy feature.

Clean Disk decision:

- show logical size, allocated local size, exclusive reclaim estimate, quota effect, confidence, and observed free-space delta separately;
- never claim exact freed bytes unless observed or proven;
- snapshots, clones/reflinks, hardlinks, dedupe, sparse/compressed files, cloud placeholders, open files, and Trash behavior reduce confidence;
- receipt should show expected reclaim vs observed delta when measured.

### 7. Search, Filter, And Bulk Operations Need Server-Side State

What real products do:

- TreeSize exposes rich filters: file type, content, path length, hardlinks, file/folder counts, depth, dates, attributes, metadata.
- TreeSize lets users check multiple search results by rules.
- WinDirStat exposes actions from menu, toolbar, and keyboard shortcuts.

Clean Disk decision:

- search/filter/sort runs in Rust over indexes;
- bulk selection over `all query results` creates a server-side `SelectionSetId`;
- UI must say whether selection applies to visible rows, current page, expanded subtree, or all query results;
- every bulk action is previewable and returns grouped outcomes;
- command availability data feeds toolbar, context menu, shortcuts, and details panel.

### 8. History, Compare, And Reports Are Power Features, Not MVP Clutter

What real products do:

- TreeSize compares current scans with saved XML scans or filesystem snapshots.
- TreeSize Professional supports CLI exports, scheduled scans, top-file reports, treemaps, XML, CSV, Excel, HTML, PDF, SQLite, and event-log errors.
- WinDirStat can generate owner reports for network/shared drives.

Clean Disk decision:

- MVP persists summaries and receipts first;
- saved scans are immutable snapshots for review, comparison, and reports;
- compare is post-MVP and must label confidence when matching by path/name instead of stable identity;
- export is an operation with redaction level, progress, cancellation, and receipt;
- reports default to redacted paths.

### 9. Automation Must Start Conservative

What real products do:

- Storage Sense automates low-risk temporary cleanup and only touches Downloads/cloud content when configured.
- TreeSize scheduled scans generate reports and run later, often for admins.
- BleachBit CLI separates preview and clean.
- Hazel automates rules, but its domain is explicit folder automation configured by the user.

Clean Disk decision:

- MVP automation means reminders, scan profiles, and maybe scheduled reports;
- scheduled cleanup starts as scheduled preview only;
- destructive automation is advanced/admin and must require explicit policy, dry-run, receipt, and safe category limits;
- automation respects Low-space mode, battery, thermal, network, and package permissions.

### 10. Permissions And Repair Should Be A Checklist With Proof

What real products do:

- Backblaze and Carbon Copy Cloner document Full Disk Access for the app/helper identity.
- Malwarebytes explains that Real-Time Protection is inactive until the correct macOS permission is granted.
- Norton/Avast/Trend Micro support docs show repeated permission prompts are a real product-support problem.

Clean Disk decision:

- repair cards show affected feature, component identity, detected state, action, re-check, fallback, and support export;
- re-check must run in the scanner/helper process, not in Flutter;
- opening System Settings is not proof;
- package mode and app/helper identity are capability facts.

### 11. Diagnostics Need Redaction By Default

What real products do:

- Backblaze has support log workflows.
- Microsoft PC Manager documents local processing vs data sent to servers.
- Cleaner/security tools emphasize privacy and trust because they inspect sensitive local data.

Clean Disk decision:

- support bundle is previewable;
- default bundle redacts usernames, raw paths, search text, delete targets, tokens, auth headers, and full trees;
- bundle includes app version, daemon version, package mode, scan profile, capability probes, grouped errors, and issue counts;
- user can opt into selected path inclusion for a specific support case.

### 12. Expert Mode Is Useful But Must Be Isolated

What real products do:

- BleachBit Expert mode relaxes guardrails but keeps normal users protected.
- WinDirStat user-defined cleanups are powerful but command-line based and expert-oriented.
- TreeSize Professional has simple/normal/expert UI levels.

Clean Disk decision:

- ordinary mode never exposes raw permanent delete, arbitrary scripts, or unsafe tool cleanup;
- advanced mode can expose more details, but destructive guardrails remain unless explicit future policy says otherwise;
- expert settings are grouped, searchable later, and resettable;
- every expert bypass is logged locally in a receipt/audit trail.

## UX Patterns To Copy Directly

| Product pattern | Source products | Clean Disk adaptation |
| --- | --- | --- |
| Category cards for easy start | Apple Storage, Storage Sense, Files by Google, CCleaner | Recommendation cards with evidence/risk/confidence |
| Tree/table sorted by size | TreeSize, WinDirStat, WizTree | Primary virtualized Rust-backed tree/table |
| Visual map as accelerator | DaisyDisk, WinDirStat, WizTree | Supporting chart linked to selected node |
| Collector/queue | DaisyDisk | Delete queue with previewable DeletePlan |
| Preview before destructive clean | BleachBit, CCleaner | Required preview for cleanup and automation |
| Safety database/rule set | CleanMyMac, CCleaner | Versioned recommendation rules and ignore list |
| Expert mode | BleachBit, TreeSize | Advanced settings without weakening default safety |
| Online-only/local status | OneDrive, Dropbox, iCloud, Drive | ProviderStatus and local-vs-cloud actions |
| Historical comparison | TreeSize | Saved scans and compare after MVP |
| Scheduled reports | TreeSize Pro, Storage Sense | Reports/reminders first, destructive scheduling later |
| Support bundle/log export | Backblaze/security apps | Redacted diagnostics bundle |
| Permission repair checklist | Malwarebytes, Backblaze, CCC | Permission Doctor with scanner-process proof |

## UX Patterns To Avoid Copying Blindly

- DaisyDisk-style permanent delete as the normal path. Good for immediate reclaim, but too risky for our broad cross-platform product.
- WinDirStat-style arbitrary user-defined cleanup commands in ordinary UI. Powerful, but dangerous and hard to explain.
- Opaque one-click cleaning. It works only when the safety database is mature and still harms trust if users cannot inspect evidence.
- Full permission gate on first launch. Correct for backup/security real-time protection, wrong for an analyzer-first utility.
- Copying NTFS/MFT-specific speed promises to all platforms. WizTree's NTFS model is excellent on Windows, but Clean Disk must be honest on APFS, ext4, network shares, FUSE, and cloud roots.
- Treating cloud placeholder size as reclaimable local space. OneDrive/Dropbox/iCloud make this distinction explicit because users misunderstand it easily.
- Exporting full raw trees by default. Enterprise tools need reports, but Clean Disk must default to redacted exports.
- Marketing-heavy health scores. Users trust concrete evidence: path, size, category, risk, last modified, provider state, and action semantics.

## Feature Implications For Clean Disk

### MVP Must Feel Like A Real Product

Minimum product loop:

```text
Home target
  -> scan with progress and partial-state honesty
  -> size-sorted tree/table
  -> details/evidence panel
  -> recommendation cards
  -> queue
  -> DeletePlan
  -> execution
  -> receipt
```

MVP needs:

- first scan target cards;
- clear scan status and skipped/protected counts;
- virtualized tree/table with size, percent, items, modified, status;
- search/filter/sort over Rust indexes;
- details panel with local-vs-logical size;
- cleanup queue and DeletePlan;
- trash/provider-safe action where supported;
- receipt with restore capability;
- Permission Doctor;
- low-space mode;
- redacted diagnostics preview.

### Post-MVP Should Follow Proven Product Ladders

Post-MVP order:

1. Saved scans and reports - 🎯 9 🛡️ 9 🧠 7, roughly 2500-6500 LOC.
2. Compare scans and growth detection - 🎯 8 🛡️ 8 🧠 8, roughly 3000-8000 LOC.
3. Duplicate search workflow - 🎯 8 🛡️ 8 🧠 8, roughly 3500-9000 LOC.
4. Tool cleanup adapters - 🎯 8 🛡️ 9 🧠 9, roughly 4000-12000 LOC.
5. Scheduled reports and safe previews - 🎯 8 🛡️ 9 🧠 8, roughly 2500-7000 LOC.
6. Expert/admin policies - 🎯 6 🛡️ 8 🧠 10, roughly 6000-18000 LOC.

### UI Must Explain Actions, Not Internals

Use product language:

```text
Complete
May be partial
Needs access
Online-only
Local copy
Always available
Move to Trash
Remove local download
Review before cleanup
Restore likely
Not restorable
```

Avoid exposing raw internals as primary text:

```text
TCC
APFS clone
reparse point
inode
MFT
hardlink dedupe policy
daemon websocket cursor
```

Internals can appear in diagnostics, advanced details, and support exports.

## Product-Level Acceptance Criteria

Before a feature is considered product-ready:

- user can tell what will happen before clicking a destructive action;
- user can see why an item is recommended;
- user can tell whether bytes are local, cloud, logical, allocated, exclusive, or observed;
- user can recover from missing permissions without restarting the whole app;
- user can cancel or understand why a running operation cannot cancel immediately;
- user can export a redacted report;
- user can use keyboard/context menu for the same row actions as hover buttons;
- user can see restore capability after cleanup;
- app does not make low storage worse with cache, logs, update downloads, or cloud hydration;
- all long-running operations have operation IDs, status, terminal states, and receipts.

## Final Product Rule

Clean Disk should feel like:

```text
DaisyDisk/TreeSize discovery speed and clarity
+ CleanMyMac/BleachBit safety discipline
+ OneDrive/Dropbox cloud-state honesty
+ Backblaze-style repair/support maturity
+ TreeSize Pro reporting path later
```

It should not feel like an opaque "one click cleaner". The winning product behavior is fast discovery, explicit evidence, safe staged cleanup, honest reclaim accounting, and cross-platform repairability.
