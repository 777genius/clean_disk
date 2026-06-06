# Spec To Code Generation Readiness

## Status

Future direction. Not required for MVP.

## Purpose

If Headless becomes a standard, some artifacts can be generated from specs:
test skeletons, LLM docs, conformance reports, and renderer stubs. This file
defines what must be structured before generation is safe.

## Candidate Generated Artifacts

- conformance scenario skeletons;
- component README tables;
- keyboard reference tables;
- renderer capability stubs;
- token resolver stubs;
- `LLM.txt` summaries;
- compatibility report templates.

## Required Structured Inputs

```text
ComponentSpec
  name
  anatomy parts
  states
  commands
  effects
  semantic facts
  keyboard map
  slots
  tokens
  conformance scenarios
```

## Benefits

- fewer doc/test mismatches;
- easier third-party renderer startup;
- better LLM understanding;
- conformance reports become repeatable.

## Risks

- generated API can freeze weak design too early;
- generator can hide architectural mistakes;
- generated docs can drift if not verified;
- over-structured spec can slow early iteration.

## Recommendation

Use generation only after the first manual implementation proves contracts.

Best first generators:

1. conformance report template;
2. keyboard table from command matrix;
3. renderer stub with missing-token diagnostics.

## Stop Rules

- Do not generate production component behavior.
- Do not generate stable API before prototype.
- Do not treat generated docs as evidence without tests.
