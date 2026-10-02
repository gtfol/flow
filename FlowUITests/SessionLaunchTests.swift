import XCTest

final class SessionLaunchTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-flow.preferences.v1", "ui-test-fresh-preferences"]
        app.launch()
    }
    func testNaturalSessionFirstStartAndRepeat() {
        configure(practice: "openAwareness")
        begin(acknowledge: true)
        XCTAssertEqual(app.staticTexts["current-cue"].label, "arrive as you are.")
        let remaining = app.staticTexts["session-remaining"]
        let initial = remaining.label
        let advances = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", initial), object: remaining)
        XCTAssertEqual(XCTWaiter.wait(for: [advances], timeout: 4), .completed)
        app.buttons["player-primary"].tap()
        XCTAssertEqual(app.staticTexts["current-cue"].label, "paused")
        app.buttons["player-primary"].tap()
        capture("natural-session-running")
        stopAndReturn()
        begin(acknowledge: false)
        stopAndReturn()
    }
    func testFadeRevealAndBackgroundContinuation() {
        configure(practice: "silence")
        begin(acknowledge: true)
        XCTAssertEqual(app.staticTexts["current-cue"].label, "your space.")
        let reveal = app.buttons["reveal-controls"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 20))
        // Tap the lower area too: the reveal surface covers the whole player.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.90)).tap()
        XCTAssertTrue(app.buttons["player-primary"].waitForExistence(timeout: 4))
        let before = app.staticTexts["session-remaining"].label
        XCUIDevice.shared.press(.home)
        // Real foreground transitions exercise the app lifecycle; hardware lock/audio
        // routing still require a physical iPhone listening check.
        sleep(3)
        app.activate()
        XCTAssertEqual(app.buttons["player-primary"].label, "pause")
        XCTAssertNotEqual(app.staticTexts["session-remaining"].label, before)
        capture("pure-silence-controls-restored")
        stopAndReturn()
    }
    func testPacedSettlingCanReturnToNatural() {
        app.buttons["configure-session"].tap()
        app.buttons["practice-stillness"].tap()
        app.buttons["duration-2"].tap()
        app.swipeUp()
        app.buttons["breathing-picker"].tap()
        app.buttons["gentle pace · 5 in / 5 out"].tap()
        app.buttons["setup-done"].tap()
        begin(acknowledge: true)
        let reveal = app.buttons["reveal-controls"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 20))
        // Pacing is intentionally absent from Arrive. Wait for the real Settle phase.
        sleep(23)
        reveal.tap()
        let natural = app.buttons["return-natural"]
        XCTAssertTrue(natural.waitForExistence(timeout: 6))
        natural.tap()
        XCTAssertEqual(app.staticTexts["current-cue"].label, "find your rhythm.")
        XCTAssertFalse(natural.exists)
        stopAndReturn()
    }
    func testReadingSafetyDoesNotStartSession() {
        app.buttons["configure-session"].tap()
        app.swipeUp()
        let safety = app.buttons["safety-notes"]
        if !safety.isHittable { app.swipeUp() }
        safety.tap()
        app.buttons["acknowledge-safety"].tap()
        XCTAssertTrue(app.buttons["setup-done"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["player-primary"].exists)
        app.buttons["setup-done"].tap()
        XCTAssertTrue(app.buttons["start-session"].exists)
    }
    private func configure(practice: String) {
        XCTAssertTrue(app.buttons["configure-session"].waitForExistence(timeout: 10))
        app.buttons["configure-session"].tap()
        app.buttons["practice-\(practice)"].tap()
        app.buttons["duration-2"].tap()
        app.buttons["setup-done"].tap()
    }
    private func begin(acknowledge: Bool) {
        app.buttons["start-session"].tap()
        if acknowledge {
            XCTAssertTrue(app.buttons["acknowledge-safety"].waitForExistence(timeout: 5))
            app.buttons["acknowledge-safety"].tap()
        }
        let pause = app.buttons["player-primary"]
        XCTAssertTrue(pause.waitForExistence(timeout: 30), "Player must prepare and show a working session")
        XCTAssertEqual(pause.label, "pause")
        XCTAssertTrue(app.buttons["stop-session"].isHittable)
    }
    private func stopAndReturn() {
        if !app.buttons["stop-session"].exists { app.buttons["reveal-controls"].tap() }
        app.buttons["stop-session"].tap()
        XCTAssertTrue(app.staticTexts["finish-title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["finish-title"].label, "session stopped")
        app.buttons["finish-done"].tap()
        XCTAssertTrue(app.buttons["start-session"].waitForExistence(timeout: 5))
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
