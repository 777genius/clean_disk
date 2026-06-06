# Validation Error And Recovery Standard

## Status

Implementation standard for validation errors, invalid state, error messages,
recovery commands, and form-like primitive behavior.

## Purpose

Headless primitives will eventually include editable cells, filter builders,
rename fields, confirmation forms, command inputs, and settings controls. Error
state must be accessible, recoverable, and separate from product business
errors.

## Standards And References

- MDN `aria-invalid`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-invalid
- MDN `aria-errormessage`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-errormessage
- WCAG 2.2:
  https://www.w3.org/TR/WCAG22/
- Flutter form validation:
  https://docs.flutter.dev/cookbook/forms/validation
- Flutter accessibility testing:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing
- Flutter `SemanticsValidationResult`:
  https://api.flutter.dev/flutter/dart-ui/SemanticsValidationResult.html

## Core Rule

Validation state is attached to an input/editing scope or command target. It is
not a renderer color.

```text
draft input
  -> validation request
  -> validation result
  -> error facts
  -> recovery command
```

## Error Taxonomy

```text
required
format
range
conflict
permission
stale
unsafe
unsupported
serverRejected
unknown
```

Every error fact declares:

- target key;
- severity;
- recoverability;
- user-facing message key;
- diagnostic category;
- privacy class;
- focus policy;
- live announcement policy.

## Timing Rules

Do not mark empty required field invalid while user is still typing unless the
user has attempted submit or left the field by policy.

Allowed validation moments:

- on submit;
- on blur;
- on explicit check;
- after debounce;
- after async result;
- before destructive confirmation.

## Error Message Rules

Error message must:

- be visible or reachable;
- describe what is wrong;
- suggest correction where possible;
- be linked to target in web adapter where applicable;
- not be color-only;
- not expose private debug data.

For web adapter:

- invalid target can map to `aria-invalid`;
- error message can map to `aria-errormessage`;
- description can also use `aria-describedby` if broader context is needed;
- live region may announce newly shown errors.

## Focus Recovery Rules

On failed submit:

1. preserve user input;
2. move focus to first invalid target or error summary by policy;
3. expose count of errors if multiple;
4. keep keyboard path to correction;
5. do not close dialog unless failure is non-recoverable.

For inline grid editing:

- keep focus in editor if correction is needed;
- Escape can cancel edit by policy;
- stale validation result is ignored if draft changed.

## Async Validation Rules

Async validation must include:

- request id;
- input version;
- cancellation;
- late response guard;
- busy state;
- retry policy.

Late validation response cannot overwrite newer input.

## Clean Disk Examples

- rename cleanup rule profile;
- filter expression syntax;
- custom scan target path;
- confirmation phrase if ever used;
- remote token/pairing code;
- export filename.

For delete confirmation, validation failure disables destructive action until a
current validated plan exists.

## Required Tests

Automated:

- invalid state has message;
- message linked to target in web adapter;
- failed submit focuses recovery target;
- async late validation ignored;
- message content absent from diagnostics if private;
- color-only error fails renderer test.

Manual:

- screen reader hears invalid field and error;
- keyboard user can correct error;
- multiple-error summary path;
- text scaling does not overlap error text.

## Stop Rules

- Do not show invalid state only by red border.
- Do not validate required empty draft before user action by default.
- Do not close recoverable dialog on validation error.
- Do not log invalid user input.
- Do not let stale validation enable destructive command.
