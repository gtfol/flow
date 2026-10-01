# Distribution

Flow follows the gtfol/vitals native iPhone repository setup. The shared Xcode scheme is **Flow**, signing is automatic for **gtfol, LLC** (`J59ZSG67SJ`), and the bundle identifier is `dev.gtfol.flow`.

The first beta is version **0.1.0**, build **1**. The device display name remains **flow**. A subtitle can be chosen independently of the bundle identifier.

## Checks

GitHub Actions uses macOS 26 and Xcode 26.6. It verifies that regenerating the Xcode project leaves no diff, runs core tests on macOS, compiles for simulator and device, and runs the iPhone-hosted tests. Native screen captures and the complete result bundle are retained as workflow artifacts.

Before a release, run `swift test` and `scripts/test-ios.sh`. Review the hardware checks in [VERIFICATION.md](VERIFICATION.md). Builds have no API keys, environment files, third-party dependencies, analytics, or backend configuration.

## Archive and upload

1. Sign in to Xcode with an account that can distribute apps for gtfol, LLC.
2. Open `Flow.xcodeproj`, select **Flow** and **Any iOS Device**, then use **Product → Archive**.
3. In Organizer, select the new **flow** archive and choose **Distribute App → App Store Connect**.
4. Upload to the App Store Connect app associated with `dev.gtfol.flow`, then wait for processing before using TestFlight.

Increment `CURRENT_PROJECT_VERSION` in `scripts/generate_project.py` for each new upload and regenerate the project. Change `MARKETING_VERSION` there for a new version. Keep credentials and signing private keys outside the repository.

The app uses no custom or non-exempt encryption; the generated Info.plist declares `ITSAppUsesNonExemptEncryption = false`. Uploading a beta does not submit a production App Store release or invite external testers. Source licensing remains an owner decision.
