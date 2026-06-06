# Policy Feature Flag And Evaluation Standard

## Status

Accepted as a Headless runtime interoperability standard. Not implemented yet.

## Source Standards

- MDN Permissions Policy: https://developer.mozilla.org/en-US/docs/Web/HTTP/Permissions_Policy
- MDN FeaturePolicy: https://developer.mozilla.org/en-US/docs/Web/API/FeaturePolicy
- OpenFeature Evaluation Context: https://openfeature.dev/docs/reference/concepts/evaluation-context/
- WCAG 3.2.3 Consistent Navigation: https://www.w3.org/WAI/WCAG22/Understanding/consistent-navigation.html
- WCAG 3.2.4 Consistent Identification: https://www.w3.org/WAI/WCAG22/Understanding/consistent-identification.html
- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/

## Scope

This standard defines how Headless primitives consume policy and feature flag
decisions.

It applies to:

- experimental primitives;
- renderer adapters;
- destructive commands;
- remote mode;
- chart adapters;
- accessibility fallbacks;
- telemetry sinks;
- exports;
- keyboard shortcuts;
- personalization features.

It does not choose a feature flag vendor. It defines the decision contract that
Headless can safely consume.

## Decision Options

Option A: Conditional code in widgets - 🎯 3   🛡️ 3   🧠 2, about
100-300 LOC.

- Fast.
- Inconsistent, untraceable, and unsafe for accessibility and destructive
  actions.

Option B: App-only feature flag wrapper - 🎯 6   🛡️ 6   🧠 4, about
300-800 LOC.

- Good product pattern.
- Headless still needs policy facts for renderers and command resolution.

Option C: Typed policy evaluation result - 🎯 9   🛡️ 9   🧠 7, about
900-1800 LOC.

- Accepted direction.
- Feature state includes reason, consistency group, privacy class, and safety
  effect.

## Accepted Direction

Headless should consume `PolicyDecision`.

Decision includes:

- policy id;
- evaluated value;
- reason;
- source;
- consistency group;
- scope;
- expiry;
- privacy class;
- safety impact;
- fallback;
- audit class.

Headless does not evaluate targeting with user secrets. App policy layer does.

## Policy Classes

Classes:

- `visualExperiment`;
- `accessibilityFallback`;
- `rendererCapability`;
- `destructiveAuthority`;
- `remoteMode`;
- `telemetryConsent`;
- `exportPermission`;
- `experimentalPrimitive`;
- `compatibilityGate`;
- `enterprisePolicy`.

Unknown policy fails closed when safety or privacy impact is high.

## Consistency Rules

Feature flags must not make navigation or commands inconsistent without user
reason.

Rules:

- same command id keeps same meaning;
- destructive command policy is consistent across menu, toolbar, shortcut, and
  dialog;
- route layout experiments preserve focus and headings;
- accessibility fallback cannot be randomly disabled for one user mid-flow;
- policy changes during operation wait for safe boundary.

## Privacy Rules

Policy context must not include:

- raw path;
- raw query;
- daemon token;
- clipboard content;
- file names;
- cleanup target list.

Use coarse, app-approved context facts only.

## Clean Disk Requirements

Clean Disk policy decisions:

- remote read-only mode;
- cleanup enabled;
- telemetry disabled;
- support bundle export profile;
- optional disk map adapter;
- experimental TreeGrid renderer;
- accessibility fallback enabled;
- destructive shortcut disabled.

Rules:

- feature flag cannot bypass delete validation.
- unknown remote cleanup policy disables cleanup.
- visual experiments do not change command authority.

## API Shape Sketch

```text
PolicyDecision
  id
  value
  reason
  source
  scope
  consistencyGroup
  safetyImpact
  privacyClass
  expiresAt
  fallback

PolicyResolver
  evaluate(policyId, context)
  explain(decision)
```

## Conformance Scenarios

- toolbar and menu share same destructive policy decision;
- unknown cleanup flag disables cleanup;
- visual experiment preserves command ids;
- telemetry policy blocks instrumentation sink;
- policy context has no raw path;
- policy change during scan waits for safe boundary;
- accessibility fallback is not disabled by random experiment;
- remote mode policy updates disabled reasons.

## Failure Catalog

- feature flag hides accessibility repair action;
- destructive action enabled by stale flag;
- policy context leaks user path;
- menu and shortcut disagree because flags evaluated separately;
- experiment changes command meaning;
- unknown policy treated as allow;
- telemetry flag evaluated inside renderer;
- policy changes while confirmation dialog open;
- no reason code for disabled feature;
- compatibility gate bypassed by visual adapter.

