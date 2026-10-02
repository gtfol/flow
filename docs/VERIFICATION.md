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

## First GitHub iPhone run

[Run 36946797452](https://github.com/gtfol/flow/actions/runs/36946797452) passed all **25 iPhone-hosted tests**: 18 core, six native audio, and one test rendering 23 screen variants. The actual audio background array, every narration schedule, silence/bell placement, cancellation, playback/pause/resume, repeated cleanup, and interruption/media-reset handling passed.

Three of four navigation tests failed. The captures and accessibility traces exposed overlapping player tap regions and the animated reveal layer intercepting subsequent touches. Player text buttons now use explicit non-overlapping label bounds with plain styling, and the reveal surface disables hit testing immediately. The home hero is smaller so guidance fits above Begin at standard text size. A new check verifies End sits below the pause/resume target. The first repair still failed the navigation assertions in [run 36948320413](https://github.com/gtfol/flow/actions/runs/36948320413), while all 25 iPhone-hosted tests passed again. The current repair removes the invisible overlay entirely, uses a simultaneous screen-tap gesture, and explicitly keeps the footer controls in separate accessibility elements. Its navigation rerun is pending; this is not yet a release-ready result.

## Pending for this iteration

The first local iPhone test run could not begin execution while the Mac was locked and was interrupted; it is not a passing result. A signed archive reached code signing but failed with `errSecInternalComponent` while the Mac was locked. Unlocking is needed for the remaining local UI checks and Xcode Organizer upload. Build 4 has not yet been uploaded.

Remaining automated checks: re-run after the interaction fixes, review the final screen captures, and confirm UI navigation for first/repeated launch, fade/reveal, background return, paced-to-natural override, and standalone safety. Results will be updated when those checks finish. The existing screenshots in `docs/screenshots` are from the prior release until replaced.

## Verification boundaries

- A physical iPhone is still needed to check screen-locked playback through a full session, speaker/headphone listening, Bluetooth removal, calls, route recovery, haptics, and airplane-mode use. Native notification tests simulate the notifications; they do not simulate actual hardware routing.
- The engine's clock tests verify elapsed-time behavior; they alone do not establish that iOS keeps audio running in the background. The app uses the playback category and background audio mode for its finite meditation recording.
- Normal and accessibility-size rendering checks show actual compiled SwiftUI views in a simulator window. They do not establish VoiceOver focus behavior or replace checking real Reduce Motion, Increase Contrast, and larger-text scrolling on a device.
- The available execution runtime is iOS 26.5. iOS 17 is the deployment target but has not been exercised on a device/runtime here.
- Brian was selected from the earlier auditions at the owner's request. Generated cues have digital audio checks; the new sequence has not had a complete physical-phone listening review. No claim of matching another app's production quality is made.
- No clinical review or assurance that a practice suits everyone is implied.

## Prior release

Build **0.1.0 (3)** passed 19 macOS core, 27 iPhone-hosted, and 3 UI tests and was uploaded to the Internal TestFlight group. Its results do not certify the rewritten build-4 session engine. See [distribution](DISTRIBUTION.md) for release history.
