# Diagnostics And Error Message Standard

## Status

Standard for Headless diagnostics and user-facing developer errors.

## Purpose

Diagnostics should help developers fix setup mistakes without leaking product
data or encouraging bad workarounds.

## Diagnostic Categories

```text
missingRenderer
missingToken
invalidControllerOwnership
invalidSelectionKey
invalidSlotOverride
unsupportedCapability
accessibilityContractViolation
performanceBudgetViolation
privacyRedactionViolation
```

## Message Shape

```text
Problem:
Why it matters:
How to fix:
Docs:
Safe debug facts:
```

Example:

```text
Problem: RTreeGridRenderer capability was not found.
Why it matters: RTreeGrid owns behavior but needs a renderer capability for visuals.
How to fix: Wrap the subtree in HeadlessThemeProvider with a theme that provides RTreeGridRenderer.
Docs: headless-primitives/component-profile-treegrid.md
Safe debug facts: component=RTreeGrid, capability=RTreeGridRenderer
```

## Privacy Rules

Diagnostics must not include:

- raw file paths;
- row labels;
- search text;
- command target keys;
- daemon/session tokens.

Diagnostics may include:

- component name;
- capability type;
- enum value;
- count;
- package version;
- redacted id hash in debug only if explicitly enabled.

## Severity Levels

```text
debugHint
warning
recoverableError
contractViolation
fatalSetupError
```

Missing renderer is fatal setup error in debug/test. Production behavior can
show safe fallback only if explicitly configured.

## Conformance Checks

- missing renderer error contains fix path;
- invalid key error redacts key value;
- missing token error points to token name, not product data;
- accessibility violation includes standard reference;
- production diagnostics redacted.

## Stop Rules

- Do not print raw labels or paths.
- Do not suggest importing from `src/`.
- Do not silently swallow missing renderer in debug.
