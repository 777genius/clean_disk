# Motion Reduced Animation And Transition Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN `prefers-reduced-motion`: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion
- WCAG 2.2.2 Pause, Stop, Hide: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html
- WCAG 2.3.3 Animation from Interactions: https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility
- Flutter `MediaQueryData`: https://api.flutter.dev/flutter/widgets/MediaQueryData-class.html
- Flutter `AccessibilityFeatures`: https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures-class.html

## Scope

This standard defines how Headless primitives express motion policy, animation
intent, transition duration, reduced-motion adaptation, and user-controllable
motion.

It applies to:

- open, close, expand, collapse, select, reorder, sort, scroll, drag, and route
  transitions;
- loading, skeleton, shimmer, progress, chart, map, and metric animations;
- focus rings, hover effects, press effects, and row highlight transitions;
- app-level transitions owned by shell primitives;
- renderer adapters on Flutter, web DOM, Material, Cupertino, and future
  desktop renderers.

It does not define visual style. It defines the policy that renderer adapters
must consume.

## Decision Options

Option A: Renderer-local animation rules - 🎯 3   🛡️ 3   🧠 3, about
80-200 LOC per renderer.

- Fast to implement.
- Each renderer decides how to reduce motion.
- Fails as a public UI kit because components drift.
- Clean Disk risk: table rows, panels, charts, and route transitions reduce
  differently.

Option B: Global disable-animation boolean - 🎯 6   🛡️ 5   🧠 3, about
120-250 LOC.

- Simple and easy to test.
- Too coarse for productive apps.
- Some motion should become instant, some should become opacity-only, and some
  should stay because it communicates progress.

Option C: Headless motion policy with typed motion intents - 🎯 9   🛡️ 9
🧠 6, about 500-900 LOC.

- Component emits a semantic `MotionIntent`.
- Renderer resolves it through `MotionPolicy`.
- Reduced motion, disabled animation, performance mode, and user preferences
  all flow through one contract.
- This is the accepted direction.

## Accepted Direction

Headless must expose a `MotionPolicy` primitive that every component reads
before starting non-essential movement.

The policy is not a single boolean. It has semantic levels:

- `normal`: normal product animation budget.
- `reduced`: replace movement-heavy transitions with non-motion or minimal
  transitions.
- `instant`: skip non-essential animation and complete state changes
  immediately.
- `paused`: active looping or auto-updating motion is paused until resumed.

The component owns the motion intent. The renderer owns how it looks.

## Primitive Boundary

Headless owns:

- motion intent taxonomy;
- reduced-motion resolution;
- animation cancel and finish semantics;
- looping motion policy;
- transition lifecycle events;
- testable conformance rules;
- default duration categories;
- whether motion is essential, decorative, or progress-bearing.

Renderer owns:

- actual curves;
- opacity, transform, color, and size interpolation;
- platform-specific animation engine;
- shader or canvas implementation;
- visual polish.

Application owns:

- user preference overrides;
- performance mode;
- product-specific motion opt-out;
- analytics and support diagnostics, without logging sensitive paths.

## Motion Intent Taxonomy

Each animated primitive action must declare one intent:

- `stateChange`: selected, checked, active, expanded, collapsed.
- `surfaceEnterExit`: dialog, popover, drawer, side panel.
- `layoutReflow`: split pane resize, table column resize, responsive layout.
- `navigationTransition`: route, tab, wizard step, history restore.
- `attention`: toast, validation, warning, danger affordance.
- `progress`: scan progress, meter change, spinner, indeterminate loading.
- `dataChange`: sort, filter, pagination, row insertion, row removal.
- `spatialNavigation`: scroll to focused row, reveal selected node.
- `visualization`: chart, treemap, sunburst, graph, map.
- `decorative`: purely aesthetic effects.

Every intent must carry:

- `isEssential`;
- `canBePaused`;
- `canBeSkipped`;
- `reducedReplacement`;
- `maxDuration`;
- `cancelBehavior`;
- `announcesStateChange`.

## Reduced Motion Rules

When reduced motion is active:

- large scale transforms must be removed;
- parallax must be removed;
- long panning movement must be removed;
- animated scroll should become instant or small-step focus reveal;
- shimmer should become static skeleton or low-frequency opacity;
- decorative loops must stop;
- progress animation may continue only if it communicates active work;
- opacity transitions may remain if short and non-distracting;
- focus movement must never disappear, but the visual travel can be removed;
- route changes must update title, focus target, and content before animation
  polish.

