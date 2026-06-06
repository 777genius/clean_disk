# Range Stepper Slider And Spinbutton Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Slider Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/slider/
- WAI-ARIA APG Spinbutton Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/spinbutton/
- MDN `slider` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/slider_role
- MDN `spinbutton` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/spinbutton_role
- MDN `meter` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/meter_role
- MDN `input`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers sliders, range sliders, stepper buttons, spinbuttons,
numeric inputs, bounded resource controls, scan speed controls, and value
formatting for ranges.

It does not cover progress or meter display-only components, which are defined
in the progress/meter/log/status standard.

## Decision Options

1. `RangeValueController` with slider, spinbutton, and stepper adapters - 🎯 9   🛡️ 8   🧠 8, roughly 900-1900 LOC.
   Best fit. One value model can support several interaction surfaces while
   preserving role-specific semantics.
2. Slider-only primitive plus custom numeric text fields - 🎯 5   🛡️ 6   🧠 6, roughly 700-1400 LOC.
   Too narrow. Many desktop productivity users prefer precise typed values.
3. Numeric fields only, no slider semantics - 🎯 6   🛡️ 7   🧠 4, roughly 400-900 LOC.
   More precise, but weak for fast preference adjustments and touch.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- min, max, current value, step, page step, large step, and value text;
- bounded/unbounded policy;
- slider versus spinbutton role choice;
- direct edit policy;
- validation state;
- keyboard behavior;
- pointer and touch gesture contract;
- precision and rounding policy;
- unit formatting;
- controlled state.

Renderer owns:

- track, thumb, tick marks, labels, buttons, density, and animation;
- horizontal/vertical layout;
- compact and expanded visuals.

Application owns:

- actual setting meaning;
- resource budget policy;
- persistence;
- validation ranges;
- localization of units.

## Choosing The Control

Use slider when:

- approximate value selection is acceptable;
- min and max are known;
- value changes can be previewed or applied safely;
- pointer/touch interaction adds value.

Use spinbutton when:

- value is discrete and precise;
- direct text editing is useful;
- min/max/step are known;
- keyboard increment/decrement is expected.

Use stepper buttons when:

- visible increment/decrement controls help touch and mouse users;
- they are an adapter over spinbutton/range behavior, not separate truth.

Use numeric text field when:

- value range is large or uncommon;
- direct entry is the primary workflow;
- slider would imply false precision.

## Keyboard Contract

Slider MUST:

- support arrow keys for small step changes;
- support `Home` and `End` when min and max exist;
- support `Page Up` and `Page Down` when large step exists;
- expose min, max, current value, and value text;
- keep focus on the thumb while changing value.

Spinbutton MUST:

- support `Up Arrow` and `Down Arrow`;
- support `Home` and `End` when min and max exist;
- support `Page Up` and `Page Down` for large steps where configured;
- allow standard text editing when direct edit is enabled;
- not intercept platform text editing keys.

Range slider with two thumbs MUST:

- expose two named thumbs;
- prevent min thumb from crossing max thumb unless product explicitly supports
  swapping;
- keep each thumb independently focusable;
- expose value text for each thumb.

## Value Contract

MUST:

- define numeric type and precision;
- define rounding before display and before persistence;
- separate internal value from localized value text;
- expose unknown, pending, invalid, and stale states;
- prevent impossible values from becoming authoritative state;
- avoid emitting every pointer move as persisted app state unless throttled.

SHOULD:

- support preview state while dragging;
- commit on release or explicit submit for expensive operations;
- keep undo/restore behavior for settings changes;
- expose resource implications in description, not label.

## Clean Disk Mapping

Examples:

- scan performance mode: segmented/radio first, slider only if continuous budget
  exists;
- worker count: spinbutton or numeric field with min/max;
- CPU/IO budget: slider with clear labels and value text;
- maximum scan depth: spinbutton;
- chart zoom: slider if it controls view only;
- cleanup threshold: spinbutton or slider depending on precision needs.

For MVP, avoid adding range controls unless there is a real setting. Do not add
a fancy slider just because it looks technical.

## Conformance Tests

Minimum tests:

- slider exposes min, max, current value, and value text;
- arrow keys adjust by step;
- page keys adjust by large step where configured;
- spinbutton direct edit preserves text editing shortcuts;
- invalid value is not committed as authority;
- localized value text does not change internal numeric value;
- range slider has two focusable thumbs;
- pointer drag throttles updates;
- readonly range is readable but not changeable;
- disabled range is not focusable unless product policy says otherwise.

## Failure Catalog

- Slider used for precise path or count entry.
- Locale-formatted number parsed as a different value.
- Parent shortcuts steal spinbutton arrow keys.
- Drag emits thousands of app state writes.
- Value text says "fast" while numeric policy means something else.
