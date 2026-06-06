# Speech Synthesis Audio Output Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN Web Speech API: https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API
- MDN `speechSynthesis`: https://developer.mozilla.org/en-US/docs/Web/API/Window/speechSynthesis
- W3C Web Speech API specification: https://webaudio.github.io/web-speech-api/
- WCAG 1.4.2 Audio Control: https://www.w3.org/WAI/WCAG22/Understanding/audio-control.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- WCAG 2.2.2 Pause, Stop, Hide: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html
- Captions transcripts and status media standard: captions-transcripts-status-media-standard.md

## Problem

Text-to-speech output can be useful for optional read-aloud features, learning
support, kiosk guidance, and hands-free monitoring. It can also conflict with
screen readers, leak private content, ignore pronunciation and language, or
become an inaccessible audio-only status channel.

Headless needs a speech synthesis boundary. It should not become a custom screen
reader.

## Decision Options

1. Do not support speech synthesis in Headless - 🎯 6   🛡️ 8   🧠 1, about
   0-40 LOC. Safe for MVP, but weak for public extensibility.
2. Add optional speech output intent adapter - 🎯 8   🛡️ 9   🧠 6, about
   350-850 LOC. Best fit.
3. Build a full read-aloud and narration engine - 🎯 3   🛡️ 5   🧠 10, about
   2500-6000 LOC. Not a primitive-library responsibility.

Accepted: option 2.

## Accepted Contract

Headless emits speech intents:

```dart
final class RSpeechOutputIntent {
  final RSemanticId sourceId;
  final String localizedText;
  final String languageTag;
  final RSpeechPurpose purpose;
  final RSpeechPriority priority;
  final bool interruptsExistingSpeech;
  final bool containsSensitiveContent;
}
```

Speech adapters may map intents to Web Speech API, native TTS, or no-op.

## Rules

- Speech output is user-enabled or explicitly requested.
- Speech output does not replace ARIA live regions, status text, or Flutter
  semantics.
- Speech must be pausable, stoppable, or suppressible.
- Screen-reader users should not receive duplicated app speech by default.
- Sensitive paths, tokens, and delete targets are not spoken unless user
  explicitly requests full detail.
- Language tags are required for pronunciation.
- Repeated progress speech is throttled.
- Adapter failure does not hide visible status.

## Clean Disk Requirements

Clean Disk may later support optional read-aloud for:

- scan completion summary;
- warning explanation;
- permission repair steps;
- cleanup receipt summary;
- support diagnostics guidance.

It must not speak every scanned path, every selected row, or any daemon token.

## Speech Purposes

```text
readAloud:
  user asked to hear selected content

guidance:
  optional walkthrough or repair step

attention:
  user opted into spoken notifications

statusMirror:
  mirrors visible status, never the only status

screenReaderReplacement:
  prohibited for Headless baseline
```

## Testing Requirements

- Speech disabled profile emits no adapter call.
- Screen-reader active profile suppresses duplicate speech by default.
- Language tag is present.
- Sensitive content is redacted by default.
- Stop speech command is keyboard-accessible.
- Repeated status events are coalesced.

## Failure Catalog

- Web Speech API speaks over a screen reader.
- Scan progress speaks hundreds of messages.
- Delete target path is spoken from background notification.
- English voice pronounces localized text incorrectly because language is
  missing.
- Speech failure hides the visible status.
- Product claims screen-reader support because it has TTS.

## Release Gates

- Speech synthesis is adapter-gated and off by default.
- Every speech intent has purpose, language, and privacy class.
- Speech output never replaces semantic status.
- Clean Disk MVP ships without TTS unless explicitly designed.

## Summary

Speech synthesis is optional audio output. Headless should support it through
controlled intents, user preference, privacy redaction, and semantic fallbacks.
