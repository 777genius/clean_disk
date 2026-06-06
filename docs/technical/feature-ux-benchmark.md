# Feature UX Benchmark

Last updated: 2026-05-16.

This document records feature-level UX patterns from mature storage, cleanup, sync, backup, security, and platform products. It turns product research into concrete Clean Disk feature contracts.

## Sources Reviewed

- Apple Human Interface Guidelines, [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy/), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields), [Drag and drop](https://developer.apple.com/design/Human-Interface-Guidelines/drag-and-drop), [Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications), and Apple Support, [Free up storage space on Mac](https://support.apple.com/en-us/102624), [Optimize storage space](https://support.apple.com/en-gb/guide/mac-help/sysp4ee93ca4/mac), [iCloud Drive status](https://support.apple.com/en-euro/guide/mac-help/mchlc994344b/mac), [Time Machine local snapshots](https://support.apple.com/en-us/ht204015).
- Microsoft Support and Learn, [Storage settings](https://support.microsoft.com/en-us/windows/storage-settings-in-windows-5bc98443-0711-8038-4621-6a18ddc904f2), [Storage Sense](https://support.microsoft.com/en-us/windows/manage-drive-space-with-storage-sense-654f6ada-7bfc-45e5-966b-e24aded96ad5), [Free up drive space](https://support.microsoft.com/en-us/windows/free-up-drive-space-in-windows-85529ccb-c365-490d-b548-831022bc9b32), [Accessibility overview](https://learn.microsoft.com/en-us/windows/apps/design/accessibility/accessibility), [Fluent accessibility](https://fluent2.microsoft.design/accessibility), [Command bar](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/command-bar), [Contextual commanding](https://learn.microsoft.com/en-us/windows/apps/design/controls/collection-commanding), [App settings](https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings), [Notifications UX guidance](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/toast-ux-guidance), and [MSIX auto-update and repair](https://learn.microsoft.com/en-us/windows/msix/app-installer/auto-update-and-repair--overview).
- Google, [Material permissions](https://m1.material.io/patterns/permissions.html), [Material errors](https://m1.material.io/patterns/errors.html), [Material empty states](https://m1.material.io/patterns/empty-states.html), [Material data tables](https://m2.material.io/components/data-tables), [Material chips](https://m2.material.io/components/chips), [Material snackbars](https://m2.material.io/components/snackbars), [Files by Google](https://support.google.com/files/answer/9848742), [Google Photos storage](https://support.google.com/photos/answer/10100180), [Drive for desktop on macOS](https://support.google.com/drive/answer/12178485), [Drive troubleshooting](https://support.google.com/drive/answer/2565956/fix-problems-with-syncing-to-your-computer-computer), and [stream/mirror files](https://support.google.com/drive/answer/13401938).
- Flutter docs, [Actions and Shortcuts](https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts), [Focus](https://docs.flutter.dev/ui/interactivity/focus), [Work with long lists](https://docs.flutter.dev/cookbook/lists/long-lists), and [Web accessibility](https://docs.flutter.dev/ui/accessibility/web-accessibility).
- WAI-ARIA Authoring Practices, [Treegrid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/).
- DaisyDisk, [disks overview](https://daisydiskapp.com/guide/1/en/DisksOverview/), [Deleting files](https://daisydiskapp.com/guide/4/en/DeletingFiles), [Hidden space](https://daisydiskapp.com/guide/4/en/HiddenSpace/), [Scanning as administrator](https://daisydiskapp.com/guide/4/en/AdminScan/), and [Tips and tricks](https://daisydiskapp.com/guide/2/en/TipsAndTricks/).
- TreeSize, [scan options](https://manuals.jam-software.com/treesize/EN/scan_options.html), [scan tab](https://manuals.jam-software.com/treesize/EN/scan_tab.html), [charts](https://manuals.jam-software.com/treesize/EN/charts.html), [filter types](https://manuals.jam-software.de/treesize/EN/availablefiltertypes.html), [process search results](https://manuals.jam-software.de/treesize/EN/process_search_results.html), [duplicate file search](https://manuals.jam-software.com/treesize/EN/duplicate_file_search.html), [duplicate cleanup example](https://manuals.jam-software.com/treesize/EN/example_duplicatesearch.html), and [NTFS notes](https://manuals.jam-software.de/treesize/EN/notesonntfs.html).
- WinDirStat, [documentation](https://documentation.help/WinDirStat/), [Directory List](https://documentation.help/WinDirStat/directorytree.htm), [Cleanups](https://documentation.help/WinDirStat/actions.htm), and [user-defined cleanups](https://documentation.help/WinDirStat/userdefinedcleanups.htm).
- GNOME Disk Usage Analyzer, [scan folder](https://help.gnome.org/baobab/scan-folder.html), [permission errors](https://help.gnome.org/baobab/problem-permissions.html), [Trash delete](https://help.gnome.org/baobab/question-trash.html), and GNOME HIG, [Dialogs](https://developer.gnome.org/hig/patterns/feedback/dialogs.html).
- CleanMyMac, [safety and reliability](https://macpaw.com/support/cleanmymac/knowledgebase/cleanmymac-safety), CCleaner, [Health Check](https://www.ccleaner.com/ccleaner/health-check), [Health Check support](https://support.ccleaner.com/articles/en_US/Master_Article/what-is-health-check), [Custom Clean analysis](https://support.ccleaner.com/articles/en_US/Master_Article/custom-clean-s-analysis-and-results-function), BleachBit, [general usage](https://docs.bleachbit.org/doc/general-usage.html), [expert mode](https://docs.bleachbit.org/doc/expert-mode.html), [command line](https://docs.bleachbit.org/doc/command-line-interface.html), [shred/wipe](https://docs.bleachbit.org/doc/shred-files-and-wipe-disks.html), and Hazel, [App Sweep](https://www.noodlesoft.com/manual/hazel/hazel-basics/manage-your-trash/use-app-sweep/).
- Dropbox, [sync icons](https://help.dropbox.com/sync/sync-icons), [online-only files](https://help.dropbox.com/sync/make-files-online-only), [sync troubleshooting](https://help.dropbox.com/sync/files-not-syncing), and [macOS File Provider changes](https://help.dropbox.com/installs/macos-support-for-expected-changes).
- Microsoft OneDrive, [Files On-Demand](https://support.microsoft.com/en-us/office/sync-files-with-onedrive-files-on-demand-62e8d748-7877-420f-b600-24b56562aa70), [sync icons](https://support.microsoft.com/en-us/office/what-do-the-onedrive-icons-mean-11143026-8000-44f8-aaa9-67c985aa49b3), [sync troubleshooting](https://support.microsoft.com/en-us/office/fix-onedrive-sync-problems-52a86836-1e7f-46fd-85c7-1e7a5e9b4273), and [repair sync connections](https://support.microsoft.com/en-au/office/repair-sync-connections-in-onedrive-for-work-or-school-21aac895-9f32-4e3b-aa77-25f8a06f3a9c).
- Backblaze, [Full Disk Access install guide](https://help.backblaze.com/hc/en-us/articles/1260801754709-Installing-the-Backup-Client-on-Mac-for-OSX-10-14-and-Later), [FDA status report](https://help.backblaze.com/hc/en-us/articles/360011389154-Which-Users-Have-Granted-Backblaze-Full-Disk-Access), and [send logs to support](https://help.backblaze.com/hc/en-us/articles/14750819976731-How-to-send-logs-to-Backblaze-Mac).
- Carbon Copy Cloner, [Full Disk Access for app and helper](https://bombich.com/en/kb/ccc/6/granting-full-disk-access-ccc-and-its-helper-tool), Trend Micro, [Full Disk Access setup](https://helpcenter.trendmicro.com/en-us/article/TMKA-20794), Avast, [Full Disk Access](https://support.avast.com/en-ca/article/Mac-full-disk-access), Malwarebytes, [Real-Time Protection inactive](https://help.malwarebytes.com/hc/en-us/articles/31589209948059-Real-Time-Protection-inactive-on-macOS-device), and Norton, [repeated Full Disk Access prompt](https://support.norton.com/sp/en/us/home/current/solutions/v20221020120926278).
- Sparkle, [documentation](https://sparkle-project.github.io/documentation/), Electron, [code signing](https://www.electronjs.org/docs/latest/tutorial/code-signing), and Tauri, [updater signing](https://tauri.app/plugin/updater/).

## Accepted Feature UX Strategy

Top 3 strategies:

1. Feature contracts with shared product language - 🎯 10 🛡️ 9 🧠 7, roughly 3500-9000 LOC across Flutter surfaces, Rust DTOs, query adapters, and tests.

   Accepted. Each feature has a clear user promise, states, actions, and evidence model. This keeps the app coherent across macOS, Windows, Linux, web UI, and future remote mode.

2. One large scanner screen with everything inline - 🎯 6 🛡️ 7 🧠 5, roughly 1800-4500 LOC.

   Faster to build, but it will become hard to reason about once cleanup, cloud providers, duplicate search, and repair flows arrive.

3. Platform-specific UX per OS - 🎯 5 🛡️ 7 🧠 9, roughly 8000-20000 LOC.

   Native-feeling, but too expensive and risks fragmenting product behavior. Clean Disk should be platform-aware, not three separate products.

Deeper feature pass:

1. Contract-first feature UX with shared command/query/event semantics - 🎯 10 🛡️ 9 🧠 8, roughly 6000-16000 LOC across UI, daemon DTOs, indexes, persistence, tests, and docs.

   Accepted. Search, filter, sort, bulk selection, saved scans, export, automation, notifications, keyboard commands, and restore semantics must be product contracts first. UI components and transport adapters implement those contracts.

2. UI-first convenience polish without daemon/read-model contracts - 🎯 5 🛡️ 5 🧠 5, roughly 2500-7000 LOC.

   Looks fast initially, but breaks under large trees, reconnect, web UI, background scans, multi-client sessions, and delete safety.

3. Native clone per platform for each feature - 🎯 4 🛡️ 7 🧠 10, roughly 15000-40000 LOC.

   Could feel excellent on one OS, but too expensive for a universal Flutter app and would duplicate behavior across macOS, Windows, Linux, and web/remote.

## Feature Benchmark Matrix

| Feature | What mature products do | Clean Disk decision |
| --- | --- | --- |
| First launch | Apple/Material avoid premature permission prompts; disk tools start from a target or recent disk | Show real app surface with targets, no setup wall |
| Target selection | DaisyDisk supports disks, folders, drag/drop; GNOME encourages selected-folder scans for speed | Targets are cards/chips with quality badges and recent scans |
| Permission preflight | DaisyDisk scans partial; Backblaze/CCC/security apps verify real process/helper access | Preflight is non-blocking where safe, and repair requires scanner-process re-check |
| Scan progress | TreeSize and WinDirStat show progress and partial structure; Apple/Windows require feedback for long work | Multi-phase status: scanning, indexing, partial, paused, canceling, completed_partial |
| Results navigation | TreeSize/WinDirStat combine tree, columns, charts, extension lists; DaisyDisk uses visual map plus details | Tree/table is primary. Visual charts are supporting, never the only navigation |
| Search/filter/sort | Apple gives search a global toolbar presence; TreeSize exposes rich filters; Material uses chips/tables for applied filters | Search is global to current scan, filters are explicit chips, sort is server-side and reflected in cursor |
| Bulk selection | TreeSize supports checkbox-based batch selection; Windows requires context commands for every input type | Bulk actions operate on query snapshots, not only visible rows, and always preview before queue/delete |
| Details panel | Disk tools expose path, size, attributes, file count, modified time, warnings | Right details panel owns evidence, actions, warnings, and provider state |
| Recommendations | Apple/Windows/Google group cleanup into user-understandable categories | Recommendation cards sit on top of scan/read model and require evidence/risk |
| Cleanup queue | DaisyDisk Collector and BleachBit Preview keep deletion separate from selection | Queue is explicit. DeletePlan is generated after queue selection |
| Delete execution | GNOME uses Trash; Windows uses Recycle Bin; DaisyDisk blocks dangerous roots | Trash/provider action default, permanent delete later and advanced |
| Undo/restore | DaisyDisk has a short cancel window; Trash/Recycle Bin/provider recycle bins have platform semantics | Receipt records restore capability honestly. Undo means cancel before execution unless Trash/provider restore is proven |
| Duplicate search | TreeSize separates duplicate search and exposes comparison accuracy/speed tradeoff | Duplicate cleanup is an advanced separate workflow, not MVP default |
| Cloud/offline files | Dropbox/OneDrive/iCloud/Drive use status icons and dehydrate/remove-download actions | Local bytes, logical bytes, provider status, and delete propagation are first-class |
| Tool-managed storage | Hazel prefers official uninstallers; CleanMyMac uses safety database/ignore list | Use official tool cleanup adapters where possible. Unknown tool folders are Review/Risky |
| Low-space mode | OS storage tools assume user is already constrained | App must avoid big caches, cloud hydration, oversized logs, and update downloads |
| Saved scans/history | Enterprise disk tools save reports/snapshots; backup tools show task history | Saved scans are immutable snapshots with schema version, source target, scan profile, and completeness state |
| Compare scans | TreeSize-style snapshots help answer what grew | Compare is post-MVP but must use saved snapshot IDs, not live path assumptions |
| Export/reports | TreeSize exports PDF/Excel/CSV; support tools export logs | Export is paginated/redacted by default and must not leak raw paths unless user chooses that level |
| Keyboard/commanding | WAI-ARIA treegrid, Windows commanding, and Flutter Shortcuts/Focus expect keyboard-first dense tools | Tree/table commands use Actions/Intents, visible focus, context menu parity, and shortcut discoverability |
| Background notifications | OS/sync/backup products expose completion, error, and paused states | Notifications are sparse: scan completed, cleanup completed, attention needed, daemon lost, low-space risk |
| Automation/scheduling | Storage Sense automates conservative cleanup; BleachBit has CLI; Hazel uses rules | Automation is post-MVP and starts with reports/reminders. Destructive automation requires dry-run, policy, and receipts |
| Repair | OneDrive/Dropbox/Drive/security tools use checklists and repeated status prompts | Repair cards have problem, component, action, re-check, fallback |
| Settings | Microsoft settings are searchable and grouped; advanced settings are progressively disclosed | Settings include scan, cleanup, privacy, daemon, updates, advanced |
| Updates | Sparkle/MSIX/Tauri/Electron require signing and compatibility thinking | Update is a capability event: revalidate helper identity and daemon protocol |
| Diagnostics | Backblaze sends logs; Sentry-style guidance scrubs sensitive data first | Support bundle is previewable, redacted, and excludes raw paths by default |
| Accessibility | Apple/Microsoft require keyboard, screen reader, contrast, text scaling | Tree/table, queue, charts, and dialogs must be keyboard and screen-reader usable |
| Web/remote | Browser cannot scan disk directly; cloud agents expose connection state | Web UI is a client of local/remote daemon with explicit connection state |

## Feature Contracts

### 1. First Launch And Home

User promise:

```text
Open app
  -> pick useful scan target
  -> start without broad setup
```

Best pattern:

- show target cards: `Downloads`, `Home`, `Current Disk`, `Custom Folder`;
- show recent scans if available;
- show daemon status only if broken or remote;
- show package/capability badge without lecturing;
- default CTA is `Scan`, not `Grant Access`.

States:

```text
ready
daemon_starting
daemon_unavailable
no_recent_scans
has_recent_scans
package_limited
remote_connected
remote_disconnected
```

Must not:

- block first launch on Full Disk Access;
- explain Rust daemon architecture in the main screen;
- ask for admin/root just to start.

### 2. Target Picker And Scan Profiles

User promise:

```text
The app tells me how complete and safe a scan target is before I commit.
```

Target types:

```text
Downloads
Home
Library
Current disk
External volume
Network share
Cloud root
Custom folder
Remote target
```

Profile labels:

```text
Quick
Targeted
Full
External
Cloud
Network
Advanced
Background
```

Rules:

- selected-folder scan is always first-class;
- advanced scan must say what authority it needs;
- cloud/network/external targets show speed and confidence caveats before scan;
- target picker should remember safe recent targets;
- target history stores display names and stable identifiers, not raw full paths in telemetry.

### 3. Scan Progress And Control

User promise:

```text
The app keeps working while scanning, and I can pause/cancel without corrupting state.
```

Progress model:

```text
preflighting
scanning
indexing
enriching_metadata
partial_results_available
paused
canceling
completed
completed_partial
failed_recoverable
failed_blocked
```

Controls:

- pause/resume;
- cancel;
- reveal current scanned area only if safe;
- switch to Background mode;
- open scan issues.

Rules:

- throttle progress events;
- do not emit one event per file;
- UI should show files scanned, elapsed time, throughput, skipped count, and current path;
- post-indexing is a visible phase, not hidden delay;
- partial results can appear before scan completion if consistency rules allow it.

### 4. Results Tree, Table, And Visuals

User promise:

```text
I can quickly see the largest folders/files and drill down without losing context.
```

Primary view:

- virtualized tree/table;
- columns: name, size, percent, items, modified, status;
- sorted by size by default;
- selection drives details panel;
- row badges show status.

Supporting views:

- top files;
- top folders;
- extension breakdown;
- age breakdown;
- treemap/ring chart later;
- saved scan comparison later.

Rules:

- charts are linked to tree selection, not separate truth;
- all large queries are paginated from Rust;
- Flutter does not hold full tree;
- row actions are contextual and minimal: reveal, queue, ignore, details;
- keyboard navigation is required.

### 5. Details Panel

User promise:

```text
When I click an item, I understand what it is, why it is large, and what actions are safe.
```

Details include:

```text
display name
path
logical size
allocated local size
exclusive reclaim estimate
item count
file type
modified time
permissions
owner/provider/tool
warnings
scan confidence
available actions
```

Rules:

- details are query-backed;
- long paths are copyable and ellipsized;
- warnings are actionable;
- cloud/tool-managed/provider states are visible;
- actions are disabled with a reason, not silently hidden.

### 6. Recommendation Cards

User promise:

```text
The app helps me decide where to start without pretending it knows everything.
```

Card fields:

```text
category
title
reclaim estimate
risk tier
confidence
evidence count
primary action
secondary action
why shown
why not auto-selected
```

Candidate categories:

```text
Large files
Old downloads
Temporary files
Application caches
Developer caches
Logs
Duplicates
Screenshots
Cloud local copies
Trash / Recycle Bin
Unused app support
Tool-managed storage
Unknown large folders
```

Rules:

- cards are read-model projections over scan data;
- no recommendation without evidence;
- no auto-select for personal files, projects, cloud placeholders, app stores, SDKs, Docker volumes, or unknown tool folders;
- every recommendation has `Review` as an available path.

### 7. Cleanup Queue And DeletePlan

User promise:

```text
Nothing is deleted just because I clicked around.
```

Queue item fields:

```text
node id
display name
path preview
size estimate
risk tier
confidence
action type
identity snapshot
warnings
```

DeletePlan checks:

- path still exists;
- identity still matches;
- metadata still reasonable;
- target is not protected/root/system-critical;
- cloud/provider behavior is known enough;
- Trash/provider action is available;
- reclaim confidence is honest.

Execution result:

```text
moved_to_trash
provider_dehydrated
skipped_stale
skipped_permission
partial_success
failed
manual_action_required
```

Rules:

- final confirmation shows counts, risks, and action semantics;
- receipt is durable;
- observed free-space delta is optional and explicitly labeled;
- undo/restore expectations depend on platform Trash/provider semantics.

### 8. Cloud And Sync Providers

User promise:

```text
The app does not confuse cloud account data with local disk bytes.
```

Provider states:

```text
local
online_only
available_offline
syncing
paused
error
provider_managed
unknown
may_download_if_opened
```

Actions:

```text
Reveal
Remove local download
Make available offline
Open provider settings
Move to Trash
Ignore provider root
```

Rules:

- scan must not hydrate content;
- provider action is preferred over raw delete for local-copy reclaim;
- delete warning must mention cloud propagation;
- provider root operations are Review or Risky;
- local allocated size and logical cloud size are separate.

### 9. Duplicate Search

User promise:

```text
Duplicate cleanup is accurate enough for the chosen mode and never deletes the only trusted copy silently.
```

Modes:

```text
name_size_date_fast
partial_hash_balanced
full_hash_accurate
folder_duplicate_advanced
similar_media_later
```

Top product lesson:

- TreeSize separates duplicate search from normal scan;
- checksum comparison is slower but more accurate;
- grouping and batch selection need explicit rules.

Clean Disk decision:

- duplicate search is not MVP default;
- it becomes an advanced workflow with `keep newest`, `keep oldest`, `keep in primary folder`, and manual review;
- duplicate DeletePlan has stronger confirmation and receipt requirements.

### 10. Tool-Managed Storage

User promise:

```text
The app knows when a folder belongs to another tool and avoids breaking that tool.
```

Examples:

```text
Docker
Xcode
Android SDK / AVD
Gradle
Cargo
npm / pnpm / Yarn
Pub
pip
Homebrew
game launchers
cloud sync caches
browser profiles
```

Rules:

- prefer official cleanup command or app handoff;
- raw folder delete is Review/Risky unless adapter proves safe;
- persistent data and generated cache are separate;
- tool version and path conventions can change;
- adapters need rule versioning and evidence.

### 11. Repair And Permission Doctor

User promise:

```text
If something is limited, the app tells me exactly what to fix and proves the result.
```

Repair card:

```text
problem
affected feature
component identity
detected state
why it matters
action
re-check
last checked
fallback
support export
```

Rules:

- re-check runs from scanner/helper process;
- permission can regress after OS/app update;
- macOS app/helper/extension identities are separate;
- Windows policy and Linux package mode can make repair unavailable;
- repeated prompts become supportable states, not user blame.

### 12. Settings And Preferences

User promise:

```text
Common choices are easy, advanced choices are findable.
```

Settings groups:

```text
General
Scanning
Cleanup
Cloud providers
Permissions
Daemon
Updates
Privacy
Diagnostics
Advanced
```

Rules:

- settings search later;
- defaults are conservative;
- dangerous settings have clear labels and disabled-by-default posture;
- per-platform settings hide or explain unavailable items;
- settings changes that affect scan results should trigger a stale-results badge.

### 13. Updates And Install Repair

User promise:

```text
The app stays trustworthy after updates.
```

Rules:

- signed builds and signed update artifacts;
- daemon/helper version compatibility check;
- post-update capability revalidation;
- protocol mismatch creates an actionable repair state;
- no silent scanner downgrade;
- update download respects Low-space mode;
- uninstall offers to keep/delete local scan cache and receipts.

### 14. Diagnostics And Support

User promise:

```text
I can get help without leaking my filesystem.
```

Support bundle levels:

```text
summary_only
redacted_paths
include_selected_paths
developer_verbose_local_only
```

Rules:

- preview before export;
- redact usernames, raw paths, tokens, auth headers, search text, and delete target paths by default;
- include app version, daemon version, package mode, platform, scan profile, error groups, and capability probes;
- support bundle size is shown before export;
- low-space mode can block large support bundle generation.

### 15. Accessibility And Internationalization

User promise:

```text
The dense tool remains usable with keyboard, screen reader, scaling, contrast, and localization.
```

Rules:

- tree/table supports keyboard expansion, collapse, selection, sort, and row actions;
- charts have text alternatives and equivalent table data;
- color badges have text labels;
- focus states are visible;
- destructive confirmation is screen-reader clear;
- text scales without overlapping;
- paths are bidi-safe and copyable;
- numbers, dates, and byte units are localized;
- labels must not rely on filesystem jargon only.

### 16. Web UI And Remote Mode

User promise:

```text
The web UI is honest about where scanning runs.
```

Rules:

- browser never claims direct full-disk scan;
- local daemon connection status is visible;
- remote targets are scoped and read-only by default;
- destructive remote cleanup is not MVP;
- reconnection preserves operation IDs and event cursors;
- hosted web-to-localhost pairing remains future work.

## Deeper Feature Contracts

These contracts are accepted for product design and API shape. They may ship across MVP and post-MVP phases, but the architecture must not block them.

### Search, Filter, Sort

User promise:

```text
I can narrow a huge scan without waiting for Flutter to own the whole tree.
```

Best pattern:

- global search field scoped to the current scan/session;
- filter chips for active constraints;
- saved filter presets later;
- column sort state visible in the table header;
- query summary visible near results: matched items, total local bytes, completeness, stale state;
- all large result sets paginated and cancellable.

Filter dimensions:

```text
name
path
extension
kind
size_range
modified_range
created_range
accessed_range
depth
owner
permissions
provider_status
risk_tier
recommendation_category
warning_kind
tool_owner
hardlink_state
local_only / online_only
```

Rules:

- search/filter/sort runs in Rust over indexes and returns pages;
- Flutter owns query state and display, not full result computation;
- filters must never force cloud hydration or content reads unless a future explicit content-search mode is selected;
- result pages include `queryId`, `cursor`, `sort`, `filterSummary`, and `snapshotRevision`;
- stale results are labeled if the underlying scan/session changes;
- search text is sensitive data and must not appear in production logs/metrics.

### Bulk Selection And Batch Actions

User promise:

```text
I can select many things intentionally without accidentally deleting invisible results.
```

Selection modes:

```text
visible_rows
expanded_subtree
current_query_page
all_query_results
manual_queue
rule_based_candidate_set
```

Rules:

- selection is separate from focus;
- bulk selection over `all_query_results` requires a server-side `SelectionSetId`;
- UI must show whether the user selected visible rows or all matching results;
- changing filters/sort after bulk selection marks the selection as derived from a previous query;
- bulk delete is not delete. It only adds to queue or creates a previewable DeletePlan;
- every batch action returns per-item outcomes and grouped failures.

### Saved Scans, History, And Compare

User promise:

```text
I can return to a scan, compare growth, and know whether the data is old.
```

Snapshot fields:

```text
snapshot_id
target_display_name
target_identity
profile
started_at
finished_at
schema_version
app_version
daemon_version
scanner_adapter
completeness_state
root_size_summary
issue_summary
index_capabilities
retention_policy
```

Rules:

- saved scans are immutable read snapshots;
- snapshots are not authority for deletion until revalidated against live filesystem identity;
- compare uses snapshot IDs and stable node identity where possible, then falls back to path/name matching with lower confidence;
- history stores enough to explain completeness and skipped areas;
- retention defaults are conservative in Low-space mode.

### Export And Reports

User promise:

```text
I can share results without leaking more filesystem data than intended.
```

Export levels:

```text
summary_only
redacted_paths
selected_paths
full_paths_local_only
support_bundle
```

Formats:

```text
csv
json
html
pdf_later
sqlite_snapshot_later
```

Rules:

- export is an operation with progress, cancellation, and receipt;
- exports must be paginated/streamed from Rust or persisted snapshot data;
- default export redacts usernames and sensitive path segments;
- report must include scan profile, target, completeness, skipped count, and size accounting mode;
- no hidden full-tree export from UI debug actions.

### Keyboard, Context Commands, And Command Palette

User promise:

```text
The dense desktop tool is fast without a mouse and still works with assistive tech.
```

Required commands:

```text
scan
pause_resume
cancel
refresh
expand_collapse
expand_all_visible_limited
collapse_all
focus_search
clear_search
sort_column
open_context_menu
reveal
add_to_queue
remove_from_queue
open_details
copy_path
open_permission_doctor
move_focus_between_regions
```

Rules:

- implement via Flutter `Actions`, `Intents`, `Shortcuts`, and `FocusTraversalGroup`;
- context menu contains every row action, hover buttons are accelerators only;
- shortcut labels appear in tooltips/menus;
- treegrid separates selected row, focused row/cell, and queued item;
- charts are keyboard-readable through equivalent table/list data.

### Notifications And Background Work

User promise:

```text
The app tells me about long work only when it matters.
```

Notification events:

```text
scan_completed
scan_completed_partial
scan_failed
cleanup_completed
cleanup_partial
cleanup_blocked
daemon_disconnected
permission_repair_needed
low_space_blocked_operation
update_requires_recheck
```

Rules:

- no notification spam for normal progress;
- in-app status is primary while the window is active;
- OS notifications are for completion, blocked action, or user attention;
- every notification deep-links to the relevant scan/session/receipt when possible;
- background work has operation IDs and terminal states, not fire-and-forget tasks.

### Automation And Scheduling

User promise:

```text
Automation saves time without silently destroying data.
```

Accepted stance:

- MVP can support reminders and saved scan profiles;
- post-MVP can support scheduled scans and report generation;
- destructive scheduled cleanup is advanced and disabled by default.

Automation levels:

```text
reminder_only
scheduled_scan
scheduled_report
scheduled_safe_preview
scheduled_cleanup_requires_confirmation
admin_policy_later
```

Rules:

- automation starts with dry-run/preview;
- schedules respect battery, thermal, network, low-space, and user activity policies;
- cloud/provider and risky/tool-managed targets are excluded unless a future policy explicitly includes them;
- each automation run creates a receipt and can be audited;
- CLI/headless mode uses the same operation contracts as UI.

### Restore, Undo, And Receipts

User promise:

```text
After cleanup, I know exactly what happened and what can still be restored.
```

Restore capability states:

```text
cancelable_before_execution
trash_restore_likely
provider_restore_available
manual_restore_from_backup
not_restorable
unknown
```

Rules:

- undo during the pre-execution window cancels the operation;
- after execution, the app shows restore capability, not a vague Undo button;
- Trash/Recycling Bin/provider restore is platform-specific and must be represented honestly;
- receipts include action type, item count, byte estimate, observed free-space delta if measured, failures, skipped stale items, and restore hints;
- receipts never store raw full paths in telemetry.

## Feature Priority For MVP

1. Home target picker with package/capability badges - 🎯 10 🛡️ 9 🧠 5, roughly 900-2200 LOC.
2. Scan progress with partial/complete states - 🎯 10 🛡️ 9 🧠 6, roughly 1200-3000 LOC.
3. Virtualized tree/table and details panel - 🎯 10 🛡️ 9 🧠 8, roughly 3000-7000 LOC.
4. Recommendation cards backed by scan read model - 🎯 9 🛡️ 9 🧠 7, roughly 2200-5200 LOC.
5. Cleanup queue, DeletePlan, Trash action, receipt - 🎯 10 🛡️ 10 🧠 8, roughly 2500-6500 LOC.
6. Permission Doctor with scanner-process re-check - 🎯 9 🛡️ 9 🧠 7, roughly 1400-3600 LOC.
7. Cloud/local status labels without provider mutation - 🎯 9 🛡️ 8 🧠 7, roughly 1200-3200 LOC.
8. Low-space mode - 🎯 9 🛡️ 9 🧠 8, roughly 1200-3200 LOC.
9. Search/filter/sort over Rust indexes - 🎯 9 🛡️ 9 🧠 7, roughly 1800-4500 LOC.
10. Bulk queue actions with previewable selection sets - 🎯 8 🛡️ 9 🧠 8, roughly 1800-5200 LOC.
11. Keyboard/context command layer for tree/table/queue - 🎯 9 🛡️ 9 🧠 7, roughly 1500-4200 LOC.
12. Receipts and restore capability labels - 🎯 9 🛡️ 10 🧠 7, roughly 1200-3600 LOC.

Post-MVP:

- duplicate cleanup;
- official tool cleanup adapters;
- saved scan comparison;
- scan scheduling;
- advanced export/report formats;
- command palette;
- remote destructive actions;
- provider mutation actions beyond reveal/dehydrate where safe;
- advanced visualizations beyond core tree/table.

## Protocol And DTO Implications

Feature DTOs needed:

```text
TargetSummaryDto
ScanProfileDto
CapabilityBadgeDto
ScanPhaseDto
ScanIssueGroupDto
NodePageDto
NodeDetailsDto
RecommendationCardDto
CleanupQueueItemDto
DeletePlanDto
CleanupReceiptDto
ProviderStatusDto
RepairCardDto
LowSpaceModeDto
DiagnosticsBundlePreviewDto
UpdateCompatibilityDto
SearchQueryDto
SearchResultPageDto
FilterChipDto
SortDescriptorDto
SelectionSetDto
BulkActionPreviewDto
SavedScanSnapshotDto
ScanComparisonDto
ExportJobDto
CommandAvailabilityDto
NotificationEventDto
AutomationRuleDto
OperationReceiptDto
RestoreCapabilityDto
```

Rules:

- DTOs are product contracts, not direct domain entities;
- every DTO needs versioning/evolution strategy;
- large lists are paginated;
- IDs and byte counters are string-safe for Flutter web;
- actions include disabled reasons;
- every async operation has operation id, sequence, and terminal state;
- query, selection, export, automation, and receipt DTOs must carry snapshot/session revision when they depend on scan state;
- selection sets are server-side handles and must not require Flutter to send thousands of paths back to Rust;
- command availability is data, so the UI can explain disabled actions consistently across toolbar, context menu, shortcuts, and details panel.

## Hard UX Boundaries

Do not build:

- one-click all-clean button;
- startup Full Disk Access wall;
- raw permanent delete as primary action;
- cloud placeholder cleanup without local-byte proof;
- admin/root scan as default;
- settings-only permission proof;
- unredacted support bundle by default;
- full-tree transfer into Flutter;
- background updater that consumes critical low disk space;
- duplicate auto-delete without explicit grouping and keep rule.
- bulk action that silently applies to more rows than the user can see;
- export that leaks full raw paths by default;
- automation that deletes personal/cloud/tool-managed data without fresh preview and confirmation.
