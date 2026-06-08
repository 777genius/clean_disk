# Frontend Layout Guide

This guide is the practical rulebook for building Clean Disk UI with Headless,
the local design system, and the project architecture.

## Source Docs

This guide is the short working layer over:

- `AGENTS.md`;
- `docs/technical/frontend-boundaries-decision.md`;
- `docs/technical/flutter-frontend-architecture-decision.md`;
- `docs/technical/implementation-edge-cases-flutter-large-tree-ui.md`;
- `docs/technical/implementation-edge-cases-ui-accessibility-i18n.md`;
- `docs/technical/disk-usage-map-view-adapter.md`;
- `docs/design/references/clean-disk-wide-reference.png`;
- `docs/design/references/clean-disk-compact-reference.png`.

When a deeper contract is needed, use those docs as source of truth. This file
keeps the day-to-day layout rules easy to apply.

## Main Rule

Use Headless as the interaction and primitive engine, not as product UI.

Product screens should compose Clean Disk design-system facades. Headless
imports belong inside `packages/design_system` adapters and wrappers. Feature
pages should not import `package:headless/headless.dart` directly.

```text
feature presentation page
  -> clean_disk_design_system facade
  -> Headless or Material primitive adapter
```

If Headless is missing a primitive, behavior, or accessibility contract, stop
and make the gap explicit before adding a page-local workaround. A small MVP
facade is fine when it preserves a future renderer adapter boundary.

## Current Entry Points

- App shell wraps the whole app in `AppHeadlessScope`.
- Feature UI imports `package:clean_disk_design_system/clean_disk_design_system.dart`.
- Shared visual primitives live in `packages/design_system/lib/src/components`.
- Tokens live in `packages/design_system/lib/src/tokens`.
- Disk map contracts live under `packages/design_system/lib/src/disk_usage_map`.
- Renderer-specific disk map code stays in optional adapter packages.

Do not add another `HeadlessApp` or local Headless theme inside a feature page.
Theme and overlay plumbing are app/design-system responsibilities.

## Layer Ownership

`apps/clean_disk` owns app composition:

- route shell;
- app theme mode;
- `AppHeadlessScope`;
- module mounting;
- runtime adapter choice.

`features/*/presentation` owns product composition:

- page layout;
- responsive wide/compact decisions;
- mapping store state to view models;
- localized user-facing strings;
- callbacks to store actions.

`packages/design_system` owns reusable UI contracts:

- buttons, fields, selects, panels, table, map view, scaffolds;
- tokens, density, focus visuals, hover/pressed/disabled states;
- semantic IDs and keyboard/focus behavior for reusable widgets;
- Headless and Material renderer wiring.

Domain, application, data, protocol DTOs, stores, repositories, daemon clients,
and platform adapters must not leak into design-system primitives.

User-facing strings belong in localization. Runtime-specific behavior belongs
behind adapters. Presentation may call store actions, but it must not import
daemon routes, WebSocket clients, desktop APIs, Rust bridge DTOs, or renderer
adapter types directly.

## Headless Usage Rules

Use Headless when a reusable primitive needs interaction semantics:

- button, icon button, menu, select, text field;
- overlay, dialog, bottom sheet, popover;
- keyboard focus and commandable controls;
- future tree/table, split pane, tab, segmented control, or virtualized list
  primitives.

Use plain Flutter layout widgets for structure:

- `Row`, `Column`, `Stack`, `CustomScrollView`, `SliverList`;
- `LayoutBuilder`, `ConstrainedBox`, `Expanded`, `Flexible`;
- `Scrollbar`, `SingleChildScrollView`, `ListView.builder` when owned by a
  facade or bounded page layout.

Do not use Headless to smuggle product policy into UI primitives. Product
commands still flow through:

```text
widget callback -> store action -> application use case -> port -> adapter
```

## Layout Workflow

Before changing user-facing layout:

