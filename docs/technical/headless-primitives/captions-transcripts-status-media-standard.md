# Captions Transcripts And Status Media Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WCAG 1.2.1 Audio-only and Video-only: https://www.w3.org/WAI/WCAG22/Understanding/audio-only-and-video-only-prerecorded.html
- WCAG 1.2.2 Captions: https://www.w3.org/WAI/WCAG22/Understanding/captions-prerecorded.html
- WCAG 1.2.3 Audio Description or Media Alternative: https://www.w3.org/WAI/WCAG22/Understanding/audio-description-or-media-alternative-prerecorded.html
- WCAG 1.4.2 Audio Control: https://www.w3.org/WAI/WCAG22/Understanding/audio-control.html
- WCAG 2.2.2 Pause, Stop, Hide: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- MDN `<track>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Element/track

## Problem

Headless is mostly component logic, but modern products still use sounds,
animations, onboarding videos, progress tones, media previews, and notification
feedback. If a primitive allows meaningful information to be carried only by
audio, animation, or transient media, users who cannot hear or process that
media lose workflow state.

Headless needs a media and status alternative contract even if most primitives
do not render media directly.

## Decision Options

1. Treat media alternatives as app content responsibility - 🎯 5   🛡️ 5
   🧠 2, about 0-80 LOC. Reasonable for content sites, weak for UI primitives.
2. Add media alternative hooks for status, notification, and embedded media -
   🎯 8   🛡️ 9   🧠 5, about 250-650 LOC. Best baseline for Headless.
3. Build full media player primitives - 🎯 4   🛡️ 7   🧠 9, about
   2000-4500 LOC. Useful later, not needed for Clean Disk MVP.

Accepted: option 2.

## Accepted Contract

Primitives that emit non-text media also emit text alternatives:

```dart
final class RMediaAlternative {
  final RSemanticId mediaId;
  final RMediaKind kind;
  final String? textSummary;
  final Uri? transcriptUri;
  final Uri? captionsUri;
  final bool hasMeaningfulAudio;
  final bool hasMeaningfulVisualOnlyChange;
  final bool userCanPause;
  final bool userCanMute;
}
```

Status primitives expose text status independent of sound or animation.

## Rules

- Audio notifications have visible status alternatives.
- Animation-only changes have semantic or textual alternatives.
- Onboarding or help videos require captions or transcript policy.
- Auto-playing audio can be paused or muted.
- Progress tones never replace progress text.
- Error sounds never replace visible errors.
- Reduced motion and reduced data settings may suppress media without removing
  status.

## Clean Disk Requirements

Clean Disk should not need media for MVP, but the contract applies to:

- scan completion sounds if added;
- error sounds;
- onboarding clips;
- animated empty states;
- visual-only treemap transitions;
- progress animations;
- support diagnostics recordings.

Every scan, error, warning, and cleanup outcome must be visible as text and
available to status semantics.

## Status Media Boundary

Notification primitives classify feedback:

```text
required state:
  must have text and semantic status

optional emphasis:
  may use sound, motion, color, icon, or haptic feedback

decorative media:
  hidden from semantics unless user asks for description
```

Only required state affects workflow correctness.

## Testing Requirements

- Disable audio and verify workflow state remains visible.
- Enable reduced motion and verify state is still announced or displayed.
- Disable media loading and verify fallback text.
- Verify captions or transcript metadata for media-bearing primitives.
- Verify status messages do not rely only on toast timing.
- Verify decorative media is not over-announced.

## Failure Catalog

- Scan completion is signaled only by sound.
- Error details are visible only inside an animation.
- Onboarding video has no transcript.
- Progress animation pauses under reduced motion and no text progress remains.
- A warning icon changes color with no text.
- Captions file exists but is not discoverable by the primitive contract.

## Release Gates

- Any primitive with meaningful media needs a media alternative record.
- Status primitives must work with audio, animation, and haptics disabled.
- Public examples with media must include captions or transcript hooks.
- Diagnostics must classify media as required state, optional emphasis, or
  decorative.

## Summary

Headless should treat audio, animation, and media as optional carriers. Workflow
truth lives in text, semantics, and explicit status contracts.
