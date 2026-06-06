# Assistive Technology Workaround Governance Standard

## Status

Accepted as a Headless compatibility governance standard. Not implemented yet.

## Source Standards

- WCAG 2.2 Conformance: https://www.w3.org/WAI/WCAG22/Understanding/conformance.html
- Accessibility Supported Technology Policy: accessibility-supported-technology-policy-standard.md
- ARIA-AT: https://w3c.github.io/aria-at/
- MDN browser compatibility data: https://github.com/mdn/browser-compat-data
- MDN Reporting API: https://developer.mozilla.org/en-US/docs/Web/API/Reporting_API
- Semantic Versioning: https://semver.org/

## Scope

This standard defines how Headless handles browser, OS, Flutter, and assistive
technology bugs without turning the core library into a pile of invisible
hacks.

It applies to:

- screen reader-specific workarounds;
- browser-specific semantics workarounds;
- Flutter engine behavior changes;
- platform accessibility API gaps;
- feature flags;
- release notes;
- deprecation of hacks.

It does not permit product-specific hacks in core Headless.

## Decision Options

Option A: Patch every bug inline - 🎯 3   🛡️ 3   🧠 2, about 100-500 LOC
per issue.

- Quick.
- Impossible to maintain honestly.

Option B: Put workarounds in adapter docs only - 🎯 5   🛡️ 5   🧠 3,
about 200-600 LOC.

- Documents reality.
- Runtime behavior remains hard to audit.

Option C: Versioned workaround registry with expiry and evidence - 🎯 9
🛡️ 9   🧠 7, about 900-1800 LOC.

- Accepted direction.
- Every workaround has scope, reason, test, removal condition, and owner.

## Accepted Direction

Headless should define `AssistiveTechnologyWorkaround`.

Workaround fields:

- id;
- affected stack;
- primitive;
- symptom;
- root cause if known;
- workaround behavior;
- feature flag;
- risk;
- evidence;
- owner;
- introduced version;
- expiry or review date;
- removal condition.

## Workaround Classes

Classes:

- `announcementTiming`;
- `focusEvent`;
- `roleMapping`;
- `stateMapping`;
- `relationshipMapping`;
- `keyboardBehavior`;
- `browserRendering`;
- `flutterEngine`;
- `platformApi`;
- `unknownExternal`.

Unknown external workarounds require stricter review.

## Guardrails

Rules:

- workaround is scoped to exact stack facts where possible;
- workaround cannot weaken keyboard behavior;
- workaround cannot expose sensitive data;
- workaround cannot change public API silently;
- workaround must have a test or manual scenario;
- workaround must have a removal strategy.

No workaround is allowed just because one screen reader phrase looks nicer.

## Clean Disk Requirements

Clean Disk-specific workaround examples:

- VoiceOver progress announcement throttling;
- Windows screen reader row count fallback;
- Flutter web semantics tree debug gap;
- platform dialog naming issue;
- virtualized TreeTable active descendant fallback.

Cleanup safety rule:

- workaround cannot bypass delete confirmation or validation.

## API Shape Sketch

```text
AssistiveTechnologyWorkaround
  id
  affectedStack
  primitiveId
  symptom
  workaround
  flag
  evidenceRefs
  introducedIn
  reviewBy
  removalCondition
```

## Conformance Scenarios

Required scenarios:

- workaround applies only to matching stack;
- workaround appears in evidence report;
- expired workaround blocks release;
- feature flag can disable risky workaround;
- upstream fix removes workaround in next major or minor release;
- cleanup workflow remains safe when workaround is disabled.

## Failure Catalog

Failures:

- browser sniffing without evidence;
- workaround changes semantics for all platforms;
- stale hack remains after upstream fix;
- manual screen reader note has no stack version;
- workaround hides conformance failure;
- product-specific raw path handling lands in core.

## Release Gates

Release gate:

- all workarounds are registered;
- no expired workaround in release build;
- high-risk workaround requires manual AT evidence;
- public limitation notes mention user-visible behavior;
- workaround removal is treated as compatibility change.

