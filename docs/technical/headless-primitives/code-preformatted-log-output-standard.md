# Code Preformatted And Log Output Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN `pre`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/pre
- MDN `code`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/code
- MDN `kbd`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/kbd
- MDN `samp`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/samp
- MDN `var`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/var
- MDN `output`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/output
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 1.4.12 Text Spacing: https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html

## Problem

Code blocks, command examples, keyboard input, daemon logs, JSON payloads, stack
traces, terminal output, and generated support snippets are common in developer
tools. They often break accessibility when rendered as decorative monospace
text, giant focus traps, unredacted path dumps, or non-copyable screenshots.

Headless needs a semantic technical-output contract.

## Decision Options

1. Use plain `Text` with monospace style - 🎯 3   🛡️ 3   🧠 1, about
   20-80 LOC. Good visual result, weak semantics and privacy.
2. Add semantic technical output primitives - 🎯 9   🛡️ 9   🧠 6, about
   500-1200 LOC. Best fit.
3. Embed a full terminal emulator - 🎯 4   🛡️ 6   🧠 10, about
   2500-8000 LOC. Useful later, not a Headless core default.

Accepted: option 2.

## Accepted Contract

Headless models technical output by purpose:

```dart
final class RTechnicalOutputModel {
  final RTechnicalOutputKind kind;
  final List<RTechnicalLine> lines;
  final RCopyPolicy copyPolicy;
  final RRedactionPolicy redactionPolicy;
  final RWrapPolicy wrapPolicy;
  final RLanguageHint? languageHint;
  final bool selectable;
  final bool virtualized;
}
```

The product decides source content, redaction, retention, and copyability.
Headless owns rendering behavior, selection, navigation, and semantics.

## Output Kinds

```text
code:
  source code, JSON, config, schema, examples

keyboardInput:
  key sequence or command the user should type

sampleOutput:
  terminal, daemon, compiler, or scanner output

log:
  timestamped diagnostic lines

stackTrace:
  structured failure stack

diff:
  before and after text
```

## Semantic Mapping

For web adapters:

- `pre` preserves intended whitespace for blocks.
- `code` marks source or machine text.
- `kbd` marks keyboard input.
- `samp` marks sample program or command output.
- `var` marks placeholders or variables.
- `output` marks generated result values when tied to command or form state.

Flutter adapters need equivalent semantics, copy controls, and line navigation.

## Rules

- Never render logs as images.
- Never expose unredacted logs by default.
- Long output should be virtualized or collapsed.
- Copy command must respect redaction and scope.
- Line numbers are optional UI, not content identity.
- Search within output is a separate query contract.
- Syntax highlighting is decorative unless semantic tokens are exposed.
- Wrapped lines must not change copy value.
- Keyboard snippets must distinguish literal keys from command text.
- Placeholders should be marked as variables, not copied accidentally.

## Clean Disk Requirements

Clean Disk technical output appears in:

- daemon diagnostics;
- support bundles;
- failed scan details;
- cleanup receipt details;
- command adapter dry-run output;
- JSON export previews;
- debug-only protocol inspector;
- crash and recovery report UI.

Production UI must prefer user-facing summaries. Raw logs are opt-in,
redacted, and scoped.

## Redaction Classes

```text
safe:
  public code or generic example

supportSafe:
  reviewed diagnostic fields

pathBearing:
  may include paths or filenames

secretBearing:
  may include token, auth, credential, environment value

destructive:
  includes commands that can mutate state
```

## Accessibility Rules

- Blocks have an accessible label describing purpose and size.
- Keyboard focus can enter and leave large output predictably.
- Copy, search, wrap, and expand controls are keyboard reachable.
- Screen-reader users can navigate by line without hearing thousands of lines
  unintentionally.
- Status updates are announced outside the log scroller.
- Color is not the only signal for severity.

## Performance Rules

- Large logs use bounded line windows.
- Appending output preserves user scroll position unless following tail.
- Syntax highlighting is incremental or disabled for large blocks.
- Redaction runs before output reaches renderer diagnostics.
- Support export uses raw structured facts plus rendered text, not only UI copy.

## Testing Requirements

- Copy command returns redacted output.
- Long log does not freeze UI.
- Wrapped command copies original command.
- Keyboard-only user can reach and leave log area.
- Screen reader announces block label and line count.
- Path-bearing fixture does not leak in snapshots.
- Syntax highlighter failure falls back to plain text.

## Failure Catalog

- Log view traps focus.
- Stack trace appears only as screenshot.
- Copy includes secret token.
- Wrapped path copies with inserted spaces.
- Screen reader reads 10,000 log lines on focus.
- Placeholder `<path>` is copied as a real command argument.
- Color-only log severity.

## Release Gates

- Every technical output surface has kind, copy policy, and redaction policy.
- Large outputs have virtualization or collapse.
- Support-safe copy is tested.
- Clean Disk production logs avoid raw paths and tokens by default.
- Destructive command examples require explicit dry-run or warning context.

## Summary

Technical output needs semantic purpose, bounded rendering, copy policy, and
redaction. Headless should support code, keyboard input, sample output, logs,
stack traces, and diffs without becoming a terminal emulator by default.
