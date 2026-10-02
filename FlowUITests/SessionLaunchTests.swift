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
        let resumed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'pause'"), object: app.buttons["player-primary"])
        XCTAssertEqual(XCTWaiter.wait(for: [resumed], timeout: 4), .completed)
        capture("natural-session-running")
        stopAndReturn()
        begin(acknowledge: false)
        stopAndReturn()
    }
    func testFadeRevealAndBackgroundContinuation() {
        configure(practice: "silence")
        begin(acknowledge: true)
        XCTAssertEqual(app.staticTexts["current-cue"].label, "your space.")
        waitForControlsToFade()
        capture("pure-silence-controls-faded")
        // A tap near the bottom must restore the controls too.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.90)).tap()
        waitForHittable(app.buttons["player-primary"])
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
        waitForControlsToFade()
        // Pacing is intentionally absent from Arrive. Wait for the real Settle phase.
        sleep(23)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let natural = app.buttons["return-natural"]
        waitForHittable(natural)
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
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let end = app.buttons["stop-session"]
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: end)
        XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 4), .completed)
        XCTAssertGreaterThan(end.frame.minY, app.buttons["player-primary"].frame.maxY, "End must have its own tap target below pause/resume")
        end.tap()
        XCTAssertTrue(app.staticTexts["finish-title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["finish-title"].label, "session stopped")
        app.buttons["finish-done"].tap()
        XCTAssertTrue(app.buttons["start-session"].waitForExistence(timeout: 5))
    }
    private func waitForControlsToFade() {
        // SwiftUI may retain an element in the accessibility snapshot while its
        // opacity is zero. The behavioral requirement is that hidden controls
        // cannot consume a reveal tap.
        let faded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == false"), object: app.buttons["player-primary"])
        XCTAssertEqual(XCTWaiter.wait(for: [faded], timeout: 22), .completed)
        XCTAssertFalse(app.buttons["stop-session"].isHittable)
    }
    private func waitForHittable(_ element: XCUIElement) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 6), .completed)
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
