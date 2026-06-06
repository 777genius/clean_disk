# Sticky Scroll Anchoring And Geometry Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN CSS `position`: https://developer.mozilla.org/en-US/docs/Web/CSS/position
- MDN CSS scroll snap: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_scroll_snap
- MDN CSS scroll anchoring: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_scroll_anchoring
- MDN `overflow`: https://developer.mozilla.org/en-US/docs/Web/CSS/overflow
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- WCAG 2.4.11 Focus Not Obscured Minimum: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html

## Scope

This standard defines geometry rules for sticky headers, sticky footers, frozen
columns, scroll anchoring, scroll snap, virtualized ranges, and focus reveal.

It applies to:

- TreeGrid headers;
- pinned columns;
- bottom scan progress footer;
- details panels;
- command bars;
- split panes;
- virtualized rows;
- scroll-to-selection;
- route focus restore.

It does not define layout pixels. It defines geometry facts and invariants.

## Decision Options

Option A: Let scroll containers handle themselves - 🎯 4   🛡️ 4   🧠 2,
about 100-250 LOC.

- Simple.
- Focus and selected rows can disappear behind sticky regions.

Option B: One app-level sticky offset - 🎯 6   🛡️ 6   🧠 4, about
250-600 LOC.

- Better.
- Fails with nested scroll containers, split panes, frozen columns, and
  overlays.

Option C: Headless geometry registry and reveal policy - 🎯 9   🛡️ 9
🧠 8, about 1000-2200 LOC.

- Accepted direction.
- Components publish occlusion and scroll facts.
- Focus reveal, selection reveal, and route restore share one geometry model.

## Accepted Direction

Headless must define a geometry registry.

The registry tracks:

- scroll containers;
- sticky regions;
- frozen regions;
- overlay occlusion;
- safe area insets;
- visual viewport;
- virtualized visible range;
- focus target bounds;
- anchor candidates.

Any primitive that scrolls or sticks must publish geometry facts.

## Sticky Region Rules

Sticky regions must declare:

- edge;
- size;
- z-order;
- owning scroll container;
- whether it can cover focus;
- whether it contains focusable controls;
- collapse behavior;
- accessibility label if landmark-like.

Focus reveal must avoid sticky regions.

## Frozen Column Rules

Frozen columns in data grids must:

- not duplicate accessible cells;
- not create two focus targets for same cell;
- keep row and cell references stable;
- preserve hit testing boundaries;
- avoid covering row actions;
- keep keyboard navigation logical.

If frozen visual and scrollable visual are duplicates, only one semantic cell
should be exposed.

## Scroll Anchoring Rules

Anchor should be a semantic reference, not pixel offset only.

Anchor includes:

- item ref;
- alignment;
- container ref;
- offset within item;
- query version;
- density and text scale bucket;
- sticky avoidance policy.

When rows load above the anchor, the view should preserve user context without
moving focus to a hidden or stale target.

## Scroll Snap Rules

Scroll snap can help paged surfaces, but must not trap content.

Rules:

- do not use mandatory snap when item content can overflow;
- keyboard focus must still reach every target;
- snap must account for sticky headers and footers;
- reduced motion may disable animated snap;
- virtualization must not snap to unloaded phantom rows.

## Clean Disk Requirements

Clean Disk needs geometry for:

- TreeGrid sticky header;
- size and percent columns;
- bottom progress footer;
- right details pane;
- compact delete queue;
- selected row reveal;
- search result reveal;
- route restore to previous row.

Rules:

- focused row action must not be hidden behind progress footer;
- selected row reveal accounts for sticky header;
- frozen columns do not duplicate screen reader content;
- compact layout bottom footer does not obscure confirmation controls.

## API Shape Sketch

```text
GeometryRegistry
  registerScrollContainer(container)
  registerStickyRegion(region)
  registerFrozenRegion(region)
  resolveReveal(target, policy)
  currentOcclusion(container)

RevealPolicy
  targetRef
  alignment
  avoidSticky
  avoidSafeArea
  allowMotion
```

## Conformance Scenarios

- focusing first visible row below sticky header shows full focus ring;
- bottom footer does not cover focused delete queue item;
- frozen column exposes one semantic cell;
- scroll restore uses row ref, not only pixel offset;
- mandatory snap does not trap overflowing content;
- high text scale recalculates sticky occlusion;
- overlay close restores scroll anchor;
- virtualized reveal loads target before scrolling.

## Failure Catalog

- focus hidden under sticky header;
- frozen cell duplicated in accessibility tree;
- scroll restore by pixel offset after row heights changed;
- bottom footer covering focused button;
- scroll snap trapping tall content;
- sticky region not registered with geometry;
- selected row reveal ignores safe area;
- virtualized reveal scrolls to unloaded placeholder;
- reduced motion ignored for animated scroll;
- geometry state stored as renderer object identity.

