# Native screen captures

These build **0.2.0 (4)** images show the compiled SwiftUI views on an iPhone 17 Pro simulator. They were exported from the successful [run 36953418240](https://github.com/gtfol/flow/actions/runs/36953418240), source commit `1853af3`. All 25 hosted tests and four navigation tests passed. See [verification](../VERIFICATION.md) for scope and remaining physical-device checks.

| Screen | Standard text | Largest accessibility text / static motion |
| --- | --- | --- |
| Home | [view](home-standard.png) | [view](home-accessibility5-reduce-motion.png) |
| Setup | [view](setup-standard.png) | [view](setup-accessibility5-reduce-motion.png) |
| Safety | [view](safety-standard.png) | [view](safety-accessibility5-reduce-motion.png) |
| Arrive | [view](arrive-standard.png) | [view](arrive-accessibility5-reduce-motion.png) |
| Natural player | [view](natural-standard.png) | [view](natural-accessibility5-reduce-motion.png) |
| Paced player | [view](paced-standard.png) | [view](paced-accessibility5-reduce-motion.png) |
| Open | [view](open-standard.png) | [view](open-accessibility5-reduce-motion.png) |
| Pure Silence | [view](silence-standard.png) | [view](silence-accessibility5-reduce-motion.png) |
| Paused player | [view](paused-standard.png) | [view](paused-accessibility5-reduce-motion.png) |
| Finish | [view](finish-standard.png) | [view](finish-accessibility5-reduce-motion.png) |
| Settings | [view](settings-standard.png) | [view](settings-accessibility5-reduce-motion.png) |

[Standard text with the reduced-motion player](paced-reduce-motion.png). [Natural session during navigation](natural-session-running.png). [Pure Silence with faded controls](pure-silence-controls-faded.png), and [after a tap and background return](pure-silence-controls-restored.png).

Named rendering captures inject session state into a native UIWindow. The natural-session-running and pure-silence-controls captures are from actual app navigation tests and include system indicators. These are not a physical-device walkthrough or a VoiceOver focus audit. The largest text size requires scrolling; captures show the initial viewport, and longer content remains below it. Player controls stay fixed at the bottom. Faded-state captures intentionally show less interface. The repository's `preview.png` shows the current home screen.
