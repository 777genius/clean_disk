# Fullscreen Lock And Immersive Mode Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN Fullscreen API: https://developer.mozilla.org/en-US/docs/Web/API/Fullscreen_API
- MDN guide to the Fullscreen API: https://developer.mozilla.org/en-US/docs/Web/API/Fullscreen_API/Guide
- MDN Pointer Lock API: https://developer.mozilla.org/en-US/docs/Web/API/Pointer_Lock_API
- MDN Keyboard API: https://developer.mozilla.org/en-US/docs/Web/API/Keyboard_API
- MDN user activation: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/User_activation
- MDN Permissions Policy: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Permissions_Policy
- WCAG 2.1.2 No Keyboard Trap: https://www.w3.org/WAI/WCAG22/Understanding/no-keyboard-trap.html
- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html

## Problem

Fullscreen, pointer lock, keyboard lock, and immersive app modes can hide
browser chrome, change escape behavior, capture input, or obscure system status.
These APIs are useful for media, dashboards, kiosks, and specialized tools, but
dangerous for accessibility and trust if they remove obvious exit paths.

Headless needs a lock-mode contract before any primitive can request immersive
system state.

## Decision Options

1. Leave fullscreen and lock APIs to app code - 🎯 5   🛡️ 5   🧠 2, about
   0-80 LOC. Too easy to create traps.
2. Add explicit immersive mode capability and exit contract - 🎯 9   🛡️ 10
   🧠 6, about 350-850 LOC. Best fit.
3. Ban immersive modes in Headless - 🎯 6   🛡️ 9   🧠 1, about 0-60 LOC. Safe,
   but unnecessarily limits public use.

Accepted: option 2.

## Accepted Contract

Headless models immersive mode:

```dart
final class RImmersiveModeRequest {
  final RImmersiveModeKind kind;
  final RImmersivePurpose purpose;
  final bool requiresUserActivation;
  final bool capturesPointer;
  final bool capturesKeyboard;
  final bool hidesBrowserChrome;
  final bool hasVisibleExit;
  final bool isAllowedByPolicy;
}
```

Only adapters can call platform APIs.

## Rules

- Fullscreen and lock requests require explicit user command.
- A visible and keyboard-accessible exit path is always present.
- Escape or platform exit gestures are documented and not blocked.
- Pointer lock is prohibited for ordinary productivity surfaces.
- Keyboard lock is prohibited unless the product has a specialized reviewed use
  case.
- Modal dialogs cannot silently enter fullscreen.
- Losing fullscreen or lock emits a state change.
- Permission or policy denial leaves the UI usable.

## Clean Disk Requirements

Clean Disk should not use pointer lock or keyboard lock.

Possible safe uses:

- fullscreen disk usage visualization;
- presentation mode for report review;
- kiosk read-only dashboard after explicit enablement.

Cleanup confirmation, pairing, permissions, and destructive workflows must never
depend on immersive mode.

## Exit Contract

Every immersive mode exposes:

- exit command id;
- visible exit control;
- keyboard path;
- assistive technology label;
- state announcement on enter and exit;
- recovery if browser or OS exits mode unexpectedly;
- policy that forbids hiding critical warnings.

## Testing Requirements

- Enter request fails without user activation.
- Exit is reachable by keyboard and screen reader.
- Focus remains visible after entering fullscreen.
- Unexpected exit restores layout and focus.
- Denied policy produces recoverable state.
- Pointer lock and keyboard lock are absent from Clean Disk MVP builds.

## Failure Catalog

- Fullscreen starts on page load.
- Pointer lock hides cursor with no visible exit.
- Escape key is captured and user cannot leave.
- Dialog opens behind fullscreen overlay.
- Browser exits fullscreen and app still claims immersive state.
- Cleanup confirmation enters fullscreen to "focus" the user.

## Release Gates

- Immersive APIs are adapter-gated.
- Every immersive request has purpose, exit, and fallback.
- Productivity apps default to no pointer lock and no keyboard lock.
- Conformance tests verify no keyboard trap.

## Summary

Immersive modes are powerful system state. Headless should require explicit
intent, visible exit, policy checks, and no traps before any component can use
them.
