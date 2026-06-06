# Sensor Motion And Orientation Permission Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WCAG 2.5.4 Motion Actuation: https://www.w3.org/WAI/WCAG22/Understanding/motion-actuation.html
- MDN detecting device orientation: https://developer.mozilla.org/en-US/docs/Web/API/Device_orientation_events/Detecting_device_orientation
- MDN `devicemotion` event: https://developer.mozilla.org/en-US/docs/Web/API/Window/devicemotion_event
- MDN managing screen orientation: https://developer.mozilla.org/en-US/docs/Web/API/CSS_Object_Model/Managing_screen_orientation
- MDN `ScreenOrientation.lock()`: https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation/lock
- MDN Permissions API: https://developer.mozilla.org/en-US/docs/Web/API/Permissions_API
- MDN secure contexts: https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html

## Problem

Motion sensors, orientation sensors, accelerometers, screen orientation locks,
and device gestures can create inaccessible or privacy-sensitive interactions.
Users may be unable to shake, tilt, rotate, or hold a device. Browsers may
require permission. Sensor data can reveal environment or behavior.

Headless needs a motion and sensor permission boundary.

## Decision Options

1. Ban motion sensor use in Headless - 🎯 7   🛡️ 9   🧠 1, about 0-40 LOC.
   Safe for Clean Disk MVP, too restrictive for public Headless.
2. Add sensor capability and motion-actuation policy - 🎯 9   🛡️ 10   🧠 6,
   about 350-850 LOC. Best fit.
3. Build full sensor abstraction library - 🎯 3   🛡️ 5   🧠 10, about
   2500-6000 LOC. Not Headless core responsibility.

Accepted: option 2.

## Accepted Contract

Headless models sensor capabilities:

```dart
final class RSensorMotionCapability {
  final RSensorKind kind;
  final RPermissionState permissionState;
  final bool requiresSecureContext;
  final bool requiresUserActivation;
  final bool canTriggerCommands;
  final bool hasNonMotionAlternative;
  final RPrivacyRisk privacyRisk;
}
```

Primitives consume capability, not raw sensor events.

## Rules

- Motion-based functionality always has non-motion UI alternative unless motion
  is essential.
- Sensor prompts are never triggered on render.
- Sensor data does not execute destructive commands directly.
- Orientation lock requires explicit purpose and exit path.
- Sensor readings are not logged raw by default.
- Motion actuation can be disabled.
- Browser denied state remains recoverable.
- Sensor capability is not used as fingerprinting data.

## Clean Disk Requirements

Clean Disk has no current need for motion sensors.

If future visualizations or kiosk modes use sensors:

- tilt cannot be the only way to navigate disk map;
- shake cannot clear queue;
- rotate cannot confirm cleanup;
- orientation lock cannot hide confirmation actions;
- sensor permission denial leaves app fully usable.

## Sensor Risk Classes

```text
layoutHint:
  orientation or viewport hints

optionalControl:
  secondary navigation or visualization input

primaryControl:
  important workflow input, requires alternative

dangerousControl:
  prohibited for destructive actions

privacySensitive:
  raw motion or environment-derived data
```

## Testing Requirements

- Sensor denied path remains usable.
- Motion alternative exists for every motion command.
- Orientation lock denial has fallback.
- Raw sensor data not present in logs.
- Motion-triggered input cannot activate destructive command.
- Secure-context and permission requirements are represented.

## Failure Catalog

- Shake clears cleanup queue.
- Tilt is the only way to pan treemap.
- Sensor prompt appears on app load.
- Orientation lock hides dialog buttons.
- Raw motion data appears in telemetry.
- Denied permission disables unrelated scan UI.

## Release Gates

- Sensor use requires capability adapter and privacy review.
- Motion actuation has non-motion alternative.
- Destructive commands cannot be sensor-triggered.
- Clean Disk MVP declares sensor capability unsupported and unnecessary.

## Summary

Motion sensors are optional, permissioned, and privacy-sensitive. Headless should
gate them through capability, alternatives, and motion-actuation safety.
