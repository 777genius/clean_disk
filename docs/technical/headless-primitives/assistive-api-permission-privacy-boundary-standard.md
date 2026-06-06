# Assistive API Permission And Privacy Boundary Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility
- Android `AccessibilityService`: https://developer.android.com/reference/android/accessibilityservice/AccessibilityService
- Apple Privacy and Security: https://support.apple.com/guide/security/welcome/web
- MDN Permissions API: https://developer.mozilla.org/en-US/docs/Web/API/Permissions_API
- MDN Permissions Policy: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Permissions_Policy
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html

## Problem

Accessibility APIs can expose powerful information: names, roles, focused
elements, typed text, window structure, screenshots, gestures, and sometimes
global input. Public Headless primitives need accessibility API integration, but
they must not normalize broad OS permissions, keylogging-style behavior, hidden
automation, or privacy-invasive diagnostics.

The standard needs a hard boundary between semantic output and privileged
assistive API access.

## Decision Options

1. Leave permission decisions to each adapter - 🎯 4   🛡️ 4   🧠 2, about
   0-120 LOC. Fast, but unsafe for public ecosystem growth.
2. Add a capability and privacy classification boundary - 🎯 9   🛡️ 10
   🧠 6, about 350-900 LOC. Best fit for Headless and Clean Disk.
3. Ban all privileged assistive API integrations - 🎯 5   🛡️ 8   🧠 3, about
   40-100 LOC. Safe but blocks valid native accessibility adapters.

Accepted: option 2.

## Accepted Contract

Headless classifies accessibility-adjacent capabilities:

```dart
enum RAssistiveCapabilityClass {
  semanticOutput,
  localFocusObservation,
  appWindowObservation,
  globalWindowObservation,
  inputSynthesis,
  screenshotCapture,
  keyInputObservation,
}

final class RAssistiveCapabilityGrant {
  final RAssistiveCapabilityClass capabilityClass;
  final RCapabilityScope scope;
  final bool requiresOsPermission;
  final bool requiresUserConsent;
  final bool allowedInProduction;
  final RPrivacyDataClass dataClass;
}
```

Semantic output is the default. Anything beyond semantic output requires an
explicit adapter, scope, and policy.

## Boundary Rules

- Headless primitives emit semantics. They do not request OS accessibility
  permissions directly.
- Platform adapters may request permissions only through app-owned capability
  flows.
- Global key input observation is prohibited for primitive behavior.
- Input synthesis is allowed only for explicit test drivers or declared
  automation adapters, not for user-facing hidden behavior.
- Diagnostics never include raw typed text, raw paths, raw clipboard content, or
  full accessibility trees by default.
- Permission failures degrade to visible status and keyboard operation.
- A renderer cannot silently upgrade itself to a privileged adapter.

## Clean Disk Requirements

Clean Disk must avoid broad OS Accessibility or Input Monitoring permissions
unless a separately reviewed feature truly requires them.

Expected MVP permissions:

- semantic output through Flutter semantics;
- local widget focus observation;
- no global input monitoring;
- no screenshot capture for production diagnostics;
- no hidden automation bridge;
- no raw filesystem paths in accessibility telemetry.

The scanner permission model is separate from UI accessibility permissions.
Full Disk Access does not authorize accessibility API access.

## Privacy Data Classes

Accessibility evidence is classified:

```text
public component metadata:
  role, state, supported action list

local interaction metadata:
  focused semantic id, command id, timing bucket

sensitive user content:
  typed text, search text, path, file name, clipboard, screenshot

privileged environment data:
  other app windows, global focus, global keystrokes
```

Only public component metadata and redacted local interaction metadata are
allowed in normal conformance reports.

## Adapter Review Checklist

An adapter that touches privileged APIs must document:

- exact platform API;
- exact permission prompt;
- whether data crosses process or network boundaries;
- whether it can observe other apps;
- whether it can synthesize input;
- retention policy;
- redaction policy;
- user-facing disable switch;
- test-only versus production status.

## Testing Requirements

- Permission denied tests for every privileged adapter.
- Privacy snapshot tests for diagnostics and conformance reports.
- Static lint that primitives do not import privileged platform permission APIs.
- Test-driver adapters are disabled in production builds.
- Support bundle export verifies redaction of accessibility evidence.

## Failure Catalog

- A component asks for OS Accessibility permission to fix a focus bug.
- Test automation APIs ship enabled in release builds.
- Diagnostics capture the full accessibility tree including file paths.
- A renderer observes global focus to implement local hover behavior.
- Permission denial makes the UI unusable instead of degraded.
- A third-party adapter synthesizes clicks without command provenance.

## Release Gates

- Every privileged adapter requires security and privacy review.
- Every capability has a scope and data class.
- Production builds fail if test-only input synthesis is enabled.
- Public docs list accessibility-related permissions separately from product
  permissions.

## Summary

Headless accessibility should be privacy-preserving by default. Primitives emit
semantics; privileged assistive API access lives behind explicit, scoped,
audited adapters.
