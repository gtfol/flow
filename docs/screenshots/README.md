# Native screen captures

These images show the real compiled SwiftUI views rendered in an iPhone 17 Pro simulator. The rendering test injects player state and captures a native UIWindow; it does not navigate the app through taps. See [verification](../VERIFICATION.md) for the precise limits.

| Screen | Standard text | Largest accessibility text / static motion |
| --- | --- | --- |
| Home | [view](home-standard.png) | [view](home-accessibility5-reduce-motion.png) |
| Setup | [view](setup-standard.png) | [view](setup-accessibility5-reduce-motion.png) |
| Safety | [view](safety-standard.png) | [view](safety-accessibility5-reduce-motion.png) |
| Introduction | [view](introduction-standard.png) | [view](introduction-accessibility5-reduce-motion.png) |
| Natural player | [view](natural-standard.png) | [view](natural-accessibility5-reduce-motion.png) |
| Paced player | [view](paced-standard.png) | [view](paced-accessibility5-reduce-motion.png) |
| Paused player | [view](paused-standard.png) | [view](paused-accessibility5-reduce-motion.png) |
| Finish | [view](finish-standard.png) | [view](finish-accessibility5-reduce-motion.png) |
| Settings | [view](settings-standard.png) | [view](settings-accessibility5-reduce-motion.png) |

[Standard text with the reduced-motion player](paced-reduce-motion.png).

The largest text size requires scrolling to read long content. The captures show the initial viewport; text outside it is not removed. The player’s stop button stays fixed at the bottom.

`01-home.png` is a direct simulator screen capture from an actual app launch, including system status indicators. Other named screens are deterministic native view captures. `preview.png` at the repository root arranges three unaltered native captures for quick review.
