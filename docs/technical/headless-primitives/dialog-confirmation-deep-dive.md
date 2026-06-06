# Dialog And Confirmation Deep Dive

## Status

Implementation-ready design constraints. Not implemented yet.

## Primary Standards

- WAI-ARIA APG Dialog Modal:
  https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Alert Dialog:
  https://www.w3.org/WAI/ARIA/apg/patterns/alertdialog/
- MDN `dialog` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/dialog_role
- MDN `alertdialog` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alertdialog_role
- React Aria Dialog:
  https://react-spectrum.adobe.com/react-aria/Dialog.html
- Radix Dialog:
  https://www.radix-ui.com/primitives/docs/components/dialog

## Core Decision

Dialog is a focus-management primitive. Confirmation is a policy-driven dialog
specialization. Headless never executes destructive actions.

## Dialog State

```text
DialogState
  closed
  opening
  open
  submitting
  closing
  closed
```

Dismiss policy:

```text
DismissPolicy
  escape
  outsidePointer
  closeButton
  routeChange
  ownerDisposed
```

Each reason can be allowed, blocked, or delegated to app policy.

## Initial Focus Policy

```text
InitialFocusPolicy
  firstFocusable
  title
  leastDestructiveAction
  primaryAction
  custom
```

Destructive Clean Disk confirmation default:

- focus least destructive action;
- disable destructive action until current validated plan exists;
- optional typed phrase only for high-risk actions;
- never focus destructive primary by default.

## Modal Rules

Modal dialog:

- focus moves inside on open;
- Tab and Shift + Tab loop inside;
- content behind modal is inert;
- Escape follows policy;
- focus returns to invoking target on close;
- nested dialogs restore to previous dialog;
- close button exists unless explicitly disabled by policy.

## Semantic Contract

```text
DialogSemantics
  role: dialog | alertdialog
  modal
  label
  description optional
  severity
  busy
  destructiveAction
  leastDestructiveAction
```

Do not use long description for complex structured content. For a complex
DeletePlan, title labels the dialog; content is navigable inside.

## Confirmation Request

```text
ConfirmRequest
  id
  title
  contentModel
  severity
  primaryAction
  cancelAction
  requireAcknowledgement
  requireTypedPhrase
  validationState
```

Validation states:

```text
valid
stale
missingCapability
policyBlocked
inProgress
failed
```

Destructive action is enabled only in `valid`.

## Clean Disk Delete Flow

```text
Selection
  -> cleanup queue
  -> validate DeletePlan
  -> confirmation dialog
  -> application command
  -> daemon trash/delete adapter
  -> receipt
```

Headless owns only dialog behavior. It never validates or executes DeletePlan.

## Renderer Boundary

Renderer owns:

- surface;
- backdrop;
- title/body/action layout;
- danger styling;
- progress visuals;
- responsive layout.

Component owns:

- focus trap;
- initial focus;
- close policy;
- semantics;
- submit state;
- action command dispatch.

## Conformance Tests

- focus trap loops;
- initial focus variants;
- least destructive default for destructive confirmation;
- Escape policy;
- outside click policy;
- nested dialog restore;
- `alertdialog` semantics;
- structured content omits long description;
- submitting disables repeated activation;
- controlled open state.

## Stop Rules

- Do not put destructive app logic in Headless.
- Do not enable destructive action on stale validation.
- Do not move focus to background while modal is open.
- Do not make outside click close destructive confirmation by default.
