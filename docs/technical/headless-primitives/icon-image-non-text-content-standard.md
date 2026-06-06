# Icon Image And Non Text Content Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 1.1.1 Non-text Content: https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html
- MDN `img` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/img_role
- MDN `aria-hidden`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-hidden
- MDN SVG `title`: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/title
- MDN SVG `desc`: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/desc
- Flutter Image accessibility: https://api.flutter.dev/flutter/widgets/Image-class.html
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers icons, decorative icons, command icons, folder/file icons,
warning icons, logos, screenshots, thumbnails, chart snapshots, SVGs, canvas
renderings, image buttons, and non-text status indicators.

Visualization charts have a separate standard. This file covers atomic non-text
content and its use inside other primitives.

## Decision Options

1. `NonTextContent` contract with decorative, informative, functional, and
   composite modes - 🎯 9   🛡️ 9   🧠 6, roughly 600-1200 LOC.
   Best fit. It makes icon/image semantics testable across renderers.
2. Require every icon/image to have a semantic label - 🎯 4   🛡️ 5   🧠 3, roughly 200-500 LOC.
   Over-announces decorative assets and creates screen reader noise.
3. Hide all icons from semantics and label parent controls manually - 🎯 6   🛡️ 6   🧠 4, roughly 300-700 LOC.
   Good for many command icons, but wrong for informative images and standalone
   status symbols.

Accepted direction: option 1.

## Content Modes

Decorative:

- adds no meaning;
- hidden from assistive technology;
- example: chevron decoration beside visible text.

Informative:

- conveys content;
- needs text alternative or nearby equivalent;
- example: warning icon with no visible warning text.

Functional:

- is part of an interactive control;
- the control has an accessible name describing the action;
- the icon itself is usually hidden.

Composite:

- multiple visuals form one image;
- use one overall description;
- individual child visuals should not be separately announced.

Redundant:

- repeats adjacent text;
- hide the icon or mark it decorative to avoid duplicate speech.

## Primitive Boundary

Headless owns:

- non-text content mode;
- accessible label/description requirement;
- privacy class for description;
- decorative/hidden policy;
- parent-control labeling rule;
- fallback text requirement;
- high contrast replacement metadata;
- icon semantic token.

Renderer owns:

- actual icon glyph, image asset, SVG, canvas, color, size, and animation;
- image loading/failure visuals;
- theme variant.

Application owns:

- business meaning;
- localized alt text;
- privacy redaction;
- asset choice.

## Required Rules

MUST:

- provide text alternative for meaningful non-text content;
- hide decorative icons from semantics;
- label parent controls, not child icons, for icon-only buttons;
- include visible or semantic text for color-coded status icons;
- update text alternatives when non-text content changes meaning;
- avoid filenames as alt text;
- keep raw local paths out of image labels and descriptions;
- provide long description or equivalent table/list for complex images.

SHOULD:

- prefer text plus icon for critical states;
- use semantic icon tokens like warning, folder, file, scan, trash, not raw asset
  names;
- expose failed image state when image content matters;
- support high contrast alternatives for low-contrast icons.

MUST NOT:

- announce decorative folder icons in every TreeGrid row;
- use icon color as the only signal for warning/skipped/protected;
- put a semantic icon inside a labeled button if it duplicates the button name;
- describe an icon visually when its purpose is functional;
- rely on AI-generated alt text without product review for critical content.

## Clean Disk Mapping

TreeGrid:

- folder/file icons are decorative when row text already states type or name;
- warning badge icons need text/status equivalent;
- selected row icons should not be announced as separate content.

Toolbar:

- icon-only buttons receive names from command descriptors;
- child icons are hidden from semantics;
- tooltips do not replace accessible names.

Details pane:

- disk map visuals follow visualization standard;
- folder thumbnail or file-type icon is decorative unless it carries unique
  state.

Permission and safety:

- warning icon plus text for Full Disk Access or protected path;
- never communicate risk only with yellow/red icon.

## Conformance Tests

Minimum tests:

- decorative icon is excluded from semantics;
- icon-only button has parent accessible name;
- warning icon has text equivalent;
- meaningful image has label or description;
- composite image exposes one name/description;
- filename-only alt fails conformance;
- path-containing alt is redacted;
- SVG renderer provides title/description where required;
- image loading failure is exposed when content matters;
- forced-colors mode still conveys status.

## Failure Catalog

- Every row announces "folder icon" before the folder name.
- Trash icon button has no name.
- Warning state is yellow triangle only.
- Alt text says "cache.png".
- Complex chart is exposed as one unlabeled image.
