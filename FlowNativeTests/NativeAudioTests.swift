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
        let narration = try AVAudioPlayer(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "introduction", withExtension: "mp3")))
        XCTAssertEqual(narration.duration, 27.6375, accuracy: 0.05)
        XCTAssertEqual(narration.numberOfChannels, 1)
        XCTAssertTrue(narration.prepareToPlay())
    }

    func testNarrationStopsOnBeginCancelAndRepeatedSessions() async throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "sessions", withExtension: "json")))
        let definition = try XCTUnwrap(SessionDefinition.load(data: data).first)
        let audio = AudioController()
        let storage = SessionStore(defaults: UserDefaults(suiteName: "flow.narration.\(UUID().uuidString)")!)
        storage.preferences.spokenIntroduction = true
        storage.preferences.sound = false
        for _ in 0..<3 {
            let engine = SessionEngine(definition: definition, clock: ContinuousTimeSource())
            let coordinator = SessionCoordinator(engine: engine, audio: audio, store: storage)
            coordinator.start()
            XCTAssertTrue(audio.isIntroductionPlaying)
            XCTAssertEqual(engine.elapsed, 0)
            coordinator.resume(automaticallyRefresh: false)
            XCTAssertFalse(audio.isIntroductionPlaying)
            XCTAssertEqual(engine.state, .running)
            coordinator.cancel()
            XCTAssertFalse(audio.isIntroductionPlaying)
            try await Task.sleep(for: .milliseconds(130))
        }
        XCTAssertTrue(storage.history.isEmpty)
    }

    func testNarrationCompletionDoesNotStartBreathingAutomatically() async throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "sessions", withExtension: "json")))
        let definition = try XCTUnwrap(SessionDefinition.load(data: data).first)
        // A short bundled recording exercises the real completion callback without a 28-second wait.
        let audio = AudioController(introductionURL: try XCTUnwrap(Bundle.main.url(forResource: "inhale", withExtension: "wav")))
        let storage = SessionStore(defaults: UserDefaults(suiteName: "flow.narration.end.\(UUID().uuidString)")!)
        storage.preferences.spokenIntroduction = true
        let engine = SessionEngine(definition: definition, clock: ContinuousTimeSource())
        let coordinator = SessionCoordinator(engine: engine, audio: audio, store: storage)
        coordinator.start()
        XCTAssertTrue(audio.isIntroductionPlaying)
        try await Task.sleep(for: .milliseconds(1200))
        XCTAssertFalse(audio.isIntroductionPlaying)
        XCTAssertEqual(engine.state, .introduction)
        XCTAssertEqual(engine.elapsed, 0)
        XCTAssertNil(coordinator.notice)
        coordinator.cancel()
    }

    func testMissingNarrationFallsBackAndInvalidAudioPauses() async throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "sessions", withExtension: "json")))
        let definition = try XCTUnwrap(SessionDefinition.load(data: data).first)
        let missing = AudioController(introductionURL: nil)
        XCTAssertNotNil(try missing.playIntroduction())
        XCTAssertFalse(missing.isIntroductionPlaying)
        let invalid = AudioController(introductionURL: try XCTUnwrap(Bundle.main.url(forResource: "sessions", withExtension: "json")))
        let storage = SessionStore(defaults: UserDefaults(suiteName: "flow.narration.invalid.\(UUID().uuidString)")!)
        storage.preferences.spokenIntroduction = true
        let engine = SessionEngine(definition: definition, clock: ContinuousTimeSource())
        let coordinator = SessionCoordinator(engine: engine, audio: invalid, store: storage)
        coordinator.start()
        XCTAssertEqual(engine.state, .interrupted)
        XCTAssertNotNil(engine.interruptionReason)
        XCTAssertFalse(invalid.isIntroductionPlaying)
        XCTAssertTrue(storage.history.isEmpty)
        coordinator.cancel()
    }

    func testNarrationStopsOnInterruptionAndDoesNotReplay() async throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "sessions", withExtension: "json")))
        let definition = try XCTUnwrap(SessionDefinition.load(data: data).first)
        let audio = AudioController()
        let storage = SessionStore(defaults: UserDefaults(suiteName: "flow.narration.interruption.\(UUID().uuidString)")!)
        storage.preferences.spokenIntroduction = true
        storage.preferences.sound = false
        let engine = SessionEngine(definition: definition, clock: ContinuousTimeSource())
        let coordinator = SessionCoordinator(engine: engine, audio: audio, store: storage)
        coordinator.start()
        XCTAssertTrue(audio.isIntroductionPlaying)
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification,
                                        object: AVAudioSession.sharedInstance(),
                                        userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(audio.isIntroductionPlaying)
        XCTAssertEqual(engine.state, .interrupted)
        XCTAssertEqual(engine.elapsed, 0)
        coordinator.resume(automaticallyRefresh: false)
        XCTAssertEqual(engine.state, .running)
        XCTAssertFalse(audio.isIntroductionPlaying)
        coordinator.cancel()
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
