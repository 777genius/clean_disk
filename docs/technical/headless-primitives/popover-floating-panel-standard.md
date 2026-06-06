# Popover Floating Panel Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN Popover API: https://developer.mozilla.org/en-US/docs/Web/API/Popover_API
- MDN Using the Popover API: https://developer.mozilla.org/en-US/docs/Web/API/Popover_API/Using
- WAI-ARIA APG Dialog Modal Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- MDN `dialog` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/dialog_role
- MDN `aria-haspopup`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-haspopup
- MDN `inert`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inert
- WCAG 1.4.13 Content on Hover or Focus: https://www.w3.org/WAI/WCAG22/Understanding/content-on-hover-or-focus.html
- Flutter focus system: https://docs.flutter.dev/ui/interactivity/focus

## Scope

This standard covers non-modal popovers, teaching bubbles, inspector panels,
small pickers, info panels, filter panels, inline details surfaces, anchored
floating panels, and custom hover/focus overlays that are not tooltips, menus,
or modal dialogs.

Tooltips, menus, dialogs, and select/listbox have separate standards. A popover
is for richer content that may be interactive but should not trap the whole app
unless promoted to dialog.

## Decision Options

1. `FloatingPanel` primitive with explicit interaction mode -
   🎯 9   🛡️ 9   🧠 8, roughly 900-1900 LOC.
   Best fit. It prevents accidental misuse of tooltip/menu/dialog semantics and
   gives one overlay lifecycle for all renderers.
2. Reuse dialog for all popovers - 🎯 5   🛡️ 7   🧠 4, roughly 300-800 LOC.
   Safer for focus, but too heavy for filters, hints, quick details, and
   anchored panels.
3. Reuse menu for all popovers - 🎯 3   🛡️ 4   🧠 4, roughly 250-700 LOC.
   Wrong for arbitrary content. Menus are command lists, not rich panels.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- anchor identity;
- panel identity;
- open/closed state;
- modality kind: nonModal, lightDismiss, persistent, promotedDialog;
- focus entry policy;
- focus return policy;
- outside interaction policy;
- Escape behavior;
- hover/focus dismiss timing;
- collision strategy contract;
- semantic role hint;
- privacy classification for panel labels and content summaries.

Renderer owns:

- placement visuals;
- arrow/caret;
- animation;
- surface tokens;
- scrim if any;
- responsive fallback layout.

Application owns:

- panel content;
- commands inside panel;
- data loading;
- authorization;
- product state.

## Popover Versus Other Surfaces

Use tooltip when:

- content is short;
- content is not interactive;
- it describes an existing control.

Use menu when:

- content is a list of commands or choices;
- menu keyboard behavior is expected.

Use dialog when:

- user must respond;
- focus must be trapped;
- background must be inert;
- destructive confirmation or form completion is required.

Use popover when:

- content is anchored;
- content can be interactive;
- background can remain usable;
- dismissal should be lighter than dialog.

## Interaction Modes

Non-modal persistent:

- background remains usable;
- panel remains open until closed or route changes;
- focus may move outside.

Light dismiss:

- outside click/focus closes panel;
- Escape closes panel;
- focus returns to invoker where practical.

Hover/focus:

- must meet dismissible, hoverable, and persistent expectations;
- never use for essential content only;
- provide keyboard-triggered equivalent.

Promoted dialog:

- renderer may display as popover visually;
- semantics and focus follow dialog standard.

## Focus Rules

Opening:

- if panel contains no interactive content, focus may remain on invoker;
- if panel contains first-class controls, focus may move to first meaningful
  focus target;
- panel title or first paragraph may receive focus for complex content;
- opening must not steal focus on hover-only preview.

Closing:

- Escape closes when open;
- focus returns to invoker unless invoker disappeared;
- route/layout change closes stale panel;
- closing must cancel pending hover timers and async effects.

## Semantics Mapping

Web adapter:

- prefer native Popover API for non-modal popovers where support is sufficient;
- use dialog semantics only for modal/promoted mode;
- never set `aria-modal` on non-modal popovers;
- use `aria-haspopup` and `aria-expanded` on invokers when appropriate;
- ensure popover content appears in logical focus order.

Flutter adapter:

- use overlay portal/root overlay abstraction;
- use Semantics labels for panel title when useful;
- keep focus and route lifecycle explicit;
- verify desktop screen reader behavior because Flutter overlays are not HTML.

## Clean Disk Usage

Good popover use cases:

- sort/filter quick panel;
- column picker;
- small scan target details;
- help content for skipped count;
- compact row action details.

Bad popover use cases:

- move-to-trash confirmation;
- destructive policy conflict;
- permission repair requiring steps;
- full details pane replacement on desktop.

## Conformance Scenarios

- non-modal popover does not trap focus;
- Escape closes and restores focus;
- hover/focus popover remains dismissible and hoverable;
- interactive popover is reachable by keyboard;
- popover does not use tooltip semantics when interactive;
- route change closes panel;
- private paths are not placed in panel labels;
- screen reader can distinguish panel from menu and dialog.

## Failure Catalog

- Tooltip contains buttons.
- Menu contains forms and arbitrary paragraphs.
- Non-modal popover sets `aria-modal`.
- Focus moves into hover-only preview.
- Outside click closes panel but Escape does not.
- Popover remains open after anchor unmounts.
- Renderer positions panel off-screen with no keyboard path.
