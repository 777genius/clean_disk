# Accessibility Event Order And Cache Invalidation Standard

## Status

Accepted as a Headless dynamic semantics standard. Not implemented yet.

## Source Standards

- WAI-ARIA User Agent Implementation Guide: https://www.w3.org/TR/wai-aria-implementation/
- MDN ARIA live regions: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/ARIA_Live_Regions
- MDN `aria-live`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-live
- MDN `aria-busy`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-busy
- MDN MutationObserver: https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Scope

This standard defines how Headless orders semantic updates, focus changes,
state changes, live announcements, and cache invalidation for assistive
technology.

It applies to:

- virtualized collections;
- active descendant navigation;
- live regions;
- busy loading;
- progress updates;
- route transitions;
- dialog open/close;
- TreeGrid row expansion and selection.

It does not guarantee exact screen reader phrase timing. It creates predictable
semantic event order and testable traces.

## Decision Options

Option A: Update visual state and hope semantics follow - 🎯 3   🛡️ 3
🧠 2, about 100-250 LOC.

- Simple.
- Dynamic UIs produce stale or missing AT output.

Option B: Emit announcements after every state change - 🎯 4   🛡️ 4
🧠 3, about 300-700 LOC.

- Users hear something.
- Noise, duplicates, and stale announcements become likely.

Option C: Ordered semantic transaction with cache invalidation hints - 🎯 9
🛡️ 9   🧠 8, about 1200-2400 LOC.

- Accepted direction.
- Visual, logical, semantic, and announcement updates are coordinated.
- Virtualization can update without lying to assistive tech.

## Accepted Direction

Headless should define `SemanticUpdateTransaction`.

Transaction phases:

1. apply logical state;
2. compute semantic diff;
3. mark affected regions busy if needed;
4. update focus or active descendant;
5. update role/state/value facts;
6. clear busy state;
7. publish announcement intent;
8. record trace.

## Event Classes

Classes:

- `focusMoved`;
- `activeDescendantChanged`;
- `selectionChanged`;
- `expandedChanged`;
- `valueChanged`;
- `rowMounted`;
- `rowUnmounted`;
- `collectionWindowChanged`;
- `busyStarted`;
- `busyEnded`;
- `statusAnnounced`;
- `routeContextChanged`.

Each event has ordering rules and privacy class.

## Cache Invalidation Rules

Rules:

- row identity changes invalidate row semantic cache;
- label changes invalidate accessible name cache;
- virtualization window changes invalidate collection position facts;
- busy state delays non-urgent announcement;
- active descendant update precedes selection announcement;
- route change clears stale status scoped to old route.

Do not emit one semantic transaction per filesystem item in Clean Disk.

## Live Region Timing Rules

Rules:

- live region node exists before content update in web adapter;
- repeated progress updates are coalesced;
- assertive messages require user-impact justification;
- `aria-busy` is cleared after final meaningful update;
- status message does not move focus unless workflow explicitly requires focus.

## Clean Disk Requirements

Clean Disk requires transactions for:

- scan progress milestones;
- TreeTable expand/collapse;
- selection and cleanup queue count;
- search result count;
- stale delete plan state;
- daemon disconnected/reconnected;
- move-to-trash result.

Critical rule:

- a cleanup warning must not be announced before the visible confirmation state
  exists.

## API Shape Sketch

```text
SemanticUpdateTransaction
  id
  scope
  logicalChanges
  semanticDiff
  focusEvent
  busyPolicy
  announcementIntents
  invalidatedRefs
  trace
```

## Conformance Scenarios

Required scenarios:

- active descendant changes before row details announcement;
- live region is present before update;
- rapid progress emits milestone announcements only;
- route change clears old operation status;
- virtualized row remount preserves logical identity;
- stale semantic cache cannot target deleted row.

## Failure Catalog

Failures:

- screen reader announces old selected row after virtualization;
- status message fires before visible UI update;
- `aria-busy` remains true forever;
- duplicate progress announcements flood AT;
- active descendant points to unmounted node;
- raw path leaks in semantic trace.

## Release Gates

Release gate:

- high-change primitives expose semantic transaction traces;
- conformance tests cover event order;
- live announcements go through broker;
- virtualization invalidation has fixture coverage;
- cleanup-critical warnings use ordered visible plus semantic evidence.

