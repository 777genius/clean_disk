# Dense Target Focus Visibility Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
- WCAG 2.4.11 Focus Not Obscured Minimum: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- WCAG 2.4.13 Focus Appearance: https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html
- WCAG 2.5.5 Target Size: https://www.w3.org/WAI/WCAG22/Understanding/target-size.html
- WCAG 2.5.8 Target Size Minimum: https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- MDN `forced-colors`: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/forced-colors

## Scope

This standard covers dense targets, icon buttons in tables, hit target padding,
minimum target size, focus visibility, focus not obscured, sticky footer
avoidance, compact density, text scaling, and row action affordances in dense
productivity layouts.

It extends zoom/density/target size and sticky scroll geometry standards. It
focuses on dense UI conformance rules for public Headless primitives.

## Problem

Clean Disk is intentionally dense. Dense does not mean tiny and inaccessible.
Rows, icon buttons, splitters, checkboxes, chips, and command buttons must stay
operable across desktop, compact windows, high zoom, touch, switch access,
screen magnifiers, and forced colors. Public Headless needs density rules that
preserve productivity without hiding focus or making targets impossible.

## Decision Options

1. Density-aware target and focus policy per primitive part -
   🎯 9   🛡️ 9   🧠 8, roughly 900-1900 LOC.
   Best fit. It lets apps choose density while keeping minimum focus and target
   guarantees.
2. One global minimum size for all components -
   🎯 6   🛡️ 7   🧠 3, roughly 200-500 LOC.
   Simple, but too blunt for inline text links, table rows, and platform
   differences.
3. Leave density entirely to renderer CSS/theme -
   🎯 4   🛡️ 4   🧠 2, roughly 100-300 LOC.
   Fast, but public primitives will ship inaccessible compact states.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- target role;
- minimum target policy;
- equivalent target policy;
- focus visibility requirement;
- focus obstruction risk;
- density level;
- input modality facts;
- compact fallback facts;
- conformance metadata.

Renderer owns:

- hit slop implementation;
- visual size;
- focus ring style;
- spacing;
- responsive wrapping;
- pointer cursor;
- high contrast adaptation.

Application owns:

- density preference;
- route layout;
- platform mode;
- product-critical command placement;
- user personalization.

## Target Policy

Target policy fields:

- visual size;
- hit size;
- spacing to neighboring targets;
- equivalent larger target id;
- inline exception flag;
- essential presentation flag;
- input modality requirement.

Rules:

- small visual icon may have larger hit target;
- repeated row actions need either target size or equivalent action path;
- destructive controls should not be densely packed next to safe controls;
- resize handles need keyboard alternatives;
- density cannot hide required focus indicator.

## Focus Visibility Rules

Focus indicator must:

- be visible in light/dark/high contrast;
- survive forced-colors mode;
- not rely only on box-shadow;
- not be hidden behind sticky headers/footers;
- not be clipped by overflow;
- be stable during animations;
- distinguish focus from selection where both exist.

If focus is obscured by an opened surface, user must be able to reveal it
without advancing focus.

## Dense Layout Rules

Dense layout can:

- reduce spacing;
- reduce secondary metadata;
- move actions to menu;
- use compact typography within app token rules;
- collapse optional columns.

Dense layout must not:

- reduce hit target below policy with no equivalent;
- remove keyboard path;
- hide warnings needed for risky actions;
- overlap text and controls;
- force horizontal scroll for non-tabular ordinary text;
- make focus invisible.

## Clean Disk Usage

Dense surfaces:

- TreeTable rows;
- row action menu trigger;
- cleanup queue items;
- toolbar icons;
- target chips;
- details pane property rows;
- scan status footer commands.

Rules:

- row height can be compact, but action trigger remains operable;
- selected row and focused row have distinct visuals;
- bottom status footer cannot obscure focused last row;
- warning icon has text/description alternative;
- compact layout moves actions to menus instead of shrinking below policy.

## Community API Sketch

```dart
final class RDenseTargetPolicy {
  const RDenseTargetPolicy({
    required this.visualSize,
    required this.hitSize,
    required this.spacing,
    required this.equivalentTargetId,
    required this.focusVisibility,
  });

  final RSize visualSize;
  final RSize hitSize;
  final RSpacing spacing;
  final String? equivalentTargetId;
  final RFocusVisibilityPolicy focusVisibility;
}
```

## Conformance Scenarios

- compact icon button has acceptable hit target or equivalent;
- focus ring remains visible in forced colors;
- sticky footer does not hide focused row;
- selected and focused row are distinguishable;
- high zoom does not overlap controls;
- keyboard path exists when pointer target is compact;
- destructive and safe adjacent controls have safe spacing;
- warning icon is not color-only.

## Failure Catalog

- Dense mode shrinks hit target with no equivalent.
- Focus ring clipped by row overflow.
- Sticky footer hides focused delete queue item.
- Selection color doubles as focus only.
- Icon-only warning has no description.
- High contrast removes focus outline.
- Compact toolbar packs destructive and safe actions too closely.

