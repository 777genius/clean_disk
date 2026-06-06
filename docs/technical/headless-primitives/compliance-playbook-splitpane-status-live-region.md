# Compliance Playbook - SplitPane Status And Live Regions

## Status

Compliance checklist for `RSplitPane`, `RStatusRegion`, and noninteractive
status feedback used by complex primitives.

## Standards

- WAI-ARIA APG Window Splitter:
  https://www.w3.org/WAI/ARIA/apg/patterns/windowsplitter/
- MDN `separator` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/separator_role
- MDN `status` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Roles/status_role
- MDN ARIA live regions:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/ARIA_Live_Regions
- WCAG 2.2:
  https://www.w3.org/TR/wcag-22/

## SplitPane Compliance Model

`RSplitPane` is not a layout helper only. When panes are resizable by the user,
the divider is an interactive control and must expose value, keyboard behavior,
focus visibility, and pointer alternatives.

Required facts:

- orientation;
- primary pane id;
- primary pane accessible name;
- minimum, maximum, current value;
- value text if percentages are not meaningful;
- collapsed/restored state;
- disabled/read-only state;
- resize step and large resize step;
- last restored value.

## SplitPane Keyboard Contract

Variable splitter:

- `ArrowLeft` decreases a vertical splitter in LTR;
- `ArrowRight` increases a vertical splitter in LTR;
- `ArrowUp` decreases a horizontal splitter;
- `ArrowDown` increases a horizontal splitter;
- `Home` moves to minimum allowed primary pane size;
- `End` moves to maximum allowed primary pane size;
- `Enter` toggles collapsed/restored when collapse is enabled;
- `Escape` cancels an active drag preview if preview mode exists.

RTL rule:

- visual arrow meaning may invert, but API must expose a deterministic
  `increase` and `decrease` command so renderers can adapt correctly.

Fixed splitter:

- may omit continuous arrow resizing;
- must still expose toggle state if it collapses/restores a pane.

## Flutter Mapping

The Flutter adapter should expose:

- focusable separator handle;
- semantic label based on primary pane;
- semantic value or increased/decreased actions when supported;
- `FocusableActionDetector` for hover, focus, and shortcuts;
- `Actions` and `Shortcuts` instead of ad hoc key handlers;
- separate drag controller from committed pane value.

The renderer should not own:

- pane size persistence;
- collapse policy;
- product labels;
- analytics;
- command side effects.

## StatusRegion Compliance Model

`RStatusRegion` is for advisory updates that should not steal focus. It is not
a modal dialog replacement, not an error boundary, and not a toast queue by
default.

Required facts:

- politeness: `off`, `polite`, or `assertive`;
- atomicity;
- message id;
- message text;
- message severity;
- dedupe key;
- expiry policy;
- privacy class.

Default policy:

- scan progress uses `off` or throttled `polite`;
- completed operation uses `polite`;
- destructive failure may use `assertive`;
- required user decision uses dialog, not status.

## Live Region Rules

The live region must exist before updates are emitted where the platform needs
that behavior. The component should update content inside a stable region
rather than replacing the whole region.

Announcement throttling:

- progress updates should be coalesced;
- duplicate messages should be suppressed;
- status text should be short;
- high-frequency virtual scrolling should not announce every row;
- assertive announcements require explicit severity.

Focus rule:

- status updates never move focus;
- if focus must move, the pattern is probably dialog, alert dialog, or route
  transition, not status.

## WCAG 2.2 Risks

Focus:

- focus indicator must remain visible after pane resize;
- focus must not be obscured by sticky overlays or resize handles.

Pointer:

- drag-only resize must have keyboard or button alternatives;
- touch targets for handles need sufficient physical size or equivalent
  larger targets.

Motion:

- animated pane resizing must respect reduced motion;
- resize preview should not create flashing or severe layout instability.

## Required Evidence

Automated:

- keyboard resize script;
- semantics label/value test;
- focus restore after collapse;
- no focus steal for status updates;
- announcement throttle unit test;
- Flutter guideline checks for handle target size where applicable.

Manual:

- VoiceOver announces splitter label and value;
- NVDA announces updated value or change;
- status message is heard without focus movement;
- assertive failure interrupts only when expected;
- reduced motion path avoids animated resizing.

## Stop Rules

- Do not ship a draggable SplitPane without keyboard resize.
- Do not expose raw product text in status diagnostics.
- Do not announce every progress tick.
- Do not use `alert` or assertive live regions for routine updates.
- Do not treat layout-only divider and user-resizable splitter as the same API.
