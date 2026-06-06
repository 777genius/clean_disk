# Faceted Filter Taxonomy Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Grid and Table Properties: https://www.w3.org/WAI/ARIA/apg/practices/grid-and-table-properties/
- WAI-ARIA APG Checkbox Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/checkbox/
- WAI-ARIA APG Listbox Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/listbox/
- MDN `aria-checked`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-checked
- MDN `aria-selected`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-selected
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

## Scope

This standard covers faceted filters, taxonomy filters, bucket counts,
category chips, hierarchical facets, disabled facet reasons, active facet
summaries, and result-count announcements.

It does not define product query semantics. Headless exposes filter intent and
state. Application and backend decide what a facet means.

## Problem

Facets look simple, but large data apps break when they treat visible buckets
as truth. In Clean Disk, a facet such as "Caches", "Large", "Modified recently",
or "Skipped" can be stale, approximate, privacy-sensitive, or backed by a
different snapshot. The user must understand the scope before selecting,
queuing, or deleting anything.

## Decision Options

1. `FacetSurface` primitive with typed facet groups, counts, and scope facts -
   🎯 9   🛡️ 9   🧠 8, roughly 900-1900 LOC.
   Best fit. It gives community apps a reusable accessible pattern and keeps
   Clean Disk filters backend-owned.
2. Build facets from independent checkboxes and chips -
   🎯 6   🛡️ 6   🧠 4, roughly 300-900 LOC.
   Fast visually, but count freshness, scope, grouping, and stale semantics
   fragment across screens.
3. Make facets part of TreeGrid headers only -
   🎯 4   🛡️ 5   🧠 5, roughly 400-1000 LOC.
   Too narrow. Facets often live in sidebars, sheets, command palettes, or
   result summaries.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- facet surface id;
- facet group id;
- facet option id;
- label and optional description slots;
- selected, checked, mixed, disabled, and unavailable states;
- count facts and count confidence;
- scope facts;
- stale facts;
- disclosure state for hierarchical groups;
- keyboard model;
- active facet summary;
- live announcement policy;
- privacy class.

Renderer owns:

- sidebar, toolbar, sheet, popover, or chip layout;
- checkbox, token, badge, icon, and count visuals;
- compact overflow behavior;
- density and spacing;
- color tokens.

Application owns:

- available facets;
- query execution;
- count calculation;
- backend cursor invalidation;
- localized labels;
- user permissions;
- destructive-action policy.

## Facet Group Types

Facet group kinds:

- checkbox group;
- radio group;
- multi-select listbox;
- single-select listbox;
- hierarchical taxonomy;
- range bucket list;
- date bucket list;
- capability bucket;
- risk bucket;
- saved query preset.

Each group declares:

- whether options are exclusive;
- whether empty option lists are allowed;
- whether zero-count options are hidden, disabled, or visible;
- whether counts are exact, approximate, stale, or unknown;
- whether hidden selected options remain active;
- whether the group affects result identity or only display.

## Count Model

Facet counts must distinguish:

- exact count;
- approximate count;
- capped count;
- unknown count;
- stale count;
- hidden count due to privacy or permission;
- count unavailable because query is still loading.

Rules:

- unknown count is not `0`;
- approximate count must not enable exact claims;
- stale count can be shown but cannot authorize risky commands;
- filtered result count and facet bucket count are different facts;
- selected hidden facet stays visible in the active summary until cleared.

## Selection Semantics

Facet option state can be:

- unchecked;
- checked;
- mixed;
- selected;
- disabled;
- unavailable;
- stale.

Use `checked` semantics when the UI is a checkbox-style predicate. Use
`selected` semantics when the UI is a listbox-like choice. Do not expose both
unless the UI offers different controls and the meaning is explicit.

For hierarchical facets:

- parent `mixed` means some descendants are checked;
- parent count is not necessarily the sum of visible children;
- collapsed descendants remain part of state;
- keyboard navigation must not require pointer expansion.

## Scope Rules

A facet action must carry scope:

- current snapshot;
- current target;
- current folder subtree;
- current search query;
- current result set;
- visible page only;
- all logical results.

Headless should expose scope text and scope id. Application decides wording
and authority. For Clean Disk, a facet never implies "safe to delete"; it only
changes read/query projection.

## Result Announcements

Announce:

- filter applied;
- filter cleared;
- result count changed after user action;
- result set became stale;
- facet count became unavailable;
- no results after filter.

Do not announce:

- every bucket count refresh;
- every debounced keystroke;
- every hidden internal query retry.

Announcement payload should include:

- active filter summary;
- result count if known;
- stale or approximate marker;
- next available action when result is empty.

## Clean Disk Usage

Useful facets:

- file kind;
- folder category;
- size range;
- modified recency;
- cleanup risk tier;
- skipped reason;
- permission state;
- cloud/provider state;
- scan target;
- recommendation source.

Rules:

- risky cleanup facets require evidence and risk labels;
- privacy-sensitive facet values are redacted in logs;
- stale facet result disables derived destructive actions;
- facet group ids are stable protocol/application ids, not display labels;
- filtering never mutates cleanup queue without an explicit command.

## Community API Sketch

```dart
final class RFacetSurfaceModel {
  const RFacetSurfaceModel({
    required this.id,
    required this.groups,
    required this.scope,
    required this.resultState,
    required this.announcementPolicy,
    required this.privacyClass,
  });

  final String id;
  final List<RFacetGroupModel> groups;
  final RFacetScope scope;
  final RFacetResultState resultState;
  final RAnnouncementPolicy announcementPolicy;
  final RPrivacyClass privacyClass;
}

final class RFacetOptionModel {
  const RFacetOptionModel({
    required this.id,
    required this.label,
    required this.state,
    required this.count,
    required this.capability,
  });

  final String id;
  final String label;
  final RFacetOptionState state;
  final RCountFact count;
  final RFacetCapability capability;
}
```

## Conformance Scenarios

- facet group has accessible label;
- checkbox facet exposes checked or mixed state;
- listbox facet exposes selected state;
- zero-count disabled option explains why it is disabled;
- approximate count is distinguishable from exact count;
- stale facet count disables risky derived commands;
- active hidden facet remains discoverable and clearable;
- result-count update is announced once after user action;
- hierarchical mixed state survives collapse and virtualization.

## Failure Catalog

- Unknown count rendered as `0`.
- Filter chip label is the only stable id.
- Hidden selected facet cannot be cleared.
- Parent taxonomy count lies by summing only mounted children.
- Color is the only signal for active or risky facet.
- Facet result becomes cleanup authority without revalidation.
- Bucket count updates spam assistive technology.

