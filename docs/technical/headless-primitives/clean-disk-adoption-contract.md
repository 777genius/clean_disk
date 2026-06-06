# Clean Disk Adoption Contract

## Status

Contract for using Headless primitives inside Clean Disk.

## Purpose

Clean Disk is the proving app for dense primitives, but product needs must not
pollute Headless APIs.

## Dependency Rule

```text
features/scan
  -> packages/design_system
  -> Headless public packages
```

Feature widgets should not import Headless internals directly.

## Design-System Wrappers

Clean Disk wrappers:

- `AppTreeGrid`;
- `AppContextMenu`;
- `AppDialog`;
- `AppSplitPane`;
- `AppTooltip`;
- `AppStatusRegion`.

Wrappers own:

- Clean Disk tokens;
- icon choices;
- density;
- row visuals;
- product labels;
- command mapping.

Headless owns:

- behavior;
- focus;
- semantics;
- renderer contracts;
- state machines.

## Product Boundaries

Headless must not know:

- scan session ids;
- daemon routes;
- filesystem paths;
- cleanup queue semantics;
- DeletePlan;
- Rust DTOs.

## Allowed Mapping

```text
ScanNodeViewModel
  -> AppTreeGridRow
  -> Headless row descriptor
```

The mapping strips product authority. It passes display facts and stable UI key
only.

## Release Rule

Clean Disk may use experimental local Headless during development, but release
must pin a known compatible version or document the workspace coupling.

## Stop Rules

- Do not add Clean Disk names to Headless primitives.
- Do not bypass design system wrappers from feature UI.
- Do not use Headless selection as delete authority.
- Do not expose raw paths in Headless diagnostics.
