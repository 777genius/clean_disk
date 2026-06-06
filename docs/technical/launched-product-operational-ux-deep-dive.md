# Launched Product Operational UX Deep Dive

Last updated: 2026-05-16.

This document records an additional research pass on mature launched products outside classic disk analyzers. The focus is operational UX: command models, trust modes, repair flows, logs, shell integration, keyboard access, native platform behavior, and web/desktop capability boundaries.

## Sources Reviewed

- Visual Studio Code, [Workspace Trust](https://code.visualstudio.com/docs/editing/workspaces/workspace-trust), [Workspace Trust Extension Guide](https://code.visualstudio.com/api/extension-guides/workspace-trust), [Settings Sync](https://code.visualstudio.com/docs/editor/settings-sync), [Remote Development](https://code.visualstudio.com/docs/remote/remote-overview), and [VS Code for the Web](https://code.visualstudio.com/docs/setup/vscode-web).
- GitHub Desktop, [configuring a default editor](https://docs.github.com/en/desktop/configuring-and-customizing-github-desktop/configuring-a-default-editor-in-github-desktop) and [committing/reviewing changes](https://github.com/github/docs/blob/main/content/desktop/making-changes-in-a-branch/committing-and-reviewing-changes-to-your-project-in-github-desktop.md).
- Raycast, [Keyboard Shortcuts](https://manual.raycast.com/keyboard-shortcuts), [Command Aliases and Hotkeys](https://manual.raycast.com/command-aliases-and-hotkeys), [Extensions](https://manual.raycast.com/extensions), [Preferences](https://manual.raycast.com/preferences), and [extension install/setup](https://developers.raycast.com/basics/install-an-extension).
- LaunchBar, [Actions](https://www.obdev.at/resources/launchbar/help/Actions.html).
- Slack, [connection troubleshooting](https://slack.com/help/articles/205138367-Troubleshoot-connection-issues), [notification troubleshooting](https://slack.com/hc/en-us/articles/360001559367), and [pause notifications](https://slack.com/intl/en-ie/help/articles/214908388-Pause-notifications-with-do-not-disturb).
- Notion, [desktop app update behavior](https://www.notion.com/en-gb/help/notion-for-desktop) and [enterprise macOS deployment](https://www.notion.com/help/deploy-notion-for-macos).
- Docker Desktop, [troubleshooting](https://docs.docker.com/desktop/troubleshoot-and-support/troubleshoot/), [logs view](https://docs.docker.com/desktop/use-desktop/logs/), [images cleanup](https://docs.docker.com/desktop/use-desktop/images/), and [Resource Saver](https://docs.docker.com/desktop/use-desktop/resource-saver/).
- Backblaze, [restore app](https://help.backblaze.com/hc/en-us/articles/15383074527771/).
- Dropbox, [remote wipe status reports](https://help.dropbox.com/delete-restore/delete-dropbox-device).
- Microsoft, [focus navigation](https://learn.microsoft.com/en-us/windows/apps/design/input/focus-navigation), [keyboard interactions](https://learn.microsoft.com/en-us/windows/apps/develop/input/keyboard-interactions), [Storage Sense](https://learn.microsoft.com/en-us/windows/configuration/storage/storage-sense), and [MSIX auto-update/repair](https://learn.microsoft.com/en-us/windows/msix/app-installer/auto-update-and-repair--overview).
- Apple HIG, [sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) and [lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables).

## Core Finding

The strongest launched apps separate **what the user can do** from **where the button is rendered**.

They model actions as first-class concepts:

```text
action id
label
shortcut
primary/secondary/destructive role
availability
disabled reason
required capability
trust/risk tier
platform adapter
progress model
result receipt
undo/restore behavior
support evidence
```

For Clean Disk this means we should not scatter delete/reveal/scan/rescan/export/open/settings/repair commands across widgets. We need a product command/action registry that desktop, web, CLI, context menus, keyboard shortcuts, and future automation can all use.

## Top 3 Missing UX Foundations

1. Product command/action registry - 🎯 10 🛡️ 10 🧠 7, roughly 1200-3000 LOC.

   Best next foundation. This copies Raycast, VS Code, LaunchBar, GitHub Desktop, and Docker Desktop patterns: the product owns actions, shortcuts, availability, risk, and execution. Screens only render available commands.

2. Operation ledger with receipts and support evidence - 🎯 10 🛡️ 10 🧠 8, roughly 1500-4000 LOC.

   Needed for trust. Every scan, cleanup, export, support bundle, daemon repair, and destructive action should produce inspectable operation state and a receipt.

3. Trust/authority mode model - 🎯 9 🛡️ 10 🧠 8, roughly 1000-2500 LOC.

   Inspired by VS Code Workspace Trust and platform permission models. Clean Disk needs restricted/read-only/advanced/admin/remote modes so dangerous actions are gated by explicit capability and intent.

## Patterns To Adopt

### 1. Command Palette And Action Panel

Real-product signal:

- Raycast and LaunchBar make actions discoverable through keyboard and contextual action panels.
- VS Code command palette exposes actions beyond visible toolbar buttons.
- GitHub Desktop lets users open files in external tools from context.

Clean Disk adoption:

```text
CommandRegistry
ActionPanel
ContextActions
KeyboardShortcuts
CommandPalette
```

Every important action should be available from:

- toolbar if common;
- row context menu if item-scoped;
- details panel if evidence-scoped;
- command palette if power-user or keyboard-first;
- CLI/API if automation-safe.

Do not create hidden one-off actions that only exist inside one widget.

### 2. Trust Mode Before Dangerous Capabilities

Real-product signal:

- VS Code Restricted Mode disables tasks, debugging, and workspace settings that can run code.
- Raycast extension setup can require preferences before commands run.
- Slack and Docker show repair/troubleshooting steps instead of silently failing.

Clean Disk adoption:

```text
TrustMode:
  ReadOnly
  Normal
  AdvancedCleanup
  AdminScan
  RemoteReadOnly
  RemoteManaged
```

Trust mode is not a modal. It is application state that controls action availability. Example:

- `Scan Downloads` works in `Normal`;
- `Move to Trash` requires delete preflight;
- `Permanent Delete` requires `AdvancedCleanup`;
- `Admin Scan` requires explicit mode and platform capability;
- remote/headless destructive cleanup requires policy.

### 3. Operation Ledger

Real-product signal:

- Docker exposes logs, diagnostics, reset/purge actions, and resource state.
- Slack collects net logs with clear start/stop workflow.
- Dropbox remote wipe reports per-device delete status and failures.
- Backblaze restore tracks target, time range, location, collision policy, and progress.

Clean Disk adoption:

```text
OperationLedger:
  scans
  cleanup plans
  cleanup executions
  exports
  support bundles
  daemon repairs
  permission re-probes
```

Each operation has:

```text
operation_id
type
status
started_at
ended_at
actor
target_scope
capability_snapshot
progress
warnings
result
receipt_ref
support_evidence_ref
```

This enables history, troubleshooting, support, and user trust.

### 4. Repair Recipes Instead Of Generic Errors

Real-product signal:

- Slack maps connection/notification problems to concrete steps: restart, clear cache, run connection test, collect logs.
- Docker maps runtime problems to restart, reset, purge, logs, diagnostics.
- Notion tells users where update/version state lives and when reinstall is needed.

Clean Disk adoption:

Each major failure should map to a recipe:

```text
DaemonNotReachable -> restart daemon, show logs, reinstall helper
PermissionIncomplete -> open platform settings, re-probe scanner process
ProtocolMismatch -> update app/daemon pair
PackageSandboxed -> explain Flatpak/Snap limitations, suggest supported mode
TrashUnavailable -> fallback options and risk explanation
CloudProviderUnknown -> disable cloud delete, allow reveal/open provider
```

The recipe belongs to application state, not copy hardcoded in UI.

### 5. Native Shell Integration As Trust UI

Real-product signal:

- GitHub Desktop opens files in the user's configured editor.
- LaunchBar can reveal files/folders and copy paths.
- DaisyDisk and WinDirStat support reveal/open/copy path style actions.

Clean Disk adoption:

Native shell actions are not nice-to-have:

```text
Reveal in Finder/Explorer/file manager
Open with default app
Open Terminal here
Copy path
Copy diagnostic-safe path token
Open provider UI
Open official cleanup tool
```

For trust, users need to verify targets outside our app before deletion.

### 6. Keyboard-First Without Making UI Cryptic

Real-product signal:

- Raycast is built around keyboard navigation and action panels.
- Microsoft focus navigation requires non-pointer users to complete workflows.
- Apple tables guidance values sortable/resizable columns on macOS.

Clean Disk adoption:

- Provide visible toolbar buttons for common actions.
- Provide command palette for all actions.
- Provide shortcuts for frequent non-destructive actions.
- Keep destructive actions keyboard-accessible but protected by DeletePlan.
- Context menu and action panel share the same command registry.

### 7. Web Capability Boundary

Real-product signal:

- VS Code for the Web is explicit that web lacks runtime/terminal/debug features unless moved to desktop, Codespaces, or Remote.
- VS Code Remote Development moves runtime work to a server component.
- Docker Desktop separates UI, CLI, daemon, logs, and diagnostics.

Clean Disk adoption:

Web UI should show:

```text
Connected daemon
Daemon version
Protocol version
Capability profile
Host platform
Package mode
Allowed target scopes
Unavailable local OS actions
```

Hosted web UI should not silently attempt privileged local filesystem behavior.

### 8. Update And Compatibility UX

Real-product signal:

- Notion desktop auto-updates and exposes check-for-update path.
- MSIX supports update and repair policies.
- Docker Desktop troubleshooting is versioned around app/daemon state.

Clean Disk adoption:

App and daemon update must be a product state:

```text
AppVersion
DaemonVersion
ProtocolVersion
MinimumCompatibleProtocol
UpdateChannel
RepairAvailable
RestartRequired
PermissionReprobeRequired
```

After update, revalidate helper identity, permission status, daemon protocol, and scanner capability.

### 9. Preferences Sync And Machine-Local State

Real-product signal:

- VS Code separates user settings, workspace settings, and settings sync.
- Raycast can export/import preferences but machine permissions and some local states remain per-device.
- Slack and Notion expose desktop app-specific troubleshooting/update paths.

Clean Disk adoption:

Separate:

```text
User preferences
Machine-local capability state
Daemon runtime state
Scan history
Cleanup receipts
Support bundle settings
Policy/admin settings
```

Do not sync machine-specific paths, permission grants, daemon tokens, raw history, or cleanup receipts by default.

### 10. Support Bundle As A Controlled Operation

Real-product signal:

- Slack starts/stops net logging and gives a zip file.
- Docker Desktop collects diagnostics and exposes logs.
- CleanMyMac documents support tooling and safety.

Clean Disk adoption:

Support bundle should be an operation with:

```text
preview
redaction level
included categories
excluded sensitive data
size estimate
create
receipt
manual upload or copy
```

No silent upload. No raw full-path tree by default.

## Product State Additions

Add these to product vocabulary:

```text
ActionDescriptor
ActionRole
ActionScope
ActionRisk
ActionAvailability
CommandRegistry
KeyboardShortcut
TrustMode
OperationLedger
OperationReceipt
RepairRecipe
ShellAction
ExternalToolAction
ProtocolCompatibility
MachineLocalState
SupportEvidence
```

## UI Surface Additions

These surfaces are now justified by launched-product behavior:

```text
Command Palette
Context Action Panel
Operation History
Repair Center
Daemon Compatibility Banner
Support Bundle Preview
Keyboard Shortcuts Settings
Native Integration Settings
Trust Mode / Advanced Mode Gate
```

Do not put all of them in MVP UI at once. But the architecture should not block them.

## MVP Impact

For MVP, the useful minimum is:

```text
ActionDescriptor for scan/reveal/copy path/add to queue/delete plan/export
ActionAvailability with DisabledReason
OperationState for scan and cleanup preview
OperationReceipt for cleanup execution
RepairRecipe for daemon and permission problems
ShellAction for reveal/open/copy path
TrustMode with Normal and AdvancedCleanup
```

This is enough to avoid ad hoc UI logic while keeping the scope realistic.

## Summary

The operational UX lesson from top launched products:

```text
Users trust tools when actions are discoverable,
dangerous capabilities are gated by mode and evidence,
operations leave receipts,
and repair paths are concrete.
```

Clean Disk should make actions first-class. Screens should render actions, not invent them.
