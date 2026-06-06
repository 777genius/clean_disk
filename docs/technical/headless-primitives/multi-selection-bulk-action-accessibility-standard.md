# Multi Selection And Bulk Action Accessibility Standard

## Status

Implementation standard for single selection, multi-selection, range
selection, select-all, bulk commands, and safety boundaries.

## Purpose

Selection is powerful and risky. It affects keyboard UX, screen reader
announcements, virtualized data, command enablement, and Clean Disk cleanup
safety. Headless selection must be generic and accessible without becoming
product authority.

## Standards And References

- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN `aria-selected`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-selected
- MDN `aria-multiselectable`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-multiselectable
- WCAG 2.2:
  https://www.w3.org/TR/wcag-22/

## Core Rule

Selection is interaction state, not business authority.

```text
focus
  != selection
  != checked
  != queued
  != delete plan
```

Clean Disk must validate selected/queued items through application and daemon
contracts before destructive commands.

## Selection Modes

```text
none
single
multipleIndependent
multipleRange
checkboxSelection
cellRange
rowAndCellMixed
```

Every mode declares:

- anchor behavior;
- focus behavior;
- toggle behavior;
- range behavior;
- select-all scope;
- disabled item policy;
- hidden item policy;
- virtualization policy.

## Keyboard Selection

Default concepts:

- Space toggles focused item where policy allows;
- Shift + Arrow extends range where range selection is enabled;
- Ctrl/Cmd + A selects scope where allowed;
- Escape clears selection only if no higher-priority overlay/edit scope handles
  it;
- selection follows focus only in explicit single-selection patterns.

Do not make destructive selection change single-key by default.

## Scope Rules

Select-all scope can mean:

- visible page;
- filtered result;
- current subtree;
- current snapshot;
- current query result;
- all loaded items;
- all logical items.

The scope must be explicit in command facts and UI text. Headless should expose
scope metadata, not product meaning.

## Virtualization Rules

Selection model stores logical keys, not mounted rows.

Rules:

- selected offscreen items remain selected if still valid;
- selected item count can be known, approximate, or capped;
- range selection over unloaded data requires application support;
- stale keys are removed or marked stale on projection version change;
- hidden filtered items remain selected only by explicit policy.

## Semantic Rules

When multi-select is enabled:

- root exposes multiselect capability where platform supports it;
- selected state is separate from focus;
- count changes can be announced through status policy;
- checkbox selection exposes checked state if checkbox UI is used;
- disabled items are not selectable by alternate input.

## Bulk Action Rules

Bulk command availability depends on:

- selection mode;
- current selected keys;
- item capability;
- stale state;
- app policy;
- confirmation policy.

Headless can expose bulk command intent. Application decides whether the
command is allowed and what it means.

## Clean Disk Safety

For Clean Disk:

- selection is not cleanup queue;
- queue is not delete authority;
- `DeletePlan` is separate and validated;
- hidden filtered selections cannot be deleted without explicit current plan;
- stale snapshot disables destructive bulk actions;
- select-all never means "all disk files" unless user-facing scope and daemon
  validation make that explicit.

## Required Tests

Automated:

- focus movement without selection change;
- Space toggles selection;
- range selection anchor;
- select-all scope metadata;
- selected offscreen item survives scroll;
- stale selected key removed or marked;
- disabled item cannot be selected through pointer/keyboard/semantics.

Manual:

- screen reader announces selected state;
- selected count update is understandable;
- keyboard-only bulk action path;
- confirmation UI shows current validated plan.

## Stop Rules

- Do not let selection imply product authority.
- Do not hide select-all scope.
- Do not use localized labels as selected keys.
- Do not delete hidden/stale selected items without revalidation.
- Do not let disabled items be selected by alternate input.
