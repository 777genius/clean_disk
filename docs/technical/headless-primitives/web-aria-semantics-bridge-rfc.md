# Headless Web ARIA Semantics Bridge RFC

## Status

Future adapter direction. Research required before implementation.

## Problem

Flutter exposes accessibility through its Semantics tree. On web, Flutter
translates Semantics into an accessible HTML DOM. Some complex ARIA patterns,
especially `treegrid`, `grid`, live regions, and focus management through
`aria-activedescendant`, may not map perfectly through Flutter's generic
Semantics APIs.

Headless needs platform-neutral semantic contracts now, and a possible web ARIA
bridge later if Flutter's output is insufficient.

## Standards And References

- Flutter web accessibility:
  https://docs.flutter.dev/ui/accessibility/web-accessibility
- Flutter assistive technologies:
  https://docs.flutter.dev/ui/accessibility/assistive-technologies
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN ARIA roles:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles

## Accepted Direction

Do not expose ARIA strings as core Headless API.

Expose semantic intents:

```text
HeadlessSemanticRole
HeadlessSemanticState
HeadlessSemanticRelationship
HeadlessLiveRegionIntent
HeadlessFocusIntent
```

Then map them:

```text
FlutterSemanticsAdapter
WebAriaSemanticsBridge (future)
```

## Top Options

1. Platform-neutral semantic intents now, optional web bridge later - 🎯 9
   🛡️ 8   🧠 8, roughly 600-1200 LOC now, 1200-3000 LOC later.

   Best architecture. Keeps Headless portable and allows precise web fixes.

2. Put ARIA-like fields directly in every component - 🎯 5   🛡️ 5   🧠 5,
   roughly 400-1000 LOC.

   Leaks web concepts into Flutter-native components and can be wrong on
   mobile/desktop.

3. Trust Flutter Semantics completely forever - 🎯 5   🛡️ 6   🧠 3,
   roughly 100-300 LOC.

   Maybe enough for many widgets, but risky for complex treegrid/live-region
   behavior.

Accepted: option 1.

## What To Measure Before Implementing Bridge

For Flutter web, test with:

- VoiceOver + Safari;
- VoiceOver + Chrome;
- NVDA + Firefox;
- NVDA + Chrome;
- keyboard-only without screen reader;
- browser accessibility tree inspection.

Scenarios:

- TreeGrid rows-first focus;
- TreeGrid cells-first focus;
- virtualized row count and row indexes;
- sorted header;
- tooltip described-by behavior;
- status polite announcement;
- alert/assertive announcement;
- dialog modal focus trap;
- context menu focus restore.

## Semantic Intent Shape

```text
HeadlessSemanticNode
  id
  role
  label
  description
  value
  index
  count
  level
  selected
  expanded
  disabled
  readonly
  focused
  liveRegion
  relationships
```

This is not a replacement for Flutter Semantics. It is an intermediate
component contract.

## Bridge Rules

- bridge is optional and web-only;
- default path remains Flutter Semantics;
- bridge must not duplicate interactive DOM that conflicts with Flutter;
- bridge must not expose raw product data accidentally;
- bridge must be tested per browser/screen reader pair;
- bridge can fail closed by disabling enhanced ARIA and using Flutter
  Semantics.

## Clean Disk Risk

Clean Disk web UI may be daemon-served and dense. If Flutter web semantics for
TreeGrid are weak, keyboard users and screen-reader users may struggle with the
central table. We should measure early with a synthetic TreeGrid fixture before
shipping web as a serious UI surface.

## Stop Rules

- Do not promise full ARIA treegrid parity before measurement.
- Do not expose browser DOM IDs as Headless identity.
- Do not log semantic labels containing raw paths.
- Do not build a web-only API that makes desktop/mobile worse.
