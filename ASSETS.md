# Asset provenance

All experience content was created for flow. No recordings, scripts, artwork, or branding were copied from Othership.

| Asset | Origin | Reproduce |
| --- | --- | --- |
| `ambient.wav` | Original additive synthesis, 60 seconds, 24 kHz stereo PCM; quiet partials and endpoint fades. | `python3 scripts/synthesize_audio.py` |
| `bell.wav` | Original additive bell with a soft attack and eight-second decay; no sampled instrument. | Same script |
| Narration MP3s | Original flow scripts generated with **Brian – Deep, Resonant and Comforting**, **Eleven v4**, October 1, 2026 (downloads dated October 2 UTC). | Prompts described below; model output is nondeterministic. |
| Interface and player artwork | Original SwiftUI concentric rings, radial gradients, and vector drawing. | Build the app |
| App icon | Original concentric sage rings with an open center, no lettermark. | `swift scripts/make_icon.swift Flow/Resources/Assets.xcassets/AppIcon.appiconset` |
| Typography and glyphs | Apple system fonts and SF Symbols; no third-party font files. | iOS |
| Practice plans and text | Original implementation from the owner’s briefs; accepted first iteration uses three practices and six duration presets. | `SessionDefinition.swift` |

## Guidance · elevenlabs.io

The owner requested Brian, the other voice from the earlier auditions, in place of Sarah. All nine bundled narration files use Brian. Playback is entirely offline, with no runtime voice generation. The voice is AI-generated; no human recording session or listening-quality certification is claimed.

MP3 originals are retained byte-for-byte, including embedded content credentials. Rendering decodes them into a temporary mixed recording; it does not overwrite the originals. The visible captions come from `Guidance.introduction` and `Guidance.clips`. Voice gain is 0.8; bell and ambient gains use the saved preferences. Digital headroom is measured, but speaker/headphone comfort still needs listening on the target device.

| File | Duration (s) | Mean / peak (dBFS) | SHA-256 |
| --- | ---: | --- | --- |
| `body.mp3` | 9.874 | -24.4 / -1.2 | `32470f7f3ba8d49b73e50a79b67966a636aedef9c6f03ab29c979c57230830f1` |
| `gentle.mp3` | 8.359 | -25.0 / -7.8 | `c3c876d3ccd491ffb71a321cfcc03988cb3672b6f293ce8a50e141fccfdaecf4` |
| `introduction.mp3` | 28.108 | -24.6 / -1.4 | `e495661aebdc268e46520572aeedb9cabcf62be4a1547e4d2d889a9f75bb50e8` |
| `open.mp3` | 10.449 | -23.7 / -5.0 | `d74f739ee3291f749cb4b13169a4e3ab28f66a2a784c31c3c70488c6ab7add68` |
| `pace.mp3` | 13.244 | -23.8 / -3.7 | `a34f5c48ff816acafde7fb38d3cc396e804b5caff7e276fbe1e59b13d9bc7823` |
| `return.mp3` | 10.998 | -23.5 / -4.3 | `f1d24ec59b4c27f2ac5c02bea84391d744738852445427756e97f941993d01cd` |
| `settle.mp3` | 9.247 | -24.2 / -5.0 | `179067dc904c972ad1d03fa7c942eb8fd516072609e867afa290b73beba145ce` |
| `sound.mp3` | 8.281 | -23.6 / -3.5 | `d3459cf44d19ba228cae3dee4a91b873864294a6c5ea67a52ca12c3591ffe7fb` |
| `thoughts.mp3` | 8.516 | -23.3 / -6.1 | `4f3068993b1b8b335c6149aa76a3fa16db1c75f27debee6c8cc4501483a70f1e` |

Exact sample rate, channels, hashes, and levels are in `Flow/Resources/narration-metrics.json`. Original synthesized audio measurements are in `audio-metrics.json`. The old inhale/exhale WAVs and session JSON are no longer bundled in the app.

### Generation prompts

All new prompts begin `[speaking slowly, softly, with warmth]`, with `[long pause]` between sentences. Their spoken text is exactly `Guidance.clips` in `SessionDefinition.swift`; the pace prompt writes “Five seconds in... and five seconds out.” Settings: speed 1.0, stability 0.5, similarity 0.75, Eleven v4. Generation 1 was downloaded for each cue.

The introduction reuses the original Brian audition with this prompt:

```text
[speaking slowly, softly, with warmth] Find a comfortable place to sit... or lie down. [long pause]

Let your shoulders soften. [long pause] Let your breathing stay easy. [long pause]

[slowly] There's no need to make it deeper. [long pause] For the next few minutes... simply notice your breath. [long pause]

Follow the gentle cue if it feels comfortable... or stay with your own rhythm. [long pause]

You can pause... or stop... whenever you need.
```

### License and attribution

The files were generated on ElevenLabs’ Free plan. The owner intends flow to be free and noncommercial, without monetization. The content title **guidance · elevenlabs.io** appears with narration captions and in Source Notes. The [publishing policy](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform) permits noncommercial sharing with title attribution; see also the [terms](https://elevenlabs.io/terms-of-use), checked October 1, 2026. Free app pricing alone does not establish a commercial-use license. These recordings are not offered under an open-source license; commercial reuse requires separately licensed recordings.

Othership was a public UI/UX reference only. Source licensing and future commercial content licensing remain the owner’s decisions.
