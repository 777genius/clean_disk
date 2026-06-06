# Accessibility Tree Snapshot And Regression Standard

## Status

Accepted as a Headless assurance standard. Not implemented yet.

## Source Standards

- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- MDN ARIA reference: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Scope

This standard defines how Headless captures semantic snapshots and detects
regressions in accessibility trees.

It applies to:

- roles;
- names;
- descriptions;
- states;
- values;
- relationships;
- focus targets;
- live regions;
- keyboard command facts;
- semantic order;
- adapter parity.

It does not claim that a snapshot predicts exact screen reader speech. It gives
repeatable structural evidence before manual screen reader labs.

## Decision Options

Option A: Manual screen reader testing only - 🎯 5   🛡️ 6   🧠 5, about
400-1200 LOC process cost.

- Necessary for high-risk widgets.
- Too slow as the only regression defense.
- Misses simple role, state, and relationship changes between releases.

Option B: Visual snapshots plus widget tests - 🎯 4   🛡️ 4   🧠 3, about
200-600 LOC.

- Useful for layout.
- Does not prove semantic correctness.

Option C: Semantic snapshot fixtures plus manual lab escalation - 🎯 9
🛡️ 9   🧠 8, about 1200-2600 LOC.

- Accepted direction.
- CI can catch role/state/name regressions.
- Manual labs focus on known adapter and assistive technology gaps.

## Accepted Direction

Every complex Headless primitive must expose a semantic snapshot contract.

Snapshot includes:

- primitive type;
- scenario id;
- adapter id;
- tree of semantic nodes;
- role;
- name policy result;
- description policy result;
- states;
- values;
- relationships;
- focus target;
- keyboard commands;
- live region facts;
- privacy redaction result;
- known adapter gaps.

## Snapshot Is Not Speech

Screen reader speech depends on:

- assistive technology;
- browser or platform bridge;
- verbosity settings;
- locale;
- role heuristics;
- live-region timing;
- user navigation mode.

Snapshot conformance proves structural contract. It does not replace VoiceOver,
NVDA, JAWS, TalkBack, or platform-specific testing where needed.

## Snapshot Levels

Levels:

- `contract`: Headless semantic facts before adapter projection.
- `adapter`: semantics after adapter mapping.
- `platform`: platform accessibility tree where tooling can capture it.
- `manual`: screen reader lab observation.

Conformance gates can require different levels by primitive risk.

## Redaction Rules

Snapshots must not contain raw product content by default.

Allowed:

- role;
- state;
- command id;
- placeholder-safe label key;
- count bucket;
- component id;
- scenario id.

Blocked by default:

- raw path;
- raw query;
- filename;
- daemon token;
- clipboard content;
- localized full user string unless fixture-safe.

## Regression Rules

Snapshot diff should detect:

- role change;
- missing name;
- changed relationship target;
- selected state lost;
- disabled reason lost;
- invalid focus target;
- duplicate semantic nodes;
- live-region politeness change;
- keyboard command missing;
- adapter gap introduced.

Expected changes must be reviewed and versioned.

## Clean Disk Requirements

Clean Disk must have semantic snapshots for:

- wide tree table;
- compact tree table;
- selected row;
- stale row;
- cleanup queue;
- move-to-trash confirmation;
- progress footer;
- permission-degraded scan;
- details inspector;
- disk usage map fallback.

Rules:

- raw filesystem paths are redacted in snapshots.
- cleanup confirmation snapshots must show disabled/enabled reason.
- TreeGrid snapshots use node refs, not visible indexes.

## API Shape Sketch

```text
SemanticSnapshot
  scenarioId
  primitiveType
  adapterId
  nodes
  relationships
  focus
  commands
  liveRegions
  privacyReport

SemanticNodeSnapshot
  ref
  role
  nameKey
  descriptionKey
  states
  value
```

## Conformance Scenarios

- selected row exposes selected state;
- disabled destructive command has disabled reason;
- focused cell has valid owner and row relation;
- chart fallback exposes table or summary;
- live status has polite policy;
- compact layout keeps same semantic command ids;
- raw path does not appear in snapshot;
- expected snapshot change requires review note.

## Failure Catalog

- visual snapshot passes while semantic role disappears;
- localized text used as snapshot identity;
- platform snapshot treated as exact screen reader speech;
- expected diff accepted without review;
- raw path stored in CI artifact;
- duplicate frozen cell appears twice in semantic tree;
- live region politeness changes silently;
- command shortcut present visually but absent semantically;
- missing adapter id in snapshot;
- no manual escalation for high-risk TreeGrid changes.

