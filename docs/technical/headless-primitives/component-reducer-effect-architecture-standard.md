# Component Reducer And Effect Architecture Standard

## Status

Implementation standard for complex Headless primitives.

## Purpose

Large primitives must not become piles of callbacks, focus nodes, timers, and
renderer side effects. This file defines the internal architecture that keeps
TreeGrid, ContextMenu, Dialog, SplitPane, Tooltip, and StatusRegion testable and
portable.

## Standards And References

- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Patterns:
  https://www.w3.org/WAI/ARIA/apg/patterns/
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- Flutter Focus:
  https://docs.flutter.dev/ui/interactivity/focus
- Flutter accessibility testing:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Core Rule

Every complex primitive should be internally modeled as:

```text
input event
  -> normalized command
  -> pure reducer
  -> new state
  -> effects
  -> adapter execution
  -> external callbacks
```

The renderer receives state and command handles. It must not mutate component
state directly.

## Internal Types

Required type families:

```text
ComponentState
ComponentEvent
ComponentCommand
ComponentEffect
ComponentController
ComponentPolicy
ComponentCapabilities
ComponentDiagnostics
ComponentSnapshot
```

State:

- current logical state;
- no `BuildContext`;
- no `FocusNode`;
- no renderer objects;
- no product DTOs;
- no timers or subscriptions.

Event:

- raw user or adapter signal after normalization;
- may include key, pointer, scroll, focus, data, lifecycle, or policy changes;
- no direct side effects.

Command:

- semantic action such as `moveNextRow`, `openMenu`, `confirm`, `resizePane`;
- stable public name;
- can be invoked by keyboard, pointer, assistive technology, or tests.

Effect:

- imperative work requested by reducer;
- focus, scroll, live announcement, callback, timer, viewport query, or
  diagnostics emission;
- executed by adapter layer after state transition.

## Reducer Requirements

Reducer must be:

- deterministic;
- side-effect free;
- synchronous;
- unit-testable without Flutter widget tree;
- independent from renderer package;
- independent from product domain.

Reducer may read:

- previous component state;
- normalized event;
- component policy;
- readonly collection projection;
- capability flags.

Reducer must not:

- call product callbacks;
- allocate or dispose `FocusNode`;
- perform scroll;
- call `setState`;
- read `MediaQuery`;
- access localization;
- access system time except through injected event payload.

## Effect Execution Rules

Effects must be ordered. Example:

```text
state changed
  -> ensure row visible
  -> move platform focus
  -> announce status
  -> notify external callback
```

Effect executor must:

- run after state commit;
- drop stale effects when component version changed;
- report failed effects through diagnostics;
- avoid recursive command dispatch unless explicitly allowed;
- batch related effects when user gesture creates many state changes.

## Controlled And Uncontrolled State

Controlled state:

- external owner provides value and change callback;
- reducer emits proposed state and callback effect;
- component does not permanently commit external state unless new value arrives;
- stale controlled update should produce a diagnostic in debug mode.

Uncontrolled state:

- component owns value;
- controller can read snapshot and send commands;
- default value is copied only at initialization.

Mixed state:

- allowed only when each field has explicit ownership;
- example: controlled selection, uncontrolled keyboard focus;
- ownership changes during component lifetime should warn.

## Controller Contract

Controller should expose:

```text
snapshot
dispatch(command)
focus(key)
scrollTo(key)
open()
close()
dispose()
```

Controller must not expose:

- mutable internal maps;
- mounted row widgets;
- renderer state;
- product callbacks;
- raw semantics nodes;
- private reducer events.

## Renderer Boundary

Renderer can:

- render slots;
- read visual state;
- invoke command handles;
- provide layout metrics through adapter callbacks;
- expose capability support.

Renderer cannot:

- change selection directly;
- decide keyboard behavior;
- own focus restoration;
- run product side effects;
- generate ids;
- store application authority.

## Example For TreeGrid

```text
KeyDown ArrowDown
  -> MoveFocusIntent
  -> TreeGridCommand.moveNextRow
  -> reducer changes activeRowKey
  -> effects: ensureVisible(rowKey), updatePlatformFocus(rowKey)
```

Example forbidden path:

```text
row widget onKey
  -> setState active row
  -> call app callback
  -> scroll manually
```

## Example For Dialog

```text
OpenRequested
  -> reducer enters opening state
  -> effects: captureFocusOrigin, installModalScope, moveInitialFocus
```

Close:

```text
DismissRequested Escape
  -> reducer checks escape policy
  -> effects: restoreFocus, notifyDismissed
```

## Conformance Evidence

Required tests:

- reducer unit tests for every command;
- effect ordering tests;
- stale effect drop test;
- controlled value handshake test;
- controller dispose test;
- renderer cannot mutate state without command;
- command path is identical for keyboard and pointer when action is same.

## Stop Rules

- Do not put product use cases inside Headless effects.
- Do not put `BuildContext` in reducer state.
- Do not let renderer own public behavior.
- Do not expose reducer internals as public API.
- Do not skip effect ordering tests for focus and scroll.
