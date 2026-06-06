# Technical Identifier And Error Code Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN `code`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/code
- MDN `data`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/data
- MDN `output`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/output
- WCAG 3.3.1 Error Identification: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 3.3.3 Error Suggestion: https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- WCAG 3.1.6 Pronunciation: https://www.w3.org/WAI/WCAG22/Understanding/pronunciation.html

## Problem

Public UI kits often localize or style technical identifiers until they stop
being stable. Disk tools and daemon UIs need stable command ids, policy codes,
protocol keys, issue codes, node refs, error ids, event ids, and operation ids.
These values must be copyable, pronounceable where needed, redaction-safe,
machine-readable, and separate from user-facing labels.

Headless needs an identifier and error-code display contract.

## Decision Options

1. Use strings and style them as monospace - 🎯 4   🛡️ 4   🧠 1, about
   20-80 LOC. Too weak for localization, copy, telemetry, and support.
2. Use typed technical text tokens - 🎯 9   🛡️ 9   🧠 5, about
   350-850 LOC. Best fit.
3. Build a full diagnostic language runtime - 🎯 3   🛡️ 5   🧠 10, about
   2500-6000 LOC. Outside Headless scope.

Accepted: option 2.

## Accepted Contract

Headless receives typed technical tokens:

```dart
final class RTechnicalToken {
  final String stableValue;
  final String? displayValue;
  final RTechnicalTokenKind kind;
  final RCopyPolicy copyPolicy;
  final RPrivacyClass privacyClass;
  final String? pronunciationHint;
  final String? definitionId;
  final bool localizedDisplayAllowed;
}
```

`stableValue` is not automatically visible. The product decides whether a code
should be shown, copied, hidden, or summarized.

## Token Kinds

```text
commandId:
  stable app command identity

policyCode:
  safety or authorization policy identity

protocolKey:
  DTO field, enum key, or schema identifier

errorCode:
  supportable failure code

operationId:
  scan, cleanup, export, receipt, or journal id

nodeReference:
  opaque reference, never raw path

diagnosticTag:
  privacy-reviewed support tag
```

## Rules

- Stable ids are not localized.
- Display labels can be localized.
- Copy action should copy exactly the support-safe token.
- Error message text must not be the only error identity.
- Error code alone is not enough. Provide explanation and next action.
- Unknown codes fail as recoverable unsupported state, not silent success.
- Technical tokens should have definition links where user-facing.
- Pronunciation hints are allowed for ambiguous codes.
- Tokens must not encode private paths, usernames, emails, or daemon secrets.

## Error Message Shape

Error surfaces should expose:

- short localized title;
- user-facing explanation;
- stable error code;
- affected component or capability;
- severity;
- recovery action;
- retry policy;
- support-safe copy bundle;
- privacy class.

## Clean Disk Requirements

Clean Disk tokens include:

- daemon capability codes;
- scan issue codes;
- skipped item reason codes;
- cleanup policy codes;
- DeletePlan ids;
- snapshot ids;
- node refs;
- query cursors;
- operation ids;
- receipt ids.

None of these are translated. The UI may show translated labels around them.

## Accessibility Rules

- Error code is reachable from the error surface.
- Screen readers receive a concise error summary, not a raw JSON blob.
- Repeated status updates should announce state changes, not the same code
  continuously.
- Braille output can use compact code plus user-controlled details.
- Voice command labels should target localized action labels, not opaque ids.

## Web Mapping

For web:

- `code` can represent inline technical identifiers.
- `data` can pair visible labels with machine-readable values where useful.
- `output` can identify generated result values when part of a form or command
  result.
- status changes follow WCAG status-message expectations.

Flutter adapters should mirror the same semantics through `Semantics`,
copy-policy actions, and testable technical-token snapshots.

## Testing Requirements

- Locale change does not change stable ids.
- Copy support bundle excludes private identifiers.
- Unknown error code renders as unsupported recoverable state.
- Error code is discoverable without reading logs.
- Screen-reader announcement has title and recovery action.
- Token snapshots contain privacy class.
- Long codes wrap or truncate without losing copy value.

## Failure Catalog

- Localized command label used as command id.
- Error code hidden in logs only.
- Opaque node ref contains raw path.
- Copy button copies daemon token with error code.
- Unknown policy code defaults to allow.
- Screen reader announces repeated UUIDs during progress.

## Release Gates

- Public primitives expose typed technical-token slots.
- Error surfaces include code, explanation, and recovery action.
- Token copy policy is explicit.
- Clean Disk protocol ids stay outside localized text.
- Unknown token kinds fail closed for risky commands.

## Summary

Identifiers and error codes are not ordinary text. Headless should render typed,
copy-safe, localized-around technical tokens while keeping stable identity
separate from display strings.
