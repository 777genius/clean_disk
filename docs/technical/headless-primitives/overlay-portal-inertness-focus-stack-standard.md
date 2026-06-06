# Overlay Portal Inertness And Focus Stack Standard

## Status

Implementation standard for Dialog, AlertDialog, ContextMenu, MenuButton,
Popover-like adapters, Tooltip, and nested overlay composition.

## Purpose

Overlay bugs are usually focus bugs, lifecycle bugs, or stacking bugs. This
standard defines the shared overlay model so each primitive does not invent its
own portal, dismissal, inertness, and focus restoration behavior.

## Standards And References

- WAI-ARIA APG Dialog Modal:
  https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Menu Button:
  https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/
- WAI-ARIA APG Tooltip:
  https://www.w3.org/WAI/ARIA/apg/patterns/tooltip/
- MDN `<dialog>`:
  https://developer.mozilla.org/en-US/docs/Web/HTML/Element/dialog
- MDN Popover API:
  https://developer.mozilla.org/en-US/docs/Web/API/Popover_API
- Open UI Popover explainer:
  https://open-ui.org/components/popover.research.explainer/

## Overlay Kinds

```text
tooltip
statusToast
menu
contextMenu
popover
nonModalDialog
modalDialog
alertDialog
systemBlockingAdapter
```

Each kind declares:

- focus policy;
- dismiss policy;
- stacking priority;
- modality;
- pointer outside behavior;
- escape behavior;
- inertness behavior;
- restoration behavior;
- announcement behavior.

## Overlay Stack

There is one logical overlay stack per app root:

```text
base route
  -> nonmodal overlay
  -> menu/context menu
  -> modal dialog
  -> alert dialog
```

Rules:

- top modal owns focus;
- lower overlays cannot steal focus;
- tooltip is noninteractive and never owns stack focus;
- opening dialog from menu should close or suspend menu;
- nested dialogs require explicit parent relationship;
- dismissing parent dismisses children first.

## Focus Origin Model

Every focus-owning overlay captures:

```text
origin component key
origin focus target
origin route/scope
origin validity policy
fallback target
```

On close:

1. restore to origin if mounted and still valid;
2. restore to logical key after virtualization remount;
3. restore to nearest visible ancestor or trigger group;
4. restore to route fallback;
5. focus app root with diagnostic if no safe target exists.

## Modal Inertness

Modal dialog means content outside the dialog is inert to interaction. The
adapter must prevent:

- keyboard focus leaving the dialog;
- pointer activation behind the dialog;
- screen reader interaction with background where platform supports it;
- background shortcuts from firing;
- tooltip/menu from background opening.

On web, native `<dialog>` and `inert` are relevant platform concepts. In
Flutter, the adapter must model the same behavior with focus scopes, hit-test
blocking, route barriers, and semantics exclusion where appropriate.

## Dismiss Policy

Dismiss reasons:

```text
escapeKey
outsidePointer
triggerToggle
routeChange
command
selection
blur
timeout
systemBack
parentClosed
```

Each overlay declares allowed reasons.

Safe defaults:

- tooltip closes on blur, hover exit, Escape;
- menu closes on Escape, activation, outside pointer by policy;
- modal destructive dialog does not close on outside pointer by default;
- alert dialog requires explicit action unless policy says otherwise;
- route change closes all overlays with `routeChange` reason.

## Portal Placement

Portal adapter owns placement and clipping. Component owns behavior.

Portal adapter responsibilities:

- anchor measurement;
- collision handling;
- viewport boundary;
- z-order;
- transform following;
- scroll following or closing policy;
- platform window changes.

Component responsibilities:

- open/close state;
- command handling;
- focus policy;
- semantic intent;
- dismissal permission.

## Animation Policy

Animation is visual, not state authority.

- state can be `opening`, `open`, `closing`, `closed`;
- focus should move when overlay is logically open, not after arbitrary visual
  delay unless policy requires it;
- closing animation must not leave hidden focusable content active;
- reduced motion should use minimal or no animation;
- animation cancellation must finish close effects exactly once.

## Required Tests

Automated:

- focus trap;
- focus restore;
- nested overlay close order;
- Escape policy;
- outside pointer policy;
- background shortcut blocked by modal;
- tooltip never receives focus;
- opening dialog from menu transfers focus correctly;
- route change closes stack.

Manual:

- VoiceOver/NVDA modal reads label and does not expose background workflow;
- keyboard user can close or complete every overlay;
- pointer user cannot activate background through modal barrier;
- reduced motion path has no hidden focusable leftovers.

## Stop Rules

- Do not let each primitive create a separate overlay root.
- Do not make destructive dialogs outside-click dismissible by default.
- Do not leave hidden overlay content focusable.
- Do not let tooltip contain interactive content.
- Do not make renderer responsible for focus restoration.
