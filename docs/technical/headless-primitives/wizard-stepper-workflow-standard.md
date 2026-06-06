# Wizard Stepper Workflow Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `aria-current`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-current
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WCAG 3.3.1 Error Identification: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 3.3.4 Error Prevention: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html
- WAI-ARIA APG Tabs Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/tabs/
- WAI-ARIA APG Dialog Modal Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Scope

This standard covers wizards, steppers, guided workflows, multi-step forms,
cleanup review flows, permission repair flows, onboarding flows, and any
process where the user moves through ordered steps.

It does not require every stepper to use tab semantics. Tabs are for random
access panels. Wizards are process state machines.

## Decision Options

1. `WorkflowStepper` primitive with process state, current step, validation,
   and effect gates - 🎯 9   🛡️ 10   🧠 8, roughly 1000-2200 LOC.
   Best fit. It makes destructive and permission workflows explicit and
   testable.
2. Build steppers from tabs - 🎯 5   🛡️ 6   🧠 5, roughly 600-1200 LOC.
   Acceptable only for random access non-linear steps. Wrong for validated
   destructive workflows.
3. Let each feature hand-roll workflow screens - 🎯 4   🛡️ 5   🧠 5, roughly 500-1500 LOC per flow.
   Flexible, but inconsistent and risky for cleanup, permissions, and remote
   mode.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- workflow id;
- step ids;
- current step;
- completed, blocked, skipped, invalid, and pending states;
- step ordering;
- linear/non-linear policy;
- navigation commands;
- validation result contract;
- focus entry and restore;
- status announcement policy;
- dirty/data-loss guard;
- step indicator semantics;
- privacy class for step labels and summaries.

Renderer owns:

- horizontal/vertical stepper visuals;
- progress line;
- compact step list;
- icons and state colors;
- responsive placement;
- animation.

Application owns:

- validation rules;
- business side effects;
- delete plan creation;
- permission probe;
- route persistence;
- localized copy.

## Workflow State Model

Workflow states:

- idle;
- active;
- validating;
- blocked;
- committing;
- completed;
- failed;
- cancelled.

Step states:

- upcoming;
- current;
- complete;
- invalid;
- blocked;
- skipped;
- optional;
- stale.

Command states:

- back available;
- next available;
- next blocked with reason;
- commit available;
- cancel available;
- retry available.

## Stepper Semantics

Current step:

- use `aria-current="step"` where web adapter supports it;
- visible current marker cannot rely on color only;
- announce step position when useful: "Step 2 of 4".

Completed step:

- not the same as selected;
- may be clickable only in non-linear policy;
- must not imply submitted side effects unless commit happened.

Blocked step:

- exposes reason;
- not focusable as a command if activation cannot work;
- details available through validation summary.

Skipped step:

- only if workflow explicitly permits skipping;
- skip reason retained.

## Linear Versus Non-Linear

Linear workflow:

- next step requires current step validation;
- user may go back unless destructive side effect forbids it;
- future steps are not ordinary tabs.

Non-linear workflow:

- steps may be selected directly;
- unsaved step changes require guard;
- current step semantics still apply.

Commit workflow:

- final step creates a reviewed plan;
- side effect happens only on explicit commit;
- commit result produces receipt or failure state.

## Focus Rules

On step change:

- focus moves to step heading or first meaningful field;
- error summary may receive focus when validation fails;
- no focus jump for passive progress updates;
- back navigation restores logical previous focus where possible.

On validation failure:

- current step remains active;
- first invalid field or validation summary is reachable;
- announcement uses status or alert policy based on severity;
- field errors use validation standard.

On commit:

- focus moves to result summary;
- destructive result must be available beyond transient toast.

## Clean Disk Usage

Cleanup review:

- step 1: selected queue;
- step 2: daemon validation and identity recheck;
- step 3: final confirmation;
- step 4: receipt/result.

Permission repair:

- step 1: explain missing access;
- step 2: open platform settings or helper;
- step 3: re-probe;
- step 4: scan quality result.

Remote/headless destructive flow:

- default read-only;
- destructive authority must be a separate policy gate;
- stepper cannot bypass object-level authorization.

## Conformance Scenarios

- current step announced with position;
- linear flow blocks next and exposes reason;
- back button preserves prior step state;
- validation summary focuses correctly;
- final commit cannot run from stale step state;
- cleanup wizard generates validated plan before destructive action;
- result summary remains available after toast disappears;
- route restore does not restore destructive authority.

## Failure Catalog

- Stepper implemented as visual progress only with no current state.
- Future steps are focusable commands in a required linear flow.
- Validation failure changes step without explanation.
- Cleanup commit fires from "Next" button.
- Toast is the only proof of operation result.
- Current step label includes raw target path.
- Browser back skips validation and commits stale state.
