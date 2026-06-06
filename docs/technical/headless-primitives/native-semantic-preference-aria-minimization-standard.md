# Native Semantic Preference And ARIA Minimization Standard

## Status

Accepted as a Headless web adapter and public API standard. Not implemented
yet.

## Source Standards

- WAI-ARIA APG Read Me First: https://www.w3.org/WAI/ARIA/apg/practices/read-me-first/
- Using ARIA: https://www.w3.org/TR/using-aria/
- ARIA in HTML: https://www.w3.org/TR/html-aria/
- MDN ARIA: https://developer.mozilla.org/docs/Web/Accessibility/ARIA
- MDN button role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/button_role
- Flutter web accessibility: https://docs.flutter.dev/ui/accessibility/web-accessibility

## Scope

This standard defines when Headless prefers native platform semantics and when
it permits ARIA or custom semantics.

It applies to:

- web DOM adapters;
- Flutter web semantics;
- custom element adapters;
- Material/Cupertino adapters when mapping to web;
- public examples;
- contribution review.

It does not forbid ARIA. It prevents ARIA from being used as a patch for
missing behavior.

## Decision Options

Option A: Renderer authors choose native or ARIA freely - 🎯 3   🛡️ 3
🧠 2, about 50-150 LOC.

- Flexible.
- Misuse is likely in community renderers.

Option B: Prefer native elements in docs only - 🎯 6   🛡️ 5   🧠 3,
about 200-500 LOC.

- Helpful guidance.
- Not strong enough for conformance.

Option C: Native-first semantic policy with explicit ARIA justification -
🎯 9   🛡️ 9   🧠 6, about 700-1400 LOC.

- Accepted direction.
- Every non-native semantic mapping records why native semantics are not enough.
- ARIA role becomes a behavioral contract, not decoration.

## Accepted Direction

Headless should define `SemanticImplementationChoice`.

Choice fields:

- primitive id;
- adapter id;
- native semantic candidate;
- selected semantic mechanism;
- ARIA role if used;
- required behavior contract;
- keyboard contract;
- state contract;
- fallback;
- conformance evidence.

## Native-First Rule

Rules:

- use native button when button semantics and activation are enough;
- use native input where platform text editing is enough;
- use native dialog or platform modal behavior where reliable;
- use native progress and meter semantics where visual model matches;
- use ARIA only when native semantics cannot express required behavior;
- never add ARIA role without implementing the expected interaction pattern.

For Flutter web, native-first means using Flutter semantics that produce stable
platform semantics, not hand-writing ARIA in arbitrary renderers.

## ARIA Permission Classes

Classes:

- `nativePreferred`: native semantic exists and should be used.
- `ariaAllowed`: native semantic does not cover required behavior.
- `ariaRequired`: complex composite pattern needs ARIA or equivalent semantics.
- `ariaForbidden`: role conflicts with native semantics or hides required
  behavior.
- `adapterSpecific`: platform bridge decides.

Every `ariaAllowed` and `ariaRequired` choice must link to APG, ARIA in HTML,
or Headless behavior contract.

## Role Is A Promise

If an adapter exposes a role, it promises:

- keyboard behavior;
- focus behavior;
- name and description;
- state updates;
- pointer alternatives;
- disabled/read-only behavior;
- visible and semantic parity.

Example:

- `role=button` requires activation by keyboard, not only pointer click.
- `role=treegrid` requires composite navigation behavior, not just a table
  shape.
- `aria-expanded` requires state to match visible disclosure.

## Clean Disk Requirements

Clean Disk must enforce native-first semantics for:

- icon buttons;
- scan/pause/cancel controls;
- cleanup confirmation actions;
- search and filter inputs;
- progress footer;
- details inspector properties;
- cleanup queue checkboxes.

TreeTable can use complex semantics because native table/list controls do not
cover the required virtualized tree plus grid interaction on every adapter.

## API Shape Sketch

```text
SemanticImplementationChoice
  primitiveId
  adapterId
  nativeCandidate
  selectedMechanism
  ariaRole
  permissionClass
  requiredBehaviorRefs
  evidenceRefs
  fallback
```

## Conformance Scenarios

Required scenarios:

- icon button uses native button semantics or equivalent Flutter semantics;
- custom button with role has keyboard activation;
- native input is not wrapped in conflicting role;
- TreeGrid role links to keyboard and state contract;
- public example does not add redundant ARIA to native element;
- renderer with forbidden role fails lint.

## Failure Catalog

Failures:

- `div role=button` without keyboard activation;
- native button with redundant conflicting role;
- `aria-label` hides visible text and breaks label-in-name;
- visual expanded state differs from `aria-expanded`;
- renderer exposes role without state updates;
- public docs teach ARIA-first examples.

## Release Gates

Release gate:

- every web adapter mapping has semantic choice metadata;
- every ARIA role maps to behavior tests;
- forbidden role use fails lint;
- public examples are native-first unless justified;
- Clean Disk destructive controls never rely on decorative ARIA.

