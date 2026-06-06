# Semantic Identity And Reference Stability Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- MDN ARIA reference: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference
- MDN `aria-activedescendant`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-activedescendant
- MDN `aria-controls`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-controls
- MDN `aria-owns`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-owns
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html

## Scope

This standard defines stable identity rules for Headless primitives.

It applies to:

- component ids;
- row ids;
- column ids;
- option ids;
- command ids;
- focus targets;
- accessibility relationships;
- route restoration tokens;
- persisted state envelopes;
- automation handles;
- conformance fixtures.

It does not define product domain identity. It defines how Headless references
things without using labels, indexes, raw paths, or renderer object identity.

## Decision Options

Option A: Use labels and indexes as ids - 🎯 2   🛡️ 2   🧠 2, about
50-150 LOC.

- Easy.
- Breaks localization, sorting, filtering, virtualization, and privacy.

Option B: App supplies arbitrary strings - 🎯 5   🛡️ 5   🧠 3, about
150-350 LOC.

- Flexible.
- Without typed scopes, ids collide and leak sensitive content.

Option C: Typed semantic references with scope and privacy class - 🎯 9
🛡️ 9   🧠 6, about 700-1400 LOC.

- Accepted direction.
- Every reference declares type, scope, stability, and privacy.
- Enables safe focus, persistence, automation, and accessibility mapping.

## Accepted Direction

Headless must represent identities as typed references.

A semantic reference includes:

- reference type;
- stable value;
- scope;
- owner primitive;
- version;
- privacy class;
- display label relation;
- accessibility mapping relation.

Display text is never identity.

## Reference Types

Core types:

- `componentRef`;
- `itemRef`;
- `rowRef`;
- `columnRef`;
- `cellRef`;
- `optionRef`;
- `commandRef`;
- `routeRef`;
- `focusRef`;
- `overlayRef`;
- `viewportRef`;
- `snapshotRef`;
- `operationRef`;

References can compose:

```text
cellRef = rowRef + columnRef + viewScope
focusRef = componentRef + itemRef + focusMode
```

## Stability Levels

Stability levels:

- `ephemeral`: valid only for one render or pointer gesture.
- `sessionStable`: valid for one app session.
- `snapshotStable`: valid while a data snapshot is current.
- `userStable`: valid across sessions for preference state.
- `contractStable`: part of public API.
- `operationStable`: valid for operation receipt or journal.

Persisted state must declare the stability it expects.

## Privacy Rules

References must not use:

- raw path;
- filename;
- localized label;
- raw query;
- user name;
- daemon token;
- debug message;
- row index;
- DOM id from renderer;
- object hash from framework.

If product data must become a reference, app layer must map it to an opaque id
first.

## Accessibility Relationship Rules

ARIA relationships need ids, but Headless ids are not automatically DOM ids.

Web adapter must:

- generate safe DOM ids from semantic references;
- avoid raw product data in DOM ids;
- keep ids stable while node exists;
- preserve `aria-controls`, `aria-owns`, and `aria-activedescendant`
  relationships;
- update or remove relationships when target disappears.

Flutter adapter must:

- map references to semantics and focus targets through adapter registry;
- avoid object identity as persisted focus target;
- keep virtualized item references separate from widget instances.

## Virtualization Rules

Virtualized surfaces must never identify rows by visible index.

Rules:

- selection uses item refs;
- focus uses item or cell refs;
- scroll anchors use item refs plus offset;
- automation uses safe refs;
- exported data uses domain ids or snapshot ids, not widget positions;
- stale refs fall back through explicit policy.

## Clean Disk Requirements

Clean Disk must map:

- filesystem node identity to opaque scan node id;
- scan snapshot to snapshot ref;
- query result row to row ref;
- column to contract-stable column id;
- delete queue item to operation or queue ref;
- delete plan to validation ref;
- receipt to operation ref.

Rules:

- raw path is display data, not Headless identity;
- localized column header is display text, not column id;
- stale scan node id is not current cleanup authority.

## API Shape Sketch

```text
SemanticRef
  type
  value
  scope
  stability
  owner
  version
  privacyClass

ReferenceResolver
  resolve(ref, context)
  validate(ref, context)
  toAccessibilityId(ref)
  invalidate(scope, reason)
```

## Conformance Scenarios

- changing locale does not change column id;
- sorting table does not change selected row ref;
- virtualized row recreated with same semantic ref;
- raw path is not emitted in DOM id or test id;
- removed item ref invalidates with reason;
- `aria-activedescendant` points to current owned element;
- persisted column state survives label rename;
- snapshot-scoped selection invalidates on new scan.

## Failure Catalog

- row index used as selection id;
- localized label used as command id;
- raw path used as DOM id;
- widget object used as persisted focus target;
- `aria-controls` points to removed element;
- virtualized row loses selection after scroll;
- item id collides across component scopes;
- stale ref silently resolves to new item;
- privacy class missing on persisted ref;
- automation selector uses visible text.

