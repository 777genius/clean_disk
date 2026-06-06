# Native Shell Integration And Status Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- Microsoft notification area guidelines: https://learn.microsoft.com/en-us/windows/win32/uxguide/winenv-notification
- MDN Badging API: https://developer.mozilla.org/en-US/docs/Web/API/Badging_API
- MDN display a badge on the app icon: https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/How_to/Display_badge_on_app_icon
- MDN Window Controls Overlay API: https://developer.mozilla.org/en-US/docs/Web/API/Window_Controls_Overlay_API
- GNOME accessibility guidelines: https://developer.gnome.org/documentation/guidelines/accessibility.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- WCAG 2.2.2 Pause, Stop, Hide: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html

## Problem

Desktop and installed web apps often expose state through app badges, taskbar
overlays, notification area icons, dock menus, menu bar extras, and window
controls overlay. These integrations can help long-running operations, but they
are also inconsistent across platforms and can hide critical state from users
who do not monitor the shell surface.

Headless needs a shell status contract that treats shell UI as optional mirror,
not primary truth.

## Decision Options

1. Let app shell code handle all shell integrations - 🎯 5   🛡️ 5   🧠 2,
   about 0-100 LOC. Simple but drifts from in-app status.
2. Add shell status mirror contract - 🎯 9   🛡️ 9   🧠 5, about 300-750 LOC.
   Best fit.
3. Build cross-platform tray/taskbar implementation in Headless - 🎯 3
   🛡️ 5   🧠 9, about 2000-5000 LOC. Too platform-specific.

Accepted: option 2.

## Accepted Contract

Headless emits shell status intents:

```dart
final class RShellStatusIntent {
  final RShellStatusKind kind;
  final String accessibleLabel;
  final int? badgeCount;
  final RStatusSeverity severity;
  final bool requiresUserAttention;
  final bool isPrivacySensitive;
  final RShellAction? primaryAction;
}
```

Platform adapters map intents to tray, dock, taskbar, PWA badge, or no-op.

## Rules

- In-app status remains source of truth.
- Shell badges never contain secrets, paths, or delete targets.
- Shell actions route through normal command provenance.
- Closing the window to tray must be explicit and discoverable.
- A tray icon cannot be the only way to stop a scan.
- Badge count and attention state are cleared when no longer true.
- Window controls overlay must not cover app title, navigation, or focusable
  controls.
- Unsupported shell features degrade to in-app status.

## Clean Disk Requirements

Clean Disk may expose shell status for:

- scan running;
- scan complete;
- cleanup needs review;
- daemon disconnected;
- update available;
- support bundle ready.

It must not expose full folder names, user names, or reclaim targets in taskbar,
tray, dock, or badge text.

## Shell Status Classes

```text
mirror:
  repeats in-app status

attention:
  asks user to return to app

background:
  shows operation is running

action:
  allows safe command such as open app or pause scan

danger:
  prohibited as shell-only action
```

## Testing Requirements

- Shell status intent has in-app equivalent.
- Badge clears after state resolves.
- Unsupported platform no-ops safely.
- Shell action re-enters app and validates session.
- Privacy redaction test for labels.
- Window controls overlay geometry avoids focus targets.

## Failure Catalog

- Tray icon is only stop button for scan.
- Badge says "42" with no in-app explanation.
- Dock menu exposes Move to Trash.
- Window controls overlay covers search field.
- Shell notification includes path.
- Closing window hides app with no way for keyboard user to restore it.

## Release Gates

- Shell integrations are adapters, not component dependencies.
- Every shell status has in-app equivalent.
- Destructive commands are prohibited from shell-only surfaces.
- Privacy classification is required for shell labels and badges.

## Summary

Shell integrations are useful mirrors, not product truth. Headless should expose
status intents that platform adapters can map safely without bypassing in-app
accessibility and command authority.
