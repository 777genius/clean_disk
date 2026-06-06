# Compliance Playbook - Menu Dialog Tooltip

## Status

Compliance checklist for overlay primitives.

## Standards

- WAI-ARIA APG Menu and Menubar:
  https://www.w3.org/WAI/ARIA/apg/patterns/menubar/
- WAI-ARIA APG Menu Button:
  https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/
- WAI-ARIA APG Dialog Modal:
  https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Tooltip:
  https://www.w3.org/WAI/ARIA/apg/patterns/tooltip/
- WAI-ARIA APG Names and Descriptions:
  https://www.w3.org/WAI/ARIA/apg/practices/names-and-descriptions/

## Menu Evidence

Behavior:

- opens from trigger;
- opens from context key or Shift + F10;
- focus placed on first/selected item by policy;
- arrow navigation;
- Home/End;
- typeahead;
- submenu open/close;
- Escape closes and restores focus;
- disabled item focus policy verified.

Semantics:

- menu scope;
- item labels;
- disabled/checked/submenu facts;
- separator not focusable.

## Dialog Evidence

Behavior:

- initial focus policy;
- Tab trap;
- Escape policy;
- outside interaction policy;
- nested dialog restore;
- destructive confirmation focuses least destructive action.

Semantics:

- label required;
- alertdialog only for urgent interruptive cases;
- structured content not collapsed into long description;
- busy/submitting state exposed.

## Tooltip Evidence

Behavior:

- opens on focus/hover after delay;
- closes on Escape and blur;
- focus remains on trigger;
- no interactive descendants.

Semantics:

- trigger has accessible name;
- tooltip is supplemental description;
- tooltip is not required-only information.

## Overlay Lifecycle Evidence

- open -> opening -> open;
- close -> closing -> closed;
- complete close once;
- fail-safe close;
- focus restore target valid or fallback used.

## Stop Rules

- Do not use menu as arbitrary popover.
- Do not use tooltip for interactive content.
- Do not make destructive dialog outside-click dismissible by default.
- Do not skip focus restore tests.
