# Disk Usage Map View Adapter Decision

Last updated: 2026-05-16.

This document records the accepted decision for graphical disk-usage maps such
as treemaps, sunburst maps, icicle charts, bars, and folder breakdown charts.

## Accepted Decision

Clean Disk will introduce a `DiskUsageMapView` abstraction and keep concrete
visual renderers behind adapters.

Accepted shape:

```text
Rust read model / query service
  -> bounded map projection query
  -> Flutter feature data adapter
  -> DiskUsageMapView
  -> renderer adapter
       custom Canvas/RenderBox renderer
       optional Syncfusion renderer
       future renderer
```

The visual map is a projection over the Rust-owned scan read model. It is not a
source of truth for filesystem identity, selection safety, cleanup candidates,
or delete authority.

## Terms

- **Treemap** - nested rectangles where area represents size. This is the
  WinDirStat/WizTree/TreeSize-style "many squares" visualization.
- **Squarified treemap** - treemap layout optimized for rectangles close to
  squares, usually easier to scan than thin strips.
- **Sunburst** - radial partition map with rings or petals, similar to
  DaisyDisk.
- **Icicle chart** - rectangular partition chart where hierarchy is shown as
  stacked horizontal or vertical bands.
- **Bar ranking** - top folders/files as sorted bars.
- **Donut breakdown** - selected folder/category breakdown, useful in details
  panels but not as a full disk map.

## Renderer Options

1. Custom Flutter Canvas/RenderBox treemap renderer - 🎯 9  🛡️ 9  🧠 7,
   roughly 900-1800 LOC.
   Preferred production direction. It gives us full control over selection,
   hover, drilldown, accessibility fallback, palette, performance, "Other"
   grouping, exact node ids, and design-system integration.
2. `DiskUsageMapView` plus optional Syncfusion adapter - 🎯 8  🛡️ 8  🧠 6,
   roughly 600-1400 LOC.
   Accepted boundary. Syncfusion can be used as an optional renderer adapter or
   spike, but not as a core feature/domain/protocol dependency.
3. Direct dependency on Syncfusion treemap in feature UI - 🎯 5  🛡️ 5  🧠 4,
   roughly 300-800 LOC.
   Not accepted for core architecture. It is fast to build but couples product
   UX and dependency/licensing decisions too early.

`flutter_treemap` can be used only as a learning/reference package, not as a
production dependency unless its license, maintenance, and feature fit are
re-reviewed. Its GPL-3.0 license is not acceptable for core Clean Disk without a
separate legal decision.

## Syncfusion Adapter Policy

Syncfusion is not a normal MIT/Apache-style open-source dependency.

Policy:

- Syncfusion packages require either Syncfusion Community License or commercial
  license.
- Community License may be free if the user/company qualifies, but it is still a
  license requirement.
- Syncfusion is allowed only behind an optional adapter, feature flag, or
  experimental build profile.
- Core feature code, domain models, application ports, Rust protocol DTOs, and
  design-system contracts must not depend on Syncfusion types.
- Before enabling the adapter in any distributed build, verify current
  Syncfusion license terms, eligibility, package version, platform support, and
  release obligations.

Useful references from research:

- Syncfusion Flutter Treemap package:
  https://pub.dev/packages/syncfusion_flutter_treemap
- Syncfusion Community License:
  https://www.syncfusion.com/products/communitylicense
- Syncfusion Flutter licensing overview:
  https://help.syncfusion.com/flutter/licensing/overview

## Data Contract

Flutter must receive a bounded visual projection, not the full scan tree.

Recommended DTO shape:

```text
DiskUsageMapProjection
  scan_snapshot_id
  root_node_id
  projection_id
  map_kind
  size_basis
  total_size_bytes_decimal
  generated_at
  freshness
  tiles[]
  hidden_summary
  other_tile
  warnings[]
```

```text
DiskUsageMapTile
  node_id
  parent_node_id
  label
  display_path_hint
  size_bytes_decimal
  percent_of_root_basis_points
  color_key
  depth
  tile_kind
  risk_hint
  issue_count
  child_count
  has_more_children
```

Rules:

- large byte quantities cross Flutter web as decimal strings or typed value
  DTOs;
