# Credential Autofill Passkey And Form Purpose Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WCAG 1.3.5 Identify Input Purpose: https://www.w3.org/WAI/WCAG22/Understanding/identify-input-purpose.html
- WCAG 3.3.8 Accessible Authentication Minimum: https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html
- MDN HTML `autocomplete`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/autocomplete
- MDN password input: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/password
- MDN Web Authentication API: https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API
- MDN Passkeys: https://developer.mozilla.org/en-US/docs/Web/Security/Authentication/Passkeys
- MDN Credential Management API credential types: https://developer.mozilla.org/en-US/docs/Web/API/Credential_Management_API/Credential_types

## Problem

Autofill, password managers, passkeys, and input purpose metadata reduce memory,
typing, and transcription burden. Many design systems accidentally break them by
wrapping fields in non-semantic widgets, blocking paste, hiding labels, using
wrong autocomplete tokens, or splitting one-time codes into inaccessible boxes.

Headless form primitives need a first-class input purpose contract.

## Decision Options

1. Let apps pass raw HTML or platform attributes - 🎯 5   🛡️ 5   🧠 2, about
   40-120 LOC. Flexible but easy to misuse.
2. Add typed credential and input-purpose descriptors - 🎯 9   🛡️ 9   🧠 5,
   about 300-750 LOC. Best fit for reusable primitives.
3. Build a complete auth form library - 🎯 4   🛡️ 6   🧠 9, about 1500-3500
   LOC. Too broad for Headless.

Accepted: option 2.

## Accepted Contract

Headless text inputs can declare purpose:

```dart
final class RInputPurposeDescriptor {
  final RInputPurpose purpose;
  final String? htmlAutocompleteToken;
  final bool allowsPaste;
  final bool allowsAutofill;
  final bool allowsPasswordManager;
  final bool allowsOneTimeCodeAutofill;
  final bool allowsPasskeyConditionalUi;
}
```

The web adapter maps this to HTML attributes. Native adapters map to platform
content types where available.

## Rules

- Username, email, current password, new password, and one-time code fields use
  explicit typed purpose.
- Passkey UI is progressive enhancement, not the only authentication path unless
  product policy has validated that environment.
- One-time-code controls support pasting the full code.
- Password visibility toggles have accessible names and do not alter form
  purpose.
- Labels remain visible or programmatically associated.
- Autocomplete values are fixed tokens, not localized strings.
- Custom renderers cannot replace real input semantics with decorative text.

## Clean Disk Requirements

Clean Disk does not need account login for local MVP, but this matters for:

- remote/headless admin login;
- pairing token fields;
- recovery code fields;
- enterprise identity provider wrappers;
- support portal integration;
- future passkey-based remote access.

The pairing token field should be modeled as sensitive one-time input with paste
enabled, not as a generic search field.

## Passkey Rules

- Passkey creation and authentication use browser or platform mediation.
- The UI explains fallback and recovery.
- Conditional UI does not hide the primary label or block keyboard operation.
- Passkey errors map to recoverable product states.
- Passkey prompts are not triggered on render.
- Passkey availability is capability state, not identity state.

## Testing Requirements

- Web adapter emits expected autocomplete tokens.
- One-time-code field accepts full paste.
- Password manager simulation does not break layout.
- Passkey capability absent path remains usable.
- Visible label and accessible name remain aligned.
- Text scaling and high contrast preserve field purpose indicators.

## Failure Catalog

- `autocomplete="off"` used to block password managers.
- Six code boxes accept only one pasted digit.
- Passkey button appears but keyboard users cannot trigger fallback.
- Custom field has visual label but no programmatic label.
- Autocomplete token is translated.
- Password visibility toggle is announced only as "button".

## Release Gates

- Credential-like fields require an input purpose descriptor.
- Web adapter tests cover autocomplete and paste.
- Passkey support remains progressive until compatibility evidence exists.
- Auth forms cannot ship with paste-blocking behavior.

## Summary

Credential UX is accessibility UX. Headless should expose typed input purpose so
apps get autofill, password managers, passkeys, and one-time-code flows without
fragile ad hoc attributes.
