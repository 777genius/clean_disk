# Search Result Count And Navigation Standard

## Status

Accepted direction for Headless. Complements query/filter/sort, combobox/search,
inline highlight, result-set, and status-message standards. Not implemented yet.

## Source Standards

- MDN `search` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/search_role
- MDN `searchbox` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/searchbox_role
- MDN `mark`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/mark
- MDN ARIA live regions: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/ARIA_Live_Regions
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- WCAG 2.4.4 Link Purpose In Context: https://www.w3.org/WAI/WCAG22/Understanding/link-purpose-in-context.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html

## Problem

Search UI is more than a text input. Users need to know when search is running,
how many results exist, which result is current, whether the result set is
stale, how to move between matches, and what scope is searched. If result count
is only visual or every update is announced too loudly, large data UIs become
frustrating.

Headless needs a search result count and navigation contract.

## Decision Options

1. Let search field own all result behavior - 🎯 4   🛡️ 4   🧠 2, about
   80-200 LOC. Too narrow for large result surfaces.
2. Add separate search session and result navigation semantics - 🎯 9
   🛡️ 9   🧠 6, about 450-1100 LOC. Best fit.
3. Force search results into combobox suggestions - 🎯 5   🛡️ 5   🧠 5,
   about 250-700 LOC. Wrong for full-page or tree/table search.

Accepted: option 2.

## Accepted Contract

Headless models search session state:

```dart
final class RSearchResultSemantics {
  final String searchSessionId;
  final String scopeLabel;
  final RSearchState state;
  final int? totalResults;
  final int? visibleResults;
  final int? currentResultIndex;
  final bool stale;
  final RSearchAnnouncementPolicy announcementPolicy;
}
```

Result navigation is separate from query editing:

```dart
final class RSearchNavigationCommand {
  final RSearchNavigationKind kind;
  final String searchSessionId;
}
```

## Search States

```text
idle:
  no active query

searching:
  query is running

results:
  results available

noResults:
  query completed with no results

partial:
  results are incomplete or still loading

stale:
  results no longer match current authoritative snapshot

error:
  search failed
```

## Rules

- Search field value is not result state.
- Result count is announced through status, not stuffed into field label.
- Current result index is optional but useful for match navigation.
- Search scope is explicit.
- Search result set is versioned by snapshot, query, and filter.
- Highlight is visual annotation, not selection or authority.
- Navigation commands do not mutate query text.
- Stale result disables risky actions or requires revalidation.

## Clean Disk Requirements

Clean Disk uses search over:

- current scan tree;
- visible rows;
- top files;
- cleanup candidates;
- receipts/history;
- support bundle preview;
- settings.

Search in the scan tree must query Rust indexes and return pages. Flutter must
not search the full tree locally.

## Announcement Rules

Announce:

- search started after debounce if visible delay exists;
- result count when query completes;
- no results;
- current result position when using next/previous;
- stale or failed state.

Do not announce:

- every keystroke;
- every incremental partial count;
- every highlighted match in a row;
- private raw query text in production logs.

## Web Mapping

For web adapters:

- `search` region scopes search controls;
- `searchbox` can represent a search input when native input semantics are not
  enough;
- live region announces status messages;
- `mark` highlights matches;
- result list or table semantics carry actual results.

Flutter adapters should expose equivalent status and navigation semantics.

## Accessibility Rules

- Users can move to next and previous result by keyboard.
- Result count is discoverable without leaving search field.
- No-result state includes recovery suggestion where useful.
- Stale search state is clear.
- Query text is not logged raw.
- Search scope label distinguishes current folder, whole scan, history, or
  settings.

## Testing Requirements

- Result count announcement fires once per completed query.
- Next result announces current position.
- No-results state is exposed.
- Stale snapshot invalidates result set.
- Highlight does not change selection.
- Search scope is accessible.
- Query text is redacted in diagnostics.

## Failure Catalog

- Search field label becomes "Search, 532 results".
- Every partial count update is announced.
- Highlighted deleted row can be queued without revalidation.
- Search result count belongs to old snapshot.
- Next result moves focus into hidden row.
- Query text appears in telemetry.

## Release Gates

- Search session state is separate from input field.
- Clean Disk scan search uses daemon/Rust query pages.
- Result count and current position are status messages.
- Stale result policy is enforced before risky commands.
- Search fixtures cover no result, partial, stale, huge, and redacted queries.

## Summary

Search result semantics include scope, state, count, current match, stale
version, and announcements. Headless should model these separately from the
text input and separately from result rendering.
