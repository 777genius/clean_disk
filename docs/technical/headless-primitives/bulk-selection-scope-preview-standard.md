# Bulk Selection Scope Preview Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- MDN `aria-selected`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-selected
- MDN `aria-checked`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-checked
- WCAG 3.3.4 Error Prevention: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html
- WCAG 3.3.6 Error Prevention All: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-all.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

## Scope

This standard covers select-all scope, bulk action preview, batch command
review, selected versus visible versus filtered result semantics, queued item
preview, destructive preview requirements, and stale selection policy.

It extends the multi-selection standard. It focuses on the moment when a user
turns selection into a command.

## Problem

The most dangerous phrase in a data app is "Select all". It can mean visible
rows, all loaded rows, all filtered results, all descendants, all pages, or all
items in a snapshot. Clean Disk cannot let a compact checkbox imply a cleanup
plan for hidden or stale files.

## Decision Options

1. `BulkScopePreview` contract between selection and command execution -
   🎯 10   🛡️ 10   🧠 8, roughly 900-2000 LOC.
   Best fit. It creates an explicit bridge from UI selection to app command
   review without making Headless product-aware.
2. Let each app command interpret selection directly -
   🎯 5   🛡️ 5   🧠 4, roughly 300-800 LOC.
   Common, but every screen has to rediscover hidden rows, stale state, and
   scope wording.
3. Force every bulk action into modal confirmation -
   🎯 5   🛡️ 7   🧠 5, roughly 400-1000 LOC.
   Safer than silent execution, but still weak if the modal receives ambiguous
   scope.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- selected key set facts;
- selection scope facts;
- count facts;
- hidden-selected facts;
- disabled-selected facts;
- stale-selected facts;
- preview status;
- batch command intent;
- focus flow from selection to preview;
- announcement policy.

Renderer owns:

- selected count placement;
- preview panel visuals;
- select-all banner;
- warning icon visuals;
- action button layout;
- compact collapse behavior.

Application owns:

- whether command is allowed;
- command-specific preview content;
- revalidation;
- confirmation requirements;
- operation journal;
- cleanup receipt;
- policy gates.

## Scope Taxonomy

Bulk scope must be one of:

- none;
- visibleRows;
- mountedRows;
- currentPage;
- loadedPages;
- filteredResults;
- currentSubtree;
- currentGroup;
- currentSnapshot;
- explicitIds;
- allAvailableByQuery;
- appDefined.

Each scope carries:

- human-readable label;
- stable machine id;
- count kind;
- query/snapshot version;
- whether hidden items are included;
- whether stale items exist;
- whether disabled items exist;
- whether preview is required.

## Preview Model

Preview states:

- notRequired;
- requiredNotLoaded;
- loading;
- loaded;
- partial;
- stale;
- blocked;
- failed.

Preview payload:

- command id;
- scope;
- affected count;
- excluded count;
- hidden count;
- stale count;
- risk facts;
- sample rows;
- policy blockers;
- required acknowledgement facts.

Headless should display preview state and pass command intent. It should not
invent product-specific preview rows.

## Select All Rules

Select-all control must expose:

- current state: unchecked, checked, mixed;
- scope label;
- count if known;
- hidden inclusion policy;
- disabled item policy;
- stale item policy.

Patterns:

- "Select visible rows" is allowed without backend support.
- "Select all filtered results" requires backend/application support.
- "Select all descendants" requires subtree authority and current snapshot.
- "Select all disk files" is prohibited for Clean Disk default UX.

## Destructive Command Rules

For destructive or irreversible commands:

- preview is required;
- stale preview blocks command;
- unknown count blocks command unless product policy explicitly permits;
- hidden selected items must be listed by category or count;
- final confirmation must use a current validated plan;
- `DeletePlan` is separate from selection preview.

Clean Disk delete flow:

```text
selection
  -> queue intent
  -> application validation
  -> delete plan preview
  -> explicit confirmation
  -> platform Trash adapter
  -> receipt
```

## Accessibility Rules

Bulk selection UI must:

- separate focus from selection;
- expose checked or selected state consistently;
- announce selected count changes through status policy;
- expose scope text near the action;
- preserve keyboard path to preview;
- not rely on disabled color only.

For screen readers, "12 selected" is insufficient. The user needs "12 selected
in current filtered results, 2 hidden by collapsed groups" when that affects
the command.

## Clean Disk Usage

Use cases:

- add selected folders to cleanup queue;
- remove selected queue items;
- reveal selected items;
- export selected result rows;
- compare selected folders;
- ignore selected recommendation warnings.

Rules:

- adding to queue does not create delete authority;
- hidden filtered selections require explicit review;
- stale selection disables queue/delete commands;
- queue preview uses current metadata and policy;
- bulk reveal can degrade to one item if platform cannot reveal many.

## Community API Sketch

```dart
final class RBulkScopePreview {
  const RBulkScopePreview({
    required this.commandId,
    required this.scope,
    required this.counts,
    required this.state,
    required this.risk,
    required this.blockers,
  });

  final String commandId;
  final RBulkScope scope;
  final RBulkCountFacts counts;
  final RBulkPreviewState state;
  final RCommandRisk risk;
  final List<RPolicyBlocker> blockers;
}
```

## Conformance Scenarios

- select-all scope is announced and visible;
- mixed select-all state is exposed;
- hidden selected count is discoverable;
- stale selected key blocks destructive action;
- preview refresh updates count without moving focus;
- disabled selected items are excluded or explained;
- final destructive command cannot run from selection alone;
- keyboard user can reach preview and cancel.

## Failure Catalog

- "Select all" means different scopes in different screens.
- Hidden filtered rows are deleted without preview.
- Selected count is exact visually but approximate semantically.
- Disabled rows can be selected through keyboard but not pointer.
- Selection preview becomes stale and action stays enabled.
- Bulk action reads localized labels as ids.
- Queue equals delete plan.

