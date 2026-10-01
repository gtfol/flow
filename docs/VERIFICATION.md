# Verification

Verified October 1, 2026, on this Mac with Xcode 26.6 (17F113), Swift 6.3.3, and an iPhone 17 Pro simulator running iOS 26.5. These checks describe the first implementation. Repository and distribution setup are documented separately in [distribution](DISTRIBUTION.md).

## Results

| Check | Result |
| --- | --- |
| macOS core tests | 19 passed, 0 failed |
| iPhone-hosted simulator tests | 23 passed, 0 failed: 19 core, 3 native audio, 1 multi-screen rendering test |
| Simulator Debug build and launch | Passed; app installed and launched |
| Physical iPhone Release compilation | Passed with signing disabled; compilation only, no device installation |
| Native audio resources | All three WAVs decode through AVAudioPlayer with expected duration and channel count |
| Audio lifecycle integration | Posted actual AVAudioSession notification types for interruption, route removal, media reset, and media loss; each paused the coordinator; interruption end with “should resume” did not resume |
| Repeat native playback | Three ambient/cue start-stop cycles completed without an error callback in the simulator |
| Digital audio checks | No clipped samples; first/last stereo frames are zero; measured headroom and sample steps saved in `audio-checks.json` and resource metrics |
| Native visual review | Nine production SwiftUI screens rendered at standard text and Accessibility 5; static-motion player also rendered at standard text |

The native audio tests verify API behavior, not audible output quality or real accessory behavior. The iOS run used `CODE_SIGNING_ALLOWED=NO` for simulator testing. Flow does not use Keychain. The initial signed simulator build required clearing Finder/resource-fork metadata from the generated app bundle in this Documents workspace; this was an environment issue, not a source compile error.

## Automated coverage

The test suite exercises both bundled session lengths and content revisions; rejection of unsupported/hold phases, unknown schema fields, empty/duplicate definitions, bad durations, and bad revisions; exact phase boundaries; delayed updates without drift or queued stale tones; completion clamping; accumulated active time across pause/resume; inhale-boundary restart; natural-mode switching; interruptions/background/route/media callbacks; audio activation and cue failures; cancellation and repeated starts; optional speech and missing-voice fallback; preference defaults/relaunch; history deduplication and deletion.

Native tests additionally decode the bundled assets, run repeated AVAudioPlayer playback, and check the actual notification-to-coordinator connection. Timing tests inject a monotonic clock. Real-world background timing, Bluetooth behavior, and acoustic transitions still require hardware testing.

## Screen review

[Screenshot index](screenshots/README.md) includes home, setup, safety, introduction, natural player, paced player, paused player, finish, and settings. The test harness presents actual compiled SwiftUI views in a simulator UIWindow and captures that hierarchy. Fake clocks put the player in precise states; a silent audio adapter avoids sounding every rendering fixture. These are **native rendering captures**, not design mockups, and not evidence of a completed manual navigation walkthrough. They omit the system status bar.

Large-text renders use SwiftUI's largest accessibility size. The player shows text instead of its decorative visual at these sizes. The reduced-motion test seam uses the same static visual branch as the system setting; the system's actual Reduce Motion switch was not manually toggled. Longer content remains in native scroll views. Stop, resume/pause, safety acknowledgement, and done remain in fixed safe-area controls. Image review prompted a smaller standard player visual, removal of decorative visuals at accessibility sizes, a flexible setup title area, and fixed-size decorative control glyphs.

No clipped text within controls or overlapping buttons remained in the reviewed captures. Content continuing beyond a scroll viewport is expected. Manual scrolling, VoiceOver focus/rotor behavior, and the actual system Reduce Motion setting have not yet been exercised.

## Checks still needed

- **Interactive walkthrough:** the Mac was locked, so the computer-control tool could not operate Simulator. Unlock was requested; the walkthrough remains unverified. Launch each session, review safety, change sound settings, pause/resume, return to natural mode, stop, finish, and relaunch through the actual controls.
- **Physical iPhone:** device discovery found a known device but it was disconnected. Check airplane-mode launch/use, both complete durations, screen lock, app switching, incoming calls/audio interruptions, headphone and Bluetooth disconnection, media-service recovery, and repeated sessions.
- **Listening:** listen to a full ambient loop and both tones on speaker and headphones at a comfortable device level. Check the loop seam, 80 ms pause/stop release, resume fade-in, relative tone level, clicks, and perceived loudness. The files have not been approved by listening; no claim of acoustic verification is made.
- **Speech offline:** validate installed/default voice availability in airplane mode, missing-voice fallback, and speech interruption on an actual phone. Voice download is not part of the app.
- **Accessibility:** check VoiceOver navigation and focus, real Reduce Motion/Increase Contrast settings, largest text scrolling through all content, and stop reachability on smaller iPhone screens. No VoiceOver speech is scheduled every second.
- **iOS 17 runtime:** the deployment target is iOS 17 and all code compiled against that target, but the available runtime used for execution was iOS 26.5. An iOS 17 physical device/runtime has not been tested.

Do not treat the unverified items as passed. No clinical review or assurance that the sessions suit everyone is implied.
