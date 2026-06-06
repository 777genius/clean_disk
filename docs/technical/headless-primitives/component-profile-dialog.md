# Component Profile - Dialog And Confirmation

## Status

Implementation profile for `RDialog`, `RAlertDialog`, and `RConfirmDialog`.

## Standards

- WAI-ARIA APG Dialog Modal:
  https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Alert Dialog:
  https://www.w3.org/WAI/ARIA/apg/patterns/alertdialog/
- MDN `dialog` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/dialog_role

## Purpose

Modal or alert interaction requiring user focus. Confirmation is a policy layer
over dialog.

Clean Disk use: delete/trash confirmation, capability repair, operation receipt
details.

## Required Anatomy

- backdrop;
- surface;
- title;
- optional description;
- content;
- action group;
- close control;
- focus trap;
- restore target.

## Required State

```text
openPhase
initialFocusTarget
focusedElement
submitState
dismissPolicy
validationState
restoreTarget
```

## Keyboard Profile

MUST support:

- Tab and Shift + Tab cycle inside modal;
- Escape follows dismiss policy;
- Enter activates focused action;
- focus restore on close.

## Semantic Profile

MUST expose:

- dialog or alertdialog;
- modal;
- label;
- optional description;
- busy/submitting;
- destructive action state where applicable.

## Destructive Confirmation Policy

For destructive actions:

- initial focus SHOULD be least destructive action;
- destructive action MUST be disabled when validation is stale;
- outside click SHOULD NOT dismiss by default;
- Headless MUST NOT execute product deletion.

## Conformance Gates

- focus trap;
- focus restore;
- initial focus variants;
- Escape/outside policy;
- alertdialog semantics;
- stale validation disables submit;
- nested dialog stack.

## Stop Rules

- Do not put destructive workflow in Headless.
- Do not make destructive dialogs outside-click dismissible by default.
- Do not convert complex content into one long semantic description.
