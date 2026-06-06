# Headless Dialog And Confirmation RFC

## Status

Accepted design direction. Not implemented yet.

## Problem

Clean Disk needs reliable confirmation flows for destructive actions. Headless
needs a robust dialog primitive for the community: modal dialogs, alert
dialogs, confirmation, focus trap, focus restore, nested dialogs, and renderer
separation.

## Standards And References

- WAI-ARIA APG Dialog Modal:
  https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Alert Dialog:
  https://www.w3.org/WAI/ARIA/apg/patterns/alertdialog/
- MDN `dialog` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/dialog_role
- MDN `alertdialog` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alertdialog_role
- Radix Dialog:
  https://www.radix-ui.com/primitives/docs/components/dialog
- React Aria Dialog:
  https://react-spectrum.adobe.com/react-aria/Dialog.html

## Accepted Direction

Create `components/headless_dialog` with a confirmation specialization:

```text
components/headless_dialog
  RDialog
  RAlertDialog
  RConfirmDialog
  RDialogController
  DialogFocusPolicy
  DialogDismissPolicy
  DialogStackState

headless_contracts
  RDialogRenderer
  RDialogTokenResolver
```

## Top Options

1. Headless dialog plus confirm/alert specialization - 🎯 9   🛡️ 9   🧠 7,
   roughly 700-1400 LOC.

   Best for safety and community reuse.

2. Only confirmation dialog for Clean Disk - 🎯 6   🛡️ 7   🧠 5,
   roughly 300-700 LOC.

   Faster, but duplicates future dialog requirements.

3. Material `showDialog` wrapper - 🎯 4   🛡️ 5   🧠 3,
   roughly 100-250 LOC.

   Too coupled to Material and weak for Headless renderer contracts.

Accepted: option 1.

## Focus Policy

Dialog must model initial focus:

```text
DialogInitialFocus.firstFocusable
DialogInitialFocus.title
DialogInitialFocus.leastDestructiveAction
DialogInitialFocus.primaryAction
DialogInitialFocus.custom(node)
```

For destructive Clean Disk confirmation, default to least destructive action.
This matches APG guidance for difficult or irreversible actions.

## Keyboard Model

- opening dialog moves focus inside;
- Tab and Shift + Tab cycle inside modal dialog;
- Escape closes only if dismiss policy allows it;
- close returns focus to invoking element if it still exists;
- nested dialogs restore to the previous dialog correctly;
- close button should be present unless product explicitly opts out.

## Accessibility Model

Expose:

- role dialog or alertdialog;
- modal state;
- label from visible title or explicit label;
- optional description only when content is simple;
- omit description for complex structured content;
- destructive action label;
- least destructive action;
- busy/processing state;
- disabled action state.

## Confirmation Contract

```text
ConfirmDialogRequest
  id
  title
  body model
  severity: info | warning | destructive
  primaryAction
  cancelAction
  requireAcknowledgement
  requireTypedPhrase
  canDismiss
```

Clean Disk destructive action rule:

- dialog displays current validated plan;
- stale plan disables destructive action;
- missing capability disables destructive action;
- action goes through application use case;
- Headless never performs deletion.

## Overlay And Inertness

Use Headless overlay infrastructure. Modal behavior requires:

- pointer interaction outside blocked or handled by dismiss policy;
- background visually dimmed by renderer;
- focus trap active;
- previous focus restored;
- nested stack ordered;
- disposal fails closed.

## Conformance Tests

- initial focus policy variants;
- Tab trap;
- Escape policy;
- focus restore;
- nested dialog stack;
- role and label semantics;
- alertdialog semantics;
- least destructive focus for destructive confirmation;
- controlled open state;
- renderer missing diagnostic.

## Stop Rules

- Do not move focus to status/live region instead of dialog content.
- Do not put destructive app logic in Headless.
- Do not make all dialogs dismissible by Escape/outside click by default.
- Do not apply a long `aria-describedby` style description to structured
  content.
