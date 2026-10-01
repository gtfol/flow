import XCTest

final class SessionLaunchTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Invalid preference data in the argument domain exercises fresh defaults
        // without deleting saved data or adding a test-only path to the app.
        app.launchArguments = ["-flow.preferences.v1", "ui-test-fresh-preferences"]
        app.launch()
    }

    func testNaturalSessionFirstStartAndRepeat() {
        openSession("small-pause")
        app.buttons["start-session"].tap()
        acknowledgeSafety()
        beginBreathing()
        XCTAssertEqual(app.staticTexts["current-cue"].label, "your own rhythm.")
        XCTAssertTrue(app.staticTexts["natural breathing"].exists)
        let remaining = app.staticTexts["session-remaining"]
        XCTAssertTrue(remaining.exists)
        let initialTime = remaining.label
        let timeAdvances = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", initialTime), object: remaining)
        XCTAssertEqual(XCTWaiter.wait(for: [timeAdvances], timeout: 4), .completed)
        app.buttons["player-primary"].tap()
        XCTAssertEqual(app.staticTexts["current-cue"].label, "paused")
        app.buttons["player-primary"].tap()
        XCTAssertEqual(app.staticTexts["current-cue"].label, "your own rhythm.")
        capture("natural-session-running")
        stopAndReturn()

        // A second session bypasses safety and must receive a fresh coordinator.
        app.buttons["start-session"].tap()
        XCTAssertFalse(app.buttons["acknowledge-safety"].exists)
        beginBreathing()
        XCTAssertEqual(app.staticTexts["current-cue"].label, "your own rhythm.")
        stopAndReturn()
    }

    func testPacedSessionCanReturnToNatural() {
        openSession("quiet-five")
        app.buttons["mode-paced"].tap()
        app.buttons["start-session"].tap()
        acknowledgeSafety()
        beginBreathing()
        let naturalButton = app.buttons["return-natural"]
        XCTAssertTrue(naturalButton.waitForExistence(timeout: 5))
        naturalButton.tap()
        XCTAssertEqual(app.staticTexts["current-cue"].label, "your own rhythm.")
        XCTAssertTrue(app.staticTexts["natural breathing"].exists)
        stopAndReturn()
    }

    func testReadingSafetyDoesNotStartSession() {
        openSession("small-pause")
        let safety = app.buttons["safety-notes"]
        // SwiftUI may report an offscreen link as hittable beneath the fixed CTA.
        // Reveal the bottom of the scroll view before choosing the safety link.
        app.swipeUp()
        safety.tap()
        acknowledgeSafety()
        XCTAssertTrue(app.buttons["start-session"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["player-primary"].exists)
        app.buttons["start-session"].tap()
        beginBreathing()
        stopAndReturn()
    }

    private func openSession(_ id: String) {
        let session = app.buttons[id]
        XCTAssertTrue(session.waitForExistence(timeout: 10))
        session.tap()
        XCTAssertTrue(app.buttons["start-session"].waitForExistence(timeout: 5))
    }

    private func acknowledgeSafety() {
        let acknowledge = app.buttons["acknowledge-safety"]
        XCTAssertTrue(acknowledge.waitForExistence(timeout: 5))
        acknowledge.tap()
    }

    private func beginBreathing() {
        let begin = app.buttons["player-primary"]
        XCTAssertTrue(begin.waitForExistence(timeout: 8), "The player must not present an empty cover")
        XCTAssertEqual(app.staticTexts["current-cue"].label, "arrive as you are.")
        XCTAssertTrue(app.staticTexts["introduction"].exists)
        begin.tap()
        XCTAssertEqual(begin.label, "pause")
        XCTAssertTrue(app.buttons["stop-session"].isHittable)
    }

    private func stopAndReturn() {
        app.buttons["stop-session"].tap()
        XCTAssertTrue(app.staticTexts["finish-title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["finish-title"].label, "session stopped")
        app.buttons["finish-done"].tap()
        XCTAssertTrue(app.buttons["start-session"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
