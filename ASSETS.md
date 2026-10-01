# Asset provenance

All bundled experience content was produced specifically for flow. No music, recordings, artwork, scripts, or branding were downloaded from Othership or another content service.

| Asset | Origin | Reproduce |
| --- | --- | --- |
| `ambient.wav` | Original additive synthesis: quiet sine partials at 110, 165, 220, 275, and 330 Hz, slow level variation, stereo offsets, 1.2-second endpoint fades. 60 seconds, 24 kHz stereo, 16-bit PCM. Repeats without a fast beat or escalating intensity. | `python3 scripts/synthesize_audio.py` |
| `inhale.wav` | Original 440 Hz / 660 Hz tone with smooth attack and decay; 0.8 seconds. | Same script |
| `exhale.wav` | Original 330 Hz / 495 Hz tone with smooth attack and decay; 0.8 seconds. | Same script |
| Session card artwork | Original SwiftUI gradients and Bézier line studies in `FlowStyle.swift`. Native vector rendering, no bitmap source. | Build the app |
| Player visual | Original concentric circles and radial gradients in SwiftUI. Natural mode is stationary. | Build the app |
| App icon | Original lowercase f and concentric rings, rendered with AppKit/Core Graphics at 1024 × 1024. | `swift scripts/make_icon.swift Flow/Resources/Assets.xcassets/AppIcon.appiconset` |
| Typography and control glyphs | System SwiftUI fonts and Apple SF Symbols, rendered at runtime; no third-party font files. | Provided by iOS |
| Guidance and safety text | Original copy supplied in the user brief, preserved verbatim. | `Guidance` in `SessionDefinition.swift` |
| Session definitions | Original names and descriptions from the user brief; content revision 1. | Bundled `sessions.json` |

`Flow/Resources/audio-metrics.json` records exact SHA-256 hashes, levels, durations, and sample rate. The generator has no dependencies, random seed, network requests, or paid service. Exact byte identity assumes the same Python/libm floating-point implementation; PCM remains functionally equivalent on other supported systems.

The ambient file peaks at approximately −27.14 dBFS and has approximately −35.72 dBFS RMS before the user's volume setting. The phase tones peak around −29.05 dBFS. Playback uses additional volume controls; device output volume still matters. These measurements verify digital headroom, not perceived loudness or comfort.

On-device `AVSpeechSynthesizer` can read the introduction with an installed English default voice. No voice audio is exported, saved, or included in the source tree, and no redistribution rights to system voices are claimed. The app provides the visible text when no voice is found. Studio narration and composed music remain a separate content-production task.

Othership was reviewed only as a public UI/UX and immersive-sound reference. Its marketing claims are not adopted. No stock wellness photos are used. Source licensing and any future commercial content licensing remain the owner's decisions.
