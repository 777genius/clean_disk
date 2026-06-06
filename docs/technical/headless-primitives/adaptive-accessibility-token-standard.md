# Adaptive Accessibility Token Standard

## Status

Implementation standard for design tokens that must adapt to accessibility and
platform settings.

## Purpose

Headless renderers need tokens that work in dark mode, light mode, high
contrast, text scaling, reduced motion, and dense productivity layouts. Visual
tokens are not just branding. For primitives, tokens are part of accessibility
and conformance.

## Standards And References

- WCAG 2.2:
  https://www.w3.org/TR/wcag-22/
- MDN `forced-colors`:
  https://developer.mozilla.org/en-US/docs/Web/CSS/@media/forced-colors
- MDN `prefers-reduced-motion`:
  https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion
- MDN `prefers-contrast`:
  https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-contrast
- Flutter accessibility:
  https://docs.flutter.dev/ui/accessibility
- Flutter `MediaQueryData`:
  https://api.flutter.dev/flutter/widgets/MediaQueryData-class.html
- Flutter accessibility testing:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Token Categories

Required primitive token families:

```text
color
typography
spacing
radius
border
focus
state layer
motion
density
hit target
icon
elevation
outline
selection
semantic severity
```

Tokens should be semantic, not component-color literals.

Good:

```text
focusRingColor
rowSelectedBackground
rowHoveredBackground
separatorHandleColor
dangerActionForeground
statusWarningForeground
```

Bad:

```text
blue500
neonPurpleGradient
cardGlowStrong
```

Brand palette can feed semantic tokens, but public renderers should not force a
brand palette.

## Adaptive Inputs

Renderer token resolver must accept:

- brightness;
- high contrast;
- text scale;
- accessible navigation;
- disable animations;
- platform;
- pointer kind;
- density;
- locale direction;
- reduced motion;
- forced colors or equivalent capability where available.

Flutter adapter should read these from `MediaQuery`, platform dispatcher, theme,
and renderer config, then resolve tokens before rendering.

## Focus Token Requirements

Focus indicator must be:

- visible without relying only on glow or shadow;
- distinct from hover and selected state;
- not clipped by row bounds;
- visible in high contrast;
- visible over selected row;
- not hidden by sticky header/footer;
- stable under text scaling.

Do not make focus ring a low-opacity accent that disappears in dark mode.

## Hit Target Requirements

Interactive targets need:

- minimum visual or semantic hit area;
- pointer and keyboard alternatives;
- spacing that reduces accidental activation;
- compact-density exception only with equivalent larger focus/action path;
- no tiny icon-only delete action without label and focus affordance.

Flutter guideline tests should run for tap target and labelled target where the
renderer exposes interactive controls.

## Color And Contrast Requirements

Token resolver should compute or validate:

- text contrast;
- icon contrast;
- focus indicator contrast;
- non-text state contrast;
- selected row text contrast;
- disabled text contrast policy;
- status severity contrast;
- chart segment contrast where practical.

Do not encode state by color only. Selected, warning, disabled, and queued
states need shape, icon, text, or semantic state as well.

## Motion Requirements

Motion tokens:

- duration;
- curve;
- reduced duration;
- spring disabled flag;
- large layout transition policy;
- scroll animation policy.

Reduced motion:

- remove decorative transitions;
- shorten overlay open/close;
- avoid animated scroll except where required for focus visibility;
- avoid pulsing/glowing infinite animations.

## Text Scaling Requirements

Dense components must define:

- minimum row height behavior;
- ellipsis policy;
- multi-line policy;
- column overflow policy;
- tooltip or details path for truncated content;
- non-overlap guarantee.

Text scaling must not:

- hide focus target;
- make delete buttons overlap labels;
- hide checkbox state;
- break row indentation;
- cause dialog actions to overflow.

## High Contrast And Forced Colors

Web adapters should respect forced colors by:

- using system colors when applicable;
- avoiding box-shadow-only focus;
- using borders/outlines for important state;
- avoiding background-image-only state;
- testing with Windows High Contrast where possible.

Flutter native adapters should expose a high-contrast token profile where the
platform provides high contrast or equivalent user preference.

## Token Resolution Order

```text
primitive defaults
  -> renderer preset defaults
  -> design system theme
  -> app overrides
  -> accessibility adaptations
  -> state resolution
```

Accessibility adaptations win over decorative theme preferences.

## Required Tests

Automated:

- light and dark contrast checks;
- high contrast token snapshot;
- reduced motion snapshot;
- text scale layout smoke;
- focus ring visible over selected row;
- labelled icon-only action;
- disabled state not commandable.

Manual:

- Windows high contrast web check;
- macOS increase contrast check where possible;
- text scale 200 percent layout check;
- reduced motion interaction check;
- keyboard-only focus visibility sweep.

## Stop Rules

- Do not ship focus indication based only on shadow or glow.
- Do not let brand colors override high-contrast safety.
- Do not make text scaling impossible in dense mode.
- Do not use color as the only state signal.
- Do not put product-specific palette names in Headless contracts.
