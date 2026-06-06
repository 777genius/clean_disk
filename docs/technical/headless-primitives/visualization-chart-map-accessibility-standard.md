# Visualization Chart And Map Accessibility Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `canvas` accessibility guidance: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/canvas
- MDN SVG `title`: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/title
- MDN SVG `desc`: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/desc
- WCAG 1.1.1 Non-text Content: https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html
- WCAG 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- Flutter `CustomPainter.semanticsBuilder`: https://api.flutter.dev/flutter/rendering/CustomPainter/semanticsBuilder.html
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers treemaps, sunbursts, icicle charts, bar maps, donut charts,
sparklines, heatmaps, canvas renderers, SVG renderers, and any visual disk usage
map adapter.

For Clean Disk this extends the accepted `DiskUsageMapView` abstraction. Charts
are renderer adapters over bounded Rust projections. They are not sources of
truth for selection, cleanup authority, accounting, or delete plans.

## Decision Options

1. `AccessibleVisualization` contract with data summary, interactive marks, and
   alternative table/list projection - 🎯 9   🛡️ 9   🧠 8, roughly 1000-2200 LOC.
   Best fit. It supports canvas, SVG, native Flutter painting, and third-party
   renderers without losing semantics.
2. Chart renderer only, with details pane as the only accessible fallback -
   🎯 5   🛡️ 6   🧠 5, roughly 400-900 LOC.
   Acceptable for MVP if charts are decorative, but weak for a public Headless
   visualization primitive.
3. Use a commercial chart package and trust its accessibility - 🎯 4   🛡️ 5   🧠 4, roughly 300-800 LOC.
   Useful as an adapter, not a core contract. Package accessibility varies by
   renderer and platform.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- visualization role: decorative, summary, interactive, navigable, or editor;
- chart title and description contract;
- data summary contract;
- mark identity and ordering;
- focused mark id;
- keyboard navigation between marks;
- alternative table/list projection;
- color channel metadata;
- selection mapping;
- privacy class for labels and values;
- renderer capability requirements.

Renderer owns:

- geometry, layout, animation, color, legend placement, hit testing, and drawing;
- canvas, SVG, Flutter painter, or package-specific rendering;
- label collision visuals;
- pointer interactions.

Application owns:

- source data and projections;
- node authority and delete validation;
- business meaning of categories;
- localized labels and unit formatting.

## Visualization Modes

Decorative:

- chart conveys no unique information;
- semantics may be excluded;
- nearby text or table contains the information.

Summary:

- chart conveys a high-level summary;
- expose title, description, and key values;
- marks are not individually focusable.

Interactive:

- pointer hover or click changes selection or details;
- keyboard users must have equivalent mark navigation or equivalent list/table
  navigation.

Navigable:

- chart is a primary way to explore hierarchy;
- must support keyboard focus, current mark, drill in/out, sibling navigation,
  and escape back to surrounding UI.

Editor:

- user can manipulate chart marks or ranges;
- requires separate editor-specific standard. Out of MVP scope.

Clean Disk disk maps start as summary plus optional interactive. TreeGrid stays
the authoritative navigable surface for MVP.

## Data Summary Contract

Every non-decorative visualization MUST expose:

- title;
- short description of what the chart shows;
- data timestamp or snapshot id when relevant;
- top 3-5 values or segments;
- total value and unit;
- unknown, skipped, protected, or approximate categories;
- explanation when chart values are approximate or sampled;
- link or command to open equivalent table/list details.

For disk usage maps:

- include logical size, allocated size, and reclaim estimate only when the
  projection actually contains those facts;
- mark reclaim estimates as estimate, not truth;
- never imply chart selection is delete authority.

## Interactive Mark Contract

If marks are focusable, Headless MUST define:

- stable mark id;
- accessible name;
- accessible value text;
- description or path display policy;
- level, parent id, child count where hierarchical;
- selected/current state;
- disabled or unavailable reason;
- actions: select, open details, drill in, drill out, add to queue;
- keyboard order independent from visual packing quirks.

Keyboard SHOULD support:

- arrow keys for spatial or logical movement;
- `Enter` or `Space` to select;
- `Escape` to leave drill mode or return to parent;
- `Home` and `End` for first/last mark in current level;
- typeahead only when labels are safe and not privacy-sensitive.

## Renderer Adapter Rules

Canvas adapter:

- must provide semantic fallback because canvas pixels are not enough;
- must support hit-test mapping from pointer coordinate to mark id;
- must expose `CustomPainter.semanticsBuilder` or an equivalent semantic overlay
  when using Flutter custom painting;
- must not put thousands of mark nodes in the semantics tree by default.

SVG adapter:

- must provide title and description for the chart;
- may expose individual marks when count and semantics remain usable;
- must avoid using color alone for category differences.

Third-party adapter:

- must declare accessibility capability level;
- must support equivalent summary/table fallback even when its native semantics
  are incomplete;
- must be replaceable behind `DiskUsageMapView`.

## Clean Disk Mapping

Wide details pane:

- donut chart is summary mode by default;
- treemap can become interactive but TreeGrid remains primary;
- chart labels use node display names and sizes, with path details outside the
  chart label unless user opens details;
- selected chart mark mirrors selected TreeGrid node but does not create a
  delete plan.

Compact layout:

- chart must never push TreeGrid out of the primary workflow;
- if space is tight, show summary and top segments instead of dense marks;
- equivalent list remains available below or beside the chart.

## Conformance Tests

Minimum tests:

- non-decorative chart has title, description, and summary;
- interactive chart has keyboard-equivalent selection;
- color-only category distinction fails conformance;
- chart focus order is stable across responsive layout;
- chart mark selection maps to a node id, not a localized label;
- canvas renderer provides semantic summary or overlay;
- third-party adapter declares capability level;
- equivalent table/list projection exists for disk usage maps;
- chart cannot produce delete authority.

## Failure Catalog

- Beautiful canvas chart with no semantic fallback is inaccessible.
- Treemap geometry order is not a stable keyboard order.
- Color-only legends fail for many users.
- Thousands of focusable marks overwhelm assistive technology.
- Chart-driven cleanup without revalidation is unsafe.
