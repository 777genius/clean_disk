# Recoverable Error And Assistance Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- WCAG 3.3.1 Error Identification: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html
- WCAG 3.3.3 Error Suggestion: https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html
- WCAG 3.3.4 Error Prevention: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html
- WCAG 3.3.7 Redundant Entry: https://www.w3.org/WAI/WCAG22/Understanding/redundant-entry.html
- WCAG 3.2.6 Consistent Help: https://www.w3.org/WAI/WCAG22/Understanding/consistent-help.html

## Scope

This standard defines how Headless primitives expose recoverable errors,
assistance, repair steps, validation messages, retry affordances, and consistent
help without mixing product policy into components.

It applies to:

- form fields;
- dialogs;
- wizards;
- file pickers;
- permission repair flows;
- async table loads;
- export failures;
- scan target errors;
- cleanup plan errors;
- capability errors.

It does not define product support content. It defines error and assistance
contracts.

## Decision Options

Option A: Error string plus retry callback - 🎯 4   🛡️ 4   🧠 2, about
100-250 LOC.

- Fast.
- Loses severity, cause, recoverability, focus, status announcement, and help.

Option B: App-specific error components - 🎯 6   🛡️ 6   🧠 4, about
300-800 LOC.

- Flexible.
- Public primitives still need consistent validation, retry, and help behavior.

Option C: Typed recoverable error contract - 🎯 9   🛡️ 9   🧠 7, about
900-1700 LOC.

- Accepted direction.
- Errors have type, user action, focus target, announcement, and retry policy.
- Help stays consistent across primitive families.

## Accepted Direction

Headless must model user-facing errors as `RecoverableIssue`.

Each issue declares:

- error code;
- severity;
- affected field or component;
- recoverability;
- suggested action;
- retry action;
- repair action;
- help action;
- focus target;
- announcement policy;
- privacy class;
- redundant-entry policy.

## Error Classes

Classes:

- `validation`;
- `permission`;
- `capability`;
- `network`;
- `daemon`;
- `staleData`;
- `conflict`;
- `timeout`;
- `cancelled`;
- `partialResult`;
- `unsafeActionBlocked`;
- `incompatibleVersion`;
- `unknown`.

Each class maps to default visual, semantic, and command behavior.

## Recoverability Levels

Levels:

- `selfCorrectable`: user can fix input directly.
- `retryable`: same action can be retried.
- `repairable`: user can start repair workflow.
- `needsExternalAction`: OS, browser, or daemon setting required.
- `notRecoverableHere`: only status and support actions are available.
- `policyBlocked`: user cannot override in this context.

## Assistance Rules

A recoverable issue should provide:

- what happened;
- where it happened;
- why action is blocked when safe to say;
- what the user can do next;
- whether retry is safe;
- whether data was changed;
- whether state is stale.

Do not make the user re-enter known data after a recoverable error unless
security or correctness requires it.

## Focus Rules

When an error blocks current action:

- focus the first actionable error or summary;
- preserve context if focus movement would be disruptive;
- link summary items to fields;
- do not focus disabled repair command;
- do not trap focus in error state.

For async or background errors:

- use status region or banner;
- avoid stealing focus unless user action is blocked.

## Consistent Help Rules

Help affordances must be predictable:

- same location in similar dialogs;
- same command id for help action;
- same keyboard access;
- same accessible label pattern;
- same privacy policy for support bundles.

Help content is app-owned. Headless owns the slot and command contract.

## Clean Disk Requirements

Clean Disk issues:

- Full Disk Access missing;
- scan target disappeared;
- path permission denied;
- daemon disconnected;
- protocol incompatible;
- Trash unavailable;
- delete plan stale;
- export failed;
- support bundle redaction failed;
- remote mode read-only.

Rules:

- permission denied is not empty folder;
- stale delete plan points to revalidate action;
- destructive action failure produces receipt or issue detail;
- repair flow does not lose selected scan target.

## API Shape Sketch

```text
RecoverableIssue
  code
  class
  severity
  recoverability
  affectedScope
  messageKey
  suggestionKey
  retryAction
  repairAction
  helpAction
  focusTarget
  privacyClass
```

## Conformance Scenarios

- invalid form field has message and focus path;
- permission error shows repair action, not empty state;
- retryable export failure keeps selected export options;
- stale delete plan disables move-to-trash and offers revalidate;
- help action appears consistently in wizard steps;
- async background warning does not steal focus;
- redundant entry is avoided after retry;
- support action redacts sensitive data by default.

## Failure Catalog

- raw error string only;
- hiding permission denial as no results;
- retry loses all user input;
- focus jumps to toast with no action;
- repair action appears in different places per component;
- error message contains raw secret;
- destructive failure has no receipt or outcome;
- disabled action has no reason;
- same issue announced repeatedly;
- user must re-enter data after recoverable validation.

