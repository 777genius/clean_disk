# Async Loading Busy And Cancellation Standard

## Status

Implementation standard for async child loading, paged data, busy state,
retry, error recovery, and cancellation in Headless primitives.

## Purpose

TreeGrid, large menus, command palettes, search results, and virtualized lists
often load data asynchronously. Headless must support loading without owning
product data access and without confusing assistive technology or cleanup
authority.

## Standards And References

- MDN `aria-busy`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-busy
- MDN ARIA live regions:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/ARIA_Live_Regions
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- Flutter accessibility testing:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing
- Flutter performance profiling:
  https://docs.flutter.dev/perf/ui-performance

## Core Rule

Headless can represent async state and emit load commands. Application code owns
actual data loading, errors, retries, permissions, and cache policy.

```text
Headless command
  -> application load request
  -> app data result
  -> Headless state update
```

Headless must never call product repositories directly.

## Async State Model

Per collection or node:

```text
notLoaded
loading
loaded
empty
error
stale
refreshing
cancelled
permissionDenied
```

Additional facts:

- request id;
- data version;
- parent key;
- expected range;
- loaded count;
- total count if known;
- error category;
- retry policy;
- cancellation token;
- privacy class.

## Busy Semantics

Busy state should mean "content is being updated and may not be complete".

Rules:

- busy state is semantic fact, not just spinner visual;
- status announcement is throttled;
- loaded partial content remains navigable only if policy allows;
- update complete emits concise result where useful;
- repeated progress updates do not spam live regions;
- stale content is visually and semantically distinguishable.

For future web ARIA adapters, `aria-busy` can delay announcements while content
is incomplete. Core Headless stores busy intent, not literal `aria-busy`.

## Cancellation Model

Cancellation reasons:

```text
userCancelled
nodeCollapsed
routeChanged
queryChanged
componentDisposed
newerRequestStarted
timeout
policyDenied
```

Rules:

- late response with old request id is ignored;
- cancelled request does not overwrite newer loaded data;
- collapse can cancel child loading by policy;
- dispose cancels all component-owned requests;
- app-owned loaders receive cancellation intent but may finish internally;
- diagnostics record category only.

## Error Model

Error facts:

- recoverable or fatal;
- retryable or not;
- permission-related or not;
- partial data available or not;
- user-visible message key;
- diagnostic category;
- privacy class.

Renderer may display error state. Application owns localized error text and
recovery action.

## Retry Policy

Retry can be:

- user action;
- automatic with capped attempts;
- blocked by policy;
- delegated to application.

Headless should expose retry command only when retry is allowed. Disabled retry
must be represented as disabled command, not hidden failure.

## Virtualization Interaction

Async loading and virtualization must not require full materialization.

Rules:

- viewport asks for ranges or children by key;
- missing data produces placeholder rows only if policy allows;
- placeholders have stable keys;
- row count can be known, unknown, approximate, or loading;
- scroll-to-target can return `targetNotLoaded`;
- selection cannot include unresolved placeholder unless policy explicitly
  supports it.

## Clean Disk Boundary

For Clean Disk:

- Rust owns scan tree and indexes;
- Flutter queries pages;
- Headless displays view models only;
- async state does not create cleanup authority;
- stale rows cannot be added to delete plan without validation.

## Evidence

Automated:

- late response ignored;
- cancellation on collapse;
- cancellation on dispose;
- retry command visibility;
- busy semantics present;
- placeholder row not selected by accident;
- stale data warning state.

Manual:

- screen reader receives concise loading/completion state;
- keyboard focus survives loading;
- loading failure can be retried without mouse;
- refreshing does not reset scroll unexpectedly.

## Stop Rules

- Do not let Headless import repositories or HTTP clients.
- Do not let late async response overwrite newer state.
- Do not announce every loaded item.
- Do not use loading placeholder as product authority.
- Do not hide permission errors as empty state.
