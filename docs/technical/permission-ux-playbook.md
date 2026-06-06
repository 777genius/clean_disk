# Permission UX Playbook

Last updated: 2026-05-16.

This document records the user-facing permission model for Clean Disk across macOS, Windows, and Linux. It complements [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md).

The core decision is simple: permissions are part of scan quality, not a first-launch wall.

## Sources Reviewed

- Apple Human Interface Guidelines, [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy/). Relevant points: request access only to data actually needed; avoid asking before the user shows interest; avoid launch-time permission prompts unless access is required for the app to function.
- Apple Developer Documentation, [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/app_sandbox/accessing_files_from_the_macos_app_sandbox). Relevant points: selected files/folders and security-scoped bookmarks can extend access; Full Disk Access must be granted by the user in System Settings; apps must handle denied access defensively.
- Apple Developer Documentation, [PPPC Identity](https://developer.apple.com/documentation/devicemanagement/privacypreferencespolicycontrol/services-data.dictionary/identity). Relevant point: app bundles and nonbundled binaries are identified differently, and embedded helper tools inherit enclosing app permissions.
- Apple Developer Support, [Developer ID](https://developer.apple.com/support/developer-id/) and Apple Platform Security, [App code signing process in macOS](https://support.apple.com/en-ca/guide/security/sec3ad8e6e53/web). Relevant points: direct macOS distribution needs Developer ID signing and notarization for Gatekeeper trust; signing proves the app has not been tampered with; notarization means Apple checked it for known malware.
- Google Material Design, [Permissions](https://m1.material.io/patterns/permissions.html). Relevant points: ask in context, provide immediate benefit, ask only for permissions needed by the invoked feature, educate before or during less obvious permission requests, and explain denied permissions with a recovery path.
- CleanMyMac Support, [Full Disk Access permission](https://macpaw.com/support/cleanmymac-x/knowledgebase/full-disk-access). Relevant point: cleanup/security apps often request FDA because without it they cannot scan all junk or malware locations.
- CleanMyMac Support, [Safety and reliability](https://macpaw.com/support/cleanmymac/knowledgebase/cleanmymac-safety). Relevant points: mature cleanup tools use a safety database, default to automatically generated/system/app-related data, avoid selecting personal files unless the user explicitly chooses them, and support ignore lists.
- DaisyDisk User Guide, [Full Disk Access](https://daisydiskapp.com/guide/full-disk-access), [Hidden space](https://daisydiskapp.com/guide/4/en/HiddenSpace/), and [Restricted folders](https://daisydiskapp.com/guide/4/en/Restricted/). Relevant points: disk analyzers can scan without Full Disk Access, show hidden/restricted space, and ask users to rescan after granting access.
- DaisyDisk User Guide, [Scanning as administrator](https://daisydiskapp.com/guide/4/en/AdminScan/). Relevant points: administrator scan is not available in the Mac App Store edition, normal scan is faster and enough in most cases, admin scan is for significant hidden space, and quick rescan can save time.
- GrandPerspective Help, [Full Disk Access](https://grandperspectiv.sourceforge.net/HelpDocumentation/FullDiskAccess.html). Relevant point: Full Disk Access improves coverage but still cannot guarantee every file is readable.
- GrandPerspective Help, [Preferences](https://grandperspectiv.sourceforge.net/HelpDocumentation/Preferences.html). Relevant points: deletion can be disabled or limited to files/folders, confirmation can be required, and deleting folders can affect files that were filtered, unscanned, or added after the scan.
- Backblaze Help, [Installing the backup client on macOS 10.14 and later](https://help.backblaze.com/hc/en-us/articles/1260801754709-Installing-the-Backup-Client-on-Mac-for-OSX-10-14-and-Later) and [which users have granted Full Disk Access](https://help.backblaze.com/hc/en-us/articles/360011389154-Which-Users-Have-Granted-Backblaze-Full-Disk-Access). Relevant points: backup apps need FDA to back up protected Apple app data and expose permission status to administrators.
- Carbon Copy Cloner Documentation PDF, [CCC 6 documentation](https://bombich.com/doc-pdf/ccc6-documentation-en.pdf). Relevant point: backup tools may need FDA for both app and helper tool, making helper identity visible in permission UX.
- Google Drive Help, [Use Drive for desktop on macOS](https://support.google.com/drive/answer/12178485). Relevant points: sync apps request macOS permissions only for folders/devices the user chooses to sync, and changes may require restart.
- Microsoft Support, [Back up your folders with OneDrive](https://support.microsoft.com/en-us/office/work-on-the-go-with-onedrive-8ce30c76-e27b-4e55-9050-082393954213). Relevant points: OneDrive macOS folder backup requires standalone sync app and Full Disk Access; IT policy can disable capabilities.
- Dropbox Help, [Fix Dropbox files not syncing](https://help.dropbox.com/sync/files-not-syncing) and [Expected changes with Dropbox for macOS on File Provider](https://help.dropbox.com/installs/macos-support-for-expected-changes). Relevant points: mature sync apps keep visible sync/access status, provide repair checklists, require app restart after permission changes, and cloud-provider APIs can change apparent local disk usage, online-only behavior, external drive support, and file operation limits.
- Malwarebytes Help, [Allow Full Disk Access on macOS](https://help.malwarebytes.com/hc/en-us/articles/39633984494235-Allow-Full-Disk-Access-on-macOS-device). Relevant point: endpoint security products need FDA for thorough scans and real-time protection.
- Avast Support, [Enabling Full Disk Access](https://support.avast.com/en-ca/article/Mac-full-disk-access) and [Mac scans](https://support.avast.com/en-us/article/mac-security-malware-scan). Relevant points: security apps separate scan types such as smart, deep, targeted, external storage, and custom scans; deep protection requires broader access.
- Norton Support, [Allow all permissions on macOS](https://support.norton.com/sp/en/us/home/current/solutions/v20240130170216702). Relevant point: security tools treat FDA and other protection permissions as enabling full protection and hidden-threat scans.
- Trend Micro Help Center, [Cleaner One Pro Full Disk Access](https://helpcenter.trendmicro.com/en-us/article/tmka-21628). Relevant point: cleanup tools provide OS-version-specific manual steps for granting FDA.
- Microsoft Learn, [User Account Control](https://learn.microsoft.com/en-us/windows/win32/secauthz/user-account-control). Relevant point: UAC lets users run common tasks as standard users and elevate only tasks requiring administrator privileges.
- Microsoft Learn, [Launch Windows Settings](https://learn.microsoft.com/en-us/windows/apps/develop/launch/launch-settings). Relevant point: Windows documents `ms-settings:privacy-broadfilesystemaccess` for file system privacy settings.
- Microsoft Learn, [File access permissions](https://learn.microsoft.com/en-us/windows/apps/develop/files/file-access-permissions). Relevant points: packaged apps can use pickers, future access lists, and restricted broad file-system access; users can change access in Settings and apps must be resilient.
- Microsoft Support, [Manage drive space with Storage Sense](https://support.microsoft.com/en-us/windows/manage-drive-space-with-storage-sense-654f6ada-7bfc-45e5-966b-e24aded96ad5) and [Free up drive space in Windows](https://support.microsoft.com/en-us/windows/free-up-drive-space-in-windows-85529ccb-c365-490d-b548-831022bc9b32). Relevant points: Windows separates automatic cleanup from reviewable cleanup recommendations, does not touch Downloads or cloud content by default unless configured, and distinguishes personal files from temporary/system cleanup.
- Microsoft Learn, [Configure Storage Sense in Windows](https://learn.microsoft.com/en-us/windows/configuration/storage/storage-sense). Relevant point: fleet cleanup policy is configurable through Intune, CSP, Group Policy, and Settings, so enterprise mode needs policy visibility rather than consumer-style prompts.
- Microsoft PC Manager, [official product page](https://pcmanager.microsoft.com/en-us). Relevant point: Microsoft frames cleanup as storage management, large-file discovery, Storage Sense integration, and quiet/reliable maintenance rather than raw filesystem deletion.
- Apple Support, [Free up storage space on Mac](https://support.apple.com/en-us/102624), [Find and delete files on your Mac](https://support.apple.com/en-gb/guide/mac-help/syspf5a64aa6/mac), and [Optimize storage space on your Mac](https://support.apple.com/en-tm/guide/mac-help/sysp4ee93ca4/mac). Relevant points: macOS uses category-based storage views, large-file review, app handoff for category-specific deletion, Trash-based deletion, and automatic safe cache/log cleanup when space is needed.
- JAM Software TreeSize Manual, [General scan options](https://manuals.jam-software.com/treesize/EN/scan_options.html), [Scan tab](https://manuals.jam-software.com/treesize/EN/scan_tab.html), [Installation](https://manuals.jam-software.com/treesize/EN/installation.html), and [Notes on NTFS](https://manuals.jam-software.de/treesize/EN/notesonntfs.html). Relevant points: mature analyzers expose scan accuracy/performance options, follow-mount policies, pause/resume/stop, watch-for-changes, export, portable/installable modes, NTFS hardlink/ADS/dedup caveats, and administrator/backup privilege paths for restricted folders.
- WinDirStat Documentation, [Cleanups](https://documentation.help/WinDirStat/actions.htm) and [User Defined Cleanups](https://documentation.help/WinDirStat/userdefinedcleanups.htm). Relevant points: disk analyzers commonly offer reveal/open/copy-path/delete actions, separate Recycle Bin delete from irreversible delete, refresh stale items after cleanup, and treat custom cleanup commands as expert features.
- GNOME Disk Usage Analyzer, [help index](https://help.gnome.org/baobab/), [scan folder](https://help.gnome.org/baobab/scan-folder.html), [error when scanning](https://help.gnome.org/baobab/problem-permissions.html), [delete folder](https://help.gnome.org/baobab/question-trash.html), and [slow scan](https://help.gnome.org/baobab/problem-slow-scan.html). Relevant points: selected folder scans are faster, scan errors from unreadable folders mean results may be incomplete, deletion goes through Trash, and scan speed depends on media, remote paths, tree depth, and file count.
- GNOME Human Interface Guidelines, [Dialogs](https://developer.gnome.org/hig/patterns/feedback/dialogs.html). Relevant points: dialogs are disruptive and should be used when the user must respond; non-critical errors can use less disruptive surfaces; destructive actions need confirmation or undo where possible.
- Flatpak Documentation, [Sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html). Relevant points: default sandbox has limited host access; broad filesystem access should be minimized.
- Flathub Documentation, [Modifying default permissions](https://docs.flathub.org/docs/for-users/permissions). Relevant points: users can inspect and override Flatpak permissions, and maintainers are encouraged to keep default permissions limited.
- GNOME Developer Documentation, [File Dialogs](https://developer.gnome.org/documentation/tutorials/beginners/components/file_dialog.html). Relevant point: native file dialogs are preferred and work better with sandboxed environments.
- XDG Desktop Portal Documentation, [FileChooser](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.FileChooser.html). Relevant point: sandboxed apps can ask the user for file/folder access through a portal.
- Snapcraft Documentation, [home interface](https://snapcraft.io/docs/home-interface) and [removable-media interface](https://snapcraft.io/docs/reference/interfaces/removable-media-interface/). Relevant points: Snap home access excludes hidden files by default, and removable media usually requires a separate interface.
- WizTree, [Windows disk analyzer](https://wiztree.app/). Relevant point: administrator mode enables fastest NTFS MFT scanning, but standard user/basic scan remains a valid mode.

## UX Decision

Top 3 approaches:

1. Permission ladder with target preflight - 🎯 10 🛡️ 9 🧠 6, roughly 1200-2600 LOC across UI components, capability DTOs, platform probes, and tests.

   Accepted. This gives users value immediately, keeps platform details out of the happy path, and makes partial scans honest.

2. Permission Doctor first-run wizard - 🎯 6 🛡️ 8 🧠 7, roughly 900-2200 LOC.

   Useful as an optional repair surface, not as the first screen. Too much setup before user value.

3. Max-permission onboarding - 🎯 3 🛡️ 5 🧠 4, roughly 400-1000 LOC.

   Rejected. It causes trust friction, still cannot guarantee full access, and differs too much across platforms.

Accepted principle:

```text
User intent -> capability preflight -> scan with honest completeness -> guided improvement -> rescan.
```

## What Top Products Usually Do

Different product categories ask for permissions at different times. Clean Disk should copy the disk-analyzer pattern for scan, and the backup/cleanup pattern only for explicit cleanup or full-coverage workflows.

### Pattern 1 - Disk Analyzer Scan-First

Examples:

- DaisyDisk scans what it can, puts unaccounted restricted space into hidden space, and asks the user to grant access/rescan to reveal more.
- GrandPerspective recommends Full Disk Access but documents that FDA still cannot read every file.
- WizTree keeps standard scan usable and treats administrator/MFT access as the fastest NTFS path, not the only path.

Takeaway for Clean Disk:

- default to scan-first;
- show hidden/restricted/skipped as a first-class result;
- provide `Improve access` and `Rescan`;
- do not make full access a first-launch gate.

Fit: 🎯 10 🛡️ 9 🧠 6, roughly 1200-2600 LOC.

### Pattern 2 - Backup/Sync Setup Gate

Examples:

- Backblaze needs FDA to back up Apple app data and exposes FDA status in reports.
- Carbon Copy Cloner documents helper-tool FDA because the helper performs privileged filesystem work.
- OneDrive macOS folder backup requires the standalone sync app and Full Disk Access for Desktop/Documents backup.
- Google Drive asks for macOS permission when syncing selected folders/devices such as Desktop, Documents, Downloads, removable/network volumes, or Photos.

Takeaway for Clean Disk:

- use setup-gate style only for features that cannot honestly work without access, such as complete full-disk scan or protected cleanup;
- expose helper/scanner identity clearly;
- after settings change, require restart/recheck/rescan when platform needs it;
- admin/business reporting can include permission status later, but consumer UI should stay simpler.

Fit: 🎯 7 🛡️ 8 🧠 8, roughly 1600-3800 LOC if applied broadly. Too heavy as the default Clean Disk first-run flow.

### Pattern 3 - Security/Cleanup Permission Center

Examples:

- CleanMyMac asks for Full Disk Access to scan all junk/malware areas and centralizes permission explanation in support docs and app permission management.
- Backup/security products tend to provide a dedicated setup/repair area because missing permission means missing protection.

Takeaway for Clean Disk:

- Permission Doctor is important, but should be a repair/settings surface;
- use it for users who want full completeness, cleanup readiness, or support diagnostics;
- do not force it before the first useful scan.

Fit: 🎯 8 🛡️ 8 🧠 7, roughly 900-2200 LOC as an optional panel.

### Accepted Hybrid

Clean Disk combines:

```text
Disk analyzer scan-first UX
+ Backup-style explicit identity/probe for the Rust scanner/helper
+ Cleanup-style delete preflight and receipt
```

This is the most user-friendly cross-platform model because it preserves immediate value and still handles destructive work rigorously.

## Competitive Pattern Matrix

| Product/category | Permission behavior | User-friendly lesson | Clean Disk decision |
| --- | --- | --- | --- |
| DaisyDisk | Scans what it can, explains hidden/restricted space, prompts for FDA/rescan to reveal more | Partial scan is valuable if completeness is honest | Copy for normal scan UX |
| GrandPerspective | Recommends FDA but warns it still cannot read everything | Do not overpromise full access | Copy for copywriting and confidence |
| WizTree | Standard scan works; administrator/MFT path gives fastest NTFS scan | Admin is a performance/coverage mode, not default | Copy for Windows Advanced mode |
| TreeSize/FolderSizes-style tools | Admin/backup privileges can improve access to denied folders | Power-user modes need clear authority boundaries | Later, advanced read-only first |
| CleanMyMac/Trend Micro cleaners | FDA requested to scan/remove more junk and protected data | Cleanup apps can justify broader access after value is clear | Use for cleanup preflight and Permission Doctor |
| Malwarebytes/Avast/Norton | FDA enables thorough/deep scans and real-time protection | Security tools can use setup gate because protection is the core product | Do not use as first-run default for Clean Disk scan |
| Backblaze | FDA is required for protected app data backup and status is reportable | Background agents need explicit status/probe reporting | Copy scanner-helper identity probe |
| Carbon Copy Cloner | App and helper may both need FDA | Helper identity must be visible and testable | Copy exact helper naming in guidance |
| Google Drive | Requests permissions for chosen sync folders/devices; restart may be needed | Ask in context of selected folder/device | Copy target-intent permission timing |
| OneDrive | Folder backup has setup requirements and admin/IT policy limits | Enterprise policy can make features unavailable | Copy `Unavailable` state and policy reason |
| Flatpak/GNOME portals | User-selected file/folder via native dialog grants access | Portal picker is the friendly sandbox path | Copy for Linux sandboxed builds |

## Deeper Product Benchmark Findings

This section records what changes when we look beyond permission prompts and compare actual storage-product flows.

### Built-In OS Storage Tools

Examples:

- Apple Storage uses category views, large-file review, `Show in Finder`, and app handoff for category-specific cleanup.
- macOS distinguishes free, available, purgeable, cache/log cleanup, Trash, iCloud offload, and system-managed data.
- Windows Storage Sense separates automatic cleanup from reviewable cleanup recommendations.
- Windows does not delete Downloads or cloud content by default unless the user or policy configures it.
- Enterprise Windows cleanup is policy-driven through Intune, CSP, Group Policy, or Settings.

Takeaway for Clean Disk:

- cleanup candidates must be grouped by safety and source, not just by size;
- default cleanup should start with reviewable recommendations, not automatic removal;
- `Downloads`, cloud placeholders, and user documents need conservative defaults;
- enterprise/fleet policy belongs in later admin mode, not consumer onboarding;
- show `Move to Trash`, `Free after emptying Trash`, and `Observed free-space delta` as separate facts.

Fit: 🎯 10 🛡️ 9 🧠 7, roughly 1800-4200 LOC across rule engine, delete plan, UI groups, receipts, and policy DTOs.

### Mature Disk Analyzer Tools

Examples:

- TreeSize exposes scan accuracy options for hardlinks, ADS, mount points, age statistics, extension statistics, owners, and network unreadable-folder errors.
- TreeSize supports pause/resume/stop, automatic updates from filesystem notifications, search, export, compare with saved scans, and portable/installable distribution.
- TreeSize documents NTFS edge cases such as hardlinks, deduplication, alternate data streams, offline files, administrator rights, and backup privileges.
- DaisyDisk models hidden/restricted space instead of pretending every byte is attributable.
- WizTree-class UX treats fast NTFS/MFT/admin scanning as a special faster path, not the only useful path.

Takeaway for Clean Disk:

- advanced scan accuracy toggles should be capability-backed and explain speed/memory impact;
- follow symlink/mount/reparse policies must be explicit per scan profile;
- pause/resume/stop are product-grade requirements, not nice-to-have controls;
- export/saved-scan compare are strong later differentiators;
- unreadable folders should become grouped scan issues, never interrupting modal spam;
- Windows MFT/admin path can be a future adapter, while normal recursive scan remains the default.

Fit: 🎯 9 🛡️ 9 🧠 8, roughly 2500-7000 LOC depending on how much of pause/resume, watchers, compare, export, and accuracy options ship in MVP.

### Backup And Sync Tools

Examples:

- Backblaze asks for access during setup because missing access means missing protected backups.
- Backblaze reports Full Disk Access status for admins.
- Carbon Copy Cloner documents app/helper identity because helper tools perform privileged filesystem work.
- Google Drive asks for macOS permissions in context of selected sync folders/devices.
- OneDrive's folder backup on macOS requires the standalone sync app, Full Disk Access, and may be disabled by IT policy.

Takeaway for Clean Disk:

- scanner identity and package mode must be visible in diagnostics;
- target-specific permission timing is better than global startup prompts;
- settings repair must end with scanner-process re-probe;
- IT policy and package limitations must map to `Unavailable` or `Advanced`, not generic failure.

Fit: 🎯 9 🛡️ 9 🧠 7, roughly 1200-3200 LOC across capability probes, helper identity, Permission Doctor, and support export.

### Cleaner And Security Tools

Examples:

- CleanMyMac justifies Full Disk Access through cleaning, maintenance, protection, notarization, local operation, and safety database messaging.
- Avast exposes scan types: smart, deep, targeted, external storage, and custom scheduled scans.
- Norton/Malwarebytes-style tools use protection setup flows because thorough protection is the core promise.

Takeaway for Clean Disk:

- scan types should be explicit: Quick, Targeted, Full, External, Advanced;
- permission copy must say what is read and what is not read;
- cleanup recommendations need evidence and risk tiers;
- if we introduce scheduled/background cleanup later, it needs a separate consent model.

Fit: 🎯 8 🛡️ 8 🧠 7, roughly 1800-4800 LOC if we include rule evidence, scheduling, and permission repair.

## Final Cross-Platform UX Recommendation

Top 3 options after the deeper benchmark:

1. Analyzer-first product with progressive capability ladder - 🎯 10 🛡️ 9 🧠 7, roughly 3000-7500 LOC.

   Accepted. This matches DaisyDisk/GrandPerspective/WizTree-style trust, while borrowing OS cleanup recommendations and backup-helper identity checks. It is the best default for a cross-platform disk analyzer that can also clean up.

2. Cleaner-first product with upfront full-access setup - 🎯 5 🛡️ 7 🧠 6, roughly 2200-5800 LOC.

   Good for antivirus/maintenance suites, weaker for Clean Disk because users want to inspect space first. It would make us feel heavier and less trustworthy before the first result.

3. OS-native cleanup companion with minimal custom scanner - 🎯 6 🛡️ 8 🧠 5, roughly 1200-3500 LOC.

   Safer and simpler, but not ambitious enough. It gives recommendations but does not solve the user's main problem: fast, detailed tree/table visibility across large folders.

Accepted product shape:

```text
fast scan-first analyzer
+ honest completeness model
+ optional advanced authority
+ conservative cleanup recommendation engine
+ explicit delete plan and receipt
+ Permission Doctor for repair/support
+ later enterprise/policy mode
```

## Top-Tier Product Rules

These are implementation rules to make the app feel like a mature tool rather than a prototype.

1. First useful result must not require broad access.
2. Every scan result shows completeness and skipped groups.
3. Big folders and big files are visible before cleanup recommendations.
4. Cleanup candidates are separated into `Safe`, `Review`, `Risky`, and `Unsupported`.
5. System/tool-managed data uses official cleanup adapters when available.
6. Delete is always a plan: selected items, identity revalidation, expected reclaim, confidence, and final receipt.
7. Downloads and cloud placeholders are never auto-selected by default.
8. Advanced authority is read-only first.
9. Permission repair always re-probes from the actual scanner process.
10. Error dialogs do not appear during normal scanning; issues accumulate as grouped facts.
11. Scan profile controls explain speed, memory, accuracy, and boundary tradeoffs.
12. Cross-platform UI vocabulary stays stable even when platform adapters differ.

## MVP User Flow

Best first-run flow:

```text
open app
  -> show last scan or empty analyzer surface
  -> background capability probe
  -> show target chips: Downloads, Home, Disk, Custom
  -> recommend Downloads or Custom for first quick scan
  -> user scans
  -> table/tree appears as soon as page data is available
  -> skipped/protected banner if needed
  -> user selects folder/file
  -> details panel shows size, path, modified, permissions, warnings
  -> cleanup candidates are suggestions, not automatic selections
  -> delete queue requires explicit confirmation and receipt
```

Best full-disk flow:

```text
user selects Disk or Home
  -> preflight says Complete / May be partial / Needs access
  -> actions: Scan Anyway, Improve Access, Choose Folder
  -> scan result has completeness badge
  -> Improve Access opens guidance
  -> user returns
  -> Re-check from scanner process
  -> Rescan
```

Best advanced Windows flow:

```text
normal user scan first
  -> if NTFS/full system target and user wants speed/completeness:
      Advanced scan
      explain admin/MFT read-only mode
      UAC only after explicit action
      normal delete path remains separately confirmed
```

Best Linux flow:

```text
native package: current-user scan first
sandboxed package: portal-selected folder first
root/system scan: later advanced read-only profile, not MVP default
```

## Deeper Cross-Platform UX Decisions

These decisions come from comparing top platform guidance, OS storage tools, disk analyzers, cleanup suites, and sync/backup apps.

### 1. Permission Timing Must Follow Visible Intent

Accepted approach: contextual permission prompts - 🎯 10 🛡️ 9 🧠 6, roughly 900-2200 LOC.

Why:

- Apple and Material guidance converge on the same pattern: ask only when the user understands why.
- Google Drive and Dropbox request access when sync folders/devices need it, not because the app launched.
- Disk analyzers such as DaisyDisk show useful partial results first, then ask for more authority to reduce hidden space.

Clean Disk rule:

```text
target selected
  -> capability preflight
  -> explain concrete missing access
  -> offer Scan Anyway / Improve Access / Choose Folder
```

Never show broad access requests on first launch unless we later ship a mode whose whole purpose cannot function without it.

### 2. Distribution Mode Is Part Of Product UX

Accepted approach: direct signed installer as primary full scanner path - 🎯 9 🛡️ 9 🧠 7, roughly 1600-4000 LOC across packaging, signing, update, and Permission Doctor detection.

Platform implications:

- macOS: primary distribution should be Developer ID signed and notarized direct app. App Store builds may be reduced because sandbox and store policy can limit admin/helper/system scanning.
- Windows: primary consumer distribution should be a signed installer. Portable zip can be offered later for read-only scan, but must make update, trust, daemon lifecycle, and firewall behavior explicit.
- Linux: AppImage/deb/rpm is the most honest full desktop scanner route. Flatpak/Snap can exist as reduced-capability packages with portal-first selected-folder scan.

Clean Disk rule:

```text
packageMode = direct_signed | portable | app_store | msix | appimage | deb_rpm | flatpak | snap | remote
```

`packageMode` must be shown in Permission Doctor and included in capability probes because it changes what "full scan" can honestly mean.

### 3. Cleanup Must Feel Like Review, Not Magic

Accepted approach: recommendation review with risk tiers - 🎯 10 🛡️ 10 🧠 8, roughly 2200-6200 LOC.

Why:

- Apple and Windows built-in storage tools show categories and recommendations, not a blind delete button.
- CleanMyMac relies on safety database, smart selection, and ignore lists.
- WinDirStat separates Recycle Bin delete from irreversible delete.
- GrandPerspective warns that deleting a folder may affect hidden, filtered, unscanned, or newly added files.

Clean Disk tiers:

```text
Safe
Review
Risky
Unsupported
```

Rules:

- default selection can include only high-confidence generated cache/log/temp data;
- personal files, Downloads, cloud placeholders, archives, project folders, developer stores, and tool-managed data are never auto-selected;
- irreversible delete is not MVP default;
- delete queue must show stale-scan risk and revalidate identity before action.

### 4. Cloud And File Provider Storage Need First-Class Labels

Accepted approach: local-vs-cloud accounting labels - 🎯 9 🛡️ 9 🧠 8, roughly 1600-4800 LOC.

Why:

- Dropbox and Google Drive File Provider behavior changes local path, local size, online-only behavior, search behavior, external drive behavior, and file availability.
- Windows Storage Sense can dehydrate cloud-backed content.
- macOS can make iCloud-backed files available on demand.

Clean Disk UI labels:

```text
Local bytes
Cloud placeholder
Available offline
Online-only
Provider-managed
May download if opened
```

Rules:

- scanning must not accidentally hydrate/download online-only files;
- cleanup must not treat cloud placeholders as local reclaim unless allocated local bytes are proven;
- delete copy must explain whether delete propagates to cloud;
- "reclaimed" must distinguish local storage from cloud/account storage.

### 5. Advanced Scan Modes Must Explain Speed, Coverage, And Risk

Accepted approach: explicit scan profiles - 🎯 9 🛡️ 9 🧠 7, roughly 1400-3600 LOC.

Mature products expose scan modes because one mode cannot optimize everything:

- DaisyDisk says normal scan is faster and enough in most cases; admin scan is for significant hidden space.
- TreeSize exposes accuracy options that can slow scans.
- Avast exposes smart, deep, targeted, external, and custom scans.
- GNOME explains slow scans by media, remote paths, tree depth, and file count.

Clean Disk scan profiles:

```text
Quick
Targeted
Full
External
Advanced
Background
```

Rules:

- `Quick` and `Targeted` are default user-friendly choices;
- `Advanced` is read-only first and may require elevation or package changes;
- `Background` prioritizes responsiveness and battery;
- profile copy must say speed, coverage, memory, and permissions impact.

### 6. Repair UX Must Be A Checklist With Proof

Accepted approach: Permission Doctor plus platform-specific repair cards - 🎯 9 🛡️ 9 🧠 7, roughly 1200-3400 LOC.

Why:

- Dropbox uses a checklist style for sync/access failures.
- Backblaze exposes status reporting for FDA.
- Windows and Flathub expose policy/permission settings that can be changed outside the app.
- Opening settings is not proof that anything changed.

Clean Disk repair card shape:

```text
problem
why it matters
exact component identity
recommended action
manual fallback
re-check
last probe result
```

Rules:

- all repair cards end in scanner-process `Re-check`;
- no success state without observed probe;
- if policy/package mode makes repair impossible, say `Unavailable` with a fallback target.

### 7. Large-Scale Results Need Progressive Disclosure

Accepted approach: overview first, paginated details on demand - 🎯 10 🛡️ 9 🧠 8, roughly 2500-7000 LOC across Rust indexes, protocol pagination, Flutter virtualization, and cache.

Why:

- OS tools start with categories and large files.
- Disk analyzers pair tree/list views with visual summaries.
- Large remote/network/deep scans can take a long time and can produce partial/stale data.

Clean Disk result order:

```text
drive summary
top folders
tree rows visible page
selected node details
cleanup candidates
search/top files on demand
export/compare later
```

Rules:

- Flutter must never own the full scan tree;
- table first paint should happen before every index is complete when possible;
- search, sort, and top lists are Rust queries;
- stale nodes must be marked if filesystem changed after scan.

### 8. Enterprise And Remote Modes Are Later, But The Vocabulary Starts Now

Accepted approach: same capability model, no enterprise UI in MVP - 🎯 8 🛡️ 9 🧠 8, roughly 2000-6000 LOC later.

Why:

- Storage Sense is policy-configurable.
- Backblaze reports permission state to admins.
- OneDrive and Dropbox document IT/admin-controlled limitations.
- Remote/headless scanning changes threat model and delete safety.

Clean Disk rule:

- MVP stores normalized `policyBlocked`, `packageLimited`, `remoteReadOnly`, and `adminRequired` capability reasons.
- UI can show them now as `Unavailable` or `Advanced`.
- Full fleet reporting, managed profiles, and remote destructive cleanup stay out of MVP.

## Top-Company UX Anti-Patterns

Avoid these even if they look simpler:

1. Prompting for FDA/admin/root before first scan.
2. Saying "full access" means complete results.
3. Treating cloud placeholders as reclaimable local files without proof.
4. Auto-selecting user documents, Downloads, project folders, or provider-managed data.
5. Showing one modal per permission error during scan.
6. Making advanced/elevated scan the default because it is faster.
7. Hiding package limitations until after failure.
8. Calling settings links "Grant access" instead of "Open settings" or "Improve access".
9. Offering permanent delete beside Trash with equal visual weight.
10. Reporting exact reclaimed bytes when snapshots, clones, dedupe, cloud providers, or Trash make it uncertain.

## Top-Company Operating Principles

These principles repeat across mature backup, sync, security, cleaner, and disk analyzer products.

### 1. Permission Is A Capability Status, Not A One-Time Dialog

Top apps keep a durable status surface:

- Backblaze exposes whether users have granted FDA in reports.
- Security tools keep setup/protection status visible.
- Disk analyzers show hidden/restricted/unaccounted space after scan.

Clean Disk implication:

- every scan snapshot stores its capability state;
- app-level status strip shows current scan authority;
- Permission Doctor shows last successful probe;
- support bundle includes redacted permission state.

### 2. Product Category Decides Prompt Timing

Top apps do not all ask at the same time.

```text
disk analyzer -> scan first, then improve access
backup/sync -> ask when user enables protected folder/device backup
security/real-time protection -> setup gate can be justified
cleanup/delete -> ask only after user selects cleanup targets
```

Clean Disk is primarily a disk analyzer, then a cleanup tool. It should not behave like antivirus onboarding on first launch.

### 3. Exact Process Identity Matters

Mature Mac utilities often name app/helper components in docs:

- CCC documents app and helper tool.
- Backblaze has separate app/menu/helper components in troubleshooting.
- macOS PPPC distinguishes app bundles and nonbundled binaries.

Clean Disk implication:

- UI guidance must name the real scanner component;
- scanner process identity appears in Permission Doctor;
- settings repair must be followed by scanner-process re-check;
- production must avoid external `pdu` binaries.

### 4. Advanced Authority Is A Mode, Not A Default

Top disk tools keep high-authority modes separate:

- DaisyDisk says normal scanning is enough in most cases and admin scan is for significant hidden space.
- WizTree treats administrator/MFT as fastest NTFS path, while standard scan still exists.

Clean Disk implication:

- `Advanced` badge and read-only first;
- no admin prompt on ordinary scans;
- advanced mode explains risk and scope;
- advanced mode never changes delete semantics silently.

### 5. Repair Is A Loop

Permission repair is not complete when the user opens settings.

```text
open guidance/settings
  -> user changes something or cancels
  -> app re-probes from scanner process
  -> state updates
  -> user rescans
```

Clean Disk implication:

- `Open Settings` always pairs with `Re-check`;
- no optimistic "permission granted" state;
- settings link failure has manual fallback;
- if restart is required, state says so explicitly.

### 6. Users Need A Non-Broad Path

Top platform guidance favors user-selected files/folders:

- Apple supports selected-folder access and security-scoped bookmarks.
- Windows packaged apps can use pickers and future access lists.
- Flatpak portals use user-mediated selection.

Clean Disk implication:

- `Choose Folder` must be first-class;
- custom folder scans work well in all package modes;
- selected-folder path is the fallback when full-disk access is unavailable or declined.

### 7. Trust Copy Must Be Specific

Strong apps explain:

- why access is requested;
- what data is read;
- whether data leaves the device;
- what happens if the user declines.

Clean Disk implication:

- say `file names, sizes, timestamps, and folder structure`;
- say `file contents are not read`;
- say `scan can continue but may be partial`;
- never say `better experience` or `required` unless literally true.

## User Personas And Best Flows

| Persona | Likely concern | Best first action | Permission posture |
| --- | --- | --- | --- |
| Casual cleanup user | Wants quick space back, low setup friction | Downloads scan | No broad prompt, clear cleanup suggestions |
| Power user | Wants complete disk map | Full disk target preflight | Improve access, rescan, advanced details |
| Privacy-sensitive user | Does not trust FDA/admin | Selected folder scan | Metadata-only explanation and no nagging |
| Windows power user | Wants fastest NTFS scan | Normal scan first, then Advanced MFT | Admin is opt-in, read-only first |
| Linux sandbox user | Expects package limits | Portal-selected folder | Reduced capability explained upfront |
| IT/admin user | Needs fleet status | Permission Doctor/export later | Capability report and managed-policy status |

## MVP Versus Later By Persona

MVP should optimize for casual cleanup, privacy-sensitive users, and power users on direct installs.

Later:

- fleet/admin reporting;
- managed PPPC/MDM docs;
- advanced Windows MFT/admin scan;
- Linux root/system scan;
- package-store-specific full-access profiles.

## What To Copy

- Scan-first from disk analyzers.
- Hidden/restricted/skipped as visible product data.
- Rescan after permission changes.
- Exact helper/app identity from backup tools.
- Dedicated Permission Doctor from cleaners/security tools.
- Separate scan types from security tools: quick/default, targeted, full/deep, external/custom.
- Advanced admin mode from Windows disk tools, but opt-in and read-only first.
- Portal-first selected-folder flow from Linux desktop apps.

## What To Avoid

- First-run wall that says the app cannot work without broad access.
- "Always run as administrator" as normal guidance.
- Claiming Full Disk Access means everything is readable.
- Combining skipped protected data into generic `Other`.
- Opening settings and assuming success.
- Asking for cleanup/delete authority before the user selects cleanup targets.
- Explaining normal UX with raw platform acronyms.
- Hiding helper identity behind the Flutter app name when the helper does the scan.

## MVP Permission UX Policy

MVP should ship these flows:

1. Downloads/custom folder scan with no broad permission request - 🎯 10 🛡️ 9 🧠 4, roughly 300-800 LOC.
2. Home/full disk preflight with `Scan anyway` and `Improve access` - 🎯 10 🛡️ 9 🧠 6, roughly 700-1600 LOC.
3. Partial result banner plus skipped reasons drawer - 🎯 9 🛡️ 9 🧠 6, roughly 700-1800 LOC.
4. Permission Doctor with scanner-process `Re-check` - 🎯 9 🛡️ 9 🧠 7, roughly 900-2200 LOC.
5. Delete preflight separate from scan permission - 🎯 10 🛡️ 10 🧠 7, roughly 900-2400 LOC.

MVP should not ship these as default:

1. macOS admin/system scan - 🎯 4 🛡️ 5 🧠 9, roughly 1500-4000 LOC.
2. Windows MFT/admin scan as default - 🎯 5 🛡️ 6 🧠 8, roughly 1200-3200 LOC.
3. Linux root scan from UI - 🎯 3 🛡️ 4 🧠 8, roughly 1000-3000 LOC.
4. Flatpak/Snap full-host promise - 🎯 3 🛡️ 4 🧠 7, roughly 800-2400 LOC plus store policy risk.

Later options:

- Advanced read-only system scan profile.
- Enterprise permission status/reporting.
- Managed PPPC/MDM documentation for macOS business installs.
- Windows packaged-app broad file access profile.
- Guided visual setup for helper/FDA only after signing/notarization spike proves exact identity behavior.

## User Mental Model

Users should see scan quality states, not OS internals.

```text
Complete
May be partial
Needs access
Advanced
Unavailable
```

Mapping:

- `Complete`: expected to scan the selected target accurately.
- `May be partial`: scan can run, but skipped/protected folders may affect totals.
- `Needs access`: user action can improve or unblock the scan.
- `Advanced`: higher-risk mode, such as admin/system scan.
- `Unavailable`: current build/package cannot honestly support this target.

Avoid exposing these as primary labels:

```text
TCC
UAC
PPPC
ACL
Flatpak interface
Snap interface
```

These belong in diagnostics, support bundles, and advanced details.

## Canonical Flow

```text
app opens
  -> background capability probe
  -> show app with target quality badges
  -> user selects target
  -> scanner-process preflight
  -> complete enough?
      yes -> start scan
      no, but usable -> show Scan anyway + Improve access
      no, blocked -> show exact remediation
  -> scan completes
  -> show completeness, skipped groups, and rescan action
  -> cleanup selected?
      yes -> delete preflight, confirmation, receipt
```

Rules:

- never block first launch with broad permissions;
- every broad permission request follows a visible user action;
- every denied permission leaves a usable next step;
- every partial result is visibly partial;
- read authority and delete authority are separate.

## UI Components

### Permission Status Strip

Purpose: keep permission state visible without interrupting the workflow.

Location:

- bottom scan/status area in wide layout;
- sticky bottom row in compact layout;
- Permission Doctor entry point in settings/details.

Content examples:

```text
Ready to scan Downloads
```

```text
Home scan may be partial
```

```text
17 protected folders skipped
```

Actions:

```text
Review
Improve access
Re-check
```

Rules:

- use this for non-blocking permission state;
- do not show modal dialogs for warnings that do not block the user;
- state survives navigation until scan result is dismissed or superseded;
- `Re-check` must call scanner-process probe, not UI-side probe.

### Scan Target Badge

Purpose: communicate quality before scan.

States:

```text
Complete
May be partial
Needs access
Advanced
Unavailable
Checking
```

Rules:

- badge text must fit compact layout;
- tooltip/details explains platform reason;
- badge state comes from capability DTO, not hardcoded UI platform checks;
- `Checking` must not block scanning a low-risk selected folder forever.

### Preflight Sheet

Purpose: ask at the moment of intent.

Primary variants:

```text
Complete scan
  Start Scan

Partial scan
  Scan Anyway
  Improve Access

Blocked scan
  Open Settings / Choose Folder / Change Package Access
  Cancel

Advanced scan
  Continue Read-Only
  Learn More
```

Rules:

- never use "permission required" when scan can continue partially;
- always state fallback behavior;
- for macOS, mention app/helper name exactly as the user sees it in settings;
- for Windows, distinguish normal user scan from administrator mode;
- for Linux, distinguish native package from Flatpak/Snap reduced capability.
- modal sheet is allowed here because the user explicitly selected a target and must choose scan quality;
- default keyboard action must not trigger an advanced/elevated/destructive path;
- cancel/back returns to target selection without losing current app state.

### Partial Result Banner

Purpose: keep trust after scan.

Content:

```text
Scan may be partial
17 protected folders were skipped. Grant access and rescan to include them.
```

Actions:

```text
Review skipped
Improve access
Rescan
```

Rules:

- show count and size confidence separately;
- do not merge skipped/protected space into generic `Other`;
- grouped skipped reasons must be inspectable;
- if exact hidden size is unknown, say unknown.

### Permission Doctor

Purpose: repair and support, not onboarding.

Sections:

```text
Scan authority
Scanner identity
Package mode
Selected folder grants
Full disk/all-files access
External/removable volume access
Trash/delete authority
Last probe result
```

Rules:

- reachable from Settings and partial banners;
- includes one-click re-check;
- includes manual steps when direct settings link is unsupported;
- support export redacts raw paths by default.

### Settings And System Action Links

Purpose: make repair easy without pretending every platform can be automated.

Rules:

- actions are capability-driven: `open_settings`, `choose_folder`, `open_package_help`, `restart_required`, `recheck`;
- Windows packaged file-system access can use the documented `ms-settings:privacy-broadfilesystemaccess` URI when relevant;
- macOS Full Disk Access guidance should include manual steps and exact app/helper name because deep links to privacy subpanes are not a stable cross-version contract;
- Linux Flatpak/Snap guidance should prefer portal folder selection first, then package-specific instructions if broader access is impossible;
- every settings action must be followed by `Re-check`;
- never mark permission as granted only because the settings page was opened.

### Skipped Reasons Drawer

Purpose: let users understand partial scans without reading logs.

Groups:

```text
Protected by privacy settings
Access denied by file permissions
Package or sandbox limitation
External/removable volume not available
Files changed during scan
Mount boundary skipped
Unsupported filesystem feature
```

Rules:

- show counts and confidence, not raw full paths by default;
- reveal paths only after user expands details;
- support copy/export with redaction controls;
- each group may offer a targeted action if one exists;
- no group should say "Unknown error" unless platform adapter genuinely cannot classify it.

## Interaction Detail Defaults

### When To Use Each Surface

| Surface | Use for | Avoid for |
| --- | --- | --- |
| Badge | target quality before scan | long explanations |
| Status strip | non-blocking current permission state | final destructive confirmation |
| Preflight sheet | target-specific choice before scan | first launch onboarding |
| Banner | partial scan result | one-off low-value notices |
| Drawer/panel | skipped reasons and repair details | blocking scan start |
| Modal confirmation | destructive cleanup or irreversible advanced action | normal permission warnings |
| Toast | completed re-check or small transient success | access denied or partial scan state |

### Preferred First Screen

The app opens into the real product surface:

```text
top controls: target selector, Scan, search/filter/settings
main area: empty tree/table placeholder or last scan
target chips: Downloads, Home, Custom Folder, current disk
status strip: capability probe state
```

What not to show first:

```text
Grant Full Disk Access to continue
Run as administrator
Choose package permissions
Read this setup wizard before scanning
```

### Best Defaults By Distribution

| Platform/distribution | Best first scan | Broad scan path | Advanced path |
| --- | --- | --- | --- |
| macOS direct signed app | Downloads or selected folder | Full Disk Access after target intent | admin/helper/system scan later, read-only first |
| Windows signed installer | current-user folders | normal user token plus ACL handling | admin/MFT fast scan, opt-in |
| Windows MSIX/packaged | selected folder/picker | broad file-system access settings when justified | store/capability review |
| Linux AppImage/distro | home/downloads/selected folder | native unsandboxed scan under current user | root/system scan later, read-only first |
| Linux Flatpak | portal-selected folder | limited package permissions with honest warning | not full-disk MVP |
| Linux Snap strict | visible home files | connected interfaces with warning | not full-disk MVP |

### Trust Details That Matter

Users are more likely to grant access when the app is specific.

Show:

- what will be read: names, sizes, timestamps, folder structure;
- what will not be read: file contents;
- why access improves this specific target;
- whether scan continues without access;
- exact app/helper name for system settings;
- whether restart/rescan is required.

Do not show:

- broad technical acronyms first;
- vague "better experience" copy;
- "required" if scan can continue partially;
- instructions to weaken OS security;
- repeated prompts after denial.

## Platform Defaults

### macOS

Best default:

- first scan: Downloads or selected folder;
- for Home/Library/full disk: preflight first;
- for Full Disk Access: user-guided settings flow;
- after settings: scanner-process re-probe and rescan;
- production scanner must be signed app/helper, not external `pdu`.

Important UX:

- say metadata, not contents;
- do not promise Full Disk Access scans everything;
- if deep-link to settings fails, provide manual steps;
- never ask users to disable SIP or security protections.

### Windows

Best default:

- run app and daemon as current user with `asInvoker`;
- scan current-user areas without admin;
- show access denied as partial scan, not failure;
- administrator/MFT fast scan is Advanced and read-only first;
- packaged builds use documented Settings and picker mechanisms.

Important UX:

- do not encourage "always run as administrator";
- if UAC appears, it must follow a clear Advanced action;
- explain that admin can change what Recycle Bin/delete means;
- Defender/Controlled Folder Access should appear as write/cleanup blocker.

### Linux

Best default:

- direct AppImage/distro package for best full-disk UX;
- Flatpak/Snap clearly labeled as reduced capability;
- portal folder picker before broad host access in sandboxed builds;
- no root UI for normal use;
- root/system scans are Advanced and read-only first.

Important UX:

- explain hidden files, removable media, and package-interface limits before scan;
- support selected-folder workflow well in sandboxed builds;
- do not tell users to weaken AppArmor, SELinux, Snap, or Flatpak isolation.

## Capability DTO Contract

The UI should receive product-ready capability facts.

```json
{
  "targetId": "home",
  "scanQuality": "may_be_partial",
  "canScanNow": true,
  "canImproveAccess": true,
  "requiresRestart": false,
  "requiresRescan": true,
  "authority": {
    "scannerIdentity": "bundled_helper",
    "packageMode": "direct_app_bundle",
    "sandboxed": false
  },
  "issues": [
    {
      "kind": "protected_folder_access_missing",
      "severity": "warning",
      "userLabel": "Some protected folders may be skipped",
      "technicalCode": "macos_full_disk_access_missing"
    }
  ],
  "actions": [
    {
      "kind": "open_settings",
      "label": "Improve access",
      "available": true
    },
    {
      "kind": "scan_anyway",
      "label": "Scan anyway",
      "available": true
    }
  ]
}
```

Rules:

- labels are UI-safe but can be localized later;
- technical codes remain stable for telemetry/support;
- raw paths are not included in capability summaries;
- scanner process is the source of truth.

## Permission State Machine

```text
unknown
  -> probing
  -> complete
  -> partial_available
  -> blocked_needs_action
  -> advanced_only
  -> unavailable

partial_available
  -> scanning_partial
  -> remediation_started
  -> probing_after_return
  -> complete

blocked_needs_action
  -> remediation_started
  -> probing_after_return
  -> complete | partial_available | blocked_needs_action
```

Failure rules:

- permission denied never becomes generic scan failed;
- revoked access during app lifetime forces a new preflight;
- stale settings guidance becomes `unknown_needs_probe`;
- permission state is attached to scan snapshot, not only global app state.

## User Preference Rules

The app should remember user intent without nagging.

Store:

- target-specific choice to scan anyway with partial results;
- dismissed educational copy version;
- selected-folder grants/bookmark status where platform allows;
- last successful capability probe timestamp;
- preferred advanced mode only if explicitly enabled.

Do not store:

- "user granted Full Disk Access" unless scanner-process probe confirms it;
- permanent suppression of critical cleanup/delete warnings;
- broad permission assumptions from debug builds;
- raw skipped paths in preference state.

Nagging rules:

- if the user chooses `Scan anyway`, do not show the same preflight for the same target until capability state changes or the app version changes the copy;
- still show the partial result banner after scan;
- if the user opens `Improve access` and returns without granting access, show one failed re-check state, then let them continue;
- never loop Settings -> app -> Settings automatically.

## Recovery Cases

User denies access:

- keep the target available as partial if possible;
- store no nag state that repeatedly interrupts;
- show one calm banner after scan.

User grants access but app cannot see it:

- re-probe in scanner process;
- show scanner identity mismatch if helper cannot read;
- do not assume UI process access means daemon access.

User revokes access:

- next scan preflight detects it;
- saved scan targets remain, but quality becomes `Needs access` or `May be partial`;
- cached old results are marked stale capability.

Settings link fails:

- show manual steps;
- allow copyable app/helper name;
- keep re-check button visible.

Sandboxed package cannot support target:

- mark target `Unavailable`;
- suggest selected-folder/portal workflow instead;
- avoid pretending a package setting will fix impossible access.

## Testing Checklist

Required before shipping permission UX:

- first launch has no broad permission wall;
- Downloads scan succeeds without broad access;
- Home/Library/full disk preflight shows partial/improve choices;
- deny flow still allows scan where possible;
- grant flow re-probes from scanner process;
- revoked permission changes scan badge;
- partial result exposes skipped groups;
- cleanup preflight is separate from scan preflight;
- Windows standard user scan does not trigger UAC;
- Windows Advanced admin path is opt-in;
- Linux Flatpak/Snap show reduced capability;
- selected-folder portal flow works in sandboxed package;
- macOS signed/notarized artifact tested with bundled scanner.

## Implementation Consequences

- Flutter UI needs reusable `ScanQualityBadge`, `PermissionPreflightSheet`, `PartialScanBanner`, and `PermissionDoctorPanel`.
- Rust server needs target capability endpoints before scan start.
- `fs_usage_*` needs normalized permission/issue vocabulary independent of platform names.
- Platform adapters own remediation actions and settings links.
- Design system should expose compact warning/badge/banner primitives that work in wide and compact layouts.
