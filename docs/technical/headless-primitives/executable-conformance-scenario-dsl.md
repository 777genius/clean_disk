# Executable Conformance Scenario DSL

## Status

Spec-level test protocol. Not implemented yet.

## Purpose

Conformance should be executable where possible. This file sketches a small
scenario DSL for keyboard, focus, semantics, and state tests.

## Primary References

- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- Flutter widget testing:
  https://docs.flutter.dev/testing
- Flutter accessibility testing:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Scenario Shape

```text
scenario:
  component:
  fixture:
  steps:
    - press: Tab
    - expectFocus: treegrid.root
    - press: ArrowDown
    - expectLogicalFocus: row:item-2
    - press: Space
    - expectSelected: item-2
    - expectSemantics:
        selected: true
```

This is a design sketch. Actual implementation can be Dart builders instead of
YAML/JSON.

## Step Types

```text
pressKey
tap
rightClick
longPress
hover
drag
pump
setViewport
updateProps
dispose
```

## Assertion Types

```text
expectLogicalFocus
expectPlatformFocus
expectSelection
expectExpansion
expectOverlayPhase
expectSemanticsFact
expectCommand
expectEffect
expectNoProductCallback
expectBuiltCountBelow
expectAnnouncement
```

## Required Scenarios

TreeGrid:

- rows-first navigation;
- range selection;
- expand/collapse;
- virtual scroll-to-key;
- sorted header.

Dialog:

- initial focus;
- Tab trap;
- Escape policy;
- focus restore.

ContextMenu:

- right click;
- Shift + F10;
- submenu;
- disabled item.

SplitPane:

- keyboard resize;
- pointer drag;
- min/max clamp.

Tooltip/Status:

- tooltip focus/hover;
- status announcement coalescing.

## Evidence Output

```text
component:
scenario:
result:
failedStep:
expected:
actual:
environment:
packageVersions:
```

## Stop Rules

- Do not rely only on screenshots for behavior.
- Do not make scenarios depend on real app data.
- Do not skip keyboard scenarios.
- Do not let scenario runner expose raw paths or labels in logs.
