# Keyboard Shortcut Conflict And Remapping Standard

## Status

Implementation standard for keyboard commands, shortcut conflicts, and user
remapping in Headless primitives.

## Purpose

Keyboard support is not just a list of keys. Complex primitives must avoid
conflicting with text input, browser shortcuts, operating system shortcuts,
assistive technology commands, and product-level command palettes.

## Standards And References

- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Patterns:
  https://www.w3.org/WAI/ARIA/apg/patterns/
- WCAG 2.2:
  https://www.w3.org/TR/wcag-22/
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- Flutter Focus:
  https://docs.flutter.dev/ui/interactivity/focus
- Flutter `FocusableActionDetector`:
  https://api.flutter.dev/flutter/widgets/FocusableActionDetector-class.html

## Core Rule

Headless owns semantic command mapping. Applications own global shortcut
policy. Renderers own only visual affordances.

```text
physical key event
  -> shortcut resolver
  -> semantic command
  -> reducer
```

Public docs should describe commands first and default shortcuts second.

## Command Categories

Navigation:

- move next;
- move previous;
- move parent;
- move child;
- move first;
- move last;
- page up;
- page down;
- enter composite;
- exit composite.

Activation:

- activate;
- open;
- close;
- expand;
- collapse;
- toggle;
- confirm;
- cancel.

Selection:

- select focused;
- extend selection;
- select range;
- select all visible;
- clear selection.

Editing or layout:

- resize;
- reorder;
- sort;
- filter;
- rename;
- commit edit;
- cancel edit.

Context:

- open context menu;
- open command menu;
- show help.

## Shortcut Resolver Layers

Resolver order:

1. active text editing scope;
2. active modal dialog;
3. active menu or popover;
4. focused composite primitive;
5. application global shortcuts;
6. platform defaults.

If a lower layer handles a key, higher layers must not also run unless the
command is explicitly marked as chainable.

## Text Input Guard

When focus is inside text input, editable cell, search field, or content entry:

- character keys belong to editing;
- Arrow keys belong to caret movement unless editing mode delegates them;
- Escape can leave edit mode before closing outer overlay;
- Enter can commit edit before row activation;
- shortcut resolver must know the editing boundary.

Do not let TreeGrid row navigation steal typing from search fields or rename
inputs.

## Assistive Technology Conflict Guard

Some key chords are used by screen readers or operating systems. Headless must:

- prefer APG standard keys for composites;
- avoid requiring undocumented modifier-heavy chords;
- make advanced shortcuts remappable;
- provide pointer or menu alternatives for nonessential shortcuts;
- document platform-specific differences.

Risky shortcuts:

- single-letter global shortcuts;
- browser-reserved shortcuts;
- OS window management shortcuts;
- screen-reader navigation chords;
- shortcuts that depend on keyboard layout.

## Default Shortcut Policy

Defaults can follow APG where a component has an APG pattern.

TreeGrid:

- arrows navigate;
- Right expands or moves into child by policy;
- Left collapses or moves to parent by policy;
- Home/End move to first/last;
- PageUp/PageDown move viewport pages;
- Enter activates or toggles expansion by focus mode;
- Space selects or toggles by selection policy;
- Shift + F10 or context menu key opens context menu.

Menu:

- arrows navigate;
- Home/End jump;
- Escape closes;
- Enter/Space activates;
- character search if enabled.

Dialog:

- Tab/Shift + Tab loop inside modal;
- Escape follows dialog dismiss policy;
- Enter follows default action only when safe and explicit.

SplitPane:

- arrows resize;
- Home/End min/max;
- Enter collapse/restore if enabled.

## Remapping Contract

Public API should allow:

```text
shortcutMap
disabledDefaultShortcuts
platformShortcutProfile
conflictResolver
commandPaletteLabels
```

Remapping must preserve:

- command identity;
- accessibility docs;
- conformance scenario expectations;
- diagnostics for conflicts;
- serialization without localized labels.

## Diagnostics

Detect and warn:

- same shortcut maps to two commands in one scope;
- global shortcut shadows focused composite key;
- text editing scope receives navigation command;
- shortcut uses unsupported key on current platform;
- renderer shows shortcut label that does not match resolver.

Diagnostics must not log user-entered text.

## Evidence

Automated:

- key event maps to one command;
- text input guard;
- modal precedence;
- menu precedence;
- remapped command works;
- conflicting shortcut warns;
- RTL arrow policy tested separately from command identity.

Manual:

- keyboard-only sweep;
- screen reader quick navigation sanity check;
- browser web build does not block critical browser escape routes;
- platform keyboard layouts tested for critical commands.

## Stop Rules

- Do not implement keyboard behavior in renderer only.
- Do not use localized labels as shortcut ids.
- Do not require pointer input for a core action.
- Do not let global shortcuts bypass modal dialog scope.
- Do not let destructive command be single-key by default.
