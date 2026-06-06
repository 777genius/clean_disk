# Roving Focus And Active Descendant Algorithm Standard

## Status

Implementation standard for choosing and implementing logical focus strategies
inside composite primitives.

## Purpose

Composite widgets need one predictable keyboard entry point and efficient
internal navigation. Web standards commonly use roving `tabindex` or
`aria-activedescendant`. Flutter uses Focus, FocusScope, Semantics, and logical
state. Headless must expose a platform-neutral algorithm that can map to these
strategies without locking the public API to DOM details.

## Standards And References

- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- MDN `aria-activedescendant`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-activedescendant
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- Flutter Focus:
  https://docs.flutter.dev/ui/interactivity/focus
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Core Rule

Core Headless owns logical active item. Platform adapters own physical focus
mechanics.

```text
logical active key
  -> strategy adapter
  -> platform focus or active descendant
  -> semantic exposure
```

## Strategy Options

Logical root focus:

- Flutter root `Focus` remains active;
- logical key changes in component state;
- renderer draws active row or cell;
- semantics adapter exposes active facts.

Roving physical focus:

- platform focus moves between visible items;
- useful when each item is a natural control;
- adapter must handle unmount/remount under virtualization.

Active descendant:

- platform focus stays on root or input;
- adapter references active item by generated id;
- useful for virtualized composite web adapters;
- requires active item to be owned or represented in accessible tree.

## Strategy Selection

TreeGrid default for Clean Disk:

- rows-first logical focus in Headless;
- adapter can later choose active descendant for web;
- physical focus moves only when platform evidence shows it is better.

Menu default:

- roving focus can be appropriate because menu items are short-lived and
  mounted.

Combobox/CommandMenu default:

- input keeps physical focus;
- list uses active descendant or logical active option.

Dialog default:

- physical focus moves to concrete focus target inside dialog.

## Logical Focus Facts

Every composite focus model should expose:

```text
activeKey
activeKind
activeIndex
activeColumnKey
activeDepth
visibleRange
isActiveMounted
restorePolicy
scrollPolicy
reason
```

`activeKey` is not a product authority id. It is a UI logical key scoped to the
component snapshot.

## Navigation Algorithm

Navigation command:

1. validate component enabled state;
2. resolve active key against current projection;
3. find next candidate using policy;
4. skip or include disabled candidates by component rule;
5. update logical active key;
6. emit scroll effect if candidate is offscreen;
7. emit platform focus/semantics effect;
8. emit callback if public API requires it.

No step may depend on mounted widget index as authority.

## Virtualization Rules

When active item unmounts:

- logical focus remains;
- root or sentinel keeps platform focus if needed;
- semantic adapter does not expose stale offscreen item as mounted;
- scroll-to-active can remount target;
- if target disappears, fallback algorithm runs.

Fallback:

1. same key after refresh;
2. nearest visible sibling;
3. nearest visible ancestor;
4. first visible item;
5. root fallback.

## Focus And Selection

Focus is current navigation target. Selection is user choice for an action.

Rules:

- multi-select keeps selected state independent from active key;
- moving focus does not select unless policy explicitly says selection follows
  focus;
- selected item can be offscreen;
- active item must have visible focus indicator if mounted;
- destructive action cannot use active key alone as authority.

## Web Adapter Rules

If using active descendant:

- generated id must be stable while mounted;
- id must not contain user data;
- referenced item must be owned or logically represented;
- update active descendant on pointer and keyboard movement;
- keep visual active state synchronized.

If using roving tabindex:

- exactly one item in the composite is in tab sequence;
- all others are programmatically focusable or removed from tab sequence;
- click/tap updates roving target;
- focus movement scroll behavior is tested.

## Flutter Adapter Rules

- use `Focus`, `FocusScope`, `Shortcuts`, and `Actions`;
- do not create one `FocusNode` per million logical rows;
- maintain focus nodes only for mounted visible range where needed;
- keep logical focus in controller state;
- renderer receives focus facts, not focus authority.

## Required Tests

Automated:

- one active logical key;
- Tab enters and exits composite;
- arrow movement updates active key;
- disabled candidate policy;
- active key survives virtualization unmount;
- focus restore after overlay close;
- active descendant id redacted and stable.

Manual:

- screen reader announces active item;
- keyboard user sees focus indicator;
- pointer click updates keyboard target;
- web active-descendant path works in at least one browser/screen reader pair.

## Stop Rules

- Do not expose DOM focus strategy as core API.
- Do not create focus nodes for every logical row.
- Do not conflate focus and selection.
- Do not let unmounted active item vanish without fallback.
- Do not include product data in generated focus ids.
