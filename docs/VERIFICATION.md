# Verification

Current iteration: **0.2.0 (4)**, October 1, 2026. Xcode 26.6 (17F113), Swift 6.3.3, iOS deployment target 17.0. This file distinguishes completed checks from release work still pending.

## Completed locally

- **18 macOS core tests passed**, zero failures. They cover all three practices and six preset durations, guidance schedules, exact five-second phase boundaries, pause/resume position, delayed refreshes, interruption/manual recovery, background completion, stop/cancel, remote commands, preference migration, and history deduplication/deletion.
- **Simulator Debug and iPhone Release builds passed.** The final background-audio configuration is an explicit `UIBackgroundModes = [audio]` array in the processed app Info.plist. A generated build-setting-only attempt omitted this key; it was replaced by `Flow/Info.plist` and rebuilt.
- **108 practice/duration/guidance/breathing combinations** were checked against the actual decoded narration lengths: no overlap and no voice crossing the selected ending time.
- **Real production renderer exercised on macOS**, using AVAudioFile and AVAudioConverter: 2-minute and 30-minute Full/Paced Open Awareness, plus 2-minute Pure Silence. Every output had the exact selected duration plus an eight-second bell tail. Silent sections contained zero samples; closing-bell audio began at the expected frame.
- Optimized renders on this Mac took approximately **0.28 s, 0.70 s, and 0.04 s**, respectively. These are Mac measurements, not a phone performance claim.
- **Nine Brian recordings decoded and measured.** Durations, hashes, sample rates, channels, and levels are saved in `Flow/Resources/narration-metrics.json`. No clipped decoded source samples were found. The introduction matches the earlier Brian audition byte-for-byte.
- **Test targets compile.** The expanded iPhone suite includes native renderer/playback checks, actual SwiftUI screen captures at normal and largest accessibility text, and production UI navigation.

## Passing GitHub checks

[Run 36953418240](https://github.com/gtfol/flow/actions/runs/36953418240), source `1853af3`, passed the macOS and iPhone jobs:

- **18 macOS core tests**, zero failures.
- **25 iPhone-hosted tests**, zero failures: 18 core, six native audio, and one rendering test capturing 23 screen variants. Native audio checks cover the background-mode declaration, all narration schedules, silence/bell placement, cancellation, playback/pause/resume, repeated cleanup, and interruption/media-reset handling.
- **Four UI navigation tests**, zero failures: first and repeated natural-session launch with pause/resume/End/Done, actual screen fading and tap-to-reveal with background continuation, paced-to-natural override, and standalone safety navigation.
- Simulator Debug and unsigned device Release builds, plus reproducible Xcode project generation, passed.

The visual fade test confirms the pause button changes from its light background to the dark canvas before a real tap restores it. This avoids an XCTest invalid-activation-point error when querying a fully hidden SwiftUI control. End/Pause bounds are asserted separately. Earlier overlapping bounds were repaired with explicit control bounds, a contained accessibility group, and a simultaneous screen-tap gesture.

An earlier [run](https://github.com/gtfol/flow/actions/runs/36952051897) had one repeat-session navigation timeout after a long automation delay. The successful run used unchanged app and test sources; the intervening commit updated documentation and previews only. Local manual/device verification remains outstanding, as listed below.

Current [screen captures](screenshots/README.md) replace the prior-release images. Home, setup, running/paused player, reduced-motion pacing, open silence, and completion were visually reviewed, including home/setup/paused views at the largest accessibility text size. Long content scrolls while primary controls remain fixed. Full test output is summarized in `test-results.txt`; GitHub retains the complete result bundle and attachments.

## Signed archive and upload

The first local iPhone test run could not begin execution while the Mac was locked and was interrupted; it is not a passing result. Initial archive attempts failed at code signing with `errSecInternalComponent`. After the owner unlocked the login keychain, the archive succeeded and strict code-signature verification passed. The archive contains **0.2.0 (4)**, bundle `dev.gtfol.flow`, team `J59ZSG67SJ`, display name **flow**, and the audio background mode.

Xcode Organizer confirmed **flow 0.2.0 (4) uploaded** on October 1, 2026, at 8:12 PM Pacific. The Codex browser verified build 4 as **Testing** in App Store Connect's **Internal** group after processing. No production App Store release has been submitted.

## Verification boundaries

- A physical iPhone is still needed to check screen-locked playback through a full session, speaker/headphone listening, Bluetooth removal, calls, route recovery, haptics, and airplane-mode use. Native notification tests simulate the notifications; they do not simulate actual hardware routing.
- The engine's clock tests verify elapsed-time behavior; they alone do not establish that iOS keeps audio running in the background. The app uses the playback category and background audio mode for its finite meditation recording.
- Normal and accessibility-size rendering checks show actual compiled SwiftUI views in a simulator window. They do not establish VoiceOver focus behavior or replace checking real Reduce Motion, Increase Contrast, and larger-text scrolling on a device.
- The available execution runtime is iOS 26.5. iOS 17 is the deployment target but has not been exercised on a device/runtime here.
- Brian was selected from the earlier auditions at the owner's request. Generated cues have digital audio checks; the new sequence has not had a complete physical-phone listening review. No claim of matching another app's production quality is made.
- No clinical review or assurance that a practice suits everyone is implied.

## Prior release

Build **0.1.0 (3)** passed 19 macOS core, 27 iPhone-hosted, and 3 UI tests and was uploaded to the Internal TestFlight group. Its results do not certify the rewritten build-4 session engine. See [distribution](DISTRIBUTION.md) for release history.
