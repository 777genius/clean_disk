# Side Navigation Drawer Rail Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Disclosure Navigation Menu Example: https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/
- WAI-ARIA APG Landmarks Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/landmarks/
- MDN `navigation` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/navigation_role
- MDN `aria-current`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-current
- WCAG 2.4.1 Bypass Blocks: https://www.w3.org/WAI/WCAG22/Understanding/bypass-blocks.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- Flutter Material navigation: https://docs.flutter.dev/ui/widgets/material
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Scope

This standard covers side navigation, navigation rails, drawers, sidebar
navigation groups, collapsible navigation, recent items navigation, scan target
navigation, and route/location current markers.

It does not cover arbitrary command menus. Navigation changes location. Commands
perform operations.

## Decision Options

1. `NavigationSurface` with rail, sidebar, drawer, and disclosure adapters -
   🎯 9   🛡️ 9   🧠 8, roughly 900-1900 LOC.
   Best fit. It preserves one semantic model across wide, compact, web, and
   desktop layouts.
2. Use Flutter `NavigationRail`, `Drawer`, and `NavigationDrawer` directly -
   🎯 6   🛡️ 7   🧠 4, roughly 300-700 LOC.
   Good Material defaults, but weak for shared Headless semantics, custom
   keyboard contracts, and public renderer adapters.
3. Treat side navigation as a list of buttons -
   🎯 4   🛡️ 5   🧠 3, roughly 250-600 LOC.
   Simple but loses navigation semantics, current state, and route identity.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- navigation item identity;
- current item state;
- expanded/collapsed group state;
- route target or logical target;
- disabled/unavailable reason;
- disclosure behavior for groups;
- focus order;
- keyboard shortcuts;
- selection versus current semantics;
- badge/count attachment model;
- privacy class for item label and metadata.

Renderer owns:

- rail/sidebar/drawer visual mode;
- icons, compact labels, group indentation;
- responsive placement;
- selected/current styling;
- high contrast and reduced motion.

Application owns:

- route changes;
- scan target availability;
- recent scans source;
- permission and capability gating;
- localization.

## Navigation Item Types

Route item:

- points to app route;
- uses current state when active.

Scan target item:

- points to a target category such as Home, Downloads, Library, Apps, Custom;
- may show size estimate;
- must not become scan authority without application validation.

Recent item:

- references previous scan snapshot;
- read-only until current validation.

Group item:

- controls visibility of child navigation items;
- uses disclosure semantics, not menu semantics.

External item:

- opens documentation or support;
- follows link standard.

## Current State Rules

Use current state for:

- current route;
- current page in a navigation group;
- current scan target view;
- current history snapshot.

Do not use current state for:

- hover;
- focus;
- selected table row;
- queued cleanup item;
- checked filter.

`aria-current` mapping:

- `page` for route/page;
- `location` for current location-like item where adapter supports it;
- `step` belongs to wizard, not navigation sidebar.

## Keyboard Behavior

Required:

- Tab reaches navigation as one region or predictable sequence;
- arrow keys may supplement but not replace Tab on web-style navigation;
- Enter/Space activates disclosure buttons and route links according to role;
- Escape closes temporary drawer and returns focus to invoker;
- collapsed rail still exposes labels through semantics or tooltip standard;
- focus does not disappear when responsive mode changes.

Optional:

- Home/End among visible items;
- typeahead for large navigation lists;
- shortcuts for top-level sections.

## Drawer Versus Sidebar

Persistent sidebar:

- part of normal layout;
- not modal;
- participates in bypass navigation;
- should not trap focus.

Temporary drawer:

- overlay surface;
- may be modal or non-modal depending platform and layout;
- requires focus restore;
- closes on Escape;
- must not hide main content from screen readers unless modal.

Rail:

- compact persistent navigation;
- labels may be visually hidden but must remain accessible;
- selected/current state must be perceivable beyond color.

## Badge And Status Attachments

Counts and badges inside navigation:

- use token standard;
- must not be sole state indicator;
- dynamic changes should use status announcement only when meaningful;
- raw path or query counts must not leak private values.

Examples:

- skipped count;
- recent scan age;
- daemon disconnected;
- permission degraded.

## Clean Disk Usage

Wide layout:

- persistent scan-target sidebar;
- recent scans list;
- disk summary action.

Compact layout:

- top target chips or drawer;
- no permanent sidebar;
- equivalent navigation available through the same `NavigationSurface` model.

Web UI:

- route navigation must not encode private target paths in URLs;
- remote/headless modes may hide destructive navigation targets by capability.

## Conformance Scenarios

- current route is announced as current;
- collapsed rail item has accessible label;
- temporary drawer closes on Escape and restores focus;
- scan target size badge is not color-only;
- recent scan item opens history view, not cleanup authority;
- responsive transition preserves current item;
- unavailable item exposes reason;
- bypass command reaches main content without tabbing through full nav.

## Failure Catalog

- Sidebar buttons pretend to be tabs.
- Current scan target uses selected state and conflicts with table selection.
- Drawer traps focus even when non-modal.
- Collapsed rail exposes icon-only unlabeled controls.
- Recent scan target becomes delete authority.
- Private path appears in navigation route URL.
