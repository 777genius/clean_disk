# Launched Product UX Playbook

Last updated: 2026-05-16.

This document records the second product-research pass focused on launched tools and OS features. It turns mature product behavior into Clean Disk UX and architecture rules.

It complements:

- [Real product UX lessons](real-product-ux-lessons.md)
- [Feature UX benchmark](feature-ux-benchmark.md)
- [Cross-platform user experience playbook](cross-platform-user-experience-playbook.md)
- [Permission UX playbook](permission-ux-playbook.md)

## Sources Reviewed

Primary product and platform sources:

- Apple Support, [Free up storage space on Mac](https://support.apple.com/en-us/ht206996), [Optimize storage space on your Mac](https://support.apple.com/guide/mac-help/sysp4ee93ca4/mac), [iCloud Drive status](https://support.apple.com/en-euro/guide/mac-help/mchlc994344b/mac), and Apple Developer, [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy/).
- Microsoft Support and Learn, [Free up drive space in Windows](https://support.microsoft.com/windows/free-up-drive-space-in-windows-85529ccb-c365-490d-b548-831022bc9b32), [Storage Sense](https://support.microsoft.com/windows/manage-drive-space-with-storage-sense-654f6ada-7bfc-45e5-966b-e24aded96ad5), [Storage Sense policy](https://learn.microsoft.com/windows/configuration/storage/storage-sense), [MSIX auto-update and repair](https://learn.microsoft.com/windows/msix/app-installer/auto-update-and-repair--overview), and [Microsoft PC Manager](https://pcmanager.microsoft.com/en-us).
- Google, [Files by Google](https://files.google.com/), [Files by Google duplicate cleanup](https://support.google.com/files/answer/9764075), and [Drive for desktop stream and mirror](https://support.google.com/drive/answer/13401938).
- Dropbox Help, [online-only files](https://help.dropbox.com/sync/make-files-online-only), [sync icons](https://help.dropbox.com/sync/sync-icons), and [macOS File Provider changes](https://help.dropbox.com/installs/macos-support-for-expected-changes).
- Microsoft OneDrive, [Files On-Demand](https://support.microsoft.com/office/sync-files-with-onedrive-files-on-demand-62e8d748-7877-420f-b600-24b56562aa70) and [sync icons](https://support.microsoft.com/office/what-do-the-onedrive-icons-mean-11143026-8000-44f8-aaa9-67c985aa49b3).
- DaisyDisk Guide, [Deleting files](https://daisydiskapp.com/guide/4/en/DeletingFiles), [Hidden space](https://daisydiskapp.com/guide/4/en/HiddenSpace/), [Scanning as administrator](https://daisydiskapp.com/guide/4/en/AdminScan/), and [Full Disk Access](https://daisydiskapp.com/guide/full-disk-access).
- TreeSize Manual, [general scan options](https://manuals.jam-software.com/treesize/EN/scan_options.html), [command line options](https://manuals.jam-software.de/treesize/EN/command_line_opt.html), [duplicate file search](https://manuals.jam-software.com/treesize/EN/duplicate_file_search.html), and [deduplication with hardlinks](https://manuals.jam-software.com/treesize/EN/deduplication.html).
- WizTree, [official guide](https://www.diskanalyzer.com/guide), [FAQ](https://diskanalyzer.com/faq), and [what's new](https://diskanalyzer.com/whats-new).
- WinDirStat Documentation, [directory list](https://documentation.help/WinDirStat/directorytree.htm), [cleanups](https://documentation.help/WinDirStat/actions.htm), and [user-defined cleanups](https://documentation.help/WinDirStat/userdefinedcleanups.htm).
- GNOME Disk Usage Analyzer, [introduction](https://help.gnome.org/baobab/introduction.html), [permission errors](https://help.gnome.org/baobab/problem-permissions.html), and [move to Trash](https://help.gnome.org/baobab/question-trash.html).
- GrandPerspective, [quick start](https://grandperspectiv.sourceforge.net/HelpDocumentation/QuickStart.html) and [filters and masks](https://grandperspectiv.sourceforge.net/HelpDocumentation/MasksAndFilters.html).
- SpaceSniffer, [official product page](https://www.uderzo.it/main_products/space_sniffer/).
- OmniDiskSweeper, [Omni Labs product page](https://www.omnigroup.com/more/?from=gyagbbb3), [Catalina update note](https://www.omnigroup.com/blog/omnidisksweeper-catalina), and [1.10 update note](https://www.omnigroup.com/blog/entry/omnidisksweeper-1.10).
- CleanMyMac, [Large and Old Files](https://macpaw.com/support/cleanmymac/knowledgebase/large-and-old), [Space Lens](https://macpaw.com/support/cleanmymac/knowledgebase/space-lens), [My Tools](https://macpaw.com/support/cleanmymac/knowledgebase/my-tools), and [safety and reliability](https://macpaw.com/support/cleanmymac/knowledgebase/cleanmymac-safety).
- CCleaner, [Health Check](https://www.ccleaner.com/ccleaner/health-check), [Custom Clean analysis](https://support.ccleaner.com/articles/en_US/Master_Article/custom-clean-s-analysis-and-results-function), and [safety](https://www.ccleaner.com/ccleaner/is-ccleaner-safe).
- BleachBit, [general usage](https://docs.bleachbit.org/doc/general-usage.html), [expert mode](https://docs.bleachbit.org/doc/expert-mode.html), and [command line interface](https://docs.bleachbit.org/doc/command-line-interface.html).
- Hazel, [App Sweep](https://www.noodlesoft.com/manual/hazel/hazel-basics/manage-your-trash/use-app-sweep/).
- Backblaze, [Full Disk Access install guide](https://help.backblaze.com/hc/en-us/articles/1260801754709-Installing-the-Backup-Client-on-Mac-for-OSX-10-14-and-Later), [Full Disk Access admin status report](https://help.backblaze.com/hc/en-us/articles/360011389154-Which-Users-Have-Granted-Backblaze-Full-Disk-Access), and [send logs to support](https://help.backblaze.com/hc/en-us/articles/14750819976731-How-to-send-logs-to-Backblaze-Mac).
- Carbon Copy Cloner, [Full Disk Access for app and helper](https://bombich.com/en/kb/ccc/6/granting-full-disk-access-ccc-and-its-helper-tool).
- Malwarebytes, [Real-Time Protection on macOS](https://help.malwarebytes.com/hc/en-us/articles/31589448817563-Turn-on-Real-Time-Protection-in-Desktop-Security), and Norton, [repeated Full Disk Access prompt](https://support.norton.com/sp/en/us/home/current/solutions/v20221020120926278).
- WAI-ARIA Authoring Practices, [treegrid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/), and Google Material Design, [permissions](https://m1.material.io/patterns/permissions.html).
- Sparkle, [documentation](https://sparkle-project.github.io/documentation/), Tauri, [updater signing](https://tauri.app/plugin/updater/), and Flatpak, [sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html).

## Core Finding

Mature products do not make cleanup a single action. They split the experience into six loops:

```text
discover space
  -> explain completeness
  -> review candidates
  -> choose exact action
  -> execute with platform semantics
  -> show receipt, repair, or support path
```

Clean Disk should copy that structure. The app should feel fast like a disk analyzer, but behave safely like a backup/security/cleanup tool.

## Top 3 Product Borrowing Strategies

1. Product-journey contracts copied from multiple mature product classes - 🎯 10 🛡️ 10 🧠 8, roughly 5000-14000 LOC across UI, Rust DTOs, state machines, tests, and docs.

   Accepted. Borrow discovery from DaisyDisk, TreeSize, WizTree, WinDirStat, GrandPerspective, SpaceSniffer, and OmniDiskSweeper. Borrow safety from BleachBit, CleanMyMac, Hazel, Windows Storage Sense, and GNOME Disk Usage Analyzer. Borrow cloud vocabulary from OneDrive, Dropbox, Google Drive, and iCloud. Borrow repair/support maturity from Backblaze, CCC, Malwarebytes, and Norton.

2. Copy one flagship analyzer UX almost directly - 🎯 6 🛡️ 6 🧠 5, roughly 2500-7000 LOC.

   This would be faster, but weak cross-platform. DaisyDisk-style permanent delete, WizTree's Windows-only MFT speed, or GrandPerspective's visual-first simplicity would each leave major gaps for cleanup safety, web UI, remote mode, Linux packages, and cloud placeholders.

3. Copy OS storage assistants only - 🎯 6 🛡️ 9 🧠 5, roughly 2500-6500 LOC.

   Safe, but too shallow. Apple Storage and Windows Storage are good for broad categories and conservative recommendations, but they do not give enough folder/file structure visibility for Clean Disk's main promise.

## Feature-By-Feature Lessons

| Feature | Products to learn from | Product behavior | Clean Disk rule |
| --- | --- | --- | --- |
| First run | Apple HIG, Material, GrandPerspective, OmniDiskSweeper | Start from an action and ask for access when the user understands why | Open into the real app surface. Default CTA is `Scan Downloads` or `Choose Folder`, not `Grant Full Disk Access` |
| Target picker | DaisyDisk, GNOME Baobab, GrandPerspective, CleanMyMac Space Lens | Scan disk, folder, external drive, or selected target | Targets are first-class objects with type, capability, speed caveat, and recent history |
| Partial access | GNOME Baobab, DaisyDisk, OmniDiskSweeper | Results can be useful but incomplete when files are unreadable | Partial scan is a valid state with skipped counts, issue groups, and re-probe action |
| Permissions repair | Backblaze, CCC, Malwarebytes, Norton | Permission state is tied to real app/helper identity and can regress after OS updates | Permission Doctor must prove access from the scanner process, not from Flutter |
| Scan progress | TreeSize, SpaceSniffer, WinDirStat | Users need progress, current location, pause/cancel, and partial structure | Scan lifecycle has visible phases: preflight, scanning, indexing, enriching, partial, completed_partial |
| Visual discovery | DaisyDisk, GrandPerspective, SpaceSniffer, WinDirStat | Visual maps help users identify huge objects quickly | Charts and treemaps are projections over Rust read model and sync selection back to tree/details |
| Tree/table discovery | TreeSize, WizTree, OmniDiskSweeper | Size-sorted tree and file list remain the power surface | Virtualized tree/table is primary, sorted by size, paginated from Rust |
| Search and filters | WizTree, TreeSize, GrandPerspective, SpaceSniffer | Rich filters by name, path, size, allocated size, date, regex, tags, and scan-time excludes | Search/filter/sort are Rust queries. Flutter never filters a full transferred tree |
| Accuracy controls | TreeSize, WizTree | Hardlink/ADS/follow-link options improve accuracy but can slow scans | Scan profile exposes speed vs accuracy and boundary behavior before or during scan |
| Review before cleanup | DaisyDisk Collector, BleachBit Preview, CCleaner Analyze, CleanMyMac My Clutter | Selection and deletion are separate | Add to Queue is separate from DeletePlan, and DeletePlan is separate from execution |
| Safe delete | GNOME Trash, OmniDiskSweeper Trash, Hazel App Sweep | Trash/recoverable path is preferred for ordinary users | Move to Trash or provider-safe action is default. Permanent delete is advanced and not MVP default |
| Reclaim truth | DaisyDisk hidden/purgeable space, TreeSize/WizTree allocated size | Visible size and freed bytes can differ | UI separates logical size, allocated local size, exclusive reclaim estimate, confidence, and observed delta |
| Cloud files | OneDrive, Dropbox, Google Drive, iCloud | Local-only, online-only, syncing, error, and provider-managed states are distinct | Cloud actions are not generic deletes. Show local bytes, logical bytes, provider status, and propagation risk |
| Recommendations | Apple Storage, Windows Storage Sense, Files by Google, CleanMyMac | Suggestions are grouped and conservative | Recommendation cards need category, evidence, risk, confidence, and why-not-auto-selected |
| Duplicates | Files by Google, TreeSize | Duplicate cleanup needs original/keep rules and accuracy tradeoffs | Duplicate workflow is separate and post-MVP, with keep rules and stronger confirmation |
| App leftovers | Hazel, CleanMyMac, App Cleaner class products | Related files are shown after app intent and can be unchecked | Leftover cleanup needs app identity evidence, uncheckable items, and Trash receipt |
| Tool storage | CleanMyMac, Windows Storage, Docker/Xcode-style real-world usage | Tool caches and data stores need domain-specific handling | Prefer official cleanup adapters and classify persistent data separately from generated cache |
| Reports | TreeSize Professional, WizTree CSV export, WinDirStat reports | Power users need export, scheduled scans, and saved snapshots | Reports are explicit redacted operations with progress, cancellation, and receipts |
| Automation | Storage Sense, TreeSize CLI, BleachBit CLI, Hazel rules | Automation works when categories and policy are clear | Start with scheduled scans/reports and dry-run previews. Destructive automation is advanced |
| Diagnostics | Backblaze, sync/security tools | Support workflows need logs, status, and guided repair | Support bundle is previewable and redacted by default |
| Install/update | Sparkle, MSIX, Tauri, Apple Developer ID | Updates and package identity affect trust and permissions | Update must preserve helper identity or revalidate capability before claiming success |
| Accessibility | WAI-ARIA treegrid, Microsoft/Apple platform norms | Dense tables need keyboard, focus, selection, and screen reader semantics | Tree/table must separate focus from selection and expose row count, sort, expanded state, and selected state |
| Web/remote | Drive/Dropbox/Backblaze-style agents and local services | Browser UI is useful when backed by a local/remote agent | Web UI is a daemon client. It never pretends browser sandbox can scan full disk |

## Product Flows To Copy

### 1. Partial Scan Flow

```text
user scans target
  -> scanner returns results plus skipped/protected groups
  -> UI shows largest known items
  -> banner says "May be partial"
  -> issue drawer groups permission, symlink, mount, cloud, transient errors
  -> user can repair access and rescan
```

This is the GNOME Baobab plus DaisyDisk lesson: incomplete does not mean useless, but it must be labeled.

### 2. Safe Cleanup Flow

```text
user selects item or recommendation
  -> Add to Queue
  -> queue shows exact action and risk
  -> Generate DeletePlan
  -> revalidate path, identity, metadata, provider state, Trash support
  -> confirm
  -> execute
  -> receipt with outcomes and restore capability
```

This combines DaisyDisk Collector, BleachBit Preview, GNOME Trash, Hazel App Sweep, and CleanMyMac's category review. Clean Disk should not copy DaisyDisk's permanent-delete default for MVP.

### 3. Cloud Local-Reclaim Flow

```text
scan detects provider root
  -> classify provider state
  -> show logical cloud size and local allocated size separately
  -> prefer Remove Local Download when supported
  -> warn when Move to Trash propagates to cloud
  -> receipt records provider action and sync state
```

This copies OneDrive, Dropbox, Google Drive, and iCloud language. It prevents the classic user mistake: confusing "free local disk" with "delete account data".

### 4. Permission Doctor Flow

```text
capability issue detected
  -> card names affected feature
  -> card names scanner component identity
  -> user opens OS settings or runs repair action
  -> scanner process re-probes
  -> UI shows what changed
  -> support bundle is available if still broken
```

This copies Backblaze and CCC's real-process permission model and security tools' repair posture. Opening Settings is not proof.

### 5. Low-Space Rescue Flow

```text
low free space detected
  -> avoid large local caches and heavy preview generation
  -> prioritize cheap targets: Trash, Downloads, temp, local cloud copies, large installers
  -> delay app updates unless necessary
  -> show "need enough space for operation" warnings
```

This copies Windows update/storage guidance and OS storage assistants. A cleaner must not make low disk pressure worse.

### 6. Power User Report Flow

```text
user opens saved scan or completed scan
  -> chooses export type and redaction level
  -> daemon creates report from paginated read model
  -> operation can be canceled
  -> receipt records schema version and filters
```

This copies TreeSize Professional and WizTree export workflows, but with privacy defaults suitable for a consumer app.

## UX Patterns To Avoid Copying Blindly

- Permanent delete as the normal path. DaisyDisk does this for reclaim certainty, but Clean Disk should default to Trash/provider-safe actions.
- One-click "health" cleanup without evidence. CCleaner and PC Manager style simplicity is useful, but opaque cleanup lowers trust for a disk analyzer.
- Admin/root scan as the default. It can improve coverage, but it expands blast radius and breaks the analyzer-first trust model.
- Cloud placeholders as reclaimable local space. Online-only files may be logically huge but locally small.
- Visual map as the only navigation. GrandPerspective and SpaceSniffer are great for discovery, but Clean Disk also needs exact tree/table, details, queue, and receipts.
- Raw scheduled delete jobs for normal users. TreeSize/BleachBit/Hazel show automation is powerful, but destructive automation needs policy and dry-run.
- Hardlink deduplication as basic cleanup. TreeSize supports it, but it is filesystem-specific and advanced.
- Full raw path export by default. Reports and support bundles must default to redaction.
- A first-launch permission wall. Backup/security tools can justify it, but analyzer tools should first show useful scoped results.
- User-defined shell cleanup commands in normal UI. WinDirStat supports them, but Clean Disk should keep command adapters behind trusted policy/rule packs.

## Architecture Implications

### Rust Read Model

The Rust side needs product-level facts, not only pdu's tree:

```text
ScanSession
  -> ScanSnapshot
  -> NodeReadModel
  -> IssueGroup
  -> Recommendation
  -> SelectionSet
  -> DeletePlan
  -> OperationReceipt
```

Required query families:

```text
children_page
top_files
top_folders
search_results
filter_results
recommendation_candidates
details
issue_groups
selection_preview
delete_plan_preview
receipt
```

### Flutter UI

Flutter owns product interaction, not raw filesystem truth:

```text
Home target cards
Scan status bar
Virtualized tree/table
Details panel
Issue drawer
Recommendation cards
Cleanup queue
DeletePlan dialog
Receipt view
Permission Doctor
Report/export dialog
```

Important UI requirement for the design system:

- treegrid/table primitive with virtual rows, disclosure controls, roving focus, multi-select, column sort, row actions, and keyboard shortcuts;
- status badge primitive for `Complete`, `May be partial`, `Needs access`, `Advanced`, `Unavailable`;
- confirmation flow primitive that can show evidence, risk tier, stale checks, and disabled reasons;
- operation progress primitive that supports determinate and indeterminate phases;
- issue drawer/list primitive with grouped recoverable problems.

If Headless lacks any of these primitives, we should improve Headless instead of forcing one-off widgets into the app.

### Protocol

HTTP commands/queries plus WebSocket events remains appropriate:

```text
HTTP: create session, start scan, query pages, create selection set, generate DeletePlan, execute cleanup, fetch receipt
WS: scan status, progress summary, issue count changes, session state, operation state, daemon lifecycle
```

Rules:

- no one-event-per-file stream;
- every event has session id, sequence, timestamp, schema version, and resumability semantics;
- queries return pages and cursors;
- large counters and byte values are encoded safely for Flutter web;
- stale client selections become server-side validation errors, not silent best-effort deletion.

## Decisions Added From This Research

- Clean Disk will use product journeys, not standalone feature widgets, as the UX unit.
- Target picker, scan profile, scan quality, issue groups, recommendations, cleanup queue, DeletePlan, receipt, and Permission Doctor are product concepts.
- Recommendations are never a separate truth source. They are projections over the Rust read model.
- Large-file and old-file categories should not auto-select, following CleanMyMac's own "no advice" posture for user files.
- Filtered scan is a first-class scan profile option because GrandPerspective, WizTree, and TreeSize show it can improve speed and focus.
- Scan accuracy options must be visible because TreeSize/WizTree show hardlink, ADS, allocated-size, MFT/admin, and link-following behavior matters.
- Cloud provider actions need provider-specific wording and receipts.
- Low-space mode affects UX, logging, caching, update behavior, and scan resource profile.
- Reports and support bundles are operations with privacy levels and receipts.

## Implementation Priority

Top 3 next product/architecture spikes:

1. Product state and DTO contract spike - 🎯 9 🛡️ 9 🧠 7, roughly 500-1200 LOC.

   Define `ScanSessionState`, `ScanQuality`, `IssueGroup`, `RecommendationDto`, `SelectionSet`, `DeletePlanPreview`, `OperationReceipt`, and event envelopes before building major UI. This prevents UI rework when daemon behavior lands.

2. Tree/table and issue drawer UX prototype over fake paginated data - 🎯 9 🛡️ 8 🧠 6, roughly 800-1800 LOC.

   Validate density, keyboard navigation, selection vs focus, badges, skipped counts, and details panel before real scanner integration. This is the highest-value UI risk.

3. Recommendation/evidence/risk model spike - 🎯 8 🛡️ 9 🧠 8, roughly 700-1800 LOC.

   Define how a candidate becomes `Safe`, `Review`, `Risky`, or `Unsupported`, and what evidence must be shown. This protects us from becoming an opaque cleaner.

## Acceptance Criteria

- A new user can scan a useful target without a permission wall.
- A partial scan is useful and visibly incomplete.
- The largest folders/files are visible before any cleanup suggestion.
- Search, filter, sort, and top lists work on the daemon read model.
- Every cleanup action has evidence, risk, action type, and restore capability.
- The app never confuses local reclaim with cloud deletion.
- Permission repair proves access from the scanner process.
- Reports/support bundles default to redacted data.
- The UI stays dense, keyboard-friendly, and readable at wide and compact sizes.

## Summary

Clean Disk should be:

```text
DaisyDisk / TreeSize / WizTree discovery clarity
+ GrandPerspective / SpaceSniffer visual orientation
+ BleachBit / Hazel / GNOME Trash safety
+ OneDrive / Dropbox / Google Drive cloud-state honesty
+ Backblaze / CCC repair maturity
+ TreeSize Pro reporting path later
```

The important product lesson: fast scan earns attention, but honest action flow earns trust.
