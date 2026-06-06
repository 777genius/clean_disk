# Conformance And Public Standard Deep Dive

## Status

Implementation-ready design constraints. Not implemented yet.

## Primary Standards

- Existing Headless `SPEC_V1.md`
- Existing Headless `CONFORMANCE.md`
- WAI-ARIA APG Patterns:
  https://www.w3.org/WAI/ARIA/apg/patterns/
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- Flutter testing:
  https://docs.flutter.dev/testing
- Flutter accessibility:
  https://docs.flutter.dev/ui/accessibility

## Core Decision

Headless-compatible must mean testable compatibility, not branding.

## Conformance Levels

```text
Level 0 - API Shape
  public exports only
  no src imports
  dependency DAG

Level 1 - Behavior
  keyboard
  controlled state
  disabled policy
  focus management

Level 2 - Accessibility
  semantics facts
  focus restoration
  role/state mapping
  live region policy

Level 3 - Renderer Boundary
  renderer capability lookup
  missing renderer diagnostics
  renderer does not own root behavior
  slots preserve command boundary

Level 4 - Scale
  virtualization
  large dataset fixtures
  no unbounded rebuilds
```

## Required Report

Every component package should ship:

```text
CONFORMANCE_REPORT.md
LLM.txt
README compatibility section
test command list
spec version
core package versions
renderer/preset versions
```

## Test Fixtures

Shared fixtures:

- small eager collection;
- disabled items;
- multi-select;
- backend-owned virtual collection;
- 100k synthetic rows;
- nested tree;
- menu with submenu;
- destructive confirmation;
- tooltip with noninteractive content;
- status region progress stream;
- split pane min/max.

## Golden Behavior Scripts

Use behavior scripts instead of screenshots:

```text
press Tab
expect focus target
press ArrowDown
expect focus target
press Space
expect selected state
expect semantics facts
```

Screenshots can verify visual presets, but they are not behavioral conformance.

## Renderer Compatibility

Renderer packages must prove:

- capability registered;
- subtree override works;
- required tokens resolved;
- focus visual state visible;
- disabled visual state visible;
- root gesture is not duplicated;
- commands flow through request;
- semantics remain component-owned.

## Public API Stability

API annotations:

```text
experimental
stable
deprecated
internal
```

TreeGrid should remain experimental until:

- collection/grid/tree foundation pass tests;
- Material renderer passes conformance;
- Clean Disk synthetic large table passes performance gate;
- web accessibility measurement has at least known limitations.

## Performance Gates

Minimum before stable:

- 50k row synthetic TreeGrid no obvious jank in profile;
- hover rebuild affects one row;
- selection range does not allocate all backend rows;
- progress footer does not rebuild viewport;
- viewport built row count bounded by visible range plus overscan.

## Stop Rules

- Do not let a package claim Headless compatibility without report.
- Do not accept screenshot-only tests as conformance.
- Do not stabilize TreeGrid before foundation contracts stabilize.
- Do not test only Material preset.
- Do not skip keyboard-only paths.
