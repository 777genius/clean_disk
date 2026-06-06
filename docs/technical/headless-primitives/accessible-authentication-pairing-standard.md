# Accessible Authentication And Pairing Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WCAG 3.3.8 Accessible Authentication Minimum: https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html
- WCAG 3.3.9 Accessible Authentication Enhanced: https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-enhanced.html
- WCAG 3.3.7 Redundant Entry: https://www.w3.org/WAI/WCAG22/Understanding/redundant-entry.html
- WCAG 2.2.1 Timing Adjustable: https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html
- WCAG 3.3.1 Error Identification: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 3.3.3 Error Suggestion: https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html
- MDN Web Authentication API: https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API
- MDN Passkeys: https://developer.mozilla.org/en-US/docs/Web/Security/Authentication/Passkeys

## Problem

Headless primitives increasingly sit inside products with login, local daemon
pairing, device authorization, remote admin links, and destructive command
approval. Authentication UI often fails accessibility when it requires users to
memorize, transcribe, solve puzzles, race a timeout, or repeat data that the
system already has.

For Clean Disk, pairing the web UI to a local daemon or remote server must not
become a hidden CAPTCHA-style obstacle.

## Decision Options

1. Treat authentication as product-only UI - 🎯 4   🛡️ 4   🧠 2, about 0-80
   LOC. Too weak for a reusable UI kit.
2. Add authentication and pairing primitives with accessibility constraints -
   🎯 9   🛡️ 9   🧠 6, about 350-900 LOC. Best fit for Headless.
3. Build a full identity provider UI framework - 🎯 3   🛡️ 6   🧠 10, about
   3000-8000 LOC. Not Headless responsibility.

Accepted: option 2.

## Accepted Contract

Headless exposes an authentication challenge model:

```dart
final class RAuthenticationChallenge {
  final String challengeId;
  final RAuthenticationKind kind;
  final bool requiresCognitiveFunctionTest;
  final bool supportsPaste;
  final bool supportsAutofill;
  final bool supportsPasswordManager;
  final bool supportsPasskey;
  final bool hasNonCognitiveAlternative;
  final Duration? expiresIn;
  final RAuthenticationRisk risk;
}
```

The product owns identity. Headless owns interaction constraints and evidence.

## Rules

- Do not require memorization, transcription, puzzle solving, or calculation
  without an accessible alternative.
- One-time codes support paste and autofill where the platform allows it.
- Password fields do not block paste or password managers.
- QR pairing has a text fallback and copyable pairing URL or code where safe.
- Time-limited pairing warns before expiry and preserves entered data where
  feasible.
- Failed authentication explains recovery without exposing secrets.
- Re-auth for destructive actions requires fresh validation but does not force
  inaccessible cognitive tests.

## Clean Disk Requirements

Clean Disk may need this for:

- daemon-served web UI pairing;
- remote/headless read-only access;
- remote destructive cleanup approval;
- support bundle export authorization;
- multi-window session refresh;
- admin policy unlock.

MVP can use a simple local token, but the UI contract must still support paste,
copy, non-timed recovery, and screen-reader-readable status.

## Pairing UX Contract

Pairing UI exposes:

- device or daemon identity;
- origin and host being paired;
- capability scope;
- expiry time if any;
- copyable token or link when policy allows;
- retry and cancel;
- support for keyboard, switch access, screen readers, and voice control;
- clear failure state for denied, expired, mismatched, and revoked sessions.

## Security Boundary

- Headless never stores secrets in component state snapshots.
- Tokens are redacted in logs and support evidence.
- Visible pairing codes are treated as sensitive.
- Copy-to-clipboard is explicit and has expiry copy text.
- Authentication state is not inferred from localized labels.

## Testing Requirements

- Paste works in token and one-time-code fields.
- Password manager and autofill attributes are not blocked.
- Timed challenges can be extended or safely retried.
- QR-only pairing has fallback.
- Screen-reader transcript does not leak full token unless the focused field
  intentionally reveals it.
- Destructive re-auth fails closed on timeout.

## Failure Catalog

- Token field blocks paste.
- Pairing code expires while switch user is scanning with no warning.
- QR pairing has no keyboard-accessible fallback.
- CAPTCHA appears after repeated failure with no alternative.
- Re-auth clears selected cleanup plan without explanation.
- Support logs include the local daemon token.

## Release Gates

- Any auth or pairing primitive declares cognitive-test status.
- Any challenge with timeout has timing and recovery policy.
- Sensitive values are redacted in snapshots and diagnostics.
- Clean Disk remote cleanup cannot ship without this contract implemented.

## Summary

Authentication is part of accessibility. Headless must make pairing and auth
flows paste-friendly, recoverable, screen-reader-friendly, and safe by default.
