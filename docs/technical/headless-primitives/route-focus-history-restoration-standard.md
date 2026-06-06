# Route Focus And History Restoration Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN History API: https://developer.mozilla.org/en-US/docs/Web/API/History_API
- MDN Page Visibility API: https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API
- MDN `beforeunload`: https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeunload_event
- WCAG 2.4.2 Page Titled: https://www.w3.org/WAI/WCAG22/Understanding/page-titled.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
- Flutter focus system: https://docs.flutter.dev/ui/interactivity/focus
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Scope

This standard defines how Headless primitives cooperate with app navigation,
route changes, browser history, focus restoration, scroll restoration, and
page lifecycle.

It applies to:

- tabs and route-like panels;
- drawers, sheets, dialogs, popovers, and side panels;
- virtualized tree and grid rows;
- command palette navigation;
- browser back and forward;
- desktop multi-window navigation;
- app restart and session restore;
- web page visibility and unload warnings.

Headless does not own the app router. It owns reusable focus and restoration
protocols that routers and shell components can call.

## Decision Options

Option A: Let router and widgets handle restoration - 🎯 4   🛡️ 4   🧠 3,
about 100-300 LOC.

- Easy to start.
- Every app invents a focus story.
- Virtualized rows and overlays will drift.

Option B: Store raw focus node and scroll offsets - 🎯 5   🛡️ 5   🧠 4,
about 250-500 LOC.

- Works for simple screens.
- Breaks when rows disappear, ids change, or sessions restore after scan
  snapshot changes.

Option C: Headless restoration tokens and route lifecycle hooks - 🎯 9
🛡️ 8   🧠 7, about 900-1600 LOC.

- Accepted direction.
- Stores stable restoration intent, not framework object identity.
- Supports virtualized data and multi-window sessions.

## Accepted Direction

Headless must define a restoration protocol:

- route enters;
- route exits;
- focus target registered;
- focus target removed;
- scroll anchor captured;
- overlay stack captured;
- route title requested;
- restoration attempted;
- restoration fallback selected;
- restoration completed or failed with reason.

The protocol stores semantic restoration tokens, not `FocusNode` references.

## Restoration Tokens

Focus restoration token should include:

- route key;
- primitive type;
- stable item id;
- optional column id;
- optional cell mode;
- focus scope path;
- selection context;
- fallback target;
- snapshot or data version when relevant.

Scroll restoration token should include:

- viewport id;
- anchor item id;
- anchor alignment;
- pixel offset relative to anchor;
- query or filter version;
- column layout version;
- text scale bucket;
- density bucket.

Overlay restoration token should include:

- overlay kind;
- invoker id;
- modal or non-modal;
- dismiss reason;
- return focus target;
- authority state if the overlay is safety-related.

## Page Title And Route Name

Each route-like surface must provide:

- stable route id;
- localized title;
- optional title suffix;
- screen-reader announcement label;
- restore priority.

Web adapters must update document title when route meaning changes.

Flutter adapters must expose route title to the shell and platform where
possible.

## Focus Restoration Rules

On route entry:

- prefer explicit focus target from navigation command;
- otherwise restore last valid token;
- otherwise focus primary heading or main region;
- otherwise focus first safe interactive control;
- otherwise keep focus on shell with live status announcement.

On route exit:

- capture current focus token before disposing nodes;
- capture selection token separately;
- capture scroll anchor separately;
- do not capture transient overlay focus as page focus unless overlay is the
  route itself.

On failed restore:

- do not focus body or hidden root;
- do not focus stale destructive action;
- publish diagnostic reason in development;
- fall back to main content or safe heading.

## Virtualized Surface Rules

Virtualized rows cannot restore by widget instance.

They must restore by:

- stable row id;
- visible query;
- snapshot id;
- column id;
- row focus mode or cell focus mode.

If row is not loaded:

- ask application data source to reveal or page to anchor;
- show busy state if needed;
- time out to nearest safe ancestor;
- never fabricate cleanup authority from stale row visibility.

## History Rules

Browser history and desktop route history must preserve:

- route id;
- query state that is safe to expose;
- selected tab or panel;
- safe scroll anchor;
- read-only view state.

They must not preserve:

- daemon tokens;
- raw destructive plan authority;
- delete confirmation state;
- sensitive search text if privacy policy disallows it;
- raw path in public URL unless explicitly allowed by app policy.

Clean Disk rule:

- history can restore a scan view, but delete actions require current
  validation.

## Page Lifecycle Rules

Use page visibility or app lifecycle to autosave view state.

Use unload warnings sparingly:

- only when there is unsaved user-entered state or operation state that could
  be lost;
- remove the handler when not needed;
- do not rely on unload firing for durable operation journals.

Clean Disk must not depend on web unload for cleanup receipts. Receipts belong
to daemon or persistence layer.

## Flutter Adapter Requirements

Flutter adapter must:

- create and dispose focus nodes by owner lifecycle;
- avoid sharing one focus node between multiple widgets;
- expose restoration tokens from Headless components;
- integrate with Actions and Shortcuts for route commands;
- support semantic route announcements where practical;
- test focus traversal after route changes.

## Web Adapter Requirements

Web adapter must:

- cooperate with History API;
- update document title;
- move focus after route changes;
- preserve logical focus order;
- handle browser back and forward;
- avoid trapping focus in hidden overlays;
- handle `visibilitychange` for state save;
- avoid permanent `beforeunload` handlers.

## Clean Disk Requirements

Clean Disk needs restoration for:

- selected scan target;
- selected node;
- expanded tree ancestors;
- table scroll anchor;
- active sort and filter;
- details panel section;
- delete queue collapsed or expanded state;
- bottom progress footer focus;
- settings and diagnostics routes.

Destructive state rule:

- route restore can restore queue display only as pending view state.
- move-to-trash authority requires a fresh validated `DeletePlan`.

## Conformance Scenarios

- navigate from tree to settings and back restores selected node when still
  valid;
- selected node removed from snapshot falls back to nearest valid ancestor;
- browser back updates title and focus;
- dialog close returns focus to invoker unless invoker disappeared;
- reload restores read-only route state but not destructive authority;
- virtualized row focus restores after paging data from Rust;
- high text scale changes scroll anchor without hiding focus target;
- multi-window route state does not overwrite another window's focus token.

## Failure Catalog

- storing framework focus objects in persisted state;
- focusing body after route change;
- restoring focus to hidden overlay content;
- preserving delete confirmation through history;
- putting daemon token or raw path in URL;
- relying on unload to save critical cleanup receipt;
- scroll restoration by pixel offset only in a virtualized table;
- row restore without snapshot or query version;
- route title not updated for screen reader users;
- focus restoration happening before content is available.

