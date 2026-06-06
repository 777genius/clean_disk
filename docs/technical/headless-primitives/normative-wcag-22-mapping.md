# Normative WCAG 2.2 Mapping

## Status

Normative accessibility mapping for Headless primitives.

## Primary Standards

- WCAG 2.2: https://www.w3.org/TR/WCAG22/
- WAI WCAG 2.2 overview:
  https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/

## Purpose

This file maps WCAG 2.2 concerns into Headless component contracts. It is not a
full legal conformance statement. It is an engineering gate.

## Mapping

| WCAG concern | Headless requirement | Affected primitives |
| --- | --- | --- |
| Keyboard | all actions operable by keyboard | all interactive |
| No keyboard trap | Escape/Tab policies documented | Dialog, Menu, TreeGrid |
| Focus order | logical focus order predictable | all composite widgets |
| Focus visible | renderer token for visible focus ring | all focusable |
| Focus not obscured | scroll-to-focus effect and overlay policy | TreeGrid, Dialog, Menu |
| Target size minimum | hit target tokens and conformance checks | buttons, handles, rows |
| Pointer cancellation | activation on release where possible | buttons, menu items |
| Dragging movements | non-drag alternative | SplitPane, column resize, reorder |
| Label in name | visible label included in semantic label | buttons, menus, dialogs |
| Name, role, value | semantic intent contract | all |
| Status messages | status region without focus movement | StatusRegion |
| Reduced motion | motion tokens respect reduce policy | overlays, tooltip, dialog |

## Target Size Policy

```text
HitTargetPolicy
  minimum: 24x24 logical px equivalent
  preferred: 32x32 or design-system value
  exceptions: inline text, dense table with equivalent row action path
```

Clean Disk dense table may have compact row actions, but commands must also be
available through row context menu and keyboard.

## Focus Appearance Policy

Renderer tokens:

```text
FocusRingTokens
  minThickness
  contrastIntent
  offset
  shape
```

Design system must ensure visible focus in dark and light themes.

## Dragging Alternative Policy

SplitPane:

- keyboard arrows;
- Home/End;
- collapse/restore command.

Column resize:

- keyboard resize mode before stable.

Reorder:

- do not stabilize without keyboard reorder alternative.

## Status Message Policy

Use `RStatusRegion` for:

- scan completed;
- reconnecting;
- background operation status.

Do not use status for:

- destructive confirmation;
- complex operation receipt;
- errors requiring decision.

## Conformance Checks

- keyboard-only walkthrough for every primitive;
- focus ring visible in dark/light renderer fixture;
- target size measured or equivalent alternative documented;
- drag alternative present;
- visible labels match semantic names;
- status update does not steal focus;
- reduced motion disables nonessential motion.

## Stop Rules

- Do not ship pointer-only primitives.
- Do not hide focus behind sticky UI.
- Do not use status messages for required destructive confirmation.
- Do not stabilize drag features without alternatives.
