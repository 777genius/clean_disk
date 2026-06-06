# Untrusted Content Rendering And Sanitization Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN Cross-site scripting: https://developer.mozilla.org/en-US/docs/Web/Security/Attacks/XSS
- MDN HTML Sanitizer API: https://developer.mozilla.org/en-US/docs/Web/API/HTML_Sanitizer_API
- MDN Using the HTML Sanitizer API: https://developer.mozilla.org/en-US/docs/Web/API/HTML_Sanitizer_API/Using_the_HTML_Sanitizer_API
- MDN `Node.textContent`: https://developer.mozilla.org/en-US/docs/Web/API/Node/textContent
- MDN Trusted Types API: https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API
- WCAG 1.1.1 Non-text Content: https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html

## Scope

This standard defines how Headless primitives render untrusted text, rich
content, filenames, paths, logs, markdown-like content, HTML-like content, and
diagnostic messages.

It applies to:

- table cells;
- tree node labels;
- search results;
- logs;
- toasts;
- details inspectors;
- command labels;
- tooltips;
- export previews;
- documentation panels;
- custom renderer slots.

It does not make Headless a sanitizer library. It defines trust classes and
safe rendering sinks.

## Decision Options

Option A: Trust all strings from app code - 🎯 3   🛡️ 3   🧠 2, about
50-150 LOC.

- Very simple.
- Unsafe for filenames, logs, remote data, extension output, and docs.

Option B: Escape everything as plain text - 🎯 7   🛡️ 8   🧠 3, about
200-400 LOC.

- Safe default.
- Too limiting for rich documentation, highlighted search results, and
  structured logs.

Option C: Content trust classes plus renderer sinks - 🎯 9   🛡️ 9   🧠 7,
about 800-1600 LOC.

- Accepted direction.
- Plain text is default.
- Rich content requires explicit trusted or sanitized pipeline.
- Renderer slots declare safe sinks.

## Accepted Direction

Headless must classify content before rendering.

Trust classes:

- `plainText`;
- `localizedMessage`;
- `userProvidedText`;
- `filesystemName`;
- `filesystemPath`;
- `searchQuery`;
- `logLine`;
- `trustedRichText`;
- `sanitizedRichText`;
- `unsafeRichText`;
- `secret`.

Default rule:

- render as plain text unless trust class explicitly allows structured rich
  rendering.

## Safe Sink Rules

Renderer adapters must expose safe sinks:

- plain text sink;
- localized text sink;
- rich text fragment sink;
- icon or image alt text sink;
- code or monospace text sink;
- diagnostic details sink.

Web DOM adapter:

- prefer text nodes or `textContent` for plain text;
- do not use `innerHTML` for untrusted content;
- sanitized HTML must pass through app-approved sanitizer;
- Trusted Types can be used by app adapter;
- renderer must not concatenate HTML strings from slots.

Flutter adapter:

- use `Text`, `RichText`, or explicit span builders;
- do not parse HTML in primitive renderer unless adapter declares sanitizer;
- avoid treating log text as widget markup;
- file names and paths are text, not rich content.

## Rich Content Rules

Rich content must declare:

- allowed elements or spans;
- allowed attributes;
- link policy;
- image policy;
- code block policy;
- keyboard focus policy;
- accessible name policy;
- privacy class.

If any of this is unknown, downgrade to plain text or block rendering.

## Filenames And Paths

Filenames and paths are untrusted display content.

Rules:

- display as text;
- preserve bidi isolation where needed;
- handle control characters;
- handle extremely long segments;
- avoid interpreting file extension as markup;
- avoid using raw path as DOM id, analytics id, route id, or test id;
- redact based on privacy policy.

Clean Disk must assume scanned file and folder names are arbitrary.

## Search Highlighting

Search highlighting must not build unsafe markup.

Rules:

- compute ranges over text;
- render as spans;
- preserve original text;
- support bidi and grapheme boundaries;
- do not log raw query;
- do not expose query through element id or telemetry.

## Logs And Diagnostics

Logs can contain hostile or sensitive text.

Rules:

- display as text;
- classify and redact fields;
- avoid auto-linking raw content by default;
- avoid executing ANSI escape sequences as styling unless parser is safe;
- limit line length;
- support copy with privacy policy.

## Clean Disk Requirements

Clean Disk must use this standard for:

- file names;
- folder paths;
- daemon error messages;
- pdu adapter diagnostics;
- support bundle previews;
- cleanup receipts;
- export previews;
- search highlights.

Rules:

- raw path is not a stable id;
- raw path is not a safe HTML fragment;
- daemon error detail is not localized message identity;
- support bundle preview redacts by default.

## API Shape Sketch

```text
ContentValue
  text
  trustClass
  privacyClass
  locale
  bidiPolicy
  maxDisplayLength

SafeContentRenderer
  renderText(value)
  renderRich(value, sanitizerPolicy)
  renderHighlighted(value, ranges)
```

## Conformance Scenarios

- filename containing `<script>` renders as text;
- search highlight does not use raw HTML;
- long path truncates visually but full text remains accessible if policy
  allows;
- RTL path segment is isolated;
- log line with ANSI escape does not execute as formatting unless safe parser
  is enabled;
- unsafe rich text downgrades or blocks;
- raw path is not used as element id;
- support preview redacts sensitive fields.

## Failure Catalog

- using `innerHTML` for filenames;
- treating daemon log as trusted markdown;
- localized message key built from raw error text;
- raw path used as test id;
- auto-linking sensitive paths;
- sanitizer owned by visual renderer instead of adapter policy;
- search highlight breaks grapheme clusters;
- rich text link has no safe target policy;
- support export preview leaks secrets;
- hiding dangerous content instead of showing safe redacted state.

