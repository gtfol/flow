import XCTest
import UIKit

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
        sleep(20)
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
        // The iOS accessibility snapshot retains faded SwiftUI buttons and can
        // throw instead of returning false for isHittable. Check the actual
        // rendered button background, then exercise the screen tap to reveal.
        let frame = app.buttons["player-primary"].frame
        let sample = CGPoint(x: frame.minX + frame.width * 0.15, y: frame.midY)
        XCTAssertGreaterThan(screenBrightness(at: sample), 0.5, "The pause button must initially be visible")
        sleep(17) // 14 seconds until fading, plus the two-second transition.
        XCTAssertLessThan(screenBrightness(at: sample), 0.15, "The pause button must fade to the dark canvas")
    }
    private func screenBrightness(at point: CGPoint) -> Double {
        guard let source = app.screenshot().image.cgImage else { XCTFail("Screenshot unavailable"); return -1 }
        let scale = CGFloat(source.width) / app.frame.width
        let region = CGRect(x: point.x * scale, y: point.y * scale, width: 1, height: 1)
        guard let pixel = source.cropping(to: region) else { XCTFail("Button sample is outside the screen"); return -1 }
        var rgba = [UInt8](repeating: 0, count: 4)
        let drew = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                          bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        XCTAssertTrue(drew)
        return Double(Int(rgba[0]) + Int(rgba[1]) + Int(rgba[2])) / (3 * 255)
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
