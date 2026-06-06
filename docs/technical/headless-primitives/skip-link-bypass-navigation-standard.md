# Skip Link Bypass Navigation Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 2.4.1 Bypass Blocks: https://www.w3.org/WAI/WCAG22/Understanding/bypass-blocks.html
- WAI-ARIA APG Landmarks Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/landmarks/
- MDN `main` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/main_role
- MDN `navigation` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/navigation_role
- MDN `region` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/region_role
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- Flutter focus system: https://docs.flutter.dev/ui/interactivity/focus
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers skip links, bypass actions, jump-to-main commands,
landmark shortcuts, keyboard-first entry points, repeated navigation bypass,
and compact desktop equivalents for apps that do not render native HTML.

It complements the landmark/app shell standard. That file defines regions.
This file defines the user's fast path through those regions.

## Decision Options

1. `BypassNavigation` primitive bound to landmarks and command intents -
   🎯 9   🛡️ 9   🧠 7, roughly 700-1400 LOC.
   Best fit. It works for Flutter desktop, Flutter web, future web ARIA bridge,
   and product shells with dense navigation.
2. Rely only on landmarks - 🎯 5   🛡️ 6   🧠 3, roughly 200-500 LOC.
   Useful for screen readers but not enough for keyboard-only users who do not
   use landmark navigation shortcuts.
3. Add one hidden "skip to content" link in the app shell only -
   🎯 6   🛡️ 6   🧠 3, roughly 150-400 LOC.
   Better than nothing, but weak for multi-pane desktop apps with sidebar,
   tree grid, details pane, logs, and delete queue.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- bypass target registry;
- target ids and labels;
- target kind: main, navigation, search, content, details, status, queue,
  footer, or custom region;
- target availability;
- focus transfer command;
- focus restoration policy;
- announcement policy;
- keyboard shortcut contract;
- web adapter mapping to skip links and landmarks;
- privacy class for region labels.

Renderer owns:

- visible-on-focus styling;
- compact command palette presentation;
- high contrast focus ring;
- visual placement.

Application owns:

- which regions exist;
- which targets are safe to expose;
- route-specific target enablement;
- product copy and localization;
- user preference for visible skip controls.

## Target Model

Target identity:

- stable within route/layout instance;
- not derived from private path, query, node id, or daemon id;
- survives responsive layout changes when semantic target is same.

Target label:

- describes destination, not implementation;
- localized;
- must not include raw filesystem paths by default;
- may include a generic context such as "folder table" or "cleanup queue".

Target availability:

- available;
- temporarily hidden;
- disabled due to layout;
- stale due to route transition;
- unavailable in current mode.

## Required Targets For Clean Disk

Wide layout:

- main folder tree table;
- scan target sidebar;
- top search/sort area;
- details pane;
- delete queue;
- bottom scan status;
- settings or command bar.

Compact layout:

- target chips;
- main folder tree table;
- details section;
- collapsible delete queue;
- bottom scan status.

Web UI:

- main route content;
- daemon status;
- navigation shell;
- support/diagnostics area when present.

## Keyboard Behavior

Required:

- first keyboard stop can reveal bypass controls where platform supports it;
- a command must move focus to the selected target;
- focus target must be meaningful, not a decoration wrapper;
- hidden target cannot receive focus;
- target change must not trigger destructive action;
- Escape from bypass menu returns focus to invoker.

Recommended shortcuts:

- web: visible skip link as first tabbable item;
- desktop: command palette entry and optional platform shortcut;
- screen reader: landmarks plus named regions;
- compact layout: jump to table, jump to queue, jump to status.

## Focus Transfer Rules

On activation:

1. validate target still exists;
2. close transient overlays if they are not the target;
3. focus the target's focus anchor;
4. optionally scroll target into view;
5. announce target if platform will not announce it naturally.

Do not:

- focus a row that is not selected by user intent;
- focus disabled destructive command;
- focus a virtualized child that may unmount immediately;
- scroll without moving focus when user requested keyboard bypass.

## Semantics Mapping

Web adapter:

- use real anchor skip links when possible;
- map major regions to native landmarks or ARIA landmarks;
- use `main`, `navigation`, `complementary`, `search`, `region`, and headings
  appropriately;
- keep landmarks limited and useful;
- avoid duplicate unlabeled navigation regions.

Flutter desktop adapter:

- use Semantics labels and focus anchors;
- use Actions/Shortcuts for bypass commands;
- expose enough region structure for screen readers;
- verify with platform accessibility tools.

## Privacy Rules

Bypass labels must not expose:

- full local paths;
- search query text;
- daemon token;
- username-derived folder names;
- cleanup target names;
- support bundle filenames.

Use generic labels:

- "main folder table";
- "details panel";
- "delete queue";
- "scan status".

## Conformance Scenarios

- first Tab reveals or reaches bypass mechanism on web;
- jump to main focuses folder table anchor;
- jump to delete queue does not confirm deletion;
- jump to status does not announce raw scanned path;
- route change invalidates stale targets;
- compact breakpoint preserves equivalent bypass targets;
- screen reader can discover named regions;
- high contrast mode keeps skip control visible when focused.

## Clean Disk Usage

Clean Disk should expose bypass targets for the central tree, details, delete
queue, status footer, target navigation, and search. The primitive must never
use scan path strings as labels or ids.

## Failure Catalog

- Landmarks exist but keyboard-only users still tab through 80 controls.
- Skip target receives scroll but not focus.
- Focus lands inside a virtualized row that unmounts.
- Private folder name appears in skip link label.
- Compact layout removes the bypass target for the delete queue.
- Renderer hides focus-visible skip link in high contrast mode.
