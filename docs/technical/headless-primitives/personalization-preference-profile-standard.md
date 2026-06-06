# Personalization Preference Profile Standard

## Status

Accepted as a Headless assurance standard. Not implemented yet.

## Source Standards

- WAI-Adapt Overview: https://www.w3.org/WAI/adapt/
- WAI-Adapt Explainer: https://www.w3.org/TR/adapt/
- MDN media queries for accessibility: https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Media_queries/Using_for_accessibility
- MDN `prefers-reduced-motion`: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion
- MDN `prefers-contrast`: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-contrast
- WCAG 3.2.4 Consistent Identification: https://www.w3.org/WAI/WCAG22/Understanding/consistent-identification.html
- WCAG 3.2.6 Consistent Help: https://www.w3.org/WAI/WCAG22/Understanding/consistent-help.html

## Scope

This standard defines how Headless represents user preferences and
personalization needs across primitives.

It applies to:

- reduced motion;
- contrast;
- density;
- text scale;
- help visibility;
- verbosity;
- icon plus text preference;
- confirmation strictness;
- keyboard model preferences;
- content simplification;
- table detail level.

It does not replace OS or browser settings. It merges system, app, and user
preferences through a safe profile.

## Decision Options

Option A: Individual boolean flags per component - 🎯 4   🛡️ 4   🧠 2,
about 150-400 LOC.

- Easy for first controls.
- Inconsistent across component families.

Option B: App-only preference model - 🎯 6   🛡️ 6   🧠 4, about
400-1000 LOC.

- Works in Clean Disk.
- Not enough for public Headless renderers and third-party primitives.

Option C: Headless personalization profile with scoped overrides - 🎯 9
🛡️ 9   🧠 7, about 1000-2000 LOC.

- Accepted direction.
- All primitives consume the same preference facts.
- System preferences and app overrides are separated.

## Accepted Direction

Headless should define a `PersonalizationProfile`.

Profile includes:

- source;
- scope;
- motion preference;
- contrast preference;
- density preference;
- text scale bucket;
- verbosity preference;
- help preference;
- interaction preference;
- cognitive support preference;
- persistence policy;
- privacy class.

## Preference Sources

Sources:

- operating system;
- browser media query;
- app setting;
- route override;
- component override;
- enterprise policy;
- test fixture;
- unknown.

Resolution order must be deterministic and explainable.

## Preference Categories

Categories:

- `motion`: normal, reduced, instant.
- `contrast`: normal, more, forced, custom.
- `density`: comfortable, regular, compact, dataDense.
- `verbosity`: minimal, normal, detailed, expert.
- `help`: hidden, contextual, alwaysVisible.
- `labels`: iconOnlyAllowed, preferText, alwaysText.
- `confirmation`: standard, strict, guided.
- `keyboard`: platform, vimLike, custom, unknown.

Not every category applies to every primitive.

## Conflict Rules

Conflicts resolve by safety:

- user accessibility preference beats visual density;
- destructive confirmation policy beats simplified mode;
- forced colors beats brand palette;
- text scale beats fixed row height;
- enterprise policy can block risky features but not remove required
  accessibility affordances.

## Clean Disk Requirements

Clean Disk profile uses:

- compact data table density;
- high contrast state;
- reduced motion;
- expert details disclosure;
- guided cleanup confirmation;
- always-visible help for permission repair;
- text labels for destructive actions in compact layout when needed.

Rules:

- simplified UI does not hide cleanup risk.
- expert mode does not bypass confirmation.
- density preference cannot reduce target safety below policy.

## API Shape Sketch

```text
PersonalizationProfile
  id
  source
  scope
  motion
  contrast
  density
  verbosity
  help
  labels
  confirmation
  privacyClass

PreferenceResolver
  resolve(context)
  explain(key)
```

## Conformance Scenarios

- reduced motion applies to TreeGrid and dialogs consistently;
- high contrast does not lose selected row state;
- always-text preference expands icon buttons where space allows;
- guided confirmation shows extra step but preserves safety;
- expert mode shows details without changing command authority;
- test fixture can force profile without persisting it;
- source conflict explains winning preference;
- profile does not store sensitive user content.

## Failure Catalog

- each component invents separate reduced-motion flag;
- compact density overrides target safety;
- expert mode bypasses destructive confirmation;
- simplified mode hides warning;
- browser preference ignored by renderer;
- enterprise policy removes accessibility help;
- preference source cannot be explained;
- app stores profile with raw scan data;
- icon-only controls remain icon-only under preferText;
- profile change causes focus loss.

