# Destructive Action Safety Affordance Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 3.3.4 Error Prevention: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html
- WCAG 3.3.1 Error Identification: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WAI-ARIA APG Alert Dialog Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/alertdialog/
- WAI-ARIA APG Dialog Modal Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- MDN `alertdialog` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alertdialog_role
- MDN `button` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/button_role
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Scope

This standard covers danger buttons, destructive menu items, explicit
confirmation affordances, consequence summaries, stale-plan disable states,
least-destructive focus defaults, undo/restore indicators, and safety copy used
around high-risk actions.

It does not execute destructive work. Headless can describe safety state.
Application decides authority, validation, and side effects.

## Decision Options

1. `DangerActionDescriptor` plus confirmation affordance state shared across
   button/menu/dialog/toolbar/palette - 🎯 9   🛡️ 10   🧠 8, roughly 900-2100 LOC.
   Best fit. It makes dangerous command state consistent and testable.
2. Keep danger styling as renderer-only token -
   🎯 4   🛡️ 4   🧠 3, roughly 150-400 LOC.
   Looks right but does not protect users.
3. Put all destructive safety only in app workflows -
   🎯 6   🛡️ 7   🧠 5, roughly 500-1200 LOC per app.
   Safer than renderer-only, but public Headless primitives still leak unsafe
   affordances through menus, toolbars, and palettes.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- danger kind;
- consequence label;
- confirmation requirement;
- validated state;
- stale state;
- disabled reason;
- least-destructive focus hint;
- undo/restore capability display fact;
- policy conflict state;
- command surface restrictions;
- announcement strategy;
- privacy class for consequence summary.

Renderer owns:

- danger color token;
- warning icon;
- button/menu styling;
- disabled/pending visuals;
- confirmation checkbox or phrase visuals when requested by application.

Application owns:

- DeletePlan or operation plan;
- identity revalidation;
- authorization;
- operation execution;
- receipt and restore capability;
- exact confirmation copy.

## Danger Kinds

Soft destructive:

- reversible or easy to restore;
- example: remove from local queue.

Recoverable destructive:

- may be recoverable through Trash or receipt;
- still requires review.

Irreversible destructive:

- not recoverable through app;
- requires strongest confirmation and policy gate.

Authority-changing:

- changes permissions, tokens, remote scopes, or destructive capability.

Ambiguous destructive:

- unknown restore/reclaim confidence;
- must fail closed for commit.

## Confirmation Requirements

None:

- harmless command or undoable UI state.

Soft:

- danger styling plus clear command label.

Review:

- user sees affected items and consequences before commit.

Explicit:

- checkbox or typed phrase if application chooses;
- must be associated with consequence text.

Validated plan:

- current app/domain validation required;
- stale or missing validation disables destructive action.

## Focus Rules

For destructive confirmation:

- initial focus defaults to least destructive action;
- destructive action is not focused by default;
- Escape closes or cancels according to dialog policy;
- outside click does not dismiss by default for high-risk confirmations;
- validation failure focuses summary or affected field.

For menu/toolbar/palette:

- danger command may be discoverable;
- activation opens review flow, not immediate commit, unless policy proves safe;
- disabled reason must be available.

## Copy Rules

Danger copy must answer:

- what will happen;
- which scope is affected;
- whether it is reversible;
- how much may be reclaimed if relevant;
- what cannot be known;
- what blocks action.

Avoid:

- vague "Are you sure?";
- color-only warning;
- raw full paths by default;
- technical IDs;
- reassuring exactness when estimate is uncertain.

## Clean Disk Usage

Move to Trash:

- requires current DeletePlan;
- requires identity revalidation;
- shows restore capability;
- stale plan disables button;
- shortcut opens review flow only.

Remove from queue:

- soft destructive UI command;
- no filesystem effect;
- may not need modal confirmation.

Remote/headless destructive:

- disabled by default;
- authority-changing gate separate from local UI selection.

## Conformance Scenarios

- stale DeletePlan disables danger action;
- least destructive action receives initial focus;
- danger menu item opens confirmation instead of deleting;
- disabled reason is available to keyboard and screen reader users;
- restore capability is shown honestly;
- consequence summary avoids raw paths unless policy allows;
- high contrast shows danger beyond color;
- command palette cannot execute irreversible action directly.

## Failure Catalog

- Danger is only a red button.
- Destructive button is default focused.
- `Enter` commits delete when dialog opens.
- Disabled danger button gives no reason.
- Shortcut bypasses confirmation.
- Restore confidence is overstated.
- Path list in confirmation leaks private data unnecessarily.
