# Figure Media Caption And Fallback Standard

## Status

Accepted direction for Headless. Complements visualization accessibility and
export standards. Not implemented yet.

## Source Standards

- MDN `figure`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/figure
- MDN `figcaption`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/figcaption
- MDN `canvas`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/canvas
- MDN SVG `title`: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/title
- MDN SVG `desc`: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/desc
- MDN text labels and names: https://developer.mozilla.org/en-US/docs/Web/Accessibility/Guides/Understanding_WCAG/Text_labels_and_names
- WAI-ARIA Graphics Module: https://www.w3.org/TR/graphics-aria-1.0/
- WCAG 1.1.1 Non-text Content: https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html

## Problem

Charts, treemaps, donut charts, screenshots, canvas drawings, SVG diagrams,
icons, thumbnails, and exported report figures need names, descriptions,
captions, fallback data, and privacy policy. A figure without a caption or data
fallback becomes a visual-only artifact. A chart with an overlong description
becomes unusable.

Headless needs a figure and media fallback contract.

## Decision Options

1. Let renderer provide alt text manually - 🎯 5   🛡️ 5   🧠 2, about
   80-200 LOC. Inconsistent and easy to forget.
2. Add figure semantics and fallback model - 🎯 9   🛡️ 9   🧠 6, about
   450-1100 LOC. Best fit.
3. Build full chart accessibility system here - 🎯 5   🛡️ 7   🧠 10,
   about 2500-7000 LOC. Belongs behind visualization adapters, not core figure
   semantics.

Accepted: option 2.

## Accepted Contract

Headless media surfaces expose figure metadata:

```dart
final class RFigureSemantics {
  final String figureId;
  final String? caption;
  final String? shortDescription;
  final String? longDescriptionRef;
  final RFallbackContent? fallbackContent;
  final RFigureKind kind;
  final RPrivacyClass privacyClass;
}
```

The renderer owns visual drawing. The app owns facts. Headless preserves
caption, description, and fallback routes.

## Figure Kinds

```text
informativeImage:
  image carries content

decorativeImage:
  image can be ignored by assistive tech

chart:
  visualizes data

diagram:
  explains structure or flow

canvasVisualization:
  drawn surface needing fallback

svgGraphic:
  vector figure with accessible title and description

screenshot:
  captured UI or artifact
```

## Rules

- Informative figures have accessible name.
- Complex figures have short summary plus long details or data table.
- Decorative figures are explicitly decorative.
- Canvas content needs fallback content or external accessible data.
- SVG title and description are used where appropriate.
- Caption should not duplicate adjacent heading unless that is the intended
  accessible name.
- Figure export includes caption and data fallback.
- Privacy policy applies before screenshots or paths become captions.

## Clean Disk Requirements

Clean Disk uses figures for:

- disk usage treemap;
- donut size breakdown;
- capacity charts;
- scan history charts;
- compact reference screenshots in docs;
- support evidence screenshots;
- exported reports.

Treemap and donut visuals must expose the same bounded Rust projection used for
the visual. The figure is not the source of truth.

## Fallback Content Types

```text
summary:
  short text description

dataTable:
  table of chart data

legend:
  labeled series or segments

detailsPanel:
  navigable product details

download:
  accessible export artifact

noneDecorative:
  intentionally ignored
```

## Web Mapping

For web adapters:

- `figure` and `figcaption` are preferred for captioned media;
- canvas fallback content or associated details is required for meaningful
  canvas visualizations;
- SVG `title` and `desc` provide accessible name and description where
  supported;
- ARIA graphics roles can be used only when they improve supported semantics.

Flutter adapters need equivalent semantics and a route to accessible data.

## Accessibility Rules

- Figure can be skipped if decorative.
- Figure can be entered if interactive.
- Short description tells users whether deeper data is useful.
- Long description is navigable, not a giant alt string.
- Chart data has table alternative.
- Keyboard and screen-reader users can reach legend and details.

## Testing Requirements

- Treemap figure has caption and data fallback.
- Canvas chart has accessible summary.
- Decorative icon is not announced.
- Exported report preserves caption and alternative data.
- Support screenshot redacts private paths.
- SVG title and description are present where renderer emits SVG.
- Screen-reader flow does not duplicate caption and heading unnecessarily.

## Failure Catalog

- Canvas treemap is blank to assistive technology.
- Screenshot caption contains raw path.
- Chart legend uses color only.
- Export image lacks data table.
- SVG has no title or description.
- Decorative background is announced as important content.
- Long chart description is forced into one label.

## Release Gates

- `DiskUsageMapView` adapters provide figure semantics.
- Chart renderers expose data fallback.
- Support screenshots obey redaction policy.
- Figure semantics have web and Flutter adapter tests.
- Export artifacts include captions and accessible alternatives.

## Summary

Figures need names, captions, descriptions, and fallback data. Headless should
make media and visualization semantics explicit while renderer adapters remain
replaceable.
