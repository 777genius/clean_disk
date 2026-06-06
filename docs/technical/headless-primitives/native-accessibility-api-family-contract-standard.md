# Native Accessibility API Family Contract Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- Apple Accessibility Inspector: https://developer.apple.com/documentation/accessibility/accessibility-inspector
- Apple integrating accessibility: https://developer.apple.com/documentation/Accessibility/integrating_accessibility_into_your_app
- Microsoft UI Automation control patterns: https://learn.microsoft.com/en-us/windows/apps/design/accessibility/control-patterns-and-interfaces
- Microsoft UI Automation testing: https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-usefortesting
- GNOME accessibility guidelines: https://developer.gnome.org/documentation/guidelines/accessibility.html
- GNOME AT-SPI Accessible API: https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/class.Accessible.html
- Android accessibility testing: https://developer.android.com/guide/topics/ui/accessibility/views/testing-views

## Problem

ARIA, Flutter Semantics, macOS AX, Windows UI Automation, Linux AT-SPI, Android
Accessibility, and iOS accessibility all expose similar ideas through different
capabilities. A role/action mapping table is not enough. Headless needs a family
contract that records which semantics are native, emulated, lossy, unsupported,
or dangerous on each accessibility API family.

## Decision Options

1. Keep one cross-platform semantic model and hope adapters map it - 🎯 5
   🛡️ 5   🧠 3, about 100-250 LOC. Simple but hides loss.
2. Add per-family capability contracts - 🎯 9   🛡️ 9   🧠 7, about 500-1100
   LOC. Best fit for public Headless.
3. Build separate component APIs per platform - 🎯 3   🛡️ 6   🧠 10, about
   2500-6000 LOC. Too fragmented.

Accepted: option 2.

## Accepted Contract

Each platform adapter publishes a family contract:

```dart
final class RNativeAccessibilityFamilyContract {
  final RPlatformFamily family;
  final String platformVersionRange;
  final Set<RSemanticFeature> nativeFeatures;
  final Set<RSemanticFeature> emulatedFeatures;
  final Set<RSemanticFeature> lossyFeatures;
  final Set<RSemanticFeature> unsupportedFeatures;
  final Set<RInspectionTool> supportedInspectors;
  final Set<RKnownInteropIssue> knownIssues;
}
```

The Headless core consumes this as evidence. Components do not branch on OS
details directly.

## Family Rules

- macOS and iOS adapters document AX role, subrole, action, value, title, help,
  and focused element behavior where available.
- Windows adapters document UIA control type, patterns, properties, live region
  support, and events.
- Linux adapters document AT-SPI role, state set, relations, actions, table,
  text, value, and cache behavior.
- Android adapters document content description, state description, collection
  info, actions, traversal, and Accessibility Scanner findings.
- Web adapters document ARIA, HTML AAM, browser tree behavior, and browser
  version constraints.
- Flutter adapters document which Flutter Semantics facts survive to each
  native family.

## Clean Disk Requirements

Clean Disk must care about:

- TreeGrid row and cell semantics;
- progress and status;
- modal confirmation;
- details inspector;
- cleanup queue;
- split panes;
- search and filter controls;
- large virtualized collections.

Any platform where these semantics are lossy must show a degraded support state
in the internal release checklist.

## Loss Classification

Semantic loss is classified:

```text
none:
  platform exposes the intended role, state, and action

minor:
  wording or role naming differs but workflow remains clear

major:
  action or state needs emulation or is hard to discover

blocking:
  workflow cannot be completed with the supported AT stack
```

Major and blocking losses require explicit release review.

## Testing Requirements

- Run at least one inspector per platform family.
- Snapshot role, name, state, value, action, relation, and bounds.
- Compare Headless semantic intent with native exposed facts.
- Record AT transcript for critical workflows.
- Test platform settings: high contrast, reduce motion, text scaling, and
  screen reader enabled where available.

## Failure Catalog

- Flutter Semantics exposes a state that Windows UIA does not map.
- AT-SPI cache returns stale virtualized row data.
- Android collection info omits row count.
- macOS AX action name is generic and hides destructive intent.
- Browser accessibility tree differs between Chrome and Safari.
- A support matrix says "supported" but adapter only emulates a role visually.

## Release Gates

- Every shipping adapter has a family contract.
- Every major primitive has a native exposure snapshot for claimed platforms.
- Known lossy mappings are public in engineering docs.
- Unsupported features fail closed for risky commands.

## Summary

Cross-platform accessibility needs explicit native family contracts. Headless
keeps one semantic API, but adapters must declare what survives, what is lossy,
and what is unsupported.
