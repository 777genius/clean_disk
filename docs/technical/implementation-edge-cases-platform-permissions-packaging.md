# Implementation Edge Cases - Platform Permissions And Packaging

Last updated: 2026-05-16.

This file records edge cases for desktop packaging, OS permissions, signing, installers, app identity, app stores, and update channels.

Clean Disk is not a normal desktop CRUD app. It scans protected user folders, starts a local Rust daemon, displays private path metadata, and eventually moves files to Trash. Packaging choices decide what the app can see, how much users trust it, whether the daemon can start, and whether security prompts are understandable.

Related documents:

- [Implementation edge cases advanced scenarios](implementation-edge-cases-advanced-scenarios.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Rust architecture](rust-architecture.md)

## Sources Reviewed

- Apple Developer Documentation, [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox?changes=_3). Relevant points: sandboxed apps only get unrestricted access to limited filesystem areas; user-selected files/folders and bookmarks can extend access; POSIX permissions, ACLs, and mandatory controls can still deny access.
- Apple Human Interface Guidelines, [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy/). Relevant points: request access only to data actually needed; avoid asking before the person shows interest in the feature; avoid launch-time permission requests unless the app cannot function without the resource; explain the reason clearly.
- Apple Developer Documentation, [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice). Relevant points: macOS 13+ uses `SMAppService` to register LoginItems, LaunchAgents, and LaunchDaemons as helper executables for an app; helper executables live inside the app's main bundle and registration is subject to user approval.
- Apple Developer Documentation, [Privacy Preferences Policy Control.Services](https://developer.apple.com/documentation/devicemanagement/privacypreferencespolicycontrol/services-data.dictionary). Relevant point: `SystemPolicyAllFiles` is the managed-device service that grants access to protected files.
- Apple Developer Documentation, [Privacy Preferences Policy Control.Services.Identity](https://developer.apple.com/documentation/devicemanagement/privacypreferencespolicycontrol/services-data.dictionary/identity). Relevant points: PPPC identities require an `Identifier`, `IdentifierType`, and `CodeRequirement`; application bundles are identified by bundle ID; nonbundled binaries are identified by installation path; helper tools embedded within an application bundle inherit permissions of the enclosing app bundle.
- Apple Developer Technote, [TN3127: Inside Code Signing - Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements). Relevant point: designated requirements identify code across app versions; without a suitable designated requirement, macOS cannot reliably track authorization across updates.
- Apple Developer Technical Note, [TN2206: macOS Code Signing In Depth](https://developer.apple.com/library/archive/technotes/tn2206/_index.html). Relevant points: macOS code signing policy recognizes updates through designated requirements; nested code must be signed correctly; apps distributed outside the Mac App Store should ship as signed DMG or signed installer package.
- Apple Developer Forums, [On File System Permissions](https://developer.apple.com/forums/thread/678819). Relevant points from Apple DTS: Full Disk Access is part of mandatory access control; all processes including root are subject to MAC; TCC decisions rely on stable code signing identity; responsible code attribution can break for helper tools, especially if a child daemonizes itself; `AssociatedBundleIdentifiers` may be needed for launchd jobs.
- Apple Developer Forums, [Are TCC permissions inherited by bundled extensions?](https://developer.apple.com/forums/thread/763956). Relevant point from Apple DTS: TCC permissions can or should be inherited by the responsible process, but exact behavior depends on implementation and bugs, so the only reliable answer for a specific bundle/helper shape is to test it.
- Apple Developer Forums, [daemons are unable to access files or folders](https://developer.apple.com/forums/thread/118508). Relevant point from Apple DTS: when granting Full Disk Access to a CLI tool as a LaunchDaemon is problematic, the simplest solution is to put the daemon inside an app bundle.
- DaisyDisk User Guide, [Full Disk Access](https://daisydiskapp.com/guide/full-disk-access), [Disk overview and scanning](https://daisydiskapp.com/guide/4/en/DisksOverview/), and [Restricted folders](https://daisydiskapp.com/guide/4/en/Restricted/). Relevant points: a disk analyzer can still scan without FDA, hidden/restricted space is shown as incomplete, users can rescan after granting access, and administrator scanning is a separate advanced flow.
- GrandPerspective Help, [Full Disk Access](https://grandperspectiv.sourceforge.net/HelpDocumentation/FullDiskAccess.html). Relevant points: FDA improves scan coverage but still does not guarantee access to all files, such as other users' files or certain system-protected locations.
- Apple Developer Documentation, [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). Relevant points: Developer ID signing, notarization, hardened runtime, and notary logs are part of direct distribution.
- Apple Help/Xcode, [Enable hardened runtime](https://help.apple.com/xcode/mac/current/en.lproj/devf87a2ac8f.html). Relevant point: notarized macOS apps require hardened runtime and entitlements for required behavior.
- Apple Support, [App code signing process in macOS](https://support.apple.com/en-ca/guide/security/sec3ad8e6e53/web). Relevant points: apps distributed outside the Mac App Store need Developer ID signing and notarization for default Gatekeeper behavior; notarization tickets can be stapled.
- Apple Support, [Controlling app access to files in macOS](https://support.apple.com/en-mide/guide/security/secddd1d86a6/web). Relevant point: macOS file access is based on transparency, consent, and control.
- Apple Developer Documentation, [Security-scoped bookmark and URL access](https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access). Relevant point: app-scoped bookmarks/URLs require entitlements and are the persistent-access path for selected resources.
- Flutter Documentation, [Build and release a macOS app](https://docs.flutter.dev/deployment/macos). Relevant points: Flutter macOS release uses Xcode signing settings and Apple distribution concepts.
- Flutter Documentation, [Building Windows apps with Flutter](https://docs.flutter.dev/platform-integration/windows/building). Relevant point: Flutter Windows distribution can use MSIX or installer tooling.
- Flutter Documentation, [Build and release a Linux app to the Snap Store](https://docs.flutter.dev/deployment/linux). Relevant points: Snap confinement controls runtime resource access; Snap Store has review channels.
- Microsoft Learn, [What is MSIX?](https://learn.microsoft.com/en-us/windows/msix/overview). Relevant points: MSIX gives package identity, clean install/uninstall, automatic updates, and package integrity checks.
- Microsoft Learn, [SmartScreen reputation for Windows app developers](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation). Relevant points: SmartScreen uses publisher and file-hash reputation; EV certificates no longer bypass SmartScreen for new files as of the 2024 behavior change.
- Microsoft Support, [Windows file system access and privacy](https://support.microsoft.com/en-us/windows/-windows-file-system-access-and-privacy-a7d90b20-b252-0e7b-6a29-a3a688e5c7be). Relevant points: file system access can expose the same files/folders the user can access; users can change app access in Windows Settings; some desktop programs do not appear in the privacy list and are not affected by the setting.
- Microsoft Learn, [File access permissions](https://learn.microsoft.com/en-us/windows/apps/develop/files/file-access-permissions). Relevant points: Windows apps can access additional files through pickers, capabilities, and `FutureAccessList`; `broadFileSystemAccess` is restricted, user-changeable in Settings, and should be resilient to permission changes.
- Microsoft Learn, [App capability declarations](https://learn.microsoft.com/en-us/windows/uwp/packaging/app-capability-declarations). Relevant point: `broadFileSystemAccess` allows access like the current user for packaged apps, but capabilities are explicit product/distribution choices.
- Microsoft Learn, [Maximum Path Length Limitation](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=cmd). Relevant point: long path behavior requires registry/group policy support and an app manifest with `longPathAware`.
- Microsoft Learn, [UAC execution level manifest guidance](https://learn.microsoft.com/en-us/windows/win32/dxtecharts/user-account-control-for-game-developers). Relevant point: apps that require admin privileges declare requested execution level and trigger UAC prompts.
- Microsoft Learn, [Application manifests](https://learn.microsoft.com/en-us/windows/win32/sbscs/application-manifests). Relevant point: `asInvoker`, `requireAdministrator`, and `highestAvailable` decide whether Windows prompts for elevation and which token the process uses.
- Microsoft Learn, [User Account Control](https://learn.microsoft.com/en-us/windows/win32/secauthz/user-account-control). Relevant point: UAC lets users perform common tasks as standard users and elevate only tasks that require administrator privileges.
- Microsoft Learn, [Controlled folder access](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/enable-controlled-folders). Relevant point: Defender can block untrusted apps from changing protected folders and this can affect cleanup/write workflows.
- WizTree, [Windows disk analyzer documentation/site](https://wiztree.app/). Relevant point: fastest NTFS scanning through MFT requires administrator privileges, but that should be treated as an optional performance/coverage mode, not a default permission requirement.
- Flatpak Documentation, [Sandbox Permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html). Relevant points: default sandbox has very limited host access; static filesystem access should be minimized; broad host/home access is discouraged and sometimes reserved paths remain unavailable.
- GNOME Developer Documentation, [File Dialogs](https://developer.gnome.org/documentation/tutorials/beginners/components/file_dialog.html). Relevant point: native file selection dialogs are preferred and work better with sandboxed environments.
- XDG Desktop Portal Documentation, [FileChooser](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.FileChooser.html). Relevant points: sandboxed apps can ask the user for access through a file chooser; selected files may remain accessible across sessions through the document portal.
- Snapcraft Documentation, [Interfaces](https://snapcraft.io/docs/reference/interfaces/). Relevant point: Snap interfaces define resource access and auto-connect behavior.
- Snapcraft Documentation, [home interface](https://snapcraft.io/docs/home-interface). Relevant point: `home` allows non-hidden user-owned files in home, not arbitrary hidden or system paths.
- Snapcraft Documentation, [removable-media interface](https://snapcraft.io/docs/reference/interfaces/removable-media-interface/). Relevant points: removable media access covers `/media`, `/run/media`, `/mnt`; auto-connect is normally not granted because media can contain sensitive data.
- Linux man-pages, [path_resolution(7)](https://man7.org/linux/man-pages/man7/path_resolution.7.html) and [access(2)](https://man7.org/linux/man-pages/man2/access.2.html). Relevant points: path traversal can fail with `EACCES` when search permission is missing on a path component; permission checks are user and process-context dependent.
- AppImage Documentation, [Packaging guide](https://docs.appimage.org/packaging-guide/index.html) and [Signing AppImages](https://docs.appimage.org/packaging-guide/optional/signatures.html?highlight=signing). Relevant points: AppImage can be packaged, updated, and signed, but it is not the same permission model as Flatpak/Snap.
- FreeDesktop.org, [Trash Specification](https://specifications.freedesktop.org/trash/latest). Relevant point: Linux Trash behavior depends on spec-compliant storage, top directories, and restore metadata.

## Severity Scale

- `P0` - can make the app unable to scan expected folders, delete under the wrong identity, lose user trust through scary prompts, break updates during destructive work, or ship an unsafe remote/daemon configuration.
- `P1` - can create confusing permission UX, partial platform support, false performance claims, install friction, broken cleanup receipts, or support burden.
- `P2` - important polish, documentation, enterprise readiness, app-store listing quality, or release engineering maturity.

## Top 3 Packaging Decisions

1. Direct native desktop distribution first, store/sandboxed packages later - 🎯 9 🛡️ 9 🧠 6, roughly 400-1100 LOC of packaging config, capability detection, docs, and release checks. This is the most honest route for a disk analyzer because sandboxed stores can make full disk scanning misleading.
2. Platform capability probe plus permission doctor before scan - 🎯 10 🛡️ 9 🧠 6, roughly 600-1500 LOC across Rust platform adapters, Flutter onboarding, protocol capabilities, and tests. This prevents "it scanned nothing" support cases.
3. Separate packaging profiles for `dev`, `direct`, `store`, `sandboxed`, and `enterprise` - 🎯 8 🛡️ 8 🧠 7, roughly 500-1600 LOC of build scripts, manifests, entitlements, installer metadata, and CI checks. This keeps one codebase while making OS identity and permission assumptions explicit.

## Core Principle

Packaging is part of the product architecture.

For Clean Disk, these are not release afterthoughts:

- macOS app identity decides TCC and Full Disk Access behavior;
- Windows manifest decides long-path behavior and UAC prompts;
- Linux package format decides whether the app sees host files at all;
- installer identity decides SmartScreen/Gatekeeper trust;
- daemon packaging decides whether browser UI can connect;
- updater policy decides whether active scan/delete is interrupted;
- uninstall policy decides whether receipts, caches, and tokens remain.

The app must expose its current authority as data:

```text
platform
distribution_channel
package_mode
signed_or_debug
sandboxed
scan_authority
trash_authority
daemon_bind_mode
permission_grants
known_limitations
```

This belongs in a capability endpoint/read model, not only in release notes.

## Permission Timing And Architecture

### Permission Requests Are Product Workflows - `P0`

The app should not ask for broad filesystem authority on launch. Apple HIG guidance is clear: request access only when needed, avoid asking before the user shows interest in the feature, and avoid launch-time prompts unless the app cannot function without the resource. Clean Disk can function with reduced scope, so broad permission should be progressive.

Recommended default flow:

1. Launch into a useful app state with no broad prompt.
2. Let the user scan safe/default targets first, such as Downloads or a selected folder.
3. If the target is Home, Library, system folders, external volumes, or full disk, run a capability preflight before starting the scan.
4. If access is missing, show exactly what will be partial and offer the smallest useful permission path.
5. If the user declines, continue with a partial scan and show skipped/protected counts.
6. After the user changes settings, rerun the scanner-process capability probe and then rescan.

Top 3 permission timing options:

1. Progressive permission from scan intent - 🎯 10 🛡️ 9 🧠 6, roughly 700-1800 LOC across capability probes, UI states, settings guidance, and test fixtures.

   Best fit. Ask only when the user chooses a target that needs broader authority. This respects platform guidance and keeps the first experience useful.

2. Permission Doctor page available from first run - 🎯 8 🛡️ 9 🧠 7, roughly 900-2200 LOC.

   Strong companion to option 1. It should not block the first screen, but it gives power users a clear place to fix macOS FDA, Windows packaged-app access, Linux sandbox interfaces, and daemon identity problems.

3. Ask for maximum access at launch - 🎯 3 🛡️ 5 🧠 4, roughly 300-900 LOC but poor trust.

   Technically simpler, but bad UX for a privacy-sensitive disk analyzer. It creates scary first-run friction and still does not solve Windows/Linux package-mode differences.

### User-First Permission Ladder - `P0`

The UI should speak in terms of scan completeness, not raw OS permissions. Users usually care about "can I find what's using space?" and "is this result complete?", not about TCC, UAC, Flatpak, PPPC, or ACL internals.

Recommended ladder:

```text
Level 0 - No extra access
  Show disks/known folders if discoverable, scan app-visible/default targets, display limitations.

Level 1 - User selected target
  Folder picker/open panel/portal. Best first broad action because it is intent-based.

Level 2 - Complete user-space scan
  Home, Library/AppData, hidden folders, app containers, external drives. Use platform-specific guidance.

Level 3 - Full disk or all-files scan
  macOS Full Disk Access, Windows packaged broad file access, Linux native unsandboxed/package-specific host access.

Level 4 - Elevated/system scan
  Windows admin/MFT fast path, macOS admin scan, Linux root/system paths. Advanced, read-only first, never default.

Level 5 - Destructive cleanup authority
  Revalidate identity, write/delete permission, Trash support, locks, provider state, and confirmation.
```

Recommended first-run UX:

- show the normal app, not a permission wall;
- default target chips: Downloads, Home, Custom Folder, and current disk if probe says it is meaningful;
- each target shows a compact capability badge: `Complete`, `May be partial`, `Needs access`, `Advanced`, or `Unavailable`;
- first scan recommendation should be a low-friction target, usually Downloads or Custom Folder;
- "Full disk scan" is present but shows a preflight explainer before scan;
- Permission Doctor is reachable from the warning/status area and Settings, not forced on first launch.

Recommended scan flow:

```text
select target
  -> scanner-process preflight
  -> if complete enough: start scan
  -> if partial: show "Scan anyway" and "Improve access"
  -> if blocked: show exact platform action
  -> after scan: show skipped/protected count and rescan action
```

Recommended copy principles:

- avoid "Clean Disk needs permission";
- prefer "This scan can continue, but protected folders like Library and Messages will be counted as skipped";
- state what the app reads: names, metadata, sizes, timestamps, not file contents unless a future preview feature explicitly does so;
- always offer a non-broad fallback where possible;
- do not use alarming OS terms unless the platform settings page requires them.

### Cross-Platform UX Contract - `P0`

All platforms should render the same product states even though the underlying permission mechanisms differ.

| Product state | User meaning | macOS | Windows | Linux |
| --- | --- | --- | --- | --- |
| `complete` | Result is expected to cover target | FDA or selected-folder grant is sufficient | Current token/package grant covers target | UID/package grant covers target |
| `partial_can_scan` | Scan can run but skipped count matters | TCC/FDA missing for protected folders | ACL/Defender/package setting may block parts | POSIX/ACL/sandbox/interface may block parts |
| `needs_user_action` | User can improve result now | Open settings, picker, bookmark | Picker, Settings, restart packaged app if needed | Portal picker, package interface, install profile |
| `advanced_only` | Higher-risk mode | admin/helper scan | run elevated/MFT fast path | root/system path/native package |
| `unsupported_here` | Build/package cannot do it honestly | sandboxed/store limitation | packaged/store limitation | Flatpak/Snap limitation |

This gives Flutter one consistent UI:

- capability badge on scan target;
- preflight sheet for incomplete targets;
- partial result banner after scan;
- skipped/protected drawer with grouped reasons;
- Permission Doctor for platform-specific repair;
- rescan button after permission changes.

### Competitor UX Lessons - `P1`

Existing disk analyzers confirm the same direction:

- DaisyDisk can scan without Full Disk Access, but explains hidden/restricted space and asks users to rescan after granting access.
- GrandPerspective recommends Full Disk Access for broader coverage but documents that even FDA cannot read everything.
- WizTree uses administrator privileges for fastest NTFS MFT scanning, but this is a speed/coverage optimization and should not become our default trust posture.

Clean Disk should be more explicit than those tools:

- never make hidden/protected space look like normal "Other";
- separate "not scanned because protected" from "scanned but unknown type";
- separate "read scan authority" from "delete authority";
- make permission changes observable through scanner-process probes, not assumptions.

### Concrete User Journeys - `P0`

The product should support these journeys before adding any elevated/system mode.

#### First Launch

Goal: let the user see value without asking for broad trust.

UI:

- show target chips/cards: `Downloads`, `Home`, `Custom Folder`, current disk if available;
- each target has a small scan-quality badge;
- primary action is `Scan`;
- secondary action is `Choose Folder`;
- Permission Doctor is visible but not blocking.

Behavior:

- run a lightweight scanner-process capability probe in the background;
- never trigger macOS FDA setup, Windows elevation, or Linux package-interface guidance before target intent;
- if probe is slow or inconclusive, show `May be partial`, not a spinner wall;
- store no broad permission decision until the user selects a target.

#### User Scans Downloads

Goal: fastest low-risk success path.

Behavior:

- start scan immediately if preflight says readable;
- no Full Disk Access prompt;
- if a few files are denied, complete scan and show skipped count;
- after scan, show details and cleanup candidates only for readable/safe paths.

#### User Scans Home Or Library

Goal: make partial scan useful and permission improvement obvious.

Preflight sheet:

```text
This scan can run now, but some protected folders may be skipped.

Scan anyway
Improve access
```

Behavior:

- `Scan anyway` starts and marks result as partial if protected paths fail;
- `Improve access` opens platform guidance;
- after permission changes, the app re-probes and offers `Rescan`;
- skipped paths are grouped by reason: protected, ACL denied, sandbox/package, disappeared, mount boundary.

#### User Scans Full Disk

Goal: make broad access intentional.

Behavior:

- show target summary before scan: which volumes, expected limitations, whether external/network/system paths are included;
- ask for broad permission only after the user confirms the full disk target;
- if permission is denied, keep the target selectable but label result as partial;
- never claim "100% scanned" when protected/skipped groups exist.

#### User Wants To Delete

Goal: do not reuse read permission as delete permission.

Behavior:

- delete preflight runs after selection and before final confirmation;
- read authority, write/delete authority, Trash support, lock/in-use state, and stale identity are separate checks;
- if cleanup needs more authority, show it after the user has selected items, not at app launch;
- partial cleanup returns a receipt with moved, skipped, failed, and unchanged items.

### UX Quality Gates - `P1`

These gates should be used in design reviews and tests:

- no first-run broad permission wall;
- a user can complete a useful scan without changing OS settings;
- every permission prompt is caused by a visible user action;
- denied/revoked permissions leave the app usable;
- scan result has a visible completeness state;
- skipped/protected groups are explorable and countable;
- settings guidance names the exact app/helper/process where platform requires it;
- after returning from settings, the app re-probes automatically or with one clear button;
- Windows does not require "Run as administrator" for ordinary user-space scans;
- Linux sandboxed builds clearly label reduced capability before the user wastes time;
- no normal help text tells users to disable SIP, UAC, Defender, Gatekeeper, SELinux, AppArmor, or sandboxing.

### Product Copy Patterns - `P1`

Preferred copy:

```text
Clean Disk can scan this folder now.
```

```text
This scan may be partial because some protected folders are not readable yet.
```

```text
Clean Disk reads file names, sizes, timestamps, and folder structure for this scan. It does not read file contents.
```

```text
Grant access, then rescan to include protected folders.
```

Avoid:

```text
Clean Disk needs Full Disk Access to work.
```

```text
Run as administrator for best results.
```

```text
Disable your security settings.
```

### Platform-Specific Best UX Defaults - `P0`

macOS:

- default to selected-folder and normal user scan;
- ask for Full Disk Access when the user chooses full disk, Home/Library completeness, or after a partial protected-folder result;
- show "metadata only" reassurance before broad access;
- use the app/helper name exactly as it appears in System Settings;
- do not promise FDA reads everything.

Windows:

- default to current-user scan with `asInvoker`;
- treat administrator/MFT scanning as `Advanced` and separate from ordinary cleanup;
- explain that admin mode may scan more system/user folders but changes risk;
- for packaged builds, support Settings/file-system-access changes and restart/rescan guidance;
- Defender/Controlled Folder Access issues should be typed as write/cleanup blockers, not generic app failures.

Linux:

- native package/AppImage first for best full-disk UX;
- Flatpak/Snap are reduced-capability profiles by default;
- use portal folder selection for sandboxed builds before broad package permissions;
- explain hidden folders/removable media/package interface limits before scan;
- do not suggest running the UI as root for normal use.

### Cross-Platform Permission Architecture - `P0`

Permissions must be modeled as capabilities and workflows, not as OS-specific booleans scattered through UI code.

Accepted clean architecture shape:

```text
domain
  ScanTarget
  ScanScope
  ScanCapability
  PermissionStatus
  PermissionRequirement
  PermissionGrantKind
  PermissionIssue

application ports
  ScanCapabilityProbePort
  PermissionGuidancePort
  FolderGrantPort
  ScannerIdentityPort
  PackageProfilePort
  TrashCapabilityProbePort

application use cases
  EvaluateScanTargetCapability
  PrepareScanTarget
  StartScanWithPreflight
  RefreshPermissionState
  BuildPermissionGuidance

infrastructure adapters
  macos_tcc_capability
  macos_security_scoped_bookmarks
  windows_acl_capability
  windows_packaged_app_capability
  windows_uac_elevation_detector
  linux_posix_acl_capability
  linux_flatpak_portal_capability
  linux_snap_interface_capability
```

Rules:

- domain models permission concepts without naming TCC, UAC, Flatpak, Snap, PPPC, or portals;
- application layer owns workflows and decisions such as "scan is allowed but partial";
- infrastructure adapters own platform probes, settings URLs, package detection, bookmarks, portals, ACL checks, and scanner identity details;
- UI only renders capability state and sends user commands;
- daemon/server exposes capability endpoints produced by the scanner process, not guessed by Flutter;
- scan/delete use cases depend on capability ports before performing filesystem work.

Minimal normalized states:

```text
granted
missing_user_grant
missing_package_permission
blocked_by_os_policy
blocked_by_enterprise_policy
blocked_by_acl
blocked_by_sandbox
blocked_by_scanner_identity
unsupported_in_package_mode
unknown_needs_probe
```

Minimal normalized grant kinds:

```text
selected_folder
recursive_selected_folder
full_disk_or_all_files
packaged_app_file_system_access
admin_or_elevated_token
linux_portal_document_grant
linux_static_package_interface
enterprise_managed_policy
```

### Permission Guidance Must Be Capability-Driven - `P1`

Do not hardcode "open macOS settings" or "run as admin" into the screen. The app should render `PermissionGuidance` returned by the platform adapter:

```text
title
reason
risk_level
affected_targets
recommended_action
can_open_settings
settings_uri_or_command
requires_restart
requires_rescan
fallback_behavior
support_redaction_policy
```

This keeps the same Flutter UI usable for:

- direct macOS app with bundled scanner;
- Windows traditional installer;
- Windows MSIX/packaged app;
- Linux AppImage/distro package;
- Linux Flatpak/Snap reduced-capability builds;
- future remote/headless server mode.

## Distribution Strategy

### Direct Native Builds Are The MVP Baseline - `P0`

Clean Disk needs broad filesystem visibility. Sandboxed package formats can be useful later, but they are likely to create confusing MVP behavior.

Recommended MVP:

- macOS direct Developer ID signed and notarized app bundle/DMG;
- Windows direct signed installer or MSIX after path/UAC behavior is tested;
- Linux AppImage or distro package for broad host access, plus Snap/Flatpak later with reduced capability labels;
- web UI connects to local daemon only after local token/origin model exists.

Why:

- users expect a disk analyzer to see home, caches, external drives, and developer folders;
- sandboxed modes may hide the exact folders users want to inspect;
- a partial scan that looks complete is worse than a clear permission warning.

### Store Builds Are Separate Products - `P1`

Mac App Store, Microsoft Store, Snap Store, and Flathub each have review, sandbox, capability, and update rules.

Required behavior:

- each store build has its own capability profile;
- store build UI must not promise full disk scan if sandbox blocks it;
- store build release notes must state access model;
- feature flags disable unsupported cleanup/reveal/daemon behavior;
- support docs identify the build channel before troubleshooting.

### Do Not Hide Permission Limits Behind Generic Errors - `P0`

`permission denied` is not enough.

Required behavior:

- distinguish OS privacy denial, sandbox denial, POSIX/ACL denial, read-only filesystem, missing package interface, system protection, and daemon identity mismatch;
- capability probe runs before scan and after permission changes;
- scan result includes skipped count by denial class;
- UI shows remediation path where possible;
- support bundle includes redacted capability state.

## macOS

### Full Disk Access Is A Trust Boundary - `P0`

macOS protects many user data locations through privacy controls. A disk analyzer may need broad access, but asking for Full Disk Access too early can damage trust.

Recommended product flow:

1. Start with selected folder scan and visible limitations.
2. Explain why broader access improves scan completeness.
3. Offer guided Full Disk Access setup only when user requests full home/system scan.
4. Re-check capabilities after the user returns.

Required behavior:

- do not show a fake complete disk total when protected areas were skipped;
- classify TCC/privacy denial separately from ordinary permission denial;
- show "scan is partial" in summary when privacy restrictions affected traversal;
- avoid forcing Full Disk Access before the user has seen value;
- never instruct users to weaken SIP or other system protections.

When to ask:

- first scan of Downloads or a user-selected folder: do not ask for Full Disk Access upfront;
- scan of Home or `~/Library`: preflight, show likely protected folders, offer Full Disk Access only if the user wants a complete result;
- full disk scan: show a clear before-scan explanation and link/open the correct settings page where possible;
- after a partial scan with TCC-denied paths: show "scan is partial" and an action to grant access/rescan;
- before delete from protected locations: revalidate in the scanner/helper and request remediation before the destructive confirmation.

Mac-specific grant types:

- user-selected folder through open panel or security-scoped bookmark;
- Full Disk Access in System Settings for complete protected-folder scanning;
- MDM PPPC profile for enterprise deployment;
- no programmatic self-grant for consumer builds.

### The Scanner Process Identity Matters - `P0`

Clean Disk will likely have a Flutter app and a Rust daemon/server process. macOS permissions may be tied to the identity/path/signature of the process that performs filesystem access.

Risk:

- user grants access to UI app but daemon still cannot scan;
- daemon is launched from a debug path and receives different identity than release helper;
- code signing identity changes between builds and invalidates saved permissions/bookmarks;
- moving app bundle changes behavior in ways users cannot diagnose.

Required behavior:

- decide which process performs actual filesystem traversal;
- bundle and sign helper/daemon consistently with the app;
- capability probe runs in the same process that scans;
- docs and UI name the exact app/helper requiring permission;
- debug builds never define final permission UX.

### Production Scanner Must Be A Signed App Component - `P0`

The local `pdu` runs proved that macOS protected folders are a normal scan path, not a rare edge case. In `~/Library`, pdu completed quickly but reported many `read_dir` `Operation not permitted` errors for protected folders. This turns scanner identity from a generic packaging concern into a product architecture constraint.

Accepted guardrail:

- production must not shell out to a random external `pdu` binary, Homebrew binary, shell script, or unsigned helper;
- `parallel-disk-usage` is used as a Rust library adapter compiled into our scanner component;
- the scanner component is either the main app process or a bundled helper/daemon signed with the Clean Disk release artifact;
- the capability probe, real scan, metadata enrichment, and delete preflight run under the same signed component identity;
- CLI wrapping is allowed only for throwaway benchmarking and must never define permission UX or production contracts.

Why:

- Apple documents that Full Disk Access must be granted explicitly for full storage access;
- Apple PPPC identity uses bundle ID or binary path plus a code requirement, so a nonbundled binary has a different identity surface from the app;
- Apple DTS notes that TCC/MAC depends on stable code signing identity and responsible code attribution;
- helper attribution can break if the child process daemonizes, is launched through a shell wrapper, or is not clearly associated with the app bundle;
- a permission granted to `Clean Disk.app` cannot be assumed to authorize `/opt/homebrew/bin/pdu`, `/tmp/pdu`, `/bin/sh`, or a debug sidecar.

Top 3 macOS scanner identity models:

1. Bundled signed app-child scanner process - 🎯 9 🛡️ 8 🧠 6, roughly 500-1400 LOC/config/tests.

   Best MVP fit. The Flutter app launches a bundled signed `clean-disk-server` helper on demand from inside the app bundle. It keeps install simple and lets the permission doctor name one product. Must test responsible-code attribution after signing/notarization.

2. `SMAppService` per-user LaunchAgent/helper inside the app bundle - 🎯 8 🛡️ 9 🧠 8, roughly 1000-2600 LOC/config/tests.

   Strong later path for web UI availability without keeping the Flutter window open. More lifecycle/update complexity. Must test whether FDA appears under the app, helper, or both, and whether `AssociatedBundleIdentifiers` is needed.

3. External installed CLI or Homebrew `pdu` binary - 🎯 2 🛡️ 3 🧠 4, roughly 200-700 LOC but unacceptable for production.

   Easy to prototype, but unstable for permissions. It creates a separate TCC identity, can be path-based instead of bundle-ID-based, and makes user guidance impossible to keep honest.

Required release QA matrix:

| Case | What must be proven |
| --- | --- |
| Debug unsigned/ad-hoc build | Permission behavior is marked non-authoritative and never used for product claims. |
| Signed and notarized app without Full Disk Access | Protected folders produce typed partial-scan issues, not generic failures. |
| Signed and notarized app with Full Disk Access granted to app | The scanner helper can read the same protected probe set used by production scans. |
| App-child scanner helper | FDA attribution is stable and System Settings shows a user-understandable app/helper name. |
| `SMAppService` LaunchAgent/helper | FDA attribution, launch approval, update, and uninstall behavior are measured separately. |
| App moved after permission grant | Capability probe detects permission loss or path/signature attribution change. |
| App update with same bundle ID/team ID | FDA and selected-folder access survive normal update, or remediation is shown. |
| Helper renamed/resigned/path changed | Permission loss is detected and reported as scanner identity mismatch. |
| External pdu binary | Confirmed prototype-only path, expected to have separate/unstable permission behavior. |

Permission doctor data must include:

```text
scanner_launch_model
scanner_executable_path
scanner_bundle_identifier
scanner_team_identifier
scanner_code_requirement_available
scanner_signed_status
scanner_notarized_status
scanner_responsible_bundle_identifier
full_disk_access_probe_status
protected_probe_results
selected_folder_bookmark_status
identity_mismatch_reason
```

The probe must run in the scanner process, not in Flutter UI. The UI can display results and open guidance, but it cannot infer the Rust scanner's TCC authority by checking its own access.

### Security-Scoped Bookmarks Are For Scoped Access - `P1`

For user-selected roots, security-scoped bookmarks can preserve access without requiring broad Full Disk Access.

Required behavior:

- selected folder access is modeled as an app capability;
- bookmark state has valid, stale, missing, and denied states;
- app can forget/revoke selected roots;
- failed bookmark resolution becomes a typed target-unavailable error;
- stale bookmark requires user re-selection before destructive actions.

### App Sandbox Changes The Product Shape - `P0`

Mac App Store and sandboxed builds can be more trusted, but broad disk scanning is constrained.

Required behavior:

- sandboxed build advertises `sandboxed = true`;
- UI defaults to selected-folder workflows;
- full disk scan is disabled or clearly marked unavailable;
- Trash/reveal behavior is tested inside sandbox;
- do not use unsandboxed assumptions in shared presentation copy.

### Notarization And Hardened Runtime Are Required For Trustworthy Direct Distribution - `P1`

Apple documentation and platform security guidance make Developer ID signing, notarization, hardened runtime, entitlements, and notary logs part of a normal direct-distribution flow.

Required behavior:

- release CI signs app, daemon/helper, and bundled native libraries;
- release CI notarizes and staples where appropriate;
- notary warnings fail or at least block promotion;
- hardened runtime entitlements are minimal and reviewed;
- first-run permission QA uses notarized release artifacts, not only debug builds.

### macOS Updates Can Break Permissions - `P1`

Even when behavior is correct, OS updates, app moves, bundle ID changes, signature changes, or helper path changes can force users to re-grant access.

Required behavior:

- capability probe catches permission loss after update;
- release checklist includes update-over-old-version test;
- app displays "permission changed" remediation, not generic scan failure;
- saved scan targets track whether they depend on security-scoped access;
- support docs explain how to reset/re-grant access without editing system databases.

## Windows

### Long Path Support Is A Packaging Requirement - `P0`

Package managers, `node_modules`, game folders, generated build outputs, and deeply nested archives can exceed legacy Windows path limits.

Microsoft documents that long path support requires both OS policy/registry support and an application manifest with `longPathAware`.

Required behavior:

- Windows app/daemon manifest includes long-path awareness;
- path adapter uses Windows-native path handling consistently;
- scan tests include paths over 260 characters;
- UI can display long paths with middle truncation;
- failure code distinguishes OS long-path support disabled from ordinary not-found.

### Do Not Run The Whole App As Administrator - `P0`

Admin elevation can make a disk analyzer more dangerous and less predictable.

Risks:

- scanning/deleting as admin can affect other users or system areas;
- Trash/Recycle Bin behavior may use a different token/context;
- UAC prompt on every launch damages trust;
- elevated daemon plus browser UI increases attack impact.

Required behavior:

- default manifest should be `asInvoker`;
- admin-only scan targets are advanced/read-only first;
- system cleanup requires separate explicit design;
- destructive actions under elevated token are disabled until reviewed;
- UI clearly shows elevated state if ever supported.

When to ask:

- normal user-profile scans: do not ask for admin/elevation;
- `C:\Users\<current-user>`, Downloads, developer caches, and app caches: run as the current user;
- `C:\Windows`, `Program Files`, other users' profiles, service-owned folders, and system restore areas: mark as elevated/admin-only or read-only advanced targets;
- if a scan hits ACL denial, show skipped/denied count and continue partial where safe;
- before cleanup in elevated/system areas, require a separate design review and explicit user workflow.

Windows permission model notes:

- traditional Win32 apps are primarily constrained by the current user's token, ACLs, locks, Defender, and package/install identity;
- Windows packaged apps can use picker grants, `FutureAccessList`, and restricted `broadFileSystemAccess`;
- users can change packaged app file-system access in Settings, so capability state must be refreshed;
- Controlled Folder Access can block writes/cleanup even when read scanning works;
- running the whole app elevated changes Recycle Bin and delete semantics and is not the default.

### SmartScreen Reputation Is Expected Early - `P1`

Microsoft documents that SmartScreen uses publisher reputation and file-hash reputation. The current docs state EV certificates no longer provide instant bypass for new files after the 2024 change.

Required behavior:

- sign binaries/installers to avoid "unknown publisher";
- set expectations that new builds may still show SmartScreen warnings;
- prefer stable release cadence to reduce constant new-file reputation resets;
- consider Microsoft Store or trusted signing path when distribution matures;
- support docs show verified publisher and official download URLs.

### MSIX Is Attractive But Not Free - `P1`

MSIX gives clean install/uninstall, package identity, updates, and integrity checks. It also introduces package manifest capabilities and distribution constraints.

Top 3 Windows package options:

1. Signed traditional installer first - 🎯 8 🛡️ 7 🧠 5, roughly 250-700 LOC/config. Best MVP flexibility, more responsibility for uninstall/update cleanup.
2. MSIX first - 🎯 7 🛡️ 8 🧠 7, roughly 500-1400 LOC/config. Cleaner install/update model, but must validate broad filesystem access, daemon startup, and store/direct sideload UX.
3. Microsoft Store first - 🎯 6 🛡️ 8 🧠 8, roughly 800-2200 LOC/process. Better trust, harder review/capability constraints, not ideal before product shape stabilizes.

Required behavior:

- decide package identity before persisted tokens/paths depend on it;
- test local daemon startup inside selected package model;
- test uninstall stops daemon and removes discovery token;
- test update during active scan/delete;
- capability endpoint reports package mode.

### Defender And Security Products Affect Scan Benchmarks - `P1`

Filesystem traversal can trigger antivirus, endpoint protection, or controlled-folder-access policies.

Required behavior:

- benchmark Windows with Defender enabled;
- do not tell users to disable protection as normal guidance;
- scanner classifies slow target/security interference separately when detectable;
- support docs include "security software may slow scan" without blaming the OS;
- avoid opening file contents for size scanning unless absolutely required.

### Recycle Bin Semantics Need User Context - `P0`

Moving to Recycle Bin is not the same as permanent delete and not universal for every path.

Required behavior:

- Trash adapter executes in intended user context;
- network/removable/system paths report capability before action;
- per-item outcomes record recycle-bin unavailable versus access denied;
- elevated/system-service cleanup does not silently bypass user Recycle Bin;
- receipt describes whether item was recycled or permanently deleted only when true.

## Linux

### Flatpak Is Usually A Reduced-Capability Build - `P0`

Flatpak's default sandbox has very limited host access. Docs recommend minimizing static filesystem access and using portals where possible. A disk analyzer needs broader access than many app types.

Required behavior:

- Flatpak build advertises `sandboxed = true`;
- full disk scan is not default promised behavior;
- selected-folder scan via portal/access grants is the primary UX;
- broad `--filesystem=host` style permissions require separate review and honest store metadata;
- UI explains which host paths are invisible.

When to ask:

- Flatpak/Snap first run: do not claim full disk visibility;
- selected folder scan: use portal or package-supported folder grant first;
- hidden home, external drives, network mounts, or full host scan: show reduced-capability warning and exact package interface/permission needed;
- AppImage/distro package: no portal prompt is normally required, but POSIX permissions, ACLs, mount options, and user identity still decide access;
- remote/headless Linux: expose capability state from the server process and keep cleanup disabled until authorization is designed.

Linux permission model notes:

- unsandboxed Linux is mostly current UID/GID, POSIX permissions, ACLs, mount options, namespaces, and sometimes SELinux/AppArmor;
- Flatpak static filesystem permissions are package-time choices and broad access is discouraged;
- Flatpak portals can grant selected files/folders through a user-mediated chooser and may persist access through the document portal;
- Snap `home` access does not include hidden folders; `removable-media` covers common external mount paths but usually requires manual connection;
- package mode must be part of the capability DTO, otherwise scans will look randomly incomplete.

### Snap Strict Confinement Has Interface Limits - `P0`

Snap `home` access covers non-hidden home files; removable media requires a separate interface and normally does not auto-connect because it can expose sensitive data.

Required behavior:

- Snap build reports connected interfaces;
- hidden folders and developer caches are not assumed visible;
- external drive scan prompts for missing removable-media connection;
- strict Snap build is treated as reduced capability;
- classic confinement, if considered, needs review and store acceptance expectations.

### AppImage Is Flexible But Less Managed - `P1`

AppImage can be a pragmatic Linux MVP because it behaves more like a native app and avoids some sandbox limits. It does not provide the same store review, auto-update, or permission model as Flatpak/Snap.

Required behavior:

- sign AppImage if distributed directly;
- publish checksums and official download URL;
- update mechanism is explicit, not assumed;
- desktop integration is tested;
- daemon discovery/token files live in XDG runtime/state locations with user-only permissions.

### Linux Trash Depends On Desktop And Mount Topology - `P1`

FreeDesktop Trash spec gives a common model, but not every environment/path behaves equally.

Required behavior:

- Trash adapter reports support per target/mount;
- cross-filesystem Trash rules are respected;
- headless/server Linux defaults to no GUI Trash assumption;
- permanent delete is separate and more dangerous;
- receipts record Trash path/info only when known.

### Sandboxed Linux And Local Daemon Can Conflict - `P1`

A sandboxed Flutter UI may not be able to start or talk to a local Rust daemon the same way as an unsandboxed app.

Required behavior:

- package profile decides whether daemon is bundled, sidecar, user service, or external;
- loopback/network permission is declared where needed;
- sandboxed UI has a clear daemon discovery method;
- no hidden fallback to an unprotected public port;
- install docs tell users which package mode supports web UI.

## Daemon And Helper Packaging

### The Daemon Is Part Of The Trust Boundary - `P0`

Clean Disk's Rust daemon can scan private paths and eventually move files to Trash. Packaging it as a sidecar/helper/service changes the threat model.

Required behavior:

- daemon binary is signed with release artifact;
- daemon version is tied to app/protocol compatibility;
- daemon owns token generation and secure discovery file;
- app verifies daemon identity/version before trusting it;
- stale daemon from old install is detected and stopped/replaced.

### Single Instance Needs Installer Support - `P1`

Double-click, auto-start, browser UI launch, and update restart can produce multiple daemons.

Required behavior:

- installer/update stops old daemon gracefully;
- single-instance lock includes version and owner info;
- discovery file points to the active daemon only;
- orphan discovery files are cleaned;
- new app refuses to talk to daemon with incompatible protocol.

### User Service Vs App-Child Process Is A Product Decision - `P1`

Top 3 daemon launch models:

1. App launches child daemon on demand - 🎯 8 🛡️ 8 🧠 5, roughly 300-900 LOC. Good MVP, simpler install, browser UI needs app/launcher path.
2. Per-user background service/agent - 🎯 7 🛡️ 8 🧠 7, roughly 800-2200 LOC. Better web/CLI availability, more installer/update complexity.
3. System service - 🎯 4 🛡️ 5 🧠 9, roughly 1500-4000 LOC. Too risky for MVP because authority, auth, multi-user, and cleanup semantics become much harder.

MVP recommendation:

- app-child daemon first;
- no system service;
- per-user service only after protocol/security/update model is proven.

## Updater And Uninstaller

### Never Update During Active Delete - `P0`

Update during active move-to-trash can produce partial work, lost receipts, or incompatible daemon/UI state.

Required behavior:

- update is blocked or deferred during active delete execution;
- update during active scan asks to cancel or waits for terminal state;
- daemon drains event streams and persists terminal status before restart;
- new app queries old daemon state before replacement;
- update rollback does not replay destructive commands.

### Uninstall Must Stop Daemon But Preserve Receipts Policy - `P1`

Uninstall is not just file removal.

Required behavior:

- stop daemon;
- remove local discovery/token files;
- remove transient scan cache;
- preserve or ask about receipts/preferences according to privacy policy;
- never leave launch agent/service running after app removal;
- support reinstall without stale incompatible state.

### Release Artifacts Need Identity Tests - `P1`

Testing debug builds is not enough because signing, sandbox, paths, and permissions differ.

Required release QA:

- fresh install on clean user account;
- update from previous signed version;
- first-run permission flow;
- selected-folder scan;
- full-home/full-disk scan where supported;
- daemon start/stop/restart;
- move-to-trash smoke test on disposable fixture;
- uninstall/reinstall;
- offline launch;
- app moved to another folder on macOS where applicable.

## Capability Model

### Capability Endpoint Must Include Packaging Facts - `P0`

The UI needs to know what this build can safely do.

Recommended capability DTO:

```json
{
  "platform": "macos",
  "distributionChannel": "direct",
  "packageMode": "app_bundle",
  "sandboxed": false,
  "signedBuild": true,
  "debugBuild": false,
  "scannerProcess": "bundled_daemon",
  "scanAuthority": {
    "fullDiskLikely": false,
    "selectedFolders": true,
    "externalDrives": "unknown",
    "systemPaths": "restricted"
  },
  "trashAuthority": {
    "userTrash": true,
    "externalVolumeTrash": "unknown",
    "permanentDelete": false
  },
  "limitations": [
    "macos_full_disk_access_not_granted"
  ]
}
```

Rules:

- this DTO is produced by infrastructure/platform adapters;
- domain does not know macOS TCC, MSIX, Flatpak, or Snap;
- application use cases depend on capability ports;
- UI copy and action availability use capabilities, not platform string checks;
- support bundle includes redacted capability DTO.

### Permission Doctor Is A Feature, Not A Modal - `P1`

Disk utility users need a way to understand incomplete scans.

Required UI:

- show current scan authority;
- show why a target cannot be scanned;
- show remediation action if known;
- re-check button;
- last checked timestamp;
- reduced-capability package warning;
- safe explanation before broad access requests.

### Platform Copy Must Be Specific - `P1`

Bad:

```text
Clean Disk needs permissions.
```

Better:

```text
Clean Disk can scan Downloads now. To scan Library, Mail, Messages, and other protected folders, grant Full Disk Access to Clean Disk in System Settings.
```

Rules:

- name the folder/action affected;
- name the exact app/helper when needed;
- state whether action is optional;
- do not imply permissions bypass OS security;
- avoid scary wording before user understands benefit.

## Clean Architecture Fit

### Platform Packaging Is Infrastructure - `P0`

Domain should not import package concepts.

Recommended boundaries:

```text
domain:
  ScanTarget
  ScanAuthority
  TrashCapability
  PermissionRisk

application ports:
  PlatformCapabilityProbe
  PermissionRemediationGuide
  InstallIdentityProvider
  DaemonIdentityVerifier
  UpdateGuard

infrastructure adapters:
  macos_tcc_probe
  windows_manifest_probe
  linux_flatpak_probe
  linux_snap_probe
  appimage_identity_probe
  installer_update_guard
```

Rules:

- domain models express capability, not OS APIs;
- infrastructure translates OS/package facts;
- presentation receives user-facing remediation view models;
- tests can fake capabilities without macOS/Windows/Linux APIs;
- package profiles are composition-root decisions.

### Do Not Hardcode Platform Branches In Widgets - `P1`

The UI should not contain scattered `if macOS`, `if Windows`, `if Flatpak` checks.

Required behavior:

- feature store exposes capability view model;
- design system provides reusable permission/status components;
- app shell wires platform capability adapter;
- platform-specific copy is centralized and localized;
- tests cover capability states as data.

## Testing Matrix

### macOS Tests

Required:

- unsigned debug build permission behavior documented but not trusted as final;
- Developer ID signed/notarized direct build first launch;
- selected folder scan with bookmark persistence;
- app restart and bookmark reuse;
- Full Disk Access not granted partial scan;
- Full Disk Access granted scan;
- helper/daemon access matches UI expectation;
- update signed v1 to signed v2;
- app moved after install;
- Trash operation on disposable fixture;
- external volume scan if supported.

### Windows Tests

Required:

- signed installer fresh install;
- SmartScreen expectation documented for new artifact;
- non-admin launch;
- long path fixture over 260 chars;
- path with Unicode and spaces;
- Defender enabled benchmark;
- Recycle Bin move for normal user path;
- network/removable path Trash capability;
- update while scan active;
- update blocked during delete;
- uninstall stops daemon;
- MSIX-specific tests if MSIX profile exists.

### Linux Tests

Required:

- AppImage/native build scan home/dev folder;
- Flatpak reduced-capability scan;
- Snap strict reduced-capability scan;
- hidden home folder visibility in package modes;
- removable-media visibility;
- Trash support on common desktop environment;
- headless Linux no-GUI Trash behavior;
- daemon discovery under XDG runtime/state directories;
- uninstall/removal cleanup for each package mode.

### Cross-Platform Packaging Tests

Required:

- capability DTO snapshot per package profile;
- permission doctor copy per limitation;
- route/action disabled when capability absent;
- daemon identity mismatch rejected;
- stale daemon discovery file handled;
- update does not restart during delete;
- support bundle redacts paths and tokens;
- official artifact checksum/signature documented.

## MVP Cut Line

Before first public desktop beta:

- direct native distribution profile exists for macOS, Windows, and at least one Linux format;
- capability endpoint reports package mode, sandboxed state, scanner authority, and Trash authority;
- permission doctor exists;
- macOS release artifact is signed/notarized before real permission UX is judged;
- Windows artifact is signed and long-path-aware;
- Linux package mode does not pretend sandboxed builds have full disk access;
- daemon/helper identity is checked;
- updater is disabled or blocks during active delete;
- uninstall stops daemon and removes tokens;
- docs explain package-specific limitations.

Do not ship "full disk scan" marketing/copy until each target package profile proves what full disk means on that OS and channel.

## Summary

The safe packaging stance:

```text
Direct native builds first.
Sandboxed/store builds later as explicit reduced-capability variants.
Capability probe before scan.
Permission doctor before support burden.
No destructive cleanup under unknown package/permission identity.
```

The invariant:

```text
Clean Disk must never present a scan as complete when the package, OS privacy layer, sandbox, or daemon identity prevented it from seeing important paths.
```
