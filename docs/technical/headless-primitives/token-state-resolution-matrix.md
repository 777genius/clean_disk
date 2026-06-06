# Token And State Resolution Matrix

## Status

Spec-level token and state resolution contract.

## Primary References

- Flutter accessibility testing:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing
- WCAG 2.2:
  https://www.w3.org/TR/WCAG22/
- Existing Headless token/theme architecture.

## Purpose

Tokens must resolve consistently across Material/Cupertino/custom renderers.
State resolution must not drift between primitives.

## State Dimensions

```text
enabled
disabled
focused
focusVisible
hovered
pressed
selected
expanded
checked
loading
error
readonly
danger
dragging
resizing
```

Each renderer should support only dimensions relevant to its primitive, but the
meaning of shared dimensions must stay consistent.

## Resolution Priority

High to low:

1. explicit per-instance override;
2. scoped Headless theme override;
3. preset token resolver;
4. global design-system token;
5. component safe fallback;
6. missing token diagnostic in strict mode.

## Token Categories

| Category | Examples | Required for |
| --- | --- | --- |
| color | foreground, background, accent, danger | all renderers |
| focus | ring color, thickness, offset | focusable parts |
| hit target | min width/height, padding | controls/handles |
| motion | enter/exit duration, curve | overlays/tooltip |
| density | row height, spacing | TreeGrid, menus |
| border | width, color, radius | surfaces |
| semantic | danger, warning, info mapping | dialogs/status |

## Reduced Motion

Renderer MUST respect reduced-motion policy:

- remove nonessential transition;
- keep state change understandable;
- preserve close completion callback.

## Contrast And Target Size

Flutter guideline tests can verify:

- tappable target sizes;
- labels for tap targets;
- text contrast.

Headless conformance SHOULD include these guideline tests for preset renderers.

## Strict Token Mode

```text
HeadlessRendererPolicy.requireResolvedTokens
```

Strict mode fails in debug/test if required tokens are missing.

## Conformance Checks

- focused state resolves focus tokens;
- disabled state changes visual and semantic state;
- selected and focused can coexist visually;
- danger action uses danger tokens;
- reduced motion affects animation;
- strict mode catches missing tokens;
- dark/light themes both pass contrast fixture.

## Stop Rules

- Do not hardcode visual constants in renderer when tokens exist.
- Do not make focus ring optional for keyboard focus.
- Do not let danger styling imply delete authority.
