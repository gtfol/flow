# Asset provenance

All bundled experience content was produced specifically for flow. No music, recordings, artwork, scripts, or branding were copied from Othership. The introduction uses a generated ElevenLabs recording, described below.

| Asset | Origin | Reproduce |
| --- | --- | --- |
| `ambient.wav` | Original additive synthesis: quiet sine partials at 110, 165, 220, 275, and 330 Hz, slow level variation, stereo offsets, 1.2-second endpoint fades. 60 seconds, 24 kHz stereo, 16-bit PCM. Repeats without a fast beat or escalating intensity. | `python3 scripts/synthesize_audio.py` |
| `inhale.wav` | Original 440 Hz / 660 Hz tone with smooth attack and decay; 0.8 seconds. | Same script |
| `exhale.wav` | Original 330 Hz / 495 Hz tone with smooth attack and decay; 0.8 seconds. | Same script |
| `introduction.mp3` — **introduction · elevenlabs.io** | Original flow script, generated with ElevenLabs' included **Sarah – Mature, Reassuring, Confident** voice and **Eleven v4** on October 1, 2026. Selected by the app owner after audition. 27.6375 seconds, 44.1 kHz mono, MP3. | Generation prompt below; model output is nondeterministic. |
| Session card artwork | Original SwiftUI gradients and Bézier line studies in `FlowStyle.swift`. Native vector rendering, no bitmap source. | Build the app |
| Player visual | Original concentric circles and radial gradients in SwiftUI. Natural mode is stationary. | Build the app |
| App icon | Five original concentric sage rings, an open center, and a dark radial gradient; rendered with AppKit/Core Graphics at 1024 × 1024. | `swift scripts/make_icon.swift Flow/Resources/Assets.xcassets/AppIcon.appiconset` |
| Typography and control glyphs | System SwiftUI fonts and Apple SF Symbols, rendered at runtime; no third-party font files. | Provided by iOS |
| Guidance and safety text | Original copy supplied in the user brief, with the introduction revised for clarity. Safety guidance is preserved verbatim. | `Guidance` in `SessionDefinition.swift` |
| Session definitions | Original names and descriptions from the user brief; content revision 1. | Bundled `sessions.json` |

`Flow/Resources/audio-metrics.json` records exact SHA-256 hashes, levels, durations, and sample rate. The generator has no dependencies, random seed, network requests, or paid service. Exact byte identity assumes the same Python/libm floating-point implementation; PCM remains functionally equivalent on other supported systems.

The ambient file peaks at approximately −27.14 dBFS and has approximately −35.72 dBFS RMS before the user's volume setting. The phase tones peak around −29.05 dBFS. Playback uses additional volume controls; device output volume still matters. These measurements verify digital headroom, not perceived loudness or comfort.

## Introduction · elevenlabs.io

The optional introduction plays a bundled recording, with no runtime speech synthesis, voice download, account, or network call. The visible transcript matches the recording. The narration is AI-generated; no human recording session or Othership production quality is claimed. The owner selected Sarah after listening to two auditions.

The original file is preserved unchanged, including its embedded content credentials. SHA-256: `1a824f6ef61a432a45feae2c66ad5966c0612a709d30d4dc5bd4512859f33d80`. Decoded mean level: −22.7 dBFS; peak: −2.4 dBFS. Playback applies a volume multiplier of 0.8. File measurements do not establish perceived comfort on every device.

This recording was generated on ElevenLabs' Free plan. The owner intends flow to remain free and noncommercial, without monetization. ElevenLabs permits noncommercial sharing with attribution in the content title; `introduction · elevenlabs.io` appears beside the introduction and in source notes. See the [publishing policy](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform) and [terms](https://elevenlabs.io/terms-of-use), checked October 1, 2026. Those pages do not specifically resolve every free App Store distribution scenario. This is not a commercial-use license or a claim that free pricing alone establishes noncommercial use. Commercial reuse requires a separately licensed recording. The audio is not offered under an open-source license.

Generation settings: stability 0.5, similarity 0.75; default speed. Prompt:

```text
[speaking slowly, softly, with warmth] Find a comfortable place to sit... or lie down. [long pause]

Let your shoulders soften. [long pause] Let your breathing stay easy. [long pause]

[slowly] There's no need to make it deeper. [long pause] For the next few minutes... simply notice your breath. [long pause]

Follow the gentle cue if it feels comfortable... or stay with your own rhythm. [long pause]

You can pause... or stop... whenever you need.
```

Othership was reviewed only as a public UI/UX and immersive-sound reference. Its marketing claims are not adopted. No stock wellness photos are used. Source licensing and any future commercial content licensing remain the owner's decisions.
