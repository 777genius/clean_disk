# Semantic Diff Change Set And Announcement Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN ARIA live regions: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/ARIA_Live_Regions
- MDN `aria-live`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-live
- MDN `aria-busy`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-busy
- MDN `log` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/log_role
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/

## Scope

This standard defines how Headless primitives represent and announce semantic
changes to dynamic data.

It applies to:

- TreeGrid row changes;
- search result changes;
- scan progress updates;
- log append operations;
- virtualized list changes;
- table sort and filter changes;
- chart data refreshes;
- details panel updates;
- cleanup queue changes.

It does not define product data diffing. It defines UI-facing change-set
contracts and announcement policy.

## Decision Options

Option A: Re-render and rely on visual change - 🎯 3   🛡️ 3   🧠 2, about
80-200 LOC.

- Fast.
- Screen reader users and keyboard users can miss meaningful changes.
- Dynamic updates become noisy or silent unpredictably.

Option B: Announce every update - 🎯 4   🛡️ 3   🧠 3, about 150-400 LOC.

- Hard to miss changes.
- Produces announcement spam on scans, logs, and filters.
- Breaks productivity tools.

Option C: Semantic change sets with announcement policy - 🎯 9   🛡️ 9
🧠 7, about 900-1800 LOC.

- Accepted direction.
- Components publish typed changes.
- Broker decides what to announce, batch, suppress, or expose through log.

## Accepted Direction

Headless must represent dynamic changes as `SemanticChangeSet`.

A change set includes:

- source primitive;
- scope;
- data version;
- operation id;
- change class;
- affected references;
- visible impact;
- focus impact;
- selection impact;
- announcement policy;
- privacy class.

The renderer receives final view state. It does not infer semantic changes from
widget rebuilds.

## Change Classes

Classes:

- `added`;
- `removed`;
- `updated`;
- `moved`;
- `reordered`;
- `filteredIn`;
- `filteredOut`;
- `selected`;
- `deselected`;
- `expanded`;
- `collapsed`;
- `stale`;
- `refreshed`;
- `partial`;
- `operationPhaseChanged`;
- `errorStateChanged`.

Each class declares whether it affects visible layout, focus, selection,
status, and export projections.

## Announcement Rules

Announcement policy must be explicit:

- `silent`: no automatic announcement.
- `politeSummary`: announce summarized change.
- `assertiveBlocker`: announce blocking safety issue.
- `logAppend`: append to readable log.
- `manualOnly`: visible change can be discovered by user.
- `coalescedMilestone`: announce only on meaningful milestone.

Examples:

- 1000 new rows from scan: coalesced summary.
- selected folder removed from current snapshot: polite summary and focus
  fallback.
- delete plan stale: assertive only if user attempted destructive action.
- log entry appended: log role, not assertive alert.

## Busy And Atomic Rules

During multi-step updates:

- set busy state on affected semantic region where adapter supports it;
- avoid exposing incomplete required owned elements;
- batch changes before announcement;
- publish final summary after busy clears;
- keep focus stable if target still exists.

Do not use busy state to hide errors indefinitely.

## Virtualized Data Rules

Virtualization creates extra risk:

- a row can be added without mounted widget;
- a visible index can point to different item after sort;
- focus target can disappear during refresh;
- selection can remain valid outside visible range.

Change sets must use semantic refs, not widget instances or visible indexes.

## Clean Disk Requirements

Clean Disk change sets:

- scan discovered subtree;
- skipped count changed;
- selected node changed;
- current node became stale;
- sort changed visible order;
- filter changed result count;
- delete queue changed;
- delete plan validation changed;
- cleanup operation appended receipt line.

Rules:

- scan progress does not announce every file;
- skipped warnings are summarized;
- stale delete plan is clearly announced when user attempts cleanup;
- focus fallback after node disappearance is explicit.

## API Shape Sketch

```text
SemanticChangeSet
  id
  sourceRef
  scope
  dataVersion
  changes
  focusImpact
  selectionImpact
  announcementPolicy
  privacyClass

SemanticChange
  kind
  targetRef
  beforeRef
  afterRef
  valueSummary
```

## Conformance Scenarios

- filtering 10,000 rows announces final result count once;
- sorting table preserves selection by row ref;
- removing focused row moves focus to safe neighbor or ancestor;
- scan progress emits milestone summaries, not per-file messages;
- `aria-busy` clears after batch update;
- log append is readable without stealing focus;
- privacy policy prevents raw path in change announcement;
- chart refresh exposes data summary change.

## Failure Catalog

- announcement derived from widget rebuild count;
- every row insertion announced;
- sorted row index used as identity;
- `aria-busy` left true forever;
- focused row removed with no fallback;
- stale selection shown as current;
- log updates announced as assertive alerts;
- raw query or path spoken in change summary;
- visual order changes but semantic order is stale;
- renderer decides whether data change is meaningful.

