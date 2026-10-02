import XCTest
import AVFoundation
@testable import Flow

@MainActor final class NativeAudioTests: XCTestCase {
    private func assets() throws -> [String: URL] {
        var result: [String: URL] = [:]
        for name in ["ambient", "bell", "introduction"] + Array(Guidance.clips.keys) {
            result[name] = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: ["ambient", "bell"].contains(name) ? "wav" : "mp3"))
        }
        return result
    }
    func testBundledAudioAndEveryNarrationTimeline() throws {
        let assets = try assets()
        var lengths: [String: Double] = [:]
        for (name, url) in assets {
            let samples = try SessionAudioRenderer.samples(url)
            lengths[name] = Double(samples.count) / SessionAudioRenderer.rate
            XCTAssertGreaterThan(samples.map { abs($0) }.max() ?? 0, 0.005, name)
            XCTAssertLessThan(samples.map { abs($0) }.max() ?? 1, 1, name)
        }
        XCTAssertEqual(lengths["introduction"]!, 28.10775, accuracy: 0.1)
        XCTAssertEqual(lengths["bell"]!, 8, accuracy: 0.01)
        for practice in Practice.allCases {
            for minutes in SessionDefinition.minuteOptions {
                for guidance in GuidanceLevel.allCases {
                    for breathing in BreathingMode.allCases {
                        let definition = try SessionDefinition(practice: practice, minutes: minutes, guidance: guidance, breathing: breathing)
                        var end = 0.0
                        for cue in definition.narration {
                            XCTAssertGreaterThanOrEqual(cue.time, end, "overlap: \(definition), \(cue.clip)")
                            end = cue.time + lengths[cue.clip]!
                            XCTAssertLessThan(end, definition.duration)
                        }
                    }
                }
            }
        }
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String], ["audio"])
    }
    func testRenderedGuidanceSilenceAndBellPlacement() throws {
        let definition = try SessionDefinition(minutes: 2, guidance: .full, breathing: .paced)
        let url = try SessionAudioRenderer.render(definition: definition, preferences: Preferences(), assets: assets())
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(Double(file.length) / file.processingFormat.sampleRate, 128, accuracy: 0.001)
        func peak(_ start: Double, _ length: Double) throws -> Float {
            file.framePosition = AVAudioFramePosition(start * file.processingFormat.sampleRate)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(length * file.processingFormat.sampleRate)))
            try file.read(into: buffer)
            let data = try XCTUnwrap(buffer.floatChannelData?[0])
            return UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)).map { abs($0) }.max() ?? 0
        }
        XCTAssertGreaterThan(try peak(0, 1), 0.01)
        XCTAssertGreaterThan(try peak(4, 4), 0.02)
        XCTAssertEqual(try peak(101, 3), 0) // Beyond the opening of Open, before Return.
        XCTAssertGreaterThan(try peak(120, 1), 0.01)
        XCTAssertLessThan(try peak(127.5, 0.5), 0.001)
    }
    func testThirtyMinutePureSilenceIsFiniteAndSilentBetweenBells() throws {
        let definition = try SessionDefinition(practice: .silence, minutes: 30)
        let url = try SessionAudioRenderer.render(definition: definition, preferences: Preferences(), assets: assets())
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(Double(file.length) / file.processingFormat.sampleRate, 1808, accuracy: 0.001)
        file.framePosition = 20 * 24_000
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 24_000))
        try file.read(into: buffer)
        XCTAssertTrue(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)).allSatisfy { $0 == 0 })
        let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize!
        XCTAssertLessThan(bytes, 90_000_000)
    }
    func testMissingAssetAndCancelledPreparationFailCleanly() async throws {
        XCTAssertThrowsError(try SessionAudioRenderer.render(definition: SessionDefinition(minutes: 2), preferences: Preferences(), assets: [:]))
        let audio = AudioController()
        let task = Task { try await audio.prepare(definition: SessionDefinition(minutes: 30), preferences: Preferences()) }
        task.cancel()
        do { try await task.value; XCTFail("Cancelled render should throw") } catch is CancellationError {} catch { XCTFail("\(error)") }
        XCTAssertFalse(audio.isPlaying)
        XCTAssertEqual(audio.playbackDuration, 0)
        audio.stopAll()
    }
    func testNativePlaybackPauseResumeAndRepeatedCleanup() async throws {
        let audio = AudioController()
        for _ in 0..<2 {
            try await audio.prepare(definition: SessionDefinition(practice: .silence, minutes: 2), preferences: Preferences())
            XCTAssertEqual(audio.playbackDuration, 128, accuracy: 0.01)
            try audio.play(from: 45)
            XCTAssertTrue(audio.isPlaying)
            try await Task.sleep(for: .milliseconds(150))
            audio.pause()
            let position = audio.playbackTime
            XCTAssertGreaterThan(position, 45)
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertEqual(audio.playbackTime, position, accuracy: 0.02)
            audio.setMuted(true)
            try audio.play(from: position)
            XCTAssertTrue(audio.isPlaying)
            audio.stopAll()
            XCTAssertFalse(audio.isPlaying)
            XCTAssertEqual(audio.playbackDuration, 0)
        }
    }
    func testNativeNotificationsPauseAndResetCanResume() async throws {
        let notifications: [(Notification.Name, [String: Any]?)] = [
            (AVAudioSession.interruptionNotification, [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]),
            (AVAudioSession.routeChangeNotification, [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]),
            (AVAudioSession.mediaServicesWereResetNotification, nil),
            (AVAudioSession.mediaServicesWereLostNotification, nil)
        ]
        let audio = AudioController()
        let storage = SessionStore(defaults: UserDefaults(suiteName: "flow.native.\(UUID().uuidString)")!)
        let engine = SessionEngine(definition: try SessionDefinition(practice: .silence, minutes: 2), clock: ContinuousTimeSource())
        let coordinator = SessionCoordinator(engine: engine, audio: audio, store: storage)
        await coordinator.prepareAndStart(automaticallyRefresh: false)
        for (name, info) in notifications {
            XCTAssertEqual(engine.state, .running)
            NotificationCenter.default.post(name: name, object: AVAudioSession.sharedInstance(), userInfo: info)
            try await Task.sleep(for: .milliseconds(150))
            XCTAssertEqual(engine.state, .interrupted)
            XCTAssertFalse(audio.isPlaying)
            NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(),
                userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                           AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue])
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertEqual(engine.state, .interrupted)
            coordinator.resume(automaticallyRefresh: false)
            XCTAssertTrue(audio.isPlaying)
        }
        XCTAssertTrue(storage.history.isEmpty)
        coordinator.cancel()
    }
}
