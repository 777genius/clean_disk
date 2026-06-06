# Screen Reader Interoperability Lab

## Status

Research and test plan for proving Headless primitive behavior across assistive
technology stacks.

## Purpose

ARIA and Flutter semantics are contracts, but real behavior depends on the
platform accessibility bridge, browser, screen reader, keyboard layout, and
user settings. Headless needs a repeatable lab instead of one-off manual
checks.

## References

- ARIA-AT project:
  https://w3c.github.io/aria-at/
- WAI-ARIA APG Patterns:
  https://www.w3.org/WAI/ARIA/apg/patterns/
- Flutter web accessibility:
  https://docs.flutter.dev/ui/accessibility/web-accessibility
- Flutter accessibility testing:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Test Matrix

Minimum public matrix:

```text
macOS + VoiceOver + Safari
macOS + VoiceOver + Chrome
Windows + NVDA + Firefox
Windows + NVDA + Chrome
Windows + JAWS + Chrome, optional commercial lab
Linux + Orca + Firefox, best-effort
Flutter desktop macOS + VoiceOver
Flutter desktop Windows + Narrator/NVDA, best-effort
Flutter web + browser accessibility bridge
```

Clean Disk internal matrix can start smaller:

```text
macOS + VoiceOver + Flutter desktop
macOS + VoiceOver + Flutter web
Windows + NVDA + Flutter web
```

## Scenario Shape

Each scenario records:

- component;
- renderer;
- platform;
- browser/runtime;
- screen reader;
- exact version;
- keyboard layout;
- input modality;
- fixture id;
- expected announcement;
- actual announcement;
- pass/fail;
- notes;
- linked issue.

## Component Scenarios

TreeGrid:

- enter grid from previous control;
- move row by row;
- expand parent;
- collapse parent;
- select row;
- sort column;
- open context menu by keyboard;
- jump to offscreen row;
- load more children;
- announce skipped/disabled row.

ContextMenu:

- open from trigger;
- open by context menu key;
- arrow between items;
- skip or focus disabled item according to policy;
- open submenu;
- close submenu;
- activate item;
- restore focus.

Dialog:

- initial focus on title/static content;
- initial focus on least destructive action;
- Tab loop;
- Escape close;
- nested dialog close order;
- busy submission;
- validation error announcement.

SplitPane:

- focus handle;
- announce label and current value;
- arrow resize;
- Home/End;
- collapse/restore;
- move focus between panes.

StatusRegion:

- polite message;
- assertive failure;
- duplicate suppression;
- no focus movement;
- throttled progress.

Tooltip:

- focus trigger;
- hover trigger;
- Escape close;
- description relationship;
- no interactive descendants.

## Evidence Format

Use the `accessibility-evidence-report-template.md` file for every manual run.

Evidence can include:

- short sanitized transcript;
- pass/fail table;
- screen reader speech viewer screenshot if safe;
- semantic tree dump with product data removed;
- browser accessibility tree snapshot if safe.

Evidence must not include:

- real disk paths;
- file names from user machines;
- search text;
- daemon tokens;
- support bundle ids;
- private user names.

## Interop Risk Levels

```text
green: automated tests and two manual AT stacks pass
yellow: automated tests pass, one AT gap documented
orange: core keyboard works, AT behavior inconsistent
red: keyboard trap, wrong target, false destructive cue, or missing label
```

Red blocks stable release. Orange blocks accessibility claim. Yellow requires
known limitation docs.

## Public Claim Policy

Allowed claims:

- "keyboard accessible according to the documented command matrix";
- "tested with VoiceOver on macOS";
- "Flutter semantics adapter passes guideline tests";
- "web ARIA bridge is experimental".

Forbidden claims:

- "fully accessible" without matrix evidence;
- "WCAG compliant" without scope and audit evidence;
- "screen-reader compatible" without naming tested stacks;
- "APG compliant" if keyboard behavior diverges silently.

## Stop Rules

- Do not treat one screen reader as proof for all platforms.
- Do not hide interop gaps in release notes.
- Do not let screen reader workarounds leak into core platform-neutral API.
- Do not make accessibility evidence depend on Clean Disk private data.
