# Locale Unit And Quantity Formatting Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN Internationalization guide: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Internationalization
- MDN `Intl.NumberFormat`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat
- MDN `Intl.PluralRules`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/PluralRules
- MDN `Intl.DateTimeFormat`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat
- Unicode CLDR: https://cldr.unicode.org/
- WCAG 3.1.1 Language of Page: https://www.w3.org/WAI/WCAG22/Understanding/language-of-page.html
- WCAG 3.1.2 Language of Parts: https://www.w3.org/WAI/WCAG22/Understanding/language-of-parts.html

## Scope

This standard defines how Headless primitives handle locale-aware display of
numbers, units, byte sizes, dates, durations, percentages, counts, plural
messages, sort labels, and accessible value text.

It applies to:

- table cells;
- metric cards;
- progress bars;
- charts and legends;
- details panels;
- export projections;
- announcement messages;
- command labels with counts;
- validation and status text.

It does not own application translation files. It owns formatting contracts and
separation between raw values and display strings.

## Decision Options

Option A: Preformatted strings everywhere - 🎯 3   🛡️ 3   🧠 2, about
100-250 LOC.

- Easy for widgets.
- Loses sorting, accessibility value semantics, export precision, and locale
  consistency.

Option B: App formatting helpers only - 🎯 6   🛡️ 6   🧠 4, about
300-700 LOC.

- Works for one product.
- Public Headless components cannot reason about value semantics.

Option C: Typed quantity model plus locale formatting adapter - 🎯 9
🛡️ 9   🧠 7, about 900-1800 LOC.

- Accepted direction.
- Headless receives raw typed values and formatting policy.
- Renderer displays localized text but keeps raw values available for sorting,
  accessibility, export, and testing.

## Accepted Direction

Headless must not treat user-visible formatted text as data identity.

Primitives should receive typed quantities:

- number;
- integer count;
- bytes;
- percentage;
- duration;
- timestamp;
- relative time;
- rate;
- ratio;
- ordinal;
- localized message arguments.

Formatting happens through a `LocaleFormatAdapter`.

## Quantity Shape

Each quantity should include:

- raw value;
- unit kind;
- exactness;
- rounding policy;
- display precision;
- accessible precision;
- sort value;
- privacy class;
- locale override if required;
- fallback string key.

Example:

- raw bytes: `41570752512`
- display: `38.7 GB`
- accessible: `38.7 gigabytes, 41,570,752,512 bytes`
- sort: raw bytes
- export: raw bytes plus formatted string

## Byte Size Rules

Disk usage apps must distinguish:

- decimal units: KB, MB, GB, TB;
- binary units: KiB, MiB, GiB, TiB;
- logical size;
- allocated size;
- exclusive reclaim estimate;
- approximate value;
- exact byte count.

Headless must not decide filesystem accounting truth. It only displays
quantity facts from application or domain models.

Clean Disk default display can use decimal GB for user readability, but details
and exports should preserve exact bytes.

## Rounding Rules

Rounding policy must be explicit:

- `exact`;
- `rounded`;
- `floor`;
- `ceil`;
- `bucket`;
- `lessThan`;
- `greaterThan`;
- `approximate`.

Do not show rounded values as exact reclaim authority.

If `38.7 GB` is displayed, exact bytes can be available in details or tooltip
where policy allows.

## Plural And Message Rules

Counts must not concatenate strings manually.

The formatting adapter must support:

- plural categories;
- count formatting;
- unit display width;
- gender or grammatical context if locale requires it;
- bidi isolation for inserted file names or paths;
- fallback when locale data is missing.

Clean Disk examples:

- `1 file`;
- `2 files`;
- localized equivalents;
- `17 skipped items`;
- `2 folders selected`.

## Date And Time Rules

Date/time display must separate:

- absolute timestamp;
- relative time;
- duration;
- elapsed time;
- estimated remaining time;
- filesystem modified time;
- operation receipt time.

Rules:

- receipts should include absolute timestamp;
- progress footer may show elapsed duration;
- relative time is helpful but not authoritative;
- exports should include stable machine-readable timestamp.

## Accessible Value Text

Visual compact values may be ambiguous.

Accessible text should expand:

- units;
- approximations;
- exact bytes when useful;
- percent context;
- range min and max;
- sort direction;
- warning qualifiers.

Example:

- visual: `1.24 GB/s`
- accessible: `throughput 1.24 gigabytes per second`

## Clean Disk Requirements

Clean Disk must use typed quantities for:

- folder size;
- total scanned;
- cleanup candidates;
- skipped bytes;
- reclaim estimates;
- file and folder counts;
- scan throughput;
- elapsed time;
- modified time;
- percentages;
- chart segments;
- export and receipt quantities.

Delete safety rule:

- displayed rounded size is never the authoritative cleanup amount.

## API Shape Sketch

```text
Quantity
  kind
  rawValue
  unit
  exactness
  rounding
  displayPrecision
  sortValue
  privacyClass

LocaleFormatAdapter
  formatQuantity(quantity, context)
  formatMessage(key, args)
  formatAccessibleValue(quantity, context)
```

## Conformance Scenarios

- table sorts by raw bytes, not localized text;
- export includes exact raw value and localized display;
- percentage announces context;
- plural messages use locale rules;
- text direction isolates inserted paths;
- rounded reclaim size is labeled approximate;
- missing locale falls back without crashing;
- modified time and receipt time use different policies.

## Failure Catalog

- sorting `100 MB` before `9 GB` as text;
- concatenating number plus English unit;
- treating `GB` and `GiB` as interchangeable;
- showing rounded delete size as exact;
- path inserted into RTL text without isolation;
- chart legend value not localized;
- screen reader reads `GB/s` unclearly;
- export loses raw bytes;
- relative time used as receipt authority;
- localization package imported into domain models.

