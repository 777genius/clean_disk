# Platform Accessibility API Bridge Standard

## Status

Research and implementation standard for native accessibility API differences
that affect Headless primitives.

## Purpose

Screen readers do not read Flutter widgets directly. They read platform
accessibility trees exposed through macOS Accessibility, Windows UI Automation,
Linux AT-SPI, browser accessibility layers, or mobile equivalents. Headless
must design semantic contracts that can survive these differences.

## Standards And References

- WAI-ARIA APG Patterns:
  https://www.w3.org/WAI/ARIA/apg/patterns/
- Accessible Name and Description Computation 1.2:
  https://www.w3.org/TR/accname-1.2/
- Flutter accessibility:
  https://docs.flutter.dev/ui/accessibility
- Flutter web accessibility:
  https://docs.flutter.dev/ui/accessibility/web-accessibility
- ARIA-AT:
  https://w3c.github.io/aria-at/

## Core Rule

Headless conformance is measured by user-observable behavior and semantic facts,
not by assuming one platform API maps perfectly to another.

## Platform Families

```text
Flutter native macOS -> macOS Accessibility -> VoiceOver
Flutter native Windows -> UI Automation -> Narrator/NVDA/JAWS behavior varies
Flutter native Linux -> AT-SPI -> Orca behavior varies
Flutter web -> browser accessibility tree -> screen reader
Flutter mobile -> Android/iOS accessibility services
```

The same Headless semantic snapshot can produce different spoken output across
these stacks.

## Bridge Gap Categories

Role fidelity:

- role intent may not map exactly;
- fallback label/action can be more reliable than fake role.

State fidelity:

- selected, expanded, checked, disabled, busy, and sorted may have different
  exposure behavior.

Relationship fidelity:

- labelled-by, described-by, controls, owns, and active descendant may not have
  native equivalents in every stack.

Collection fidelity:

- row/column counts and indexes may not be announced consistently;
- virtualized rows need explicit interop tests.

Focus fidelity:

- platform focus, Flutter focus, and screen reader browse cursor can diverge.

Live region fidelity:

- polite announcements can be delayed or dropped;
- alert announcements may interrupt too aggressively;
- repeated messages can be coalesced.

## Adapter Contract

Every platform adapter declares:

```text
role fidelity level
state fidelity level
relationship fidelity level
collection fidelity level
live region fidelity level
known screen-reader gaps
tested runtime versions
```

Fidelity levels:

```text
exact
approximate
fallbackLabel
unsupported
unknown
```

## Fallback Strategy

When a platform cannot expose a semantic fact well:

1. preserve keyboard behavior;
2. preserve visible state;
3. expose concise label/value fallback;
4. expose command alternatives;
5. document limitation;
6. block strong accessibility claim if critical.

Do not silently drop critical facts for Dialog, Menu, TreeGrid, or SplitPane.

## Clean Disk Risk

Clean Disk uses dense TreeGrid and destructive confirmation flows. Therefore:

- dialog semantics and focus restore are release blockers;
- TreeGrid row navigation must be keyboard reliable even if row count
  announcements differ;
- delete confirmation must not rely on color or visual placement only;
- status messages must not reveal raw paths in support evidence.

## Evidence Requirements

Automated:

- platform semantic snapshot where tool support exists;
- Flutter semantics tests;
- web accessibility tree snapshot for web adapter;
- reducer behavior independent from platform.

Manual:

- at least one macOS VoiceOver path;
- at least one Windows NVDA or Narrator path before broad Windows claim;
- Linux Orca marked best-effort unless officially supported;
- browser/screen reader matrix documented.

## Stop Rules

- Do not claim exact ARIA behavior for native Flutter without evidence.
- Do not assume screen reader output from semantic snapshot alone.
- Do not hide platform gaps behind generic "accessible" wording.
- Do not create platform-specific hacks in core Headless.
- Do not let fallback labels contain sensitive product data.
