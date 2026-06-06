# User Intent And Command Provenance Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN User activation: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/User_activation
- MDN `Event.isTrusted`: https://developer.mozilla.org/en-US/docs/Web/API/Event/isTrusted
- MDN Clipboard API: https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API
- WCAG 2.5.2 Pointer Cancellation: https://www.w3.org/WAI/WCAG22/Understanding/pointer-cancellation.html
- WCAG 3.3.4 Error Prevention: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Scope

This standard defines how Headless primitives represent where a command came
from, whether it was user initiated, whether it can access privileged platform
APIs, and whether it can trigger destructive or sensitive actions.

It applies to:

- buttons;
- menu items;
- keyboard shortcuts;
- command palettes;
- context menus;
- native menus;
- gesture activations;
- assistive technology activations;
- automation and test drivers;
- programmatic API calls;
- daemon-originated events.

It does not define product authorization. It defines UI command provenance so
the application can make safe decisions.

## Decision Options

Option A: Treat every callback the same - 🎯 3   🛡️ 3   🧠 2, about
80-200 LOC.

- Easy.
- Cannot distinguish user click, shortcut, automation, restore, or programmatic
  dispatch.
- Unsafe for clipboard, file picker, destructive, and remote operations.

Option B: Boolean `isUserAction` - 🎯 5   🛡️ 5   🧠 3, about 150-350 LOC.

- Better than nothing.
- Too coarse for assistive tech, synthetic tests, native menus, and command
  replay.

Option C: Typed command provenance envelope - 🎯 9   🛡️ 9   🧠 6, about
700-1400 LOC.

- Accepted direction.
- Every Headless command has source, trust, modality, scope, and replay policy.
- Sensitive actions can require fresh user intent without coupling primitives
  to product logic.

## Accepted Direction

Every Headless command dispatch should include a `CommandProvenance`.

Provenance records:

- input modality;
- source primitive;
- source event kind;
- trusted user activation status if adapter can know it;
- keyboard shortcut id;
- assistive technology path;
- automation driver path;
- replay status;
- freshness timestamp;
- scope and focus owner;
- privacy class.

## Provenance Classes

Classes:

- `directPointer`;
- `directKeyboard`;
- `directTouch`;
- `assistiveTechnology`;
- `nativeMenu`;
- `shortcut`;
- `commandPalette`;
- `dragDrop`;
- `programmatic`;
- `automation`;
- `historyRestore`;
- `daemonEvent`;
- `replay`;
- `unknown`.

Each command declares which classes are acceptable.

## Fresh Intent Rules

Some actions require fresh user intent:

- open file picker;
- write clipboard;
- paste or read clipboard;
- reveal file in native shell;
- move to Trash confirmation;
- export sensitive report;
- authorize remote destructive action.

Fresh intent means:

- recent enough;
- came from an accepted input class;
- passed current capability and policy gates;
- not replayed from history restore;
- not triggered only by daemon event;
- not triggered by hidden focus target.

## Pointer Cancellation Rules

Pointer activation should follow safe cancellation rules:

- activate on release where possible;
- allow cancel by moving pointer away before release;
- avoid destructive action on pointer down;
- avoid duplicate activation from synthesized click plus key event;
- suppress repeat activation while command is submitting unless command is
  explicitly repeatable.

## Keyboard And Shortcut Rules

Keyboard activations are first-class user intent.

Rules:

- `Enter` and `Space` semantics must match the role;
- text editing shortcuts belong to text fields first;
- destructive shortcuts must open review or confirmation, not commit directly;
- shortcut invocation must include command id and focused scope;
- shortcuts cannot bypass disabled or capability-blocked state.

## Automation Rules

Automation is useful for tests, not automatically user intent.

Headless should support:

- automation provenance;
- deterministic test commands;
- conformance trace;
- test-only bypass flags guarded by environment;
- assertions that production destructive paths require accepted intent.

Automated tests can simulate accepted intent through adapter hooks, but the
trace must say that it is simulated.

## Clean Disk Requirements

Clean Disk must require command provenance for:

- add to queue;
- remove from queue;
- move to Trash;
- reveal in Finder or Explorer;
- copy path;
- custom scan target picker;
- export support bundle;
- remote destructive action.

Rules:

- daemon event cannot trigger cleanup by itself;
- route restore cannot trigger cleanup;
- stale shortcut cannot trigger cleanup;
- automation can test cleanup only through test policy and safe fixtures.

## API Shape Sketch

```text
CommandProvenance
  sourceClass
  sourcePrimitiveId
  inputModality
  trustedActivation
  commandId
  focusScopeId
  timestamp
  replayStatus
  automationMarker
  privacyClass

CommandIntentPolicy
  acceptedSources
  requiresFreshIntent
  maxAge
  allowReplay
```

## Conformance Scenarios

- pressing Space on button produces directKeyboard provenance;
- pointer down outside and release inside follows component policy;
- disabled shortcut cannot dispatch command;
- route restore does not dispatch move-to-trash;
- automation command is marked as automation in trace;
- clipboard write requires fresh accepted intent;
- native menu command preserves command id and window scope;
- duplicate keyboard and click synthesis results in one command.

## Failure Catalog

- destructive action triggered from history restore;
- shortcut bypasses disabled button;
- renderer callback omits provenance;
- user activation assumed from any callback;
- automation indistinguishable from user intent;
- pointer down commits destructive action;
- assistive tech activation treated as untrusted by default;
- duplicate activation from key and click;
- stale command replay after capability change;
- daemon event converted into UI command without user action.

