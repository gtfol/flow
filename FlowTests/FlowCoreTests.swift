import XCTest
#if canImport(FlowCore)
@testable import FlowCore
#else
@testable import Flow
#endif

@MainActor private final class FakeClock: MonotonicTimeSource {
    var now: TimeInterval = 0
    func advance(_ duration: TimeInterval) { now += duration }
}

@MainActor private final class FakeAudio: SessionAudio {
    var onInterruption: ((String) -> Void)?
    var starts = 0
    var stops = 0
    var tones: [SessionDefinition.Phase.Kind] = []
    var speeches = 0
    var failAmbient = false
    var failCue = false
    var failSpeech = false
    var soundPlaying = false
    var speechPlaying = false
    var noVoice = false
    enum Failure: Error { case failed }
    func startAmbient(preferences: Preferences) throws {
        if failAmbient { throw Failure.failed }
        starts += 1
        soundPlaying = true
    }
    func cue(_ kind: SessionDefinition.Phase.Kind, volume: Float) throws {
        if failCue { throw Failure.failed }
        tones.append(kind)
    }
    func setVolumes(ambient: Float, cue: Float) {}
    func stopSound() { soundPlaying = false }
    func stopAll() { stops += 1; soundPlaying = false; speechPlaying = false }
    func playIntroduction() throws -> String? {
        if failSpeech { throw Failure.failed }
        if noVoice { return "introduction audio unavailable" }
        speeches += 1
        speechPlaying = true
        return nil
    }
}

@MainActor final class FlowCoreTests: XCTestCase {
    private func definition(_ duration: Double = 120) throws -> SessionDefinition {
        try SessionDefinition(id: "test", title: "test session", detail: "original description",
                              duration: duration, contentRevision: 1,
                              phases: [.init(kind: .inhale, duration: 4), .init(kind: .exhale, duration: 4)])
    }

    private func store() -> SessionStore {
        SessionStore(defaults: UserDefaults(suiteName: "flow.tests.\(UUID().uuidString)")!)
    }

    private func harness(_ duration: Double = 120, paced: Bool = true) throws -> (SessionCoordinator, FakeClock, FakeAudio, SessionStore) {
        let clock = FakeClock()
        let audio = FakeAudio()
        let storage = store()
        let engine = SessionEngine(definition: try definition(duration), mode: paced ? .paced : .natural, clock: clock)
        let coordinator = SessionCoordinator(engine: engine, audio: audio, store: storage)
        coordinator.start()
        coordinator.resume(automaticallyRefresh: false)
        return (coordinator, clock, audio, storage)
    }

