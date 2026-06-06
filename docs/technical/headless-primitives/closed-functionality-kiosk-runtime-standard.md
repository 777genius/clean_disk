# Closed Functionality And Kiosk Runtime Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WCAG2ICT: https://w3c.github.io/wcag2ict/
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.2.1 Timing Adjustable: https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 3.3.1 Error Identification: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

## Problem

Some deployments are closed functionality environments: kiosk mode, appliance
mode, managed devices, embedded displays, restricted enterprise desktops, remote
VDI shells, or platforms where users cannot install or run their preferred
assistive technology. WCAG2ICT treats these contexts differently from ordinary
open web usage because the software may need built-in accessible operation.

Headless is a public UI foundation. It should not assume users can always add a
screen reader, switch tool, custom keyboard remapper, browser extension, or
automation helper.

## Decision Options

1. Ignore closed functionality until an app needs kiosk mode - 🎯 4   🛡️ 3
   🧠 1, about 0-40 LOC. Too risky for public primitives.
2. Add a closed runtime profile and built-in fallback requirements - 🎯 8
   🛡️ 8   🧠 6, about 350-900 LOC. Strong enough without overbuilding.
3. Make all primitives self-voicing and self-scanning - 🎯 3   🛡️ 6   🧠 10,
   about 3000-7000 LOC. Not realistic as the base standard.

Accepted: option 2.

## Accepted Contract

Headless defines a runtime accessibility openness profile:

```dart
enum RAssistiveRuntimeOpenness {
  open,
  managed,
  closed,
  unknown,
}

final class RClosedRuntimeProfile {
  final RAssistiveRuntimeOpenness openness;
  final bool externalScreenReaderLikelyAvailable;
  final bool externalSwitchLikelyAvailable;
  final bool externalVoiceControlLikelyAvailable;
  final bool keyboardRemappingAvailable;
  final bool browserExtensionsAvailable;
  final bool canInstallAssistiveTechnology;
}
```

Apps declare or detect the profile. Primitives adapt only through public
settings and capability contracts.

## Built-In Fallback Requirements

In closed or managed runtime profiles:

- every workflow has a keyboard path;
- every timed step can be paused, extended, or made non-time-critical;
- status messages have an in-app textual representation;
- errors include visible recovery instructions;
- command discovery is available without external documentation;
- focus order is visible and predictable;
- destructive actions have explicit review and confirmation;
- scan and progress states remain readable without a screen reader.

## Clean Disk Requirements

Clean Disk MVP is not a kiosk app, but the architecture must not block future
closed deployments:

- headless server UI in a remote admin shell;
- managed enterprise desktop;
- read-only support mode;
- locked-down cleanup review station;
- lab benchmark environment without external AT.

For these modes, the UI must still expose readable status, keyboard operation,
and confirmation safety.

## Runtime Declarations

The app composition root owns runtime declaration:

```dart
final class RRuntimeAccessibilityDeclaration {
  final RClosedRuntimeProfile profile;
  final Set<RBuiltInAccessFeature> builtInFeatures;
  final Set<RKnownLimitation> limitations;
  final String? evidenceReportId;
}
```

The declaration is shown in diagnostics and conformance reports. It is not
hidden in theme state.

## What Headless Does Not Promise

- Headless does not certify legal compliance by itself.
- Headless does not emulate a full screen reader.
- Headless does not guarantee every platform kiosk shell exposes the same APIs.
- Headless does not bypass operating system restrictions.
- Headless does not turn a visual-only renderer into an accessible renderer
  without semantic adapters.

## Testing Requirements

- Run conformance scenarios with external AT features marked unavailable.
- Verify no workflow depends only on a screen reader announcement.
- Verify command discovery is reachable by keyboard.
- Verify status messages are visible and not only live-region events.
- Verify destructive confirmation works without pointer or speech input.
- Verify reset and escape paths exist from overlays.

## Failure Catalog

- The only explanation of a scan error is a transient toast.
- A kiosk user cannot open shortcut help.
- A managed browser blocks clipboard or file APIs and the app has no fallback.
- A confirmation dialog relies on spoken screen reader text that is not visible.
- A remote desktop hides OS notifications and the app treats the workflow as
  complete.
- A locked-down environment disables browser extensions that the component
  assumed for testing.

## Release Gates

- Every public primitive declares whether it works in open, managed, closed, or
  unknown runtime profiles.
- Every unsupported closed-runtime behavior must have an explicit limitation
  code.
- Closed-runtime fixtures must not require external AT installation.
- Docs must separate legal conformance claims from technical support claims.

## Summary

Closed functionality changes the accessibility contract. Headless should expose
runtime openness explicitly and provide built-in fallback paths where external
assistive technology cannot be assumed.
