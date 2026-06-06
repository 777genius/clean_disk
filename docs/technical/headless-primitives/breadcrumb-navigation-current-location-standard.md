# Breadcrumb Navigation And Current Location Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Breadcrumb Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/breadcrumb/
- MDN `navigation` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/navigation_role
- MDN `aria-current`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-current
- WCAG 2.4.1 Bypass Blocks: https://www.w3.org/WAI/WCAG22/Understanding/bypass-blocks.html
- WCAG 2.4.4 Link Purpose In Context: https://www.w3.org/WAI/WCAG22/Understanding/link-purpose-in-context.html
- WCAG 2.4.8 Location: https://www.w3.org/WAI/WCAG22/Understanding/location.html
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers breadcrumbs, current location markers, path bars, route
hierarchy, folder path chips, navigation lists, current route state, and compact
navigation overflow.

For Clean Disk this applies to the top path bar, scan target hierarchy, current
folder path, recent scans, settings breadcrumbs, and future history/compare
views.

## Decision Options

1. `NavigationTrail` primitive with breadcrumb and path-bar adapters - 🎯 9   🛡️ 8   🧠 7, roughly 700-1500 LOC.
   Best fit. It supports route breadcrumbs and filesystem path bars without
   treating raw disk paths as public route strings.
2. Plain row of buttons/links - 🎯 5   🛡️ 6   🧠 4, roughly 300-700 LOC.
   Works visually, but loses current item semantics, overflow rules, and privacy
   controls.
3. Reuse tabs or segmented controls for navigation trail - 🎯 3   🛡️ 4   🧠 5, roughly 400-900 LOC.
   Wrong semantics. Breadcrumbs describe location and ancestors, not peer panel
   selection.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- trail id;
- ordered segments;
- segment stable ids;
- segment kind: route, folder, volume, virtual root, search, history snapshot,
  settings section;
- current segment;
- overflow policy;
- privacy class per segment;
- navigation command facts;
- accessible label and description;
- current marker semantics.

Renderer owns:

- separators, icons, truncation, compact overflow, hover, and selected visuals;
- responsive chip layout;
- platform path separator display.

Application owns:

- route transition;
- filesystem authority;
- path display policy;
- localization;
- permission and availability of segment commands.

## Breadcrumb Contract

MUST:

- expose the trail as navigation where platform supports it;
- label the breadcrumb navigation when multiple navigation regions exist;
- mark the current item with current semantics where possible;
- keep current item non-commandable unless product has a specific action;
- preserve order from root to current;
- keep segment ids stable and separate from visible labels;
- handle compact overflow without removing current location meaning.

SHOULD:

- use links for route navigation segments on web when they navigate like links;
- use buttons for in-app commands that do not behave as links;
- expose overflow as a menu button with hidden ancestor segments;
- include enough context for duplicate segment names;
- support keyboard focus through visible segments and overflow.

MUST NOT:

- use tab semantics for breadcrumbs;
- use localized labels as route ids;
- expose raw private paths in route URLs;
- mark multiple segments current;
- rely only on separators visually to convey hierarchy.

## Filesystem Path Bar Contract

Filesystem path bars are breadcrumb-like but have extra privacy and authority
risk.

MUST:

- distinguish display path from authority path;
- keep path segment click actions behind application ports;
- treat hidden, restricted, cloud, virtual, and stale segments as capability
  facts, not visual styling only;
- redact or abbreviate paths in logs and support bundles;
- avoid putting full path in accessible name unless user explicitly requests
  path reading or details view;
- revalidate target before scan or cleanup commands.

SHOULD:

- expose volume/root segment distinctly;
- support copy path as an explicit command with privacy warning where needed;
- support reveal/open parent as platform command;
- show stale snapshot or historical path state clearly.

## Navigation List Contract

For side navigation and recent scans:

MUST:

- distinguish current item from selected item and focused item;
- expose navigation region label;
- keep recent scan entries as navigation or list items, not listbox options, if
  activation opens a view;
- keep destructive row actions outside ordinary navigation activation.

SHOULD:

- support roving focus only when the list is a composite navigation widget;
- support ordinary tab order for small static nav lists;
- provide current item state for the active route or active target.

## Clean Disk Mapping

Top path bar:

- represents current scan scope and selected node path;
- segment labels are display labels, not authority;
- current segment is the selected node or current folder view;
- restricted/skipped segments need status or warning, not only muted color.

Left sidebar:

- scan targets are navigation items;
- current target uses current state;
- storage size text is description, not part of command id.

Recent scans:

- list of snapshot navigation commands;
- current historical view must be clearly separate from current live scan;
- historical nodes cannot become cleanup targets without revalidation.

## Conformance Tests

Minimum tests:

- exactly one current segment exists;
- breadcrumb region has accessible label when needed;
- segment order is root to current;
- overflow menu exposes hidden ancestors;
- current segment is not accidentally activated as ordinary link;
- display path differs from authority path in tests;
- path labels are redacted in logs;
- recent scan item opens snapshot view but does not create cleanup authority;
- keyboard traversal reaches visible segments and overflow;
- duplicate segment names have enough context in details or description.

## Failure Catalog

- Breadcrumb implemented as tabs.
- Current location confused with selection.
- Full local path leaks into URL, logs, or accessible label.
- Overflow hides important ancestors from keyboard users.
- Historical path becomes destructive target without revalidation.