- projection page size is capped, for example top 300-800 visual tiles;
- tiny nodes collapse into `Other` with count and size summary;
- hidden/skipped/protected content remains visible as explicit summary tiles or
  warnings;
- map projection includes snapshot/freshness so stale maps are visually marked;
- color is derived from stable category/depth/risk keys, not arbitrary random
  color in the widget.

## Interaction Contract

The map and tree/table must stay linked.

Accepted interactions:

```text
hover tile -> highlight matching tree row/details preview
select tile -> select node id in shared selection state
double click / enter -> drill down into node projection
back / breadcrumb -> parent projection
context action -> route through ActionAvailability
add to cleanup queue -> DeletePlan flow, never direct delete
```

Rules:

- map selection uses stable `node_id` plus `scan_snapshot_id`, never visible
  text or row index;
- hover state and selected state are visually distinct;
- focused tile and selected tile are keyboard accessible;
- drilldown updates breadcrumb and details panel;
- cleanup actions are disabled unless the same application-level action registry
  says they are available;
- visual map cannot create cleanup authority.

## UI Placement

The folder tree/table remains the primary power surface.

Accepted placement:

- wide layout: map can be a secondary tab, collapsible panel, or details-side
  visualization tied to the selected root;
- compact layout: map is a secondary view below/behind the tree, not the default
  destructive workflow;
- details panel can use donut or mini-bars for selected folder breakdown;
- treemap/sunburst should support "open in focused map view" later.

The map is for discovery and orientation. Delete/reclaim decisions still go
through tree/details, queue, DeletePlan, confirmation, execution, and receipt.

## Accessibility And Safety

Every visual map must have a table/list equivalent.

Rules:

- screen readers get equivalent top items and current selection;
- keyboard users can navigate tiles or use equivalent list;
- small tiles may omit text but still expose tooltip/details on focus;
- bidi/control-character path display follows path safety rules from UI/i18n
  docs;
- colors are not the only meaning channel;
- chart labels do not overflow or obscure neighboring tiles.

Kill criteria:

- map is the only way to access an action;
- map hides high-risk cleanup candidates inside `Other` with no drilldown;
- map renders stale data without stale/freshness state;
- map selection can be mistaken for queued-for-delete state;
- chart rebuilds on every scan progress event.

## Performance Rules

The renderer must be cheaper than the table workflow.

Rules:

- layout calculation uses bounded tile lists;
- Rust performs sorting/grouping/top-N projection;
- Flutter caches the current projection and renderer layout by projection id and
  viewport constraints;
- map updates are throttled and lower priority than tree/table interaction;
- on Flutter web, map can degrade first before tree/table workflow;
- animations are optional and disabled during active scan pressure.

## Proposed Package Shape

This is a target shape, not implementation already written.

```text
packages/design_system/
  lib/src/disk_usage_map/
    disk_usage_map_view.dart
    disk_usage_map_models.dart
    disk_usage_map_renderer.dart
    renderers/
      custom_treemap_renderer.dart
      simple_bar_map_renderer.dart

features/scan/
  lib/src/application/ports/
    disk_usage_map_query_port.dart
  lib/src/data/
    dto/disk_usage_map_projection_dto.dart
    repositories/disk_usage_map_repository.dart
  lib/src/presentation/
    widgets/disk_usage_map_panel.dart
    stores/disk_usage_map_store.dart

packages/syncfusion_disk_usage_map_adapter/    # optional later
  lib/syncfusion_disk_usage_map_adapter.dart
```

The optional Syncfusion adapter should live outside core `design_system` if it
would force Syncfusion into normal dependency resolution for every build.

## MVP Cut

For scan-only MVP:

- define `DiskUsageMapView` abstraction and DTO/query contract;
- ship either no map yet or a simple custom top-N treemap/bar prototype;
- keep map behind a feature flag if performance is not proven;
- no Syncfusion dependency in core MVP.

For beta:

- implement custom treemap renderer or optional adapter spike;
- add golden/widget tests for wide and compact layouts;
- verify desktop and Flutter web frame behavior;
- verify selection sync with tree/details.

## Final Decision

Use `DiskUsageMapView + renderer adapter`.

The architecture should let us start with a simple custom renderer, test a
Syncfusion adapter if useful, and later replace either without changing Rust
domain, protocol contracts, cleanup safety, or feature workflows.
