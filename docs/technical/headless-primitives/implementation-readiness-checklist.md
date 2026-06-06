# Headless Primitive Implementation Readiness Checklist

## Status

Gate checklist before implementation starts.

## Purpose

Use this checklist before implementing or stabilizing any complex Headless
primitive.

## Required Inputs

- RFC exists.
- Deep-dive exists for relevant behavior.
- State machine documented.
- Keyboard map documented.
- Semantic facts documented.
- Renderer boundary documented.
- Conformance tests listed.
- Stop rules listed.

## Universal Gates

Architecture:

- component package does not depend on other component packages;
- reusable mechanics live in foundation;
- renderer contracts live in contracts package;
- preset implementation lives in Material/Cupertino package;
- app-specific behavior stays outside Headless.

State:

- controlled/uncontrolled rules documented;
- external controllers are not disposed;
- state snapshots are immutable;
- stale async response policy exists;
- disabled states are reasoned, not just boolean.

Accessibility:

- keyboard-only path exists;
- semantic role/state/value facts exist;
- focus restoration is specified;
- tooltip/status/dialog/menu roles are not conflated;
- visible label is contained in accessible name.

Performance:

- large fixture exists for dense components;
- rebuild budget exists;
- viewport built count can be asserted;
- semantics node count can be asserted;
- progress/status coalescing policy exists.

Privacy:

- diagnostics avoid raw labels/paths;
- command contexts are redacted by default;
- conformance fixtures use synthetic data.

## Primitive-Specific Gates

TreeGrid:

- collection/grid/tree foundations ready or explicitly stubbed;
- viewport adapter boundary ready;
- row/cell/header semantics documented;
- rows-first mode conformance ready.

Dialog:

- focus trap ready;
- initial focus policy ready;
- destructive confirmation policy ready;
- nested stack policy ready.

ContextMenu:

- menu stack ready;
- Shift + F10 and context key supported;
- submenu restore ready;
- command identity separate from label.

SplitPane:

- keyboard resize ready;
- separator semantics ready;
- min/max/collapse policy ready.

Tooltip/StatusRegion:

- tooltip has no interactive content;
- status does not move focus;
- announcement coalescing ready.

## Stop Rule

Do not start production implementation of a primitive if its readiness checklist
fails on architecture, accessibility, or renderer boundary.
