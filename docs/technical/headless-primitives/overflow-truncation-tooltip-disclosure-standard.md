# Overflow Truncation Tooltip Disclosure Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 1.4.13 Content on Hover or Focus: https://www.w3.org/WAI/WCAG22/Understanding/content-on-hover-or-focus.html
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
- WAI-ARIA APG Tooltip Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/tooltip/
- MDN `overflow`: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/overflow
- MDN `text-overflow`: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/text-overflow
- MDN `aria-describedby`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-describedby

## Scope

This standard covers ellipsis, clipped text, path truncation, hover/focus
tooltip disclosure, full-value reveal, copyable hidden text, dense table cell
overflow, and accessible descriptions for truncated values.

It extends tooltip, text selection, path display, untrusted content, clipboard
privacy, and dense target standards.

## Problem

Clean Disk will show long paths, filenames, daemon errors, rule names, command
labels, and receipts inside dense columns. Truncation is unavoidable, but
truncation must not become data loss or an accessibility trap.

Common failures:

- full path is only visible on mouse hover;
- tooltip disappears before it can be reached;
- truncated text differs from accessible name;
- screen reader hears a huge raw path where a short row label was expected;
- copy action copies a visual ellipsis instead of the real value;
- untrusted filename markup is rendered as UI.

## Decision Options

1. Explicit truncation disclosure contract per text part -
   🎯 10   🛡️ 9   🧠 7, roughly 900-1800 LOC.
   Best fit. It lets components expose full values safely without making
   tooltips the only access path.
2. Always use normal tooltips for overflowed text -
   🎯 5   🛡️ 5   🧠 3, roughly 200-600 LOC.
   Easy, but hover/focus requirements and mobile access are often missed.
3. Never truncate important text -
   🎯 4   🛡️ 7   🧠 4, roughly 300-900 LOC.
   Safer semantically, but unusable in dense tables and compact panes.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- raw value;
- display value;
- truncation state;
- full-value disclosure availability;
- accessible label and description policy;
- copy value policy;
- hover/focus disclosure behavior;
- privacy class;
- untrusted content flag.

Renderer owns:

- ellipsis style;
- tooltip surface;
- reveal affordance;
- copy icon;
- wrapping and clipping;
- high contrast styling.

Application owns:

- value redaction;
- privacy policy;
- path normalization;
- command destination;
- support export behavior.

## Core Rule

Visual truncation is not semantic truncation.

```text
raw value
  -> sanitized semantic value
  -> display projection
  -> optional truncated visual text
  -> optional disclosure surface
```

The visual ellipsis must never become:

- copied value;
- command identity;
- route parameter;
- delete authority;
- telemetry label;
- support bundle evidence without redaction policy.

## Disclosure Rules

Full-value disclosure must be:

- available by keyboard;
- available without hover when text is essential;
- dismissible;
- persistent long enough to read;
- hoverable when it appears on hover;
- not clipped by parent overflow;
- not the only way to copy the value;
- not used for large interactive content.

Tooltip is for supplemental disclosure. Details panel, inline expansion, copy
button, or inspector row is required when the full value is operationally
important.

## Accessible Name Rules

Rules:

- visible row label should stay concise;
- full raw path usually belongs in description or details, not always in name;
- accessible label and visual label must not contradict;
- `aria-describedby` style behavior must not dump thousands of characters;
- redacted value must stay redacted in accessible text;
- user-controlled filenames are plain text.

For Clean Disk, a row can expose:

- name: folder/file basename;
- description: parent path and size facts;
- details: full path in inspector;
- copy value: full path if policy allows.

## Overflow Rules

Rules:

- essential focus rings cannot be clipped by text overflow;
- clipping container must not hide interactive children;
- middle truncation is allowed for paths;
- end truncation is allowed for ordinary labels;
- start truncation is rarely acceptable;
- wrapping is preferred in details panels;
- table cells may truncate but inspector must reveal full value.

## Clean Disk Usage

Surfaces:

- TreeTable path/name cells;
- current scanning path;
- details pane path;
- cleanup queue items;
- operation receipts;
- support bundle preview;
- error messages.

Rules:

- selected cleanup target shows full path in confirmation plan;
- row tooltip cannot be the only place where full delete target is visible;
- copy path goes through clipboard privacy policy;
- path display uses bidi-safe isolation and filename semantic rules;
- stale scan paths show stale marker separately from text truncation.

## Community API Sketch

```dart
final class RTruncationDisclosure {
  const RTruncationDisclosure({
    required this.rawValue,
    required this.displayValue,
    required this.strategy,
    required this.disclosureMode,
    required this.copyPolicy,
  });

  final String rawValue;
  final String displayValue;
  final RTruncationStrategy strategy;
  final RDisclosureMode disclosureMode;
  final RCopyPolicy copyPolicy;
}
```

## Conformance Scenarios

- keyboard user can reveal full truncated path;
- hover tooltip is dismissible, hoverable, and persistent;
- copied value is not the ellipsized visual string;
- full text is redacted when privacy policy requires it;
- long untrusted filename cannot inject markup;
- screen reader output remains useful and not massively verbose;
- details panel reveals full operational value before destructive confirmation.

## Anti-Patterns

- relying on title attribute behavior as the only full-value path;
- putting full raw paths into every accessible name;
- copying visible text with ellipsis;
- hiding focus outline inside clipped cell;
- showing interactive controls inside a tooltip;
- rendering filename/path as trusted markup;
- using localized display string as command identity.

## Clean Architecture Note

Headless owns disclosure mechanics. Application policy owns redaction and copy
permission. Domain and protocol models never receive truncated display strings
as authoritative data.

