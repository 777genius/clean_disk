# Cross Primitive Composition Rules

## Status

Composition rules for complex product surfaces.

## Purpose

Real apps compose primitives: TreeGrid row opens ContextMenu, ContextMenu opens
Dialog, Dialog updates StatusRegion, SplitPane contains TreeGrid. Composition
must not break focus, semantics, or command boundaries.

## Allowed Composition

```text
SplitPane
  contains TreeGrid

TreeGrid
  opens ContextMenu through command

ContextMenu
  emits product command intent

Application
  opens Dialog or updates StatusRegion

Dialog
  confirms product action
```

## Forbidden Composition

- TreeGrid directly deletes product data.
- Renderer opens Dialog by itself.
- Tooltip contains ContextMenu trigger.
- StatusRegion replaces Dialog for required decision.
- ContextMenu contains text fields or complex forms.
- SplitPane handle lives inside TreeGrid row semantics.

## Focus Chains

Example:

```text
TreeGrid row focus
  -> ContextMenu opens
  -> focus moves to menu item
  -> menu closes
  -> logical focus restores to TreeGrid row
```

If row unmounted, restore to:

1. same logical key after scroll/resolve;
2. nearest visible ancestor;
3. TreeGrid root;
4. route fallback.

## Command Chains

```text
Headless command
  -> component state
  -> app callback intent
  -> application use case
  -> product result
  -> status/dialog/tree update
```

No renderer-to-use-case shortcut.

## Overlay Stacking

Stack order:

- tooltip lowest and noninteractive;
- menu/popover;
- dialog;
- alert dialog.

Opening a dialog from a menu should close or suspend menu focus first.

## Conformance Checks

- TreeGrid -> ContextMenu focus restore;
- ContextMenu -> Dialog focus transfer;
- Dialog close returns to logical origin;
- StatusRegion update during dialog does not steal focus;
- SplitPane resize does not rebuild TreeGrid state;
- tooltip over row action does not trap focus.

## Stop Rules

- Do not create cycles between primitives.
- Do not allow nested overlays to own each other's state.
- Do not let lower-priority overlay steal focus from modal dialog.