## Pause Stop Hide Rule

Any motion that:

- starts automatically;
- lasts more than five seconds;
- repeats;
- appears next to other content;
- can distract from reading or operation;

must expose at least one of:

- pause;
- stop;
- hide;
- reduce;
- replace with static state.

Clean Disk examples:

- scan activity spinner may continue, but decorative row shimmer must stop;
- progress footer can show numeric progress instead of animated movement;
- visualization refresh must not continuously animate while user is reviewing
  deletion candidates.

## Animation From Interaction Rule

Motion triggered by user interaction must be disableable unless essential to
meaning.

Examples:

- expanding a folder can be instant under reduced motion;
- sorting a column must not animate rows flying across the table;
- opening the cleanup queue can use opacity instead of slide;
- moving an item to a delete queue must not rely on animated travel to explain
  the result.

## Flutter Adapter Requirements

The Flutter adapter should read:

- `MediaQuery.disableAnimations`;
- `MediaQuery.accessibleNavigation`;
- `MediaQuery.platformBrightness`;
- `MediaQuery.highContrast`;
- `MediaQuery.textScaler`;
- `PlatformDispatcher.accessibilityFeatures` where needed.

It should expose a stable `HeadlessMotionEnvironment` to primitives.

Renderer implementations must avoid creating animation controllers when the
resolved policy is `instant`, except when controller presence is required by a
framework primitive and duration is zero.

## Web Adapter Requirements

The web adapter should map:

- `prefers-reduced-motion: reduce`;
- visibility changes;
- user motion overrides;
- route and page lifecycle changes.

For web DOM adapters:

- CSS transitions must be guarded by motion classes or custom properties;
- animations must not be hidden in component-local CSS that bypasses Headless;
- `transitionend` must not be the only state completion path;
- reduced motion must complete state synchronously or through a deterministic
  microtask.

## State Machine

Motion state is:

```text
idle
  -> requested
  -> running
  -> completed
  -> cancelled
  -> skipped
  -> paused
  -> resumed
```

Rules:

- `skipped` is a successful completion path.
- `cancelled` must settle the component into a valid state.
- changing policy while running must either cancel or retarget the animation.
- no focus move may wait only for animation completion.
- no destructive confirmation may depend on decorative animation completion.

## Clean Disk Requirements

Clean Disk must use this standard for:

- scan progress footer;
- row selection and expansion;
- split pane resize;
- details panel enter or collapse;
- delete queue changes;
- toast and warning movement;
- chart and treemap refresh;
- route or tab transitions.

Critical rule:

- cleanup authority must never be conveyed only by animation.

If a folder is added to the queue, the queue state and accessible status must
change even when all animation is disabled.

## API Shape Sketch

```text
MotionPolicy
  level
  allowDecorativeMotion
  allowAutoPlayingMotion
  maxDuration(intent)
  resolve(intent, requestedSpec)

MotionIntent
  kind
  isEssential
  canBeSkipped
  canBePaused
  reducedReplacement

MotionLifecycle
  onRequested
  onStarted
  onCompleted
  onSkipped
  onCancelled
```

This is conceptual. Final API belongs in Headless implementation docs.

## Conformance Scenarios

- with reduced motion enabled, expanding 100 tree rows does not animate layout
  movement;
- with animation disabled, opening a dialog still moves focus correctly;
- cancelling an animated drawer leaves no hidden focusable child active;
- long-running shimmer can be paused or replaced;
- progress still communicates active work without motion;
- sort and filter changes are understandable without row movement;
- route transition updates page title and focus even when animation is skipped;
- runtime motion preference changes affect newly requested animations and
  safely cancel affected running animations.

## Failure Catalog

- relying on animation completion to update component state;
- using animated scroll as the only way to reveal focus;
- decorative loops with no pause or hide control;
- shimmer that continues while screen reader announces loading;
- reduced motion implemented in one renderer but not another;
- hidden CSS animation inside a renderer slot;
- chart animation that changes meaning without text or data update;
- global no-animation switch that also hides necessary progress state;
- policy changes causing controller leaks;
- tests that only run in normal animation mode.

