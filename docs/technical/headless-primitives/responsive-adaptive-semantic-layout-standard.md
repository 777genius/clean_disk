# Responsive Adaptive Semantic Layout Standard

## Status

Implementation standard for responsive layouts, adaptive density, text scaling,
semantic continuity, and mobile/desktop differences.

## Purpose

Headless primitives must work in desktop-size dense apps and compact windows.
The visual layout may change, but semantic identity, keyboard behavior, focus
restore, and command authority must remain coherent.

## Standards And References

- WCAG 2.2:
  https://www.w3.org/TR/wcag-22/
- W3C WCAG 2.2 new criteria:
  https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/
- MDN accessibility media queries:
  https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Media_queries/Using_for_accessibility
- MDN `prefers-color-scheme`:
  https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme
- Flutter accessibility:
  https://docs.flutter.dev/ui/accessibility
- Flutter `MediaQuery`:
  https://api.flutter.dev/flutter/widgets/MediaQuery-class.html

## Core Rule

Responsive layout can move or hide visuals, but must not change command
identity, semantic meaning, or safety authority.

```text
same component state
  -> different layout adapter
  -> same logical commands and semantic facts
```

## Adaptive Inputs

Layout adapters should consider:

- window size;
- platform;
- pointer kind;
- text scale;
- high contrast;
- reduced motion;
- accessible navigation;
- brightness;
- locale direction;
- density preference;
- safe areas and system insets.

## Semantic Continuity

When layout changes:

- focused logical key remains;
- selection remains;
- expanded state remains;
- open overlay closes or repositions by policy;
- hidden controls remain reachable through menu or details path;
- command ids remain stable;
- semantic labels remain equivalent.

If a control disappears visually, an equivalent command path must exist.

## Compact TreeGrid Rules

Compact layout may:

- hide low-priority columns;
- move details below table;
- collapse sidebar;
- move actions into row/context menu;
- reduce density within token limits.

Compact layout must not:

- hide critical warning state;
- remove keyboard path to row actions;
- remove selected/queued state;
- remove details required before destructive confirmation;
- change sort/filter semantics silently.

## Text Scaling Rules

Text scaling can increase layout pressure. The component should:

- allow row height growth or controlled multiline policy;
- preserve focus indicator;
- use ellipsis only when full value is available elsewhere;
- keep icon-only action labels;
- prevent overlap;
- test high text scale fixtures.

Do not globally disable text scaling for real text. Only decorative icon fonts
or fixed symbols may opt out.

## Reflow And Two-Dimensional Data

Data grids may require horizontal scrolling because two-dimensional layout can
be meaningful. Still:

- horizontal scroll region must be keyboard reachable;
- sticky columns/headers must not obscure focus;
- compact alternative should show important row facts;
- details view should provide full hidden facts;
- screen reader path should not depend on visual horizontal scroll alone.

## Touch And Mobile Screen Reader Rules

Touch layouts need:

- larger hit targets;
- long-press alternative to context menu where platform supports it;
- explicit overflow action button;
- no hover-only information;
- focus/announcement path for screen reader gestures;
- no drag-only operations.

## Required Tests

Automated:

- layout breakpoint preserves active key;
- hidden column command still reachable;
- text scale smoke at large values;
- high contrast token path;
- reduced motion path;
- no overlap in reference widths.

Manual:

- compact keyboard path;
- mobile/touch path if platform supported;
- screen reader path after breakpoint change;
- horizontal scroll focus not obscured;
- details path exposes hidden facts.

## Stop Rules

- Do not change command ids by breakpoint.
- Do not hide dangerous state only because layout is compact.
- Do not remove keyboard path for hidden visual controls.
- Do not disable text scaling globally.
- Do not let sticky UI obscure focused controls.
