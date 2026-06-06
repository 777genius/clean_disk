# Accessibility Evidence Report Template

## Status

Template for manual and automated accessibility evidence.

## Purpose

Accessibility claims need evidence. This template records what was tested and
what remains unknown.

## Report Template

```text
Component:
Version:
Renderer:
Platform:
Flutter version:
Date:
Tester:

Automated tests:
  keyboard:
  semantics:
  tap target:
  labels:
  contrast:

Manual assistive technology:
  screen reader:
  browser/runtime:
  scenarios:
  pass/fail:

Known limitations:

Risk:

Next action:
```

## Required Scenarios By Component

TreeGrid:

- row focus;
- selection;
- expand/collapse;
- sorted header;
- context menu.

Dialog:

- initial focus;
- trap;
- close;
- alertdialog.

Menu:

- keyboard navigation;
- submenu;
- disabled item.

Tooltip/Status:

- description;
- no focus movement;
- polite/assertive behavior.

SplitPane:

- value announcement;
- keyboard resize.

## Evidence Rules

- use synthetic data;
- do not record raw user paths;
- note browser/screen reader versions;
- document gaps instead of hiding them;
- rerun after keyboard/semantics changes.

## Stop Rules

- Do not call a component fully accessible without evidence.
- Do not rely only on automated tests for complex widgets.
- Do not publish transcripts containing sensitive user data.
