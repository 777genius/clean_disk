# Component Profile - Foundations

## Status

Implementation profile for `collection`, `grid`, `tree`, and `viewport`
foundations.

## Purpose

Foundations are not visual components. They provide reusable mechanics for
public primitives.

## Collection Foundation

Owns:

- stable keys;
- selection;
- range math;
- disabled policy;
- typeahead text values;
- query-scope selection.

Must not own:

- rendering;
- backend fetch;
- product actions.

## Grid Foundation

Owns:

- row/cell/header focus model;
- 2D movement;
- tab policy;
- sort descriptors;
- column specs.

Must not own:

- product sorting for backend-owned data;
- cell rendering;
- viewport implementation.

## Tree Foundation

Owns:

- expansion state;
- depth facts;
- parent/child navigation;
- visible projection contract;
- lazy loading states.

Must not own:

- backend fetch in Clean Disk;
- path identity;
- product tree semantics.

## Viewport Foundation

Owns:

- visible range contract;
- scroll-to-target interface;
- adapter capability flags;
- test viewport adapter protocol.

Must not own:

- TreeGrid behavior;
- renderer visuals;
- product pagination.

## Conformance Gates

- collection identity survives reorder;
- grid focus moves predictably;
- tree collapse hides descendants;
- stale async tree responses ignored;
- viewport built count bounded;
- test adapter deterministic.

## Stop Rules

- Do not make foundation depend on component packages.
- Do not import Material.
- Do not leak Clean Disk DTOs.
