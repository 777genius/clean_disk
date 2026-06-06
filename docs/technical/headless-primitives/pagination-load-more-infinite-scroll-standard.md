# Pagination Load More And Infinite Scroll Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `navigation` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/navigation_role
- MDN `aria-current`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-current
- WAI-ARIA APG Feed Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/feed/
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 2.4.4 Link Purpose In Context: https://www.w3.org/WAI/WCAG22/Understanding/link-purpose-in-context.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- MDN `aria-busy`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-busy
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers page navigation, cursor pagination, load more buttons,
virtualized page windows, infinite scroll, result counts, empty pages, stale
pages, and pagination inside tables, lists, logs, feeds, and TreeGrid queries.

It does not replace viewport virtualization. Pagination is a data/query
contract. Virtualization is a rendering contract.

## Decision Options

1. Cursor-first `PagedCollection` contract with pagination, load-more, and feed
   adapters - 🎯 9   🛡️ 9   🧠 8, roughly 900-2000 LOC.
   Best fit. It works for daemon queries, web, TreeGrid pages, logs, and search.
2. Offset page numbers only - 🎯 5   🛡️ 6   🧠 4, roughly 400-900 LOC.
   Simpler, but weak for changing scan snapshots and large sorted datasets.
3. Infinite scroll only - 🎯 3   🛡️ 4   🧠 5, roughly 500-1100 LOC.
   Feels smooth visually but creates focus, footer access, and state recovery
   problems.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- page/query id;
- cursor;
- page size;
- total known/unknown state;
- current page/window;
- loading, stale, error, and end states;
- focus restore after page change;
- announcement policy for result count changes;
- navigation item labels;
- current page semantics;
- load-more command contract.

Renderer owns:

- pager layout, buttons, compact overflow, skeleton rows, spinner, and count
  display.

Application owns:

- query semantics;
- backend cursor;
- sorting/filtering contract;
- cache invalidation;
- authorization and privacy.

## Pagination Modes

Numbered pages:

- use when total count and stable order are known;
- expose current page;
- page links/buttons have clear purpose.

Cursor pages:

- use when data changes or total is unknown;
- expose previous/next/load more labels;
- do not fake page numbers.

Load more:

- explicit command;
- keeps user in control;
- best default for logs and result lists.

Infinite scroll:

- only when feed semantics or clear recovery/focus strategy exists;
- must not block access to footer or following content;
- must have alternative navigation or load-more fallback.

Virtualized window:

- renderer may show only visible rows;
- data contract still uses stable ids/cursors;
- focus and selection cannot depend on visible index.

## Required Rules

MUST:

- keep page/query identity stable;
- distinguish loading next page from replacing current query;
- mark current page or current range where applicable;
- restore focus to a logical target after page changes;
- announce result count changes as status when useful;
- expose busy state while page content is being replaced;
- handle stale cursor and snapshot mismatch;
- preserve selection by stable id, not row/page index.

SHOULD:

- prefer cursor-based queries for scan data;
- keep load-more button reachable after appended content;
- support "back to top" or region navigation for long loaded content;
- provide explicit empty, end, and error states;
- keep previous content visible during background page load when safe.

MUST NOT:

- use infinite scroll for critical cleanup review without explicit navigation;
- move focus unexpectedly to the top after appending content;
- fake total page count when total is unknown;
- lose keyboard position after sort/filter changes;
- allow stale visible row to become delete authority.

## Clean Disk Mapping

Rust owns sorted/filtered pages. Flutter asks for pages and renders them.

TreeGrid:

- query pages use cursor or parent+offset depending adapter;
- visible row virtualization is separate from Rust pagination;
- selection and cleanup queue use node ids, not visible row indexes.

Search:

- result count can be approximate or unknown;
- result pages carry snapshot id and query id;
- stale query results cannot be used for delete validation.

Logs:

- load more or reverse cursor is preferred;
- infinite scroll only with feed/log standard support.

## Conformance Tests

Minimum tests:

- page change has deterministic focus target;
- current page/range is exposed;
- load-more button remains reachable;
- busy state appears while replacing results;
- stale cursor returns explicit stale state;
- selection survives page changes by id;
- sort/filter reset invalidates old page cursor;
- infinite scroll has fallback or feed contract;
- result count status is throttled;
- visible row index is never cleanup authority.

## Failure Catalog

- Infinite scroll traps keyboard users before footer.
- Page number links all say "1", "2", "3" without context.
- Sort changes but old cursor still fetches rows.
- Selection by page index deletes wrong item.
- Loading replaces focused content and loses focus.
