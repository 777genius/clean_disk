# Landmark Region And App Shell Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `main` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/main_role
- MDN `navigation` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/navigation_role
- MDN `complementary` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/complementary_role
- MDN `region` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/region_role
- WAI-ARIA APG Landmark Regions: https://www.w3.org/WAI/ARIA/apg/practices/landmark-regions/
- WCAG 2.4.1 Bypass Blocks: https://www.w3.org/WAI/WCAG22/Understanding/bypass-blocks.html
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard defines how Headless and the design system describe app shell
regions: main content, navigation, complementary panes, search, toolbars,
status/footer regions, dialogs, overlays, and virtualized content areas.

For Clean Disk this maps the wide layout, compact layout, daemon-served web UI,
settings, diagnostics, scan history, and future remote/headless dashboards.

## Decision Options

1. App shell region registry with platform landmark adapters - 🎯 9   🛡️ 9   🧠 7, roughly 700-1500 LOC.
   Best fit. The app declares semantic regions once and renderers/platform
   adapters decide how to map them.
2. Landmarks embedded ad hoc in each widget - 🎯 4   🛡️ 5   🧠 4, roughly 300-800 LOC.
   Fast at first, but it creates duplicate main regions and noisy landmark
   navigation.
3. No app landmarks until web renderer needs them - 🎯 3   🛡️ 4   🧠 2, roughly 100-300 LOC.
   Weak for community Headless because desktop, web, and screen reader users
   need consistent structure.

Accepted direction: option 1.

## Region Model

Headless defines semantic region facts, not visual layout:

- app root;
- banner or top app controls;
- primary navigation;
- main work surface;
- complementary details pane;
- complementary cleanup queue;
- search region;
- status region;
- modal region;
- diagnostics/log region.

Every region has:

- stable region id;
- role candidate;
- visible label id or localized accessible label;
- privacy class for labels;
- landmark importance: landmark, named region, semantic group, or visual only;
- responsive behavior: persistent, collapsible, moved, hidden, modalized;
- focus entry target;
- restore policy.

## Landmark Rules

MUST:

- expose exactly one active main region per route or document;
- label multiple navigation or complementary regions;
- provide a bypass path to main content for web and keyboard-heavy desktop
  shells;
- update active/inactive semantics when responsive layout moves or hides panes;
- keep modal dialogs outside ordinary landmark traversal while modal;
- ensure region labels are stable across locale changes except for translated
  display text;
- keep scanner paths and user file names out of app landmark labels.

SHOULD:

- prefer native semantic elements on web when available;
- use named regions for major panes only;
- expose TreeGrid as the main work surface in scan views;
- expose details and delete queue as complementary regions in wide layout;
- collapse compact panes into named disclosures rather than duplicate
  complementary landmarks.

MUST NOT:

- create one region landmark per card, row, accordion panel, or chart;
- keep hidden responsive panes in the accessibility tree;
- expose background route landmarks behind modal dialogs;
- use visual headings alone as landmark structure without programmatic mapping.

## Flutter Adapter Contract

Flutter does not map one-to-one to web landmarks on all platforms. The adapter
therefore must expose the closest stable semantic structure:

- `Semantics(container: true)` for major app regions;
- route naming with `scopesRoute` and `namesRoute` where route transitions need
  orientation;
- sort keys only where traversal order differs from widget order;
- `ExcludeSemantics` for inactive duplicate panes;
- explicit labels for app regions that are visually persistent but not obvious
  from text;
- `SemanticsDebugger` and semantics tree dumps in conformance tests.

The web adapter may add DOM landmarks around Flutter-rendered surfaces when a
platform bridge is available. That adapter must be generated from the same
region registry and must not be handwritten in product widgets.

## Clean Disk Wide Layout

Accepted semantic map:

- app banner: window controls, title, top commands;
- primary navigation: scan targets and recent scans;
- main: folder TreeGrid and top metrics;
- complementary details: selected node details and charts;
- complementary cleanup: delete queue when visible as a separate pane;
- status: scan progress footer;
- search: search field and result count when search is active.

## Clean Disk Compact Layout

Accepted semantic map:

- app banner: compact top controls;
- main: target selector, metrics, TreeGrid;
- details: named disclosure below the tree;
- cleanup queue: named disclosure, not persistent complementary landmark unless
  expanded as a major pane;
- status: sticky scan progress footer.

## Conformance Tests

Minimum tests:

- exactly one active main region exists;
- repeated navigation regions are named;
- hidden responsive panes are excluded from semantics;
- modal dialog suppresses background landmark traversal;
- skip or bypass command focuses main work surface;
- compact and wide layouts have equivalent region intent;
- TreeGrid remains the main workflow after responsive changes;
- support bundle or logs do not include raw region labels with private paths;
- semantics tree dump matches expected region registry.

## Failure Catalog

- Landmark spam makes screen reader region navigation useless.
- Duplicate main regions appear after responsive layout changes.
- Hiding a pane visually but keeping semantics active creates ghost content.
- Putting file paths in region labels leaks private data.
- Product widgets inventing their own landmarks breaks consistency.
