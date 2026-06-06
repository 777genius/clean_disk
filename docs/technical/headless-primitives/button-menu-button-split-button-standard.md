# Button Menu Button And Split Button Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Button Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/button/
- WAI-ARIA APG Menu Button Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/
- WAI-ARIA APG Menu and Menubar Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/menubar/
- MDN `button` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/button_role
- MDN `aria-haspopup`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-haspopup
- MDN `aria-expanded`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-expanded
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers ordinary buttons, icon buttons, toggle buttons, menu
buttons, split buttons, destructive buttons, loading buttons, and command
buttons embedded in rows, toolbars, dialogs, and details panes.

It does not replace the ContextMenu or Toolbar standards. It defines the atomic
button contract those primitives compose.

## Decision Options

1. One `ButtonCommand` model with role-specific adapters - 🎯 9   🛡️ 9   🧠 6, roughly 600-1200 LOC.
   Best fit. The same command descriptor can render as a button, icon button,
   menu button, or split button while keeping authorization, labels, shortcuts,
   and semantics centralized.
2. Separate primitives for every button visual variant - 🎯 5   🛡️ 6   🧠 7, roughly 900-1800 LOC.
   Visually clean, but behavior and accessibility rules drift across variants.
3. Let Material/Cupertino buttons define behavior directly - 🎯 6   🛡️ 6   🧠 3, roughly 200-500 LOC.
   Good for quick app code, weak for Headless because platform renderers become
   the behavior authority.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- stable command id;
- command kind: action, toggle, menu trigger, split primary, split secondary,
  destructive, navigation, submit, cancel, reset;
- accessible text contract;
- enabled, disabled, loading, pressed, expanded, has popup, danger, and pending
  states;
- activation semantics for pointer, touch, keyboard, shortcut, and assistive
  technology actions;
- focus outcome after activation;
- menu opening handoff;
- double-invocation prevention;
- command authorization gate.

Renderer owns:

- visual style, icon placement, density, color, hover, pressed and loading
  animation;
- split button shape and divider;
- icon glyphs;
- local visual affordance for danger or primary action.

Application owns:

- side effects;
- delete-plan validation;
- command policy and user permissions;
- localized labels and descriptions;
- analytics and audit logging.

## Button Types

Ordinary action button:

- triggers one command;
- keeps focus unless the command intentionally changes context;
- uses `Enter` and `Space`.

Toggle button:

- represents a command mode, not a settings value;
- exposes pressed state;
- keeps a stable label while state changes.

Menu button:

- opens a menu;
- exposes popup and expanded state;
- moves focus into the menu when opened through keyboard.

Split button:

- has one primary action and one secondary menu trigger;
- each part has its own focus target;
- primary and secondary actions must have different accessible names;
- if the split affordance cannot be exposed correctly on a platform, fallback
  renders as a menu button with the primary action first.

Destructive button:

- represents a high-risk side effect;
- requires policy and confirmation state before enabled;
- must keep the destructive consequence visible or described.

Loading button:

- represents pending command execution;
- suppresses repeated activation unless the command is explicitly repeatable;
- does not rename itself every progress tick.

## Activation Contract

MUST:

- activate with `Enter` and `Space`;
- prevent duplicate activation from keydown/keyup/click synthesis;
- preserve pointer cancellation where possible;
- route activation through `Actions` and command dispatch, not renderer
  callbacks;
- expose disabled state and disabled reason;
- keep focus deterministic after command completion;
- expose loading or pending state without changing command identity;
- support assistive technology custom action where platform requires it.

SHOULD:

- keep focus on the button after ordinary in-place actions;
- move focus into dialog when a button opens a dialog;
- return focus to the opener when a dialog is cancelled;
- move focus to the next logical context only when the command changes workflow;
- expose shortcut hints outside the accessible name.

MUST NOT:

- use link semantics for actions that mutate state;
- use button semantics for navigation links that change URL or route like a link;
- change toggle button label from "Mute" to "Unmute" while also using pressed
  state;
- let icon-only buttons ship without accessible names;
- let a renderer call destructive side effects directly.

## Split Button Contract

Split buttons are high-risk for accessibility because they combine two targets.

MUST:

- expose two focusable controls or one menu button fallback;
- label the primary action by the visible primary command;
- label the secondary trigger as a menu for related actions;
- support `Enter` and `Space` on both controls;
- support `Down Arrow` opening the menu on the secondary trigger where platform
  convention allows it;
- keep hit targets large enough for touch and pointer;
- make the visual divider obvious in high contrast and forced-colors modes.

SHOULD:

- avoid split buttons for destructive actions;
- avoid split buttons in dense TreeGrid rows;
- prefer menu button fallback on compact mobile-like layouts.

## Clean Disk Mapping

Primary examples:

- `Scan`: primary action button.
- `Pause`: toggle-like operation command only while scan is running.
- `Cancel`: destructive-ish operation command that requires clear consequence.
- `Move to Trash`: destructive button disabled until validated plan exists.
- `Sort / Filter`: menu button.
- `Reveal in Finder`: ordinary platform action button.
- row overflow action: menu button, not a toolbar and not a split button.

Do not use split buttons in the MVP scan table. They add density and ambiguity.
They can be useful later for export or cleanup recipe actions.

## Conformance Tests

Minimum tests:

- `Enter` and `Space` activate once;
- disabled button cannot invoke command;
- disabled reason is available as description or status;
- icon-only button has accessible name;
- toggle label remains stable while pressed changes;
- menu button exposes popup and expanded state;
- split button exposes primary and menu trigger separately or falls back;
- loading button suppresses duplicate execution;
- destructive button requires policy gate;
- focus after dialog open/close matches the declared focus outcome.

## Failure Catalog

- Duplicate activation from keyboard and click handlers.
- Icon button with only a tooltip.
- Toggle that changes both label and pressed state.
- Split button whose arrow trigger is not keyboard reachable.
- Disabled destructive button with no explanation.
- Renderer bypassing application command policy.
