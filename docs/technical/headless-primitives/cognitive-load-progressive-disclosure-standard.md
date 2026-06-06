# Cognitive Load And Progressive Disclosure Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- WAI-Adapt Overview: https://www.w3.org/WAI/adapt/
- WAI-Adapt Explainer: https://www.w3.org/TR/adapt/
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WCAG 3.1.5 Reading Level: https://www.w3.org/WAI/WCAG21/Understanding/reading-level.html
- WCAG 3.2.4 Consistent Identification: https://www.w3.org/WAI/WCAG22/Understanding/consistent-identification.html
- WCAG 3.2.6 Consistent Help: https://www.w3.org/WAI/WCAG22/Understanding/consistent-help.html
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html
- WCAG 3.3.7 Redundant Entry: https://www.w3.org/WAI/WCAG22/Understanding/redundant-entry.html

## Scope

This standard defines how Headless primitives support clear, consistent, and
progressively disclosed interfaces without burying critical state.

It applies to:

- complex tables;
- cleanup workflows;
- wizards;
- settings;
- details inspectors;
- error recovery;
- help surfaces;
- command discovery;
- first-run and permission repair flows.

It does not write product copy. It defines semantic slots and behavior for
clarity, help, and progressive disclosure.

## Decision Options

Option A: App copy and layout only - 🎯 5   🛡️ 5   🧠 2, about 100-300 LOC.

- Leaves flexibility to app teams.
- Public primitives still need consistent help, labels, and disclosure
  behavior.

Option B: Opinionated onboarding components - 🎯 5   🛡️ 6   🧠 5, about
600-1400 LOC.

- Useful for one design system.
- Too product-specific for Headless.

Option C: Cognitive support contracts and progressive disclosure slots -
🎯 9   🛡️ 8   🧠 7, about 900-1800 LOC.

- Accepted direction.
- Components expose consistent labels, summaries, help slots, and detail
  levels.
- Product copy stays app-owned.

## Accepted Direction

Headless must define cognitive support contracts:

- short label;
- descriptive label;
- summary;
- details;
- help action;
- risk explanation;
- next step;
- consistent icon intent;
- disclosure level;
- redundancy avoidance.

## Disclosure Levels

Levels:

- `minimal`: core command or state only.
- `summary`: short explanation or count.
- `detailed`: technical or policy details.
- `expert`: raw-ish diagnostics with privacy rules.
- `support`: structured facts for help or export.

Users and apps can choose defaults, but critical safety state must not be
hidden only in expert level.

## Consistency Rules

Consistent identification means:

- same command id has same purpose;
- same icon intent means same action family;
- same risk class uses same language pattern;
- same repair action appears in a predictable location;
- destructive confirmation structure is stable.

Labels can be localized, but purpose must stay consistent.

## Redundant Entry Rules

Headless workflows should avoid asking users to re-enter data:

- preserve scan target through permission repair;
- preserve export options through recoverable error;
- preserve filter query through retry;
- preserve wizard choices when moving back and forward;
- avoid duplicate confirmation fields unless safety policy justifies them.

For destructive actions, repeated confirmation may be justified only when the
action risk requires it and the requirement is explicit.

## Help Slot Rules

Help slot includes:

- help command id;
- summary text key;
- repair command id;
- docs link key;
- support export command id;
- privacy note slot;
- consistent placement hint.

Headless owns the slot. App owns content and destination.

## Clean Disk Requirements

Clean Disk needs cognitive support for:

- scan target selection;
- Full Disk Access repair;
- skipped item explanation;
- reclaim estimate confidence;
- cleanup queue;
- delete plan validation;
- Trash restore limits;
- remote read-only mode;
- support bundle export.

Rules:

- largest folders table stays dense but not cryptic;
- delete workflow shows risk and next step without wall of text;
- expert details exist but do not replace plain summary;
- repair flows preserve user choices.

## API Shape Sketch

```text
CognitiveSupport
  shortLabelKey
  descriptiveLabelKey
  summaryKey
  detailKey
  helpAction
  riskClass
  disclosureLevel
  consistencyGroup
  redundantEntryPolicy
```

## Conformance Scenarios

- same delete command uses same label pattern across menu and dialog;
- permission repair flow preserves chosen target;
- advanced diagnostic details are collapsed but discoverable;
- destructive confirmation shows plain summary and expert details;
- help action appears in consistent location;
- icon-only button has stable accessible name;
- recoverable export error preserves chosen format;
- text can be localized without changing command identity.

## Failure Catalog

- same icon means different actions in different screens;
- help appears unpredictably;
- dense UI hides critical safety state;
- repair flow loses user input;
- expert diagnostic text is only explanation;
- repeated confirmation used as substitute for clear risk model;
- localized labels used as command identity;
- detail disclosure hides error recovery;
- first-run instruction becomes permanent clutter;
- support link bypasses privacy policy.

