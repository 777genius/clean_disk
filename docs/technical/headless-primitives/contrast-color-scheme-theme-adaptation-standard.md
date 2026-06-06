# Contrast Color Scheme And Theme Adaptation Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN `forced-colors`: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/forced-colors
- MDN `prefers-contrast`: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-contrast
- MDN `prefers-color-scheme`: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme
- MDN `color-scheme`: https://developer.mozilla.org/en-US/docs/Web/CSS/color-scheme
- WCAG 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- WCAG 1.4.3 Contrast Minimum: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- WCAG 1.4.11 Non-text Contrast: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
- WCAG 2.4.13 Focus Appearance: https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html
- Flutter `MediaQueryData`: https://api.flutter.dev/flutter/widgets/MediaQueryData-class.html

## Scope

This standard defines how Headless primitives adapt to:

- light and dark schemes;
- high contrast;
- forced colors;
- user contrast preference;
- disabled, readonly, selected, focused, hovered, pressed, invalid, warning,
  danger, and busy states;
- chart and visualization colors;
- focus appearance;
- text scaling and density pressure.

It is a token resolution standard, not a palette.

## Decision Options

Option A: App-specific theme only - 🎯 4   🛡️ 4   🧠 2, about 100-250 LOC.

- Easy for Clean Disk.
- Weak for Headless as a public standard.
- Does not protect third-party renderers from inaccessible state colors.

Option B: Material theme mirror - 🎯 6   🛡️ 6   🧠 4, about 250-500 LOC.

- Good Flutter ergonomics.
- Too narrow for web, Cupertino, custom renderers, and forced-colors mode.
- Material color roles do not fully encode Headless state semantics.

Option C: Headless adaptive token resolver - 🎯 9   🛡️ 9   🧠 7, about
800-1400 LOC.

- Accepted direction.
- Headless defines semantic token roles and state resolution.
- Renderer maps tokens into visual implementation.
- App theme can feed the resolver, but cannot bypass accessibility rules.

## Accepted Direction

Headless must define an adaptive token resolver with:

- semantic color roles;
- state modifiers;
- contrast mode;
- forced-color behavior;
- focus appearance requirements;
- fallback roles;
- validation and diagnostics.

Applications may provide brand palettes, but primitive states must resolve
through Headless tokens before rendering.

## Token Layers

Token resolution order:

1. system accessibility environment;
2. user preference override;
3. application theme;
4. primitive semantic role;
5. component state;
6. renderer-specific projection;
7. fallback and diagnostics.

The resolver must be deterministic. A state combination must resolve the same
way across rebuilds and platforms unless the environment changes.

## Semantic Color Roles

Core roles:

- `surface`;
- `surfaceRaised`;
- `surfaceInset`;
- `textPrimary`;
- `textSecondary`;
- `textDisabled`;
- `borderSubtle`;
- `borderStrong`;
- `focusRing`;
- `selectionSurface`;
- `selectionText`;
- `accentPrimary`;
- `accentSecondary`;
- `danger`;
- `warning`;
- `success`;
- `info`;
- `chartSeries`;
- `chartOther`;
- `overlayScrim`;

State roles:

- `hovered`;
- `pressed`;
- `focused`;
- `selected`;
- `current`;
- `checked`;
- `expanded`;
- `busy`;
- `invalid`;
- `readonly`;
- `disabled`;
- `destructivePending`;

## Contrast Requirements

Text:

- normal text should meet at least WCAG AA contrast against its immediate
  background;
- large text may use the large-text threshold only when the renderer can
  prove size and weight;
- placeholder and helper text should remain readable;
- disabled text may be exempt from strict WCAG contrast, but Headless should
  still provide a readable token unless the platform convention requires lower
  emphasis.

Non-text UI:

- focus indicators, checkbox borders, selected rows, sliders, progress bars,
  icons that communicate state, chart marks, and input borders must meet
  non-text contrast against adjacent colors;
- state must not rely on hue alone;
- selected plus focused must have a distinct combined state.

