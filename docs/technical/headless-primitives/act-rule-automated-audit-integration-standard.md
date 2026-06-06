# ACT Rule And Automated Audit Integration Standard

## Status

Accepted as a Headless conformance tooling standard. Not implemented yet.

## Source Standards

- WAI ACT Overview: https://www.w3.org/WAI/standards-guidelines/act/
- ACT Rules Format 1.1: https://www.w3.org/TR/act-rules-format/
- WCAG 2.2: https://www.w3.org/TR/wcag-22/
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing
- MDN ARIA reference: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles

## Scope

This standard defines how Headless uses automated, semi-automated, and manual
accessibility rules without pretending automation proves full accessibility.

It applies to:

- conformance harness rules;
- Flutter widget tests;
- web ARIA adapter linting;
- semantic snapshots;
- release evidence;
- community contribution checks.

It does not require Headless to implement the whole ACT ecosystem in MVP.

## Decision Options

Option A: Use ad hoc lint names - 🎯 4   🛡️ 4   🧠 3, about 200-500 LOC.

- Quick to write.
- Contributors cannot tell what rule means or what it proves.

Option B: Use third-party audit output directly - 🎯 6   🛡️ 5   🧠 4,
about 300-700 LOC.

- Useful for web adapter.
- Flutter native and behavior-level primitives still need custom rules.

Option C: ACT-shaped rule metadata with Headless-specific executors - 🎯 9
🛡️ 9   🧠 7, about 1000-2200 LOC.

- Accepted direction.
- Makes tests transparent, scoped, and reviewable.
- Supports automated, semi-automated, and manual evidence in one model.

## Accepted Direction

Headless should define `ConformanceRule`.

Rule metadata includes:

- stable rule id;
- requirement mapping;
- applicability;
- expectation;
- input aspect;
- test mode;
- assumptions;
- limitations;
- false-positive notes;
- false-negative notes;
- evidence output;
- remediation hint.

This mirrors ACT principles without locking Headless into browser-only tooling.

## Rule Modes

Modes:

- `automated`: no human judgment after fixture setup.
- `semiAutomated`: tool detects facts, reviewer decides result.
- `manual`: human verifies screen reader, keyboard, or visual behavior.
- `hybrid`: automated reducer plus manual AT check.

Only automated rules can block fast CI without review. Manual gates block
release milestones, not every local development loop.

## Input Aspects

Aspects:

- Flutter semantics tree;
- web accessibility tree;
- DOM/ARIA projection;
- reducer state trace;
- keyboard event trace;
- focus trace;
- visual snapshot;
- AT transcript;
- adapter capability matrix.

Each rule declares which aspects it consumes.

## Rule Examples

Examples:

- TreeGrid root has a name and row/column metadata where adapter supports it.
- Dialog has a title, modal scope, initial focus, and focus return target.
- Icon button has a name and does not rely on tooltip text only.
- Progress update exposes status without stealing focus.
- Disabled command is not reachable through command registry.
- Delete action requires current validated plan state.

## Automation Limits

Automated audits cannot prove:

- real screen reader phrase quality;
- user understanding;
- all keyboard workflows;
- focus not obscured under every viewport;
- destructive safety comprehension;
- chart usefulness.

Headless docs must label automation as evidence, not as proof of usability.

## Clean Disk Requirements

Clean Disk should use ACT-shaped rules for:

- TreeTable accessibility snapshot;
- delete confirmation flow;
- cleanup queue command safety;
- disk usage map accessible table projection;
- search/filter/sort label and result count behavior;
- progress/status announcement policy.

MVP rule:

- scan-only can use automated plus manual smoke;
- cleanup beta requires manual destructive-flow evidence.

## API Shape Sketch

```text
ConformanceRule
  id
  requirementRefs
  applicability
  expectations
  mode
  inputAspects
  assumptions
  limitations
  evidenceSchema
  remediation
```

## Conformance Scenarios

Required scenarios:

- rule output cites WCAG/APG/Headless requirement;
- rule says automated or manual explicitly;
- inapplicable rule records why;
- false-positive suppression requires waiver id;
- semantic snapshot rule does not inspect raw user paths;
- release report distinguishes automated pass from manual pass.

## Failure Catalog

Failures:

- green automated report used as full accessibility claim;
- rule has no requirement mapping;
- rule assumes DOM for native Flutter adapter;
- suppression has no expiry;
- screenshot diff passes while semantic role is missing;
- manual rule silently skipped in release pipeline.

## Release Gates

Release gate:

- every critical primitive has at least one rule pack;
- every rule pack has automated and manual boundaries;
- suppressions link to accessibility exception register;
- CI artifacts are privacy-safe;
- public docs explain what the rule pack does not prove.