    func testBundledDefinitionsContainBothDurationsAndRevisions() async throws {
        #if os(iOS)
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "sessions", withExtension: "json")))
        #else
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Flow/Resources/sessions.json"))
        #endif
        let definitions = try SessionDefinition.load(data: data)
        XCTAssertEqual(definitions.map(\.duration), [120, 300])
        XCTAssertEqual(definitions.map(\.contentRevision), [1, 1])
        XCTAssertEqual(definitions.map(\.id), ["small-pause", "quiet-five"])
    }

    func testRejectsNonpositiveNonfiniteAndExcessiveDurations() async throws {
        for duration in [0.0, -1, .infinity, .nan, 301] { XCTAssertThrowsError(try definition(duration)) }
    }

    func testRejectsHoldsMalformedPhasesAndUnknownFields() async throws {
        let valid = try JSONEncoder().encode([definition()])
        let text = String(decoding: valid, as: UTF8.self)
        for invalid in [
            text.replacingOccurrences(of: "inhale", with: "hold"),
            text.replacingOccurrences(of: "exhale", with: "rapid"),
            text.replacingOccurrences(of: "\"duration\":4", with: "\"duration\":0"),
            text.replacingOccurrences(of: "\"duration\":4", with: "\"duration\":3"),
            text.replacingOccurrences(of: "\"contentRevision\":1", with: "\"contentRevision\":0"),
            text.replacingOccurrences(of: "\"kind\":", with: "\"hold\":2,\"kind\":"),
            text.replacingOccurrences(of: "\"contentRevision\":", with: "\"customProtocol\":true,\"contentRevision\":")
        ] { XCTAssertThrowsError(try SessionDefinition.load(data: Data(invalid.utf8))) }
        XCTAssertThrowsError(try SessionDefinition.load(data: Data("[]".utf8)))
        XCTAssertThrowsError(try SessionDefinition.load(data: JSONEncoder().encode([definition(), definition()])))
        XCTAssertThrowsError(try SessionDefinition(id: "x", title: "x", detail: "x", duration: 120, contentRevision: 1, phases: []))
    }

    func testExactPhaseBoundaries() async throws {
        let (coordinator, clock, _, _) = try harness()
        let engine = coordinator.engine
        XCTAssertEqual(engine.phase?.kind, .inhale)
        clock.advance(3.999); coordinator.tick()
        XCTAssertEqual(engine.phase?.kind, .inhale)
        clock.advance(0.001); coordinator.tick()
        XCTAssertEqual(engine.phase?.kind, .exhale)
        XCTAssertEqual(engine.phase?.progress, 0)
        clock.advance(4); coordinator.tick()
        XCTAssertEqual(engine.phase?.kind, .inhale)
        XCTAssertEqual(engine.phase?.sequence, 2)
    }

    func testDelayedRefreshDerivesPhaseWithoutDriftOrStaleTones() async throws {
        let (coordinator, clock, audio, _) = try harness()
        clock.advance(29.75); coordinator.tick()
        XCTAssertEqual(coordinator.engine.elapsed, 29.75)
        XCTAssertEqual(coordinator.engine.phase?.kind, .exhale)
        XCTAssertEqual(coordinator.engine.phase?.progress, 1.75 / 4)
        XCTAssertEqual(audio.tones, [.inhale])
        clock.advance(2.25); coordinator.tick()
        XCTAssertEqual(audio.tones, [.inhale, .inhale])
    }

    func testBothDurationsCompleteOnceAndClampLateUpdates() async throws {
        for duration in [120.0, 300.0] {
            let (coordinator, clock, audio, storage) = try harness(duration)
            clock.advance(duration - 0.001); coordinator.tick()
            XCTAssertEqual(coordinator.engine.state, .running)
            XCTAssertTrue(storage.history.isEmpty)
            clock.advance(22); coordinator.tick()
            XCTAssertEqual(coordinator.engine.state, .completed)
            XCTAssertEqual(coordinator.engine.elapsed, duration)
            XCTAssertFalse(audio.soundPlaying)
            for _ in 0..<5 { coordinator.tick(); coordinator.stop(); storage.recordCompletion(of: coordinator.engine, at: Date()) }
            XCTAssertEqual(storage.history.count, 1)
            XCTAssertEqual(storage.history[0].activeDuration, duration)
            XCTAssertEqual(storage.history[0].runID, coordinator.engine.runID)
            XCTAssertEqual(storage.history[0].sessionID, "test")
        }
    }

    func testPauseFreezesTimeAndResumeRestartsInhaleWithoutDiscardingActiveTime() async throws {
        let (coordinator, clock, audio, storage) = try harness()
        clock.advance(5.5); coordinator.pause()
        XCTAssertEqual(coordinator.engine.elapsed, 5.5)
        XCTAssertFalse(audio.soundPlaying)
        clock.advance(900); coordinator.tick()
        XCTAssertEqual(coordinator.engine.elapsed, 5.5)
        XCTAssertTrue(storage.history.isEmpty)
        coordinator.resume(automaticallyRefresh: false)
        XCTAssertEqual(coordinator.engine.phase?.kind, .inhale)
        XCTAssertEqual(coordinator.engine.phase?.progress, 0)
        XCTAssertEqual(audio.tones, [.inhale, .inhale])
        clock.advance(4); coordinator.tick()
        XCTAssertEqual(coordinator.engine.elapsed, 9.5)
        XCTAssertEqual(coordinator.engine.phase?.kind, .exhale)
        clock.advance(110.5); coordinator.tick()
        XCTAssertEqual(coordinator.engine.state, .completed)
        XCTAssertEqual(storage.history.count, 1)
    }

    func testAllInterruptionsFreezeAndNeverAutoResume() async throws {
        for event in 0..<4 {
            let (coordinator, clock, audio, storage) = try harness()
            clock.advance(7)
            switch event {
            case 0: coordinator.appBecameInactive()
            case 1: coordinator.routeDisconnected()
            case 2: coordinator.mediaServicesReset()
            default: audio.onInterruption?("interrupted")
            }
            XCTAssertEqual(coordinator.engine.state, .interrupted)
            XCTAssertEqual(coordinator.engine.elapsed, 7)
            XCTAssertNotNil(coordinator.engine.interruptionReason)
            clock.advance(1000); coordinator.tick()
            XCTAssertEqual(coordinator.engine.elapsed, 7)
            XCTAssertEqual(coordinator.engine.state, .interrupted)
            XCTAssertFalse(audio.soundPlaying)
            XCTAssertTrue(storage.history.isEmpty)
            coordinator.resume(automaticallyRefresh: false)
            XCTAssertEqual(coordinator.engine.phase?.kind, .inhale)
            XCTAssertEqual(coordinator.engine.elapsed, 7)
        }
    }

    func testStopAndCancellationNeverRecordACompletion() async throws {
        for shouldCancel in [true, false] {
            let (coordinator, clock, audio, storage) = try harness()
            clock.advance(23.5)
            if shouldCancel { coordinator.cancel() } else { coordinator.stop() }
            coordinator.stop(); coordinator.tick()
            storage.recordCompletion(of: coordinator.engine, at: Date())
            XCTAssertEqual(coordinator.engine.state, .stopped)
            XCTAssertEqual(coordinator.engine.elapsed, 23.5)
            XCTAssertTrue(storage.history.isEmpty)
            XCTAssertFalse(audio.soundPlaying)
            coordinator.resume(automaticallyRefresh: false)
            XCTAssertEqual(coordinator.engine.state, .stopped)
        }
    }

    func testAmbientFailurePausesAndCanRecoverWithSoundDisabled() async throws {
        let clock = FakeClock(), audio = FakeAudio(), storage = store()
        audio.failAmbient = true
        let coordinator = SessionCoordinator(engine: SessionEngine(definition: try definition(), clock: clock), audio: audio, store: storage)
        coordinator.start(); coordinator.resume(automaticallyRefresh: false)
        XCTAssertEqual(coordinator.engine.state, .interrupted)
        clock.advance(300); coordinator.tick()
        XCTAssertEqual(coordinator.engine.elapsed, 0)
        XCTAssertFalse(audio.soundPlaying)
        coordinator.setSound(false); coordinator.resume(automaticallyRefresh: false)
        XCTAssertEqual(coordinator.engine.state, .running)
        XCTAssertFalse(audio.soundPlaying)
    }

    func testCueFailureStopsAudioAndPausesVisual() async throws {
        let (coordinator, clock, audio, storage) = try harness()
        audio.failCue = true
        clock.advance(4); coordinator.tick()
        XCTAssertEqual(coordinator.engine.state, .interrupted)
        XCTAssertFalse(audio.soundPlaying)
        XCTAssertTrue(storage.history.isEmpty)
    }

    func testNaturalModeHasNoPhaseCuesAndCanBeSelectedMidSession() async throws {
        let (coordinator, clock, audio, _) = try harness()
        clock.advance(3); coordinator.setMode(.natural)
        XCTAssertNil(coordinator.engine.phase)
        clock.advance(13); coordinator.tick()
        XCTAssertEqual(coordinator.engine.elapsed, 16)
        XCTAssertEqual(audio.tones, [.inhale])
        let (natural, _, naturalAudio, _) = try harness(paced: false)
        XCTAssertEqual(natural.engine.mode, .natural)
        XCTAssertTrue(naturalAudio.tones.isEmpty)
    }

    func testIntroductionIsUntimedAndPauseStopsSpeechWithoutReplay() async throws {
        let storage = store(), clock = FakeClock(), audio = FakeAudio()
        storage.preferences.spokenIntroduction = true
        storage.preferences.sound = false
        let coordinator = SessionCoordinator(engine: SessionEngine(definition: try definition(), clock: clock), audio: audio, store: storage)
        coordinator.start(); coordinator.start()
        XCTAssertEqual(audio.speeches, 1)
        clock.advance(30); coordinator.tick()
        XCTAssertEqual(coordinator.engine.elapsed, 0)
        coordinator.appBecameInactive()
        XCTAssertFalse(audio.speechPlaying)
        clock.advance(300); coordinator.resume(automaticallyRefresh: false)
        XCTAssertEqual(audio.speeches, 1)
        XCTAssertEqual(coordinator.engine.elapsed, 0)
        XCTAssertEqual(coordinator.engine.state, .running)
        XCTAssertEqual(audio.starts, 0)
    }

    func testMissingNarrationHasReadableFallbackAndNoTimedProgress() async throws {
        let storage = store(), clock = FakeClock(), audio = FakeAudio()
        storage.preferences.spokenIntroduction = true
        audio.noVoice = true
        let coordinator = SessionCoordinator(engine: SessionEngine(definition: try definition(), clock: clock), audio: audio, store: storage)
        coordinator.start()
        XCTAssertNotNil(coordinator.notice)
        XCTAssertEqual(coordinator.engine.state, .introduction)
        XCTAssertEqual(coordinator.engine.elapsed, 0)
        coordinator.resume(automaticallyRefresh: false)
        XCTAssertEqual(coordinator.engine.state, .running)
    }

    func testDefaultsAndPreferencesSurviveRelaunch() async throws {
        let defaults = UserDefaults(suiteName: "flow.relaunch.\(UUID().uuidString)")!
        let storage = SessionStore(defaults: defaults)
        XCTAssertTrue(storage.preferences.sound)
        XCTAssertFalse(storage.preferences.spokenIntroduction)
        XCTAssertFalse(storage.preferences.haptics)
        XCTAssertFalse(storage.preferences.hasReadSafety)
        storage.preferences.sound = false
        storage.preferences.spokenIntroduction = true
        storage.preferences.haptics = true
        storage.preferences.hasReadSafety = true
        storage.preferences.ambientVolume = 0.15
        storage.preferences.cueVolume = 0.5
        let relaunched = SessionStore(defaults: defaults)
        XCTAssertEqual(storage.preferences, relaunched.preferences)
        let engine = SessionEngine(definition: try definition(), clock: FakeClock())
        XCTAssertEqual(engine.mode, .natural)
    }

    func testHistoryRelaunchDeduplicationAndDeletionPreservePreferencesAndContent() async throws {
        let defaults = UserDefaults(suiteName: "flow.history.\(UUID().uuidString)")!
        let storage = SessionStore(defaults: defaults), clock = FakeClock()
        let content = try definition()
        let engine = SessionEngine(definition: content, clock: clock)
        engine.beginIntroduction(); engine.beginRunning(); clock.advance(120); engine.refresh()
        storage.recordCompletion(of: engine, at: Date(timeIntervalSince1970: 42))
        let relaunched = SessionStore(defaults: defaults)
        relaunched.recordCompletion(of: engine, at: Date())
        XCTAssertEqual(relaunched.history.count, 1)
        XCTAssertEqual(relaunched.history[0].completedAt, Date(timeIntervalSince1970: 42))
        relaunched.preferences.haptics = true
        relaunched.deleteHistory()
        XCTAssertTrue(SessionStore(defaults: defaults).history.isEmpty)
        XCTAssertTrue(SessionStore(defaults: defaults).preferences.haptics)
        XCTAssertEqual(engine.definition, content)
    }

    func testLateCallbacksDoNotRecreateDeletedHistory() async throws {
        let (coordinator, clock, _, storage) = try harness()
        clock.advance(120); coordinator.tick()
        storage.deleteHistory()
        coordinator.tick(); coordinator.stop(); coordinator.cancel()
        XCTAssertTrue(storage.history.isEmpty)
    }

    func testRepeatedStartsDoNotStackAndNewRunsHaveUniqueIDs() async throws {
        let (coordinator, _, audio, _) = try harness()
        coordinator.start(); coordinator.resume(automaticallyRefresh: false)
        XCTAssertEqual(audio.starts, 1)
        let (next, _, _, _) = try harness()
        XCTAssertNotEqual(coordinator.engine.runID, next.engine.runID)
    }

    func testCancelledObserverCannotCompleteLater() async throws {
        let (coordinator, clock, _, storage) = try harness()
        coordinator.pause()
        coordinator.resume()
        coordinator.cancel()
        clock.advance(1000)
        try await Task.sleep(for: .milliseconds(130))
        XCTAssertEqual(coordinator.engine.state, .stopped)
        XCTAssertTrue(storage.history.isEmpty)
    }
}
