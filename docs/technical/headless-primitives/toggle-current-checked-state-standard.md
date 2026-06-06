# Toggle Current Checked And Selected State Standard

## Status

Implementation standard for `selected`, `checked`, `pressed`, `current`,
`expanded`, and `active` state semantics.

## Purpose

Many accessibility bugs come from using the wrong state. A selected row is not
a checked checkbox. A pressed toggle button is not a current page. An active
option is not a committed value. Headless needs explicit state semantics so
renderers do not mix visual state with meaning.

## Standards And References

- WAI-ARIA APG Switch:
  https://www.w3.org/WAI/ARIA/apg/patterns/switch/
- WAI-ARIA APG Checkbox:
  https://www.w3.org/WAI/ARIA/apg/patterns/checkbox/
- WAI-ARIA APG Button:
  https://www.w3.org/WAI/ARIA/apg/patterns/button/
- MDN ARIA attributes:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes
- MDN `aria-current`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-current
- MDN `aria-selected`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-selected
- Flutter accessibility:
  https://docs.flutter.dev/ui/accessibility

## Core Rule

State name must match user meaning, not visual style.

```text
highlighted
  != focused
  != active
  != selected
  != checked
  != pressed
  != current
  != queued
```

## State Meanings

Focused:

- current keyboard target;
- one logical active point per focus scope.

Active:

- current option candidate inside popup or composite;
- not necessarily selected or committed.

Selected:

- chosen item in selectable collection;
- can be single or multiple;
- independent from focus in multi-select.

Checked:

- checkbox, radio, switch-like value;
- can be mixed where role supports it.

Pressed:

- toggle button state;
- label usually remains stable.

Current:

- current item in a set such as page, step, location, or date;
- not selection for action.

Expanded:

- controls visibility of related content;
- parent node or disclosure state.

Queued:

- product/application concept;
- not Headless semantic state by itself.

## Mapping Rules

Use selected for:

- selected listbox option;
- selected grid row or cell;
- selected tab where tab pattern expects it.

Use checked for:

- checkbox;
- radio;
- switch;
- row checkbox UI.

Use pressed for:

- toggle button;
- toolbar toggle action.

Use current for:

- current route;
- current step;
- current breadcrumb item;
- current date in calendar.

Use expanded for:

- disclosure;
- tree node;
- combobox popup;
- menu button open state.

## Multi-State Controls

If a visual control could be checkbox, switch, or toggle button, choose based
on user mental model:

- setting on/off: switch;
- independent option in form/list: checkbox;
- command that toggles mode: toggle button;
- row selected for action: selection, not checkbox unless checkbox UI exists.

## Renderer Rules

Renderer can style:

- focused;
- hovered;
- active;
- selected;
- checked;
- pressed;
- current;
- disabled;
- warning.

Renderer cannot redefine semantic meaning. If app wants "queued", design
system maps it to product state plus any appropriate visible/semantic label.

## Clean Disk Examples

- focused row: TreeGrid navigation target;
- selected row: user selected for action;
- checked queue item: queue item included in cleanup plan review;
- queued folder: product state, not Headless selected state;
- current scan target: product state, possibly current item in navigation;
- expanded folder: hierarchy state.

## Required Tests

Automated:

- focus movement does not select in multi-select mode;
- checkbox checked state independent from row selected state;
- toggle button keeps stable label;
- current state not used for multi-selection;
- expanded state only on expandable items;
- renderer state names match semantic facts.

Manual:

- screen reader distinguishes selected from checked;
- toggle button announced as toggle/pressed where platform supports it;
- current navigation item is not confused with selected action target.

## Stop Rules

- Do not use selected to mean queued.
- Do not use checked without checkbox/switch/radio semantics.
- Do not use pressed for ordinary action buttons.
- Do not use current to mean focused.
- Do not let visual highlight create semantic state silently.
