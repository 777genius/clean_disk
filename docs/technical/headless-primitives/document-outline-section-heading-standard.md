# Document Outline Section And Heading Standard

## Status

Accepted direction for Headless. Complements landmarks, dialogs, reports, and
page structure standards. Not implemented yet.

## Source Standards

- W3C WAI Page Structure Tutorial: https://www.w3.org/WAI/tutorials/page-structure/
- MDN heading elements: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/Heading_Elements
- MDN `section`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/section
- MDN ARIA `heading` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/heading_role
- MDN ARIA `region` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/region_role
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WCAG 2.4.10 Section Headings: https://www.w3.org/WAI/WCAG22/Understanding/section-headings.html

## Problem

Component libraries often render headings visually without preserving a usable
document outline. This breaks pages, drawers, dialogs, report views, receipts,
support bundles, and settings screens. A public Headless library cannot assume
the surrounding app heading level, but it also cannot generate arbitrary heading
levels that skip structure.

Headless needs a section and heading-level contract.

## Decision Options

1. Renderer chooses heading tags by visual size - 🎯 3   🛡️ 3   🧠 1,
   about 20-80 LOC. Common and wrong.
2. App passes explicit heading context into Headless sections - 🎯 9   🛡️ 9
   🧠 5, about 350-900 LOC. Best fit.
3. Headless computes a global document outline automatically - 🎯 4   🛡️ 5
   🧠 9, about 1500-4000 LOC. Too fragile across app boundaries.

Accepted: option 2.

## Accepted Contract

Headless sections receive heading context:

```dart
final class RSectionSemantics {
  final String sectionId;
  final String? label;
  final int? headingLevel;
  final RSectionKind kind;
  final bool landmarkEligible;
  final bool includeInOutline;
}
```

Headless components can request a section title slot, but the app or design
system decides final heading level.

## Section Kinds

```text
page:
  top-level app page

panel:
  persistent content panel

dialog:
  modal or nonmodal dialog body

receipt:
  durable operation evidence

report:
  exportable document view

card:
  repeated standalone unit

subsection:
  nested logical group
```

## Rules

- Visual size is not heading level.
- Heading levels must not be skipped inside one document context.
- Component docs define required heading context.
- Named regions are used only when navigation benefit is real.
- Too many regions create noise.
- Dialog title participates in dialog naming and local outline.
- Cards are not headings by default unless they represent independent sections.
- Reusable components expose title slots, not hardcoded `h2`.

## Clean Disk Requirements

Clean Disk needs heading and section semantics for:

- Home scan page;
- right details pane;
- delete queue;
- scan progress footer;
- permission repair cards;
- settings;
- cleanup receipts;
- support bundle preview;
- report/export pages.

The dense scan table should not become a heading jungle. Headings define major
regions; table headers define grid data.

## Web Mapping

For web adapters:

- native `h1` through `h6` are preferred;
- ARIA `heading` with `aria-level` is fallback only when native heading cannot
  be used;
- `section` or `region` requires meaningful label when exposed as a landmark;
- heading hierarchy should be stable across responsive layouts.

Flutter adapters should expose heading semantics where platform APIs support
them and keep a testable outline model even where native support is weaker.

## Accessibility Rules

- Users can navigate major product regions by headings.
- Compact layout does not remove logical headings.
- Collapsed sections keep discoverable labels.
- Dialog headings do not conflict with page headings.
- Repeated cards avoid every item becoming a high-level heading.
- Hidden headings used for structure are allowed only when they reflect real
  visible or conceptual sections.

## Testing Requirements

- Page outline snapshot has no skipped levels.
- Dialog title is both visible and accessible.
- Compact and wide layouts keep equivalent outline.
- Details pane has discoverable section label.
- Repeated recommendation cards do not flood heading navigation.
- Report export preserves heading structure.
- Region labels are unique where multiple regions exist.

## Failure Catalog

- Text styled as 32px title has no heading semantics.
- Every table row name becomes a heading.
- Compact layout removes section title from accessibility tree.
- Dialog has a title visually but no accessible name.
- Multiple regions share the same label.
- Component hardcodes `h1` inside nested settings page.

## Release Gates

- Design system exposes section title and heading-level tokens.
- Public components document heading expectations.
- Clean Disk pages have outline snapshots.
- Report and receipt views preserve heading structure.
- Landmark count is reviewed for noise.

## Summary

Headings are document navigation, not typography. Headless should expose
section intent and heading context so apps can build coherent outlines across
pages, panels, dialogs, receipts, and reports.
