# Community Documentation Template

## Status

Template for public Headless primitive documentation.

## Purpose

Every public primitive should have a consistent documentation structure.

## Required Sections

```text
Purpose
When to use
When not to use
Anatomy
Basic usage
Controlled usage
Keyboard interaction
Accessibility notes
Renderer capabilities
Slots and customization
Tokens
State model
Conformance
Known limitations
Migration notes
```

## Accessibility Section Template

Include:

- standards used;
- semantic roles or Flutter semantic facts;
- keyboard behavior table;
- focus management;
- disabled behavior;
- screen-reader limitations;
- test evidence status.

## Conformance Section Template

```text
Spec version:
Component package:
Renderer package:
Test commands:
Keyboard evidence:
Semantics evidence:
Renderer boundary evidence:
Performance evidence:
Known gaps:
```

## Example Policy

Examples must:

- avoid real user data;
- use stable ids separate from labels;
- include keyboard path;
- include controlled mode where relevant;
- show missing renderer setup.

Examples must not:

- import from `src/`;
- use localized labels as ids;
- call product callbacks from renderer;
- show pointer-only interaction.

## LLM.txt Policy

Each package should include:

- purpose;
- non-goals;
- invariants;
- correct usage;
- anti-patterns;
- public imports;
- conformance status.

## Stop Rules

- Do not publish component docs without keyboard section.
- Do not claim accessibility without evidence status.
- Do not omit known limitations for beta components.
