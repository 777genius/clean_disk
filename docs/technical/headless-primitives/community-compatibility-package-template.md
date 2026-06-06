# Community Compatibility Package Template

## Status

Template for third-party packages that want to claim Headless compatibility.

## Package Requirements

```text
pubspec.yaml
README.md
CHANGELOG.md
CONFORMANCE_REPORT.md
LLM.txt
test/
```

## Compatibility Statement

```text
Compatibility: conforms to Headless Component Spec v1 for <component>.
Scope: renderer | component | adapter | preset.
Core versions:
Renderer capabilities:
Known limitations:
```

## Required Tests

Renderer package:

- capability lookup;
- subtree override;
- token resolution;
- disabled state visual;
- focus state visual;
- no root behavior ownership.

Component package:

- keyboard;
- focus;
- semantics;
- controlled state;
- disabled policy;
- renderer boundary.

Adapter package:

- capability detection;
- degraded mode;
- platform fallback;
- no product workflow ownership.

## Version Pinning

Compatibility report must specify:

- Headless spec version;
- core package versions;
- tested Flutter version;
- tested platforms;
- date.

## Bad Claims

Do not say:

- "fully accessible" without AT evidence;
- "Headless-compatible" without conformance report;
- "drop-in replacement" if keyboard/semantics differ;
- "stable" if API is experimental.

## Stop Rules

- Do not accept compatibility claims without test evidence.
- Do not allow renderer-only packages to claim component conformance.
- Do not let third-party docs import Headless internals.
