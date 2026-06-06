# Empty Skeleton And Placeholder State Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `aria-busy`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-busy
- MDN ARIA live regions: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers loading skeletons, placeholders, empty states, no-results
states, permission-empty states, degraded states, partial states, stale states,
and replacement content during async loading.

It complements the async/error/empty/disabled contract by defining the concrete
UI primitive behavior.

## Decision Options

1. Typed `ContentState` primitive with separate loading, empty, no-results,
   permission, stale, and partial variants - 🎯 9   🛡️ 9   🧠 7, roughly 800-1600 LOC.
   Best fit. It prevents "empty" from hiding errors, permissions, or stale data.
2. One generic empty/loading component - 🎯 5   🛡️ 5   🧠 3, roughly 250-600 LOC.
   Fast, but product risk is high because every state looks the same.
3. Let each feature render states manually - 🎯 4   🛡️ 5   🧠 4, roughly 300-1000 LOC per feature over time.
   Flexible but inconsistent, and it will leak authority mistakes into cleanup
   flows.

Accepted direction: option 1.

## State Types

Loading:

- data is not ready;
- content may be replaced or appended;
- expose busy state where useful.

Skeleton:

- visual placeholder approximating future layout;
- usually decorative;
- should not create fake rows, labels, or authority.

Empty:

- valid result contains no items;
- example: empty cleanup queue.

No results:

- query/filter returns no matches;
- should include query/filter context when privacy policy allows it.

Permission empty:

- content may exist but app cannot access it;
- must show repair path where possible.

Stale:

- previously valid data no longer matches current snapshot/session;
- risky actions disabled.

Partial:

- some data loaded and some failed/skipped;
- must expose what is missing and why.

## Primitive Boundary

Headless owns:

- content state kind;
- state reason code;
- busy flag;
- announcement policy;
- repair/action contracts;
- stale/risky-action policy;
- placeholder authority flag;
- privacy class for state text;
- focus behavior after state change.

Renderer owns:

- skeleton geometry, shimmer, icons, spacing, illustration, layout, and compact
  visual treatment.

Application owns:

- actual reason;
- repair commands;
- authorization;
- data retry;
- localization.

## Required Rules

MUST:

- distinguish empty, no-results, permission denied, error, stale, and partial;
- mark regions busy while content is being updated when platform supports it;
- avoid announcing decorative skeleton internals;
- never treat placeholder rows as real data;
- disable destructive actions in stale, loading, permission, and unresolved
  placeholder states;
- preserve focus or move it to a logical state message only when the current
  focused item disappeared;
- expose repair/retry command labels when present;
- redact query/path text in state messages by policy.

SHOULD:

- keep prior content visible during background refresh when safer;
- show no-results state near the query/filter that produced it;
- expose skipped/partial facts as details, not generic emptiness;
- support reduced motion by disabling shimmer or replacing it with static
  placeholders;
- provide bounded skeleton count to avoid layout thrash.

MUST NOT:

- hide permission denial behind "Nothing here";
- let skeleton row be selectable;
- move focus repeatedly as loading progresses;
- announce every skeleton paint;
- use empty state as error recovery;
- use fake counts that look authoritative.

## Clean Disk Mapping

Scan not started:

- app state, not empty result.

Scanning:

- busy state with progress/status;
- skeleton rows are visual only and not selectable.

No search results:

- no-results state scoped to query;
- raw query is privacy-sensitive.

Permission denied:

- permission-empty or degraded state with repair action;
- not a true empty folder.

Cleanup queue empty:

- valid empty state;
- move to trash disabled.

Stale scan:

- stale state; details may be visible read-only;
- delete plan validation required before any cleanup.

## Conformance Tests

Minimum tests:

- empty and no-results render different reason codes;
- permission denied is not empty;
- skeleton children are not announced individually;
- placeholder row cannot be selected or queued;
- busy state toggles during replacement;
- reduced motion disables shimmer;
- stale state disables destructive commands;
- retry/repair action is labelled and command-routed;
- focus remains stable during background loading;
- raw query/path is redacted when privacy policy requires it.

## Failure Catalog

- "No files found" shown because Full Disk Access is missing.
- Skeleton row appears selectable.
- Loading state steals focus every second.
- Search no-results logs raw private query.
- Stale cached view still allows cleanup.
