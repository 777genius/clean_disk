# Launched Product Cross-Platform Workflows

Last updated: 2026-05-16.

This document records a deeper practical research pass on launched storage, cleanup, sync, backup, OS, developer-tool, and accessibility products. It focuses on how Clean Disk should feel convenient and trustworthy across macOS, Windows, Linux, desktop UI, web UI, and headless/server use.

## Sources Reviewed

- DaisyDisk, [Deleting files](https://daisydiskapp.com/guide/2/en/DeletingFiles/), [What is safe to delete](https://daisydiskapp.com/guide/4/en/WhatToDelete/), [Restricted folders](https://daisydiskapp.com/guide/4/en/Restricted/), [Hidden space](https://daisydiskapp.com/guide/4/en/HiddenSpace/), [Purgeable space](https://daisydiskapp.com/guide/4/en/PurgeableSpace), [Hard links and APFS clones](https://daisydiskapp.com/guide/4/en/HardLinks/), and [Cloud scanning](https://daisydiskapp.com/guide/4/en/CloudScan/).
- TreeSize, [Details](https://manuals.jam-software.com/treesize/EN/details.html), [View menu](https://manuals.jam-software.de/treesize/EN/view_menu.html), [File Operations](https://manuals.jam-software.de/treesize/EN/move_checked_files.html), [Comparison](https://manuals.jam-software.de/treesize/EN/disk_usage_comparison.html), [Scheduled tasks](https://manuals.jam-software.de/treesize/EN/schedule_treesize_tasks.html), and [remote/cloud storage](https://www.jam-software.com/treesize/manage-s3storage-and-sharepoint-servers.shtml).
- WinDirStat, [cleanup actions](https://documentation.help/WinDirStat/actions.htm) and [user-defined cleanups](https://documentation.help/WinDirStat/userdefinedcleanups.htm).
- GNOME Disk Usage Analyzer, [official help](https://help.gnome.org/users/baobab/stable/) and [scan permission errors](https://teams.pages.gitlab.gnome.org/Websites/help.gnome.org/baobab/problem-permissions.html).
- KDE Filelight, [handbook](https://docs.kde.org/stable5/en/filelight/filelight/index.html).
- BleachBit, [general usage](https://docs.bleachbit.org/doc/general-usage.html), [CLI preview/clean](https://docs.bleachbit.org/doc/command-line-interface.html), [preferences/whitelist](https://docs.bleachbit.org/doc/preferences.html), [CleanerML](https://docs.bleachbit.org/cml/cleanerml.html), and [secure erase caveats](https://docs.bleachbit.org/doc/shred-files-and-wipe-disks.html).
- CleanMyMac, [Safety and Reliability](https://macpaw.com/support/cleanmymac-x/knowledgebase/cleanmymac-safety), [Smart Care](https://macpaw.com/support/cleanmymac/knowledgebase/smart-care), [Space Lens](https://macpaw.com/support/cleanmymac/knowledgebase/space-lens-results), and [Support Tool safety](https://macpaw.com/support/cleanmymac/knowledgebase/support-tool-safety).
- Apple Support, [free up storage space on Mac](https://support.apple.com/en-gb/102624), [optimize storage](https://support.apple.com/en-tm/guide/mac-help/sysp4ee93ca4/mac), and [delete files and folders on Mac](https://support.apple.com/en-mide/guide/mac-help/mchlp1093).
- Microsoft Support and Learn, [Storage Sense](https://support.microsoft.com/en-us/windows/manage-drive-space-with-storage-sense-654f6ada-7bfc-45e5-966b-e24aded96ad5), [free up drive space](https://support.microsoft.com/en-us/windows/free-up-drive-space-in-windows-85529ccb-c365-490d-b548-831022bc9b32), [Storage Sense policy](https://learn.microsoft.com/en-us/windows/configuration/storage/storage-sense), [settings guidelines](https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings), and [MSIX auto-update/repair](https://learn.microsoft.com/en-us/windows/msix/app-installer/auto-update-and-repair--overview).
- Docker Desktop, [troubleshoot](https://docs.docker.com/desktop/troubleshoot-and-support/troubleshoot/), [images view](https://docs.docker.com/desktop/use-desktop/images/), [Resource Saver](https://docs.docker.com/desktop/use-desktop/resource-saver/), and [docker system prune](https://docs.docker.com/reference/cli/docker/system/prune/).
- Google Drive for desktop, [stream and mirror](https://support.google.com/drive/answer/13401938).
- OneDrive, [Files On-Demand](https://support.microsoft.com/en-us/office/sync-files-with-onedrive-files-on-demand-62e8d748-7877-420f-b600-24b56562aa70) and [sync icons](https://support.microsoft.com/en-us/office/what-do-the-onedrive-icons-mean-11143026-8000-44f8-aaa9-67c985aa49b3).
- Dropbox, [online-only files](https://help.dropbox.com/sync/make-files-online-only), [sync icons](https://help.dropbox.com/sync/sync-icons), [delete files](https://help.dropbox.com/delete-restore/delete-files), and [remote wipe status reports](https://help.dropbox.com/delete-restore/delete-dropbox-device).
- Backblaze, [restore app](https://help.backblaze.com/hc/en-us/articles/15383074527771/).
- Carbon Copy Cloner, [Full Disk Access for app and helper](https://bombich.com/en/kb/ccc/6/granting-full-disk-access-ccc-and-its-helper-tool).
- Flatpak, [sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html).
- Apple HIG, [sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) and [lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables).
- Microsoft Learn, [focus navigation](https://learn.microsoft.com/en-us/windows/apps/design/input/focus-navigation) and [keyboard interactions](https://learn.microsoft.com/en-us/windows/apps/develop/input/keyboard-interactions).
- WAI-ARIA, [treegrid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/).

## Core Finding

Cross-platform quality does not mean identical UI everywhere. It means identical product truth everywhere, with native platform actions where trust depends on the OS.

Clean Disk should normalize concepts like scan quality, cloud state, reclaim confidence, operation status, restore capability, and disabled reasons. But execution should use native adapters for Trash/Recycling Bin, Finder/Explorer reveal, file-provider states, package sandbox limits, official tool cleanup, diagnostics, updates, and repair.

## Top 3 Cross-Platform UX Strategies

1. Workflow engine plus platform adapters - 🎯 10 🛡️ 10 🧠 8, roughly 7000-18000 LOC.

   Accepted. Product workflows are shared, while platform adapters implement native details. This is how mature apps stay consistent without lying about OS behavior.

2. Shared Flutter screens with thin native helpers - 🎯 7 🛡️ 6 🧠 5, roughly 3500-10000 LOC.

   Faster, but risks leaking platform quirks into widgets and accumulating one-off fixes.

3. Fully platform-specific apps sharing only Rust scanner - 🎯 5 🛡️ 8 🧠 10, roughly 15000-40000 LOC.

   Strong native fidelity, but too expensive for this product stage and weak for web/headless reuse.

Accepted direction: option 1.

## Product Workflows To Copy

### 1. Analyzer First, Cleaner Second

Real-product signal:

- DaisyDisk and GNOME Disk Usage Analyzer start with scanning and visualizing.
- TreeSize gives deep details, sortable columns, comparison, export, and operations.
- CleanMyMac starts more cleanup-oriented, but its best trust signal is safety classification.

Clean Disk rule:

```text
Scan first
Inspect evidence
Then propose cleanup
```

The first product surface is not "Clean now". It is "Here is where your space went".

### 2. Collector / Queue Before Delete

Real-product signal:

- DaisyDisk's Collector keeps files untouched until the user deletes and even has a short cancellation window.
- TreeSize File Operations previews affected items and supports Recycle Bin.
- BleachBit has a Preview step before Clean.

Clean Disk rule:

```text
Selection
  -> CleanupQueue
  -> DeletePlan preview
  -> Identity revalidation
  -> Execution
  -> Receipt
```

No direct row delete for risky targets. Row actions can add to queue, reveal, inspect, copy path, or open details.

### 3. Native Delete Semantics

Real-product signal:

- Apple file deletion uses Trash and may require admin authentication.
- Windows cleanup uses Recycle Bin, Storage Sense, and cleanup recommendations.
- Dropbox/OneDrive/Google Drive deletion can propagate to cloud, while "free up space" only removes local content.

Clean Disk rule:

The same UI command label must not hide different semantics. Use separate actions:

```text
Move to Trash
Delete permanently
Remove local download
Delete from sync root
Run official cleanup
Archive/move elsewhere
```

The action availability model must explain why each action is enabled, disabled, risky, or unsupported.

### 4. Preview And Evidence Before Automation

Real-product signal:

- BleachBit separates preview from clean in both GUI and CLI.
- Windows Storage Sense can automate low-risk cleanup with retention policies.
- TreeSize scheduled tasks are report/admin-oriented.

Clean Disk rule:

Automation starts as:

```text
scheduled scan
scheduled report
dry-run cleanup preview
reminder
```

Destructive scheduled cleanup is a later advanced feature with policy, dry-run, receipt, and restore model.

### 5. Explain Space Mismatches

Real-product signal:

- DaisyDisk documents hidden space, purgeable space, APFS clones, hardlinks, local snapshots, restricted folders, and Finder mismatches.
- TreeSize exposes allocated size, owner, permissions, hardlinks, alternate streams, errors, and cost columns.
- GNOME documents that scan errors often come from permissions and that filesystem totals differ from file traversal totals.

Clean Disk rule:

The UI must make mismatch explanations first-class:

```text
why Finder/Explorer differs
why free space did not change
why reclaim estimate is low confidence
why a folder appears as zero size
why cloud placeholders are not local reclaim
why snapshots/clones/hardlinks change math
```

This should be in details/issue drawer, not hidden in docs only.

### 6. Cloud Is A Different Domain

Real-product signal:

- OneDrive says deleting an online-only file deletes it from OneDrive everywhere.
- Dropbox distinguishes online-only, available offline, sync statuses, cache clearing, and delete/restore windows.
- Google Drive distinguishes streaming and mirroring, with changes reflecting across devices.
- DaisyDisk can scan cloud directly to avoid local cache growth.

Clean Disk rule:

Cloud-backed files require a provider-aware model:

```text
local_size
cloud_size
placeholder_size
hydration_state
sync_state
provider
delete_propagation
restore_window
```

Never "helpfully" hydrate online-only content during scan. Never present cloud delete as local cleanup.

### 7. Official Tool Cleanup Beats Raw Folder Deletion

Real-product signal:

- Docker exposes image cleanup and `docker system prune`, with volumes protected by default unless explicitly requested.
- Xcode exposes simulator runtime removal through its UI.
- Windows Storage Sense has vetted cleanup categories.
- CleanMyMac and BleachBit use rule packs/cleaners with descriptions, whitelists, and previews.

Clean Disk rule:

For tool-managed storage, prefer adapters:

```text
DockerCleanupAdapter
XcodeCleanupAdapter
AndroidStudioCleanupAdapter
HomebrewCleanupAdapter
PackageManagerCleanupAdapter
BrowserCacheCleanupAdapter
```

Raw deletion is fallback only, with lower confidence and stronger warning.

### 8. Status And Repair Beat Error Modals

Real-product signal:

- Docker Desktop has Troubleshoot, Restart, Reset, Clean/Purge data, logs, and diagnostics.
- Backblaze restore has progress and restore location/collision options.
- CCC teaches that app/helper permissions can both matter.
- Dropbox remote wipe reports status and errors per device.

Clean Disk rule:

Use persistent repair surfaces:

```text
Daemon Status
Permission Doctor
Scan Issue Drawer
Operation History
Support Bundle Preview
Repair Checklist
```

Modals are for decisions. Status panels are for ongoing system truth.

### 9. Desktop And Web Share Workflows, Not Runtime Assumptions

Real-product signal:

- Docker Desktop has UI, CLI, daemon logs, and diagnostics around one local runtime.
- TreeSize has GUI, command-line, scheduling, and reports.
- Backblaze can restore through desktop app and web/server-side restore flows.

Clean Disk rule:

The same product operations should work through desktop UI, web UI, CLI, and later remote/headless mode:

```text
scan session
query read model
create cleanup queue
preview DeletePlan
execute operation
get receipt
export report
collect support bundle
```

The UI changes by platform. The workflow contract should not.

### 10. Accessibility Is A Product Capability

Real-product signal:

- Apple recommends tables/lists for scannable text data, sortable columns on macOS, and resizable columns.
- Microsoft documents focus navigation and keyboard operation for custom controls.
- WAI-ARIA treegrid has explicit keyboard, expanded, selected, row, cell, and sort semantics.

Clean Disk rule:

The tree/table cannot be an afterthought. It needs:

```text
keyboard navigation
roving focus or active-descendant model
selection distinct from focus
expand/collapse semantics
sortable columns
resizable columns on desktop
screen-reader row labels
large text support
chart alternatives
```

If Headless lacks this primitive, improving Headless is the product-correct move.

## Platform-Specific Convenience Rules

### macOS

- Use Finder reveal and Trash semantics.
- Full Disk Access is requested progressively and verified by the scanner/helper process.
- Model hidden space, purgeable space, APFS clones, snapshots, hardlinks, and other volumes.
- Do not promise exact reclaim when purgeable space or snapshots are involved.
- App/helper signing identity is part of capability health.

### Windows

- Use Explorer reveal, Recycle Bin, Storage Sense vocabulary, and cleanup recommendations style.
- Treat admin/elevated scan as advanced, not default.
- Support OneDrive Files On-Demand states.
- Do not raw-delete Docker volumes or Windows update/rollback files outside official APIs or clear warnings.
- Consider MSIX/installer repair and app/daemon version compatibility as product state.

### Linux

- Package mode matters: AppImage, deb/rpm, Flatpak, Snap, distro package, remote daemon.
- Flatpak/Snap may not see host filesystem without explicit permissions.
- Use file manager reveal where available, Trash where supported, and CLI-safe fallback messages.
- Remote folders, FUSE/rclone mounts, and permission errors must be expected, not exceptional.
- Root scan is advanced and read-only first.

### Web UI

- Web is an interface to a local or remote daemon, not a scanner.
- The daemon should serve or authorize the UI through local token/origin policy.
- Web must show daemon connection state, protocol version, and capability limits.
- Service worker/offline behavior must not create stale UI talking to a newer/older daemon without compatibility checks.

### Headless / Server

- Default to read-only scan/report.
- Destructive cleanup requires explicit policy, scoped targets, dry-run, receipt, and audit.
- Remote mode must not expose raw filesystem paths to unauthenticated clients.
- Use operation IDs and receipts, not one-shot commands with no audit trail.

## Required Product Contracts

These are the contracts that make the cross-platform UX possible:

```text
ActionAvailability
CapabilityState
CloudFileState
DeletePlan
DisabledReason
IssueGroup
NodeDetails
OperationReceipt
OperationState
PackageMode
ReclaimEstimate
RestoreCapability
ScanQuality
ToolCleanupPlan
```

These contracts belong in application/protocol layers, not inside widgets.

## Required Adapter Families

```text
CapabilityProbeAdapter
CloudStateAdapter
DaemonLifecycleAdapter
DiagnosticsAdapter
FileRevealAdapter
OfficialToolCleanupAdapter
PackageModeAdapter
PermissionRepairAdapter
PlatformTrashAdapter
ReclaimAccountingAdapter
SupportBundleAdapter
```

Adapters can vary by platform. The product vocabulary should stay stable.

## Red Flags From Real Products

- User-defined cleanup commands are powerful but dangerous. WinDirStat supports them for experts; Clean Disk should not put this in MVP.
- Secure erase sounds reassuring but SSD/TRIM/cloud/snapshots make promises tricky. If added, it needs strong caveats.
- Smart cleanup creates trust only if every recommendation is explainable and reversible or honestly irreversible.
- Cloud placeholders make "size" misleading. The UI must avoid one-number oversimplification.
- Permission repair is not "open settings and hope". It is re-probe, compare, and report.
- Scheduled cleanup without dry-run/report is too risky for consumer MVP.
- Remote/headless cleanup without policy/audit is an enterprise incident waiting to happen.

## What We Should Build First

Top 3 implementation sequences:

1. Workflow contracts before screen polish - 🎯 10 🛡️ 10 🧠 7, roughly 1000-2500 LOC.

   Define scan quality, issues, action availability, reclaim estimate, DeletePlan, receipt, cloud states, and operation state. This prevents UI hacks.

2. Central treegrid and details before charts - 🎯 9 🛡️ 9 🧠 8, roughly 1500-3500 LOC.

   Tree/table is the power-user workflow. Charts can come later, but the table must be excellent.

3. Permission Doctor and low-space rescue before automation - 🎯 9 🛡️ 10 🧠 7, roughly 1200-3000 LOC.

   These are the trust-building flows. Automation without these creates hidden risk.

## Summary

The cross-platform product lesson from launched tools:

```text
Share the workflow.
Normalize the product vocabulary.
Use native platform actions for trust boundaries.
Show evidence before cleanup.
Show receipts after cleanup.
```

Clean Disk should feel like one product everywhere, but it must not pretend every platform behaves the same.
