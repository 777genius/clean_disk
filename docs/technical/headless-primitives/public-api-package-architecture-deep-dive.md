# Public API And Package Architecture Deep Dive

## Status

Implementation-ready design constraints. Not implemented yet.

## Source Rules

This file applies existing Headless architecture:

- component packages expose `R*` widgets;
- component packages do not depend on other component packages;
- foundation contains reusable behavior mechanics;
- contracts contain renderer capability interfaces;
- preset packages implement renderers;
- apps consume through design-system wrappers.

## Package Split

```text
headless_foundation
  collection/
  grid/
  tree/
  overlay/
  menu/
  viewport/

headless_contracts
  renderers/
    tree_grid/
    split_pane/
    context_menu/
    dialog/
    tooltip/
    status_region/

components/headless_tree_grid
components/headless_split_pane
components/headless_context_menu
components/headless_dialog
components/headless_tooltip
components/headless_status_region

headless_material
headless_cupertino future
```

## Component Package Shape

```text
lib/
  headless_<component>.dart
  src/
    domain/
      ids/
      state/
      events/
      specs/
    presentation/
      r_<component>.dart
      controllers/
      reducer/
      effects/
      semantics/
      render_request/
    infra/
      adapters/
```

No empty folders required for trivial components, but complex primitives should
use this shape.

## Public API Rule

Public exports:

- widget;
- controller;
- specs/value objects;
- slots;
- style/tokens if component-owned;
- conformance helpers if package owns them.

Do not export:

- reducer internals;
- private effects executor;
- renderer implementations;
- app-specific adapters;
- test-only adapters from production entrypoint.

## Controller Ownership

```text
external controller
  component does not dispose

internal controller
  component disposes

controlled value
  component emits intent
  parent updates value

uncontrolled value
  component updates internal state
```

This must be tested in every component.

## Renderer Contracts

Renderer capability interfaces should be non-generic where possible for stable
type identity.

Render request includes:

- context;
- resolved state;
- resolved tokens;
- slots;
- commands;
- semantic facts;
- density/motion/accessibility policy.

Renderer never receives raw app callback if a command object can represent the
same operation.

## Slots

Use typed slots:

```text
Replace
Decorate
Enhance
```

Slot contexts must include enough state to customize visuals without requiring
people to fork renderers.

## Clean Disk Consumption

```text
features/scan
  -> packages/design_system AppTreeGrid
    -> headless RTreeGrid
```

Feature packages should not import Headless internals directly unless the
design-system package deliberately exposes a lower-level escape hatch.

## Versioning

Experimental packages:

- allow additive API movement;
- document limitations;
- no compatibility claim unless conformance report exists.

Stable packages:

- breaking changes require major version;
- deprecate before removal;
- conformance report required.

## Stop Rules

- Do not expose `src/` imports in docs.
- Do not make component packages depend on each other.
- Do not put Material visuals in component packages.
- Do not couple Clean Disk feature code to renderer internals.
