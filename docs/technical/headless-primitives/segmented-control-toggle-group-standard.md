# Segmented Control Toggle Group Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Radio Group Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/radio/
- WAI-ARIA APG Toolbar Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/toolbar/
- WAI-ARIA APG Button Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/button/
- MDN `aria-pressed`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-pressed
- MDN `aria-selected`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-selected
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html

## Scope

This standard covers segmented controls, toggle groups, view mode switchers,
single-choice compact controls, multi-toggle tool clusters, scan mode pickers,
and toolbar-embedded exclusive choices.

It extends button, radio, toolbar, tabs, command bar, and density standards.
It focuses on the common design-system mistake where a row of visual buttons is
not modeled as any real interaction pattern.

## Problem

Segmented controls look simple but have several incompatible meanings:

- one selected value from a known set;
- multiple independent toggles;
- a navigation tab list;
- a toolbar group;
- a view mode command group;
- a filter shortcut group.

If Headless exposes only "buttons in a row", applications will guess semantics.
That leads to wrong keyboard behavior, wrong screen-reader output, broken
selection state, and accidental command execution when arrowing through a group.

## Decision Options

1. Typed segmented control with explicit selection behavior -
   🎯 10   🛡️ 9   🧠 7, roughly 800-1600 LOC.
   Best fit. It lets one primitive cover exclusive selection, toggle groups, and
   toolbar-contained variants without lying to assistive technology.
2. Render segmented controls as ordinary buttons -
   🎯 4   🛡️ 4   🧠 2, roughly 150-400 LOC.
   Fast, but it hides current value and forces every app to invent keyboard
   behavior.
3. Use tabs for every segmented control -
   🎯 5   🛡️ 6   🧠 4, roughly 250-700 LOC.
   Useful only when each option controls a tab panel. Wrong for scan modes,
   sort presets, and density modes.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- group mode;
- selected value set;
- focus value;
- roving focus or active descendant strategy;
- keyboard model;
- disabled item facts;
- orientation;
- toolbar containment behavior;
- accessible names and descriptions;
- controlled/uncontrolled state contract.

Renderer owns:

- segment visuals;
- selected styling;
- separators;
- compact/wide layout;
- icons;
- focus ring style;
- overflow wrapping.

Application owns:

- semantic option ids;
- current product mode;
- command execution;
- persistence;
- policy that disables values.

## Modes

Supported modes:

- `singleRequired`: exactly one item selected;
- `singleOptional`: zero or one item selected;
- `multiple`: independent toggles;
- `commandGroup`: buttons with no persistent pressed state;
- `toolbarRadio`: exclusive choice nested in a toolbar.

Rules:

- `singleRequired` maps to radio-group semantics;
- `multiple` maps to toggle button semantics;
- navigation tabs must use Tabs, not SegmentedControl;
- if an option changes route/content panel identity, use Tabs or Navigation;
- if an option immediately performs a command, use CommandBar/ButtonGroup.

## Keyboard Rules

For ordinary exclusive groups:

- `Tab` enters and leaves the group;
- arrow keys move focus;
- selection behavior follows configured activation policy;
- `Home` and `End` move to first and last item when enabled;
- disabled options can be skipped or focusable by explicit policy.

For toolbar-contained radio groups:

- arrow keys move focus through toolbar controls;
- moving focus does not change the checked value;
- `Space` or `Enter` commits the focused value;
- group boundaries do not trap toolbar navigation.

This distinction is mandatory because APG radio behavior changes when a radio
group is inside a toolbar.

## Toggle Button Rules

Independent toggles use pressed state.

Rules:

- label remains stable when `aria-pressed` state changes;
- if the visible label changes from "Play" to "Pause", it is not a pressed
  toggle and must be modeled as an ordinary command button;
- `mixed` state is reserved for aggregate controls;
- pressed state is not selected row state;
- pressed state is not current route state.

## State Model

```text
idle
  -> focused(option)
  -> pendingActivation(option)
  -> selected(value)
  -> disabledByPolicy(value, reason)
```

Selection facts:

- stable option id;
- selected flag;
- focused flag;
- disabled flag;
- disabled reason;
- availability confidence;
- policy version;
- shortcut hint.

## Clean Disk Usage

Likely uses:

- view mode: tree, map, list;
- scan mode: balanced, fast, background;
- result filter quick chips: all, files, folders, cleanup candidates;
- density: comfortable, compact;
- cleanup queue visibility: show, collapse.

Rules:

- scan mode choice is state, not a command;
- "Move to Trash" is never a segmented option;
- selected view mode cannot be represented by localized label;
- disabled mode explains missing capability;
- compact layout may wrap segments into a menu but keeps same state contract.

## Community API Sketch

```dart
enum RSegmentedControlMode {
  singleRequired,
  singleOptional,
  multiple,
  commandGroup,
  toolbarRadio,
}

final class RSegmentedControlItem<T extends Object> {
  const RSegmentedControlItem({
    required this.id,
    required this.value,
    required this.label,
    this.icon,
    this.description,
    this.disabledReason,
  });

  final String id;
  final T value;
  final String label;
  final RIconData? icon;
  final String? description;
  final String? disabledReason;
}
```

## Conformance Scenarios

- exclusive segmented control exposes one selected value;
- multi-toggle group exposes independent pressed states;
- toolbar-contained segmented radio does not change selected value on arrow;
- disabled option explains why it cannot be selected;
- label remains stable for pressed toggle buttons;
- visual selected state and keyboard focus state remain distinct;
- compact overflow menu preserves the same option ids.

## Anti-Patterns

- using tabs for non-panel mode choices;
- using `aria-pressed` for mutually exclusive radio-like options;
- changing toggle labels while keeping pressed state;
- treating focused segment as selected segment;
- using localized labels as values;
- hiding disabled options without explaining capability;
- making arrow navigation execute commands.

## Clean Architecture Note

The primitive owns interaction state only. Product state lives in the
application layer. Renderer adapters style selected and focused parts, but do
not decide which mode is available.

