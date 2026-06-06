# Accessibility Exception Waiver And Risk Register Standard

## Status

Accepted as a Headless quality-operations standard. Not implemented yet.

## Source Standards

- WCAG 2.2 Understanding Conformance: https://www.w3.org/WAI/WCAG22/Understanding/conformance.html
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/

## Scope

This standard defines how Headless records temporary accessibility exceptions,
known gaps, waivers, risk owners, expiry dates, and mitigation plans.

It applies to:

- adapter gaps;
- platform accessibility bugs;
- incomplete renderer support;
- temporary keyboard gaps;
- target-size exceptions;
- contrast exceptions;
- screen reader incompatibilities;
- virtualization limitations;
- third-party renderer limitations.

It does not weaken conformance. It prevents hidden exceptions from becoming
permanent undocumented behavior.

## Decision Options

Option A: Mention exceptions in comments - 🎯 2   🛡️ 2   🧠 1, about
50-150 LOC.

- Easy.
- Exceptions disappear and users get surprised.

Option B: Track exceptions in issue tracker only - 🎯 5   🛡️ 5   🧠 3,
about 150-500 LOC process cost.

- Better for maintainers.
- Not visible to conformance, docs, or release gates.

Option C: Versioned risk register tied to conformance evidence - 🎯 9
🛡️ 9   🧠 6, about 700-1400 LOC.

- Accepted direction.
- Exceptions have owner, expiry, mitigation, and public claim impact.
- Release gates can block stale or high-risk waivers.

## Accepted Direction

Headless should maintain an `AccessibilityExceptionRegister`.

Each exception includes:

- stable id;
- primitive;
- adapter;
- affected standard;
- user impact;
- severity;
- scope;
- mitigation;
- owner;
- expiry;
- public documentation status;
- conformance impact;
- privacy impact.

## Exception Classes

Classes:

- `adapterLimitation`;
- `platformBug`;
- `assistiveTechnologyGap`;
- `temporaryImplementationGap`;
- `targetSizeException`;
- `contrastException`;
- `keyboardException`;
- `semanticMappingException`;
- `performanceTradeoff`;
- `privacyRedactionConstraint`.

Each class has default review requirements.

## Waiver Rules

Waiver may be accepted only when:

- user impact is understood;
- safer alternative is provided where practical;
- exception is documented;
- owner is assigned;
- expiry or review date exists;
- release claim is downgraded if needed;
- conformance test records the exception.

High-severity destructive-flow exceptions block release.

## Mitigation Rules

Mitigations can include:

- alternate accessible path;
- visible warning;
- adapter degradation claim;
- documented unsupported platform;
- feature disablement;
- reduced scope;
- manual screen reader guidance;
- issue linked to upstream platform bug.

Mitigation is not a substitute for fixing critical defects.

## Clean Disk Requirements

Clean Disk exceptions must be explicit for:

- TreeGrid web semantic gaps;
- chart adapter accessibility fallback gaps;
- compact target-size exceptions;
- platform-specific screen reader behavior;
- virtualized row announcement limitations;
- optional renderer degradation.

Rules:

- cleanup confirmation cannot have active accessibility waiver.
- move-to-trash cannot rely on unreviewed target-size exception.
- disk map can degrade if table fallback is accessible.

## API Shape Sketch

```text
AccessibilityException
  id
  primitive
  adapter
  standardRef
  severity
  userImpact
  mitigation
  owner
  expiresAt
  claimImpact
  evidenceRefs

ExceptionGate
  allow(exception)
  blockRelease(reason)
  requireReview(exception)
```

## Conformance Scenarios

- target-size exception has alternate keyboard command;
- adapter limitation downgrades public claim;
- expired exception blocks release;
- critical cleanup-flow exception blocks release;
- platform bug has external evidence and workaround;
- exception appears in conformance report;
- support docs do not claim unsupported behavior;
- privacy constraint is not used to hide user-facing failure.

## Failure Catalog

- exception hidden in source comment;
- no owner or expiry;
- waiver used for destructive action path;
- public docs claim full support despite exception;
- target-size exception has no alternate path;
- adapter gap not linked to manifest;
- expired exception ignored;
- same waiver copied across releases without review;
- support cannot explain known limitation;
- exception register contains raw user data.

