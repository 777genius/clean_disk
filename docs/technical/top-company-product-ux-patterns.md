# Top Company Product UX Patterns

Last updated: 2026-05-16.

This document records a deeper research pass on how mature platform, sync, backup, developer-tool, and system-utility products handle user experience across macOS, Windows, Linux, desktop agents, and web surfaces.

The goal is not to copy one app. The goal is to copy the operating discipline behind launched products: clear state, recoverable actions, progressive authority, diagnostics, accessibility, and honest platform semantics.

## Sources Reviewed

- Apple Developer, [Human Interface Guidelines - Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback) and [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy), plus [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).
- Microsoft, [Windows app settings guidelines](https://learn.microsoft.com/windows/apps/design/app-settings/guidelines-for-app-settings), [Storage Sense policy](https://learn.microsoft.com/windows/configuration/storage/storage-sense), [MSIX auto-update and repair](https://learn.microsoft.com/windows/msix/app-installer/auto-update-and-repair--overview), [Windows privacy](https://learn.microsoft.com/windows/privacy/), and [Microsoft PC Manager](https://pcmanager.microsoft.com/en-us).
- Microsoft Fluent, [Accessibility](https://fluent2.microsoft.design/accessibility).
- Google Material Design, [Permissions](https://m1.material.io/patterns/permissions.html), [Errors](https://m1.material.io/patterns/errors.html), [Empty states](https://m1.material.io/patterns/empty-states.html), and [Progress and activity](https://m1.material.io/components/progress-activity.html).
- Atlassian Design, [Empty state](https://atlassian.design/components/empty-state).
- Docker Desktop, [Troubleshoot Docker Desktop](https://docs.docker.com/desktop/troubleshoot-and-support/troubleshoot/), [settings and resources](https://docs.docker.com/desktop/settings-and-maintenance/settings/), [Resource Saver](https://docs.docker.com/desktop/use-desktop/resource-saver/), [images cleanup](https://docs.docker.com/desktop/use-desktop/images/), and [Docker Desktop CLI](https://docs.docker.com/desktop/features/desktop-cli/).
- Google Drive for desktop, [fix problems](https://support.google.com/drive/answer/2565956) and [stream/mirror files](https://support.google.com/drive/answer/13401938).
- Dropbox, [sync troubleshooting](https://help.dropbox.com/sync/files-not-syncing), [sync icons](https://help.dropbox.com/sync/sync-icons), [online-only files](https://help.dropbox.com/sync/make-files-online-only), and [missing file recovery](https://help.dropbox.com/delete-restore/missing-reappearing-corrupted-files).
- OneDrive, [Files On-Demand](https://support.microsoft.com/office/sync-files-with-onedrive-files-on-demand-62e8d748-7877-420f-b600-24b56562aa70), [sync icons](https://support.microsoft.com/office/what-do-the-onedrive-icons-mean-11143026-8000-44f8-aaa9-67c985aa49b3), and [restore deleted files](https://support.microsoft.com/office/restore-deleted-files-or-folders-in-onedrive-949ada80-0026-4db3-a953-c99083e6a84f).
- Backblaze, [restore app](https://help.backblaze.com/hc/en-us/articles/15383074527771-How-to-use-the-restore-app), [Full Disk Access status report](https://help.backblaze.com/hc/en-us/articles/360011389154-Which-Users-Have-Granted-Backblaze-Full-Disk-Access), and [send logs to support](https://help.backblaze.com/hc/en-us/articles/14750819976731-How-to-send-logs-to-Backblaze-Mac).
- Carbon Copy Cloner, [Full Disk Access for app and helper](https://bombich.com/en/kb/ccc/6/granting-full-disk-access-ccc-and-its-helper-tool).
- Malwarebytes and Norton support docs for macOS Full Disk Access and repeated permission prompt recovery.
- Sentry, [data scrubbing](https://docs.sentry.io/security-legal-pii/scrubbing/).
- WAI-ARIA Authoring Practices, [treegrid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/).
- Flatpak, [sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html).

## Core Finding

Top products make system state legible before they ask the user to act.

The mature pattern is:

```text
show useful state
  -> explain limitation
  -> offer one concrete next action
  -> verify outcome
  -> record what happened
  -> provide support or recovery path
```

For Clean Disk this means the app must not feel like a raw scanner with buttons. It should feel like a local storage operations console with guardrails.

## Top 3 UX Architecture Choices

1. State-led product architecture - 🎯 10 🛡️ 10 🧠 8, roughly 4000-12000 LOC across app state, DTOs, screens, tests, receipts, and support flows.

   Accepted. Every important feature has explicit states, disabled reasons, proof loops, recovery paths, and receipts. This matches how Docker Desktop, OneDrive, Dropbox, Backblaze, Windows Storage, and Material/Fluent guidance handle complex local systems.

2. Screen-led feature architecture - 🎯 6 🛡️ 6 🧠 5, roughly 2500-8000 LOC.

   Faster at first, but weak once scans, deletes, cloud states, daemon lifecycle, low-space mode, and support diagnostics overlap. It creates pretty screens without enough product truth.

3. Raw expert-tool architecture - 🎯 5 🛡️ 5 🧠 4, roughly 1500-5000 LOC.

   Efficient for power users, but not enough for a trusted cleanup app. It pushes too much filesystem risk onto the user.

## Product Patterns To Adopt

### 1. First Value Before Setup

Mature pattern:

- Material recommends asking for permissions in context and giving immediate benefit.
- Apple privacy guidance favors specific, explainable access.
- Atlassian and Material empty-state patterns make first empty states actionable instead of dead ends.

Clean Disk rule:

- first screen shows targets and a real scan CTA;
- broad permission is requested only after target intent;
- empty state has one primary action, usually `Scan Downloads` or `Choose Folder`;
- daemon repair appears only if it blocks a user action.

### 2. Status Over Modal Spam

Mature pattern:

- Docker Desktop exposes status, troubleshoot, restart, purge data, reset, diagnostics ID, and logs through a dedicated support surface.
- Material errors recommend keeping the rest of the app usable during connectivity/sync failure when possible.
- Apple feedback guidance frames feedback as status, success/failure, warning, and correction opportunity.

Clean Disk rule:

- use persistent status strips, badges, issue drawers, and details panels before modal dialogs;
- modals are for target choices that need a decision and destructive confirmations;
- scan issues are grouped by cause, not shown as repeated alerts;
- disabled actions show reasons.

### 3. Permission Is A Capability State

Mature pattern:

- Backblaze reports whether the real backup client can read protected macOS data.
- CCC documents that app and helper identity can both matter.
- Norton and Malwarebytes support docs show permission state can regress after OS updates.
- Google Drive and Dropbox troubleshooters use checklists and repair steps rather than blaming the user.

Clean Disk rule:

```text
CapabilityState:
  Complete
  MayBePartial
  NeedsAccess
  BlockedByPolicy
  BrokenAfterUpdate
  UnsupportedPackageMode
```

The scanner process must re-probe. Flutter cannot prove access.

### 4. Background Agent UX Must Be Quiet But Inspectable

Mature pattern:

- Docker Desktop has tray/status behavior, CLI commands, restart/quit/reset, diagnostics, and resource controls.
- Sync clients expose paused/syncing/error states in Finder/File Explorer and tray/menu bar.
- Backup/security apps show health cards and issue reports.

Clean Disk rule:

- local daemon status is visible but not central unless broken;
- provide `Start`, `Restart`, `Stop`, `Open logs`, `Collect support bundle`, and `Protocol version` in settings/doctor;
- no hidden long-running worker with no explanation;
- CLI and UI should use the same daemon lifecycle contract.

### 5. Resource Saver And Low-Space Mode Are Product Features

Mature pattern:

- Docker Desktop Resource Saver reduces host CPU/memory while idle and shows a visible status.
- Docker settings expose CPU, memory, disk, file sharing, proxy, and network resource limits.
- Windows Storage Sense distinguishes automatic maintenance from user-reviewed cleanup.

Clean Disk rule:

- scan profiles include `Balanced`, `Fast`, and `Background`;
- low-space mode disables or limits local caches, heavy thumbnails, huge report generation, and non-critical update downloads;
- resource budgets are user-visible when they affect behavior;
- background scanning should not feel like a hidden battery drain.

### 6. Destructive Actions Need Recovery Semantics, Not Just Confirmation

Mature pattern:

- OneDrive restore behavior differs between local Trash and cloud recycle bin, especially for online-only and cloud-deleted files.
- Dropbox recovery depends on plan/version history and permanent delete boundaries.
- Backblaze restore asks where to restore and how to handle existing files.

Clean Disk rule:

```text
ActionReceipt:
  action_type
  targets
  stale_checks
  platform_store
  restore_level
  observed_delta
  failed_items
  manual_recovery_path
```

The confirmation dialog is not enough. The app must show what recovery actually means for each target.

### 7. Diagnostics Are A Product Flow

Mature pattern:

- Docker Desktop can gather diagnostics from the app or an error message and returns a diagnostic ID.
- Backblaze has explicit support log workflows.
- Sentry documents default and advanced data scrubbing.
- Apple App Privacy Details and Microsoft privacy docs make data collection visible.

Clean Disk rule:

- support bundle is previewable;
- default redaction removes raw paths, usernames, tokens, auth headers, search text, delete targets, and full tree data;
- support bundle has a local receipt and data categories;
- diagnostics never silently upload.

### 8. Settings Need Scope And Defaults

Mature pattern:

- Microsoft settings guidance keeps workflow commands out of settings, keeps settings simple, groups related settings, and places legal/about/help in an appropriate section.
- Docker Desktop separates resources, file sharing, network, proxy, diagnostics, and reset flows.

Clean Disk rule:

Settings groups:

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

Do not hide normal workflow commands in settings. Use settings for preferences, policy, diagnostics, and app identity.

### 9. Accessibility Must Be Designed Before The Table Exists

Mature pattern:

- Fluent explicitly requires accessible design from first wireframe and text zoom without clipping.
- WAI-ARIA treegrid separates focus, selection, expanded state, sort, row/column count, and row index.

Clean Disk rule:

- tree/table design system primitive needs roving focus, selection distinct from focus, keyboard expand/collapse, screen-reader labels, sort state, row counts, and visible focus;
- compact layout must survive 200% text zoom without unusable controls;
- charts must have table/list equivalents.

### 10. Enterprise/Admin Mode Is Not Consumer Mode

Mature pattern:

- Windows Storage Sense policy supports admin-managed cleanup thresholds.
- Docker Desktop supports enterprise/admin configuration and centralized policy.
- TreeSize-style scheduled reporting is admin-oriented.

Clean Disk rule:

- MVP consumer mode uses local manual scans and reviewed cleanup;
- admin/remote/headless mode is separate, policy-driven, auditable, and read-only by default;
- destructive automation requires dry-run, approval policy, receipt, and retention.

## Product Surface Model

Clean Disk should have these high-level surfaces:

```text
Home / Targets
Scan Results
Issue Drawer
Details Panel
Recommendations
Cleanup Queue
DeletePlan Review
Receipt History
Permission Doctor
Daemon Status
Reports
Settings
Support Bundle
```

Each surface needs:

```text
empty state
loading state
partial state
error state
disabled action reason
recovery action
keyboard path
analytics-safe event name
```

## Architecture Implications

### Application Concepts

Product UX adds these application-level concepts:

```text
CapabilityProbe
CapabilityState
OperationStateMachine
ActionAvailability
DisabledReason
SupportBundlePlan
SupportBundleReceipt
RestoreCapability
ResourceProfile
LowSpaceMode
DaemonHealth
UpdateCompatibilityState
```

These are not UI-only fields. They should exist in application contracts and DTOs.

### Rust Host

The Rust host must expose:

```text
GET /health
GET /capabilities
POST /scan-sessions
POST /scan-sessions/{id}/start
POST /operations/{id}/cancel
GET /operations/{id}
POST /support-bundles/preview
POST /support-bundles
GET /daemon/info
```

The exact routes can change, but the product capabilities should not be hidden behind ad hoc scanner calls.

### Flutter

Flutter should model:

```text
DaemonConnectionStore
CapabilityStore
ScanSessionStore
IssueStore
SelectionSetStore
CleanupQueueStore
ReceiptStore
SupportBundleStore
SettingsStore
```

These stores can be feature-scoped, but the state vocabulary must stay consistent across screens.

### Design System

Headless/design-system gaps to watch:

- virtual treegrid/table;
- status badge with severity and proof state;
- issue drawer;
- operation progress footer;
- evidence/risk confirmation dialog;
- receipt timeline;
- keyboard command surface;
- diagnostic preview panel;
- redaction-level selector;
- compact responsive split layout.

If these are missing, we should improve the shared Headless/design-system layer instead of writing screen-specific hacks.

## Decisions Added From This Research

- Clean Disk UX is state-led. Product states are part of the domain/application contract, not copy sprinkled in widgets.
- Daemon and scanner health are quiet by default but inspectable and repairable.
- Low-space mode and resource budgets are user-facing product behavior.
- Restore and support are first-class flows, not afterthoughts.
- Settings are for durable preferences and diagnostics, not common workflow commands.
- Accessibility is a first-pass requirement for the tree/table, not a polish phase.
- Enterprise/headless behavior must be separate from consumer UX and default to read-only.

## Next Spikes

Top 3 next spikes from top-company UX research:

1. Product state vocabulary and route/event contract - 🎯 10 🛡️ 9 🧠 7, roughly 600-1400 LOC.

   Define states and DTOs for capabilities, daemon health, operation status, disabled reasons, support bundle preview, receipt, and restore capability. This is the foundation for a mature app.

2. Design-system treegrid plus issue/status primitives - 🎯 9 🛡️ 8 🧠 8, roughly 1200-3000 LOC.

   Validate keyboard, focus, selection, virtual rows, compact layout, status badges, issue drawers, and action availability before real scanner integration.

3. Support and recovery flow prototype - 🎯 8 🛡️ 9 🧠 7, roughly 700-1800 LOC.

   Prototype support bundle preview, redaction levels, diagnostics receipt, and restore capability receipt. This is not MVP glamour, but it prevents trust debt.

## Summary

The strongest product lesson from top companies:

```text
Users trust local system utilities when state is visible,
actions are recoverable or honestly irreversible,
errors explain the next step,
and the product proves repairs instead of assuming them.
```

Clean Disk should use that as the product bar.
