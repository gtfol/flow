# flow: your inner space

[![iPhone build and tests](https://github.com/gtfol/flow/actions/workflows/ios.yml/badge.svg)](https://github.com/gtfol/flow/actions/workflows/ios.yml)

A personal, offline iPhone app for a little room to breathe. Two original sessions: **a small pause** (2 minutes) and **a quiet five** (5 minutes). Natural breathing is the default. An optional gentle visual cue uses 4 seconds in / 4 seconds out, with no holds.

## Run

1. Open `Flow.xcodeproj` in Xcode.
2. Select **Flow**, choose an iPhone simulator, and press Run.
3. For your iPhone, select your device. Signing is configured for **gtfol, LLC** (`J59ZSG67SJ`) with bundle identifier `dev.gtfol.flow`. Contributors can select their own development team and bundle identifier.

The complete project, sessions, audio, and icon are included. No dependency installation, code generation, account, API key, server, or subscription is needed to run the app. The deployment target is iOS 17.0. Development uses Xcode 26.6 / Swift 6.3.3 in Swift 5 language mode.

From this repository root, run the core tests:

```sh
swift test
```

Build without a device signing team:

```sh
xcodebuild -project Flow.xcodeproj -scheme Flow \
  -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

The package tests use the same core source as the iPhone app. They run on macOS and do not pretend to validate physical iPhone audio, haptics, or screen locking. See [verification](docs/VERIFICATION.md) for results and device checks.

For the iPhone-hosted tests and native screen rendering checks, use **Product → Test** in Xcode with an iPhone simulator selected, or:

```sh
xcodebuild -project Flow.xcodeproj -scheme Flow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Choose an available simulator name on your Mac. The test target includes native audio decoding, lifecycle-notification integration, and screenshots of the real SwiftUI views at standard and largest accessibility text sizes. Screens are saved as test-result attachments and inside the test app's Documents/ScreenChecks folder. These deterministic renders complement the manual walkthrough; they do not replace it.

For the complete simulator/device build and test sequence, run `scripts/test-ios.sh`. Build outputs go to a temporary folder by default. Override `FLOW_DERIVED_DATA` and `FLOW_RESULT_BUNDLE` to retain them at chosen paths.

## This first slice

Home → session setup → first-use safety notes → readable, optionally spoken introduction → breathing player → finish. Pausing, returning to natural breathing, muting sound, and stopping early are always available in the player. Stop is pinned outside the scrolling content, including at accessibility text sizes. A stopped session says **session stopped** and earns no completion.

Settings provide separate ambient/tone volume controls, independent sound and spoken-introduction switches, optional haptics, completed-session details, local history deletion, safety notes, and source notes. Links in source notes require internet if explicitly opened; breathing sessions do not.

## Assumptions and design direction

- **Name:** flow, as requested. The App Store listing is **flow: your inner space**. The home-screen name and interface use **flow**. App Store Connect uses bundle identifier `dev.gtfol.flow`; no trademark clearance is implied.
- **Platform:** native iPhone, SwiftUI, iOS 17+. No web app, Android app, or backend is included.
- **Reference:** Othership's public [app page](https://www.othership.us/app) and [App Store screenshots](https://apps.apple.com/us/app/othership-guided-breathwork/id1590348936) informed the immersive, sound-led approach, atmospheric session selection, and focused player. Flow uses original vector light studies, a dark ink / sage palette, and system serif and sans-serif typography. No recordings, subscription content, artwork, claims, names, or distinctive layouts were copied.
- **gtfol reference:** inspected the local capsule iPhone project from gtfol/capsule. Its separated core/presentation structure, lowercase interface, native controls, and generous spacing informed this project. No capsule application code, font files, or account integration were copied.
- **Audio:** the original synthesized bed and tones are a usable first soundscape, not studio-produced music or narration. System speech is optional, English, and restricted to an enumerated default voice. No system voice is recorded or redistributed. The outro is visible text only.
- **Repository/distribution:** this repository follows the gtfol/vitals layout, with reproducible Xcode project generation and GitHub Actions for core tests, iPhone builds, native tests, and screenshot artifacts. See [distribution](docs/DISTRIBUTION.md) for release steps. No source license has been selected.

## Timing and lifecycle

`SessionEngine` is the only session state machine: idle, introduction, running, paused, interrupted, completed, stopped. `ContinuousClock` provides monotonic time through an injectable `MonotonicTimeSource`. Elapsed time is accumulated active duration plus the monotonic difference since the latest resume. The 50 ms observation task only refreshes the presentation; counting callbacks never advances the session. Wall-clock dates are used only for completion records.

Introduction and ending text sit outside the timed interval. The user starts the breathing interval explicitly. Pausing or interrupting the introduction stops speech; explicit resume starts the interval without replaying narration. The introduction remains readable on the introduction screen; a spoken-intro failure offers text/recovery.

**Resume policy:** preserve all active duration, exclude all paused duration, and restart the optional cue at a new inhale boundary. No partial-cycle time is removed from the total. For example, pause at 5.5 active seconds, wait 10 minutes, resume: elapsed stays 5.5, the cue begins an inhale, and the 2-minute session still ends at exactly 120 active seconds. Its last cycle can be shorter than eight seconds. Completion never depends on following the cue.

On delayed refreshes, calculate the current phase directly. Only a transition observed in its first 250 ms can sound; missed tones are skipped, never replayed. Pause freezes the visual and stops speech immediately; player audio has an 80 ms release ramp, then resources are released. Resume cancels any remaining release task before preparing new playback.

App inactivity (including backgrounding/locking), audio interruption, headphone disconnection, and media-service loss/reset pause the session. Interruption-end notifications never resume it. Audio activation/playback failures present recovery text and pause the timeline. Users can turn sound off and resume with the visual/text. Terminal states stop audio; leaving cancels the observation task and audio callbacks. There is no background-audio entitlement or automatic resumption.

## Local data

`SessionStore` wraps app-scoped `UserDefaults` with versioned, Codable data for preferences and a small list of completed sessions. This is sufficient for a personal first slice; there is no database or migration framework. Each record contains exactly a run UUID, session ID, completion date, and actual active duration. The coordinator saves once per run and the store also deduplicates UUIDs across relaunches. Stopped, abandoned, and currently interrupted runs are never persisted. An interrupted run can be completed only after explicit resume and the full active interval.

History deletion leaves preferences and bundled definitions alone. There is no app cloud sync; operating-system backups may include app data. No diaries, diagnoses, biometric records, analytics, or tracking SDKs are used. The privacy manifest declares app-scoped UserDefaults access.

## Source layout

- `Flow/Core`: strict declarative definitions, monotonic engine, coordinator/audio seam, local store.
- `Flow/Audio`: native audio session handling, bundled audio playback, optional on-device introduction.
- `Flow/UI`: home, setup/safety, player/finish, settings/source notes, vector visuals.
- `Flow/Resources`: validated session JSON, WAVs, icon, privacy manifest.
- `FlowTests`: fake-clock and fake-audio regression tests.
- `FlowNativeTests`: iPhone-hosted audio integration and native rendering checks.
- `FlowUITests`: actual session navigation, first and repeat starts, safety acknowledgement, and natural/paced playback controls.
- `scripts`: reproducible audio/icon synthesis and optional project regeneration.

Definitions reject unknown fields, unsupported phases, holds, nonpositive or nonfinite durations, durations over five minutes, and any phase pair other than the approved 4/4 inhale/exhale. Content revisions are explicit. There is no import UI or custom protocol editor. Future owned narration can implement the `SessionAudio` introduction seam without changing the clock or history logic.

## Safety and content

This is a general wellness tool, not treatment or assessment. Safety and guidance text comes from the supplied brief. The [NHS guidance](https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/) supports comfortable breathing without forcing and optional counting; it does not prescribe flow's fixed 4/4 cue. The source notes also link to [Cleveland Clinic's hyperventilation explanation](https://my.clevelandclinic.org/health/diseases/hyperventilation). No claims to treat anxiety, improve oxygenation, release trauma, or guarantee sleep are made.

Read [ASSETS.md](ASSETS.md) for provenance and [docs/VERIFICATION.md](docs/VERIFICATION.md) for the verification boundary. Licensing remains an owner decision; there is deliberately no source license file yet.
