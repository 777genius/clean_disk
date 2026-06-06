# Haptic Vibration Feedback Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN user activation: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/User_activation
- MDN GamepadHapticActuator: https://developer.mozilla.org/en-US/docs/Web/API/GamepadHapticActuator
- MDN Vibration API: https://developer.mozilla.org/en-US/docs/Web/API/Vibration_API
- Apple Human Interface Guidelines haptics: https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- WCAG 1.4.2 Audio Control: https://www.w3.org/WAI/WCAG22/Understanding/audio-control.html
- WCAG 2.2.2 Pause, Stop, Hide: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html
- WCAG 2.3.3 Animation from Interactions: https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html

## Problem

Haptics and vibration can help confirm touch, scanning, gamepad, and mobile
interactions. They can also be unavailable, distracting, physically
uncomfortable, battery-expensive, or privacy-relevant. A UI primitive must not
make haptic feedback the only way to understand success, failure, warning, or
danger.

Headless needs a haptic feedback contract that treats tactile output as optional
emphasis, not workflow truth.

## Decision Options

1. Leave haptics to each renderer - 🎯 4   🛡️ 4   🧠 2, about 0-80 LOC.
   Simple, but inconsistent and hard to disable.
2. Add haptic intent adapter with policy and fallback - 🎯 9   🛡️ 9   🧠 5,
   about 250-650 LOC. Best fit.
3. Build detailed platform haptic pattern libraries - 🎯 4   🛡️ 6   🧠 9,
   about 1500-3500 LOC. Too platform-specific for Headless core.

Accepted: option 2.

## Accepted Contract

Headless emits haptic intents:

```dart
final class RHapticFeedbackIntent {
  final RHapticKind kind;
  final RFeedbackPurpose purpose;
  final RFeedbackSeverity severity;
  final bool requiresUserActivation;
  final bool isOptionalEmphasis;
  final RPrivacyDataClass privacyClass;
}
```

Adapters map intents to platform haptics, web vibration, gamepad haptics, or
no-op.

## Rules

- Haptics never carry exclusive meaning.
- Every haptic event has visible and semantic status equivalent.
- Haptics are disabled by user preference, reduced motion-like profiles, quiet
  mode, or unsupported platform.
- Haptics are never emitted on render or background polling.
- Destructive action confirmation cannot rely on vibration.
- Repeated progress haptics are rate-limited.
- Device-specific patterns stay in adapters.
- Haptic failure does not fail the command.

## Clean Disk Requirements

Clean Disk may use haptics only as optional emphasis for:

- scan started;
- scan paused;
- cleanup added to queue;
- cleanup completed;
- warning requires review.

It must not vibrate for every scanned file, every progress tick, every skipped
item, or every row selection.

## Feedback Classes

```text
selection:
  small optional acknowledgement

success:
  optional confirmation with visible status

warning:
  optional attention request, never the only warning

error:
  optional emphasis with visible error

danger:
  prohibited as sole confirmation
```

## Testing Requirements

- Haptics disabled profile produces no haptic adapter calls.
- Unsupported adapter no-ops without changing command result.
- Rate-limit prevents repeated progress vibration.
- Every haptic intent maps to visible status.
- User activation requirements are respected for browser APIs.
- Sensitive command names are not encoded into haptic telemetry.

## Failure Catalog

- Vibration is the only indication a delete target was queued.
- Progress emits haptics every 100 ms.
- Haptic feedback fires during background scan with app hidden.
- Unsupported browser throws and breaks the command.
- User disables haptics but renderer still calls native feedback.
- Haptic pattern is used as hidden product analytics.

## Release Gates

- Haptic output is adapter-gated.
- Haptic intents require feedback purpose and fallback status.
- User preference disables all optional haptics.
- Clean Disk MVP ships with haptics off unless explicitly enabled later.

## Summary

Haptics are optional feedback, not semantic truth. Headless should standardize
haptic intents, fallbacks, rate limits, and user control.
