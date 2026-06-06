# Normative Keyboard Command Matrix

## Status

Normative keyboard map for implementation and conformance.

## Primary Standards

- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- WAI-ARIA APG Menu and Menubar:
  https://www.w3.org/WAI/ARIA/apg/patterns/menubar/
- WAI-ARIA APG Dialog Modal:
  https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Window Splitter:
  https://www.w3.org/WAI/ARIA/apg/patterns/windowsplitter/
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Core Rule

Keyboard support is component behavior. Renderers draw keyboard state but do not
define keyboard behavior.

## Shared Key Policy

| Key | Shared meaning |
| --- | --- |
| Tab | move between components or enter/leave composite by policy |
| Shift + Tab | reverse Tab movement |
| Escape | close/cancel/leave mode by policy |
| Enter | activate, commit, or enter content mode |
| Space | activate or toggle selection depending component |
| Home | first item, min value, or row start |
| End | last item, max value, or row end |
| Page Up/Down | viewport-sized movement where meaningful |
| Context Menu / Shift + F10 | open context menu for focused target |

## TreeGrid Rows-First

| Key | Command |
| --- | --- |
| Up/Down | previous/next visible row |
| Right | expand collapsed parent, then optional first child |
| Left | collapse expanded parent, then optional parent |
| Home/End | first/last visible row |
| Page Up/Down | move by viewport page |
| Space | toggle row selection |
| Shift + Up/Down | extend row range |
| Enter | activate row |
| Ctrl/Cmd + A | select configured scope |

## TreeGrid Cells-First

| Key | Command |
| --- | --- |
| Left/Right | previous/next cell |
| Up/Down | same column previous/next row |
| Home/End | row start/end |
| Ctrl/Cmd + Home/End | grid start/end |
| Enter/F2 | enter content or edit mode |
| Escape | leave content/edit mode |
| Shift + arrows | extend cell selection |

## Context Menu

| Key | Command |
| --- | --- |
| Up/Down | previous/next menu item |
| Home/End | first/last item |
| Enter | activate or open submenu |
| Space | activate checkbox/radio policy |
| Right | open submenu |
| Left | close submenu or parent menu |
| Escape | close menu and restore focus |
| Printable character | typeahead |
| Tab | close menu and continue focus traversal |

## Dialog

| Key | Command |
| --- | --- |
| Tab | next focusable inside dialog |
| Shift + Tab | previous focusable inside dialog |
| Escape | close if dismiss policy allows |
| Enter | activate focused action |

Destructive confirmation default:

- initial focus on least destructive action;
- destructive action disabled until validation state is valid.

## SplitPane

| Key | Vertical splitter | Horizontal splitter |
| --- | --- | --- |
| Arrow Left | decrease primary size | n/a |
| Arrow Right | increase primary size | n/a |
| Arrow Up | n/a | decrease primary size |
| Arrow Down | n/a | increase primary size |
| Home | minimum primary size | minimum primary size |
| End | maximum primary size | maximum primary size |
| Enter | collapse/restore | collapse/restore |

## Tooltip And StatusRegion

| Primitive | Key behavior |
| --- | --- |
| Tooltip | Escape closes, focus remains on trigger |
| StatusRegion | no keyboard focus, no focus movement |

## Shortcut Registry

```text
ShortcutDefinition
  commandId
  activators
  platformVariants
  enabledWhen
  scope
  visibleInMenu
  exposeToSemantics
```

Rules:

- shortcuts must route to commands;
- disabled command disables shortcut;
- shortcut display label is localized;
- command id is stable and not localized.

## Conformance Checks

- every command has a keyboard path or documented exception;
- every pointer-only path has non-pointer alternative;
- shortcuts do not fire outside active scope;
- disabled commands do not fire through shortcuts;
- focus after Escape returns to correct logical target.

## Stop Rules

- Do not implement keyboard logic in renderer.
- Do not use global shortcuts for local component commands.
- Do not make drag the only way to resize/reorder.
- Do not bind destructive action to key press without validation.
