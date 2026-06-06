# Master Detail Preview Panel Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Disclosure Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/
- MDN `<details>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/details
- MDN `<summary>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/summary
- MDN `aria-details`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-details
- MDN `aria-describedby`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-describedby
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html

## Scope

This standard covers master-detail surfaces, details panes, preview panels,
peek panels, expandable row details, selected item inspectors, and lightweight
read-only previews attached to collection items.

It extends property list/details inspector, drawer/sheet, disclosure, and
responsive layout standards. It focuses on the relationship between a master
collection and detail content.

## Problem

The details pane in Clean Disk is central: it shows path, size facts,
permissions, warnings, breakdowns, and queue actions. Many UI kits treat this
as a visual side panel. That is not enough. The detail panel has to be tied to
the selected item, survive virtualization, avoid focus traps, and not become
delete authority by displaying stale facts.

## Decision Options

1. `MasterDetailSurface` contract with explicit selected item and detail facts -
   🎯 9   🛡️ 9   🧠 8, roughly 900-1900 LOC.
   Best fit. It standardizes preview/detail behavior across table, card,
   search, receipt, and compare views.
2. Treat details pane as ordinary card content -
   🎯 5   🛡️ 5   🧠 3, roughly 200-600 LOC.
   Looks simple, but loses relationship semantics, stale state, and focus
   restoration.
3. Make details a modal dialog -
   🎯 5   🛡️ 7   🧠 5, roughly 500-1000 LOC.
   Useful on compact layouts, but wrong for persistent desktop workbench
   inspection.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- master collection id;
- focused item id;
- selected item id;
- detail item ref;
- relationship between master and detail;
- detail loading state;
- detail freshness;
- stale marker;
- focus entry and return policy;
- collapse/expand state;
- announcement policy;
- privacy class.

Renderer owns:

- side panel, bottom panel, popover, or inline row layout;
- spacing and visual hierarchy;
- icon and chart visuals;
- compact collapse affordance;
- animation;
- responsive placement.

Application owns:

- detail data source;
- item validation;
- localized labels;
- action authorization;
- destructive plan creation;
- support and diagnostic policy.

## Relationship Model

The detail surface must distinguish:

- focused item details;
- selected item details;
- pinned item details;
- previewed item details;
- compared item details;
- historical item details.

Rules:

- focus change does not always imply detail change;
- selected item can be different from focused item in multi-select mode;
- pinned details remain stable while focus moves;
- historical detail cannot become current cleanup target without validation;
- detail item ref includes snapshot/query version.

## Detail State Model

States:

- empty;
- loading;
- loaded;
- partial;
- stale;
- incompatible;
- permissionDenied;
- failed;
- detached.

Detached means the detail content is still visible but the backing item is no
longer present in the current projection. Detached details are read-only by
default.

## Focus Rules

Desktop persistent detail pane:

- does not trap focus;
- can be reached by keyboard shortcut or normal traversal;
- returns focus to master item when requested;
- does not steal focus on every selection change;
- exposes heading or region label.

Compact detail sheet/dialog:

- may trap focus if modal;
- must return focus to trigger;
- must preserve item context in title;
- must not hide stale state.

Inline row detail:

- expands from a disclosure-like control;
- exposes expanded state;
- remains associated with its row;
- does not break row index accounting.

## Preview Versus Authority

Preview shows information. Authority comes from application validation.

```text
detail preview
  != selected item
  != cleanup queue
  != delete plan
```

If the detail panel contains actions:

- actions use command descriptors;
- actions carry item refs;
- stale facts disable risky actions;
- delete/reclaim preview comes from validated plan, not displayed values.

## Clean Disk Usage

Wide layout:

- right details pane shows selected node;
- delete queue can share side panel region but remains a different state;
- breakdown chart is detail visualization, not source of truth;
- warnings are critical facts.

Compact layout:

- details move below tree or into collapsible panel;
- queue can be a separate collapsible section;
- primary row selection remains visible.

Rules:

- path display follows path semantic standard;
- permission and warning facts are always available when actions exist;
- stale detail disables queue/delete commands;
- selected row and detail panel use same opaque node ref.

## Community API Sketch

```dart
final class RMasterDetailModel {
  const RMasterDetailModel({
    required this.masterRef,
    required this.detailRef,
    required this.relationship,
    required this.state,
    required this.focusPolicy,
  });

  final RCollectionRef masterRef;
  final RItemRef? detailRef;
  final RDetailRelationship relationship;
  final RDetailState state;
  final RDetailFocusPolicy focusPolicy;
}
```

## Conformance Scenarios

- details pane has accessible region label or heading;
- selection change updates details without stealing focus;
- keyboard user can move from master to details and back;
- stale detail disables risky command;
- compact modal detail returns focus to trigger;
- inline row details expose expanded state;
- multi-select summary does not pretend to be single item detail;
- historical detail cannot become delete target.

## Failure Catalog

- Details pane is visual-only.
- Focus jumps into details on every row change.
- Detail action uses stale row index.
- Historical scan detail enables current delete command.
- Compact sheet hides warnings shown on desktop.
- Inline detail breaks virtualized row count.
- Preview chart becomes source of cleanup authority.

