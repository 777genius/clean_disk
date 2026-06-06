# Versioned State And Migration Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN History API: https://developer.mozilla.org/en-US/docs/Web/API/History_API
- MDN Web Storage API: https://developer.mozilla.org/en-US/docs/Web/API/Web_Storage_API
- MDN Structured clone algorithm: https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Structured_clone_algorithm
- WCAG 3.2.3 Consistent Navigation: https://www.w3.org/WAI/WCAG22/Understanding/consistent-navigation.html
- WCAG 3.3.7 Redundant Entry: https://www.w3.org/WAI/WCAG22/Understanding/redundant-entry.html

## Scope

This standard defines how Headless primitives version, persist, migrate, and
invalidate component state across releases, app restarts, route restores, and
multi-window sessions.

It applies to:

- table column state;
- split pane sizes;
- selection state;
- expanded tree nodes;
- filter state;
- command history;
- route restoration tokens;
- density preferences;
- renderer capability preferences;
- conformance fixtures.

It does not choose a storage backend. It defines state contracts that storage
adapters can persist safely.

## Decision Options

Option A: Persist raw component objects - 🎯 2   🛡️ 2   🧠 2, about
80-200 LOC.

- Looks convenient.
- Breaks across versions and can leak unsafe state.

Option B: Persist app-specific JSON with ad hoc migrations - 🎯 5   🛡️ 5
🧠 5, about 300-900 LOC.

- Works in one app.
- Public components cannot guarantee compatibility.

Option C: Versioned Headless state envelopes - 🎯 9   🛡️ 9   🧠 7, about
900-1800 LOC.

- Accepted direction.
- Persisted state is explicit, typed, versioned, scoped, and invalidatable.
- Migration is part of public API stability.

## Accepted Direction

Every persisted Headless state value must use a state envelope:

- primitive id;
- schema version;
- component version;
- scope;
- owner id;
- data version;
- created time;
- migration path;
- privacy class;
- invalidation rules.

Headless components must never require app storage to persist framework objects.

## Persistable Versus Ephemeral

Persistable:

- column order;
- column widths;
- visible columns;
- split pane ratio;
- density choice;
- selected tab;
- safe route tokens;
- filter presets if app allows.

Ephemeral:

- hover;
- pressed;
- animation state;
- active pointer;
- live focus node reference;
- unsent destructive confirmation;
- daemon token;
- raw delete authority.

## Version Rules

Each envelope must include:

- `schemaVersion`;
- `componentContractVersion`;
- `adapterVersion`;
- optional `appStateVersion`;
- optional `dataSnapshotVersion`.

Unknown major version:

- fail closed;
- ignore unsafe state;
- show safe default;
- emit diagnostic in development.

Unknown minor version:

- ignore unknown fields;
- preserve if round-trip safe;
- apply migration if registered.

## Migration Rules

Migration must be:

- deterministic;
- bounded;
- testable;
- privacy-safe;
- reversible only when declared;
- able to drop unsafe fields.

Migrations must not:

- restore destructive authority;
- invent selected item identity;
- turn display labels into stable ids;
- keep raw paths when redaction policy changed;
- silently map incompatible data snapshots.

## Invalidation Rules

State invalidates when:

- primitive contract changes incompatibly;
- data snapshot changes;
- column id removed;
- capability policy changes;
- app version declares reset;
- privacy policy changes;
- storage corruption detected;
- scope owner disappears.

Invalidation must explain reason in development and fall back safely.

## Clean Disk Requirements

Clean Disk may persist:

- UI density;
- theme;
- column layout;
- sidebar width;
- details panel width;
- last safe route;
- scan target shortcuts if policy allows;
- read-only historical snapshot selection.

Clean Disk must not persist:

- delete confirmation authority;
- daemon token in Headless state;
- raw delete plan as UI state;
- stale node as current cleanup target;
- support bundle content.

## API Shape Sketch

```text
StateEnvelope
  primitiveType
  primitiveId
  schemaVersion
  contractVersion
  scope
  payload
  privacyClass
  invalidationPolicy

StateMigrator
  canMigrate(from, to)
  migrate(envelope)
  validate(envelope, context)
```

## Conformance Scenarios

- unknown state version falls back safely;
- column id removal drops only affected column state;
- split pane state migrates across minor release;
- route restore does not restore delete confirmation;
- privacy policy change redacts old path-bearing state;
- storage corruption emits diagnostic and uses defaults;
- snapshot-scoped state invalidates on new scan;
- migration tests cover old fixture envelopes.

## Failure Catalog

- persisted framework objects;
- localized label used as persisted id;
- major version mismatch ignored;
- stale delete plan restored;
- raw path persisted after redaction policy changed;
- migration without fixture tests;
- invalid state crashing app startup;
- minor unknown fields deleted when extension needed round-trip;
- app storage bypassing Headless envelope;
- corrupted state treated as valid.

