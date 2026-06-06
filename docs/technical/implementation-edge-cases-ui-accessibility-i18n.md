# Implementation Edge Cases - UI Accessibility And Internationalization

Last updated: 2026-05-12.

This file records UI, accessibility, internationalization, and desktop ergonomics edge cases for Clean Disk.

Clean Disk is not a marketing page. The core product surface is a dense, interactive tree/table used for risky decisions. If the tree can only be understood visually, if keyboard navigation is inconsistent, if text scaling breaks rows, or if a path can visually spoof its own name, the product becomes unsafe even when the scanner is technically correct.

Related documents:

- [Implementation edge cases](implementation-edge-cases.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Rust architecture](rust-architecture.md)

## Sources Reviewed

- Flutter, [Web accessibility](https://docs.flutter.dev/ui/accessibility/web-accessibility). Relevant points: Flutter web translates its Semantics tree into accessible DOM, standard widgets often provide semantics, and custom components need explicit roles.
- Flutter API, [Semantics widget](https://api.flutter.dev/flutter/widgets/Semantics-class.html) and [semantics library](https://api.flutter.dev/flutter/semantics/). Relevant points: Semantics annotates widgets for assistive technologies and includes traversal order, events, roles, labels, and actions.
- Flutter, [Keyboard focus system](https://docs.flutter.dev/ui/interactivity/focus). Relevant points: desktop/web apps need deliberate focus traversal, `FocusableActionDetector`, `Actions`, and `Shortcuts`.
- Flutter, [Internationalizing Flutter apps](https://docs.flutter.dev/ui/internationalization). Relevant points: locale tracking, localized Material/Cupertino widgets, and supported locale configuration are first-class app concerns.
- Flutter API, [GlobalMaterialLocalizations](https://api.flutter.dev/flutter/flutter_localizations/GlobalMaterialLocalizations-class.html). Relevant point: Material widgets use localized strings and intl-based date/time formatting.
- W3C WAI-ARIA APG, [Treegrid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/). Relevant points: treegrids need explicit keyboard interaction, focus state, selection state, expansion state, and sort semantics.
- W3C, [WCAG 2.2](https://www.w3.org/TR/wcag/) and [What's new in WCAG 2.2](https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/). Relevant points: focus visibility, target size, contrast, keyboard accessibility, and non-color indicators matter for dense controls.
- Unicode, [UTR #36 Unicode Security Considerations](https://www.unicode.org/reports/tr36/). Relevant point: Unicode and bidirectional text can create visual spoofing risks.
- W3C, [Additional Requirements for Bidi in HTML and CSS](https://www.w3.org/TR/html-bidi/). Relevant point: direction should be declared with markup/style mechanisms and bidi isolation matters for mixed-direction text.
- Unicode CLDR, [CLDR Project](https://cldr.unicode.org/) and [Unit names and patterns](https://cldr.unicode.org/translation/units/unit-names-and-patterns). Relevant points: dates, numbers, units, file-size labels, and alphabetical order vary by language and locale.
- Apple Human Interface Guidelines, [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards/). Relevant points: support full keyboard access, respect standard shortcuts, and test keyboard-only operation.
- Microsoft Fluent 2, [Accessibility](https://fluent2.microsoft.design/accessibility). Relevant points: accessible design starts early; focus, color contrast, hierarchy, and keyboard support are foundational.
- Microsoft Learn, [Developing inclusive Windows apps](https://learn.microsoft.com/windows/apps/design/accessibility/developing-inclusive-windows-apps). Relevant points: programmatic access, keyboard navigation, and color/contrast behavior affect Windows usability.
- GNOME HIG, [Keyboard](https://developer.gnome.org/hig/guidelines/keyboard.html). Relevant point: every UI part should be reachable and operable by keyboard.

## Severity Scale

- `P0` - must be handled before delete-capable releases.
- `P1` - should be handled before public beta.
- `P2` - important polish, but can follow once core workflows are stable.

## Top 3 UI Decisions

1. Accessible virtual tree/table primitive in `packages/design_system` - 🎯 9 🛡️ 9 🧠 8, roughly 700-1800 LOC across widget, focus model, semantics, keyboard actions, tests, and examples.
2. Separate focus, selection, expansion, and delete queue state - 🎯 10 🛡️ 10 🧠 5, roughly 300-800 LOC across stores, row models, protocol queries, and widget tests.
3. Bidi/control-character-safe path rendering and confirmation copy - 🎯 9 🛡️ 9 🧠 6, roughly 250-700 LOC across path display, suspicious character marking, screen-reader labels, and delete confirmation tests.

## Core UI Principle

Every destructive decision must be understandable through three channels:

- visual layout;
- keyboard/focus state;
- assistive technology semantics.

If these disagree, the workflow is unsafe.

Examples:

- selected row is not the same as focused row;
- queued-for-delete item is not the same as selected detail row;
- expanded tree branch is not the same as loaded children page;
- visual path text is not the same as filesystem identity;
- table sort order is not the same as localized display string order.

## Central Tree/Table

### Treegrid Is A Product Primitive - `P0`

The folder tree is not an ordinary list. It combines hierarchy, columns, expansion, sorting, selection, focus, details, and destructive actions.

Implementation rule:

- build a dedicated Clean Disk tree/table primitive;
- do not compose the main workflow from generic cards or a basic `DataTable`;
- expose row level, expanded/collapsed state, selected state, queued state, size, percent, item count, and modified date;
- row identity uses stable node id, not visual index;
- all row actions are available without hover.

Headless/design-system rule:

- if Headless lacks treegrid/table virtualization, roving focus, keyboard action, menu, tooltip, or accessible disclosure primitives, report the gap before adding local hacks.

### Focus, Selection, Expansion, And Queue Are Different - `P0`

WAI-ARIA treegrid guidance treats focus and selection as separate, especially for multi-select workflows. Clean Disk also has a delete queue.

Implementation rule:

- focused row: where keyboard actions go;
- selected row: what details panel describes;
- expanded rows: presentation state for visible hierarchy;
- queued items: pending cleanup plan state;
- checked items inside delete queue: cleanup plan item inclusion state.

Forbidden:

- moving focus automatically queues for delete;
- selecting a row automatically confirms cleanup;
- details panel changing while keyboard focus moves if the product policy says it follows selection;
- row index as state key.

### Virtualization Must Preserve Orientation - `P0`

A virtualized tree will render only part of the data. That is good for performance but risky for accessibility.

Implementation rule:

- screen reader label includes level, name, type, size, percent, expansion, and queued state;
- row exposes position where feasible: visible row position and sibling count, not fake total count if unknown;
- expanding a row announces whether children are loading, loaded, empty, or failed;
- collapsed branches must not leave stale focus on an unmounted child;
- scrolling should not steal focus unless user action caused it.

Tests:

- focus row, expand it, verify focus remains understandable;
- collapse parent while child focused;
- filter hides focused row;
- scan update changes size while row focused;
- screen-reader semantics dump includes row label and actions.

### Sorting And Filtering Are State, Not Cosmetic - `P1`

Sort/filter changes can silently change what a keyboard or screen-reader user acts on.

Implementation rule:

- sort column and direction are visible and semantic;
- after sort/filter, focus moves by stable node id when possible;
- if focused node disappears, focus moves to nearest explainable row and announces why;
- filter results cannot be used as delete proof;
- "show only cleanup candidates" is a query mode, not an implicit deletion list.

### Details Panel Must Mirror The Same Object - `P0`

The details panel is where a user forms trust before adding to queue.

Implementation rule:

- details panel always references node id and scan snapshot/version;
- if selected node goes stale, details panel shows stale state;
- details action buttons send node/delete-candidate id, not raw path strings;
- screen-reader label for details begins with object name and status;
- "Reveal in Finder/Explorer" and "Add to Queue" are keyboard reachable.

## Keyboard And Desktop Ergonomics

### Keyboard-Only MVP Workflow - `P0`

A user should be able to scan, search, navigate, inspect, queue, remove, and confirm without a mouse.

Required keyboard path:

- choose target;
- start scan;
- focus search;
- move through tree;
- expand/collapse folders;
- sort/filter;
- open context menu or action menu;
- add/remove from queue;
- inspect details;
- move through delete queue;
- open confirmation;
- cancel safely.

### Shortcut Policy Must Be Platform-Aware - `P1`

macOS, Windows, Linux, and web have different expectations.

Implementation rule:

- use `Cmd` on macOS and `Ctrl` on Windows/Linux/web for command shortcuts;
- do not override standard platform shortcuts such as quit, close, copy, paste, select all, find, refresh, and system navigation unless product intent is explicit;
- avoid shortcuts that conflict with browser shortcuts in web UI;
- text fields keep text-editing shortcuts;
- shortcuts are discoverable through menus/tooltips/help, not hidden lore.

Examples:

- `Cmd/Ctrl+F` focuses search;
- `Enter` opens/default action;
- `Space` toggles selection/check only where expected;
- arrow keys navigate tree;
- `Right` expands, `Left` collapses or moves to parent;
- `Delete/Backspace` removes from queue only when queue has focus, not from disk.

### Roving Focus Is Preferable For The Tree - `P1`

Dense tree tables become painful if every button in every row is in the tab order.

Implementation rule:

- one tab stop enters the tree;
- arrow keys move within rows/cells;
- row action menu is opened by keyboard;
- inline icon buttons remain reachable through row action mode or context menu;
- tab exits the tree to details/queue.

### Native Dialogs Can Break Focus Recovery - `P1`

Folder picker, reveal-in-file-manager, permissions dialogs, confirmation dialogs, and updater prompts can change focus.

Implementation rule:

- save logical focus before opening native dialog;
- restore focus to the triggering control or meaningful fallback;
- if target disappears, focus returns to the nearest stable parent panel;
- modal close never leaves focus on an offstage widget;
- tests cover file picker cancel and permission flow cancel.

### Hover-Only Controls Are Not Acceptable - `P0`

Row action icons can appear on hover visually, but actions must remain available without hover.

Implementation rule:

- row action menu is keyboard reachable;
- visible selected/focused row can show actions;
- screen reader exposes actions;
- touch/trackpad users have a stable target;
- destructive actions require queue/confirmation path, not a tiny hover button.

## Screen Reader And Semantics

### Flutter Web Semantics Needs Explicit Enablement - `P1`

Flutter web accessibility depends on the Semantics layer being exposed to the browser. Custom components without roles can be incomprehensible.

Implementation rule:

- web app enables semantics intentionally in production;
- custom tree/table rows use `Semantics` and appropriate roles/actions where Flutter supports them;
- semantics tests run for web and desktop where feasible;
- visible text and semantic label are not contradictory;
- icon-only buttons have labels and tooltips.

### Semantics Labels Need Product Language - `P1`

Raw file names alone are not enough.

Good row label shape:

```text
Folder Caches, level 4, expanded, selected, 38.7 GB, 10 percent of scanned target, 24,981 items, queued for cleanup.
```

Implementation rule:

- labels are concise but complete;
- high-frequency progress changes are not announced every frame;
- terminal scan/delete events are announced;
- warnings such as stale, skipped, permission denied, and in use are announced;
- screen-reader labels use localized size/date strings.

### Progress Announcements Must Be Throttled - `P1`

Progress updates can become assistive-technology spam.

Implementation rule:

- announce scan start, significant milestones, pause/resume, errors, completion, and cancellation;
- do not announce every file or every percent;
- screen-reader live region behavior is tested manually;
- user can inspect detailed progress without forced announcements.

### Charts Need Text Alternatives - `P2`

Donut charts and bars are useful visually, but they are secondary.

Implementation rule:

- chart data is also available as text/list;
- chart labels include category, size, and percent;
- color is never the only category indicator;
- details panel remains the authoritative information view.

## Visual Accessibility

### Dark Neon Palette Needs Contrast Discipline - `P0`

The chosen design direction uses dark surfaces, cyan/violet accents, and warning colors. This can look good and still fail readability.

Implementation rule:

- every text/background pair meets WCAG AA contrast for normal text where applicable;
- focus ring has enough contrast against both selected and unselected rows;
- disabled controls are visibly disabled but still readable;
- warning/error/success states include icon/text, not color alone;
- selected row, focused row, hover row, and queued row are visually distinct.

### Focus Indicator Is A Core Token - `P0`

Focus must not disappear inside neon glows or selected rows.

Implementation rule:

- design system owns focus tokens;
- focus ring works on dark and light themes;
- focus ring is visible over selected row;
- focus ring is not replaced only by color shift;
- compact layout keeps focused element unobscured by sticky bottom progress.

### Target Size And Hit Areas - `P1`

Dense productivity UI still needs usable targets.

Implementation rule:

- icon buttons have predictable hit boxes;
- tiny visual icons can have larger invisible hit area;
- row checkboxes and disclosure controls meet minimum target size where possible;
- resize handles/splitters are usable with pointer and keyboard;
- compact layout preserves target size before reducing density.

### Reduced Motion And Animation - `P1`

Scanning progress, row expansion, loading shimmer, and chart animations can be distracting.

Implementation rule:

- respect platform reduce-motion/disable-animation signals where Flutter exposes them;
- animations are short and non-essential;
- no flashing progress effects;
- progress remains understandable if animations are disabled.

## Text Scaling, Layout, And Density

### Text Scale Must Not Break The Table - `P0`

Users can increase system font size. Dense rows and fixed-height cells are the first things to break.

Implementation rule:

- do not clamp global text scale to 1.0;
- table row height can grow within defined limits;
- numeric columns have min/max constraints and ellipsis strategy;
- long paths wrap or elide in details where appropriate;
- action buttons do not clip localized labels.

Tests:

- 100 percent text scale;
- 150 percent text scale;
- 200 percent text scale for core workflows;
- bold text where platform exposes it;
- compact width with long folder names.

### Truncation Must Preserve Important Ends - `P1`

For paths, the end can be more important than the beginning.

Implementation rule:

- use middle truncation for full paths;
- keep file/folder basename visible where possible;
- tooltip/details show full sanitized path;
- screen reader can access full path separately;
- delete confirmation shows enough parent context.

### Density Is A User Preference, Not A Hidden Constant - `P2`

The app may need comfortable and compact modes later.

Implementation rule:

- design system tokens support row height/density variants;
- compact mode never hides warnings or delete confirmation details;
- accessibility mode can force comfortable density;
- saved density is per user/device.

## Internationalization And Locale

### Localized Text Must Be Designed Early - `P1`

English labels are often shorter than other languages.

Implementation rule:

- all user-facing strings go through localization APIs;
- UI components are tested with pseudo-localized long strings;
- buttons have min widths and wrapping/ellipsis policy;
- no string concatenation for localized sentences;
- pluralization is handled through localization, not manual `s`.

### Sizes, Dates, Numbers, And Units Need A Policy - `P1`

CLDR exists because units, dates, numbers, and sorting vary by locale.

Implementation rule:

- define binary vs decimal size policy explicitly;
- display size is localized;
- internal sort uses numeric bytes, not displayed string;
- dates use locale-aware formatting;
- tests include locales with different separators, date order, and longer unit names.

Open question:

- Should default size display be binary (`GiB`) for technical accuracy or user-friendly decimal (`GB`) by platform convention? This should be a product decision, not an adapter accident.

### Sorting And Search Must Not Depend On Display Strings Alone - `P1`

Localized collation and filesystem order are not always the same.

Implementation rule:

- size sort uses numeric value;
- date sort uses timestamp value;
- path/name sort has a stable deterministic fallback;
- search matching can be user-friendly, but delete identity cannot use normalized display strings;
- remote/server mode reports sort policy in query metadata.

### RTL Layout And Mixed-Direction Paths - `P1`

The app may not localize to RTL languages immediately, but file paths can contain RTL text today.

Implementation rule:

- path segments are rendered with bidi isolation where possible;
- suspicious bidi controls are visibly marked or escaped in safety-critical contexts;
- confirmation dialog shows sanitized display plus stable metadata;
- screen-reader label includes warning when path contains hidden controls;
- tests include Arabic/Hebrew names mixed with Latin extensions and numbers.

### Control Characters In Names Are A UX And Security Risk - `P0`

Filenames can include tabs, newlines, carriage returns, ANSI-like sequences, zero-width characters, and bidi controls.

Implementation rule:

- table cells render control characters safely;
- confirmation dialog marks or escapes control characters;
- logs and support bundle escape controls;
- clipboard/export paths use safe escaping policy;
- delete operation uses node id and identity snapshot, not copied display text.

## Destructive UX Accessibility

### Confirmation Must Be Keyboard And Screen-Reader Clear - `P0`

Delete confirmation is a safety boundary.

Implementation rule:

- focus moves to confirmation title or first safe control;
- dangerous action is not default focus;
- confirmation includes count, total estimated reclaim, risk tier summary, and top representative paths;
- screen-reader label announces that items will move to Trash, not just "confirm";
- Escape/cancel is always available.

### Required Acknowledgement Must Not Be A Mouse Trap - `P1`

If we require a checkbox, typed phrase, or review step, it must work with keyboard and screen reader.

Implementation rule:

- checkbox label is explicit;
- typed phrase is localized carefully or avoided;
- errors are announced;
- submit button disabled reason is available;
- validation does not depend on color only.

### Undo/Trash State Needs Accessible Feedback - `P1`

If a move-to-trash operation finishes, users need to know what happened.

Implementation rule:

- terminal status is announced;
- failures stay in queue with reason;
- receipt link/action is keyboard reachable;
- "Reveal in Trash" is capability-gated;
- no toast-only success message for destructive actions.

## Web, Desktop, And Platform Differences

### Web UI Must Work With Browser Accessibility Expectations - `P1`

Flutter web is not normal HTML, so we must test rather than assume.

Implementation rule:

- test with browser zoom at 100, 150, and 200 percent;
- test with screen reader/browser combinations;
- test keyboard navigation when address bar, browser shortcuts, and page focus compete;
- ensure route changes update title/semantic context;
- avoid trapping focus in canvas-like regions.

### macOS, Windows, And Linux Need Separate Manual Checks - `P1`

Accessibility stacks differ by OS.

Manual test matrix:

- macOS: VoiceOver, Full Keyboard Access, increase contrast, reduce motion;
- Windows: Narrator or NVDA, high contrast/contrast themes, keyboard-only, text scaling;
- Linux: at least keyboard-only and a screen-reader/desktop environment check when packaging target is chosen;
- web: Chrome/Edge plus at least one screen-reader path.

### File Manager Integration Needs Fallbacks - `P2`

Reveal in Finder/Explorer/file manager is useful but not universal.

Implementation rule:

- failed reveal returns typed error;
- keyboard user gets path copy/open parent fallback;
- UI does not rely on reveal as the only way to inspect an item;
- remote/headless mode hides local reveal actions.

## Design System And Headless Requirements

### Required Primitives - `P0`

The design system should expose primitives for:

- accessible icon button;
- tooltip with semantic label policy;
- menu/action menu;
- dialog with focus trap and restoration;
- tree/table row;
- disclosure control;
- progress status;
- alert/warning row state;
- split pane/resizable panel;
- keyboard shortcut registry;
- focus ring token;
- path text renderer;
- size/date formatter wrapper.

### Headless Improvement Triggers - `P1`

Report a Headless gap instead of hiding it when:

- custom table virtualization cannot expose stable semantics;
- focus traversal must be implemented per page;
- menu/dialog focus management is not reusable;
- tooltip semantics differ from visible label;
- keyboard shortcuts cannot be composed safely;
- high-contrast tokens require per-widget overrides;
- path/bidi safe rendering cannot be centralized.

### Component Tests Are Contracts - `P1`

Design system components should have tests for:

- keyboard traversal;
- focus restoration;
- semantic labels;
- high contrast token use;
- text scale behavior;
- RTL/mixed-direction rendering;
- disabled and loading states;
- tooltip/menu/dialog behavior.

## Testing Matrix

### Tree/Table Tests

- focus vs selection vs queue are independent;
- expand/collapse with keyboard;
- selection survives sorting by node id;
- focus recovery after filter hides focused row;
- row action menu opens from keyboard;
- no hover-only action is required;
- semantics label contains name, role/type, level, size, state, and warning.

### Accessibility Tests

- screen reader can identify scan target controls;
- tree row announces expanded/collapsed and selected/queued state;
- progress milestone announcement is throttled;
- confirmation dialog is understandable without looking;
- keyboard can complete scan and cancel confirmation;
- focus is visible in dark and light themes;
- high contrast mode keeps critical states distinct.

### I18n Tests

- pseudo-localized long strings;
- German/Russian/French labels in compact layout;
- Arabic/Hebrew mixed-direction path;
- Hindi/Arabic number formatting if supported;
- 12h/24h date differences;
- decimal separator differences;
- plural forms for files/folders/items;
- long unit strings for bytes and file counts.

### Spoofing And Control Character Tests

- filename with newline;
- filename with tab;
- filename with carriage return;
- filename with zero-width joiner/non-joiner;
- filename with RTL override;
- filename with mixed Latin/Cyrillic confusables;
- filename that visually ends in `.txt` but logically differs;
- path copied/exported safely.

### Layout Tests

- 320-480 px compact width;
- 768 px tablet/narrow desktop;
- wide desktop reference;
- 150 percent text scale;
- 200 percent text scale core workflows;
- browser zoom 200 percent;
- long path in details panel;
- delete queue with many long names.

## MVP Cut Line

Must be in MVP:

- dedicated tree/table primitive plan;
- keyboard-only scan/search/tree/details/queue/cancel workflow;
- focus/selection/queue separation;
- icon buttons with labels/tooltips;
- visible focus ring tokens;
- no hover-only required actions;
- safe path renderer for control characters and bidi controls in delete contexts;
- localized string infrastructure;
- size/date formatter abstraction;
- screen-reader labels for critical controls;
- confirmation dialog accessible by keyboard and screen reader;
- basic high-contrast and text-scale checks.

Can wait:

- full RTL localization;
- full OpenTelemetry accessibility metrics;
- user-configurable density;
- complete screen-reader parity for every secondary chart;
- advanced custom collation;
- keyboard shortcut customization;
- formal WCAG audit.

## Summary

📌 UI invariant: if a user cannot understand and operate the cleanup workflow with keyboard and assistive technology, the workflow is not safe enough to delete files.

The strongest product shape is:

- one central accessible tree/table primitive;
- clear separation between focus, selection, expansion, and queue;
- safe path rendering for Unicode/control-character edge cases;
- localized formatting for sizes, dates, counts, and messages;
- visible focus and contrast discipline in both themes;
- Headless/design-system primitives that carry accessibility instead of page-level patches.
