# Gamepad And Remote Input Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN Gamepad API: https://developer.mozilla.org/en-US/docs/Web/API/Gamepad_API
- MDN Gamepad interface: https://developer.mozilla.org/en-US/docs/Web/API/Gamepad
- W3C Gamepad specification: https://www.w3.org/TR/gamepad/
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.5.1 Pointer Gestures: https://www.w3.org/WAI/WCAG22/Understanding/pointer-gestures.html
- WCAG 2.5.2 Pointer Cancellation: https://www.w3.org/WAI/WCAG22/Understanding/pointer-cancellation.html
- WCAG 2.5.5 Target Size: https://www.w3.org/WAI/WCAG22/Understanding/target-size.html

## Problem

Gamepads and remotes expose buttons, axes, repeats, dead zones, vendor mappings,
and connection lifecycle. They can be useful for kiosks, TV surfaces, couch
interfaces, and some accessibility setups. They can also accidentally trigger
dangerous commands if treated as keyboard shortcuts without provenance.

Headless needs an input adapter contract, not hardcoded gamepad behavior.

## Decision Options

1. Do not support gamepad or remote input - 🎯 6   🛡️ 8   🧠 1, about 0-40
   LOC. Fine for Clean Disk MVP, weak for public Headless.
2. Add optional input device adapter mapping to commands - 🎯 8   🛡️ 9
   🧠 6, about 400-950 LOC. Best baseline.
3. Build complete game UI navigation - 🎯 3   🛡️ 5   🧠 10, about 2500-6000
   LOC. Not a general UI kit responsibility.

Accepted: option 2.

## Accepted Contract

Input adapters publish normalized events:

```dart
final class RExternalInputEvent {
  final RInputDeviceKind deviceKind;
  final String? deviceIdHash;
  final RInputControl control;
  final RInputAction action;
  final double value;
  final bool isRepeat;
  final RInputProvenance provenance;
}
```

Commands consume normalized input through the command routing layer.

## Rules

- Gamepad and remote input is opt-in.
- Button mapping is visible and remappable where product supports it.
- Repeats are rate-limited.
- Analog axes use dead zones and hysteresis.
- Disconnection is a visible degraded state.
- Destructive commands require explicit confirmation and are not bound to a
  single accidental button press.
- Gamepad input does not bypass focus, selection, or command provenance.
- Keyboard support remains the baseline.

## Clean Disk Requirements

Clean Disk does not need gamepad support for MVP. If enabled later:

- D-pad moves focus through spatial navigation;
- primary button activates focused safe command;
- back button closes overlay or returns to prior region;
- destructive cleanup requires confirmation with focus visible;
- scan progress can be monitored read-only.

No gamepad shortcut may move items to Trash directly.

## Device Capability Model

```text
connected:
  device observed and usable

mappingKnown:
  browser or platform reports standard mapping

mappingUnknown:
  adapter must use safe defaults or require configuration

unstable:
  axes or buttons produce noisy values

disconnected:
  focus and command state remain stable
```

## Testing Requirements

- Synthetic gamepad events map to commands deterministically.
- Unknown mapping does not enable destructive commands.
- Axis noise does not move focus repeatedly.
- Disconnect during dialog leaves keyboard focus usable.
- Repeat rate is bounded.
- Remapping UI remains accessible by keyboard and screen reader.

## Failure Catalog

- Controller reconnect activates focused delete button.
- Axis drift scrolls the tree forever.
- Button mapping differs by browser and command labels are wrong.
- A disconnected device leaves UI in "pressed" state.
- Gamepad shortcut bypasses confirmation.
- Device id is logged as stable fingerprint.

## Release Gates

- Gamepad support is adapter-gated and off by default for productivity apps.
- Unknown mappings fail closed.
- Device ids are privacy-protected.
- Destructive command bindings require explicit product review.

## Summary

Gamepad and remote support should be an input adapter, not a hidden shortcut
layer. Headless maps device events to commands through provenance and safety
rules.
