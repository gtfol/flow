import XCTest
import AVFoundation
@testable import Flow

@MainActor final class NativeAudioTests: XCTestCase {
    func testBundledAudioDecodesAndHasExpectedDuration() async throws {
        for (name, duration) in [("ambient", 60.0), ("inhale", 0.8), ("exhale", 0.8)] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "wav"))
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertEqual(player.duration, duration, accuracy: 0.001)
            XCTAssertEqual(player.numberOfChannels, 2)
            XCTAssertTrue(player.prepareToPlay())
        }
    }

    func testNativeNotificationsPauseWithoutAutomaticResume() async throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "sessions", withExtension: "json")))
        let definition = try XCTUnwrap(SessionDefinition.load(data: data).first)
        let notifications: [(Notification.Name, [String: Any]?)] = [
            (AVAudioSession.interruptionNotification, [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]),
            (AVAudioSession.routeChangeNotification, [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]),
            (AVAudioSession.mediaServicesWereResetNotification, nil),
            (AVAudioSession.mediaServicesWereLostNotification, nil)
        ]
        for (name, info) in notifications {
            let audio = AudioController()
            let storage = SessionStore(defaults: UserDefaults(suiteName: "flow.native.\(UUID().uuidString)")!)
            storage.preferences.sound = false
            let engine = SessionEngine(definition: definition, clock: ContinuousTimeSource())
            let coordinator = SessionCoordinator(engine: engine, audio: audio, store: storage)
            coordinator.start(); coordinator.resume(automaticallyRefresh: false)
            XCTAssertEqual(engine.state, .running)
            NotificationCenter.default.post(name: name, object: AVAudioSession.sharedInstance(), userInfo: info)
            try await Task.sleep(for: .milliseconds(150))
            XCTAssertEqual(engine.state, .interrupted)
            XCTAssertNotNil(engine.interruptionReason)
            NotificationCenter.default.post(name: AVAudioSession.interruptionNotification,
                                            object: AVAudioSession.sharedInstance(),
                                            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                                                       AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue])
            try await Task.sleep(for: .milliseconds(150))
            XCTAssertEqual(engine.state, .interrupted)
            XCTAssertTrue(storage.history.isEmpty)
            coordinator.cancel()
        }
    }

    func testNativeSoundStartStopAndRepeat() async throws {
        let audio = AudioController()
        var errors: [String] = []
        audio.onInterruption = { errors.append($0) }
        for _ in 0..<3 {
            try audio.startAmbient(preferences: Preferences())
            try audio.cue(.inhale, volume: 0.1)
            audio.stopAll()
            try await Task.sleep(for: .milliseconds(130))
        }
        XCTAssertTrue(errors.isEmpty, errors.joined(separator: "\n"))
        audio.onInterruption = nil
    }
}
