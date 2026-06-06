# Real Product Feature Adoption Playbook

Last updated: 2026-05-16.

This document records a deeper feature-by-feature research pass on launched products and platform guidance. It focuses on what Clean Disk should copy, adapt, or avoid when building a cross-platform disk analyzer and cleanup app.

The key question:

```text
What makes this kind of app convenient and trustworthy for real users on macOS, Windows, Linux, desktop app, web UI, and headless/server modes?
```

## Sources Reviewed

- DaisyDisk, [deleting files](https://daisydiskapp.com/guide/4/en/DeletingFiles/), [what is safe to delete](https://daisydiskapp.com/guide/4/en/WhatToDelete/), [mismatches with Finder](https://daisydiskapp.com/guide/4/en/FinderMismatch/), and [hard links / APFS clones](https://daisydiskapp.com/guide/4/en/HardLinks/).
- TreeSize, [Details view](https://manuals.jam-software.com/treesize/EN/details.html), [File Operations](https://manuals.jam-software.com/treesize/EN/move_checked_files.html), [snapshots](https://manuals.jam-software.com/treesize/EN/snapshots.html), [comparison](https://manuals.jam-software.de/treesize/EN/disk_usage_comparison.html), [scheduled tasks](https://manuals.jam-software.de/treesize/EN/schedule_treesize_tasks.html), and [remote/cloud storage support](https://www.jam-software.com/treesize/manage-s3storage-and-sharepoint-servers.shtml).
- Apple Support, [Free up storage space on Mac](https://support.apple.com/en-us/102624).
- Microsoft Learn, [Storage Sense](https://learn.microsoft.com/en-us/windows/configuration/storage/storage-sense), [Windows app settings guidelines](https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings), and [MSIX auto-update and repair](https://learn.microsoft.com/en-us/windows/msix/app-installer/auto-update-and-repair--overview).
- Docker Desktop, [Troubleshoot Docker Desktop](https://docs.docker.com/desktop/troubleshoot-and-support/troubleshoot/) and [Resource Saver](https://docs.docker.com/desktop/use-desktop/resource-saver/).
- OneDrive, [sync icons](https://support.microsoft.com/en-us/office/what-do-the-onedrive-icons-mean-11143026-8000-44f8-aaa9-67c985aa49b3).
- Dropbox, [sync icons and online-only files](https://help.dropbox.com/sync/sync-icons).
- Google Drive for desktop, [stream and mirror files](https://support.google.com/drive/answer/13401938).
- CleanMyMac, [Safety and Reliability](https://macpaw.com/support/cleanmymac-x/knowledgebase/cleanmymac-safety), [Smart Care](https://macpaw.com/support/cleanmymac/knowledgebase/smart-care), [Space Lens results](https://macpaw.com/support/cleanmymac/knowledgebase/space-lens-results), and [Support Tool safety](https://macpaw.com/support/cleanmymac/knowledgebase/support-tool-safety).
- Carbon Copy Cloner, [Full Disk Access for app and helper](https://bombich.com/en/kb/ccc/6/granting-full-disk-access-ccc-and-its-helper-tool).
- Flatpak, [Sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html).
- Microsoft Fluent, [Accessibility](https://fluent2.microsoft.design/accessibility).
- WAI-ARIA, [treegrid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/).

## Core Finding

The best products do not merely make dangerous work look simple. They make complex state understandable, then make the next safe action obvious.

For Clean Disk the product bar is:

```text
scan visibly
  -> explain completeness
  -> let the user inspect evidence
  -> stage cleanup
  -> execute through platform semantics
  -> show receipt, restore level, and observed result
```

## Top 3 Product Architecture Options

1. Operations-console UX with explicit capability, operation, receipt, and recovery models - 🎯 10 🛡️ 10 🧠 8, roughly 6000-16000 LOC across contracts, stores, screens, tests, and platform adapters.

   Best fit. This copies the mature discipline from Docker Desktop, TreeSize, DaisyDisk, sync clients, backup tools, and OS storage managers. It gives users a powerful interface without hiding risk.

2. Classic disk analyzer with cleanup queue only - 🎯 7 🛡️ 7 🧠 5, roughly 3000-9000 LOC.

   Good for MVP browsing, but weak for cloud files, permission drift, remote mode, support, low-space mode, and enterprise workflows.

3. One-click cleaner with smart recommendations first - 🎯 5 🛡️ 4 🧠 6, roughly 3500-10000 LOC.

   Looks convenient, but it creates trust debt. We can use recommendation cards, but they must be evidence-backed projections over the scan tree, not the primary authority.

Accepted direction: option 1.

## Feature Adoption Matrix

### 1. First Run And Target Selection

What real products do:

- Apple Storage starts from categories and recommendations, not raw filesystem internals.
- DaisyDisk makes scanning the first workflow and blocks dangerous roots from deletion.
- Flatpak recommends portals and narrow filesystem access instead of blanket access where possible.
- Material permission guidance favors context and immediate benefit.

Clean Disk adoption:

- First launch should offer `Scan Downloads`, `Choose Folder`, and a visible drive target.
- No startup Full Disk Access wall.
- Use native folder pickers or portals where possible.
- Show package-mode limits before promising full-disk behavior.
- If daemon is unavailable, show a repairable state, not a fatal app shell.

### 2. Scan Progress And Partial Results

What real products do:

- Docker Desktop separates app status, troubleshooting, logs, diagnostics, restart, and reset.
- TreeSize-style products expose scan output as navigable data instead of hiding everything behind a spinner.
- Dropbox and OneDrive use persistent sync states and error states instead of one-off modals.

Clean Disk adoption:

- Scan progress should show scanned size, scanned item count, current path, elapsed time, throughput, skipped count, and error count.
- Partial results should be usable while scan continues if read-model consistency permits it.
- Current path events must be throttled and privacy-aware.
- `Pause`, `Cancel`, `Restart scan`, and `Open issue drawer` are first-class controls.
- Daemon health is separate from scan health.

### 3. Results Navigation

What real products do:

- TreeSize uses an Explorer-like detail list with configurable columns, export, context menu, preview, owner, permissions, allocated size, hardlinks, error column, and path.
- DaisyDisk uses a strong visual map, but still supports details and preview.
- WAI-ARIA treats treegrid as a distinct interactive pattern with keyboard focus and selection semantics.

Clean Disk adoption:

- Tree/table is the primary power surface.
- Treemap/sunburst can be added later as a secondary visualization.
- Details panel must expose path, logical size, allocated size, reclaim estimate, item counts, modified time, permissions, file type, skip state, warnings, cloud state, and identity confidence.
- Selection must be distinct from focus.
- The treegrid primitive belongs in `packages/design_system`, not inside a single screen.

### 4. Size Accounting And Mismatch Explanation

What real products do:

- DaisyDisk explicitly explains mismatches with Finder through permissions, hardlinks, compression, APFS clones, Time Machine snapshots, hidden space, and purgeable space.
- TreeSize exposes size, allocated size, hardlinks, attributes, alternate streams, compression, owner, permissions, and errors as columns.
- Apple explains that storage categories update as cleanup steps happen and that Trash must be emptied before space becomes available.

Clean Disk adoption:

- Never show a single "size" as if it answers every user question.
- Use separate fields:

```text
logical_size
allocated_size
exclusive_reclaim_estimate
quota_effect_estimate
observed_free_space_delta
confidence
explanation_codes
```

- Details should explain "why this may not free exactly X GB".
- APFS clones, hardlinks, snapshots, cloud placeholders, sparse files, compression, dedupe, and open files lower confidence.

### 5. Cleanup Queue And DeletePlan

What real products do:

- DaisyDisk uses a Collector and keeps files intact until the delete action. It blocks system roots and gives a short cancellation window.
- TreeSize File Operations uses a two-panel dialog: operation settings on one side and affected file preview on the other. It supports Recycle Bin, copy, move, archive, logging, timestamps, permissions, and collision behavior.
- CleanMyMac smart-selects generated data but does not remove personal files unless the user chooses to.

Clean Disk adoption:

- Cleanup is staged:

```text
select candidates
  -> add to cleanup queue
  -> generate DeletePlan
  -> revalidate identity and metadata
  -> confirm action
  -> execute
  -> receipt
```

- Trash/Recycling Bin is default where available.
- Permanent delete is advanced and off the main path.
- Queue shows restore level and confidence per item.
- Critical roots and unsupported tool-managed stores are blocked or require official adapters.

### 6. Recommendation Cards

What real products do:

- Apple and Windows use category recommendations: large files, Downloads, Trash/Recycling Bin, cloud offload, temporary files.
- CleanMyMac uses a Safety Database, smart selection, module-specific ignore list, and generated-data bias.
- TreeSize does not pretend it knows user intent. It gives evidence, filters, reports, and operations.

Clean Disk adoption:

- Recommendation cards are projections over scan indexes:

```text
rule_id
risk_tier
reason
evidence
affected_nodes_query
default_action
excluded_reason
confidence
official_cleanup_adapter
```

- Only generated cache/log/temp artifacts can be selected by default.
- User-created files are review-only by default.
- Tool-managed stores use official cleanup adapters when available.

### 7. Cloud And Sync Providers

What real products do:

- OneDrive and Dropbox teach users file states through icons: available offline, online-only, syncing, paused, failed, ignored.
- Google Drive clearly distinguishes streaming from mirroring and warns users to make sure files are synced before deleting mirrored folders.
- Storage Sense can dehydrate cloud-backed content using age thresholds.

Clean Disk adoption:

- Cloud state is part of node metadata:

```text
local
online_only
available_offline
syncing
sync_error
ignored
provider_unknown
```

- Actions are separate:

```text
Remove local download
Move to Trash
Delete from sync root
Open provider cleanup
Reveal in provider
```

- The scanner must not hydrate online-only content.
- Reclaim estimate for online-only files is not local reclaim.
- Cleanup plan must warn when deletion propagates to cloud.

### 8. Permissions And Capability Repair

What real products do:

- CCC documents that both app and helper can need Full Disk Access and that macOS privacy state can be unreliable.
- Backblaze and security tools use status reports and repair flows.
- Flatpak treats package sandbox mode as a real product limitation.

Clean Disk adoption:

- Capability probing must run in the scanner process.
- Permission Doctor is a product surface, not a generic error.
- App/helper identity is part of capability state.
- After settings changes, always re-probe.
- On Linux, package mode should be visible: direct package, AppImage, deb/rpm, Flatpak, Snap, remote daemon.

### 9. Low-Space And Resource Modes

What real products do:

- Docker Resource Saver visibly reduces host resource use when idle and changes behavior by platform.
- Windows Storage Sense runs automatically when disk space is low by default and supports retention thresholds.
- Apple suggests temporary cleanup paths when an operation needs space, such as OS update.

Clean Disk adoption:

- Low-space mode should reduce app self-footprint.
- Avoid huge local caches, huge logs, large report generation, thumbnails, and background downloads.
- Scan profiles are visible:

```text
Balanced
Fast
Background
LowSpaceRescue
ReadOnlyRemote
```

- If a scan mode changes accuracy or responsiveness, tell the user.

### 10. Automation, Reports, And Admin Use

What real products do:

- TreeSize supports scheduled scans, reports, comparison with saved scans, snapshots, and command-line workflows.
- Storage Sense supports policy-managed schedules and retention thresholds.
- Docker Desktop and MSIX expose enterprise/admin configuration and repair/update controls.

Clean Disk adoption:

- Start automation with scheduled scans, scheduled reports, dry-run cleanup previews, and reminders.
- Do not start with silent scheduled destructive cleanup.
- Saved scans are immutable snapshots for review, compare, and reporting.
- Admin/headless mode should be separate, auditable, and read-only by default.

### 11. Diagnostics And Support

What real products do:

- Docker Desktop offers in-app diagnostics, diagnostics from error states, terminal diagnostics, logs, and diagnostic IDs.
- MacPaw documents a signed and notarized support tool.
- Sentry supports server-side, SDK-side, and relay-level scrubbing patterns.

Clean Disk adoption:

- Support bundle must have preview, redaction level, and explicit export/upload step.
- Default redaction removes raw paths, usernames, tokens, auth headers, search text, full trees, and delete targets.
- Daemon logs should be inspectable, but production metrics must not use high-cardinality path labels.
- Support bundle creation should produce a receipt.

### 12. Settings, Updates, And Repair

What real products do:

- Microsoft settings guidance keeps common workflow commands out of settings and recommends simple defaults.
- MSIX supports update and repair settings, including launch-blocking update behavior and fallback update URIs.
- Docker exposes restart, reset, purge, diagnostics, resource settings, and versioned troubleshooting.

Clean Disk adoption:

- Settings are for durable preferences and policy, not normal workflow commands.
- App update must revalidate daemon/helper compatibility and permission state.
- If app and daemon protocol mismatch, show update/repair path instead of weird UI failures.
- Settings groups should remain:

```text
General
Scan
Cleanup safety
Daemon
Privacy
Reports
Updates
Advanced
About
```

### 13. Accessibility And Keyboard Use

What real products do:

- Fluent says accessibility must be designed from first wireframe, with clear hierarchy, managed focus, contrast, text zoom, and semantic structure.
- WAI-ARIA treegrid requires focusable rows/cells, keyboard navigation, expansion, selection, row/column metadata, and visual focus.

Clean Disk adoption:

- Design-system treegrid must handle:

```text
row focus
cell focus
selection independent from focus
expand/collapse keyboard controls
sort state
row count
virtualized row semantics
visible focus
screen-reader labels
```

- Charts require table/list equivalents.
- Compact layout must work with 200% text zoom and not hide critical actions.

### 14. Installer And Trust

What real products do:

- CleanMyMac emphasizes Apple notarization, App Store availability, Safety Database, and support tooling.
- MSIX supports repair/update controls.
- Flatpak makes sandbox permission scope explicit.
- Utility apps are frequent spoofing targets, so download channel trust matters.

Clean Disk adoption:

- Installer/channel state is part of support diagnostics:

```text
distribution_channel
package_mode
app_signature_state
helper_signature_state
daemon_version
protocol_version
update_policy
```

- UI should warn only when trust state affects safety or capability.
- Portable builds are allowed but should show reduced update/repair expectations.

## Product Rules To Copy Directly

- Make the first useful scan easy.
- Keep the tree/table central.
- Stage deletion through a queue and plan.
- Use Trash/Recycling Bin by default.
- Show exact affected targets before cleanup.
- Treat skip/permission errors as useful result data.
- Explain size mismatches instead of hiding them.
- Keep cloud local-reclaim distinct from cloud deletion.
- Make daemon health repairable.
- Make support bundles previewable and redacted.
- Support export/reporting as an explicit operation.
- Design keyboard and accessibility before virtualizing the table.

## Product Rules To Avoid

- Do not make Full Disk Access the first screen.
- Do not hide the scan tree behind only "smart cleanup".
- Do not auto-select personal files.
- Do not claim exact reclaim on snapshots, clones, dedupe, cloud placeholders, or sparse files.
- Do not scatter cleanup actions in row buttons without a final DeletePlan.
- Do not make permanent delete the primary action.
- Do not rely on Flutter UI to prove permissions.
- Do not keep raw full paths in diagnostics by default.
- Do not promise Flatpak/Snap full-disk scanning unless the runtime can actually do it.

## Concrete Clean Disk Backlog Additions

Top 3 additions after this research:

1. Product state and action availability contract - 🎯 10 🛡️ 10 🧠 7, roughly 800-1800 LOC.

   Define `ActionAvailability`, `DisabledReason`, `CapabilityState`, `ScanQuality`, `RestoreCapability`, `ReclaimConfidence`, and `OperationReceipt` before building feature screens.

2. Cleanup queue and DeletePlan prototype before recommendation cards - 🎯 10 🛡️ 9 🧠 8, roughly 1200-3000 LOC.

   Proves staged deletion, revalidation, warnings, platform trash behavior, partial failures, and receipts before we let recommendations drive cleanup.

3. Design-system virtual treegrid spike - 🎯 9 🛡️ 9 🧠 9, roughly 1500-3500 LOC.

   The central workflow depends on a high-quality tree/table primitive. If Headless lacks this, improve Headless rather than writing a one-off table in the scan feature.

## Summary

The launched-product lesson is simple but hard to implement:

```text
Convenience comes from making the next safe action obvious.
Trust comes from proving what happened.
Power comes from keeping evidence inspectable.
```

Clean Disk should be a fast analyzer first, a careful cleanup planner second, and an automation/admin tool later.
