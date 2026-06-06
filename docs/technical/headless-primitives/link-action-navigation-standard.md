# Link Action And Navigation Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Link Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/link/
- MDN `link` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/link_role
- MDN `aria-current`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-current
- WCAG 2.4.4 Link Purpose In Context: https://www.w3.org/WAI/WCAG22/Understanding/link-purpose-in-context.html
- WCAG 3.2.2 On Input: https://www.w3.org/WAI/WCAG22/Understanding/on-input.html
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers links, route links, external links, file/location links,
inline links, row links, breadcrumb segment links, current page links, and
link-like command visuals.

It does not cover buttons. A link references a resource or navigation target. A
button performs an action. If a visual design wants a link-looking button, the
semantics still follow the function.

## Decision Options

1. Separate `LinkAction` from `ButtonCommand` with shared text and focus
   contracts - 🎯 9   🛡️ 9   🧠 6, roughly 500-1000 LOC.
   Best fit. It prevents action/navigation confusion while reusing labels,
   shortcuts, privacy, and command dispatch.
2. Treat every clickable text as a button command - 🎯 4   🛡️ 5   🧠 4, roughly 250-600 LOC.
   Fast, but breaks web expectations, link context menus, browser navigation,
   and screen reader link lists.
3. Treat every clickable row or text as a link - 🎯 4   🛡️ 5   🧠 5, roughly 400-900 LOC.
   Also wrong. Mutating actions, delete, reveal, queue, and scan start are not
   links.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- link id and target id;
- target kind: route, external URL, local file, filesystem location, snapshot,
  documentation, support bundle, or in-page anchor;
- accessible text contract;
- link purpose contract;
- current state;
- visited state where platform supports it and product allows it;
- disabled/unavailable reason;
- privacy class for URL, path, label, and description;
- focus and keyboard behavior;
- external/open-in-new-context disclosure policy.

Renderer owns:

- text style, underline, icon, hover, focus ring, visited color, and truncation;
- external link icon visuals;
- compact row presentation;
- high contrast styling.

Application owns:

- actual route transition;
- browser/native open behavior;
- platform reveal/open policy;
- telemetry and audit;
- user authorization.

## Link Versus Button Rule

Use link when:

- activation navigates to a resource or route;
- activation changes URL or location history;
- activation opens documentation, support page, folder location, or snapshot
  route;
- the user can reasonably expect link context menu behavior on web.

Use button when:

- activation mutates state;
- activation starts, pauses, cancels, deletes, validates, queues, copies,
  exports, refreshes, or scans;
- activation opens a dialog, menu, popover, or command surface;
- activation depends on command authorization rather than navigation target.

Use neither if the item is only selected or focused inside a composite widget.

## Keyboard Contract

MUST:

- activate links with `Enter`;
- not require `Space` for link activation;
- support context menu intent where platform supports it;
- preserve focus order that matches reading/navigation order;
- expose current link state only for active route or location;
- keep link text meaningful from text or programmatic context.

SHOULD:

- use native web links where web adapter can expose real URLs safely;
- expose shortcut hints separately from accessible name;
- keep route links in normal tab order unless inside a composite navigation
  primitive with roving focus.

MUST NOT:

- use link role for delete, queue, scan, cancel, reveal action, or settings
  toggle;
- use button role for documentation or route navigation just because it looks
  like a button;
- use "click here", "more", or "open" without useful context;
- expose raw local paths as web URLs;
- mark multiple navigation items current in one scope.

## Privacy And Security

Local links are dangerous in Clean Disk because a filesystem path may reveal
private names.

MUST:

- separate display label from authority target;
- classify raw path/URL before logging, telemetry, support bundles, or route
  state;
- show platform permission/state when target cannot be opened;
- revalidate filesystem target before using it as cleanup authority;
- avoid copying local path to clipboard without an explicit command.

## Clean Disk Mapping

Accepted links:

- documentation links;
- settings route links;
- scan history snapshot links;
- breadcrumb/path segments when they navigate to a scanned node view;
- support bundle help links.

Accepted buttons instead:

- reveal in Finder;
- add to queue;
- move to trash;
- scan, pause, cancel, refresh;
- copy path;
- open filter menu.

TreeGrid row names are not automatically links. In rows-first mode, row
activation is a TreeGrid command. A cell may expose a link only if it navigates
to a separate route or resource.

## Conformance Tests

Minimum tests:

- link activates with `Enter`;
- link purpose is understandable from name or programmatic context;
- link-looking delete control fails conformance;
- current state appears once per navigation scope;
- external link disclosure is available where product policy requires it;
- local path target is redacted in logs;
- route link preserves route identity separate from label;
- link inside TreeGrid does not steal row navigation unexpectedly;
- unavailable link exposes reason;
- web adapter uses native link when safe.

## Failure Catalog

- "Reveal in Finder" exposed as a link despite being a platform command.
- Generic "Open" links in rows are meaningless in screen reader link lists.
- Raw path placed in href or route.
- Link style used as decoration without focus affordance.
- Current state used as selection state.
