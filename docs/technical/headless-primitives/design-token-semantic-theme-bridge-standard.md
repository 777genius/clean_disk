# Design Token Semantic Theme Bridge Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- WCAG 1.4.3 Contrast Minimum: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- WCAG 1.4.11 Non-text Contrast: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
- MDN `forced-colors`: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/forced-colors
- MDN `prefers-contrast`: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-contrast
- MDN `prefers-color-scheme`: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-color-scheme
- MDN `color-scheme`: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/color-scheme

## Scope

This standard covers semantic design tokens, theme bridges, color-scheme
mapping, high contrast mapping, state tokens, focus tokens, density tokens,
motion tokens, renderer token adapters, and app theme integration.

It extends contrast/color-scheme and adaptive accessibility token standards.
It focuses on keeping Headless public contracts independent from a single
brand palette or Flutter Material theme.

## Problem

Clean Disk has a strong dark visual direction, but Headless is a public UI
foundation. If Headless exposes brand colors directly, it becomes app-specific.
If renderers invent tokens independently, app theme, high contrast, disabled
state, and focus visuals drift. We need a semantic token bridge.

## Decision Options

1. Semantic token bridge from Headless states to renderer/theme tokens -
   🎯 9   🛡️ 9   🧠 8, roughly 1000-2200 LOC.
   Best fit. It keeps public Headless generic and lets Clean Disk map its
   Cyber Blue/Violet theme cleanly.
2. Use Material ThemeData directly in Headless contracts -
   🎯 6   🛡️ 6   🧠 4, roughly 400-900 LOC.
   Convenient for Flutter Material apps, but weak for Cupertino, web, and
   community renderers.
3. Hardcode renderer colors per component -
   🎯 3   🛡️ 3   🧠 2, roughly 100-400 LOC.
   Fast, but guarantees drift and accessibility regressions.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- semantic state tokens;
- component part token ids;
- required token categories;
- token fallback policy;
- accessibility requirements;
- contrast role;
- motion preference hooks;
- density hooks.

Renderer owns:

- actual color values;
- typography values;
- spacing values;
- radius values;
- shadow/elevation values;
- animation curves;
- platform-specific system color mapping.

Application owns:

- brand palette;
- light/dark theme choice;
- high contrast preference;
- user personalization;
- persistence;
- localization of theme labels.

## Token Categories

Semantic categories:

- surface;
- content;
- border;
- focus;
- selection;
- hover;
- pressed;
- disabled;
- danger;
- warning;
- success;
- info;
- stale;
- estimate;
- progress;
- chart;
- overlay;
- scrim.

Each token declares:

- purpose;
- state;
- minimum contrast expectation;
- fallback;
- forced-colors behavior;
- high-contrast override behavior.

## State Resolution

State precedence:

1. disabled;
2. loading/busy;
3. destructive/danger;
4. selected/current;
5. focused;
6. pressed;
7. hovered;
8. default.

Rules:

- selected and focused are separate states;
- danger and disabled can coexist;
- stale is semantic, not only color;
- focus token must remain visible in high contrast;
- renderer cannot hide semantic state solely because app palette lacks color.

## Web Adapter Rules

Web renderer may map to:

- CSS custom properties;
- `color-scheme`;
- `prefers-color-scheme`;
- `prefers-contrast`;
- `forced-colors`;
- system colors in forced-colors mode.

Rules:

- do not rely on box-shadow for essential focus in forced colors;
- do not encode meaning only in background gradients;
- preserve non-text contrast for controls and meaningful graphics;
- expose theme switch without overriding OS/user preference silently.

## Flutter Adapter Rules

Flutter renderer may map to:

- ThemeData;
- ColorScheme;
- text theme;
- FocusTheme or component focus styles;
- MediaQuery accessibility features;
- platform high contrast signals where available.

Rules:

- Material theme is an adapter input, not Headless core dependency;
- Headless token ids remain stable across renderers;
- design system can bridge app tokens into Headless tokens;
- renderer snapshots should be testable for light, dark, high contrast, and
  text scale.

## Clean Disk Usage

Clean Disk maps:

- primary neon/cyan accent to semantic primary and progress;
- violet to selection/secondary accent;
- warning yellow to warning with non-color icon/text;
- danger pink/red to destructive with text label;
- dark surfaces to surface levels;
- light theme equivalents to same semantic ids.

Rules:

- app theme and Headless theme share one source of semantic tokens;
- visual reference images guide renderer values, not Headless contracts;
- critical warnings do not rely on neon glow;
- Syncfusion or chart adapters consume semantic chart tokens through adapter.

## Community API Sketch

```dart
final class RSemanticTokenSet {
  const RSemanticTokenSet({
    required this.colors,
    required this.focus,
    required this.motion,
    required this.density,
  });

  final Map<RSemanticColorToken, RTokenValueRef> colors;
  final RFocusTokenSet focus;
  final RMotionTokenSet motion;
  final RDensityTokenSet density;
}
```

## Conformance Scenarios

- selected focused destructive disabled states resolve deterministically;
- high contrast mode preserves focus indicator;
- forced-colors mode does not depend on box-shadow;
- warning state has non-color cue;
- light and dark themes use same semantic token ids;
- renderer missing token gets documented fallback;
- chart adapter consumes semantic chart tokens;
- app palette names do not appear in Headless core API.

## Failure Catalog

- Public API exposes Clean Disk palette names.
- Focus is visible only through glow.
- Disabled danger state loses danger explanation.
- Renderer hardcodes state colors.
- Forced-colors mode hides borders.
- Material ThemeData leaks into Headless foundation.
- Token ids are localized labels.

