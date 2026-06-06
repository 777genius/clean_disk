# Spec MUST SHOULD MAY Clauses

## Status

Spec-level normative contract.

## Primary References

- RFC 2119 key words:
  https://www.ietf.org/rfc/rfc2119.txt
- WAI-ARIA APG introduction:
  https://www.w3.org/WAI/ARIA/apg/about/introduction/
- Headless conformance docs in the Headless repository.

## Purpose

This file translates the Headless primitive work into enforceable language.
`MUST`, `SHOULD`, and `MAY` are used with their RFC 2119 meanings.

## Universal MUST

- A component MUST own behavior, keyboard handling, state machine, and root
  accessibility.
- A renderer MUST own visuals only.
- A renderer MUST NOT call application product callbacks directly.
- A component MUST expose a clear missing-renderer diagnostic.
- Public component APIs MUST avoid imports from `src/`.
- Stable identities MUST NOT be localized labels or visible indexes.
- Controlled mode MUST NOT be overwritten by internal state.
- External controllers MUST NOT be disposed by the component.
- Keyboard operation MUST exist for every essential interaction.
- Disabled behavior MUST specify focus, selection, and activation separately.
- Product data MUST stay outside Headless primitives.

## Universal SHOULD

- Complex components SHOULD use pure reducer plus typed effects.
- Components SHOULD expose immutable state snapshots.
- Components SHOULD provide conformance fixtures.
- Components SHOULD support subtree renderer capability overrides.
- Components SHOULD expose semantic facts rather than raw ARIA fields.
- Dense components SHOULD provide performance/debug counters in test mode.
- Documentation SHOULD include keyboard maps and accessibility notes.

## Universal MAY

- Components MAY provide convenience uncontrolled state.
- Components MAY provide test-only adapters from a test package.
- Presets MAY provide opinionated visuals if renderer contracts stay stable.
- Web adapters MAY enhance Flutter Semantics if measurement proves a gap.

## Component-Specific MUST

TreeGrid:

- MUST keep focus and selection independent.
- MUST NOT require the full tree in Flutter.
- MUST expose row/column count and index facts when known.

Dialog:

- MUST trap focus while modal.
- MUST restore focus on close when target is still valid.
- MUST use least destructive focus by default for destructive confirmation.

ContextMenu:

- MUST support keyboard invocation.
- MUST restore focus to logical invoker.
- MUST use stable command ids.

SplitPane:

- MUST support keyboard resizing.
- MUST clamp value to min/max.
- MUST expose adjustable value semantics where possible.

Tooltip:

- MUST NOT contain focusable interactive descendants.
- MUST keep focus on trigger.

StatusRegion:

- MUST NOT move focus on update.
- MUST coalesce noisy progress where configured.

## Stability Rule

A primitive MUST NOT be marked stable until all applicable MUST clauses have
conformance evidence or documented accepted exceptions.
