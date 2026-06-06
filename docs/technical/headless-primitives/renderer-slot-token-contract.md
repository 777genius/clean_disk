# Renderer, Slot, And Token Contract

## Status

Implementation contract. Not implemented yet.

## Source Rules

Existing Headless architecture requires:

- component owns behavior and root accessibility;
- renderer owns visuals;
- renderer receives commands, not app callbacks;
- slots are typed;
- tokens drive visual values;
- capability lookup is explicit.

## Core Decision

Complex primitives need a strict render request contract. Renderers must not
reconstruct behavior.

## Render Request Shape

```text
RenderRequest
  context
  componentId
  stateSnapshot
  semanticSnapshot
  resolvedTokens
  slots
  commands
  density
  motion
  accessibilityPolicy
```

State snapshot is read-only. Commands are the only way back into component
behavior.

## Capability Interfaces

```text
RTreeGridRenderer
RSplitPaneRenderer
RContextMenuRenderer
RDialogRenderer
RTooltipRenderer
RStatusRegionRenderer
```

Renderer capability types should be stable and non-generic where possible.

## Slot Types

Use:

```text
Replace
Decorate
Enhance
```

Rules:

- slot contexts are typed;
- no string part names;
- slot cannot bypass root semantics;
- slot can call command object but not product callback directly;
- slot docs describe whether semantic responsibility stays with parent or slot.

## Token Categories

```text
color
typography
spacing
radius
border
shadow
motion
focus
density
hitTarget
semantic
danger
```

Clean Disk needs dark/light token parity. Headless must not hardcode product
colors.

## Accessibility Tokens

```text
FocusRingTokens
  thickness
  offset
  contrastColor
  shape

HitTargetTokens
  minWidth
  minHeight
  spacing

MotionTokens
  reducedMotionBehavior
  enterDuration
  exitDuration
```

Renderer must respect reduced-motion policy.

## Renderer Forbidden Actions

Renderer must not:

- call user callback directly;
- install independent root GestureDetector/InkWell for activation;
- own selection/focus/open state;
- skip semantics facts from component;
- fetch app data;
- read daemon DTOs;
- mutate controllers.

## Conformance Tests

- missing renderer gives diagnostic;
- subtree override wins;
- renderer commands route through component;
- root activation fires once;
- disabled state blocks command;
- tokens are used for focus/hit target/danger state;
- reduced motion policy affects animation;
- slot replacement cannot remove required root semantics without explicit unsafe
  mode.

## Stop Rules

- Do not put visuals in component packages.
- Do not make renderer a behavior owner.
- Do not use untyped string slot identifiers.
- Do not hardcode Clean Disk colors into Headless.