## Forced Colors Rules

In forced colors:

- app brand colors are advisory only;
- system colors or renderer platform equivalents take priority;
- backgrounds and text must not be hard-coded in ways that fight the user
  agent;
- box shadows and gradients cannot be the only boundaries;
- focus rings must remain visible;
- SVG and canvas visualizations need alternate semantic tables or system-color
  overlays;
- disabled and selected states must remain distinguishable.

## Color Scheme Rules

Headless must separate:

- scheme: light or dark;
- contrast: no preference, more, less, custom;
- forced colors: active or none;
- palette: application-provided values;
- state: semantic component state.

Dark mode is not just inverted light mode.

Clean Disk dark mode can use cyber blue and violet accents, but:

- table text must stay readable;
- progress cyan must not be the only meaning;
- danger pink must have text and icon support;
- warning yellow must not be only color-coded;
- row selection must survive high contrast.

## Focus Appearance

Focus tokens must define:

- minimum contrast;
- minimum visible area;
- inner or outer ring placement;
- behavior on selected rows;
- behavior on dense tables;
- behavior on rounded and square controls;
- fallback when outlines are clipped.

Renderer must not remove focus outline without providing an equivalent or
better focus indicator.

## Visualization Rules

Charts, treemaps, donuts, sparklines, and maps must not use color as the only
carrier of meaning.

Headless visualization adapters should expose:

- series label;
- color token role;
- pattern or stroke fallback;
- selected and focused mark state;
- legend mapping;
- data table fallback;
- high contrast projection;
- print projection.

Clean Disk disk maps must use this standard through `DiskUsageMapView`.

## Flutter Adapter Requirements

Flutter adapter should read:

- `MediaQuery.platformBrightness`;
- `MediaQuery.highContrast`;
- `MediaQuery.boldText`;
- `MediaQuery.textScaler`;
- `ThemeData.colorScheme`;
- platform accessibility features where needed.

Headless should provide `MaterialHeadlessTheme.fromThemeData` or equivalent
token bridge so Material theme and Headless tokens do not drift.

## Web Adapter Requirements

Web adapter should support:

- `prefers-color-scheme`;
- `prefers-contrast`;
- `forced-colors`;
- `color-scheme`;
- CSS custom property projection;
- deterministic state classes or attributes;
- conformance snapshots for light, dark, high contrast, and forced colors.

## Clean Disk Requirements

Clean Disk must validate:

- wide dark reference;
- compact dark reference;
- light theme;
- high contrast light;
- high contrast dark;
- selected row plus focus;
- destructive queue state;
- permission warning state;
- disabled destructive action;
- chart legend and chart mark contrast.

Cleanup safety state must not depend only on pink, yellow, or cyan.

## API Shape Sketch

```text
HeadlessAdaptiveTheme
  environment
  palette
  resolveColor(role, states)
  resolveFocusAppearance(surface, states)
  resolveVisualizationSeries(index, states)
  validateContrast(componentContract)

AdaptiveEnvironment
  scheme
  contrastPreference
  forcedColors
  textScaler
  boldText
  reducedMotion
```

## Conformance Scenarios

- selected row is readable in light, dark, and high contrast;
- focused selected row has a distinct visible focus indicator;
- forced-colors web rendering does not disappear because of gradients;
- disabled button remains recognizable but cannot be confused with active;
- warning state is identifiable without color;
- chart legend maps to series even under forced colors;
- changing platform brightness updates tokens without stale cached colors;
- text scaling does not make labels overlap or hide required indicators.

## Failure Catalog

- using opacity alone for disabled state and making text unreadable;
- using glow or shadow as the only focus indicator;
- hard-coded hex colors inside renderer slots;
- chart meaning available only through color;
- selected plus focused state visually identical to selected;
- dark mode contrast tested but light mode ignored;
- forced-colors mode fighting system colors;
- app theme and Headless theme drifting;
- token resolver producing different colors for same state after rebuild;
- warning or danger conveyed only by color.

