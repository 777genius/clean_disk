# Drawer Sheet Side Panel Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Dialog Modal Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- MDN `<dialog>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Element/dialog
- MDN `dialog` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/dialog_role
- MDN `inert`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inert
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 2.1.2 No Keyboard Trap: https://www.w3.org/WAI/WCAG22/Understanding/no-keyboard-trap.html
- Flutter Material widgets: https://docs.flutter.dev/ui/widgets/material
- Flutter focus system: https://docs.flutter.dev/ui/interactivity/focus

## Scope

This standard covers drawers, side sheets, bottom sheets, inspector panels,
details panels, command panels, responsive panel replacements, and temporary
layout surfaces that can be persistent, dismissible, modal, or non-modal.

It does not cover navigation sidebar semantics. Navigation drawer content uses
the navigation standard inside this surface standard.

## Decision Options

1. `PanelSurface` primitive with explicit modality and persistence -
   🎯 9   🛡️ 9   🧠 8, roughly 1000-2200 LOC.
   Best fit. It unifies desktop side panels, compact bottom sheets, drawers,
   and details panes without confusing focus behavior.
2. Treat all panels as dialogs - 🎯 6   🛡️ 7   🧠 5, roughly 500-1000 LOC.
   Safer for modal cases, but wrong for persistent details panes and wide
   desktop layouts.
3. Treat all panels as layout containers - 🎯 4   🛡️ 5   🧠 4, roughly 400-900 LOC.
   Easy visually, but fails modal sheet focus, Escape, inertness, and restore.

Accepted direction: option 1.

## Panel Modes

Persistent layout panel:

- always part of layout;
- not modal;
- does not trap focus;
- can be bypassed;
- examples: wide details pane, delete queue side panel.

Temporary non-modal panel:

- overlays or pushes content;
- background remains available;
- Escape closes if dismissible;
- focus may enter and leave naturally.

Temporary modal panel:

- background is inert;
- focus is contained;
- Escape behavior is explicit;
- used for critical mobile/compact workflows.

Promoted dialog:

- visually a sheet/drawer;
- semantically a dialog;
- used for confirmation, permission repair, or destructive review.

## Primitive Boundary

Headless owns:

- panel id;
- panel mode;
- anchor edge;
- open/closed state;
- modal/inert contract;
- focus trap or no-trap policy;
- focus entry and restore;
- dismiss reasons;
- resize/collapse state;
- safe area contract;
- route/lifecycle behavior;
- privacy class for panel title and summary.

Renderer owns:

- side/bottom placement;
- animation and motion reduction;
- scrim visuals;
- handle visuals;
- density and responsive layout;
- high contrast borders.

Application owns:

- panel content;
- panel availability;
- destructive capability gating;
- route and persistence;
- platform-specific window behavior.

## Focus Rules

Persistent panel:

- no focus trap;
- participates in normal focus order;
- has a named region when substantial;
- can be skipped through bypass standard.

Temporary non-modal panel:

- opening may keep focus on invoker or move into panel depending content;
- Escape closes if dismissible;
- focus restore required on close;
- outside focus may close if light dismiss.

Temporary modal panel:

- focus moves into panel on open;
- Tab and Shift+Tab remain inside;
- background inert;
- closing returns focus to invoker or logical fallback.

## Responsive Behavior

The same logical panel can render as:

- right details pane on wide desktop;
- bottom sheet on compact desktop;
- full-height drawer on narrow web;
- modal dialog when destructive workflow requires it.

Responsive changes must preserve:

- panel identity;
- selected item association;
- pending command state;
- focus target if still valid;
- announcement of major mode change.

## Clean Disk Usage

Details pane:

- persistent on wide layout;
- collapsible bottom section on compact layout;
- not modal;
- stale selection disables destructive actions.

Delete queue:

- persistent or collapsible;
- move-to-trash final confirmation uses dialog or promoted modal panel;
- queue state is not delete authority.

Permission repair:

- can be temporary modal panel if user must complete a flow;
- must not hide scan-quality facts.

Settings:

- persistent route or temporary panel depending platform;
- sensitive settings require explicit policy objects.

## Semantics Mapping

Web adapter:

- persistent side panel maps to complementary/region where appropriate;
- modal sheet maps to dialog semantics or native dialog;
- use inert for background when modal;
- do not put `aria-modal` on persistent panels.

Flutter adapter:

- use FocusScope and route/overlay lifecycle;
- use Semantics container labels for meaningful panels;
- verify focus restoration after close and breakpoint change.

## Conformance Scenarios

- persistent details panel does not trap focus;
- compact modal sheet traps focus and restores focus;
- Escape behavior is consistent with dismissible flag;
- background is inert only when modal;
- panel title contains no raw path by default;
- responsive transform from side pane to sheet preserves state;
- reduced motion disables large slide animation;
- destructive action inside panel still requires validated plan.

## Failure Catalog

- Wide details pane uses modal dialog semantics.
- Mobile sheet allows focus behind destructive confirmation.
- Panel close loses focus to document root.
- Responsive breakpoint destroys pending review state.
- Drawer hides content visually but leaves focusable controls behind it.
- Raw cleanup target path appears in panel title.
