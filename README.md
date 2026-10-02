# flow: your inner space

[![iPhone build and tests](https://github.com/gtfol/flow/actions/workflows/ios.yml/badge.svg)](https://github.com/gtfol/flow/actions/workflows/ios.yml)

A free, offline iPhone app for a little room to be here. Choose **Stillness**, **Open Awareness**, or **Pure Silence**, set **2, 5, 10, 15, 20, or 30 minutes**, and begin.

## Run

Open `Flow.xcodeproj`, select **Flow**, choose an iPhone simulator, and run. For a physical iPhone, signing is configured for **gtfol, LLC** (`J59ZSG67SJ`), bundle `dev.gtfol.flow`. Contributors can select their own team and bundle identifier.

The deployment target is iOS 17. Development uses Xcode 26.6 / Swift 6.3.3 in Swift 5 language mode. All recordings and resources are bundled. No dependency installation, API key, account, server, runtime speech synthesis, or subscription is needed.

```sh
swift test
scripts/test-ios.sh
```

The second command builds for simulator and device, then runs core, native audio, rendering, and UI tests on an available simulator. Override `FLOW_SIMULATOR_ID`, `FLOW_DERIVED_DATA`, and `FLOW_RESULT_BUNDLE` for isolated checks. Outputs default to a temporary directory. See [verification](docs/VERIFICATION.md) for results and hardware limitations.

## The experience

- **Stillness:** arrive, settle with the breath, let the guidance recede, and return gently.
- **Open Awareness:** adds an invitation to include the body and sound before a quiet open period.
- **Pure Silence:** an opening bell, silence, and a closing bell. No voice or pacing.
- **Full / Minimal / Silent guidance:** more reminders, a few invitations, or the opening instruction only. Minimal is the default.
- **Natural breathing / gentle pace:** natural is the default; optional five-second inhale/exhale pacing appears only during Settle, with no holds. A control returns to natural breathing immediately.
- **Progressive disappearance:** controls, timer, text, then the visual fade. Tap anywhere to recover the controls. Return brings them back. VoiceOver retains controls, and Reduce Motion keeps written pacing available.
- **Sparse sound:** original ambient bed fades away before the quiet portion; Brian narration is bundled offline. Opening and closing bells mark the selected interval. Pure Silence never includes ambience.
- **Optional haptics:** gentle phase-boundary taps while the app is in the foreground. Audio and timing continue with the screen locked.
- **Gentle ending:** the bell rings at the selected duration; the screen offers a quiet moment before showing completion. Done is available immediately. Stopping early records no completion.

The home and app icon say **flow**. The App Store display name is **flow: your inner space**. The owner intends the app to remain free and noncommercial. No paywall, tracking, ads, feed, achievements, social features, or backend is included.

Othership's public [app experience](https://www.othership.us/app) informed the atmosphere and focus on sound. The interface, scripts, rings, bell, and ambient bed are original; no Othership content was copied. See [asset provenance](ASSETS.md) for the generated narration's noncommercial license and attribution.

## Timing and audio

`SessionDefinition` builds a deterministic plan from validated preset durations. Guided plans contain Arrive, Settle, optional Expand, Open, and Return. Phase lengths are capped so longer practices increasingly add quiet time. Full guidance leaves the latter 65% of Open free of prompts. The shortest session compresses the plan; it does not promise several minutes in each phase.

`SessionEngine` uses an injectable monotonic clock. Its states are idle, preparing, running, paused, interrupted, completed, and stopped. Elapsed time is accumulated active duration plus time since resume; UI refresh callbacks do not count time. Pause excludes paused duration, and resume preserves the exact phase and recording position. Delayed refreshes skip missed haptics.

Before playback, `SessionAudioRenderer` mixes the finite session into a temporary 24 kHz mono PCM recording. It includes narration, fading ambience, intentional silence, and an eight-second closing-bell tail. Rendering is cancellable, validates voice overlaps, and uses bounded chunks. A 30-minute file is approximately 87 MB and is removed on stop or completion. Bundled MP3 originals remain unchanged.

`AudioController` plays that recording using AVAudioPlayer with the playback audio-session category and the audio background mode. This keeps scheduled cues and the ending bell together during screen lock. Lock-screen pause, resume, and stop commands are supported. Backgrounding does not pause. Audio interruptions, disconnected output, and media-service loss/reset pause and require explicit resume. Reset reconstructs the native player. Audio preparation/play failures show recovery text; a stopped or cancelled preparation cannot start late.

The closing bell begins at the exact selected duration. Completion is recorded once; playback may continue through the bell's decay. Exiting stops and removes audio resources. Mute affects all sound without altering the timer. Haptics use foreground-only UIKit feedback and are not advertised as background haptics.

## Local data

App-scoped UserDefaults stores preferences and completed sessions. Existing build-3 preferences migrate with defaults for the new practice options, retaining safety acknowledgement, volumes, and history. Completion records contain a run UUID, practice ID, completion date, and active duration; IDs are deduplicated. Older session names remain readable.

No unfinished session is restored after process termination. History deletion leaves preferences intact. There is no app cloud sync; operating-system backups may include local data. No diaries, medical records, biometrics, analytics, or tracking SDKs are used. The privacy manifest declares app-scoped UserDefaults access.

## Source layout

- `Flow/Core`: practice plans, monotonic engine, coordinator, local store.
- `Flow/Audio`: finite audio rendering and native playback lifecycle.
- `Flow/UI`: home, setup/safety, fading player/finish, settings, source notes, vector artwork.
- `Flow/Resources`: offline recordings, original bell/ambience, icon, privacy manifest, measurement manifests.
- `FlowTests`: fake-clock and audio-adapter regression tests.
- `FlowNativeTests`: real decoding/rendering/playback and SwiftUI screen captures.
- `FlowUITests`: first/repeated launch, controls, fading/reveal, background return, safety navigation.
- `scripts`: reproducible audio/icon synthesis, project generation, and iOS checks.

Regenerate the project with `python3 scripts/generate_project.py` after changing source/resource membership. [Distribution](docs/DISTRIBUTION.md) describes GitHub and TestFlight setup. No source license has been selected.

## Content boundaries

Flow is a general wellness tool, not treatment or assessment. Natural breathing is the default, pacing is optional, and the safety notes emphasize comfort and stopping when unwell. There are no breath holds, intense breathing protocols, clinical promises, or claims that experiences establish metaphysical facts. Source notes link to [NHS gentle breathing guidance](https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/) and [Cleveland Clinic's hyperventilation explanation](https://my.clevelandclinic.org/health/diseases/hyperventilation); the five-second pace is a product choice, not a prescribed protocol from those sources.
