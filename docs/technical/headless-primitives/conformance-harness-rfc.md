# Headless Conformance Harness RFC

## Status

Accepted design direction. Not implemented yet.

## Problem

Headless is intended to be a public UI kit standard, not just a widget
collection. Complex primitives like TreeGrid, Dialog, ContextMenu, SplitPane,
Tooltip, and StatusRegion need repeatable conformance tests so custom renderers
and third-party packages can claim compatibility honestly.

## Standards And References

- Existing Headless `docs/SPEC_V1.md`
- Existing Headless `docs/CONFORMANCE.md`
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Patterns:
  https://www.w3.org/WAI/ARIA/apg/patterns/
- Flutter testing and semantics:
  https://docs.flutter.dev/testing
  https://docs.flutter.dev/ui/accessibility

## Accepted Direction

Create a public `headless_test` conformance harness for complex primitives:

```text
packages/headless_test/lib/src/conformance/
  component_conformance.dart
  semantics_probe.dart
  keyboard_probe.dart
  focus_probe.dart
  controlled_state_probe.dart
  renderer_capability_probe.dart
  viewport_test_adapter.dart
  golden_behavior_script.dart
```

Each component package ships a `CONFORMANCE_REPORT.md`.

## Top Options

1. Shared conformance harness - 🎯 9   🛡️ 9   🧠 7,
   roughly 700-1500 LOC.

   Best for community trust. Makes custom renderers testable.

2. Per-component tests only - 🎯 6   🛡️ 6   🧠 5,
   roughly 300-900 LOC per component.

   Useful but inconsistent and hard for third parties.

3. Documentation checklist only - 🎯 3   🛡️ 3   🧠 2,
   roughly 100-200 LOC.

   Too weak for a public standard.

Accepted: option 1.

## Harness Categories

Each public component should test:

- public API imports only;
- missing renderer diagnostics;
- controlled/uncontrolled state;
- external controller ownership;
- keyboard-only interaction;
- focus restore and focus visibility;
- semantic facts;
- disabled behavior;
- pointer behavior where relevant;
- renderer command boundary;
- no direct product callback from renderer root;
- lifecycle/disposal safety.

## Complex Primitive Suites

TreeGrid:

- keyboard rows-first and cells-first;
- virtual viewport adapter;
- selection/focus split;
- row/cell/header semantics.

ContextMenu:

- right click;
- Shift + F10;
- submenu stack;
- disabled focus policy;
- Escape restore.

Dialog:

- modal focus trap;
- initial focus;
- least destructive focus;
- nested stack;
- focus restore.

SplitPane:

- arrow resize;
- Home/End;
- Enter collapse/restore;
- separator semantic values.

Tooltip:

- focus/hover open;
- Escape close;
- no interactive descendants.

StatusRegion:

- no focus movement;
- announcement coalescing;
- polite/assertive policy.

## Renderer Capability Tests

For every renderer:

- capability can be found from theme;
- subtree override wins;
- required tokens resolved;
- renderer does not own root semantics;
- renderer does not install competing gesture handler for root activation;
- renderer handles disabled/focused/hovered/pressed state visually.

## Test Adapter Rule

Virtualized components need a deterministic test viewport adapter. Tests should
not disable virtualization by changing production contracts. They should inject
`TestViewportAdapter` that exposes a controlled visible window.

## Conformance Report Template

```text
## Conformance Report

- Component: RTreeGrid
- Spec: Headless Component Spec v1 + TreeGrid RFC
- Date:
- Core versions:
- Test commands:
- Scope:
  - semantics:
  - keyboard:
  - controlled state:
  - renderer capability:
  - viewport:
- Evidence:
```

## Stop Rules

- Do not allow "Headless-compatible" claims without a report.
- Do not test only Material renderer.
- Do not skip keyboard tests for pointer-first widgets.
- Do not use golden screenshots as behavioral conformance.
