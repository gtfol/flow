# Verification

Verified October 1, 2026, on this Mac with Xcode 26.6 (17F113), Swift 6.3.3, and an iPhone 17 Pro simulator running iOS 26.5. Repository and distribution setup are documented separately in [distribution](DISTRIBUTION.md).

## Results

| Check | Result |
| --- | --- |
| macOS core tests | 19 passed, 0 failed |
| iPhone-hosted simulator tests | 27 passed, 0 failed on build 3: 19 core, 7 native audio, 1 multi-screen rendering test |
| Session navigation UI tests | 3 passed, 0 failed on build 3 in a dedicated simulator: first and repeated natural starts, paced-to-natural playback, standalone safety review |
| Simulator Debug build and launch | Passed; app installed and launched |
| iPhone Release archive | Build 3 signed archive succeeded; code signature, bundle identity, build number, and selected narration hash verified; no physical-device installation performed |
| Native audio resources | All three WAVs and the 27.64-second Sarah MP3 decode through AVAudioPlayer with expected duration and channel count |
| Audio lifecycle integration | Posted actual AVAudioSession notification types for interruption, route removal, media reset, and media loss; each paused the coordinator; interruption end with “should resume” did not resume |
| Repeat native playback | Three ambient/cue start-stop cycles completed without an error callback in the simulator |
| Recorded introduction | Real playback starts, stops on begin/cancel/route interruption, repeats across sessions, and finishes without starting the breathing timer; missing file falls back to text, invalid audio pauses with recovery text |
| Digital audio checks | No clipped samples; first/last stereo frames are zero; measured headroom and sample steps saved in `audio-checks.json` and resource metrics |
| Native visual review | Nine production SwiftUI screens rendered at standard text and Accessibility 5; static-motion player also rendered at standard text |

The native audio tests verify API behavior, not audible output quality or real accessory behavior. The iOS run used `CODE_SIGNING_ALLOWED=NO` for simulator testing. Flow does not use Keychain. The initial signed simulator build required clearing Finder/resource-fork metadata from the generated app bundle in this Documents workspace; this was an environment issue, not a source compile error.

Build 3's first UI run encountered another app (`dev.gtfol.vitals`) taking foreground on the shared simulator; its logs show those activations during taps. Two navigation checks failed in that run. The same unmodified checks passed on a new, dedicated iPhone 17 Pro simulator. Native/core results are retained in `/private/tmp/flow-build3/Tests.xcresult`; the isolated UI results are in `/private/tmp/flow-build3/UITests-isolated.xcresult`.

## Automated coverage

The test suite exercises both bundled session lengths and content revisions; rejection of unsupported/hold phases, unknown schema fields, empty/duplicate definitions, bad durations, and bad revisions; exact phase boundaries; delayed updates without drift or queued stale tones; completion clamping; accumulated active time across pause/resume; inhale-boundary restart; natural-mode switching; interruptions/background/route/media callbacks; audio activation and cue failures; cancellation and repeated starts; optional narration and missing-file fallback; preference defaults/relaunch; history deduplication and deletion.

Native tests additionally decode the bundled assets, run repeated AVAudioPlayer playback, and check the actual notification-to-coordinator connection. Timing tests inject a monotonic clock. Real-world background timing, Bluetooth behavior, and acoustic transitions still require hardware testing.

## Session launch regression

The original build's black screen was reproduced by opening a small pause, starting a natural session, and acknowledging safety. The player cover used a Boolean independently of its optional coordinator, which allowed empty content. Build 2 presents the coordinator as the cover's identifiable item and waits for the safety sheet's dismissal callback before starting the player.

The new UI test target taps through the production app instead of directly constructing a player. It checks first-time natural breathing after safety acknowledgement, advancing remaining time, pause/resume, stop/done, another start without safety, paced breathing switching to natural, and opening safety notes without starting a session.

## Screen review

[Screenshot index](screenshots/README.md) includes home, setup, safety, introduction, natural player, paced player, paused player, finish, and settings. The test harness presents actual compiled SwiftUI views in a simulator UIWindow and captures that hierarchy. Fake clocks put the player in precise states; a silent audio adapter avoids sounding every rendering fixture. These are **native rendering captures**, not design mockups, and not evidence of a completed manual navigation walkthrough. They omit the system status bar.

Large-text renders use SwiftUI's largest accessibility size. The player shows text instead of its decorative visual at these sizes. The reduced-motion test seam uses the same static visual branch as the system setting; the system's actual Reduce Motion switch was not manually toggled. Longer content remains in native scroll views. Stop, resume/pause, safety acknowledgement, and done remain in fixed safe-area controls. Image review prompted a smaller standard player visual, removal of decorative visuals at accessibility sizes, a flexible setup title area, and fixed-size decorative control glyphs.

No clipped text within controls or overlapping buttons remained in the reviewed captures. Content continuing beyond a scroll viewport is expected. Manual scrolling, VoiceOver focus/rotor behavior, and the actual system Reduce Motion setting have not yet been exercised.

## Checks still needed

- **Remaining interactive checks:** automated UI coverage now exercises launch and playback controls. Complete both full durations through the UI and check changes to sound, completion history, and relaunch manually.
- **Physical iPhone:** device discovery found a known device but it was disconnected. Check airplane-mode launch/use, both complete durations, screen lock, app switching, incoming calls/audio interruptions, headphone and Bluetooth disconnection, media-service recovery, and repeated sessions.
- **Listening:** listen to a full ambient loop and both tones on speaker and headphones at a comfortable device level. Check the loop seam, 80 ms pause/stop release, resume fade-in, relative tone level, clicks, and perceived loudness. The files have not been approved by listening; no claim of acoustic verification is made.
- **Narration on a physical phone:** the owner chose Sarah's audition; the bundled MP3 matches it byte-for-byte. Check its playback level and stop behavior on phone speaker/headphones and in airplane mode. No system voice or voice download remains.
- **Accessibility:** check VoiceOver navigation and focus, real Reduce Motion/Increase Contrast settings, largest text scrolling through all content, and stop reachability on smaller iPhone screens. No VoiceOver speech is scheduled every second.
- **iOS 17 runtime:** the deployment target is iOS 17 and all code compiled against that target, but the available runtime used for execution was iOS 26.5. An iOS 17 physical device/runtime has not been tested.

Do not treat the unverified items as passed. No clinical review or assurance that the sessions suit everyone is implied.
