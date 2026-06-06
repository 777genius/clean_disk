# Tabs Disclosure And Accordion Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Tabs Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/tabs/
- WAI-ARIA APG Accordion Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/accordion/
- WAI-ARIA APG Disclosure Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/
- MDN `tab` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/tab_role
- MDN `tablist` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/tablist_role
- MDN `tabpanel` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/tabpanel_role
- MDN `details`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/details
- Flutter Focus: https://docs.flutter.dev/ui/interactivity/focus

## Scope

This standard decides when Headless should expose tabs, disclosure, accordion,
or segmented command semantics. These primitives look similar visually but have
different accessibility contracts and keyboard expectations.

For Clean Disk this applies to details panes, compact delete queue sections,
scan target filters, settings categories, history/compare panels, and future
recommendation groups.

## Decision Options

1. Separate `Tabs`, `Disclosure`, and `Accordion` primitives with shared
   collection mechanics - 🎯 9   🛡️ 9   🧠 7, roughly 900-1800 LOC.
   Best fit. Shared focus and collection mechanics reduce duplication while
   preserving exact role semantics.
2. One generic expandable panel primitive for everything - 🎯 5   🛡️ 6   🧠 5, roughly 500-1000 LOC.
   Faster initially, but it blurs tab selection, disclosure expansion, and
   accordion heading semantics.
3. Use Material `TabBar` and expansion widgets only through visual wrappers -
   🎯 6   🛡️ 6   🧠 4, roughly 300-700 LOC.
   Good for MVP visuals, weak for a community Headless package because behavior
   and conformance cannot be standardized across renderers.

Accepted direction: option 1.

## Choosing The Primitive

Use tabs when:

- one panel is active at a time;
- switching panels changes the main content associated with a selected label;
- the set of tabs is small enough for arrow navigation;
- panel content can be preloaded or manual activation is chosen.

Use disclosure when:

- one button shows or hides one related section;
- the content remains part of the normal page flow;
- no coordinated group state is required.

Use accordion when:

- there is a vertical set of section headers;
- each header controls an associated panel;
- product policy can allow one open panel, many open panels, or at least one
  always open panel;
- headings are part of page information architecture.

Do not use tabs for filters, toggles, or mutually exclusive settings unless
they genuinely swap associated tab panels. Use segmented controls or radio
groups for those cases.

## Primitive Boundary

Headless owns:

- item identity and ordering;
- selected tab id, focused tab id, expanded panel ids;
- activation mode: automatic or manual;
- panel mount policy: mounted, lazy mounted, unmounted;
- keyboard behavior and focus restore;
- aria facts for tablist/tab/tabpanel, button/expanded, accordion heading level,
  disabled collapse state, and region usage policy;
- region proliferation guardrails.

Renderer owns:

- indicator, animation, spacing, icons, density, and panel transitions;
- responsive placement;
- visual collapse affordance;
- scroll or overflow styling.

Application owns:

- tab content data;
- route synchronization;
- persistence of selected or expanded ids;
- authorization for close/delete actions;
- localized labels.

## Tabs Contract

MUST:

- expose `tablist`, `tab`, and `tabpanel` semantics on web when using tab
  semantics;
- focus the active tab when tabbing into the tablist;
- use arrow keys to move between tabs according to orientation;
- support `Enter` or `Space` for manual activation;
- set selected state on the active tab and false selected state on inactive
  tabs;
- associate each tab with exactly one panel;
- include the panel in tab order when the panel has no focusable meaningful
  content;
- use manual activation when panel load has noticeable latency.

SHOULD:

- use automatic activation only when panel content is preloaded or switching is
  effectively instant;
- support `Home` and `End`;
- support close/delete only when focus after close is deterministic;
- expose tab deletion through a context menu as an alternative to `Delete`.

MUST NOT:

- auto-activate slow tabs and make arrow navigation wait on data loading;
- hide active panel content from semantics;
- use localized tab labels as stable ids;
- treat filter chips as tabs when they do not own panels.

## Disclosure Contract

MUST:

- expose a button-like control with expanded state;
- keep the control focusable whether expanded or collapsed;
- activate with `Enter` and `Space`;
- preserve focus on the trigger after toggling unless product workflow explicitly
  moves focus into revealed content;
- keep collapsed content out of accessibility traversal.

SHOULD:

- support native web `details` and `summary` adapter when styling and behavior
  match product needs;
- keep simple one-off show/hide behavior as disclosure, not accordion.

## Accordion Contract

MUST:

- represent each header as a heading containing exactly one button in web
  semantics;
- set expanded state on the header button;
- associate the header button with its panel;
- include all focusable panel content in normal tab order;
- enforce the product expansion policy: single, multiple, or at least one open.

SHOULD:

- support optional arrow navigation between headers;
- support `Home` and `End` between headers;
- use region semantics only when panel count is bounded and structure benefits
  screen reader navigation;
- avoid region role proliferation when many panels can be open.

## Clean Disk Mapping

Wide layout:

- the permanent left scan target list is navigation or list semantics, not tabs;
- details and delete queue are panels, not tabs, unless they become mutually
  exclusive content sections;
- settings categories may use tabs on desktop if all panels are local and fast.

Compact layout:

- delete queue collapse uses disclosure;
- secondary details sections can use accordion when several information groups
  compete for vertical space;
- target chips are segmented commands, not tabs, unless they switch tab panels.

## Conformance Tests

Minimum tests:

- tabs support automatic and manual activation modes;
- arrow focus movement does not activate manual tabs;
- slow/lazy panels force or recommend manual activation;
- tabpanel relationship is present in the web adapter;
- accordion heading level is configurable and valid in context;
- accordion region role is suppressed when too many panels are open;
- disclosure removes collapsed content from traversal;
- focus after close/delete is deterministic;
- route restore does not select a missing tab id;
- localized labels do not affect stable ids.

## Failure Catalog

- Calling filters tabs breaks keyboard expectations.
- Auto-activation with network or daemon latency makes keyboard navigation
  sluggish.
- Accordion regions for every panel create landmark noise.
- Animating collapse without updating hidden semantics creates phantom content.
- Keeping panel state in renderers breaks controlled state.
