# Assistive Technology Transcript Correlation Standard

## Status

Accepted as a Headless manual evidence standard. Not implemented yet.

## Source Standards

- ARIA-AT: https://w3c.github.io/aria-at/
- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- MDN ARIA live regions: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/ARIA_Live_Regions
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Scope

This standard defines how Headless correlates expected semantic events with
screen reader, speech viewer, braille viewer, or manual assistive technology
transcripts.

It applies to:

- screen reader lab testing;
- release evidence;
- manual regression tests;
- live announcement behavior;
- dialog and TreeGrid workflows.

It does not make exact spoken phrasing normative. It records whether the user
can perceive and operate the workflow.

## Decision Options

Option A: Assert expected speech text exactly - 🎯 3   🛡️ 3   🧠 3,
about 300-700 LOC.

- Easy to diff.
- Breaks across screen reader versions, verbosity settings, and locales.

Option B: Store freeform manual notes - 🎯 5   🛡️ 5   🧠 2, about
100-300 LOC.

- Useful for humans.
- Hard to compare over time.

Option C: Correlate transcript tokens to semantic expectations - 🎯 9
🛡️ 8   🧠 7, about 900-1800 LOC.

- Accepted direction.
- Stable enough for regression.
- Flexible across AT, verbosity, and language.

## Accepted Direction

Headless should define `AssistiveTechnologyTranscriptRecord`.

Record fields:

- scenario id;
- stack id;
- primitive id;
- expected semantic events;
- observed transcript tokens;
- missing facts;
- extra noise;
- interruption events;
- reviewer verdict;
- privacy redaction;
- evidence attachment refs.

## Expected Fact Model

Expected facts:

- role family;
- accessible name;
- state change;
- value change;
- focus movement;
- announcement kind;
- action availability;
- collection position;
- error status;
- confirmation requirement.

Facts are semantic. They are not exact phrases.

## Transcript Token Classes

Token classes:

- role token;
- name token;
- state token;
- value token;
- position token;
- instruction token;
- warning token;
- noise token;
- missing token;
- privacy-redacted token.

Example:

```text
Expected: role=dialog, name=Move to Trash, state=modal
Observed: "Move to Trash dialog"
Verdict: pass
```

## Noise Policy

Noise matters when it blocks task completion.

Examples:

- duplicate alerts are a failure if they interrupt repeated progress updates;
- extra role phrase is acceptable if workflow remains understandable;
- stale status after new selection is a failure;
- sensitive path in spoken output is a privacy failure.

## Clean Disk Requirements

Clean Disk needs transcript correlation for:

- scan started and completed;
- permission degraded status;
- TreeTable row expansion and selection;
- add to cleanup queue;
- delete plan blocked as stale;
- move to Trash confirmation;
- cleanup result and partial failure.

Raw file paths should be redacted unless the scenario explicitly uses synthetic
fixtures.

## API Shape Sketch

```text
AssistiveTechnologyTranscriptRecord
  scenarioId
  stackId
  expectedFacts
  observedTokens
  missingFacts
  noiseFindings
  privacyFindings
  verdict
  reviewer
```

## Conformance Scenarios

Required scenarios:

- exact phrase changes do not fail if all facts are present;
- missing destructive warning fails;
- duplicate progress announcements fail noise threshold;
- localized transcript maps to semantic token classes;
- redacted path remains correlated by stable placeholder;
- reviewer can link record to scenario script and stack policy.

## Failure Catalog

Failures:

- exact speech string treated as public API;
- transcript stored with private user paths;
- reviewer notes cannot be mapped to scenario;
- noisy announcements marked pass because semantics snapshot looked correct;
- missing action availability hidden by visual success;
- braille output ignored when relevant.

## Release Gates

Release gate:

- critical workflows have transcript records for claimed stacks;
- transcript records use synthetic data or redaction;
- failures link to triage or waiver;
- exact phrasing is never the only pass criterion;
- known AT noise is public if users will encounter it.

