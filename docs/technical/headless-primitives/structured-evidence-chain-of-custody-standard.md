# Structured Evidence And Chain Of Custody Standard

## Status

Accepted direction for Headless. Complements provenance, receipts, audit
timeline, privacy, and cleanup safety standards. Not implemented yet.

## Source Standards

- W3C PROV Overview: https://www.w3.org/TR/prov-overview/
- W3C PROV Data Model: https://www.w3.org/TR/prov-dm/
- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 3.3.4 Error Prevention Legal Financial Data: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html
- WCAG 3.3.6 Error Prevention All: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-all.html

## Problem

Safety-critical UI often says "safe", "validated", "will free", "moved to
trash", or "skipped" without showing evidence. For Clean Disk this is dangerous:
destructive actions require proof of user intent, policy, identity validation,
capability state, operation outcomes, and receipt persistence. Public Headless
should not own that domain, but it should provide a structure to display and
export evidence without confusing it with ordinary help text.

Headless needs a structured evidence and chain-of-custody display contract.

## Decision Options

1. Treat evidence as long descriptions - 🎯 3   🛡️ 3   🧠 2, about
   80-200 LOC. Too verbose and not durable.
2. Add structured evidence descriptors - 🎯 9   🛡️ 10   🧠 7, about
   600-1500 LOC. Best fit.
3. Implement product audit authority in Headless - 🎯 1   🛡️ 3   🧠 10,
   about 3000-9000 LOC. Wrong layer.

Accepted: option 2.

## Accepted Contract

Headless displays evidence descriptors supplied by product layers:

```dart
final class REvidenceItem {
  final String evidenceId;
  final REvidenceKind kind;
  final String title;
  final String? summary;
  final REvidenceConfidence confidence;
  final String? sourceRef;
  final String? generatedAtIso8601;
  final RPrivacyClass privacyClass;
  final REvidenceExportPolicy exportPolicy;
}
```

Evidence chains group items:

```dart
final class REvidenceChain {
  final String chainId;
  final REvidenceChainKind kind;
  final List<REvidenceItem> items;
  final bool complete;
  final String? missingReasonCode;
}
```

## Evidence Kinds

```text
userIntent:
  command provenance, confirmation, scope

capability:
  permission, daemon, platform capability

identity:
  file identity or target validation

policy:
  rule or safety decision

measurement:
  size, count, estimate, confidence

sideEffect:
  action result

persistence:
  journal, receipt, export, support bundle durability

recovery:
  restore or repair path
```

## Chain Kinds

```text
deletePlan:
  evidence required before destructive action

operationReceipt:
  evidence after side effects

supportExport:
  evidence included in diagnostics

recommendation:
  evidence behind cleanup recommendation

permissionRepair:
  evidence behind access state
```

## Rules

- Headless displays evidence. It does not certify truth.
- Missing evidence is a first-class state.
- Evidence confidence is visible where decision-critical.
- Evidence items have privacy class.
- Export policy is explicit.
- User intent evidence is separate from selection.
- Side-effect evidence must link to receipt or operation id.
- Evidence chain can be incomplete and must say why.

## Clean Disk Requirements

Clean Disk evidence chains:

- DeletePlan validation chain;
- cleanup receipt chain;
- reclaim estimate chain;
- recommendation rule evidence;
- permission capability evidence;
- support bundle redaction evidence;
- remote/headless authorization evidence.

Destructive UI must render current validated evidence before action. Stale or
missing evidence disables side effects.

## Accessibility Rules

- Evidence summary is short.
- Full evidence is navigable by section or list.
- Missing evidence is announced as blocking state where relevant.
- Confidence is not color only.
- Evidence ids are copyable only if support-safe.
- Private evidence is redacted before display.

## Web Mapping

For web adapters:

- evidence chains can render as sections, lists, tables, or timelines depending
  on shape;
- machine-readable provenance is exported separately;
- `time` and `data` elements may expose safe timestamps and codes;
- hidden raw evidence is not stored in DOM attributes.

Flutter adapters should expose equivalent document and collection semantics.

## Testing Requirements

- Missing evidence blocks destructive action.
- Evidence chain renders complete/incomplete state.
- Private evidence is redacted in copy and semantics.
- Confidence is accessible.
- Side-effect item links to operation receipt.
- Export includes support-safe evidence only.
- Stale evidence is not accepted as current.

## Failure Catalog

- Delete confirmation shows "validated" without evidence.
- Selection item is treated as user intent evidence.
- Receipt exists visually but was not persisted.
- Evidence id contains raw path.
- Missing capability is hidden behind disabled button.
- Confidence only shown by color.
- Support export includes private evidence by default.

## Release Gates

- Evidence descriptors are separate from descriptions and logs.
- Clean Disk destructive flows require complete evidence chains.
- Missing evidence disables side effects.
- Evidence export policy is tested.
- Privacy redaction covers evidence ids, summaries, and source refs.

## Summary

Evidence is a structured product fact, not ordinary help text. Headless should
display evidence chains, confidence, missing reasons, privacy class, and export
policy while product layers own truth and safety.