1. Inspect `docs/design/references/clean-disk-wide-reference.png`.
2. Inspect `docs/design/references/clean-disk-compact-reference.png`.
3. Decide what is shared primitive vs feature composition.
4. Prefer an existing design-system component.
5. If missing, add a small facade in `packages/design_system` and export it.
6. Keep feature widgets on view models and callbacks, not protocol DTOs.
7. Add focused widget tests for the facade or page behavior.
8. Run `fvm flutter analyze` for touched packages.
9. Visually verify wide and compact layouts with Marionette first.

## Clean Disk Visual Rules

Clean Disk is a dense productivity tool, not a landing page.

- Keep the disk map, folder tree/table, selection details, scan status, and
  cleanup/AI actions visible without marketing-style hero sections.
- Use the Cyber Blue/Violet dark direction from the reference screenshots.
- Keep panels at 8px radius or less.
- Do not nest cards inside cards.
- Prefer icon buttons for common actions: scan, pause, refresh, reveal, sort,
  filter, settings, queue, remove.
- Use hover, selected, focus, progress, and warning states intentionally.
- Keep neon accents restrained so table readability stays first.
- Use stable dimensions for boards, toolbars, counters, rows, and map areas.
- Text must fit at desktop and compact widths. Use ellipsis for long paths and
  names.
- Do not use visible instructional text to explain obvious controls.

## Wide And Compact Rules

Wide layout should usually preserve:

- left scan-target/navigation rail;
- central disk map plus folder tree/table;
- right details, queue, recommendations, or AI side panel;
- scan/progress status in a stable footer or compact status band.

Compact layout should usually preserve:

- top target/search/action controls;
- central disk map and folder tree/table;
- below-tree details or collapsible assistant/queue;
- no permanent left or right rail.

If content does not fit, prefer page-level scrolling for the working canvas.
Avoid tiny nested scroll areas unless the component is intentionally virtualized
and has a stable height.

## Tree, Table, And Map Contracts

Tree/table UI goes through `AppTreeTable`.

- Rows need stable IDs.
- Expansion state is product state, not renderer truth.
- Keep row height fixed for large lists.
- Use `ListView.builder` or future virtualized adapters for large result sets.
- Rust/query layers sort and filter large scan results; Flutter must not sort
  the whole scan tree.
- Page-level non-scrollable rows are acceptable only for bounded visible sets.

Disk maps go through `DiskUsageMapView`.

- The map is a projection of scan data, not source of truth.
- Syncfusion or other renderers are optional adapters.
- Feature pages should not import renderer-specific adapter types directly.
- Selection on the map must reconcile with the same selected node identity used
  by the tree/table.

## AI Assistant Placement

AI chat is a product workflow surface, not a design-system primitive.

Preferred desktop pattern: collapsible right side sheet/panel. It keeps the map
and tree primary while making AI available for analysis and cleanup questions.

Preferred compact pattern: bottom drawer or full-height sheet. It should not
hide destructive confirmation state, selected path, or scan warnings.

The design system may provide shell primitives, input, buttons, and scroll
behavior. Feature presentation owns chat state, prompts, evidence, and commands.

## Verification Checklist

Before calling layout work done:

- wide reference shape is still recognizable;
- compact reference shape does not overflow;
- no text overlaps or escapes controls;
- hover, selected, focus, disabled, loading, empty, error, and degraded states
  are covered where relevant;
- keyboard traversal reaches primary controls;
- row and map selection stay in sync;
- large-tree path does not rebuild the full page on progress updates;
- design-system changes have widget tests;
- feature page changes have at least focused layout/state tests;
- Marionette screenshot/checks pass for desktop and compact sizes.

## Stop Rules

Stop and report before continuing when:

- Headless cannot express the needed interaction or accessibility contract;
- a feature page needs direct `package:headless` import;
- a design-system primitive would need feature stores, protocol DTOs, daemon
  clients, localization classes, or platform APIs;
- the UI would need Flutter to keep the entire scan tree in memory;
- a cleanup action could bypass current capabilities, validation, or
  confirmation state;
- the layout only works by hiding required scan warnings, skipped paths, or
  stale/incompatible daemon states.
