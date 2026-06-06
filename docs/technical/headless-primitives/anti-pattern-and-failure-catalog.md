# Anti-Pattern And Failure Catalog

## Status

Spec-level failure catalog.

## Purpose

This file names patterns that should trigger design review or rejection.

## Architecture Anti-Patterns

- Renderer owns root activation.
- Renderer calls product callback directly.
- Component package imports another component package.
- Public docs import from `src/`.
- App-specific DTO appears in Headless API.
- Index used as logical identity.
- Localized label used as command id.
- Full backend tree passed into Flutter for convenience.

## Accessibility Anti-Patterns

- Every grid cell is a global Tab stop by default.
- Focus and selection are treated as the same state.
- Tooltip contains buttons or links.
- Dialog uses outside-click close by default for destructive confirmation.
- Status update moves focus.
- Leaf tree row exposes expanded/collapsed.
- Disabled item behavior is one bool with no policy.
- Keyboard behavior is implemented in renderer.

## Performance Anti-Patterns

- Hover rebuilds whole viewport.
- Progress event rebuilds table rows.
- Virtualized list keeps all rows alive.
- Search/filter/sort runs over full scan tree in Flutter.
- Semantics tree contains offscreen virtual rows.
- Column resize relayouts all cells on every pointer delta without throttling.

## Privacy Anti-Patterns

- Raw path appears in debug log.
- Semantic label is logged by default.
- Command target key appears in support bundle.
- Test fixture uses real local paths.
- DOM id derived from filesystem path.

## Product Safety Anti-Patterns

- Selection directly deletes.
- Cleanup queue directly deletes.
- Stale scan enables destructive action.
- Renderer performs clipboard/delete/export.
- Confirmation dialog shows old validation result.

## Review Response

When an anti-pattern appears:

1. Identify the boundary violation.
2. Move behavior to component or app use case.
3. Add conformance test.
4. Update RFC if the pattern exposed a missing contract.

## Stop Rules

- Do not work around anti-patterns silently.
- Do not keep app-specific behavior in Headless because it is convenient.
- Do not call a component accessible without keyboard and semantics tests.
