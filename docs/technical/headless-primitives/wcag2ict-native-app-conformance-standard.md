# WCAG2ICT Native App Conformance Standard

## Status

Accepted as a Headless conformance standard. Not implemented yet.

## Source Standards

- WCAG2ICT: https://w3c.github.io/wcag2ict/
- WCAG 2.2 Conformance: https://www.w3.org/WAI/WCAG22/Understanding/conformance.html
- WCAG 2.2: https://www.w3.org/TR/wcag-22/
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility
- Flutter web accessibility: https://docs.flutter.dev/ui/accessibility/web-accessibility
- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/

## Scope

This standard defines how Headless applies WCAG-oriented accessibility
requirements to non-web Flutter apps, Flutter web, and native desktop adapters.

It applies to:

- Flutter desktop primitives;
- Flutter mobile primitives;
- Flutter web adapters;
- design-system facades;
- Clean Disk desktop and daemon-served web UI;
- public Headless conformance claims.

It does not turn WCAG into a legal opinion. It defines engineering traceability
from user needs to behavior and evidence.

## Decision Options

Option A: Treat WCAG as web-only - 🎯 3   🛡️ 3   🧠 2, about 100-250 LOC.

- Simple.
- Native Flutter claims become vague and inconsistent.

Option B: Copy WCAG success criteria directly to native widgets - 🎯 5
🛡️ 5   🧠 5, about 400-900 LOC.

- Better coverage.
- Some web terms do not map cleanly to non-web software.

Option C: Maintain a WCAG2ICT profile per primitive and adapter - 🎯 9
🛡️ 9   🧠 7, about 900-1800 LOC.

- Accepted direction.
- Matches W3C guidance for non-web ICT.
- Keeps web, desktop, and mobile evidence comparable without pretending they
  are identical.

## Accepted Direction

Headless should define `Wcag2IctConformanceProfile`.

Profile fields:

- primitive id;
- adapter id;
- WCAG success criterion;
- WCAG2ICT interpretation;
- user need;
- applicability;
- evidence requirement;
- known limitations;
- release gate;
- public claim wording.

## Applicability Classes

Classes:

- `appliesDirectly`: requirement applies without meaningful translation.
- `appliesWithTermSubstitution`: web terms map to non-web software terms.
- `appliesWithPlatformEvidence`: behavior depends on native accessibility API.
- `notApplicable`: requirement does not apply to this primitive.
- `unsupported`: primitive cannot meet requirement yet.
- `notReliedUpon`: feature exists, but is not used to satisfy conformance.

Every `notApplicable`, `unsupported`, and `notReliedUpon` entry requires a
reason and review date.

## Web Terms To Native Terms

Headless should map terms explicitly:

- web page -> route, window, view, or screen;
- page title -> route title, window title, or top-level heading;
- link -> link-like command or navigable affordance;
- form field -> editable input control;
- focus indicator -> platform focus, logical focus, and visual focus;
- status message -> non-focus-changing status update;
- user agent -> app runtime, browser, OS, or accessibility bridge.

Do not hide term substitutions inside prose. They belong in machine-readable
profile entries.

## Flutter Adapter Rules

Flutter native:

- evidence starts from Flutter semantics and keyboard behavior;
- platform output must be sampled for major claims;
- semantics tree alone is not proof of spoken output.

Flutter web:

- evidence includes Flutter semantics and browser accessibility tree where
  available;
- web ARIA adapter claims must specify browser and screen reader matrix.

Design system:

- exposes conformance profiles by component facade;
- does not invent separate accessibility rules outside Headless.

## Clean Disk Requirements

Clean Disk needs WCAG2ICT profiles for:

- TreeTable;
- details inspector;
- cleanup queue;
- destructive confirmation dialog;
- progress/status footer;
- search/filter/sort surface;
- disk usage map view;
- settings and permission repair flows.

MVP rule:

- scan-only UI can ship with documented non-destructive gaps;
- cleanup UI cannot ship with stale focus, confirmation, or status-message
  gaps.

## API Shape Sketch

```text
Wcag2IctConformanceProfile
  primitiveId
  adapterId
  platformFamily
  successCriterionId
  applicability
  interpretation
  evidenceRequired
  evidenceAvailable
  claimImpact
  knownLimitations
```

## Conformance Scenarios

Required scenarios:

- dialog focus is trapped and returned on web and desktop;
- TreeGrid has keyboard navigation and visible focus in desktop window;
- route title or heading equivalent is exposed in Flutter web;
- status update is announced or exposed without moving focus;
- dense table remains usable at text scaling and high contrast;
- shortcut help is discoverable without relying on hover.

## Failure Catalog

Failures:

- claim says WCAG AA but native desktop adapter has no evidence;
- web terms copied into native docs without interpretation;
- non-web screen lacks route/window name;
- status change is visible only;
- platform screen reader output contradicts semantics snapshot;
- `notApplicable` is used to avoid hard work.

## Release Gates

Release gate:

- every public primitive has at least one WCAG2ICT profile;
- every cleanup-critical primitive has desktop evidence;
- unknown applicability blocks strong conformance claims;
- profiles are versioned with primitive API changes;
- public docs show known limitations in user-readable language.

