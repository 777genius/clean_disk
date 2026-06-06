# Platform Accessibility Settings Adapter Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- Flutter accessibility: https://docs.flutter.dev/ui/accessibility
- Flutter `MediaQuery`: https://api.flutter.dev/flutter/widgets/MediaQuery-class.html
- Flutter `AccessibilityFeatures`: https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures-class.html
- Flutter `PlatformDispatcher.accessibilityFeatures`: https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/accessibilityFeatures.html
- MDN media queries for accessibility: https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Media_queries/Using_for_accessibility
- MDN `prefers-reduced-motion`: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion
- MDN `prefers-contrast`: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-contrast
- MDN `prefers-reduced-data`: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-data
- WCAG 1.4.3 Contrast Minimum: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- WCAG 1.4.4 Resize Text: https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- WCAG 2.3.3 Animation from Interactions: https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html

## Problem

Headless components cannot assume a fixed visual, motion, density, contrast, or
assistive setting environment. On Flutter, these facts arrive through
`MediaQuery`, `PlatformDispatcher.accessibilityFeatures`, platform adapters, and
web CSS media queries. If every component reads these signals directly, the
library gets inconsistent behavior and impossible tests.

The public standard needs one normalized accessibility settings adapter.

## Decision Options

1. Per component environment reads - 🎯 3   🛡️ 4   🧠 2, about 80-180 LOC per
   primitive. Fast at first, but creates drift between primitives.
2. Global normalized accessibility settings snapshot - 🎯 9   🛡️ 9   🧠 5,
   about 220-500 LOC. Best default for Headless because it centralizes platform
   quirks and makes tests deterministic.
3. Full reactive policy engine - 🎯 6   🛡️ 8   🧠 8, about 700-1400 LOC. Useful
   later for enterprise policy, but too heavy as the first primitive layer.

Accepted: option 2.

## Accepted Contract

Headless exposes a normalized immutable settings object:

```dart
final class RAccessibilitySettings {
  final bool reduceMotion;
  final bool disableAnimations;
  final bool accessibleNavigation;
  final bool highContrast;
  final bool boldText;
  final bool invertColors;
  final bool reduceTransparency;
  final bool reduceData;
  final double textScaleFactor;
  final RContrastPreference contrastPreference;
  final RColorSchemePreference colorSchemePreference;
  final RPointerPrecision pointerPrecision;
  final RSettingsEvidence evidence;
}
```

The adapter is owned by `headless_foundation`, not by individual primitives.

## Mapping Rules

- Flutter `MediaQuery` is the preferred source for widget tree scoped settings.
- `PlatformDispatcher.accessibilityFeatures` is the fallback for non-widget
  contexts, tests, and service-level state.
- Web CSS media features are optional evidence sources, not the public API.
- Unknown platform facts map to explicit `unknown` evidence, never to false
  confidence.
- A platform setting can tighten behavior but must not remove operability.
- Components consume normalized settings. They do not import `dart:ui` directly
  unless they are the platform adapter.

## Primitive Responsibilities

- Motion primitives reduce duration, disable parallax, and avoid vestibular
  triggers when `reduceMotion` or `disableAnimations` is true.
- Layout primitives preserve text and controls under text scaling and reflow.
- Token resolvers increase contrast and focus ring strength under high
  contrast modes.
- Virtualized collections keep row height policy explicit under text scaling.
- Live-region primitives reduce repeated announcements when accessible
  navigation is enabled.
- Visualization primitives expose non-visual summaries regardless of visual
  theme.

## Non-Responsibilities

- The adapter does not decide product permissions.
- The adapter does not localize strings.
- The adapter does not infer disability categories from settings.
- The adapter does not persist user settings unless an app-level profile asks
  for it.
- The adapter does not hide platform settings from the user.

## Clean Disk Requirements

Clean Disk must use this adapter before rendering:

- dense table rows;
- treemap or disk usage visualizations;
- progress footer motion;
- danger confirmation dialogs;
- compact layout;
- search and filter overlays.

When settings are unknown, Clean Disk defaults to accessible behavior for risky
actions: stronger focus, no time-critical confirmation, and stable layout.

## Evidence Model

Each setting carries evidence:

```dart
enum RAccessibilityEvidenceSource {
  mediaQuery,
  platformDispatcher,
  cssMediaQuery,
  appPreference,
  testOverride,
  unknown,
}

final class RSettingsEvidence {
  final Set<RAccessibilityEvidenceSource> sources;
  final bool isUserDeclared;
  final bool isPlatformDeclared;
  final DateTime? observedAt;
}
```

The renderer may inspect evidence for diagnostics, but behavior should use the
normalized value.

## Testing Requirements

- Golden tests cover light, dark, high contrast, text scale 2.0, reduce motion,
  and inverted colors where supported.
- Widget tests override `PlatformDispatcher.accessibilityFeaturesTestValue`
  through supported Flutter testing APIs.
- Web adapter tests stub CSS media query matches without requiring a real
  browser.
- Snapshot tests include the normalized settings object in failure metadata.
- Components must pass with all settings unknown.

## Failure Catalog

- Component reads `MediaQuery` directly and ignores test override.
- High contrast changes color but removes selected state distinction.
- Text scale expands row labels but clips action buttons.
- Reduce motion disables progress status updates instead of only animation.
- Invert colors is treated as dark theme.
- CSS media query support is assumed on every browser.
- App preference overrides platform preference without explicit user consent.

## Release Gates

- No primitive may add a new direct platform setting read without updating this
  adapter.
- Public docs must list which platform settings are supported, unknown, and
  emulated.
- A conformance fixture must run every major primitive under at least six
  settings profiles.
- Unknown settings must not block rendering.

## Summary

The Headless standard gets one accessibility settings source of truth. Primitives
consume normalized policy, renderers apply visual choices, and platform quirks
stay in adapters.
