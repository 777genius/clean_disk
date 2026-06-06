# Query Filter Sort Surface Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `search` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/search_role
- MDN `input type=search`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/search
- MDN `aria-sort`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-sort
- WAI-ARIA APG Combobox Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/combobox/
- WAI-ARIA APG Disclosure Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Scope

This standard covers search fields, filter bars, filter builders, saved views,
sort controls, query chips, active filter summaries, reset/clear commands,
result count summaries, and query surfaces that drive large backend-owned
collections.

It does not sort or filter data. Headless owns interaction and semantics.
Application/backend owns query meaning and execution.

## Decision Options

1. `QuerySurface` primitive with typed query intents and active-query view model -
   🎯 9   🛡️ 9   🧠 8, roughly 900-2000 LOC.
   Best fit. It keeps filters accessible while preventing Flutter from taking
   ownership of large scan tree sorting.
2. Build query UI from independent text fields, chips, and dropdowns -
   🎯 6   🛡️ 6   🧠 5, roughly 500-1200 LOC.
   Fine visually, but weak for summary, reset semantics, stale query state, and
   backend cursor invalidation.
3. Make TreeGrid headers and rows own all query behavior -
   🎯 4   🛡️ 5   🧠 5, roughly 500-1300 LOC.
   Tempting, but couples data-grid interactions to app query semantics.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- query surface id;
- search field semantics;
- filter control descriptors;
- sort descriptor display;
- active filter token model;
- clear/reset command semantics;
- result count announcement policy;
- stale query state;
- loading state;
- keyboard shortcuts and focus movement;
- privacy class for search text and filter values.

Renderer owns:

- layout: toolbar, compact sheet, side panel, inline chips;
- iconography;
- filter popover visuals;
- active token visuals;
- loading indicators.

Application owns:

- query schema;
- backend request;
- cursor invalidation;
- saved view persistence;
- privacy policy for query text;
- localization of labels and values.

## Query State Model

States:

- idle;
- editing;
- submitted;
- loading;
- loaded;
- empty;
- stale;
- failed;
- incompatible.

Important distinction:

- draft query: user is editing;
- submitted query: backend accepted it;
- active query: current result set is based on it;
- stale query: result set no longer matches current snapshot or capability.

## Search Landmark Rules

Use search landmark when:

- the surface searches a major app collection;
- the app has multiple regions and users benefit from landmark navigation;
- search is not merely a small inline field inside a form.

Do not create excessive search landmarks:

- one main app search is enough for most screens;
- filter popover fields usually do not need separate landmarks;
- repeated equivalent search regions should be labeled consistently.

## Sort Rules

Sort descriptor:

- column key;
- direction;
- null ordering if relevant;
- semantic label;
- backend/query version;
- stability guarantee where known.

Web adapter:

- use `aria-sort` only on the currently sorted table/grid header;
- do not put `aria-sort` on arbitrary filter buttons;
- expose non-standard sort with `other` only when meaningful.

Flutter adapter:

- expose sorted facts through TreeGrid semantics;
- keep sort command intent separate from local data mutation;
- show clear active sort summary for screen reader and compact UI.

## Filter Rules

Filter controls may be:

- checkbox group;
- radio group;
- select/listbox;
- range/slider;
- date/time picker;
- text predicate;
- advanced expression builder;
- preset chip.

Each filter must have:

- stable filter id;
- localized label;
- value type;
- operator;
- active/inactive state;
- validation state;
- clear command;
- privacy class.

## Active Query Summary

The user must be able to answer:

- what is being searched;
- which filters are active;
- how results are sorted;
- whether results are current;
- how many results are known;
- how to clear or edit query.

For Clean Disk, active query summary must not expose raw private path text in
logs, route strings, support bundles, or unrequested announcements.

## Large Data Rules

Headless must not:

- sort a full backend-owned scan tree;
- filter millions of rows in Flutter;
- treat visible rows as complete result set;
- keep stale query pages as delete authority.

Instead:

- emit query intent;
- display backend result state;
- render pages/cursors;
- show stale/incompatible states;
- use application ports for query execution.

## Clean Disk Usage

Top bar:

- search files and folders;
- sort/filter button;
- active query chips in compact layout;
- result count and stale state.

TreeGrid:

- sortable headers emit query intent;
- filtered result pages come from Rust;
- selection survives query only by stable node ids and snapshot ids.

Delete queue:

- query state must not automatically add or remove cleanup authority;
- filtered-hidden queued items still need explicit review.

## Conformance Scenarios

- search field has accessible name;
- search landmark is not duplicated without label;
- active filters are discoverable without color;
- clearing one filter announces updated result summary;
- sort state exists on exactly one sorted header in web adapter;
- stale query disables destructive derived actions;
- draft query does not overwrite active result until submitted or debounced by policy;
- private query text is redacted in diagnostics.

## Failure Catalog

- Filter chips are visual only and invisible to screen readers.
- Sort icon changes but `aria-sort` or equivalent semantic fact does not.
- Flutter filters only currently visible virtualized rows.
- Search query appears in URL or support bundle.
- Clearing filters resets selection into cleanup authority.
- Result count changes silently after filter.
